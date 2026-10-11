unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Buttons,
  ComCtrls, Menus, FileUtil, uAppTypes, uAgentTypes, uAgentTools, uTheme, fraThemedButton, fraThemedTabs, uWorkspaceState,
  uWorkspaceRegistry, uChatSessionStore, uChatSessionHub, uPanelDetach, uNavigationPanel, uChatPanel,
  uTerminalPanel,
  uAgentEngine, frmSettings, frmNewWorkspace, frmWorkspaceRules,
  uUtilityPlanTab, uUtilityExecutionDetailTab, uAgentExecutionLog, uAgentToolErrorLog,
  uFileEditorTab,
  uFileMarkdownTab, uSyntaxSchemeRegistry, frmSyntaxSchemes,
  frmOpenMarkdown, frmHelp, fpjson, jsonparser;

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
    pnlNavHost: TPanel;
    pnlNavChrome: TPanel;
    lblNavTitle: TLabel;
    btnNavDetach: TButton;
    btnNavHide: TButton;
    pnlNavContent: TPanel;
    splNav: TSplitter;
    pnlChatHost: TPanel;
    pnlCenterTabsHost: TPanel;
    pnlChatCenter: TPanel;
    pnlChatChrome: TPanel;
    lblChatTitle: TLabel;
    btnChatDetach: TButton;
    btnChatHide: TButton;
    pnlChatContent: TPanel;
    pnlChatSessionToolBar: TPanel;
    pnlChatSessionsHost: TPanel;
    pnlChatBody: TPanel;
    splReserved: TSplitter;
    pnlReservedHost: TPanel;
    pnlReservedChrome: TPanel;
    lblReservedTitle: TLabel;
    btnReservedDetach: TButton;
    btnReservedHide: TButton;
    pnlReservedContent: TPanel;
    memReserved: TMemo;
    splUtility: TSplitter;
    pnlUtilityHost: TPanel;
    pnlUtilityChrome: TPanel;
    lblUtilityTitle: TLabel;
    btnUtilityDetach: TButton;
    btnUtilityHide: TButton;
    pnlUtilityContent: TPanel;
    pnlUtilityTabsHost: TPanel;
    pnlUtilityScratch: TPanel;
    pnlUtilityExecDetail: TPanel;
    splTerminal: TSplitter;
    pnlTerminalHost: TPanel;
    pnlTerminalChrome: TPanel;
    lblTerminalTitle: TLabel;
    btnTerminalDetach: TButton;
    btnTerminalHide: TButton;
    pnlTerminalContent: TPanel;

    procedure PanelDetachClick(Sender: TObject);
    procedure PanelHideClick(Sender: TObject);
    procedure CenterTabsChange(Sender: TObject);
    procedure ChatSessionTabChange(Sender: TObject);
    procedure FloatingFormRequestAttach(Sender: TObject; AId: TPanelId);

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
  private
    FState: TWorkspaceState;
    FSessionHubs: TChatSessionHubManager;
    FActiveHub: TChatSessionHub;
    FUpdatingState: Boolean;
    FSyncingChatTabs: Boolean;
    FPendingTabArchiveSessionId: string;
    FPendingInitialDockLayout: Boolean;
    FPendingInitialWorkspaceUI: Boolean;
    FDeferThemesUntilShown: Boolean;
    FPostShowStartupScheduled: Boolean;
    FPostShowStartupTimer: TTimer;
    FTerminalStartQueued: Boolean;
    FTerminalRetryTimer: TTimer;
    FTerminalRetryCount: Integer;

    FNavRailBtns: array[TNavigationItem] of TSpeedButton;
    FNavRailIndicator: TPanel;
    FNavContent: TNavContentControl;
    FChatPanel: TChatPanel;
    FDetachSlots: array[TPanelId] of TPanelDetachSlot;
    FSyntaxSchemes: TSyntaxSchemeRegistry;

    FChatTabSessionIds: TStringList;
    FTerminalPanel: TTerminalPanel;
    FUtilityExecDetail: TUtilityExecutionDetailTab;
    FCurrentRunMode: TWorkspaceMode;
    FPlanSavedThisRun: Boolean;
    FChatCenterTabIndex: Integer;
    FUtilityExecDetailTabIndex: Integer;
    FFraCenterTabs: TThemedTabHostFrame;
    FFraChatSessions: TThemedTabHostFrame;
    FFraUtility: TThemedTabHostFrame;

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
    procedure SyncChatSessionTabs;
    procedure RefreshChatSessionRunningBadges;
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
    procedure DeferredTabArchiveClose(Data: PtrInt);
    procedure ApplyWorkspaceChatVisibility;

    function ParsePlanToolSuccess(const AResult: TToolExecutionResult;
      out APath, AContent: string): Boolean;
    procedure OpenPlanInUtilityTab(const APath, AContent: string);
    procedure TrySaveProposedPlanFromChat;
    procedure PlanBuildRequested(Sender: TObject; const APlanPath, APlanContent,
      AModelId: string);
    procedure ApplyUtilityPlanTabThemes;
    procedure RefreshUtilityPlanTabModels(const AModels: array of TSavedModel);

    function IsMarkdownFile(const APath: string): Boolean;
    function FindEditorTabByPath(const APath: string): TFileEditorTab;
    function FindMarkdownTabByPath(const APath: string): TFileMarkdownTab;
    function ActiveFileEditorTab: TFileEditorTab;
    procedure OpenFileInCenterTab(const APath: string);
    procedure OpenMarkdownInCenterTab(const APath: string);
    function CenterEditorTabCloseAllow: Boolean;
    function CenterEditorCloseAllowForIndex(APageIndex: Integer): Boolean;
    function CenterTabCloseQuery(Sender: TObject; APageIndex: Integer): Boolean;
    function ChatSessionCloseQuery(Sender: TObject; APageIndex: Integer): Boolean;
    procedure CenterTabsPlusClick(Sender: TObject);
    procedure ChatSessionsPlusClick(Sender: TObject);
    procedure InitThemedTabHosts;
    procedure ShowChatCenterTab;
    procedure ApplyCenterEditorThemes;
    procedure RefreshAllEditorSchemes;
    function SaveActiveEditorFile: Boolean;
    function PromptAllDirtyEditors: Boolean;
    procedure RebuildActiveSchemeMenu;
    procedure MenuSelectSyntaxScheme(Sender: TObject);
    procedure NavFileOpen(Sender: TObject; const AFilePath: string);

    procedure ApplyInitialWindowSize;
    procedure RaiseDetachedFloatingForms;
    procedure InitWorkspaceSubControls;
    procedure InitNavRailButtons;
    procedure InitDetachSlots;
    procedure UpdateNavRailSelection;
    procedure NavRailBtnClick(Sender: TObject);
    function DetachSlot(AId: TPanelId): TPanelDetachSlot;
    procedure PopulateMenusAndCombos;
    procedure StateChanged(Sender: TObject);
    procedure ApplyPanelDetachLayout(AId: TPanelId; AHost: TWinControl; ASplitter: TSplitter);
    procedure ApplyDockPanelsLayout;
    procedure SyncTerminalWorkingDirectory;
    procedure ScheduleDeferredTerminalStart;
    procedure DeferredEnsureTerminal(Data: PtrInt);
    procedure ScheduleTerminalStartRetry;
    procedure TerminalRetryTimer(Sender: TObject);
    procedure TerminalStatus(Sender: TObject; const AMessage: string);
    function IsTerminalSurfaceVisible: Boolean;
    function EffectiveTerminalDockHeight: Integer;
    procedure ApplyDetachSlotThemes;
    procedure ApplyAllThemes;
    procedure ApplyPlatformChromeThemes;
    procedure SchedulePostShowStartup;
    procedure PostShowStartup(Sender: TObject);
    procedure RebuildWindowMenu;

    procedure DockPanelAction(AId: TPanelId; AAction: TDockPanelAction);
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
    procedure MenuDetachPanel(Sender: TObject);
    procedure MenuAttachPanel(Sender: TObject);
    procedure FinalizeDetachSlotForClose(AId: TPanelId);
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
  if Assigned(FUtilityExecDetail) then
    FUtilityExecDetail.ClearDetail;
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
  SyncChatSessionTabs;
