unit uCdpWebSocket;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCdpWebSocket = class
  private
    FSocket: LongInt;
    FConnected: Boolean;
    FReadBuf: RawByteString;
    function ReadMore(TimeoutMs: Integer): Boolean;
    function Sha1WebSocketAccept(const Key: AnsiString): AnsiString;
    function BuildClientKey: AnsiString;
    function ParseOneFrame(out Opcode: Byte; out Payload: RawByteString): Boolean;
    procedure SetSocketTimeout(Ms: Integer);
  public
    destructor Destroy; override;
    function Connect(const Host: string; Port: Word; const Path: string;
      TimeoutMs: Integer): Boolean;
    procedure Disconnect;
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
  end;

implementation

uses
  sha1, base64, Math, Sockets, NetDB, ctypes
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF};

const
  LCA_INVALID_SOCKET = TSocket(-1);

function TCdpWebSocket.Sha1WebSocketAccept(const Key: AnsiString): AnsiString;
var
  D: TSHA1Digest;
  Combined: AnsiString;
  Bin: AnsiString;
begin
  Combined := Key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  D := SHA1Buffer(Combined[1], Length(Combined));
  SetLength(Bin, SizeOf(D));
  Move(D[0], Bin[1], SizeOf(D));
  Result := EncodeStringBase64(Bin);
end;

function TCdpWebSocket.BuildClientKey: AnsiString;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
  Raw: AnsiString;
begin
  SetLength(Raw, 16);
  Randomize;
  for I := 1 to 16 do
    Raw[I] := Chars[1 + Random(Length(Chars))];
  Result := EncodeStringBase64(Raw);
end;

procedure TCdpWebSocket.SetSocketTimeout(Ms: Integer);
{$IFDEF UNIX}
var
  Tv: timeval;
begin
  if FSocket = LCA_INVALID_SOCKET then Exit;
  Tv.tv_sec := Ms div 1000;
  Tv.tv_usec := (Ms mod 1000) * 1000;
  fpsetsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, @Tv, SizeOf(Tv));
  fpsetsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, @Tv, SizeOf(Tv));
end;
{$ELSE}
begin
end;
{$ENDIF}

destructor TCdpWebSocket.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

procedure TCdpWebSocket.Disconnect;
begin
  FConnected := False;
  if (FSocket <> 0) and (FSocket <> LCA_INVALID_SOCKET) then
  begin
    {$IFDEF UNIX}
    fpClose(FSocket);
    {$ELSE}
    closesocket(FSocket);
    {$ENDIF}
    FSocket := LCA_INVALID_SOCKET;
  end;
  FReadBuf := '';
end;

function TCdpWebSocket.ReadMore(TimeoutMs: Integer): Boolean;
var
  Chunk: array[0..8191] of Byte;
  Tmp: RawByteString;
  N: Integer;
begin
  if FSocket = LCA_INVALID_SOCKET then Exit(False);
  SetSocketTimeout(TimeoutMs);
  {$IFDEF UNIX}
  N := fpRecv(FSocket, @Chunk[0], SizeOf(Chunk), 0);
  {$ELSE}
  N := recv(FSocket, @Chunk[0], SizeOf(Chunk), 0);
  {$ENDIF}
  if N <= 0 then Exit(False);
  SetLength(Tmp, N);
  Move(Chunk[0], Tmp[1], N);
  FReadBuf := FReadBuf + Tmp;
  Result := True;
end;

function TCdpWebSocket.Connect(const Host: string; Port: Word; const Path: string;
  TimeoutMs: Integer): Boolean;
var
  Req, Resp, Line, Key, AcceptExpected, P: AnsiString;
  I, PPos, N: Integer;
  H: THostEntry;
  Addr: sockaddr_in;
