unit LcaThemeWin32ScrollBars;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, ComCtrls, LcaTheme;

procedure ApplyWin32ThemedScrollBars(AControl: TWinControl; ATheme: TThemeKind);

function ControlUsesThemedScrollBars(AControl: TWinControl): Boolean;

implementation

uses
  Graphics, Forms, LCLIntf, LMessages, SysUtils, Windows;

const
  SUBCLASS_ID = 2;
  MIN_THUMB_PX = 24;
  MIN_DRAW_THUMB_PX = 8;
  THUMB_INSET = 2;
  THUMB_RADIUS = 3;
  WM_NCMOUSEMOVE = $00A0;
  WM_NCLBUTTONDOWN = $00A1;
  WM_NCLBUTTONUP = $00A2;
  WM_NCUAHDRAWSCROLL = $0313;
  WM_NCUAHSCROLL = $0314;
  HTHSCROLL = 6;
  HTVSCROLL = 7;
  OBJID_VSCROLL = -5;
  OBJID_HSCROLL = -4;
  STATE_SYSTEM_PRESSED = $00000008;
  STATE_SYSTEM_HOTTRACKED = $00000080;
  STATE_SYSTEM_INVISIBLE = $00008000;

type
  TScrollBarInfo = record
    cbSize: DWORD;
    rcScrollBar: TRect;
    dxyLineButton: Integer;
    xyThumbTop: Integer;
    xyThumbBottom: Integer;
    reserved: Integer;
    rgstate: array[0..5] of DWORD;
  end;

  SUBCLASSPROC = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
    uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;

function SetWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): BOOL; stdcall; external 'comctl32.dll' name 'SetWindowSubclass';

function RemoveWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC;
  uIdSubclass: UINT_PTR): BOOL; stdcall; external 'comctl32.dll' name 'RemoveWindowSubclass';

function DefSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
  stdcall; external 'comctl32.dll' name 'DefSubclassProc';

procedure SetWindowTheme(hwnd: HWND; pszSubAppName, pszSubIdList: PWideChar); stdcall;
  external 'uxtheme.dll' name 'SetWindowTheme';

function GetScrollBarInfo(hwnd: HWND; idObject: LongInt; var psbi: TScrollBarInfo): BOOL;
  stdcall; external 'user32.dll' name 'GetScrollBarInfo';

