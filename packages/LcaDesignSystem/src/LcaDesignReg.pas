unit LcaDesignReg;

{$mode objfpc}{$H+}

interface

uses
  Classes;

procedure Register;

implementation

uses
  TypInfo, PropEdits, LcaTheme, LcaThemedPageTabBar, LcaThemedButton,
  LcaThemedComboBox, LcaNavRailButton, LcaSurfacePanel, LcaMarkdownView, LcaTerminalPanel,
  LcaThemedMainMenu, LcaThemedMenuBar;

procedure Register;
begin
  RegisterComponents('LCA Design', [
    TLcaThemedPageTabBar,
    TLcaThemedButton,
    TLcaThemedComboBox,
    TLcaNavRailButton,
    TLcaSurfacePanel,
    TLcaMarkdownView,
    TLcaTerminalPanel,
    TLcaThemedMainMenu,
    TLcaThemedMenuBar
  ]);
  RegisterPropertyEditor(TypeInfo(TThemeKind), nil, '', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemedButtonRole), nil, '', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedButton, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemedButtonRole), TLcaThemedButton, 'ButtonRole', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedComboBox, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedPageTabBar, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaNavRailButton, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaSurfacePanel, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaMarkdownView, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaTerminalPanel, 'ThemeKind', TEnumPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TThemeKind), TLcaThemedMenuBar, 'ThemeKind', TEnumPropertyEditor);
end;

end.
