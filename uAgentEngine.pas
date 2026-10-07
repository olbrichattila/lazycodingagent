unit uAgentEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, uAppTypes, uAgentTypes, uLlmClient, uAgentTools, uAgentRules,
  uAgentExecutionLog;

type
  { Event types for UI notification }
  TAgentStateChangeEvent = procedure(Sender: TObject; AOldState, ANewState: TAgentState) of object;
  TAgentMessageEvent = procedure(Sender: TObject; const AMessage: TChatMessage) of object;
  TAgentToolCallEvent = procedure(Sender: TObject; const AToolName, AArgs: string) of object;
  TAgentToolResultEvent = procedure(Sender: TObject; const AToolName, AArgsJson: string;
    const AResult: TToolExecutionResult) of object;
  TAgentExecutionLogEvent = procedure(Sender: TObject; AEntryIndex: Integer) of object;

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
    FRunActive: Boolean;
    FInWorkerRun: Boolean;
    FDestroying: Boolean;
    FRunThread: TThread;
    FRunLock: TCriticalSection;
    FDataLock: TCriticalSection;

    FOnStateChange: TAgentStateChangeEvent;
    FOnMessageAdded: TAgentMessageEvent;
    FOnToolCall: TAgentToolCallEvent;
    FOnToolResult: TAgentToolResultEvent;
    FOnExecutionLogAdded: TAgentExecutionLogEvent;
    FExecutionLog: TAgentExecutionLog;

    FSyncOldState: TAgentState;
    FSyncNewState: TAgentState;
    FSyncMessage: TChatMessage;
    FSyncToolName: string;
    FSyncToolArgs: string;
    FSyncToolResult: TToolExecutionResult;
    FSyncLogEntryIndex: Integer;

    FRunSnapProvider: TLlmProvider;
    FRunSnapApiKey: string;
    FRunSnapBaseUrl: string;
    FRunSnapModel: string;
    FRunSnapTemperature: Double;
    FRunSnapMaxTokens: Integer;
    FRunSnapTimeoutMs: Integer;

    procedure SetState(ANewState: TAgentState);
    procedure AppendMessage(const AMsg: TChatMessage);
    procedure ApplySystemPrompt(AMode: TWorkspaceMode);
    function BuildSystemPrompt(AMode: TWorkspaceMode): string;
    function GetCancelRequested: Boolean;
    procedure CaptureClientSnapshot;
    procedure ApplyClientSnapshot;
    procedure SyncStateChange;
    procedure SyncMessageAdded;
    procedure SyncToolCall;
    procedure SyncToolResult;
    procedure SyncExecutionLogAdded;
    procedure NotifyExecutionLogAdded(AEntryIndex: Integer);
    procedure WaitForRunComplete;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    procedure ClearConversation;
    procedure LoadConversation(const AMessages: TChatMessageArray);
    procedure ExportMessages(out AMessages: TChatMessageArray);
    function StartRunAsync(const AUserPrompt: string; AMode: TWorkspaceMode;
      const AModel: string): Boolean;
    procedure RequestCancel;
    function IsRunActive: Boolean;
    procedure ExecuteRun(const AUserPrompt: string; AMode: TWorkspaceMode;
      const AModel: string);
    procedure RunThreadFinished;

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
    property OnExecutionLogAdded: TAgentExecutionLogEvent read FOnExecutionLogAdded
      write FOnExecutionLogAdded;
    property ExecutionLog: TAgentExecutionLog read FExecutionLog write FExecutionLog;
  end;

implementation

uses
  Forms, uAgentRunThread, uAgentToolBase;

function FinishReasonIndicatesTruncation(const AReason: string): Boolean;
var
  R: string;
begin
  R := LowerCase(Trim(AReason));
  Result := (R = 'length') or (R = 'max_tokens');
end;

function TruncationHintForFinishReason(const AReason: string): string;
begin
  if FinishReasonIndicatesTruncation(AReason) then
    Result := 'Response was truncated (finish_reason=' + Trim(AReason) + '). '
  else
    Result := '';
end;

