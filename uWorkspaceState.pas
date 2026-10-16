unit uWorkspaceState;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Forms, uAppTypes, uAgentTypes;

type
  TPanelState = record
    Visible: Boolean;
    Floating: Boolean;
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    { Docked strip height (terminal bottom panel); 0 = use default at runtime. }
    DockedHeight: Integer;
  end;

  TSavedModel = record
    ModelId: string;
    DisplayName: string;
  end;

  TProviderCredentials = record
    ApiKey: string;
    BaseUrl: string;
  end;

  TWorkspaceState = class
  private
    FWorkspaceName: string;
    FWorkspaceRoot: string;
    FActiveWorkspaceId: string;
    FNavigation: TNavigationItem;
    FMode: TWorkspaceMode;
    FModel: string;
    FTheme: TThemeKind;

    FProvider: TLlmProvider;
    FApiKey: string;
    FBaseUrl: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FMaxSteps: Integer;
    FDebuggingMode: Boolean;
    FLearnMode: Boolean;
    FAutoSummarizeContext: Boolean;
    FContextWindowTokens: Integer;
    FSummarizeThreshold: Double;

    FProviderCreds: array[TLlmProvider] of TProviderCredentials;
    FProviderModels: array[TLlmProvider] of array of TSavedModel;

    FPanels: array[TPanelId] of TPanelState;
    FOnChange: TNotifyEvent;
    procedure Changed;
    procedure InitProviderDefaults;
    procedure ResetProviderStorage;
    procedure SyncActiveFromProviderSlot;
    procedure SyncActiveToProviderSlot;
    function ModelListHasId(AProv: TLlmProvider; const AModelId: string; ASkipIndex: Integer): Boolean;
  public
    constructor Create;
    procedure ResetLayout;
    procedure SetNavigation(AValue: TNavigationItem);
    procedure SetMode(AValue: TWorkspaceMode);
    procedure SetModel(const AValue: string);
    procedure SetTheme(AValue: TThemeKind);
    procedure SetPanelVisible(AId: TPanelId; AValue: Boolean);
    function IsPanelVisible(AId: TPanelId): Boolean;
    procedure SetPanelFloating(AId: TPanelId; AValue: Boolean);
    function IsPanelFloating(AId: TPanelId): Boolean;
    procedure SetPanelBounds(AId: TPanelId; ALeft, ATop, AWidth, AHeight: Integer);
    function GetPanelBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
    procedure SetPanelDockedHeight(AId: TPanelId; AHeight: Integer);
    function GetPanelDockedHeight(AId: TPanelId): Integer;
    procedure Load;
    procedure Save;

    procedure GetProviderCredentials(AProv: TLlmProvider; out AApiKey, ABaseUrl: string);
    procedure SetProviderCredentials(AProv: TLlmProvider; const AApiKey, ABaseUrl: string);
    function SavedModelCount(AProv: TLlmProvider): Integer;
    function GetSavedModel(AProv: TLlmProvider; AIndex: Integer): TSavedModel;
    procedure SetSavedModels(AProv: TLlmProvider; const AModels: array of TSavedModel);
    function AddSavedModel(AProv: TLlmProvider; const AModelId, ADisplayName: string): Integer;
    function UpdateSavedModel(AProv: TLlmProvider; AIndex: Integer; const AModelId, ADisplayName: string): Boolean;
    procedure DeleteSavedModel(AProv: TLlmProvider; AIndex: Integer);
    function FindSavedModelIndexById(AProv: TLlmProvider; const AModelId: string): Integer;
    procedure CommitActiveProviderCredentials(const AApiKey, ABaseUrl: string);
    procedure ActivateProvider(AProv: TLlmProvider);

    property WorkspaceName: string read FWorkspaceName write FWorkspaceName;
    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
    property ActiveWorkspaceId: string read FActiveWorkspaceId write FActiveWorkspaceId;
    function HasActiveWorkspace: Boolean;
    property Navigation: TNavigationItem read FNavigation;
    property Mode: TWorkspaceMode read FMode;
    property Model: string read FModel;
    property Theme: TThemeKind read FTheme;

    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property MaxSteps: Integer read FMaxSteps write FMaxSteps;
    property DebuggingMode: Boolean read FDebuggingMode write FDebuggingMode;
    property LearnMode: Boolean read FLearnMode write FLearnMode;
    property AutoSummarizeContext: Boolean read FAutoSummarizeContext write FAutoSummarizeContext;
    property ContextWindowTokens: Integer read FContextWindowTokens write FContextWindowTokens;
    property SummarizeThreshold: Double read FSummarizeThreshold write FSummarizeThreshold;

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

