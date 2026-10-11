unit fraThemedTabs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Types, Controls, Graphics, ExtCtrls, Forms, LCLType, uAppTypes, uTheme;

type
  TThemedTabHitKind = (thkNone, thkPage, thkClose, thkPlus);

  TThemedTabPageCloseQueryEvent = function(Sender: TObject; APageIndex: Integer): Boolean of object;

  TThemedTabPageEntry = class
  public
    Body: TControl;
    Caption: string;
    CanClose: Boolean;
    OwnsBody: Boolean;
    TabRect: TRect;
    CloseRect: TRect;
  end;

  { TThemedTabHostFrame }
  TThemedTabHostFrame = class(TFrame)
    pbTabs: TPaintBox;
    pnlPages: TPanel;
    procedure PbTabsPaint(Sender: TObject);
    procedure PbTabsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure PbTabsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PbTabsMouseLeave(Sender: TObject);
  private
    FPages: TObjectList;
    FActiveIndex: Integer;
    FTheme: TThemeKind;
    FShowPlus: Boolean;
    FStripOnly: Boolean;
    FScrollOffset: Integer;
    FHoverIndex: Integer;
    FHoverPlus: Boolean;
    FHoverCloseIndex: Integer;
    FPlusRect: TRect;
    FOnChange: TNotifyEvent;
    FOnPlusClick: TNotifyEvent;
    FOnPageCloseQuery: TThemedTabPageCloseQueryEvent;
    FSuppressChange: Boolean;
    FUpdatingMetrics: Boolean;
    FTabPadH: Integer;
    FTabPadV: Integer;
    FTabCloseW: Integer;
    FTabGap: Integer;
    FPlusTabW: Integer;
    FTabMinWidth: Integer;
    FTabFontSize: Integer;
    function GetPageCount: Integer;
    function GetActivePageIndex: Integer;
    function GetTabStripHeight: Integer;
    procedure SetActivePageIndex(AValue: Integer);
    procedure SetShowPlus(AValue: Boolean);
    procedure SetStripOnly(AValue: Boolean);
    function EntryAt(AIndex: Integer): TThemedTabPageEntry;
    procedure MeasureTabBar(ACanvas: TCanvas);
    function HitTestTabBar(X, Y: Integer; out APageIndex: Integer): TThemedTabHitKind;
    procedure UpdatePageVisibility;
    procedure EnsureActiveVisible;
    procedure InvalidateTabs;
    procedure DoClosePage(AIndex: Integer);
    procedure UpdateTabStripMetrics;
    function TabStripBottom: Integer;
    procedure EnsureTabChrome;
    procedure AdoptEmbeddedPageBodies;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure HostPageBody(ABody: TControl);
    function RegisterPage(ABody: TControl; const ACaption: string; ACanClose: Boolean): Integer;
    function AddPage(const ACaption: string; ACanClose: Boolean): TPanel;
    procedure RemovePage(AIndex: Integer);
    procedure ClearPages;
    procedure SetPageCaption(AIndex: Integer; const ACaption: string);
    function PageBody(AIndex: Integer): TWinControl;
    function IndexOfBody(ABody: TControl): Integer;
    procedure ApplyTheme(ATheme: TThemeKind);
    property PageCount: Integer read GetPageCount;
    property ActivePageIndex: Integer read GetActivePageIndex write SetActivePageIndex;
    property TabStripHeight: Integer read GetTabStripHeight;
    property ShowPlus: Boolean read FShowPlus write SetShowPlus;
    property StripOnly: Boolean read FStripOnly write SetStripOnly;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnPlusClick: TNotifyEvent read FOnPlusClick write FOnPlusClick;
    property OnPageCloseQuery: TThemedTabPageCloseQueryEvent read FOnPageCloseQuery
      write FOnPageCloseQuery;
  end;

function EnsureThemedTabHost(AOwner: TComponent; AHost: TWinControl): TThemedTabHostFrame;

implementation

{$R *.lfm}

function ThemedTabHostCompanionName(const AHostName: string): string;
begin
  Result := AHostName + 'Frame';
end;

function EnsureThemedTabHost(AOwner: TComponent; AHost: TWinControl): TThemedTabHostFrame;
var
  C: TComponent;
  F: TThemedTabHostFrame;
  CompName: string;
begin
  if not Assigned(AOwner) or not Assigned(AHost) then
    Exit(nil);
  CompName := ThemedTabHostCompanionName(AHost.Name);
  C := AOwner.FindComponent(CompName);
  if (C <> nil) and (C is TThemedTabHostFrame) then
    Exit(TThemedTabHostFrame(C));
  F := TThemedTabHostFrame.Create(AOwner);
  F.Name := CompName;
  F.Parent := AHost;
  F.Align := alClient;
  Result := F;
