unit uPanelDetach;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, uAppTypes, uWorkspaceState, uTheme;

type
  TPanelDetachManager = class
  private
    FOwner: TComponent;
    FMainForm: TForm;
    FState: TWorkspaceState;
    FDockHost: array[TPanelId] of TPanel;
    FContent: array[TPanelId] of TWinControl;
    FFloatForm: array[TPanelId] of TForm;
    FBound: array[TPanelId] of Boolean;
    procedure FloatFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FloatFormBoundsChanged(Sender: TObject);
    procedure EnsureFloatForm(AId: TPanelId);
    procedure DetachPanel(AId: TPanelId);
    function DefaultFloatBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
  public
    procedure AttachPanel(AId: TPanelId);
    constructor Create(AOwner: TComponent; AMainForm: TForm; AState: TWorkspaceState);
    destructor Destroy; override;
    procedure Bind(AId: TPanelId; ADockHost: TPanel; AContent: TWinControl);
    procedure ToggleDetach(AId: TPanelId);
    procedure ApplyLayout;
    procedure ApplyThemes(ATheme: TThemeKind);
    procedure RaiseFloatingForms;
    procedure AttachAll;
    procedure FinalizeOnClose;
  end;

implementation

procedure TPanelDetachManager.Bind(AId: TPanelId; ADockHost: TPanel; AContent: TWinControl);
begin
  if AId = piTerminal then Exit;
  FDockHost[AId] := ADockHost;
  FContent[AId] := AContent;
  FBound[AId] := Assigned(ADockHost) and Assigned(AContent);
end;

constructor TPanelDetachManager.Create(AOwner: TComponent; AMainForm: TForm;
  AState: TWorkspaceState);
var
  P: TPanelId;
begin
  inherited Create;
  FOwner := AOwner;
  FMainForm := AMainForm;
  FState := AState;
  for P := Low(TPanelId) to High(TPanelId) do
    FBound[P] := False;
end;

destructor TPanelDetachManager.Destroy;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do
    FreeAndNil(FFloatForm[P]);
  inherited Destroy;
end;

function TPanelDetachManager.DefaultFloatBounds(AId: TPanelId; out ALeft, ATop, AWidth,
  AHeight: Integer): Boolean;
begin
  Result := False;
  if not FBound[AId] then Exit;
  AWidth := FDockHost[AId].Width;
  AHeight := FDockHost[AId].Height;
  if AWidth < 280 then AWidth := 420;
  if AHeight < 200 then AHeight := 480;
  ALeft := FMainForm.Left + FMainForm.Width + 12;
  ATop := FMainForm.Top;
  Result := True;
end;

procedure TPanelDetachManager.EnsureFloatForm(AId: TPanelId);
var
  FF: TForm;
begin
  if Assigned(FFloatForm[AId]) then Exit;
  FF := TForm.CreateNew(FOwner);
  FF.Caption := PanelCaption(AId);
  FF.Position := poDesigned;
  FF.Tag := Ord(AId);
  FF.OnClose := @FloatFormClose;
  FF.OnResize := @FloatFormBoundsChanged;
  FFloatForm[AId] := FF;
end;

procedure TPanelDetachManager.FloatFormBoundsChanged(Sender: TObject);
var
  FF: TForm;
  Id: TPanelId;
begin
  if not (Sender is TForm) then Exit;
  FF := TForm(Sender);
  Id := TPanelId(FF.Tag);
  if Id = piTerminal then Exit;
  FState.SetPanelBounds(Id, FF.Left, FF.Top, FF.Width, FF.Height);
end;

procedure TPanelDetachManager.FloatFormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Id: TPanelId;
begin
  CloseAction := caHide;
  if Sender is TForm then begin
    Id := TPanelId(TForm(Sender).Tag);
    AttachPanel(Id);
  end;
end;

procedure TPanelDetachManager.DetachPanel(AId: TPanelId);
var
  L, T, W, H: Integer;
  FF: TForm;
begin
  if AId = piTerminal then Exit;
  if not FBound[AId] then Exit;
  if not FState.IsPanelVisible(AId) then
    FState.SetPanelVisible(AId, True);

  EnsureFloatForm(AId);
  FF := FFloatForm[AId];

  if not FState.GetPanelBounds(AId, L, T, W, H) or (W < 200) or (H < 120) then
    DefaultFloatBounds(AId, L, T, W, H);
  FF.SetBounds(L, T, W, H);

  FContent[AId].DisableAlign;
  try
    FContent[AId].Parent := FF;
    FContent[AId].Align := alClient;
  finally
    FContent[AId].EnableAlign;
  end;

  FState.SetPanelFloating(AId, True);
  FF.Show;
  ApplyLayout;
end;

procedure TPanelDetachManager.AttachPanel(AId: TPanelId);
var
  FF: TForm;
begin
  if AId = piTerminal then Exit;
  if not FBound[AId] then Exit;
  if not Assigned(FMainForm) or (csDestroying in FMainForm.ComponentState) then Exit;
  if not FState.IsPanelFloating(AId) then Exit;

  FF := FFloatForm[AId];
  if Assigned(FF) then
    FF.Hide;

  FContent[AId].DisableAlign;
  try
    FContent[AId].Parent := FDockHost[AId];
    FContent[AId].Align := alClient;
  finally
    FContent[AId].EnableAlign;
  end;

  FState.SetPanelFloating(AId, False);
  ApplyLayout;
end;

procedure TPanelDetachManager.ToggleDetach(AId: TPanelId);
begin
  if AId = piTerminal then Exit;
  if FState.IsPanelFloating(AId) then
    AttachPanel(AId)
  else
    DetachPanel(AId);
end;

procedure TPanelDetachManager.ApplyLayout;
var
  P: TPanelId;
  FF: TForm;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    if P = piTerminal then Continue;
    if not FBound[P] then Continue;

    if FState.IsPanelVisible(P) and FState.IsPanelFloating(P) then begin
      FDockHost[P].Visible := False;
      FF := FFloatForm[P];
      if Assigned(FF) then
        FF.Visible := True;
    end else begin
      if FState.IsPanelFloating(P) then
        AttachPanel(P);
      FF := FFloatForm[P];
      if Assigned(FF) then
        FF.Visible := False;
    end;
  end;
end;

procedure TPanelDetachManager.ApplyThemes(ATheme: TThemeKind);
var
  P: TPanelId;
  FF: TForm;
  Pal: TThemePalette;
begin
  Pal := ThemePalette(ATheme);
  for P := Low(TPanelId) to High(TPanelId) do begin
    if P = piTerminal then Continue;
    FF := FFloatForm[P];
    if not Assigned(FF) then Continue;
    FF.Color := Pal.Background;
    FF.Font.Color := Pal.Text;
    ApplyControlTheme(FF, ATheme);
  end;
end;

procedure TPanelDetachManager.RaiseFloatingForms;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    if P = piTerminal then Continue;
    if not FBound[P] then Continue;
    if FState.IsPanelVisible(P) and FState.IsPanelFloating(P) then
      DetachPanel(P);
  end;
end;

procedure TPanelDetachManager.AttachAll;
var
  P: TPanelId;
begin
  if not Assigned(FMainForm) or (csDestroying in FMainForm.ComponentState) then Exit;
  for P := Low(TPanelId) to High(TPanelId) do
    if FState.IsPanelFloating(P) then
      AttachPanel(P);
end;

procedure TPanelDetachManager.FinalizeOnClose;
var
  P: TPanelId;
begin
  AttachAll;
  for P := Low(TPanelId) to High(TPanelId) do
    FreeAndNil(FFloatForm[P]);
end;

end.
