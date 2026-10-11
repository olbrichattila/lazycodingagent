unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs, Forms,
  LCLType, fpjson, jsonparser,
  uAppTypes, uTheme, fraThemedButton, fraThemedPicker, uAgentTypes, uWorkspaceState,
  uMarkdownView;

type
  TPromptEvent = procedure(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string) of object;
  TModeChangeEvent = procedure(Sender: TObject; AMode: TWorkspaceMode) of object;
  TModelChangeEvent = procedure(Sender: TObject; const AModel: string) of object;
  TCancelEvent = procedure(Sender: TObject) of object;

  { TChatPanel }
  TChatPanel = class(TPanel)
  private
    FWorkspaceName: string;
    FTheme: TThemeKind;
    FMode: TWorkspaceMode;
    FModel: string;
    FIsRunning: Boolean;
    FHistoryMarkdown: string;

    FOnPrompt: TPromptEvent;
    FOnModeChange: TModeChangeEvent;
    FOnModelChange: TModelChangeEvent;
    FOnCancel: TCancelEvent;

    // UI Controls
    FHeading: TLabel;
    FSubHeading: TLabel;
    FHistoryHost: TPanel;
    FChatView: TMarkdownView;
    FComposerCard: TPanel;
    FComposerFooter: TPanel;
    FWorkspaceTag: TLabel;
    FPromptMemo: TMemo;
    FModePicker: TThemedPickerFrame;
    FModelPicker: TThemedPickerFrame;
    FModelIds: TStringList;
    FSendBtn: TThemedButtonFrame;
    FStopBtn: TThemedButtonFrame;
    FUpdatingLayout: Boolean;
    FInThemeApply: Boolean;
    FDeferLayout: Boolean;
    FLastLayoutW: Integer;
    FLastLayoutH: Integer;

    procedure ModePickerChange(Sender: TObject);
    procedure ModelPickerChange(Sender: TObject);
    procedure SendBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure UpdateHeading;
    procedure UpdateLayout;
    procedure InitWelcomeMarkdown;
    procedure AppendToHistoryMarkdown(const ARoleLabel, ABody: string);
    procedure RefreshHistoryView;
    procedure ScrollChatToBottom(Data: PtrInt);
    function ToolMessageBody(const AMsg: TChatMessage): string;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure EnsureLayout;
    procedure SetWorkspace(const AName: string);
    procedure SetMode(AMode: TWorkspaceMode);
    procedure SetModel(const AModel: string);
    procedure SetAvailableModels(const AModels: array of TSavedModel);
    procedure SetRunning(ARunning: Boolean);

    procedure AppendMessage(const AMsg: TChatMessage);
    procedure AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
    procedure AppendText(const AText: string);
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
  ComposerSidePad = 14;
  ComposerBottomPad = 12;
  ComposerFooterGap = 10;
  ComposerSendBtnMinW = 108;
  ComposerFooterBtnH = 28;
  ComposerFooterRightPad = 6;
  ComposerComboGap = 8;
  ComposerModelComboMinW = 148;
  ComposerModelComboMaxW = 360;
  ComposerModePickerMaxW = 168;
  ComposerCardHMin = 200;
  ComposerCardHMax = 240;
  ChatHeadingTop = 32;
  ChatHeadingH = 40;
  ChatSubHeadingH = 22;

function MaxLayoutDim(V, MinV: Integer): Integer;
begin
  if V < MinV then
    Result := MinV
  else
    Result := V;
end;

procedure SetBoundsIfChanged(AControl: TControl; AL, AT, AW, AH: Integer);
begin
  if not Assigned(AControl) then Exit;
  if (AControl.Left = AL) and (AControl.Top = AT) and
     (AControl.Width = AW) and (AControl.Height = AH) then Exit;
  AControl.SetBounds(AL, AT, AW, AH);
end;

