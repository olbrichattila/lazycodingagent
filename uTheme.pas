unit uTheme;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Forms, StdCtrls, ExtCtrls, ComCtrls,
  LCLType, uAppTypes;

type
  TThemePalette = record
    Background: TColor;      // Main background (e.g. deepest charcoal / soft light gray)
    Surface: TColor;         // Panel surface
    SurfaceAlt: TColor;      // Input / secondary surface
    HeaderBg: TColor;        // Header strip background
    RailBg: TColor;          // Left navigation rail background
    Border: TColor;          // Visible crisp boundary borders
    BorderStrong: TColor;    // Prominent boundary / active splitters
    Text: TColor;            // Primary high-contrast text
    TextMuted: TColor;       // Secondary / hint text
    Accent: TColor;          // Vivid brand / active blue
    AccentHover: TColor;     // Hover state blue
    AccentActive: TColor;    // Active tab / item background
    AccentText: TColor;      // Text on accent
    SplitterColor: TColor;   // Resizing splitter bar
    CardBg: TColor;          // Cards and message pill background
  end;

function ThemePalette(ATheme: TThemeKind): TThemePalette;

// Helper to configure ComboBox for sleek theme owner-drawing
procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
// Unified DrawItem handler for styled ComboBoxes (Black style on dark mode, clean on light mode)
procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);

implementation

function ThemePalette(ATheme: TThemeKind): TThemePalette;
begin
  if ATheme = tkDark then begin
    // Modern sleek VSCode / Cursor dark theme tokens
    Result.Background     := RGBToColor(24, 24, 28);      // #18181C
    Result.Surface        := RGBToColor(30, 30, 36);      // #1E1E24
    Result.SurfaceAlt     := RGBToColor(38, 38, 46);      // #26262E
    Result.HeaderBg       := RGBToColor(34, 34, 42);      // #22222A
    Result.RailBg         := RGBToColor(20, 20, 24);      // #141418
    Result.Border         := RGBToColor(52, 53, 65);      // #343541
    Result.BorderStrong   := RGBToColor(70, 72, 88);      // #464858
    Result.Text           := RGBToColor(240, 243, 248);   // #F0F3F8
    Result.TextMuted      := RGBToColor(140, 147, 163);   // #8C93A3
    Result.Accent         := RGBToColor(59, 130, 246);    // #3B82F6
    Result.AccentHover    := RGBToColor(96, 165, 250);    // #60A5FA
    Result.AccentActive   := RGBToColor(40, 60, 95);      // #283C5F
    Result.AccentText     := clWhite;
    Result.SplitterColor  := RGBToColor(45, 47, 58);      // #2D2F3A
    Result.CardBg         := RGBToColor(34, 35, 43);      // #22232B
  end else begin
    // Modern sleek light theme tokens
    Result.Background     := RGBToColor(243, 244, 246);   // #F3F4F6
    Result.Surface        := RGBToColor(255, 255, 255);   // #FFFFFF
    Result.SurfaceAlt     := RGBToColor(246, 248, 250);   // #F6F8FA
    Result.HeaderBg       := RGBToColor(240, 242, 245);   // #F0F2F5
    Result.RailBg         := RGBToColor(235, 237, 242);   // #EBEDF2
    Result.Border         := RGBToColor(218, 222, 230);   // #DADEEC
    Result.BorderStrong   := RGBToColor(180, 186, 198);   // #B4BAC6
    Result.Text           := RGBToColor(24, 28, 36);      // #181C24
    Result.TextMuted      := RGBToColor(100, 110, 125);   // #646E7D
    Result.Accent         := RGBToColor(37, 99, 235);     // #2563EB
    Result.AccentHover    := RGBToColor(29, 78, 216);     // #1D4ED8
    Result.AccentActive   := RGBToColor(224, 236, 255);   // #E0ECFF
    Result.AccentText     := clWhite;
    Result.SplitterColor  := RGBToColor(220, 224, 232);   // #DCE0E8
    Result.CardBg         := RGBToColor(248, 249, 251);   // #F8F9FB
  end;
end;

procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ACombo) then Exit;
  P := ThemePalette(ATheme);

  ACombo.Style := csOwnerDrawFixed;
  ACombo.ItemHeight := 22;
  ACombo.Color := P.SurfaceAlt;
  ACombo.Font.Color := P.Text;
  ACombo.Font.Name := 'Segoe UI';
  ACombo.Font.Size := 9;
  ACombo.Invalidate;
end;

procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  Combo: TComboBox;
  P: TThemePalette;
  TextStr: string;
  TextTop: Integer;
begin
  if not (Control is TComboBox) then Exit;
  Combo := TComboBox(Control);
  P := ThemePalette(ATheme);

  // Background selection / hover highlight
  if (odSelected in State) or (odFocused in State) then begin
    Combo.Canvas.Brush.Color := P.AccentActive;
    Combo.Canvas.Pen.Color := P.Accent;
  end else begin
    Combo.Canvas.Brush.Color := P.SurfaceAlt;
    Combo.Canvas.Pen.Color := P.SurfaceAlt;
  end;

  Combo.Canvas.FillRect(ARect);

  // Draw item text
  if (Index >= 0) and (Index < Combo.Items.Count) then begin
    TextStr := Combo.Items[Index];
    Combo.Canvas.Font.Name := 'Segoe UI';
    Combo.Canvas.Font.Size := 9;
    if (odSelected in State) and (ATheme = tkLight) then
      Combo.Canvas.Font.Color := P.Accent
    else
      Combo.Canvas.Font.Color := P.Text;

    TextTop := ARect.Top + ((ARect.Bottom - ARect.Top - Combo.Canvas.TextHeight(TextStr)) div 2);
    Combo.Canvas.TextRect(ARect, ARect.Left + 6, TextTop, TextStr);
  end;
end;

end.
