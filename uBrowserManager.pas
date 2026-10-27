unit uBrowserManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fpjson,
  uBrowserReadTypes, uCdpConnection, uCdpWebSocket, uBrowserProcess,
  uBrowserSession, uBrowserNetworkGuard, uBrowserNavigate,
  uBrowserAutomationEventContext, uBrowserConsoleCollector, uBrowserNetworkCollector;

type
  TBrowserManagedSession = class
  public
    Id: string;
    WorkspaceRoot: string;
    ChatSessionId: string;
    AllowLocalhost: Boolean;
    Visible: Boolean;
    AutomationPaused: Boolean;
    LastActivity: TDateTime;
    Browser: TBrowserProcess;
    Socket: TCdpWebSocket;
    Connection: TCdpConnection;
    PageSession: TBrowserSession;
    Guard: TBrowserNetworkGuard;
    Navigator: TBrowserNavigator;
    EventCtx: TBrowserAutomationEventContext;
    ConsoleLog: TBrowserConsoleCollector;
    NetworkLog: TBrowserNetworkCollector;
    RefMap: TStringList;
    RefCounter: Integer;
    Lock: TCriticalSection;
    destructor Destroy; override;
    procedure Touch;
    function WithLock: TCriticalSection;
  end;

procedure BrowserManagerAcquire(const Config: TBrowserReadConfig);
procedure BrowserManagerRelease;
procedure BrowserManagerShutdownAll;

