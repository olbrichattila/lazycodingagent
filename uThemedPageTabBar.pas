unit uThemedPageTabBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, ComCtrls, Graphics, LCLType, uAppTypes, uTheme;

type
  TThemedTabCloseEvent = procedure(Sender: TObject; TabSheet: TTabSheet;
    var AllowClose: Boolean) of object;
  TThemedAddTabEvent = procedure(Sender: TObject) of object;

  { Themed tab strip for a PageControl with ShowTabs = False. }
  TThemedPageTabBar = class(TPanel)
  private
    FPageControl: TPageControl;
    FTheme: TThemeKind;
    FShowAddTab: Boolean;
    FAddTabCaption: string;
    FHoverTabIndex: Integer;
    FHoverCloseIndex: Integer;
    FOnTabClose: TThemedTabCloseEvent;
    FOnAddTab: TThemedAddTabEvent;
    FTabRects: array of TRect;
    FAddTabRect: TRect;
    function VisibleTabCount: Integer;
    function VisibleTabSheetAt(AVisibleIndex: Integer): TTabSheet;
    function IndexOfTabSheet(ASheet: TTabSheet): Integer;
    procedure LayoutTabs;
    procedure PaintTabStrip;
    procedure SetPageControl(AControl: TPageControl);
    class function FindMetaIndex(ASheet: TTabSheet): Integer; static;
    class procedure EnsureMeta(ASheet: TTabSheet); static;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RefreshFromPageControl;
    class procedure SetTabAllowsClose(ASheet: TTabSheet; AValue: Boolean); static;
    class procedure SetTabHidden(ASheet: TTabSheet; AValue: Boolean); static;
    class function TabIsHidden(ASheet: TTabSheet): Boolean; static;
    class function TabAllowsClose(ASheet: TTabSheet): Boolean; static;
    property PageControl: TPageControl read FPageControl write SetPageControl;
    property ShowAddTab: Boolean read FShowAddTab write FShowAddTab;
    property AddTabCaption: string read FAddTabCaption write FAddTabCaption;
    property OnTabClose: TThemedTabCloseEvent read FOnTabClose write FOnTabClose;
    property OnAddTab: TThemedAddTabEvent read FOnAddTab write FOnAddTab;
  end;

implementation

type
  TThemedTabMeta = record
    Sheet: TTabSheet;
    AllowClose: Boolean;
    Hidden: Boolean;
  end;

var
  GThemedTabMeta: array of TThemedTabMeta;

class function TThemedPageTabBar.FindMetaIndex(ASheet: TTabSheet): Integer;
var
  I: Integer;
begin
  Result := -1;
  if not Assigned(ASheet) then Exit;
  for I := 0 to High(GThemedTabMeta) do
    if GThemedTabMeta[I].Sheet = ASheet then
      Exit(I);
end;

class procedure TThemedPageTabBar.EnsureMeta(ASheet: TTabSheet);
var
  N: Integer;
begin
  if not Assigned(ASheet) then Exit;
  if FindMetaIndex(ASheet) >= 0 then Exit;
  N := Length(GThemedTabMeta);
  SetLength(GThemedTabMeta, N + 1);
  GThemedTabMeta[N].Sheet := ASheet;
  GThemedTabMeta[N].AllowClose := False;
  GThemedTabMeta[N].Hidden := False;
end;

class procedure TThemedPageTabBar.SetTabAllowsClose(ASheet: TTabSheet; AValue: Boolean);
var
  I: Integer;
begin
  EnsureMeta(ASheet);
  I := FindMetaIndex(ASheet);
  if I >= 0 then
    GThemedTabMeta[I].AllowClose := AValue;
end;

class procedure TThemedPageTabBar.SetTabHidden(ASheet: TTabSheet; AValue: Boolean);
var
  I: Integer;
begin
  EnsureMeta(ASheet);
  I := FindMetaIndex(ASheet);
  if I >= 0 then
    GThemedTabMeta[I].Hidden := AValue;
  if Assigned(ASheet) then
    ASheet.TabVisible := not AValue;
