unit uAgentExecutionLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uAppTypes, uAgentTypes;

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
    AssistantToolCalls: TToolCallArray;
    function BuildInspectorText: string;
    function BuildInspectorHtml(ATheme: TThemeKind): string;
    destructor Destroy; override;
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
      ASuccess: Boolean; AStep, AMaxSteps: Integer): Integer;
    function AddAssistant(const AContent, ALlmContext: string;
      const AToolCalls: TToolCallArray; AStep, AMaxSteps: Integer): Integer;
  end;

function PrettyJsonString(const S: string): string;
function TruncateLogCaption(const S: string; AMaxLen: Integer = 72): string;
function FormatMessagesForDisplay(const AMessages: array of TChatMessage;
  const ATools: array of TToolDef): string;
function FormatMessageBodyForLog(const AMsg: TChatMessage): string;

implementation

uses
  fpjson, jsonparser, uAgentToolBase, uExecutionDetailHtml, uChatImageStore;

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

procedure CopyToolCalls(const ASrc: TToolCallArray; var ADst: TToolCallArray);
var
  I: Integer;
begin
  SetLength(ADst, Length(ASrc));
  for I := Low(ASrc) to High(ASrc) do begin
    ADst[I].Id := ASrc[I].Id;
    ADst[I].Name := ASrc[I].Name;
    ADst[I].ArgumentsJson := ASrc[I].ArgumentsJson;
  end;
end;

function ToolCallNamesCaption(const AToolCalls: TToolCallArray): string;
var
  I: Integer;
  Names: TStringList;
begin
  Names := TStringList.Create;
  try
    Names.Duplicates := dupIgnore;
    for I := Low(AToolCalls) to High(AToolCalls) do
      if AToolCalls[I].Name <> '' then
        Names.Add(AToolCalls[I].Name);
    Result := Names.CommaText;
    Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  finally
    Names.Free;
  end;
end;

function FormatMessageBodyForLog(const AMsg: TChatMessage): string;
var
  I: Integer;
  Parts: TStringList;
  AttSummary: string;
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
    end else begin
      if Trim(AMsg.Content) <> '' then
        Parts.Add(AMsg.Content);
      if Length(AMsg.Attachments) > 0 then begin
        AttSummary := FormatAttachmentsSummary(AMsg.Attachments);
        if AttSummary <> '' then
          Parts.Add(AttSummary);
      end;
    end;
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

destructor TExecutionLogEntry.Destroy;
begin
  SetLength(AssistantToolCalls, 0);
  inherited Destroy;
end;

function TExecutionLogEntry.BuildInspectorText: string;
var
  SB: TStringBuilder;
  I: Integer;
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
          if Length(AssistantToolCalls) > 0 then begin
            SB.AppendLine('=== Tool calls ===');
            for I := Low(AssistantToolCalls) to High(AssistantToolCalls) do begin
              SB.AppendLine(Format('--- %s ---', [AssistantToolCalls[I].Name]));
              if AssistantToolCalls[I].Id <> '' then
                SB.AppendLine('id: ' + AssistantToolCalls[I].Id);
              SB.AppendLine(PrettyJsonString(AssistantToolCalls[I].ArgumentsJson));
              SB.AppendLine;
            end;
          end;
          SB.AppendLine('=== Model response ===');
          if Trim(UserOrResponseText) <> '' then
            SB.AppendLine(UserOrResponseText)
          else if Length(AssistantToolCalls) = 0 then
            SB.AppendLine('(empty)')
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
  SetLength(Result.AssistantToolCalls, 0);
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
  E.Caption := 'User: ' + TruncateLogCaption(AUserText);
  Result := FEntries.Count - 1;
end;

function StepCaptionPrefix(AStep, AMaxSteps: Integer): string;
begin
  if (AMaxSteps > 0) and (AStep > 0) then
    Result := Format('Step %d/%d · ', [AStep, AMaxSteps])
  else
    Result := '';
end;

