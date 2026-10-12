unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Buttons,
  ComCtrls, Menus, FileUtil, SynEdit, SynEditTypes,
  uAppTypes, uAgentTypes, uAgentTools, uTheme, uThemedPageTabBar, uWorkspaceState,
  uWorkspaceRegistry, uChatSessionStore, uChatSessionHub, uNavigationPanel, uChatPanel,
  uTerminalPanel, uMainFileEditor, uPlanView,
  uAgentEngine, frmSettings, frmNewWorkspace, frmWorkspaceRules,
  uAgentExecutionLog, uAgentToolErrorLog,
  uSyntaxSchemeRegistry, frmSyntaxSchemes,
  frmOpenMarkdown, frmHelp, uMarkdownHtmlView, uPanelDetach, uThemeHooks, fpjson, jsonparser;

type
  { TLazyCodingAgentForm }
  TLazyCodingAgentForm = class(TForm)
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuFileNew: TMenuItem;
    mnuFileOpen: TMenuItem;
    mnuFileSave: TMenuItem;
    mnuFileSaveFile: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuFileExit: TMenuItem;
    mnuView: TMenuItem;
    mnuViewToggleTheme: TMenuItem;
    mnuViewResetLayout: TMenuItem;
    mnuViewTerminal: TMenuItem;
    mnuViewSyntaxSep: TMenuItem;
    mnuViewSyntaxSchemes: TMenuItem;
    mnuViewActiveSchemes: TMenuItem;
    mnuWindow: TMenuItem;
    mnuPanelsVisibility: TMenuItem;
    mnuWorkspace: TMenuItem;
    mnuWorkspaceSepRules: TMenuItem;
    mnuWorkspaceProjectRules: TMenuItem;
    mnuAgent: TMenuItem;
    mnuAgentClearHistory: TMenuItem;
    mnuAgentStop: TMenuItem;
    mnuSettings: TMenuItem;
    mnuSettingsOptions: TMenuItem;
    mnuHelp: TMenuItem;
    mnuHelpUserGuide: TMenuItem;
    mnuHelpAbout: TMenuItem;

    StatusBar1: TStatusBar;

    pnlMainContainer: TPanel;
    pnlNavRailHost: TPanel;
    sbtnNavHome: TSpeedButton;
    sbtnNavProjects: TSpeedButton;
    sbtnNavSessions: TSpeedButton;
    sbtnNavBots: TSpeedButton;
    sbtnNavTools: TSpeedButton;
    sbtnNavTasks: TSpeedButton;
    sbtnNavToolErrors: TSpeedButton;
    sbtnNavMultiAgent: TSpeedButton;
    sbtnNavExecPlans: TSpeedButton;
    sbtnNavKnowledge: TSpeedButton;
    sbtnNavBrain: TSpeedButton;
    pnlNavHost: TPanel;
    pnlNavChrome: TPanel;
    lblNavTitle: TLabel;
    btnNavDetach: TButton;
    btnNavHide: TButton;
    pnlNavContent: TPanel;
    lblNavViewTitle: TLabel;
    lblNavViewSub: TLabel;
    btnNavPrimary: TButton;
    btnNavSecondary: TButton;
    lstNavFile: TListBox;
    tvNavProjects: TTreeView;
    lstNavLog: TListBox;
    lstNavErrors: TListBox;
    splNav: TSplitter;
    pnlUtilityHost: TPanel;
    pnlUtilityChrome: TPanel;
    pnlUtilityTabStripHost: TPanel;
    btnUtilityDetach: TButton;
    btnUtilityHide: TButton;
    pnlUtilityContent: TPanel;
    pgcUtility: TPageControl;
    tsUtilityScratch: TTabSheet;
    memUtilityScratch: TMemo;
    tsUtilityExecDetail: TTabSheet;
    memUtilityExecDetail: TMemo;
    tsUtilityPlan: TTabSheet;
    pnlPlanHeader: TPanel;
    lblPlanPath: TLabel;
    cboPlanModel: TComboBox;
    btnPlanBuild: TButton;
    memPlanBody: TMemo;
    splUtility: TSplitter;
    pnlReservedHost: TPanel;
    pnlReservedChrome: TPanel;
    lblReservedTitle: TLabel;
    btnReservedDetach: TButton;
    btnReservedHide: TButton;
    pnlReservedContent: TPanel;
    memReserved: TMemo;
    splReserved: TSplitter;
    pnlChatHost: TPanel;
    pnlChatChrome: TPanel;
    pnlCenterTabStripHost: TPanel;
    btnChatDetach: TButton;
    btnChatHide: TButton;
    pgcCenter: TPageControl;
    tsChat: TTabSheet;
    lblChatHeading: TLabel;
    lblChatSession: TLabel;
    lblChatSub: TLabel;
    pnlChatComposer: TPanel;
    lblChatWorkspaceTag: TLabel;
    memChatPrompt: TMemo;
    pnlChatFooter: TPanel;
    cboChatMode: TComboBox;
    cboChatModel: TComboBox;
    btnChatStop: TButton;
    btnChatSend: TButton;
    pnlChatHistoryHost: TPanel;
    tsEditor: TTabSheet;
    synEditor: TSynEdit;
    tsMarkdown: TTabSheet;
    pnlMarkdownPreviewHost: TPanel;
    splTerminal: TSplitter;
    pnlTerminalHost: TPanel;
    pnlTerminalChrome: TPanel;
    lblTerminalTitle: TLabel;
    btnTerminalHide: TButton;
    pnlTerminalContent: TPanel;
    lblTerminalStatus: TLabel;

    procedure PanelHideClick(Sender: TObject);
    procedure PanelDetachClick(Sender: TObject);

    // Published Event Handlers (Form Designer connected)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure MnuViewToggleThemeClick(Sender: TObject);
    procedure MnuViewResetLayoutClick(Sender: TObject);
    procedure MnuViewTerminalClick(Sender: TObject);
    procedure SplTerminalMoved(Sender: TObject);
    procedure MnuFileNewClick(Sender: TObject);
    procedure MnuFileOpenClick(Sender: TObject);
    procedure MnuFileSaveClick(Sender: TObject);
    procedure MnuFileSaveFileClick(Sender: TObject);
    procedure MnuFileExitClick(Sender: TObject);
    procedure MnuViewSyntaxSchemesClick(Sender: TObject);
    procedure MnuAgentClearHistoryClick(Sender: TObject);
    procedure MnuAgentStopClick(Sender: TObject);
    procedure MnuSettingsOptionsClick(Sender: TObject);
    procedure MnuWorkspaceProjectRulesClick(Sender: TObject);
    procedure MnuHelpUserGuideClick(Sender: TObject);
    procedure MnuHelpAboutClick(Sender: TObject);
    procedure NavRailBtnClick(Sender: TObject);
  private
    FCenterTabBar: TThemedPageTabBar;
    FUtilityTabBar: TThemedPageTabBar;
    FState: TWorkspaceState;
    FSessionHubs: TChatSessionHubManager;
    FActiveHub: TChatSessionHub;
    FUpdatingState: Boolean;
    FPendingInitialDockLayout: Boolean;
    FPendingInitialWorkspaceUI: Boolean;
    FDeferThemesUntilShown: Boolean;
    FPostShowStartupScheduled: Boolean;
    FPostShowStartupTimer: TTimer;
    FTerminalStartQueued: Boolean;
    FTerminalRetryTimer: TTimer;
    FTerminalRetryCount: Integer;

    FNavRailBtns: array[TNavigationItem] of TSpeedButton;
    FNavContent: TNavContentControl;
    FChatPanel: TChatPanel;
    FSyntaxSchemes: TSyntaxSchemeRegistry;

    FTerminalPanel: TTerminalPanel;
    FFileEditor: TMainFileEditor;
    FPlanView: TPlanView;
    FMarkdownPreview: TMarkdownHtmlView;
    FPanelDetach: TPanelDetachManager;
    FMarkdownPath: string;
    FCurrentRunMode: TWorkspaceMode;
    FPlanSavedThisRun: Boolean;

    FRegistry: TWorkspaceRegistry;
    FCurrentSessionId: string;
    FNavWorkCaptions: TStringList;
    FNavWorkIds: TStringList;
    FNavSessionCaptions: TStringList;
    FNavSessionIds: TStringList;
    FNavSessionArchived: TStringList;

    function ActiveAgent: TAgentEngine;
    function ActiveStore: TChatSessionStore;
    procedure EnsureActiveHub;
    procedure SaveCurrentSession;
    procedure BindSessionToUI(const ASessionId: string);
    procedure SelectSession(const ASessionId: string);
    procedure UpdateSessionCaption;
    function AgentStateIsRunning(AState: TAgentState): Boolean;
    procedure ApplySessionComposerState;
    procedure ActivateWorkspace(const AWorkspaceId: string);
    procedure DeactivateWorkspace;
    function AddOrActivateFolder(const ADisplayName, AFolderPath: string): Boolean;
    procedure RefreshWorkspaceNav;
    procedure RefreshSessionNav;
    procedure NavWorkspaceSelect(Sender: TObject; const AWorkspaceId: string);
    procedure NavWorkspaceNew(Sender: TObject);
    procedure NavWorkspaceDelete(Sender: TObject; const AWorkspaceId: string);
    procedure NavSessionSelect(Sender: TObject; const ASessionId: string);
    procedure CreateAndSelectNewSession;
    procedure NavSessionNew(Sender: TObject);
    procedure DoArchiveSession(const ASessionId: string);
    procedure EnsureActiveNonArchivedSession;
    procedure NavSessionArchive(Sender: TObject; const ASessionId: string);
    procedure NavSessionRestore(Sender: TObject; const ASessionId: string);
    procedure NavSessionDelete(Sender: TObject; const ASessionId: string);
    procedure ApplyWorkspaceChatVisibility;

    function ParsePlanToolSuccess(const AResult: TToolExecutionResult;
      out APath, AContent: string): Boolean;
    procedure OpenPlanInUtilityTab(const APath, AContent: string);
    procedure TrySaveProposedPlanFromChat;
    procedure PlanBuildRequested(Sender: TObject; const APlanPath, APlanContent,
      AModelId: string);
    procedure RefreshPlanViewModels(const AModels: array of TSavedModel);

    function IsMarkdownFile(const APath: string): Boolean;
    procedure OpenFileInCenterTab(const APath: string);
    procedure OpenMarkdownInCenterTab(const APath: string);
    procedure ShowChatCenterTab;
    procedure ApplyEditorTheme;
    procedure RefreshEditorScheme;
    function SaveActiveEditorFile: Boolean;
    function PromptDirtyEditor: Boolean;
    procedure RebuildActiveSchemeMenu;
    procedure MenuSelectSyntaxScheme(Sender: TObject);
    procedure NavFileOpen(Sender: TObject; const AFilePath: string);

    procedure ApplyInitialWindowSize;
    procedure InitWorkspaceSubControls;
    procedure InitNavRailButtons;
    procedure UpdateNavRailSelection;
    procedure PopulateMenusAndCombos;
    procedure StateChanged(Sender: TObject);
    procedure ApplyDockPanelsLayout;
    procedure SyncCenterAddTabNav;
    procedure CreateThemedTabBars;
    procedure InitCenterTabStrip;
    procedure TabBarCenterAddTab(Sender: TObject);
    procedure TabBarCenterTabClose(Sender: TObject; TabSheet: TTabSheet; var AllowClose: Boolean);
    procedure SyncTerminalWorkingDirectory;
    procedure ScheduleDeferredTerminalStart;
    procedure DeferredEnsureTerminal(Data: PtrInt);
    procedure ScheduleTerminalStartRetry;
    procedure TerminalRetryTimer(Sender: TObject);
    procedure TerminalStatus(Sender: TObject; const AMessage: string);
    function IsTerminalSurfaceVisible: Boolean;
    function EffectiveTerminalDockHeight: Integer;
    procedure ApplyAllThemes;
    procedure ApplyPlatformChromeThemes;
    procedure SchedulePostShowStartup;
    procedure PostShowStartup(Sender: TObject);
    procedure RebuildWindowMenu;

    procedure PanelHideClickAction(AId: TPanelId);
    procedure ChatPrompt(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string);
    procedure ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
    procedure ChatModelChange(Sender: TObject; const AModel: string);
    procedure ChatCancel(Sender: TObject);

    procedure HubStateChange(Sender: TObject; const ASessionId: string;
      AOldState, ANewState: TAgentState);
    procedure HubMessageAdded(Sender: TObject; const ASessionId: string; const AMsg: TChatMessage);
    procedure HubToolCall(Sender: TObject; const ASessionId: string; const AToolName, AArgs: string);
    procedure HubToolResult(Sender: TObject; const ASessionId: string; const AToolName,
      AArgsJson: string; const AResult: TToolExecutionResult);
    procedure HubExecutionLogAdded(Sender: TObject; const ASessionId: string; AEntryIndex: Integer);
    procedure HubToolErrorAdded(Sender: TObject; const ASessionId: string; AEntryIndex: Integer);
    procedure NavLogEntrySelected(Sender: TObject; AIndex: Integer);
    procedure NavToolErrorEntrySelected(Sender: TObject; AIndex: Integer);
    procedure NavClearExecutionLog(Sender: TObject);
    procedure NavClearToolErrorLog(Sender: TObject);
    procedure BindExecutionLogToNav(const ASessionId: string);
    procedure BindToolErrorLogToNav(const ASessionId: string);
    procedure RefreshNavTaskList;
    procedure NavTasksRefresh(Sender: TObject);
    procedure SyncHubClientSettings(AHub: TChatSessionHub);

    procedure MenuSelectNav(Sender: TObject);
    procedure MenuSelectMode(Sender: TObject);
    procedure MenuTogglePanel(Sender: TObject);
  public
    property State: TWorkspaceState read FState;
    property Agent: TAgentEngine read ActiveAgent;
  end;

