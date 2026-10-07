unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, uAppTypes, uAgentTypes, uAgentTools, uTheme, uWorkspaceState, uDockPanel,
  uNavigationPanel, uChatPanel, uAppLogo, uAgentEngine, uCustomTabControl, frmSettings,
  frmWorkspaceRules, uUtilityPlanTab, fpjson, jsonparser;

type
  { TLazyCodingAgentForm }
  TLazyCodingAgentForm = class(TForm)
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuFileNew: TMenuItem;
    mnuFileOpen: TMenuItem;
    mnuFileSave: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuFileExit: TMenuItem;
    mnuView: TMenuItem;
    mnuViewToggleTheme: TMenuItem;
    mnuViewResetLayout: TMenuItem;
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
    mnuHelpAbout: TMenuItem;

    StatusBar1: TStatusBar;

    pnlMainContainer: TPanel;
    pnlNavRailHost: TPanel;
    pnlNavHost: TPanel;
    splNav: TSplitter;
    pnlChatHost: TPanel;
    splReserved: TSplitter;
    pnlReservedHost: TPanel;
    splUtility: TSplitter;
    pnlUtilityHost: TPanel;

    // Published Event Handlers (Form Designer connected)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure MnuViewToggleThemeClick(Sender: TObject);
    procedure MnuViewResetLayoutClick(Sender: TObject);
    procedure MnuFileNewClick(Sender: TObject);
    procedure MnuFileOpenClick(Sender: TObject);
    procedure MnuFileSaveClick(Sender: TObject);
    procedure MnuFileExitClick(Sender: TObject);
    procedure MnuAgentClearHistoryClick(Sender: TObject);
    procedure MnuAgentStopClick(Sender: TObject);
    procedure MnuSettingsOptionsClick(Sender: TObject);
    procedure MnuWorkspaceProjectRulesClick(Sender: TObject);
    procedure MnuHelpAboutClick(Sender: TObject);
  private
    FState: TWorkspaceState;
    FAgent: TAgentEngine;
    FUpdatingState: Boolean;
    FPendingInitialDockLayout: Boolean;

    // Sub-components hosted inside visually designed panels
    FNavRail: TNavRailControl;
    FDockNav: TDockPanel;
    FNavContent: TNavContentControl;

    FDockChat: TDockPanel;
    FChatContent: TChatPanel;

    FDockReserved: TDockPanel;
    FReservedMemo: TMemo;

    FDockUtility: TDockPanel;
    FPageControlUtility: TLazyTabControl;
    FTabSheetBlank: TLazyTabPage;
    FCurrentRunMode: TWorkspaceMode;
    FPlanSavedThisRun: Boolean;

    function ParsePlanToolSuccess(const AResult: TToolExecutionResult;
      out APath, AContent: string): Boolean;
    procedure OpenPlanInUtilityTab(const APath, AContent: string);
    procedure TrySaveProposedPlanFromChat;
    procedure PlanBuildRequested(Sender: TObject; const APlanPath, APlanContent: string);
    procedure ApplyUtilityPlanTabThemes;

    procedure InitWorkspaceSubControls;
    procedure PopulateMenusAndCombos;
    procedure StateChanged(Sender: TObject);
    procedure ApplyDockPanelsLayout;
    procedure ApplyAllThemes;
    procedure ApplyPlatformChromeThemes;
    procedure RebuildWindowMenu;

    procedure NavRailSelect(Sender: TObject);
    procedure DockPanelAction(Sender: TObject; AId: TPanelId; AAction: TDockPanelAction);
    procedure ChatPrompt(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string);
    procedure ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
    procedure ChatModelChange(Sender: TObject; const AModel: string);
    procedure ChatCancel(Sender: TObject);

    // Agent Engine Callbacks
    procedure AgentStateChange(Sender: TObject; AOldState, ANewState: TAgentState);
    procedure AgentMessageAdded(Sender: TObject; const AMsg: TChatMessage);
    procedure AgentToolCall(Sender: TObject; const AToolName, AArgs: string);
    procedure AgentToolResult(Sender: TObject; const AToolName: string; const AResult: TToolExecutionResult);

    procedure MenuSelectNav(Sender: TObject);
    procedure MenuSelectMode(Sender: TObject);
    procedure MenuTogglePanel(Sender: TObject);
    procedure MenuDetachPanel(Sender: TObject);
    procedure MenuAttachPanel(Sender: TObject);
    procedure FinalizeDockPanelForClose(ADock: TDockPanel; AId: TPanelId);
  public
    property State: TWorkspaceState read FState;
    property Agent: TAgentEngine read FAgent;
  end;

