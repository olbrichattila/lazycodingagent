unit uBrowserContentExtract;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uCdpConnection, uBrowserReadTypes, uWebFetchTypes;

function ExtractRenderedContent(AConnection: TCdpConnection; const Format: string;
  MaxLength: Integer; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out Title, Content: string; out Truncated: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  fpjson, uWebContentExtract;

function CdpEvaluate(AConnection: TCdpConnection; const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): string;
var
  Params, ResultObj, Val: TJSONObject;
begin
  Result := '';
  Params := TJSONObject.Create;
  try
    Params.Add('expression', Expr);
    Params.Add('returnByValue', True);
    if not AConnection.SendCommand('Runtime.evaluate', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    try
      if ResultObj.Find('exceptionDetails') <> nil then
        Exit;
      if ResultObj.Find('result') = nil then Exit;
      Val := TJSONObject(ResultObj.Find('result'));
      if Val.Find('value') <> nil then
        Result := Val.Get('value', '');
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function ExtractRenderedContent(AConnection: TCdpConnection; const Format: string;
  MaxLength: Integer; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out Title, Content: string; out Truncated: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  HtmlBody, TextBody, Fmt: string;
  WfKind: TWebFetchErrorKind;
begin
  Title := '';
  Content := '';
  Truncated := False;
  ErrKind := brekNone;
  ErrMsg := '';

  Title := CdpEvaluate(AConnection, 'document.title || ""', TimeoutMs, CancelCheck);
  HtmlBody := CdpEvaluate(AConnection,
    'document.documentElement ? document.documentElement.outerHTML : ""',
    TimeoutMs, CancelCheck);
  TextBody := CdpEvaluate(AConnection,
    'document.body ? document.body.innerText : ""',
    TimeoutMs, CancelCheck);

  if (HtmlBody = '') and (TextBody = '') then
  begin
    ErrKind := brekContentExtractionFailed;
    ErrMsg := 'No content extracted from page';
    Exit(False);
  end;

  Fmt := LowerCase(Format);
  if Fmt = 'html' then
    Content := HtmlBody
  else if Fmt = 'text' then
    Content := TextBody
  else
  begin
    if not ExtractWebContent(RawByteString(UTF8Encode(HtmlBody)), 'text/html',
      'markdown', MaxLength, Title, Content, Truncated, WfKind, ErrMsg) then
    begin
      ErrKind := brekContentExtractionFailed;
      if WfKind <> wfekNone then
        ErrMsg := 'Content extraction failed: ' + ErrMsg;
      Exit(False);
    end;
  end;

  if (Fmt = 'html') or (Fmt = 'text') then
  begin
    if Length(Content) > MaxLength then
    begin
      SetLength(Content, MaxLength);
      Truncated := True;
    end;
  end;

  Result := True;
end;

end.
