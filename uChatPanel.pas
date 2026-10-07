unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  uAppTypes, uTheme;

type
  TPromptEvent = procedure(Sender: TObject; const APrompt: string; AMode: TWorkspaceMode; const AModel: string) of object;
  TModeChangeEvent = procedure(Sender: TObject; AMode: TWorkspaceMode) of object;
  TModelChangeEvent = procedure(Sender: TObject; const AModel: string) of object;

  { TChatPanel }
  TChatPanel = class(TCustomControl)
  private
    FWorkspaceName: string;
    FTheme: TThemeKind;
    FMode: TWorkspaceMode;
    FModel: string;
    FOnPrompt: TPromptEvent;
    FOnModeChange: TModeChangeEvent;
    FOnModelChange: TModelChangeEvent;

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

    procedure ModeComboChange(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure SendBtnClick(Sender: TObject);
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
    property Mode: TWorkspaceMode read FMode write SetMode;
    property Model: string read FModel write SetModel;
    property OnModeChange: TModeChangeEvent read FOnModeChange write FOnModeChange;
    property OnModelChange: TModelChangeEvent read FOnModelChange write FOnModelChange;
    property OnPrompt: TPromptEvent read FOnPrompt write FOnPrompt;
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
  FModel := 'claude-3-7-sonnet';

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

  // Mode selector dropdown (Agent, Plan, Ask)
  FModeCombo := TComboBox.Create(FComposerFooter);
  FModeCombo.Parent := FComposerFooter;
  FModeCombo.Align := alLeft;
  FModeCombo.Width := 115;
  FModeCombo.BorderSpacing.Top := 6;
  FModeCombo.BorderSpacing.Bottom := 6;
  FModeCombo.BorderSpacing.Left := 4;
  FModeCombo.BorderSpacing.Right := 6;
  FModeCombo.Hint := 'Select workspace AI interaction mode';
  FModeCombo.ShowHint := True;
  for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
    FModeCombo.Items.Add(WorkspaceModeCaption(M));
  FModeCombo.ItemIndex := Ord(FMode);
  FModeCombo.OnDrawItem := @ComboDrawItem;
  FModeCombo.OnChange := @ModeComboChange;

  // Send action button
  FSendBtn := TButton.Create(FComposerFooter);
  FSendBtn.Parent := FComposerFooter;
  FSendBtn.Align := alRight;
  FSendBtn.Width := 90;
  FSendBtn.Caption := '➤ Send';
  FSendBtn.BorderSpacing.Top := 4;
  FSendBtn.BorderSpacing.Bottom := 4;
  FSendBtn.BorderSpacing.Right := 4;
  FSendBtn.BorderSpacing.Left := 4;
  FSendBtn.OnClick := @SendBtnClick;

  // Model selector dropdown
  FModelCombo := TComboBox.Create(FComposerFooter);
  FModelCombo.Parent := FComposerFooter;
  FModelCombo.Align := alRight;
  FModelCombo.Width := 170;
  FModelCombo.BorderSpacing.Top := 6;
  FModelCombo.BorderSpacing.Bottom := 6;
  FModelCombo.BorderSpacing.Left := 4;
  FModelCombo.BorderSpacing.Right := 6;
  FModelCombo.Items.Add('claude-3-7-sonnet');
  FModelCombo.Items.Add('gpt-4o');
  FModelCombo.Items.Add('deepseek-r1');
  FModelCombo.Items.Add('claude-3-5-sonnet');
  FModelCombo.ItemIndex := 0;
  FModelCombo.OnDrawItem := @ComboDrawItem;
  FModelCombo.OnChange := @ModelComboChange;

  UpdateLayout;
  UpdateHeading;
end;

procedure TChatPanel.ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  StyleComboBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TChatPanel.UpdateLayout;
var
  W, H: Integer;
  CardW, CardH, CardTop: Integer;
begin
  W := Width;
  H := Height;
  if W < 50 then W := 50;
  if H < 50 then H := 50;

  if Assigned(FHeading) then
    FHeading.SetBounds(16, 20, W - 32, 30);

  if Assigned(FSubHeading) then
    FSubHeading.SetBounds(16, 52, W - 32, 20);

  CardW := W - 48;
  if CardW < 100 then CardW := 100;
  CardH := 154;

  if H > 250 then begin
    CardTop := H - 170;
    if Assigned(FHistoryList) then
      FHistoryList.SetBounds(24, 80, CardW, CardTop - 90);
  end else begin
    CardTop := 80;
    if Assigned(FHistoryList) then
      FHistoryList.SetBounds(24, 80, CardW, 20);
  end;

  if Assigned(FComposerCard) then begin
    FComposerCard.SetBounds(24, CardTop, CardW, CardH);

    if Assigned(FWorkspaceTag) then
      FWorkspaceTag.SetBounds(10, 8, CardW - 20, 18);

    if Assigned(FPromptMemo) then
      FPromptMemo.SetBounds(10, 28, CardW - 20, CardH - 74);

    if Assigned(FComposerFooter) then
      FComposerFooter.SetBounds(8, CardH - 44, CardW - 16, 38);
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
  R: TRect;
begin
  P := ThemePalette(FTheme);

  // Background
  Canvas.Brush.Color := P.Surface;
  Canvas.FillRect(ClientRect);

  // Outer border of composer card
  if Assigned(FComposerCard) then begin
    R := FComposerCard.BoundsRect;
    Canvas.Pen.Color := P.BorderStrong;
    Canvas.Pen.Width := 1;
    Canvas.Rectangle(R.Left - 1, R.Top - 1, R.Right + 1, R.Bottom + 1);
  end;
end;

procedure TChatPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);

  Color := P.Surface;
  FHeading.Font.Color := P.Text;
  FSubHeading.Font.Color := P.TextMuted;

  FHistoryList.Color := P.Surface;
  FHistoryList.Font.Color := P.Text;
  FHistoryList.Font.Name := 'Segoe UI';

  FComposerCard.Color := P.SurfaceAlt;
  FWorkspaceTag.Font.Color := P.Accent;

  FPromptMemo.Color := P.SurfaceAlt;
  FPromptMemo.Font.Color := P.Text;
  FPromptMemo.Font.Name := 'Consolas';

  // Apply dark/light combobox styling flow
  StyleComboBox(FModeCombo, FTheme);
  StyleComboBox(FModelCombo, FTheme);

  Invalidate;
