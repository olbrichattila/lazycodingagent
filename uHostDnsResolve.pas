unit uHostDnsResolve;

{$mode objfpc}{$H+}

interface

uses
  Sockets;

const
  MaxHostResolveAddr = 10;

type
  THostAddr = in_addr;
  THostAddr6 = Tin6_addr;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;

implementation

{$IFDEF UNIX}
uses
  netdb;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
var
  H: THostEntry;
begin
  Result := ResolveName(Host, Addrs);
  if Result <= 0 then
  begin
    if ResolveHostByName(Host, H) then
    begin
      if Length(Addrs) > 0 then
      begin
        Addrs[0] := H.Addr;
        Result := 1;
      end;
    end;
  end;
end;

function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
var
  H6: THostEntry6;
begin
  Result := ResolveName6(Host, Addrs);
  if Result <= 0 then
  begin
    if ResolveHostByName6(Host, H6) then
    begin
      if Length(Addrs) > 0 then
      begin
        Addrs[0] := H6.Addr;
        Result := 1;
      end;
    end;
  end;
end;

function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;
var
  H: THostEntry;
begin
  Result := ResolveHostByName(Host, H);
  if Result then
    AddrNet := LongWord(H.Addr);
end;

{$ELSE}

uses
  Winsock2;

type
  PADDRINFOA = ^ADDRINFOA;
  PPADDRINFOA = ^PADDRINFOA;
  ADDRINFOA = record
    ai_flags: DWORD;
    ai_family: Integer;
    ai_socktype: Integer;
    ai_protocol: Integer;
    ai_addrlen: NativeUInt;
    ai_canonname: PAnsiChar;
    ai_addr: Pointer;
    ai_next: PADDRINFOA;
  end;

function getaddrinfo(NodeName, ServiceName: PAnsiChar; Hints: PADDRINFOA;
  Res: PPADDRINFOA): Integer; stdcall; external 'ws2_32.dll' name 'getaddrinfo';
procedure freeaddrinfo(AddrInfo: PADDRINFOA); stdcall; external 'ws2_32.dll' name 'freeaddrinfo';

var
  GWsaStarted: Boolean = False;

procedure EnsureWsaStarted;
var
  Wsa: TWsaData;
begin
  if GWsaStarted then
    Exit;
  if WSAStartup($0202, Wsa) = 0 then
    GWsaStarted := True;
end;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
var
  He: PHostEnt;
  I: Integer;
begin
  Result := 0;
  if Length(Addrs) = 0 then
    Exit;
  EnsureWsaStarted;
  He := gethostbyname(PAnsiChar(AnsiString(Host)));
  if He = nil then
    Exit;
  I := 0;
  while (I < Length(Addrs)) and (He^.h_addr_list[I] <> nil) do
  begin
    Move(He^.h_addr_list[I]^, Addrs[I], SizeOf(THostAddr));
    Inc(I);
  end;
  Result := I;
end;

function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
var
  Head, Cur: PADDRINFOA;
  Sock6: PSockAddrIn6;
  N: Integer;
  Rc: Integer;
begin
  Result := 0;
  if Length(Addrs) = 0 then
    Exit;
  EnsureWsaStarted;
  Head := nil;
  Rc := getaddrinfo(PAnsiChar(AnsiString(Host)), nil, nil, @Head);
  if (Rc <> 0) or (Head = nil) then
    Exit;
  N := 0;
  Cur := Head;
  while (Cur <> nil) and (N < Length(Addrs)) do
  begin
    if Cur^.ai_family = AF_INET6 then
    begin
      Sock6 := PSockAddrIn6(Cur^.ai_addr);
      Move(Sock6^.sin6_addr, Addrs[N], SizeOf(THostAddr6));
      Inc(N);
    end;
    Cur := Cur^.ai_next;
  end;
  freeaddrinfo(Head);
  Result := N;
end;

function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;
var
  Addrs: array[0..0] of THostAddr;
begin
  Result := ResolveHostAddresses4(Host, Addrs) > 0;
  if Result then
    AddrNet := LongWord(Addrs[0].S_addr);
end;

{$ENDIF}

end.