end;

class function TThemedPageTabBar.TabIsHidden(ASheet: TTabSheet): Boolean;
var
  I: Integer;
begin
  I := FindMetaIndex(ASheet);
  if I < 0 then
    Result := False
  else
    Result := GThemedTabMeta[I].Hidden;
end;

class function TThemedPageTabBar.TabAllowsClose(ASheet: TTabSheet): Boolean;
var
  I: Integer;
begin
  I := FindMetaIndex(ASheet);
  if I < 0 then
    Result := False
  else
    Result := GThemedTabMeta[I].AllowClose;
end;

constructor TThemedPageTabBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FTheme := tkDark;
  FHoverTabIndex := -1;
  FHoverCloseIndex := -1;
  FShowAddTab := False;
  FAddTabCaption := '[+]';
  Height := ScaledThemedTabBarHeight(Self);
  DoubleBuffered := True;
end;

procedure TThemedPageTabBar.SetPageControl(AControl: TPageControl);
begin
  if FPageControl = AControl then Exit;
  FPageControl := AControl;
  RefreshFromPageControl;
end;

procedure TThemedPageTabBar.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.HeaderBg;
  Font.Color := P.Text;
  Invalidate;
end;

function TThemedPageTabBar.VisibleTabCount: Integer;
var
  I: Integer;
  Sheet: TTabSheet;
begin
  Result := 0;
  if not Assigned(FPageControl) then Exit;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if not TabIsHidden(Sheet) then
      Inc(Result);
  end;
end;

function TThemedPageTabBar.VisibleTabSheetAt(AVisibleIndex: Integer): TTabSheet;
var
  I, N: Integer;
  Sheet: TTabSheet;
begin
  Result := nil;
  if not Assigned(FPageControl) then Exit;
  N := 0;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if TabIsHidden(Sheet) then Continue;
    if N = AVisibleIndex then
      Exit(Sheet);
    Inc(N);
  end;
end;

function TThemedPageTabBar.IndexOfTabSheet(ASheet: TTabSheet): Integer;
var
  I, N: Integer;
  Sheet: TTabSheet;
begin
  Result := -1;
  if not Assigned(FPageControl) or not Assigned(ASheet) then Exit;
  N := 0;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if TabIsHidden(Sheet) then Continue;
    if Sheet = ASheet then
      Exit(N);
    Inc(N);
  end;
end;

procedure TThemedPageTabBar.LayoutTabs;
var
  I, Count, TabW, X, Pad, MinW: Integer;
  Sheet: TTabSheet;
  MeasureCanvas: TControlCanvas;
begin
  SetLength(FTabRects, 0);
  FAddTabRect := Rect(0, 0, 0, 0);
  Count := VisibleTabCount;
  if Count = 0 then Exit;

  MeasureCanvas := TControlCanvas.Create;
  try
    MeasureCanvas.Control := Self;
    MeasureCanvas.Font.Name := 'Segoe UI';
    MeasureCanvas.Font.Size := ThemedTabFontSize;
    Pad := 8;
    MinW := 72;
    SetLength(FTabRects, Count);
    X := Pad;
    for I := 0 to Count - 1 do begin
      Sheet := VisibleTabSheetAt(I);
      TabW := MeasureCanvas.TextWidth(Sheet.Caption) + 28;
      if TabAllowsClose(Sheet) then
        Inc(TabW, 16);
      if TabW < MinW then
        TabW := MinW;
      FTabRects[I].Left := X;
      FTabRects[I].Top := 2;
      FTabRects[I].Right := X + TabW;
      FTabRects[I].Bottom := Height - 2;
      X := FTabRects[I].Right + 4;
    end;
    if FShowAddTab then begin
      TabW := MeasureCanvas.TextWidth(FAddTabCaption) + 16;
      if TabW < 40 then TabW := 40;
      FAddTabRect.Left := X;
      FAddTabRect.Top := 2;
      FAddTabRect.Right := X + TabW;
      FAddTabRect.Bottom := Height - 2;
    end;
  finally
    MeasureCanvas.Free;
  end;
