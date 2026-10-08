unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ComCtrls, LCLType, uAppTypes, uTheme, uThemedButton, uAppLogo, uCodingAgentPresets,
  uAgentExecutionLog, uAgentToolErrorLog;

type
  TNavWorkspaceSelectEvent = procedure(Sender: TObject; const AWorkspaceId: string) of object;
  TNavWorkspaceActionEvent = procedure(Sender: TObject) of object;
  TNavWorkspaceDeleteEvent = procedure(Sender: TObject; const AWorkspaceId: string) of object;
  TNavSessionSelectEvent = procedure(Sender: TObject; const ASessionId: string) of object;
  TNavSessionActionEvent = procedure(Sender: TObject) of object;
  TNavSessionArchiveEvent = procedure(Sender: TObject; const ASessionId: string) of object;
  TNavFileOpenEvent = procedure(Sender: TObject; const AFilePath: string) of object;
  TNavLogEntrySelectedEvent = procedure(Sender: TObject; AIndex: Integer) of object;
  TNavExecutionLogClearEvent = procedure(Sender: TObject) of object;
  TNavToolErrorLogClearEvent = procedure(Sender: TObject) of object;

type
  { TNavRailControl - Left sleek icon bar }
  TNavRailControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FHovered: Integer;
    FPressedIndex: Integer;
    FTheme: TThemeKind;
    FOnSelect: TNotifyEvent;
    function GetItemRect(AIndex: Integer): TRect;
    function HitTestItemIndex(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem);
    property Selected: TNavigationItem read FSelected write SetSelected;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
  end;

  { TNavContentControl - Content panel hosting views inside the Nav Dock Host }
  TNavContentControl = class(TCustomControl)
  private
    FSelected: TNavigationItem;
    FTheme: TThemeKind;
    FWorkspaceName: string;
    FWorkspaceRoot: string;

    // Sub-controls
    FTitleLabel: TLabel;
    FSubLabel: TLabel;
    FFileList: TListBox;
    FTreeView: TTreeView;
    FLogList: TListBox;
    FErrorLogList: TListBox;
    FExecutionLog: TAgentExecutionLog;
    FToolErrorLog: TAgentToolErrorLog;
    FActionBtn: TThemedButton;
    FSecondaryActionBtn: TThemedButton;
    FWorkspaceIds: TStringList;
    FSessionIds: TStringList;
    FSessionArchived: TStringList;
    FActiveWorkspaceId: string;
    FActiveSessionId: string;
    FLastPopulatedRoot: string;
    FSessionTaskCaptions: TStringList;

    FOnWorkspaceSelect: TNavWorkspaceSelectEvent;
    FOnWorkspaceNew: TNavWorkspaceActionEvent;
    FOnWorkspaceDelete: TNavWorkspaceDeleteEvent;
    FOnSessionSelect: TNavSessionSelectEvent;
    FOnSessionNew: TNavSessionActionEvent;
    FOnSessionArchive: TNavSessionArchiveEvent;
    FOnSessionRestore: TNavSessionArchiveEvent;
    FOnSessionDelete: TNavSessionArchiveEvent;
    FOnFileOpen: TNavFileOpenEvent;
    FOnLogEntrySelected: TNavLogEntrySelectedEvent;
    FOnClearExecutionLog: TNavExecutionLogClearEvent;
    FOnClearToolErrorLog: TNavToolErrorLogClearEvent;
    FOnToolErrorEntrySelected: TNavLogEntrySelectedEvent;
    FOnTasksRefresh: TNotifyEvent;

    procedure ActionBtnClick(Sender: TObject);
    procedure FillTaskListBox;
    procedure LogListClick(Sender: TObject);
    procedure ErrorLogListClick(Sender: TObject);
    procedure SecondaryActionBtnClick(Sender: TObject);
    procedure UpdateSessionSecondaryAction;
    procedure FileListClick(Sender: TObject);
    procedure FileListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FileListDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure PopulateFileTree(const ARoot: string);
    procedure FreeFileTreeNodePaths;
    procedure TreeViewDblClick(Sender: TObject);
    procedure TreeViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TryOpenSelectedTreeFile;
    procedure RebuildView;
    procedure MaybePopulateProjectsTree;
    procedure UpdateLayout;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
    procedure SetWorkspaceList(const ACaptions, AIds: TStrings; const AActiveId: string);
    procedure SetSessionList(const ACaptions, AIds, AArchived: TStrings; const AActiveId: string);
    procedure BindExecutionLog(ALog: TAgentExecutionLog);
    procedure RefreshExecutionLogList;
    procedure AppendExecutionLogEntry(AIndex: Integer);
    procedure BindToolErrorLog(ALog: TAgentToolErrorLog);
    procedure RefreshToolErrorLogList;
    procedure AppendToolErrorLogEntry(AIndex: Integer);
    procedure UpdateSessionTasks(const ACaptions: TStrings);
    destructor Destroy; override;

    property OnWorkspaceSelect: TNavWorkspaceSelectEvent read FOnWorkspaceSelect write FOnWorkspaceSelect;
    property OnWorkspaceNew: TNavWorkspaceActionEvent read FOnWorkspaceNew write FOnWorkspaceNew;
    property OnWorkspaceDelete: TNavWorkspaceDeleteEvent read FOnWorkspaceDelete write FOnWorkspaceDelete;
    property OnSessionSelect: TNavSessionSelectEvent read FOnSessionSelect write FOnSessionSelect;
    property OnSessionNew: TNavSessionActionEvent read FOnSessionNew write FOnSessionNew;
    property OnSessionArchive: TNavSessionArchiveEvent read FOnSessionArchive write FOnSessionArchive;
    property OnSessionRestore: TNavSessionArchiveEvent read FOnSessionRestore write FOnSessionRestore;
    property OnSessionDelete: TNavSessionArchiveEvent read FOnSessionDelete write FOnSessionDelete;
    property OnFileOpen: TNavFileOpenEvent read FOnFileOpen write FOnFileOpen;
    property OnLogEntrySelected: TNavLogEntrySelectedEvent read FOnLogEntrySelected
      write FOnLogEntrySelected;
    property OnClearExecutionLog: TNavExecutionLogClearEvent read FOnClearExecutionLog
      write FOnClearExecutionLog;
    property OnClearToolErrorLog: TNavToolErrorLogClearEvent read FOnClearToolErrorLog
      write FOnClearToolErrorLog;
    property OnToolErrorEntrySelected: TNavLogEntrySelectedEvent read FOnToolErrorEntrySelected
      write FOnToolErrorEntrySelected;
    property OnTasksRefresh: TNotifyEvent read FOnTasksRefresh write FOnTasksRefresh;
  end;

