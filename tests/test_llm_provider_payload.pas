program test_llm_provider_payload;
{$mode objfpc}{$H+}
uses
  SysUtils, fpjson, uAgentTypes, uLlmPromptCacheTypes, uLlmRequestAnthropic,
  uLlmCacheCapabilities, uLlmProviderCatalog;

procedure TestAnthropicUrl;
begin
  if Pos('/messages', AnthropicMessagesUrl('https://api.anthropic.com/v1')) = 0 then
    raise Exception.Create('Anthropic URL must end with /messages');
end;

procedure TestExplicitBreakpointsOmittedWhenDisabled;
var
  Payload: string;
  Data: TJSONData;
  Root: TJSONObject;
  Settings: TPromptCacheSettings;
  Caps: TPromptCacheCapabilities;
  Segments: TPromptSegmentArray;
  Msg: TChatMessage;
begin
  Settings := DefaultPromptCacheSettings;
  Settings.Mode := pcmDisabled;
  Caps := DefaultPromptCacheCapabilities;
  Caps.SupportsExplicitCaching := True;
  SetLength(Segments, 0);
  Msg := StringToChatRole('user');
  Msg.Content := 'hi';
  Payload := BuildAnthropicMessagesPayload('claude-3-5-sonnet-20241022', 0.2, 1024,
    [Msg], [], Segments, Settings, Caps);
  Data := GetJSON(Payload);
  try
    if not (Data is TJSONObject) then
      raise Exception.Create('Payload must be object');
    Root := TJSONObject(Data);
    if Root.IndexOfName('system') >= 0 then begin
      if Pos('cache_control', Payload) > 0 then
        raise Exception.Create('Disabled mode must not emit cache_control');
    end;
  finally
    Data.Free;
  end;
end;

procedure TestWireFormatAnthropicDirect;
var
  Wire: TLlmWireFormat;
begin
  Wire := ResolveLlmWireFormat(lpCustom, 'https://api.anthropic.com/v1', 'claude-3-5-sonnet');
  if Wire <> lwfAnthropicMessages then
    raise Exception.Create('Direct Anthropic must use messages wire format');
  Wire := ResolveLlmWireFormat(lpOpenRouter, 'https://openrouter.ai/api/v1', 'anthropic/claude-3.5');
  if Wire <> lwfOpenAiChat then
    raise Exception.Create('OpenRouter must stay OpenAI-compatible');
end;

procedure TestMigrateLegacyProviderOrd;
var
  P: TLlmProvider;
  LabelStr: string;
begin
  if not MigrateLegacyProviderOrd(LEGACY_PROV_OPENROUTER, P, LabelStr) then
    raise Exception.Create('OpenRouter legacy ord must migrate');
  if P <> lpOpenRouter then
    raise Exception.Create('Legacy OpenRouter must map to lpOpenRouter');
  if not MigrateLegacyProviderOrd(LEGACY_PROV_ANTHROPIC, P, LabelStr) then
    raise Exception.Create('Anthropic legacy ord must migrate');
  if (P <> lpCustom) or (LabelStr <> 'Anthropic') then
    raise Exception.Create('Legacy Anthropic must map to Custom');
end;

begin
  TestAnthropicUrl;
  TestExplicitBreakpointsOmittedWhenDisabled;
  TestWireFormatAnthropicDirect;
  TestMigrateLegacyProviderOrd;
  WriteLn('LLM provider payload tests passed.');
end.