function ThemedActionButtonWidth(AChat: TChatPanel; const ACaption: string): Integer;
begin
  Result := ComposerSendBtnMinW;
  if not Assigned(AChat) then Exit;
  Result := MeasureThemedButtonWidth(AChat, ACaption, tbrPrimary,
    ScaledThemedTabMetric(AChat, ComposerSendBtnMinW));
end;

function ExtractToolErrorLine(const AJsonText: string): string;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := '';
  try
    Data := GetJSON(AJsonText);
    try
      if Data.JSONType = jtObject then
      begin
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

procedure TChatPanel.InitWelcomeMarkdown;
begin
  FHistoryMarkdown :=
    '✨ Welcome to LazyCodingAgent!' + LineEnding + LineEnding +
    '💡 Type a prompt below or pick a mode (Ask, Plan, Agent) to start building.';
end;

constructor TChatPanel.Create(AOwner: TComponent);
var
  M: TWorkspaceMode;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  DoubleBuffered := True;
  FTheme := tkDark;
  FWorkspaceName := 'LazyCodingAgent';
  FMode := wmAgent;
  FModel := '';
  FIsRunning := False;
  FUpdatingLayout := False;
  FInThemeApply := False;
  FDeferLayout := False;
  FLastLayoutW := -1;
  FLastLayoutH := -1;
  FModelIds := TStringList.Create;

  FHeading := TLabel.Create(Self);
  FHeading.Parent := Self;
  FHeading.AutoSize := False;
  FHeading.Font.Size := 16;
  FHeading.Font.Style := [fsBold];
  FHeading.Alignment := taCenter;
  FHeading.Layout := tlCenter;

  FSubHeading := TLabel.Create(Self);
  FSubHeading.Parent := Self;
  FSubHeading.AutoSize := False;
  FSubHeading.Font.Size := 9;
  FSubHeading.Alignment := taCenter;
  FSubHeading.Caption := 'Autonomous AI agent to help you design, implement, and refactor code.';

  FHistoryHost := TPanel.Create(Self);
  FHistoryHost.Parent := Self;
  FHistoryHost.BevelOuter := bvNone;

  FChatView := TMarkdownView.Create(FHistoryHost);
  FChatView.Parent := FHistoryHost;
  FChatView.Align := alClient;

  InitWelcomeMarkdown;

  FComposerCard := TPanel.Create(Self);
  FComposerCard.Parent := Self;
  FComposerCard.BevelOuter := bvNone;

  FWorkspaceTag := TLabel.Create(FComposerCard);
  FWorkspaceTag.Parent := FComposerCard;
  FWorkspaceTag.AutoSize := False;
  FWorkspaceTag.Font.Size := 8;
  FWorkspaceTag.Font.Style := [fsBold];

  FPromptMemo := TMemo.Create(FComposerCard);
  FPromptMemo.Parent := FComposerCard;
  FPromptMemo.BorderStyle := bsNone;
  FPromptMemo.ScrollBars := ssVertical;
  FPromptMemo.Lines.Text := '';
  FPromptMemo.Hint := 'Ask a question, propose a plan, or describe changes to your codebase...';
  FPromptMemo.ShowHint := True;

  FComposerFooter := TPanel.Create(FComposerCard);
  FComposerFooter.Parent := FComposerCard;
  FComposerFooter.BevelOuter := bvNone;

  FModePicker := TThemedPickerFrame.Create(FComposerFooter);
  FModePicker.Parent := FComposerFooter;
  FModePicker.Placeholder := 'Mode';
  for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
    FModePicker.Items.Add(WorkspaceModeCaption(M));
  FModePicker.ItemIndex := Ord(FMode);
  FModePicker.OnChange := @ModePickerChange;

  FModelPicker := TThemedPickerFrame.Create(FComposerFooter);
  FModelPicker.Parent := FComposerFooter;
  FModelPicker.Placeholder := 'Model';
  FModelPicker.OnChange := @ModelPickerChange;

  FStopBtn := TThemedButtonFrame.Create(FComposerFooter);
  FStopBtn.Parent := FComposerFooter;
  FStopBtn.Caption := '⏹ Stop';
  FStopBtn.Visible := False;
  FStopBtn.OnClick := @StopBtnClick;

  FSendBtn := TThemedButtonFrame.Create(FComposerFooter);
  FSendBtn.Parent := FComposerFooter;
  FSendBtn.Caption := '➤ Run Agent';
  FSendBtn.OnClick := @SendBtnClick;

  ApplyTheme(FTheme);
  RefreshHistoryView;
  UpdateHeading;
