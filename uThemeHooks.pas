unit uThemeHooks;

{$mode objfpc}{$H+}

interface

uses
  SynEdit, uAppTypes;

procedure RegisterThemeCustomHooks;
procedure ApplySynEditGutterTheme(AEd: TSynEdit; ATheme: TThemeKind);

implementation

uses
  Classes, SysUtils, Controls, Graphics, Terminal.View.LCL, uTheme, uThemedPageTabBar;

type
  TThemeHookRegistry = class
  public
    function HookThemedPageTabBar(AControl: TControl; ATheme: TThemeKind): Boolean;
    function HookSynEdit(AControl: TControl; ATheme: TThemeKind): Boolean;
    function HookTerminalView(AControl: TControl; ATheme: TThemeKind): Boolean;
  end;

var
  ThemeHookRegistry: TThemeHookRegistry;
  GThemeHooksRegistered: Boolean = False;

function TThemeHookRegistry.HookThemedPageTabBar(AControl: TControl; ATheme: TThemeKind): Boolean;
begin
  Result := False;
  if not Assigned(AControl) then Exit;
  if not AControl.ClassNameIs('TThemedPageTabBar') then Exit;
  TThemedPageTabBar(AControl).ApplyTheme(ATheme);
  Result := True;
end;

procedure ApplySynEditGutterTheme(AEd: TSynEdit; ATheme: TThemeKind);
var
  P: TThemePalette;
  GutterBg, LineNumFg: TColor;
begin
  if not Assigned(AEd) then Exit;
  P := ThemePalette(ATheme);
  if ATheme = tkDark then begin
    GutterBg := P.Background;
    LineNumFg := clWhite;
  end else begin
    GutterBg := clWhite;
    LineNumFg := clBlack;
  end;
  AEd.Gutter.Color := GutterBg;
  with AEd.Gutter.LineNumberPart do begin
    MarkupInfo.Background := GutterBg;
    MarkupInfo.Foreground := LineNumFg;
  end;
  with AEd.Gutter.MarksPart do
    MarkupInfo.Background := GutterBg;
  with AEd.Gutter.SeparatorPart do begin
    MarkupInfo.Background := GutterBg;
    MarkupInfo.Foreground := P.TextMuted;
  end;
  with AEd.Gutter.CodeFoldPart do
    MarkupInfo.Foreground := P.TextMuted;
end;

function TThemeHookRegistry.HookSynEdit(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  P: TThemePalette;
  Ed: TSynEdit;
begin
  Result := False;
  if not (AControl is TSynEdit) then Exit;
  Ed := TSynEdit(AControl);
  P := ThemePalette(ATheme);
  Ed.Color := P.SurfaceAlt;
  Ed.Font.Color := P.Text;
  Ed.Font.Size := ScaledEditorFontSize(Ed);
  ApplySynEditGutterTheme(Ed, ATheme);
  ApplyPlatformScrollableTheme(Ed, ATheme);
  Ed.Invalidate;
  Result := True;
end;

function TThemeHookRegistry.HookTerminalView(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  P: TThemePalette;
  View: TTerminalLCLView;
begin
  Result := False;
  if not (AControl is TTerminalLCLView) then Exit;
  View := TTerminalLCLView(AControl);
  P := ThemePalette(ATheme);
  View.Color := P.SurfaceAlt;
  View.Font.Color := P.Text;
  View.Invalidate;
  Result := True;
end;

procedure RegisterThemeCustomHooks;
begin
  if GThemeHooksRegistered then Exit;
  GThemeHooksRegistered := True;
  RegisterThemeCustomApply(@ThemeHookRegistry.HookThemedPageTabBar);
  RegisterThemeCustomApply(@ThemeHookRegistry.HookSynEdit);
  RegisterThemeCustomApply(@ThemeHookRegistry.HookTerminalView);
end;

initialization
  ThemeHookRegistry := TThemeHookRegistry.Create;

finalization
  FreeAndNil(ThemeHookRegistry);

end.