implementation

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

procedure GetRailItemStyle(P: TThemePalette; ASelected, AHover, APressed: Boolean;
  out DrawEdgeMarker: Boolean; out IconColor: TColor);
begin
  DrawEdgeMarker := False;
  if ASelected then begin
    DrawEdgeMarker := True;
    IconColor := P.Accent;
    if APressed then
      IconColor := P.AccentHover;
  end else if AHover or APressed then
    IconColor := P.Text
  else
    IconColor := P.TextMuted;
end;

{ TNavRailControl }

constructor TNavRailControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 56;
  FSelected := niHome;
  FHovered := -1;
  FPressedIndex := -1;
  FTheme := tkDark;
  ShowHint := True;
end;

procedure TNavRailControl.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Invalidate;
end;

procedure TNavRailControl.SetSelected(AItem: TNavigationItem);
begin
  if FSelected <> AItem then begin
    FSelected := AItem;
    Invalidate;
  end;
end;

function TNavRailControl.GetItemRect(AIndex: Integer): TRect;
const
  ItemH = 40;
  ItemGap = 2;
begin
  Result := Rect(6, 48 + AIndex * (ItemH + ItemGap), Width - 6,
    48 + (AIndex + 1) * (ItemH + ItemGap) - ItemGap);
end;

function TNavRailControl.HitTestItemIndex(X, Y: Integer): Integer;
var
  I: Integer;
  Item: TNavigationItem;
begin
  Result := -1;
  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    if GetItemRect(I).Contains(Point(X, Y)) then
      Exit(I);
    Inc(I);
  end;
end;

procedure TNavRailControl.Paint;
var
  P: TThemePalette;
  Item: TNavigationItem;
  I: Integer;
  R, MarkerR: TRect;
  Sym: string;
  DrawEdgeMarker: Boolean;
  IconColor: TColor;
  IsSelected, IsHover, IsPressed: Boolean;
  IconY: Integer;
