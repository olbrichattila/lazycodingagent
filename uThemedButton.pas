unit uThemedButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Graphics, LCLType, uAppTypes, uTheme;

type
  TThemedButtonRole = (tbrPrimary, tbrCancel, tbrDestructive);

  { TThemedButton — cross-platform painted button (Win32, GTK, Cocoa) }
  TThemedButton = class(TCustomControl)
  private
    FCaption: string;
    FRole: TThemedButtonRole;
    FTheme: TThemeKind;
    FEnabled: Boolean;
    FHover: Boolean;
    FModalResult: TModalResult;
    FDefault: Boolean;
    FCancel: Boolean;
    procedure SetCaption(const AValue: string);
    procedure SetModalResult(AValue: TModalResult);
    procedure SetRole(AValue: TThemedButtonRole);
    procedure SetThemedEnabled(AValue: Boolean);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Click; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property Caption: string read FCaption write SetCaption;
    property ButtonRole: TThemedButtonRole read FRole write SetRole default tbrPrimary;
    property ModalResult: TModalResult read FModalResult write SetModalResult default mrNone;
    property Default: Boolean read FDefault write FDefault default False;
    property Cancel: Boolean read FCancel write FCancel default False;
    property Enabled: Boolean read FEnabled write SetThemedEnabled default True;
    property OnClick;
    property Align;
    property Anchors;
    property Height default 28;
    property Left;
    property TabOrder;
    property Top;
    property Visible;
    property Width;
  end;

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover: Boolean);

implementation

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover: Boolean);
var
  P: TThemePalette;
  R: TRect;
  FillColor, TextColor, BorderColor: TColor;
  DrawBorder: Boolean;
  TextTop: Integer;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);

  DrawBorder := False;
  BorderColor := P.Border;

  case ARole of
    tbrPrimary:
      begin
        FillColor := P.Accent;
        TextColor := P.AccentText;
        if AHover and AEnabled then
          FillColor := P.AccentHover;
      end;
    tbrCancel:
      begin
        DrawBorder := True;
        if ATheme = tkDark then begin
          FillColor := P.SurfaceAlt;
          BorderColor := P.BorderStrong;
        end else begin
          FillColor := P.Surface;
          BorderColor := P.Border;
        end;
        TextColor := P.TextMuted;
        if AHover and AEnabled then
          TextColor := P.Text;
      end;
    tbrDestructive:
      begin
        if ATheme = tkDark then begin
          FillColor := RGBToColor(72, 32, 36);
          TextColor := RGBToColor(248, 113, 113);
        end else begin
          FillColor := RGBToColor(254, 226, 226);
          TextColor := RGBToColor(185, 28, 28);
        end;
        if AHover and AEnabled then begin
          if ATheme = tkDark then
            FillColor := RGBToColor(92, 42, 48)
          else
            FillColor := RGBToColor(252, 210, 210);
        end;
      end;
  end;

  if not AEnabled then begin
    FillColor := P.SurfaceAlt;
    TextColor := P.TextMuted;
    DrawBorder := ARole = tbrCancel;
  end;

  Canvas.Brush.Color := FillColor;
  Canvas.Pen.Color := FillColor;
  Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, 6, 6);

  if DrawBorder then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := BorderColor;
    Canvas.Pen.Width := 1;
    Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, 6, 6);
    Canvas.Brush.Style := bsSolid;
  end;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  if ARole = tbrPrimary then
    Canvas.Font.Style := [fsBold]
  else if ARole = tbrDestructive then
    Canvas.Font.Style := [fsBold]
  else
    Canvas.Font.Style := [];
  Canvas.Font.Color := TextColor;

  TextTop := R.Top + ((R.Bottom - R.Top - Canvas.TextHeight(ACaption)) div 2);
  Canvas.TextOut(R.Left + (R.Width - Canvas.TextWidth(ACaption)) div 2, TextTop, ACaption);
end;

{ TThemedButton }

constructor TThemedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 100;
  Height := 28;
  FCaption := 'Button';
  FRole := tbrPrimary;
  FTheme := tkDark;
  FEnabled := True;
  FHover := False;
  FModalResult := mrNone;
  Cursor := crHandPoint;
end;

procedure TThemedButton.SetModalResult(AValue: TModalResult);
begin
  FModalResult := AValue;
end;

procedure TThemedButton.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TThemedButton.SetRole(AValue: TThemedButtonRole);
begin
  if FRole = AValue then Exit;
  FRole := AValue;
  Invalidate;
end;

procedure TThemedButton.SetThemedEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
  inherited Enabled := AValue;
  if FEnabled then
    Cursor := crHandPoint
  else
    Cursor := crDefault;
  Invalidate;
end;

procedure TThemedButton.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Invalidate;
end;

procedure TThemedButton.Paint;
begin
  PaintThemedButton(Canvas, ClientRect, FTheme, FRole, FCaption, FEnabled, FHover);
end;

procedure TThemedButton.MouseEnter;
begin
  inherited MouseEnter;
  if FEnabled then begin
    FHover := True;
    Invalidate;
  end;
end;

procedure TThemedButton.MouseLeave;
begin
  inherited MouseLeave;
  if FHover then begin
    FHover := False;
    Invalidate;
  end;
end;

procedure TThemedButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and FEnabled then
    MouseCapture := True;
end;

procedure TThemedButton.Click;
var
  F: TCustomForm;
begin
  inherited Click;
  if FModalResult <> mrNone then begin
    F := GetParentForm(Self);
    if F <> nil then
      F.ModalResult := FModalResult;
  end;
end;

procedure TThemedButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button = mbLeft) and FEnabled and MouseCapture then begin
    MouseCapture := False;
    if ClientRect.Contains(Point(X, Y)) then
      Click;
  end;
end;

initialization
  RegisterClass(TThemedButton);

finalization
  UnRegisterClass(TThemedButton);

end.
