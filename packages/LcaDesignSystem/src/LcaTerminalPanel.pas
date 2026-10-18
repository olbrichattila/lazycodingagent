unit LcaTerminalPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, FileUtil, Forms, LCLType, LMessages, LcaTheme,
  Terminal.Controller, Terminal.View.LCL;

type
  TLcaTerminalStatusEvent = procedure(Sender: TObject; const AMessage: string) of object;

  { Embedded PTY terminal for the Lazarus form designer (streams on .lfm). }
  TLcaTerminalPanel = class(TPanel)
  private
    FView: TTerminalLCLView;
    FController: TTerminalController;
    FStatusLabel: TLabel;
    FShellRunning: Boolean;
    FWorkingDir: string;
    FThemeKind: TThemeKind;
    FOnTerminalStatus: TLcaTerminalStatusEvent;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetStatusLabel(AValue: TLabel);
    procedure ShellExited(Sender: TObject);
    procedure EnsureTerminalView;
    function TryStartShell: Boolean;
    procedure SetStatus(const AMessage: string);
    procedure HideStatus;
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure CMShowingChanged(var Message: TLMessage); message CM_SHOWINGCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetWorkingDirectory(const ADir: string);
    function EnsureRunning: Boolean;
    procedure Stop;
    procedure RestartForWorkspace;
    procedure FocusTerminal;
    function TerminalVisible: Boolean;
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property StatusLabel: TLabel read FStatusLabel write SetStatusLabel;
    property OnTerminalStatus: TLcaTerminalStatusEvent read FOnTerminalStatus write FOnTerminalStatus;
  end;

implementation

{$IFDEF UNIX}
{$linklib util}
{$ENDIF}

procedure TLcaTerminalPanel.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaTerminalPanel.SetStatusLabel(AValue: TLabel);
begin
  FStatusLabel := AValue;
end;

procedure TLcaTerminalPanel.SetStatus(const AMessage: string);
begin
  if Assigned(FStatusLabel) then begin
    FStatusLabel.Caption := AMessage;
    FStatusLabel.Visible := Trim(AMessage) <> '';
  end;
  if Assigned(FOnTerminalStatus) then
    FOnTerminalStatus(Self, AMessage);
end;

procedure TLcaTerminalPanel.HideStatus;
begin
  SetStatus('');
end;

procedure TLcaTerminalPanel.ShellExited(Sender: TObject);
begin
  FShellRunning := False;
  if Assigned(FView) then
    FView.WriteExitBanner;
  SetStatus('Shell exited — hide and show Terminal (View menu) to start a new session.');
end;

function TLcaTerminalPanel.TerminalVisible: Boolean;
begin
  Result := Visible;
end;

procedure TLcaTerminalPanel.EnsureTerminalView;
begin
  if csDesigning in ComponentState then Exit;
  if Assigned(FView) then Exit;
  if not ParentFormHandlesReady(Self) then Exit;
  FView := TTerminalLCLView.Create(Self);
  FView.Parent := Self;
  FView.Align := alClient;
  FView.FontName := ThemedMonospaceFontName;
  FView.FontSize := ScaledEditorFontSize(Self);
  FView.OnShellExit := @ShellExited;
end;

function TLcaTerminalPanel.TryStartShell: Boolean;
var
  PrevDir: string;
  ShellPath: string;
  ShellArgs: array of string;
  BaseName: string;