end;

const
  BASE_TAB_PAD_H = 10;
  BASE_TAB_PAD_V = 4;
  BASE_TAB_CLOSE_W = 18;
  BASE_TAB_GAP = 2;
  BASE_PLUS_TAB_W = 28;
  BASE_TAB_MIN_WIDTH = 48;

constructor TThemedTabHostFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPages := TObjectList.Create(True);
  FActiveIndex := -1;
  FTheme := tkDark;
  FShowPlus := False;
  FStripOnly := False;
  FScrollOffset := 0;
  FHoverIndex := -1;
  FHoverCloseIndex := -1;
  FHoverPlus := False;
  FUpdatingMetrics := False;
  Color := clNone;
  Align := alNone;
  EnsureTabChrome;
  UpdateTabStripMetrics;
end;

destructor TThemedTabHostFrame.Destroy;
var
  I: Integer;
  E: TThemedTabPageEntry;
begin
  if Assigned(FPages) then begin
    for I := 0 to FPages.Count - 1 do begin
      E := TThemedTabPageEntry(FPages[I]);
      if Assigned(E) then
        E.Body := nil;
    end;
    FreeAndNil(FPages);
  end;
  inherited Destroy;
end;

procedure TThemedTabHostFrame.EnsureTabChrome;
var
  H: Integer;
begin
  H := ScaledThemedTabBarHeight(Self);
  if not Assigned(pbTabs) then begin
    pbTabs := TPaintBox.Create(Self);
    pbTabs.Parent := Self;
    pbTabs.Align := alTop;
    pbTabs.Height := H;
    pbTabs.OnPaint := @PbTabsPaint;
    pbTabs.OnMouseDown := @PbTabsMouseDown;
    pbTabs.OnMouseMove := @PbTabsMouseMove;
    pbTabs.OnMouseLeave := @PbTabsMouseLeave;
  end;
  if not Assigned(pnlPages) then begin
    pnlPages := TPanel.Create(Self);
    pnlPages.Parent := Self;
    pnlPages.Align := alClient;
    pnlPages.BevelOuter := bvNone;
  end;
end;

procedure TThemedTabHostFrame.AdoptEmbeddedPageBodies;
var
  I: Integer;
  C: TControl;
begin
  if not Assigned(pnlPages) then Exit;
  for I := ControlCount - 1 downto 0 do begin
    C := Controls[I];
    if (C = pbTabs) or (C = pnlPages) then Continue;
    if C.Parent = Self then
      HostPageBody(C);
  end;
end;

procedure TThemedTabHostFrame.Loaded;
begin
  inherited Loaded;
  EnsureTabChrome;
  AdoptEmbeddedPageBodies;
  UpdateTabStripMetrics;
end;

function TThemedTabHostFrame.GetTabStripHeight: Integer;
begin
  if Assigned(pbTabs) and (pbTabs.Height > 0) then
    Result := pbTabs.Height
  else
    Result := ScaledThemedTabBarHeight(Self);
end;

procedure TThemedTabHostFrame.UpdateTabStripMetrics;
var
  H: Integer;
begin
  if FUpdatingMetrics or (csDestroying in ComponentState) then Exit;
  FUpdatingMetrics := True;
  try
    H := ScaledThemedTabBarHeight(Self);
    FTabPadH := ScaledThemedTabMetric(Self, BASE_TAB_PAD_H);
    FTabPadV := ScaledThemedTabMetric(Self, BASE_TAB_PAD_V);
    FTabCloseW := ScaledThemedTabMetric(Self, BASE_TAB_CLOSE_W);
    FTabGap := ScaledThemedTabMetric(Self, BASE_TAB_GAP);
    FPlusTabW := ScaledThemedTabMetric(Self, BASE_PLUS_TAB_W);
    FTabMinWidth := ScaledThemedTabMetric(Self, BASE_TAB_MIN_WIDTH);
    FTabFontSize := ThemedTabFontSize;
    if Assigned(pbTabs) and (pbTabs.Height <> H) then
      pbTabs.Height := H;
  finally
    FUpdatingMetrics := False;
  end;
  InvalidateTabs;
end;

function TThemedTabHostFrame.TabStripBottom: Integer;
begin
  if Assigned(pbTabs) and (pbTabs.ClientHeight > 0) then
    Result := pbTabs.ClientHeight - FTabPadV
  else
    Result := ScaledThemedTabBarHeight(Self) - FTabPadV;
end;

function TThemedTabHostFrame.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