var
  LazyCodingAgentForm: TLazyCodingAgentForm;

implementation

{$R *.lfm}

{ TLazyCodingAgentForm }

function TLazyCodingAgentForm.ActiveAgent: TAgentEngine;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then
    Exit(nil);
  Result := FActiveHub.EngineFor(FCurrentSessionId);
  if Result = nil then
    Result := FActiveHub.GetOrCreateEngine(FCurrentSessionId);
end;

function TLazyCodingAgentForm.ActiveStore: TChatSessionStore;
begin
  if Assigned(FActiveHub) then
    Result := FActiveHub.Store
  else
    Result := nil;
end;

procedure TLazyCodingAgentForm.EnsureActiveHub;
var
  Hub: TChatSessionHub;
begin
  if not FState.HasActiveWorkspace then begin
    FActiveHub := nil;
    Exit;
  end;
  Hub := FSessionHubs.GetOrCreate(FState.ActiveWorkspaceId, FState.WorkspaceRoot);
  Hub.OnStateChange := @HubStateChange;
  Hub.OnMessageAdded := @HubMessageAdded;
  Hub.OnToolCall := @HubToolCall;
  Hub.OnToolResult := @HubToolResult;
  Hub.OnExecutionLogAdded := @HubExecutionLogAdded;
  Hub.OnToolErrorAdded := @HubToolErrorAdded;
  SyncHubClientSettings(Hub);
  FActiveHub := Hub;
end;

procedure TLazyCodingAgentForm.SyncHubClientSettings(AHub: TChatSessionHub);
begin
  if not Assigned(AHub) then Exit;
  AHub.ApplyClientSettings(FState.Provider, FState.ApiKey, FState.BaseUrl, FState.Model,
    FState.Temperature, FState.MaxTokens, FState.MaxSteps);
end;

procedure TLazyCodingAgentForm.ApplySessionComposerState;
var
  Info: TChatSessionInfo;
  Archived: Boolean;
begin
  if not Assigned(FChatPanel) then Exit;
  Archived := False;
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, Info) then
    Archived := Info.Archived;
  if Archived then
    FChatPanel.SetComposerEnabled(False)
  else
    FChatPanel.SetComposerEnabled(True);
end;

procedure TLazyCodingAgentForm.BindSessionToUI(const ASessionId: string);
var
  E: TAgentEngine;
  I: Integer;
  Msgs: TChatMessageArray;
begin
  if ASessionId = '' then Exit;
  EnsureActiveHub;
  if not Assigned(FActiveHub) then Exit;

  E := FActiveHub.GetOrCreateEngine(ASessionId);
  SetLength(Msgs, E.GetMessageCount);
  for I := 0 to E.GetMessageCount - 1 do
    Msgs[I] := E.GetMessage(I);

  if Assigned(FChatPanel) then begin
    FChatPanel.ReloadFromMessages(Msgs, FState.DebuggingMode);
    FChatPanel.SetRunning(E.IsRunActive);
  end;
  ApplySessionComposerState;
  BindExecutionLogToNav(ASessionId);
  BindToolErrorLogToNav(ASessionId);
  RefreshNavTaskList;
  memUtilityExecDetail.Clear;
end;

procedure TLazyCodingAgentForm.BindExecutionLogToNav(const ASessionId: string);
var
  Log: TAgentExecutionLog;
begin
  if not Assigned(FNavContent) then Exit;
  Log := nil;
  if (ASessionId <> '') and FState.HasActiveWorkspace then begin
    EnsureActiveHub;
    if Assigned(FActiveHub) then begin
      FActiveHub.GetOrCreateEngine(ASessionId);
      Log := FActiveHub.ExecutionLogFor(ASessionId);
    end;
  end;
  FNavContent.BindExecutionLog(Log);
end;

procedure TLazyCodingAgentForm.BindToolErrorLogToNav(const ASessionId: string);
var
  Log: TAgentToolErrorLog;
begin
  if not Assigned(FNavContent) then Exit;
  Log := nil;
  if (ASessionId <> '') and FState.HasActiveWorkspace then begin
    EnsureActiveHub;
    if Assigned(FActiveHub) then begin
      FActiveHub.GetOrCreateEngine(ASessionId);
      Log := FActiveHub.ToolErrorLogFor(ASessionId);
    end;
  end;
  FNavContent.BindToolErrorLog(Log);
end;

procedure TLazyCodingAgentForm.SelectSession(const ASessionId: string);
begin
  if ASessionId = '' then Exit;
  if SameText(ASessionId, FCurrentSessionId) then Exit;
  SaveCurrentSession;
  FCurrentSessionId := ASessionId;
  if Assigned(ActiveStore) then
    ActiveStore.SetLastSessionId(ASessionId);
  if FState.HasActiveWorkspace then
    FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, ASessionId);
  BindSessionToUI(ASessionId);
  UpdateSessionCaption;
end;



procedure TLazyCodingAgentForm.UpdateSessionCaption;
var
  S: TChatSessionInfo;
  Cap: string;
begin
  if not Assigned(FChatPanel) then Exit;
  Cap := '(no session)';
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, S) then begin
    Cap := S.Title;
    if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(FCurrentSessionId) then
      Cap := Cap + ' ●';
  end;
  FChatPanel.SetSessionCaption('Session: ' + Cap);
end;

function TLazyCodingAgentForm.AgentStateIsRunning(AState: TAgentState): Boolean;
begin
  Result := not (AState in [asIdle, asFinished, asError]);
end;



procedure TLazyCodingAgentForm.ApplyInitialWindowSize;
var
  R: TRect;
  W, H, MaxW, MaxH: Integer;
const
  IDEAL_W = 1440;
  IDEAL_H = 900;
  MAX_PCT = 92;