end;

procedure TChatPanel.UpdateHeading;
begin
  FHeading.Caption := 'What should we build in ' + FWorkspaceName + '?';
  FWorkspaceTag.Caption := 'WORKSPACE: ' + UpperCase(FWorkspaceName) + '  •  MODE: ' + UpperCase(WorkspaceModeCaption(FMode));
end;

procedure TChatPanel.SetWorkspace(const AName: string);
begin
  FWorkspaceName := AName;
  UpdateHeading;
end;

procedure TChatPanel.SetMode(AMode: TWorkspaceMode);
begin
  FMode := AMode;
  if Assigned(FModeCombo) and (FModeCombo.ItemIndex <> Ord(AMode)) then
    FModeCombo.ItemIndex := Ord(AMode);
  UpdateHeading;
end;

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelCombo.Items.IndexOf(AModel);
  if Idx < 0 then
    Idx := FModelCombo.Items.Add(AModel);
  FModelCombo.ItemIndex := Idx;
end;

procedure TChatPanel.ModeComboChange(Sender: TObject);
begin
  if FModeCombo.ItemIndex >= 0 then begin
    FMode := TWorkspaceMode(FModeCombo.ItemIndex);
    UpdateHeading;
    if Assigned(FOnModeChange) then
      FOnModeChange(Self, FMode);
  end;
end;

procedure TChatPanel.ModelComboChange(Sender: TObject);
begin
  if FModelCombo.ItemIndex >= 0 then begin
    FModel := FModelCombo.Items[FModelCombo.ItemIndex];
    if Assigned(FOnModelChange) then
      FOnModelChange(Self, FModel);
  end;
end;

procedure TChatPanel.SendBtnClick(Sender: TObject);
var
  Msg: string;
begin
  Msg := Trim(FPromptMemo.Lines.Text);
  if Msg = '' then Exit;

  FHistoryList.Items.Add('[' + WorkspaceModeCaption(FMode) + ' @ ' + FModel + ']: ' + Msg);
  FPromptMemo.Lines.Clear;

  if Assigned(FOnPrompt) then
    FOnPrompt(Self, Msg, FMode, FModel);
end;

end.
