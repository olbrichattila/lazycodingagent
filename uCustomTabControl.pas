unit uCustomTabControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, Dialogs,
  uAppTypes, uTheme;

type
  TLazyTabControl = class;

  { TLazyTabPage }
  TLazyTabPage = class(TCustomControl)
  private
    FCaption: string;
    FCanClose: Boolean;
    FBadgeText: string;
    FImageIndex: Integer;
    procedure SetCaptionText(const AValue: string);
    procedure SetBadgeText(const AValue: string);
  protected
    procedure Paint; override;
    procedure SetParent(AParent: TWinControl); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: string read FCaption write SetCaptionText;
    property CanClose: Boolean read FCanClose write FCanClose default False;
    property BadgeText: string read FBadgeText write SetBadgeText;
    property ImageIndex: Integer read FImageIndex write FImageIndex default -1;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Height;
    property Left;
    property ParentColor;
    property ParentFont;
    property TabOrder;
    property Top;
    property Visible;
    property Width;
  end;

  TTabCloseAllowEvent = function(Sender: TObject): Boolean of object;

  { TLazyTabControl }
  TLazyTabControl = class(TCustomControl)
  private
    FPages: TFPList;
    FActivePageIndex: Integer;
    FHeaderHeight: Integer;
    FTheme: TThemeKind;
    FHoverIndex: Integer;
    FHoverCloseIndex: Integer;
    FOnChange: TNotifyEvent;
    FOnTabClose: TNotifyEvent;
    FOnTabCloseAllow: TTabCloseAllowEvent;
    FHeaderOnly: Boolean;
    FInLayout: Boolean;
    procedure SetHeaderOnly(AValue: Boolean);
    function GetPageCount: Integer;
    function GetPage(AIndex: Integer): TLazyTabPage;
    function GetActivePage: TLazyTabPage;
    procedure SetActivePageIndex(AIndex: Integer);
    procedure SetActivePage(APage: TLazyTabPage);
    procedure SetHeaderHeight(AValue: Integer);
    function GetTabRect(AIndex: Integer): TRect;
    function GetCloseButtonRect(const ATabRect: TRect): TRect;
    procedure InternalRegisterPage(APage: TLazyTabPage);
    procedure InternalUnregisterPage(APage: TLazyTabPage);
    function SkipPageLayoutUpdates: Boolean;
    function LayoutPagesAllowed: Boolean;
    procedure UpdatePagesLayout;
  protected
    procedure CreateWnd; override;
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure Loaded; override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    function AddPage(const ACaption: string): TLazyTabPage;
    procedure RemovePage(APage: TLazyTabPage);
    procedure Clear;
    function IndexOf(APage: TLazyTabPage): Integer;
    property PageCount: Integer read GetPageCount;
    property Pages[AIndex: Integer]: TLazyTabPage read GetPage;
    property ActivePageIndex: Integer read FActivePageIndex write SetActivePageIndex;
    property ActivePage: TLazyTabPage read GetActivePage write SetActivePage;
    property HeaderHeight: Integer read FHeaderHeight write SetHeaderHeight default 34;
    property HeaderOnly: Boolean read FHeaderOnly write SetHeaderOnly default False;
    property Theme: TThemeKind read FTheme write ApplyTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnTabClose: TNotifyEvent read FOnTabClose write FOnTabClose;
    property OnTabCloseAllow: TTabCloseAllowEvent read FOnTabCloseAllow write FOnTabCloseAllow;
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Height;
    property Hint;
    property Left;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property Top;
    property Visible;
    property Width;
    property OnClick;
    property OnResize;
  end;

implementation

uses
  LResources;

{ TLazyTabPage }

constructor TLazyTabPage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque];
  DoubleBuffered := True;
  FCaption := 'Tab';
  FCanClose := False;
  FImageIndex := -1;
  FBadgeText := '';
  Align := alNone;
  Visible := False;
end;

procedure TLazyTabPage.SetCaptionText(const AValue: string);
begin
  if FCaption <> AValue then begin
    FCaption := AValue;
    if Assigned(Parent) and (Parent is TLazyTabControl) then
      TLazyTabControl(Parent).Invalidate;
  end;
