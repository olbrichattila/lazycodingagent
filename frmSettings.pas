unit frmSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls, LCLType, LcaThemedButton, LcaThemedComboBox,
  uAppTypes, uAgentTypes, LcaTheme, uWorkspaceState, uWorkspaceRegistry,
  
  uLlmClient, frmModelSearch, frmEditSavedModel;

type
  { TSettingsForm }
  TSettingsForm = class(TForm)
    pnlBottom: TPanel;
    btnOK: TLcaThemedButton;
    btnCancel: TLcaThemedButton;
    pnlSettingsTabsHost: TPanel;
    pgcSettings: TPageControl;
    tsProvider: TTabSheet;
    pnlTabProvider: TPanel;
    tsAgent: TTabSheet;
    pnlTabAgent: TPanel;
    tsWorkspace: TTabSheet;
    pnlTabWorkspace: TPanel;

    lblProvider: TLabel;
    cboProvider: TLcaThemedComboBox;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    lblModels: TLabel;
    lstModels: TListBox;
    btnFetchModels: TLcaThemedButton;
    btnEditModel: TLcaThemedButton;
    btnDeleteModel: TLcaThemedButton;
    lblNotice: TLabel;

    lblTemp: TLabel;
    edtTemp: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblMaxSteps: TLabel;
    edtMaxSteps: TEdit;
    chkDebuggingMode: TCheckBox;
    lblDebuggingHint: TLabel;

    lblWorkspaceRoot: TLabel;
    edtWorkspaceRoot: TEdit;
    btnBrowseWorkspace: TLcaThemedButton;
    lblWorkspaceName: TLabel;
    edtWorkspaceName: TEdit;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure cboProviderChange(Sender: TObject);
    procedure lstModelsClick(Sender: TObject);
    procedure lstModelsDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure btnFetchModelsClick(Sender: TObject);
    procedure btnEditModelClick(Sender: TObject);
    procedure btnDeleteModelClick(Sender: TObject);
    procedure btnBrowseWorkspaceClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FState: TWorkspaceState;
    FRegistry: TWorkspaceRegistry;
    FCurrentTheme: TThemeKind;
    FDialogProvider: TLlmProvider;
    FDefaultModelId: string;
    FSwitchingProvider: Boolean;
    function CurrentDialogProvider: TLlmProvider;
    function SavedModelLine(const M: TSavedModel): string;
    procedure LoadFromState;
    procedure SaveToState;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure FlushCredentialsToState(AProv: TLlmProvider);
    procedure LoadProviderTab(AProv: TLlmProvider);
    procedure RefreshModelList;
    procedure ModelSearchAdd(Sender: TObject; const AModelId, ADisplayName: string);
  public
    class function Execute(AState: TWorkspaceState; ARegistry: TWorkspaceRegistry = nil): Boolean;
  end;

implementation

{$R *.lfm}

function TSettingsForm.CurrentDialogProvider: TLlmProvider;
begin
  Result := TLlmProvider(cboProvider.ItemIndex);
end;