begin
  P := ThemePalette(FTheme);

  Canvas.Brush.Color := P.RailBg;
  Canvas.FillRect(ClientRect);

  Canvas.Pen.Color := P.Border;
  Canvas.Line(Width - 1, 0, Width - 1, Height);

  DrawLazyAgentLogo(Canvas, Rect(12, 10, 44, 42), FTheme = tkDark);

  I := 0;
  for Item := Low(TNavigationItem) to High(TNavigationItem) do begin
    R := GetItemRect(I);
    Sym := NavigationIconSymbol(Item);

    IsSelected := Item = FSelected;
    IsHover := I = FHovered;
    IsPressed := I = FPressedIndex;
    GetRailItemStyle(P, IsSelected, IsHover, IsPressed, DrawEdgeMarker, IconColor);

    if DrawEdgeMarker then begin
      Canvas.Brush.Color := P.Accent;
      MarkerR := Rect(0, R.Top + 8, 2, R.Bottom - 8);
      Canvas.FillRect(MarkerR);
    end;

    Canvas.Font.Style := [];
    Canvas.Font.Size := 16;
    Canvas.Font.Name := 'Segoe UI Symbol';
    Canvas.Font.Color := IconColor;
    IconY := R.Top + (R.Height - Canvas.TextHeight(Sym)) div 2;
    Canvas.Brush.Color := P.RailBg;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(R.Left + (R.Width - Canvas.TextWidth(Sym)) div 2, IconY, Sym);

    Inc(I);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TNavRailControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewHover := HitTestItemIndex(X, Y);
  if NewHover >= 0 then
    Hint := NavigationHint(TNavigationItem(NewHover));

  if NewHover <> FHovered then begin
    FHovered := NewHover;
    Invalidate;
  end;
end;

procedure TNavRailControl.MouseLeave;
begin
  inherited MouseLeave;
  if FHovered <> -1 then begin
    FHovered := -1;
    Invalidate;
  end;
end;

procedure TNavRailControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  HitIndex: Integer;
  Item: TNavigationItem;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  HitIndex := HitTestItemIndex(X, Y);
  if HitIndex < 0 then Exit;

  FPressedIndex := HitIndex;
  MouseCapture := True;
  Invalidate;

  Item := TNavigationItem(HitIndex);
  SetSelected(Item);
  if Assigned(FOnSelect) then
    FOnSelect(Self);
end;

procedure TNavRailControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  if FPressedIndex <> -1 then begin
    FPressedIndex := -1;
    MouseCapture := False;
    Invalidate;
  end;
end;

{ TNavContentControl }

constructor TNavContentControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FTheme := tkDark;
  FSelected := niHome;
  FWorkspaceName := '';
  FWorkspaceRoot := '';
  FWorkspaceIds := TStringList.Create;
  FSessionIds := TStringList.Create;
  FSessionArchived := TStringList.Create;
  FActiveWorkspaceId := '';
  FActiveSessionId := '';
  FLastPopulatedRoot := '';
  FSessionTaskCaptions := TStringList.Create;

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := Self;
  FTitleLabel.AutoSize := False;
  FTitleLabel.Font.Size := 11;
  FTitleLabel.Font.Style := [fsBold];

  FSubLabel := TLabel.Create(Self);
  FSubLabel.Parent := Self;
  FSubLabel.AutoSize := False;
  FSubLabel.Font.Size := 8;

  FFileList := TListBox.Create(Self);
  FFileList.Parent := Self;
  FFileList.OnDrawItem := @FileListDrawItem;
  FFileList.OnClick := @FileListClick;
  FFileList.OnKeyDown := @FileListKeyDown;
  ConfigureThemedListBox(FFileList, FTheme);

  FTreeView := TTreeView.Create(Self);
  FTreeView.Parent := Self;
  FTreeView.ReadOnly := True;
  FTreeView.Visible := False;
  FTreeView.OnDblClick := @TreeViewDblClick;
  FTreeView.OnKeyDown := @TreeViewKeyDown;
  ConfigureThemedTreeView(FTreeView, FTheme);

  FLogList := TListBox.Create(Self);
  FLogList.Parent := Self;
  FLogList.Visible := False;
  FLogList.OnClick := @LogListClick;
  FLogList.OnDrawItem := @FileListDrawItem;
  ConfigureThemedListBox(FLogList, FTheme);
  FExecutionLog := nil;

  FErrorLogList := TListBox.Create(Self);
  FErrorLogList.Parent := Self;
  FErrorLogList.Visible := False;
  FErrorLogList.OnClick := @ErrorLogListClick;
  FErrorLogList.OnDrawItem := @FileListDrawItem;
  ConfigureThemedListBox(FErrorLogList, FTheme);
  FToolErrorLog := nil;

  FActionBtn := TThemedButton.Create(Self);
  FActionBtn.Parent := Self;
  FActionBtn.Height := 28;
  FActionBtn.ButtonRole := tbrPrimary;
  FActionBtn.OnClick := @ActionBtnClick;

  FSecondaryActionBtn := TThemedButton.Create(Self);
  FSecondaryActionBtn.Parent := Self;
  FSecondaryActionBtn.Height := 28;
  FSecondaryActionBtn.ButtonRole := tbrCancel;
  FSecondaryActionBtn.Visible := False;
  FSecondaryActionBtn.OnClick := @SecondaryActionBtnClick;

  UpdateLayout;
  RebuildView;