end;

procedure TLazyTabPage.SetBadgeText(const AValue: string);
begin
  if FBadgeText <> AValue then begin
    FBadgeText := AValue;
    if Assigned(Parent) and (Parent is TLazyTabControl) then
      TLazyTabControl(Parent).Invalidate;
  end;
end;

procedure TLazyTabPage.SetParent(AParent: TWinControl);
begin
  if Assigned(Parent) and (Parent is TLazyTabControl) then
    TLazyTabControl(Parent).InternalUnregisterPage(Self);

  inherited SetParent(AParent);

  if Assigned(AParent) and (AParent is TLazyTabControl) then
    TLazyTabControl(AParent).InternalRegisterPage(Self);
end;

procedure TLazyTabPage.Paint;
var
  P: TThemePalette;
  TControl: TLazyTabControl;
  CurTheme: TThemeKind;
begin
  CurTheme := tkDark;
  if Assigned(Parent) and (Parent is TLazyTabControl) then begin
    TControl := TLazyTabControl(Parent);
    CurTheme := TControl.FTheme;
  end;
  P := ThemePalette(CurTheme);

  Canvas.Brush.Color := P.Surface;
  Canvas.Pen.Color := P.Surface;
  Canvas.FillRect(ClientRect);
end;

{ TLazyTabControl }

constructor TLazyTabControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque];
  DoubleBuffered := True;
  FPages := TFPList.Create;
  FActivePageIndex := -1;
  FHeaderHeight := 34;
  FHeaderOnly := False;
  FTheme := tkDark;
  FHoverIndex := -1;
  FHoverCloseIndex := -1;
  Width := 300;
  Height := 200;
end;

destructor TLazyTabControl.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FPages);
end;

function TLazyTabControl.SkipPageLayoutUpdates: Boolean;
var
  Root: TComponent;
begin
  Result := not Assigned(FPages);
  if Result then Exit;
  Result := csDestroying in ComponentState;
  if Result then Exit;
  Root := Owner;
  while Assigned(Root) do begin
    if csDestroying in Root.ComponentState then
      Exit(True);
    Root := Root.Owner;
  end;
end;

function TLazyTabControl.LayoutPagesAllowed: Boolean;
var
  Root: TComponent;
begin
  if SkipPageLayoutUpdates then
    Exit(False);
  if csLoading in ComponentState then
    Exit(False);
  Root := Owner;
  while Assigned(Root) do begin
    if csLoading in Root.ComponentState then
      Exit(False);
    Root := Root.Owner;
  end;
  Result := ParentFormHandlesReady(Self);
end;

function TLazyTabControl.GetPageCount: Integer;
begin
  if not Assigned(FPages) then
    Result := 0
  else
    Result := FPages.Count;
end;

function TLazyTabControl.GetPage(AIndex: Integer): TLazyTabPage;
begin
  if not Assigned(FPages) then
    Exit(nil);
  if (AIndex >= 0) and (AIndex < FPages.Count) then
    Result := TLazyTabPage(FPages[AIndex])
  else
    Result := nil;
end;

function TLazyTabControl.GetActivePage: TLazyTabPage;
begin
  Result := GetPage(FActivePageIndex);
end;

procedure TLazyTabControl.InternalRegisterPage(APage: TLazyTabPage);
begin
  if not Assigned(FPages) then Exit;
  if FPages.IndexOf(APage) < 0 then begin
    FPages.Add(APage);
    if FActivePageIndex < 0 then
      FActivePageIndex := 0;
    if not LayoutPagesAllowed then
      Exit;
    UpdatePagesLayout;
    Invalidate;
  end;
end;

procedure TLazyTabControl.InternalUnregisterPage(APage: TLazyTabPage);
var
  Idx: Integer;
begin
  if not Assigned(FPages) then Exit;
  Idx := FPages.IndexOf(APage);
  if Idx >= 0 then begin
    FPages.Delete(Idx);
    if FActivePageIndex >= FPages.Count then
      FActivePageIndex := FPages.Count - 1;
    if not LayoutPagesAllowed then
      Exit;
    UpdatePagesLayout;
    Invalidate;
  end;