end;

destructor TChatPanel.Destroy;
begin
  FModelIds.Free;
  inherited Destroy;
end;

procedure TChatPanel.UpdateHeading;
begin
  if Assigned(FHeading) then
    FHeading.Caption := Format('What should we build in %s?', [FWorkspaceName]);
  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.Caption := Format('PROJECT: %s  •  MODE: %s', [FWorkspaceName, WorkspaceModeCaption(FMode)]);
end;

procedure TChatPanel.SetRunning(ARunning: Boolean);
begin
  FIsRunning := ARunning;
  FStopBtn.Visible := ARunning;
  FSendBtn.Enabled := not ARunning;
  FPromptMemo.ReadOnly := ARunning;
  UpdateLayout;
end;

procedure TChatPanel.CreateWnd;
begin
  inherited CreateWnd;
end;

procedure TChatPanel.EnsureLayout;
begin
  if ParentFormHandlesReady(Self) then
    UpdateLayout;
end;

procedure TChatPanel.UpdateLayout;
var
  W, H, InnerW, CardW, CardH, CardX, CardY, HistoryH, HistoryTop, FooterW, FooterH,
  FooterY, BtnTop, FooterBtnH, SendW, StopW, SendLeft, StopLeft, MemoH, ModeW,
  ModelLeft, ModelW, ModelRight, MinButtonsW: Integer;