function TAgentExecutionLog.AddTool(const AName, AArgsJson, AOutputJson, ASummary: string;
  ASuccess: Boolean; AStep, AMaxSteps: Integer): Integer;
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
  E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + AName + '(' + Cap + ')';
  Result := FEntries.Count - 1;
end;

function TAgentExecutionLog.AddAssistant(const AContent, ALlmContext: string;
  const AToolCalls: TToolCallArray; AStep, AMaxSteps: Integer): Integer;
var
  E: TExecutionLogEntry;
  Cap: string;
  ToolCount: Integer;
begin
  E := NewEntry;
  E.Kind := elAssistantResponse;
  E.UserOrResponseText := AContent;
  E.ContextText := ALlmContext;
  CopyToolCalls(AToolCalls, E.AssistantToolCalls);
  ToolCount := Length(AToolCalls);
  if ToolCount > 0 then begin
    Cap := TruncateLogCaption(AContent);
    if Cap = '' then
      Cap := TruncateLogCaption(ToolCallNamesCaption(AToolCalls), 48);
    E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + 'Model: ' + Cap +
      Format(' [%d tools]', [ToolCount]);
  end else begin
    Cap := TruncateLogCaption(AContent);
    E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + 'Model: ' + Cap;
  end;
  Result := FEntries.Count - 1;
end;

function TExecutionLogEntry.BuildInspectorHtml(ATheme: TThemeKind): string;
var
  SB: TStringBuilder;
  I: Integer;
  Body: string;
begin
  SB := TStringBuilder.Create;
  try
    case Kind of
      elUserPrompt:
        begin
          AppendHtmlSectionHeader(SB, 'User input');
          SB.Append(ProseTextToHtmlBlock(UserOrResponseText));
          AppendHtmlSectionHeader(SB, 'Full prompt sent to model');
          SB.Append(ProseTextToHtmlBlock(ContextText));
        end;
      elToolExecution:
        begin
          AppendHtmlSectionHeader(SB, 'Tool');
          SB.Append('<div class="tool-call"><span class="tool-name">');
          SB.Append(ExecDetailEscapeHtml(ToolName));
          SB.Append('</span>');
          if not ToolSuccess then
            AppendHtmlFailBadge(SB);
          SB.Append('</div>');
          AppendHtmlSectionHeader(SB, 'Input (arguments)');
          SB.Append(JsonTextToHtmlBlock(ToolArgsJson));
          AppendHtmlSectionHeader(SB, 'Output');
          SB.Append(JsonTextToHtmlBlock(ToolOutputJson));
        end;
      elAssistantResponse:
        begin
          if Length(AssistantToolCalls) > 0 then begin
            AppendHtmlSectionHeader(SB, 'Tool calls');
            for I := Low(AssistantToolCalls) to High(AssistantToolCalls) do begin
              AppendHtmlToolCallHeader(SB, AssistantToolCalls[I].Name);
              if AssistantToolCalls[I].Id <> '' then
                SB.Append('<p class="prose-empty">id: ' +
                  ExecDetailEscapeHtml(AssistantToolCalls[I].Id) + '</p>');
              SB.Append(JsonTextToHtmlBlock(AssistantToolCalls[I].ArgumentsJson));
            end;
          end;
          AppendHtmlSectionHeader(SB, 'Model response');
          if Trim(UserOrResponseText) <> '' then
            SB.Append(ProseTextToHtmlBlock(UserOrResponseText))
          else if Length(AssistantToolCalls) = 0 then
            SB.Append('<p class="prose-empty">(empty)</p>')
          else
            SB.Append('<p class="prose-empty">(empty content; tool calls only)</p>');
          AppendHtmlSectionHeader(SB, 'Request context');
          SB.Append(ProseTextToHtmlBlock(ContextText));
        end;
    end;
    Body := SB.ToString;
  finally
    SB.Free;
  end;
  Result := WrapExecDetailHtmlDocument(Body, ATheme);
end;

end.
