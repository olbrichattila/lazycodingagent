unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ComCtrls, uAppTypes, uTheme, uAppLogo;

type
  { TNavRailControl - Left sleek icon bar }
  TNavRailControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FHovered: Integer;
    FTheme: TThemeKind;
    FOnSelect: TNotifyEvent;
    function GetItemRect(AIndex: Integer): TRect;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem);
    property Selected: TNavigationItem read FSelected write SetSelected;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
  end;

  { TNavContentControl - Content panel hosting views inside the Nav Dock Host }
  TNavContentControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FTheme: TThemeKind;
    FWorkspaceName: string;
    FWorkspaceRoot: string;

    // Sub-controls
    FTitleLabel: TLabel;
    FSubLabel: TLabel;
    FFileList: TListBox;
    FTreeView: TTreeView;
    FMemoLogs: TMemo;
    FActionBtn: TButton;

    procedure ActionBtnClick(Sender: TObject);
    procedure PopulateFileTree(const ARoot: string);
    procedure RebuildView;
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
    procedure AppendLog(const ALogLine: string);
  end;

implementation

{ TNavRailControl }

constructor TNavRailControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 56;
  FSelected := niHome;
  FHovered := -1;
  FTheme := tkDark;
  ShowHint := True;
end;

procedure TNavRailControl.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Invalidate;
end;

procedure TNavRailControl.SetSelected(AItem: TNavigationItem);
begin
  if FSelected <> AItem then begin
    FSelected := AItem;
    Invalidate;
  end;
end;

function TNavRailControl.GetItemRect(AIndex: Integer): TRect;
var
  ItemH: Integer;
begin
  ItemH := 46;
  Result := Rect(4, 52 + AIndex * (ItemH + 4), Width - 4, 52 + (AIndex + 1) * (ItemH + 4) - 4);
end;

procedure TNavRailControl.Paint;
var
  P: TThemePalette;
  Item: TNavigationItem;
  I: Integer;
  R, IndicatorR: TRect;
  Sym, Cap: string;
begin
  P := ThemePalette(FTheme);

  // Background
  Canvas.Brush.Color := P.Surface;
  Canvas.FillRect(ClientRect);

  // Right vertical separator
  Canvas.Pen.Color := P.Border;
  Canvas.Line(Width - 1, 0, Width - 1, Height);

  // App Logo Top Icon
  DrawLazyAgentLogo(Canvas, Rect(12, 10, 44, 42), FTheme = tkDark);

  // Render Nav Buttons
  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    R := GetItemRect(I);
    Sym := NavigationIconSymbol(Item);
    Cap := NavigationCaption(Item);

    if Item = FSelected then begin
      Canvas.Brush.Color := P.SurfaceAlt;
      Canvas.Pen.Color := P.Border;
      Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);

      // Active Pill Indicator
      Canvas.Brush.Color := P.Accent;
      IndicatorR := Rect(R.Left + 1, R.Top + 10, R.Left + 4, R.Bottom - 10);
      Canvas.FillRect(IndicatorR);

      Canvas.Font.Color := P.Accent;
      Canvas.Font.Style := [fsBold];
    end else if I = FHovered then begin
      Canvas.Brush.Color := P.SurfaceAlt;
      Canvas.Pen.Color := P.Border;
      Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);
      Canvas.Font.Color := P.Text;
      Canvas.Font.Style := [];
    end else begin
      Canvas.Font.Color := P.TextMuted;
      Canvas.Font.Style := [];
    end;

    // Draw Icon Symbol
    Canvas.Font.Size := 13;
    Canvas.Font.Name := 'Segoe UI Symbol';
    Canvas.TextOut(R.Left + (R.Width - Canvas.TextWidth(Sym)) div 2, R.Top + 6, Sym);

    // Draw short caption
    Canvas.Font.Size := 7;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.TextOut(R.Left + (R.Width - Canvas.TextWidth(Cap)) div 2, R.Top + 27, Cap);

    Inc(I);
  end;
end;

procedure TNavRailControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Item: TNavigationItem;
  NewHover: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewHover := -1;
  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    if GetItemRect(I).Contains(Point(X, Y)) then begin
      NewHover := I;
      Hint := NavigationHint(Item);
      Break;
    end;
    Inc(I);
  end;

  if NewHover <> FHovered then begin
    FHovered := NewHover;
    Invalidate;
  end;
end;

procedure TNavRailControl.MouseLeave;
begin
  inherited MouseLeave;
  if FHovered <> -1 then begin
    FHovered := -1;
    Invalidate;
  end;
end;