end;

function TLazyTabControl.AddPage(const ACaption: string): TLazyTabPage;
begin
  Result := TLazyTabPage.Create(Self);
  Result.Caption := ACaption;
  Result.Parent := Self;
  if FActivePageIndex < 0 then
    SetActivePageIndex(0)
  else if LayoutPagesAllowed then
    UpdatePagesLayout;
  Invalidate;
end;

procedure TLazyTabControl.RemovePage(APage: TLazyTabPage);
begin
  if not Assigned(APage) then Exit;
  APage.Parent := nil;
  APage.Free;
end;

procedure TLazyTabControl.Clear;
var
  I: Integer;
  P: TLazyTabPage;
begin
  for I := FPages.Count - 1 downto 0 do begin
    P := TLazyTabPage(FPages[I]);
    P.Parent := nil;
    P.Free;
  end;
  FPages.Clear;
  FActivePageIndex := -1;
  Invalidate;
end;

function TLazyTabControl.IndexOf(APage: TLazyTabPage): Integer;
begin
  Result := FPages.IndexOf(APage);
end;

procedure TLazyTabControl.SetActivePageIndex(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FPages.Count) then begin
    if FActivePageIndex <> AIndex then begin
      FActivePageIndex := AIndex;
      if LayoutPagesAllowed then
        UpdatePagesLayout;
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self);
    end;
  end else if (FPages.Count = 0) and (FActivePageIndex <> -1) then begin
    FActivePageIndex := -1;
    Invalidate;
  end;
end;

procedure TLazyTabControl.SetActivePage(APage: TLazyTabPage);
var
  Idx: Integer;
begin
  Idx := IndexOf(APage);
  if Idx >= 0 then
    SetActivePageIndex(Idx);
end;

procedure TLazyTabControl.SetHeaderHeight(AValue: Integer);
begin
  if FHeaderHeight <> AValue then begin
    FHeaderHeight := AValue;
    ReAlign;
    Invalidate;
  end;
end;

procedure TLazyTabControl.SetHeaderOnly(AValue: Boolean);
begin
  if FHeaderOnly = AValue then Exit;
  FHeaderOnly := AValue;
  if LayoutPagesAllowed then
    UpdatePagesLayout;
  ReAlign;
  Invalidate;
end;

procedure TLazyTabControl.ApplyTheme(ATheme: TThemeKind);
var
  I: Integer;
begin
  FTheme := ATheme;
  for I := 0 to PageCount - 1 do
    Pages[I].Invalidate;
  Invalidate;
end;

procedure TLazyTabControl.UpdatePagesLayout;
var
  I: Integer;
  P: TLazyTabPage;
begin
  if not LayoutPagesAllowed then Exit;
  if FInLayout then Exit;
  FInLayout := True;
  try
    for I := 0 to FPages.Count - 1 do begin
      P := TLazyTabPage(FPages[I]);
      if FHeaderOnly then begin
        P.Visible := False;
        P.Align := alNone;
      end else if I = FActivePageIndex then begin
        P.Align := alClient;
        P.Visible := True;
        P.BringToFront;
      end else begin
        P.Visible := False;
        P.Align := alNone;
      end;
    end;
  finally
    FInLayout := False;
  end;
end;

procedure TLazyTabControl.CreateWnd;
begin
  inherited CreateWnd;
  UpdatePagesLayout;
end;

procedure TLazyTabControl.AdjustClientRect(var Rect: TRect);
begin
  inherited AdjustClientRect(Rect);
  Inc(Rect.Top, FHeaderHeight);
  if FHeaderOnly or (Rect.Top >= Rect.Bottom) then
    Rect.Top := Rect.Bottom;
end;

procedure TLazyTabControl.Loaded;
begin
  inherited Loaded;
  if LayoutPagesAllowed then
    UpdatePagesLayout;
  Invalidate;
end;

function TLazyTabControl.GetTabRect(AIndex: Integer): TRect;
var
  I: Integer;
  LeftPos: Integer;
  TabW: Integer;
  TextW: Integer;
  PageObj: TLazyTabPage;
