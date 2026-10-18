unit LcaTheme;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Forms, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  Menus, LCLType, Types;

type
  TThemeKind = (tkDark, tkLight);
  TThemedButtonRole = (tbrPrimary, tbrCancel, tbrDestructive, tbrGhost);

  TThemePalette = record
    Background: TColor;      // Main background (e.g. deepest charcoal / soft light gray)
    Surface: TColor;         // Panel surface
    SurfaceAlt: TColor;      // Input / secondary surface
    HeaderBg: TColor;        // Header strip background
    TitleBarBg: TColor;      // Frameless title bar (menu + window buttons)
    MenuFlyoutBg: TColor;    // Main menu dropdown panel
    RailBg: TColor;          // Left navigation rail background
    RailActiveBg: TColor;    // Selected nav rail cell
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
{ True when the control or an owner is on a form open in the Lazarus designer. }
function LcaComponentOrOwnerDesigning(AComponent: TComponent): Boolean;
{ Form designer, IDE-hosted preview, or JIT .lfm load before csDesigning is set. }
function LcaInDesignContext(const AComponent: TComponent): Boolean;
{ Lazarus designer uses the light palette so streamed dark-theme forms stay readable. }
function EffectiveControlTheme(const AComponent: TComponent; AStored: TThemeKind): TThemeKind;
{ True when ParamStr(0) is the lazarus or startlazarus IDE binary. }
function LazarusIdeHostExecutable: Boolean;
function ParentFormHandlesReady(AControl: TControl): Boolean;

const
  { Fallback until the widget handle exists; GTK/Qt often normalize to 25. }
  ThemedComboBoxHeight = 25;
  ThemedComboBoxItemHeight = 22;
  ThemedTabBarBaseHeight = 38;
  ThemedMenuBarBaseHeight = 36;
  ThemedMenuPopupItemBaseHeight = 28;
  { Menu bar caption — logical pt like ThemedTabFontSize (not PPI-scaled again). }
  ThemedMenuBarFontSizeBase = 10;
  { Logical pt for combo/list metrics — do not PPI-scale ad hoc. }
  ThemedTabFontSize = 9;
  { Close column and min tab width at 96 DPI — scaled via ScaledThemedTabMetric. }
  ThemedTabCloseColumnBase = 28;
  ThemedTabHorizPadBase = 8;
  ThemedTabMinWidthBase = 72;
  ThemedTabMinWidthClosableBase = 96;
  ThemedButtonCornerBase = 8;
  ThemedComboCornerBase = 6;
  ThemedComboChevronGutterBase = 22;
  ThemedButtonFontSizeBase = 9;
  ThemedButtonHorizPadBase = 14;
  ThemedButtonVertPadBase = 2;
  ThemedButtonDescentSafetyBase = 1;
  ThemedButtonHeightBase = 28;
  { Code editor — logical pt; LCL scales Font.Size on DPI-aware forms. }
  ThemedEditorFontSizeBase = 6;
  { Utility Execution Detail memo — logical pt; LCL scales on DPI-aware forms (no MulDiv). }
  ThemedExecDetailFontSizeBase = 10;
  { Main form left nav list boxes — owner-draw row metrics. }
  ThemedNavListItemHeight = 40;
  ThemedNavListPadLeft = 14;
  ThemedNavListPadV = 4;
  ThemedNavListRowGap = 2;

function ScaledThemedTabMetric(AControl: TControl; ABaseAt96: Integer): Integer;
function ThemedButtonCornerRadius(AControl: TControl): Integer;
function ThemedButtonFontSize(AControl: TControl): Integer;
function ThemedButtonHorizPad(AControl: TControl): Integer;
function ThemedButtonVertPad(AControl: TControl): Integer;
function ScaledThemedButtonHeight(AControl: TControl): Integer;
function MeasureThemedButtonWidth(AControl: TControl; const ACaption: string;
  ARole: TThemedButtonRole; AMinWidth: Integer = 0): Integer;
function ScaledThemedTabBarHeight(AControl: TControl): Integer;
function ThemedTabCloseColumn(AControl: TControl): Integer;
function ThemedTabHorizPad(AControl: TControl): Integer;
function ThemedTabCloseHitRect(const ARect: TRect; AControl: TControl): TRect;
function ScaledThemedMenuBarHeight(AControl: TControl): Integer;
function ScaledThemedMenuPopupItemHeight(AControl: TControl): Integer;
function MenuItemDisplayCaption(const ACaption: string): string;
function ScaledEditorFontSize(AControl: TControl): Integer;
function ThemedComboCornerRadius(AControl: TControl): Integer;
function ThemedComboChevronGutter(AControl: TControl): Integer;

procedure PaintThemedMenuBarItem(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  ASelected: Boolean; ATheme: TThemeKind; AFontSize: Integer; AChromeBg: TColor = clNone);
procedure ThemedMenuPopupDrawItem(ACanvas: TCanvas; const ARect: TRect;
  State: TOwnerDrawState; ATheme: TThemeKind; ASource: TMenuItem);

// Owner-draw colors/font for ComboBox; preserves Height/ItemHeight from the form resource.
procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
// Read-only row height estimate for panels around a combo (do not pass to SetBounds height).
function EffectiveThemedComboBoxHeight(ACombo: TComboBox): Integer;
// Unified DrawItem handler for styled ComboBoxes (Black style on dark mode, clean on light mode)
procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);

procedure StylePageControl(APageControl: TPageControl; ATheme: TThemeKind);
{ Re-apply ShowTabs=False for TLcaThemedPageTabBar hosts (GTK may ignore until relayout). }
procedure EnforcePageControlHiddenTabs(APageControl: TPageControl);
procedure ApplyControlTheme(AControl: TControl; ATheme: TThemeKind);

procedure PaintThemedTab(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  AActive, AHover: Boolean; AShowClose, ACloseHover: Boolean; ATheme: TThemeKind;
  AMetricsControl: TControl = nil);

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover, APressed, AFocused: Boolean;
  ACornerRadius, AFontSize, AHorizPad: Integer; AMetricsControl: TControl = nil);