end;

procedure TLazyCodingAgentForm.SyncChatSessionTabs;
var
  I, TabIdx, ActiveTab: Integer;
  S: TChatSessionInfo;
  Cap: string;
  Store: TChatSessionStore;
  Hub: TChatSessionHub;
begin
  if not Assigned(FFraChatSessions) or not Assigned(FChatTabSessionIds) then Exit;
  if not FState.HasActiveWorkspace or not Assigned(FActiveHub) then begin
    FFraChatSessions.ClearPages;
    FChatTabSessionIds.Clear;
    Exit;
  end;

  FSyncingChatTabs := True;
  try
    Store := FActiveHub.Store;
    Hub := FActiveHub;
    FFraChatSessions.ClearPages;
    FChatTabSessionIds.Clear;
    ActiveTab := -1;
    for I := 0 to Store.SessionCount - 1 do begin
      S := Store.GetSessionInfo(I);
      if S.Archived then Continue;
      Cap := S.Title;
      if Hub.IsSessionRunning(S.Id) then
        Cap := Cap + ' ●';
      FFraChatSessions.AddPage(Cap, True);
      FChatTabSessionIds.Add(S.Id);
      TabIdx := FChatTabSessionIds.Count - 1;
      if SameText(S.Id, FCurrentSessionId) then
        ActiveTab := TabIdx;
    end;
    if ActiveTab >= 0 then
      FFraChatSessions.ActivePageIndex := ActiveTab;
  finally
    FSyncingChatTabs := False;
  end;
end;

function TLazyCodingAgentForm.AgentStateIsRunning(AState: TAgentState): Boolean;
begin
  Result := not (AState in [asIdle, asFinished, asError]);
end;

procedure TLazyCodingAgentForm.RefreshChatSessionRunningBadges;
var
  I: Integer;
  Sid: string;
  S: TChatSessionInfo;
  Cap: string;
  Store: TChatSessionStore;
begin
  if not Assigned(FFraChatSessions) or not Assigned(FChatTabSessionIds) then Exit;
  if not Assigned(FActiveHub) then Exit;
  Store := FActiveHub.Store;
  for I := 0 to FChatTabSessionIds.Count - 1 do begin
    if I >= FFraChatSessions.PageCount then Break;
    Sid := FChatTabSessionIds[I];
    if not Store.FindSessionInfo(Sid, S) then Continue;
    Cap := S.Title;
    if FActiveHub.IsSessionRunning(Sid) then
      Cap := Cap + ' ●';
    FFraChatSessions.SetPageCaption(I, Cap);
  end;
end;

