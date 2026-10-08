unit uFormChrome;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, StdCtrls, Menus,
  LCLType, LCLIntf, LMessages, uAppTypes, uTheme, uAppLogo;

const
  FormChromeBarHeight = 36;
  FormMenuStripHeight = 28;
  FormChromeResizeBorder = 8;
  FormChromeWinButtonWidth = 46;
  FormChromeMacButtonSize = 12;
  FormChromeMacButtonGap = 8;
  FormChromeMacInset = 12;
  FormChromeCloseHover = TColor($001711E8); // #E81123 BGR

type
  TWindowChromeButton = (wcbMinimize, wcbMaximize, wcbClose);

  TFormMenuStrip = class;
  TBorderlessFormHooks = class;

  { TFormChromeBar — themed title row with platform window controls }
  TFormChromeBar = class(TCustomPanel)
  private
    FHostForm: TForm;
    FTheme: TThemeKind;
    FTitleLabel: TLabel;
    FHooks: TBorderlessFormHooks;
    FHoverBtn: TWindowChromeButton;
    FBtnDown: TWindowChromeButton;
    FDragActive: Boolean;
    FDragStartScreen: TPoint;
    FFormStartPos: TPoint;
    FMacLayout: Boolean;
    FButtonHover: Boolean;
    procedure SetTitleText(const AValue: string);
    function ButtonRects(out RMin, RMax, RClose: TRect): Boolean;
    function IsInButtonArea(X, Y: Integer): Boolean;
    function HitTestButton(X, Y: Integer): TWindowChromeButton;
    procedure DoMinimize;
    procedure DoMaximizeRestore;
    procedure DoClose;
    procedure StartWindowDrag;
    procedure ContinueWindowDrag(const AScreenPos: TPoint);
    procedure EndWindowDrag;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AttachForm(AForm: TForm; AMenuStrip: TFormMenuStrip = nil);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetTitle(const ACaption: string);
    property HostForm: TForm read FHostForm;
  published
    property Align;
    property Height default FormChromeBarHeight;
    property Visible;
    property Width;
  end;

  { TFormMenuStrip — client-area menu row under the title bar }
  TFormMenuStrip = class(TPanel)
  private
    FMainMenu: TMainMenu;
    FTheme: TThemeKind;
    FButtons: TList;
    procedure ClearButtons;
    procedure RebuildButtons;
    procedure MenuBtnClick(Sender: TObject);
    procedure MenuBtnMouseEnter(Sender: TObject);
    procedure MenuBtnMouseLeave(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure WireMenu(AMenu: TMainMenu);
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property Align;
    property Height default FormMenuStripHeight;
    property Visible;
    property Width;
  end;

  TBorderlessFormHooks = class
  private
    FForm: TForm;
    FChrome: TFormChromeBar;
    FMenuStrip: TFormMenuStrip;
    FPrevWndProc: TWndMethod;
    procedure WndProc(var Msg: TLMessage);
    function HitTestResize(const P: TPoint): PtrInt;
  public
    constructor Create(AForm: TForm; AChrome: TFormChromeBar; AMenuStrip: TFormMenuStrip);
    destructor Destroy; override;
  end;

procedure Register;

implementation

uses
  Math
  {$IFDEF WINDOWS}, Windows{$ENDIF};

const
  { Win32 hit-test codes (used via LM_NCHITTEST on all LCL widgetsets) }
  HTCLIENT = 1;
  HTLEFT = 10;
  HTRIGHT = 11;
  HTTOP = 12;
  HTTOPLEFT = 13;
  HTTOPRIGHT = 14;
  HTBOTTOM = 15;
  HTBOTTOMLEFT = 16;
  HTBOTTOMRIGHT = 17;

type
  TMenuStripButton = class(TCustomControl)
  private
    FMenuItem: TMenuItem;
    FTheme: TThemeKind;
    FHover: Boolean;
    procedure SetTheme(ATheme: TThemeKind);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure Click; override;
  public
    constructor Create(AOwner: TComponent); override;
    property MenuItem: TMenuItem read FMenuItem write FMenuItem;
    property Theme: TThemeKind write SetTheme;
  end;

procedure CopyMenuItemBranch(ASrc, ADest: TMenuItem);
var
  I: Integer;
  Child, NewChild: TMenuItem;
begin
  ADest.Action := ASrc.Action;
  ADest.AutoCheck := ASrc.AutoCheck;
  ADest.Caption := ASrc.Caption;
  ADest.Checked := ASrc.Checked;
  ADest.Default := ASrc.Default;
  ADest.Enabled := ASrc.Enabled;
  ADest.GroupIndex := ASrc.GroupIndex;
  ADest.HelpContext := ASrc.HelpContext;
  ADest.Hint := ASrc.Hint;
  ADest.ImageIndex := ASrc.ImageIndex;
  ADest.RadioItem := ASrc.RadioItem;
  ADest.ShortCut := ASrc.ShortCut;
  ADest.Visible := ASrc.Visible;
  ADest.OnClick := ASrc.OnClick;
  ADest.Tag := ASrc.Tag;
  for I := 0 to ASrc.Count - 1 do begin
    Child := ASrc.Items[I];
    if Child.IsLine then begin
      ADest.AddSeparator;
      Continue;
    end;
    NewChild := TMenuItem.Create(ASrc.Owner);
    CopyMenuItemBranch(Child, NewChild);
    ADest.Add(NewChild);
  end;
end;

procedure PopupMenuItemSubmenu(AOwner: TComponent; AItem: TMenuItem; X, Y: Integer);
var
  Pop: TPopupMenu;
  I: Integer;
  MI: TMenuItem;
begin
  if not Assigned(AItem) then Exit;
  if AItem.Count = 0 then begin
    AItem.Click;
    Exit;
  end;
  Pop := TPopupMenu.Create(AOwner);
  try
    for I := 0 to AItem.Count - 1 do begin
      if AItem.Items[I].IsLine then
        Pop.Items.AddSeparator
      else begin
        MI := TMenuItem.Create(Pop);
        CopyMenuItemBranch(AItem.Items[I], MI);
        Pop.Items.Add(MI);
      end;
    end;
    Pop.PopUp(X, Y);
  finally
    Pop.Free;
  end;
end;

{ TBorderlessFormHooks }

constructor TBorderlessFormHooks.Create(AForm: TForm; AChrome: TFormChromeBar;
  AMenuStrip: TFormMenuStrip);
begin
  inherited Create;
  FForm := AForm;
  FChrome := AChrome;
  FMenuStrip := AMenuStrip;
  if Assigned(FForm) then begin
    FForm.BorderStyle := bsNone;
    FPrevWndProc := FForm.WindowProc;
    FForm.WindowProc := @WndProc;
  end;
end;

destructor TBorderlessFormHooks.Destroy;
begin
  if Assigned(FForm) then
    FForm.WindowProc := FPrevWndProc;
  inherited Destroy;
end;

function TBorderlessFormHooks.HitTestResize(const P: TPoint): PtrInt;
var
  B, W, H: Integer;
begin
  B := FormChromeResizeBorder;
  W := FForm.ClientWidth;
  H := FForm.ClientHeight;

  if (P.X >= 0) and (P.X < B) and (P.Y >= 0) and (P.Y < H) then begin
    if P.Y < B then Exit(HTTOPLEFT);
    if P.Y >= H - B then Exit(HTBOTTOMLEFT);
    Exit(HTLEFT);
  end;
  if (P.X >= W - B) and (P.X < W) and (P.Y >= 0) and (P.Y < H) then begin
    if P.Y < B then Exit(HTTOPRIGHT);
    if P.Y >= H - B then Exit(HTBOTTOMRIGHT);
    Exit(HTRIGHT);
  end;
  if (P.Y >= 0) and (P.Y < B) and (P.X >= B) and (P.X < W - B) then
    Exit(HTTOP);
  if (P.Y >= H - B) and (P.Y < H) and (P.X >= B) and (P.X < W - B) then
    Exit(HTBOTTOM);

  Result := HTCLIENT;
end;

procedure TBorderlessFormHooks.WndProc(var Msg: TLMessage);
var
  P: TPoint;
  Hit: PtrInt;
begin
  if Assigned(FForm) and (Msg.Msg = LM_NCHITTEST) then begin
    P := Point(SmallInt(LoWord(Msg.LParam)), SmallInt(HiWord(Msg.LParam)));
    P := FForm.ScreenToClient(P);
    Hit := HitTestResize(P);
    if Hit <> HTCLIENT then begin
      Msg.Result := Hit;
      Exit;
    end;
  end;
  FPrevWndProc(Msg);
end;

{ TFormChromeBar }

constructor TFormChromeBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse];
  DoubleBuffered := True;
  BevelOuter := bvNone;
  Height := FormChromeBarHeight;
  FTheme := tkDark;
  FHoverBtn := wcbMinimize;
  FBtnDown := wcbMinimize;
  FMacLayout := {$IFDEF DARWIN}True{$ELSE}False{$ENDIF};
  FButtonHover := False;
  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := Self;
  FTitleLabel.AutoSize := True;
  FTitleLabel.Layout := tlCenter;
  FTitleLabel.Transparent := True;
  FTitleLabel.Caption := 'Application';