end;

destructor TNavContentControl.Destroy;
begin
  FreeFileTreeNodePaths;
  FWorkspaceIds.Free;
  FSessionIds.Free;
  FSessionArchived.Free;
  FSessionTaskCaptions.Free;
  inherited Destroy;
end;

procedure TNavContentControl.SetWorkspaceList(const ACaptions, AIds: TStrings; const AActiveId: string);
var
  I, SelIdx: Integer;
begin
  FActiveWorkspaceId := AActiveId;
  FWorkspaceIds.Clear;
  if Assigned(ACaptions) and Assigned(AIds) then begin
    for I := 0 to ACaptions.Count - 1 do begin
      if I >= AIds.Count then Break;
      FWorkspaceIds.Add(AIds[I]);
    end;
  end;
  if FSelected <> niHome then Exit;

  FFileList.Items.Clear;
  SelIdx := -1;
  if Assigned(ACaptions) and Assigned(AIds) then begin
    for I := 0 to ACaptions.Count - 1 do begin
      if I >= AIds.Count then Break;
      FFileList.Items.Add(ACaptions[I]);
      if SameText(AIds[I], AActiveId) then
        SelIdx := I;
    end;
  end;
  if (SelIdx >= 0) and (SelIdx < FFileList.Items.Count) then
    FFileList.ItemIndex := SelIdx;
end;

procedure TNavContentControl.SetSessionList(const ACaptions, AIds, AArchived: TStrings;
  const AActiveId: string);
var
  I, SelIdx: Integer;
begin
  FActiveSessionId := AActiveId;
  FSessionIds.Clear;
  FSessionArchived.Clear;
  if Assigned(ACaptions) and Assigned(AIds) then begin
    for I := 0 to ACaptions.Count - 1 do begin
      if I >= AIds.Count then Break;
      FSessionIds.Add(AIds[I]);
      if Assigned(AArchived) and (I < AArchived.Count) then
        FSessionArchived.Add(AArchived[I])
      else
        FSessionArchived.Add('0');
    end;
  end;
  if FSelected <> niSessions then Exit;

  FFileList.Items.Clear;
  SelIdx := -1;
  if Assigned(ACaptions) and Assigned(AIds) then begin
    for I := 0 to ACaptions.Count - 1 do begin
      if I >= AIds.Count then Break;
      FFileList.Items.Add(ACaptions[I]);
      if (AIds[I] <> '') and SameText(AIds[I], AActiveId) then
        SelIdx := I;
    end;
  end;
  if (SelIdx >= 0) and (SelIdx < FFileList.Items.Count) then
    FFileList.ItemIndex := SelIdx;
  FSecondaryActionBtn.Visible := True;
  UpdateSessionSecondaryAction;
end;

procedure TNavContentControl.UpdateSessionSecondaryAction;
var
  Idx: Integer;
  Archived: Boolean;
