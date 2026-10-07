unit uLlmClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets, fpjson, jsonparser, uAgentTypes;

type
  { Completion Response struct }
  TLlmResponse = record
    Success: Boolean;
    ErrorMessage: string;
    Content: string;
    ToolCalls: TToolCallArray;
    FinishReason: string;
    PromptTokens: Integer;
    CompletionTokens: Integer;
    TotalTokens: Integer;
  end;

  { Callback types for async LLM interactions }
  TLlmChunkCallback = procedure(Sender: TObject; const AChunk: string) of object;

  { TLlmClient - Handles REST API communication with OpenAI, OpenRouter, Anthropic, Ollama }
  TLlmClient = class
  private
    FProvider: TLlmProvider;
    FApiKey: string;
    FBaseUrl: string;
    FModel: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FTimeoutMs: Integer;
    function BuildOpenAiPayload(const AMessages: array of TChatMessage; const ATools: array of TToolDef): string;
    function ParseOpenAiResponse(const AJsonStr: string): TLlmResponse;
    function SendHttpPost(const AUrl, APayload: string; out AResponse: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function SendChatCompletion(
      const AMessages: array of TChatMessage;
      const ATools: array of TToolDef
    ): TLlmResponse;

    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Model: string read FModel write FModel;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;

implementation

constructor TLlmClient.Create;
begin
  inherited Create;
  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := 'https://openrouter.ai/api/v1';
  FModel := 'anthropic/claude-3.7-sonnet';
  FTemperature := 0.2;
  FMaxTokens := 4096;
  FTimeoutMs := 60000;
end;

destructor TLlmClient.Destroy;
begin
  inherited Destroy;
end;

function TLlmClient.BuildOpenAiPayload(
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef
): string;
var
  RootObj, MsgObj, ToolCallObj, FuncObj, ToolObj, PropsObj, PropDetail, ParamObj: TJSONObject;
  MsgArray, ToolCallsArray, ToolsArray, ReqArray: TJSONArray;
  I, J: Integer;
  Msg: TChatMessage;
begin
  RootObj := TJSONObject.Create;
  try
    RootObj.Add('model', FModel);
    RootObj.Add('temperature', FTemperature);
    if FMaxTokens > 0 then
      RootObj.Add('max_tokens', FMaxTokens);

    // Messages
    MsgArray := TJSONArray.Create;
    for I := Low(AMessages) to High(AMessages) do begin
      Msg := AMessages[I];
      MsgObj := TJSONObject.Create;
      MsgObj.Add('role', ChatRoleToString(Msg.Role));

      if Msg.Role = crTool then begin
        MsgObj.Add('tool_call_id', Msg.ToolCallId);
        MsgObj.Add('content', Msg.Content);
      end else begin
        MsgObj.Add('content', Msg.Content);
      end;

      // If assistant produced tool calls previously
      if (Msg.Role = crAssistant) and (Length(Msg.ToolCalls) > 0) then begin
        ToolCallsArray := TJSONArray.Create;
        for J := Low(Msg.ToolCalls) to High(Msg.ToolCalls) do begin
          ToolCallObj := TJSONObject.Create;
          ToolCallObj.Add('id', Msg.ToolCalls[J].Id);
          ToolCallObj.Add('type', 'function');
          FuncObj := TJSONObject.Create;
          FuncObj.Add('name', Msg.ToolCalls[J].Name);
          FuncObj.Add('arguments', Msg.ToolCalls[J].ArgumentsJson);
          ToolCallObj.Add('function', FuncObj);
          ToolCallsArray.Add(ToolCallObj);
        end;
        MsgObj.Add('tool_calls', ToolCallsArray);
      end;

      MsgArray.Add(MsgObj);
    end;
    RootObj.Add('messages', MsgArray);

    // Tools definition
    if Length(ATools) > 0 then begin
      ToolsArray := TJSONArray.Create;
      for I := Low(ATools) to High(ATools) do begin
        ToolObj := TJSONObject.Create;
        ToolObj.Add('type', 'function');

        FuncObj := TJSONObject.Create;
        FuncObj.Add('name', ATools[I].Name);
        FuncObj.Add('description', ATools[I].Description);

        ParamObj := TJSONObject.Create;
        ParamObj.Add('type', 'object');

        PropsObj := TJSONObject.Create;
        ReqArray := TJSONArray.Create;

        for J := Low(ATools[I].Params) to High(ATools[I].Params) do begin
          PropDetail := TJSONObject.Create;
          PropDetail.Add('type', ATools[I].Params[J].ParamType);
          PropDetail.Add('description', ATools[I].Params[J].Description);
          PropsObj.Add(ATools[I].Params[J].Name, PropDetail);

          if ATools[I].Params[J].Required then
            ReqArray.Add(ATools[I].Params[J].Name);
        end;

        ParamObj.Add('properties', PropsObj);
        ParamObj.Add('required', ReqArray);
        FuncObj.Add('parameters', ParamObj);
        ToolObj.Add('function', FuncObj);

        ToolsArray.Add(ToolObj);
      end;
      RootObj.Add('tools', ToolsArray);
    end;

    Result := RootObj.AsJSON;
  finally
    RootObj.Free;
  end;
end;

function TLlmClient.ParseOpenAiResponse(const AJsonStr: string): TLlmResponse;
var
  Data: TJSONData;
  RootObj, ChoiceObj, MsgObj, ToolCallObj, FuncObj, UsageObj: TJSONObject;
  ChoicesArray, ToolCallsArray: TJSONArray;
  I: Integer;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  Result.Content := '';
  SetLength(Result.ToolCalls, 0);
  Result.FinishReason := '';
  Result.PromptTokens := 0;
  Result.CompletionTokens := 0;
  Result.TotalTokens := 0;

  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from LLM endpoint.';
        Exit;
      end;

      RootObj := TJSONObject(Data);

      // Check for API errors
      if RootObj.IndexOfName('error') >= 0 then begin
        if RootObj.Types['error'] = jtObject then
          Result.ErrorMessage := RootObj.Objects['error'].Get('message', 'Unknown API Error')
        else
          Result.ErrorMessage := RootObj.Get('error', 'Unknown API Error');
        Exit;
      end;

      if RootObj.IndexOfName('choices') >= 0 then begin
        ChoicesArray := RootObj.Arrays['choices'];
        if ChoicesArray.Count > 0 then begin
          ChoiceObj := ChoicesArray.Objects[0];
          Result.FinishReason := ChoiceObj.Get('finish_reason', '');
          if ChoiceObj.IndexOfName('message') >= 0 then begin
            MsgObj := ChoiceObj.Objects['message'];
            Result.Content := MsgObj.Get('content', '');

            // Parse tool_calls if present
            if MsgObj.IndexOfName('tool_calls') >= 0 then begin
              ToolCallsArray := MsgObj.Arrays['tool_calls'];
              SetLength(Result.ToolCalls, ToolCallsArray.Count);
              for I := 0 to ToolCallsArray.Count - 1 do begin
                ToolCallObj := ToolCallsArray.Objects[I];
                Result.ToolCalls[I].Id := ToolCallObj.Get('id', Format('call_%d', [I]));
                if ToolCallObj.IndexOfName('function') >= 0 then begin
                  FuncObj := ToolCallObj.Objects['function'];
                  Result.ToolCalls[I].Name := FuncObj.Get('name', '');
                  Result.ToolCalls[I].ArgumentsJson := FuncObj.Get('arguments', '{}');
                end;
              end;
            end;
          end;
        end;
      end;

      if RootObj.IndexOfName('usage') >= 0 then begin
        UsageObj := RootObj.Objects['usage'];
        Result.PromptTokens := UsageObj.Get('prompt_tokens', 0);
        Result.CompletionTokens := UsageObj.Get('completion_tokens', 0);
        Result.TotalTokens := UsageObj.Get('total_tokens', 0);
      end;

      Result.Success := True;
    finally
      Data.Free;
    end;
  except
    on E: Exception do begin
      Result.ErrorMessage := 'JSON Parse Error: ' + E.Message;
      Result.Success := False;
    end;
  end;
end;

function TLlmClient.SendHttpPost(const AUrl, APayload: string; out AResponse: string): Boolean;
var
  Client: TFPHTTPClient;
  ReqStream, RespStream: TStringStream;
begin
  Result := False;
  AResponse := '';

  Client := TFPHTTPClient.Create(nil);
  ReqStream := TStringStream.Create(APayload, TEncoding.UTF8);
  RespStream := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      Client.AddHeader('Content-Type', 'application/json');
      if Trim(FApiKey) <> '' then begin
        if FProvider = lpAnthropic then
          Client.AddHeader('x-api-key', FApiKey)
        else
          Client.AddHeader('Authorization', 'Bearer ' + Trim(FApiKey));
      end;

      // OpenRouter specifics
      if FProvider = lpOpenRouter then begin
        Client.AddHeader('HTTP-Referer', 'https://github.com/lazycodingagent');
        Client.AddHeader('X-Title', 'LazyCodingAgent');
      end;

      Client.IOTimeout := FTimeoutMs div 1000;
      Client.RequestBody := ReqStream;
      Client.Post(AUrl, RespStream);

      AResponse := RespStream.DataString;
      Result := (Client.ResponseStatusCode >= 200) and (Client.ResponseStatusCode < 300);
      if not Result then begin
        if Trim(AResponse) = '' then
          AResponse := Format('HTTP Error %d: %s', [Client.ResponseStatusCode, Client.ResponseStatusText]);
      end;
    except
      on E: Exception do begin
        AResponse := 'Connection Exception: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    RespStream.Free;
    ReqStream.Free;
    Client.Free;
  end;
end;

function TLlmClient.SendChatCompletion(
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef
): TLlmResponse;
var
  Url, Payload, RespStr: string;
begin
  Url := Trim(FBaseUrl);
  if Url = '' then begin
    case FProvider of
      lpOpenRouter: Url := 'https://openrouter.ai/api/v1/chat/completions';
      lpOpenAI: Url := 'https://api.openai.com/v1/chat/completions';
      lpOllama: Url := 'http://localhost:11434/v1/chat/completions';
      else Url := 'https://openrouter.ai/api/v1/chat/completions';
    end;
  end else begin
    if not (Copy(Url, Length(Url) - 15, 16) = '/chat/completions') then begin
      if Url[Length(Url)] = '/' then
        Url := Url + 'chat/completions'
      else
        Url := Url + '/chat/completions';
    end;
  end;

  Payload := BuildOpenAiPayload(AMessages, ATools);
  if SendHttpPost(Url, Payload, RespStr) then begin
    Result := ParseOpenAiResponse(RespStr);
  end else begin
    // Try to parse error JSON if available
    Result := ParseOpenAiResponse(RespStr);
    if Result.ErrorMessage = '' then
      Result.ErrorMessage := RespStr;
    Result.Success := False;
  end;
end;

end.
