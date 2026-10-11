unit uPanelDetach;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, ExtCtrls, uAppTypes, uTheme;

type
  TDockPanelAction = (dpaHide, dpaDetach, dpaAttach);
  TPanelDetachAttachEvent = procedure(Sender: TObject; AId: TPanelId) of object;

  { TDetachedPanelForm }
  TDetachedPanelForm = class(TForm)
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FPanelId: TPanelId;
    FOnRequestAttach: TPanelDetachAttachEvent;
    function IsApplicationShutdown: Boolean;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor CreateForPanel(AOwner: TComponent; AId: TPanelId; const ACaption: string;
      ALeft, ATop, AWidth, AHeight: Integer; AOnRequestAttach: TPanelDetachAttachEvent);
    procedure ApplyTheme(ATheme: TThemeKind);
    property PanelId: TPanelId read FPanelId;
    property OnRequestAttach: TPanelDetachAttachEvent read FOnRequestAttach write FOnRequestAttach;
  end;

  { TPanelDetachSlot — reparents a content root between dock host and floating form }
  TPanelDetachSlot = class
  private
    FId: TPanelId;
    FDockHost: TWinControl;
    FContentRoot: TWinControl;
    FFloatingForm: TDetachedPanelForm;
    FOnRequestAttach: TPanelDetachAttachEvent;
    procedure EnsureFloatingForm(const ACaption: string; ALeft, ATop, AWidth, AHeight: Integer);
  public
    constructor Create(AId: TPanelId; ADockHost, AContentRoot: TWinControl;
      AOnRequestAttach: TPanelDetachAttachEvent);
    destructor Destroy; override;
    function IsDetached: Boolean;
    procedure DetachToWindow(ALeft, ATop, AWidth, AHeight: Integer; const ACaption: string);
    procedure AttachToHost;
    procedure PrepareForApplicationClose(out ABounds: TRect);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure BringFloatingToFront;
    procedure HideFloating;
    property FloatingForm: TDetachedPanelForm read FFloatingForm;
    property ContentRoot: TWinControl read FContentRoot;
  end;

implementation

{ TDetachedPanelForm }

constructor TDetachedPanelForm.CreateForPanel(AOwner: TComponent; AId: TPanelId;
  const ACaption: string; ALeft, ATop, AWidth, AHeight: Integer;
  AOnRequestAttach: TPanelDetachAttachEvent);
begin
  inherited CreateNew(AOwner);
  FPanelId := AId;
  FOnRequestAttach := AOnRequestAttach;
  Caption := ACaption + ' [Detached]';
  Position := poDesigned;
  Left := ALeft;
  Top := ATop;
  Width := AWidth;
  Height := AHeight;
  Constraints.MinWidth := 280;
  Constraints.MinHeight := 200;
  ShowInTaskBar := stAlways;
  OnCloseQuery := @FormCloseQuery;
end;

function TDetachedPanelForm.IsApplicationShutdown: Boolean;
begin
  Result := Application.Terminated or (csDestroying in ComponentState);
end;

procedure TDetachedPanelForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if IsApplicationShutdown then
    CanClose := True;
end;

procedure TDetachedPanelForm.DoClose(var CloseAction: TCloseAction);
begin
  if IsApplicationShutdown then begin
    CloseAction := caFree;
    Exit;
  end;
  CloseAction := caHide;
  if Assigned(FOnRequestAttach) then
    FOnRequestAttach(Self, FPanelId);
end;

procedure TDetachedPanelForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  Invalidate;
end;

{ TPanelDetachSlot }

constructor TPanelDetachSlot.Create(AId: TPanelId; ADockHost, AContentRoot: TWinControl;
  AOnRequestAttach: TPanelDetachAttachEvent);
begin
  inherited Create;
  FId := AId;
  FDockHost := ADockHost;
  FContentRoot := AContentRoot;
  FOnRequestAttach := AOnRequestAttach;
  FFloatingForm := nil;
end;

destructor TPanelDetachSlot.Destroy;
begin
  if Assigned(FFloatingForm) then
    FreeAndNil(FFloatingForm);
  inherited Destroy;
end;

procedure TPanelDetachSlot.EnsureFloatingForm(const ACaption: string; ALeft, ATop, AWidth,
  AHeight: Integer);
begin
  if not Assigned(FFloatingForm) then
    FFloatingForm := TDetachedPanelForm.CreateForPanel(Application, FId, ACaption, ALeft, ATop,
      AWidth, AHeight, FOnRequestAttach);
end;

function TPanelDetachSlot.IsDetached: Boolean;
begin
  Result := Assigned(FFloatingForm) and FFloatingForm.Visible;
end;

procedure TPanelDetachSlot.DetachToWindow(ALeft, ATop, AWidth, AHeight: Integer;
  const ACaption: string);
begin
  EnsureFloatingForm(ACaption, ALeft, ATop, AWidth, AHeight);
  if Assigned(FContentRoot) then begin
    FContentRoot.Parent := FFloatingForm;
    FContentRoot.Align := alClient;
  end;
  FFloatingForm.Show;
  FFloatingForm.BringToFront;
  if Assigned(FDockHost) then
    FDockHost.Visible := False;
end;

procedure TPanelDetachSlot.AttachToHost;
begin
  if Assigned(FFloatingForm) then
    FFloatingForm.Hide;
  if Assigned(FDockHost) then
    FDockHost.Visible := True;
  if Assigned(FContentRoot) and Assigned(FDockHost) then begin
    FContentRoot.Parent := FDockHost;
    FContentRoot.Align := alClient;
    if ParentFormHandlesReady(FContentRoot) then
      FContentRoot.ReAlign;
  end;
end;

procedure TPanelDetachSlot.PrepareForApplicationClose(out ABounds: TRect);
begin
  ABounds := Rect(0, 0, 0, 0);
  if not Assigned(FFloatingForm) then Exit;
  with FFloatingForm do
    ABounds := Rect(Left, Top, Width, Height);
  if Assigned(FContentRoot) and (FContentRoot.Parent = FFloatingForm) then begin
    if Assigned(FDockHost) then begin
      FContentRoot.Parent := FDockHost;
      FContentRoot.Align := alClient;
    end;
  end;
  FreeAndNil(FFloatingForm);
end;

procedure TPanelDetachSlot.ApplyTheme(ATheme: TThemeKind);
begin
  if Assigned(FFloatingForm) then
    FFloatingForm.ApplyTheme(ATheme);
end;

procedure TPanelDetachSlot.BringFloatingToFront;
begin
  if Assigned(FFloatingForm) and FFloatingForm.Visible then
    FFloatingForm.BringToFront;
end;

procedure TPanelDetachSlot.HideFloating;
begin
  if Assigned(FFloatingForm) then
    FFloatingForm.Hide;
end;

end.