procedure TLazyCodingAgentForm.ChatSessionTabChange(Sender: TObject);
var
  Idx: Integer;
begin
  if FSyncingChatTabs then Exit;
  if not Assigned(FFraChatSessions) then Exit;
  Idx := FFraChatSessions.ActivePageIndex;
  if (Idx < 0) or (Idx >= FChatTabSessionIds.Count) then Exit;
  if SameText(FChatTabSessionIds[Idx], FCurrentSessionId) then Exit;
  SelectSession(FChatTabSessionIds[Idx]);
  StateChanged(Self);
end;

function TLazyCodingAgentForm.ChatSessionCloseQuery(Sender: TObject;
  APageIndex: Integer): Boolean;
begin
  if (APageIndex < 0) or (APageIndex >= FChatTabSessionIds.Count) then
    Exit(False);
  FPendingTabArchiveSessionId := FChatTabSessionIds[APageIndex];
  Application.QueueAsyncCall(@DeferredTabArchiveClose, 0);
  Result := False;
end;

procedure TLazyCodingAgentForm.ChatSessionsPlusClick(Sender: TObject);
begin
  CreateAndSelectNewSession;
end;

procedure TLazyCodingAgentForm.DeferredTabArchiveClose(Data: PtrInt);
var
  Sid: string;
begin
  Sid := FPendingTabArchiveSessionId;
  FPendingTabArchiveSessionId := '';
  if Sid = '' then Exit;
  DoArchiveSession(Sid);
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

procedure TLazyCodingAgentForm.RaiseDetachedFloatingForms;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do
    if Assigned(FDetachSlots[P]) then
      FDetachSlots[P].BringFloatingToFront;
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
  FSyncingChatTabs := False;
  FNavWorkCaptions := TStringList.Create;
  FNavWorkIds := TStringList.Create;
  FNavSessionCaptions := TStringList.Create;
  FNavSessionIds := TStringList.Create;
  FNavSessionArchived := TStringList.Create;
  FChatTabSessionIds := TStringList.Create;
  FCurrentSessionId := '';

  FSyntaxSchemes := TSyntaxSchemeRegistry.Create;
  FSyntaxSchemes.Load;

  mnuWorkspaceSepRules.Tag := -1;
  mnuWorkspaceProjectRules.Tag := -1;

  InitWorkspaceSubControls;
  PopulateMenusAndCombos;
end;

procedure TLazyCodingAgentForm.FormShow(Sender: TObject);
begin
  if FPendingInitialDockLayout then begin
    FPendingInitialDockLayout := False;
    ApplyDockPanelsLayout;
    RaiseDetachedFloatingForms;
  end;
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
  if Assigned(FChatPanel) then
    FChatPanel.EnsureLayout;
  if FState.IsPanelVisible(piTerminal) then
    ScheduleDeferredTerminalStart;
end;

procedure TLazyCodingAgentForm.FinalizeDetachSlotForClose(AId: TPanelId);
var
  R: TRect;
  Slot: TPanelDetachSlot;
begin
  Slot := FDetachSlots[AId];
  if not Assigned(Slot) then Exit;
  Slot.PrepareForApplicationClose(R);
  if (R.Width > 0) and (R.Height > 0) then
    FState.SetPanelBounds(AId, R.Left, R.Top, R.Width, R.Height);
end;

procedure TLazyCodingAgentForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
begin
  CanClose := True;
  if not PromptAllDirtyEditors then begin
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
  FinalizeDetachSlotForClose(piNavigation);
  FinalizeDetachSlotForClose(piChat);
  FinalizeDetachSlotForClose(piReserved);
  FinalizeDetachSlotForClose(piUtility);
  FinalizeDetachSlotForClose(piTerminal);
  if Assigned(FTerminalPanel) then
    FTerminalPanel.Stop;
end;

procedure TLazyCodingAgentForm.FormDestroy(Sender: TObject);
var
  I: Integer;
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do
    FreeAndNil(FDetachSlots[P]);
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
  FreeAndNil(FChatTabSessionIds);

  FreeAndNil(FSyntaxSchemes);

  if Assigned(FState) then begin
    FState.Save;
    FreeAndNil(FState);
  end;
end;

function TLazyCodingAgentForm.DetachSlot(AId: TPanelId): TPanelDetachSlot;
begin
  Result := FDetachSlots[AId];
end;

procedure TLazyCodingAgentForm.FloatingFormRequestAttach(Sender: TObject; AId: TPanelId);
begin
  DockPanelAction(AId, dpaAttach);
end;

procedure TLazyCodingAgentForm.InitDetachSlots;
begin
  FDetachSlots[piNavigation] := TPanelDetachSlot.Create(piNavigation, pnlNavHost, pnlNavContent,
    @FloatingFormRequestAttach);
  FDetachSlots[piChat] := TPanelDetachSlot.Create(piChat, pnlChatCenter, pnlChatContent,
    @FloatingFormRequestAttach);
  FDetachSlots[piReserved] := TPanelDetachSlot.Create(piReserved, pnlReservedHost, pnlReservedContent,
    @FloatingFormRequestAttach);
  FDetachSlots[piUtility] := TPanelDetachSlot.Create(piUtility, pnlUtilityHost, pnlUtilityContent,
    @FloatingFormRequestAttach);
  FDetachSlots[piTerminal] := TPanelDetachSlot.Create(piTerminal, pnlTerminalHost, pnlTerminalContent,
    @FloatingFormRequestAttach);
end;

