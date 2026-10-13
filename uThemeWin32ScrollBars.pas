unit uThemeWin32ScrollBars;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, ComCtrls, uAppTypes, uTheme;

procedure ApplyWin32ThemedScrollBars(AControl: TWinControl; ATheme: TThemeKind);

function ControlUsesThemedScrollBars(AControl: TWinControl): Boolean;

implementation

uses
  Graphics, Forms, LCLIntf, LMessages, SysUtils, Windows;

const
  SUBCLASS_ID = 2;
  MIN_THUMB_PX = 24;
  THUMB_INSET = 2;
  THUMB_RADIUS = 3;
  WM_NCMOUSEMOVE = $00A0;
  WM_NCLBUTTONDOWN = $00A1;
  WM_NCLBUTTONUP = $00A2;
  WM_NCUAHDRAWSCROLL = $0313;
  WM_NCUAHSCROLL = $0314;
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
    function ThumbRectInTrack(SBCode: Integer; const Track: TRect; Vertical: Boolean): TRect;
    procedure PaintVerticalBar(Canvas: TCanvas; const BarRect: TRect; const sbi: TScrollBarInfo);
    procedure PaintHorizontalBar(Canvas: TCanvas; const BarRect: TRect; const sbi: TScrollBarInfo);
    procedure FillSolid(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowUp(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowDown(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowLeft(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawArrowRight(Canvas: TCanvas; const R: TRect; AColor: TColor);
    procedure DrawThumb(Canvas: TCanvas; const ThumbRect: TRect; AColor: TColor);
    procedure MaybeDrawFlatBorder(HDC: HDC);
    function ThumbColor(const sbi: TScrollBarInfo; ThumbIndex: Integer): TColor;
    function ArrowColor(const sbi: TScrollBarInfo; ArrowIndex: Integer): TColor;
  public
    constructor Create(AOwner: TWinControl); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind);
    class function FindOnControl(AControl: TWinControl): TWin32ThemedScrollBarPaint;
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

procedure TWin32ThemedScrollBarPaint.DrawThumb(Canvas: TCanvas; const ThumbRect: TRect;
  AColor: TColor);
var
  R: TRect;
begin
  if (ThumbRect.Right <= ThumbRect.Left) or (ThumbRect.Bottom <= ThumbRect.Top) then
    Exit;
  R := ThumbRect;
  InflateRect(R, -THUMB_INSET, -THUMB_INSET);
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

function TWin32ThemedScrollBarPaint.ThumbRectInTrack(SBCode: Integer; const Track: TRect;
  Vertical: Boolean): TRect;
var
  si: TScrollInfo;
  Range, Page, Pos, TrackLen, ThumbLen, ThumbPos, MaxPos: Integer;
begin
  Result.Left := 0;
  Result.Top := 0;
  Result.Right := 0;
  Result.Bottom := 0;
  FillChar(si, SizeOf(si), 0);
  si.cbSize := SizeOf(si);
  si.fMask := SIF_PAGE or SIF_POS or SIF_RANGE;
  if not GetScrollInfo(HostHwnd, SBCode, si) then Exit;
  Range := si.nMax - si.nMin + 1;
  Page := Integer(si.nPage);
  if Page < 1 then Page := 1;
  if Range <= Page then Exit;
  if Vertical then
    TrackLen := Track.Bottom - Track.Top
  else
    TrackLen := Track.Right - Track.Left;
  if TrackLen <= 0 then Exit;
  ThumbLen := MulDivFloor(TrackLen, Page, Range);
  if ThumbLen < MIN_THUMB_PX then
    ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
  MaxPos := Range - Page;
  if MaxPos < 1 then Exit;
  Pos := si.nPos - si.nMin;
  if Pos < 0 then Pos := 0;
  if Pos > MaxPos then Pos := MaxPos;
  ThumbPos := MulDivFloor(Pos, TrackLen - ThumbLen, MaxPos);
  Result := Track;
  if Vertical then begin
    Result.Top := Track.Top + ThumbPos;
    Result.Bottom := Result.Top + ThumbLen;
    if Result.Bottom > Track.Bottom then begin
      Result.Bottom := Track.Bottom;
      Result.Top := IMax(Track.Top, Result.Bottom - ThumbLen);
    end;
    if Result.Top < Track.Top then
      Result.Top := Track.Top;
  end else begin
    Result.Left := Track.Left + ThumbPos;
    Result.Right := Result.Left + ThumbLen;
    if Result.Right > Track.Right then begin
      Result.Right := Track.Right;
      Result.Left := IMax(Track.Left, Result.Right - ThumbLen);
    end;
    if Result.Left < Track.Left then
      Result.Left := Track.Left;
  end;
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

  if (Track.Bottom > Track.Top) and ((sbi.rgstate[2] and STATE_SYSTEM_INVISIBLE) = 0) then begin
    Thumb := ThumbRectInTrack(SB_VERT, Track, True);
    if Thumb.Bottom > Thumb.Top then
      DrawThumb(Canvas, Thumb, ThumbColor(sbi, 2));
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

  if (Track.Right > Track.Left) and ((sbi.rgstate[2] and STATE_SYSTEM_INVISIBLE) = 0) then begin
    Thumb := ThumbRectInTrack(SB_HORZ, Track, False);
    if Thumb.Right > Thumb.Left then
      DrawThumb(Canvas, Thumb, ThumbColor(sbi, 2));
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

procedure TWin32ThemedScrollBarPaint.PaintNcScrollBars(HDC: HDC);
var
  sbi: TScrollBarInfo;
  Canvas: TCanvas;
  WR, Bar: TRect;
begin
  if HostHwnd = 0 then Exit;
  if not GetWindowRect(HostHwnd, WR) then Exit;
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := HDC;
    FillChar(sbi, SizeOf(sbi), 0);
    sbi.cbSize := SizeOf(sbi);
    if GetScrollBarInfo(HostHwnd, OBJID_VSCROLL, sbi) then
      if (sbi.rgstate[0] and STATE_SYSTEM_INVISIBLE) = 0 then begin
        Bar := sbi.rcScrollBar;
        OffsetRect(Bar, -WR.Left, -WR.Top);
        PaintVerticalBar(Canvas, Bar, sbi);
      end;
    FillChar(sbi, SizeOf(sbi), 0);
    sbi.cbSize := SizeOf(sbi);
    if GetScrollBarInfo(HostHwnd, OBJID_HSCROLL, sbi) then
      if (sbi.rgstate[0] and STATE_SYSTEM_INVISIBLE) = 0 then begin
        Bar := sbi.rcScrollBar;
        OffsetRect(Bar, -WR.Left, -WR.Top);
        PaintHorizontalBar(Canvas, Bar, sbi);
      end;
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

      ThumbLen := MulDivFloor(TrackLen, Visible, Range);
      if ThumbLen < MIN_THUMB_PX then
        ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
      if Range > Visible then
        ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, Range - Visible)
      else
        ThumbPos := 0;

      if (TrackLen > 0) and (ThumbLen > 0) and (Range > Visible) then begin
        Thumb := Track;
        Thumb.Top := Track.Top + ThumbPos;
        Thumb.Bottom := Thumb.Top + ThumbLen;
        DrawThumb(Canvas, Thumb, P.BorderStrong);
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

      ThumbLen := MulDivFloor(TrackLen, Visible, Range);
      if ThumbLen < MIN_THUMB_PX then
        ThumbLen := IMin(MIN_THUMB_PX, TrackLen);
      if Range > Visible then
        ThumbPos := MulDivFloor(si.nPos - si.nMin, TrackLen - ThumbLen, Range - Visible)
      else
        ThumbPos := 0;

      if (TrackLen > 0) and (ThumbLen > 0) and (Range > Visible) then begin
        Thumb := Track;
        Thumb.Left := Track.Left + ThumbPos;
        Thumb.Right := Thumb.Left + ThumbLen;
        DrawThumb(Canvas, Thumb, P.BorderStrong);
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
        Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
        Helper.RepaintNcScrollBarsNow;
        Exit;
      end;
    WM_NCUAHDRAWSCROLL, WM_NCUAHSCROLL:
      begin
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
    WM_NCMOUSEMOVE, WM_NCLBUTTONDOWN, WM_NCLBUTTONUP:
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