function TThemedTabHostFrame.GetActivePageIndex: Integer;
begin
  Result := FActiveIndex;
end;

procedure TThemedTabHostFrame.SetActivePageIndex(AValue: Integer);
begin
  if (AValue < 0) or (AValue >= FPages.Count) then Exit;
  if FActiveIndex = AValue then Exit;
  FActiveIndex := AValue;
  UpdatePageVisibility;
  EnsureActiveVisible;
  InvalidateTabs;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TThemedTabHostFrame.SetShowPlus(AValue: Boolean);
begin
  if FShowPlus = AValue then Exit;
  FShowPlus := AValue;
  InvalidateTabs;
end;

procedure TThemedTabHostFrame.SetStripOnly(AValue: Boolean);
begin
  if FStripOnly = AValue then Exit;
  FStripOnly := AValue;
  if FStripOnly then
    pnlPages.Visible := False
  else
    pnlPages.Visible := True;
  UpdatePageVisibility;
end;

function TThemedTabHostFrame.EntryAt(AIndex: Integer): TThemedTabPageEntry;
begin
  if (AIndex < 0) or (AIndex >= FPages.Count) then
    Exit(nil);
  Result := TThemedTabPageEntry(FPages[AIndex]);
end;

procedure TThemedTabHostFrame.InvalidateTabs;
begin
  if Assigned(pbTabs) then
    pbTabs.Invalidate;
end;

procedure TThemedTabHostFrame.UpdatePageVisibility;
var
  I: Integer;
  E: TThemedTabPageEntry;
begin
  for I := 0 to FPages.Count - 1 do begin
    E := EntryAt(I);
    if not Assigned(E) or not Assigned(E.Body) then Continue;
    if FStripOnly then begin
      E.Body.Visible := False;
      E.Body.Align := alNone;
    end else if I = FActiveIndex then begin
      E.Body.Visible := True;
      E.Body.Align := alClient;
      E.Body.BringToFront;
    end else begin
      E.Body.Visible := False;
      E.Body.Align := alNone;
    end;
  end;
  if not FStripOnly and Assigned(pnlPages) then
    pnlPages.Color := ThemePalette(FTheme).Surface;
end;

procedure TThemedTabHostFrame.HostPageBody(ABody: TControl);
begin
  if not Assigned(ABody) or not Assigned(pnlPages) then Exit;
  if (ABody = pnlPages) or (ABody = pbTabs) then Exit;
  if ABody.Parent <> pnlPages then
    ABody.Parent := pnlPages;
  ABody.Align := alNone;
  ABody.Visible := False;
end;

procedure TThemedTabHostFrame.EnsureActiveVisible;
var
  E: TThemedTabPageEntry;
  ViewW: Integer;
begin
  if FActiveIndex < 0 then Exit;
  E := EntryAt(FActiveIndex);
  if E = nil then Exit;
  ViewW := pbTabs.ClientWidth;
  if E.TabRect.Right - FScrollOffset > ViewW then
    FScrollOffset := E.TabRect.Right - ViewW;
  if E.TabRect.Left - FScrollOffset < 0 then
    FScrollOffset := E.TabRect.Left;
  if FScrollOffset < 0 then
    FScrollOffset := 0;
end;

function TThemedTabHostFrame.RegisterPage(ABody: TControl; const ACaption: string;
  ACanClose: Boolean): Integer;
var
  E: TThemedTabPageEntry;
  Existing: Integer;
begin
  Existing := IndexOfBody(ABody);
  if Existing >= 0 then
    Exit(Existing);
  E := TThemedTabPageEntry.Create;
  E.Body := ABody;
  E.Caption := ACaption;
  E.CanClose := ACanClose;
  E.OwnsBody := False;
  HostPageBody(ABody);
  FPages.Add(E);
  Result := FPages.Count - 1;
  if FActiveIndex < 0 then
    FActiveIndex := Result;
  UpdatePageVisibility;
  EnsureActiveVisible;
  InvalidateTabs;
end;

function TThemedTabHostFrame.AddPage(const ACaption: string; ACanClose: Boolean): TPanel;
var
  P: TPanel;
  Idx: Integer;
begin
  P := TPanel.Create(Self);
  P.Parent := pnlPages;
  P.BevelOuter := bvNone;
  P.Align := alNone;
  P.Visible := False;
  Idx := RegisterPage(P, ACaption, ACanClose);
  EntryAt(Idx).OwnsBody := True;
  ActivePageIndex := Idx;
  Result := P;
end;