begin
  if not ParentFormHandlesReady(Self) then Exit;
  if FUpdatingLayout or FDeferLayout then Exit;
  FUpdatingLayout := True;
  try
  W := Width;
  H := Height;
  InnerW := MaxLayoutDim(W - 48, 8);

  SetBoundsIfChanged(FHeading, 24, ChatHeadingTop, InnerW, ChatHeadingH);
  SetBoundsIfChanged(FSubHeading, 24, ChatHeadingTop + ChatHeadingH + 6, InnerW, ChatSubHeadingH);

  HistoryTop := ChatHeadingTop + ChatHeadingH + 6 + ChatSubHeadingH + 8;

  CardW := W - 48;
  if CardW < 100 then CardW := 100;
  CardH := H div 5;
  if CardH < ComposerCardHMin then
    CardH := ComposerCardHMin;
  if CardH > ComposerCardHMax then
    CardH := ComposerCardHMax;
  CardX := 24;
  CardY := H - CardH - 16;
  if CardY < HistoryTop + 40 then CardY := HistoryTop + 40;

  HistoryH := MaxLayoutDim(CardY - HistoryTop, 8);
  SetBoundsIfChanged(FHistoryHost, 24, HistoryTop, InnerW, HistoryH);
  SetBoundsIfChanged(FComposerCard, CardX, CardY, CardW, CardH);
  SetBoundsIfChanged(FWorkspaceTag, ComposerSidePad, 10, MaxLayoutDim(CardW - ComposerSidePad * 2, 8), 18);

  FooterBtnH := ScaledThemedButtonHeight(Self);
  FooterH := FooterBtnH + 12;
  FooterY := CardH - FooterH - ComposerBottomPad;
  FooterW := MaxLayoutDim(CardW - ComposerSidePad * 2, 8);
  MemoH := MaxLayoutDim(FooterY - 32 - ComposerFooterGap, 8);
  SetBoundsIfChanged(FPromptMemo, ComposerSidePad, 32, FooterW, MemoH);

  if Assigned(FComposerFooter) then begin
    SetBoundsIfChanged(FComposerFooter, ComposerSidePad, FooterY, FooterW, FooterH);

    BtnTop := (FooterH - FooterBtnH) div 2;
    if BtnTop < 0 then BtnTop := 0;

    ModeW := ComposerModePickerMaxW;
    if Assigned(FModePicker) then
      ModeW := FModePicker.PreferredWidth;
    if ModeW > ComposerModePickerMaxW then
      ModeW := ComposerModePickerMaxW;
    if ModeW > FooterW div 2 then
      ModeW := MaxLayoutDim(FooterW div 2, 72);

    SendW := ThemedActionButtonWidth(Self, FSendBtn.Caption);
    StopW := 0;
    if Assigned(FStopBtn) and FStopBtn.Visible then
      StopW := MeasureThemedButtonWidth(FStopBtn, FStopBtn.Caption, tbrDestructive,
        ScaledThemedTabMetric(Self, ComposerSendBtnMinW));

    SendLeft := FooterW - ComposerFooterRightPad - SendW;
    if StopW > 0 then begin
      StopLeft := SendLeft - ComposerComboGap - StopW;
      ModelRight := StopLeft - ComposerComboGap;
      SetBoundsIfChanged(FStopBtn, StopLeft, BtnTop, StopW, FooterBtnH);
    end else
      ModelRight := SendLeft - ComposerComboGap;
    SetBoundsIfChanged(FSendBtn, SendLeft, BtnTop, SendW, FooterBtnH);

    ModelLeft := ModeW + ComposerComboGap;
    ModelW := ComposerModelComboMinW;
    if Assigned(FModelPicker) then
      ModelW := FModelPicker.PreferredWidth;
    if ModelW < ComposerModelComboMinW then
      ModelW := ComposerModelComboMinW;
    if ModelW > ComposerModelComboMaxW then
      ModelW := ComposerModelComboMaxW;
    if ModelW > ModelRight - ModelLeft then
      ModelW := MaxLayoutDim(ModelRight - ModelLeft, 8);
    while (ModelRight - ModelLeft < ComposerModelComboMinW) and (ModeW > 72) do begin
      ModeW := ModeW - 4;
      ModelLeft := ModeW + ComposerComboGap;
    end;
    if ModelW > ModelRight - ModelLeft then
      ModelW := MaxLayoutDim(ModelRight - ModelLeft, 8);

    SetBoundsIfChanged(FModePicker, 0, BtnTop, ModeW, FooterBtnH);
    SetBoundsIfChanged(FModelPicker, ModelLeft, BtnTop, ModelW, FooterBtnH);
  end;
  FLastLayoutW := W;
  FLastLayoutH := H;
  finally
    FUpdatingLayout := False;
  end;
end;

procedure TChatPanel.Resize;
begin
  inherited Resize;
  if FDeferLayout or FInThemeApply then Exit;
  if (Width = FLastLayoutW) and (Height = FLastLayoutH) then Exit;
  UpdateLayout;
end;

procedure TChatPanel.RefreshHistoryView;
begin
  if Assigned(FChatView) then
    FChatView.SetMarkdown(FHistoryMarkdown);
  if ParentFormHandlesReady(Self) then
    Application.QueueAsyncCall(@ScrollChatToBottom, 0);
end;

procedure TChatPanel.ScrollChatToBottom(Data: PtrInt);
begin
  if Data <> 0 then ;
  if Assigned(FChatView) then
    FChatView.ScrollToBottom;
end;

procedure TChatPanel.AppendToHistoryMarkdown(const ARoleLabel, ABody: string);
begin
  if Trim(ABody) = '' then Exit;
  if FHistoryMarkdown <> '' then
    FHistoryMarkdown := FHistoryMarkdown + LineEnding + LineEnding;
  FHistoryMarkdown := FHistoryMarkdown + '**' + ARoleLabel + '**' +
    LineEnding + LineEnding + ABody;
  RefreshHistoryView;