end;

destructor TFormChromeBar.Destroy;
begin
  FreeAndNil(FHooks);
  inherited Destroy;
end;

procedure TFormChromeBar.SetTitleText(const AValue: string);
begin
  FTitleLabel.Caption := AValue;
end;

procedure TFormChromeBar.AttachForm(AForm: TForm; AMenuStrip: TFormMenuStrip = nil);
begin
  FHostForm := AForm;
  if not Assigned(FHostForm) then Exit;
  FreeAndNil(FHooks);
  FHooks := TBorderlessFormHooks.Create(FHostForm, Self, AMenuStrip);
end;

procedure TFormChromeBar.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.HeaderBg;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  FTitleLabel.Font := Font;
  Invalidate;
end;

procedure TFormChromeBar.SetTitle(const ACaption: string);
begin
  SetTitleText(ACaption);
  if Assigned(FHostForm) then
    FHostForm.Caption := ACaption;
end;

function TFormChromeBar.ButtonRects(out RMin, RMax, RClose: TRect): Boolean;
var
  H, BtnW, Y0: Integer;
  MacY, MacX: Integer;
begin
  H := Height;
  Y0 := 0;
  BtnW := FormChromeWinButtonWidth;
  if FMacLayout then begin
    MacY := (H - FormChromeMacButtonSize) div 2;
    MacX := FormChromeMacInset;
    RClose := Rect(MacX, MacY, MacX + FormChromeMacButtonSize, MacY + FormChromeMacButtonSize);
    MacX := MacX + FormChromeMacButtonSize + FormChromeMacButtonGap;
    RMin := Rect(MacX, MacY, MacX + FormChromeMacButtonSize, MacY + FormChromeMacButtonSize);
    MacX := MacX + FormChromeMacButtonSize + FormChromeMacButtonGap;
    RMax := Rect(MacX, MacY, MacX + FormChromeMacButtonSize, MacY + FormChromeMacButtonSize);
  end else begin
    RClose := Rect(Width - BtnW, Y0, Width, H);
    RMax := Rect(Width - 2 * BtnW, Y0, Width - BtnW, H);
    RMin := Rect(Width - 3 * BtnW, Y0, Width - 2 * BtnW, H);
  end;
  Result := True;