constructor TAgentEngine.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  FState := asIdle;
  FMaxSteps := 20;
  FCancelRequested := False;
  FRunActive := False;
  FInWorkerRun := False;
  FDestroying := False;
  FRunThread := nil;
  FRunLock := TCriticalSection.Create;
  FDataLock := TCriticalSection.Create;

  FClient := TLlmClient.Create;
  FContext := TAgentToolContext.Create(AWorkspaceRoot);
  FContext.SetCancelFlag(@FCancelRequested);
  FContext.SetCancelDeadline(0);
  FTools := TAgentToolRegistry.Create(FContext);
  SetLength(FMessages, 0);
end;

destructor TAgentEngine.Destroy;
begin
  RequestCancel;
  WaitForRunComplete;
  if Assigned(Application) then
    Application.ProcessMessages;
  FDestroying := True;
  FTools.Free;
  FContext.Free;
  FClient.Free;
  FDataLock.Free;
  FRunLock.Free;
  inherited Destroy;
end;

function TAgentEngine.GetCancelRequested: Boolean;
begin
  FRunLock.Enter;
  try
    Result := FCancelRequested;
  finally
    FRunLock.Leave;
  end;
end;

procedure TAgentEngine.CaptureClientSnapshot;
begin
  FRunSnapProvider := FClient.Provider;
  FRunSnapApiKey := FClient.ApiKey;
  FRunSnapBaseUrl := FClient.BaseUrl;
  FRunSnapModel := FClient.Model;
  FRunSnapTemperature := FClient.Temperature;
  FRunSnapMaxTokens := FClient.MaxTokens;
  FRunSnapTimeoutMs := FClient.TimeoutMs;
end;

procedure TAgentEngine.ApplyClientSnapshot;
begin
  FClient.Provider := FRunSnapProvider;
  FClient.ApiKey := FRunSnapApiKey;
  FClient.BaseUrl := FRunSnapBaseUrl;
  FClient.Model := FRunSnapModel;
  FClient.Temperature := FRunSnapTemperature;
  FClient.MaxTokens := FRunSnapMaxTokens;
  FClient.TimeoutMs := FRunSnapTimeoutMs;
end;

procedure TAgentEngine.SyncStateChange;
begin
  if FDestroying then Exit;
  if Assigned(FOnStateChange) then
    FOnStateChange(Self, FSyncOldState, FSyncNewState);
end;

procedure TAgentEngine.SyncMessageAdded;
begin
  if FDestroying then Exit;
  if Assigned(FOnMessageAdded) then
    FOnMessageAdded(Self, FSyncMessage);
end;

procedure TAgentEngine.SyncToolCall;
begin
  if FDestroying then Exit;
  if Assigned(FOnToolCall) then
    FOnToolCall(Self, FSyncToolName, FSyncToolArgs);
end;

procedure TAgentEngine.SyncToolResult;
begin
  if FDestroying then Exit;
  if Assigned(FOnToolResult) then
    FOnToolResult(Self, FSyncToolName, FSyncToolArgs, FSyncToolResult);
end;

procedure TAgentEngine.SyncExecutionLogAdded;
begin
  if FDestroying then Exit;
  if Assigned(FOnExecutionLogAdded) then
    FOnExecutionLogAdded(Self, FSyncLogEntryIndex);
end;

procedure TAgentEngine.NotifyExecutionLogAdded(AEntryIndex: Integer);
begin
  if FInWorkerRun then begin
    FSyncLogEntryIndex := AEntryIndex;
    TThread.Queue(nil, @SyncExecutionLogAdded);
  end else if Assigned(FOnExecutionLogAdded) then
    FOnExecutionLogAdded(Self, AEntryIndex);
end;

procedure TAgentEngine.SetState(ANewState: TAgentState);
var
  Old: TAgentState;
begin
  FDataLock.Enter;
  try
    if FState = ANewState then Exit;
    Old := FState;
    FState := ANewState;
  finally
    FDataLock.Leave;
  end;

  if FInWorkerRun then begin
    FSyncOldState := Old;
    FSyncNewState := ANewState;
    TThread.Queue(nil, @SyncStateChange);
  end else if Assigned(FOnStateChange) then
    FOnStateChange(Self, Old, ANewState);
end;

procedure TAgentEngine.AppendMessage(const AMsg: TChatMessage);
var
  Idx: Integer;