var
  LazyCodingAgentForm: TLazyCodingAgentForm;

implementation

{$R *.lfm}

{ TLazyCodingAgentForm }

procedure TLazyCodingAgentForm.FormCreate(Sender: TObject);
begin
  Caption := 'LazyCodingAgent — AI Workspace';
  FUpdatingState := False;

  FState := TWorkspaceState.Create;
  FState.Load;
  FState.OnChange := @StateChanged;

  FAgent := TAgentEngine.Create(FState.WorkspaceRoot);
  FAgent.OnStateChange := @AgentStateChange;
  FAgent.OnMessageAdded := @AgentMessageAdded;
  FAgent.OnToolCall := @AgentToolCall;
  FAgent.OnToolResult := @AgentToolResult;

  // Sync state to agent client
  FAgent.Client.Provider := FState.Provider;
  FAgent.Client.ApiKey := FState.ApiKey;
  FAgent.Client.BaseUrl := FState.BaseUrl;
  FAgent.Client.Model := FState.Model;
  FAgent.Client.Temperature := FState.Temperature;
  FAgent.Client.MaxTokens := FState.MaxTokens;
  FAgent.MaxSteps := FState.MaxSteps;

  mnuWorkspaceSepRules.Tag := -1;
  mnuWorkspaceProjectRules.Tag := -1;

  InitWorkspaceSubControls;
  PopulateMenusAndCombos;

  FPendingInitialDockLayout := True;
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.FormShow(Sender: TObject);
begin
  if FPendingInitialDockLayout then begin
    FPendingInitialDockLayout := False;
    ApplyDockPanelsLayout;
  end;
  ApplyPlatformChromeThemes;
end;

procedure TLazyCodingAgentForm.FinalizeDockPanelForClose(ADock: TDockPanel; AId: TPanelId);
begin
  if not Assigned(ADock) or not Assigned(ADock.FloatingForm) then Exit;
  with ADock.FloatingForm do
    FState.SetPanelBounds(AId, Left, Top, Width, Height);
  ADock.PrepareForApplicationClose;
end;

procedure TLazyCodingAgentForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
  if not Assigned(FState) then Exit;
  FinalizeDockPanelForClose(FDockNav, piNavigation);
  FinalizeDockPanelForClose(FDockChat, piChat);
  FinalizeDockPanelForClose(FDockReserved, piReserved);
  FinalizeDockPanelForClose(FDockUtility, piUtility);
end;

procedure TLazyCodingAgentForm.FormDestroy(Sender: TObject);
begin
  if Assigned(FAgent) then
    FreeAndNil(FAgent);

  if Assigned(FState) then begin
    FState.Save;
    FreeAndNil(FState);
  end;
end;

