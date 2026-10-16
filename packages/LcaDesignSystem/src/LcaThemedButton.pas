unit LcaThemedButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, StdCtrls, Controls, Forms, LcaTheme;

type
  TLcaThemedButton = class(TButton)
  private
    FThemeKind: TThemeKind;
    FButtonRole: TThemedButtonRole;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetButtonRole(AValue: TThemedButtonRole);
    function CanApplyRuntimeTheme: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property ButtonRole: TThemedButtonRole read FButtonRole write SetButtonRole default tbrCancel;
  end;

implementation

procedure TLcaThemedButton.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaThemedButton.SetButtonRole(AValue: TThemedButtonRole);
begin
  if FButtonRole = AValue then Exit;
  FButtonRole := AValue;
  ApplyTheme(FThemeKind);
end;

constructor TLcaThemedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FThemeKind := tkDark;
  FButtonRole := tbrCancel;
end;

function TLcaThemedButton.CanApplyRuntimeTheme: Boolean;
var
  F: TCustomForm;
begin
  if csDesigning in ComponentState then
    Exit(False);
  if csLoading in ComponentState then
    Exit(False);
  if csReading in ComponentState then
    Exit(False);
  F := GetParentForm(Self);
  if (F = nil) or not F.HandleAllocated then
    Exit(False);
  if not HandleAllocated then
    Exit(False);
  Result := True;
end;

procedure TLcaThemedButton.ApplyTheme(ATheme: TThemeKind);
begin
  FThemeKind := ATheme;
  if not CanApplyRuntimeTheme then
    Exit;
  StyleThemedButtonRole(Self, ATheme, FButtonRole);
end;

end.