end;

function TFormChromeBar.HitTestButton(X, Y: Integer): TWindowChromeButton;
var
  RMin, RMax, RClose: TRect;
begin
  ButtonRects(RMin, RMax, RClose);
  if PtInRect(RClose, Point(X, Y)) then Exit(wcbClose);
  if PtInRect(RMax, Point(X, Y)) then Exit(wcbMaximize);
  if PtInRect(RMin, Point(X, Y)) then Exit(wcbMinimize);
  Result := wcbClose;
end;

function TFormChromeBar.IsInButtonArea(X, Y: Integer): Boolean;
var
  RMin, RMax, RClose: TRect;
begin
  ButtonRects(RMin, RMax, RClose);
  Result := PtInRect(RMin, Point(X, Y)) or PtInRect(RMax, Point(X, Y)) or PtInRect(RClose, Point(X, Y));
end;

procedure TFormChromeBar.DoMinimize;
begin
  if Assigned(FHostForm) then
    FHostForm.WindowState := wsMinimized;
end;

procedure TFormChromeBar.DoMaximizeRestore;
begin
  if not Assigned(FHostForm) then Exit;
  if FHostForm.WindowState = wsMaximized then
    FHostForm.WindowState := wsNormal
  else
    FHostForm.WindowState := wsMaximized;
  Invalidate;