procedure TLazyCodingAgentForm.InitWorkspaceSubControls;
begin
  // 1. Navigation Rail hosted inside pnlNavRailHost
  FNavRail := TNavRailControl.Create(pnlNavRailHost);
  FNavRail.Parent := pnlNavRailHost;
  FNavRail.Align := alClient;
  FNavRail.OnSelect := @NavRailSelect;

  // 2. Navigation Content inside Dock Panel
  FDockNav := TDockPanel.Create(pnlNavHost);
  FDockNav.Parent := pnlNavHost;
  FDockNav.Align := alClient;
  FDockNav.Configure(piNavigation, PanelCaption(piNavigation), @DockPanelAction);

  FNavContent := TNavContentControl.Create(FDockNav);
  FDockNav.Content := FNavContent;

  // 3. Center Chat Panel inside Dock Panel
  FDockChat := TDockPanel.Create(pnlChatHost);
  FDockChat.Parent := pnlChatHost;
  FDockChat.Align := alClient;
  FDockChat.Configure(piChat, PanelCaption(piChat), @DockPanelAction);

  FChatContent := TChatPanel.Create(FDockChat);
  FChatContent.OnPrompt := @ChatPrompt;
  FChatContent.OnModeChange := @ChatModeChange;
  FChatContent.OnModelChange := @ChatModelChange;
  FChatContent.OnCancel := @ChatCancel;
  FDockChat.Content := FChatContent;

  // 4. Instructions / Reserved panel inside Dock Panel
  FDockReserved := TDockPanel.Create(pnlReservedHost);
  FDockReserved.Parent := pnlReservedHost;
  FDockReserved.Align := alClient;
  FDockReserved.Configure(piReserved, PanelCaption(piReserved), @DockPanelAction);

  FReservedMemo := TMemo.Create(FDockReserved);
  FReservedMemo.BorderStyle := bsNone;
  FReservedMemo.ScrollBars := ssVertical;
  FReservedMemo.Lines.Add('=== Workspace Context & Guidelines ===');
  FReservedMemo.Lines.Add('');
  FReservedMemo.Lines.Add('• Follow single responsibility principles.');
  FReservedMemo.Lines.Add('• Visual Form Designer first with modern styling.');
  FReservedMemo.Lines.Add('• Dark-first modern design across all platforms.');
  FReservedMemo.Lines.Add('• Detachable windows work across multi-monitors.');
  FReservedMemo.Lines.Add('• Cross-platform Free Pascal / LCL target.');
  FReservedMemo.Lines.Add('• Autonomous tool execution with live logging.');
  FDockReserved.Content := FReservedMemo;

  // 5. Utility / TabPage panel inside Dock Panel (Right corner)
  FDockUtility := TDockPanel.Create(pnlUtilityHost);
  FDockUtility.Parent := pnlUtilityHost;
  FDockUtility.Align := alClient;
  FDockUtility.Configure(piUtility, PanelCaption(piUtility), @DockPanelAction);

  FPageControlUtility := TLazyTabControl.Create(FDockUtility);
  FTabSheetBlank := FPageControlUtility.AddPage('Workspace Scratchpad');
  FTabSheetBlank.CanClose := False;
  FDockUtility.Content := FPageControlUtility;
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
    if (mnuWorkspace.Items[I].Tag >= Ord(Low(TNavigationItem))) and
       (mnuWorkspace.Items[I].Tag <= Ord(High(TNavigationItem))) then
      mnuWorkspace.Delete(I)
    else
      Inc(I);
  end;

  for Nav := High(TNavigationItem) downto Low(TNavigationItem) do begin
    SubItem := TMenuItem.Create(mnuWorkspace);
    SubItem.Caption := NavigationCaption(Nav);
    SubItem.Hint := NavigationHint(Nav);
    SubItem.Tag := Ord(Nav);
    SubItem.OnClick := @MenuSelectNav;
    mnuWorkspace.Insert(0, SubItem);
  end;

  RebuildWindowMenu;
end;

procedure TLazyCodingAgentForm.ApplyDockPanelsLayout;
var
  L, T, W, H: Integer;
begin
  // Navigation Dock Panel
  pnlNavHost.Visible := FState.IsPanelVisible(piNavigation) and not FState.IsPanelFloating(piNavigation);
  splNav.Visible := pnlNavHost.Visible;
  if FState.IsPanelFloating(piNavigation) then begin
    if FState.GetPanelBounds(piNavigation, L, T, W, H) then
      FDockNav.DetachToWindow(L, T, W, H);
  end else begin
    if FDockNav.IsDetached then
      FDockNav.AttachToHost(pnlNavHost);
    if not FState.IsPanelVisible(piNavigation) and Assigned(FDockNav.FloatingForm) then
      FDockNav.FloatingForm.Hide;
  end;

  // Chat Dock Panel
  pnlChatHost.Visible := FState.IsPanelVisible(piChat) and not FState.IsPanelFloating(piChat);
  if FState.IsPanelFloating(piChat) then begin
    if FState.GetPanelBounds(piChat, L, T, W, H) then
      FDockChat.DetachToWindow(L, T, W, H);
  end else begin
    if FDockChat.IsDetached then
      FDockChat.AttachToHost(pnlChatHost);
    if not FState.IsPanelVisible(piChat) and Assigned(FDockChat.FloatingForm) then
      FDockChat.FloatingForm.Hide;
  end;

  // Reserved Dock Panel
  pnlReservedHost.Visible := FState.IsPanelVisible(piReserved) and not FState.IsPanelFloating(piReserved);
  splReserved.Visible := pnlReservedHost.Visible;
  if FState.IsPanelFloating(piReserved) then begin
    if FState.GetPanelBounds(piReserved, L, T, W, H) then
      FDockReserved.DetachToWindow(L, T, W, H);
  end else begin
    if FDockReserved.IsDetached then
      FDockReserved.AttachToHost(pnlReservedHost);
    if not FState.IsPanelVisible(piReserved) and Assigned(FDockReserved.FloatingForm) then
      FDockReserved.FloatingForm.Hide;
  end;

  // Utility Dock Panel
  pnlUtilityHost.Visible := FState.IsPanelVisible(piUtility) and not FState.IsPanelFloating(piUtility);
  splUtility.Visible := pnlUtilityHost.Visible;
  if FState.IsPanelFloating(piUtility) then begin
    if FState.GetPanelBounds(piUtility, L, T, W, H) then
      FDockUtility.DetachToWindow(L, T, W, H);
  end else begin
    if FDockUtility.IsDetached then
      FDockUtility.AttachToHost(pnlUtilityHost);
    if not FState.IsPanelVisible(piUtility) and Assigned(FDockUtility.FloatingForm) then
      FDockUtility.FloatingForm.Hide;
  end;