function DefaultBaseUrlForProvider(AProv: TLlmProvider): string;
function LoadPersistedThemeKind: TThemeKind;

implementation

const
  LLM_CONFIG_VERSION = 3;
  OLD_LLM_PROVIDER_CUSTOM_ORD = 4;

function SettingsFileName: string;
begin
  Result := GetAppConfigFile(False);
end;

function LoadPersistedThemeKind: TThemeKind;
var
  I: TIniFile;
  OrdVal: Integer;
begin
  Result := tkDark;
  I := TIniFile.Create(SettingsFileName);
  try
    OrdVal := I.ReadInteger('Appearance', 'Theme', Ord(tkDark));
    if (OrdVal >= Ord(Low(TThemeKind))) and (OrdVal <= Ord(High(TThemeKind))) then
      Result := TThemeKind(OrdVal)
    else
      Result := tkDark;
  finally
    I.Free;
  end;
end;

function DefaultBaseUrlForProvider(AProv: TLlmProvider): string;
begin
  case AProv of
    lpOpenRouter: Result := 'https://openrouter.ai/api/v1';
    lpOpenAI: Result := 'https://api.openai.com/v1';
    lpAnthropic: Result := 'https://api.anthropic.com/v1';
    lpOllama: Result := 'http://localhost:11434/v1';
    lpNousResearch: Result := 'https://inference-api.nousresearch.com/v1';
    else Result := '';
  end;
end;

function TWorkspaceState.HasActiveWorkspace: Boolean;
begin
  Result := (Trim(FActiveWorkspaceId) <> '') and
    (Trim(FWorkspaceRoot) <> '') and DirectoryExists(FWorkspaceRoot);
end;

constructor TWorkspaceState.Create;
begin
  inherited Create;
  FWorkspaceName := '';
  FWorkspaceRoot := '';
  FActiveWorkspaceId := '';
  FNavigation := niHome;
  FMode := wmAgent;
  FModel := 'anthropic/claude-3.7-sonnet';
  FTheme := tkDark;

  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := DefaultBaseUrlForProvider(lpOpenRouter);
  FTemperature := 0.2;
  FMaxTokens := DEFAULT_MAX_OUTPUT_TOKENS;
  FMaxSteps := 20;
  FDebuggingMode := False;
  FLearnMode := False;
  FAutoSummarizeContext := True;
  FContextWindowTokens := DEFAULT_CONTEXT_WINDOW_TOKENS;
  FSummarizeThreshold := DEFAULT_SUMMARIZE_THRESHOLD;

  InitProviderDefaults;
  ResetLayout;
end;

procedure TWorkspaceState.InitProviderDefaults;
var
  P: TLlmProvider;
begin
  ResetProviderStorage;
  FProviderCreds[FProvider].ApiKey := FApiKey;
  FProviderCreds[FProvider].BaseUrl := FBaseUrl;
  AddSavedModel(FProvider, FModel, FModel);
end;

procedure TWorkspaceState.ResetProviderStorage;
var
  P: TLlmProvider;
begin
  for P := Low(TLlmProvider) to High(TLlmProvider) do begin
    FProviderCreds[P].ApiKey := '';
    FProviderCreds[P].BaseUrl := DefaultBaseUrlForProvider(P);
    SetLength(FProviderModels[P], 0);
  end;
end;

procedure TWorkspaceState.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TWorkspaceState.SyncActiveFromProviderSlot;
begin
  FApiKey := FProviderCreds[FProvider].ApiKey;
  FBaseUrl := FProviderCreds[FProvider].BaseUrl;
end;

procedure TWorkspaceState.SyncActiveToProviderSlot;
begin
  FProviderCreds[FProvider].ApiKey := FApiKey;
  FProviderCreds[FProvider].BaseUrl := FBaseUrl;
