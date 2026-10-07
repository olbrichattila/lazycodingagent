unit frmSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, uAppTypes, uAgentTypes, uTheme, uWorkspaceState;

type
  { TSettingsForm }
  TSettingsForm = class(TForm)
    pnlBottom: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    PageControl1: TPageControl;
    tabProvider: TTabSheet;
    tabAgent: TTabSheet;
    tabWorkspace: TTabSheet;

    // Provider tab controls
    lblProvider: TLabel;
    cboProvider: TComboBox;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    lblModel: TLabel;
    edtModel: TEdit;
    lblNotice: TLabel;

    // Agent tab controls
    lblTemp: TLabel;
    edtTemp: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblMaxSteps: TLabel;
    edtMaxSteps: TEdit;

    // Workspace tab controls
    lblWorkspaceRoot: TLabel;
    edtWorkspaceRoot: TEdit;
    btnBrowseWorkspace: TButton;
    lblWorkspaceName: TLabel;
    edtWorkspaceName: TEdit;

    procedure FormCreate(Sender: TObject);
    procedure cboProviderChange(Sender: TObject);
    procedure btnBrowseWorkspaceClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FState: TWorkspaceState;
    procedure LoadFromState;
    procedure SaveToState;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AState: TWorkspaceState): Boolean;
  end;

implementation

{$R *.lfm}

{ TSettingsForm }

class function TSettingsForm.Execute(AState: TWorkspaceState): Boolean;
var
  Dlg: TSettingsForm;
begin
  Dlg := TSettingsForm.Create(Application);
  try
    Dlg.FState := AState;
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

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  Caption := 'LazyCodingAgent Settings';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Width := 560;
  Height := 460;
end;

procedure TSettingsForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlBottom.Color := P.Surface;
  PageControl1.Color := P.Background;
  tabProvider.Color := P.Background;
  tabAgent.Color := P.Background;
  tabWorkspace.Color := P.Background;
end;

procedure TSettingsForm.LoadFromState;
begin
  if not Assigned(FState) then Exit;

  cboProvider.ItemIndex := Ord(FState.Provider);
  edtApiKey.Text := FState.ApiKey;
  edtBaseUrl.Text := FState.BaseUrl;
  edtModel.Text := FState.Model;

  edtTemp.Text := FloatToStr(FState.Temperature);
  edtMaxTokens.Text := IntToStr(FState.MaxTokens);
  edtMaxSteps.Text := IntToStr(FState.MaxSteps);

  edtWorkspaceRoot.Text := FState.WorkspaceRoot;
  edtWorkspaceName.Text := FState.WorkspaceName;
end;

procedure TSettingsForm.SaveToState;
begin
  if not Assigned(FState) then Exit;

  FState.Provider := TLlmProvider(cboProvider.ItemIndex);
  FState.ApiKey := Trim(edtApiKey.Text);
  FState.BaseUrl := Trim(edtBaseUrl.Text);
  FState.SetModel(Trim(edtModel.Text));

  FState.Temperature := StrToFloatDef(edtTemp.Text, 0.2);
  FState.MaxTokens := StrToIntDef(edtMaxTokens.Text, 4096);
  FState.MaxSteps := StrToIntDef(edtMaxSteps.Text, 20);

  FState.WorkspaceRoot := Trim(edtWorkspaceRoot.Text);
  FState.WorkspaceName := Trim(edtWorkspaceName.Text);
end;

procedure TSettingsForm.cboProviderChange(Sender: TObject);
begin
  case TLlmProvider(cboProvider.ItemIndex) of
    lpOpenRouter:
      begin
        if (edtBaseUrl.Text = '') or (Pos('openai.com', edtBaseUrl.Text) > 0) or (Pos('localhost', edtBaseUrl.Text) > 0) then
          edtBaseUrl.Text := 'https://openrouter.ai/api/v1';
        if (edtModel.Text = '') or (edtModel.Text = 'gpt-4o') then
          edtModel.Text := 'anthropic/claude-3.7-sonnet';
      end;
    lpOpenAI:
      begin
        if (edtBaseUrl.Text = '') or (Pos('openrouter.ai', edtBaseUrl.Text) > 0) or (Pos('localhost', edtBaseUrl.Text) > 0) then
          edtBaseUrl.Text := 'https://api.openai.com/v1';
        if (edtModel.Text = '') or (Pos('claude', edtModel.Text) > 0) then
          edtModel.Text := 'gpt-4o';
      end;
    lpOllama:
      begin
        edtBaseUrl.Text := 'http://localhost:11434/v1';
        edtModel.Text := 'qwen2.5-coder:7b';
      end;
    lpAnthropic:
      begin
        edtBaseUrl.Text := 'https://api.anthropic.com/v1';
        edtModel.Text := 'claude-3-7-sonnet-20250219';
      end;
    lpCustom: ;
  end;
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