procedure TThemedTabHostFrame.ClearPages;
begin
  FSuppressChange := True;
  try
    while FPages.Count > 0 do
      RemovePage(FPages.Count - 1);
  finally
    FSuppressChange := False;
  end;
end;

procedure TThemedTabHostFrame.RemovePage(AIndex: Integer);
var
  E: TThemedTabPageEntry;
begin
  if (AIndex < 0) or (AIndex >= FPages.Count) then Exit;
  E := EntryAt(AIndex);
  if FActiveIndex = AIndex then begin
    if FPages.Count > 1 then begin
      if AIndex > 0 then
        FActiveIndex := AIndex - 1
      else
        FActiveIndex := 0;
    end else
      FActiveIndex := -1;
  end else if FActiveIndex > AIndex then
    Dec(FActiveIndex);
  if Assigned(E.Body) and E.OwnsBody then
    E.Body.Free;
  FPages.Delete(AIndex);
  UpdatePageVisibility;
  InvalidateTabs;
  if (not FSuppressChange) and Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TThemedTabHostFrame.SetPageCaption(AIndex: Integer; const ACaption: string);
var
  E: TThemedTabPageEntry;
begin
  E := EntryAt(AIndex);
  if E = nil then Exit;
  E.Caption := ACaption;
  InvalidateTabs;
end;

function TThemedTabHostFrame.PageBody(AIndex: Integer): TWinControl;
var
  E: TThemedTabPageEntry;
begin
  E := EntryAt(AIndex);
  if (E = nil) or not (E.Body is TWinControl) then
    Result := nil
  else
    Result := TWinControl(E.Body);
end;

function TThemedTabHostFrame.IndexOfBody(ABody: TControl): Integer;
var
  I: Integer;
  E: TThemedTabPageEntry;
begin
  for I := 0 to FPages.Count - 1 do begin
    E := EntryAt(I);
    if Assigned(E) and (E.Body = ABody) then
      Exit(I);
  end;
  Result := -1;
end;

procedure TThemedTabHostFrame.MeasureTabBar(ACanvas: TCanvas);
var
  I, X, W, TextW, CapW, CloseInset: Integer;
  E: TThemedTabPageEntry;
  Cap: string;
  StripBottom: Integer;
begin
  FPlusRect := Rect(0, 0, 0, 0);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := FTabFontSize;
  StripBottom := TabStripBottom;
  CloseInset := ScaledThemedTabMetric(Self, 2);
  X := FTabPadH - FScrollOffset;
  for I := 0 to FPages.Count - 1 do begin
    E := EntryAt(I);
    if E = nil then Continue;
    Cap := E.Caption;
    TextW := ACanvas.TextWidth(Cap);
    CapW := TextW + FTabPadH * 2;
    if E.CanClose then
      CapW := CapW + FTabCloseW;
    if CapW < FTabMinWidth then
      CapW := FTabMinWidth;
    W := CapW;
    E.TabRect := Rect(X, FTabPadV, X + W, StripBottom);
    if E.CanClose then
      E.CloseRect := Rect(E.TabRect.Right - FTabCloseW - CloseInset, E.TabRect.Top + CloseInset,
        E.TabRect.Right - CloseInset, E.TabRect.Bottom - CloseInset)
    else
      E.CloseRect := Rect(0, 0, 0, 0);
    X := X + W + FTabGap;
  end;
  if FShowPlus then begin
    FPlusRect := Rect(X, FTabPadV, X + FPlusTabW, StripBottom);
  end;
end;

function TThemedTabHostFrame.HitTestTabBar(X, Y: Integer; out APageIndex: Integer): TThemedTabHitKind;
var
  I: Integer;
  E: TThemedTabPageEntry;
begin
  APageIndex := -1;
  Result := thkNone;
  if not Assigned(pbTabs) or (csDestroying in ComponentState) then Exit;
  if (Y < 0) or (Y >= pbTabs.ClientHeight) then Exit;
  MeasureTabBar(pbTabs.Canvas);
  if FShowPlus and PtInRect(FPlusRect, Point(X, Y)) then
    Exit(thkPlus);
  for I := FPages.Count - 1 downto 0 do begin
    E := EntryAt(I);
    if E = nil then Continue;
    if not PtInRect(E.TabRect, Point(X, Y)) then Continue;
    APageIndex := I;
    if E.CanClose and PtInRect(E.CloseRect, Point(X, Y)) then
      Exit(thkClose);
    Exit(thkPage);
  end;
end;

procedure TThemedTabHostFrame.DoClosePage(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FPages.Count) then Exit;
  if Assigned(FOnPageCloseQuery) and not FOnPageCloseQuery(Self, AIndex) then
    Exit;
  RemovePage(AIndex);