end;

procedure TWorkspaceState.CommitActiveProviderCredentials(const AApiKey, ABaseUrl: string);
begin
  FApiKey := AApiKey;
  FBaseUrl := ABaseUrl;
  SyncActiveToProviderSlot;
end;

procedure TWorkspaceState.ActivateProvider(AProv: TLlmProvider);
begin
  if FProvider <> AProv then begin
    SyncActiveToProviderSlot;
    FProvider := AProv;
    SyncActiveFromProviderSlot;
  end;
end;

function TWorkspaceState.ModelListHasId(AProv: TLlmProvider; const AModelId: string; ASkipIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FProviderModels[AProv]) do begin
    if I = ASkipIndex then Continue;
    if SameText(FProviderModels[AProv][I].ModelId, AModelId) then begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TWorkspaceState.GetProviderCredentials(AProv: TLlmProvider; out AApiKey, ABaseUrl: string);
begin
  AApiKey := FProviderCreds[AProv].ApiKey;
  ABaseUrl := FProviderCreds[AProv].BaseUrl;
end;

procedure TWorkspaceState.SetProviderCredentials(AProv: TLlmProvider; const AApiKey, ABaseUrl: string);
begin
  FProviderCreds[AProv].ApiKey := AApiKey;
  if Trim(ABaseUrl) <> '' then
    FProviderCreds[AProv].BaseUrl := ABaseUrl
  else
    FProviderCreds[AProv].BaseUrl := DefaultBaseUrlForProvider(AProv);
  if AProv = FProvider then
    SyncActiveFromProviderSlot;
end;

function TWorkspaceState.SavedModelCount(AProv: TLlmProvider): Integer;
begin
  Result := Length(FProviderModels[AProv]);
end;

function TWorkspaceState.GetSavedModel(AProv: TLlmProvider; AIndex: Integer): TSavedModel;
begin
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then
    raise ERangeError.Create('Saved model index out of range');
  Result := FProviderModels[AProv][AIndex];
end;

procedure TWorkspaceState.SetSavedModels(AProv: TLlmProvider; const AModels: array of TSavedModel);
var
  I: Integer;
begin
  SetLength(FProviderModels[AProv], Length(AModels));
  for I := 0 to High(AModels) do
    FProviderModels[AProv][I] := AModels[I];
end;

function TWorkspaceState.AddSavedModel(AProv: TLlmProvider; const AModelId, ADisplayName: string): Integer;
var
  M: TSavedModel;
  N: Integer;
begin
  Result := -1;
  if Trim(AModelId) = '' then Exit;
  if ModelListHasId(AProv, Trim(AModelId), -1) then Exit;
  M.ModelId := Trim(AModelId);
  if Trim(ADisplayName) <> '' then
    M.DisplayName := Trim(ADisplayName)
  else
    M.DisplayName := M.ModelId;
  N := Length(FProviderModels[AProv]);
  SetLength(FProviderModels[AProv], N + 1);
  FProviderModels[AProv][N] := M;
  Result := N;
end;

function TWorkspaceState.UpdateSavedModel(AProv: TLlmProvider; AIndex: Integer;
  const AModelId, ADisplayName: string): Boolean;
var
  Id: string;
begin
  Result := False;
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then Exit;
  Id := Trim(AModelId);
  if Id = '' then Exit;
  if ModelListHasId(AProv, Id, AIndex) then Exit;
  if SameText(FModel, FProviderModels[AProv][AIndex].ModelId) then
    FModel := Id;
  FProviderModels[AProv][AIndex].ModelId := Id;
  if Trim(ADisplayName) <> '' then
    FProviderModels[AProv][AIndex].DisplayName := Trim(ADisplayName)
  else
    FProviderModels[AProv][AIndex].DisplayName := Id;
  Result := True;
end;

procedure TWorkspaceState.DeleteSavedModel(AProv: TLlmProvider; AIndex: Integer);
var
  I, N: Integer;
  DeletedId: string;
begin
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then Exit;
  DeletedId := FProviderModels[AProv][AIndex].ModelId;
  N := Length(FProviderModels[AProv]);
  for I := AIndex to N - 2 do
    FProviderModels[AProv][I] := FProviderModels[AProv][I + 1];
  SetLength(FProviderModels[AProv], N - 1);
  if SameText(FModel, DeletedId) then begin
    if SavedModelCount(AProv) > 0 then
      FModel := FProviderModels[AProv][0].ModelId
    else
      FModel := '';
  end;
