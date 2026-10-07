unit uUtilityExecutionDetailTab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, uAppTypes, uTheme, uAgentExecutionLog;

type
  { Read-only inspector for a single execution log entry }
  TUtilityExecutionDetailTab = class(TPanel)
  private
    FTheme: TThemeKind;
    FMemo: TMemo;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ShowEntry(AEntry: TExecutionLogEntry);
    procedure ClearDetail;
  end;

implementation

constructor TUtilityExecutionDetailTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FTheme := tkDark;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.BorderStyle := bsNone;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoBoth;
  FMemo.WordWrap := False;
end;

procedure TUtilityExecutionDetailTab.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.Surface;
  ConfigureThemedMemo(FMemo, FTheme, 'Consolas');
end;

procedure TUtilityExecutionDetailTab.ShowEntry(AEntry: TExecutionLogEntry);
begin
  if not Assigned(AEntry) then begin
    ClearDetail;
    Exit;
  end;
  FMemo.Lines.Text := AEntry.BuildInspectorText;
end;

procedure TUtilityExecutionDetailTab.ClearDetail;
begin
  FMemo.Clear;
end;

end.
