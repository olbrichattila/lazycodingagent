unit uTerminalPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Forms, StdCtrls, FileUtil, uAppTypes, uTheme,
  Terminal.Controller, Terminal.View.LCL;

type
  TTerminalStatusEvent = procedure(Sender: TObject; const AMessage: string) of object;

  { PTY controller; TTerminalLCLView is created at runtime (not on .lfm) for IDE compatibility. }
  TTerminalPanel = class(TComponent)
  private
    FHost: TWinControl;
    FView: TTerminalLCLView;
    FController: TTerminalController;
    FStatusLabel: TLabel;
    FShellRunning: Boolean;
    FWorkingDir: string;
    FOnTerminalStatus: TTerminalStatusEvent;
    procedure ShellExited(Sender: TObject);
    procedure EnsureTerminalView;
    function TryStartShell: Boolean;
    procedure SetStatus(const AMessage: string);
    procedure HideStatus;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(AHost: TWinControl; AStatus: TLabel);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetWorkingDirectory(const ADir: string);
    function EnsureRunning: Boolean;
    procedure Stop;
    procedure RestartForWorkspace;
    procedure FocusTerminal;
    function Visible: Boolean;
    property OnTerminalStatus: TTerminalStatusEvent read FOnTerminalStatus write FOnTerminalStatus;
  end;

implementation

{$IFDEF UNIX}
{$linklib util}
{$ENDIF}

procedure TTerminalPanel.SetStatus(const AMessage: string);
begin
  if Assigned(FStatusLabel) then begin
    FStatusLabel.Caption := AMessage;
    FStatusLabel.Visible := Trim(AMessage) <> '';
  end;
  if Assigned(FOnTerminalStatus) then
    FOnTerminalStatus(Self, AMessage);
end;

procedure TTerminalPanel.HideStatus;
begin
  SetStatus('');
end;

procedure TTerminalPanel.ShellExited(Sender: TObject);
begin
  FShellRunning := False;
  if Assigned(FView) then
    FView.WriteExitBanner;
  SetStatus('Shell exited — hide and show Terminal (View menu) to start a new session.');
end;

function TTerminalPanel.Visible: Boolean;
begin
  if Assigned(FHost) then
    Result := FHost.Visible
  else
    Result := False;
end;

function TTerminalPanel.TryStartShell: Boolean;
var
  PrevDir: string;
  ShellPath: string;
  ShellArgs: array of string;
  BaseName: string;
begin
  Result := False;
  if FShellRunning then begin
    Result := True;
    Exit;
  end;
  if not Assigned(FController) then
    Exit;
  if not Assigned(FHost) then
    Exit;
  if not ParentFormHandlesReady(FHost) then
    Exit;
  if not FHost.Visible then
    Exit;

  EnsureTerminalView;
  if not Assigned(FView) then
    Exit;

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

constructor TTerminalPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWorkingDir := GetUserDir;
  FShellRunning := False;
  FController := TTerminalController.Create(80, 24, 5000);
end;

destructor TTerminalPanel.Destroy;
begin
  Stop;
  if Assigned(FView) then
    FView.DetachController;
  FreeAndNil(FController);
  inherited Destroy;
end;

procedure TTerminalPanel.EnsureTerminalView;
begin
  if Assigned(FView) then Exit;
  if not Assigned(FHost) then Exit;
  if not ParentFormHandlesReady(FHost) then Exit;
  FView := TTerminalLCLView.Create(Self);
  FView.Parent := FHost;
  FView.Align := alClient;
  FView.FontName := 'DejaVu Sans Mono';
  FView.FontSize := 10;
  FView.OnShellExit := @ShellExited;
end;

procedure TTerminalPanel.Bind(AHost: TWinControl; AStatus: TLabel);
begin
  FHost := AHost;
  FStatusLabel := AStatus;
  EnsureTerminalView;
end;

procedure TTerminalPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  if Assigned(FStatusLabel) then begin
    FStatusLabel.Color := P.Background;
    FStatusLabel.Font.Color := P.TextMuted;
  end;
  if not Assigned(FView) then Exit;
  FView.BackgroundColor := P.Background;
  FView.DefaultFGColor := P.Text;
  FView.SelectionFGColor := P.AccentText;
  FView.SelectionBGColor := P.Accent;
  ApplyPlatformScrollableTheme(FView, ATheme);
  FView.Invalidate;
end;

procedure TTerminalPanel.SetWorkingDirectory(const ADir: string);
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

function TTerminalPanel.EnsureRunning: Boolean;
begin
  Result := TryStartShell;
end;

procedure TTerminalPanel.Stop;
begin
  if Assigned(FView) then
    FView.DetachController
  else if Assigned(FController) then
    FController.Stop;
  FShellRunning := False;
end;

procedure TTerminalPanel.RestartForWorkspace;
begin
  Stop;
end;

procedure TTerminalPanel.FocusTerminal;
begin
  if Assigned(FView) and FView.CanFocus then
    FView.SetFocus;
end;

end.
