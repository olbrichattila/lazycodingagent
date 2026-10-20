unit LcaDesignReg;

{$mode objfpc}{$H+}

interface

uses
  Classes;

procedure Register;

implementation

uses
  TypInfo, PropEdits, LcaTheme, LcaThemedPageTabBar, LcaThemedButton,
  LcaThemedComboBox, LcaNavRailButton, LcaSurfacePanel, LcaPaintSurface, LcaPaintButton, LcaScrollHost,
  LcaMarkdownView,
  LcaTerminalPanel, LcaThemedMainMenu, LcaThemedMenuBar, LcaThemedTitleBar;

{$R ../res/lca_design_glyphs.res}

procedure Register;
begin
  RegisterComponents('LCA Design', [
    TLcaThemedPageTabBar,
    TLcaThemedButton,
    TLcaThemedComboBox,
    TLcaNavRailButton,
    TLcaSurfacePanel,
    TLcaPaintSurface,
    TLcaPaintButton,
    TLcaScrollHost,
    TLcaMarkdownView,
    TLcaTerminalPanel,
    TLcaThemedMainMenu,
    TLcaThemedMenuBar,
    TLcaThemedTitleBar
  ]);
  RegisterPropertyEditor(TypeInfo(TThemeKind), nil, '', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemedButtonRole), nil, '', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedButton, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemedButtonRole), TLcaThemedButton, 'ButtonRole', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedComboBox, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedPageTabBar, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaNavRailButton, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaSurfacePanel, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaPaintSurface, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaPaintButton, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemedButtonRole), TLcaPaintButton, 'ButtonRole', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaScrollHost, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaMarkdownView, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaTerminalPanel, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedMenuBar, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedTitleBar, 'ThemeKind', TEnumPropertyEditor);
end;

end.
