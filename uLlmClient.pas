unit uLlmClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uAgentTypes;

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

  TLlmModelInfo = record
    Id: string;
    DisplayName: string;
  end;

  TLlmModelListResult = record
    Success: Boolean;
    ErrorMessage: string;
    Models: array of TLlmModelInfo;
  end;

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
    function ParseModelsResponse(const AJsonStr: string): TLlmModelListResult;
    function BuildRequestHeaders(AIncludeJsonContentType: Boolean): TStringList;
    function ModelsListUrl: string;
    function SendHttpPost(const AUrl, APayload: string; out AResponse: string): Boolean;
    function SendHttpGet(const AUrl: string; out AResponse: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function SendChatCompletion(
      const AMessages: array of TChatMessage;
      const ATools: array of TToolDef
    ): TLlmResponse;

    function ListModels: TLlmModelListResult;

    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Model: string read FModel write FModel;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;

implementation

uses
  uAgentToolBase, uChatImageStore, uSslRuntime
  {$IFNDEF MSWINDOWS}
  , fphttpclient, opensslsockets
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  , uWindowsHTTP
  {$ENDIF}
  ;

procedure AddUserContentToMessageObject(AMsgObj: TJSONObject; const AMsg: TChatMessage);
var
  Parts: TJSONArray;
  TextPart, ImgPart, ImgUrlObj: TJSONObject;
  K: Integer;
  DataUrl, Err: string;
begin
  if (AMsg.Role <> crUser) or (Length(AMsg.Attachments) = 0) then begin
    AMsgObj.Add('content', AMsg.Content);
    Exit;
  end;

  Parts := TJSONArray.Create;
  TextPart := TJSONObject.Create;
  TextPart.Add('type', 'text');
  TextPart.Add('text', UserMessageTextForPayload(AMsg.Content, True));
  Parts.Add(TextPart);
  for K := Low(AMsg.Attachments) to High(AMsg.Attachments) do begin
    Err := LoadAttachmentAsDataUrl(AMsg.Attachments[K].RelativePath, DataUrl);
    if Err <> '' then
      raise Exception.Create(Err);
    ImgPart := TJSONObject.Create;
    ImgPart.Add('type', 'image_url');
    ImgUrlObj := TJSONObject.Create;
    ImgUrlObj.Add('url', DataUrl);
    ImgUrlObj.Add('detail', 'auto');
    ImgPart.Add('image_url', ImgUrlObj);
    Parts.Add(ImgPart);
  end;
  AMsgObj.Add('content', Parts);
end;

function ExtractFunctionArgumentsJson(AFuncObj: TJSONObject): string;
var
  Node: TJSONData;
begin
  Result := '{}';
  if not Assigned(AFuncObj) then Exit;
  Node := AFuncObj.Find('arguments');
  if Node = nil then Exit;
  case Node.JSONType of
    jtString: Result := Node.AsString;
    jtObject, jtArray: Result := Node.AsJSON;
  else
    Result := '{}';
  end;
end;

function SanitizeToolArgumentsForPayload(const AArgumentsJson: string): string;
begin
  if ToolArgumentsJsonIsValid(AArgumentsJson) then
    Result := AArgumentsJson
  else
    Result := '{"_parse_error":"invalid stored tool arguments"}';
end;

function HttpFailureMessage(AStatusCode: Integer; const AStatusText: string): string;
begin
  if AStatusCode = 0 then
    Result := 'No HTTP response (timed out or connection closed before headers).'
  else if Trim(AStatusText) = '' then
    Result := Format('HTTP Error %d', [AStatusCode])
  else
    Result := Format('HTTP Error %d: %s', [AStatusCode, AStatusText]);
end;

function HttpConnectionErrorMessage(const E: Exception): string;
begin
  if E is EInOutError then begin
    Result := 'HTTPS requires OpenSSL. ' + E.Message;
    if (Pos('OpenSSL', E.Message) > 0) or (Pos('initialize', LowerCase(E.Message)) > 0) then
      Result := Result + ' ' + OpenSslUnavailableUserMessage;
    Exit;
  end;
  {$IFNDEF MSWINDOWS}
  if E is EHTTPClient then begin
    Result := 'HTTP Error: ' + E.Message;
    Exit;
  end;
  {$ENDIF}
  Result := 'Connection Exception: ' + E.Message;
end;

{$IFNDEF MSWINDOWS}
procedure ConfigureHttpClientTimeouts(AClient: TFPHTTPClient; ATimeoutMs: Integer);
begin
  AClient.IOTimeout := ATimeoutMs;
  if ATimeoutMs < 30000 then
    AClient.ConnectTimeout := ATimeoutMs
  else
    AClient.ConnectTimeout := 30000;
end;

procedure ApplyHeadersToHttpClient(AClient: TFPHTTPClient; AHeaders: TStrings);
var
  I, P: Integer;
  Line, N, V: string;
begin
  for I := 0 to AHeaders.Count - 1 do begin
    Line := AHeaders[I];
    P := Pos(':', Line);
    if P > 0 then begin
      N := Trim(Copy(Line, 1, P - 1));
      V := Trim(Copy(Line, P + 1, MaxInt));
      AClient.AddHeader(N, V);
    end;
  end;
end;
{$ENDIF}

constructor TLlmClient.Create;
begin
  inherited Create;
  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := 'https://openrouter.ai/api/v1';
  FModel := 'anthropic/claude-3.7-sonnet';
  FTemperature := 0.2;
  FMaxTokens := DEFAULT_MAX_OUTPUT_TOKENS;
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
  RootObj, MsgObj, ToolCallObj, FuncObj, ToolObj, ParamObj: TJSONObject;
  MsgArray, ToolCallsArray, ToolsArray: TJSONArray;
  ParamData: TJSONData;
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
      end else if Msg.Role = crUser then
        AddUserContentToMessageObject(MsgObj, Msg)
      else
        MsgObj.Add('content', Msg.Content);

      // If assistant produced tool calls previously
      if (Msg.Role = crAssistant) and (Length(Msg.ToolCalls) > 0) then begin
        ToolCallsArray := TJSONArray.Create;
        for J := Low(Msg.ToolCalls) to High(Msg.ToolCalls) do begin
          ToolCallObj := TJSONObject.Create;
          ToolCallObj.Add('id', Msg.ToolCalls[J].Id);
          ToolCallObj.Add('type', 'function');
          FuncObj := TJSONObject.Create;
          FuncObj.Add('name', Msg.ToolCalls[J].Name);
          FuncObj.Add('arguments', SanitizeToolArgumentsForPayload(Msg.ToolCalls[J].ArgumentsJson));
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

        ParamData := GetJSON(ToolDefToParametersJson(ATools[I]));
        if ParamData is TJSONObject then
          FuncObj.Add('parameters', TJSONObject(ParamData))
        else begin
          ParamData.Free;
          ParamObj := TJSONObject.Create;
          ParamObj.Add('type', 'object');
          ParamObj.Add('properties', TJSONObject.Create);
          ParamObj.Add('required', TJSONArray.Create);
          FuncObj.Add('parameters', ParamObj);
        end;
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
                  Result.ToolCalls[I].ArgumentsJson := ExtractFunctionArgumentsJson(FuncObj);
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

function TLlmClient.BuildRequestHeaders(AIncludeJsonContentType: Boolean): TStringList;
begin
  Result := TStringList.Create;
  if AIncludeJsonContentType then
    Result.Add('Content-Type: application/json');
  Result.Add('Accept: application/json');
  Result.Add('User-Agent: LazyCodingAgent/1.0');
  if Trim(FApiKey) <> '' then begin
    if FProvider = lpAnthropic then begin
      Result.Add('x-api-key: ' + Trim(FApiKey));
      Result.Add('anthropic-version: 2023-06-01');
    end else
      Result.Add('Authorization: Bearer ' + Trim(FApiKey));
  end;
  if FProvider = lpOpenRouter then begin
    Result.Add('HTTP-Referer: https://github.com/lazycodingagent');
    Result.Add('X-Title: LazyCodingAgent');
  end;
end;

function TLlmClient.ModelsListUrl: string;
var
  Url: string;
begin
  Url := Trim(FBaseUrl);
  if Url = '' then begin
    case FProvider of
      lpOpenRouter: Url := 'https://openrouter.ai/api/v1';
      lpOpenAI: Url := 'https://api.openai.com/v1';
      lpAnthropic: Url := 'https://api.anthropic.com/v1';
      lpOllama: Url := 'http://localhost:11434/v1';
      lpNousResearch: Url := 'https://inference-api.nousresearch.com/v1';
      else Url := 'https://openrouter.ai/api/v1';
    end;
  end;
  if (Length(Url) >= 7) and SameText(Copy(Url, Length(Url) - 6, 7), '/models') then
    Result := Url
  else if Url[Length(Url)] = '/' then
    Result := Url + 'models'
  else
    Result := Url + '/models';
end;

function TLlmClient.ParseModelsResponse(const AJsonStr: string): TLlmModelListResult;
var
  Data: TJSONData;
  RootObj, ItemObj: TJSONObject;
  DataArray: TJSONArray;
  I, N: Integer;
  Id, Name: string;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.Models, 0);

  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from models endpoint.';
        Exit;
      end;

      RootObj := TJSONObject(Data);

      if RootObj.IndexOfName('error') >= 0 then begin
        if RootObj.Types['error'] = jtObject then
          Result.ErrorMessage := RootObj.Objects['error'].Get('message', 'Unknown API Error')
        else
          Result.ErrorMessage := RootObj.Get('error', 'Unknown API Error');
        Exit;
      end;

      if RootObj.IndexOfName('data') >= 0 then
        DataArray := RootObj.Arrays['data']
      else if RootObj.IndexOfName('models') >= 0 then
        DataArray := RootObj.Arrays['models']
      else begin
        Result.ErrorMessage := 'Models list not found in response.';
        Exit;
      end;

      N := DataArray.Count;
      SetLength(Result.Models, N);
      for I := 0 to N - 1 do begin
        if not (DataArray.Items[I] is TJSONObject) then Continue;
        ItemObj := TJSONObject(DataArray.Items[I]);
        Id := ItemObj.Get('id', '');
        if Id = '' then
          Id := ItemObj.Get('name', '');
        Name := ItemObj.Get('display_name', '');
        if Name = '' then
          Name := ItemObj.Get('name', '');
        if (Name = '') or SameText(Name, Id) then
          Name := Id;
        Result.Models[I].Id := Id;
        Result.Models[I].DisplayName := Name;
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