end;

procedure TLazyCodingAgentForm.StateChanged(Sender: TObject);
var
  I, N: Integer;
  Models: array of TSavedModel;
begin
  if FUpdatingState then Exit;
  FUpdatingState := True;
  try
    // Sync Agent client config
    if Assigned(FAgent) then begin
      FAgent.Client.Provider := FState.Provider;
      FAgent.Client.ApiKey := FState.ApiKey;
      FAgent.Client.BaseUrl := FState.BaseUrl;
      FAgent.Client.Model := FState.Model;
      FAgent.Client.Temperature := FState.Temperature;
      FAgent.Client.MaxTokens := FState.MaxTokens;
      FAgent.MaxSteps := FState.MaxSteps;
      FAgent.Context.WorkspaceRoot := FState.WorkspaceRoot;
    end;

    if Assigned(FNavRail) then
      FNavRail.SetSelected(FState.Navigation);
    if Assigned(FNavContent) then
      FNavContent.SetSelected(FState.Navigation, FState.WorkspaceName, FState.WorkspaceRoot);

    if Assigned(FChatContent) then begin
      N := FState.SavedModelCount(FState.Provider);
      SetLength(Models, N);
      for I := 0 to N - 1 do
        Models[I] := FState.GetSavedModel(FState.Provider, I);
      FChatContent.SetAvailableModels(Models);
      FChatContent.SetWorkspace(FState.WorkspaceName);
      FChatContent.SetMode(FState.Mode);
      FChatContent.SetModel(FState.Model);
    end;

    if not FPendingInitialDockLayout then
      ApplyDockPanelsLayout;

    ApplyAllThemes;
    RebuildWindowMenu;

    StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
      [FState.WorkspaceName, WorkspaceModeCaption(FState.Mode), FState.Model, AgentStateToString(FAgent.State)]);
  finally
    FUpdatingState := False;
  end;
end;

procedure TLazyCodingAgentForm.ApplyAllThemes;
var
  P: TThemePalette;
begin
  P := ThemePalette(FState.Theme);

  Color := P.Background;
  Font.Color := P.Text;
  pnlMainContainer.Color := P.Background;

  pnlNavRailHost.Color := P.RailBg;
  pnlNavHost.Color := P.Surface;
  pnlChatHost.Color := P.Background;
  pnlReservedHost.Color := P.Surface;
  pnlUtilityHost.Color := P.Surface;

  splNav.Color := P.Border;
  splReserved.Color := P.Border;
  splUtility.Color := P.Border;

  StatusBar1.Color := P.Surface;
  StatusBar1.Font.Color := P.TextMuted;

  if Assigned(FNavRail) then FNavRail.ApplyTheme(FState.Theme);
  if Assigned(FDockNav) then FDockNav.ApplyTheme(FState.Theme);
  if Assigned(FNavContent) then FNavContent.ApplyTheme(FState.Theme);

  if Assigned(FDockChat) then FDockChat.ApplyTheme(FState.Theme);
  if Assigned(FChatContent) then FChatContent.ApplyTheme(FState.Theme);

  if Assigned(FDockReserved) then FDockReserved.ApplyTheme(FState.Theme);
  if Assigned(FReservedMemo) then begin
    FReservedMemo.Color := P.Surface;
    FReservedMemo.Font.Color := P.Text;
    FReservedMemo.Font.Name := 'Segoe UI';
  end;

  if Assigned(FDockUtility) then FDockUtility.ApplyTheme(FState.Theme);
  if Assigned(FPageControlUtility) then begin
    FPageControlUtility.ApplyTheme(FState.Theme);
    ApplyUtilityPlanTabThemes;
  end;

  ApplyPlatformChromeThemes;
  Invalidate;
