unit uLlmProviderCatalog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAgentTypes;

const
  LLM_PROVIDER_CATALOG_VERSION = 4;

function LlmProviderCatalogName(AProv: TLlmProvider): string;
function LlmProviderRegistrationUrl(AProv: TLlmProvider): string;
function LlmProviderIsCustom(AProv: TLlmProvider): Boolean;
function LlmProviderComboCaption(AProv: TLlmProvider; const ACustomDisplayName: string): string;
procedure PopulateLlmProviderCombo(AItems: TStrings; const ACustomDisplayName: string);

implementation

type
  TCatalogEntry = record
    Name: string;
    RegistrationUrl: string;
  end;

const
  CATALOG: array[TLlmProvider] of TCatalogEntry = (
    (Name: 'OpenAI'; RegistrationUrl: 'https://platform.openai.com'),
    (Name: 'Nous Research'; RegistrationUrl: 'https://portal.nousresearch.com'),
    (Name: 'OpenRouter'; RegistrationUrl: 'https://openrouter.ai'),
    (Name: 'Groq'; RegistrationUrl: 'https://console.groq.com'),
    (Name: 'Together AI'; RegistrationUrl: 'https://api.together.xyz'),
    (Name: 'Fireworks AI'; RegistrationUrl: 'https://fireworks.ai'),
    (Name: 'DeepSeek'; RegistrationUrl: 'https://platform.deepseek.com'),
    (Name: 'Google Gemini'; RegistrationUrl: 'https://aistudio.google.com'),
    (Name: 'xAI'; RegistrationUrl: 'https://console.x.ai'),
    (Name: 'Mistral AI'; RegistrationUrl: 'https://console.mistral.ai'),
    (Name: 'Cerebras'; RegistrationUrl: 'https://cloud.cerebras.ai'),
    (Name: 'Nebius AI'; RegistrationUrl: 'https://studio.nebius.ai'),
    (Name: 'Novita AI'; RegistrationUrl: 'https://novita.ai'),
    (Name: 'Hyperbolic'; RegistrationUrl: 'https://hyperbolic.xyz'),
    (Name: 'DeepInfra'; RegistrationUrl: 'https://deepinfra.com'),
    (Name: 'SambaNova'; RegistrationUrl: 'https://cloud.sambanova.ai'),
    (Name: 'Moonshot AI'; RegistrationUrl: 'https://platform.moonshot.cn'),
    (Name: 'Hugging Face'; RegistrationUrl: 'https://huggingface.co/settings/tokens'),
    (Name: 'Venice AI'; RegistrationUrl: 'https://venice.ai'),
    (Name: 'Lepton AI'; RegistrationUrl: 'https://dashboard.lepton.ai'),
    (Name: 'Perplexity'; RegistrationUrl: 'https://www.perplexity.ai/settings/api'),
    (Name: 'Anyscale'; RegistrationUrl: 'https://console.anyscale.com'),
    (Name: 'Custom'; RegistrationUrl: '')
  );

function LlmProviderCatalogName(AProv: TLlmProvider): string;
begin
  Result := CATALOG[AProv].Name;
end;

function LlmProviderRegistrationUrl(AProv: TLlmProvider): string;
begin
  Result := CATALOG[AProv].RegistrationUrl;
end;

function LlmProviderIsCustom(AProv: TLlmProvider): Boolean;
begin
  Result := AProv = lpCustom;
end;

function LlmProviderComboCaption(AProv: TLlmProvider; const ACustomDisplayName: string): string;
begin
  if LlmProviderIsCustom(AProv) and (Trim(ACustomDisplayName) <> '') then
    Result := 'Custom — ' + Trim(ACustomDisplayName)
  else
    Result := LlmProviderCatalogName(AProv);
end;

procedure PopulateLlmProviderCombo(AItems: TStrings; const ACustomDisplayName: string);
var
  P: TLlmProvider;
begin
  AItems.Clear;
  for P := Low(TLlmProvider) to High(TLlmProvider) do
    AItems.Add(LlmProviderComboCaption(P, ACustomDisplayName));
end;

end.
