unit uExecutionDetailHtml;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, uAppTypes, LcaTheme;

function ExecDetailEscapeHtml(const S: string): string;
function JsonTextToHtmlBlock(const AJson: string): string;
function ProseTextToHtmlBlock(const AText: string): string;
procedure AppendHtmlSectionHeader(SB: TStringBuilder; const ATitle: string);
procedure AppendHtmlToolCallHeader(SB: TStringBuilder; const AToolName: string);
procedure AppendHtmlFailBadge(SB: TStringBuilder);
function WrapExecDetailHtmlDocument(const ABodyHtml: string; ATheme: TThemeKind): string;

implementation

uses
  uAgentExecutionLog;

function ColorToHex(AColor: TColor): string;
begin
  Result := '#' + LowerCase(IntToHex(Red(AColor), 2) + IntToHex(Green(AColor), 2) +
    IntToHex(Blue(AColor), 2));
end;

function ExecDetailEscapeHtml(const S: string): string;
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

function HighlightJsonKeysHtml(const S: string): string;
var
  I, J: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(S) do begin
      if S[I] = '"' then begin
        J := I + 1;
        while (J <= Length(S)) and (S[J] <> '"') do
          Inc(J);
        if (J <= Length(S)) and (J < Length(S)) and (S[J + 1] = ':') then begin
          SB.Append('<span class="json-key">');
          SB.Append(ExecDetailEscapeHtml(Copy(S, I, J - I + 1)));
          SB.Append('</span>:');
          I := J + 2;
          Continue;
        end;
      end;
      SB.Append(ExecDetailEscapeHtml(S[I]));
      Inc(I);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function JsonTextToHtmlBlock(const AJson: string): string;
var
  Pretty: string;
begin
  Pretty := Trim(PrettyJsonString(AJson));
  if Pretty = '' then
    Exit('<pre class="json-block"><code>(empty)</code></pre>');
  Result := '<pre class="json-block"><code>' + HighlightJsonKeysHtml(Pretty) + '</code></pre>';
end;

function ProseTextToHtmlBlock(const AText: string): string;
var
  T: string;
begin
  T := Trim(AText);
  if T = '' then
    Exit('<p class="prose-empty">(empty)</p>');
  Result := '<pre class="prose-block">' + ExecDetailEscapeHtml(T) + '</pre>';
end;

procedure AppendHtmlSectionHeader(SB: TStringBuilder; const ATitle: string);
begin
  SB.Append('<h3 class="exec-section">');
  SB.Append(ExecDetailEscapeHtml(ATitle));
  SB.Append('</h3>');
end;

procedure AppendHtmlToolCallHeader(SB: TStringBuilder; const AToolName: string);
begin
  SB.Append('<div class="tool-call">');
  SB.Append('<span class="tool-name">');
  SB.Append(ExecDetailEscapeHtml(AToolName));
  SB.Append('</span></div>');
end;

procedure AppendHtmlFailBadge(SB: TStringBuilder);
begin
  SB.Append(' <span class="badge-fail">failed</span>');
end;

function WrapExecDetailHtmlDocument(const ABodyHtml: string; ATheme: TThemeKind): string;
var
  P: TThemePalette;
  FailColor: string;
begin
  P := ThemePalette(ATheme);
  if ATheme = tkDark then
    FailColor := ColorToHex(RGBToColor(248, 113, 113))
  else
    FailColor := ColorToHex(RGBToColor(220, 38, 38));
  Result :=
    '<html><head><meta charset="utf-8"><style>' +
    'body { font-family: Segoe UI, sans-serif; font-size: 10pt; margin: 8px; ' +
    'background: ' + ColorToHex(P.Background) + '; color: ' + ColorToHex(P.Text) + '; } ' +
    'h3.exec-section { color: ' + ColorToHex(P.Accent) + '; font-size: 11pt; ' +
    'margin: 1em 0 0.4em; padding-bottom: 4px; border-bottom: 1px solid ' +
    ColorToHex(P.Border) + '; } ' +
    'h3.exec-section:first-child { margin-top: 0; } ' +
    '.tool-call { border-left: 3px solid ' + ColorToHex(P.Accent) + '; ' +
    'padding: 4px 0 4px 10px; margin: 8px 0; } ' +
    '.tool-name { font-weight: bold; color: ' + ColorToHex(P.AccentHover) + '; ' +
    'font-family: Consolas, monospace; font-size: 10pt; } ' +
    '.badge-fail { display: inline-block; font-size: 9pt; font-weight: bold; ' +
    'color: ' + FailColor + '; border: 1px solid ' + FailColor + '; ' +
    'border-radius: 3px; padding: 0 6px; margin-left: 6px; vertical-align: middle; } ' +
    'pre.json-block { background: ' + ColorToHex(P.SurfaceAlt) + '; ' +
    'border: 1px solid ' + ColorToHex(P.Border) + '; border-radius: 4px; ' +
    'padding: 8px 10px; margin: 6px 0 12px; overflow-x: auto; ' +
    'font-family: Consolas, monospace; font-size: 10pt; line-height: 1.35; white-space: pre-wrap; } ' +
    'pre.json-block code { background: transparent; } ' +
    '.json-key { color: ' + ColorToHex(P.TextMuted) + '; } ' +
    'pre.prose-block { background: ' + ColorToHex(P.Surface) + '; ' +
    'border: 1px solid ' + ColorToHex(P.Border) + '; border-radius: 4px; ' +
    'padding: 8px 10px; margin: 6px 0 12px; overflow-x: auto; ' +
    'font-family: Consolas, monospace; font-size: 10pt; line-height: 1.35; white-space: pre-wrap; } ' +
    'p.prose-empty { color: ' + ColorToHex(P.TextMuted) + '; font-style: italic; margin: 4px 0; } ' +
    '</style></head><body>' + ABodyHtml + '</body></html>';
end;

end.