procedure TNavRailControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Item: TNavigationItem;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    if GetItemRect(I).Contains(Point(X, Y)) then begin
      SetSelected(Item);
      if Assigned(FOnSelect) then
        FOnSelect(Self);
      Break;
    end;
    Inc(I);
  end;
end;

{ TNavContentControl }

constructor TNavContentControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FTheme := tkDark;
  FSelected := niHome;
  FWorkspaceName := 'LazyCodingAgent';
  FWorkspaceRoot := GetCurrentDir;

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := Self;
  FTitleLabel.AutoSize := False;
  FTitleLabel.Font.Size := 11;
  FTitleLabel.Font.Style := [fsBold];

  FSubLabel := TLabel.Create(Self);
  FSubLabel.Parent := Self;
  FSubLabel.AutoSize := False;
  FSubLabel.Font.Size := 8;

  FFileList := TListBox.Create(Self);
  FFileList.Parent := Self;
  FFileList.BorderStyle := bsNone;

  FTreeView := TTreeView.Create(Self);
  FTreeView.Parent := Self;
  FTreeView.BorderStyle := bsNone;
  FTreeView.ReadOnly := True;
  FTreeView.HideSelection := False;
  FTreeView.Visible := False;

  FMemoLogs := TMemo.Create(Self);
  FMemoLogs.Parent := Self;
  FMemoLogs.BorderStyle := bsNone;
  FMemoLogs.ReadOnly := True;
  FMemoLogs.ScrollBars := ssAutoBoth;
  FMemoLogs.Visible := False;

  FActionBtn := TButton.Create(Self);
  FActionBtn.Parent := Self;
  FActionBtn.Height := 28;
  FActionBtn.OnClick := @ActionBtnClick;

  UpdateLayout;
  RebuildView;
end;

procedure TNavContentControl.UpdateLayout;
var
  W, H: Integer;
begin
  W := Width - 24;
  if W < 10 then W := 10;
  H := Height;

  if Assigned(FTitleLabel) then
    FTitleLabel.SetBounds(12, 12, W, 22);

  if Assigned(FSubLabel) then
    FSubLabel.SetBounds(12, 36, W, 18);

  if Assigned(FFileList) then begin
    if H > 170 then
      FFileList.SetBounds(12, 60, W, H - 110)
    else
      FFileList.SetBounds(12, 60, W, 30);
  end;

  if Assigned(FTreeView) then begin
    if H > 170 then
      FTreeView.SetBounds(12, 60, W, H - 110)
    else
      FTreeView.SetBounds(12, 60, W, 30);
  end;

  if Assigned(FMemoLogs) then begin
    if H > 170 then
      FMemoLogs.SetBounds(12, 60, W, H - 110)
    else
      FMemoLogs.SetBounds(12, 60, W, 30);
  end;

  if Assigned(FActionBtn) then begin
    if H > 50 then
      FActionBtn.SetBounds(12, H - 40, W, 28)
    else
      FActionBtn.SetBounds(12, 10, W, 28);
  end;
end;

procedure TNavContentControl.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TNavContentControl.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.Surface;
  FTitleLabel.Font.Color := P.Text;
  FSubLabel.Font.Color := P.TextMuted;

  FFileList.Color := P.SurfaceAlt;
  FFileList.Font.Color := P.Text;
  FFileList.Font.Name := 'Segoe UI';

  FTreeView.Color := P.SurfaceAlt;
  FTreeView.Font.Color := P.Text;
  FTreeView.Font.Name := 'Segoe UI';

  FMemoLogs.Color := P.SurfaceAlt;
  FMemoLogs.Font.Color := P.Text;
  FMemoLogs.Font.Name := 'Consolas';

  Invalidate;
end;

procedure TNavContentControl.SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
begin
  FSelected := AItem;
  FWorkspaceName := AWorkspaceName;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := AWorkspaceRoot;
  RebuildView;
  Invalidate;
end;

procedure TNavContentControl.AppendLog(const ALogLine: string);
begin
  FMemoLogs.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss', Now), ALogLine]));
end;

procedure TNavContentControl.PopulateFileTree(const ARoot: string);
var
  RootNode: TTreeNode;

  procedure AddFolder(AParentNode: TTreeNode; const ADir: string);
  var
    Rec: TSearchRec;
    ChildNode: TTreeNode;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, Rec) = 0 then begin
      repeat
        if (Rec.Name = '.') or (Rec.Name = '..') or (Rec.Name = '.git') or (Rec.Name = 'lib') or (Rec.Name = 'backup') then
          Continue;

        if (Rec.Attr and faDirectory) <> 0 then begin
          ChildNode := FTreeView.Items.AddChild(AParentNode, '📁 ' + Rec.Name);
          AddFolder(ChildNode, IncludeTrailingPathDelimiter(ADir) + Rec.Name);
        end else begin
          FTreeView.Items.AddChild(AParentNode, '📄 ' + Rec.Name);
        end;
      until FindNext(Rec) <> 0;
      FindClose(Rec);
    end;
  end;