type
  TWin32ThemedScrollBarPaint = class(TComponent)
  private
    FControl: TWinControl;
    FTheme: TThemeKind;
    FSubclassInstalled: Boolean;
    FChainedWindowProc: Boolean;
    FPrevWindowProc: TWndMethod;
    FStandaloneScrollBar: TScrollBar;
    procedure ControlWindowProc(var Message: TMessage);
    procedure InstallSubclass;
    procedure RemoveSubclass;
    procedure RepaintNcScrollBarsNow;
    procedure RepaintStandaloneScrollBarNow;
    function HostHwnd: HWND;
    function Palette: TThemePalette;
    procedure PaintNcScrollBars(HDC: HDC);
    procedure PaintStandaloneScrollBar(HDC: HDC);
    function ClipRectToInner(const R, Bounds: TRect): TRect;
    function FitThumbIntoTrack(const Thumb, Track: TRect; Vertical: Boolean): TRect;
    function MappedScrollbarThumbUsable(const Mapped, Track: TRect; Vertical: Boolean): Boolean;
    function ThumbRectFromScrollInfo(SBCode: Integer; const Track: TRect; Vertical: Boolean): TRect;
    function ResolveThumbRect(SBCode: Integer; const Track, BarRect: TRect;
      const sbi: TScrollBarInfo; Vertical: Boolean): TRect;
    procedure PaintVerticalBar(Canvas: TCanvas; const BarRect: TRect; const sbi: TScrollBarInfo);
    procedure PaintHorizontalBar(Canvas: TCanvas; const BarRect: TRect; const sbi: TScrollBarInfo);
    procedure FillSolid(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowUp(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowDown(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowLeft(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowRight(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawThumb(Canvas: TCanvas; const ThumbRect: TRect; Vertical: Boolean; AColor: TColor);
    procedure MaybeDrawFlatBorder(HDC: HDC);
    function ThumbColor(const sbi: TScrollBarInfo; ThumbIndex: Integer): TColor;
    function ArrowColor(const sbi: TScrollBarInfo; ArrowIndex: Integer): TColor;
    function NcScrollBarHasBarGeometry(const Bar: TRect; Vertical: Boolean): Boolean;
    function WindowNcScrollBarEnabled(Vertical: Boolean): Boolean;
    procedure InitDefaultScrollBarInfo(var sbi: TScrollBarInfo; Vertical: Boolean);
    procedure FallbackNcScrollBarRect(Vertical: Boolean; const Wnd, OtherBar: TRect;
      out Bar: TRect; var sbi: TScrollBarInfo);
    procedure PaintScrollCorner(Canvas: TCanvas; const VertBar, HorzBar: TRect);
    procedure ResolveNcScrollBarRects(out BarVert, BarHorz: TRect; var sbiVert, sbiHorz: TScrollBarInfo);
    procedure PaintNcScrollBarsContent(Canvas: TCanvas; const BarVert, BarHorz: TRect;
      const sbiVert, sbiHorz: TScrollBarInfo);
    procedure ExcludeClientFromWindowDC(DC: HDC);
  public
    constructor Create(AOwner: TWinControl); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind);
    class function FindOnControl(AControl: TWinControl): TWin32ThemedScrollBarPaint;
  end;

function NcScrollBarHit(WParam: WPARAM): Boolean;
begin
  Result := (WParam = HTVSCROLL) or (WParam = HTHSCROLL);
end;

function IsSynEditClass(AControl: TControl): Boolean;
begin
  Result := Assigned(AControl) and (CompareText(AControl.ClassName, 'TSynEdit') = 0);
end;

function IsIpHtmlPanelClass(AControl: TControl): Boolean;
begin
  Result := Assigned(AControl) and (CompareText(AControl.ClassName, 'TIpHtmlPanel') = 0);
end;

function ControlUsesThemedScrollBars(AControl: TWinControl): Boolean;
begin
  if not Assigned(AControl) then
    Exit(False);
  if AControl is TCustomMemo then
    Exit(True);
  if AControl is TCustomListBox then
    Exit(True);
  if AControl is TCustomTreeView then
    Exit(True);
  if AControl is TScrollBar then
    Exit(True);
  Result := IsSynEditClass(AControl) or IsIpHtmlPanelClass(AControl);
end;

function MulDivFloor(AValue, ANumerator, ADenominator: Integer): Integer;
begin
  if ADenominator <= 0 then
    Exit(0);
  Result := (Int64(AValue) * ANumerator) div ADenominator;
end;

function IMin(A, B: Integer): Integer;
begin
  if A < B then Result := A else Result := B;
end;

function IMax(A, B: Integer): Integer;
begin
  if A > B then Result := A else Result := B;
end;

procedure TWin32ThemedScrollBarPaint.FillSolid(Canvas: TCanvas; const R: TRect; AColor: TColor);
begin
  Canvas.Brush.Color := AColor;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := AColor;
  Canvas.Rectangle(R);
end;

function TWin32ThemedScrollBarPaint.Palette: TThemePalette;
begin
  Result := ThemePalette(FTheme);
end;

function TWin32ThemedScrollBarPaint.HostHwnd: HWND;
begin
  Result := 0;
  if Assigned(FControl) and FControl.HandleAllocated then
    Result := FControl.Handle;
end;

function TWin32ThemedScrollBarPaint.ThumbColor(const sbi: TScrollBarInfo; ThumbIndex: Integer): TColor;
var
  P: TThemePalette;
begin
  P := Palette;
  if (sbi.rgstate[ThumbIndex] and STATE_SYSTEM_PRESSED) <> 0 then
    Exit(P.Accent);
  if (sbi.rgstate[ThumbIndex] and STATE_SYSTEM_HOTTRACKED) <> 0 then
    Exit(P.TextMuted);
  Result := P.BorderStrong;
end;

function TWin32ThemedScrollBarPaint.ArrowColor(const sbi: TScrollBarInfo; ArrowIndex: Integer): TColor;
var
  P: TThemePalette;
begin
  P := Palette;
  if (sbi.rgstate[ArrowIndex] and STATE_SYSTEM_PRESSED) <> 0 then
    Exit(P.Accent);
  if (sbi.rgstate[ArrowIndex] and STATE_SYSTEM_HOTTRACKED) <> 0 then
    Exit(P.Text);
  Result := P.TextMuted;
end;

function TWin32ThemedScrollBarPaint.NcScrollBarHasBarGeometry(const Bar: TRect;
  Vertical: Boolean): Boolean;
begin
  if Vertical then
    Result := (Bar.Right > Bar.Left) and (Bar.Bottom - Bar.Top >= 4)
  else
    Result := (Bar.Bottom > Bar.Top) and (Bar.Right - Bar.Left >= 4);
end;

function TWin32ThemedScrollBarPaint.WindowNcScrollBarEnabled(Vertical: Boolean): Boolean;
var
  Style: LongInt;
begin
  Style := Windows.GetWindowLong(HostHwnd, GWL_STYLE);
  if Vertical then
    Result := (Style and WS_VSCROLL) <> 0
  else
    Result := (Style and WS_HSCROLL) <> 0;
end;

procedure TWin32ThemedScrollBarPaint.InitDefaultScrollBarInfo(var sbi: TScrollBarInfo;
  Vertical: Boolean);
begin
  FillChar(sbi, SizeOf(sbi), 0);
  sbi.cbSize := SizeOf(sbi);
  if Vertical then
    sbi.dxyLineButton := GetSystemMetrics(SM_CYVSCROLL)
  else
    sbi.dxyLineButton := GetSystemMetrics(SM_CXHSCROLL);
end;

procedure TWin32ThemedScrollBarPaint.FallbackNcScrollBarRect(Vertical: Boolean; const Wnd,
  OtherBar: TRect; out Bar: TRect; var sbi: TScrollBarInfo);
var
  Thickness: Integer;
begin
  InitDefaultScrollBarInfo(sbi, Vertical);
  Bar := Wnd;
  if Vertical then begin
    Thickness := GetSystemMetrics(SM_CXVSCROLL);
    if Thickness <= 0 then
      Thickness := 17;
    Bar.Left := Wnd.Right - Thickness;
    Bar.Right := Wnd.Right;
    if NcScrollBarHasBarGeometry(OtherBar, False) then
      Bar.Bottom := OtherBar.Top;
  end else begin
    Thickness := GetSystemMetrics(SM_CYHSCROLL);
    if Thickness <= 0 then
      Thickness := 17;
    Bar.Top := Wnd.Bottom - Thickness;
    Bar.Bottom := Wnd.Bottom;
    if NcScrollBarHasBarGeometry(OtherBar, True) then
      Bar.Right := OtherBar.Left;
  end;
end;

procedure TWin32ThemedScrollBarPaint.PaintScrollCorner(Canvas: TCanvas; const VertBar,
  HorzBar: TRect);
var
  Corner: TRect;
begin
  if not NcScrollBarHasBarGeometry(VertBar, True) then Exit;
  if not NcScrollBarHasBarGeometry(HorzBar, False) then Exit;
  Corner.Left := VertBar.Left;
  Corner.Top := HorzBar.Top;
  Corner.Right := VertBar.Right;
  Corner.Bottom := HorzBar.Bottom;
  if (Corner.Right <= Corner.Left) or (Corner.Bottom <= Corner.Top) then Exit;
  FillSolid(Canvas, Corner, Palette.Background);
end;

procedure TWin32ThemedScrollBarPaint.DrawThumb(Canvas: TCanvas; const ThumbRect: TRect;
  Vertical: Boolean; AColor: TColor);
var
  R: TRect;
  Span: Integer;
begin
  if (ThumbRect.Right <= ThumbRect.Left) or (ThumbRect.Bottom <= ThumbRect.Top) then
    Exit;
  R := ThumbRect;
  if Vertical then begin
    InflateRect(R, -THUMB_INSET, 0);
    Span := R.Bottom - R.Top;
    if Span < MIN_DRAW_THUMB_PX then begin
      R.Top := ThumbRect.Top;
      R.Bottom := ThumbRect.Top + IMin(MIN_DRAW_THUMB_PX, ThumbRect.Bottom - ThumbRect.Top);
    end;
  end else begin
    InflateRect(R, 0, -THUMB_INSET);
    Span := R.Right - R.Left;
    if Span < MIN_DRAW_THUMB_PX then begin
      R.Left := ThumbRect.Left;
      R.Right := ThumbRect.Left + IMin(MIN_DRAW_THUMB_PX, ThumbRect.Right - ThumbRect.Left);
    end;
  end;
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
    Exit;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, THUMB_RADIUS, THUMB_RADIUS);
end;

procedure TWin32ThemedScrollBarPaint.DrawArrowUp(Canvas: TCanvas; const R: TRect; AColor: TColor);
var
  CX, CY, S: Integer;
  Pts: array[0..2] of TPoint;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  S := IMax(2, IMin(R.Right - R.Left, R.Bottom - R.Top) div 5);
  Pts[0].X := CX;
  Pts[0].Y := CY - S;
  Pts[1].X := CX - S;
  Pts[1].Y := CY + S;
  Pts[2].X := CX + S;
  Pts[2].Y := CY + S;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.Polygon(Pts);
end;

procedure TWin32ThemedScrollBarPaint.DrawArrowDown(Canvas: TCanvas; const R: TRect; AColor: TColor);
var
  CX, CY, S: Integer;
  Pts: array[0..2] of TPoint;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  S := IMax(2, IMin(R.Right - R.Left, R.Bottom - R.Top) div 5);
  Pts[0].X := CX;
  Pts[0].Y := CY + S;
  Pts[1].X := CX - S;
  Pts[1].Y := CY - S;
  Pts[2].X := CX + S;
  Pts[2].Y := CY - S;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.Polygon(Pts);
end;

procedure TWin32ThemedScrollBarPaint.DrawArrowLeft(Canvas: TCanvas; const R: TRect; AColor: TColor);
var
  CX, CY, S: Integer;
  Pts: array[0..2] of TPoint;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  S := IMax(2, IMin(R.Right - R.Left, R.Bottom - R.Top) div 5);
  Pts[0].X := CX - S;
  Pts[0].Y := CY;
  Pts[1].X := CX + S;
  Pts[1].Y := CY - S;
  Pts[2].X := CX + S;
  Pts[2].Y := CY + S;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.Polygon(Pts);
end;

procedure TWin32ThemedScrollBarPaint.DrawArrowRight(Canvas: TCanvas; const R: TRect; AColor: TColor);
var
  CX, CY, S: Integer;
  Pts: array[0..2] of TPoint;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  S := IMax(2, IMin(R.Right - R.Left, R.Bottom - R.Top) div 5);
  Pts[0].X := CX + S;
  Pts[0].Y := CY;
  Pts[1].X := CX - S;
  Pts[1].Y := CY - S;
  Pts[2].X := CX - S;
  Pts[2].Y := CY + S;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Color := AColor;
  Canvas.Polygon(Pts);
end;

function TWin32ThemedScrollBarPaint.ClipRectToInner(const R, Bounds: TRect): TRect;
begin
  Result := R;
  if Result.Left < Bounds.Left then Result.Left := Bounds.Left;
  if Result.Top < Bounds.Top then Result.Top := Bounds.Top;
  if Result.Right > Bounds.Right then Result.Right := Bounds.Right;
  if Result.Bottom > Bounds.Bottom then Result.Bottom := Bounds.Bottom;
end;

function TWin32ThemedScrollBarPaint.FitThumbIntoTrack(const Thumb, Track: TRect;
  Vertical: Boolean): TRect;
var
  TrackLen, ThumbLen: Integer;
begin
  Result := Thumb;
  if Vertical then begin
    TrackLen := Track.Bottom - Track.Top;
    if TrackLen <= 0 then Exit;
    ThumbLen := Result.Bottom - Result.Top;
    if ThumbLen < MIN_DRAW_THUMB_PX then
      ThumbLen := IMin(MIN_DRAW_THUMB_PX, TrackLen);
    if ThumbLen > TrackLen then
      ThumbLen := TrackLen;
    if Result.Bottom > Track.Bottom then begin
      Result.Bottom := Track.Bottom;
      Result.Top := Result.Bottom - ThumbLen;
    end;
    if Result.Top < Track.Top then begin
      Result.Top := Track.Top;
      Result.Bottom := Result.Top + ThumbLen;
    end;
    if Result.Bottom > Track.Bottom then
      Result.Bottom := Track.Bottom;
  end else begin
    TrackLen := Track.Right - Track.Left;
    if TrackLen <= 0 then Exit;
    ThumbLen := Result.Right - Result.Left;
    if ThumbLen < MIN_DRAW_THUMB_PX then
      ThumbLen := IMin(MIN_DRAW_THUMB_PX, TrackLen);
    if ThumbLen > TrackLen then
      ThumbLen := TrackLen;
    if Result.Right > Track.Right then begin
      Result.Right := Track.Right;
      Result.Left := Result.Right - ThumbLen;
    end;
    if Result.Left < Track.Left then begin
      Result.Left := Track.Left;
      Result.Right := Result.Left + ThumbLen;
    end;
    if Result.Right > Track.Right then
      Result.Right := Track.Right;
  end;
end;

function TWin32ThemedScrollBarPaint.MappedScrollbarThumbUsable(const Mapped, Track: TRect;
  Vertical: Boolean): Boolean;
var
  Span, ClippedSpan: Integer;
  Clipped: TRect;
begin
  if Vertical then
    Span := Mapped.Bottom - Mapped.Top
  else
    Span := Mapped.Right - Mapped.Left;
  if Span < MIN_DRAW_THUMB_PX then
    Exit(False);
  Clipped := ClipRectToInner(Mapped, Track);
  if Vertical then
    ClippedSpan := Clipped.Bottom - Clipped.Top
  else
    ClippedSpan := Clipped.Right - Clipped.Left;
  if ClippedSpan < MIN_DRAW_THUMB_PX then
    Exit(False);
  if ClippedSpan * 2 < Span then
    Exit(False);
  Result := True;
end;

function TWin32ThemedScrollBarPaint.ThumbRectFromScrollInfo(SBCode: Integer; const Track: TRect;
  Vertical: Boolean): TRect;
var
  si: TScrollInfo;
  Range, Page, Pos, TrackLen, ThumbLen, ThumbPos, MaxPos, Span: Integer;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := 0;
  Result.Bottom := 0;
  FillChar(si, SizeOf(si), 0);
  si.cbSize := SizeOf(si);
  si.fMask := SIF_PAGE or SIF_POS or SIF_RANGE;
  if not GetScrollInfo(HostHwnd, SBCode, si) then Exit;
  if Vertical then
    TrackLen := Track.Bottom - Track.Top
  else
    TrackLen := Track.Right - Track.Left;
  if TrackLen <= 0 then Exit;

  Range := si.nMax - si.nMin + 1;
  Page := Integer(si.nPage);
  if Page < 1 then Page := 1;

  if Range <= Page then begin
    if si.nMax <= si.nMin then Exit;
    ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
    if ThumbLen < MIN_DRAW_THUMB_PX then
      ThumbLen := IMin(MIN_DRAW_THUMB_PX, TrackLen);
    Result := Track;
    Pos := si.nPos;
    if Pos <= si.nMin then
      ThumbPos := 0
    else if Pos >= si.nMax then
      ThumbPos := IMax(0, TrackLen - ThumbLen)
    else begin
      Span := si.nMax - si.nMin;
      if Span < 1 then Span := 1;
      ThumbPos := MulDivFloor(Pos - si.nMin, TrackLen - ThumbLen, Span);
    end;
    if Vertical then begin
      Result.Top := Track.Top + ThumbPos;
      Result.Bottom := Result.Top + ThumbLen;
    end else begin
      Result.Left := Track.Left + ThumbPos;
      Result.Right := Result.Left + ThumbLen;
    end;
    Exit(FitThumbIntoTrack(Result, Track, Vertical));
  end;

  ThumbLen := MulDivFloor(TrackLen, Page, Range);
  if ThumbLen < MIN_THUMB_PX then
    ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
  MaxPos := Range - Page;
  if MaxPos < 1 then
    MaxPos := 1;
  Pos := si.nPos - si.nMin;
  if Pos < 0 then Pos := 0;
  if Pos > MaxPos then Pos := MaxPos;
  ThumbPos := MulDivFloor(Pos, TrackLen - ThumbLen, MaxPos);
  Result := Track;
  if Vertical then begin
    Result.Top := Track.Top + ThumbPos;
    Result.Bottom := Result.Top + ThumbLen;
  end else begin
    Result.Left := Track.Left + ThumbPos;
    Result.Right := Result.Left + ThumbLen;
  end;
  Result := FitThumbIntoTrack(Result, Track, Vertical);
end;

function TWin32ThemedScrollBarPaint.ResolveThumbRect(SBCode: Integer; const Track, BarRect: TRect;
  const sbi: TScrollBarInfo; Vertical: Boolean): TRect;
var
  Thumb: TRect;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := 0;
  Result.Bottom := 0;
  if Vertical then begin
    if sbi.xyThumbBottom > sbi.xyThumbTop then begin
      Thumb := Track;
      Thumb.Top := BarRect.Top + (sbi.xyThumbTop - sbi.rcScrollBar.Top);
      Thumb.Bottom := BarRect.Top + (sbi.xyThumbBottom - sbi.rcScrollBar.Top);
      Thumb.Left := Track.Left;
      Thumb.Right := Track.Right;
      if MappedScrollbarThumbUsable(Thumb, Track, True) then
        Exit(FitThumbIntoTrack(Thumb, Track, True));
    end;
  end else begin
    if sbi.xyThumbBottom > sbi.xyThumbTop then begin
      Thumb := Track;
      Thumb.Left := BarRect.Left + (sbi.xyThumbTop - sbi.rcScrollBar.Left);
      Thumb.Right := BarRect.Left + (sbi.xyThumbBottom - sbi.rcScrollBar.Left);
      Thumb.Top := Track.Top;
      Thumb.Bottom := Track.Bottom;
      if MappedScrollbarThumbUsable(Thumb, Track, False) then
        Exit(FitThumbIntoTrack(Thumb, Track, False));
    end;
  end;
  Result := ThumbRectFromScrollInfo(SBCode, Track, Vertical);
end;

procedure TWin32ThemedScrollBarPaint.PaintVerticalBar(Canvas: TCanvas; const BarRect: TRect;
  const sbi: TScrollBarInfo);
var
  P: TThemePalette;
  Btn, Track, Thumb: TRect;
  ArrowH: Integer;
begin
  P := Palette;
  FillSolid(Canvas, BarRect, P.Background);
  ArrowH := sbi.dxyLineButton;
  if ArrowH <= 0 then
    ArrowH := GetSystemMetrics(SM_CYVSCROLL);
  if ArrowH * 2 > (BarRect.Bottom - BarRect.Top) then
    ArrowH := IMax(0, (BarRect.Bottom - BarRect.Top) div 2);

  Btn := BarRect;
  Btn.Bottom := Btn.Top + ArrowH;
  FillSolid(Canvas, Btn, P.Background);
  DrawArrowUp(Canvas, Btn, ArrowColor(sbi, 0));

  Btn := BarRect;
  Btn.Top := BarRect.Bottom - ArrowH;
  FillSolid(Canvas, Btn, P.Background);
  DrawArrowDown(Canvas, Btn, ArrowColor(sbi, 1));

  Track := BarRect;
  Track.Top := BarRect.Top + ArrowH;
  Track.Bottom := BarRect.Bottom - ArrowH;
  FillSolid(Canvas, Track, P.Background);

  if Track.Bottom > Track.Top then begin
    Thumb := ResolveThumbRect(SB_VERT, Track, BarRect, sbi, True);
    if Thumb.Bottom > Thumb.Top then
      DrawThumb(Canvas, Thumb, True, ThumbColor(sbi, 2));
  end;
end;

procedure TWin32ThemedScrollBarPaint.PaintHorizontalBar(Canvas: TCanvas; const BarRect: TRect;
  const sbi: TScrollBarInfo);
var
  P: TThemePalette;
  Btn, Track, Thumb: TRect;
  ArrowW: Integer;
begin
  P := Palette;
  FillSolid(Canvas, BarRect, P.Background);
  ArrowW := sbi.dxyLineButton;
  if ArrowW <= 0 then
    ArrowW := GetSystemMetrics(SM_CXHSCROLL);
  if ArrowW * 2 > (BarRect.Right - BarRect.Left) then
    ArrowW := IMax(0, (BarRect.Right - BarRect.Left) div 2);

  Btn := BarRect;
  Btn.Right := Btn.Left + ArrowW;
  FillSolid(Canvas, Btn, P.Background);
  DrawArrowLeft(Canvas, Btn, ArrowColor(sbi, 0));

  Btn := BarRect;
  Btn.Left := BarRect.Right - ArrowW;
  FillSolid(Canvas, Btn, P.Background);
  DrawArrowRight(Canvas, Btn, ArrowColor(sbi, 1));

  Track := BarRect;
  Track.Left := BarRect.Left + ArrowW;
  Track.Right := BarRect.Right - ArrowW;
  FillSolid(Canvas, Track, P.Background);

  if Track.Right > Track.Left then begin
    Thumb := ResolveThumbRect(SB_HORZ, Track, BarRect, sbi, False);
    if Thumb.Right > Thumb.Left then
      DrawThumb(Canvas, Thumb, False, ThumbColor(sbi, 2));
  end;
end;

procedure TWin32ThemedScrollBarPaint.MaybeDrawFlatBorder(HDC: HDC);
var
  WR: TRect;
  Canvas: TCanvas;
  P: TThemePalette;
  HasBorder: Boolean;
begin
  if not Assigned(FControl) then Exit;
  HasBorder := False;
  if FControl is TCustomMemo then
    HasBorder := TCustomMemo(FControl).BorderStyle <> bsNone
  else if FControl is TCustomListBox then
    HasBorder := TCustomListBox(FControl).BorderStyle <> bsNone
  else if FControl is TCustomTreeView then
    HasBorder := TCustomTreeView(FControl).BorderStyle <> bsNone;
  if not HasBorder then Exit;

  if not GetWindowRect(HostHwnd, WR) then Exit;
  OffsetRect(WR, -WR.Left, -WR.Top);
  P := Palette;
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := HDC;
    Canvas.Pen.Color := P.Border;
    Canvas.Pen.Width := 1;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(WR.Left, WR.Top, WR.Right - 1, WR.Bottom - 1);
  finally
    Canvas.Handle := 0;
    Canvas.Free;
  end;
end;

procedure TWin32ThemedScrollBarPaint.ResolveNcScrollBarRects(out BarVert, BarHorz: TRect;
  var sbiVert, sbiHorz: TScrollBarInfo);
var
  WR, Wnd, Mapped: TRect;
begin
  BarVert.Left := 0;
  BarVert.Top := 0;
  BarVert.Right := 0;
  BarVert.Bottom := 0;
  BarHorz := BarVert;
  if HostHwnd = 0 then Exit;
  if not GetWindowRect(HostHwnd, WR) then Exit;
  Wnd := WR;
  OffsetRect(Wnd, -WR.Left, -WR.Top);

  if WindowNcScrollBarEnabled(True) then begin
    InitDefaultScrollBarInfo(sbiVert, True);
    if GetScrollBarInfo(HostHwnd, OBJID_VSCROLL, sbiVert) then begin
      Mapped := sbiVert.rcScrollBar;
      OffsetRect(Mapped, -WR.Left, -WR.Top);
      if NcScrollBarHasBarGeometry(Mapped, True) then
        BarVert := Mapped
      else
        FallbackNcScrollBarRect(True, Wnd, BarHorz, BarVert, sbiVert);
    end else
      FallbackNcScrollBarRect(True, Wnd, BarHorz, BarVert, sbiVert);
  end;

  if WindowNcScrollBarEnabled(False) then begin
    InitDefaultScrollBarInfo(sbiHorz, False);
    if GetScrollBarInfo(HostHwnd, OBJID_HSCROLL, sbiHorz) then begin
      Mapped := sbiHorz.rcScrollBar;
      OffsetRect(Mapped, -WR.Left, -WR.Top);
      if NcScrollBarHasBarGeometry(Mapped, False) then
        BarHorz := Mapped
      else
        FallbackNcScrollBarRect(False, Wnd, BarVert, BarHorz, sbiHorz);
    end else
      FallbackNcScrollBarRect(False, Wnd, BarVert, BarHorz, sbiHorz);
  end;

  if WindowNcScrollBarEnabled(True) and WindowNcScrollBarEnabled(False) and
     NcScrollBarHasBarGeometry(BarHorz, False) and
     (not NcScrollBarHasBarGeometry(BarVert, True) or (BarVert.Bottom > BarHorz.Top)) then
  begin
    if NcScrollBarHasBarGeometry(BarVert, True) then
      BarVert.Bottom := BarHorz.Top
    else
      FallbackNcScrollBarRect(True, Wnd, BarHorz, BarVert, sbiVert);
  end;
end;

procedure TWin32ThemedScrollBarPaint.PaintNcScrollBarsContent(Canvas: TCanvas;
  const BarVert, BarHorz: TRect; const sbiVert, sbiHorz: TScrollBarInfo);
begin
  if NcScrollBarHasBarGeometry(BarHorz, False) then
    PaintHorizontalBar(Canvas, BarHorz, sbiHorz);
  if NcScrollBarHasBarGeometry(BarVert, True) then
    PaintVerticalBar(Canvas, BarVert, sbiVert);
  PaintScrollCorner(Canvas, BarVert, BarHorz);
end;

procedure TWin32ThemedScrollBarPaint.ExcludeClientFromWindowDC(DC: HDC);
var
  WR, ClientInWindow: TRect;
  Origin: TPoint;
  CW, CH: Integer;
begin
  if (HostHwnd = 0) or (DC = 0) then Exit;
  if not GetWindowRect(HostHwnd, WR) then Exit;
  if not GetClientRect(HostHwnd, ClientInWindow) then Exit;
  CW := ClientInWindow.Right - ClientInWindow.Left;
  CH := ClientInWindow.Bottom - ClientInWindow.Top;
  Origin.X := 0;
  Origin.Y := 0;
  if ClientToScreen(HostHwnd, Origin) then begin
    ClientInWindow.Left := Origin.X - WR.Left;
    ClientInWindow.Top := Origin.Y - WR.Top;
    ClientInWindow.Right := ClientInWindow.Left + CW;
    ClientInWindow.Bottom := ClientInWindow.Top + CH;
    ExcludeClipRect(DC, ClientInWindow.Left, ClientInWindow.Top, ClientInWindow.Right,
      ClientInWindow.Bottom);
  end;
end;

procedure TWin32ThemedScrollBarPaint.PaintNcScrollBars(HDC: HDC);
var
  sbiVert, sbiHorz: TScrollBarInfo;
  Canvas: TCanvas;
  BarVert, BarHorz: TRect;
begin
  if HostHwnd = 0 then Exit;
  ResolveNcScrollBarRects(BarVert, BarHorz, sbiVert, sbiHorz);
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := HDC;
    PaintNcScrollBarsContent(Canvas, BarVert, BarHorz, sbiVert, sbiHorz);
  finally
    Canvas.Handle := 0;
    Canvas.Free;
  end;
  MaybeDrawFlatBorder(HDC);
end;

procedure TWin32ThemedScrollBarPaint.PaintStandaloneScrollBar(HDC: HDC);
var
  SB: TScrollBar;
  CR: TRect;
  Canvas: TCanvas;
  si: TScrollInfo;
  P: TThemePalette;
  ArrowSz, TrackLen, ThumbLen, ThumbPos, Range, Visible: Integer;
  Btn, Track, Thumb: TRect;
  Vertical: Boolean;
begin
  SB := FStandaloneScrollBar;
  if not Assigned(SB) then Exit;
  if not GetClientRect(HostHwnd, CR) then Exit;

  Vertical := SB.Kind = sbVertical;
  if Vertical then
    ArrowSz := GetSystemMetrics(SM_CYVSCROLL)
  else
    ArrowSz := GetSystemMetrics(SM_CXHSCROLL);
  if ArrowSz < 4 then ArrowSz := 16;

  P := Palette;
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := HDC;
    FillSolid(Canvas, CR, P.Background);

    si.cbSize := SizeOf(si);
    si.fMask := SIF_ALL;
    if Vertical then begin
      si.nMin := SB.Min;
      si.nMax := SB.Max;
      si.nPage := SB.PageSize;
      si.nPos := SB.Position;
    end else begin
      si.nMin := SB.Min;
      si.nMax := SB.Max;
      si.nPage := SB.PageSize;
      si.nPos := SB.Position;
    end;

    Range := IMax(1, si.nMax - si.nMin + 1);
    Visible := IMax(1, si.nPage);
    if Visible > Range then
      Visible := Range;

    if Vertical then begin
      Btn := CR;
      Btn.Bottom := Btn.Top + ArrowSz;
      FillSolid(Canvas, Btn, P.Background);
      DrawArrowUp(Canvas, Btn, P.TextMuted);

      Btn := CR;
      Btn.Top := CR.Bottom - ArrowSz;
      FillSolid(Canvas, Btn, P.Background);
      DrawArrowDown(Canvas, Btn, P.TextMuted);

      Track := CR;
      Track.Top := CR.Top + ArrowSz;
      Track.Bottom := CR.Bottom - ArrowSz;
      TrackLen := IMax(0, Track.Bottom - Track.Top);
      FillSolid(Canvas, Track, P.Background);

      if Range > Visible then begin
        ThumbLen := MulDivFloor(TrackLen, Visible, Range);
        if ThumbLen < MIN_THUMB_PX then
          ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
        ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, Range - Visible);
      end else if si.nMax > si.nMin then begin
        ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
        if ThumbLen < MIN_DRAW_THUMB_PX then
          ThumbLen := IMin(MIN_DRAW_THUMB_PX, TrackLen);
        if si.nPos <= si.nMin then
          ThumbPos := 0
        else if si.nPos >= si.nMax then
          ThumbPos := IMax(0, TrackLen - ThumbLen)
        else
          ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, si.nMax - si.nMin);
      end else begin
        ThumbLen := 0;
        ThumbPos := 0;
      end;

      if (TrackLen > 0) and (ThumbLen > 0) then begin
        Thumb := Track;
        Thumb.Top := Track.Top + ThumbPos;
        Thumb.Bottom := Thumb.Top + ThumbLen;
        Thumb := FitThumbIntoTrack(Thumb, Track, True);
        if Thumb.Bottom > Thumb.Top then
          DrawThumb(Canvas, Thumb, True, P.BorderStrong);
      end;
    end else begin
      Btn := CR;
      Btn.Right := Btn.Left + ArrowSz;
      FillSolid(Canvas, Btn, P.Background);
      DrawArrowLeft(Canvas, Btn, P.TextMuted);

      Btn := CR;
      Btn.Left := CR.Right - ArrowSz;
      FillSolid(Canvas, Btn, P.Background);
      DrawArrowRight(Canvas, Btn, P.TextMuted);

      Track := CR;
      Track.Left := CR.Left + ArrowSz;
      Track.Right := CR.Right - ArrowSz;
      TrackLen := IMax(0, Track.Right - Track.Left);
      FillSolid(Canvas, Track, P.Background);

      if Range > Visible then begin
        ThumbLen := MulDivFloor(TrackLen, Visible, Range);
        if ThumbLen < MIN_THUMB_PX then
          ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
        ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, Range - Visible);
      end else if si.nMax > si.nMin then begin
        ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
        if ThumbLen < MIN_DRAW_THUMB_PX then
          ThumbLen := IMin(MIN_DRAW_THUMB_PX, TrackLen);
        if si.nPos <= si.nMin then
          ThumbPos := 0
        else if si.nPos >= si.nMax then
          ThumbPos := IMax(0, TrackLen - ThumbLen)
        else
          ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, si.nMax - si.nMin);
      end else begin
        ThumbLen := 0;
        ThumbPos := 0;
      end;

      if (TrackLen > 0) and (ThumbLen > 0) then begin
        Thumb := Track;
        Thumb.Left := Track.Left + ThumbPos;
        Thumb.Right := Thumb.Left + ThumbLen;
        Thumb := FitThumbIntoTrack(Thumb, Track, False);
        if Thumb.Right > Thumb.Left then
          DrawThumb(Canvas, Thumb, False, P.BorderStrong);
      end;
    end;
  finally
    Canvas.Handle := 0;
    Canvas.Free;
  end;