function TLlmClient.SendHttpGet(const AUrl: string; out AResponse: string): Boolean;
var
  {$IFNDEF MSWINDOWS}
  Client: TFPHTTPClient;
  {$ENDIF}
  Headers: TStringList;
  RespStream: TStringStream;
  StatusCode: Integer;
begin
  Result := False;
  AResponse := '';
  Headers := BuildRequestHeaders(False);
  RespStream := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      {$IFDEF MSWINDOWS}
      StatusCode := 0;
      WindowsHTTPRequest('GET', AUrl, Headers, '', RespStream, StatusCode);
      AResponse := RespStream.DataString;
      Result := (StatusCode >= 200) and (StatusCode < 300);
      if not Result then begin
        if Trim(AResponse) = '' then
          AResponse := HttpFailureMessage(StatusCode, '');
      end;
      {$ELSE}
      if not EnsureOpenSslAvailable then begin
        AResponse := OpenSslUnavailableUserMessage;
        Exit;
      end;
      Client := TFPHTTPClient.Create(nil);
      try
        ApplyHeadersToHttpClient(Client, Headers);
        ConfigureHttpClientTimeouts(Client, FTimeoutMs);
        Client.AllowRedirect := True;
        Client.MaxRedirects := 5;
        Client.Get(AUrl, RespStream);
        AResponse := RespStream.DataString;
        Result := (Client.ResponseStatusCode >= 200) and (Client.ResponseStatusCode < 300);
        if not Result then begin
          if Trim(AResponse) = '' then
            AResponse := HttpFailureMessage(Client.ResponseStatusCode, Client.ResponseStatusText);
        end;
      finally
        Client.Free;
      end;
      {$ENDIF}
    except
      on E: Exception do begin
        AResponse := HttpConnectionErrorMessage(E);
        Result := False;
      end;
    end;
  finally
    RespStream.Free;
    Headers.Free;
  end;