function TSettingsForm.SavedModelLine(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName + ' — ' + M.ModelId
  else
    Result := M.ModelId;
end;

class function TSettingsForm.Execute(AState: TWorkspaceState; ARegistry: TWorkspaceRegistry): Boolean;
var
  Dlg: TSettingsForm;
begin
  Dlg := TSettingsForm.Create(nil);
  try
    Dlg.FState := AState;
    Dlg.FRegistry := ARegistry;
    Dlg.LoadFromState;
    Dlg.ApplyTheme(AState.Theme);
    Result := (Dlg.ShowModal = mrOk);
    if Result then begin
      Dlg.SaveToState;
      AState.Save;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TSettingsForm.FormShow(Sender: TObject);
begin
  ApplyFormPlatformThemes(Self, FCurrentTheme);
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  Caption := 'LazyCodingAgent Settings';
  FCurrentTheme := tkDark;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TSettingsForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    btnCancelClick(Self);
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    if not (ActiveControl is TComboBox) then begin
      Key := 0;
      btnOKClick(Self);
    end;
  end;
end;

procedure TSettingsForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FCurrentTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  pnlBottom.Color := P.Surface;

  ApplyThemedForm(Self, ATheme);
  pnlBottom.Color := P.Surface;

  edtApiKey.Color := P.SurfaceAlt;
  edtApiKey.Font.Color := P.Text;
  edtBaseUrl.Color := P.SurfaceAlt;
  edtBaseUrl.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
  ApplyPlatformScrollableThemeRecursive(Self, ATheme);
  ConfigureThemedListBox(lstModels, ATheme);
  lstModels.OnDrawItem := @lstModelsDrawItem;
  lstModels.Invalidate;

  edtTemp.Color := P.SurfaceAlt;
  edtTemp.Font.Color := P.Text;
  edtMaxTokens.Color := P.SurfaceAlt;
  edtMaxTokens.Font.Color := P.Text;
  edtMaxSteps.Color := P.SurfaceAlt;
  edtMaxSteps.Font.Color := P.Text;

  edtWorkspaceRoot.Color := P.SurfaceAlt;
  edtWorkspaceRoot.Font.Color := P.Text;
  edtWorkspaceName.Color := P.SurfaceAlt;
  edtWorkspaceName.Font.Color := P.Text;

  if Assigned(lblNotice) then
    lblNotice.Font.Color := P.TextMuted;
  if Assigned(lblDebuggingHint) then
    lblDebuggingHint.Font.Color := P.TextMuted;

  Invalidate;
end;

procedure TSettingsForm.FlushCredentialsToState(AProv: TLlmProvider);
begin
  if not Assigned(FState) then Exit;
  FState.SetProviderCredentials(AProv, Trim(edtApiKey.Text), Trim(edtBaseUrl.Text));
end;

procedure TSettingsForm.LoadProviderTab(AProv: TLlmProvider);
var
  Key, Url: string;
begin
  if not Assigned(FState) then Exit;
  FState.GetProviderCredentials(AProv, Key, Url);
  edtApiKey.Text := Key;
  edtBaseUrl.Text := Url;
  RefreshModelList;
end;

procedure TSettingsForm.RefreshModelList;
var
  I, SelIdx: Integer;
  M: TSavedModel;
  Prov: TLlmProvider;
begin
  if not Assigned(FState) then Exit;
  Prov := CurrentDialogProvider;
  lstModels.Items.BeginUpdate;
  try
    lstModels.Items.Clear;
    SelIdx := -1;
    for I := 0 to FState.SavedModelCount(Prov) - 1 do begin
      M := FState.GetSavedModel(Prov, I);
      lstModels.Items.Add(SavedModelLine(M));
      if SameText(M.ModelId, FDefaultModelId) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      lstModels.ItemIndex := SelIdx
    else if lstModels.Items.Count > 0 then begin
      lstModels.ItemIndex := 0;
      FDefaultModelId := FState.GetSavedModel(Prov, 0).ModelId;
    end else
      FDefaultModelId := '';
  finally
    lstModels.Items.EndUpdate;
  end;
end;

procedure TSettingsForm.LoadFromState;
begin
  if not Assigned(FState) then Exit;

  FSwitchingProvider := True;
  try
    cboProvider.ItemIndex := Ord(FState.Provider);
    FDialogProvider := FState.Provider;
    FDefaultModelId := FState.Model;
    LoadProviderTab(FDialogProvider);
  finally
    FSwitchingProvider := False;
  end;

  edtTemp.Text := FloatToStr(FState.Temperature);
  edtMaxTokens.Text := IntToStr(FState.MaxTokens);
  edtMaxSteps.Text := IntToStr(FState.MaxSteps);
  chkDebuggingMode.Checked := FState.DebuggingMode;

  edtWorkspaceRoot.Text := FState.WorkspaceRoot;
  edtWorkspaceName.Text := FState.WorkspaceName;

  if Assigned(pgcSettings) then
    pgcSettings.ActivePageIndex := 0;
end;

procedure TSettingsForm.SaveToState;
var
  Prov: TLlmProvider;
begin
  if not Assigned(FState) then Exit;

  FlushCredentialsToState(FDialogProvider);

  Prov := CurrentDialogProvider;
  FState.Provider := Prov;
  FState.ActivateProvider(Prov);
  FState.CommitActiveProviderCredentials(Trim(edtApiKey.Text), Trim(edtBaseUrl.Text));
  FState.SetModel(FDefaultModelId);

  FState.Temperature := StrToFloatDef(edtTemp.Text, 0.2);
  FState.MaxTokens := StrToIntDef(edtMaxTokens.Text, 4096);
  FState.MaxSteps := StrToIntDef(edtMaxSteps.Text, 20);
  FState.DebuggingMode := chkDebuggingMode.Checked;

  FState.WorkspaceRoot := Trim(edtWorkspaceRoot.Text);
  FState.WorkspaceName := Trim(edtWorkspaceName.Text);

  if Assigned(FRegistry) and FState.HasActiveWorkspace then
    FRegistry.UpdateWorkspace(FState.ActiveWorkspaceId, FState.WorkspaceName, FState.WorkspaceRoot);
end;

procedure TSettingsForm.cboProviderChange(Sender: TObject);
var
  NewProv: TLlmProvider;
begin
  if FSwitchingProvider then Exit;
  NewProv := CurrentDialogProvider;
  if NewProv = FDialogProvider then Exit;

  FlushCredentialsToState(FDialogProvider);
  FDialogProvider := NewProv;
  LoadProviderTab(FDialogProvider);
end;

procedure TSettingsForm.lstModelsDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FCurrentTheme);
end;