end;

function ThemedScrollBarSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Helper: TWin32ThemedScrollBarPaint;
  PS: TPaintStruct;
  DC: HDC;
begin
  Helper := TWin32ThemedScrollBarPaint(Pointer(dwRefData));
  if (Helper = nil) or not Assigned(Helper.FControl) or (Helper.HostHwnd <> hWnd) then
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));

  if Assigned(Helper.FStandaloneScrollBar) then begin
    case uMsg of
      WM_ERASEBKGND:
        Exit(1);
      WM_PAINT:
        begin
          DC := BeginPaint(hWnd, PS);
          try
            Helper.PaintStandaloneScrollBar(DC);
          finally
            EndPaint(hWnd, PS);
          end;
          Exit(0);
        end;
      WM_VSCROLL, WM_HSCROLL, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP:
        begin
          Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
          Helper.RepaintStandaloneScrollBarNow;
          Exit;
        end;
    end;
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  end;

  case uMsg of
    WM_NCPAINT:
      begin
        Helper.RepaintNcScrollBarsNow;
        Exit(0);
      end;
    WM_NCUAHDRAWSCROLL:
      begin
        Helper.RepaintNcScrollBarsNow;
        Exit(0);
      end;
    WM_NCUAHSCROLL:
      begin
        Helper.RepaintNcScrollBarsNow;
        Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
        Helper.RepaintNcScrollBarsNow;
        Exit;
      end;
    WM_VSCROLL, WM_HSCROLL, WM_MOUSEWHEEL, WM_SIZE:
      begin
        Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
        Helper.RepaintNcScrollBarsNow;
        Exit;
      end;
    WM_NCMOUSEMOVE:
      begin
        if NcScrollBarHit(wParam) then begin
          Helper.RepaintNcScrollBarsNow;
          Exit(0);
        end;
        Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
      end;
    WM_NCLBUTTONDOWN, WM_NCLBUTTONUP:
      begin
        Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
        Helper.RepaintNcScrollBarsNow;
        Exit;
      end;
    WM_NCDESTROY:
      Helper.RemoveSubclass;
  end;
  Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