procedure PaintThemedComboField(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  const AText: string; AEnabled, AFocused, ADropped, AShowFocusRing: Boolean;
  ACornerRadius, AChevronGutter: Integer);

procedure StyleThemedButtonRole(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleGhostButton(ABtn: TButton; ATheme: TThemeKind);

procedure ConfigureThemedListBox(AList: TListBox; ATheme: TThemeKind);
procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
procedure ConfigureThemedCheckBox(ACheck: TCheckBox; ATheme: TThemeKind);
procedure ConfigureThemedMemo(AMemo: TCustomMemo; ATheme: TThemeKind;
  const AFontName: string = 'Segoe UI'; ABackground: TColor = clNone);
procedure ConfigureThemedExecDetailMemo(AMemo: TCustomMemo; ATheme: TThemeKind);
procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
procedure SyncThemedEditWidget(AEdit: TCustomEdit);
procedure SyncThemedListBoxWidget(AList: TCustomListBox);
procedure ThemedListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
procedure ThemedNavListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);

procedure ApplyWin32ScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32ScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32FormChrome(AForm: TForm; ATheme: TThemeKind);

procedure ApplyPlatformScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyPlatformScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyFormPlatformThemes(AForm: TCustomForm; ATheme: TThemeKind);
procedure ApplyPlatformChrome(AForm: TForm; ATheme: TThemeKind);

type
  TThemeCustomApplyProc = function(AControl: TControl; ATheme: TThemeKind): Boolean of object;

procedure RegisterThemeCustomApply(const AProc: TThemeCustomApplyProc);
procedure ApplyThemedButtonControl(ABtn: TButton; ATheme: TThemeKind);
procedure ApplyThemedControlTree(ARoot: TWinControl; ATheme: TThemeKind);
procedure ApplyThemedForm(AForm: TCustomForm; ATheme: TThemeKind);
{ Ensures panel background paints on Cocoa/GTK (ParentColor off) and sets default text color. }
procedure ApplyThemedPanelColors(APanel: TPanel; AColor: TColor; ATheme: TThemeKind);

type
  TThemedButtonFrameApplyProc = procedure(AControl: TControl; ATheme: TThemeKind);

var
  ThemedButtonFrameApplyTheme: TThemedButtonFrameApplyProc = nil;

implementation

uses
  Math, SysUtils, LCLIntf, LCLProc, LcaThemedButton, LcaThemedComboBox, LcaThemedButtonPaint
  {$IFDEF WINDOWS}, LcaThemeWin32Buttons{$ENDIF}
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

function ThemedTabStripPixelsPerInch(AControl: TControl): Integer;
var
  F: TCustomForm;
begin
  Result := 96;
  if not Assigned(AControl) then Exit;
  F := GetParentForm(AControl);
  if (F <> nil) and (F.PixelsPerInch > 0) then
    Exit(F.PixelsPerInch);
  if Screen.PixelsPerInch > 0 then
    Result := Screen.PixelsPerInch;
end;

function ScaledThemedTabMetric(AControl: TControl; ABaseAt96: Integer): Integer;
begin
  Result := MulDiv(ABaseAt96, ThemedTabStripPixelsPerInch(AControl), 96);
end;

function ScaledThemedTabBarHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabBarBaseHeight);
end;

function ThemedTabCloseColumn(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabCloseColumnBase);
end;

function ThemedTabHorizPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabHorizPadBase);
end;

function ThemedTabCloseHitRect(const ARect: TRect; AControl: TControl): TRect;
var
  R: TRect;
  CloseCol, EdgePad, VertPad: Integer;
begin
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  CloseCol := ThemedTabCloseColumn(AControl);
  EdgePad := ScaledThemedTabMetric(AControl, 4);
  VertPad := ScaledThemedTabMetric(AControl, 3);
  Result.Left := R.Right - CloseCol;
  Result.Top := R.Top + VertPad;
  Result.Right := R.Right - EdgePad;
  Result.Bottom := R.Bottom - VertPad;
end;

function ScaledThemedMenuBarHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedMenuBarBaseHeight);
end;

function ScaledThemedMenuPopupItemHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedMenuPopupItemBaseHeight);
end;

function MenuItemDisplayCaption(const ACaption: string): string;
var
  I: Integer;
begin
  Result := ACaption;
  I := 1;
  while I <= Length(Result) do begin
    if Result[I] = '&' then
      Delete(Result, I, 1)
    else
      Inc(I);
  end;
end;

function ScaledEditorFontSize(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedEditorFontSizeBase);
end;

function ThemedComboCornerRadius(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedComboCornerBase);
end;

function ThemedComboChevronGutter(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedComboChevronGutterBase);
end;

function ThemedButtonCornerRadius(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonCornerBase);
end;

function ThemedButtonFontSize(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonFontSizeBase);
end;

function ThemedButtonHorizPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonHorizPadBase);
end;

function ThemedButtonVertPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonVertPadBase);
end;

function ScaledThemedButtonHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonHeightBase);
end;

function MeasureThemedButtonWidth(AControl: TControl; const ACaption: string;
  ARole: TThemedButtonRole; AMinWidth: Integer): Integer;
var
  Bmp: TBitmap;
  TextW, Pad: Integer;
begin
  Result := AMinWidth;
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := ThemedButtonFontSize(AControl);
    if ARole in [tbrPrimary, tbrDestructive] then
      Bmp.Canvas.Font.Style := [fsBold]
    else
      Bmp.Canvas.Font.Style := [];
    TextW := Bmp.Canvas.TextWidth(ACaption);
    Pad := ThemedButtonHorizPad(AControl);
    Result := TextW + Pad * 2;
    if Result < AMinWidth then
      Result := AMinWidth;
  finally
    Bmp.Free;
  end;
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

{ Legacy LCL Form.Menu chrome (Qt/GTK). Main app uses TLcaThemedMenuBar instead. }
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

function LazarusIdeHostExecutable: Boolean;
var
  N: string;
begin
  N := LowerCase(ExtractFileName(ParamStr(0)));
  Result := (N = 'lazarus') or (N = 'startlazarus');
end;