begin
  Result := False;
  if csDesigning in ComponentState then Exit;
  if FShellRunning then Exit(True);
  if not Assigned(FController) then Exit;
  if not ParentFormHandlesReady(Self) then Exit;
  if not Visible then Exit;

  EnsureTerminalView;
  if not Assigned(FView) then Exit;

  FView.OnShellExit := @ShellExited;
  FView.DetachController;
  SetLength(ShellArgs, 0);
  {$IFDEF WINDOWS}
  ShellPath := GetEnvironmentVariable('COMSPEC');
  if Trim(ShellPath) = '' then
    ShellPath := 'cmd.exe';
  {$ELSE}
  ShellPath := Trim(GetEnvironmentVariable('SHELL'));
  if (ShellPath = '') or not FileExists(ShellPath) then
    ShellPath := '/bin/bash';
  if not FileExists(ShellPath) then
    ShellPath := '/bin/sh';
  if not FileExists(ShellPath) then begin
    SetStatus('Terminal failed to start: no shell found (check $SHELL or install bash).');
    Exit;
  end;
  BaseName := LowerCase(ExtractFileName(ShellPath));
  if (BaseName = 'bash') or (BaseName = 'zsh') then begin
    SetLength(ShellArgs, 1);
    ShellArgs[0] := '-i';
  end;
  {$ENDIF}

  PrevDir := GetCurrentDir;
  try
    if (FWorkingDir <> '') and DirectoryExists(FWorkingDir) then
      SetCurrentDir(FWorkingDir);
    if FController.StartShell(ShellPath, ShellArgs) and
       Assigned(FController.Backend) and FController.Backend.IsRunning then begin
      FView.AttachController(FController);
      FView.EnsureRendered;
      FController.Pump;
      FShellRunning := True;
      HideStatus;
      FView.Invalidate;
      FocusTerminal;
      Result := True;
    end else
      SetStatus('Terminal failed to start (PTY). On Linux ensure libutil is available (util-linux / bsdutils).');
  finally
    if (PrevDir <> '') and DirectoryExists(PrevDir) then
      SetCurrentDir(PrevDir);
  end;
end;

constructor TLcaTerminalPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FWorkingDir := GetUserDir;
  FShellRunning := False;
  FThemeKind := tkDark;
  if not (csDesigning in ComponentState) then
    FController := TTerminalController.Create(80, 24, 5000);
end;

destructor TLcaTerminalPanel.Destroy;
begin
  Stop;
  if Assigned(FView) then
    FView.DetachController;
  FreeAndNil(FController);
  inherited Destroy;
end;

procedure TLcaTerminalPanel.Loaded;
begin
  inherited Loaded;
  if csDesigning in ComponentState then begin
    ApplyTheme(FThemeKind);
    Exit;
  end;
  EnsureTerminalView;
  ApplyTheme(FThemeKind);
end;

procedure TLcaTerminalPanel.Resize;
begin
  inherited Resize;
  if Assigned(FView) then
    FView.Invalidate;
end;

procedure TLcaTerminalPanel.CMShowingChanged(var Message: TLMessage);
begin
  inherited CMShowingChanged(Message);
  if csDesigning in ComponentState then Exit;
  if not Showing or not Visible then Exit;
  if FShellRunning then Exit;
  if not ParentFormHandlesReady(Self) then Exit;
  EnsureRunning;
end;

procedure TLcaTerminalPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  P := ThemePalette(EffectiveControlTheme(Self, ATheme));
  Color := P.Background;
  if Assigned(FStatusLabel) then begin
    FStatusLabel.Color := P.Background;
    FStatusLabel.Font.Color := P.TextMuted;
  end;
  if not Assigned(FView) then Exit;
  FView.BackgroundColor := P.Background;
  FView.DefaultFGColor := P.Text;
  FView.SelectionFGColor := P.AccentText;
  FView.SelectionBGColor := P.Accent;
  FView.FontName := ThemedMonospaceFontName;
  FView.FontSize := ScaledEditorFontSize(Self);
  ApplyPlatformScrollableTheme(FView, ATheme);
  FView.Invalidate;
end;

procedure TLcaTerminalPanel.SetWorkingDirectory(const ADir: string);
var
  Norm: string;
begin
  Norm := Trim(ADir);
  if Norm = '' then
    Norm := GetUserDir;
  if DirectoryExists(Norm) then
    FWorkingDir := IncludeTrailingPathDelimiter(Norm)
  else
    FWorkingDir := GetUserDir;
end;

function TLcaTerminalPanel.EnsureRunning: Boolean;
begin
  if csDesigning in ComponentState then
    Exit(False);
  Result := TryStartShell;
end;

procedure TLcaTerminalPanel.Stop;
begin
  if Assigned(FView) then
    FView.DetachController
  else if Assigned(FController) then
    FController.Stop;
  FShellRunning := False;
end;

procedure TLcaTerminalPanel.RestartForWorkspace;
begin
  Stop;
end;

procedure TLcaTerminalPanel.FocusTerminal;
begin
  if Assigned(FView) and FView.CanFocus then
    FView.SetFocus;
end;

end.