end;

procedure TLazyCodingAgentForm.ApplyPlatformChromeThemes;
begin
  ApplyPlatformChrome(Self, FState.Theme);
  if Assigned(FReservedMemo) then
    ApplyPlatformScrollableTheme(FReservedMemo, FState.Theme);
  if Assigned(FNavContent) then
    FNavContent.ApplyPlatformChrome(FState.Theme);
  if Assigned(FChatContent) then
    FChatContent.ApplyPlatformChrome(FState.Theme);
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
end;

procedure TLazyCodingAgentForm.NavRailSelect(Sender: TObject);
begin
  FState.SetNavigation(FNavRail.Selected);
end;

procedure TLazyCodingAgentForm.DockPanelAction(Sender: TObject; AId: TPanelId; AAction: TDockPanelAction);
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
begin
  FCurrentRunMode := AMode;
  FPlanSavedThisRun := False;
  FChatContent.SetRunning(True);
  try
    FAgent.StartRun(APrompt, AMode, AModel);
  finally
    FChatContent.SetRunning(False);
  end;
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
begin
  if Assigned(FAgent) then
    FAgent.RequestCancel;
end;

procedure TLazyCodingAgentForm.AgentStateChange(Sender: TObject; AOldState, ANewState: TAgentState);
begin
  StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
    [FState.WorkspaceName, WorkspaceModeCaption(FState.Mode), FState.Model, AgentStateToString(ANewState)]);
  if (ANewState = asFinished) and (FCurrentRunMode = wmPlan) and not FPlanSavedThisRun then
    TrySaveProposedPlanFromChat;
  Application.ProcessMessages;
end;

procedure TLazyCodingAgentForm.AgentMessageAdded(Sender: TObject; const AMsg: TChatMessage);
begin
  if Assigned(FChatContent) then begin
    if AMsg.Role = crTool then
      FChatContent.AppendToolMessage(AMsg, FState.DebuggingMode)
    else
      FChatContent.AppendMessage(AMsg);
  end;
  if Assigned(FNavContent) and (AMsg.Role = crTool) then
    FNavContent.AppendLog(Format('Tool Result: %s', [AMsg.VisualSummary]));
  Application.ProcessMessages;
end;

procedure TLazyCodingAgentForm.AgentToolCall(Sender: TObject; const AToolName, AArgs: string);
begin
  if Assigned(FNavContent) then
    FNavContent.AppendLog(Format('Tool Invoked: %s(%s)', [AToolName, AArgs]));
  Application.ProcessMessages;
end;

procedure TLazyCodingAgentForm.AgentToolResult(Sender: TObject; const AToolName: string; const AResult: TToolExecutionResult);
var
  PlanPath, PlanContent: string;
begin
  if Assigned(FNavContent) then
    FNavContent.AppendLog(Format('Tool Finished: %s => %s', [AToolName, AResult.Summary]));
  if SameText(AToolName, 'create_plan_file') then begin
    if ParsePlanToolSuccess(AResult, PlanPath, PlanContent) and (FCurrentRunMode = wmPlan) then begin
      FPlanSavedThisRun := True;
      OpenPlanInUtilityTab(PlanPath, PlanContent);
    end;
  end;
  Application.ProcessMessages;
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
  Page: TLazyTabPage;
  Tab: TUtilityPlanTab;
  Cap: string;
