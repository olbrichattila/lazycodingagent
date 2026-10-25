unit uToolBrowserAutomation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase, uBrowserReadTypes,
  uBrowserManager;

type
  TBrowserToolBase = class(TAgentTool)
  protected
    function Config: TBrowserReadConfig;
    function GetSession(const SessionId: string; out S: TBrowserManagedSession;
      out Err: string): Boolean;
    function DenyInteractive: TToolExecutionResult;
    function DenySensitive(const Action: string): TToolExecutionResult;
    function JsonOk(O: TJSONObject): TToolExecutionResult;
    function JsonErr(const Code, Msg: string): TToolExecutionResult;
  end;

  TToolBrowserNavigate = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserInspect = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserClick = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserFill = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserWait = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserClose = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserScreenshot = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserConsole = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserNetwork = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserSelect = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserSetViewport = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  Math, uBrowserReadConfig, uBrowserAutomation,
  uBrowserPageInspector, uBrowserInputController, uBrowserWait, uBrowserScreenshot,
  uBrowserPermissions, uBrowserReadUrl, uChatImageStore, uToolArtifactStore;

type
  TBrowserCancelAdapter = class
  private
    FContext: TAgentToolContext;
  public
    constructor Create(AContext: TAgentToolContext);
    function Check: Boolean;
  end;

constructor TBrowserCancelAdapter.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
end;

function TBrowserCancelAdapter.Check: Boolean;
begin
  Result := Assigned(FContext) and FContext.IsCancelled;
end;

constructor TBrowserToolBase.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TBrowserToolBase.Config: TBrowserReadConfig;
begin
  Result := LoadBrowserReadConfig;
  if FContext.AllowBrowserLocalhost then
    Result.AllowLocalhost := True;
end;

function TBrowserToolBase.GetSession(const SessionId: string;
  out S: TBrowserManagedSession; out Err: string): Boolean;
begin
  S := BrowserSessionFind(SessionId);
  if S = nil then
  begin
    Err := 'Unknown browser session: ' + SessionId;
    Exit(False);
  end;
  if (FContext.ChatSessionId <> '') and (S.ChatSessionId <> '') and
     not SameText(FContext.ChatSessionId, S.ChatSessionId) then
  begin
    Err := 'Session belongs to another chat';
    Exit(False);
  end;
  Result := True;
end;

function TBrowserToolBase.DenyInteractive: TToolExecutionResult;
begin
  Result := JsonErr('ACCESS_DENIED',
    'Enable interactive browser actions for this chat session');
end;

function TBrowserToolBase.DenySensitive(const Action: string): TToolExecutionResult;
begin
  Result := JsonErr('USER_DENIED', 'User denied sensitive browser action: ' + Action);
end;

function TBrowserToolBase.JsonOk(O: TJSONObject): TToolExecutionResult;
begin
  O.Add('success', True);
  Result := ToolResultFromJson(O.AsJSON);
  O.Free;
end;

function TBrowserToolBase.JsonErr(const Code, Msg: string): TToolExecutionResult;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  O.Add('success', False);
  O.Add('error', Msg);
  O.Add('error_code', Code);
  Result := ToolResultFromJson(O.AsJSON);
  O.Free;
end;

constructor TToolBrowserNavigate.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserNavigate.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_navigate';
  Result.Description :=
    'Navigate a browser session to a URL. Creates a session when session_id is omitted.';
  SetLength(Result.Params, 5);
  Result.Params[0].Name := 'url';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'session_id';
  Result.Params[1].ParamType := 'string';
  Result.Params[2].Name := 'wait_strategy';
  Result.Params[2].ParamType := 'string';
  Result.Params[3].Name := 'wait_selector';
  Result.Params[3].ParamType := 'string';
  Result.Params[4].Name := 'timeout_ms';
  Result.Params[4].ParamType := 'integer';
end;

function TToolBrowserNavigate.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Url, Sid, WaitSel, FinalUrl, Title: string;
  Strategy: TBrowserReadWaitStrategy;
  TimeoutMs: Integer;
  S: TBrowserManagedSession;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg, Err: string;
  O: TJSONObject;
  Adapter: TBrowserCancelAdapter;
  Cfg: TBrowserReadConfig;
