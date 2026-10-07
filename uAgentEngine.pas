unit uAgentEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentTypes, uLlmClient, uAgentTools, uAgentRules;

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
    procedure ApplySystemPrompt(AMode: TWorkspaceMode);
    function BuildSystemPrompt(AMode: TWorkspaceMode): string;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    procedure ClearConversation;
    procedure StartRun(const AUserPrompt: string; AMode: TWorkspaceMode; const AModel: string);
    procedure RequestCancel;
    function ExecuteToolDirect(const AName, AArgumentsJson: string;
      AMode: TWorkspaceMode): TToolExecutionResult;

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
  FContext.SetCancelFlag(@FCancelRequested);
  FContext.SetCancelDeadline(0);
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
var
  RulesText, ToolsInfo, WorkingDir: string;
begin
  WorkingDir := FContext.WorkspaceRoot;
  ToolsInfo := FTools.ToolGuidance(AMode);

  case AMode of
    wmPlan:
      Result :=
        'You are an expert software architect planning development in the current project.' + LineEnding +
        'Active Mode: Plan' + LineEnding +
        'Current Project Directory: ' + WorkingDir + LineEnding + LineEnding +
        ToolsInfo +
        'Instructions:' + LineEnding +
        '- This agent is working on a project. For project tasks, always inspect the actual files and use list_directory/glob/search_code/read_file before making claims.' + LineEnding +
        '- Use inspection tools, cached diagnostics, and task tracking.' + LineEnding +
        '- Only create .md files inside ' + IncludeTrailingPathDelimiter(WorkingDir) + '.plan' + DirectorySeparator + ', using create_plan_file. Do not modify other project files. Shell commands and compiler builds are unavailable.' + LineEnding +
        '- Produce a structured, actionable Markdown plan and save it with create_plan_file. The tool chooses a timestamped filename under .plan/.' + LineEnding +
        '- If clarification is needed, ask questions in chat without saving a plan. Otherwise, mark any completed plan returned in chat with <proposed_plan> and </proposed_plan> on separate lines, so the app can save and preview it if necessary.' + LineEnding +
        '- Do not implement the plan.';

    wmAgent:
      Result :=
        'You are LazyCodingAgent, an autonomous coding agent working on the current project, integrated into Free Lazarus IDE / Free Pascal.' + LineEnding +
        'Active Mode: Agent' + LineEnding +
        'Current Project Directory: ' + WorkingDir + LineEnding + LineEnding +
        ToolsInfo + LineEnding +
        'Instructions:' + LineEnding +
        '- For project tasks, always inspect the actual files with list_directory/glob/search_code/read_file before making claims or changes; do not guess at file contents.' + LineEnding +
        '- Implement the user request fully using the available project tools.' + LineEnding +
        '- If apply_patch reports a context mismatch, reread the affected file and retry with exact current lines; never guess or use fuzzy context.' + LineEnding +
        '- The apply_patch patch argument contains only a raw unified diff: --- a/file.pas, +++ b/file.pas, @@ -1 +1 @@, -old, +new on separate lines. Do not include prose, Markdown fences, or *** Begin Patch markers.' + LineEnding +
        '- If apply_patch returns hunk_count_mismatch or incomplete_hunk, recount the @@ old/new line counts: every hunk line must start with space, -, or +; blank lines are invalid.' + LineEnding +
        {$IFDEF UNIX}
        '- For shell, use /bin/sh syntax (&&, ;, $?, etc.).' + LineEnding +
        {$ELSE}
        '- For shell, use cmd.exe syntax (&, >, exit /b, etc.).' + LineEnding +
        {$ENDIF}
        '- When diagnostics cannot start the resolved toolchain, explain the missing dependency/PATH requirement. When a build fails, use its preserved stdout/stderr and parsed messages to diagnose the failure.' + LineEnding +
        '- Output clean, robust Free Pascal code compatible with the Lazarus Component Library (LCL).' + LineEnding +
        '- Work systematically step by step until the user task is fully resolved.' + LineEnding +
        '- Finish with a short summary of what was accomplished and any checks actually performed. State unfinished work or failures clearly.';

    else
      Result :=
        'You are an expert software assistant working in the current project.' + LineEnding +
        'Active Mode: Ask' + LineEnding +
        'Current Project Directory: ' + WorkingDir + LineEnding + LineEnding +
        ToolsInfo + LineEnding +
        'Instructions:' + LineEnding +
        '- For project questions, always inspect the actual files with list_directory/glob/search_code/read_file before answering.' + LineEnding +
        '- This is Ask mode: use inspection tools, cached diagnostics, and task tracking. Do not write or create files, call write tools, or propose file-write actions.' + LineEnding +
        '- Answer questions directly and accurately using what you learned from the project.';
  end;

  Result := Result + LineEnding + LineEnding +
    'Tool results are JSON objects. Read error and error_kind fields to recover from failures.';

  RulesText := TAgentRules.ReadAll(FContext.WorkspaceRoot);
  if RulesText <> '' then
    Result := Result + LineEnding + LineEnding +
      'Project Rules (from .rules/*.md):' + LineEnding + RulesText;
end;

procedure TAgentEngine.ApplySystemPrompt(AMode: TWorkspaceMode);
var
  SysMsg: TChatMessage;
  I: Integer;
begin
  SysMsg := StringToChatRole('system');
  SysMsg.Content := BuildSystemPrompt(AMode);
  if (Length(FMessages) > 0) and (FMessages[0].Role = crSystem) then
    FMessages[0] := SysMsg
  else if Length(FMessages) = 0 then
    FMessages := [SysMsg]
  else begin
    SetLength(FMessages, Length(FMessages) + 1);
    for I := High(FMessages) downto 1 do
      FMessages[I] := FMessages[I - 1];
    FMessages[0] := SysMsg;
  end;
end;

function TAgentEngine.ExecuteToolDirect(const AName, AArgumentsJson: string;
  AMode: TWorkspaceMode): TToolExecutionResult;
begin
  Result := FTools.ExecuteTool(AName, AArgumentsJson, AMode);
end;

procedure TAgentEngine.ClearConversation;
begin
  SetLength(FMessages, 0);
  FContext.ClearSession;
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
  UserMsg, AssistantMsg, ToolMsg: TChatMessage;
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

  ApplySystemPrompt(AMode);

  // Append user message
  UserMsg := StringToChatRole('user');
  UserMsg.Content := AUserPrompt;
  AppendMessage(UserMsg);

  StepCount := 0;
  FContext.Mode := AMode;
  ToolDefs := FTools.GetToolDefinitions(AMode);

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

      ToolResult := FTools.ExecuteTool(Resp.ToolCalls[I].Name, Resp.ToolCalls[I].ArgumentsJson, AMode);

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