begin
  if not Assigned(FPageControlUtility) then Exit;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;

  Cap := ExtractFileName(APath);
  if Cap = '' then
    Cap := 'Plan';
  Page := FPageControlUtility.AddPage(Cap);
  Page.CanClose := True;
  Tab := TUtilityPlanTab.Create(Page);
  Tab.Parent := Page;
  Tab.Align := alClient;
  Tab.OnBuild := @PlanBuildRequested;
  Tab.LoadPlan(APath, AContent);
  Tab.ApplyTheme(FState.Theme);
  FPageControlUtility.ActivePage := Page;
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
  for I := FAgent.GetMessageCount - 1 downto 0 do begin
    Msg := FAgent.GetMessage(I);
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
      Res := FAgent.ExecuteToolDirect('create_plan_file', Args.AsJSON, wmPlan);
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

procedure TLazyCodingAgentForm.PlanBuildRequested(Sender: TObject; const APlanPath, APlanContent: string);
var
  Prompt: string;
begin
  if not Assigned(FChatContent) then Exit;
  if FChatContent.IsRunning then Exit;
  FState.SetMode(wmAgent);
  FChatContent.SetMode(wmAgent);
  Prompt := 'Implement the plan saved at ' + APlanPath +
    '. First inspect the project files, then carry out the plan completely.' +
    LineEnding + LineEnding + APlanContent;
  FChatContent.SubmitPrompt(Prompt);
end;

procedure TLazyCodingAgentForm.ApplyUtilityPlanTabThemes;
var
  I: Integer;
  Page: TLazyTabPage;
  Tab: TUtilityPlanTab;
begin
  if not Assigned(FPageControlUtility) then Exit;
  for I := 0 to FPageControlUtility.PageCount - 1 do begin
    Page := FPageControlUtility.Pages[I];
    if (Page.ControlCount > 0) and (Page.Controls[0] is TUtilityPlanTab) then begin
      Tab := TUtilityPlanTab(Page.Controls[0]);
      Tab.ApplyTheme(FState.Theme);
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
    DockPanelAction(Self, TPanelId(TMenuItem(Sender).Tag), dpaDetach);
end;

procedure TLazyCodingAgentForm.MenuAttachPanel(Sender: TObject);
begin
  if Sender is TMenuItem then
    DockPanelAction(Self, TPanelId(TMenuItem(Sender).Tag), dpaAttach);
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

procedure TLazyCodingAgentForm.MnuFileNewClick(Sender: TObject);
var
  WName: string;
begin
  WName := InputBox('New Workspace', 'Enter workspace name:', 'MyProject');
  if Trim(WName) <> '' then begin
    FState.WorkspaceName := WName;
    StateChanged(Self);
  end;
end;

procedure TLazyCodingAgentForm.MnuFileOpenClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := FState.WorkspaceRoot;
  if SelectDirectory('Select Workspace Directory', '', Dir) then begin
    FState.WorkspaceRoot := Dir;
    FState.WorkspaceName := ExtractFileName(Dir);
    StateChanged(Self);
  end;
end;

procedure TLazyCodingAgentForm.MnuFileSaveClick(Sender: TObject);
begin
  FState.Save;
  ShowMessage('Workspace configuration saved.');
end;

procedure TLazyCodingAgentForm.MnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TLazyCodingAgentForm.MnuAgentClearHistoryClick(Sender: TObject);
begin
  if Assigned(FAgent) then
    FAgent.ClearConversation;
  if Assigned(FChatContent) then
    FChatContent.ClearHistory;
end;

procedure TLazyCodingAgentForm.MnuAgentStopClick(Sender: TObject);
begin
  if Assigned(FAgent) then
    FAgent.RequestCancel;
end;

procedure TLazyCodingAgentForm.MnuSettingsOptionsClick(Sender: TObject);
begin
  if TSettingsForm.Execute(FState) then
    StateChanged(Self);
end;

procedure TLazyCodingAgentForm.MnuWorkspaceProjectRulesClick(Sender: TObject);
begin
  if Trim(FState.WorkspaceRoot) = '' then begin
    ShowMessage('Set a workspace project folder first (Settings or File → Open Project Folder).');
    Exit;
  end;
  TWorkspaceRulesForm.Execute(Self, FState.Theme, FState.WorkspaceRoot);
end;

procedure TLazyCodingAgentForm.MnuHelpAboutClick(Sender: TObject);
begin
  ShowMessage('LazyCodingAgent v1.0'#13#10 +
              'Standalone Desktop AI Coding Assistant'#13#10 +
              'Built with Free Pascal & Lazarus LCL');
end;

end.
