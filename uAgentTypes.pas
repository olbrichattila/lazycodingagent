unit uAgentTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

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

  { Chat Message data struct }
  TChatMessage = record
    Role: TChatRole;
    Content: string;
    ToolCallId: string; // for tool response messages
    ToolCalls: TToolCallArray;
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

end.
