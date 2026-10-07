unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, uAppTypes, uTheme, uWorkspaceState, uDockPanel,
  uNavigationPanel, uChatPanel, uAppLogo;

type
  { TForm1 }
  TForm1 = class(TForm)
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
    mnuAgent: TMenuItem;
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

    // Published Event Handlers (Form Designer connected)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MnuViewToggleThemeClick(Sender: TObject);
    procedure MnuViewResetLayoutClick(Sender: TObject);
    procedure MnuFileNewClick(Sender: TObject);
    procedure MnuFileOpenClick(Sender: TObject);
    procedure MnuFileSaveClick(Sender: TObject);
    procedure MnuFileExitClick(Sender: TObject);
    procedure MnuHelpAboutClick(Sender: TObject);
  private
    FState: TWorkspaceState;
    FUpdatingState: Boolean;

    // Sub-components hosted inside visually designed panels
    FNavRail: TNavRailControl;
    FDockNav: TDockPanel;
    FNavContent: TNavContentControl;

    FDockChat: TDockPanel;
    FChatContent: TChatPanel;

    FDockReserved: TDockPanel;
    FReservedMemo: TMemo;

    procedure InitWorkspaceSubControls;
    procedure PopulateMenusAndCombos;
    procedure StateChanged(Sender: TObject);
    procedure ApplyAllThemes;
    procedure RebuildWindowMenu;

    procedure NavRailSelect(Sender: TObject);
    procedure DockPanelAction(Sender: TObject; AId: TPanelId; AAction: TDockPanelAction);
    procedure ChatPrompt(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string);
    procedure ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
    procedure ChatModelChange(Sender: TObject; const AModel: string);
    procedure MenuSelectNav(Sender: TObject);
    procedure MenuSelectMode(Sender: TObject);
    procedure MenuTogglePanel(Sender: TObject);
    procedure MenuDetachPanel(Sender: TObject);
    procedure MenuAttachPanel(Sender: TObject);
  public
    property State: TWorkspaceState read FState;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
var
  AppIcoPath: string;
begin
  Caption := 'LazyCodingAgent — AI Workspace';
  FUpdatingState := False;

  AppIcoPath := ExtractFilePath(Application.ExeName) + 'lazycodingagent.ico';
  if FileExists(AppIcoPath) then begin
    try
      Self.Icon.LoadFromFile(AppIcoPath);
      Application.Icon.LoadFromFile(AppIcoPath);
    except
    end;
  end;

  FState := TWorkspaceState.Create;
  FState.Load;
  FState.OnChange := @StateChanged;

  InitWorkspaceSubControls;
  PopulateMenusAndCombos;

  StateChanged(Self);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FState) then begin
    FState.Save;
    FreeAndNil(FState);
  end;
end;

procedure TForm1.InitWorkspaceSubControls;
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
  FDockReserved.Content := FReservedMemo;
end;

procedure TForm1.PopulateMenusAndCombos;
var
  Nav: TNavigationItem;
  Mode: TWorkspaceMode;
  SubItem: TMenuItem;
begin
  // Populate Workspace Menu
  mnuWorkspace.Clear;
  for Nav := Low(TNavigationItem) to High(TNavigationItem) do begin
    SubItem := TMenuItem.Create(mnuWorkspace);
    SubItem.Caption := NavigationCaption(Nav);
    SubItem.Hint := NavigationHint(Nav);
    SubItem.Tag := Ord(Nav);
    SubItem.OnClick := @MenuSelectNav;
    mnuWorkspace.Add(SubItem);
  end;

  // Populate Agent Menu
  mnuAgent.Clear;
  for Mode := Low(TWorkspaceMode) to High(TWorkspaceMode) do begin
    SubItem := TMenuItem.Create(mnuAgent);
    SubItem.Caption := 'Mode: ' + WorkspaceModeCaption(Mode);
    SubItem.Hint := WorkspaceModeDesc(Mode);
    SubItem.Tag := Ord(Mode);
    SubItem.OnClick := @MenuSelectMode;
    mnuAgent.Add(SubItem);
  end;
end;

procedure TForm1.StateChanged(Sender: TObject);
var
  L, T, W, H: Integer;
