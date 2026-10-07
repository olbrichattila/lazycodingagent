unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ComCtrls, uAppTypes, uTheme, uThemedButton, uAppLogo, uCodingAgentPresets;

type
  { TNavRailControl - Left sleek icon bar }
  TNavRailControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FHovered: Integer;
    FPressedIndex: Integer;
    FTheme: TThemeKind;
    FOnSelect: TNotifyEvent;
    function GetItemRect(AIndex: Integer): TRect;
    function HitTestItemIndex(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
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
    FActionBtn: TThemedButton;

    procedure ActionBtnClick(Sender: TObject);
    procedure FileListDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure PopulateFileTree(const ARoot: string);
    procedure RebuildView;
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
    procedure AppendLog(const ALogLine: string);
  end;

implementation

function MaxLayoutDim(V, MinV: Integer): Integer;
begin
  if V < MinV then
    Result := MinV
  else
    Result := V;
end;

procedure SetBoundsIfChanged(AControl: TControl; AL, AT, AW, AH: Integer);
begin
  if not Assigned(AControl) then Exit;
  if (AControl.Left = AL) and (AControl.Top = AT) and
     (AControl.Width = AW) and (AControl.Height = AH) then Exit;
  AControl.SetBounds(AL, AT, AW, AH);
end;

procedure GetRailItemStyle(P: TThemePalette; ASelected, AHover, APressed: Boolean;
  out DrawEdgeMarker: Boolean; out IconColor: TColor);
begin
  DrawEdgeMarker := False;
  if ASelected then begin
    DrawEdgeMarker := True;
    IconColor := P.Accent;
    if APressed then
      IconColor := P.AccentHover;
  end else if AHover or APressed then
    IconColor := P.Text
  else
    IconColor := P.TextMuted;
end;

{ TNavRailControl }

constructor TNavRailControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 56;
  FSelected := niHome;
  FHovered := -1;
  FPressedIndex := -1;
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
const
  ItemH = 40;
  ItemGap = 2;
begin
  Result := Rect(6, 48 + AIndex * (ItemH + ItemGap), Width - 6,
    48 + (AIndex + 1) * (ItemH + ItemGap) - ItemGap);
end;

function TNavRailControl.HitTestItemIndex(X, Y: Integer): Integer;
var
  I: Integer;
  Item: TNavigationItem;
begin
  Result := -1;
  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    if GetItemRect(I).Contains(Point(X, Y)) then
      Exit(I);
    Inc(I);
  end;
end;

procedure TNavRailControl.Paint;
var
  P: TThemePalette;
  Item: TNavigationItem;
  I: Integer;
  R, MarkerR: TRect;
  Sym: string;
  DrawEdgeMarker: Boolean;
  IconColor: TColor;
  IsSelected, IsHover, IsPressed: Boolean;
  IconY: Integer;
begin
  P := ThemePalette(FTheme);

  Canvas.Brush.Color := P.RailBg;
  Canvas.FillRect(ClientRect);

  Canvas.Pen.Color := P.Border;
  Canvas.Line(Width - 1, 0, Width - 1, Height);

  DrawLazyAgentLogo(Canvas, Rect(12, 10, 44, 42), FTheme = tkDark);

  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    R := GetItemRect(I);
    Sym := NavigationIconSymbol(Item);

    IsSelected := Item = FSelected;
    IsHover := I = FHovered;
    IsPressed := I = FPressedIndex;
    GetRailItemStyle(P, IsSelected, IsHover, IsPressed, DrawEdgeMarker, IconColor);

    if DrawEdgeMarker then begin
      Canvas.Brush.Color := P.Accent;
      MarkerR := Rect(0, R.Top + 8, 2, R.Bottom - 8);
      Canvas.FillRect(MarkerR);
    end;

    Canvas.Font.Style := [];
    Canvas.Font.Size := 16;
    Canvas.Font.Name := 'Segoe UI Symbol';
    Canvas.Font.Color := IconColor;
    IconY := R.Top + (R.Height - Canvas.TextHeight(Sym)) div 2;
    Canvas.Brush.Color := P.RailBg;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(R.Left + (R.Width - Canvas.TextWidth(Sym)) div 2, IconY, Sym);

    Inc(I);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TNavRailControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewHover := HitTestItemIndex(X, Y);
  if NewHover >= 0 then
    Hint := NavigationHint(TNavigationItem(NewHover));

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
  HitIndex: Integer;
  Item: TNavigationItem;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  HitIndex := HitTestItemIndex(X, Y);
  if HitIndex < 0 then Exit;

  FPressedIndex := HitIndex;
  MouseCapture := True;
  Invalidate;

  Item := TNavigationItem(HitIndex);
  SetSelected(Item);
  if Assigned(FOnSelect) then
    FOnSelect(Self);
end;

procedure TNavRailControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  if FPressedIndex <> -1 then begin
    FPressedIndex := -1;
    MouseCapture := False;
    Invalidate;
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
  FFileList.OnDrawItem := @FileListDrawItem;
  ConfigureThemedListBox(FFileList, FTheme);

  FTreeView := TTreeView.Create(Self);
  FTreeView.Parent := Self;
  FTreeView.ReadOnly := True;
  FTreeView.Visible := False;
  ConfigureThemedTreeView(FTreeView, FTheme);

  FMemoLogs := TMemo.Create(Self);
  FMemoLogs.Parent := Self;
  FMemoLogs.BorderStyle := bsNone;
  FMemoLogs.ReadOnly := True;
  FMemoLogs.ScrollBars := ssAutoBoth;
  FMemoLogs.Visible := False;

  FActionBtn := TThemedButton.Create(Self);
  FActionBtn.Parent := Self;
  FActionBtn.Height := 28;
  FActionBtn.ButtonRole := tbrPrimary;
  FActionBtn.OnClick := @ActionBtnClick;

  UpdateLayout;
  RebuildView;
end;

procedure TNavContentControl.UpdateLayout;
var
  W, H, ListH: Integer;
begin
  W := MaxLayoutDim(Width - 24, 8);
  H := Height;
  ListH := MaxLayoutDim(H - 110, 8);

  SetBoundsIfChanged(FTitleLabel, 12, 12, W, 22);
  SetBoundsIfChanged(FSubLabel, 12, 36, W, 18);
  SetBoundsIfChanged(FFileList, 12, 60, W, ListH);
  SetBoundsIfChanged(FTreeView, 12, 60, W, ListH);
  SetBoundsIfChanged(FMemoLogs, 12, 60, W, ListH);

  if H > 50 then
    SetBoundsIfChanged(FActionBtn, 12, H - 40, W, 28)
  else
    SetBoundsIfChanged(FActionBtn, 12, 10, W, 28);
end;

procedure TNavContentControl.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TNavContentControl.FileListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FTheme);
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

  ConfigureThemedListBox(FFileList, FTheme);
  ConfigureThemedTreeView(FTreeView, FTheme);

  FMemoLogs.Color := P.SurfaceAlt;
  FMemoLogs.Font.Color := P.Text;
  FMemoLogs.Font.Name := 'Consolas';

  if Assigned(FActionBtn) then
    FActionBtn.ApplyTheme(FTheme);

  Invalidate;
end;

procedure TNavContentControl.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  ApplyPlatformScrollableTheme(FFileList, ATheme);
  ApplyPlatformScrollableTheme(FTreeView, ATheme);
  ApplyPlatformScrollableTheme(FMemoLogs, ATheme);
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
var
  I: Integer;
  Preset: TCodingAgentPreset;
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
        ConfigureThemedTreeView(FTreeView, FTheme);
        FTreeView.Invalidate;
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
        FSubLabel.Caption := 'Modes & pre-defined models (OpenRouter)';
        FFileList.Items.Clear;
        FFileList.Items.Add('⚡ Autopilot Agent (wmAgent)');
        FFileList.Items.Add('📋 Architect & Planner (wmPlan)');
        FFileList.Items.Add('💡 Code Assistant & Q&A (wmAsk)');
        FFileList.Items.Add('');
        FFileList.Items.Add('── Pre-defined coding agents ──');
        for I := 0 to CodingAgentPresetCount - 1 do begin
          Preset := GetCodingAgentPreset(I);
          FFileList.Items.Add(Format('🧠 %s — %s (%s)', [Preset.Vendor, Preset.Caption, Preset.ModelId]));
        end;
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
  UpdateLayout;
end;

end.
                                                                                      