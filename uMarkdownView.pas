unit uMarkdownView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, Graphics, LCLIntf, IpHtml, uAppTypes, uTheme;

type
  TMarkdownView = class(TIpHtmlPanel)
  private
    FTheme: TThemeKind;
    FBodyTextCss: string;
    FBodyBgCss: string;
    FCodeBgCss: string;
    FLinkCss: string;
    FMarkdownContent: string;
    FMarkdownDirty: Boolean;
    procedure FlushMarkdown;
    procedure HandleHotClick(Sender: TObject);
    class function EscapeHTML(const S: string): string; static;
    class function SafeURL(const S: string): Boolean; static;
    class function RenderInline(const S, ALinkCss: string): string; static;
    function RenderHTML(const AMarkdown: string): string;
  protected
    procedure CreateWnd; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetMarkdown(const AMarkdown: string);
    procedure ScrollToBottom;
  end;

implementation

type
  TIpHtmlFrameAccess = class(TIpHtmlFrame)
  public
    function GetScrollPanel: TIpHtmlInternalPanel;
  end;

function ColorToCssHex(AColor: TColor): string;
var
  C: LongInt;
  R, G, B: Byte;
begin
  C := ColorToRGB(AColor);
  R := (C shr 16) and $FF;
  G := (C shr 8) and $FF;
  B := C and $FF;
  Result := Format('#%.2x%.2x%.2x', [R, G, B]);
end;

procedure TMarkdownView.FlushMarkdown;
begin
  if not FMarkdownDirty then Exit;
  if not ParentFormHandlesReady(Self) then Exit;
  FMarkdownDirty := False;
  SetHtmlFromStr(RenderHTML(FMarkdownContent));
end;

constructor TMarkdownView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FMarkdownContent := '';
  FMarkdownDirty := False;
  DefaultTypeFace := 'Segoe UI';
  FixedTypeface := 'Consolas';
  MarginWidth := 10;
  MarginHeight := 8;
  OnHotClick := @HandleHotClick;
  ApplyTheme(FTheme);
end;

procedure TMarkdownView.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  FlowBg: TColor;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  if ATheme = tkDark then
    FlowBg := P.Background
  else
    FlowBg := P.Surface;
  BgColor := FlowBg;
  TextColor := P.Text;
  FBodyBgCss := ColorToCssHex(FlowBg);
  FBodyTextCss := ColorToCssHex(P.Text);
  FCodeBgCss := ColorToCssHex(P.SurfaceAlt);
  FLinkCss := ColorToCssHex(P.Accent);
  Color := FlowBg;
end;

function TIpHtmlFrameAccess.GetScrollPanel: TIpHtmlInternalPanel;
begin
  Result := HyperPanel;
end;

