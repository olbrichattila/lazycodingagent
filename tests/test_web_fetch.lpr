program test_web_fetch;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils,
  uWebFetchTypes, uWebFetchUrl, uWebFetch, uWebContentExtract;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure AssertBlocked(const Url: string);
var
  P: TWebFetchUrl;
  K: TWebFetchErrorKind;
  Msg: string;
begin
  if not ParseWebFetchUrl(Url, P, K, Msg) then
  begin
    if K = wfekBlockedDestination then Exit;
    if K = wfekInvalidUrl then Exit;
    Fail('expected block for ' + Url + ' got parse ' + Msg);
  end;
  if ValidateWebFetchTarget(P, K, Msg) then
    Fail('expected blocked destination for ' + Url);
  if K <> wfekBlockedDestination then
    Fail('wrong error kind for ' + Url);
end;

type
  TRedirectThenOkTransport = class(TInterfacedObject, IWebFetchTransport)
  public
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
  end;

  TMockTransport = class(TInterfacedObject, IWebFetchTransport)
  private
    FStatus: Integer;
    FContentType: string;
    FBody: RawByteString;
    FLocation: string;
    FCalls: Integer;
  public
    constructor Create(AStatus: Integer; const AContentType: string;
      const ABody: RawByteString; const ALocation: string = '');
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
    property Calls: Integer read FCalls;
  end;

function TRedirectThenOkTransport.Fetch(const RequestUrl: string;
  const Parsed: TWebFetchUrl; const ConnectIP, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
begin
  FillChar(Resp, SizeOf(Resp), 0);
  if Pos('/next', RequestUrl) > 0 then
  begin
    Resp.StatusCode := 200;
    Resp.ContentType := 'text/plain';
    Resp.Body := 'done';
  end
  else
  begin
    Resp.StatusCode := 302;
    Resp.Location := 'http://93.184.216.34/next';
  end;
  Result := True;
  ErrKind := wfekNone;
  ErrMsg := '';
end;

constructor TMockTransport.Create(AStatus: Integer; const AContentType: string;
  const ABody: RawByteString; const ALocation: string);
begin
  inherited Create;
  FStatus := AStatus;
  FContentType := AContentType;
  FBody := ABody;
  FLocation := ALocation;
  FCalls := 0;
end;

function TMockTransport.Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
  const ConnectIP, VHost: string; const Config: TWebFetchConfig;
  CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
begin
  Inc(FCalls);
  FillChar(Resp, SizeOf(Resp), 0);
  Resp.StatusCode := FStatus;
  Resp.ContentType := FContentType;
  Resp.Body := FBody;
  Resp.Location := FLocation;
  Result := True;
  ErrKind := wfekNone;
  ErrMsg := '';
end;

var
  FixturePath, FixtureHtml, Title, Content, Resolved: string;
  Truncated: Boolean;
  K: TWebFetchErrorKind;
  Msg: string;
  R: TWebFetchResult;
  Mock: IWebFetchTransport;
  Config: TWebFetchConfig;
  CancelFlag: Boolean;
  P: TWebFetchUrl;

function CancelSoon: Boolean;
begin
  Result := CancelFlag;
end;

begin
  if ParamCount >= 1 then
    FixturePath := ParamStr(1)
  else
    FixturePath := 'tests/fixtures/web_fetch/sample.html';
  if not FileExists(FixturePath) then
    Fail('fixture not found: ' + FixturePath);

  AssertBlocked('http://127.0.0.1/');
  AssertBlocked('http://[::1]/');
  AssertBlocked('http://10.0.0.1/');
  AssertBlocked('http://localhost/');
  AssertBlocked('http://user:pass@example.com/');
  if ParseWebFetchUrl('file:///etc/passwd', P, K, Msg) then
    Fail('file url should not parse');

  if not IsBlockedIPv4((127 shl 24) or 1) then
    Fail('127.0.0.1 should be blocked');

  with TStringList.Create do
  try
    LoadFromFile(FixturePath);
    FixtureHtml := Text;
  finally
    Free;
  end;
  if not ExtractWebContent(RawByteString(FixtureHtml), 'text/html', 'markdown', 20000,
    Title, Content, Truncated, K, Msg) then
    Fail('extract html: ' + Msg);
  if Title <> 'Sample Docs' then
    Fail('title mismatch: ' + Title);
  if Pos('Authentication', Content) = 0 then
    Fail('missing heading');
  if Pos('token guide', Content) = 0 then
    Fail('missing link text');
  if Pos('skip me', Content) > 0 then
    Fail('nav should be stripped');

  if not ExtractWebContent(RawByteString('hello'), 'text/plain', 'text', 3,
    Title, Content, Truncated, K, Msg) then
    Fail('plain extract');
  if not Truncated then
    Fail('expected truncation');
  if Length(Content) <> 3 then
    Fail('truncation length');

  Config := DefaultWebFetchConfig;
  Mock := TMockTransport.Create(200, 'text/html',
    RawByteString('<html><head><title>T</title></head><body><p>OK</p></body></html>'));
  R := FetchWebContent('http://93.184.216.34/page', 'markdown', 20000, Config, nil, Mock);
  if not R.Success then
    Fail('mock fetch failed: ' + R.ErrorMessage);

  Mock := TRedirectThenOkTransport.Create;
  R := FetchWebContent('http://93.184.216.34/start', 'text', 20000, Config, nil, Mock);
  if not R.Success then
    Fail('redirect chain failed: ' + R.ErrorMessage);
  if R.Content <> 'done' then
    Fail('redirect body mismatch');

  if ResolveRedirectUrl('http://93.184.216.34/a', 'http://127.0.0.1/evil', Resolved, K, Msg) then
    Fail('redirect to private should not resolve');
  if K <> wfekBlockedDestination then
    Fail('redirect to private should be blocked');

  Mock := TMockTransport.Create(404, 'text/html', 'missing');
  R := FetchWebContent('http://93.184.216.34/missing', 'markdown', 20000, Config, nil, Mock);
  if R.Success or (R.ErrorKind <> wfekHttpError) then
    Fail('expected http 404 error');

  CancelFlag := True;
  Mock := TMockTransport.Create(200, 'text/plain', 'x');
  R := FetchWebContent('http://93.184.216.34/', 'text', 20000, Config, @CancelSoon, Mock);
  if R.ErrorKind <> wfekCancelled then
    Fail('expected cancel');

  WriteLn('Web fetch tests passed.');
end.