end;

procedure TThemedPageTabBar.RefreshFromPageControl;
begin
  LayoutTabs;
  Invalidate;
end;

procedure TThemedPageTabBar.PaintTabStrip;
var
  I: Integer;
  Sheet: TTabSheet;
  ActiveSheet: TTabSheet;
begin
  if not Assigned(FPageControl) then Exit;
  ActiveSheet := FPageControl.ActivePage;
  LayoutTabs;
  for I := 0 to High(FTabRects) do begin
    Sheet := VisibleTabSheetAt(I);
    PaintThemedTab(Canvas, FTabRects[I], Sheet.Caption, Sheet = ActiveSheet, FHoverTabIndex = I,
      TabAllowsClose(Sheet), FHoverCloseIndex = I, FTheme);
  end;
  if FShowAddTab and (FAddTabRect.Right > FAddTabRect.Left) then
    PaintThemedTab(Canvas, FAddTabRect, FAddTabCaption, False, FHoverTabIndex = VisibleTabCount,
      False, False, FTheme);
end;

procedure TThemedPageTabBar.Paint;
begin
  inherited Paint;
  PaintTabStrip;
end;

procedure TThemedPageTabBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I, OldTab, OldClose: Integer;
  R: TRect;
  CloseR: TRect;
  Sheet: TTabSheet;
begin
  inherited MouseMove(Shift, X, Y);
  OldTab := FHoverTabIndex;
  OldClose := FHoverCloseIndex;
  FHoverTabIndex := -1;
  FHoverCloseIndex := -1;
  LayoutTabs;
  for I := 0 to High(FTabRects) do begin
    R := FTabRects[I];
    if PtInRect(R, Point(X, Y)) then begin
      FHoverTabIndex := I;
      Sheet := VisibleTabSheetAt(I);
      if TabAllowsClose(Sheet) then begin
        CloseR := R;
        CloseR.Left := CloseR.Right - 20;
        if PtInRect(CloseR, Point(X, Y)) then
          FHoverCloseIndex := I;
      end;
      Break;
    end;
  end;
  if FShowAddTab and PtInRect(FAddTabRect, Point(X, Y)) then
    FHoverTabIndex := VisibleTabCount;
  if (FHoverTabIndex <> OldTab) or (FHoverCloseIndex <> OldClose) then
    Invalidate;
end;

procedure TThemedPageTabBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Sheet: TTabSheet;
  AllowClose: Boolean;
  CloseR: TRect;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  LayoutTabs;

  if FShowAddTab and PtInRect(FAddTabRect, Point(X, Y)) then begin
    if Assigned(FOnAddTab) then
      FOnAddTab(Self);
    Exit;
  end;

  for I := 0 to High(FTabRects) do begin
    if not PtInRect(FTabRects[I], Point(X, Y)) then Continue;
    Sheet := VisibleTabSheetAt(I);
    if TabAllowsClose(Sheet) then begin
      CloseR := FTabRects[I];
      CloseR.Left := CloseR.Right - 20;
      if PtInRect(CloseR, Point(X, Y)) then begin
        AllowClose := True;
        if Assigned(FOnTabClose) then
          FOnTabClose(Self, Sheet, AllowClose);
        if AllowClose then
          RefreshFromPageControl;
        Exit;
      end;
    end;
    if Assigned(FPageControl) then
      FPageControl.ActivePage := Sheet;
    RefreshFromPageControl;
    Exit;
  end;
end;

procedure TThemedPageTabBar.MouseLeave;
begin
  inherited MouseLeave;
  if (FHoverTabIndex >= 0) or (FHoverCloseIndex >= 0) then begin
    FHoverTabIndex := -1;
    FHoverCloseIndex := -1;
    Invalidate;
  end;
end;

procedure TThemedPageTabBar.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  Height := ScaledThemedTabBarHeight(Self);
end;

end.