begin
  LeftPos := 4;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];

  for I := 0 to AIndex do begin
    PageObj := TLazyTabPage(FPages[I]);
    TextW := Canvas.TextWidth(PageObj.Caption);
    TabW := TextW + 28; // Padding
    if PageObj.CanClose then
      TabW := TabW + 18;
    if PageObj.BadgeText <> '' then
      TabW := TabW + Canvas.TextWidth(PageObj.BadgeText) + 12;

    if TabW < 64 then TabW := 64;

    if I = AIndex then begin
      Result := Rect(LeftPos, 2, LeftPos + TabW, FHeaderHeight);
      Exit;
    end;
    LeftPos := LeftPos + TabW + 2;
  end;

  Result := Rect(0, 0, 0, 0);
end;

function TLazyTabControl.GetCloseButtonRect(const ATabRect: TRect): TRect;
begin
  Result := Rect(ATabRect.Right - 20, ATabRect.Top + (ATabRect.Bottom - ATabRect.Top - 14) div 2,
                 ATabRect.Right - 6, ATabRect.Top + (ATabRect.Bottom - ATabRect.Top - 14) div 2 + 14);
end;

procedure TLazyTabControl.Paint;
var
  P: TThemePalette;
  I: Integer;
  TabR, CloseR: TRect;
  PageObj: TLazyTabPage;
  IsActive, IsHover, IsCloseHover: Boolean;
  TextX, TextY: Integer;
begin
  P := ThemePalette(FTheme);

  // 1. Draw Tab Strip / Header Background
  Canvas.Brush.Color := P.HeaderBg;
  Canvas.Pen.Color := P.HeaderBg;
  Canvas.Rectangle(0, 0, Width, FHeaderHeight);

  // 2. Draw Bottom Separator Border under tabs
  Canvas.Pen.Color := P.Border;
  Canvas.MoveTo(0, FHeaderHeight - 1);
  Canvas.LineTo(Width, FHeaderHeight - 1);

  // 3. Draw Tab Buttons
  for I := 0 to FPages.Count - 1 do begin
    PageObj := TLazyTabPage(FPages[I]);
    TabR := GetTabRect(I);
    IsActive := (I = FActivePageIndex);
    IsHover := (I = FHoverIndex);
    IsCloseHover := (I = FHoverCloseIndex);

    // Tab Background
    if IsActive then begin
      Canvas.Brush.Color := P.Surface;
      Canvas.Pen.Color := P.Border;
      // Draw tab outline: Left, Top, Right
      Canvas.Rectangle(TabR.Left, TabR.Top + 2, TabR.Right, TabR.Bottom);
      
      // Cover the bottom line on active tab to integrate with page surface
      Canvas.Pen.Color := P.Surface;
      Canvas.MoveTo(TabR.Left + 1, FHeaderHeight - 1);
      Canvas.LineTo(TabR.Right - 1, FHeaderHeight - 1);

      // Active Indicator top line or bottom line (accent)
      Canvas.Brush.Color := P.Accent;
      Canvas.Pen.Color := P.Accent;
      Canvas.FillRect(Rect(TabR.Left, TabR.Top + 2, TabR.Right, TabR.Top + 4));
    end else if IsHover then begin
      Canvas.Brush.Color := P.SurfaceAlt;
      Canvas.Pen.Color := P.Border;
      Canvas.RoundRect(TabR.Left, TabR.Top + 4, TabR.Right, TabR.Bottom - 1, 4, 4);
    end;

    // Tab Caption
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    if IsActive then begin
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := P.Text;
    end else if IsHover then begin
      Canvas.Font.Style := [];
      Canvas.Font.Color := P.Text;
    end else begin
      Canvas.Font.Style := [];
      Canvas.Font.Color := P.TextMuted;
    end;

    TextX := TabR.Left + 12;
    TextY := TabR.Top + ((TabR.Bottom - TabR.Top - Canvas.TextHeight(PageObj.Caption)) div 2);
    Canvas.TextRect(TabR, TextX, TextY, PageObj.Caption);

    // Badge (if any)
    if PageObj.BadgeText <> '' then begin
      // Render small count pill
      TextX := TextX + Canvas.TextWidth(PageObj.Caption) + 6;
      Canvas.Brush.Color := P.BorderStrong;
      Canvas.Pen.Color := P.BorderStrong;
      Canvas.RoundRect(TextX, TextY - 1, TextX + Canvas.TextWidth(PageObj.BadgeText) + 8, TextY + Canvas.TextHeight(PageObj.BadgeText) + 1, 6, 6);
      Canvas.Font.Size := 8;
      Canvas.Font.Color := P.Text;
      Canvas.TextOut(TextX + 4, TextY, PageObj.BadgeText);
    end;

    // Close button (if CanClose)
    if PageObj.CanClose then begin
      CloseR := GetCloseButtonRect(TabR);
      if IsCloseHover then begin
        Canvas.Brush.Color := P.AccentActive;
        Canvas.Pen.Color := P.Accent;
        Canvas.RoundRect(CloseR.Left, CloseR.Top, CloseR.Right, CloseR.Bottom, 3, 3);
      end;
      // Draw 'x' icon
      Canvas.Pen.Color := P.TextMuted;
      if IsCloseHover then Canvas.Pen.Color := P.Accent;
      Canvas.MoveTo(CloseR.Left + 3, CloseR.Top + 3);
      Canvas.LineTo(CloseR.Right - 3, CloseR.Bottom - 3);
      Canvas.MoveTo(CloseR.Right - 4, CloseR.Top + 3);
      Canvas.LineTo(CloseR.Left + 2, CloseR.Bottom - 3);
    end;
  end;

  // 4. Fill client band below tabs when there is no page content
  if FHeaderOnly or (FPages.Count = 0) then begin
    if FHeaderHeight < Height then begin
      Canvas.Brush.Color := P.HeaderBg;
      Canvas.Pen.Color := P.HeaderBg;
      Canvas.FillRect(Rect(0, FHeaderHeight, Width, Height));
    end;
  end;
