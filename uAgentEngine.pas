unit uAgentEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentTypes, uLlmClient, uAgentTools;

type
  { Event types for UI notification }
  TAgentStateChangeEvent = procedure(Sender: TObject; AOldState, ANewState: TAgentState) of object;
  TAgentMessageEvent = procedure(Sender: TObject; const AMessage: TChatMessage) of object;
  TAgentToolCallEvent = procedure(Sender: TObject; const AToolName, AArgs: string) of object;
  TAgentToolResultEvent = procedure(Sender: TObject; const AToolName: string; const AResult: TToolExecutionResult) of object;

  { TAgentEngine - Coordinates conversation, autonomous ReAct loops, and tool execution }
  TAgentEngine = class
  private
    FState: TAgentState;
    FClient: TLlmClient;
    FTools: TAgentToolRegistry;
    FContext: TAgentToolContext;
    FMessages: array of TChatMessage;
    FMaxSteps: Integer;
    FCancelRequested: Boolean;

    FOnStateChange: TAgentStateChangeEvent;
    FOnMessageAdded: TAgentMessageEvent;
    FOnToolCall: TAgentToolCallEvent;
    FOnToolResult: TAgentToolResultEvent;

    procedure SetState(ANewState: TAgentState);
    procedure AppendMessage(const AMsg: TChatMessage);
    function BuildSystemPrompt(AMode: TWorkspaceMode): string;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    procedure ClearConversation;
    procedure StartRun(const AUserPrompt: string; AMode: TWorkspaceMode; const AModel: string);
    procedure RequestCancel;

    function GetMessageCount: Integer;
    function GetMessage(AIndex: Integer): TChatMessage;

    property State: TAgentState read FState;
    property Client: TLlmClient read FClient;
    property Context: TAgentToolContext read FContext;
    property MaxSteps: Integer read FMaxSteps write FMaxSteps;

    property OnStateChange: TAgentStateChangeEvent read FOnStateChange write FOnStateChange;
    property OnMessageAdded: TAgentMessageEvent read FOnMessageAdded write FOnMessageAdded;
    property OnToolCall: TAgentToolCallEvent read FOnToolCall write FOnToolCall;
    property OnToolResult: TAgentToolResultEvent read FOnToolResult write FOnToolResult;
  end;

implementation

constructor TAgentEngine.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  FState := asIdle;
  FMaxSteps := 20;
  FCancelRequested := False;

  FClient := TLlmClient.Create;
  FContext := TAgentToolContext.Create(AWorkspaceRoot);
  FTools := TAgentToolRegistry.Create(FContext);
  SetLength(FMessages, 0);
end;

destructor TAgentEngine.Destroy;
begin
  FTools.Free;
  FContext.Free;
  FClient.Free;
  inherited Destroy;
end;

procedure TAgentEngine.SetState(ANewState: TAgentState);
var
  Old: TAgentState;
begin
  if FState <> ANewState then begin
    Old := FState;
    FState := ANewState;
    if Assigned(FOnStateChange) then
      FOnStateChange(Self, Old, ANewState);
  end;
end;

procedure TAgentEngine.AppendMessage(const AMsg: TChatMessage);
var
  Idx: Integer;
begin
  Idx := Length(FMessages);
  SetLength(FMessages, Idx + 1);
  FMessages[Idx] := AMsg;
  if Assigned(FOnMessageAdded) then
    FOnMessageAdded(Self, AMsg);
end;

function TAgentEngine.BuildSystemPrompt(AMode: TWorkspaceMode): string;
begin
  Result := 'You are LazyCodingAgent, an autonomous AI software engineer and coding assistant working inside the user''s Free Pascal / Lazarus project.' + LineEnding;
  Result := Result + 'Current workspace root: ' + FContext.WorkspaceRoot + LineEnding + LineEnding;

  case AMode of
    wmAsk:
      begin
        Result := Result + 'MODE: ASK (Q&A)' + LineEnding;
        Result := Result + 'Help the user by explaining code, answering architecture or language questions, and providing code examples. Do not modify workspace files unless explicitly requested.' + LineEnding;
      end;
    wmPlan:
      begin
        Result := Result + 'MODE: PLAN (Architecture & Specs)' + LineEnding;
        Result := Result + 'Formulate architectural plans, step-by-step checklists, and design docs. Use the `todo` tool to track tasks and keep items organized.' + LineEnding;
      end;
    wmAgent:
      begin
        Result := Result + 'MODE: AGENT (Autopilot Execution)' + LineEnding;
        Result := Result + 'You have full access to workspace tools: read_file, write_file, list_directory, search_code, run_process, diagnostics, todo.' + LineEnding;
        Result := Result + '1. Always inspect files first before making assumptions.' + LineEnding;
        Result := Result + '2. Execute code edits systematically and test with diagnostics.' + LineEnding;
        Result := Result + '3. Always provide a clear, concise summary of changes made when finished.' + LineEnding;
      end;
  end;