begin
  FTreeView.Items.Clear;
  RootNode := FTreeView.Items.Add(nil, '📦 ' + ExtractFileName(ARoot));
  AddFolder(RootNode, ARoot);
  RootNode.Expand(False);
end;

procedure TNavContentControl.ActionBtnClick(Sender: TObject);
var
  Dir: string;
begin
  case FSelected of
    niHome:
      ShowMessage('Workspace Status: Ready & connected.');
    niProjects:
      begin
        Dir := FWorkspaceRoot;
        if SelectDirectory('Select Workspace Directory', '', Dir) then begin
          FWorkspaceRoot := Dir;
          FWorkspaceName := ExtractFileName(Dir);
          RebuildView;
        end;
      end;
    niSessions:
      ShowMessage('New AI Chat Session Created.');
    niBots:
      ShowMessage('Configure Agent Models in Settings menu.');
    niTools:
      FMemoLogs.Lines.Clear;
    niTasks:
      ShowMessage('Task list synced with agent.');
  end;
end;

procedure TNavContentControl.RebuildView;
begin
  FFileList.Visible := False;
  FTreeView.Visible := False;
  FMemoLogs.Visible := False;

  case FSelected of
    niHome:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Workspace Overview';
        FSubLabel.Caption := 'Active Project: ' + FWorkspaceName;
        FFileList.Items.Clear;
        FFileList.Items.Add('📁 Project Root: ' + FWorkspaceRoot);
        FFileList.Items.Add('⚙ Target: x86_64 Free Pascal / Lazarus');
        FFileList.Items.Add('🤖 Local Autonomous Agent: Ready');
        FFileList.Items.Add('💬 Multi-Window Detachable Workspace');
        FActionBtn.Caption := '⚡ Quick Diagnostic Check';
      end;
    niProjects:
      begin
        FTreeView.Visible := True;
        FTitleLabel.Caption := 'Project Explorer';
        FSubLabel.Caption := 'Workspace Tree';
        PopulateFileTree(FWorkspaceRoot);
        FActionBtn.Caption := '📁 Change Workspace Root...';
      end;
    niSessions:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Chat Sessions';
        FSubLabel.Caption := 'Saved History & Tasks';
        FFileList.Items.Clear;
        FFileList.Items.Add('💬 Session 1: Current Active Workspace');
        FFileList.Items.Add('💬 Session 2: Refactoring & Tools');
        FFileList.Items.Add('💬 Session 3: AST & Diagnostics Test');
        FActionBtn.Caption := '+ New Chat Session';
      end;
    niBots:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Coding Agent Personas';
        FSubLabel.Caption := 'Modes & System Prompts';
        FFileList.Items.Clear;
        FFileList.Items.Add('⚡ Autopilot Agent (wmAgent)');
        FFileList.Items.Add('📋 Architect & Planner (wmPlan)');
        FFileList.Items.Add('💡 Code Assistant & Q&A (wmAsk)');
        FActionBtn.Caption := '⚙ Agent Settings...';
      end;
    niTools:
      begin
        FMemoLogs.Visible := True;
        FTitleLabel.Caption := 'Tool Execution & Logs';
        FSubLabel.Caption := 'Local Tool Terminal Output';
        if FMemoLogs.Lines.Count = 0 then
          FMemoLogs.Lines.Add('[Ready] Local tools initialized: read_file, write_file, list_dir, search_code, run_process, diagnostics, todo.');
        FActionBtn.Caption := '🗑 Clear Tool Logs';
      end;
    niTasks:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Task List & Checklist';
        FSubLabel.Caption := 'Autonomous Steps';
        FFileList.Items.Clear;
        FFileList.Items.Add('✔ 1. Define LLM & Agent Types');
        FFileList.Items.Add('✔ 2. Implement Local Tools Registry');
        FFileList.Items.Add('✔ 3. Build Autonomous ReAct Engine');
        FFileList.Items.Add('✔ 4. Create Dedicated Settings Form');
        FFileList.Items.Add('⏳ 5. Wire Navigation & Chat Stream');
        FActionBtn.Caption := '🔄 Refresh Checklist';
      end;
  end;
end;

end.
