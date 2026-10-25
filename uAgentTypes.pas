unit uAgentTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

const
  DEFAULT_MAX_OUTPUT_TOKENS = 16384;
  MIN_MAX_OUTPUT_TOKENS = 256;
  MAX_MAX_OUTPUT_TOKENS = 200000;
  RECOMMENDED_MIN_OUTPUT_TOKENS = 2048;
  DEFAULT_CONTEXT_WINDOW_TOKENS = 128000;
  DEFAULT_SUMMARIZE_THRESHOLD = 0.85;
  CONTEXT_RESERVE_OVERHEAD = 4096;
  SUMMARIZE_MAX_OUTPUT_TOKENS = 2048;
  MAX_TRUNCATION_RETRIES = 2;
  MAX_SUMMARIZE_ATTEMPTS_PER_RUN = 2;
  CONTEXT_KEEP_RECENT_MESSAGES = 6;
  TRUNCATION_RETRY_CAP_TOKENS = 16384;

type
  { Role in a conversation }
  TChatRole = (crSystem, crUser, crAssistant, crTool);

  { Agent Loop Execution Status }
  TAgentState = (
    asIdle,
    asThinking,
    asExecutingTool,
    asAwaitingConfirmation,
    asFinished,
    asError
  );

  { LLM Provider Target }
  TLlmProvider = (
    lpOpenRouter,
    lpOpenAI,
    lpAnthropic,
    lpOllama,
    lpNousResearch,
    lpCustom
  );

  { Single Tool Parameter Definition }
  TToolParamDef = record
    Name: string;
    ParamType: string; // 'string', 'integer', 'boolean', 'array', 'object'
    Description: string;
    Required: Boolean;
    EnumValues: array of string;
  end;

  { Tool Schema Definition }
  TToolDef = record
    Name: string;
    Description: string;
    Params: array of TToolParamDef;
  end;
  TToolDefArray = array of TToolDef;

  { Invocable Tool Call received from LLM }
  TToolCall = record
    Id: string;
    Name: string;
    ArgumentsJson: string;
  end;
  TToolCallArray = array of TToolCall;

  TChatAttachmentKind = (cakImage);

  TChatAttachment = record
    Kind: TChatAttachmentKind;
    RelativePath: string;
    MimeType: string;
    OriginalName: string;
    Width: Integer;
    Height: Integer;
  end;
  TChatAttachmentArray = array of TChatAttachment;

  { Chat Message data struct }
  TChatMessage = record
    Role: TChatRole;
    Content: string;
    ToolCallId: string; // for tool response messages
    ToolCalls: TToolCallArray;
    Attachments: TChatAttachmentArray;
    Timestamp: TDateTime;
    TokensUsed: Integer;
    VisualSummary: string; // Summary banner for tool outputs in UI
  end;
  TChatMessageArray = array of TChatMessage;

  { Task / Checklist Item }
  TTaskItem = record
    Id: string;
    Text: string;
    Status: string; // 'pending', 'in_progress', 'completed'
  end;

  { Helper Conversion Functions }
  function ChatRoleToString(ARole: TChatRole): string;
  function StringToChatRole(const ARole: string): TChatMessage;
  function LlmProviderToString(AProv: TLlmProvider): string;
  function StringToLlmProvider(const S: string): TLlmProvider;
  function AgentStateToString(AState: TAgentState): string;
  function FormatAgentStateLabel(AState: TAgentState; AStep, AMaxSteps: Integer): string;
  function ChatAttachmentKindToString(AKind: TChatAttachmentKind): string;
  function StringToChatAttachmentKind(const S: string): TChatAttachmentKind;

implementation

function ChatRoleToString(ARole: TChatRole): string;
begin
  case ARole of
    crSystem: Result := 'system';
    crUser: Result := 'user';
    crAssistant: Result := 'assistant';
    crTool: Result := 'tool';
  end;
end;

function StringToChatRole(const ARole: string): TChatMessage;
begin
  Result.Content := '';
  Result.ToolCallId := '';
  SetLength(Result.ToolCalls, 0);
  SetLength(Result.Attachments, 0);
  Result.Timestamp := Now;
  Result.TokensUsed := 0;
  Result.VisualSummary := '';

  if SameText(ARole, 'system') then
    Result.Role := crSystem
  else if SameText(ARole, 'assistant') then
    Result.Role := crAssistant
  else if SameText(ARole, 'tool') then
    Result.Role := crTool
  else
    Result.Role := crUser;
end;

function LlmProviderToString(AProv: TLlmProvider): string;
begin
  case AProv of
    lpOpenRouter: Result := 'OpenRouter';
    lpOpenAI: Result := 'OpenAI';
    lpAnthropic: Result := 'Anthropic';
    lpOllama: Result := 'Ollama';
    lpNousResearch: Result := 'Nous Research';
    lpCustom: Result := 'Custom / OpenAI Compatible';
  end;
end;

function StringToLlmProvider(const S: string): TLlmProvider;
begin
  if SameText(S, 'OpenRouter') then Result := lpOpenRouter
  else if SameText(S, 'OpenAI') then Result := lpOpenAI
  else if SameText(S, 'Anthropic') then Result := lpAnthropic
  else if SameText(S, 'Ollama') then Result := lpOllama
  else if SameText(S, 'Nous Research') or SameText(S, 'Nous') then Result := lpNousResearch
  else Result := lpCustom;
end;

function AgentStateToString(AState: TAgentState): string;
begin
  case AState of
    asIdle: Result := 'Idle';
    asThinking: Result := 'Thinking...';
    asExecutingTool: Result := 'Executing Tool...';
    asAwaitingConfirmation: Result := 'Awaiting Permission';
    asFinished: Result := 'Completed';
    asError: Result := 'Error';
  end;
end;

function FormatAgentStateLabel(AState: TAgentState; AStep, AMaxSteps: Integer): string;
begin
  Result := AgentStateToString(AState);
  if (AMaxSteps > 0) and (AStep > 0) and (AState in [asThinking, asExecutingTool]) then
    Result := Result + Format(' (step %d/%d)', [AStep, AMaxSteps]);
end;

function ChatAttachmentKindToString(AKind: TChatAttachmentKind): string;
begin
  case AKind of
    cakImage: Result := 'image';
  end;
end;

function StringToChatAttachmentKind(const S: string): TChatAttachmentKind;
begin
  if SameText(S, 'image') then
    Result := cakImage
  else
    Result := cakImage;
end;

end.