begin
  R := Screen.PrimaryMonitor.WorkareaRect;
  MaxW := (R.Width * MAX_PCT) div 100;
  MaxH := (R.Height * MAX_PCT) div 100;
  W := IDEAL_W;
  if W > MaxW then
    W := MaxW;
  H := IDEAL_H;
  if H > MaxH then
    H := MaxH;
  if Constraints.MinWidth > R.Width then
    Constraints.MinWidth := R.Width;
  if Constraints.MinHeight > R.Height then
    Constraints.MinHeight := R.Height;
  if W < Constraints.MinWidth then
    W := Constraints.MinWidth;
  if H < Constraints.MinHeight then
    H := Constraints.MinHeight;
  if W > R.Width then
    W := R.Width;
  if H > R.Height then
    H := R.Height;
  Width := W;
  Height := H;
  if Position = poScreenCenter then begin
    Left := R.Left + (R.Width - W) div 2;
    Top := R.Top + (R.Height - H) div 2;
  end;
end;


procedure TLazyCodingAgentForm.FormCreate(Sender: TObject);
begin
  ApplyInitialWindowSize;
  Caption := 'LazyCodingAgent — AI Workspace';
  FUpdatingState := False;
  FTerminalStartQueued := False;
  FPendingInitialDockLayout := True;
  FPendingInitialWorkspaceUI := True;
  FDeferThemesUntilShown := True;
  FPostShowStartupScheduled := False;

  FPostShowStartupTimer := TTimer.Create(Self);
  FPostShowStartupTimer.Enabled := False;
  FPostShowStartupTimer.Interval := 1;
  FPostShowStartupTimer.OnTimer := @PostShowStartup;

  FState := TWorkspaceState.Create;
  FState.Load;
  FState.OnChange := @StateChanged;

  FRegistry := TWorkspaceRegistry.Create;
  FRegistry.Load;
  FRegistry.MigrateFromLegacyIni(FState.WorkspaceName, FState.WorkspaceRoot);

  FSessionHubs := TChatSessionHubManager.Create;
  FActiveHub := nil;
  FNavWorkCaptions := TStringList.Create;
  FNavWorkIds := TStringList.Create;
  FNavSessionCaptions := TStringList.Create;
  FNavSessionIds := TStringList.Create;
  FNavSessionArchived := TStringList.Create;
  FCurrentSessionId := '';

  FSyntaxSchemes := TSyntaxSchemeRegistry.Create;
  FSyntaxSchemes.Load;

  mnuWorkspaceSepRules.Tag := -1;
  mnuWorkspaceProjectRules.Tag := -1;

  RegisterThemeCustomHooks;
  CreateThemedTabBars;
  InitWorkspaceSubControls;
  FPanelDetach := TPanelDetachManager.Create(Self, Self, FState);
  FPanelDetach.Bind(piNavigation, pnlNavHost, pnlNavContent);
  FPanelDetach.Bind(piChat, pnlChatHost, pgcCenter);
  FPanelDetach.Bind(piReserved, pnlReservedHost, pnlReservedContent);
  FPanelDetach.Bind(piUtility, pnlUtilityHost, pnlUtilityContent);
  PopulateMenusAndCombos;
end;

procedure TLazyCodingAgentForm.FormShow(Sender: TObject);
begin
  if FPendingInitialDockLayout then begin
    FPendingInitialDockLayout := False;
    ApplyDockPanelsLayout;
  end;
  if Assigned(FPanelDetach) then
    FPanelDetach.RaiseFloatingForms;
  SchedulePostShowStartup;
end;

procedure TLazyCodingAgentForm.SchedulePostShowStartup;
begin
  if FPostShowStartupScheduled then Exit;
  FPostShowStartupScheduled := True;
  FPostShowStartupTimer.Enabled := True;
end;

procedure TLazyCodingAgentForm.PostShowStartup(Sender: TObject);
begin
  FPostShowStartupTimer.Enabled := False;
  if csDestroying in ComponentState then Exit;
  if not HandleAllocated then Exit;

  if FDeferThemesUntilShown then begin
    FDeferThemesUntilShown := False;
    ApplyAllThemes;
  end;
  if FPendingInitialWorkspaceUI then begin
    FPendingInitialWorkspaceUI := False;
    if Trim(FRegistry.ActiveWorkspaceId) <> '' then
      ActivateWorkspace(FRegistry.ActiveWorkspaceId)
    else
      DeactivateWorkspace;
  end;
  if FState.IsPanelVisible(piTerminal) then
    ScheduleDeferredTerminalStart;
end;