function LcaComponentOrOwnerDesigning(AComponent: TComponent): Boolean;
var
  C: TComponent;
begin
  C := AComponent;
  while C <> nil do begin
    if csDesigning in C.ComponentState then
      Exit(True);
    C := C.Owner;
  end;
  Result := False;
end;

function LcaInDesignContext(const AComponent: TComponent): Boolean;
var
  F: TCustomForm;
begin
  if LcaComponentOrOwnerDesigning(AComponent) then
    Exit(True);
  if Assigned(Application) and (csDesigning in Application.ComponentState) then
    Exit(True);
  if LazarusIdeHostExecutable and (AComponent is TControl) then begin
    F := GetParentForm(TControl(AComponent));
    if Assigned(F) then
      Exit(True);
  end;
  Result := False;
end;

function EffectiveControlTheme(const AComponent: TComponent; AStored: TThemeKind): TThemeKind;
begin
  if LcaInDesignContext(AComponent) then
    Result := tkLight
  else
    Result := AStored;
end;

function ThemePalette(ATheme: TThemeKind): TThemePalette;
begin
  if ATheme = tkDark then begin
    // Neon workspace — deep base with cyan / violet accents
    Result.Background     := RGBToColor(8, 10, 18);       // #080A12
    Result.Surface        := RGBToColor(14, 16, 28);      // #0E101C
    Result.SurfaceAlt     := RGBToColor(22, 24, 40);      // #161828
    Result.HeaderBg       := RGBToColor(12, 14, 24);      // #0C0E18
    Result.TitleBarBg     := RGBToColor(0, 0, 0);         // #000000
    Result.MenuFlyoutBg   := RGBToColor(28, 32, 50);     // #1C2032 — above Surface / Background
    Result.RailBg         := RGBToColor(6, 8, 14);        // #06080E
    Result.RailActiveBg   := RGBToColor(14, 16, 28);      // #0E101C (Surface)
    Result.Border         := RGBToColor(45, 55, 90);      // #2D375A
    Result.BorderStrong   := RGBToColor(0, 200, 255);     // cyan glow edge
    Result.Text           := RGBToColor(240, 248, 255);   // #F0F8FF
    Result.TextMuted      := RGBToColor(140, 160, 195);   // #8CA0C3
    Result.Accent         := RGBToColor(0, 229, 255);     // #00E5FF
    Result.AccentHover    := RGBToColor(56, 189, 248);    // #38BDF8
    Result.AccentActive   := RGBToColor(30, 45, 85);       // selected rail/tab
    Result.AccentText     := RGBToColor(8, 12, 22);
    Result.SplitterColor  := RGBToColor(35, 45, 75);
    Result.CardBg         := RGBToColor(16, 20, 36);       // glassy card
  end else begin
    // Modern sleek light theme tokens
    Result.Background     := RGBToColor(243, 244, 246);   // #F3F4F6
    Result.Surface        := RGBToColor(255, 255, 255);   // #FFFFFF
    Result.SurfaceAlt     := RGBToColor(246, 248, 250);   // #F6F8FA
    Result.HeaderBg       := RGBToColor(240, 242, 245);   // #F0F2F5
    Result.TitleBarBg     := RGBToColor(240, 242, 245);   // match header (light)
    Result.MenuFlyoutBg   := RGBToColor(240, 242, 245);   // #F0F2F5 — gray vs white Surface / page bg
    Result.RailBg         := RGBToColor(255, 255, 255);   // idle nav cells / rail
    Result.RailActiveBg   := RGBToColor(235, 237, 242);   // #EBEDF2 selected cell
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
const
  MIN_COMBO_H = 20;
  MAX_COMBO_H = 40;
begin
  if not Assigned(ACombo) then
    Exit(ThemedComboBoxHeight);
  if not ACombo.HandleAllocated then
    Exit(ThemedComboBoxHeight);
  Result := ACombo.Height;
  if (Result < MIN_COMBO_H) or (Result > MAX_COMBO_H) then
    Result := ThemedComboBoxHeight;
end;

function ThemedComboItemHeightForControl(ADesignHeight,
  ADesignItemHeight: Integer): Integer;
const
  MIN_ITEM_H = 8;
begin
  if ADesignItemHeight > 0 then
    Exit(ADesignItemHeight);
  if ADesignHeight > 0 then
    Exit(Max(MIN_ITEM_H, ADesignHeight - 6));
  Result := ThemedComboBoxItemHeight;
end;

procedure RestoreComboDesignerBounds(ACombo: TComboBox; ASavedH: Integer);
begin
  if Assigned(ACombo) and (ACombo.Height <> ASavedH) then
    ACombo.Height := ASavedH;
end;

procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Changed: Boolean;
  SavedH, SavedItemH, TargetItemH: Integer;
begin
  if not Assigned(ACombo) then Exit;
  SavedH := ACombo.Height;
  SavedItemH := ACombo.ItemHeight;
  P := ThemePalette(ATheme);
  Changed := False;

  if ACombo.Style <> csOwnerDrawFixed then begin
    ACombo.Style := csOwnerDrawFixed;
    Changed := True;
  end;
  TargetItemH := ThemedComboItemHeightForControl(SavedH, SavedItemH);
  if ACombo.ItemHeight <> TargetItemH then begin
    ACombo.ItemHeight := TargetItemH;
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
  if ACombo.Height <> SavedH then begin
    RestoreComboDesignerBounds(ACombo, SavedH);
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
    Combo.Canvas.TextRect(ARect, ARect.Left + 8, TextTop, TextStr);
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

  for I := 0 to APageControl.PageCount - 1 do begin
    APageControl.Pages[I].Color := P.Surface;
    APageControl.Pages[I].Font.Color := P.Text;
  end;

  APageControl.Invalidate;
  EnforcePageControlHiddenTabs(APageControl);
end;

