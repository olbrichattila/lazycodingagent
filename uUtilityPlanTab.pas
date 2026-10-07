unit uUtilityPlanTab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics,
  uAppTypes, uTheme, uThemedButton, uMarkdownView, uWorkspaceState;

type
  TPlanBuildEvent = procedure(Sender: TObject; const APlanPath, APlanContent,
    AModelId: string) of object;

  { TUtilityPlanTab — plan markdown viewer with Build action for Utility Panel tabs }
  TUtilityPlanTab = class(TPanel)
  private
    FTheme: TThemeKind;
    FPnlHeader: TPanel;
    FLblPath: TLabel;
    FModelCombo: TComboBox;
    FModelIds: TStringList;
    FModel: string;
    FBuildBtn: TThemedButton;
    FMarkdown: TMarkdownView;
    FPlanPath: string;
    FPlanContent: string;
    FOnBuild: TPlanBuildEvent;
    FUpdatingLayout: Boolean;
    procedure BuildClick(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadPlan(const APath, AContent: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetAvailableModels(const AModels: array of TSavedModel);
    procedure SetModel(const AModel: string);
    function SelectedModelId: string;
    property PlanPath: string read FPlanPath;
    property PlanContent: string read FPlanContent;
    property OnBuild: TPlanBuildEvent read FOnBuild write FOnBuild;
  end;

implementation

const
  PlanHeaderHeight = 36;
  PlanBuildBtnWidth = 72;
  PlanBuildBtnHeight = 24;
  PlanModelComboWidth = 210;
  PlanHeaderPad = 8;
  PlanHeaderGap = 8;

procedure SetBoundsIfChanged(AControl: TControl; AL, AT, AW, AH: Integer);
begin
  if not Assigned(AControl) then Exit;
  if (AControl.Left = AL) and (AControl.Top = AT) and
     (AControl.Width = AW) and (AControl.Height = AH) then Exit;
  AControl.SetBounds(AL, AT, AW, AH);
end;

function ModelComboCaption(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName
  else
    Result := M.ModelId;
end;

constructor TUtilityPlanTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FTheme := tkDark;
  FModel := '';
  FUpdatingLayout := False;
  FModelIds := TStringList.Create;

  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := Self;
  FPnlHeader.Align := alTop;
  FPnlHeader.Height := PlanHeaderHeight;
  FPnlHeader.BevelOuter := bvNone;

  FLblPath := TLabel.Create(FPnlHeader);
  FLblPath.Parent := FPnlHeader;
  FLblPath.AutoSize := False;
  FLblPath.Alignment := taLeftJustify;
  FLblPath.Layout := tlCenter;
  FLblPath.Caption := 'Plan file:';

  FModelCombo := TComboBox.Create(FPnlHeader);
  FModelCombo.Parent := FPnlHeader;
  FModelCombo.Style := csOwnerDrawFixed;
  FModelCombo.OnDrawItem := @ComboDrawItem;
  FModelCombo.ItemHeight := ThemedComboBoxItemHeight;
  FModelCombo.OnChange := @ModelComboChange;

  FBuildBtn := TThemedButton.Create(FPnlHeader);
  FBuildBtn.Parent := FPnlHeader;
  FBuildBtn.Caption := 'Build';
  FBuildBtn.OnClick := @BuildClick;

  FMarkdown := TMarkdownView.Create(Self);
  FMarkdown.Parent := Self;
  FMarkdown.Align := alClient;

  ApplyTheme(FTheme);
  UpdateLayout;
end;

destructor TUtilityPlanTab.Destroy;
begin
  FModelIds.Free;
  inherited Destroy;
end;

procedure TUtilityPlanTab.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TUtilityPlanTab.UpdateLayout;
var
  W, ComboH, BtnTop, RightX, LabelW: Integer;
begin
  if FUpdatingLayout then Exit;
  if not Assigned(FPnlHeader) then Exit;
  FUpdatingLayout := True;
  try
    W := FPnlHeader.ClientWidth;
    ComboH := EffectiveThemedComboBoxHeight(FModelCombo);
    BtnTop := (PlanHeaderHeight - PlanBuildBtnHeight) div 2;
    if BtnTop < 0 then BtnTop := 0;

    RightX := W - PlanHeaderPad;
    SetBoundsIfChanged(FBuildBtn, RightX - PlanBuildBtnWidth, BtnTop,
      PlanBuildBtnWidth, PlanBuildBtnHeight);
    RightX := FBuildBtn.Left - PlanHeaderGap;

    SetBoundsIfChanged(FModelCombo, RightX - PlanModelComboWidth,
      (PlanHeaderHeight - ComboH) div 2, PlanModelComboWidth, ComboH);
    RightX := FModelCombo.Left - PlanHeaderGap;

    LabelW := RightX - PlanHeaderPad;
    if LabelW < 40 then LabelW := 40;
    SetBoundsIfChanged(FLblPath, PlanHeaderPad, 0, LabelW, PlanHeaderHeight);
  finally
    FUpdatingLayout := False;
  end;
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

procedure TUtilityPlanTab.SetAvailableModels(const AModels: array of TSavedModel);
var
  I, SelIdx: Integer;
  Cap: string;
begin
  FModelCombo.Items.BeginUpdate;
  FModelIds.BeginUpdate;
  try
    FModelCombo.Items.Clear;
    FModelIds.Clear;
    SelIdx := -1;
    for I := 0 to High(AModels) do begin
      Cap := ModelComboCaption(AModels[I]);
      FModelCombo.Items.Add(Cap);
      FModelIds.Add(AModels[I].ModelId);
      if SameText(AModels[I].ModelId, FModel) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      FModelCombo.ItemIndex := SelIdx
    else if FModelCombo.Items.Count > 0 then begin
      FModelCombo.ItemIndex := 0;
      FModel := FModelIds[0];
    end else
      FModel := '';
  finally
    FModelIds.EndUpdate;
    FModelCombo.Items.EndUpdate;
  end;
end;

procedure TUtilityPlanTab.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Idx >= 0 then
    FModelCombo.ItemIndex := Idx;
end;

function TUtilityPlanTab.SelectedModelId: string;
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    Result := FModelIds[Idx]
  else
    Result := FModel;
end;

procedure TUtilityPlanTab.ModelComboChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    FModel := FModelIds[Idx]
  else
    FModel := '';
end;

procedure TUtilityPlanTab.ComboDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  StyleComboBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TUtilityPlanTab.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Surface;
  FPnlHeader.Color := P.Surface;
  FLblPath.Font.Color := P.TextMuted;
  StyleComboBox(FModelCombo, ATheme);
  FBuildBtn.ApplyTheme(ATheme);
  FMarkdown.ApplyTheme(ATheme);
  UpdateLayout;
end;

procedure TUtilityPlanTab.BuildClick(Sender: TObject);
var
  ModelId: string;
begin
  if not Assigned(FOnBuild) then Exit;
  ModelId := SelectedModelId;
  if ModelId = '' then Exit;
  FOnBuild(Self, FPlanPath, FPlanContent, ModelId);
end;

end.