begin
  FDataLock.Enter;
  try
    Idx := Length(FMessages);
    SetLength(FMessages, Idx + 1);
    FMessages[Idx] := AMsg;
  finally
    FDataLock.Leave;
  end;

  if FInWorkerRun then begin
    FSyncMessage := AMsg;
    TThread.Queue(nil, @SyncMessageAdded);
  end else if Assigned(FOnMessageAdded) then
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
    'Tool results are JSON objects. Read error and error_kind fields to recover from failures.' + LineEnding +
    'For todo replace, pass {"action":"replace","items":[{"id":"1","text":"...","status":"pending"}]} (status: pending, in_progress, or completed).';

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
  FDataLock.Enter;
  try
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
  finally
    FDataLock.Leave;
  end;
end;

function TAgentEngine.ExecuteToolDirect(const AName, AArgumentsJson: string;
  AMode: TWorkspaceMode): TToolExecutionResult;
begin
  if IsRunActive then begin
    Result.Success := False;
    Result.Output := '{"error":"Agent run in progress"}';
    Result.Summary := 'busy';
    Exit;
  end;
  Result := FTools.ExecuteTool(AName, AArgumentsJson, AMode);
end;

procedure TAgentEngine.ClearConversation;
begin
  RequestCancel;
  WaitForRunComplete;
  FDataLock.Enter;
  try
    SetLength(FMessages, 0);
  finally
    FDataLock.Leave;
  end;
  FContext.ClearSession;
  if Assigned(FExecutionLog) then
    FExecutionLog.Clear;
  SetState(asIdle);
end;

procedure TAgentEngine.LoadConversation(const AMessages: TChatMessageArray);
var
  I: Integer;
begin
  RequestCancel;
  WaitForRunComplete;
  FDataLock.Enter;
  try
    SetLength(FMessages, Length(AMessages));
    for I := 0 to High(AMessages) do
      FMessages[I] := AMessages[I];
  finally
    FDataLock.Leave;
  end;
  FContext.ClearSession;
  SetState(asIdle);
end;

procedure TAgentEngine.ExportMessages(out AMessages: TChatMessageArray);
var
  I: Integer;
begin
  FDataLock.Enter;
  try
    SetLength(AMessages, Length(FMessages));
    for I := 0 to High(FMessages) do
      AMessages[I] := FMessages[I];
  finally
    FDataLock.Leave;
  end;
end;

procedure TAgentEngine.RequestCancel;
begin
  FRunLock.Enter;
  try
    FCancelRequested := True;
  finally
    FRunLock.Leave;
  end;
end;

function TAgentEngine.IsRunActive: Boolean;
begin
  FRunLock.Enter;
  try
    Result := FRunActive;
  finally
    FRunLock.Leave;
  end;
end;

procedure TAgentEngine.WaitForRunComplete;
var
  T: TThread;
begin
  T := FRunThread;
  if T = nil then Exit;
  if T = TThread.CurrentThread then Exit;
  T.WaitFor;
  FreeAndNil(FRunThread);
end;

procedure TAgentEngine.RunThreadFinished;
begin
  FRunLock.Enter;
  try
    FRunActive := False;
  finally
    FRunLock.Leave;
  end;
end;

function TAgentEngine.GetMessageCount: Integer;
begin
  FDataLock.Enter;
  try
    Result := Length(FMessages);
  finally
    FDataLock.Leave;
  end;
end;

function TAgentEngine.GetMessage(AIndex: Integer): TChatMessage;
begin
  FDataLock.Enter;
  try
    Result := FMessages[AIndex];
  finally
    FDataLock.Leave;
  end;
end;

function TAgentEngine.StartRunAsync(const AUserPrompt: string; AMode: TWorkspaceMode;
  const AModel: string): Boolean;
begin
  Result := False;
  if IsRunActive then Exit;

  WaitForRunComplete;

  FRunLock.Enter;
  try
    FCancelRequested := False;
    FRunActive := True;
  finally
    FRunLock.Leave;
  end;

  CaptureClientSnapshot;

  FRunThread := TAgentRunThread.Create(Self, AUserPrompt, AMode, AModel);
  TAgentRunThread(FRunThread).Start;
  Result := True;