begin
  if FSelected <> niSessions then begin
    FSecondaryActionBtn.Visible := False;
    Exit;
  end;
  FSecondaryActionBtn.Visible := True;
  Idx := FFileList.ItemIndex;
  if (Idx < 0) or (Idx >= FSessionIds.Count) or (FSessionIds[Idx] = '') then begin
    FSecondaryActionBtn.Caption := 'Archive Session';
    FSecondaryActionBtn.Enabled := False;
    Exit;
  end;
  Archived := (Idx < FSessionArchived.Count) and (FSessionArchived[Idx] = '1');
  FSecondaryActionBtn.Enabled := True;
  if Archived then begin
    FSecondaryActionBtn.Caption := 'Restore Session';
    FSecondaryActionBtn.ButtonRole := tbrCancel;
  end else begin
    FSecondaryActionBtn.Caption := 'Archive Session';
    FSecondaryActionBtn.ButtonRole := tbrCancel;
  end;
end;

procedure TNavContentControl.SecondaryActionBtnClick(Sender: TObject);
var
  Idx: Integer;
  Sid: string;
  Archived: Boolean;
begin
  if FSelected <> niSessions then Exit;
  Idx := FFileList.ItemIndex;
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  Sid := FSessionIds[Idx];
  if Sid = '' then Exit;
  Archived := (Idx < FSessionArchived.Count) and (FSessionArchived[Idx] = '1');
  if Archived then begin
    if Assigned(FOnSessionRestore) then
      FOnSessionRestore(Self, Sid);
  end else if Assigned(FOnSessionArchive) then
    FOnSessionArchive(Self, Sid);
end;

procedure TNavContentControl.FileListClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FFileList.ItemIndex;
  if Idx < 0 then Exit;
  case FSelected of
    niHome:
      if (Idx < FWorkspaceIds.Count) and Assigned(FOnWorkspaceSelect) then
        FOnWorkspaceSelect(Self, FWorkspaceIds[Idx]);
    niSessions:
      if (Idx < FSessionIds.Count) and (FSessionIds[Idx] <> '') and Assigned(FOnSessionSelect) then
        FOnSessionSelect(Self, FSessionIds[Idx]);
  end;
  if FSelected = niSessions then
    UpdateSessionSecondaryAction;
end;