procedure TLazyCodingAgentForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
begin
  CanClose := True;
  if not PromptDirtyEditor then begin
    CanClose := False;
    Exit;
  end;
  if Assigned(FSessionHubs) and FSessionHubs.AnyRunActive then begin
    if MessageDlg('One or more agent runs are still in progress. Stop all runs and exit?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then begin
      CanClose := False;
      Exit;
    end;
    FSessionHubs.ShutdownAll(True);
  end;
  if not Assigned(FState) then Exit;
  if Assigned(FSessionHubs) then
    for I := 0 to FSessionHubs.Count - 1 do
      FSessionHubs.HubAt(I).SaveAll;
  SaveCurrentSession;
  if Assigned(FRegistry) then
    FRegistry.Save;
  if Assigned(FTerminalPanel) then
    FTerminalPanel.Stop;
  if Assigned(FPanelDetach) then
    FPanelDetach.FinalizeOnClose;
end;

procedure TLazyCodingAgentForm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  FreeAndNil(FPanelDetach);
  FreeAndNil(FMarkdownPreview);
  FreeAndNil(FFileEditor);
  if Assigned(FSessionHubs) then begin
    for I := 0 to FSessionHubs.Count - 1 do
      FSessionHubs.HubAt(I).SaveAll;
  end;
  SaveCurrentSession;
  if Assigned(FRegistry) then begin
    FRegistry.Save;
    FreeAndNil(FRegistry);
  end;
  FreeAndNil(FSessionHubs);
  FreeAndNil(FNavWorkCaptions);
  FreeAndNil(FNavWorkIds);
  FreeAndNil(FNavSessionCaptions);
  FreeAndNil(FNavSessionIds);
  FreeAndNil(FNavSessionArchived);
  FreeAndNil(FSyntaxSchemes);

  if Assigned(FState) then begin
    FState.Save;
    FreeAndNil(FState);
  end;
end;




procedure TLazyCodingAgentForm.InitNavRailButtons;
begin
  FNavRailBtns[niHome] := sbtnNavHome;
  FNavRailBtns[niProjects] := sbtnNavProjects;
  FNavRailBtns[niSessions] := sbtnNavSessions;
  FNavRailBtns[niBots] := sbtnNavBots;
  FNavRailBtns[niTools] := sbtnNavTools;
  FNavRailBtns[niTasks] := sbtnNavTasks;
  FNavRailBtns[niToolErrors] := sbtnNavToolErrors;
  FNavRailBtns[niMultiAgent] := sbtnNavMultiAgent;
  FNavRailBtns[niExecutionPlans] := sbtnNavExecPlans;
  FNavRailBtns[niKnowledgeBase] := sbtnNavKnowledge;
  FNavRailBtns[niTheBrain] := sbtnNavBrain;
end;

procedure TLazyCodingAgentForm.NavRailBtnClick(Sender: TObject);
begin
  if Sender is TSpeedButton then
    FState.SetNavigation(TNavigationItem(TSpeedButton(Sender).Tag));
end;

procedure TLazyCodingAgentForm.UpdateNavRailSelection;
var
  Nav: TNavigationItem;
  Btn: TSpeedButton;
  P: TThemePalette;
begin
  P := ThemePalette(FState.Theme);
  for Nav := Low(TNavigationItem) to High(TNavigationItem) do begin
    Btn := FNavRailBtns[Nav];
    if not Assigned(Btn) then Continue;
    Btn.Down := Nav = FState.Navigation;
    if Nav = FState.Navigation then
      Btn.Font.Color := P.Accent
    else
      Btn.Font.Color := P.TextMuted;
  end;
end;

procedure TLazyCodingAgentForm.PanelHideClickAction(AId: TPanelId);
begin
  if Assigned(FPanelDetach) and FState.IsPanelFloating(AId) then
    FPanelDetach.AttachPanel(AId);
  FState.SetPanelVisible(AId, False);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.PanelHideClick(Sender: TObject);
begin
  if Sender is TControl then
    PanelHideClickAction(TPanelId(TControl(Sender).Tag));
end;

procedure TLazyCodingAgentForm.PanelDetachClick(Sender: TObject);
begin
  if not Assigned(FPanelDetach) then Exit;
  if Sender is TControl then
    FPanelDetach.ToggleDetach(TPanelId(TControl(Sender).Tag));
end;





procedure TLazyCodingAgentForm.ShowChatCenterTab;
begin
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsChat;
end;

procedure TLazyCodingAgentForm.CreateThemedTabBars;
begin
  if Assigned(pnlCenterTabStripHost) and not Assigned(FCenterTabBar) then begin
    FCenterTabBar := TThemedPageTabBar.Create(Self);
    FCenterTabBar.Parent := pnlCenterTabStripHost;
    FCenterTabBar.Align := alClient;
    FCenterTabBar.PageControl := pgcCenter;
    FCenterTabBar.ShowAddTab := True;
    FCenterTabBar.AddTabCaption := '[+]';
    FCenterTabBar.OnAddTab := @TabBarCenterAddTab;
    FCenterTabBar.OnTabClose := @TabBarCenterTabClose;
  end;
  if Assigned(pnlUtilityTabStripHost) and not Assigned(FUtilityTabBar) then begin
    FUtilityTabBar := TThemedPageTabBar.Create(Self);
    FUtilityTabBar.Parent := pnlUtilityTabStripHost;
    FUtilityTabBar.Align := alClient;
    FUtilityTabBar.PageControl := pgcUtility;
  end;
end;

procedure TLazyCodingAgentForm.InitCenterTabStrip;
begin
  TThemedPageTabBar.SetTabAllowsClose(tsEditor, True);
  TThemedPageTabBar.SetTabAllowsClose(tsMarkdown, True);
  TThemedPageTabBar.SetTabHidden(tsEditor, True);
  TThemedPageTabBar.SetTabHidden(tsMarkdown, True);
  if Assigned(FCenterTabBar) then
    FCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.SyncCenterAddTabNav;
begin
  if Assigned(FNavContent) then
    FNavContent.SetCenterAddTabAvailable(FState.IsPanelVisible(piChat));
end;

procedure TLazyCodingAgentForm.TabBarCenterAddTab(Sender: TObject);
begin
  CreateAndSelectNewSession;
end;

procedure TLazyCodingAgentForm.TabBarCenterTabClose(Sender: TObject; TabSheet: TTabSheet;
  var AllowClose: Boolean);
begin
  AllowClose := False;
  if TabSheet = tsEditor then begin
    if not PromptDirtyEditor then Exit;
    if Assigned(FFileEditor) then
      FFileEditor.Clear;
    TThemedPageTabBar.SetTabHidden(tsEditor, True);
    AllowClose := True;
    ShowChatCenterTab;
  end else if TabSheet = tsMarkdown then begin
    FMarkdownPath := '';
    if Assigned(FMarkdownPreview) then
      FMarkdownPreview.SetMarkdown('');
    TThemedPageTabBar.SetTabHidden(tsMarkdown, True);
    AllowClose := True;
    ShowChatCenterTab;
  end;
  if Assigned(FCenterTabBar) then
    FCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.InitWorkspaceSubControls;
begin
  lblNavTitle.Caption := PanelCaption(piNavigation);
  lblReservedTitle.Caption := PanelCaption(piReserved);
  lblTerminalTitle.Caption := PanelCaption(piTerminal);
  InitCenterTabStrip;

  if memReserved.Lines.Count = 0 then begin
    memReserved.Lines.Add('=== Workspace Context & Guidelines ===');
    memReserved.Lines.Add('');
    memReserved.Lines.Add('• Follow single responsibility principles.');
    memReserved.Lines.Add('• Visual Form Designer first with modern styling.');
    memReserved.Lines.Add('• Dark-first modern design across all platforms.');
    memReserved.Lines.Add('• Cross-platform Free Pascal / LCL target.');
    memReserved.Lines.Add('• Autonomous tool execution with live logging.');
  end;

  InitNavRailButtons;

  FNavContent := TNavContentControl.Create(Self);
  FNavContent.Bind(lblNavViewTitle, lblNavViewSub, lstNavFile, tvNavProjects, lstNavLog,
    lstNavErrors, btnNavPrimary, btnNavSecondary);
  FNavContent.OnWorkspaceSelect := @NavWorkspaceSelect;
  FNavContent.OnWorkspaceNew := @NavWorkspaceNew;
  FNavContent.OnWorkspaceDelete := @NavWorkspaceDelete;
  FNavContent.OnSessionSelect := @NavSessionSelect;
  FNavContent.OnSessionNew := @NavSessionNew;
  FNavContent.OnSessionArchive := @NavSessionArchive;
  FNavContent.OnSessionRestore := @NavSessionRestore;
  FNavContent.OnSessionDelete := @NavSessionDelete;
  FNavContent.OnFileOpen := @NavFileOpen;
  FNavContent.OnLogEntrySelected := @NavLogEntrySelected;
  FNavContent.OnClearExecutionLog := @NavClearExecutionLog;
  FNavContent.OnToolErrorEntrySelected := @NavToolErrorEntrySelected;
  FNavContent.OnClearToolErrorLog := @NavClearToolErrorLog;
  FNavContent.OnTasksRefresh := @NavTasksRefresh;

  FChatPanel := TChatPanel.Create(Self);
  FChatPanel.Bind(lblChatHeading, lblChatSub, lblChatSession, pnlChatHistoryHost, memChatPrompt,
    lblChatWorkspaceTag, cboChatMode, cboChatModel, btnChatSend, btnChatStop);
  FChatPanel.OnPrompt := @ChatPrompt;
  FChatPanel.OnModeChange := @ChatModeChange;
  FChatPanel.OnModelChange := @ChatModelChange;
  FChatPanel.OnCancel := @ChatCancel;

  FFileEditor := TMainFileEditor.Create(synEditor, Self);
  FPlanView := TPlanView.Create(Self);
  FPlanView.Bind(lblPlanPath, cboPlanModel, btnPlanBuild, memPlanBody);
  FPlanView.OnBuild := @PlanBuildRequested;

  FTerminalPanel := TTerminalPanel.Create(Self);
  FTerminalPanel.Bind(pnlTerminalContent, lblTerminalStatus);
  FTerminalPanel.OnTerminalStatus := @TerminalStatus;

  ConfigureThemedMemo(memUtilityScratch, FState.Theme);
  ConfigureThemedMemo(memUtilityExecDetail, FState.Theme, 'Consolas');
  if not Assigned(FMarkdownPreview) then
    FMarkdownPreview := TMarkdownHtmlView.Create(Self, pnlMarkdownPreviewHost);
  FMarkdownPreview.ApplyTheme(FState.Theme);

  FTerminalRetryTimer := TTimer.Create(Self);
  FTerminalRetryTimer.Enabled := False;
  FTerminalRetryTimer.Interval := 150;
  FTerminalRetryTimer.OnTimer := @TerminalRetryTimer;

  FCurrentRunMode := wmAgent;
  FPlanSavedThisRun := False;
  FMarkdownPath := '';
end;

procedure TLazyCodingAgentForm.PopulateMenusAndCombos;
var
  Nav: TNavigationItem;
  SubItem: TMenuItem;
  I: Integer;
begin
  // Remove dynamic navigation entries; keep designer-defined items (separator, rules).
  I := 0;
  while I < mnuWorkspace.Count do begin
    if ((mnuWorkspace.Items[I].Tag >= Ord(Low(TNavigationItem))) and
        (mnuWorkspace.Items[I].Tag <= Ord(High(TNavigationItem)))) or
       (mnuWorkspace.Items[I].Tag = -2) or (mnuWorkspace.Items[I].Tag = -3) then
      mnuWorkspace.Delete(I)
    else
      Inc(I);
  end;

  for Nav := High(TNavigationItem) downto Low(TNavigationItem) do begin
    if Nav = NavigationFutureFeatureFirst then begin
      SubItem := TMenuItem.Create(mnuWorkspace);
      SubItem.Caption := '-';
      SubItem.Tag := -2;
      mnuWorkspace.Insert(0, SubItem);
      SubItem := TMenuItem.Create(mnuWorkspace);
      SubItem.Caption := 'Future Features';
      SubItem.Enabled := False;
      SubItem.Tag := -3;
      mnuWorkspace.Insert(0, SubItem);
    end;
    SubItem := TMenuItem.Create(mnuWorkspace);
    SubItem.Caption := NavigationCaption(Nav);
    SubItem.Hint := NavigationHint(Nav);
    SubItem.Tag := Ord(Nav);
    SubItem.OnClick := @MenuSelectNav;
    mnuWorkspace.Insert(0, SubItem);
  end;

  RebuildWindowMenu;
  RebuildActiveSchemeMenu;
end;


procedure TLazyCodingAgentForm.ApplyDockPanelsLayout;
begin
  pnlNavHost.Visible := FState.IsPanelVisible(piNavigation) and
    not FState.IsPanelFloating(piNavigation);
  splNav.Visible := pnlNavHost.Visible;
  pnlChatHost.Visible := FState.IsPanelVisible(piChat) and
    not FState.IsPanelFloating(piChat);
  pnlReservedHost.Visible := FState.IsPanelVisible(piReserved) and
    not FState.IsPanelFloating(piReserved);
  splReserved.Visible := pnlReservedHost.Visible;
  pnlUtilityHost.Visible := FState.IsPanelVisible(piUtility) and
    not FState.IsPanelFloating(piUtility);
  splUtility.Visible := pnlUtilityHost.Visible;

  pnlTerminalHost.Visible := FState.IsPanelVisible(piTerminal);
  splTerminal.Visible := pnlTerminalHost.Visible;
  if Assigned(FPanelDetach) then
    FPanelDetach.ApplyLayout;
  if pnlTerminalHost.Visible then
    pnlTerminalHost.Height := EffectiveTerminalDockHeight;

  if FState.IsPanelVisible(piTerminal) and not FDeferThemesUntilShown
     and not FPendingInitialWorkspaceUI then
    ScheduleDeferredTerminalStart;
  SyncCenterAddTabNav;
end;

function TLazyCodingAgentForm.EffectiveTerminalDockHeight: Integer;
var
  Available, DefaultH, MaxDock, Saved: Integer;
begin
  Available := ClientHeight - StatusBar1.Height;
  if Available < splTerminal.MinSize + 80 then
    Available := splTerminal.MinSize + 80;
  DefaultH := Available div 4;
  if DefaultH < splTerminal.MinSize then
    DefaultH := splTerminal.MinSize;
  MaxDock := Available div 2;
  if MaxDock < DefaultH then
    MaxDock := DefaultH;
  Saved := FState.GetPanelDockedHeight(piTerminal);
  if (Saved >= splTerminal.MinSize) and (Saved <= MaxDock) then
    Result := Saved
  else
    Result := DefaultH;
end;

procedure TLazyCodingAgentForm.ScheduleDeferredTerminalStart;
begin
  if FTerminalStartQueued then Exit;
  if not FState.IsPanelVisible(piTerminal) then Exit;
  FTerminalStartQueued := True;
  Application.QueueAsyncCall(@DeferredEnsureTerminal, 0);
end;

procedure TLazyCodingAgentForm.DeferredEnsureTerminal(Data: PtrInt);
begin
  FTerminalStartQueued := False;
  if not Assigned(FTerminalPanel) then Exit;
  if not IsTerminalSurfaceVisible then Exit;
  SyncTerminalWorkingDirectory;
  if not FTerminalPanel.EnsureRunning then
    ScheduleTerminalStartRetry
  else
    FTerminalRetryTimer.Enabled := False;
end;

function TLazyCodingAgentForm.IsTerminalSurfaceVisible: Boolean;
begin
  if not FState.IsPanelVisible(piTerminal) then
    Exit(False);
  if not Assigned(FTerminalPanel) then
    Exit(False);
  Result := pnlTerminalHost.Visible;
end;

procedure TLazyCodingAgentForm.ScheduleTerminalStartRetry;
begin
  if not Assigned(FTerminalRetryTimer) then Exit;
  FTerminalRetryCount := 0;
  FTerminalRetryTimer.Enabled := True;
end;

procedure TLazyCodingAgentForm.TerminalRetryTimer(Sender: TObject);
begin
  if not Assigned(FTerminalPanel) then begin
    FTerminalRetryTimer.Enabled := False;
    Exit;
  end;
  Inc(FTerminalRetryCount);
  if FTerminalRetryCount > 3 then begin
    FTerminalRetryTimer.Enabled := False;
    Exit;
  end;
  if not IsTerminalSurfaceVisible then
    Exit;
  SyncTerminalWorkingDirectory;
  if FTerminalPanel.EnsureRunning then
    FTerminalRetryTimer.Enabled := False;
end;

procedure TLazyCodingAgentForm.TerminalStatus(Sender: TObject; const AMessage: string);
begin
  if Trim(AMessage) <> '' then
    StatusBar1.SimpleText := AMessage;
end;

procedure TLazyCodingAgentForm.SyncTerminalWorkingDirectory;
begin
  if not Assigned(FTerminalPanel) then Exit;
  if FState.HasActiveWorkspace then
    FTerminalPanel.SetWorkingDirectory(FState.WorkspaceRoot)
  else
    FTerminalPanel.SetWorkingDirectory('');
end;


procedure TLazyCodingAgentForm.StateChanged(Sender: TObject);
var
  I, N: Integer;
  Models: array of TSavedModel;
  WsLabel: string;
begin
  if FUpdatingState then Exit;
  if FPendingInitialWorkspaceUI then Exit;
  FUpdatingState := True;
  try
    if FState.HasActiveWorkspace then
      EnsureActiveHub;
    if Assigned(FActiveHub) then
      SyncHubClientSettings(FActiveHub);
    for I := 0 to FSessionHubs.Count - 1 do begin
      if Assigned(FSessionHubs.HubAt(I)) then
        SyncHubClientSettings(FSessionHubs.HubAt(I));
    end;

    UpdateNavRailSelection;
    if Assigned(FNavContent) then begin
      RefreshWorkspaceNav;
      RefreshSessionNav;
      FNavContent.SetSelected(FState.Navigation, FState.WorkspaceName, FState.WorkspaceRoot);
      FNavContent.SetWorkspaceList(FNavWorkCaptions, FNavWorkIds, FState.ActiveWorkspaceId);
      FNavContent.SetSessionList(FNavSessionCaptions, FNavSessionIds, FNavSessionArchived,
        FCurrentSessionId);
    end;

    UpdateSessionCaption;
    ApplyWorkspaceChatVisibility;

    if Assigned(FChatPanel) then begin
      N := FState.SavedModelCount(FState.Provider);
      SetLength(Models, N);
      for I := 0 to N - 1 do
        Models[I] := FState.GetSavedModel(FState.Provider, I);
      FChatPanel.SetAvailableModels(Models);
      FChatPanel.SetWorkspace(FState.WorkspaceName);
      FChatPanel.SetMode(FState.Mode);
      FChatPanel.SetModel(FState.Model);
      ApplySessionComposerState;
      RefreshPlanViewModels(Models);
    end;

    if not FPendingInitialDockLayout then
      ApplyDockPanelsLayout;

    if not FDeferThemesUntilShown then
      ApplyAllThemes;
    RebuildWindowMenu;
    if Assigned(mnuViewTerminal) then
      mnuViewTerminal.Checked := FState.IsPanelVisible(piTerminal);

    if FState.HasActiveWorkspace then
      WsLabel := FState.WorkspaceName
    else
      WsLabel := '(none)';
    if Assigned(ActiveAgent) then
      StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
        [WsLabel, WorkspaceModeCaption(FState.Mode), FState.Model, AgentStateToString(ActiveAgent.State)])
    else
      StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s',
        [WsLabel, WorkspaceModeCaption(FState.Mode), FState.Model]);
  finally
    FUpdatingState := False;
  end;
