program lazycodingagent;

{$mode objfpc}{$H+}

{$R packages/LcaDesignSystem/res/owl_icon.res}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset (keep cthreads before Interfaces on Unix)
  SysUtils,
  Forms, mainunit, frmSplash, uWorkspaceState
  { you can add units after this };

{$IFDEF WINDOWS}
{$R lazycodingagent_appicon.res}
{$ENDIF}
{$R *.res}

{$IFDEF UNIX}
{$IFDEF LCLGtk2}
function libc_setenv(name, value: PChar; overwrite: Integer): Integer; cdecl;
  external 'c' name 'setenv';

procedure ApplyGtk2WaylandGdkBackend;
begin
  if (GetEnvironmentVariable('GDK_BACKEND') = '') and
     (GetEnvironmentVariable('WAYLAND_DISPLAY') <> '') then
    libc_setenv('GDK_BACKEND', 'x11', 1);
end;
{$ENDIF}
{$ENDIF}

var
  Splash: TSplashForm;

begin
  {$IFDEF UNIX}
  {$IFDEF LCLGtk2}
  ApplyGtk2WaylandGdkBackend;
  {$ENDIF}
  {$ENDIF}
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.ShowMainForm := False;
  Splash := TSplashForm.Create(Application);
  try
    SetActiveSplashForm(Splash);
    Splash.ApplyTheme(LoadPersistedThemeKind);
    Splash.SetLoadProgress(0);
    Splash.Show;
    Application.ProcessMessages;
    Application.CreateForm(TLazyCodingAgentForm, LazyCodingAgentForm);
    LazyCodingAgentForm.PrepareVisibleStartup;
    Splash.HoldVisible(SplashPostLoadDelayMs);
  finally
    SetActiveSplashForm(nil);
    Splash.Hide;
    Splash.Free;
  end;
  LazyCodingAgentForm.Show;
  Application.Run;
end.