function NewBrowserSessionId: string;
function BrowserSessionCreate(const WorkspaceRoot, ChatSessionId: string;
  AllowLocalhost: Boolean; AVisible: Boolean; const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out Session: TBrowserManagedSession;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
function BrowserSessionFind(const SessionId: string): TBrowserManagedSession;
function BrowserSessionClose(const SessionId: string;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
procedure BrowserSessionPurgeIdle(const Config: TBrowserReadConfig);

implementation

uses
  DateUtils, Math,
  uBrowserDiscovery, uBrowserRead;

function NewBrowserSessionId: string;
begin
  Result := 'bs_' + IntToHex(GetTickCount64, 16) + '_' + IntToHex(Random($7FFFFFFF), 8);
end;

var
  GLock: TCriticalSection;
  GActive: Integer;
  GMaxConcurrent: Integer;
  GSessions: TList;
  GSessionLock: TCriticalSection;

destructor TBrowserManagedSession.Destroy;
begin
  Lock.Enter;
  try
    if Assigned(PageSession) then
      PageSession.ClosePage(nil);
    PageSession.Free;
    Navigator.Free;
    Guard.Free;
    EventCtx.Free;
    ConsoleLog.Free;
    NetworkLog.Free;
    RefMap.Free;
    if Assigned(Connection) then
      Connection.Free;
    Socket.Free;
    Browser.Free;
  finally
    Lock.Leave;
  end;
  Lock.Free;
  inherited Destroy;
end;

procedure TBrowserManagedSession.Touch;
begin
  LastActivity := Now;
end;

function TBrowserManagedSession.WithLock: TCriticalSection;
begin
  Result := Lock;
end;

procedure BrowserManagerAcquire(const Config: TBrowserReadConfig);
begin
  if GLock = nil then
    GLock := TCriticalSection.Create;
  GMaxConcurrent := Config.MaxConcurrent;
  if GMaxConcurrent < 1 then
    GMaxConcurrent := 1;
  while True do
  begin
    GLock.Enter;
    try
      if GActive < GMaxConcurrent then
      begin
        Inc(GActive);
        Exit;
      end;
    finally
      GLock.Leave;
    end;
    Sleep(50);
  end;
end;

procedure BrowserManagerRelease;
begin
  if GLock = nil then Exit;
  GLock.Enter;
  try
    if GActive > 0 then
      Dec(GActive);
  finally
    GLock.Leave;
  end;
end;

procedure BrowserSessionPurgeIdle(const Config: TBrowserReadConfig);
var
  I: Integer;
  S: TBrowserManagedSession;
  Cutoff: TDateTime;
begin
  if GSessionLock = nil then Exit;
  Cutoff := IncMilliSecond(Now, -Config.IdleTimeoutMs);
  GSessionLock.Enter;
  try
    for I := GSessions.Count - 1 downto 0 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if S.Visible then
        Continue;
      if S.LastActivity < Cutoff then
      begin
        GSessions.Delete(I);
        S.Free;
        BrowserManagerRelease;
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
end;

procedure BrowserManagerShutdownAll;
var
  I: Integer;
begin
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    for I := GSessions.Count - 1 downto 0 do
      TBrowserManagedSession(GSessions[I]).Free;
    GSessions.Clear;
  finally
    GSessionLock.Leave;
  end;
end;

function BrowserSessionFind(const SessionId: string): TBrowserManagedSession;
var
  I: Integer;
  S: TBrowserManagedSession;
begin
  Result := nil;
  if (SessionId = '') or (GSessionLock = nil) then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if SameText(S.Id, SessionId) then
        Exit(S);
    end;
  finally
    GSessionLock.Leave;
  end;
end;

function BrowserSessionCreate(const WorkspaceRoot, ChatSessionId: string;
  AllowLocalhost: Boolean; AVisible: Boolean; const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out Session: TBrowserManagedSession;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Executable, WsUrl, Host, Path: string;
  Port: Word;
  Transport: ICdpTransport;
  EnableParams, ResultObj: TJSONObject;
  I: Integer;
begin
  Session := nil;
  ErrKind := brekNone;
  ErrMsg := '';
  BrowserSessionPurgeIdle(Config);

  if GSessionLock = nil then
    GSessionLock := TCriticalSection.Create;
  if GSessions = nil then
    GSessions := TList.Create;

  GSessionLock.Enter;
  try
    if GSessions.Count >= Config.MaxSessions then
    begin
      ErrKind := brekInternal;
      ErrMsg := 'Maximum browser sessions reached';
      Exit(False);
    end;
  finally
    GSessionLock.Leave;
  end;

  if not DiscoverChromiumExecutable(Config, Executable, ErrMsg) then
  begin
    ErrKind := brekBrowserNotFound;
    Exit(False);
  end;

  BrowserManagerAcquire(Config);
  Session := TBrowserManagedSession.Create;
  Session.Id := NewBrowserSessionId;
  Session.WorkspaceRoot := WorkspaceRoot;
  Session.ChatSessionId := ChatSessionId;
  Session.AllowLocalhost := AllowLocalhost;
  Session.Visible := AVisible;
  Session.AutomationPaused := AVisible;
  Session.LastActivity := Now;
  Session.Lock := TCriticalSection.Create;
  Session.RefMap := TStringList.Create;
  Session.RefCounter := 0;
  Session.Browser := TBrowserProcess.Create;
  Session.Socket := TCdpWebSocket.Create;

  try
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;

    if not Session.Browser.Start(Executable, Config.MaxTimeoutMs, not AVisible,
      CancelCheck, WsUrl, ErrKind, ErrMsg) then
      Exit(False);

    if not ParseBrowserWebSocketEndpoint(WsUrl, Host, Port, Path) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Invalid debugger WebSocket URL';
      Exit(False);
    end;

    if not Session.Socket.Connect(Host, Port, Path, Min(Config.MaxTimeoutMs, 15000), ErrMsg) then
    begin
      ErrKind := brekCdpConnectionFailed;
      if Trim(ErrMsg) = '' then
        ErrMsg := 'WebSocket connection failed';
      Exit(False);
    end;

    Transport := TCdpWebSocketTransport.Create(Session.Socket);
    Session.Connection := TCdpConnection.Create(Transport);
    Session.Guard := TBrowserNetworkGuard.Create(Session.Connection, AllowLocalhost);
    Session.Navigator := TBrowserNavigator.Create(Session.Connection);
    Session.ConsoleLog := TBrowserConsoleCollector.Create;
    Session.NetworkLog := TBrowserNetworkCollector.Create;
    Session.EventCtx := TBrowserAutomationEventContext.Create;
    Session.EventCtx.NetGuard := Session.Guard;
    Session.EventCtx.PageNav := Session.Navigator;
    Session.EventCtx.ConsoleLog := Session.ConsoleLog;
    Session.EventCtx.NetworkLog := Session.NetworkLog;
    Session.Connection.OnEvent := @Session.EventCtx.OnCdpEvent;
    Session.Connection.Tag := PtrUInt(Session);

    Session.PageSession := TBrowserSession.Create(Session.Connection);
    if not Session.PageSession.OpenBlankPage(CancelCheck, ErrKind, ErrMsg) then
      Exit(False);

    if not Session.Guard.Enable(CancelCheck) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Network guard failed';
      Exit(False);
    end;

    EnableParams := TJSONObject.Create;
    try
      if not Session.Connection.SendCommand('Network.enable', EnableParams, 10000,
        CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Network.enable failed';
        Exit(False);
      end;
      ResultObj.Free;
      if not Session.Connection.SendCommand('Log.enable', EnableParams, 10000,
        CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Log.enable failed';
        Exit(False);
      end;
      ResultObj.Free;
    finally
      EnableParams.Free;
    end;

    GSessionLock.Enter;
    try
      GSessions.Add(Session);
    finally
      GSessionLock.Leave;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      ErrKind := brekInternal;
      ErrMsg := E.Message;
      Result := False;
    end;
  end;

  if not Result then
  begin
    GSessionLock.Enter;
    try
      I := GSessions.IndexOf(Session);
      if I >= 0 then
        GSessions.Delete(I);
    finally
      GSessionLock.Leave;
    end;
    Session.Free;
    Session := nil;
    BrowserManagerRelease;
  end;
end;

function BrowserSessionClose(const SessionId: string;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  I: Integer;
  S: TBrowserManagedSession;
begin
  Result := False;
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if SameText(S.Id, SessionId) then
      begin
        GSessions.Delete(I);
        S.Free;
        BrowserManagerRelease;
        Exit(True);
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
end;

initialization
  Randomize;

finalization
  BrowserManagerShutdownAll;
  GSessions.Free;
  GSessionLock.Free;
  GLock.Free;

end.
