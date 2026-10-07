unit uAppLogo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Controls, Forms, uAppTypes, uTheme;

{ Draw dynamic vector-quality LazyCodingAgent brand logo onto any TCanvas }
procedure DrawLazyAgentLogo(ACanvas: TCanvas; const ARect: TRect; ADarkMode: Boolean = True);

{ Generate dynamic TBitmap representation of logo }
function CreateLazyAgentBitmap(ASize: Integer = 32; ADarkMode: Boolean = True): TBitmap;

implementation

procedure DrawLazyAgentLogo(ACanvas: TCanvas; const ARect: TRect; ADarkMode: Boolean);
var
  W, H, MinDim, RoundRad: Integer;
  BgColor, BorderColor, GlyphCyan, GlyphBlue, SparkleColor: TColor;
  BoxR: TRect;
  Pts: array[0..2] of TPoint;
  Cx, Cy, SparkSize: Integer;
begin
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (W <= 2) or (H <= 2) then Exit;

  MinDim := W;
  if H < MinDim then MinDim := H;

  // Modern brand palette
  if ADarkMode then begin
    BgColor := RGBToColor(22, 24, 32);        // #161820 Deep Sleek Charcoal
    BorderColor := RGBToColor(59, 130, 246);   // #3B82F6 Cyber Blue
    GlyphCyan := RGBToColor(56, 189, 248);     // #38BDF8 Sky Cyan
    GlyphBlue := RGBToColor(99, 102, 241);     // #6366F1 Electric Indigo
    SparkleColor := RGBToColor(250, 204, 21);  // #FACC15 Radiant AI Spark Gold
  end else begin
    BgColor := RGBToColor(240, 244, 255);      // #F0F4FF Soft Cool White
    BorderColor := RGBToColor(37, 99, 235);    // #2563EB Primary Blue
    GlyphCyan := RGBToColor(2, 132, 199);      // #0284C7 Deep Cyan
    GlyphBlue := RGBToColor(79, 70, 229);      // #4F46E5 Indigo
    SparkleColor := RGBToColor(217, 119, 6);   // #D97706 Warm Amber
  end;

  BoxR := ARect;
  RoundRad := MinDim div 4;
  if RoundRad < 3 then RoundRad := 3;

  // 1. Draw rounded squircle base badge
  ACanvas.Brush.Color := BgColor;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Pen.Color := BorderColor;
  ACanvas.Pen.Width := 1 + (MinDim div 28);
  ACanvas.RoundRect(BoxR.Left, BoxR.Top, BoxR.Right, BoxR.Bottom, RoundRad, RoundRad);

  // 2. Draw Code Terminal Chevron `>_`
  ACanvas.Pen.Color := GlyphCyan;
  ACanvas.Pen.Width := 1 + (MinDim div 12);

  // Left Chevron >
  Pts[0] := Point(BoxR.Left + Round(MinDim * 0.22), BoxR.Top + Round(MinDim * 0.28));
  Pts[1] := Point(BoxR.Left + Round(MinDim * 0.44), BoxR.Top + Round(MinDim * 0.50));
  Pts[2] := Point(BoxR.Left + Round(MinDim * 0.22), BoxR.Top + Round(MinDim * 0.72));

  ACanvas.Polyline(Pts);

  // Terminal Prompt Dash _ (at bottom right)
  ACanvas.Pen.Color := GlyphBlue;
  ACanvas.Line(
    BoxR.Left + Round(MinDim * 0.50), BoxR.Top + Round(MinDim * 0.72),
    BoxR.Left + Round(MinDim * 0.78), BoxR.Top + Round(MinDim * 0.72)
  );

  // 3. Draw AI Neural Sparkle / Star (Top Right)
  Cx := BoxR.Left + Round(MinDim * 0.68);
  Cy := BoxR.Top + Round(MinDim * 0.35);
  SparkSize := Round(MinDim * 0.16);
  if SparkSize < 2 then SparkSize := 2;

  ACanvas.Pen.Color := SparkleColor;
  ACanvas.Pen.Width := 1 + (MinDim div 20);
  // Vertical spark
  ACanvas.Line(Cx, Cy - SparkSize, Cx, Cy + SparkSize);
  // Horizontal spark
  ACanvas.Line(Cx - SparkSize, Cy, Cx + SparkSize, Cy);

  // Center node core
  if MinDim >= 24 then begin
    ACanvas.Brush.Color := clWhite;
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Pen.Color := SparkleColor;
    ACanvas.Pen.Width := 1;
    ACanvas.Ellipse(Cx - 2, Cy - 2, Cx + 3, Cy + 3);
  end;
end;

function CreateLazyAgentBitmap(ASize: Integer; ADarkMode: Boolean): TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(ASize, ASize);
  Result.Canvas.Brush.Color := clBlack;
  Result.Canvas.FillRect(0, 0, ASize, ASize);
  DrawLazyAgentLogo(Result.Canvas, Rect(1, 1, ASize - 1, ASize - 1), ADarkMode);
end;

end.