begin
  Disconnect;
  {$IFDEF UNIX}
  FSocket := fpsocket(AF_INET, SOCK_STREAM, 0);
  {$ELSE}
  FSocket := socket(AF_INET, SOCK_STREAM, 0);
  {$ENDIF}
  if FSocket = LCA_INVALID_SOCKET then Exit(False);
  SetSocketTimeout(TimeoutMs);

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  if not ResolveHostByName(Host, H) then
  begin
    Disconnect;
    Exit(False);
  end;
  Addr.sin_addr.s_addr := LongWord(H.Addr);

  {$IFDEF UNIX}
  if fpConnect(FSocket, @Addr, SizeOf(Addr)) <> 0 then
  {$ELSE}
  if connect(FSocket, @Addr, SizeOf(Addr)) <> 0 then
  {$ENDIF}
  begin
    Disconnect;
    Exit(False);
  end;

  Key := BuildClientKey;
  AcceptExpected := Sha1WebSocketAccept(Key);
  P := AnsiString(Path);
  if (P = '') or (P[1] <> '/') then
    P := '/' + P;
  Req :=
    'GET ' + P + ' HTTP/1.1' + #13#10 +
    'Host: ' + AnsiString(Host) + ':' + AnsiString(IntToStr(Port)) + #13#10 +
    'Upgrade: websocket' + #13#10 +
    'Connection: Upgrade' + #13#10 +
    'Sec-WebSocket-Key: ' + Key + #13#10 +
    'Sec-WebSocket-Version: 13' + #13#10#13#10;
  {$IFDEF UNIX}
  N := fpSend(FSocket, Pointer(Req), Length(Req), 0);
  {$ELSE}
  N := send(FSocket, Pointer(Req), Length(Req), 0);
  {$ENDIF}
  if N <> Length(Req) then
  begin
    Disconnect;
    Exit(False);
  end;

  Resp := '';
  while Pos(#13#10#13#10, Resp) = 0 do
  begin
    if not ReadMore(TimeoutMs) then
    begin
      Disconnect;
      Exit(False);
    end;
    Resp := Resp + FReadBuf;
    FReadBuf := '';
    if Length(Resp) > 16384 then
    begin
      Disconnect;
      Exit(False);
    end;
  end;

  if Pos('101', Resp) = 0 then
  begin
    Disconnect;
    Exit(False);
  end;
  I := 1;
  while I <= Length(Resp) do
  begin
    PPos := Pos(#10, Copy(Resp, I, MaxInt));
    if PPos = 0 then
      Line := Copy(Resp, I, MaxInt)
    else
      Line := Copy(Resp, I, PPos - 1);
    if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
      SetLength(Line, Length(Line) - 1);
    if Pos('Sec-WebSocket-Accept:', Line) > 0 then
    begin
      if Trim(Copy(Line, Pos(':', Line) + 1, MaxInt)) <> Trim(AcceptExpected) then
      begin
        Disconnect;
        Exit(False);
      end;
    end;
    if PPos = 0 then Break;
    I := I + PPos;
  end;
  FConnected := True;
  Result := True;
end;

function TCdpWebSocket.Connected: Boolean;
begin
  Result := FConnected and (FSocket <> LCA_INVALID_SOCKET);
end;

function TCdpWebSocket.SendText(const Text: UTF8String): Boolean;
var
  Payload, Frame: RawByteString;
  Len: QWord;
  I: Integer;
  Mask: array[0..3] of Byte;
  N: Integer;
begin
  if not Connected then Exit(False);
  Payload := Text;
  Len := Length(Payload);
  Frame := '';
  Frame := Frame + AnsiChar($81);
  if Len < 126 then
    Frame := Frame + AnsiChar(Ord(Len) or $80)
  else if Len < 65536 then
  begin
    Frame := Frame + AnsiChar($FE);
    Frame := Frame + AnsiChar((Len shr 8) and $FF);
    Frame := Frame + AnsiChar(Len and $FF);
  end
  else
  begin
    Frame := Frame + AnsiChar($FF);
    for I := 7 downto 0 do
      Frame := Frame + AnsiChar((Len shr (I * 8)) and $FF);
  end;
  Randomize;
  Mask[0] := Random(256);
  Mask[1] := Random(256);
  Mask[2] := Random(256);
  Mask[3] := Random(256);
  Frame := Frame + AnsiChar(Mask[0]) + AnsiChar(Mask[1]) + AnsiChar(Mask[2]) + AnsiChar(Mask[3]);
  Frame := Frame + Payload;
  for I := 1 to Length(Payload) do
    Frame[Length(Frame) - Length(Payload) + I] :=
      AnsiChar(Ord(Frame[Length(Frame) - Length(Payload) + I]) xor Mask[(I - 1) mod 4]);
  {$IFDEF UNIX}
  N := fpSend(FSocket, Pointer(Frame), Length(Frame), 0);
  {$ELSE}
  N := send(FSocket, Pointer(Frame), Length(Frame), 0);
  {$ENDIF}
  Result := N = Length(Frame);
end;

function TCdpWebSocket.ParseOneFrame(out Opcode: Byte; out Payload: RawByteString): Boolean;
var
  B0, B1: Byte;
  Masked: Boolean;
  PayloadLen: QWord;
  Mask: array[0..3] of Byte;
  HeaderLen: Integer;
  I: Integer;
begin
  Result := False;
  Opcode := 0;
  Payload := '';
  if Length(FReadBuf) < 2 then Exit;
  B0 := Ord(FReadBuf[1]);
  B1 := Ord(FReadBuf[2]);
  Opcode := B0 and $0F;
  Masked := (B1 and $80) <> 0;
  PayloadLen := B1 and $7F;
  HeaderLen := 2;
  if PayloadLen = 126 then
  begin
    if Length(FReadBuf) < 4 then Exit;
    PayloadLen := (Ord(FReadBuf[3]) shl 8) or Ord(FReadBuf[4]);
    HeaderLen := 4;
  end
  else if PayloadLen = 127 then
  begin
    if Length(FReadBuf) < 10 then Exit;
    PayloadLen := 0;
    for I := 0 to 7 do
      PayloadLen := (PayloadLen shl 8) or Ord(FReadBuf[3 + I]);
    HeaderLen := 10;
  end;
  if Masked then
    HeaderLen := HeaderLen + 4;
  if Int64(Length(FReadBuf)) < HeaderLen + Int64(PayloadLen) then Exit;
  if Masked then
  begin
    Mask[0] := Ord(FReadBuf[HeaderLen - 3]);
    Mask[1] := Ord(FReadBuf[HeaderLen - 2]);
    Mask[2] := Ord(FReadBuf[HeaderLen - 1]);
    Mask[3] := Ord(FReadBuf[HeaderLen]);
  end;
  Payload := Copy(FReadBuf, HeaderLen + 1, PayloadLen);
  FReadBuf := Copy(FReadBuf, HeaderLen + PayloadLen + 1, MaxInt);
  if Masked then
    for I := 1 to Length(Payload) do
      Payload[I] := AnsiChar(Ord(Payload[I]) xor Mask[(I - 1) mod 4]);
  Result := True;
end;

function TCdpWebSocket.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
var
  Opcode: Byte;
  Payload: RawByteString;
begin
  Text := '';
  Result := False;
  if not Connected then Exit;
  while True do
  begin
    if not ParseOneFrame(Opcode, Payload) then
    begin
      if not ReadMore(TimeoutMs) then Exit;
      if not ParseOneFrame(Opcode, Payload) then Exit;
    end;
    if Opcode = 8 then
    begin
      FConnected := False;
      Exit;
    end;
    if Opcode = 9 then
      Continue;
    if Opcode = 1 then
    begin
      Text := UTF8String(Payload);
      Exit(True);
    end;
  end;
end;

end.
