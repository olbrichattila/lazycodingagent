unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs, Forms,
  LCLType, fpjson, jsonparser,
  uAppTypes, LcaTheme, LcaThemedButton, LcaThemedComboBox, uAgentTypes, uWorkspaceState,
  LcaMarkdownView;

type
  TPromptEvent = procedure(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode;
    const AModel: string) of object;
  TModeChangeEvent = procedure(Sender: TObject; AMode: TWorkspaceMode) of object;
  TModelChangeEvent = procedure(Sender: TObject; const AModel: string) of object;
  TCancelEvent = procedure(Sender: TObject) of object;

  { Binds designer-placed chat controls; Markdown subset in TLcaMarkdownView on host panel. }
  TChatPanel = class(TComponent)
  private
    FWorkspaceName: string;
    FTheme: TThemeKind;
    FMode: TWorkspaceMode;
    FModel: string;
    FIsRunning: Boolean;
    FHistoryText: string;

    FOnPrompt: TPromptEvent;
    FOnModeChange: TModeChangeEvent;
    FOnModelChange: TModelChangeEvent;
    FOnCancel: TCancelEvent;

    FHeading: TLabel;
    FSubHeading: TLabel;
    FSessionLabel: TLabel;
    FHistoryHost: TPanel;
    FHistoryView: TLcaMarkdownView;
    FWorkspaceTag: TLabel;
    FPromptMemo: TMemo;
    FModeCombo: TLcaThemedComboBox;
    FModelCombo: TLcaThemedComboBox;
    FModelIds: TStringList;
    FSendBtn: TLcaThemedButton;
    FStopBtn: TLcaThemedButton;

    procedure ModeComboChange(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure SendBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure UpdateHeading;
    procedure UpdateSessionLabel(const ACaption: string);
    procedure InitWelcomeText;
    procedure EnsureHistoryView;
    procedure AppendToHistory(const ARoleLabel, ABody: string);
    procedure RefreshHistoryView;
    function ToolMessageBody(const AMsg: TChatMessage): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(AHeading, ASubHeading, ASessionLabel: TLabel; AHistoryHost: TPanel;
      APrompt: TMemo; AWorkspaceTag: TLabel; AModeCombo, AModelCombo: TLcaThemedComboBox;
      ASendBtn, AStopBtn: TLcaThemedButton);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure SetWorkspace(const AName: string);
    procedure SetSessionCaption(const ACaption: string);
    procedure SetMode(AMode: TWorkspaceMode);
    procedure SetModel(const AModel: string);
    procedure SetAvailableModels(const AModels: array of TSavedModel);
    procedure SetRunning(ARunning: Boolean);

    procedure AppendMessage(const AMsg: TChatMessage);
    procedure AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
    procedure AppendText(const AText: string);
    procedure AppendTraceLine(const AText: string);
    procedure ClearHistory;
    procedure ReloadFromMessages(const AMessages: TChatMessageArray; ADebuggingMode: Boolean);
    procedure SetComposerEnabled(AEnabled: Boolean);
    procedure SubmitPrompt(const APrompt: string);

    property Mode: TWorkspaceMode read FMode write SetMode;
    property Model: string read FModel write SetModel;
    property IsRunning: Boolean read FIsRunning write SetRunning;
    property OnModeChange: TModeChangeEvent read FOnModeChange write FOnModeChange;
    property OnModelChange: TModelChangeEvent read FOnModelChange write FOnModelChange;
    property OnPrompt: TPromptEvent read FOnPrompt write FOnPrompt;
    property OnCancel: TCancelEvent read FOnCancel write FOnCancel;
  end;

implementation

const
  MaxToolBodyInChat = 1200;

function ExtractToolErrorLine(const AJson: string): string;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := '';
  try
    Data := GetJSON(AJson);
    try
      if Data is TJSONObject then begin
        Obj := TJSONObject(Data);
        Result := Obj.Get('error', '');
        if Result = '' then
          Result := Obj.Get('message', '');
      end;
    finally
      Data.Free;
    end;
  except
    Result := '';
  end;
end;

function ModelComboCaption(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName
  else
    Result := M.ModelId;
end;

constructor TChatPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FWorkspaceName := 'LazyCodingAgent';
  FMode := wmAgent;
  FModel := '';
  FModelIds := TStringList.Create;
  InitWelcomeText;
end;

destructor TChatPanel.Destroy;
begin
  FHistoryView := nil;
  FModelIds.Free;
  inherited Destroy;
end;

procedure TChatPanel.EnsureHistoryView;
var
  I: Integer;
  C: TControl;
begin
  if Assigned(FHistoryView) then Exit;
  if not Assigned(FHistoryHost) then Exit;
  for I := 0 to FHistoryHost.ControlCount - 1 do begin
    C := FHistoryHost.Controls[I];
    if C is TLcaMarkdownView then begin
      FHistoryView := TLcaMarkdownView(C);
      Exit;
    end;
  end;
end;

procedure TChatPanel.Bind(AHeading, ASubHeading, ASessionLabel: TLabel; AHistoryHost: TPanel;
  APrompt: TMemo; AWorkspaceTag: TLabel; AModeCombo, AModelCombo: TLcaThemedComboBox;
  ASendBtn, AStopBtn: TLcaThemedButton);
var
  M: TWorkspaceMode;
begin
  FHeading := AHeading;
  FSubHeading := ASubHeading;
  FSessionLabel := ASessionLabel;
  FHistoryHost := AHistoryHost;
  FPromptMemo := APrompt;
  FWorkspaceTag := AWorkspaceTag;
  FModeCombo := AModeCombo;
  FModelCombo := AModelCombo;
  FSendBtn := ASendBtn;
  FStopBtn := AStopBtn;

  EnsureHistoryView;

  if Assigned(FModeCombo) then begin
    FModeCombo.Items.Clear;
    for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
      FModeCombo.Items.Add(WorkspaceModeCaption(M));
    FModeCombo.ItemIndex := Ord(FMode);
    FModeCombo.OnChange := @ModeComboChange;
    FModeCombo.Style := csDropDownList;
  end;
  if Assigned(FModelCombo) then begin
    FModelCombo.OnChange := @ModelComboChange;
    FModelCombo.Style := csDropDownList;
  end;
  if Assigned(FSendBtn) then
    FSendBtn.OnClick := @SendBtnClick;
  if Assigned(FStopBtn) then begin
    FStopBtn.OnClick := @StopBtnClick;
    FStopBtn.Visible := False;
  end;
  if Assigned(FPromptMemo) then
    FPromptMemo.OnKeyDown := nil;

  UpdateHeading;
  RefreshHistoryView;
end;

procedure TChatPanel.InitWelcomeText;
begin
  FHistoryText :=
    '# Welcome to LazyCodingAgent!' + LineEnding + LineEnding +
    'Type a prompt below or pick a mode (Ask, Plan, Agent) to start building.';
end;

procedure TChatPanel.UpdateHeading;
begin
  if Assigned(FHeading) then
    FHeading.Caption := Format('What should we build in %s?', [FWorkspaceName]);
  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.Caption := Format('PROJECT: %s  •  MODE: %s', [FWorkspaceName, WorkspaceModeCaption(FMode)]);
end;

procedure TChatPanel.UpdateSessionLabel(const ACaption: string);
begin
  if Assigned(FSessionLabel) then
    FSessionLabel.Caption := ACaption;
end;

procedure TChatPanel.SetSessionCaption(const ACaption: string);
begin
  UpdateSessionLabel(ACaption);
end;

procedure TChatPanel.SetRunning(ARunning: Boolean);
begin
  FIsRunning := ARunning;
  if Assigned(FStopBtn) then
    FStopBtn.Visible := ARunning;
  if Assigned(FSendBtn) then
    FSendBtn.Enabled := not ARunning;
  SetComposerEnabled(FPromptMemo.Enabled);
end;

procedure TChatPanel.RefreshHistoryView;
begin
  EnsureHistoryView;
  if Assigned(FHistoryView) then
    FHistoryView.SetMarkdown(FHistoryText);
end;

procedure TChatPanel.AppendToHistory(const ARoleLabel, ABody: string);
begin
  if Trim(ABody) = '' then Exit;
  if FHistoryText <> '' then
    FHistoryText := FHistoryText + LineEnding + LineEnding;
  FHistoryText := FHistoryText + '### ' + ARoleLabel + LineEnding + LineEnding + ABody;
  RefreshHistoryView;
end;

function TChatPanel.ToolMessageBody(const AMsg: TChatMessage): string;
var
  ErrLine: string;
  ResultText: string;
begin
  ResultText := Trim(AMsg.Content);
  if (Length(ResultText) > MaxToolBodyInChat) or
     ((Length(ResultText) > 80) and (Pos('"error"', LowerCase(ResultText)) > 0)) then begin
    ErrLine := ExtractToolErrorLine(ResultText);
    if ErrLine <> '' then
      Result := ErrLine
    else if Length(ResultText) > MaxToolBodyInChat then
      Result := Copy(ResultText, 1, MaxToolBodyInChat) + '…'
    else if AMsg.VisualSummary <> '' then
      Result := AMsg.VisualSummary
    else
      Result := ResultText;
  end else
    Result := ResultText;
end;

procedure TChatPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  if Assigned(FHeading) then
    FHeading.Font.Color := P.Text;
  if Assigned(FSubHeading) then
    FSubHeading.Font.Color := P.TextMuted;
  if Assigned(FSessionLabel) then
    FSessionLabel.Font.Color := P.TextMuted;
  EnsureHistoryView;
  if Assigned(FHistoryView) then
    FHistoryView.ApplyTheme(ATheme);
  if Assigned(FHistoryHost) then
    FHistoryHost.Color := P.Surface;
  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.Font.Color := P.Accent;
  if Assigned(FPromptMemo) then
    ConfigureThemedMemo(FPromptMemo, ATheme);
  if Assigned(FModeCombo) then
    FModeCombo.ApplyTheme(ATheme);
  if Assigned(FModelCombo) then
    FModelCombo.ApplyTheme(ATheme);
  if Assigned(FSendBtn) then
    FSendBtn.ApplyTheme(ATheme);
  if Assigned(FStopBtn) then
    FStopBtn.ApplyTheme(ATheme);
  RefreshHistoryView;
end;

procedure TChatPanel.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  if Assigned(FPromptMemo) then
    ApplyPlatformScrollableTheme(FPromptMemo, ATheme);
end;

procedure TChatPanel.SetWorkspace(const AName: string);
begin
  FWorkspaceName := AName;
  UpdateHeading;
end;

procedure TChatPanel.SetMode(AMode: TWorkspaceMode);
begin
  FMode := AMode;
  if Assigned(FModeCombo) then
    FModeCombo.ItemIndex := Ord(AMode);
  UpdateHeading;
  if Assigned(FSendBtn) then
    case FMode of
      wmAsk: FSendBtn.Caption := 'Ask Question';
      wmPlan: FSendBtn.Caption := 'Create Plan';
      wmAgent: FSendBtn.Caption := 'Run Agent';
    end;
end;

procedure TChatPanel.SetAvailableModels(const AModels: array of TSavedModel);
var
  I, SelIdx: Integer;
  Cap: string;
begin
  if not Assigned(FModelCombo) then Exit;
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
    end else begin
      FModelCombo.ItemIndex := -1;
      FModel := '';
    end;
  finally
    FModelIds.EndUpdate;
    FModelCombo.Items.EndUpdate;
  end;
end;

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Assigned(FModelCombo) then begin
    if Idx >= 0 then
      FModelCombo.ItemIndex := Idx
    else if FModel = '' then
      FModelCombo.ItemIndex := -1;
  end;
end;

procedure TChatPanel.ClearHistory;
begin
  FHistoryText := '';
  InitWelcomeText;
  RefreshHistoryView;
end;

procedure TChatPanel.AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
var
  RoleLabel, Body: string;
begin
  if ADebuggingMode then begin
    if AMsg.VisualSummary <> '' then
      RoleLabel := 'Tool Result [' + AMsg.VisualSummary + ']'
    else
      RoleLabel := 'Tool Result';
    Body := Trim(AMsg.Content);
    if Body = '' then Exit;
    AppendToHistory(RoleLabel, Body);
    Exit;
  end;

  if Pos('"error"', LowerCase(AMsg.Content)) = 0 then
    Exit;

  if AMsg.VisualSummary <> '' then
    RoleLabel := 'Tool Error [' + AMsg.VisualSummary + ']'
  else
    RoleLabel := 'Tool Error';
  Body := ToolMessageBody(AMsg);
  if Trim(Body) = '' then Exit;
  AppendToHistory(RoleLabel, Body);
end;

procedure TChatPanel.AppendMessage(const AMsg: TChatMessage);
var
  RoleLabel, Body: string;
begin
  if AMsg.Role = crSystem then
    Exit;

  case AMsg.Role of
    crUser:
      begin
        RoleLabel := 'You';
        Body := AMsg.Content;
      end;
    crAssistant:
      begin
        RoleLabel := 'Agent';
        Body := AMsg.Content;
      end;
    crTool:
      begin
        if AMsg.VisualSummary <> '' then
          RoleLabel := 'Tool [' + AMsg.VisualSummary + ']'
        else
          RoleLabel := 'Tool';
        Body := ToolMessageBody(AMsg);
      end;
  else
    Body := AMsg.Content;
    RoleLabel := 'Message';
  end;
  AppendToHistory(RoleLabel, Body);
end;

procedure TChatPanel.AppendTraceLine(const AText: string);
begin
  if Trim(AText) = '' then Exit;
  AppendToHistory('Activity', AText);
end;

procedure TChatPanel.AppendText(const AText: string);
begin
  if Trim(AText) = '' then Exit;
  if FHistoryText <> '' then
    FHistoryText := FHistoryText + LineEnding + LineEnding;
  FHistoryText := FHistoryText + AText;
  RefreshHistoryView;
end;

procedure TChatPanel.ModeComboChange(Sender: TObject);
begin
  if not Assigned(FModeCombo) then Exit;
  if (FModeCombo.ItemIndex < Ord(Low(TWorkspaceMode))) or
     (FModeCombo.ItemIndex > Ord(High(TWorkspaceMode))) then
    Exit;
  FMode := TWorkspaceMode(FModeCombo.ItemIndex);
  UpdateHeading;
  if Assigned(FOnModeChange) then
    FOnModeChange(Self, FMode);
end;

procedure TChatPanel.ModelComboChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    FModel := FModelIds[Idx]
  else
    FModel := '';
  if Assigned(FOnModelChange) then
    FOnModelChange(Self, FModel);
end;

procedure TChatPanel.SetComposerEnabled(AEnabled: Boolean);
begin
  if Assigned(FPromptMemo) then
    FPromptMemo.Enabled := AEnabled;
  if Assigned(FModeCombo) then
    FModeCombo.Enabled := AEnabled;
  if Assigned(FModelCombo) then
    FModelCombo.Enabled := AEnabled;
  if Assigned(FSendBtn) then
    FSendBtn.Enabled := AEnabled and not FIsRunning;
end;

procedure TChatPanel.ReloadFromMessages(const AMessages: TChatMessageArray; ADebuggingMode: Boolean);
var
  I: Integer;
begin
  FHistoryText := '';
  for I := 0 to High(AMessages) do begin
    if AMessages[I].Role = crTool then
      AppendToolMessage(AMessages[I], ADebuggingMode)
    else
      AppendMessage(AMessages[I]);
  end;
  if FHistoryText = '' then
    InitWelcomeText;
  RefreshHistoryView;
end;

procedure TChatPanel.SubmitPrompt(const APrompt: string);
begin
  if Trim(APrompt) = '' then Exit;
  if FIsRunning then Exit;
  if Assigned(FPromptMemo) and not FPromptMemo.Enabled then Exit;
  if Assigned(FOnPrompt) then
    FOnPrompt(Self, Trim(APrompt), FMode, FModel);
end;

procedure TChatPanel.SendBtnClick(Sender: TObject);
var
  Prompt: string;
begin
  if not Assigned(FPromptMemo) then Exit;
  Prompt := Trim(FPromptMemo.Text);
  if Prompt = '' then Exit;
  FPromptMemo.Text := '';
  SubmitPrompt(Prompt);
end;

procedure TChatPanel.StopBtnClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

end.
