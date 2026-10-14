unit uMarkdownHtmlView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, uAppTypes, uTheme;

type
  { Subset Markdown renderer on a streamed TPanel host (TurboPower IpHtml at runtime). }
  TMarkdownHtmlView = class
  private
    FOwner: TComponent;
    FHost: TPanel;
    FHtmlPanel: TControl;
    FTheme: TThemeKind;
    FMarkdown: string;
    FRawHtml: string;
    FUseRawHtml: Boolean;
    procedure EnsureViewer;
    procedure Render;
  public
    constructor Create(AOwner: TComponent; AHost: TPanel);
    destructor Destroy; override;
    procedure SetMarkdown(const AMarkdown: string);
    procedure SetHtmlBody(const AFullHtml: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    property Host: TPanel read FHost;
  end;

function MarkdownSubsetToHtml(const AMarkdown: string): string;
function WrapThemedHtmlDocument(const ABodyHtml: string; ATheme: TThemeKind): string;

implementation

uses
  IpHtml;

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
  Ch: Char;
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
    'h1,h2,h3 { color: ' + ColorToHex(P.Text) + '; margin: 0.6em 0 0.3em; } ' +
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
    '</style></head><body>' + ABodyHtml + '</body></html>';
end;

constructor TMarkdownHtmlView.Create(AOwner: TComponent; AHost: TPanel);
begin
  inherited Create;
  FOwner := AOwner;
  FHost := AHost;
  FHtmlPanel := nil;
  FTheme := tkDark;
  FMarkdown := '';
  FRawHtml := '';
  FUseRawHtml := False;
  EnsureViewer;
end;

destructor TMarkdownHtmlView.Destroy;
begin
  { IpHtmlPanel is owned by FHost (LCL); freeing here double-frees on form close. }
  FHtmlPanel := nil;
  inherited Destroy;
end;

procedure TMarkdownHtmlView.EnsureViewer;
begin
  if not Assigned(FHost) then Exit;
  if (csDestroying in FHost.ComponentState) or not FHost.HandleAllocated then Exit;
  if Assigned(FHtmlPanel) then Exit;
  FHtmlPanel := TIpHtmlPanel.Create(FHost);
  FHtmlPanel.Parent := FHost;
  FHtmlPanel.Align := alClient;
  TIpHtmlPanel(FHtmlPanel).BorderStyle := bsNone;
  TIpHtmlPanel(FHtmlPanel).AllowTextSelect := True;
  TIpHtmlPanel(FHtmlPanel).DefaultTypeFace := 'Segoe UI';
  TIpHtmlPanel(FHtmlPanel).FixedTypeface := 'Consolas';
end;

procedure TMarkdownHtmlView.Render;
var
  Html: string;
begin
  if Assigned(FHost) and (csDestroying in FHost.ComponentState) then Exit;
  EnsureViewer;
  if not Assigned(FHtmlPanel) then Exit;
  if csDestroying in FHtmlPanel.ComponentState then Exit;
  if FUseRawHtml then
    Html := FRawHtml
  else
    Html := WrapThemedHtmlDocument(MarkdownSubsetToHtml(FMarkdown), FTheme);
  TIpHtmlPanel(FHtmlPanel).BgColor := ThemePalette(FTheme).Background;
  TIpHtmlPanel(FHtmlPanel).TextColor := ThemePalette(FTheme).Text;
  TIpHtmlPanel(FHtmlPanel).SetHtmlFromStr(Html);
end;

procedure TMarkdownHtmlView.SetMarkdown(const AMarkdown: string);
begin
  FUseRawHtml := False;
  FRawHtml := '';
  FMarkdown := AMarkdown;
  Render;
end;

procedure TMarkdownHtmlView.SetHtmlBody(const AFullHtml: string);
begin
  FUseRawHtml := True;
  FMarkdown := '';
  FRawHtml := AFullHtml;
  Render;
end;

procedure TMarkdownHtmlView.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  if FUseRawHtml and (FRawHtml <> '') then
    Render
  else if FMarkdown <> '' then
    Render;
  EnsureViewer;
  if Assigned(FHtmlPanel) and (FHtmlPanel is TWinControl) and
     TWinControl(FHtmlPanel).HandleAllocated then
    ApplyPlatformScrollableTheme(TWinControl(FHtmlPanel), ATheme);
end;

end.