end;

function TLlmClient.SendHttpPost(const AUrl, APayload: string; out AResponse: string): Boolean;
var
  {$IFNDEF MSWINDOWS}
  Client: TFPHTTPClient;
  ReqStream: TStringStream;
  {$ENDIF}
  Headers: TStringList;
  RespStream: TStringStream;
  StatusCode: Integer;
  Body: RawByteString;
begin
  Result := False;
  AResponse := '';
  Headers := BuildRequestHeaders(True);
  RespStream := TStringStream.Create('', TEncoding.UTF8);
  Body := RawByteString(APayload);
  try
    try
      {$IFDEF MSWINDOWS}
      StatusCode := 0;
      WindowsHTTPRequest('POST', AUrl, Headers, Body, RespStream, StatusCode);
      AResponse := RespStream.DataString;
      Result := (StatusCode >= 200) and (StatusCode < 300);
      if not Result then begin
        if Trim(AResponse) = '' then
          AResponse := HttpFailureMessage(StatusCode, '');
      end;
      {$ELSE}
      if not EnsureOpenSslAvailable then begin
        AResponse := OpenSslUnavailableUserMessage;
        Exit;
      end;
      Client := TFPHTTPClient.Create(nil);
      ReqStream := TStringStream.Create(APayload, TEncoding.UTF8);
      try
        ApplyHeadersToHttpClient(Client, Headers);
        ConfigureHttpClientTimeouts(Client, FTimeoutMs);
        Client.AllowRedirect := True;
        Client.MaxRedirects := 5;
        Client.RequestBody := ReqStream;
        Client.Post(AUrl, RespStream);
        AResponse := RespStream.DataString;
        Result := (Client.ResponseStatusCode >= 200) and (Client.ResponseStatusCode < 300);
        if not Result then begin
          if Trim(AResponse) = '' then
            AResponse := HttpFailureMessage(Client.ResponseStatusCode, Client.ResponseStatusText);
        end;
      finally
        ReqStream.Free;
        Client.Free;
      end;
      {$ENDIF}
    except
      on E: Exception do begin
        AResponse := HttpConnectionErrorMessage(E);
        Result := False;
      end;
    end;
  finally
    RespStream.Free;
    Headers.Free;
  end;
