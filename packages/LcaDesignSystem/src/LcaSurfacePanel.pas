unit LcaSurfacePanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, ExtCtrls, Graphics, LcaTheme;

type
  TLcaSurfacePanel = class(TPanel)
  private
    FThemeKind: TThemeKind;
    FShowAccentBorder: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetShowAccentBorder(AValue: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property ShowAccentBorder: Boolean read FShowAccentBorder write SetShowAccentBorder default False;
  end;

implementation

procedure TLcaSurfacePanel.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaSurfacePanel.SetShowAccentBorder(AValue: Boolean);
begin
  if FShowAccentBorder = AValue then Exit;
  FShowAccentBorder := AValue;
  Invalidate;
end;

constructor TLcaSurfacePanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FThemeKind := tkDark;
  FShowAccentBorder := False;
  DoubleBuffered := True;
end;

procedure TLcaSurfacePanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  P := ThemePalette(ATheme);
  Color := P.CardBg;
  Font.Color := P.Text;
  Invalidate;
end;

procedure TLcaSurfacePanel.Paint;
var
  P: TThemePalette;
  R: TRect;
begin
  inherited Paint;
  P := ThemePalette(FThemeKind);
  Canvas.Pen.Color := P.Border;
  Canvas.Brush.Style := bsClear;
  R := ClientRect;
  Dec(R.Right);
  Dec(R.Bottom);
  Canvas.Rectangle(R);
  if FShowAccentBorder then begin
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(R.Left, R.Bottom);
    Canvas.LineTo(R.Right, R.Bottom);
    Canvas.Pen.Width := 1;
  end;
end;

end.