procedure TSettingsForm.lstModelsClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then Exit;
  Prov := CurrentDialogProvider;
  if Idx >= FState.SavedModelCount(Prov) then Exit;
  FDefaultModelId := FState.GetSavedModel(Prov, Idx).ModelId;
end;

procedure TSettingsForm.ModelSearchAdd(Sender: TObject; const AModelId, ADisplayName: string);
var
  Prov: TLlmProvider;
begin
  Prov := CurrentDialogProvider;
  FState.AddSavedModel(Prov, AModelId, ADisplayName);
end;

procedure TSettingsForm.btnFetchModelsClick(Sender: TObject);
var
  Client: TLlmClient;
  ListResult: TLlmModelListResult;
  OldCursor: TCursor;
begin
  if not Assigned(FState) then Exit;

  FlushCredentialsToState(FDialogProvider);

  Client := TLlmClient.Create;
  try
    Client.Provider := CurrentDialogProvider;
    Client.ApiKey := Trim(edtApiKey.Text);
    Client.BaseUrl := Trim(edtBaseUrl.Text);

    OldCursor := Screen.Cursor;
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    try
      ListResult := Client.ListModels;
    finally
      Screen.Cursor := OldCursor;
    end;

    if not ListResult.Success then begin
      ShowMessage(ListResult.ErrorMessage);
      Exit;
    end;

    if Length(ListResult.Models) = 0 then begin
      ShowMessage('No models returned by the provider.');
      Exit;
    end;

    TModelSearchForm.ShowModalSearch(Self, FCurrentTheme, ListResult.Models, @ModelSearchAdd);
    RefreshModelList;
  finally
    Client.Free;
  end;
end;

procedure TSettingsForm.btnEditModelClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
  M, NewName, NewId: string;
  Cur: TSavedModel;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then begin
    ShowMessage('Select a model to edit.');
    Exit;
  end;
  Prov := CurrentDialogProvider;
  Cur := FState.GetSavedModel(Prov, Idx);
  if TEditSavedModelForm.Execute(Self, FCurrentTheme, Cur.DisplayName, Cur.ModelId, M, NewId) then begin
    if not FState.UpdateSavedModel(Prov, Idx, NewId, M) then begin
      ShowMessage('Could not update model. The model id may already exist in this provider list.');
      Exit;
    end;
    if SameText(FDefaultModelId, Cur.ModelId) then
      FDefaultModelId := NewId;
    RefreshModelList;
  end;
end;

procedure TSettingsForm.btnDeleteModelClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
  DelId: string;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then begin
    ShowMessage('Select a model to delete.');
    Exit;
  end;
  Prov := CurrentDialogProvider;
  DelId := FState.GetSavedModel(Prov, Idx).ModelId;
  if MessageDlg('Remove this model from your saved list?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FState.DeleteSavedModel(Prov, Idx);
  if SameText(FDefaultModelId, DelId) then begin
    if FState.SavedModelCount(Prov) > 0 then
      FDefaultModelId := FState.GetSavedModel(Prov, 0).ModelId
    else
      FDefaultModelId := '';
  end;
  RefreshModelList;
end;

procedure TSettingsForm.btnBrowseWorkspaceClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtWorkspaceRoot.Text;
  if SelectDirectory('Select Workspace Directory', '', Dir) then begin
    edtWorkspaceRoot.Text := Dir;
    if edtWorkspaceName.Text = '' then
      edtWorkspaceName.Text := ExtractFileName(Dir);
  end;
end;

procedure TSettingsForm.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TSettingsForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
