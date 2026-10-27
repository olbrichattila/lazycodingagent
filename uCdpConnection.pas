unit uCdpConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uCdpWebSocket, uBrowserReadTypes;

type
  TCdpEventHandler = procedure(Sender: TObject; const Method, ParamsJson: AnsiString) of object;

  ICdpTransport = interface
    ['{B8A2F4E1-9C3D-4A5B-8E7F-1D2C3B4A5968}']
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
  end;

  TCdpWebSocketTransport = class(TInterfacedObject, ICdpTransport)
  private
    FSocket: TCdpWebSocket;
  public
    constructor Create(ASocket: TCdpWebSocket);
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
  end;

  TCdpConnection = class
  private
    FTransport: ICdpTransport;
    FNextId: Integer;
    FOnEvent: TCdpEventHandler;
    FSessionId: string;
    FTag: PtrUInt;
    function WaitForResponse(AId: Integer; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck; out ResultObj: TJSONObject): Boolean;
  public
    constructor Create(ATransport: ICdpTransport);
    destructor Destroy; override;
    property OnEvent: TCdpEventHandler read FOnEvent write FOnEvent;
    property SessionId: string read FSessionId write FSessionId;
    property Tag: PtrUInt read FTag write FTag;
    procedure NotifyEvent(const Method, ParamsJson: AnsiString);
    function ConnectLoopAlive: Boolean;
    function SendCommand(const Method: string; const Params: TJSONObject;
      TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
      out ResultObj: TJSONObject): Boolean;
    procedure PumpEvents(TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck);
    procedure DrainEvents(MaxMessages: Integer; CancelCheck: TBrowserReadCancelCheck);
    procedure Disconnect;
  private
    function ProcessOneEventMessage(TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): Boolean;
  end;

implementation

uses
  DateUtils;

constructor TCdpWebSocketTransport.Create(ASocket: TCdpWebSocket);
begin
  inherited Create;
  FSocket := ASocket;
end;

function TCdpWebSocketTransport.Connected: Boolean;
begin
  Result := Assigned(FSocket) and FSocket.Connected;
end;

function TCdpWebSocketTransport.SendText(const Text: UTF8String): Boolean;
begin
  if Assigned(FSocket) then
    Result := FSocket.SendText(Text)
  else
    Result := False;
end;

function TCdpWebSocketTransport.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
begin
  if Assigned(FSocket) then
    Result := FSocket.TryReceiveText(Text, TimeoutMs)
  else
    Result := False;
end;

procedure TCdpWebSocketTransport.Disconnect;
begin
  if Assigned(FSocket) then
    FSocket.Disconnect;
end;

constructor TCdpConnection.Create(ATransport: ICdpTransport);
begin
  inherited Create;
  FTransport := ATransport;
  FNextId := 1;
  FSessionId := '';
end;

destructor TCdpConnection.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

procedure TCdpConnection.Disconnect;
begin
  if Assigned(FTransport) then
    FTransport.Disconnect;
end;

procedure TCdpConnection.NotifyEvent(const Method, ParamsJson: AnsiString);
begin
  if Assigned(FOnEvent) then
    FOnEvent(Self, Method, ParamsJson);
end;

function TCdpConnection.ConnectLoopAlive: Boolean;
begin
  Result := Assigned(FTransport) and FTransport.Connected;
end;

function TCdpConnection.ProcessOneEventMessage(TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Text: UTF8String;
  Root, Params: TJSONObject;
  Method: string;
begin
  Result := False;
  if not ConnectLoopAlive then Exit;
  if Assigned(CancelCheck) and CancelCheck() then Exit;
  if not FTransport.TryReceiveText(Text, TimeoutMs) then Exit;
  Root := TJSONObject(GetJSON(Text));
  try
    if Root.Find('id') <> nil then
      Exit;
    Method := Root.Get('method', '');
    if Method = '' then Exit;
    if Root.Find('params') <> nil then
      Params := TJSONObject(Root.Find('params').Clone)
    else
      Params := TJSONObject.Create;
    try
      if Assigned(FOnEvent) then
        FOnEvent(Self, AnsiString(Method), AnsiString(Params.AsJSON));
    finally
      Params.Free;
    end;
    Result := True;
  finally
    Root.Free;
  end;
end;

procedure TCdpConnection.PumpEvents(TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck);
begin
  ProcessOneEventMessage(TimeoutMs, CancelCheck);
end;

procedure TCdpConnection.DrainEvents(MaxMessages: Integer;
  CancelCheck: TBrowserReadCancelCheck);
var
  N: Integer;
begin
  if MaxMessages < 1 then
    MaxMessages := 32;
  N := 0;
  while N < MaxMessages do
  begin
    if not ProcessOneEventMessage(50, CancelCheck) then
      Break;
    Inc(N);
  end;
end;

function TCdpConnection.WaitForResponse(AId: Integer; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; out ResultObj: TJSONObject): Boolean;
var
  Start: QWord;
  Text: UTF8String;
  Root, Err: TJSONObject;
  IdVal: TJSONNumber;
  Method: string;
  Params: TJSONObject;
begin
  ResultObj := nil;
  Result := False;
  Start := GetTickCount64;
  while GetTickCount64 - Start < QWord(TimeoutMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then Exit;
    if not ConnectLoopAlive then Exit;
    if FTransport.TryReceiveText(Text, 200) then
    begin
      Root := TJSONObject(GetJSON(Text));
      try
        if Root.Find('id') <> nil then
        begin
          IdVal := TJSONNumber(Root.Find('id'));
          if IdVal.AsInteger = AId then
          begin
            if Root.Find('error') <> nil then
            begin
              Err := TJSONObject(Root.Find('error'));
              ResultObj := TJSONObject.Create;
              ResultObj.Add('error', Err.Clone);
              Exit(True);
            end;
            if Root.Find('result') <> nil then
              ResultObj := TJSONObject(TJSONObject(Root.Find('result')).Clone);
            Result := True;
            Exit;
          end;
        end
        else
        begin
          Method := Root.Get('method', '');
          if (Method <> '') and Assigned(FOnEvent) then
          begin
            if Root.Find('params') <> nil then
              Params := TJSONObject(Root.Find('params').Clone)
            else
              Params := TJSONObject.Create;
            try
              FOnEvent(Self, AnsiString(Method), AnsiString(Params.AsJSON));
            finally
              Params.Free;
            end;
          end;
        end;
      finally
        Root.Free;
      end;
    end;
  end;
end;

function TCdpConnection.SendCommand(const Method: string; const Params: TJSONObject;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ResultObj: TJSONObject): Boolean;
var
  Cmd: TJSONObject;
  Id: Integer;
  Payload: string;
begin
  ResultObj := nil;
  if not ConnectLoopAlive then Exit(False);
  Id := FNextId;
  Inc(FNextId);
  Cmd := TJSONObject.Create;
  try
    Cmd.Add('id', Id);
    Cmd.Add('method', Method);
    if FSessionId <> '' then
      Cmd.Add('sessionId', FSessionId);
    if Assigned(Params) then
      Cmd.Add('params', Params.Clone);
    Payload := Cmd.AsJSON;
  finally
    Cmd.Free;
  end;
  if not FTransport.SendText(Payload) then Exit(False);
  Result := WaitForResponse(Id, TimeoutMs, CancelCheck, ResultObj);
end;

end.
