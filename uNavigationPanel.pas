unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ComCtrls, LCLType, uAppTypes, uTheme, uCodingAgentPresets,
  uAgentExecutionLog, uAgentToolErrorLog, uNavFuturePlaceholder;

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

  { Binds designer-placed nav controls; does not create visual children. }
  TNavContentControl = class(TComponent)
  private
    FSelected: TNavigationItem;
    FTheme: TThemeKind;
    FWorkspaceName: string;
    FWorkspaceRoot: string;

    FTitleLabel: TLabel;
    FSubLabel: TLabel;
    FComingSoonLabel: TLabel;
    FFileList: TListBox;
    FTreeView: TTreeView;
    FLogList: TListBox;
    FErrorLogList: TListBox;
    FExecutionLog: TAgentExecutionLog;
    FToolErrorLog: TAgentToolErrorLog;
    FActionBtn: TButton;
    FSecondaryActionBtn: TButton;
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
    procedure ApplyNavListMetrics;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(ATitle: TLabel; ASub: TLabel; AComingSoon: TLabel; AFileList: TListBox;
      ATree: TTreeView; ALogList, AErrorLogList: TListBox; APrimaryBtn, ASecondaryBtn: TButton);
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
    procedure SetCenterAddTabAvailable(AAvailable: Boolean);

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

const
  NavListFontSize = 11;
  NavListItemHeight = 32;

constructor TNavContentControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FSelected := niHome;
  FWorkspaceIds := TStringList.Create;
  FSessionIds := TStringList.Create;
  FSessionArchived := TStringList.Create;
  FSessionTaskCaptions := TStringList.Create;
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

procedure TNavContentControl.Bind(ATitle: TLabel; ASub: TLabel; AComingSoon: TLabel;
  AFileList: TListBox; ATree: TTreeView; ALogList, AErrorLogList: TListBox;
  APrimaryBtn, ASecondaryBtn: TButton);
begin
  FTitleLabel := ATitle;
  FSubLabel := ASub;
  FComingSoonLabel := AComingSoon;
  FFileList := AFileList;
  FTreeView := ATree;
  FLogList := ALogList;
  FErrorLogList := AErrorLogList;
  FActionBtn := APrimaryBtn;
  FSecondaryActionBtn := ASecondaryBtn;

  if Assigned(FFileList) then begin
    FFileList.OnDrawItem := @FileListDrawItem;
    FFileList.OnClick := @FileListClick;
    FFileList.OnKeyDown := @FileListKeyDown;
  end;
  if Assigned(FTreeView) then begin
    FTreeView.OnDblClick := @TreeViewDblClick;
    FTreeView.OnKeyDown := @TreeViewKeyDown;
  end;
  if Assigned(FLogList) then begin
    FLogList.OnClick := @LogListClick;
    FLogList.OnDrawItem := @FileListDrawItem;
  end;
  if Assigned(FErrorLogList) then begin
    FErrorLogList.OnClick := @ErrorLogListClick;
    FErrorLogList.OnDrawItem := @FileListDrawItem;
  end;
  if Assigned(FActionBtn) then
    FActionBtn.OnClick := @ActionBtnClick;
  if Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.OnClick := @SecondaryActionBtnClick;

  ApplyNavListMetrics;
  RebuildView;
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

  FFileList.Items.BeginUpdate;
  try
    FFileList.Items.Clear;
    if Assigned(ACaptions) then
      FFileList.Items.Assign(ACaptions);
    SelIdx := -1;
    for I := 0 to FWorkspaceIds.Count - 1 do
      if SameText(FWorkspaceIds[I], AActiveId) then begin
        SelIdx := I;
        Break;
      end;
    FFileList.ItemIndex := SelIdx;
  finally
    FFileList.Items.EndUpdate;
  end;
end;

procedure TNavContentControl.SetSessionList(const ACaptions, AIds, AArchived: TStrings;
  const AActiveId: string);
var
  I, SelIdx: Integer;
begin
  FActiveSessionId := AActiveId;
  FSessionIds.Clear;
  FSessionArchived.Clear;
  if Assigned(AIds) then
    FSessionIds.Assign(AIds);
  if Assigned(AArchived) then
    FSessionArchived.Assign(AArchived);
  if FSelected <> niSessions then Exit;

  FFileList.Items.BeginUpdate;
  try
    FFileList.Items.Clear;
    if Assigned(ACaptions) then
      FFileList.Items.Assign(ACaptions);
    SelIdx := -1;
    for I := 0 to FSessionIds.Count - 1 do
      if SameText(FSessionIds[I], AActiveId) then begin
        SelIdx := I;
        Break;
      end;
    FFileList.ItemIndex := SelIdx;
  finally
    FFileList.Items.EndUpdate;
  end;
  UpdateSessionSecondaryAction;
end;

procedure TNavContentControl.UpdateSessionSecondaryAction;
var
  Idx: Integer;
  Archived: Boolean;
begin
  if not Assigned(FSecondaryActionBtn) then Exit;
  Idx := FFileList.ItemIndex;
  Archived := False;
  if (Idx >= 0) and (Idx < FSessionArchived.Count) then
    Archived := SameText(FSessionArchived[Idx], '1');
  if Archived then
    FSecondaryActionBtn.Caption := 'Restore Session'
  else
    FSecondaryActionBtn.Caption := 'Archive Session';
end;

procedure TNavContentControl.SecondaryActionBtnClick(Sender: TObject);
var
  Idx: Integer;
  Archived: Boolean;