procedure TNavContentControl.FileListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Idx: Integer;
begin
  if Key <> VK_DELETE then Exit;
  Idx := FFileList.ItemIndex;
  if Idx < 0 then Exit;
  if FSelected = niHome then begin
    if (Idx < FWorkspaceIds.Count) and Assigned(FOnWorkspaceDelete) then
      FOnWorkspaceDelete(Self, FWorkspaceIds[Idx]);
    Exit;
  end;
  if FSelected <> niSessions then Exit;
  if (Idx >= FSessionIds.Count) or (FSessionIds[Idx] = '') then Exit;
  if ssShift in Shift then begin
    if Assigned(FOnSessionDelete) then
      FOnSessionDelete(Self, FSessionIds[Idx]);
  end else if (Idx < FSessionArchived.Count) and (FSessionArchived[Idx] = '1') then begin
    if Assigned(FOnSessionDelete) then
      FOnSessionDelete(Self, FSessionIds[Idx]);
  end else if Assigned(FOnSessionArchive) then
    FOnSessionArchive(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.CreateWnd;
begin
  inherited CreateWnd;
  UpdateLayout;
end;

procedure TNavContentControl.UpdateLayout;
var
  W, H, ListH: Integer;
begin
  if not ParentFormHandlesReady(Self) then Exit;
  W := MaxLayoutDim(Width - 24, 8);
  H := Height;
  if (FSelected = niSessions) and FSecondaryActionBtn.Visible then
    ListH := MaxLayoutDim(H - 148, 8)
  else
    ListH := MaxLayoutDim(H - 110, 8);

  SetBoundsIfChanged(FTitleLabel, 12, 12, W, 22);
  SetBoundsIfChanged(FSubLabel, 12, 36, W, 18);
  SetBoundsIfChanged(FFileList, 12, 60, W, ListH);
  SetBoundsIfChanged(FTreeView, 12, 60, W, ListH);
  SetBoundsIfChanged(FLogList, 12, 60, W, ListH);
  SetBoundsIfChanged(FErrorLogList, 12, 60, W, ListH);

  if H > 80 then begin
    if (FSelected = niSessions) and FSecondaryActionBtn.Visible then begin
      SetBoundsIfChanged(FSecondaryActionBtn, 12, H - 76, W, 28);
      SetBoundsIfChanged(FActionBtn, 12, H - 40, W, 28);
    end else begin
      SetBoundsIfChanged(FSecondaryActionBtn, 12, H - 76, W, 0);
      SetBoundsIfChanged(FActionBtn, 12, H - 40, W, 28);
    end;
  end else
    SetBoundsIfChanged(FActionBtn, 12, 10, W, 28);
end;

procedure TNavContentControl.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TNavContentControl.FileListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TNavContentControl.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.Surface;
  FTitleLabel.Font.Color := P.Text;
  FSubLabel.Font.Color := P.TextMuted;

  ConfigureThemedListBox(FFileList, FTheme);
  ConfigureThemedTreeView(FTreeView, FTheme);

  ConfigureThemedListBox(FLogList, FTheme);
  ConfigureThemedListBox(FErrorLogList, FTheme);

  if Assigned(FActionBtn) then
    FActionBtn.ApplyTheme(FTheme);
  if Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.ApplyTheme(FTheme);

  Invalidate;
end;

procedure TNavContentControl.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  ApplyPlatformScrollableTheme(FFileList, ATheme);
  ApplyPlatformScrollableTheme(FTreeView, ATheme);
  ApplyPlatformScrollableTheme(FLogList, ATheme);
  ApplyPlatformScrollableTheme(FErrorLogList, ATheme);
end;

procedure TNavContentControl.SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
begin
  FSelected := AItem;
  FWorkspaceName := AWorkspaceName;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := AWorkspaceRoot;
  RebuildView;
  Invalidate;
end;

procedure TNavContentControl.BindExecutionLog(ALog: TAgentExecutionLog);
begin
  FExecutionLog := ALog;
  RefreshExecutionLogList;
end;

procedure TNavContentControl.RefreshExecutionLogList;
var
  I: Integer;
begin
  if not Assigned(FLogList) then Exit;
  FLogList.Items.Clear;
  if not Assigned(FExecutionLog) then Exit;
  for I := 0 to FExecutionLog.Count - 1 do
    FLogList.Items.Add(FExecutionLog.Entry(I).Caption);
end;

procedure TNavContentControl.AppendExecutionLogEntry(AIndex: Integer);
begin
  if not Assigned(FExecutionLog) or not Assigned(FLogList) then Exit;
  if (AIndex < 0) or (AIndex >= FExecutionLog.Count) then Exit;
  if FLogList.Items.Count <> FExecutionLog.Count then
    RefreshExecutionLogList
  else
    FLogList.Items[AIndex] := FExecutionLog.Entry(AIndex).Caption;
  if AIndex < FLogList.Items.Count then
    FLogList.ItemIndex := AIndex;
end;

procedure TNavContentControl.LogListClick(Sender: TObject);
begin
  if not Assigned(FOnLogEntrySelected) then Exit;
  if FLogList.ItemIndex < 0 then Exit;
  FOnLogEntrySelected(Self, FLogList.ItemIndex);
end;

procedure TNavContentControl.ErrorLogListClick(Sender: TObject);
begin
  if not Assigned(FOnToolErrorEntrySelected) then Exit;
  if FErrorLogList.ItemIndex < 0 then Exit;
  FOnToolErrorEntrySelected(Self, FErrorLogList.ItemIndex);
end;

procedure TNavContentControl.BindToolErrorLog(ALog: TAgentToolErrorLog);
begin
  FToolErrorLog := ALog;
  RefreshToolErrorLogList;
end;

procedure TNavContentControl.RefreshToolErrorLogList;
var
  I: Integer;
begin
  if not Assigned(FErrorLogList) then Exit;
  FErrorLogList.Items.Clear;
  if not Assigned(FToolErrorLog) then Exit;
  for I := 0 to FToolErrorLog.Count - 1 do
    FErrorLogList.Items.Add(FToolErrorLog.Entry(I).Caption);
end;

procedure TNavContentControl.AppendToolErrorLogEntry(AIndex: Integer);
begin
  if not Assigned(FToolErrorLog) or not Assigned(FErrorLogList) then Exit;
  if (AIndex < 0) or (AIndex >= FToolErrorLog.Count) then Exit;
  if FErrorLogList.Items.Count <> FToolErrorLog.Count then
    RefreshToolErrorLogList
  else
    FErrorLogList.Items[AIndex] := FToolErrorLog.Entry(AIndex).Caption;
  if AIndex < FErrorLogList.Items.Count then
    FErrorLogList.ItemIndex := AIndex;
end;

procedure TNavContentControl.FreeFileTreeNodePaths;
var
  N: TTreeNode;
begin
  if not Assigned(FTreeView) then Exit;
  N := FTreeView.Items.GetFirstNode;
  while N <> nil do begin
    if N.Data <> nil then begin
      StrDispose(PChar(N.Data));
      N.Data := nil;
    end;
    N := N.GetNext;
  end;
end;

procedure TNavContentControl.TryOpenSelectedTreeFile;
var
  N: TTreeNode;
  Path: string;
begin
  if not Assigned(FTreeView) then Exit;
  N := FTreeView.Selected;
  if (N = nil) or (N.Data = nil) then Exit;
  Path := string(PChar(N.Data));
  if (Path <> '') and Assigned(FOnFileOpen) then
    FOnFileOpen(Self, Path);
end;

procedure TNavContentControl.TreeViewDblClick(Sender: TObject);
begin
  if FSelected = niProjects then
    TryOpenSelectedTreeFile;
end;

procedure TNavContentControl.TreeViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (FSelected = niProjects) then
    TryOpenSelectedTreeFile;
end;

procedure TNavContentControl.PopulateFileTree(const ARoot: string);
var
  RootNode: TTreeNode;

  procedure AddFolder(AParentNode: TTreeNode; const ADir: string);
  var
    Rec: TSearchRec;
    ChildNode: TTreeNode;
    FullPath: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, Rec) = 0 then begin
      repeat
        if (Rec.Name = '.') or (Rec.Name = '..') or (Rec.Name = '.git') or (Rec.Name = 'lib') or (Rec.Name = 'backup') then
          Continue;

        if (Rec.Attr and faDirectory) <> 0 then begin
          ChildNode := FTreeView.Items.AddChild(AParentNode, '📁 ' + Rec.Name);
          AddFolder(ChildNode, IncludeTrailingPathDelimiter(ADir) + Rec.Name);
        end else begin
          FullPath := IncludeTrailingPathDelimiter(ADir) + Rec.Name;
          ChildNode := FTreeView.Items.AddChild(AParentNode, '📄 ' + Rec.Name);
          ChildNode.Data := StrNew(PChar(FullPath));
        end;
      until FindNext(Rec) <> 0;
      FindClose(Rec);
    end;
  end;

