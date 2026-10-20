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

type
  TLcaMarkdownView = class;

  { Forwards wheel to TLcaScrollHost; IPro must not keep native scroll. }
  TLcaMarkdownHtmlPanel = class(TIpHtmlPanel)
  private
    FScrollHost: TLcaScrollHost;
    FOwnerView: TLcaMarkdownView;
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
    procedure SetThemeKind(AValue: TThemeKind);
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
  Math, LCLIntf, IpHtmlTypes, StrUtils;

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

function TLcaMarkdownView.HostReadyForRender: Boolean;
begin
  Result := HandleAllocated and Showing and (ClientWidth > 0) and (ClientHeight > 0);
end;

procedure TLcaMarkdownView.ScheduleDeferredRender;
begin
  if FRenderDeferQueued then Exit;
  if FRenderDeferRetries >= LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES then Exit;
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

procedure DisableIpHtmlPanelChromeScroll(APanel: TWinControl);
var
  I: Integer;
  C: TWinControl;
begin
  { Only the viewer + IPro HyperPanel host — not embedded HTML form controls (Qt5 breaks). }
  if not Assigned(APanel) then Exit;
  if APanel.HandleAllocated then begin
    ShowScrollBar(APanel.Handle, SB_VERT, False);
    ShowScrollBar(APanel.Handle, SB_HORZ, False);
  end;
  for I := 0 to APanel.ControlCount - 1 do
    if APanel.Controls[I] is TWinControl then begin
      C := TWinControl(APanel.Controls[I]);
      if C.HandleAllocated then begin
        ShowScrollBar(C.Handle, SB_VERT, False);
        ShowScrollBar(C.Handle, SB_HORZ, False);
      end;
    end;
end;

procedure TLcaMarkdownView.DisableIpHtmlNativeScroll(APanel: TIpHtmlPanel);
begin
  if not Assigned(APanel) then Exit;
  APanel.VScrollPos := 0;
  DisableIpHtmlPanelChromeScroll(APanel);
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
  if FScrollToEndPending and Settled then
    ScheduleScrollToEndAfterRender;
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
  EnsureScrollHostFillsClient;
  Panel := TIpHtmlPanel(FHtmlPanel);
  ViewSz := FScrollHost.LayoutViewportSize;
  ViewW := Max(1, ViewSz.cx);
  FLastLayoutViewportW := ViewW;
  LayPanelH := Max(LCA_MARKDOWN_HTML_LAYOUT_MIN_HEIGHT, Max(FLastSyncedContentH,
    Max(1, ViewSz.cy)));
  if (Panel.Width <> ViewW) or (Panel.Height < LayPanelH) then
    Panel.SetBounds(0, 0, ViewW, Max(Panel.Height, LayPanelH));
  Sz := Panel.GetContentSize;
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
  NeedUpdate := False;
  if (CH > FLastSyncedContentH) or (CW <> FLastSyncedContentW) then
    NeedUpdate := True
  else if (FLastSyncedContentW <> CW) or (FLastSyncedContentH <> CH) then begin
    if (FLastSyncedContentH <= 0) or (Abs(CH - FLastSyncedContentH) >= LCA_MARKDOWN_CONTENT_HEIGHT_SLACK) then
      NeedUpdate := True;
  end;
  if not NeedUpdate then begin
    if FContentStabilityMeasureH = CH then
      Result := True
    else begin
      FContentStabilityMeasureH := CH;
      ScheduleDeferredContentSync;
    end;
    Exit;
  end;
  FLastSyncedContentW := CW;
  FLastSyncedContentH := CH;
  FScrollHost.UpdateContentExtent(CW, CH);
  DisableIpHtmlNativeScroll(Panel);
  if FContentStabilityMeasureH = CH then
    Result := True
  else begin
    FContentStabilityMeasureH := CH;
    ScheduleDeferredContentSync;
  end;
end;

procedure TLcaMarkdownView.ScheduleDeferredScrollToEnd;
begin
  if FScrollDeferQueued then Exit;
  if FScrollDeferRetries >= LCA_MARKDOWN_HTML_MAX_RENDER_DEFER_RETRIES then begin
    FScrollToEndPending := False;
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
  if FUseRawHtml then
    Html := FRawHtml
  else
    Html := WrapThemedHtmlDocument(MarkdownSubsetToHtml(FMarkdown), FThemeKind);
  Panel := TIpHtmlPanel(FHtmlPanel);
  FRendering := True;
  DisableAutoSizing;
  try
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
    ScheduleDeferredContentSync;
  finally
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
  Render;
end;

procedure TLcaMarkdownView.SetHtmlBody(const AFullHtml: string);
begin
  FUseRawHtml := True;
  FMarkdown := '';
  FRawHtml := AFullHtml;
  Render;
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
  if Assigned(FHtmlPanel) then begin
    if FUseRawHtml and (FRawHtml <> '') then
      Render
    else if FMarkdown <> '' then
      Render;
  end;
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
  if WidthChanged then begin
    FContentStabilityMeasureH := -1;
    FLastSyncedContentW := 0;
    FLastSyncedContentH := 0;
    if (FMarkdown <> '') or (FUseRawHtml and (FRawHtml <> '')) then
      ScheduleDeferredRender;
  end;
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
  ScheduleDeferredRender;
end;

end.
