unit uThemeHooks;

{$mode objfpc}{$H+}

interface

procedure RegisterThemeCustomHooks;

implementation

uses
  Classes, SysUtils, Controls, SynEdit, Terminal.View.LCL, uAppTypes, uTheme, uThemedPageTabBar;

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
