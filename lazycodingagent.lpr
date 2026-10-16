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
  Interfaces, // this includes the LCL widgetset
  Forms, uAppIcon, mainunit, frmSplash, uWorkspaceState
  { you can add units after this };

{$IFDEF WINDOWS}
{$R lazycodingagent_appicon.res}
{$ENDIF}
{$R *.res}

var
  Splash: TSplashForm;

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  ApplyOwlApplicationIcon;
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