end;

function TWorkspaceState.FindSavedModelIndexById(AProv: TLlmProvider; const AModelId: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FProviderModels[AProv]) do begin
    if SameText(FProviderModels[AProv][I].ModelId, AModelId) then begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TWorkspaceState.ResetLayout;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    FPanels[P].Visible := (P in [piNavigation, piChat]);
    FPanels[P].Floating := False;
    FPanels[P].Left := 100 + Ord(P) * 50;
    FPanels[P].Top := 100 + Ord(P) * 50;
    FPanels[P].Width := 500;
    if P = piTerminal then begin
      FPanels[P].Height := 0;
      FPanels[P].DockedHeight := 0;
    end else
      FPanels[P].Height := 600;
    if P <> piTerminal then
      FPanels[P].DockedHeight := 0;
  end;
  Changed;
end;

procedure TWorkspaceState.SetNavigation(AValue: TNavigationItem);
begin
  if FNavigation <> AValue then begin
    FNavigation := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetMode(AValue: TWorkspaceMode);
begin
  if FMode <> AValue then begin
    FMode := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetModel(const AValue: string);
begin
  if FModel <> AValue then begin
    FModel := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetTheme(AValue: TThemeKind);
begin
  if FTheme <> AValue then begin
    FTheme := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetPanelVisible(AId: TPanelId; AValue: Boolean);
begin
  if FPanels[AId].Visible <> AValue then begin
    FPanels[AId].Visible := AValue;
    Changed;
  end;
end;

function TWorkspaceState.IsPanelVisible(AId: TPanelId): Boolean;
begin
  Result := FPanels[AId].Visible;
end;

procedure TWorkspaceState.SetPanelFloating(AId: TPanelId; AValue: Boolean);
begin
  if FPanels[AId].Floating <> AValue then begin
    FPanels[AId].Floating := AValue;
    Changed;
  end;
end;

function TWorkspaceState.IsPanelFloating(AId: TPanelId): Boolean;
begin
  Result := FPanels[AId].Floating;
end;

procedure TWorkspaceState.SetPanelBounds(AId: TPanelId; ALeft, ATop, AWidth, AHeight: Integer);
begin
  FPanels[AId].Left := ALeft;
  FPanels[AId].Top := ATop;
  FPanels[AId].Width := AWidth;
  FPanels[AId].Height := AHeight;
end;

function TWorkspaceState.GetPanelBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
begin
  ALeft := FPanels[AId].Left;
  ATop := FPanels[AId].Top;
  AWidth := FPanels[AId].Width;
  AHeight := FPanels[AId].Height;
  Result := True;
end;

procedure TWorkspaceState.SetPanelDockedHeight(AId: TPanelId; AHeight: Integer);
begin
  if FPanels[AId].DockedHeight <> AHeight then begin
    FPanels[AId].DockedHeight := AHeight;
    Changed;
  end;
end;

function TWorkspaceState.GetPanelDockedHeight(AId: TPanelId): Integer;
begin
  Result := FPanels[AId].DockedHeight;
end;

procedure TWorkspaceState.Load;
var
  I: TIniFile;
  P: TPanelId;
  Sec: string;
  ConfigVersion, ProvOrd, ModelCount, J: Integer;
  LegacyApiKey, LegacyBaseUrl, LegacyModel: string;
  M: TSavedModel;
  AnyModels: Boolean;
  Prov: TLlmProvider;
