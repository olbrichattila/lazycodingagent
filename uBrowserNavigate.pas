unit uBrowserNavigate;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uCdpConnection, uBrowserReadTypes;

type
  TBrowserNavigator = class
  private
    FConnection: TCdpConnection;
    FDomContentLoaded: Boolean;
    FLoadEventFired: Boolean;
    FNavFailed: Boolean;
    FNavErrorText: string;
    function EvaluateBoolExpression(const Expr: string; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): Boolean;
  public
    constructor Create(AConnection: TCdpConnection);
    procedure HandleEvent(const Method, ParamsJson: AnsiString);
    function Navigate(const Url: string; Strategy: TBrowserReadWaitStrategy;
      const WaitSelector: string; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck; out FinalUrl: string;
      out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
    function EvaluateString(const Expr: string; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): string;
  end;

implementation

uses
  DateUtils, Classes, Math;

constructor TBrowserNavigator.Create(AConnection: TCdpConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TBrowserNavigator.HandleEvent(const Method, ParamsJson: AnsiString);
var
  Params: TJSONObject;
begin
  if Method = 'Page.domContentEventFired' then
    FDomContentLoaded := True
  else if Method = 'Page.loadEventFired' then
    FLoadEventFired := True
  else if Method = 'Page.frameStoppedLoading' then
  begin
    Params := TJSONObject(GetJSON(ParamsJson));
    try
      // navigation failure hints
    finally
      Params.Free;
    end;
  end;
end;

function TBrowserNavigator.EvaluateString(const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): string;
var
  Params, ResultObj, RemoteObj, Val: TJSONObject;
  ExprEsc: string;
begin
  Result := '';
  Params := TJSONObject.Create;
  try
    ExprEsc := StringReplace(Expr, '\', '\\', [rfReplaceAll]);
    ExprEsc := StringReplace(ExprEsc, '"', '\"', [rfReplaceAll]);
    Params.Add('expression', Expr);
    Params.Add('returnByValue', True);
    if not FConnection.SendCommand('Runtime.evaluate', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    try
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

function TBrowserNavigator.EvaluateBoolExpression(const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  S: string;
begin
  S := EvaluateString(Expr, Min(TimeoutMs, 5000), CancelCheck);
  Result := SameText(S, 'true');
end;

function TBrowserNavigator.Navigate(const Url: string; Strategy: TBrowserReadWaitStrategy;
  const WaitSelector: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; out FinalUrl: string;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Params, ResultObj: TJSONObject;
  Start: QWord;
  SelectorExpr: string;
  SelEsc: string;
begin
  FinalUrl := '';
  ErrKind := brekNone;
  ErrMsg := '';
  FDomContentLoaded := False;
  FLoadEventFired := False;
  FNavFailed := False;

  Params := TJSONObject.Create;
  try
    Params.Add('url', Url);
    if not FConnection.SendCommand('Page.navigate', Params, TimeoutMs, CancelCheck, ResultObj) then
    begin
      ErrKind := brekNavigationFailed;
      ErrMsg := 'Page.navigate failed';
      Exit(False);
    end;
    try
      if ResultObj.Find('errorText') <> nil then
      begin
        ErrKind := brekNavigationFailed;
        ErrMsg := ResultObj.Get('errorText', 'Navigation failed');
        Exit(False);
      end;
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;

  Start := GetTickCount64;
  while GetTickCount64 - Start < QWord(TimeoutMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;
    FConnection.PumpEvents(100, CancelCheck);

    case Strategy of
      brwsDomContentLoaded:
        if FDomContentLoaded then Break;
      brwsLoad:
        if FLoadEventFired then Break;
      brwsSelector:
        begin
          SelEsc := StringReplace(WaitSelector, '\', '\\', [rfReplaceAll]);
          SelEsc := StringReplace(SelEsc, '"', '\"', [rfReplaceAll]);
          SelectorExpr := '(() => { try { return document.querySelector("' + SelEsc +
            '") !== null; } catch(e) { return false; } })()';
          if EvaluateBoolExpression(SelectorExpr, 2000, CancelCheck) then
            Break;
        end;
    end;
    Sleep(50);
  end;

  if GetTickCount64 - Start >= QWord(TimeoutMs) then
  begin
    if Strategy = brwsSelector then
    begin
      ErrKind := brekSelectorTimeout;
      ErrMsg := 'Timed out waiting for selector';
    end
    else
    begin
      ErrKind := brekNavigationTimeout;
      ErrMsg := 'Navigation timed out';
    end;
    Exit(False);
  end;

  FinalUrl := EvaluateString('location.href', 5000, CancelCheck);
  Result := True;
end;

end.
