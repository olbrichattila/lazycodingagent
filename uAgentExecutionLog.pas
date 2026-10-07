unit uAgentExecutionLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uAgentTypes;

type
  TExecutionLogKind = (elUserPrompt, elToolExecution, elAssistantResponse);

  TExecutionLogEntry = class
  public
    Kind: TExecutionLogKind;
    Timestamp: TDateTime;
    Caption: string;
    UserOrResponseText: string;
    ContextText: string;
    ToolName: string;
    ToolArgsJson: string;
    ToolOutputJson: string;
    ToolSuccess: Boolean;
    function BuildInspectorText: string;
  end;

  TAgentExecutionLog = class
  private
    FEntries: TObjectList;
    function NewEntry: TExecutionLogEntry;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    function Entry(AIndex: Integer): TExecutionLogEntry;
    function AddUserPrompt(const AUserText, AFullContext: string): Integer;
    function AddTool(const AName, AArgsJson, AOutputJson, ASummary: string;
      ASuccess: Boolean): Integer;
    function AddAssistant(const AContent, ALlmContext: string; AToolCallCount: Integer): Integer;
  end;

function PrettyJsonString(const S: string): string;
function TruncateLogCaption(const S: string; AMaxLen: Integer = 72): string;
function FormatMessagesForDisplay(const AMessages: array of TChatMessage;
  const ATools: array of TToolDef): string;

implementation

uses
  fpjson, jsonparser, uAgentToolBase;

function PrettyJsonString(const S: string): string;
var
  Data: TJSONObject;
  T: string;
begin
  T := Trim(S);
  if T = '' then Exit('');
  if not JsonToolArgumentsWellFormed(T) then
  begin
    Result := string(SafeToolText(T, 200));
    if Length(T) > Length(Result) then
      Result := Result + '…';
    Exit;
  end;
  if TryGetJSONObject(T, Data) then
  begin
    try
      Result := Data.FormatJSON;
    finally
      Data.Free;
    end;
  end
  else
    Result := T;
end;

function TruncateLogCaption(const S: string; AMaxLen: Integer): string;
var
  T: string;
begin
  T := Trim(StringReplace(S, LineEnding, ' ', [rfReplaceAll]));
  if Length(T) <= AMaxLen then
    Result := T
  else
    Result := Copy(T, 1, AMaxLen - 1) + '…';
end;

function FormatMessageBodyForLog(const AMsg: TChatMessage): string;
var
  I: Integer;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    if AMsg.Role = crTool then begin
      if AMsg.ToolCallId <> '' then
        Parts.Add('tool_call_id: ' + AMsg.ToolCallId);
      Parts.Add(PrettyJsonString(AMsg.Content));
    end else if (AMsg.Role = crAssistant) and (Length(AMsg.ToolCalls) > 0) then begin
      if Trim(AMsg.Content) <> '' then
        Parts.Add(AMsg.Content);
      for I := Low(AMsg.ToolCalls) to High(AMsg.ToolCalls) do
        Parts.Add(Format('tool_call: %s(%s)', [
          AMsg.ToolCalls[I].Name, PrettyJsonString(AMsg.ToolCalls[I].ArgumentsJson)]));
    end else
      Parts.Add(AMsg.Content);
    Result := Parts.Text;
  finally
    Parts.Free;
  end;
end;

function FormatMessagesForDisplay(const AMessages: array of TChatMessage;
  const ATools: array of TToolDef): string;
var
  I, J: Integer;
  SB: TStringBuilder;
  SysText: string;