begin
  LegacyApiKey := FApiKey;
  LegacyBaseUrl := FBaseUrl;
  LegacyModel := FModel;

  I := TIniFile.Create(SettingsFileName);
  try
    FTheme := TThemeKind(I.ReadInteger('Appearance', 'Theme', Ord(FTheme)));
    FMode := TWorkspaceMode(I.ReadInteger('Agent', 'Mode', Ord(FMode)));
    FModel := I.ReadString('Agent', 'Model', FModel);
    FWorkspaceName := I.ReadString('Workspace', 'Name', FWorkspaceName);
    FWorkspaceRoot := I.ReadString('Workspace', 'Root', FWorkspaceRoot);
    FActiveWorkspaceId := I.ReadString('Workspace', 'ActiveId', FActiveWorkspaceId);

    ConfigVersion := I.ReadInteger('LLM', 'ConfigVersion', 1);
    ProvOrd := I.ReadInteger('LLM', 'Provider', Ord(FProvider));
    if (ConfigVersion < 2) and (ProvOrd = OLD_LLM_PROVIDER_CUSTOM_ORD) then
      ProvOrd := Ord(lpCustom);
    FProvider := TLlmProvider(ProvOrd);

    if ConfigVersion < LLM_CONFIG_VERSION then begin
      LegacyApiKey := I.ReadString('LLM', 'ApiKey', LegacyApiKey);
      LegacyBaseUrl := I.ReadString('LLM', 'BaseUrl', LegacyBaseUrl);
      if Trim(LegacyBaseUrl) = '' then
        LegacyBaseUrl := DefaultBaseUrlForProvider(FProvider);
    end;

    FTemperature := I.ReadFloat('LLM', 'Temperature', FTemperature);
    FMaxTokens := I.ReadInteger('LLM', 'MaxTokens', FMaxTokens);
    FMaxSteps := I.ReadInteger('LLM', 'MaxSteps', FMaxSteps);
    FDebuggingMode := I.ReadBool('General', 'DebuggingMode', FDebuggingMode);
    FLearnMode := I.ReadBool('General', 'LearnMode', FLearnMode);
    FAutoSummarizeContext := I.ReadBool('General', 'AutoSummarizeContext', FAutoSummarizeContext);
    FContextWindowTokens := I.ReadInteger('LLM', 'ContextWindowTokens', FContextWindowTokens);
    FSummarizeThreshold := I.ReadFloat('LLM', 'SummarizeThreshold', FSummarizeThreshold);

    ResetProviderStorage;

    for Prov := Low(TLlmProvider) to High(TLlmProvider) do begin
      Sec := 'Provider_' + IntToStr(Ord(Prov));
      if I.SectionExists(Sec) or (ConfigVersion >= LLM_CONFIG_VERSION) then begin
        FProviderCreds[Prov].ApiKey := I.ReadString(Sec, 'ApiKey', FProviderCreds[Prov].ApiKey);
        FProviderCreds[Prov].BaseUrl := I.ReadString(Sec, 'BaseUrl', FProviderCreds[Prov].BaseUrl);
        if Trim(FProviderCreds[Prov].BaseUrl) = '' then
          FProviderCreds[Prov].BaseUrl := DefaultBaseUrlForProvider(Prov);
      end;

      Sec := 'Models_' + IntToStr(Ord(Prov));
      ModelCount := I.ReadInteger(Sec, 'Count', -1);
      if ModelCount >= 0 then begin
        SetLength(FProviderModels[Prov], ModelCount);
        for J := 0 to ModelCount - 1 do begin
          M.ModelId := I.ReadString(Sec, 'Id_' + IntToStr(J), '');
          M.DisplayName := I.ReadString(Sec, 'Name_' + IntToStr(J), M.ModelId);
          if Trim(M.DisplayName) = '' then
            M.DisplayName := M.ModelId;
          FProviderModels[Prov][J] := M;
        end;
      end;
    end;

    if ConfigVersion < LLM_CONFIG_VERSION then begin
      FProviderCreds[FProvider].ApiKey := LegacyApiKey;
      FProviderCreds[FProvider].BaseUrl := LegacyBaseUrl;
      AnyModels := False;
      for Prov := Low(TLlmProvider) to High(TLlmProvider) do
        if SavedModelCount(Prov) > 0 then
          AnyModels := True;
      if not AnyModels then
        AddSavedModel(FProvider, FModel, FModel);
    end;

    SyncActiveFromProviderSlot;

    for P := Low(TPanelId) to High(TPanelId) do begin
      Sec := 'Panel_' + IntToStr(Ord(P));
      FPanels[P].Visible := I.ReadBool(Sec, 'Visible', FPanels[P].Visible);
      FPanels[P].Floating := I.ReadBool(Sec, 'Floating', FPanels[P].Floating);
      FPanels[P].Left := I.ReadInteger(Sec, 'Left', FPanels[P].Left);
      FPanels[P].Top := I.ReadInteger(Sec, 'Top', FPanels[P].Top);
      FPanels[P].Width := I.ReadInteger(Sec, 'Width', FPanels[P].Width);
      FPanels[P].Height := I.ReadInteger(Sec, 'Height', FPanels[P].Height);
      FPanels[P].DockedHeight := I.ReadInteger(Sec, 'DockedHeight', FPanels[P].DockedHeight);
    end;

    { One-time migration: docked height was briefly stored in Height (not float size). }
    if (FPanels[piTerminal].DockedHeight = 0) and (FPanels[piTerminal].Height >= 120) and
       (FPanels[piTerminal].Height <= 500) then
      FPanels[piTerminal].DockedHeight := FPanels[piTerminal].Height;
  finally
    I.Free;
  end;
