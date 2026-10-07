unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  LCLType, uAppTypes, uTheme, uAgentTypes;

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

    FOnPrompt: TPromptEvent;
    FOnModeChange: TModeChangeEvent;
    FOnModelChange: TModelChangeEvent;
    FOnCancel: TCancelEvent;

    // UI Controls
    FHeading: TLabel;
    FSubHeading: TLabel;
    FHistoryList: TListBox;
    FComposerCard: TPanel;
    FComposerFooter: TPanel;
    FWorkspaceTag: TLabel;
    FPromptMemo: TMemo;
    FModeCombo: TComboBox;
    FModelCombo: TComboBox;
    FSendBtn: TButton;
    FStopBtn: TButton;

    procedure ModeComboChange(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure SendBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure UpdateHeading;
    procedure UpdateLayout;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetWorkspace(const AName: string);
    procedure SetMode(AMode: TWorkspaceMode);
    procedure SetModel(const AModel: string);
    procedure SetRunning(ARunning: Boolean);

    procedure AppendMessage(const AMsg: TChatMessage);
    procedure AppendText(const AText: string);
    procedure ClearHistory;

    property Mode: TWorkspaceMode read FMode write SetMode;
    property Model: string read FModel write SetModel;
    property IsRunning: Boolean read FIsRunning write SetRunning;
    property OnModeChange: TModeChangeEvent read FOnModeChange write FOnModeChange;
    property OnModelChange: TModelChangeEvent read FOnModelChange write FOnModelChange;
    property OnPrompt: TPromptEvent read FOnPrompt write FOnPrompt;
    property OnCancel: TCancelEvent read FOnCancel write FOnCancel;
  end;

implementation

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
  FModel := 'anthropic/claude-3.7-sonnet';
  FIsRunning := False;

  // Hero Top Greeting
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

  // Conversation history area
  FHistoryList := TListBox.Create(Self);
  FHistoryList.Parent := Self;
  FHistoryList.BorderStyle := bsNone;
  FHistoryList.Items.Add('✨ Welcome to LazyCodingAgent!');
  FHistoryList.Items.Add('💡 Type a prompt below or pick a mode (Ask, Plan, Agent) to start building.');

  // Modern Card Container for Composer
  FComposerCard := TPanel.Create(Self);
  FComposerCard.Parent := Self;
  FComposerCard.BevelOuter := bvNone;

  // Workspace badge/label
  FWorkspaceTag := TLabel.Create(FComposerCard);
  FWorkspaceTag.Parent := FComposerCard;
  FWorkspaceTag.AutoSize := False;
  FWorkspaceTag.Font.Size := 8;
  FWorkspaceTag.Font.Style := [fsBold];

  // Multiline prompt memo
  FPromptMemo := TMemo.Create(FComposerCard);
  FPromptMemo.Parent := FComposerCard;
  FPromptMemo.BorderStyle := bsNone;
  FPromptMemo.ScrollBars := ssVertical;
  FPromptMemo.Lines.Text := '';
  FPromptMemo.Hint := 'Ask a question, propose a plan, or describe changes to your codebase...';
  FPromptMemo.ShowHint := True;

  // Footer bar inside composer card
  FComposerFooter := TPanel.Create(FComposerCard);
  FComposerFooter.Parent := FComposerCard;
  FComposerFooter.BevelOuter := bvNone;

  // Mode combo box
  FModeCombo := TComboBox.Create(FComposerFooter);
  FModeCombo.Parent := FComposerFooter;
  FModeCombo.Style := csOwnerDrawFixed;
  FModeCombo.OnDrawItem := @ComboDrawItem;
  FModeCombo.ItemHeight := 24;
  for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
    FModeCombo.Items.Add(WorkspaceModeCaption(M));
  FModeCombo.ItemIndex := Ord(FMode);
  FModeCombo.OnChange := @ModeComboChange;

  // Model combo box
  FModelCombo := TComboBox.Create(FComposerFooter);
  FModelCombo.Parent := FComposerFooter;
  FModelCombo.Style := csOwnerDrawFixed;
  FModelCombo.OnDrawItem := @ComboDrawItem;
  FModelCombo.ItemHeight := 24;
  FModelCombo.Items.Add('anthropic/claude-3.7-sonnet');
  FModelCombo.Items.Add('openai/gpt-4o');
  FModelCombo.Items.Add('deepseek/deepseek-r1');
  FModelCombo.Items.Add('google/gemini-2.0-flash');
  FModelCombo.Items.Add('qwen2.5-coder:7b');
  FModelCombo.ItemIndex := 0;
  FModelCombo.OnChange := @ModelComboChange;

  // Stop button
  FStopBtn := TButton.Create(FComposerFooter);
  FStopBtn.Parent := FComposerFooter;
  FStopBtn.Caption := '⏹ Stop';
  FStopBtn.Visible := False;
  FStopBtn.OnClick := @StopBtnClick;

  // Send button
  FSendBtn := TButton.Create(FComposerFooter);
  FSendBtn.Parent := FComposerFooter;
  FSendBtn.Caption := '➤ Run Agent';
  FSendBtn.OnClick := @SendBtnClick;

  UpdateHeading;
  UpdateLayout;
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

procedure TChatPanel.UpdateLayout;
var
  W, H, CardW, CardH, CardX, CardY: Integer;
begin
  W := Width;
  H := Height;

  if Assigned(FHeading) then
    FHeading.SetBounds(24, 20, W - 48, 30);

  if Assigned(FSubHeading) then
    FSubHeading.SetBounds(24, 52, W - 48, 20);

  CardW := W - 48;
  if CardW < 100 then CardW := 100;
  CardH := 160;
  CardX := 24;
  CardY := H - CardH - 16;
  if CardY < 80 then CardY := 80;

  if Assigned(FHistoryList) then
    FHistoryList.SetBounds(24, 78, W - 48, CardY - 86);

  if Assigned(FComposerCard) then
    FComposerCard.SetBounds(CardX, CardY, CardW, CardH);

  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.SetBounds(14, 10, CardW - 28, 18);

  if Assigned(FPromptMemo) then
    FPromptMemo.SetBounds(14, 32, CardW - 28, CardH - 80);

  if Assigned(FComposerFooter) then begin
    FComposerFooter.SetBounds(14, CardH - 42, CardW - 28, 32);

    if Assigned(FModeCombo) then
      FModeCombo.SetBounds(0, 2, 100, 28);

    if Assigned(FModelCombo) then
      FModelCombo.SetBounds(108, 2, 210, 28);

    if Assigned(FStopBtn) and FStopBtn.Visible then begin
      FStopBtn.SetBounds(FComposerFooter.Width - 195, 2, 85, 28);
      if Assigned(FSendBtn) then
        FSendBtn.SetBounds(FComposerFooter.Width - 105, 2, 105, 28);
    end else begin
      if Assigned(FSendBtn) then
        FSendBtn.SetBounds(FComposerFooter.Width - 110, 2, 110, 28);
    end;
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

  // Background
  Canvas.Brush.Color := P.Background;
  Canvas.FillRect(ClientRect);

  // Composer Card styling
  CR := FComposerCard.BoundsRect;
  Canvas.Brush.Color := P.Surface;
  Canvas.Pen.Color := P.BorderStrong;
  Canvas.RoundRect(CR.Left, CR.Top, CR.Right, CR.Bottom, 10, 10);
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

  FHistoryList.Color := P.Surface;
  FHistoryList.Font.Color := P.Text;
  FHistoryList.Font.Name := 'Segoe UI';

  FComposerCard.Color := P.Surface;
  FWorkspaceTag.Font.Color := P.Accent;
  FPromptMemo.Color := P.SurfaceAlt;
  FPromptMemo.Font.Color := P.Text;
  FPromptMemo.Font.Name := 'Segoe UI';

  FComposerFooter.Color := P.Surface;
  FModeCombo.Color := P.SurfaceAlt;
  FModeCombo.Font.Color := P.Text;
  FModelCombo.Color := P.SurfaceAlt;
  FModelCombo.Font.Color := P.Text;

  Invalidate;
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

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelCombo.Items.IndexOf(AModel);
  if Idx >= 0 then
    FModelCombo.ItemIndex := Idx
  else begin
    FModelCombo.Items.Insert(0, AModel);
    FModelCombo.ItemIndex := 0;
  end;
end;

procedure TChatPanel.ClearHistory;
begin
  FHistoryList.Items.Clear;
end;

procedure TChatPanel.AppendMessage(const AMsg: TChatMessage);
var
  Prefix: string;
begin
  case AMsg.Role of
    crSystem: Prefix := '⚙ System: ';
    crUser: Prefix := '👤 You: ';
    crAssistant: Prefix := '🤖 Agent: ';
    crTool: Prefix := '🛠 Tool [' + AMsg.VisualSummary + ']: ';
  end;

  FHistoryList.Items.Add(Prefix + AMsg.Content);
  FHistoryList.ItemIndex := FHistoryList.Items.Count - 1;
end;

procedure TChatPanel.AppendText(const AText: string);
begin
  FHistoryList.Items.Add(AText);
  FHistoryList.ItemIndex := FHistoryList.Items.Count - 1;
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
begin
  FModel := FModelCombo.Text;
  if Assigned(FOnModelChange) then
    FOnModelChange(Self, FModel);
end;

procedure TChatPanel.SendBtnClick(Sender: TObject);
var
  Prompt: string;
begin
  Prompt := Trim(FPromptMemo.Text);
  if Prompt = '' then Exit;

  FPromptMemo.Text := '';
  if Assigned(FOnPrompt) then
    FOnPrompt(Self, Prompt, FMode, FModel);
end;

procedure TChatPanel.StopBtnClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

end.
