unit LcaMarkdownView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, Forms, LCLType, LMessages, Types,
  IpHtml, LcaTheme, LcaScrollHost;

const
  LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES = 20;
  LCA_MARKDOWN_HTML_LAYOUT_MIN_HEIGHT = 512;
  LCA_MARKDOWN_CONTENT_HEIGHT_SLACK = 3;
  LCA_MARKDOWN_RESIZE_QUIESCENCE_MS = 120;
  { LCL SendMoveSizeMessages rejects control sizes above ~32767 on Win32. }
  LCA_MARKDOWN_MAX_CONTENT_EXTENT = 32767;

type
  TLcaMarkdownView = class;

  { Forwards wheel to TLcaScrollHost; IPro must not keep native scroll. }
  TLcaMarkdownHtmlPanel = class(TIpHtmlPanel)
  private
    FScrollHost: TLcaScrollHost;
    FOwnerView: TLcaMarkdownView;
  protected
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
  public
    procedure BindScrollHost(AHost: TLcaScrollHost);
    procedure BindOwnerView(AView: TLcaMarkdownView);
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure Click; override;
  end;

  TLcaMarkdownView = class(TPanel)
  private
    FScrollHost: TLcaScrollHost;
    FHtmlPanel: TControl;
    FThemeKind: TThemeKind;
    FLastLayoutViewportW: Integer;
    FLastSyncedContentW: Integer;
    FLastSyncedContentH: Integer;
    FMarkdown: string;
    FRawHtml: string;
    FUseRawHtml: Boolean;
    FRenderDeferRetries: Integer;
    FRenderDeferQueued: Boolean;
    FRendering: Boolean;
    FScrollToEndPending: Boolean;
    FScrollDeferRetries: Integer;
    FScrollDeferQueued: Boolean;
    FContentSyncQueued: Boolean;
    FContentSyncDeferRetries: Integer;
    FContentStabilityMeasureH: Integer;
    FViewportReflowQueued: Boolean;
    FViewportReflowDeadline: QWord;
    FLastRenderedMarkdownLen: Integer;
    FLastRenderedRawHtmlLen: Integer;
    function ShouldResetLayoutBeforeRender: Boolean;
    procedure SetHtmlPanelRedrawActive(AActive: Boolean);
    procedure SetThemeKind(AValue: TThemeKind);
    procedure ApplyViewportWidthReflow;
    procedure ScheduleDebouncedViewportReflow;
    procedure DeferredViewportReflow(Data: PtrInt);
    function HostReadyForRender: Boolean;
    procedure EnsureViewer;
    procedure ScheduleDeferredRender;
    procedure DeferredRender(Data: PtrInt);
    procedure ScheduleDeferredScrollToEnd;
    procedure DeferredScrollToEnd(Data: PtrInt);
    procedure ScrollDocumentToEnd;
    function IsDocumentScrolledToEnd: Boolean;
    procedure ScheduleScrollToEndAfterRender;
    procedure Render;
    function SyncContentLayout: Boolean;
    procedure ScheduleDeferredContentSync;
    procedure DeferredContentSync(Data: PtrInt);
    procedure ResetContentLayoutState;
    procedure EnsureScrollHostFillsClient;
    procedure DisableIpHtmlNativeScroll(APanel: TIpHtmlPanel);
    procedure EnsureHyperWheelBridge(HP: TIpHtmlInternalPanel);
    procedure HtmlDocumentOpened(Sender: TObject);
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure CMShowingChanged(var Message: TLMessage); message CM_SHOWINGCHANGED;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean = False);
    procedure SetHtmlBody(const AFullHtml: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure NotifyContentMaybeResized;
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property Align;
  end;

function MarkdownSubsetToHtml(const AMarkdown: string): string;
function WrapThemedHtmlDocument(const ABodyHtml: string; ATheme: TThemeKind): string;

implementation

uses
  Math, LCLIntf, IpHtmlTypes, StrUtils, LcaUiPaintProfile
  {$IFDEF LCLwin32}, Windows{$ENDIF};

function ColorToHex(AColor: TColor): string;
begin
  Result := '#' + LowerCase(IntToHex(Red(AColor), 2) + IntToHex(Green(AColor), 2) +
    IntToHex(Blue(AColor), 2));
end;

function EscapeHtml(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do begin
    C := S[I];
    case C of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
    else
      Result := Result + C;
    end;
  end;
end;

function InlineMarkdownToHtml(const S: string): string;
var
  I, N: Integer;
  InBold, InCode: Boolean;
  Token: string;
begin
  Result := '';
  I := 1;
  InBold := False;
  InCode := False;
  while I <= Length(S) do begin
    if (I + 1 <= Length(S)) and (S[I] = '*') and (S[I + 1] = '*') then begin
      if InCode then
        Result := Result + EscapeHtml(Copy(S, I, 2))
      else begin
        if InBold then
          Result := Result + '</strong>'
        else
          Result := Result + '<strong>';
        InBold := not InBold;
      end;
      Inc(I, 2);
      Continue;
    end;
    if S[I] = '`' then begin
      if InBold then
        Result := Result + '`'
      else begin
        if InCode then
          Result := Result + '</code>'
        else
          Result := Result + '<code>';
        InCode := not InCode;
      end;
      Inc(I);
      Continue;
    end;
    N := I;
    while (N <= Length(S)) and not (
      ((N + 1 <= Length(S)) and (S[N] = '*') and (S[N + 1] = '*')) or (S[N] = '`')) do
      Inc(N);
    Token := Copy(S, I, N - I);
    Result := Result + EscapeHtml(Token);
    I := N;
  end;
  if InBold then
    Result := Result + '</strong>';
  if InCode then
    Result := Result + '</code>';
end;

function MarkdownImageLineToHtml(const ALine: string): string;
var
  S, Alt, Url: string;
  P1, P2: Integer;
begin
  Result := '';
  S := Trim(ALine);
  if Length(S) < 5 then Exit;
  if not ((S[1] = '!') and (S[2] = '[')) then Exit;
  P1 := Pos(']', S);
  if P1 <= 3 then Exit;
  Alt := Copy(S, 3, P1 - 3);
  if (P1 + 1 > Length(S)) or (S[P1 + 1] <> '(') then Exit;
  P2 := PosEx(')', S, P1 + 2);
  if P2 = 0 then Exit;
  Url := Copy(S, P1 + 2, P2 - P1 - 2);
  if not (StartsText('file://', Url) or StartsText('http://', Url) or
    StartsText('https://', Url)) then
    Exit;
  Result := '<p><img src="' + EscapeHtml(Url) + '" alt="' + EscapeHtml(Alt) +
    '" class="lca-md-img"/></p>';
end;

function MarkdownSubsetToHtml(const AMarkdown: string): string;
var
  Lines: TStringList;
  I, Level: Integer;
  Line, Trimmed, FenceLang: string;
  InFence: Boolean;
  InList: Boolean;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := AMarkdown;
    InFence := False;
    InList := False;
    FenceLang := '';
    for I := 0 to Lines.Count - 1 do begin
      Line := Lines[I];
      Trimmed := Trim(Line);
      if InFence then begin
        if Trimmed = '```' then begin
          Result := Result + '</pre>';
          InFence := False;
          FenceLang := '';
        end else
          Result := Result + EscapeHtml(Line) + #10;
        Continue;
      end;
      if (Length(Trimmed) >= 3) and (Copy(Trimmed, 1, 3) = '```') then begin
        if InList then begin
          Result := Result + '</ul>';
          InList := False;
        end;
        FenceLang := Trim(Copy(Trimmed, 4, MaxInt));
        Result := Result + '<pre><code>';
        if FenceLang <> '' then
          Result := Result + '<!-- ' + EscapeHtml(FenceLang) + ' -->';
        InFence := True;
        Continue;
      end;
      if Trimmed = '' then begin
        if InList then begin
          Result := Result + '</ul>';
          InList := False;
        end;
        Result := Result + '<p></p>';
        Continue;
      end;
      if (Length(Trimmed) > 0) and (Trimmed[1] = '#') then begin
        if InList then begin
          Result := Result + '</ul>';
          InList := False;
        end;
        Level := 0;
        while (Level < Length(Trimmed)) and (Trimmed[Level + 1] = '#') do
          Inc(Level);
        if (Level >= 1) and (Level <= 6) and ((Level = Length(Trimmed)) or (Trimmed[Level + 1] = ' ')) then begin
          Line := Trim(Copy(Trimmed, Level + 1, MaxInt));
          Result := Result + Format('<h%d>%s</h%d>', [Level, InlineMarkdownToHtml(Line), Level]);
          Continue;
        end;
      end;
      if (Length(Trimmed) >= 2) and ((Copy(Trimmed, 1, 2) = '- ') or (Copy(Trimmed, 1, 2) = '* ')) then begin
        if not InList then begin
          Result := Result + '<ul>';
          InList := True;
        end;
        Line := Trim(Copy(Trimmed, 3, MaxInt));
        Result := Result + '<li>' + InlineMarkdownToHtml(Line) + '</li>';
        Continue;
      end;
      if InList then begin
        Result := Result + '</ul>';
        InList := False;
      end;
      if MarkdownImageLineToHtml(Trimmed) <> '' then begin
        Result := Result + MarkdownImageLineToHtml(Trimmed);
        Continue;
      end;
      Result := Result + '<p>' + InlineMarkdownToHtml(Trimmed) + '</p>';
    end;
    if InList then
      Result := Result + '</ul>';
    if InFence then
      Result := Result + '</pre></code>';
  finally
    Lines.Free;
  end;
end;

function WrapThemedHtmlDocument(const ABodyHtml: string; ATheme: TThemeKind): string;
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  Result :=
    '<html><head><meta charset="utf-8"><style>' +
    'body { font-family: Segoe UI, sans-serif; font-size: 10pt; margin: 8px; ' +
    'background: ' + ColorToHex(P.Background) + '; color: ' + ColorToHex(P.Text) + '; } ' +
    'h1 { color: ' + ColorToHex(P.Text) + '; font-size: 1.35em; font-weight: bold; ' +
    'margin: 0.5em 0 0.35em; } ' +
    'h2 { color: ' + ColorToHex(P.Text) + '; font-size: 1.2em; font-weight: bold; ' +
    'margin: 0.5em 0 0.3em; } ' +
    'h3 { color: ' + ColorToHex(P.Text) + '; font-size: 1.05em; font-weight: bold; ' +
    'margin: 0.45em 0 0.25em; } ' +
    'p { margin: 0.4em 0; line-height: 1.45; } ' +
    'code { font-family: Consolas, monospace; background: ' + ColorToHex(P.SurfaceAlt) +
    '; padding: 1px 4px; border-radius: 3px; } ' +
    'pre { background: ' + ColorToHex(P.SurfaceAlt) + '; padding: 8px; ' +
    'border: 1px solid ' + ColorToHex(P.Border) + '; border-radius: 4px; overflow-x: auto; } ' +
    'pre code { background: transparent; padding: 0; } ' +
    'ul { margin: 0.4em 0 0.4em 1.2em; } ' +
    '.msg-user { border-left: 3px solid ' + ColorToHex(P.Accent) + '; padding-left: 8px; ' +
    'margin: 10px 0; } ' +
    '.msg-assistant { padding-left: 8px; margin: 10px 0; } ' +
    '.msg-tool { color: ' + ColorToHex(P.TextMuted) + '; font-size: 9pt; margin: 6px 0; } ' +
    '.msg-label { font-weight: bold; color: ' + ColorToHex(P.TextMuted) + '; } ' +
    'img.lca-md-img { max-width: 100%; height: auto; border-radius: 4px; ' +
    'border: 1px solid ' + ColorToHex(P.Border) + '; margin: 4px 0; } ' +
    '</style></head><body>' + ABodyHtml + '</body></html>';
end;

procedure TLcaMarkdownView.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

constructor TLcaMarkdownView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  AutoSize := False;
  FThemeKind := tkDark;
  FMarkdown := '';
  FRawHtml := '';
  FUseRawHtml := False;
  FRenderDeferRetries := 0;
  FRenderDeferQueued := False;
  FRendering := False;
  FScrollToEndPending := False;
  FScrollDeferRetries := 0;
  FScrollDeferQueued := False;
  FLastLayoutViewportW := 0;
  FLastSyncedContentW := 0;
  FLastSyncedContentH := 0;
  FContentSyncQueued := False;
  FContentSyncDeferRetries := 0;
  FContentStabilityMeasureH := -1;
  FViewportReflowQueued := False;
  FViewportReflowDeadline := 0;
  FLastRenderedMarkdownLen := 0;
  FLastRenderedRawHtmlLen := 0;
end;

procedure TLcaMarkdownHtmlPanel.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  LcaUiProfileRecordIpHtmlSetBounds;
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TLcaMarkdownHtmlPanel.BindScrollHost(AHost: TLcaScrollHost);
begin
  FScrollHost := AHost;
end;

procedure TLcaMarkdownHtmlPanel.BindOwnerView(AView: TLcaMarkdownView);
begin
  FOwnerView := AView;
end;

procedure TLcaMarkdownHtmlPanel.Click;
begin
  inherited Click;
  if Assigned(FOwnerView) then
    FOwnerView.NotifyContentMaybeResized;
end;

function TLcaMarkdownHtmlPanel.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if Assigned(FScrollHost) then begin
    FScrollHost.HandleHostWheel(Shift, WheelDelta);
    Exit(True);
  end;
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

destructor TLcaMarkdownView.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  FHtmlPanel := nil;
  FScrollHost := nil;
  inherited Destroy;
end;

type
  { Intercepts wheel on IPro HyperPanel before IPro marks it handled with no host scroll. }
  TLcaIproHyperWheelBridge = class(TComponent)
  private
    FHyper: TIpHtmlInternalPanel;
    FScrollHost: TLcaScrollHost;
    FPrevWindowProc: TWndMethod;
    FChained: Boolean;
    procedure HyperWindowProc(var Message: TLMessage);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure Attach(AHyper: TIpHtmlInternalPanel; AHost: TLcaScrollHost);
    procedure Detach;
    procedure UpdateScrollHost(AHost: TLcaScrollHost);
    function IsBoundTo(AHyper: TIpHtmlInternalPanel): Boolean;
  end;

function TLcaIproHyperWheelBridge.IsBoundTo(AHyper: TIpHtmlInternalPanel): Boolean;
begin
  Result := FHyper = AHyper;
end;

destructor TLcaIproHyperWheelBridge.Destroy;
begin
  Detach;
  inherited Destroy;
end;

procedure TLcaIproHyperWheelBridge.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FHyper) then
    Detach;
end;

procedure TLcaIproHyperWheelBridge.Detach;
begin
  if FChained and Assigned(FHyper) then
    FHyper.WindowProc := FPrevWindowProc;
  FChained := False;
  FPrevWindowProc := nil;
  if Assigned(FHyper) then
    FHyper.RemoveFreeNotification(Self);
  FHyper := nil;
  FScrollHost := nil;
end;

procedure TLcaIproHyperWheelBridge.UpdateScrollHost(AHost: TLcaScrollHost);
begin
  FScrollHost := AHost;
end;

procedure TLcaIproHyperWheelBridge.Attach(AHyper: TIpHtmlInternalPanel;
  AHost: TLcaScrollHost);
begin
  if (FHyper = AHyper) and FChained then begin
    UpdateScrollHost(AHost);
    Exit;
  end;
  Detach;
  FHyper := AHyper;
  FScrollHost := AHost;
  if not Assigned(FHyper) then Exit;
  FHyper.FreeNotification(Self);
  FPrevWindowProc := FHyper.WindowProc;
  FHyper.WindowProc := @HyperWindowProc;
  FChained := True;
end;

procedure TLcaIproHyperWheelBridge.HyperWindowProc(var Message: TLMessage);
var
  Ev: TLMMouseEvent absolute Message;
  ShiftState: TShiftState;
begin
  if Assigned(FScrollHost) and ((Message.Msg = LM_MOUSEWHEEL) or
    (Message.Msg = LM_MOUSEHWHEEL)) then begin
    ShiftState := Ev.State - [ssCaps, ssNum, ssScroll];
    if Message.Msg = LM_MOUSEHWHEEL then
      Include(ShiftState, ssShift);
    FScrollHost.HandleHostWheel(ShiftState, Ev.WheelDelta);
    Message.Result := 1;
    Exit;
  end;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TLcaMarkdownView.EnsureHyperWheelBridge(HP: TIpHtmlInternalPanel);
var
  I: Integer;
  B: TLcaIproHyperWheelBridge;
begin
  if csDestroying in ComponentState then Exit;
  if not Assigned(FScrollHost) or not Assigned(HP) then Exit;
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TLcaIproHyperWheelBridge then begin
      B := TLcaIproHyperWheelBridge(Components[I]);
      if B.IsBoundTo(HP) then begin
        B.UpdateScrollHost(FScrollHost);
        Exit;
      end;
    end;
  B := TLcaIproHyperWheelBridge.Create(Self);
  B.Attach(HP, FScrollHost);
end;

function ClampMarkdownContentExtent(AValue: Integer): Integer;
begin
  if AValue <= 0 then
    Result := AValue
  else if AValue > LCA_MARKDOWN_MAX_CONTENT_EXTENT then
    Result := LCA_MARKDOWN_MAX_CONTENT_EXTENT
  else
    Result := AValue;
end;

function TLcaMarkdownView.HostReadyForRender: Boolean;
begin
  Result := HandleAllocated and Showing and (ClientWidth > 0) and (ClientHeight > 0);
end;

procedure TLcaMarkdownView.ScheduleDeferredRender;
begin
  if FRenderDeferQueued then Exit;
  if FRenderDeferRetries >= LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES then
    Exit;
  Inc(FRenderDeferRetries);
  FRenderDeferQueued := True;
  Application.QueueAsyncCall(@DeferredRender, PtrInt(Self));
end;

procedure TLcaMarkdownView.DeferredRender(Data: PtrInt);
begin
  FRenderDeferQueued := False;
  if PtrInt(Self) <> Data then Exit;
  Render;
end;

function TLcaMarkdownView.IsDocumentScrolledToEnd: Boolean;
var
  Panel: TIpHtmlPanel;
  Sz, Synced: TSize;
begin
  Result := False;
  if not Assigned(FScrollHost) or not Assigned(FHtmlPanel) then Exit;
  if csDestroying in ComponentState then Exit;
  Panel := TIpHtmlPanel(FHtmlPanel);
  Sz := Panel.GetContentSize;
  if Sz.cy <= 0 then Exit;
  Synced := FScrollHost.SyncedContentExtent;
  if Sz.cy > Synced.cy + LCA_MARKDOWN_CONTENT_HEIGHT_SLACK then begin
    ScheduleDeferredContentSync;
    Exit;
  end;
  if Synced.cy <= 0 then Exit;
  if not FScrollHost.ContentScrolledToEnd then Exit;
  Result := True;
end;

procedure TLcaMarkdownView.ScrollDocumentToEnd;
begin
  if not Assigned(FScrollHost) then Exit;
  if csDestroying in ComponentState then Exit;
  FScrollHost.ScrollContentToEnd;
end;

procedure SuppressIpHtmlInternalScroll(HP: TIpHtmlInternalPanel);
begin
  HP.HScroll.Visible := False;
  HP.VScroll.Visible := False;
  HP.HScroll.Position := 0;
  HP.VScroll.Position := 0;
end;

{$IFDEF LCLwin32}
procedure HideWin32ScrollChrome(AWin: TWinControl);
var
  Style: PtrUInt;
const
  GWL_STYLE_WIN32 = -16;
begin
  if not Assigned(AWin) or not AWin.HandleAllocated then Exit;
  Style := GetWindowLongPtr(AWin.Handle, GWL_STYLE_WIN32);
  if (Style and (WS_VSCROLL or WS_HSCROLL)) <> 0 then begin
    SetWindowLongPtr(AWin.Handle, GWL_STYLE_WIN32, Style and not (WS_VSCROLL or WS_HSCROLL));
    SetWindowPos(AWin.Handle, 0, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_FRAMECHANGED or SWP_NOACTIVATE);
  end;
  ShowScrollBar(AWin.Handle, SB_VERT, False);
  ShowScrollBar(AWin.Handle, SB_HORZ, False);
end;
{$ENDIF}

procedure DisableIpHtmlPanelChromeScroll(APanel: TWinControl; AOwnerView: TLcaMarkdownView);

  procedure WalkIproHosts(AHost: TWinControl);
  var
    I: Integer;
    C: TControl;
    HP: TIpHtmlInternalPanel;
  begin
    if AHost is TIpHtmlInternalPanel then begin
      HP := TIpHtmlInternalPanel(AHost);
      SuppressIpHtmlInternalScroll(HP);
      {$IFDEF LCLwin32}
      HideWin32ScrollChrome(HP);
      {$ENDIF}
      if Assigned(AOwnerView) then
        AOwnerView.EnsureHyperWheelBridge(HP);
    end;
    for I := 0 to AHost.ControlCount - 1 do begin
      C := AHost.Controls[I];
      if C is TWinControl then
        WalkIproHosts(TWinControl(C));
    end;
  end;

begin
  { IPro HyperPanel hosts only — do not ShowScrollBar on embedded HTML form controls (Qt breaks). }
  if not Assigned(APanel) then Exit;
  WalkIproHosts(APanel);
  {$IFDEF LCLwin32}
  HideWin32ScrollChrome(APanel);
  {$ENDIF}
end;

procedure TLcaMarkdownView.DisableIpHtmlNativeScroll(APanel: TIpHtmlPanel);
begin
  if not Assigned(APanel) then Exit;
  APanel.VScrollPos := 0;
  DisableIpHtmlPanelChromeScroll(APanel, Self);
end;

procedure TLcaMarkdownView.HtmlDocumentOpened(Sender: TObject);
begin
  if Sender is TIpHtmlPanel then
    DisableIpHtmlNativeScroll(TIpHtmlPanel(Sender));
  ScheduleDeferredContentSync;
end;

procedure TLcaMarkdownView.NotifyContentMaybeResized;
begin
  if csDestroying in ComponentState then Exit;
  ScheduleDeferredContentSync;
end;

procedure TLcaMarkdownView.ResetContentLayoutState;
begin
  FLastSyncedContentW := 0;
  FLastSyncedContentH := 0;
  FContentSyncDeferRetries := 0;
  FContentStabilityMeasureH := -1;
  FLastRenderedMarkdownLen := 0;
  FLastRenderedRawHtmlLen := 0;
  if Assigned(FScrollHost) then
    FScrollHost.UpdateContentExtent(0, 0);
end;

procedure TLcaMarkdownView.ScheduleDeferredContentSync;
begin
  if FContentSyncQueued then Exit;
  if csDestroying in ComponentState then Exit;
  FContentSyncQueued := True;
  Application.QueueAsyncCall(@DeferredContentSync, PtrInt(Self));
end;

procedure TLcaMarkdownView.DeferredContentSync(Data: PtrInt);
var
  Settled: Boolean;
begin
  FContentSyncQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if not Assigned(FHtmlPanel) or not Assigned(FScrollHost) then Exit;
  Settled := SyncContentLayout;
  if FScrollToEndPending and Settled then begin
    ScrollDocumentToEnd;
    if IsDocumentScrolledToEnd then begin
      FScrollToEndPending := False;
      FScrollDeferRetries := 0;
    end else
      ScheduleDeferredScrollToEnd;
  end;
end;

procedure TLcaMarkdownView.EnsureScrollHostFillsClient;
begin
  if not Assigned(FScrollHost) then Exit;
  if (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;
  if FScrollHost.Align <> alNone then
    FScrollHost.Align := alNone;
  FScrollHost.Anchors := [akLeft, akTop, akRight, akBottom];
  FScrollHost.SetBounds(0, 0, ClientWidth, ClientHeight);
  FScrollHost.Update;
end;

function TLcaMarkdownView.SyncContentLayout: Boolean;
var
  Panel: TIpHtmlPanel;
  Sz, ViewSz: TSize;
  ViewW, CW, CH, LayPanelH: Integer;
  NeedUpdate: Boolean;
begin
  Result := False;
  if not Assigned(FScrollHost) or not Assigned(FHtmlPanel) then Exit;
  if csDestroying in ComponentState then Exit;
  LcaUiProfileRecordMarkdownSyncContent;
  EnsureScrollHostFillsClient;
  Panel := TIpHtmlPanel(FHtmlPanel);
  ViewSz := FScrollHost.LayoutViewportSize;
  ViewW := Max(1, ViewSz.cx);
  FLastLayoutViewportW := ViewW;
  LayPanelH := Max(LCA_MARKDOWN_HTML_LAYOUT_MIN_HEIGHT, Max(FLastSyncedContentH,
    Max(1, ViewSz.cy)));
  if (Panel.Width <> ViewW) or (Panel.Height < LayPanelH) then
    Panel.SetBounds(0, 0, ViewW, Max(Panel.Height, LayPanelH));
  LcaUiProfileRecordMarkdownGetContentSize;
  Sz := Panel.GetContentSize;
  Sz.cx := ClampMarkdownContentExtent(Sz.cx);
  Sz.cy := ClampMarkdownContentExtent(Sz.cy);
  if Sz.cy <= 0 then begin
    if FContentSyncDeferRetries < LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES then begin
      Inc(FContentSyncDeferRetries);
      ScheduleDeferredContentSync;
    end;
    Exit;
  end;
  FContentSyncDeferRetries := 0;
  CH := Sz.cy;
  if Sz.cx > ViewW then
    CW := Sz.cx
  else
    CW := ViewW;
  CW := ClampMarkdownContentExtent(CW);
  CH := ClampMarkdownContentExtent(CH);
  NeedUpdate := False;
  if (CH > FLastSyncedContentH) or (CW <> FLastSyncedContentW) then
    NeedUpdate := True
  else if (FLastSyncedContentW <> CW) or (FLastSyncedContentH <> CH) then begin
    if (FLastSyncedContentH <= 0) or (Abs(CH - FLastSyncedContentH) >= LCA_MARKDOWN_CONTENT_HEIGHT_SLACK) then
      NeedUpdate := True;
  end;
  if not NeedUpdate then begin
    Result := (FLastSyncedContentH > 0) and (FContentStabilityMeasureH = CH);
    if Result then Exit;
    if FContentStabilityMeasureH <> CH then
      FContentStabilityMeasureH := CH
    else if FContentSyncDeferRetries < LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES then begin
      Inc(FContentSyncDeferRetries);
      ScheduleDeferredContentSync;
    end else
      Result := True;
    Exit;
  end;
  FLastSyncedContentW := CW;
  FLastSyncedContentH := CH;
  FScrollHost.UpdateContentExtent(CW, CH);
  DisableIpHtmlNativeScroll(Panel);
  FContentStabilityMeasureH := CH;
  Result := True;
end;

procedure TLcaMarkdownView.ScheduleDeferredScrollToEnd;
begin
  if FScrollDeferQueued then Exit;
  if FScrollDeferRetries >= 4 then begin
    FScrollToEndPending := False;
    FScrollDeferRetries := 0;
    Exit;
  end;
  Inc(FScrollDeferRetries);
  FScrollDeferQueued := True;
  Application.QueueAsyncCall(@DeferredScrollToEnd, PtrInt(Self));
end;

procedure TLcaMarkdownView.DeferredScrollToEnd(Data: PtrInt);
begin
  FScrollDeferQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if not FScrollToEndPending then Exit;
  if not Assigned(FHtmlPanel) or not HostReadyForRender then begin
    ScheduleDeferredScrollToEnd;
    Exit;
  end;
  if not SyncContentLayout then begin
    ScheduleDeferredScrollToEnd;
    Exit;
  end;
  ScrollDocumentToEnd;
  if IsDocumentScrolledToEnd then begin
    FScrollToEndPending := False;
    FScrollDeferRetries := 0;
  end else
    ScheduleDeferredScrollToEnd;
end;

procedure TLcaMarkdownView.ScheduleScrollToEndAfterRender;
begin
  if not FScrollToEndPending then Exit;
  FScrollDeferRetries := 0;
  ScheduleDeferredScrollToEnd;
end;

procedure TLcaMarkdownView.EnsureViewer;
var
  Html: TLcaMarkdownHtmlPanel;
begin
  if csDesigning in ComponentState then Exit;
  if (csDestroying in ComponentState) or not HandleAllocated then Exit;
  if Assigned(FHtmlPanel) then Exit;
  DisableAutoSizing;
  try
    if not Assigned(FScrollHost) then begin
      FScrollHost := TLcaScrollHost.Create(Self);
      FScrollHost.Parent := Self;
      FScrollHost.ThemeKind := FThemeKind;
      FScrollHost.SetViewportFillColor(ThemePalette(FThemeKind).Background);
      FScrollHost.AutoSize := False;
      EnsureScrollHostFillsClient;
    end;
    Html := TLcaMarkdownHtmlPanel.Create(Self);
    Html.Parent := FScrollHost;
    Html.BindScrollHost(FScrollHost);
    Html.BindOwnerView(Self);
    Html.BorderStyle := bsNone;
    Html.AllowTextSelect := True;
    Html.DefaultTypeFace := 'Segoe UI';
    Html.FixedTypeface := 'Consolas';
    Html.AutoSize := False;
    Html.OnDocumentOpen := @HtmlDocumentOpened;
    FHtmlPanel := Html;
    FScrollHost.Content := Html;
  finally
    EnableAutoSizing;
  end;
end;

function TLcaMarkdownView.ShouldResetLayoutBeforeRender: Boolean;
var
  CurLen, LastLen: Integer;
begin
  if FUseRawHtml then begin
    CurLen := Length(FRawHtml);
    LastLen := FLastRenderedRawHtmlLen;
  end else begin
    CurLen := Length(FMarkdown);
    LastLen := FLastRenderedMarkdownLen;
  end;
  if LastLen <= 0 then Exit(True);
  Result := CurLen < LastLen;
end;

procedure TLcaMarkdownView.SetHtmlPanelRedrawActive(AActive: Boolean);
var
  Panel: TIpHtmlPanel;
  W: TWinControl;
begin
  {$IFDEF LCLwin32}
  if not Assigned(FHtmlPanel) then Exit;
  if not (FHtmlPanel is TWinControl) then Exit;
  W := TWinControl(FHtmlPanel);
  if not W.HandleAllocated then Exit;
  if AActive then begin
    SendMessage(W.Handle, WM_SETREDRAW, 1, 0);
    InvalidateRect(W.Handle, nil, False);
  end else
    SendMessage(W.Handle, WM_SETREDRAW, 0, 0);
  if FHtmlPanel is TIpHtmlPanel then begin
    Panel := TIpHtmlPanel(FHtmlPanel);
    DisableIpHtmlNativeScroll(Panel);
  end;
  {$ELSE}
  if not AActive then ;
  {$ENDIF}
end;

procedure TLcaMarkdownView.Render;
var
  Html: string;
  Panel: TIpHtmlPanel;
  ViewSz: TSize;
  ViewW, LayH, LayPanelH: Integer;
begin
  if csDesigning in ComponentState then Exit;
  if csDestroying in ComponentState then Exit;
  if FRendering then Exit;
  if not HostReadyForRender then begin
    ScheduleDeferredRender;
    Exit;
  end;
  EnsureViewer;
  if not Assigned(FHtmlPanel) then begin
    ScheduleDeferredRender;
    Exit;
  end;
  if csDestroying in FHtmlPanel.ComponentState then Exit;
  LcaUiProfileRecordMarkdownRender;
  if FUseRawHtml then
    Html := FRawHtml
  else
    Html := WrapThemedHtmlDocument(MarkdownSubsetToHtml(FMarkdown), FThemeKind);
  Panel := TIpHtmlPanel(FHtmlPanel);
  FRendering := True;
  DisableAutoSizing;
  SetHtmlPanelRedrawActive(False);
  try
    if ShouldResetLayoutBeforeRender then
      ResetContentLayoutState;
    EnsureScrollHostFillsClient;
    Panel.BgColor := ThemePalette(FThemeKind).Background;
    Panel.TextColor := ThemePalette(FThemeKind).Text;
    ViewSz := FScrollHost.LayoutViewportSize;
    ViewW := Max(1, ViewSz.cx);
    LayH := Max(1, ViewSz.cy);
    LayPanelH := Max(LayH, Max(FLastSyncedContentH, LCA_MARKDOWN_HTML_LAYOUT_MIN_HEIGHT));
    if (Panel.Width <> ViewW) or (Panel.Height <> LayPanelH) then
      Panel.SetBounds(0, 0, ViewW, LayPanelH);
    Panel.SetHtmlFromStr(Html);
    DisableIpHtmlNativeScroll(Panel);
    if FUseRawHtml then
      FLastRenderedRawHtmlLen := Length(FRawHtml)
    else
      FLastRenderedMarkdownLen := Length(FMarkdown);
    ScheduleDeferredContentSync;
  finally
    SetHtmlPanelRedrawActive(True);
    EnableAutoSizing;
    FRendering := False;
  end;
  FRenderDeferRetries := 0;
end;

procedure TLcaMarkdownView.SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean = False);
begin
  FUseRawHtml := False;
  FRawHtml := '';
  if AScrollToEndAfterRender then
    FScrollToEndPending := True
  else
    FScrollToEndPending := False;
  if FMarkdown = AMarkdown then begin
    if AScrollToEndAfterRender then
      ScheduleScrollToEndAfterRender;
    Exit;
  end;
  FMarkdown := AMarkdown;
  ScheduleDeferredRender;
end;

procedure TLcaMarkdownView.SetHtmlBody(const AFullHtml: string);
begin
  FUseRawHtml := True;
  FMarkdown := '';
  FRawHtml := AFullHtml;
  ScheduleDeferredRender;
end;

procedure TLcaMarkdownView.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  EffTheme: TThemeKind;
begin
  FThemeKind := ATheme;
  EffTheme := EffectiveControlTheme(Self, ATheme);
  P := ThemePalette(EffTheme);
  Color := P.Background;
  if csDesigning in ComponentState then Exit;
  if Assigned(FScrollHost) then begin
    FScrollHost.SetViewportFillColor(P.Background);
    FScrollHost.ThemeKind := ATheme;
    FScrollHost.ApplyTheme(ATheme);
  end;
  if (FUseRawHtml and (FRawHtml <> '')) or (FMarkdown <> '') then
    ScheduleDeferredRender;
end;

procedure TLcaMarkdownView.Loaded;
begin
  inherited Loaded;
  ApplyTheme(FThemeKind);
  if csDesigning in ComponentState then Exit;
  EnsureScrollHostFillsClient;
  if (FMarkdown <> '') or (FUseRawHtml and (FRawHtml <> '')) then
    ScheduleDeferredRender;
end;

procedure TLcaMarkdownView.ApplyViewportWidthReflow;
var
  Panel: TIpHtmlPanel;
  ViewSz: TSize;
  ViewW, LayPanelH: Integer;
begin
  if csDesigning in ComponentState then Exit;
  if not Assigned(FScrollHost) or not Assigned(FHtmlPanel) then Exit;
  EnsureScrollHostFillsClient;
  Panel := TIpHtmlPanel(FHtmlPanel);
  ViewSz := FScrollHost.LayoutViewportSize;
  ViewW := Max(1, ViewSz.cx);
  if (FLastLayoutViewportW > 0) and (ViewW <> FLastLayoutViewportW) then
    FContentStabilityMeasureH := -1;
  FLastLayoutViewportW := ViewW;
  LayPanelH := Max(LCA_MARKDOWN_HTML_LAYOUT_MIN_HEIGHT, Max(FLastSyncedContentH,
    Max(1, ViewSz.cy)));
  if (Panel.Width <> ViewW) or (Panel.Height < LayPanelH) then
    Panel.SetBounds(0, 0, ViewW, Max(Panel.Height, LayPanelH));
  ScheduleDeferredContentSync;
end;

procedure TLcaMarkdownView.ScheduleDebouncedViewportReflow;
begin
  FViewportReflowDeadline := GetTickCount64 + LCA_MARKDOWN_RESIZE_QUIESCENCE_MS;
  if FViewportReflowQueued then Exit;
  FViewportReflowQueued := True;
  Application.QueueAsyncCall(@DeferredViewportReflow, PtrInt(Self));
end;

procedure TLcaMarkdownView.DeferredViewportReflow(Data: PtrInt);
begin
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if GetTickCount64 < FViewportReflowDeadline then begin
    Application.QueueAsyncCall(@DeferredViewportReflow, PtrInt(Self));
    Exit;
  end;
  FViewportReflowQueued := False;
  ApplyViewportWidthReflow;
end;

procedure TLcaMarkdownView.Resize;
var
  ViewW: Integer;
  WidthChanged: Boolean;
begin
  inherited Resize;
  if csDesigning in ComponentState then Exit;
  if not Assigned(FScrollHost) then Exit;
  if (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;
  EnsureScrollHostFillsClient;
  ViewW := FScrollHost.LayoutViewportSize.cx;
  if ViewW <= 0 then Exit;
  WidthChanged := (FLastLayoutViewportW > 0) and (ViewW <> FLastLayoutViewportW);
  if not ((FMarkdown <> '') or (FUseRawHtml and (FRawHtml <> ''))) then begin
    FLastLayoutViewportW := ViewW;
    Exit;
  end;
  if WidthChanged then
    ApplyViewportWidthReflow
  else
    EnsureScrollHostFillsClient;
  if WidthChanged then
    ScheduleDebouncedViewportReflow;
end;

function TLcaMarkdownView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if Assigned(FScrollHost) then begin
    FScrollHost.HandleHostWheel(Shift, WheelDelta);
    Exit(True);
  end;
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TLcaMarkdownView.CMShowingChanged(var Message: TLMessage);
begin
  inherited CMShowingChanged(Message);
  if csDesigning in ComponentState then Exit;
  if not Showing then Exit;
  if (FMarkdown = '') and not (FUseRawHtml and (FRawHtml <> '')) then Exit;
  FRenderDeferRetries := 0;
  FRenderDeferQueued := False;
  ScheduleDeferredRender;
end;

end.
