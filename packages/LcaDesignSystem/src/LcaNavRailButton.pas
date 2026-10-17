unit LcaNavRailButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, Buttons, LcaTheme;

type
  TLcaNavRailButton = class(TSpeedButton)
  private
    FThemeKind: TThemeKind;
    FNavCaption: string;
    FActive: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetNavCaption(const AValue: string);
    procedure SetActive(AValue: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property NavCaption: string read FNavCaption write SetNavCaption;
    property Active: Boolean read FActive write SetActive default False;
  end;

implementation

uses
  Graphics, Types;

procedure TLcaNavRailButton.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaNavRailButton.SetNavCaption(const AValue: string);
begin
  if FNavCaption = AValue then Exit;
  FNavCaption := AValue;
  if FNavCaption <> '' then
    Hint := FNavCaption;
  Invalidate;
end;

procedure TLcaNavRailButton.SetActive(AValue: Boolean);
begin
  if FActive = AValue then Exit;
  FActive := AValue;
  ApplyTheme(FThemeKind);
end;

constructor TLcaNavRailButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Flat := True;
  AllowAllUp := True;
  FThemeKind := tkDark;
  FActive := False;
  Layout := blGlyphTop;
  Spacing := 4;
end;

procedure TLcaNavRailButton.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  P := ThemePalette(ATheme);
  Color := P.RailBg;
  if FActive then
    Font.Color := P.Accent
  else
    Font.Color := P.TextMuted;
  Invalidate;
end;

procedure TLcaNavRailButton.Paint;
var
  P: TThemePalette;
  R: TRect;
  BgColor: TColor;
  TextX, TextY: Integer;
begin
  P := ThemePalette(FThemeKind);
  R := ClientRect;
  if FActive then
    BgColor := P.RailActiveBg
  else
    BgColor := P.RailBg;

  Canvas.Brush.Color := BgColor;
  Canvas.FillRect(R);

  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
  TextX := R.Left + (R.Width - Canvas.TextWidth(Caption)) div 2;
  TextY := R.Top + (R.Height - Canvas.TextHeight(Caption)) div 2;
  Canvas.TextOut(TextX, TextY, Caption);

  if not FActive then Exit;
  Canvas.Pen.Color := P.Accent;
  Canvas.Pen.Width := 3;
  Canvas.MoveTo(0, R.Top + 4);
  Canvas.LineTo(0, R.Bottom - 4);
  Canvas.Pen.Width := 1;
end;

end.