procedure TLazyCodingAgentForm.InitNavRailButtons;
var
  Nav: TNavigationItem;
  Btn: TSpeedButton;
  TopY: Integer;
const
  ItemH = 40;
  ItemGap = 2;
  SepGap = 10;
begin
  FNavRailIndicator := TPanel.Create(pnlNavRailHost);
  FNavRailIndicator.Parent := pnlNavRailHost;
  FNavRailIndicator.Width := 2;
  FNavRailIndicator.Height := 24;
  FNavRailIndicator.BevelOuter := bvNone;
  FNavRailIndicator.Visible := False;

  TopY := 48;
  for Nav := Low(TNavigationItem) to High(TNavigationItem) do begin
    Btn := TSpeedButton.Create(pnlNavRailHost);
    Btn.Parent := pnlNavRailHost;
    Btn.Left := 6;
    Btn.Top := TopY;
    Btn.Width := 44;
    Btn.Height := ItemH;
    Btn.GroupIndex := 1;
    Btn.AllowAllUp := False;
    Btn.Flat := True;
    Btn.Caption := NavigationIconSymbol(Nav);
    Btn.Hint := NavigationHint(Nav);
    Btn.ShowHint := True;
    Btn.Tag := Ord(Nav);
    Btn.Font.Name := 'Segoe UI Symbol';
    Btn.Font.Size := 14;
    Btn.OnClick := @NavRailBtnClick;
    FNavRailBtns[Nav] := Btn;
    Inc(TopY, ItemH + ItemGap);
    if Nav = Pred(NavigationFutureFeatureFirst) then
      Inc(TopY, SepGap);
  end;
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
  if Assigned(FNavRailIndicator) and Assigned(FNavRailBtns[FState.Navigation]) then begin
    FNavRailIndicator.Visible := True;
    FNavRailIndicator.Top := FNavRailBtns[FState.Navigation].Top + 8;
    FNavRailIndicator.Color := P.Accent;
  end;
end;

procedure TLazyCodingAgentForm.PanelDetachClick(Sender: TObject);
begin
  if Sender is TControl then
    DockPanelAction(TPanelId(TControl(Sender).Tag), dpaDetach);
end;

procedure TLazyCodingAgentForm.PanelHideClick(Sender: TObject);
begin
  if Sender is TControl then
    DockPanelAction(TPanelId(TControl(Sender).Tag), dpaHide);
end;

procedure TLazyCodingAgentForm.CenterTabsPlusClick(Sender: TObject);
begin
  MnuFileOpenClick(Sender);
end;

procedure TLazyCodingAgentForm.CenterTabsChange(Sender: TObject);
begin
end;

function TLazyCodingAgentForm.CenterEditorCloseAllowForIndex(APageIndex: Integer): Boolean;
var
  Page: TWinControl;
  Tab: TFileEditorTab;
begin
  if not Assigned(FFraCenterTabs) then
    Exit(True);
  if APageIndex = FChatCenterTabIndex then
    Exit(False);
  Page := FFraCenterTabs.PageBody(APageIndex);
  if Page = nil then
    Exit(True);
  if (Page.ControlCount > 0) and (Page.Controls[0] is TFileEditorTab) then begin
    Tab := TFileEditorTab(Page.Controls[0]);
    Exit(Tab.PromptSaveIfModified);
  end;
  Result := True;
end;

function TLazyCodingAgentForm.CenterTabCloseQuery(Sender: TObject;
  APageIndex: Integer): Boolean;
begin
  Result := CenterEditorCloseAllowForIndex(APageIndex);
end;

procedure TLazyCodingAgentForm.ShowChatCenterTab;
begin
  if Assigned(FFraCenterTabs) and (FChatCenterTabIndex >= 0) then
    FFraCenterTabs.ActivePageIndex := FChatCenterTabIndex;
end;

procedure TLazyCodingAgentForm.InitThemedTabHosts;
begin
  FFraCenterTabs := EnsureThemedTabHost(Self, pnlCenterTabsHost);
  FFraChatSessions := EnsureThemedTabHost(Self, pnlChatSessionsHost);
  FFraUtility := EnsureThemedTabHost(Self, pnlUtilityTabsHost);
  if Assigned(FFraCenterTabs) then begin
    FFraCenterTabs.HostPageBody(pnlChatCenter);
    FChatCenterTabIndex := FFraCenterTabs.RegisterPage(pnlChatCenter, 'Chat', False);
    FFraCenterTabs.ShowPlus := True;
    FFraCenterTabs.OnPlusClick := @CenterTabsPlusClick;
    FFraCenterTabs.OnPageCloseQuery := @CenterTabCloseQuery;
    FFraCenterTabs.OnChange := @CenterTabsChange;
  end;
  if Assigned(FFraChatSessions) then begin
    FFraChatSessions.StripOnly := True;
    FFraChatSessions.ShowPlus := True;
    FFraChatSessions.OnPlusClick := @ChatSessionsPlusClick;
    FFraChatSessions.OnPageCloseQuery := @ChatSessionCloseQuery;
    FFraChatSessions.OnChange := @ChatSessionTabChange;
    if Assigned(pnlChatSessionToolBar) then
      pnlChatSessionToolBar.Height := FFraChatSessions.TabStripHeight;
  end;
  if Assigned(FFraUtility) then begin
    FFraUtility.HostPageBody(pnlUtilityScratch);
    FFraUtility.HostPageBody(pnlUtilityExecDetail);
    FFraUtility.RegisterPage(pnlUtilityScratch, 'Scratchpad', False);
    FUtilityExecDetailTabIndex := FFraUtility.RegisterPage(pnlUtilityExecDetail, 'Execution Detail', False);
    FFraUtility.ShowPlus := False;
  end;
  if Assigned(FFraCenterTabs) then
    FFraCenterTabs.ApplyTheme(FState.Theme);
  if Assigned(FFraChatSessions) and Assigned(pnlChatSessionToolBar) then
    pnlChatSessionToolBar.Height := FFraChatSessions.TabStripHeight;