end;

procedure TLazyTabControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  TabR, CloseR: TRect;
  PageObj: TLazyTabPage;
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button = mbLeft then begin
    if Y < FHeaderHeight then begin
      for I := 0 to FPages.Count - 1 do begin
        TabR := GetTabRect(I);
        if PtInRect(TabR, Point(X, Y)) then begin
          PageObj := TLazyTabPage(FPages[I]);
          if PageObj.CanClose then begin
            CloseR := GetCloseButtonRect(TabR);
            if PtInRect(CloseR, Point(X, Y)) then begin
              if Assigned(FOnTabCloseAllow) and not FOnTabCloseAllow(PageObj) then
                Exit;
              if Assigned(FOnTabClose) then
                FOnTabClose(PageObj);
              RemovePage(PageObj);
              Exit;
            end;
          end;

          SetActivePageIndex(I);
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TLazyTabControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  TabR, CloseR: TRect;
  NewHover, NewCloseHover: Integer;
  PageObj: TLazyTabPage;
begin
  inherited MouseMove(Shift, X, Y);

  NewHover := -1;
  NewCloseHover := -1;

  if Y < FHeaderHeight then begin
    for I := 0 to FPages.Count - 1 do begin
      TabR := GetTabRect(I);
      if PtInRect(TabR, Point(X, Y)) then begin
        NewHover := I;
        PageObj := TLazyTabPage(FPages[I]);
        if PageObj.CanClose then begin
          CloseR := GetCloseButtonRect(TabR);
          if PtInRect(CloseR, Point(X, Y)) then
            NewCloseHover := I;
        end;
        Break;
      end;
    end;
  end;

  if (FHoverIndex <> NewHover) or (FHoverCloseIndex <> NewCloseHover) then begin
    FHoverIndex := NewHover;
    FHoverCloseIndex := NewCloseHover;
    Invalidate;
  end;
end;

procedure TLazyTabControl.MouseLeave;
begin
  inherited MouseLeave;
  if (FHoverIndex <> -1) or (FHoverCloseIndex <> -1) then begin
    FHoverIndex := -1;
    FHoverCloseIndex := -1;
    Invalidate;
  end;
end;

initialization
  RegisterComponents('LazyCodingAgent', [TLazyTabControl, TLazyTabPage]);

end.