end;

function TLlmClient.ListModels: TLlmModelListResult;
var
  Url, RespStr: string;
begin
  Url := ModelsListUrl;
  if SendHttpGet(Url, RespStr) then
    Result := ParseModelsResponse(RespStr)
  else begin
    RespStr := Trim(RespStr);
    if (RespStr <> '') and ((RespStr[1] = '{') or (RespStr[1] = '[')) then begin
      Result := ParseModelsResponse(RespStr);
      if (not Result.Success) and (Result.ErrorMessage = '') then
        Result.ErrorMessage := RespStr;
    end else begin
      Result.Success := False;
      SetLength(Result.Models, 0);
      Result.ErrorMessage := RespStr;
    end;
    Result.Success := False;
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
      lpNousResearch: Url := 'https://inference-api.nousresearch.com/v1/chat/completions';
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
    RespStr := Trim(RespStr);
    if (RespStr <> '') and ((RespStr[1] = '{') or (RespStr[1] = '[')) then begin
      Result := ParseOpenAiResponse(RespStr);
      if Result.ErrorMessage = '' then
        Result.ErrorMessage := RespStr;
    end else begin
      FillChar(Result, SizeOf(Result), 0);
      Result.ErrorMessage := RespStr;
    end;
    Result.Success := False;
  end;
end;

end.