end;

procedure TLazyCodingAgentForm.InitWorkspaceSubControls;
begin
  lblNavTitle.Caption := PanelCaption(piNavigation);
  lblChatTitle.Caption := PanelCaption(piChat);
  lblReservedTitle.Caption := PanelCaption(piReserved);
  lblUtilityTitle.Caption := PanelCaption(piUtility);
  lblTerminalTitle.Caption := PanelCaption(piTerminal);

  if memReserved.Lines.Count = 0 then begin
    memReserved.Lines.Add('=== Workspace Context & Guidelines ===');
    memReserved.Lines.Add('');
    memReserved.Lines.Add('• Follow single responsibility principles.');
    memReserved.Lines.Add('• Visual Form Designer first with modern styling.');
    memReserved.Lines.Add('• Dark-first modern design across all platforms.');
    memReserved.Lines.Add('• Detachable windows work across multi-monitors.');
    memReserved.Lines.Add('• Cross-platform Free Pascal / LCL target.');
    memReserved.Lines.Add('• Autonomous tool execution with live logging.');
  end;

  InitNavRailButtons;
  InitDetachSlots;
  InitThemedTabHosts;

  FNavContent := TNavContentControl.Create(pnlNavContent);
  FNavContent.Parent := pnlNavContent;
  FNavContent.Align := alClient;

  FChatPanel := TChatPanel.Create(pnlChatBody);
  FChatPanel.Parent := pnlChatBody;
  FChatPanel.Align := alClient;

  FChatPanel.OnPrompt := @ChatPrompt;
  FChatPanel.OnModeChange := @ChatModeChange;
  FChatPanel.OnModelChange := @ChatModelChange;
  FChatPanel.OnCancel := @ChatCancel;

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

  FUtilityExecDetail := TUtilityExecutionDetailTab.Create(pnlUtilityExecDetail);
  FUtilityExecDetail.Parent := pnlUtilityExecDetail;
  FUtilityExecDetail.Align := alClient;

  FTerminalPanel := TTerminalPanel.Create(pnlTerminalContent);
  FTerminalPanel.Parent := pnlTerminalContent;
  FTerminalPanel.Align := alClient;
  FTerminalPanel.OnTerminalStatus := @TerminalStatus;

  FTerminalRetryTimer := TTimer.Create(Self);
  FTerminalRetryTimer.Enabled := False;
  FTerminalRetryTimer.Interval := 150;
  FTerminalRetryTimer.OnTimer := @TerminalRetryTimer;

  FCurrentRunMode := wmAgent;
  FPlanSavedThisRun := False;
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

procedure TLazyCodingAgentForm.ApplyPanelDetachLayout(AId: TPanelId; AHost: TWinControl;
  ASplitter: TSplitter);
var
  L, T, W, H: Integer;
  Slot: TPanelDetachSlot;
  VisibleDocked: Boolean;
begin
  Slot := FDetachSlots[AId];
  if not Assigned(Slot) then Exit;
  VisibleDocked := FState.IsPanelVisible(AId) and not FState.IsPanelFloating(AId);
  AHost.Visible := VisibleDocked;
  if Assigned(ASplitter) then
    ASplitter.Visible := VisibleDocked;
  if FState.IsPanelFloating(AId) then begin
    if FState.GetPanelBounds(AId, L, T, W, H) then
      Slot.DetachToWindow(L, T, W, H, PanelCaption(AId));
  end else begin
    if Slot.IsDetached then
      Slot.AttachToHost;
    if not FState.IsPanelVisible(AId) then
      Slot.HideFloating;
  end;
end;

procedure TLazyCodingAgentForm.ApplyDockPanelsLayout;
begin
  ApplyPanelDetachLayout(piNavigation, pnlNavHost, splNav);
  pnlChatHost.Visible := FState.IsPanelVisible(piChat) and not FState.IsPanelFloating(piChat);
  ApplyPanelDetachLayout(piChat, pnlChatCenter, nil);
  ApplyPanelDetachLayout(piReserved, pnlReservedHost, splReserved);
  ApplyPanelDetachLayout(piUtility, pnlUtilityHost, splUtility);

  pnlTerminalHost.Visible := FState.IsPanelVisible(piTerminal) and not FState.IsPanelFloating(piTerminal);
  splTerminal.Visible := pnlTerminalHost.Visible;
  if pnlTerminalHost.Visible then
    pnlTerminalHost.Height := EffectiveTerminalDockHeight;
  ApplyPanelDetachLayout(piTerminal, pnlTerminalHost, nil);

  if FState.IsPanelVisible(piTerminal) and not FDeferThemesUntilShown
     and not FPendingInitialWorkspaceUI then
    ScheduleDeferredTerminalStart;

  RaiseDetachedFloatingForms;
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
  if not Assigned(FTerminalPanel) or not FTerminalPanel.Visible then
    Exit(False);
  if FState.IsPanelFloating(piTerminal) then
    Result := Assigned(FDetachSlots[piTerminal]) and FDetachSlots[piTerminal].IsDetached
  else
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

