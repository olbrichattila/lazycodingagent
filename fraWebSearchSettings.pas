unit fraWebSearchSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls, LcaPaintButton,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uWebSearchTypes, uWebSearchConfig, uWebSearchSecrets,
  uWebSearchManager, uWebSearchHttp;

type
  { TWebSearchSettingsFrame }
  TWebSearchSettingsFrame = class(TFrame)
    scrWebSearch: TScrollBox;
    pnlWebSearchContent: TPanel;
    pnlWebSearchHeader: TPanel;
    pnlConnections: TPanel;
    pnlWebSearchFooter: TPanel;
    pnlConnButtons: TPanel;
    lblWebSearchTitle: TLabel;
    chkWebSearchEnabled: TCheckBox;
    lblMaxResults: TLabel;
    edtMaxResults: TEdit;
    lblTotalTimeout: TLabel;
    edtTotalTimeoutSec: TEdit;
    chkAutoFallback: TCheckBox;
    chkFallbackEmpty: TCheckBox;
    chkAllowPrivateInstances: TCheckBox;
    lblConnections: TLabel;
    lvConnections: TListView;
    btnAddConn: TLcaPaintButton;
    btnEditConn: TLcaPaintButton;
    btnRemoveConn: TLcaPaintButton;
    btnTestConn: TLcaPaintButton;
    btnMoveUp: TLcaPaintButton;
    btnMoveDown: TLcaPaintButton;
    lblTestNote: TLabel;
    memoConnStatus: TMemo;
    procedure btnAddConnClick(Sender: TObject);
    procedure btnEditConnClick(Sender: TObject);
    procedure btnRemoveConnClick(Sender: TObject);
    procedure btnTestConnClick(Sender: TObject);
    procedure btnMoveUpClick(Sender: TObject);
    procedure btnMoveDownClick(Sender: TObject);
    procedure lvConnectionsResize(Sender: TObject);
  private
    FTheme: TThemeKind;
    FConfig: TWebSearchGlobalConfig;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure AdjustConnectionListColumns;
    procedure RefreshConnectionList;
    function SelectedConnectionIndex: Integer;
    procedure RenumberPriorities;
    procedure ApplyUiToConfig;
  public
    procedure LoadSettings;
    procedure SaveSettings;
    procedure InitTheme(ATheme: TThemeKind);
  end;

implementation

{$R *.lfm}

uses
  frmWebSearchConnection;

procedure TWebSearchSettingsFrame.InitTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyTheme(ATheme);
end;

procedure TWebSearchSettingsFrame.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  if not ParentFormHandlesReady(Self) then
    Exit;
  scrWebSearch.Color := P.Background;
  pnlWebSearchContent.Color := P.Background;
  pnlWebSearchHeader.Color := P.Background;
  pnlConnections.Color := P.Background;
  pnlWebSearchFooter.Color := P.Background;
  pnlConnButtons.Color := P.Background;
  memoConnStatus.Color := P.SurfaceAlt;
  memoConnStatus.Font.Color := P.Text;
  edtMaxResults.Color := P.SurfaceAlt;
  edtTotalTimeoutSec.Color := P.SurfaceAlt;
  ApplyThemedControlTree(Self, ATheme);
  lvConnections.Color := P.SurfaceAlt;
  lvConnections.Font.Color := P.Text;
end;

procedure TWebSearchSettingsFrame.LoadSettings;
begin
  FConfig := LoadWebSearchConfig;
  chkWebSearchEnabled.Checked := FConfig.Enabled;
  edtMaxResults.Text := IntToStr(FConfig.MaxResults);
  edtTotalTimeoutSec.Text := IntToStr(FConfig.TotalTimeoutMs div 1000);
  chkAutoFallback.Checked := FConfig.AutomaticFallback;
  chkFallbackEmpty.Checked := FConfig.FallbackOnEmptyResults;
  chkAllowPrivateInstances.Checked := FConfig.AllowPrivateInstances;
  RefreshConnectionList;
  memoConnStatus.Clear;
end;

