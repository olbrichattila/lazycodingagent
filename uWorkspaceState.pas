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
  end;

  TWorkspaceState = class
  private
    FWorkspaceName: string;
    FWorkspaceRoot: string;
    FNavigation: TNavigationItem;
    FMode: TWorkspaceMode;
    FModel: string;
    FTheme: TThemeKind;

    // LLM & Agent Settings
    FProvider: TLlmProvider;
    FApiKey: string;
    FBaseUrl: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FMaxSteps: Integer;

    FPanels: array[TPanelId] of TPanelState;
    FOnChange: TNotifyEvent;
    procedure Changed;
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
    procedure Load;
    procedure Save;

    property WorkspaceName: string read FWorkspaceName write FWorkspaceName;
    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
    property Navigation: TNavigationItem read FNavigation;
    property Mode: TWorkspaceMode read FMode;
    property Model: string read FModel;
    property Theme: TThemeKind read FTheme;

    // LLM settings
    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property MaxSteps: Integer read FMaxSteps write FMaxSteps;

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

function SettingsFileName: string;
begin
  Result := GetAppConfigFile(False);
end;

constructor TWorkspaceState.Create;
begin
  inherited Create;
  FWorkspaceName := 'LazyCodingAgent';
  FWorkspaceRoot := GetCurrentDir;
  FNavigation := niHome;
  FMode := wmAgent;
  FModel := 'anthropic/claude-3.7-sonnet';
  FTheme := tkDark;

  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := 'https://openrouter.ai/api/v1';
  FTemperature := 0.2;
  FMaxTokens := 4096;
  FMaxSteps := 20;

  ResetLayout;
end;

procedure TWorkspaceState.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
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
    FPanels[P].Height := 600;
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

procedure TWorkspaceState.Load;
var
  I: TIniFile;
  P: TPanelId;
  Sec: string;
begin
  I := TIniFile.Create(SettingsFileName);
  try
    FTheme := TThemeKind(I.ReadInteger('Appearance', 'Theme', Ord(FTheme)));
    FMode := TWorkspaceMode(I.ReadInteger('Agent', 'Mode', Ord(FMode)));
    FModel := I.ReadString('Agent', 'Model', FModel);
    FWorkspaceName := I.ReadString('Workspace', 'Name', FWorkspaceName);
    FWorkspaceRoot := I.ReadString('Workspace', 'Root', FWorkspaceRoot);

    FProvider := TLlmProvider(I.ReadInteger('LLM', 'Provider', Ord(FProvider)));
    FApiKey := I.ReadString('LLM', 'ApiKey', FApiKey);
    FBaseUrl := I.ReadString('LLM', 'BaseUrl', FBaseUrl);
    FTemperature := I.ReadFloat('LLM', 'Temperature', FTemperature);
    FMaxTokens := I.ReadInteger('LLM', 'MaxTokens', FMaxTokens);
    FMaxSteps := I.ReadInteger('LLM', 'MaxSteps', FMaxSteps);

    for P := Low(TPanelId) to High(TPanelId) do begin
      Sec := 'Panel_' + IntToStr(Ord(P));
      FPanels[P].Visible := I.ReadBool(Sec, 'Visible', FPanels[P].Visible);
      FPanels[P].Floating := I.ReadBool(Sec, 'Floating', FPanels[P].Floating);
      FPanels[P].Left := I.ReadInteger(Sec, 'Left', FPanels[P].Left);
      FPanels[P].Top := I.ReadInteger(Sec, 'Top', FPanels[P].Top);
      FPanels[P].Width := I.ReadInteger(Sec, 'Width', FPanels[P].Width);
      FPanels[P].Height := I.ReadInteger(Sec, 'Height', FPanels[P].Height);
    end;
  finally
    I.Free;
  end;
end;

procedure TWorkspaceState.Save;
var
  I: TIniFile;
  P: TPanelId;
  Sec: string;
begin
  I := TIniFile.Create(SettingsFileName);
  try
    I.WriteInteger('Appearance', 'Theme', Ord(FTheme));
    I.WriteInteger('Agent', 'Mode', Ord(FMode));
    I.WriteString('Agent', 'Model', FModel);
    I.WriteString('Workspace', 'Name', FWorkspaceName);
    I.WriteString('Workspace', 'Root', FWorkspaceRoot);

    I.WriteInteger('LLM', 'Provider', Ord(FProvider));
    I.WriteString('LLM', 'ApiKey', FApiKey);
    I.WriteString('LLM', 'BaseUrl', FBaseUrl);
    I.WriteFloat('LLM', 'Temperature', FTemperature);
    I.WriteInteger('LLM', 'MaxTokens', FMaxTokens);
    I.WriteInteger('LLM', 'MaxSteps', FMaxSteps);

    for P := Low(TPanelId) to High(TPanelId) do begin
      Sec := 'Panel_' + IntToStr(Ord(P));
      I.WriteBool(Sec, 'Visible', FPanels[P].Visible);
      I.WriteBool(Sec, 'Floating', FPanels[P].Floating);
      I.WriteInteger(Sec, 'Left', FPanels[P].Left);
      I.WriteInteger(Sec, 'Top', FPanels[P].Top);
      I.WriteInteger(Sec, 'Width', FPanels[P].Width);
      I.WriteInteger(Sec, 'Height', FPanels[P].Height);
    end;
  finally
    I.Free;
  end;
end;

end.