end;

procedure TFormChromeBar.DoClose;
begin
  if Assigned(FHostForm) then
    FHostForm.Close;
end;

procedure TFormChromeBar.StartWindowDrag;
begin
  if not Assigned(FHostForm) then Exit;
{$IFDEF WINDOWS}
  ReleaseCapture;
  SendMessage(FHostForm.Handle, WM_SYSCOMMAND, SC_MOVE + HTCAPTION, 0);
{$ELSE}
  FDragActive := True;
  FDragStartScreen := Mouse.CursorPos;
  FFormStartPos := Point(FHostForm.Left, FHostForm.Top);
  MouseCapture := True;
{$ENDIF}
end;

procedure TFormChromeBar.ContinueWindowDrag(const AScreenPos: TPoint);
begin
  if not FDragActive or not Assigned(FHostForm) then Exit;
  FHostForm.SetBounds(
    FFormStartPos.X + (AScreenPos.X - FDragStartScreen.X),
    FFormStartPos.Y + (AScreenPos.Y - FDragStartScreen.Y),
    FHostForm.Width,
    FHostForm.Height);
end;

procedure TFormChromeBar.EndWindowDrag;
begin
  if FDragActive then begin
    FDragActive := False;
    if MouseCapture then
      MouseCapture := False;
  end;
end;

procedure TFormChromeBar.Paint;
var
  P: TThemePalette;
  RMin, RMax, RClose, R: TRect;
  LogoR: TRect;
  Maximized: Boolean;
  Ic: TWindowChromeButton;
  Fill, Glyph: TColor;
  Cx, Cy: Integer;

  procedure PaintWinGlyph(ABtn: TWindowChromeButton; const AR: TRect);
  var
    M: Integer;
  begin
    M := 4;
    Canvas.Pen.Color := Glyph;
    Canvas.Pen.Width := 1;
    case ABtn of
      wcbMinimize:
        begin
          Canvas.MoveTo(AR.Left + M, AR.Bottom - M - 2);
          Canvas.LineTo(AR.Right - M, AR.Bottom - M - 2);
        end;
      wcbMaximize:
        if Maximized then begin
          Canvas.Rectangle(AR.Left + M + 3, AR.Top + M, AR.Right - M, AR.Bottom - M - 3);
          Canvas.Rectangle(AR.Left + M, AR.Top + M + 3, AR.Right - M - 3, AR.Bottom - M);
        end else
          Canvas.Rectangle(AR.Left + M, AR.Top + M, AR.Right - M, AR.Bottom - M);
      wcbClose:
        begin
          Canvas.MoveTo(AR.Left + M, AR.Top + M);
          Canvas.LineTo(AR.Right - M, AR.Bottom - M);
          Canvas.MoveTo(AR.Right - M, AR.Top + M);
          Canvas.LineTo(AR.Left + M, AR.Bottom - M);
        end;
    end;
  end;

  procedure PaintMacDot(ABtn: TWindowChromeButton; const AR: TRect);
  begin
    case ABtn of
      wcbClose: Fill := RGBToColor(255, 95, 87);
      wcbMinimize: Fill := RGBToColor(255, 189, 46);
      wcbMaximize: Fill := RGBToColor(39, 201, 63);
    end;
    if FButtonHover and (FHoverBtn = ABtn) then
      Fill := RGBToColor(
        Min(255, Red(Fill) + 20),
        Min(255, Green(Fill) + 20),
        Min(255, Blue(Fill) + 20));
    Canvas.Brush.Color := Fill;
    Canvas.Pen.Color := Fill;
    Cx := (AR.Left + AR.Right) div 2;
    Cy := (AR.Top + AR.Bottom) div 2;
    Canvas.Ellipse(Cx - FormChromeMacButtonSize div 2, Cy - FormChromeMacButtonSize div 2,
      Cx + FormChromeMacButtonSize div 2, Cy + FormChromeMacButtonSize div 2);
  end;