procedure TWebSearchSettingsFrame.ApplyUiToConfig;
begin
  FConfig.Enabled := chkWebSearchEnabled.Checked;
  FConfig.MaxResults := StrToIntDef(Trim(edtMaxResults.Text), WEB_SEARCH_DEFAULT_MAX_RESULTS);
  if FConfig.MaxResults < 1 then FConfig.MaxResults := 1;
  if FConfig.MaxResults > 50 then FConfig.MaxResults := 50;
  FConfig.TotalTimeoutMs := StrToIntDef(Trim(edtTotalTimeoutSec.Text), 30) * 1000;
  if FConfig.TotalTimeoutMs < 1000 then FConfig.TotalTimeoutMs := 1000;
  FConfig.AutomaticFallback := chkAutoFallback.Checked;
  FConfig.FallbackOnEmptyResults := chkFallbackEmpty.Checked;
  FConfig.AllowPrivateInstances := chkAllowPrivateInstances.Checked;
end;

procedure TWebSearchSettingsFrame.SaveSettings;
begin
  ApplyUiToConfig;
  SaveWebSearchConfig(FConfig);
end;

procedure TWebSearchSettingsFrame.AdjustConnectionListColumns;
var
  I, Fixed, LastW: Integer;
begin
  if lvConnections.Columns.Count < 2 then Exit;
  Fixed := 0;
  for I := 0 to lvConnections.Columns.Count - 2 do
    Fixed := Fixed + lvConnections.Columns[I].Width;
  LastW := lvConnections.ClientWidth - Fixed - 6;
  if LastW < 64 then LastW := 64;
  lvConnections.Columns[lvConnections.Columns.Count - 1].Width := LastW;
end;

procedure TWebSearchSettingsFrame.lvConnectionsResize(Sender: TObject);
begin
  AdjustConnectionListColumns;
end;

procedure TWebSearchSettingsFrame.RefreshConnectionList;
var
  I: Integer;
  Item: TListItem;
  Conn: TWebSearchConnection;
begin
  lvConnections.Items.Clear;
  lvConnections.Columns.Clear;
  with lvConnections.Columns.Add do begin
    Caption := 'Priority';
    Width := 64;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Enabled';
    Width := 64;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Name';
    Width := 180;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Provider';
    Width := 100;
  end;
  for I := 0 to High(FConfig.Connections) do begin
    Conn := FConfig.Connections[I];
    Item := lvConnections.Items.Add;
    Item.Caption := IntToStr(Conn.Priority);
    Item.SubItems.Add(IfThen(Conn.Enabled, 'Yes', 'No'));
    Item.SubItems.Add(Conn.Name);
    Item.SubItems.Add(WebSearchProviderDisplayName(Conn.Kind));
    Item.Data := Pointer(I);
  end;
  AdjustConnectionListColumns;
end;

function TWebSearchSettingsFrame.SelectedConnectionIndex: Integer;
begin
  if lvConnections.Selected = nil then Exit(-1);
  Result := Integer(lvConnections.Selected.Data);
end;

procedure TWebSearchSettingsFrame.RenumberPriorities;
var
  I: Integer;
begin
  for I := 0 to High(FConfig.Connections) do
    FConfig.Connections[I].Priority := I + 1;
end;

procedure TWebSearchSettingsFrame.btnAddConnClick(Sender: TObject);
var
  Conn, OutConn: TWebSearchConnection;
  Key: string;
  ApiKeyChanged: Boolean;
begin
  FillChar(Conn, SizeOf(Conn), 0);
  Conn.Id := NewWebSearchConnectionId;
  Conn.Name := 'New connection';
  Conn.Kind := wspkBrave;
  Conn.Enabled := True;
  Conn.TimeoutMs := WEB_SEARCH_DEFAULT_CONNECTION_TIMEOUT_MS;
  Conn.Priority := Length(FConfig.Connections) + 1;
  if TWebSearchConnectionForm.Execute(Self, FTheme, Conn, True, OutConn, Key, ApiKeyChanged) then begin
    SetLength(FConfig.Connections, Length(FConfig.Connections) + 1);
    FConfig.Connections[High(FConfig.Connections)] := OutConn;
    if ApiKeyChanged then
      SetWebSearchApiKey(OutConn.Id, Key);
    RenumberPriorities;
    RefreshConnectionList;
  end;
end;

procedure TWebSearchSettingsFrame.btnEditConnClick(Sender: TObject);
var
  Idx: Integer;
  OutConn: TWebSearchConnection;
  Key: string;
  ApiKeyChanged: Boolean;