end;

procedure TWorkspaceState.Save;
var
  I: TIniFile;
  P: TPanelId;
  Sec: string;
  Prov: TLlmProvider;
  J, N: Integer;
begin
  SyncActiveToProviderSlot;

  I := TIniFile.Create(SettingsFileName);
  try
    I.WriteInteger('Appearance', 'Theme', Ord(FTheme));
    I.WriteInteger('Agent', 'Mode', Ord(FMode));
    I.WriteString('Agent', 'Model', FModel);
    I.WriteString('Workspace', 'Name', FWorkspaceName);
    I.WriteString('Workspace', 'Root', FWorkspaceRoot);
    I.WriteString('Workspace', 'ActiveId', FActiveWorkspaceId);

    I.WriteInteger('LLM', 'ConfigVersion', LLM_CONFIG_VERSION);
    I.WriteInteger('LLM', 'Provider', Ord(FProvider));
    I.WriteString('LLM', 'ApiKey', FApiKey);
    I.WriteString('LLM', 'BaseUrl', FBaseUrl);
    I.WriteFloat('LLM', 'Temperature', FTemperature);
    I.WriteInteger('LLM', 'MaxTokens', FMaxTokens);
    I.WriteInteger('LLM', 'MaxSteps', FMaxSteps);
    I.WriteBool('General', 'DebuggingMode', FDebuggingMode);
    I.WriteBool('General', 'LearnMode', FLearnMode);
    I.WriteBool('General', 'AutoSummarizeContext', FAutoSummarizeContext);
    I.WriteInteger('LLM', 'ContextWindowTokens', FContextWindowTokens);
    I.WriteFloat('LLM', 'SummarizeThreshold', FSummarizeThreshold);

    for Prov := Low(TLlmProvider) to High(TLlmProvider) do begin
      Sec := 'Provider_' + IntToStr(Ord(Prov));
      I.WriteString(Sec, 'ApiKey', FProviderCreds[Prov].ApiKey);
      I.WriteString(Sec, 'BaseUrl', FProviderCreds[Prov].BaseUrl);

      Sec := 'Models_' + IntToStr(Ord(Prov));
      N := SavedModelCount(Prov);
      I.WriteInteger(Sec, 'Count', N);
      for J := 0 to N - 1 do begin
        I.WriteString(Sec, 'Id_' + IntToStr(J), FProviderModels[Prov][J].ModelId);
        I.WriteString(Sec, 'Name_' + IntToStr(J), FProviderModels[Prov][J].DisplayName);
      end;
    end;

    for P := Low(TPanelId) to High(TPanelId) do begin
      Sec := 'Panel_' + IntToStr(Ord(P));
      I.WriteBool(Sec, 'Visible', FPanels[P].Visible);
      I.WriteBool(Sec, 'Floating', FPanels[P].Floating);
      I.WriteInteger(Sec, 'Left', FPanels[P].Left);
      I.WriteInteger(Sec, 'Top', FPanels[P].Top);
      I.WriteInteger(Sec, 'Width', FPanels[P].Width);
      I.WriteInteger(Sec, 'Height', FPanels[P].Height);
      I.WriteInteger(Sec, 'DockedHeight', FPanels[P].DockedHeight);
    end;
  finally
    I.Free;
  end;
end;

end.