begin
  if FSelected <> niSessions then Exit;
  Idx := FFileList.ItemIndex;
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  Archived := (Idx < FSessionArchived.Count) and SameText(FSessionArchived[Idx], '1');
  if Archived then begin
    if Assigned(FOnSessionRestore) then
      FOnSessionRestore(Self, FSessionIds[Idx]);
  end else if Assigned(FOnSessionArchive) then
    FOnSessionArchive(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.FileListClick(Sender: TObject);
var
  Idx: Integer;
begin
  if FSelected = niHome then begin
    Idx := FFileList.ItemIndex;
    if (Idx < 0) or (Idx >= FWorkspaceIds.Count) then Exit;
    if Assigned(FOnWorkspaceSelect) then
      FOnWorkspaceSelect(Self, FWorkspaceIds[Idx]);
  end else if FSelected = niSessions then begin
    Idx := FFileList.ItemIndex;
    if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
    if Assigned(FOnSessionSelect) then
      FOnSessionSelect(Self, FSessionIds[Idx]);
    UpdateSessionSecondaryAction;
  end;
end;

procedure TNavContentControl.FileListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Idx: Integer;
begin
  if Key <> VK_DELETE then Exit;
  if FSelected = niHome then begin
    Idx := FFileList.ItemIndex;
    if (Idx < 0) or (Idx >= FWorkspaceIds.Count) then Exit;
    if Assigned(FOnWorkspaceDelete) then
      FOnWorkspaceDelete(Self, FWorkspaceIds[Idx]);
  end else if FSelected = niSessions then begin
    Idx := FFileList.ItemIndex;
    if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
    if Assigned(FOnSessionDelete) then
      FOnSessionDelete(Self, FSessionIds[Idx]);
  end;
end;

procedure TNavContentControl.FileListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TNavContentControl.ApplyNavListMetrics;
begin
  if Assigned(FFileList) then begin
    ConfigureThemedListBox(FFileList, FTheme);
    FFileList.Font.Size := NavListFontSize;
    FFileList.ItemHeight := NavListItemHeight;
  end;
  if Assigned(FLogList) then begin
    ConfigureThemedListBox(FLogList, FTheme);
    FLogList.Font.Size := NavListFontSize;
    FLogList.ItemHeight := NavListItemHeight;
  end;
  if Assigned(FErrorLogList) then begin
    ConfigureThemedListBox(FErrorLogList, FTheme);
    FErrorLogList.Font.Size := NavListFontSize;
    FErrorLogList.ItemHeight := NavListItemHeight;
  end;
  if Assigned(FTreeView) then begin
    ConfigureThemedTreeView(FTreeView, FTheme);
    FTreeView.Font.Size := NavListFontSize;
    FTreeView.Options := FTreeView.Options - [tvoAutoItemHeight];
    FTreeView.DefaultItemHeight := NavListItemHeight;
  end;
end;

procedure TNavContentControl.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  if Assigned(FTitleLabel) then
    FTitleLabel.Font.Color := P.Text;
  if Assigned(FSubLabel) then
    FSubLabel.Font.Color := P.TextMuted;
  if Assigned(FComingSoonLabel) then begin
    FComingSoonLabel.Font.Style := [fsBold];
    FComingSoonLabel.Font.Color := P.Accent;
  end;
  ApplyNavListMetrics;
  if Assigned(FActionBtn) then
    StylePrimaryButton(FActionBtn, ATheme);
  if Assigned(FSecondaryActionBtn) then
    StyleCancelButton(FSecondaryActionBtn, ATheme);
end;

procedure TNavContentControl.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  if Assigned(FFileList) then
    ApplyPlatformScrollableTheme(FFileList, ATheme);
  if Assigned(FTreeView) then
    ApplyPlatformScrollableTheme(FTreeView, ATheme);
  if Assigned(FLogList) then
    ApplyPlatformScrollableTheme(FLogList, ATheme);
  if Assigned(FErrorLogList) then
    ApplyPlatformScrollableTheme(FErrorLogList, ATheme);
end;

procedure TNavContentControl.SetSelected(AItem: TNavigationItem; const AWorkspaceName,
  AWorkspaceRoot: string);
begin
  FSelected := AItem;
  FWorkspaceName := AWorkspaceName;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := AWorkspaceRoot;
  RebuildView;
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
        if (Rec.Name = '.') or (Rec.Name = '..') or (Rec.Name = '.git') or (Rec.Name = 'lib') or
           (Rec.Name = 'backup') then
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
    niMultiAgent, niExecutionPlans, niKnowledgeBase, niTheBrain:
      ;
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
  if not Assigned(FFileList) then Exit;
  FFileList.Visible := False;
  if Assigned(FTreeView) then FTreeView.Visible := False;
  if Assigned(FLogList) then FLogList.Visible := False;
  if Assigned(FErrorLogList) then FErrorLogList.Visible := False;
  if (FSelected <> niSessions) and Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.Visible := False;
  if Assigned(FActionBtn) then
    FActionBtn.Visible := True;
  if Assigned(FComingSoonLabel) then
    FComingSoonLabel.Visible := False;

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
    niMultiAgent, niExecutionPlans, niKnowledgeBase, niTheBrain:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := NavigationFutureFeatureTitle(FSelected);
        FSubLabel.Caption := 'Roadmap preview — functionality not available yet.';
        if Assigned(FComingSoonLabel) then begin
          FComingSoonLabel.Caption := 'COMING SOON';
          FComingSoonLabel.Visible := True;
        end;
        PopulateFutureFeatureNavList(FSelected, FFileList.Items);
        FActionBtn.Visible := False;
      end;
  end;
end;

procedure TNavContentControl.SetCenterAddTabAvailable(AAvailable: Boolean);
begin
  { Reserved: center tab [+] mirrors new-session when chat panel is visible. }
  if not Assigned(FActionBtn) then Exit;
  if FSelected = niSessions then
    FActionBtn.Enabled := AAvailable;
end;

end.