end;

procedure TLazyCodingAgentForm.ApplyAllThemes;
var
  P: TThemePalette;
begin
  if not HandleAllocated then Exit;
  P := ThemePalette(FState.Theme);

  Color := P.Background;
  Font.Color := P.Text;
  pnlMainContainer.Color := P.Background;

  pnlNavRailHost.Color := P.RailBg;
  pnlNavHost.Color := P.Surface;
  pnlChatHost.Color := P.Background;
  pnlReservedHost.Color := P.Surface;
  pnlUtilityHost.Color := P.Surface;
  pnlTerminalHost.Color := P.Surface;

  splNav.Color := P.Border;
  splReserved.Color := P.Border;
  splUtility.Color := P.Border;
  splTerminal.Color := P.Border;

  StatusBar1.Color := P.Surface;
  StatusBar1.Font.Color := P.TextMuted;

  pnlNavChrome.Color := P.HeaderBg;
  pnlNavChrome.Font.Color := P.Text;
  pnlChatChrome.Color := P.HeaderBg;
  pnlReservedChrome.Color := P.HeaderBg;
  pnlUtilityChrome.Color := P.HeaderBg;
  pnlTerminalChrome.Color := P.HeaderBg;

  ApplyThemedControlTree(pnlMainContainer, FState.Theme);
  StyleCancelButton(btnNavDetach, FState.Theme);
  StyleCancelButton(btnNavHide, FState.Theme);
  StyleCancelButton(btnChatDetach, FState.Theme);
  StyleCancelButton(btnChatHide, FState.Theme);
  StyleCancelButton(btnReservedDetach, FState.Theme);
  StyleCancelButton(btnReservedHide, FState.Theme);
  StyleCancelButton(btnUtilityDetach, FState.Theme);
  StyleCancelButton(btnUtilityHide, FState.Theme);
  StyleCancelButton(btnTerminalHide, FState.Theme);
  if Assigned(FPanelDetach) then
    FPanelDetach.ApplyThemes(FState.Theme);

  if Assigned(FNavContent) then FNavContent.ApplyTheme(FState.Theme);
  if Assigned(FChatPanel) then FChatPanel.ApplyTheme(FState.Theme);
  if Assigned(FTerminalPanel) then FTerminalPanel.ApplyTheme(FState.Theme);
  if Assigned(FPlanView) then FPlanView.ApplyTheme(FState.Theme);
  if Assigned(FCenterTabBar) then FCenterTabBar.ApplyTheme(FState.Theme);
  if Assigned(FUtilityTabBar) then FUtilityTabBar.ApplyTheme(FState.Theme);
  if not Assigned(FMarkdownPreview) then
    FMarkdownPreview := TMarkdownHtmlView.Create(Self, pnlMarkdownPreviewHost);
  FMarkdownPreview.ApplyTheme(FState.Theme);
  ApplyEditorTheme;

  UpdateNavRailSelection;
  ApplyPlatformChromeThemes;
  Invalidate;
end;

procedure TLazyCodingAgentForm.ApplyPlatformChromeThemes;
begin
  if not HandleAllocated then Exit;
  ApplyPlatformChrome(Self, FState.Theme);
  if Assigned(memReserved) then
    ApplyPlatformScrollableTheme(memReserved, FState.Theme);
  if Assigned(FNavContent) then
    FNavContent.ApplyPlatformChrome(FState.Theme);
  if Assigned(FChatPanel) then
    FChatPanel.ApplyPlatformChrome(FState.Theme);
end;

procedure TLazyCodingAgentForm.RebuildWindowMenu;
var
  P: TPanelId;
  Item, SubItem: TMenuItem;
begin
  mnuPanelsVisibility.Clear;
  for P := Low(TPanelId) to High(TPanelId) do begin
    Item := TMenuItem.Create(mnuPanelsVisibility);
    Item.Caption := PanelCaption(P);
    Item.Checked := FState.IsPanelVisible(P);
    Item.Tag := Ord(P);
    Item.OnClick := @MenuTogglePanel;
    mnuPanelsVisibility.Add(Item);
  end;

  ApplyPlatformChrome(Self, FState.Theme);
end;


procedure TLazyCodingAgentForm.ChatPrompt(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string);
var
  Info: TChatSessionInfo;
  Eng: TAgentEngine;
begin
  if not FState.HasActiveWorkspace then Exit;
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, Info) and Info.Archived then
    Exit;
  FCurrentRunMode := AMode;
  FPlanSavedThisRun := False;
  Eng := ActiveAgent;
  if not Assigned(Eng) then Exit;
  FChatPanel.SetRunning(True);
  if not Eng.StartRunAsync(APrompt, AMode, AModel) then
    FChatPanel.SetRunning(False);
end;

procedure TLazyCodingAgentForm.ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
begin
  FState.SetMode(AMode);
end;

procedure TLazyCodingAgentForm.ChatModelChange(Sender: TObject; const AModel: string);
begin
  FState.SetModel(AModel);
end;

procedure TLazyCodingAgentForm.ChatCancel(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then begin
    Eng.RequestCancel;
    StatusBar1.SimpleText := StatusBar1.SimpleText + '  |  Stopping after current step…';
  end;
end;

procedure TLazyCodingAgentForm.HubStateChange(Sender: TObject; const ASessionId: string;
  AOldState, ANewState: TAgentState);
begin
  if SameText(ASessionId, FCurrentSessionId) then begin
    StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
      [FState.WorkspaceName, WorkspaceModeCaption(FState.Mode), FState.Model, AgentStateToString(ANewState)]);
    if (ANewState = asFinished) and (FCurrentRunMode = wmPlan) and not FPlanSavedThisRun then
      TrySaveProposedPlanFromChat;
    if (ANewState in [asIdle, asFinished, asError]) and Assigned(FChatPanel) then
      FChatPanel.SetRunning(False);
  end;
  if AgentStateIsRunning(AOldState) <> AgentStateIsRunning(ANewState) then
    UpdateSessionCaption;