begin
  FreeFileTreeNodePaths;
  FTreeView.Items.Clear;
  RootNode := FTreeView.Items.Add(nil, '📦 ' + ExtractFileName(ARoot));
  AddFolder(RootNode, ARoot);
  RootNode.Expand(False);
end;

procedure TNavContentControl.ActionBtnClick(Sender: TObject);
var
  Dir: string;
begin
  case FSelected of
    niHome:
      if Assigned(FOnWorkspaceNew) then
        FOnWorkspaceNew(Self);
    niProjects:
      begin
        if Trim(FWorkspaceRoot) = '' then begin
          ShowMessage('Select a workspace first.');
          Exit;
        end;
        PopulateFileTree(FWorkspaceRoot);
        FLastPopulatedRoot := FWorkspaceRoot;
      end;
    niSessions:
      if Assigned(FOnSessionNew) then
        FOnSessionNew(Self);
    niBots:
      ShowMessage('Configure Agent Models in Settings menu.');
    niTools:
      if Assigned(FOnClearExecutionLog) then
        FOnClearExecutionLog(Self);
    niTasks:
      begin
        if Assigned(FOnTasksRefresh) then
          FOnTasksRefresh(Self);
        FillTaskListBox;
      end;
    niToolErrors:
      if Assigned(FOnClearToolErrorLog) then
        FOnClearToolErrorLog(Self);
  end;
end;

procedure TNavContentControl.MaybePopulateProjectsTree;
var
  Root: string;
begin
  Root := Trim(FWorkspaceRoot);
  if Root = '' then Exit;
  if (FTreeView.Items.Count = 0) or not SameText(Root, FLastPopulatedRoot) then begin
    PopulateFileTree(Root);
    FLastPopulatedRoot := Root;
  end;