begin
  P := ThemePalette(FTheme);
  Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := P.Border;
  Canvas.Line(0, Height - 1, Width, Height - 1);

  LogoR := Rect(8, 4, 8 + 28, Height - 4);
  DrawLazyAgentLogo(Canvas, LogoR, FTheme = tkDark);

  if FMacLayout then
    FTitleLabel.Left := FormChromeMacInset + 3 * (FormChromeMacButtonSize + FormChromeMacButtonGap) + 8
  else
    FTitleLabel.Left := LogoR.Right + 8;
  FTitleLabel.Top := (Height - FTitleLabel.Height) div 2;

  ButtonRects(RMin, RMax, RClose);
  Maximized := Assigned(FHostForm) and (FHostForm.WindowState = wsMaximized);

  for Ic := wcbMinimize to wcbClose do begin
    case Ic of
      wcbMinimize: R := RMin;
      wcbMaximize: R := RMax;
      wcbClose: R := RClose;
    end;
    if FMacLayout then begin
      PaintMacDot(Ic, R);
      Continue;
    end;
    Fill := P.HeaderBg;
    if Ic = wcbClose then begin
      if FButtonHover and (FHoverBtn = wcbClose) then Fill := FormChromeCloseHover;
      Glyph := clWhite;
    end else begin
      if FButtonHover and (FHoverBtn = Ic) then Fill := P.SurfaceAlt;
      Glyph := P.Text;
    end;
    Canvas.Brush.Color := Fill;
    Canvas.FillRect(R);
    PaintWinGlyph(Ic, R);
  end;
end;

procedure TFormChromeBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if IsInButtonArea(X, Y) then begin
    FBtnDown := HitTestButton(X, Y);
    Invalidate;
    Exit;
  end;
  StartWindowDrag;
end;

procedure TFormChromeBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Btn: TWindowChromeButton;
  RMin, RMax, RClose: TRect;
begin
  inherited MouseUp(Button, Shift, X, Y);
  EndWindowDrag;
  if Button <> mbLeft then Exit;
  ButtonRects(RMin, RMax, RClose);
  if PtInRect(RClose, Point(X, Y)) then Btn := wcbClose
  else if PtInRect(RMax, Point(X, Y)) then Btn := wcbMaximize
  else if PtInRect(RMin, Point(X, Y)) then Btn := wcbMinimize
  else Exit;
  case Btn of
    wcbMinimize: DoMinimize;
    wcbMaximize: DoMaximizeRestore;
    wcbClose: DoClose;
  end;
  FBtnDown := wcbMinimize;
  Invalidate;
end;

procedure TFormChromeBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: TWindowChromeButton;
begin
  inherited MouseMove(Shift, X, Y);
{$IFNDEF WINDOWS}
  if FDragActive then
    ContinueWindowDrag(Mouse.CursorPos);
{$ENDIF}
  if IsInButtonArea(X, Y) then begin
    NewHover := HitTestButton(X, Y);
    if (not FButtonHover) or (NewHover <> FHoverBtn) then begin
      FButtonHover := True;
      FHoverBtn := NewHover;
      Invalidate;
    end;
  end else if FButtonHover then begin
    FButtonHover := False;
    Invalidate;
  end;
end;

procedure TFormChromeBar.MouseLeave;
begin
  inherited MouseLeave;
  if FButtonHover then begin
    FButtonHover := False;
    Invalidate;
  end;
end;

procedure TFormChromeBar.DblClick;
begin
  inherited DblClick;
  if not IsInButtonArea(ScreenToClient(Mouse.CursorPos).X, ScreenToClient(Mouse.CursorPos).Y) then
    DoMaximizeRestore;
end;

{ TMenuStripButton }

constructor TMenuStripButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  Height := FormMenuStripHeight;
  FHover := False;
  FTheme := tkDark;
end;

procedure TMenuStripButton.SetTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Invalidate;
end;