begin
  if FUpdatingState then Exit;
  FUpdatingState := True;
  try
    // 1. Navigation selection
    if Assigned(FNavRail) then
      FNavRail.SetSelected(FState.Navigation);

    if Assigned(FNavContent) then
      FNavContent.SetSelected(FState.Navigation, FState.WorkspaceName);

    // 2. Chat mode & model
    if Assigned(FChatContent) then begin
      FChatContent.SetWorkspace(FState.WorkspaceName);
      FChatContent.SetMode(FState.Mode);
      FChatContent.SetModel(FState.Model);
    end;

    // 3. Navigation Panel Dock / Float / Visible
    if not FState.IsPanelVisible(piNavigation) then begin
      pnlNavHost.Visible := False;
      splNav.Visible := False;
      if FDockNav.IsDetached then
        FDockNav.FloatingForm.Hide;
    end else if FState.IsPanelFloating(piNavigation) then begin
      pnlNavHost.Visible := False;
      splNav.Visible := False;
      FState.GetPanelBounds(piNavigation, L, T, W, H);
      FDockNav.DetachToWindow(L, T, W, H);
    end else begin
      FDockNav.AttachToHost(pnlNavHost);
      pnlNavHost.Visible := True;
      splNav.Visible := True;
    end;

    // 4. Chat Panel Dock / Float / Visible
    if not FState.IsPanelVisible(piChat) then begin
      pnlChatHost.Visible := False;
      if FDockChat.IsDetached then
        FDockChat.FloatingForm.Hide;
    end else if FState.IsPanelFloating(piChat) then begin
      pnlChatHost.Visible := False;
      FState.GetPanelBounds(piChat, L, T, W, H);
      FDockChat.DetachToWindow(L, T, W, H);
    end else begin
      FDockChat.AttachToHost(pnlChatHost);
      pnlChatHost.Visible := True;
    end;

    // 5. Reserved / Instructions Panel Dock / Float / Visible
    if not FState.IsPanelVisible(piReserved) then begin
      pnlReservedHost.Visible := False;
      splReserved.Visible := False;
      if FDockReserved.IsDetached then
        FDockReserved.FloatingForm.Hide;
    end else if FState.IsPanelFloating(piReserved) then begin
      pnlReservedHost.Visible := False;
      splReserved.Visible := False;
      FState.GetPanelBounds(piReserved, L, T, W, H);
      FDockReserved.DetachToWindow(L, T, W, H);
    end else begin
      FDockReserved.AttachToHost(pnlReservedHost);
      pnlReservedHost.Visible := True;
      splReserved.Visible := True;
    end;

    // 6. Status Bar
    StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s',
      [FState.WorkspaceName, WorkspaceModeCaption(FState.Mode), FState.Model]);

    // 7. Rebuild Window menu and apply themes
    RebuildWindowMenu;
    ApplyAllThemes;
  finally
    FUpdatingState := False;
  end;
end;

procedure TForm1.ApplyAllThemes;
var
  P: TThemePalette;
begin
  P := ThemePalette(FState.Theme);

  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';

  pnlMainContainer.Color := P.Background;
  pnlNavRailHost.Color := P.RailBg;
  pnlNavHost.Color := P.Surface;
  pnlChatHost.Color := P.Background;
  pnlReservedHost.Color := P.Surface;

  splNav.Color := P.SplitterColor;
  splReserved.Color := P.SplitterColor;

  StatusBar1.Color := P.HeaderBg;
  StatusBar1.Font.Color := P.TextMuted;

  if Assigned(FNavRail) then
    FNavRail.ApplyTheme(FState.Theme);

  if Assigned(FDockNav) then
    FDockNav.ApplyTheme(FState.Theme);

  if Assigned(FNavContent) then
    FNavContent.ApplyTheme(FState.Theme);

  if Assigned(FDockChat) then
    FDockChat.ApplyTheme(FState.Theme);

  if Assigned(FChatContent) then
    FChatContent.ApplyTheme(FState.Theme);

  if Assigned(FDockReserved) then
    FDockReserved.ApplyTheme(FState.Theme);

  if Assigned(FReservedMemo) then begin
    FReservedMemo.Color := P.Surface;
    FReservedMemo.Font.Color := P.Text;
  end;
end;

procedure TForm1.RebuildWindowMenu;
var
  P: TPanelId;
  ItemVis, ItemAction: TMenuItem;
