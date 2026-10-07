unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs, Forms,
  LCLType, fpjson, jsonparser,
  uAppTypes, uTheme, uThemedButton, uAgentTypes, uWorkspaceState, uMarkdownView;

type
  TPromptEvent = procedure(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string) of object;
  TModeChangeEvent = procedure(Sender: TObject; AMode: TWorkspaceMode) of object;
  TModelChangeEvent = procedure(Sender: TObject; const AModel: string) of object;
  TCancelEvent = procedure(Sender: TObject) of object;

  { TChatPanel }
  TChatPanel = class(TCustomControl)
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
    FModeCombo: TComboBox;
    FModelCombo: TComboBox;
    FModelIds: TStringList;
    FSendBtn: TThemedButton;
    FStopBtn: TThemedButton;
    FUpdatingLayout: Boolean;

    procedure ModeComboChange(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
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
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
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
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FTheme := tkDark;
  FWorkspaceName := 'LazyCodingAgent';
  FMode := wmAgent;
  FModel := '';
  FIsRunning := False;
  FUpdatingLayout := False;
  FModelIds := TStringList.Create;

  FHeading := TLabel.Create(Self);
  FHeading.Parent := Self;
  FHeading.AutoSize := False;
  FHeading.Font.Size := 16;
  FHeading.Font.Style := [fsBold];
  FHeading.Alignment := taCenter;

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

  FModeCombo := TComboBox.Create(FComposerFooter);
  FModeCombo.Parent := FComposerFooter;
  FModeCombo.Style := csOwnerDrawFixed;
  FModeCombo.OnDrawItem := @ComboDrawItem;
  FModeCombo.ItemHeight := ThemedComboBoxItemHeight;
  for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
    FModeCombo.Items.Add(WorkspaceModeCaption(M));
  FModeCombo.ItemIndex := Ord(FMode);
  FModeCombo.OnChange := @ModeComboChange;

  FModelCombo := TComboBox.Create(FComposerFooter);
  FModelCombo.Parent := FComposerFooter;
  FModelCombo.Style := csOwnerDrawFixed;
  FModelCombo.OnDrawItem := @ComboDrawItem;
  FModelCombo.ItemHeight := ThemedComboBoxItemHeight;
  FModelCombo.OnChange := @ModelComboChange;

  FStopBtn := TThemedButton.Create(FComposerFooter);
  FStopBtn.Parent := FComposerFooter;
  FStopBtn.Caption := '⏹ Stop';
  FStopBtn.ButtonRole := tbrDestructive;
  FStopBtn.Visible := False;
  FStopBtn.OnClick := @StopBtnClick;

  FSendBtn := TThemedButton.Create(FComposerFooter);
  FSendBtn.Parent := FComposerFooter;
  FSendBtn.Caption := '➤ Run Agent';
  FSendBtn.ButtonRole := tbrPrimary;
  FSendBtn.OnClick := @SendBtnClick;

  ApplyTheme(FTheme);
  RefreshHistoryView;
  UpdateHeading;
  UpdateLayout;
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
  UpdateLayout;
end;

procedure TChatPanel.UpdateLayout;
var
  W, H, InnerW, CardW, CardH, CardX, CardY, HistoryH, FooterW, ComboH: Integer;
begin
  if not ParentFormHandlesReady(Self) then Exit;
  if FUpdatingLayout then Exit;
  FUpdatingLayout := True;
  try
  W := Width;
  H := Height;
  InnerW := MaxLayoutDim(W - 48, 8);

  SetBoundsIfChanged(FHeading, 24, 20, InnerW, 30);
  SetBoundsIfChanged(FSubHeading, 24, 52, InnerW, 20);

  CardW := W - 48;
  if CardW < 100 then CardW := 100;
  CardH := 160;
  CardX := 24;
  CardY := H - CardH - 16;
  if CardY < 80 then CardY := 80;

  HistoryH := MaxLayoutDim(CardY - 86, 8);
  SetBoundsIfChanged(FHistoryHost, 24, 78, InnerW, HistoryH);
  SetBoundsIfChanged(FComposerCard, CardX, CardY, CardW, CardH);
  SetBoundsIfChanged(FWorkspaceTag, 14, 10, MaxLayoutDim(CardW - 28, 8), 18);
  SetBoundsIfChanged(FPromptMemo, 14, 32, MaxLayoutDim(CardW - 28, 8), MaxLayoutDim(CardH - 80, 8));

  if Assigned(FComposerFooter) then begin
    FooterW := MaxLayoutDim(CardW - 28, 8);
    SetBoundsIfChanged(FComposerFooter, 14, CardH - 42, FooterW, 32);

    ComboH := EffectiveThemedComboBoxHeight(FModeCombo);
    SetBoundsIfChanged(FModeCombo, 0, 4, 100, ComboH);
    SetBoundsIfChanged(FModelCombo, 108, 4, 210, ComboH);

    if Assigned(FStopBtn) and FStopBtn.Visible then begin
      SetBoundsIfChanged(FStopBtn, FComposerFooter.Width - 195, 2, 85, 28);
      SetBoundsIfChanged(FSendBtn, FComposerFooter.Width - 105, 2, 105, 28);
    end else
      SetBoundsIfChanged(FSendBtn, FComposerFooter.Width - 110, 2, 110, 28);
  end;
  finally
    FUpdatingLayout := False;
  end;
end;

procedure TChatPanel.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TChatPanel.Paint;
var
  P: TThemePalette;
  CR: TRect;
begin
  P := ThemePalette(FTheme);

  Canvas.Brush.Color := P.Background;
  Canvas.FillRect(ClientRect);

  CR := FComposerCard.BoundsRect;
  Canvas.Brush.Color := P.Surface;
  Canvas.Pen.Color := P.BorderStrong;
  Canvas.RoundRect(CR.Left, CR.Top, CR.Right, CR.Bottom, 10, 10);
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
  StyleComboBox(FModeCombo, FTheme);
  StyleComboBox(FModelCombo, FTheme);

  if Assigned(FSendBtn) then
    FSendBtn.ApplyTheme(FTheme);
  if Assigned(FStopBtn) then
    FStopBtn.ApplyTheme(FTheme);

  if Assigned(FChatView) then
    FChatView.SetMarkdown(FHistoryMarkdown);

  UpdateLayout;
  Invalidate;
end;

procedure TChatPanel.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  ApplyPlatformScrollableTheme(FHistoryHost, ATheme);
  ApplyPlatformScrollableTheme(FChatView, ATheme);
  ApplyPlatformScrollableTheme(FPromptMemo, ATheme);
  ApplyPlatformScrollableTheme(FModeCombo, ATheme);
  ApplyPlatformScrollableTheme(FModelCombo, ATheme);
end;

procedure TChatPanel.SetWorkspace(const AName: string);
begin
  FWorkspaceName := AName;
  UpdateHeading;
end;

procedure TChatPanel.SetMode(AMode: TWorkspaceMode);
begin
  FMode := AMode;
  FModeCombo.ItemIndex := Ord(AMode);
  UpdateHeading;
  case FMode of
    wmAsk: FSendBtn.Caption := 'Ask Question';
    wmPlan: FSendBtn.Caption := 'Create Plan';
    wmAgent: FSendBtn.Caption := '➤ Run Agent';
  end;
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

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Idx >= 0 then
    FModelCombo.ItemIndex := Idx;
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

procedure TChatPanel.ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Combo: TComboBox;
  P: TThemePalette;
  Txt: string;
begin
  Combo := TComboBox(Control);
  P := ThemePalette(FTheme);

  if odSelected in State then begin
    Combo.Canvas.Brush.Color := P.Accent;
    Combo.Canvas.Font.Color := clWhite;
  end else begin
    Combo.Canvas.Brush.Color := P.SurfaceAlt;
    Combo.Canvas.Font.Color := P.Text;
  end;

  Combo.Canvas.FillRect(ARect);
  if (Index >= 0) and (Index < Combo.Items.Count) then begin
    Txt := Combo.Items[Index];
    Combo.Canvas.TextOut(ARect.Left + 6, ARect.Top + (ARect.Height - Combo.Canvas.TextHeight(Txt)) div 2, Txt);
  end;
end;

procedure TChatPanel.ModeComboChange(Sender: TObject);
begin
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
  FPromptMemo.Enabled := AEnabled;
  FModeCombo.Enabled := AEnabled;
  FModelCombo.Enabled := AEnabled;
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