class function TMarkdownView.EscapeHTML(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

class function TMarkdownView.SafeURL(const S: string): Boolean;
var
  U: string;
begin
  U := LowerCase(Trim(S));
  Result := (Copy(U, 1, 7) = 'http://') or
    (Copy(U, 1, 8) = 'https://') or (Copy(U, 1, 7) = 'mailto:');
end;

procedure TMarkdownView.HandleHotClick(Sender: TObject);
var
  U: string;
begin
  U := Trim(HotURL);
  if SafeURL(U) then
    LCLIntf.OpenURL(U);
end;

class function TMarkdownView.RenderInline(const S, ALinkCss: string): string;
var
  I, J, K: SizeInt;
  Token, URL: string;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (Copy(S, I, 2) = '**') then
    begin
      J := Pos('**', Copy(S, I + 2, MaxInt));
      if J > 0 then
      begin
        Token := Copy(S, I + 2, J - 1);
        Result := Result + '<b>' + RenderInline(Token, ALinkCss) + '</b>';
        Inc(I, J + 3);
        Continue;
      end;
    end;
    if S[I] = '`' then
    begin
      J := Pos('`', Copy(S, I + 1, MaxInt));
      if J > 0 then
      begin
        Token := Copy(S, I + 1, J - 1);
        Result := Result + '<code>' + EscapeHTML(Token) + '</code>';
        Inc(I, J + 1);
        Continue;
      end;
    end;
    if S[I] = '*' then
    begin
      J := Pos('*', Copy(S, I + 1, MaxInt));
      if J > 0 then
      begin
        Token := Copy(S, I + 1, J - 1);
        Result := Result + '<i>' + RenderInline(Token, ALinkCss) + '</i>';
        Inc(I, J + 1);
        Continue;
      end;
    end;
    if S[I] = '[' then
    begin
      J := Pos('](', Copy(S, I + 1, MaxInt));
      if J > 0 then
      begin
        K := I + J;
        J := Pos(')', Copy(S, K + 2, MaxInt));
        if J > 0 then
        begin
          Token := Copy(S, I + 1, K - I - 1);
          URL := Copy(S, K + 2, J - 1);
          if SafeURL(URL) then
            Result := Result + '<a style="color:' + ALinkCss + ';" href="' +
              EscapeHTML(URL) + '">' + RenderInline(Token, ALinkCss) + '</a>'
          else
            Result := Result + RenderInline(Token, ALinkCss);
          Inc(I, K - I + J + 2);
          Continue;
        end;
      end;
    end;
    Result := Result + EscapeHTML(S[I]);
    Inc(I);
  end;
end;

function TMarkdownView.RenderHTML(const AMarkdown: string): string;
var
  Lines: TStringList;
  I, N, MarkerLength, FenceLength, Backticks, CodeLines: Integer;
  Line, Trimmed, HTML, CodeText, BodyStyle, HtmlStyle, PreStyle: string;
  InCode, InList, Ordered, ListOrdered: Boolean;
begin
  HtmlStyle := 'background-color: ' + FBodyBgCss + ';';
  BodyStyle := 'font-family: Segoe UI, sans-serif; color: ' + FBodyTextCss +
    '; background-color: ' + FBodyBgCss + '; margin: 0;';
  PreStyle := 'background-color: ' + FCodeBgCss + '; padding: 8px; ' +
    'border-radius: 6px; overflow-x: auto;';

  Lines := TStringList.Create;
  try
    Lines.Text := AMarkdown;
    HTML := '<html style="' + HtmlStyle + '"><body style="' + BodyStyle + '">';
    InCode := False;
    InList := False;
    Ordered := False;
    ListOrdered := False;
    CodeText := '';
    FenceLength := 0;
    CodeLines := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      Trimmed := Trim(Line);
      Backticks := 0;
      while (Backticks < Length(Trimmed)) and (Trimmed[Backticks + 1] = '`') do
        Inc(Backticks);
      if ((not InCode) and (Backticks >= 3)) or
        (InCode and (Backticks = FenceLength) and (Length(Trimmed) = Backticks)) then
      begin
        if InCode then
        begin
          HTML := HTML + '<pre style="' + PreStyle + '"><code>' +
            EscapeHTML(CodeText) + '</code></pre>';
          CodeText := '';
          InCode := False;
        end
        else
        begin
          InCode := True;
          FenceLength := Backticks;
          CodeLines := 0;
          if InList then
          begin
            if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
            InList := False;
          end;
        end;
        Continue;
      end;
      if InCode then
      begin
        if CodeLines > 0 then CodeText := CodeText + LineEnding;
        CodeText := CodeText + Line;
        Inc(CodeLines);
        Continue;
      end;

      if (Trimmed = '') then
      begin
        if InList then
        begin
          if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
          InList := False;
        end;
        Continue;
      end;

      N := 0;
      while (N < Length(Trimmed)) and (Trimmed[N + 1] = '#') do Inc(N);
      if (N > 0) and (N <= 6) and (Length(Trimmed) > N) and
        (Trimmed[N + 1] = ' ') then
      begin
        if InList then
        begin
          if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
          InList := False;
        end;
        HTML := HTML + '<h' + IntToStr(N) + '>' +
          RenderInline(Trim(Copy(Trimmed, N + 2, MaxInt)), FLinkCss) + '</h' +
          IntToStr(N) + '>';
        Continue;
      end;

      Ordered := False;
      MarkerLength := 0;
      N := 0;
      while (N < Length(Trimmed)) and (Trimmed[N + 1] in ['0'..'9']) do Inc(N);
      if (N > 0) and (N + 1 < Length(Trimmed)) and
        (Trimmed[N + 1] = '.') and (Trimmed[N + 2] = ' ') then
      begin
        Ordered := True;
        MarkerLength := N + 2;
      end
      else if (Copy(Trimmed, 1, 2) = '- ') or
        (Copy(Trimmed, 1, 2) = '* ') or (Copy(Trimmed, 1, 2) = '+ ') then
        MarkerLength := 2;

      if MarkerLength > 0 then
      begin
        if not InList or (Ordered <> ListOrdered) then
        begin
          if InList then
          begin
            if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
          end;
          if Ordered then HTML := HTML + '<ol>' else HTML := HTML + '<ul>';
          InList := True;
          ListOrdered := Ordered;
        end;
        HTML := HTML + '<li>' + RenderInline(Trim(Copy(Trimmed,
          MarkerLength + 1, MaxInt)), FLinkCss) + '</li>';
        Continue;
      end;

      if InList then
      begin
        if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
        InList := False;
      end;

      if Copy(Trimmed, 1, 2) = '> ' then
        HTML := HTML + '<blockquote>' +
          RenderInline(Trim(Copy(Trimmed, 3, MaxInt)), FLinkCss) + '</blockquote>'
      else if (Trimmed = '---') or (Trimmed = '***') then
        HTML := HTML + '<hr>'
      else
        HTML := HTML + '<p>' + RenderInline(Trimmed, FLinkCss) + '</p>';
    end;

    if InCode then
      HTML := HTML + '<pre style="' + PreStyle + '"><code>' +
        EscapeHTML(CodeText) + '</code></pre>';
    if InList then
    begin
      if ListOrdered then HTML := HTML + '</ol>' else HTML := HTML + '</ul>';
    end;
    HTML := HTML + '</body></html>';
    Result := HTML;
  finally
    Lines.Free;
  end;
end;

procedure TMarkdownView.CreateWnd;
begin
  inherited CreateWnd;
  FlushMarkdown;
end;

procedure TMarkdownView.Loaded;
begin
  inherited Loaded;
  FlushMarkdown;
end;

procedure TMarkdownView.SetMarkdown(const AMarkdown: string);
begin
  FMarkdownContent := AMarkdown;
  FMarkdownDirty := True;
  FlushMarkdown;
end;

procedure TMarkdownView.ScrollToBottom;
var
  ScrollPanel: TIpHtmlInternalPanel;
begin
  if not ParentFormHandlesReady(Self) then Exit;
  if MasterFrame = nil then Exit;
  ScrollPanel := TIpHtmlFrameAccess(MasterFrame).GetScrollPanel;
  if ScrollPanel = nil then Exit;

  ScrollPanel.VScroll.Position := High(Integer);
end;

end.