begin
  // Clear dynamic panel visibility items
  while mnuPanelsVisibility.Count > 0 do
    mnuPanelsVisibility.Delete(0);

  // Clear top-level Window menu actions except the Panels visibility submenu
  while mnuWindow.Count > 1 do
    mnuWindow.Delete(1);

  for P := Low(TPanelId) to High(TPanelId) do begin
    // Visibility toggle item
    ItemVis := TMenuItem.Create(mnuPanelsVisibility);
    ItemVis.Caption := PanelCaption(P);
    ItemVis.Tag := Ord(P);
    ItemVis.Checked := FState.IsPanelVisible(P);
    ItemVis.OnClick := @MenuTogglePanel;
    mnuPanelsVisibility.Add(ItemVis);

    // Float / Dock action item
    ItemAction := TMenuItem.Create(mnuWindow);
    ItemAction.Tag := Ord(P);
    if FState.IsPanelFloating(P) then begin
      ItemAction.Caption := 'Dock ' + PanelCaption(P);
      ItemAction.OnClick := @MenuAttachPanel;
    end else begin
      ItemAction.Caption := 'Detach ' + PanelCaption(P) + ' to Window';
      ItemAction.OnClick := @MenuDetachPanel;
    end;
    mnuWindow.Add(ItemAction);
  end;
end;

procedure TForm1.NavRailSelect(Sender: TObject);
begin
  FState.SetNavigation(FNavRail.Selected);
end;

procedure TForm1.DockPanelAction(Sender: TObject; AId: TPanelId; AAction: TDockPanelAction);
var
  L, T, W, H: Integer;
begin
  case AAction of
    dpaHide:
      FState.SetPanelVisible(AId, False);
    dpaDetach:
      begin
        if not FState.GetPanelBounds(AId, L, T, W, H) then begin
          L := Left + 80;
          T := Top + 80;
          W := 480;
          H := 500;
          FState.SetPanelBounds(AId, L, T, W, H);
        end;
        FState.SetPanelFloating(AId, True);
        FState.SetPanelVisible(AId, True);
      end;
    dpaAttach:
      begin
        FState.SetPanelFloating(AId, False);
        FState.SetPanelVisible(AId, True);
      end;
  end;
end;

procedure TForm1.ChatPrompt(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string);
begin
  FState.SetMode(AMode);
  FState.SetModel(AModel);
end;

procedure TForm1.ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
begin
  FState.SetMode(AMode);
end;

procedure TForm1.ChatModelChange(Sender: TObject; const AModel: string);
begin
  FState.SetModel(AModel);
end;

procedure TForm1.MenuSelectNav(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetNavigation(TNavigationItem(TMenuItem(Sender).Tag));
end;

procedure TForm1.MenuSelectMode(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetMode(TWorkspaceMode(TMenuItem(Sender).Tag));
end;

procedure TForm1.MenuTogglePanel(Sender: TObject);
var
  Pid: TPanelId;
begin
  if Sender is TMenuItem then begin
    Pid := TPanelId(TMenuItem(Sender).Tag);
    FState.SetPanelVisible(Pid, not FState.IsPanelVisible(Pid));
  end;
end;

procedure TForm1.MenuDetachPanel(Sender: TObject);
begin
  if Sender is TMenuItem then
    DockPanelAction(Self, TPanelId(TMenuItem(Sender).Tag), dpaDetach);
end;

procedure TForm1.MenuAttachPanel(Sender: TObject);
begin
  if Sender is TMenuItem then
    DockPanelAction(Self, TPanelId(TMenuItem(Sender).Tag), dpaAttach);
end;

procedure TForm1.MnuViewToggleThemeClick(Sender: TObject);
begin
  if FState.Theme = tkDark then
    FState.SetTheme(tkLight)
  else
    FState.SetTheme(tkDark);
end;

procedure TForm1.MnuViewResetLayoutClick(Sender: TObject);
begin
  FState.ResetLayout;
end;

procedure TForm1.MnuFileNewClick(Sender: TObject);
begin
  FState.WorkspaceName := 'NewAgentProject';
  StateChanged(Self);
end;

procedure TForm1.MnuFileOpenClick(Sender: TObject);
var
  Dir: string;
begin
  if SelectDirectory('Select Project Directory', '', Dir) then begin
    FState.WorkspaceName := ExtractFileName(ExcludeTrailingPathDelimiter(Dir));
    StateChanged(Self);
  end;
end;

procedure TForm1.MnuFileSaveClick(Sender: TObject);
begin
  FState.Save;
  ShowMessage('Workspace state saved.');
end;

procedure TForm1.MnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TForm1.MnuHelpAboutClick(Sender: TObject);
begin
  ShowMessage('LazyCodingAgent v0.2' + sLineBreak +
              'Cross-platform Desktop AI Coding Assistant' + sLineBreak +
              'Built with Free Pascal & Lazarus LCL');
end;

end.