class function TWin32ThemedScrollBarPaint.FindOnControl(AControl: TWinControl): TWin32ThemedScrollBarPaint;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(AControl) then Exit;
  for I := 0 to AControl.ComponentCount - 1 do
    if AControl.Components[I] is TWin32ThemedScrollBarPaint then
      Exit(TWin32ThemedScrollBarPaint(AControl.Components[I]));
end;

constructor TWin32ThemedScrollBarPaint.Create(AOwner: TWinControl);
begin
  inherited Create(AOwner);
  FControl := AOwner;
  FStandaloneScrollBar := nil;
  if AOwner is TScrollBar then
    FStandaloneScrollBar := TScrollBar(AOwner);
  FSubclassInstalled := False;
  FChainedWindowProc := False;
end;

destructor TWin32ThemedScrollBarPaint.Destroy;
begin
  RemoveSubclass;
  if FChainedWindowProc and Assigned(FControl) then
    FControl.WindowProc := FPrevWindowProc;
  inherited Destroy;
end;

procedure TWin32ThemedScrollBarPaint.RepaintNcScrollBarsNow;
var
  DC: HDC;
begin
  if HostHwnd = 0 then Exit;
  DC := GetWindowDC(HostHwnd);
  if DC = 0 then Exit;
  try
    ExcludeClientFromWindowDC(DC);
    PaintNcScrollBars(DC);
  finally
    ReleaseDC(HostHwnd, DC);
  end;