begin
  Idx := SelectedConnectionIndex;
  if Idx < 0 then Exit;
  if TWebSearchConnectionForm.Execute(Self, FTheme, FConfig.Connections[Idx], False,
    OutConn, Key, ApiKeyChanged) then begin
    FConfig.Connections[Idx] := OutConn;
    if ApiKeyChanged then
      SetWebSearchApiKey(OutConn.Id, Key);
    RefreshConnectionList;
  end;
end;

procedure TWebSearchSettingsFrame.btnRemoveConnClick(Sender: TObject);
var
  Idx, I, J: Integer;
begin
  Idx := SelectedConnectionIndex;
  if Idx < 0 then Exit;
  if LcaMessageDlg('Web Search', 'Remove connection "' + FConfig.Connections[Idx].Name + '"?',
    mtConfirmation, [mbYes, mbNo], FTheme) <> mrYes then Exit;
  ClearWebSearchApiKey(FConfig.Connections[Idx].Id);
  J := 0;
  for I := 0 to High(FConfig.Connections) do
    if I <> Idx then begin
      FConfig.Connections[J] := FConfig.Connections[I];
      Inc(J);
    end;
  SetLength(FConfig.Connections, J);
  RenumberPriorities;
  RefreshConnectionList;
end;

procedure TWebSearchSettingsFrame.btnTestConnClick(Sender: TObject);
var
  Idx: Integer;
  TestRes: TConnectionTestResult;
  Transport: IWebSearchTransport;
  Line, PopupText, ConnName: string;
begin
  Idx := SelectedConnectionIndex;
  if Idx < 0 then begin
    LcaMessageDlg('Web Search', 'Select a connection to test.', mtWarning, [mbOK], FTheme);
    Exit;
  end;
  ConnName := FConfig.Connections[Idx].Name;
  ApplyUiToConfig;
  memoConnStatus.Lines.Add('Testing "' + ConnName + '"...');
  Transport := TWebSearchProductionTransport.Create;
  TestRes := TestWebSearchConnection(FConfig, FConfig.Connections[Idx].Id, Transport, nil);
  if TestRes.Success then begin
    Line := Format('%s: OK (%d ms, %d results)',
      [ConnName, TestRes.ResponseTimeMs, TestRes.ResultCount]);
    PopupText := Format('Connection "%s" passed.' + LineEnding + LineEnding +
      'Response time: %d ms' + LineEnding + 'Results: %d',
      [ConnName, TestRes.ResponseTimeMs, TestRes.ResultCount]);
    LcaMessageDlg('Web Search', PopupText, mtInformation, [mbOK], FTheme);
  end   else begin
    Line := Format('%s: Failed (%s) %s',
      [ConnName, TestRes.ErrorCode, TestRes.ErrorMessage]);
    PopupText := 'Connection "' + ConnName + '" failed.' + LineEnding + LineEnding;
    if Trim(TestRes.ErrorCode) <> '' then
      PopupText := PopupText + TestRes.ErrorCode;
    if Trim(TestRes.ErrorMessage) <> '' then begin
      if Trim(TestRes.ErrorCode) <> '' then
        PopupText := PopupText + LineEnding;
      PopupText := PopupText + TestRes.ErrorMessage;
    end;
    LcaMessageDlg('Web Search', PopupText, mtError, [mbOK], FTheme);
  end;
  memoConnStatus.Lines.Add(Line);
end;

procedure TWebSearchSettingsFrame.btnMoveUpClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TWebSearchConnection;
begin
  Idx := SelectedConnectionIndex;
  if (Idx <= 0) or (Idx > High(FConfig.Connections)) then Exit;
  Tmp := FConfig.Connections[Idx - 1];
  FConfig.Connections[Idx - 1] := FConfig.Connections[Idx];
  FConfig.Connections[Idx] := Tmp;
  RenumberPriorities;
  RefreshConnectionList;
  if Idx - 1 < lvConnections.Items.Count then
    lvConnections.Items[Idx - 1].Selected := True;
end;

procedure TWebSearchSettingsFrame.btnMoveDownClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TWebSearchConnection;
begin
  Idx := SelectedConnectionIndex;
  if (Idx < 0) or (Idx >= High(FConfig.Connections)) then Exit;
  Tmp := FConfig.Connections[Idx + 1];
  FConfig.Connections[Idx + 1] := FConfig.Connections[Idx];
  FConfig.Connections[Idx] := Tmp;
  RenumberPriorities;
  RefreshConnectionList;
  if Idx + 1 < lvConnections.Items.Count then
    lvConnections.Items[Idx + 1].Selected := True;
end;

end.