end;

procedure TAgentEngine.ExecuteRun(
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
  MessagesCopy: array of TChatMessage;
  RequestContext: string;
begin
  FInWorkerRun := True;
  try
    ApplyClientSnapshot;
    if Trim(AModel) <> '' then
      FClient.Model := AModel;

    ApplySystemPrompt(AMode);

    UserMsg := StringToChatRole('user');
    UserMsg.Content := AUserPrompt;
    AppendMessage(UserMsg);

    StepCount := 0;
    FContext.Mode := AMode;
    ToolDefs := FTools.GetToolDefinitions(AMode);

    if Assigned(FExecutionLog) then begin
      FDataLock.Enter;
      try
        MessagesCopy := FMessages;
      finally
        FDataLock.Leave;
      end;
      NotifyExecutionLogAdded(FExecutionLog.AddUserPrompt(AUserPrompt,
        FormatMessagesForDisplay(MessagesCopy, ToolDefs)));
    end;

    while (StepCount < FMaxSteps) and not GetCancelRequested do begin
      Inc(StepCount);
      SetState(asThinking);

      FDataLock.Enter;
      try
        MessagesCopy := FMessages;
      finally
        FDataLock.Leave;
      end;

      RequestContext := FormatMessagesForDisplay(MessagesCopy, ToolDefs);

      Resp := FClient.SendChatCompletion(MessagesCopy, ToolDefs);

      if GetCancelRequested then begin
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

      AssistantMsg := StringToChatRole('assistant');
      AssistantMsg.Content := Resp.Content;
      AssistantMsg.ToolCalls := Resp.ToolCalls;
      AssistantMsg.TokensUsed := Resp.TotalTokens;
      AppendMessage(AssistantMsg);

      if Assigned(FExecutionLog) then
        NotifyExecutionLogAdded(FExecutionLog.AddAssistant(Resp.Content, RequestContext,
          Length(Resp.ToolCalls)));

      if Length(Resp.ToolCalls) = 0 then begin
        SetState(asFinished);
        Exit;
      end;

      HadToolCalls := False;
      SetState(asExecutingTool);
      for I := Low(Resp.ToolCalls) to High(Resp.ToolCalls) do begin
        if GetCancelRequested then Break;

        HadToolCalls := True;
        FSyncToolName := Resp.ToolCalls[I].Name;
        FSyncToolArgs := Resp.ToolCalls[I].ArgumentsJson;
        TThread.Queue(nil, @SyncToolCall);

        if not JsonToolArgumentsWellFormed(Resp.ToolCalls[I].ArgumentsJson) then
          ToolResult := ToolResultFromJson(ToolError(
            'Tool call "' + Resp.ToolCalls[I].Name +
            '" has invalid or truncated JSON arguments (' +
            IntToStr(Length(Resp.ToolCalls[I].ArgumentsJson)) + ' bytes). ' +
            TruncationHintForFinishReason(Resp.FinishReason) +
            'Retry with smaller writes or increase max tokens in Settings.'))
        else
          ToolResult := FTools.ExecuteTool(Resp.ToolCalls[I].Name,
            Resp.ToolCalls[I].ArgumentsJson, AMode);

        FSyncToolName := Resp.ToolCalls[I].Name;
        FSyncToolResult := ToolResult;
        TThread.Queue(nil, @SyncToolResult);

        if Assigned(FExecutionLog) then
          NotifyExecutionLogAdded(FExecutionLog.AddTool(Resp.ToolCalls[I].Name,
            Resp.ToolCalls[I].ArgumentsJson, ToolResult.Output, ToolResult.Summary,
            ToolResult.Success));

        ToolMsg := StringToChatRole('tool');
        ToolMsg.ToolCallId := Resp.ToolCalls[I].Id;
        ToolMsg.Content := ToolResult.Output;
        ToolMsg.VisualSummary := ToolResult.Summary;
        AppendMessage(ToolMsg);
      end;

      if not HadToolCalls or GetCancelRequested then Break;
    end;

    if GetCancelRequested then
      SetState(asIdle)
    else
      SetState(asFinished);
  finally
    FInWorkerRun := False;
  end;
end;

end.