end;

procedure TWin32ThemedScrollBarPaint.RepaintStandaloneScrollBarNow;
var
  DC: HDC;
begin
  if HostHwnd = 0 then Exit;
  DC := GetDC(HostHwnd);
  if DC = 0 then Exit;
  try
    PaintStandaloneScrollBar(DC);
  finally
    ReleaseDC(HostHwnd, DC);
  end;
end;

procedure TWin32ThemedScrollBarPaint.InstallSubclass;
begin
  if FSubclassInstalled then Exit;
  if HostHwnd = 0 then Exit;
  SetWindowTheme(HostHwnd, '', '');
  if SetWindowSubclass(HostHwnd, @ThemedScrollBarSubclassProc, SUBCLASS_ID, PtrUInt(Self)) then
    FSubclassInstalled := True;
end;

procedure TWin32ThemedScrollBarPaint.RemoveSubclass;
begin
  if not FSubclassInstalled then Exit;
  if HostHwnd <> 0 then
    RemoveWindowSubclass(HostHwnd, @ThemedScrollBarSubclassProc, SUBCLASS_ID);
  FSubclassInstalled := False;
end;

procedure TWin32ThemedScrollBarPaint.ControlWindowProc(var Message: TMessage);
begin
  if Message.Msg = LM_CREATE then
    InstallSubclass;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TWin32ThemedScrollBarPaint.Apply(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  if not FChainedWindowProc and Assigned(FControl) then begin
    FPrevWindowProc := FControl.WindowProc;
    FControl.WindowProc := @ControlWindowProc;
    FChainedWindowProc := True;
  end;
  if FControl.HandleAllocated then
    InstallSubclass;
  if Assigned(FStandaloneScrollBar) then
    RepaintStandaloneScrollBarNow
  else
    RepaintNcScrollBarsNow;
end;

procedure ApplyWin32ThemedScrollBars(AControl: TWinControl; ATheme: TThemeKind);
var
  Helper: TWin32ThemedScrollBarPaint;
begin
  if not Assigned(AControl) then Exit;
  if not ControlUsesThemedScrollBars(AControl) then Exit;
  Helper := TWin32ThemedScrollBarPaint.FindOnControl(AControl);
  if Helper = nil then
    Helper := TWin32ThemedScrollBarPaint.Create(AControl);
  Helper.Apply(ATheme);
end;

end.