procedure TLazyCodingAgentForm.ApplyDetachSlotThemes;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do
    if Assigned(FDetachSlots[P]) then
      FDetachSlots[P].ApplyTheme(FState.Theme);
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

    SyncChatSessionTabs;
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
      RefreshUtilityPlanTabModels(Models);
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
  pnlChatSessionToolBar.Color := P.HeaderBg;

  ApplyControlTheme(pnlNavChrome, FState.Theme);
  ApplyControlTheme(pnlChatChrome, FState.Theme);
  ApplyControlTheme(pnlReservedChrome, FState.Theme);
  ApplyControlTheme(pnlUtilityChrome, FState.Theme);
  ApplyControlTheme(pnlTerminalChrome, FState.Theme);
  StyleCancelButton(btnNavDetach, FState.Theme);
  StyleCancelButton(btnNavHide, FState.Theme);
  StyleCancelButton(btnChatDetach, FState.Theme);
  StyleCancelButton(btnChatHide, FState.Theme);
  StyleCancelButton(btnReservedDetach, FState.Theme);
  StyleCancelButton(btnReservedHide, FState.Theme);
  StyleCancelButton(btnUtilityDetach, FState.Theme);
  StyleCancelButton(btnUtilityHide, FState.Theme);
  StyleCancelButton(btnTerminalDetach, FState.Theme);
  StyleCancelButton(btnTerminalHide, FState.Theme);

  if Assigned(FFraCenterTabs) then FFraCenterTabs.ApplyTheme(FState.Theme);
  if Assigned(FFraChatSessions) then FFraChatSessions.ApplyTheme(FState.Theme);
  if Assigned(FFraUtility) then FFraUtility.ApplyTheme(FState.Theme);

  if Assigned(FNavContent) then FNavContent.ApplyTheme(FState.Theme);
  if Assigned(FChatPanel) then FChatPanel.ApplyTheme(FState.Theme);
  if Assigned(memReserved) then
    ConfigureThemedMemo(memReserved, FState.Theme, 'Segoe UI', P.Surface);
  if Assigned(FTerminalPanel) then FTerminalPanel.ApplyTheme(FState.Theme);

  if Assigned(FFraUtility) then begin
    ApplyUtilityPlanTabThemes;
    if Assigned(FUtilityExecDetail) then
      FUtilityExecDetail.ApplyTheme(FState.Theme);
  end;

  UpdateNavRailSelection;
  ApplyDetachSlotThemes;
  ApplyCenterEditorThemes;

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

  while mnuWindow.Count > 1 do
    mnuWindow.Delete(1);

  Item := TMenuItem.Create(mnuWindow);
  Item.Caption := '-';
  mnuWindow.Add(Item);

  for P := Low(TPanelId) to High(TPanelId) do begin
    if not FState.IsPanelFloating(P) then begin
      SubItem := TMenuItem.Create(mnuWindow);
      SubItem.Caption := Format('Detach %s to Window', [PanelCaption(P)]);
      SubItem.Tag := Ord(P);
      SubItem.OnClick := @MenuDetachPanel;
      mnuWindow.Add(SubItem);
    end else begin
      SubItem := TMenuItem.Create(mnuWindow);
      SubItem.Caption := Format('Dock %s to Main Window', [PanelCaption(P)]);
      SubItem.Tag := Ord(P);
      SubItem.OnClick := @MenuAttachPanel;
      mnuWindow.Add(SubItem);
    end;
  end;

  ApplyPlatformChrome(Self, FState.Theme);
end;

procedure TLazyCodingAgentForm.DockPanelAction(AId: TPanelId; AAction: TDockPanelAction);
begin
  case AAction of
    dpaHide:
      FState.SetPanelVisible(AId, False);
    dpaDetach:
      begin
        FState.SetPanelFloating(AId, True);
        FState.SetPanelVisible(AId, True);
        StateChanged(Self);
      end;
    dpaAttach:
      begin
        FState.SetPanelFloating(AId, False);
        FState.SetPanelVisible(AId, True);
        StateChanged(Self);
      end;
  end;
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
    RefreshChatSessionRunningBadges;
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
  if not Assigned(FUtilityExecDetail) then Exit;
  Log := nil;
  if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
    Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
  if (Log = nil) or (AIndex < 0) or (AIndex >= Log.Count) then Exit;
  Entry := Log.Entry(AIndex);
  FUtilityExecDetail.ShowEntry(Entry);
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  if Assigned(FFraUtility) and (FUtilityExecDetailTabIndex >= 0) then
    FFraUtility.ActivePageIndex := FUtilityExecDetailTabIndex;
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
  if Assigned(FUtilityExecDetail) then
    FUtilityExecDetail.ClearDetail;
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
  if not Assigned(FUtilityExecDetail) then Exit;
  Log := nil;
  if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
    Log := FActiveHub.ToolErrorLogFor(FCurrentSessionId);
  if (Log = nil) or (AIndex < 0) or (AIndex >= Log.Count) then Exit;
  Entry := Log.Entry(AIndex);
  FUtilityExecDetail.ShowToolError(Entry);
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  if Assigned(FFraUtility) and (FUtilityExecDetailTabIndex >= 0) then
    FFraUtility.ActivePageIndex := FUtilityExecDetailTabIndex;
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
  if Assigned(FUtilityExecDetail) then
    FUtilityExecDetail.ClearDetail;
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
  Page: TPanel;
  Tab: TUtilityPlanTab;
  Cap: string;
  Models: array of TSavedModel;
