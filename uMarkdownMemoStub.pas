unit uMarkdownMemoStub;

{$mode objfpc}{$H+}

{ Qt5 markdown perf experiment: plain TMemo stand-in for TLcaMarkdownView. }

interface

uses
  Classes, SysUtils, StdCtrls, LcaTheme;

procedure ConfigureMarkdownMemo(AMemo: TMemo; ATheme: TThemeKind);
procedure MarkdownMemoClear(AMemo: TMemo);
procedure MarkdownMemoSetText(AMemo: TMemo; const AText: string; AScrollToEnd: Boolean);
procedure MarkdownMemoAppendTail(AMemo: TMemo; const ADelta: string; AScrollToEnd: Boolean);
procedure MarkdownMemoScrollToEnd(AMemo: TMemo);

implementation

procedure ConfigureMarkdownMemo(AMemo: TMemo; ATheme: TThemeKind);
begin
  if not Assigned(AMemo) then Exit;
  ConfigureThemedMemo(AMemo, ATheme);
  AMemo.ReadOnly := True;
  AMemo.WordWrap := True;
  AMemo.ScrollBars := ssVertical;
end;

procedure MarkdownMemoClear(AMemo: TMemo);
begin
  if not Assigned(AMemo) then Exit;
  AMemo.Clear;
end;

procedure MarkdownMemoSetText(AMemo: TMemo; const AText: string; AScrollToEnd: Boolean);
begin
  if not Assigned(AMemo) then Exit;
  AMemo.Lines.Text := AText;
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