procedure EnforcePageControlHiddenTabs(APageControl: TPageControl);
begin
  if not Assigned(APageControl) then Exit;
  if csDestroying in APageControl.ComponentState then Exit;
  if not ParentFormHandlesReady(APageControl) then Exit;
  if not APageControl.HandleAllocated then
    APageControl.HandleNeeded;
  if not APageControl.HandleAllocated then Exit;
  APageControl.ShowTabs := False;
  {$IFDEF LCLGtk2}
  gtk_notebook_set_show_tabs(PGtkNotebook(APageControl.Handle), GFalse);
  gtk_notebook_set_show_border(PGtkNotebook(APageControl.Handle), GFalse);
  {$ENDIF}
  {$IFDEF LCLGtk3}
  gtk_notebook_set_show_tabs(PGtkNotebook(APageControl.Handle), False);
  gtk_notebook_set_show_border(PGtkNotebook(APageControl.Handle), False);
  {$ENDIF}
  {$IFDEF LCLQt5}
  if TQtWidget(APageControl.Handle).ChildOfComplexWidget <> ccwTTabControl then begin
    with TQtTabWidget(APageControl.Handle) do
      if TabBar <> nil then
        ShowTabs := False;
  end;
  {$ENDIF}
end;

procedure PaintThemedTab(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  AActive, AHover: Boolean; AShowClose, ACloseHover: Boolean; ATheme: TThemeKind;
  AMetricsControl: TControl);
var
  P: TThemePalette;
  R, TextR, CloseR: TRect;
  FillColor, TextColor: TColor;
  TextTop, Rad, CloseCol, HorizPad, CloseW, CloseH, CloseX: Integer;
  CloseCaption: string;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  Rad := 6;

  if AActive then begin
    FillColor := P.Surface;
    TextColor := P.Text;
  end else if AHover then begin
    FillColor := P.SurfaceAlt;
    TextColor := P.Text;
  end else begin
    FillColor := P.HeaderBg;
    TextColor := P.TextMuted;
  end;

  Canvas.Brush.Color := FillColor;
  Canvas.Pen.Color := P.Border;
  Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);

  if AActive then begin
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(R.Left + Rad, R.Bottom);
    Canvas.LineTo(R.Right - Rad + 1, R.Bottom);
    Canvas.Pen.Width := 1;
  end;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := ThemedTabFontSize;
  Canvas.Font.Color := TextColor;

  CloseCol := ThemedTabCloseColumn(AMetricsControl);
  HorizPad := ThemedTabHorizPad(AMetricsControl);

  TextR := R;
  if AShowClose then
    Dec(TextR.Right, CloseCol);
  Inc(TextR.Left, HorizPad);
  TextTop := TextR.Top + ((TextR.Bottom - TextR.Top - Canvas.TextHeight(ACaption)) div 2);
  Canvas.TextRect(TextR, TextR.Left, TextTop, ACaption);

  if AShowClose then begin
    CloseR := ThemedTabCloseHitRect(ARect, AMetricsControl);
    if ACloseHover then begin
      Canvas.Brush.Color := P.SurfaceAlt;
      Canvas.Pen.Color := P.Border;
      Canvas.RoundRect(CloseR.Left, CloseR.Top, CloseR.Right + 1, CloseR.Bottom + 1, 4, 4);
    end;
    CloseCaption := '✕';
    Canvas.Font.Size := 9;
    if ACloseHover then
      Canvas.Font.Color := P.Accent
    else if AActive then
      Canvas.Font.Color := P.Text
    else
      Canvas.Font.Color := P.TextMuted;
    CloseW := Canvas.TextWidth(CloseCaption);
    CloseH := Canvas.TextHeight(CloseCaption);
    CloseX := CloseR.Left + ((CloseR.Right - CloseR.Left - CloseW) div 2);
    TextTop := CloseR.Top + ((CloseR.Bottom - CloseR.Top - CloseH) div 2);
    Canvas.TextOut(CloseX, TextTop, CloseCaption);
  end;
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
  end else if Assigned(ThemedButtonFrameApplyTheme) and (AControl <> nil) and
    AControl.ClassNameIs('TThemedButtonFrame') then
    ThemedButtonFrameApplyTheme(AControl, ATheme);

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

{$IFNDEF WINDOWS}
procedure ApplyWin32ThemedComboPaint(ACombo: TComboBox; ATheme: TThemeKind);
begin
end;
{$ENDIF}

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover, APressed, AFocused: Boolean;
  ACornerRadius, AFontSize, AHorizPad: Integer; AMetricsControl: TControl);
var
  P: TThemePalette;
  R, TextR: TRect;
  FillColor, TextColor, BorderColor: TColor;
  DrawBorder: Boolean;
  TextTop, TextH, LayoutH, VertPad, DescentSafety: Integer;
  Rad: Integer;
  Ext: TSize;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  if ACornerRadius < 2 then
    Rad := 6
  else
    Rad := ACornerRadius;

  DrawBorder := False;
  BorderColor := P.Border;

  case ARole of
    tbrPrimary:
      begin
        FillColor := P.Accent;
        TextColor := P.AccentText;
        if APressed and AEnabled then
          FillColor := P.AccentHover
        else if AHover and AEnabled then
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
        if APressed and AEnabled then begin
          FillColor := P.Border;
          TextColor := P.Text;
        end else if AHover and AEnabled then
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
        if APressed and AEnabled then begin
          if ATheme = tkDark then
            FillColor := RGBToColor(62, 28, 32)
          else
            FillColor := RGBToColor(248, 200, 200);
        end else if AHover and AEnabled then begin
          if ATheme = tkDark then
            FillColor := RGBToColor(92, 42, 48)
          else
            FillColor := RGBToColor(252, 210, 210);
        end;
      end;
    tbrGhost:
      begin
        DrawBorder := False;
        FillColor := P.HeaderBg;
        TextColor := P.TextMuted;
        if APressed and AEnabled then begin
          FillColor := P.Border;
          TextColor := P.Text;
        end else if AHover and AEnabled then begin
          FillColor := P.SurfaceAlt;
          TextColor := P.Text;
        end;
      end;
  end;

  if not AEnabled then begin
    FillColor := P.SurfaceAlt;
    TextColor := P.TextMuted;
    DrawBorder := ARole = tbrCancel;
    if ARole = tbrGhost then
      DrawBorder := False;
  end;

  Canvas.Brush.Color := FillColor;
  Canvas.Pen.Color := FillColor;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);

  if DrawBorder then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := BorderColor;
    Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
    Canvas.Brush.Style := bsSolid;
  end;

  if AFocused and AEnabled then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 1;
    Canvas.RoundRect(R.Left + 1, R.Top + 1, R.Right, R.Bottom, Rad, Rad);
    Canvas.Brush.Style := bsSolid;
  end;

  Canvas.Font.Color := TextColor;

  TextR := R;
  if Assigned(AMetricsControl) then begin
    VertPad := ThemedButtonVertPad(AMetricsControl);
    Inc(TextR.Top, VertPad);
    Dec(TextR.Bottom, VertPad);
  end;
  if TextR.Bottom <= TextR.Top then
    TextR := R;

  TextH := Canvas.TextHeight(ACaption);
  Ext := Canvas.TextExtent(ACaption);
  LayoutH := Max(TextH, Ext.Cy);
  if Assigned(AMetricsControl) then
    DescentSafety := ScaledThemedTabMetric(AMetricsControl, ThemedButtonDescentSafetyBase)
  else
    DescentSafety := 0;
  TextTop := TextR.Top + Max(0, (TextR.Bottom - TextR.Top - LayoutH - DescentSafety) div 2);

  if (AHorizPad > 0) and (TextR.Width > AHorizPad * 2) then
    Canvas.TextRect(TextR, TextR.Left + AHorizPad +
      Max(0, (TextR.Width - AHorizPad * 2 - Canvas.TextWidth(ACaption)) div 2),
      TextTop, ACaption)
  else
    Canvas.TextRect(TextR, TextR.Left + (TextR.Width - Canvas.TextWidth(ACaption)) div 2,
      TextTop, ACaption);