begin
  if not Assigned(FFraUtility) then Exit;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;

  Cap := ExtractFileName(APath);
  if Cap = '' then
    Cap := 'Plan';
  Page := FFraUtility.AddPage(Cap, False);
  Tab := TUtilityPlanTab.Create(Page);
  Tab.Parent := Page;
  Tab.Align := alClient;
  Tab.OnBuild := @PlanBuildRequested;
  Tab.LoadPlan(APath, AContent);
  SetLength(Models, FState.SavedModelCount(FState.Provider));
  for I := 0 to High(Models) do
    Models[I] := FState.GetSavedModel(FState.Provider, I);
  Tab.SetAvailableModels(Models);
  if Assigned(FChatPanel) and (FChatPanel.Model <> '') then
    Tab.SetModel(FChatPanel.Model)
  else
    Tab.SetModel(FState.Model);
  Tab.ApplyTheme(FState.Theme);
  FFraUtility.ActivePageIndex := FFraUtility.PageCount - 1;
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
  SyncChatSessionTabs;

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

procedure TLazyCodingAgentForm.ApplyUtilityPlanTabThemes;
var
  I: Integer;
  Page: TWinControl;
  Tab: TUtilityPlanTab;
begin
  if not Assigned(FFraUtility) then Exit;
  for I := 0 to FFraUtility.PageCount - 1 do begin
    Page := FFraUtility.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TUtilityPlanTab) then begin
      Tab := TUtilityPlanTab(Page.Controls[0]);
      Tab.ApplyTheme(FState.Theme);
    end;
  end;
end;

procedure TLazyCodingAgentForm.RefreshUtilityPlanTabModels(const AModels: array of TSavedModel);
var
  I: Integer;
  Page: TWinControl;
  Tab: TUtilityPlanTab;
begin
  if not Assigned(FFraUtility) then Exit;
  for I := 0 to FFraUtility.PageCount - 1 do begin
    Page := FFraUtility.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TUtilityPlanTab) then begin
      Tab := TUtilityPlanTab(Page.Controls[0]);
      Tab.SetAvailableModels(AModels);
    end;
  end;
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

procedure TLazyCodingAgentForm.MenuDetachPanel(Sender: TObject);
begin
  if Sender is TMenuItem then
    DockPanelAction(TPanelId(TMenuItem(Sender).Tag), dpaDetach);
end;

procedure TLazyCodingAgentForm.MenuAttachPanel(Sender: TObject);
begin
  if Sender is TMenuItem then
    DockPanelAction(TPanelId(TMenuItem(Sender).Tag), dpaAttach);
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
  if FState.IsPanelVisible(piTerminal) and not FState.IsPanelFloating(piTerminal) then
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

function TLazyCodingAgentForm.FindEditorTabByPath(const APath: string): TFileEditorTab;
var
  I: Integer;
  Page: TWinControl;
  Tab: TFileEditorTab;
  Norm: string;
begin
  Result := nil;
  if not Assigned(FFraCenterTabs) then Exit;
  Norm := ExpandFileName(APath);
  for I := 0 to FFraCenterTabs.PageCount - 1 do begin
    Page := FFraCenterTabs.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TFileEditorTab) then begin
      Tab := TFileEditorTab(Page.Controls[0]);
      if SameText(ExpandFileName(Tab.FilePath), Norm) then
        Exit(Tab);
    end;
  end;
end;

function TLazyCodingAgentForm.FindMarkdownTabByPath(const APath: string): TFileMarkdownTab;
var
  I: Integer;
  Page: TWinControl;
  Tab: TFileMarkdownTab;
  Norm: string;
begin
  Result := nil;
  if not Assigned(FFraCenterTabs) then Exit;
  Norm := ExpandFileName(APath);
  for I := 0 to FFraCenterTabs.PageCount - 1 do begin
    Page := FFraCenterTabs.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TFileMarkdownTab) then begin
      Tab := TFileMarkdownTab(Page.Controls[0]);
      if SameText(ExpandFileName(Tab.FilePath), Norm) then
        Exit(Tab);
    end;
  end;
end;

procedure TLazyCodingAgentForm.OpenMarkdownInCenterTab(const APath: string);
var
  Path, Cap: string;
  Tab: TFileMarkdownTab;
  Page: TPanel;
  Idx: Integer;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    ShowMessage('File not found.');
    Exit;
  end;
  Tab := FindMarkdownTabByPath(Path);
  if Tab <> nil then begin
    Idx := FFraCenterTabs.IndexOfBody(Tab.Parent);
    if Idx >= 0 then
      FFraCenterTabs.ActivePageIndex := Idx;
    Exit;
  end;
  Cap := ExtractFileName(Path) + ' [Preview]';
  Page := FFraCenterTabs.AddPage(Cap, True);
  Tab := TFileMarkdownTab.Create(Page);
  Tab.Parent := Page;
  Tab.Align := alClient;
  if not Tab.LoadFile(Path) then begin
    FFraCenterTabs.RemovePage(FFraCenterTabs.PageCount - 1);
    ShowMessage('Could not open file.');
    Exit;
  end;
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  Tab.ApplyTheme(FState.Theme);
end;

function TLazyCodingAgentForm.ActiveFileEditorTab: TFileEditorTab;
var
  Page: TWinControl;
  Idx: Integer;