end;

function TChatPanel.ToolMessageBody(const AMsg: TChatMessage): string;
var
  ErrLine: string;
begin
  Result := Trim(AMsg.Content);
  if (Length(Result) > MaxToolBodyInChat) or
     ((Length(Result) > 80) and (Pos('"error"', LowerCase(Result)) > 0)) then
  begin
    ErrLine := ExtractToolErrorLine(Result);
    if ErrLine <> '' then
      Result := ErrLine
    else if Length(Result) > MaxToolBodyInChat then
      Result := Copy(Result, 1, MaxToolBodyInChat) + '…'
    else if AMsg.VisualSummary <> '' then
      Result := AMsg.VisualSummary;
  end;
end;

procedure TChatPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  FInThemeApply := True;
  FDeferLayout := True;
  P := ThemePalette(FTheme);

  Color := P.Background;
  FHeading.Font.Color := P.Text;
  FSubHeading.Font.Color := P.TextMuted;

  if ATheme = tkDark then
    FHistoryHost.Color := P.Background
  else
    FHistoryHost.Color := P.Surface;
  if Assigned(FChatView) then
    FChatView.ApplyTheme(FTheme);

  FComposerCard.Color := P.Surface;
  FWorkspaceTag.Font.Color := P.Accent;
  ConfigureThemedMemo(FPromptMemo, ATheme);

  FComposerFooter.Color := P.Surface;
  if Assigned(FModePicker) then
    FModePicker.ApplyTheme(FTheme);
  if Assigned(FModelPicker) then
    FModelPicker.ApplyTheme(FTheme);

  if Assigned(FSendBtn) then
    StylePrimaryButton(FSendBtn, FTheme);
  if Assigned(FStopBtn) then
    StyleDestructiveButton(FStopBtn, FTheme);

  if Assigned(FChatView) then
    FChatView.SetMarkdown(FHistoryMarkdown);

  FDeferLayout := False;
  FInThemeApply := False;
  UpdateLayout;
  Invalidate;
end;

procedure TChatPanel.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  ApplyPlatformScrollableTheme(FHistoryHost, ATheme);
  ApplyPlatformScrollableTheme(FChatView, ATheme);
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
  if Assigned(FModePicker) then
    FModePicker.ItemIndex := Ord(AMode);
  UpdateHeading;
  case FMode of
    wmAsk: FSendBtn.Caption := 'Ask Question';
    wmPlan: FSendBtn.Caption := 'Create Plan';
    wmAgent: FSendBtn.Caption := '➤ Run Agent';
  end;
  UpdateLayout;
end;