begin
  SB := TStringBuilder.Create;
  try
    SysText := '';
    for I := Low(AMessages) to High(AMessages) do begin
      if AMessages[I].Role = crSystem then begin
        SysText := AMessages[I].Content;
        Break;
      end;
    end;

    SB.AppendLine('--- System ---');
    if SysText <> '' then
      SB.AppendLine(SysText)
    else
      SB.AppendLine('(none)');

    SB.AppendLine;
    SB.AppendLine('--- Conversation ---');
    for I := Low(AMessages) to High(AMessages) do begin
      if AMessages[I].Role = crSystem then Continue;
      SB.AppendLine('[' + ChatRoleToString(AMessages[I].Role) + ']');
      SB.AppendLine(FormatMessageBodyForLog(AMessages[I]));
      SB.AppendLine;
    end;

    SB.AppendLine('--- Tools available (this step) ---');
    if Length(ATools) = 0 then
      SB.AppendLine('(none)')
    else
      for J := Low(ATools) to High(ATools) do
        SB.AppendLine(Format('- %s: %s', [ATools[J].Name, ATools[J].Description]));

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TExecutionLogEntry.BuildInspectorText: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    case Kind of
      elUserPrompt:
        begin
          SB.AppendLine('=== User input ===');
          SB.AppendLine(UserOrResponseText);
          SB.AppendLine;
          SB.AppendLine('=== Full prompt sent to model ===');
          SB.AppendLine(ContextText);
        end;
      elToolExecution:
        begin
          SB.AppendLine('=== Tool ===');
          SB.AppendLine(ToolName);
          if not ToolSuccess then
            SB.AppendLine('(failed)');
          SB.AppendLine;
          SB.AppendLine('=== Input (arguments) ===');
          SB.AppendLine(PrettyJsonString(ToolArgsJson));
          SB.AppendLine;
          SB.AppendLine('=== Output ===');
          SB.AppendLine(PrettyJsonString(ToolOutputJson));
        end;
      elAssistantResponse:
        begin
          SB.AppendLine('=== Model response ===');
          if Trim(UserOrResponseText) <> '' then
            SB.AppendLine(UserOrResponseText)
          else
            SB.AppendLine('(empty content; tool calls only)');
          SB.AppendLine;
          SB.AppendLine('=== Request context ===');
          SB.AppendLine(ContextText);
        end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ TAgentExecutionLog }

constructor TAgentExecutionLog.Create;
begin
  inherited Create;
  FEntries := TObjectList.Create(True);
end;

destructor TAgentExecutionLog.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TAgentExecutionLog.Clear;
begin
  FEntries.Clear;
end;

function TAgentExecutionLog.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TAgentExecutionLog.Entry(AIndex: Integer): TExecutionLogEntry;
begin
  Result := TExecutionLogEntry(FEntries[AIndex]);
end;

function TAgentExecutionLog.NewEntry: TExecutionLogEntry;
begin
  Result := TExecutionLogEntry.Create;
  Result.Timestamp := Now;
  FEntries.Add(Result);
end;

function TAgentExecutionLog.AddUserPrompt(const AUserText, AFullContext: string): Integer;
var
  E: TExecutionLogEntry;
begin
  E := NewEntry;
  E.Kind := elUserPrompt;
  E.UserOrResponseText := AUserText;
  E.ContextText := AFullContext;
  E.Caption := '👤 User: ' + TruncateLogCaption(AUserText);
  Result := FEntries.Count - 1;
end;

function TAgentExecutionLog.AddTool(const AName, AArgsJson, AOutputJson, ASummary: string;
  ASuccess: Boolean): Integer;
var
  E: TExecutionLogEntry;
  Cap: string;
begin
  E := NewEntry;
  E.Kind := elToolExecution;
  E.ToolName := AName;
  E.ToolArgsJson := AArgsJson;
  E.ToolOutputJson := AOutputJson;
  E.ToolSuccess := ASuccess;
  if ASummary <> '' then
    Cap := ASummary
  else
    Cap := TruncateLogCaption(AArgsJson, 48);
  E.Caption := '🛠 ' + AName + '(' + Cap + ')';
  Result := FEntries.Count - 1;
end;

function TAgentExecutionLog.AddAssistant(const AContent, ALlmContext: string;
  AToolCallCount: Integer): Integer;
var
  E: TExecutionLogEntry;
  Cap: string;
begin
  E := NewEntry;
  E.Kind := elAssistantResponse;
  E.UserOrResponseText := AContent;
  E.ContextText := ALlmContext;
  if AToolCallCount > 0 then begin
    Cap := TruncateLogCaption(AContent);
    if Cap = '' then
      Cap := Format('%d tool call(s)', [AToolCallCount]);
    E.Caption := '🤖 Agent: ' + Cap + Format(' [%d tools]', [AToolCallCount]);
  end else begin
    Cap := TruncateLogCaption(AContent);
    E.Caption := '🤖 Agent: ' + Cap;
  end;
  Result := FEntries.Count - 1;
end;

end.