end;

procedure TAgentEngine.ClearConversation;
begin
  SetLength(FMessages, 0);
  FContext.ClearTasks;
  SetState(asIdle);
end;

procedure TAgentEngine.RequestCancel;
begin
  FCancelRequested := True;
end;

function TAgentEngine.GetMessageCount: Integer;
begin
  Result := Length(FMessages);
end;

function TAgentEngine.GetMessage(AIndex: Integer): TChatMessage;
begin
  Result := FMessages[AIndex];
end;

procedure TAgentEngine.StartRun(
  const AUserPrompt: string;
  AMode: TWorkspaceMode;
  const AModel: string
);
var
  SysMsg, UserMsg, AssistantMsg, ToolMsg: TChatMessage;
  ToolDefs: array of TToolDef;
  Resp: TLlmResponse;
  StepCount, I: Integer;
  ToolResult: TToolExecutionResult;
  HadToolCalls: Boolean;
begin
  if FState in [asThinking, asExecutingTool] then Exit;

  FCancelRequested := False;
  if Trim(AModel) <> '' then
    FClient.Model := AModel;

  // Add system message if starting fresh
  if Length(FMessages) = 0 then begin
    SysMsg := StringToChatRole('system');
    SysMsg.Content := BuildSystemPrompt(AMode);
    AppendMessage(SysMsg);
  end;

  // Append user message
  UserMsg := StringToChatRole('user');
  UserMsg.Content := AUserPrompt;
  AppendMessage(UserMsg);

  StepCount := 0;
  if AMode = wmAgent then
    ToolDefs := FTools.GetToolDefinitions
  else if AMode = wmPlan then begin
    // Plan mode provides todo, read_file, search_code, list_directory
    ToolDefs := FTools.GetToolDefinitions;
  end else
    SetLength(ToolDefs, 0);

  while (StepCount < FMaxSteps) and not FCancelRequested do begin
    Inc(StepCount);
    SetState(asThinking);

    // Call LLM
    Resp := FClient.SendChatCompletion(FMessages, ToolDefs);

    if FCancelRequested then begin
      SetState(asIdle);
      Exit;
    end;

    if not Resp.Success then begin
      AssistantMsg := StringToChatRole('assistant');
      AssistantMsg.Content := '❌ LLM Request Error: ' + Resp.ErrorMessage;
      AppendMessage(AssistantMsg);
      SetState(asError);
      Exit;
    end;

    // Record Assistant response
    AssistantMsg := StringToChatRole('assistant');
    AssistantMsg.Content := Resp.Content;
    AssistantMsg.ToolCalls := Resp.ToolCalls;
    AssistantMsg.TokensUsed := Resp.TotalTokens;
    AppendMessage(AssistantMsg);

    // If no tool calls, task step is completed
    if Length(Resp.ToolCalls) = 0 then begin
      SetState(asFinished);
      Exit;
    end;

    // Execute tools
    HadToolCalls := False;
    SetState(asExecutingTool);
    for I := Low(Resp.ToolCalls) to High(Resp.ToolCalls) do begin
      if FCancelRequested then Break;

      HadToolCalls := True;
      if Assigned(FOnToolCall) then
        FOnToolCall(Self, Resp.ToolCalls[I].Name, Resp.ToolCalls[I].ArgumentsJson);

      ToolResult := FTools.ExecuteTool(Resp.ToolCalls[I].Name, Resp.ToolCalls[I].ArgumentsJson);

      if Assigned(FOnToolResult) then
        FOnToolResult(Self, Resp.ToolCalls[I].Name, ToolResult);

      ToolMsg := StringToChatRole('tool');
      ToolMsg.ToolCallId := Resp.ToolCalls[I].Id;
      ToolMsg.Content := ToolResult.Output;
      ToolMsg.VisualSummary := ToolResult.Summary;
      AppendMessage(ToolMsg);
    end;

    if not HadToolCalls or FCancelRequested then Break;
  end;

  if FCancelRequested then
    SetState(asIdle)
  else
    SetState(asFinished);
end;

end.
