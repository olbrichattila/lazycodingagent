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
function ParentFormHandlesReady(AControl: TControl): Boolean;

const
  { Fallback until the widget handle exists; GTK/Qt often normalize to 25. }
  ThemedComboBoxHeight = 25;
  ThemedComboBoxItemHeight = 22;

// Helper to configure ComboBox for sleek theme owner-drawing
procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
// Control height after StyleComboBox — use for manual SetBounds (widgetset truth).
function EffectiveThemedComboBoxHeight(ACombo: TComboBox): Integer;
// Unified DrawItem handler for styled ComboBoxes (Black style on dark mode, clean on light mode)
procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);

procedure StylePageControl(APageControl: TPageControl; ATheme: TThemeKind);
procedure ApplyControlTheme(AControl: TControl; ATheme: TThemeKind);

procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);

procedure ConfigureThemedListBox(AList: TListBox; ATheme: TThemeKind);
procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
procedure ConfigureThemedMemo(AMemo: TCustomMemo; ATheme: TThemeKind;
  const AFontName: string = 'Segoe UI'; ABackground: TColor = clNone);
procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
procedure ThemedListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);

procedure ApplyWin32ScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32ScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32FormChrome(AForm: TForm; ATheme: TThemeKind);

procedure ApplyPlatformScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyPlatformScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyPlatformChrome(AForm: TForm; ATheme: TThemeKind);

implementation

uses
  SysUtils
  {$IFDEF LCLQt5}, Qt5, QtWidgets{$ENDIF}
  {$IFDEF LCLGtk3}, LazGtk3, LazGdk3, LazGObject2{$ENDIF}
  {$IFDEF LCLGtk2}, gtk2, gdk2, glib2{$ENDIF}
  ;

function ParentFormHandlesReady(AControl: TControl): Boolean;
var
  F: TCustomForm;
begin
  if not Assigned(AControl) then
    Exit(False);
  F := GetParentForm(AControl);
  Result := Assigned(F) and F.HandleAllocated;
end;

function ColorToStyleHex(AColor: TColor): string;
begin
  Result := '#' + LowerCase(IntToHex(Red(AColor), 2) + IntToHex(Green(AColor), 2) +
    IntToHex(Blue(AColor), 2));
end;

{$IFDEF LCLQt5}
type
  { Access StyleSheet on LCL-created TQtMenuBar instances. }
  TQtMenuBarStyleAccess = class(TQtMenuBar)
  public
    procedure ApplyMenuStyleSheet(const ASheet: WideString);
  end;

var
  FQt5MenuBarLastHandle: PtrUInt;
  FQt5MenuBarLastTheme: TThemeKind;
  FQt5MenuBarThemeSet: Boolean;

procedure TQtMenuBarStyleAccess.ApplyMenuStyleSheet(const ASheet: WideString);
begin
  StyleSheet := ASheet;
end;