end;

procedure TLazyCodingAgentForm.HubMessageAdded(Sender: TObject; const ASessionId: string;
  const AMsg: TChatMessage);
begin
  if SameText(ASessionId, FCurrentSessionId) and Assigned(FChatPanel) then begin
    if AMsg.Role = crTool then
      FChatPanel.AppendToolMessage(AMsg, FState.DebuggingMode)
    else
      FChatPanel.AppendMessage(AMsg);
  end;
end;

procedure TLazyCodingAgentForm.HubToolCall(Sender: TObject; const ASessionId: string;
  const AToolName, AArgs: string);
begin
  // Tool lines are recorded in execution log on tool result (combined input/output).
end;

procedure TLazyCodingAgentForm.HubToolResult(Sender: TObject; const ASessionId: string;
  const AToolName, AArgsJson: string; const AResult: TToolExecutionResult);
var
  PlanPath, PlanContent: string;
begin
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if SameText(AToolName, 'create_plan_file') then begin
    if ParsePlanToolSuccess(AResult, PlanPath, PlanContent) and (FCurrentRunMode = wmPlan) then begin
      FPlanSavedThisRun := True;
      OpenPlanInUtilityTab(PlanPath, PlanContent);
    end;
  end;
  if SameText(AToolName, 'todo') or SameText(AToolName, 'plan') then
    RefreshNavTaskList;
end;

procedure TLazyCodingAgentForm.NavTasksRefresh(Sender: TObject);
begin
  RefreshNavTaskList;
end;

procedure TLazyCodingAgentForm.RefreshNavTaskList;
var
  Caps: TStringList;
  Tasks: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  ID, TaskText, Status, Line: string;
  Eng: TAgentEngine;
begin
  if not Assigned(FNavContent) then Exit;
  Caps := TStringList.Create;
  try
    Eng := ActiveAgent;
    if Assigned(Eng) then begin
      Tasks := Eng.Context.Session.Tasks;
      for I := 0 to Tasks.Count - 1 do begin
        if not (Tasks[I] is TJSONObject) then Continue;
        Item := TJSONObject(Tasks[I]);
        ID := Item.Get('id', '');
        TaskText := Item.Get('text', '');
        Status := Item.Get('status', '');
        if Status = 'completed' then
          Line := '✔ '
        else if Status = 'in_progress' then
          Line := '⏳ '
        else
          Line := '○ ';
        Line := Line + ID + '. ' + TaskText;
        if Status <> '' then
          Line := Line + ' [' + Status + ']';
        Caps.Add(Line);
      end;
    end;
    FNavContent.UpdateSessionTasks(Caps);
  finally
    Caps.Free;
  end;
end;

procedure TLazyCodingAgentForm.HubExecutionLogAdded(Sender: TObject; const ASessionId: string;
  AEntryIndex: Integer);
begin
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if Assigned(FNavContent) then
    FNavContent.AppendExecutionLogEntry(AEntryIndex);
end;

procedure TLazyCodingAgentForm.NavLogEntrySelected(Sender: TObject; AIndex: Integer);
var
  Log: TAgentExecutionLog;
  Entry: TExecutionLogEntry;
begin
  Log := nil;
  if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
    Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
  if (Log = nil) or (AIndex < 0) or (AIndex >= Log.Count) then Exit;
  Entry := Log.Entry(AIndex);
  memUtilityExecDetail.Lines.Text := Entry.BuildInspectorText;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  if Assigned(pgcUtility) then
    pgcUtility.ActivePage := tsUtilityExecDetail;
end;

procedure TLazyCodingAgentForm.NavClearExecutionLog(Sender: TObject);
var
  Log: TAgentExecutionLog;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then Exit;
  Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
  if Assigned(Log) then
    Log.Clear;
  if Assigned(FNavContent) then
    FNavContent.RefreshExecutionLogList;
  memUtilityExecDetail.Clear;
end;

procedure TLazyCodingAgentForm.HubToolErrorAdded(Sender: TObject; const ASessionId: string;
  AEntryIndex: Integer);
begin
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if Assigned(FNavContent) then
    FNavContent.AppendToolErrorLogEntry(AEntryIndex);
end;

procedure TLazyCodingAgentForm.NavToolErrorEntrySelected(Sender: TObject; AIndex: Integer);
var
  Log: TAgentToolErrorLog;
  Entry: TToolErrorLogEntry;
begin
  Log := nil;
  if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
    Log := FActiveHub.ToolErrorLogFor(FCurrentSessionId);
  if (Log = nil) or (AIndex < 0) or (AIndex >= Log.Count) then Exit;
  Entry := Log.Entry(AIndex);
  memUtilityExecDetail.Lines.Text := Entry.BuildInspectorText;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  if Assigned(pgcUtility) then
    pgcUtility.ActivePage := tsUtilityExecDetail;
end;

procedure TLazyCodingAgentForm.NavClearToolErrorLog(Sender: TObject);
var
  Log: TAgentToolErrorLog;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then Exit;
  Log := FActiveHub.ToolErrorLogFor(FCurrentSessionId);
  if Assigned(Log) then
    Log.Clear;
  if Assigned(FNavContent) then
    FNavContent.RefreshToolErrorLogList;
  memUtilityExecDetail.Clear;
end;

function TLazyCodingAgentForm.ParsePlanToolSuccess(const AResult: TToolExecutionResult;
  out APath, AContent: string): Boolean;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := False;
  APath := '';
  AContent := '';
  if not AResult.Success then Exit;
  try
    Data := GetJSON(AResult.Output);
    try
      if Data is TJSONObject then begin
        Obj := TJSONObject(Data);
        if SameText(Obj.Get('status', ''), 'success') then begin
          APath := Obj.Get('path', '');
          AContent := Obj.Get('content', '');
          Result := (APath <> '') and (AContent <> '');
        end;
      end;
    finally
      Data.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TLazyCodingAgentForm.OpenPlanInUtilityTab(const APath, AContent: string);
var
  I: Integer;
  Models: array of TSavedModel;
begin
  if not Assigned(FPlanView) then Exit;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  FPlanView.LoadPlan(APath, AContent);
  SetLength(Models, FState.SavedModelCount(FState.Provider));
  for I := 0 to High(Models) do
    Models[I] := FState.GetSavedModel(FState.Provider, I);
  FPlanView.SetAvailableModels(Models);
  if Assigned(FChatPanel) and (FChatPanel.Model <> '') then
    FPlanView.SetModel(FChatPanel.Model)
  else
    FPlanView.SetModel(FState.Model);
  FPlanView.ApplyTheme(FState.Theme);
  if Assigned(pgcUtility) then
    pgcUtility.ActivePage := tsUtilityPlan;
end;

procedure TLazyCodingAgentForm.TrySaveProposedPlanFromChat;
var
  I, PlanStart, PlanEnd: Integer;
  Msg: TChatMessage;
  PlanContent, PlanPath: string;
  Args: TJSONObject;
  Res: TToolExecutionResult;
begin
  if FPlanSavedThisRun then Exit;
  if not Assigned(ActiveAgent) then Exit;
  for I := ActiveAgent.GetMessageCount - 1 downto 0 do begin
    Msg := ActiveAgent.GetMessage(I);
    if Msg.Role <> crAssistant then Continue;
    PlanStart := Pos('<proposed_plan>', Msg.Content);
    PlanEnd := Pos('</proposed_plan>', Msg.Content);
    if (PlanStart <= 0) or (PlanEnd <= PlanStart) then Exit;
    PlanContent := Trim(Copy(Msg.Content, PlanStart + Length('<proposed_plan>'),
      PlanEnd - PlanStart - Length('<proposed_plan>')));
    if PlanContent = '' then Exit;
    Args := TJSONObject.Create;
    try
      Args.Add('content', PlanContent);
      Res := ActiveAgent.ExecuteToolDirect('create_plan_file', Args.AsJSON, wmPlan);
    finally
      Args.Free;
    end;
    if ParsePlanToolSuccess(Res, PlanPath, PlanContent) then begin
      FPlanSavedThisRun := True;
      OpenPlanInUtilityTab(PlanPath, PlanContent);
    end;
    Exit;
  end;
end;

procedure TLazyCodingAgentForm.PlanBuildRequested(Sender: TObject; const APlanPath,
  APlanContent, AModelId: string);
var
  Prompt, Sid, Title: string;
begin
  if not FState.HasActiveWorkspace then Exit;
  if not Assigned(FChatPanel) then Exit;
  if Trim(AModelId) = '' then Exit;

  FState.SetModel(AModelId);
  FState.SetMode(wmAgent);

  SaveCurrentSession;
  EnsureActiveHub;
  Title := 'Build ' + ExtractFileName(APlanPath);
  if SameText(Trim(Title), 'Build') then
    Title := 'Build plan';
  Sid := ActiveStore.CreateSession(Title);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, Sid);
  FRegistry.Save;
  FCurrentSessionId := Sid;
  ActiveStore.SetLastSessionId(Sid);
  FActiveHub.GetOrCreateEngine(Sid);
  BindSessionToUI(Sid);
  UpdateSessionCaption;

  ShowChatCenterTab;
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;

  FChatPanel.SetMode(wmAgent);
  FChatPanel.SetModel(AModelId);

  Prompt := 'Implement the plan saved at ' + APlanPath +
    '. First inspect the project files, then carry out the plan completely.' +
    LineEnding + LineEnding + APlanContent;
  FChatPanel.SubmitPrompt(Prompt);
  StateChanged(Self);
end;


procedure TLazyCodingAgentForm.RefreshPlanViewModels(const AModels: array of TSavedModel);
begin
  if Assigned(FPlanView) then
    FPlanView.SetAvailableModels(AModels);
end;

