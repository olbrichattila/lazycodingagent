unit uUtilityPlanTab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics,
  uAppTypes, uTheme, uThemedButton, uMarkdownView;

type
  TPlanBuildEvent = procedure(Sender: TObject; const APlanPath, APlanContent: string) of object;

  { TUtilityPlanTab — plan markdown viewer with Build action for Utility Panel tabs }
  TUtilityPlanTab = class(TPanel)
  private
    FLblPath: TLabel;
    FPnlBottom: TPanel;
    FMarkdown: TMarkdownView;
    FBuildBtn: TThemedButton;
    FPlanPath: string;
    FPlanContent: string;
    FOnBuild: TPlanBuildEvent;
    procedure BuildClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadPlan(const APath, AContent: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    property PlanPath: string read FPlanPath;
    property PlanContent: string read FPlanContent;
    property OnBuild: TPlanBuildEvent read FOnBuild write FOnBuild;
  end;

implementation

constructor TUtilityPlanTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;

  FLblPath := TLabel.Create(Self);
  FLblPath.Parent := Self;
  FLblPath.Align := alTop;
  FLblPath.AutoSize := False;
  FLblPath.Height := 24;
  FLblPath.Caption := 'Plan file:';
  FLblPath.Layout := tlCenter;

  FPnlBottom := TPanel.Create(Self);
  FPnlBottom.Parent := Self;
  FPnlBottom.Align := alBottom;
  FPnlBottom.Height := 48;
  FPnlBottom.BevelOuter := bvNone;

  FBuildBtn := TThemedButton.Create(FPnlBottom);
  FBuildBtn.Parent := FPnlBottom;
  FBuildBtn.Caption := 'Build';
  FBuildBtn.Align := alRight;
  FBuildBtn.Width := 112;
  FBuildBtn.Height := 32;
  FBuildBtn.OnClick := @BuildClick;

  FMarkdown := TMarkdownView.Create(Self);
  FMarkdown.Parent := Self;
  FMarkdown.Align := alClient;
end;

procedure TUtilityPlanTab.LoadPlan(const APath, AContent: string);
begin
  FPlanPath := APath;
  FPlanContent := AContent;
  FLblPath.Caption := 'Plan file: ' + APath;
  FLblPath.Hint := APath;
  FLblPath.ShowHint := True;
  FMarkdown.SetMarkdown(AContent);
end;

procedure TUtilityPlanTab.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  Color := P.Surface;
  FLblPath.Font.Color := P.TextMuted;
  FPnlBottom.Color := P.Surface;
  FBuildBtn.ApplyTheme(ATheme);
  FMarkdown.ApplyTheme(ATheme);
end;

procedure TUtilityPlanTab.BuildClick(Sender: TObject);
begin
  if Assigned(FOnBuild) then
    FOnBuild(Self, FPlanPath, FPlanContent);
end;

end.
