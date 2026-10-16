unit LcaThemedWindowButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, LCLType, LcaTheme;

type
  TThemedWindowButtonRole = (twbMinimize, twbMaximize, twbRestore, twbClose);

  TLcaThemedWindowButton = class(TCustomControl)
  private
    FTheme: TThemeKind;
    FRole: TThemedWindowButtonRole;
    FHover: Boolean;
    FPressed: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetButtonRole(AValue: TThemedWindowButtonRole);
    function HostForm: TCustomForm;
    procedure ExecuteRole;
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FTheme write SetThemeKind default tkDark;
    property ButtonRole: TThemedWindowButtonRole read FRole write SetButtonRole default twbMinimize;
  end;

function ScaledWindowChromeButtonWidth(AControl: TControl): Integer;

implementation

uses
  Math;

const
  WindowChromeButtonBaseWidth = 46;

function ScaledWindowChromeButtonWidth(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, WindowChromeButtonBaseWidth);
end;

function TLcaThemedWindowButton.HostForm: TCustomForm;
begin
  Result := GetParentForm(Self);
end;

procedure TLcaThemedWindowButton.SetThemeKind(AValue: TThemeKind);
begin
  if FTheme = AValue then Exit;
  FTheme := AValue;
  ApplyTheme(FTheme);
end;

procedure TLcaThemedWindowButton.SetButtonRole(AValue: TThemedWindowButtonRole);
begin
  if FRole = AValue then Exit;
  FRole := AValue;
  Invalidate;
end;

constructor TLcaThemedWindowButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FTheme := tkDark;
  FRole := twbMinimize;
  Width := ScaledWindowChromeButtonWidth(Self);
  Height := ScaledThemedMenuBarHeight(Self);
  Cursor := crHandPoint;
end;

procedure TLcaThemedWindowButton.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Invalidate;
end;

procedure TLcaThemedWindowButton.ExecuteRole;
var
  F: TCustomForm;
begin
  F := HostForm;
  if F = nil then Exit;
  if not (F is TForm) then Exit;
  case FRole of
    twbMinimize:
      TForm(F).WindowState := wsMinimized;
    twbMaximize:
      TForm(F).WindowState := wsMaximized;
    twbRestore:
      TForm(F).WindowState := wsNormal;
    twbClose:
      F.Close;
  end;
end;

procedure TLcaThemedWindowButton.Paint;
var
  P: TThemePalette;
  R: TRect;
  CX, CY, S, I: Integer;
  HoverBg, IconColor: TColor;
begin
  P := ThemePalette(FTheme);
  R := ClientRect;

  if FRole = twbClose then begin
    if FPressed then
      HoverBg := RGBToColor(180, 40, 40)
    else if FHover then
      HoverBg := RGBToColor(232, 17, 35)
    else
      HoverBg := P.HeaderBg;
  end else if FHover or FPressed then
    HoverBg := P.SurfaceAlt
  else
    HoverBg := P.HeaderBg;

  Canvas.Brush.Color := HoverBg;
  Canvas.Pen.Color := HoverBg;
  Canvas.FillRect(R);

  IconColor := P.Text;
  if (FRole = twbClose) and (FHover or FPressed) then
    IconColor := clWhite;

  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  S := ScaledThemedTabMetric(Self, 5);
  Canvas.Pen.Color := IconColor;
  Canvas.Pen.Width := Max(1, ScaledThemedTabMetric(Self, 1));

  case FRole of
    twbMinimize:
      begin
        I := ScaledThemedTabMetric(Self, 8);
        Canvas.MoveTo(CX - I, CY + S div 2);
        Canvas.LineTo(CX + I, CY + S div 2);
      end;
    twbMaximize:
      begin
        I := ScaledThemedTabMetric(Self, 5);
        R := Rect(CX - I, CY - I, CX + I, CY + I);
        Canvas.Brush.Style := bsClear;
        Canvas.Rectangle(R);
        Canvas.Brush.Style := bsSolid;
      end;
    twbRestore:
      begin
        I := ScaledThemedTabMetric(Self, 4);
        Canvas.Brush.Style := bsClear;
        R := Rect(CX - I + 2, CY - I - 1, CX + I + 2, CY + I - 1);
        Canvas.Rectangle(R);
        R := Rect(CX - I - 1, CY - I + 2, CX + I - 1, CY + I + 2);
        Canvas.Rectangle(R);
        Canvas.Brush.Style := bsSolid;
      end;
    twbClose:
      begin
        I := ScaledThemedTabMetric(Self, 6);
        Canvas.MoveTo(CX - I, CY - I);
        Canvas.LineTo(CX + I, CY + I);
        Canvas.MoveTo(CX + I, CY - I);
        Canvas.LineTo(CX - I, CY + I);
      end;
  end;
end;

procedure TLcaThemedWindowButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TLcaThemedWindowButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  FPressed := False;
  Invalidate;
end;

procedure TLcaThemedWindowButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then begin
    FPressed := True;
    Invalidate;
  end;
end;

procedure TLcaThemedWindowButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then begin
    if FPressed and (X >= 0) and (Y >= 0) and (X < Width) and (Y < Height) then
      ExecuteRole;
    FPressed := False;
    Invalidate;
  end;
end;

procedure TLcaThemedWindowButton.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  Width := ScaledWindowChromeButtonWidth(Self);
  Height := ScaledThemedMenuBarHeight(Self);
end;

end.