end;

procedure TThemedTabHostFrame.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  if Assigned(pnlPages) then
    pnlPages.Color := P.Surface;
  if Assigned(pbTabs) then
    pbTabs.Color := P.HeaderBg;
  UpdateTabStripMetrics;
end;

procedure TThemedTabHostFrame.PbTabsPaint(Sender: TObject);
var
  P: TThemePalette;
  I, TextTop, CloseTextX: Integer;
  E: TThemedTabPageEntry;
  R: TRect;
  Cap: string;
  Active: Boolean;
begin
  if not Assigned(pbTabs) or (csDestroying in ComponentState) then Exit;
  P := ThemePalette(FTheme);
  with pbTabs.Canvas do begin
    Brush.Color := P.HeaderBg;
    FillRect(pbTabs.ClientRect);
    Font.Name := 'Segoe UI';
    Font.Size := FTabFontSize;
    MeasureTabBar(pbTabs.Canvas);
    CloseTextX := ScaledThemedTabMetric(Self, 4);
    for I := 0 to FPages.Count - 1 do begin
      E := EntryAt(I);
      if E = nil then Continue;
      Active := I = FActiveIndex;
      R := E.TabRect;
      if (I = FHoverIndex) and not Active then
        Brush.Color := P.SurfaceAlt
      else if Active then
        Brush.Color := P.Surface
      else
        Brush.Color := P.HeaderBg;
      Pen.Color := P.Border;
      Rectangle(R);
      if Active then begin
        Pen.Color := P.Accent;
        Pen.Width := 2;
        MoveTo(R.Left, R.Bottom - 1);
        LineTo(R.Right, R.Bottom - 1);
        Pen.Width := 1;
      end;
      if Active then
        Font.Color := P.Text
      else
        Font.Color := P.TextMuted;
      Cap := E.Caption;
      TextRect(R, R.Left + FTabPadH, R.Top + (R.Height - TextHeight(Cap)) div 2, Cap);
      if E.CanClose then begin
        if (I = FHoverCloseIndex) or (I = FHoverIndex) then
          Font.Color := P.Text;
        TextOut(E.CloseRect.Left + CloseTextX,
          E.CloseRect.Top + (E.CloseRect.Height - TextHeight('×')) div 2, '×');
      end;
    end;
    if FShowPlus and (FPlusRect.Right > FPlusRect.Left) then begin
      R := FPlusRect;
      if FHoverPlus then
        Brush.Color := P.SurfaceAlt
      else
        Brush.Color := P.HeaderBg;
      Pen.Color := P.Border;
      Rectangle(R);
      Font.Color := P.TextMuted;
      if FHoverPlus then
        Font.Color := P.Accent;
      Cap := '+';
      TextTop := R.Top + (R.Height - TextHeight(Cap)) div 2;
      TextOut(R.Left + (R.Width - TextWidth(Cap)) div 2, TextTop, Cap);
    end;
  end;
end;

procedure TThemedTabHostFrame.PbTabsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Hit: TThemedTabHitKind;
  PageIdx: Integer;
begin
  if Button <> mbLeft then Exit;
  Hit := HitTestTabBar(X, Y, PageIdx);
  case Hit of
    thkPage:
      ActivePageIndex := PageIdx;
    thkClose:
      DoClosePage(PageIdx);
    thkPlus:
      if Assigned(FOnPlusClick) then
        FOnPlusClick(Self);
  end;
end;

procedure TThemedTabHostFrame.PbTabsMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  Hit: TThemedTabHitKind;
  PageIdx, OldHover, OldClose, OldPlus: Integer;
  OldHoverPlus: Boolean;
begin
  OldHover := FHoverIndex;
  OldClose := FHoverCloseIndex;
  OldHoverPlus := FHoverPlus;
  FHoverIndex := -1;
  FHoverCloseIndex := -1;
  FHoverPlus := False;
  Hit := HitTestTabBar(X, Y, PageIdx);
  case Hit of
    thkPage:
      FHoverIndex := PageIdx;
    thkClose:
      begin
        FHoverIndex := PageIdx;
        FHoverCloseIndex := PageIdx;
      end;
    thkPlus:
      FHoverPlus := True;
  end;
  if (OldHover <> FHoverIndex) or (OldClose <> FHoverCloseIndex) or (OldHoverPlus <> FHoverPlus) then
    InvalidateTabs;
end;

procedure TThemedTabHostFrame.PbTabsMouseLeave(Sender: TObject);
begin
  FHoverIndex := -1;
  FHoverCloseIndex := -1;
  FHoverPlus := False;
  InvalidateTabs;
end;

end.