procedure TMenuStripButton.Paint;
var
  P: TThemePalette;
  Cap: string;
  TextY: Integer;
begin
  P := ThemePalette(FTheme);
  if FHover then
    Canvas.Brush.Color := P.SurfaceAlt
  else
    Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(ClientRect);
  Cap := StripHotkey(Caption);
  Canvas.Font.Color := P.Text;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  TextY := (Height - Canvas.TextHeight(Cap)) div 2;
  Canvas.TextOut(10, TextY, Cap);
end;

procedure TMenuStripButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TMenuStripButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Invalidate;
end;

procedure TMenuStripButton.Click;
var
  P: TPoint;
begin
  inherited Click;
  if not Assigned(FMenuItem) then Exit;
  P := ClientToScreen(Point(0, Height));
  PopupMenuItemSubmenu(Self, FMenuItem, P.X, P.Y);
end;

{ TFormMenuStrip }

constructor TFormMenuStrip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Height := FormMenuStripHeight;
  FButtons := TList.Create;
  FTheme := tkDark;
end;

destructor TFormMenuStrip.Destroy;
begin
  ClearButtons;
  FButtons.Free;
  inherited Destroy;
end;

procedure TFormMenuStrip.ClearButtons;
var
  I: Integer;
begin
  for I := 0 to FButtons.Count - 1 do
    TObject(FButtons[I]).Free;
  FButtons.Clear;
end;

procedure TFormMenuStrip.RebuildButtons;
var
  I, X: Integer;
  Item: TMenuItem;
  Btn: TMenuStripButton;
  Cap: string;
begin
  ClearButtons;
  if not Assigned(FMainMenu) then Exit;
  X := 0;
  for I := 0 to FMainMenu.Items.Count - 1 do begin
    Item := FMainMenu.Items[I];
    if not Item.Visible then Continue;
    Btn := TMenuStripButton.Create(Self);
    Btn.Parent := Self;
    Btn.MenuItem := Item;
    Btn.Theme := FTheme;
    Cap := StripHotkey(Item.Caption);
    Btn.Caption := Cap;
    Btn.Left := X;
    Btn.Top := 0;
    Btn.Width := Canvas.TextWidth(Cap) + 24;
    Btn.Height := Height;
    Btn.Anchors := [akTop, akLeft];
    Btn.OnClick := @MenuBtnClick;
    Btn.OnMouseEnter := @MenuBtnMouseEnter;
    Btn.OnMouseLeave := @MenuBtnMouseLeave;
    FButtons.Add(Btn);
    X := X + Btn.Width;
  end;
end;

procedure TFormMenuStrip.MenuBtnClick(Sender: TObject);
begin
  (Sender as TMenuStripButton).Click;
end;

procedure TFormMenuStrip.MenuBtnMouseEnter(Sender: TObject);
begin
  (Sender as TMenuStripButton).MouseEnter;
end;

procedure TFormMenuStrip.MenuBtnMouseLeave(Sender: TObject);
begin
  (Sender as TMenuStripButton).MouseLeave;
end;

procedure TFormMenuStrip.Paint;
var
  P: TThemePalette;
begin
  inherited Paint;
  P := ThemePalette(FTheme);
  Canvas.Pen.Color := P.Border;
  Canvas.Line(0, Height - 1, Width, Height - 1);
end;

procedure TFormMenuStrip.WireMenu(AMenu: TMainMenu);
begin
  FMainMenu := AMenu;
  RebuildButtons;
end;

procedure TFormMenuStrip.ApplyTheme(ATheme: TThemeKind);
var
  I: Integer;
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.HeaderBg;
  Font.Color := P.Text;
  for I := 0 to FButtons.Count - 1 do
    TMenuStripButton(FButtons[I]).Theme := FTheme;
  Invalidate;
end;

procedure Register;
begin
  RegisterComponents('LazyCodingAgent', [TFormChromeBar, TFormMenuStrip]);
end;

initialization
  RegisterClass(TFormChromeBar);
  RegisterClass(TFormMenuStrip);

finalization
  UnRegisterClass(TFormChromeBar);
  UnRegisterClass(TFormMenuStrip);

end.
