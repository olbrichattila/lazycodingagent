unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  uAppTypes, uTheme, uAppLogo;

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

  { TNavContentControl - Content panel for the active navigation area }
  TNavContentControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FTheme: TThemeKind;
    FWorkspaceName: string;
    FFileList: TListBox;
    FActionBtn: TButton;
    FTitleLabel: TLabel;
    FSubLabel: TLabel;
    procedure ActionBtnClick(Sender: TObject);
    procedure RebuildView;
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem; const AWorkspaceName: string);
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
  ItemH := 52;
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
  Canvas.Brush.Color := P.RailBg;
  Canvas.FillRect(ClientRect);

  // Right dividing boundary
  Canvas.Pen.Color := P.Border;
  Canvas.Pen.Width := 1;
  Canvas.Line(Width - 1, 0, Width - 1, Height);

  // Top Brand Logo Badge
  DrawLazyAgentLogo(Canvas, Rect(10, 8, Width - 10, 44), FTheme = tkDark);
  Canvas.Pen.Color := P.Border;
  Canvas.Line(8, 48, Width - 8, 48);

  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    R := GetItemRect(I);
    Sym := NavigationIconSymbol(Item);
    Cap := NavigationCaption(Item);

    if Item = FSelected then begin
      // Active item styling
      Canvas.Brush.Color := P.AccentActive;
      Canvas.FillRect(R);
      Canvas.Pen.Color := P.Accent;
      Canvas.Rectangle(R);

      // Left active indicator pill
      IndicatorR := Rect(0, R.Top + 8, 3, R.Bottom - 8);
      Canvas.Brush.Color := P.Accent;
      Canvas.FillRect(IndicatorR);
    end else if I = FHovered then begin
      // Hover item styling
      Canvas.Brush.Color := P.SurfaceAlt;
      Canvas.FillRect(R);
    end;

    // Icon / Symbol
    Canvas.Font.Name := 'Segoe UI Emoji';
    Canvas.Font.Size := 13;
    Canvas.Font.Style := [fsBold];
    if Item = FSelected then
      Canvas.Font.Color := P.Accent
    else
      Canvas.Font.Color := P.Text;
    Canvas.TextOut(R.Left + (R.Right - R.Left - Canvas.TextWidth(Sym)) div 2, R.Top + 6, Sym);

    // Caption underneath icon
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 7;
    Canvas.Font.Style := [];
    if Item = FSelected then
      Canvas.Font.Color := P.Accent
    else
      Canvas.Font.Color := P.TextMuted;
    Canvas.TextOut(R.Left + (R.Right - R.Left - Canvas.TextWidth(Cap)) div 2, R.Top + 32, Cap);

    Inc(I);
  end;
end;

procedure TNavRailControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I, OldHover: Integer;
  Item: TNavigationItem;
  Found: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldHover := FHovered;
  FHovered := -1;
  Found := False;

  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    if GetItemRect(I).Contains(Point(X, Y)) then begin
      FHovered := I;
      Hint := NavigationHint(Item);
      Found := True;
      Break;
    end;
    Inc(I);
  end;

  if not Found then
    Hint := '';

  if OldHover <> FHovered then
    Invalidate;
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
  Invalidate;
end;

procedure TNavContentControl.SetSelected(AItem: TNavigationItem; const AWorkspaceName: string);
begin
  FSelected := AItem;
  FWorkspaceName := AWorkspaceName;
  RebuildView;
  Invalidate;
end;

procedure TNavContentControl.ActionBtnClick(Sender: TObject);
begin
  case FSelected of
    niHome: ShowMessage('Overview refreshed');
    niProjects: ShowMessage('Open Project Folder dialog...');
    niSessions: ShowMessage('New AI session started');
    niBots: ShowMessage('Configure custom agent...');
  end;
end;

procedure TNavContentControl.RebuildView;
begin
  FFileList.Items.Clear;
  case FSelected of
    niHome:
      begin
        FTitleLabel.Caption := 'Workspace Overview';
        FSubLabel.Caption := 'Active Project: ' + FWorkspaceName;
        FFileList.Items.Add('ðŸ“ Project Root: ./' + FWorkspaceName);
        FFileList.Items.Add('âš™ Target: x86_64 Free Pascal');
        FFileList.Items.Add('ðŸ“Š Mode: Agent (Autopilot)');
        FFileList.Items.Add('ðŸ¤– Connected Model: Active');
        FActionBtn.Caption := '+ Quick Action';
      end;
    niProjects:
      begin
        FTitleLabel.Caption := 'Project Explorer';
        FSubLabel.Caption := 'Files in ' + FWorkspaceName;
        FFileList.Items.Add('ðŸ“„ lazycodingagent.lpr');
        FFileList.Items.Add('ðŸ“„ mainunit.pas');
        FFileList.Items.Add('ðŸ“„ uMainWorkspace.pas');
        FFileList.Items.Add('ðŸ“„ uDockPanel.pas');
        FFileList.Items.Add('ðŸ“„ uNavigationPanel.pas');
        FFileList.Items.Add('ðŸ“„ uChatPanel.pas');
        FFileList.Items.Add('ðŸ“„ uWorkspaceState.pas');
        FFileList.Items.Add('ðŸ“„ uTheme.pas');
        FFileList.Items.Add('ðŸ“„ README.md');
        FActionBtn.Caption := 'ðŸ“‚ Open Folder...';
      end;
    niSessions:
      begin
        FTitleLabel.Caption := 'Chat Sessions';
        FSubLabel.Caption := 'History & Agents';
        FFileList.Items.Add('ðŸ’¬ Session 1: Layout & Docking UI (Current)');
        FFileList.Items.Add('ðŸ’¬ Session 2: Free Pascal Backend');
        FFileList.Items.Add('ðŸ’¬ Session 3: AST Code Parser');
        FActionBtn.Caption := '+ New Chat Session';
      end;
    niBots:
      begin
        FTitleLabel.Caption := 'AI Coding Bots';
        FSubLabel.Caption := 'Configured Agents';
        FFileList.Items.Add('ðŸ¤– Full Agent (Code / Edit / Run)');
        FFileList.Items.Add('ðŸ“ Architect (Plan & Specs)');
        FFileList.Items.Add('â“ Code Reviewer (Ask & Explain)');
        FActionBtn.Caption := 'âš™ Manage Custom Bots';
      end;
  end;
end;

end.