end;

procedure PaintThemedComboChevron(Canvas: TCanvas; const ARect: TRect; AColor: TColor);
var
  CX, CY, HalfW, HalfH: Integer;
  P1, P2, P3: TPoint;
begin
  CX := (ARect.Left + ARect.Right) div 2;
  CY := (ARect.Top + ARect.Bottom) div 2;
  HalfW := Max(3, (ARect.Right - ARect.Left) div 5);
  HalfH := Max(2, (ARect.Bottom - ARect.Top) div 6);
  P1 := Point(CX - HalfW, CY - HalfH div 2);
  P2 := Point(CX + HalfW, CY - HalfH div 2);
  P3 := Point(CX, CY + HalfH);
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.Polygon([P1, P2, P3]);
end;

procedure PaintThemedComboField(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  const AText: string; AEnabled, AFocused, ADropped, AShowFocusRing: Boolean;
  ACornerRadius, AChevronGutter: Integer);
var
  P: TThemePalette;
  R, TextR, ChevR: TRect;
  Rad, TextTop, PadLeft: Integer;
  BorderColor, FillColor, TextColor, ChevColor: TColor;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  if ACornerRadius < 2 then
    Rad := 6
  else
    Rad := ACornerRadius;

  FillColor := P.SurfaceAlt;
  BorderColor := P.Border;
  TextColor := P.Text;
  ChevColor := P.TextMuted;
  if ADropped and AEnabled then
    BorderColor := P.Accent;
  if AFocused and AEnabled and AShowFocusRing then
    BorderColor := P.Accent;
  if not AEnabled then begin
    FillColor := P.Surface;
    TextColor := P.TextMuted;
    ChevColor := P.TextMuted;
    BorderColor := P.Border;
  end;

  Canvas.Brush.Color := FillColor;
  Canvas.Pen.Color := FillColor;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);

  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := BorderColor;
  Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
  Canvas.Brush.Style := bsSolid;

  if AFocused and AEnabled and AShowFocusRing then begin
    Canvas.Pen.Color := P.Accent;
    Canvas.RoundRect(R.Left + 1, R.Top + 1, R.Right, R.Bottom, Max(2, Rad - 1), Max(2, Rad - 1));
  end;

  ChevR := R;
  ChevR.Left := ChevR.Right - AChevronGutter + 1;
  TextR := R;
  Dec(TextR.Right, AChevronGutter);
  PadLeft := 10;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Color := TextColor;
  if AText <> '' then begin
    TextTop := TextR.Top + ((TextR.Bottom - TextR.Top - Canvas.TextHeight(AText)) div 2);
    Canvas.TextRect(TextR, TextR.Left + PadLeft, TextTop, AText);
  end;
  PaintThemedComboChevron(Canvas, ChevR, ChevColor);
end;

procedure RestoreButtonDesignerBounds(ABtn: TButton; ASavedW, ASavedH: Integer);
begin
  if (ABtn.Width <> ASavedW) or (ABtn.Height <> ASavedH) then begin
    ABtn.Width := ASavedW;
    ABtn.Height := ASavedH;
  end;
end;

procedure StyleThemedButtonRole(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  P: TThemePalette;
  SavedW, SavedH: Integer;
begin
  if not Assigned(ABtn) then Exit;
  SavedW := ABtn.Width;
  SavedH := ABtn.Height;
  P := ThemePalette(ATheme);
  case ARole of
    tbrPrimary:
      begin
        ABtn.Font.Color := P.AccentText;
        ABtn.Color := P.Accent;
      end;
    tbrDestructive:
      if ATheme = tkDark then begin
        ABtn.Color := RGBToColor(72, 32, 36);
        ABtn.Font.Color := RGBToColor(248, 113, 113);
      end else begin
        ABtn.Color := RGBToColor(254, 226, 226);
        ABtn.Font.Color := RGBToColor(185, 28, 28);
      end;
    tbrGhost:
      begin
        ABtn.Color := P.HeaderBg;
        if ATheme = tkDark then
          ABtn.Font.Color := P.Text
        else
          ABtn.Font.Color := P.TextMuted;
      end;
  else
    if ATheme = tkDark then begin
      ABtn.Color := P.SurfaceAlt;
      ABtn.Font.Color := P.TextMuted;
    end else begin
      ABtn.Color := P.Surface;
      ABtn.Font.Color := P.TextMuted;
    end;
  end;
  RestoreButtonDesignerBounds(ABtn, SavedW, SavedH);
  ApplyWin32UnthemedButton(ABtn);
  ApplyThemedButtonPaint(ABtn, ATheme, ARole);
  RestoreButtonDesignerBounds(ABtn, SavedW, SavedH);
  ABtn.Invalidate;
end;

procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrPrimary);
end;

procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrCancel);
end;

procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrDestructive);
end;

procedure StyleGhostButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrGhost);
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
  AList.Color := P.Surface;
  AList.Font.Name := 'Segoe UI';
  AList.Font.Size := 9;
  AList.Font.Color := P.Text;
  if AList.HandleAllocated then
    SyncThemedListBoxWidget(AList);
  AList.Invalidate;
end;

procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ATree) then Exit;
  P := ThemePalette(ATheme);
  ATree.BorderStyle := bsNone;
  ATree.Color := P.Surface;
  ATree.BackgroundColor := P.Surface;
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

procedure ConfigureThemedCheckBox(ACheck: TCheckBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Bg: TColor;
begin
  if not Assigned(ACheck) then Exit;
  P := ThemePalette(ATheme);
  ACheck.ParentFont := False;
  ACheck.Font.Name := 'Segoe UI';
  ACheck.Font.Color := P.Text;
  ACheck.ParentColor := False;
  if Assigned(ACheck.Parent) then
    Bg := TControl(ACheck.Parent).Color
  else
    Bg := P.Surface;
  ACheck.Color := Bg;
{$IFDEF WINDOWS}
  if ACheck.HandleAllocated then
    SetWindowTheme(ACheck.Handle, '', '');
{$ENDIF}
  ACheck.Invalidate;
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

procedure ConfigureThemedExecDetailMemo(AMemo: TCustomMemo; ATheme: TThemeKind);
begin
  ConfigureThemedMemo(AMemo, ATheme, 'Consolas');
  if Assigned(AMemo) then
    AMemo.Font.Size := ThemedExecDetailFontSizeBase;
end;

procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
begin
  if not Assigned(AMemo) then Exit;
  if not AMemo.HandleAllocated then Exit;
  AMemo.Font.Assign(AMemo.Font);
  AMemo.Invalidate;
end;

procedure SyncThemedEditWidget(AEdit: TCustomEdit);
begin
  if not Assigned(AEdit) then Exit;
  if not AEdit.HandleAllocated then Exit;
  AEdit.Font.Assign(AEdit.Font);
  AEdit.Invalidate;
end;

procedure SyncThemedListBoxWidget(AList: TCustomListBox);
{$IFDEF LCLGtk2}
var
  Bg: TGdkColor;
  W: PGtkWidget;
{$ENDIF}
{$IFDEF LCLGtk3}
var
  W: PGtkWidget;
  Rgba: TGdkRGBA;
{$ENDIF}
{$IFDEF LCLQt5}
var
  QtWidget: TQtWidget;
  Sheet: WideString;
{$ENDIF}
begin
  if not Assigned(AList) then Exit;
  if not AList.HandleAllocated then Exit;
  {$IFDEF LCLGtk2}
  W := PGtkWidget(Pointer(AList.Handle));
  if W <> nil then begin
    TColorToGdkColor(AList.Color, Bg);
    gtk_widget_modify_bg(W, GTK_STATE_NORMAL, @Bg);
  end;
  {$ENDIF}
  {$IFDEF LCLGtk3}
  W := PGtkWidget(Pointer(AList.Handle));
  if (W <> nil) and gdk_rgba_parse(@Rgba, PChar(ColorToStyleHex(AList.Color))) then
    gtk_widget_override_background_color(W, GTK_STATE_FLAG_NORMAL, @Rgba);
  {$ENDIF}
  {$IFDEF LCLQt5}
  QtWidget := TQtWidget(Pointer(AList.Handle));
  Sheet := WideString(
    'QListWidget { color: ' + ColorToStyleHex(AList.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AList.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  {$ENDIF}
  AList.Invalidate;
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

procedure ApplyQt5EditTheme(AEdit: TCustomEdit; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  P: TThemePalette;
  Sheet: WideString;
begin
  if not Assigned(AEdit) then Exit;
  if not AEdit.HandleAllocated then Exit;
  P := ThemePalette(ATheme);
  QtWidget := TQtWidget(Pointer(AEdit.Handle));
  Sheet := WideString(
    'QLineEdit { color: ' + ColorToStyleHex(AEdit.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AEdit.Color) +
    '; selection-background-color: ' + ColorToStyleHex(P.AccentActive) + '; }');
  QtWidget.StyleSheet := Sheet;
  SyncThemedEditWidget(AEdit);
end;

procedure ApplyQt5ComboBoxTheme(ACombo: TComboBox; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  Sheet: WideString;
begin
  if not Assigned(ACombo) then Exit;
  if not ACombo.HandleAllocated then Exit;
  QtWidget := TQtWidget(Pointer(ACombo.Handle));
  Sheet := WideString(
    'QComboBox { color: ' + ColorToStyleHex(ACombo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(ACombo.Color) + '; } ' +
    'QComboBox QAbstractItemView { color: ' + ColorToStyleHex(ACombo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(ACombo.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  ACombo.Invalidate;
end;
{$ENDIF}

procedure PaintThemedMenuBarItem(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  ASelected: Boolean; ATheme: TThemeKind; AFontSize: Integer; AChromeBg: TColor);
var
  P: TThemePalette;
  R: TRect;
  TextStr: string;
  TextTop: Integer;
  ChromeBg: TColor;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  if AChromeBg = clNone then
    ChromeBg := P.HeaderBg
  else
    ChromeBg := AChromeBg;
  Canvas.Brush.Style := bsSolid;
  if ASelected then begin
    Canvas.Brush.Color := P.AccentActive;
    Canvas.Pen.Color := P.AccentActive;
  end else begin
    Canvas.Brush.Color := ChromeBg;
    Canvas.Pen.Color := ChromeBg;
  end;
  Canvas.FillRect(R);

  TextStr := MenuItemDisplayCaption(ACaption);
  if TextStr = '' then Exit;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := AFontSize;
  Canvas.Font.Color := P.Text;
  TextTop := R.Top + ((R.Bottom - R.Top - Canvas.TextHeight(TextStr)) div 2);
  Canvas.TextRect(R, R.Left + 10, TextTop, TextStr);
end;

procedure ThemedMenuPopupDrawItem(ACanvas: TCanvas; const ARect: TRect;
  State: TOwnerDrawState; ATheme: TThemeKind; ASource: TMenuItem);
var
  P: TThemePalette;
  TextStr, ShortStr: string;
  TextTop, CheckLeft, SepY: Integer;
  TextColor: TColor;
  R: TRect;
  CheckPad: Integer;
begin
  if not Assigned(ASource) then Exit;

  P := ThemePalette(ATheme);
  R := ARect;

  ACanvas.Brush.Style := bsSolid;
  if (odSelected in State) and ASource.Enabled then begin
    ACanvas.Brush.Color := P.AccentActive;
    ACanvas.Pen.Color := P.AccentActive;
  end else begin
    ACanvas.Brush.Color := P.MenuFlyoutBg;
    ACanvas.Pen.Color := P.MenuFlyoutBg;
  end;
  ACanvas.FillRect(R);

  if ASource.Caption = '-' then begin
    SepY := R.Top + (R.Bottom - R.Top) div 2;
    ACanvas.Pen.Color := P.Border;
    ACanvas.MoveTo(R.Left + 8, SepY);
    ACanvas.LineTo(R.Right - 8, SepY);
    Exit;
  end;

  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := 9;

  if ASource.Enabled then
    TextColor := P.Text
  else
    TextColor := P.TextMuted;
  ACanvas.Font.Color := TextColor;

  CheckPad := ACanvas.TextWidth('✓') + 4;
  CheckLeft := R.Left + 8;
  TextStr := MenuItemDisplayCaption(ASource.Caption);
  TextTop := R.Top + ((R.Bottom - R.Top - ACanvas.TextHeight(TextStr)) div 2);

  if ASource.Checked then begin
    ACanvas.Font.Color := P.Accent;
    ACanvas.TextOut(CheckLeft, TextTop, '✓');
    Inc(CheckLeft, CheckPad);
  end else
    Inc(CheckLeft, CheckPad);

  ACanvas.Font.Color := TextColor;
  ACanvas.TextRect(R, CheckLeft, TextTop, TextStr);

  if ASource.ShortCut <> 0 then begin
    ShortStr := ShortCutToText(ASource.ShortCut);
    ACanvas.Font.Color := P.TextMuted;
    ACanvas.TextOut(R.Right - ACanvas.TextWidth(ShortStr) - 12, TextTop, ShortStr);
  end;

  if ASource.Count > 0 then begin
    ACanvas.Font.Color := P.TextMuted;
    ACanvas.TextOut(R.Right - 20, TextTop, '›');
  end;
end;

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
  LBox.Canvas.Font.Assign(LBox.Font);

  if (odSelected in State) or (odFocused in State) then
    TextColor := P.Accent
  else
    TextColor := P.Text;
  LBox.Canvas.Font.Color := TextColor;

  TextTop := ARect.Top + ((ARect.Bottom - ARect.Top - LBox.Canvas.TextHeight(TextStr)) div 2);
  LBox.Canvas.TextRect(ARect, ARect.Left + 8, TextTop, TextStr);
end;

procedure ThemedNavListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  LBox: TListBox;
  P: TThemePalette;
  TextStr: string;
  TextColor: TColor;
  TextTop: Integer;
  ContentRect: TRect;
  InsetV: Integer;
  Selected: Boolean;
begin
  if not (Control is TListBox) then Exit;
  LBox := TListBox(Control);
  P := ThemePalette(ATheme);

  LBox.Canvas.Brush.Style := bsSolid;
  LBox.Canvas.Brush.Color := LBox.Color;
  LBox.Canvas.Pen.Color := LBox.Color;
  LBox.Canvas.FillRect(ARect);

  if (Index < 0) or (Index >= LBox.Items.Count) then Exit;

  InsetV := ThemedNavListPadV + (ThemedNavListRowGap div 2);
  ContentRect := ARect;
  ContentRect.Top := ContentRect.Top + InsetV;
  ContentRect.Bottom := ContentRect.Bottom - InsetV;
  if ContentRect.Bottom <= ContentRect.Top then
    ContentRect := ARect;

  Selected := (odSelected in State) or (odFocused in State);
  if Selected then begin
    LBox.Canvas.Brush.Color := P.AccentActive;
    LBox.Canvas.Pen.Color := P.AccentActive;
    LBox.Canvas.FillRect(ContentRect);
  end;

  TextStr := LBox.Items[Index];
  LBox.Canvas.Font.Assign(LBox.Font);
  if Selected then
    TextColor := P.Accent
  else
    TextColor := P.Text;
  LBox.Canvas.Font.Color := TextColor;

  TextTop := ContentRect.Top +
    ((ContentRect.Bottom - ContentRect.Top - LBox.Canvas.TextHeight(TextStr)) div 2);
  LBox.Canvas.TextRect(ContentRect, ContentRect.Left + ThemedNavListPadLeft, TextTop, TextStr);
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
  if (AControl is TComboBox) or (AControl is TEdit) then begin
    if ATheme = tkDark then
      ThemeId := 'DarkMode_Explorer'
    else
      ThemeId := 'Explorer';
    SetWindowTheme(AControl.Handle, ThemeId, nil);
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
  if AControl is TCustomEdit then begin
    ApplyQt5EditTheme(TCustomEdit(AControl), ATheme);
    Exit;
  end;
  if AControl is TComboBox then begin
    ApplyQt5ComboBoxTheme(TComboBox(AControl), ATheme);
    Exit;
  end;
  {$ENDIF}
  if AControl is TCustomListBox then begin
    SyncThemedListBoxWidget(TCustomListBox(AControl));
    Exit;
  end;
  // GTK/Cocoa: scrollbars follow the OS widget theme; keep client colors via ApplyTheme.
  AControl.Invalidate;
{$ENDIF}
end;

procedure ApplyThemedButtonsRecursive(ARoot: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  C: TControl;
  Child: TWinControl;
begin
  if not Assigned(ARoot) then Exit;
  for I := 0 to ARoot.ControlCount - 1 do begin
    C := ARoot.Controls[I];
    if C is TLcaThemedButton then
      TLcaThemedButton(C).ApplyTheme(ATheme)
    else if C is TButton then
      ApplyThemedButtonControl(TButton(C), ATheme);
    if C is TWinControl then begin
      Child := TWinControl(C);
      if Child.ControlCount > 0 then
        ApplyThemedButtonsRecursive(Child, ATheme);
    end;
  end;
end;

procedure ApplyFormPlatformThemes(AForm: TCustomForm; ATheme: TThemeKind);
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  ApplyPlatformScrollableThemeRecursive(AForm, ATheme);
  ApplyThemedButtonsRecursive(AForm, ATheme);
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

type
  TThemedDrawHandlers = class
  public
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
  end;

var
  ThemeCustomApplies: array of TThemeCustomApplyProc;
  InternalThemeApplyContext: TThemeKind = tkDark;
  ThemedDrawHandlers: TThemedDrawHandlers;

procedure RegisterThemeCustomApply(const AProc: TThemeCustomApplyProc);
begin
  SetLength(ThemeCustomApplies, Length(ThemeCustomApplies) + 1);
  ThemeCustomApplies[High(ThemeCustomApplies)] := AProc;
end;

function TryThemeCustomApply(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ThemeCustomApplies) do
    if Assigned(ThemeCustomApplies[I]) and ThemeCustomApplies[I](AControl, ATheme) then
      Exit(True);
end;

procedure TThemedDrawHandlers.ComboDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  StyleComboBoxDrawItem(Control, Index, ARect, State, InternalThemeApplyContext);
end;

procedure TThemedDrawHandlers.ListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, InternalThemeApplyContext);
end;

function ResolveThemedButtonRole(ABtn: TButton): TThemedButtonRole;
begin
  if ABtn is TLcaThemedButton then
    Exit(TLcaThemedButton(ABtn).ButtonRole);
  case ABtn.Tag of
    1: Exit(tbrPrimary);
    2: Exit(tbrDestructive);
  else
    Exit(tbrCancel);
  end;
end;

procedure ApplyThemedButtonControl(ABtn: TButton; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  StyleThemedButtonRole(ABtn, ATheme, ResolveThemedButtonRole(ABtn));
end;

procedure ApplyThemedPanelColors(APanel: TPanel; AColor: TColor; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(APanel) then Exit;
  P := ThemePalette(ATheme);
  APanel.Color := AColor;
  APanel.ParentColor := False;
  {$IFDEF WINDOWS}
  APanel.ParentBackground := False;
  {$ENDIF}
  APanel.Font.Color := P.Text;
  APanel.Invalidate;
end;

procedure ApplyThemedControlTree(ARoot: TWinControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
  C: TControl;
  Child: TWinControl;
begin
  if not Assigned(ARoot) then Exit;
  InternalThemeApplyContext := ATheme;
  P := ThemePalette(ATheme);

  for I := 0 to ARoot.ControlCount - 1 do begin
    C := ARoot.Controls[I];
    if TryThemeCustomApply(C, ATheme) then
      Continue;

    if C is TLcaThemedButton then
      TLcaThemedButton(C).ApplyTheme(ATheme)
    else if C is TButton then
      ApplyThemedButtonControl(TButton(C), ATheme)
    else if C is TLcaThemedComboBox then
      TLcaThemedComboBox(C).ApplyTheme(ATheme)
    else if C is TComboBox then begin
      StyleComboBox(TComboBox(C), ATheme);
      TComboBox(C).OnDrawItem := @ThemedDrawHandlers.ComboDrawItem;
    end else if C is TListBox then begin
      ConfigureThemedListBox(TListBox(C), ATheme);
      TListBox(C).OnDrawItem := @ThemedDrawHandlers.ListDrawItem;
      TListBox(C).Invalidate;
    end else if C is TTreeView then
      ConfigureThemedTreeView(TTreeView(C), ATheme)
    else if C is TCustomMemo then
      ConfigureThemedMemo(TCustomMemo(C), ATheme)
    else if C is TCustomEdit then begin
      TCustomEdit(C).Color := P.SurfaceAlt;
      TCustomEdit(C).Font.Color := P.Text;
    end else if C is TLabel then
      TLabel(C).Font.Color := P.Text
    else if C is TPanel then begin
      if Pos('Chrome', C.Name) > 0 then
        ApplyThemedPanelColors(TPanel(C), P.HeaderBg, ATheme)
      else
        ApplyThemedPanelColors(TPanel(C), P.Surface, ATheme);
    end
    else if C is TScrollBox then begin
      TScrollBox(C).Color := P.Surface;
      TScrollBox(C).ParentColor := False;
    end
    else if C is TPageControl then
      StylePageControl(TPageControl(C), ATheme)
    else if C is TSplitter then
      TSplitter(C).Color := P.Border
    else if C is TStatusBar then begin
      TStatusBar(C).Color := P.Surface;
      TStatusBar(C).Font.Color := P.TextMuted;
    end else if C is TCheckBox then
      ConfigureThemedCheckBox(TCheckBox(C), ATheme)
    else if C is TSpeedButton then begin
      TSpeedButton(C).Font.Color := P.TextMuted;
      TSpeedButton(C).Color := P.RailBg;
    end;

    if C is TWinControl then begin
      Child := TWinControl(C);
      if Child.ControlCount > 0 then
        ApplyThemedControlTree(Child, ATheme);
    end;
  end;
end;

procedure ApplyThemedForm(AForm: TCustomForm; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(AForm) then Exit;
  InternalThemeApplyContext := ATheme;
  P := ThemePalette(ATheme);
  AForm.Color := P.Background;
  AForm.Font.Color := P.Text;
  ApplyThemedControlTree(AForm, ATheme);
end;

initialization
  ThemedDrawHandlers := TThemedDrawHandlers.Create;

finalization
  FreeAndNil(ThemedDrawHandlers);

end.