procedure ApplyQt5MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  MenuBar: TQtMenuBar;
  Sheet: WideString;
  MenuHandle: PtrUInt;
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  if AForm.Menu = nil then Exit;
  if not AForm.Menu.HandleAllocated then Exit;

  MenuHandle := PtrUInt(AForm.Menu.Handle);
  if FQt5MenuBarThemeSet and (FQt5MenuBarLastHandle = MenuHandle) and
     (FQt5MenuBarLastTheme = ATheme) then
    Exit;

  MenuBar := TQtMenuBar(Pointer(MenuHandle));
  P := ThemePalette(ATheme);
  Sheet := WideString(
    'QMenuBar { background-color: ' + ColorToStyleHex(P.HeaderBg) +
    '; color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'QMenuBar::item { background: transparent; color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'QMenuBar::item:selected { background-color: ' + ColorToStyleHex(P.AccentActive) + '; }');
  TQtMenuBarStyleAccess(MenuBar).ApplyMenuStyleSheet(Sheet);

  FQt5MenuBarLastHandle := MenuHandle;
  FQt5MenuBarLastTheme := ATheme;
  FQt5MenuBarThemeSet := True;
end;
{$ENDIF}

{$IFDEF LCLGtk3}
var
  FGtkMenuBarCssProvider: PGtkCssProvider;
  FGtkMenuBarCssTheme: TThemeKind;
  FGtkMenuBarCssThemeSet: Boolean;

procedure Gtk3ApplyMenuBarCssToContext(AContext: PGtkStyleContext; const ACss: string);
var
  Provider: PGtkCssProvider;
begin
  if AContext = nil then Exit;
  Provider := gtk_css_provider_new();
  gtk_css_provider_load_from_data(Provider, PChar(ACss), -1, nil);
  gtk_style_context_add_provider(AContext, PGtkStyleProvider(Provider),
    GTK_STYLE_PROVIDER_PRIORITY_USER);
  g_object_unref(Provider);
end;

procedure ApplyGtk3MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  Css: string;
  Screen: PGdkScreen;
  MenuBar: PGtkWidget;
  MenuContext: PGtkStyleContext;
begin
  if FGtkMenuBarCssThemeSet and (FGtkMenuBarCssTheme = ATheme) then
    Exit;

  P := ThemePalette(ATheme);
  Css :=
    'menubar, .menubar { ' +
    'background-color: ' + ColorToStyleHex(P.HeaderBg) + '; ' +
    'color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'menubar > menuitem { ' +
    'color: ' + ColorToStyleHex(P.Text) + ' !important; } ' +
    'menubar > menuitem label { ' +
    'color: ' + ColorToStyleHex(P.Text) + ' !important; } ' +
    'menubar > menuitem:hover { ' +
    'background-color: ' + ColorToStyleHex(P.AccentActive) + '; }';

  Screen := gdk_screen_get_default();
  if Screen = nil then Exit;

  if FGtkMenuBarCssProvider <> nil then begin
    gtk_style_context_remove_provider_for_screen(Screen,
      PGtkStyleProvider(FGtkMenuBarCssProvider));
    g_object_unref(FGtkMenuBarCssProvider);
    FGtkMenuBarCssProvider := nil;
  end;

  FGtkMenuBarCssProvider := gtk_css_provider_new();
  gtk_css_provider_load_from_data(FGtkMenuBarCssProvider, PChar(Css), -1, nil);
  gtk_style_context_add_provider_for_screen(Screen,
    PGtkStyleProvider(FGtkMenuBarCssProvider),
    GTK_STYLE_PROVIDER_PRIORITY_USER);

  if Assigned(AForm) and Assigned(AForm.Menu) and AForm.Menu.HandleAllocated then begin
    MenuBar := PGtkWidget(Pointer(AForm.Menu.Handle));
    if gtk_type_is_a(gtk_widget_get_type(MenuBar), gtk_menu_bar_get_type()) then begin
      MenuContext := gtk_widget_get_style_context(MenuBar);
      Gtk3ApplyMenuBarCssToContext(MenuContext, Css);
    end;
  end;

  FGtkMenuBarCssTheme := ATheme;
  FGtkMenuBarCssThemeSet := True;
end;
{$ENDIF}

{$IFDEF LCLGtk2}
procedure TColorToGdkColor(AColor: TColor; out AGdk: TGdkColor);
begin
  AGdk.pixel := 0;
  AGdk.red := Word(Red(AColor) * 257);
  AGdk.green := Word(Green(AColor) * 257);
  AGdk.blue := Word(Blue(AColor) * 257);
end;

procedure Gtk2ApplyMenuBarWidgetColors(AWidget: PGtkWidget; AFg, ABg: TColor);
var
  Fg, Bg: TGdkColor;
  List, Node: PGList;
  Child: PGtkWidget;
begin
  if AWidget = nil then Exit;
  TColorToGdkColor(AFg, Fg);
  TColorToGdkColor(ABg, Bg);
  gtk_widget_modify_fg(AWidget, GTK_STATE_NORMAL, @Fg);
  gtk_widget_modify_fg(AWidget, GTK_STATE_PRELIGHT, @Fg);
  gtk_widget_modify_bg(AWidget, GTK_STATE_NORMAL, @Bg);

  if not GTK_IS_CONTAINER(AWidget) then Exit;
  List := gtk_container_get_children(GTK_CONTAINER(AWidget));
  Node := List;
  while Node <> nil do begin
    Child := PGtkWidget(Node^.data);
    gtk_widget_modify_fg(Child, GTK_STATE_NORMAL, @Fg);
    gtk_widget_modify_fg(Child, GTK_STATE_PRELIGHT, @Fg);
    Node := Node^.next;
  end;
  g_list_free(List);
end;

procedure ApplyGtk2MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  MenuBar: PGtkWidget;
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  if AForm.Menu = nil then Exit;
  if not AForm.Menu.HandleAllocated then Exit;

  MenuBar := PGtkWidget(Pointer(AForm.Menu.Handle));
  if not GTK_IS_MENU_BAR(MenuBar) then Exit;

  P := ThemePalette(ATheme);
  Gtk2ApplyMenuBarWidgetColors(MenuBar, P.Text, P.HeaderBg);
end;
{$ENDIF}

procedure ApplyPlatformMenuChrome(AForm: TForm; ATheme: TThemeKind);
begin
{$IFDEF LCLQt5}
  ApplyQt5MenuBarTheme(AForm, ATheme);
{$ENDIF}
{$IFDEF LCLGtk3}
  ApplyGtk3MenuBarTheme(AForm, ATheme);
{$ENDIF}
{$IFDEF LCLGtk2}
  ApplyGtk2MenuBarTheme(AForm, ATheme);
{$ENDIF}
end;

{$IFDEF WINDOWS}
type
  TWinHwnd = PtrUInt;

procedure SetWindowTheme(hwnd: TWinHwnd; pszSubAppName, pszSubIdList: PWideChar); stdcall;
  external 'uxtheme' name 'SetWindowTheme';

function DwmSetWindowAttribute(hwnd: TWinHwnd; dwAttribute: LongWord;
  pvAttribute: Pointer; cbAttribute: LongWord): LongInt; stdcall;
  external 'dwmapi' name 'DwmSetWindowAttribute';
{$ENDIF}

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
    Result.TextMuted      := RGBToColor(160, 168, 185);   // #A0A8B9
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

function EffectiveThemedComboBoxHeight(ACombo: TComboBox): Integer;
begin
  if not Assigned(ACombo) then
    Exit(ThemedComboBoxHeight);
  if ACombo.HandleAllocated then
    Result := ACombo.Height
  else
    Result := ThemedComboBoxHeight;
end;

procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Changed: Boolean;
begin
  if not Assigned(ACombo) then Exit;
  P := ThemePalette(ATheme);
  Changed := False;

  if ACombo.Style <> csOwnerDrawFixed then begin
    ACombo.Style := csOwnerDrawFixed;
    Changed := True;
  end;
  if ACombo.ItemHeight <> ThemedComboBoxItemHeight then begin
    ACombo.ItemHeight := ThemedComboBoxItemHeight;
    Changed := True;
  end;
  if ACombo.Color <> P.SurfaceAlt then begin
    ACombo.Color := P.SurfaceAlt;
    Changed := True;
  end;
  if ACombo.Font.Color <> P.Text then begin
    ACombo.Font.Color := P.Text;
    Changed := True;
  end;
  if ACombo.Font.Name <> 'Segoe UI' then begin
    ACombo.Font.Name := 'Segoe UI';
    Changed := True;
  end;
  if ACombo.Font.Size <> 9 then begin
    ACombo.Font.Size := 9;
    Changed := True;
  end;
  if Changed then
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

procedure StylePageControl(APageControl: TPageControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
begin
  if not Assigned(APageControl) then Exit;
  P := ThemePalette(ATheme);

  APageControl.Color := P.Background;
  APageControl.Font.Color := P.Text;
  APageControl.Font.Name := 'Segoe UI';
  APageControl.Font.Size := 9;

  for I := 0 to APageControl.PageCount - 1 do begin
    APageControl.Pages[I].Color := P.Surface;
    APageControl.Pages[I].Font.Color := P.Text;
    APageControl.Pages[I].Font.Name := 'Segoe UI';
    APageControl.Pages[I].Font.Size := 9;
  end;

  APageControl.Invalidate;
end;

procedure ApplyControlTheme(AControl: TControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
  WinCtrl: TWinControl;
begin
  if not Assigned(AControl) then Exit;
  P := ThemePalette(ATheme);

  if AControl is TCustomEdit then begin
    TCustomEdit(AControl).Color := P.SurfaceAlt;
    TCustomEdit(AControl).Font.Color := P.Text;
  end else if AControl is TLabel then begin
    TLabel(AControl).Font.Color := P.Text;
  end else if AControl is TPageControl then begin
    StylePageControl(TPageControl(AControl), ATheme);
  end;

  if AControl is TWinControl then begin
    WinCtrl := TWinControl(AControl);
    for I := 0 to WinCtrl.ControlCount - 1 do
      ApplyControlTheme(WinCtrl.Controls[I], ATheme);
  end;
end;

{$IFDEF WINDOWS}
procedure ApplyWin32UnthemedButton(ABtn: TButton);
begin
  if Assigned(ABtn) and ABtn.HandleAllocated then
    SetWindowTheme(ABtn.Handle, '', '');
end;
{$ELSE}
procedure ApplyWin32UnthemedButton(ABtn: TButton);
begin
end;
{$ENDIF}

procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ABtn) then Exit;
  P := ThemePalette(ATheme);
  ABtn.Font.Name := 'Segoe UI';
  ABtn.Font.Size := 9;
  ABtn.Font.Style := [fsBold];
  ABtn.Font.Color := P.AccentText;
  ABtn.Color := P.Accent;
  ApplyWin32UnthemedButton(ABtn);
  ABtn.Invalidate;
end;

procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ABtn) then Exit;
  P := ThemePalette(ATheme);
  ABtn.Font.Name := 'Segoe UI';
  ABtn.Font.Size := 9;
  ABtn.Font.Style := [];
  if ATheme = tkDark then begin
    ABtn.Color := P.SurfaceAlt;
    ABtn.Font.Color := P.TextMuted;
  end else begin
    ABtn.Color := P.Surface;
    ABtn.Font.Color := P.TextMuted;
  end;
  ApplyWin32UnthemedButton(ABtn);
  ABtn.Invalidate;
end;

procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  ABtn.Font.Name := 'Segoe UI';
  ABtn.Font.Size := 9;
  ABtn.Font.Style := [fsBold];
  if ATheme = tkDark then begin
    ABtn.Color := RGBToColor(72, 32, 36);
    ABtn.Font.Color := RGBToColor(248, 113, 113);
  end else begin
    ABtn.Color := RGBToColor(254, 226, 226);
    ABtn.Font.Color := RGBToColor(185, 28, 28);
  end;
  ApplyWin32UnthemedButton(ABtn);
  ABtn.Invalidate;
end;

procedure ConfigureThemedListBox(AList: TListBox; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(AList) then Exit;
  P := ThemePalette(ATheme);
  AList.ItemHeight := 22;
  AList.Style := lbOwnerDrawFixed;
  AList.BorderStyle := bsNone;
  AList.MultiSelect := False;
  AList.ExtendedSelect := False;
  AList.Color := P.SurfaceAlt;
  AList.Font.Name := 'Segoe UI';
  AList.Font.Size := 9;
  AList.Font.Color := P.Text;
  AList.Invalidate;
end;

procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ATree) then Exit;
  P := ThemePalette(ATheme);
  ATree.BorderStyle := bsNone;
  ATree.Color := P.SurfaceAlt;
  ATree.BackgroundColor := P.SurfaceAlt;
  ATree.Font.Name := 'Segoe UI';
  ATree.Font.Size := 9;
  ATree.Font.Color := P.Text;
  ATree.HideSelection := True;
  ATree.Options := ATree.Options - [tvoThemedDraw];
  ATree.TreeLineColor := P.Border;
  ATree.ExpandSignColor := P.TextMuted;
  ATree.SelectionColor := P.AccentActive;
  ATree.SelectionFontColor := P.Text;
  ATree.SelectionFontColorUsed := True;
  ATree.Invalidate;
end;

procedure ConfigureThemedMemo(AMemo: TCustomMemo; ATheme: TThemeKind;
  const AFontName: string = 'Segoe UI'; ABackground: TColor = clNone);
var
  P: TThemePalette;
begin
  if not Assigned(AMemo) then Exit;
  P := ThemePalette(ATheme);
  if ABackground = clNone then
    AMemo.Color := P.SurfaceAlt
  else
    AMemo.Color := ABackground;
  AMemo.Font.Color := P.Text;
  if AFontName <> '' then
    AMemo.Font.Name := AFontName;
end;

procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
begin
  if not Assigned(AMemo) then Exit;
  if not AMemo.HandleAllocated then Exit;
  AMemo.Font.Assign(AMemo.Font);
  AMemo.Invalidate;
end;

{$IFDEF LCLQt5}
procedure ApplyQt5MemoTheme(AMemo: TCustomMemo; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  Sheet: WideString;
begin
  if not Assigned(AMemo) then Exit;
  if not AMemo.HandleAllocated then Exit;
  QtWidget := TQtWidget(Pointer(AMemo.Handle));
  Sheet := WideString(
    'QTextEdit { color: ' + ColorToStyleHex(AMemo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AMemo.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  SyncThemedMemoWidget(AMemo);
end;
{$ENDIF}

procedure ThemedListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  LBox: TListBox;
  P: TThemePalette;
  TextStr: string;
  TextColor: TColor;
  TextTop: Integer;
begin
  if not (Control is TListBox) then Exit;
  LBox := TListBox(Control);
  P := ThemePalette(ATheme);

  LBox.Canvas.Brush.Style := bsSolid;
  LBox.Canvas.Brush.Color := LBox.Color;
  LBox.Canvas.Pen.Color := LBox.Color;
  LBox.Canvas.FillRect(ARect);

  if (Index < 0) or (Index >= LBox.Items.Count) then Exit;

  TextStr := LBox.Items[Index];
  LBox.Canvas.Font.Name := 'Segoe UI';
  LBox.Canvas.Font.Size := 9;
  LBox.Canvas.Font.Style := [];

  if (odSelected in State) or (odFocused in State) then
    TextColor := P.Accent
  else
    TextColor := P.Text;
  LBox.Canvas.Font.Color := TextColor;

  TextTop := ARect.Top + ((ARect.Bottom - ARect.Top - LBox.Canvas.TextHeight(TextStr)) div 2);
  LBox.Canvas.TextRect(ARect, ARect.Left + 8, TextTop, TextStr);
end;

procedure ApplyWin32ScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
{$IFDEF WINDOWS}
var
  ThemeId: PWideChar;
{$ENDIF}
begin
  if not Assigned(AControl) then Exit;
  if not AControl.HandleAllocated then Exit;
{$IFDEF WINDOWS}
  if AControl is TTreeView then begin
    // App palette sets Font.Color / BackgroundColor; Explorer subthemes paint system (black) text.
    SetWindowTheme(AControl.Handle, '', '');
  end else if (AControl is TMemo) or (AControl is TListBox) or
     (AControl is TComboBox) or (AControl is TEdit) then begin
    if not ((AControl is TListBox) and
       (TListBox(AControl).Style in [lbOwnerDrawFixed, lbOwnerDrawVariable])) then begin
      if ATheme = tkDark then
        ThemeId := 'DarkMode_Explorer'
      else
        ThemeId := 'Explorer';
      SetWindowTheme(AControl.Handle, ThemeId, nil);
    end;
  end;
{$ENDIF}
  AControl.Invalidate;
end;

procedure ApplyWin32ScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  Child: TControl;
begin
  if not Assigned(AControl) then Exit;
  ApplyWin32ScrollableTheme(AControl, ATheme);
  for I := 0 to AControl.ControlCount - 1 do begin
    Child := AControl.Controls[I];
    if Child is TWinControl then
      ApplyWin32ScrollableThemeRecursive(TWinControl(Child), ATheme);
  end;
end;

procedure ApplyWin32FormChrome(AForm: TForm; ATheme: TThemeKind);
{$IFDEF WINDOWS}
var
  UseDark: LongBool;
{$ENDIF}
begin
  if not Assigned(AForm) then Exit;
  if not AForm.HandleAllocated then Exit;
{$IFDEF WINDOWS}
  UseDark := ATheme = tkDark;
  DwmSetWindowAttribute(AForm.Handle, 20, @UseDark, SizeOf(UseDark));
{$ENDIF}
end;

procedure ApplyPlatformScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
begin
  if not Assigned(AControl) then Exit;
{$IFDEF WINDOWS}
  ApplyWin32ScrollableTheme(AControl, ATheme);
  if AControl is TCustomMemo then
    SyncThemedMemoWidget(TCustomMemo(AControl));
{$ELSE}
  {$IFDEF LCLQt5}
  if AControl is TCustomMemo then begin
    ApplyQt5MemoTheme(TCustomMemo(AControl), ATheme);
    Exit;
  end;
  {$ENDIF}
  // GTK/Cocoa: scrollbars follow the OS widget theme; keep client colors via ApplyTheme.
  AControl.Invalidate;
{$ENDIF}
end;

procedure ApplyPlatformScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  Child: TControl;
begin
  if not Assigned(AControl) then Exit;
{$IFDEF WINDOWS}
  ApplyWin32ScrollableThemeRecursive(AControl, ATheme);
{$ELSE}
  ApplyPlatformScrollableTheme(AControl, ATheme);
  for I := 0 to AControl.ControlCount - 1 do begin
    Child := AControl.Controls[I];
    if Child is TWinControl then
      ApplyPlatformScrollableThemeRecursive(TWinControl(Child), ATheme);
  end;
{$ENDIF}
end;

procedure ApplyPlatformChrome(AForm: TForm; ATheme: TThemeKind);
begin
{$IFDEF WINDOWS}
  ApplyWin32FormChrome(AForm, ATheme);
{$ELSE}
  ApplyPlatformMenuChrome(AForm, ATheme);
  // macOS/Linux: title bar and scrollbars use system appearance unless the OS is in dark mode.
  if Assigned(AForm) then
    AForm.Invalidate;
{$ENDIF}
end;

end.
