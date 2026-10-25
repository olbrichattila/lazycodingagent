unit uBrowserReadUrl;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebFetchTypes, uWebFetchUrl, uBrowserReadTypes;

function ValidateBrowserReadUrl(const Url: string; AllowLocalhost: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function ValidateBrowserReadRequestUrl(const Url: string; AllowLocalhost: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

function MapWebFetchError(AKind: TWebFetchErrorKind): TBrowserReadErrorKind;
begin
  case AKind of
    wfekInvalidUrl: Result := brekInvalidUrl;
    wfekBlockedDestination: Result := brekAccessDenied;
  else
    Result := brekAccessDenied;
  end;
end;

function ValidateBrowserReadRequestUrl(const Url: string; AllowLocalhost: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Parsed: TWebFetchUrl;
  WfKind: TWebFetchErrorKind;
  ConnectIP: string;
  LHost: string;
begin
  ErrKind := brekNone;
  ErrMsg := '';
  if not ParseWebFetchUrl(Url, Parsed, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    if ErrKind = brekNone then
      ErrKind := brekInvalidUrl;
    Exit(False);
  end;
  if (Parsed.Scheme <> 'http') and (Parsed.Scheme <> 'https') then
  begin
    ErrKind := brekAccessDenied;
    ErrMsg := 'Only http and https URLs are allowed';
    Exit(False);
  end;
  LHost := LowerCase(Parsed.Host);
  if AllowLocalhost and ((LHost = 'localhost') or (LHost = '127.0.0.1') or
     (LHost = '::1') or (LHost = '[::1]')) then
    Exit(True);
  if not ValidateWebFetchTarget(Parsed, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    Exit(False);
  end;
  if not SelectConnectAddress(Parsed, ConnectIP, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    Exit(False);
  end;
  Result := True;
end;

function ValidateBrowserReadUrl(const Url: string; AllowLocalhost: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
begin
  Result := ValidateBrowserReadRequestUrl(Url, AllowLocalhost, ErrKind, ErrMsg);
end;

end.
