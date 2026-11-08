unit uMarkdownMemoStub;

{$mode objfpc}{$H+}

{ Read-only TMemo helpers for chat/plan/help markdown (plain text, Qt-friendly). }

interface

uses
  Classes, SysUtils, StdCtrls, LcaTheme;

const
  MARKDOWN_MEMO_TRACE_THINK_PREFIX = '@think ';
  MARKDOWN_MEMO_TRACE_TOOL_PREFIX = '@tool ';

function MarkdownMemoDisplayText(const AText: string): string;
procedure ConfigureMarkdownMemo(AMemo: TMemo; ATheme: TThemeKind);
procedure MarkdownMemoClear(AMemo: TMemo);
procedure MarkdownMemoSetText(AMemo: TMemo; const AText: string; AScrollToEnd: Boolean);
procedure MarkdownMemoAppendTail(AMemo: TMemo; const ADelta: string; AScrollToEnd: Boolean);
procedure MarkdownMemoScrollToEnd(AMemo: TMemo);

implementation

uses
  StrUtils;

procedure SplitTextLines(const AText: string; AOut: TStrings);
var
  Start, P, LBLen: Integer;
  Line: string;
begin
  AOut.Clear;
  if AText = '' then Exit;
  LBLen := Length(LineEnding);
  Start := 1;
  P := PosEx(LineEnding, AText, Start);
  while P > 0 do begin
    Line := Copy(AText, Start, P - Start);
    AOut.Add(Line);
    Start := P + LBLen;
    P := PosEx(LineEnding, AText, Start);
  end;
  AOut.Add(Copy(AText, Start, MaxInt));
end;

function MarkdownMemoDisplayText(const AText: string): string;
var
  SL: TStringList;
  I: Integer;
  T, Line: string;
begin
  if AText = '' then Exit('');
  Result := '';
  SL := TStringList.Create;
  try
    SplitTextLines(AText, SL);
    for I := 0 to SL.Count - 1 do begin
      T := Trim(SL[I]);
      if (Length(T) >= Length(MARKDOWN_MEMO_TRACE_THINK_PREFIX)) and
         SameText(Copy(T, 1, Length(MARKDOWN_MEMO_TRACE_THINK_PREFIX)),
           MARKDOWN_MEMO_TRACE_THINK_PREFIX) then
        Line := Trim(Copy(T, Length(MARKDOWN_MEMO_TRACE_THINK_PREFIX) + 1, MaxInt))
      else if (Length(T) >= Length(MARKDOWN_MEMO_TRACE_TOOL_PREFIX)) and
         SameText(Copy(T, 1, Length(MARKDOWN_MEMO_TRACE_TOOL_PREFIX)),
           MARKDOWN_MEMO_TRACE_TOOL_PREFIX) then
        Line := '- ' + Trim(Copy(T, Length(MARKDOWN_MEMO_TRACE_TOOL_PREFIX) + 1, MaxInt))
      else
        Line := SL[I];
      if I > 0 then
        Result := Result + LineEnding;
      Result := Result + Line;
    end;
  finally
    SL.Free;
  end;
end;

procedure ConfigureMarkdownMemo(AMemo: TMemo; ATheme: TThemeKind);
begin
  if not Assigned(AMemo) then Exit;
  ConfigureThemedMemo(AMemo, ATheme);
  AMemo.ReadOnly := True;
  AMemo.WordWrap := True;
  AMemo.ScrollBars := ssVertical;
  AMemo.TabStop := False;
end;

procedure MarkdownMemoClear(AMemo: TMemo);
begin
  if not Assigned(AMemo) then Exit;
  AMemo.Clear;
end;

procedure MarkdownMemoSetText(AMemo: TMemo; const AText: string; AScrollToEnd: Boolean);
begin
  if not Assigned(AMemo) then Exit;
  AMemo.Lines.Text := MarkdownMemoDisplayText(AText);
  if AScrollToEnd then
    MarkdownMemoScrollToEnd(AMemo);
end;

procedure MarkdownMemoAppendTail(AMemo: TMemo; const ADelta: string; AScrollToEnd: Boolean);
begin
  if not Assigned(AMemo) then Exit;
  if ADelta = '' then begin
    if AScrollToEnd then
      MarkdownMemoScrollToEnd(AMemo);
    Exit;
  end;
  AMemo.SelStart := Length(AMemo.Text);
  AMemo.SelLength := 0;
  AMemo.SelText := ADelta;
  if AScrollToEnd then
    MarkdownMemoScrollToEnd(AMemo);
end;

procedure MarkdownMemoScrollToEnd(AMemo: TMemo);
begin
  if not Assigned(AMemo) then Exit;
  AMemo.SelStart := Length(AMemo.Text);
  AMemo.SelLength := 0;
end;

end.