begin
  Url := Args.Get('url', '');
  if Trim(Url) = '' then
    Exit(JsonErr('INVALID_ARGUMENT', 'url is required'));
  Sid := Args.Get('session_id', '');
  if not ParseBrowserReadWaitStrategy(Args.Get('wait_strategy', 'load'), Strategy) then
    Exit(JsonErr('INVALID_ARGUMENT', 'invalid wait_strategy'));
  WaitSel := Args.Get('wait_selector', '');
  TimeoutMs := Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS);
  Cfg := Config;
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    if Sid = '' then
    begin
      if not ValidateBrowserReadUrl(Url, Cfg.AllowLocalhost or FContext.AllowBrowserLocalhost,
        ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
      if (Pos('127.0.0.1', LowerCase(Url)) > 0) or (Pos('localhost', LowerCase(Url)) > 0) then
        if not FContext.AllowBrowserLocalhost and not Cfg.AllowLocalhost then
          Exit(JsonErr('ACCESS_DENIED', 'Localhost browsing requires permission'));
      if not BrowserSessionCreate(FContext.WorkspaceRoot, FContext.ChatSessionId,
        FContext.AllowBrowserLocalhost or Cfg.AllowLocalhost, Cfg,
        @Adapter.Check, S, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
      Sid := S.Id;
    end
    else if not GetSession(Sid, S, Err) then
      Exit(JsonErr('SESSION_NOT_FOUND', Err));

    S.Lock.Enter;
    try
      if not BrowserAutomationNavigate(S, Url, Strategy, WaitSel, TimeoutMs, @Adapter.Check,
        FinalUrl, Title, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;

    O := TJSONObject.Create;
    O.Add('session_id', Sid);
    O.Add('url', FinalUrl);
    O.Add('title', Title);
    O.Add('status', 'ok');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserInspect.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserInspect.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_inspect';
  Result.Description := 'Inspect the current browser page (title, URL, elements, links, forms).';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].ParamType := 'string';
  Result.Params[2].Name := 'include_links';
  Result.Params[2].ParamType := 'boolean';
  Result.Params[3].Name := 'include_forms';
  Result.Params[3].ParamType := 'boolean';
  Result.Params[4].Name := 'include_accessibility';
  Result.Params[4].ParamType := 'boolean';
  Result.Params[5].Name := 'max_length';
  Result.Params[5].ParamType := 'integer';
end;

function TToolBrowserInspect.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Adapter: TBrowserCancelAdapter;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      O := BrowserInspectPage(S, Args.Get('selector', ''),
        Args.Get('include_links', True), Args.Get('include_forms', True),
        Args.Get('include_accessibility', False),
        Args.Get('max_length', BROWSER_READ_DEFAULT_MAX_LENGTH),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check);
    finally
      S.Lock.Leave;
    end;
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserClick.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserClick.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_click';
  Result.Description := 'Click an element via CDP pointer events.';
  SetLength(Result.Params, 5);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'timeout_ms';
  Result.Params[2].ParamType := 'integer';
  Result.Params[3].Name := 'click_count';
  Result.Params[3].ParamType := 'integer';
  Result.Params[4].Name := 'ref';
  Result.Params[4].ParamType := 'string';
end;

function TToolBrowserClick.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  AllowSession: Boolean;
  Sel, Ref: string;
  O: TJSONObject;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Sel := Args.Get('selector', '');
  Ref := Args.Get('ref', '');
  if BrowserActionLooksSensitive(Sel, Ref) and not FContext.AllowBrowserSensitive then
  begin
    AllowSession := False;
    if not RequestBrowserSensitiveConfirm('Allow clicking: ' + Sel + '?', AllowSession) then
      Exit(DenySensitive('click'));
    if AllowSession then
      FContext.AllowBrowserSensitive := True;
  end;
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserClickElement(S, Sel, Ref, Args.Get('timeout_ms',
        BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), Args.Get('click_count', 1),
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('session_id', S.Id);
    O.Add('status', 'clicked');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserFill.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserFill.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_fill';
  Result.Description := 'Fill an input or textarea (password values are not logged).';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'value';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'clear_first';
  Result.Params[3].ParamType := 'boolean';
  Result.Params[4].Name := 'ref';
  Result.Params[4].ParamType := 'string';
  Result.Params[5].Name := 'timeout_ms';
  Result.Params[5].ParamType := 'integer';
end;

function TToolBrowserFill.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
  Val: string;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Val := Args.Get('value', '');
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserFillElement(S, Args.Get('selector', ''), Args.Get('ref', ''), Val,
        Args.Get('clear_first', True), Args.Get('timeout_ms',
        BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('session_id', S.Id);
    O.Add('status', 'filled');
    if Pos('password', LowerCase(Args.Get('selector', ''))) > 0 then
      O.Add('value_logged', False);
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserWait.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserWait.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_wait';
  Result.Description := 'Wait for selector, text, URL, or document ready.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'condition';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'selector';
  Result.Params[3].Name := 'text';
  Result.Params[4].Name := 'url_pattern';
  Result.Params[5].Name := 'timeout_ms';
end;

function TToolBrowserWait.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserWaitCondition(S, Args.Get('condition', ''), Args.Get('selector', ''),
        Args.Get('text', ''), Args.Get('url_pattern', ''),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check,
        ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'ok');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserClose.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserClose.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_close';
  Result.Description := 'Close a browser session and release resources.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
end;

function TToolBrowserClose.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Sid: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  Sid := Args.Get('session_id', '');
  if Sid = '' then
    Exit(JsonErr('INVALID_ARGUMENT', 'session_id required'));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    if not BrowserSessionClose(Sid, @Adapter.Check) then
      Exit(JsonErr('SESSION_NOT_FOUND', 'Session not found'));
    O := TJSONObject.Create;
    O.Add('closed', Sid);
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserScreenshot.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserScreenshot.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_screenshot';
  Result.Description := 'Capture a PNG/JPEG screenshot; returns artifact_path for text providers.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'full_page';
  Result.Params[2].Name := 'selector';
  Result.Params[3].Name := 'format';
  Result.Params[4].Name := 'quality';
  Result.Params[5].Name := 'timeout_ms';
end;

function TToolBrowserScreenshot.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  Rel, Abs: string;
  O: TJSONObject;
  Att: TChatAttachment;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserCaptureScreenshot(S, FContext.WorkspaceRoot,
        Args.Get('full_page', False), Args.Get('selector', ''),
        Args.Get('format', 'png'), Args.Get('quality', 85),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check,
        Rel, Abs, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('artifact_path', Rel);
    O.Add('absolute_path', Abs);
    Result := JsonOk(O);
    SetLength(Result.Attachments, 1);
    Att.Kind := cakImage;
    Att.RelativePath := Rel;
    Att.OriginalName := ExtractFileName(Abs);
    Att.MimeType := MimeTypeFromImageFileName(Abs);
    Result.Attachments[0] := Att;
    Result.Summary := 'Screenshot saved';
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserConsole.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserConsole.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_console';
  Result.Description := 'Read browser console messages and JS errors.';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'level';
  Result.Params[2].Name := 'since_last_read';
  Result.Params[3].Name := 'max_entries';
end;

function TToolBrowserConsole.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Entries: TJSONArray;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Entries := S.ConsoleLog.ReadEntries(Args.Get('since_last_read', True),
    Args.Get('level', ''), Args.Get('max_entries', 100));
  O := TJSONObject.Create;
  O.Add('entries', Entries);
  Result := JsonOk(O);
end;

constructor TToolBrowserNetwork.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserNetwork.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_network';
  Result.Description := 'Inspect network request metadata (no bodies).';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'failed_only';
  Result.Params[2].Name := 'status_min';
  Result.Params[3].Name := 'max_entries';
end;

function TToolBrowserNetwork.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Entries: TJSONArray;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Entries := S.NetworkLog.ReadEntries(Args.Get('failed_only', False),
    Args.Get('status_min', 0), Args.Get('max_entries', 100));
  O := TJSONObject.Create;
  O.Add('entries', Entries);
  Result := JsonOk(O);
end;

constructor TToolBrowserSelect.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserSelect.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_select';
  Result.Description := 'Select an option on a native HTML select element.';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'value';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'timeout_ms';
end;

function TToolBrowserSelect.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserSelectOption(S, Args.Get('selector', ''), Args.Get('ref', ''),
        Args.Get('value', ''), Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS),
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'selected');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserSetViewport.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserSetViewport.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_set_viewport';
  Result.Description := 'Set viewport size for responsive testing (not full device emulation).';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'width';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'height';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'device_scale_factor';
end;

function TToolBrowserSetViewport.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserAutomationSetViewport(S, Args.Get('width', 1280), Args.Get('height', 720),
        Args.Get('device_scale_factor', 1.0), BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS,
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'ok');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

end.