procedure TLazyCodingAgentForm.MenuSelectNav(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetNavigation(TNavigationItem(TMenuItem(Sender).Tag));
end;

procedure TLazyCodingAgentForm.MenuSelectMode(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetMode(TWorkspaceMode(TMenuItem(Sender).Tag));
end;

procedure TLazyCodingAgentForm.MenuTogglePanel(Sender: TObject);
var
  P: TPanelId;
begin
  if Sender is TMenuItem then begin
    P := TPanelId(TMenuItem(Sender).Tag);
    FState.SetPanelVisible(P, not FState.IsPanelVisible(P));
  end;
end;



procedure TLazyCodingAgentForm.MnuViewToggleThemeClick(Sender: TObject);
begin
  if FState.Theme = tkDark then
    FState.SetTheme(tkLight)
  else
    FState.SetTheme(tkDark);
end;

procedure TLazyCodingAgentForm.MnuViewResetLayoutClick(Sender: TObject);
begin
  FState.ResetLayout;
end;

procedure TLazyCodingAgentForm.MnuViewTerminalClick(Sender: TObject);
begin
  FState.SetPanelVisible(piTerminal, not FState.IsPanelVisible(piTerminal));
end;

procedure TLazyCodingAgentForm.SplTerminalMoved(Sender: TObject);
begin
  if FState.IsPanelVisible(piTerminal) then
    FState.SetPanelDockedHeight(piTerminal, pnlTerminalHost.Height);
end;

procedure TLazyCodingAgentForm.MnuFileNewClick(Sender: TObject);
var
  WsName, Path: string;
  Entry: TWorkspaceEntry;
begin
  if not TNewWorkspaceForm.Execute(Self, FState.Theme, FRegistry, WsName, Path) then Exit;
  if FRegistry.FindByPath(Path, Entry) then
    ActivateWorkspace(Entry.Id)
  else
    AddOrActivateFolder(WsName, Path);
end;

procedure TLazyCodingAgentForm.MnuFileOpenClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := FState.WorkspaceRoot;
  if Dir = '' then
    Dir := GetUserDir;
  if SelectDirectory('Open project folder', '', Dir) then
    AddOrActivateFolder(ExtractFileName(Dir), Dir);
end;

procedure TLazyCodingAgentForm.MnuFileSaveClick(Sender: TObject);
begin
  SaveCurrentSession;
  FRegistry.Save;
  FState.Save;
  ShowMessage('Workspace configuration saved.');
end;

procedure TLazyCodingAgentForm.MnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TLazyCodingAgentForm.MnuAgentClearHistoryClick(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then
    Eng.ClearConversation;
  if Assigned(FChatPanel) then
    FChatPanel.ClearHistory;
  SaveCurrentSession;
end;

procedure TLazyCodingAgentForm.MnuAgentStopClick(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then
    Eng.RequestCancel;
end;

procedure TLazyCodingAgentForm.MnuSettingsOptionsClick(Sender: TObject);
begin
  if TSettingsForm.Execute(FState, FRegistry) then begin
    FRegistry.Save;
    StateChanged(Self);
  end;
end;

procedure TLazyCodingAgentForm.MnuWorkspaceProjectRulesClick(Sender: TObject);
begin
  if Trim(FState.WorkspaceRoot) = '' then begin
    ShowMessage('Set a workspace project folder first (Settings or File → Open Project Folder).');
    Exit;
  end;
  TWorkspaceRulesForm.Execute(Self, FState.Theme, FState.WorkspaceRoot);
end;

procedure TLazyCodingAgentForm.MnuHelpUserGuideClick(Sender: TObject);
begin
  THelpForm.ShowGuide(Self, FState.Theme);
end;

procedure TLazyCodingAgentForm.MnuHelpAboutClick(Sender: TObject);
begin
  ShowMessage('LazyCodingAgent v1.0'#13#10 +
              'Standalone Desktop AI Coding Assistant'#13#10 +
              'Built with Free Pascal & Lazarus LCL');
end;

procedure TLazyCodingAgentForm.ApplyWorkspaceChatVisibility;
begin
  if FState.HasActiveWorkspace then
    FState.SetPanelVisible(piChat, True)
  else
    FState.SetPanelVisible(piChat, False);
end;

procedure TLazyCodingAgentForm.RefreshWorkspaceNav;
var
  I: Integer;
  E: TWorkspaceEntry;
  Cap: string;
begin
  FNavWorkCaptions.Clear;
  FNavWorkIds.Clear;
  for I := 0 to FRegistry.Count - 1 do begin
    E := FRegistry.GetEntry(I);
    if SameText(E.Id, FState.ActiveWorkspaceId) then
      Cap := '● ' + E.DisplayName
    else
      Cap := '  ' + E.DisplayName;
    FNavWorkCaptions.Add(Cap);
    FNavWorkIds.Add(E.Id);
  end;
end;

procedure TLazyCodingAgentForm.RefreshSessionNav;
var
  I: Integer;
  S: TChatSessionInfo;
  Cap: string;
  Store: TChatSessionStore;
  HasArchived: Boolean;
begin
  FNavSessionCaptions.Clear;
  FNavSessionIds.Clear;
  FNavSessionArchived.Clear;
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  Store := ActiveStore;
  HasArchived := False;
  for I := 0 to Store.SessionCount - 1 do begin
    S := Store.GetSessionInfo(I);
    if S.Archived then begin
      HasArchived := True;
      Continue;
    end;
    Cap := S.Title;
    if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(S.Id) then
      Cap := '⏳ ' + Cap;
    if SameText(S.Id, FCurrentSessionId) then
      Cap := '● ' + Cap
    else
      Cap := '  ' + Cap;
    FNavSessionCaptions.Add(Cap);
    FNavSessionIds.Add(S.Id);
    FNavSessionArchived.Add('0');
  end;
  if HasArchived then begin
    FNavSessionCaptions.Add('── Archived ──');
    FNavSessionIds.Add('');
    FNavSessionArchived.Add('0');
    for I := 0 to Store.SessionCount - 1 do begin
      S := Store.GetSessionInfo(I);
      if not S.Archived then Continue;
      Cap := '📦 ' + S.Title;
      if SameText(S.Id, FCurrentSessionId) then
        Cap := '● ' + Cap;
      FNavSessionCaptions.Add(Cap);
      FNavSessionIds.Add(S.Id);
      FNavSessionArchived.Add('1');
    end;
  end;
end;

procedure TLazyCodingAgentForm.SaveCurrentSession;
begin
  if not FState.HasActiveWorkspace then Exit;
  if FCurrentSessionId = '' then Exit;
  if Assigned(FActiveHub) then
    FActiveHub.SaveSessionToStore(FCurrentSessionId);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, FCurrentSessionId);
end;

function TLazyCodingAgentForm.AddOrActivateFolder(const ADisplayName, AFolderPath: string): Boolean;
var
  Id: string;
  Entry: TWorkspaceEntry;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  if (Norm = '') or not DirectoryExists(Norm) then
    Exit(False);
  if FRegistry.FindByPath(Norm, Entry) then
    Id := Entry.Id
  else
    Id := FRegistry.AddWorkspace(ADisplayName, Norm);
  FRegistry.Save;
  ActivateWorkspace(Id);
  Result := True;
end;

procedure TLazyCodingAgentForm.ActivateWorkspace(const AWorkspaceId: string);
var
  Entry: TWorkspaceEntry;
  Sid: string;
begin
  if not FRegistry.FindById(AWorkspaceId, Entry) then begin
    DeactivateWorkspace;
    Exit;
  end;
  if not DirectoryExists(Entry.FolderPath) then begin
    MessageDlg('Workspace folder is missing: ' + Entry.FolderPath, mtWarning, [mbOK], 0);
    DeactivateWorkspace;
    Exit;
  end;

  if FState.HasActiveWorkspace and not SameText(FState.ActiveWorkspaceId, AWorkspaceId) then begin
    if Assigned(FActiveHub) then
      FActiveHub.SaveAll;
    FActiveHub := nil;
  end;

  FState.ActiveWorkspaceId := Entry.Id;
  FState.WorkspaceName := Entry.DisplayName;
  FState.WorkspaceRoot := Entry.FolderPath;
  FRegistry.ActiveWorkspaceId := Entry.Id;
  FRegistry.Save;

  EnsureActiveHub;
  FCurrentSessionId := Entry.LastSessionId;
  if FCurrentSessionId = '' then
    FCurrentSessionId := ActiveStore.GetLastSessionId;

  if ActiveStore.SessionCount = 0 then begin
    Sid := ActiveStore.CreateSession('Chat 1');
    FCurrentSessionId := Sid;
  end else if FCurrentSessionId = '' then
    FCurrentSessionId := ActiveStore.GetSessionInfo(0).Id;

  FRegistry.SetLastSessionId(Entry.Id, FCurrentSessionId);
  BindSessionToUI(FCurrentSessionId);

  if Assigned(FTerminalPanel) then begin
    FTerminalPanel.SetWorkingDirectory(FState.WorkspaceRoot);
    if FState.IsPanelVisible(piTerminal) then
      FTerminalPanel.RestartForWorkspace;
  end;

  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.DeactivateWorkspace;
begin
  if Assigned(FActiveHub) then
    FActiveHub.SaveAll;
  FActiveHub := nil;
  FState.ActiveWorkspaceId := '';
  FState.WorkspaceName := '';
  FState.WorkspaceRoot := '';
  FCurrentSessionId := '';
  FRegistry.ActiveWorkspaceId := '';
  FRegistry.Save;
  if Assigned(FChatPanel) then
    FChatPanel.ClearHistory;
  FState.SetPanelVisible(piChat, False);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavWorkspaceSelect(Sender: TObject; const AWorkspaceId: string);
begin
  if SameText(AWorkspaceId, FState.ActiveWorkspaceId) then Exit;
  ActivateWorkspace(AWorkspaceId);
end;

procedure TLazyCodingAgentForm.NavWorkspaceNew(Sender: TObject);
begin
  MnuFileNewClick(Self);
end;

procedure TLazyCodingAgentForm.NavWorkspaceDelete(Sender: TObject; const AWorkspaceId: string);
var
  Entry: TWorkspaceEntry;
  WasActive: Boolean;
begin
  if not FRegistry.FindById(AWorkspaceId, Entry) then Exit;
  if MessageDlg('Remove workspace "' + Entry.DisplayName + '" from the list?'#13#10 +
    'The project folder on disk will not be deleted.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  WasActive := SameText(FState.ActiveWorkspaceId, AWorkspaceId);
  if WasActive then begin
    if Assigned(FActiveHub) then
      FActiveHub.SaveAll;
    FActiveHub := nil;
  end;
  FSessionHubs.RemoveHub(AWorkspaceId, True);
  FRegistry.RemoveWorkspace(AWorkspaceId);
  FRegistry.Save;
  if WasActive then
    DeactivateWorkspace
  else
    StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavSessionSelect(Sender: TObject; const ASessionId: string);
begin
  SelectSession(ASessionId);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.CreateAndSelectNewSession;
begin
  ShowChatCenterTab;
  NavSessionNew(Self);
end;

procedure TLazyCodingAgentForm.NavSessionNew(Sender: TObject);
var
  Sid: string;
begin
  if not FState.HasActiveWorkspace then begin
    ShowMessage('Select a workspace first.');
    Exit;
  end;
  EnsureActiveHub;
  SaveCurrentSession;
  Sid := ActiveStore.CreateSession('');
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, Sid);
  FRegistry.Save;
  FCurrentSessionId := Sid;
  ActiveStore.SetLastSessionId(Sid);
  FActiveHub.GetOrCreateEngine(Sid);
  BindSessionToUI(Sid);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.EnsureActiveNonArchivedSession;
var
  I: Integer;
  Store: TChatSessionStore;
  Info: TChatSessionInfo;
  NewId: string;
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  Store := ActiveStore;
  if (FCurrentSessionId <> '') and Store.FindSessionInfo(FCurrentSessionId, Info) and not Info.Archived then
    Exit;

  NewId := '';
  for I := 0 to Store.SessionCount - 1 do
    if not Store.GetSessionInfo(I).Archived then begin
      NewId := Store.GetSessionInfo(I).Id;
      Break;
    end;
  if NewId = '' then
    NewId := Store.CreateSession('');
  FCurrentSessionId := NewId;
  ActiveStore.SetLastSessionId(NewId);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, NewId);
  FRegistry.Save;
  if Assigned(FActiveHub) then
    FActiveHub.GetOrCreateEngine(NewId);
  BindSessionToUI(NewId);
end;

procedure TLazyCodingAgentForm.DoArchiveSession(const ASessionId: string);
var
  E: TAgentEngine;
begin
  if not FState.HasActiveWorkspace or not Assigned(FActiveHub) or not Assigned(ActiveStore) then Exit;
  if ASessionId = '' then Exit;
  E := FActiveHub.EngineFor(ASessionId);
  if Assigned(E) then
    E.RequestCancel;
  ActiveStore.SetSessionArchived(ASessionId, True);
  FActiveHub.SaveSessionToStore(ASessionId);
  EnsureActiveNonArchivedSession;
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavSessionArchive(Sender: TObject; const ASessionId: string);
begin
  DoArchiveSession(ASessionId);
end;

procedure TLazyCodingAgentForm.NavSessionRestore(Sender: TObject; const ASessionId: string);
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  ActiveStore.SetSessionArchived(ASessionId, False);
  if SameText(ASessionId, FCurrentSessionId) then
    ApplySessionComposerState;
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavSessionDelete(Sender: TObject; const ASessionId: string);
var
  I: Integer;
  Store: TChatSessionStore;
  NewId: string;
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  if MessageDlg('Permanently delete this chat session?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  Store := ActiveStore;
  if Assigned(FActiveHub) then
    FActiveHub.RemoveSession(ASessionId);
  Store.DeleteSession(ASessionId);
  if SameText(ASessionId, FCurrentSessionId) then begin
    NewId := '';
    for I := 0 to Store.SessionCount - 1 do
      if not Store.GetSessionInfo(I).Archived then begin
        NewId := Store.GetSessionInfo(I).Id;
        Break;
      end;
    if NewId = '' then
      NewId := Store.CreateSession('');
    FCurrentSessionId := NewId;
    BindSessionToUI(NewId);
  end;
  StateChanged(Self);
end;



procedure TLazyCodingAgentForm.OpenMarkdownInCenterTab(const APath: string);
var
  Path: string;
  Lines: TStringList;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    ShowMessage('File not found.');
    Exit;
  end;
  FMarkdownPath := Path;
  if Assigned(FMarkdownPreview) then begin
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(Path);
      FMarkdownPreview.SetMarkdown(Lines.Text);
    finally
      Lines.Free;
    end;
  end;
  tsMarkdown.Caption := ExtractFileName(Path) + ' [Preview]';
  TThemedPageTabBar.SetTabHidden(tsMarkdown, False);
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsMarkdown;
  if Assigned(FCenterTabBar) then
    FCenterTabBar.RefreshFromPageControl;
end;


procedure TLazyCodingAgentForm.NavFileOpen(Sender: TObject; const AFilePath: string);
var
  Choice: TMarkdownOpenChoice;
begin
  if IsMarkdownFile(AFilePath) then begin
    Choice := TOpenMarkdownForm.Execute(Self, FState.Theme, AFilePath);
    case Choice of
      mocPreview: OpenMarkdownInCenterTab(AFilePath);
      mocSource: OpenFileInCenterTab(AFilePath);
    end;
  end else
    OpenFileInCenterTab(AFilePath);
end;

function TLazyCodingAgentForm.IsMarkdownFile(const APath: string): Boolean;
begin
  Result := SameText(ExtractFileExt(APath), '.md');
end;

procedure TLazyCodingAgentForm.OpenFileInCenterTab(const APath: string);
var
  Path: string;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    ShowMessage('File not found.');
    Exit;
  end;
  if Assigned(FFileEditor) and FFileEditor.Modified and
     (FFileEditor.FilePath <> '') and not SameText(FFileEditor.FilePath, Path) then
    if not FFileEditor.PromptSaveIfModified then
      Exit;
  if not Assigned(FFileEditor) then Exit;
  if not FFileEditor.LoadFile(Path) then begin
    ShowMessage('Could not open file.');
    Exit;
  end;
  tsEditor.Caption := ExtractFileName(Path);
  TThemedPageTabBar.SetTabHidden(tsEditor, False);
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  ApplyEditorTheme;
  RefreshEditorScheme;
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsEditor;
  if Assigned(FCenterTabBar) then
    FCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.ApplyEditorTheme;
begin
  if Assigned(FFileEditor) then
    FFileEditor.ApplyTheme(FState.Theme);
end;

procedure TLazyCodingAgentForm.RefreshEditorScheme;
begin
  if Assigned(FFileEditor) and Assigned(FSyntaxSchemes) then
    FFileEditor.ApplySyntaxScheme(FSyntaxSchemes.ActiveScheme);
end;

function TLazyCodingAgentForm.PromptDirtyEditor: Boolean;
begin
  if not Assigned(FFileEditor) then
    Exit(True);
  if (pgcCenter = nil) or (pgcCenter.ActivePage <> tsEditor) then
    Exit(True);
  Result := FFileEditor.PromptSaveIfModified;
end;

function TLazyCodingAgentForm.SaveActiveEditorFile: Boolean;
begin
  if not Assigned(FFileEditor) or (FFileEditor.FilePath = '') then
    Exit(False);
  if (pgcCenter = nil) or (pgcCenter.ActivePage <> tsEditor) then
    Exit(False);
  Result := FFileEditor.SaveFile;
  if Result then begin
    tsEditor.Caption := ExtractFileName(FFileEditor.FilePath);
    if Assigned(FCenterTabBar) then
      FCenterTabBar.RefreshFromPageControl;
  end;
end;


procedure TLazyCodingAgentForm.RebuildActiveSchemeMenu;
var
  I: Integer;
  Item: TMenuItem;
  E: TSyntaxSchemeEntry;
begin
  while mnuViewActiveSchemes.Count > 0 do
    mnuViewActiveSchemes.Delete(0);
  if not Assigned(FSyntaxSchemes) then Exit;
  for I := 0 to FSyntaxSchemes.Count - 1 do begin
    E := FSyntaxSchemes.GetEntry(I);
    Item := TMenuItem.Create(mnuViewActiveSchemes);
    Item.Caption := E.Name;
    Item.Tag := I;
    Item.RadioItem := True;
    Item.Checked := SameText(E.Id, FSyntaxSchemes.ActiveId);
    Item.OnClick := @MenuSelectSyntaxScheme;
    mnuViewActiveSchemes.Add(Item);
  end;
end;

procedure TLazyCodingAgentForm.MenuSelectSyntaxScheme(Sender: TObject);
var
  Idx: Integer;
  E: TSyntaxSchemeEntry;
begin
  if not (Sender is TMenuItem) or not Assigned(FSyntaxSchemes) then Exit;
  Idx := TMenuItem(Sender).Tag;
  if (Idx < 0) or (Idx >= FSyntaxSchemes.Count) then Exit;
  E := FSyntaxSchemes.GetEntry(Idx);
  FSyntaxSchemes.SetActive(E.Id);
  RefreshEditorScheme;
  RebuildActiveSchemeMenu;
end;

procedure TLazyCodingAgentForm.MnuViewSyntaxSchemesClick(Sender: TObject);
var
  SchemesChanged: Boolean;
begin
  if not Assigned(FSyntaxSchemes) then Exit;
  TSyntaxSchemesForm.Execute(Self, FState.Theme, FSyntaxSchemes, SchemesChanged);
  if SchemesChanged then begin
    RefreshEditorScheme;
    RebuildActiveSchemeMenu;
  end;
end;

procedure TLazyCodingAgentForm.MnuFileSaveFileClick(Sender: TObject);
begin
  if not SaveActiveEditorFile then
    ShowMessage('No file editor tab is active.');
end;

end.
