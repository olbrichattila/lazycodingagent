unit fraPromptCacheSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls, LcaPaintButton,
  uAppTypes, LcaTheme, uLlmPromptCacheTypes, uLlmCacheCapabilities, uLlmCacheUsage, uAgentTypes;

type
  TPromptCacheSettingsFrame = class(TFrame)
    scrPromptCache: TScrollBox;
    pnlContent: TPanel;
    lblTitle: TLabel;
    lblHint: TLabel;
    chkEnabled: TCheckBox;
    grpMode: TGroupBox;
    rbAutomatic: TRadioButton;
    rbExplicit: TRadioButton;
    rbDisabled: TRadioButton;
    lblRetention: TLabel;
    cboRetention: TComboBox;
    grpContent: TGroupBox;
    chkSystem: TCheckBox;
    chkTools: TCheckBox;
    chkProject: TCheckBox;
    chkHistory: TCheckBox;
    grpStats: TGroupBox;
    lblInputTokens: TLabel;
    lblCachedTokens: TLabel;
    lblHitRatio: TLabel;
    lblSavings: TLabel;
    btnResetStats: TLcaPaintButton;
    procedure btnResetStatsClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    FProvider: TLlmProvider;
    FBaseUrl: string;
    FModel: string;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure UpdateCapabilityUi;
    procedure RefreshStats;
  public
    procedure InitTheme(ATheme: TThemeKind);
    procedure SetProviderContext(AProvider: TLlmProvider; const ABaseUrl, AModel: string);
    procedure LoadSettings(const ASettings: TPromptCacheSettings);
    function SaveSettings: TPromptCacheSettings;
  end;

implementation

{$R *.lfm}

procedure TPromptCacheSettingsFrame.InitTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyTheme(ATheme);
end;

procedure TPromptCacheSettingsFrame.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Surface;
  Font.Color := P.Text;
  scrPromptCache.Color := P.Surface;
  pnlContent.Color := P.Surface;
  if Assigned(lblHint) then
    lblHint.Font.Color := P.TextMuted;
  ApplyThemedControlTree(Self, ATheme);
end;

procedure TPromptCacheSettingsFrame.SetProviderContext(AProvider: TLlmProvider;
  const ABaseUrl, AModel: string);
begin
  FProvider := AProvider;
  FBaseUrl := ABaseUrl;
  FModel := AModel;
  UpdateCapabilityUi;
end;

procedure TPromptCacheSettingsFrame.UpdateCapabilityUi;
var
  Wire: TLlmWireFormat;
  Caps: TPromptCacheCapabilities;
begin
  Wire := ResolveLlmWireFormat(FProvider, FBaseUrl, FModel);
  Caps := ResolveCacheCapabilities(FProvider, FBaseUrl, FModel, Wire);
  rbExplicit.Enabled := Caps.SupportsExplicitCaching;
  cboRetention.Enabled := Caps.SupportsRetentionControl;
  if not rbExplicit.Enabled and rbExplicit.Checked then
    rbAutomatic.Checked := True;
  RefreshStats;
end;

procedure TPromptCacheSettingsFrame.RefreshStats;
var
  Snap: TPromptCacheStatsSnapshot;
  Ratio: Double;
begin
  Snap := GlobalPromptCacheStats.Snapshot;
  if Snap.MetricsKnownRequestCount = 0 then begin
    lblInputTokens.Caption := 'Input tokens: —';
    lblCachedTokens.Caption := 'Cached read tokens: —';
    lblHitRatio.Caption := 'Cache hit ratio: —';
  end else begin
    lblInputTokens.Caption := Format('Input tokens: %d', [Snap.TotalInputTokens]);
    lblCachedTokens.Caption := Format('Cached read tokens: %d', [Snap.TotalCachedReadTokens]);
    Ratio := GlobalPromptCacheStats.CacheHitRatio(Snap);
    if Ratio < 0 then
      lblHitRatio.Caption := 'Cache hit ratio: —'
    else
      lblHitRatio.Caption := Format('Cache hit ratio: %.1f%%', [Ratio]);
  end;
  lblSavings.Caption := 'Estimated savings: Provider-dependent';
end;

procedure TPromptCacheSettingsFrame.LoadSettings(const ASettings: TPromptCacheSettings);
begin
  case ASettings.Mode of
    pcmDisabled: rbDisabled.Checked := True;
    pcmExplicit: rbExplicit.Checked := True;
  else
    rbAutomatic.Checked := True;
  end;
  chkEnabled.Checked := ASettings.Mode <> pcmDisabled;
  cboRetention.ItemIndex := Ord(ASettings.Retention);
  chkSystem.Checked := ASettings.CacheSystemInstructions;
  chkTools.Checked := ASettings.CacheToolDefinitions;
  chkProject.Checked := ASettings.CacheProjectContext;
  chkHistory.Checked := ASettings.CacheConversationHistory;
  UpdateCapabilityUi;
end;

function TPromptCacheSettingsFrame.SaveSettings: TPromptCacheSettings;
begin
  Result := DefaultPromptCacheSettings;
  if not chkEnabled.Checked then
    Result.Mode := pcmDisabled
  else if rbExplicit.Checked then
    Result.Mode := pcmExplicit
  else if rbDisabled.Checked then
    Result.Mode := pcmDisabled
  else
    Result.Mode := pcmAutomatic;
  if (cboRetention.ItemIndex >= Ord(Low(TPromptCacheRetention))) and
     (cboRetention.ItemIndex <= Ord(High(TPromptCacheRetention))) then
    Result.Retention := TPromptCacheRetention(cboRetention.ItemIndex);
  Result.CacheSystemInstructions := chkSystem.Checked;
  Result.CacheToolDefinitions := chkTools.Checked;
  Result.CacheProjectContext := chkProject.Checked;
  Result.CacheConversationHistory := chkHistory.Checked;
end;

procedure TPromptCacheSettingsFrame.btnResetStatsClick(Sender: TObject);
begin
  GlobalPromptCacheStats.Reset;
  RefreshStats;
end;

end.