begin
  Result := nil;
  if not Assigned(FFraCenterTabs) then Exit;
  Idx := FFraCenterTabs.ActivePageIndex;
  Page := FFraCenterTabs.PageBody(Idx);
  if Assigned(Page) and (Page.ControlCount > 0) and (Page.Controls[0] is TFileEditorTab) then
    Result := TFileEditorTab(Page.Controls[0]);
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
  Path, Cap: string;
  Tab: TFileEditorTab;
  Page: TPanel;
  Idx: Integer;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    ShowMessage('File not found.');
    Exit;
  end;
  Tab := FindEditorTabByPath(Path);
  if Tab <> nil then begin
    Idx := FFraCenterTabs.IndexOfBody(Tab.Parent);
    if Idx >= 0 then
      FFraCenterTabs.ActivePageIndex := Idx;
    Exit;
  end;
  Cap := ExtractFileName(Path);
  Page := FFraCenterTabs.AddPage(Cap, True);
  Tab := TFileEditorTab.Create(Page);
  Tab.Parent := Page;
  Tab.Align := alClient;
  if not Tab.LoadFile(Path) then begin
    FFraCenterTabs.RemovePage(FFraCenterTabs.PageCount - 1);
    ShowMessage('Could not open file.');
    Exit;
  end;
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  Tab.ApplyTheme(FState.Theme);
  if Assigned(FSyntaxSchemes) then
    Tab.ApplySyntaxScheme(FSyntaxSchemes.ActiveScheme);
end;

function TLazyCodingAgentForm.CenterEditorTabCloseAllow: Boolean;
begin
  if not Assigned(FFraCenterTabs) then
    Exit(True);
  Result := CenterEditorCloseAllowForIndex(FFraCenterTabs.ActivePageIndex);
end;

procedure TLazyCodingAgentForm.ApplyCenterEditorThemes;
var
  I: Integer;
  Page: TWinControl;
  Tab: TFileEditorTab;
  MdTab: TFileMarkdownTab;
begin
  if not Assigned(FFraCenterTabs) then Exit;
  for I := 0 to FFraCenterTabs.PageCount - 1 do begin
    Page := FFraCenterTabs.PageBody(I);
    if not Assigned(Page) or (Page.ControlCount = 0) then Continue;
    if Page.Controls[0] is TFileEditorTab then begin
      Tab := TFileEditorTab(Page.Controls[0]);
      Tab.ApplyTheme(FState.Theme);
    end else if Page.Controls[0] is TFileMarkdownTab then begin
      MdTab := TFileMarkdownTab(Page.Controls[0]);
      MdTab.ApplyTheme(FState.Theme);
    end;
  end;
end;

procedure TLazyCodingAgentForm.RefreshAllEditorSchemes;
var
  I: Integer;
  Page: TWinControl;
  Tab: TFileEditorTab;
begin
  if not Assigned(FFraCenterTabs) or not Assigned(FSyntaxSchemes) then Exit;
  for I := 0 to FFraCenterTabs.PageCount - 1 do begin
    Page := FFraCenterTabs.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TFileEditorTab) then begin
      Tab := TFileEditorTab(Page.Controls[0]);
      Tab.ApplySyntaxScheme(FSyntaxSchemes.ActiveScheme);
    end;
  end;
end;

function TLazyCodingAgentForm.SaveActiveEditorFile: Boolean;
var
  Tab: TFileEditorTab;
  Idx: Integer;
begin
  Tab := ActiveFileEditorTab;
  if Tab = nil then
    Exit(False);
  Result := Tab.SaveFile;
  if Result and Assigned(Tab.Parent) and Assigned(FFraCenterTabs) then begin
    Idx := FFraCenterTabs.IndexOfBody(Tab.Parent);
    if Idx >= 0 then
      FFraCenterTabs.SetPageCaption(Idx, ExtractFileName(Tab.FilePath));
  end;
end;

function TLazyCodingAgentForm.PromptAllDirtyEditors: Boolean;
var
  I: Integer;
  Page: TWinControl;
  Tab: TFileEditorTab;
begin
  if not Assigned(FFraCenterTabs) then
    Exit(True);
  for I := 0 to FFraCenterTabs.PageCount - 1 do begin
    if I = FChatCenterTabIndex then Continue;
    Page := FFraCenterTabs.PageBody(I);
    if not Assigned(Page) then Continue;
    if (Page.ControlCount > 0) and (Page.Controls[0] is TFileEditorTab) then begin
      Tab := TFileEditorTab(Page.Controls[0]);
      if Tab.Modified and not Tab.PromptSaveIfModified then
        Exit(False);
    end;
  end;
  Result := True;
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
  RefreshAllEditorSchemes;
  RebuildActiveSchemeMenu;
end;

procedure TLazyCodingAgentForm.MnuViewSyntaxSchemesClick(Sender: TObject);
var
  SchemesChanged: Boolean;
begin
  if not Assigned(FSyntaxSchemes) then Exit;
  TSyntaxSchemesForm.Execute(Self, FState.Theme, FSyntaxSchemes, SchemesChanged);
  if SchemesChanged then begin
    RefreshAllEditorSchemes;
    RebuildActiveSchemeMenu;
  end;
end;

procedure TLazyCodingAgentForm.MnuFileSaveFileClick(Sender: TObject);
begin
  if not SaveActiveEditorFile then
    ShowMessage('No file editor tab is active.');
end;

end.