function ModelComboCaption(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName
  else
    Result := M.ModelId;
end;

procedure TChatPanel.SetAvailableModels(const AModels: array of TSavedModel);
var
  I, SelIdx: Integer;
  Cap: string;
begin
  FModelPicker.Items.BeginUpdate;
  FModelIds.BeginUpdate;
  try
    FModelPicker.Items.Clear;
    FModelIds.Clear;
    SelIdx := -1;
    for I := 0 to High(AModels) do begin
      Cap := ModelComboCaption(AModels[I]);
      FModelPicker.Items.Add(Cap);
      FModelIds.Add(AModels[I].ModelId);
      if SameText(AModels[I].ModelId, FModel) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      FModelPicker.ItemIndex := SelIdx
    else if FModelPicker.Items.Count > 0 then begin
      FModelPicker.ItemIndex := 0;
      FModel := FModelIds[0];
    end else begin
      FModelPicker.ItemIndex := -1;
      FModel := '';
    end;
  finally
    FModelIds.EndUpdate;
    FModelPicker.Items.EndUpdate;
  end;
end;

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Assigned(FModelPicker) then begin
    if Idx >= 0 then
      FModelPicker.ItemIndex := Idx
    else if FModel = '' then
      FModelPicker.ItemIndex := -1;
  end;
end;

procedure TChatPanel.ClearHistory;
begin
  FHistoryMarkdown := '';
  if Assigned(FChatView) then
    FChatView.SetMarkdown('');
end;

procedure TChatPanel.AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
var
  RoleLabel, Body: string;
begin
  if ADebuggingMode then begin
    if AMsg.VisualSummary <> '' then
      RoleLabel := '🛠 Tool Result [' + AMsg.VisualSummary + ']'
    else
      RoleLabel := '🛠 Tool Result';
    Body := Trim(AMsg.Content);
    if Body = '' then Exit;
    AppendToHistoryMarkdown(RoleLabel, Body);
    Exit;
  end;

  if Pos('"error"', LowerCase(AMsg.Content)) = 0 then
    Exit;

  if AMsg.VisualSummary <> '' then
    RoleLabel := '🛠 Tool Error [' + AMsg.VisualSummary + ']'
  else
    RoleLabel := '🛠 Tool Error';
  Body := ToolMessageBody(AMsg);
  if Trim(Body) = '' then Exit;
  AppendToHistoryMarkdown(RoleLabel, Body);
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
        RoleLabel := '👤 You';
        Body := AMsg.Content;
      end;
    crAssistant:
      begin
        RoleLabel := '🤖 Agent';
        Body := AMsg.Content;
      end;
    crTool:
      begin
        if AMsg.VisualSummary <> '' then
          RoleLabel := '🛠 Tool [' + AMsg.VisualSummary + ']'
        else
          RoleLabel := '🛠 Tool';
        Body := ToolMessageBody(AMsg);
      end;
  else
    Body := AMsg.Content;
    RoleLabel := 'Message';
  end;
  AppendToHistoryMarkdown(RoleLabel, Body);
end;

procedure TChatPanel.AppendText(const AText: string);
begin
  if Trim(AText) = '' then Exit;
  if FHistoryMarkdown <> '' then
    FHistoryMarkdown := FHistoryMarkdown + LineEnding + LineEnding;
  FHistoryMarkdown := FHistoryMarkdown + AText;
  RefreshHistoryView;
end;

procedure TChatPanel.ModePickerChange(Sender: TObject);
begin
  if (FModePicker.ItemIndex < Ord(Low(TWorkspaceMode))) or
     (FModePicker.ItemIndex > Ord(High(TWorkspaceMode))) then
    Exit;
  FMode := TWorkspaceMode(FModePicker.ItemIndex);
  UpdateHeading;
  if Assigned(FOnModeChange) then
    FOnModeChange(Self, FMode);
end;

procedure TChatPanel.ModelPickerChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FModelPicker.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    FModel := FModelIds[Idx]
  else
    FModel := '';
  if Assigned(FOnModelChange) then
    FOnModelChange(Self, FModel);
end;

procedure TChatPanel.SetComposerEnabled(AEnabled: Boolean);
begin
  FPromptMemo.Enabled := AEnabled;
  FModePicker.Enabled := AEnabled;
  FModelPicker.Enabled := AEnabled;
  FSendBtn.Enabled := AEnabled and not FIsRunning;
end;

procedure TChatPanel.ReloadFromMessages(const AMessages: TChatMessageArray; ADebuggingMode: Boolean);
var
  I: Integer;
begin
  ClearHistory;
  for I := 0 to High(AMessages) do begin
    if AMessages[I].Role = crTool then
      AppendToolMessage(AMessages[I], ADebuggingMode)
    else
      AppendMessage(AMessages[I]);
  end;
end;

procedure TChatPanel.SubmitPrompt(const APrompt: string);
begin
  if Trim(APrompt) = '' then Exit;
  if FIsRunning then Exit;
  if not FPromptMemo.Enabled then Exit;
  if Assigned(FOnPrompt) then
    FOnPrompt(Self, Trim(APrompt), FMode, FModel);
end;

procedure TChatPanel.SendBtnClick(Sender: TObject);
var
  Prompt: string;
begin
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