end;

procedure TNavContentControl.FillTaskListBox;
begin
  if not Assigned(FFileList) then Exit;
  FFileList.Items.Assign(FSessionTaskCaptions);
end;

procedure TNavContentControl.UpdateSessionTasks(const ACaptions: TStrings);
begin
  FSessionTaskCaptions.Clear;
  if Assigned(ACaptions) then
    FSessionTaskCaptions.Assign(ACaptions);
  if FSelected = niTasks then
    FillTaskListBox;
end;

procedure TNavContentControl.RebuildView;
var
  I: Integer;
  Preset: TCodingAgentPreset;
begin
  FFileList.Visible := False;
  FTreeView.Visible := False;
  FLogList.Visible := False;
  FErrorLogList.Visible := False;
  if FSelected <> niSessions then
    FSecondaryActionBtn.Visible := False;

  case FSelected of
    niHome:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Workspaces';
        if FWorkspaceIds.Count = 0 then
          FSubLabel.Caption := 'No workspace yet — create or open a project folder.'
        else
          FSubLabel.Caption := 'Select a workspace to switch. Active: ' + FWorkspaceName;
        FActionBtn.Caption := '+ New Workspace';
      end;
    niProjects:
      begin
        FTreeView.Visible := True;
        FTitleLabel.Caption := 'Project Explorer';
        if Trim(FWorkspaceRoot) = '' then
          FSubLabel.Caption := 'No project folder (select a workspace)'
        else
          FSubLabel.Caption := 'Workspace Tree';
        MaybePopulateProjectsTree;
        ConfigureThemedTreeView(FTreeView, FTheme);
        FTreeView.Invalidate;
        FActionBtn.Caption := '↻ Refresh Tree';
      end;
    niSessions:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Chat Sessions';
        if Trim(FWorkspaceName) = '' then
          FSubLabel.Caption := 'Select a workspace to manage sessions'
        else
          FSubLabel.Caption := 'History for ' + FWorkspaceName;
        FActionBtn.Caption := '+ New Chat Session';
        FSecondaryActionBtn.Visible := True;
        UpdateSessionSecondaryAction;
      end;
    niBots:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Coding Agent Personas';
        FSubLabel.Caption := 'Modes & pre-defined models (OpenRouter)';
        FFileList.Items.Clear;
        FFileList.Items.Add('⚡ Autopilot Agent (wmAgent)');
        FFileList.Items.Add('📋 Architect & Planner (wmPlan)');
        FFileList.Items.Add('💡 Code Assistant & Q&A (wmAsk)');
        FFileList.Items.Add('');
        FFileList.Items.Add('── Pre-defined coding agents ──');
        for I := 0 to CodingAgentPresetCount - 1 do begin
          Preset := GetCodingAgentPreset(I);
          FFileList.Items.Add(Format('🧠 %s — %s (%s)', [Preset.Vendor, Preset.Caption, Preset.ModelId]));
        end;
        FActionBtn.Caption := '⚙ Agent Settings...';
      end;
    niTools:
      begin
        FLogList.Visible := True;
        FTitleLabel.Caption := 'Tool Execution & Logs';
        FSubLabel.Caption := 'Click an entry to inspect full prompt / tool I/O';
        FSubLabel.Hint := '';
        FActionBtn.Caption := '🗑 Clear Tool Logs';
        RefreshExecutionLogList;
      end;
    niToolErrors:
      begin
        FErrorLogList.Visible := True;
        FTitleLabel.Caption := 'Tool Errors';
        FSubLabel.Caption := TruncateLogCaption(ToolErrorLogFilePath, 72);
        FSubLabel.Hint := ToolErrorLogFilePath;
        FSubLabel.ShowHint := True;
        FActionBtn.Caption := '🗑 Clear Session Errors';
        RefreshToolErrorLogList;
      end;
    niTasks:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Task List & Checklist';
        FSubLabel.Caption := 'Chat-local tasks from the todo tool';
        FillTaskListBox;
        if FFileList.Items.Count = 0 then
          FFileList.Items.Add('No tasks tracked for this session.');
        FActionBtn.Caption := '🔄 Refresh Tasks';
      end;
  end;
  UpdateLayout;
end;

end.
                                                                                      