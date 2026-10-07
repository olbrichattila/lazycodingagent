unit uDockPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, Dialogs,
  uAppTypes, uTheme;

type
  TDockPanelAction = (dpaHide, dpaDetach, dpaAttach);
  TDockPanelEvent = procedure(Sender: TObject; AId: TPanelId; AAction: TDockPanelAction) of object;

  TDetachedPanelForm = class;

  { TDockPanel }
  TDockPanel = class(TCustomControl)
  private
    FPanelId: TPanelId;
    FPanelTitle: string;
    FHeaderHeight: Integer;
    FTheme: TThemeKind;
    FContent: TWinControl;
    FOnDockAction: TDockPanelEvent;
    FFloatingForm: TDetachedPanelForm;
    FBtnDetachHover: Boolean;
    FBtnHideHover: Boolean;
    function GetDetachBtnRect: TRect;
    function GetHideBtnRect: TRect;
    procedure SetContent(AControl: TWinControl);
    procedure ReleaseFloatingForm;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Configure(AId: TPanelId; const ATitle: string; AActionHandler: TDockPanelEvent);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure DetachToWindow(ALeft, ATop, AWidth, AHeight: Integer);
    procedure AttachToHost(AParent: TWinControl);
    procedure PrepareForApplicationClose;
    function IsDetached: Boolean;
    property PanelId: TPanelId read FPanelId;
    property Content: TWinControl read FContent write SetContent;
    property OnDockAction: TDockPanelEvent read FOnDockAction write FOnDockAction;
    property FloatingForm: TDetachedPanelForm read FFloatingForm;
  end;

  { TDetachedPanelForm }
  TDetachedPanelForm = class(TForm)
  private
    FOwnerPanel: TDockPanel;
    function IsApplicationShutdown: Boolean;
    procedure FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor CreateForPanel(AOwnerPanel: TDockPanel; ALeft, ATop, AWidth, AHeight: Integer);
    property OwnerPanel: TDockPanel read FOwnerPanel;
  end;

implementation

{ TDetachedPanelForm }

constructor TDetachedPanelForm.CreateForPanel(AOwnerPanel: TDockPanel; ALeft, ATop, AWidth, AHeight: Integer);
var
  P: TThemePalette;
begin
  inherited CreateNew(AOwnerPanel);
  FOwnerPanel := AOwnerPanel;
  Caption := AOwnerPanel.FPanelTitle + ' [Detached Window]';
  Position := poDesigned;
  Left := ALeft;
  Top := ATop;
  Width := AWidth;
  Height := AHeight;
  Constraints.MinWidth := 280;
  Constraints.MinHeight := 200;
  ShowInTaskBar := stAlways;

  P := ThemePalette(AOwnerPanel.FTheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  OnCloseQuery := @FormCloseQueryHandler;
end;

function TDetachedPanelForm.IsApplicationShutdown: Boolean;
var
  Root: TComponent;
begin
  Result := Application.Terminated;
  if Result or not Assigned(FOwnerPanel) then Exit;
  Result := csDestroying in FOwnerPanel.ComponentState;
  if Result then Exit;
  Root := FOwnerPanel;
  while Assigned(Root) and not (Root is TForm) do
    Root := Root.Owner;
  if Assigned(Root) then
    Result := csDestroying in Root.ComponentState;
end;

procedure TDetachedPanelForm.FormCloseQueryHandler(Sender: TObject; var CanClose: Boolean);
begin
  if IsApplicationShutdown then
    CanClose := True;
end;

procedure TDetachedPanelForm.DoClose(var CloseAction: TCloseAction);
begin
  if IsApplicationShutdown then begin
    CloseAction := caFree;
    Exit;
  end;
  CloseAction := caHide;
  if Assigned(FOwnerPanel) and Assigned(FOwnerPanel.FOnDockAction) then
    FOwnerPanel.FOnDockAction(FOwnerPanel, FOwnerPanel.PanelId, dpaAttach);
end;

{ TDockPanel }

constructor TDockPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;
  FHeaderHeight := 34;
  FTheme := tkDark;
  FBtnDetachHover := False;
  FBtnHideHover := False;
  FFloatingForm := nil;
end;

destructor TDockPanel.Destroy;
begin
  ReleaseFloatingForm;
  inherited Destroy;
end;

procedure TDockPanel.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFloatingForm) then
    FFloatingForm := nil;
end;

procedure TDockPanel.ReleaseFloatingForm;
begin
  if not Assigned(FFloatingForm) then Exit;
  FFloatingForm.FOwnerPanel := nil;
  if Assigned(FContent) and (FContent.Parent = FFloatingForm) then begin
    if csDestroying in ComponentState then
      FContent.Parent := nil
    else
      FContent.Parent := Self;
  end;
  FreeAndNil(FFloatingForm);
end;

procedure TDockPanel.PrepareForApplicationClose;
begin
  ReleaseFloatingForm;
end;

procedure TDockPanel.Configure(AId: TPanelId; const ATitle: string; AActionHandler: TDockPanelEvent);
begin
  FPanelId := AId;
  FPanelTitle := ATitle;
  FOnDockAction := AActionHandler;
  Invalidate;
end;

procedure TDockPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  Color := P.Surface;
  Font.Color := P.Text;
  if Assigned(FFloatingForm) then begin
    FFloatingForm.Color := P.Background;
    FFloatingForm.Font.Color := P.Text;
    FFloatingForm.Invalidate;
  end;
  Invalidate;
end;

procedure TDockPanel.AdjustClientRect(var Rect: TRect);
begin
  inherited AdjustClientRect(Rect);
  Inc(Rect.Left, 1);
  Inc(Rect.Top, FHeaderHeight + 1);
  Dec(Rect.Right, 1);
  Dec(Rect.Bottom, 1);
end;

procedure TDockPanel.SetContent(AControl: TWinControl);
begin
  FContent := AControl;
  if Assigned(FContent) then begin
    FContent.Parent := Self;
    FContent.Align := alClient;
    if ParentFormHandlesReady(Self) then
      ReAlign;
  end;
end;

function TDockPanel.GetHideBtnRect: TRect;
begin
  Result := Rect(Width - 30, 4, Width - 6, 28);
end;

function TDockPanel.GetDetachBtnRect: TRect;
begin
  if IsDetached then
    Result := Rect(Width - 100, 4, Width - 34, 28)
  else
    Result := Rect(Width - 92, 4, Width - 34, 28);
end;

procedure TDockPanel.Paint;
var
  P: TThemePalette;
  R, DetachR, HideR: TRect;
  DetachText: string;
begin
  P := ThemePalette(FTheme);

  // Background
  Canvas.Brush.Color := P.Surface;
  Canvas.FillRect(ClientRect);

  // Outer border
  Canvas.Pen.Color := P.Border;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(0, 0, Width, Height);

  // Header background
  R := Rect(1, 1, Width - 1, FHeaderHeight);
  Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(R);

  // Header bottom boundary line
  Canvas.Pen.Color := P.Border;
  Canvas.Line(1, FHeaderHeight, Width - 1, FHeaderHeight);

  Canvas.Font.Name := 'Segoe UI Symbol';
  Canvas.Font.Size := 11;
  Canvas.Font.Style := [];
  Canvas.Font.Color := P.Accent;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(8, 9, PanelIconSymbol(FPanelId));

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := P.Accent;
  Canvas.TextOut(26, 9, FPanelTitle);
  Canvas.Brush.Style := bsSolid;

  // Detach / Dock button
  DetachR := GetDetachBtnRect;
  if FBtnDetachHover then
    Canvas.Brush.Color := P.SurfaceAlt
  else
    Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(DetachR);
  Canvas.Pen.Color := P.Border;
  Canvas.Rectangle(DetachR);

  Canvas.Font.Style := [];
  Canvas.Font.Size := 8;
  Canvas.Font.Color := P.TextMuted;
  if IsDetached then
    DetachText := '⇲ Dock'
  else
    DetachText := '⇱ Detach';
  Canvas.TextRect(DetachR, DetachR.Left + 6, DetachR.Top + 4, DetachText);

  // Hide button
  HideR := GetHideBtnRect;
  if FBtnHideHover then
    Canvas.Brush.Color := RGBToColor(220, 50, 50)
  else
    Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(HideR);
  Canvas.Pen.Color := P.Border;
  Canvas.Rectangle(HideR);

  if FBtnHideHover then
    Canvas.Font.Color := clWhite
  else
    Canvas.Font.Color := P.TextMuted;
  Canvas.TextRect(HideR, HideR.Left + 7, HideR.Top + 3, '✕');
end;

procedure TDockPanel.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  OldDetach, OldHide: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  OldDetach := FBtnDetachHover;
  OldHide := FBtnHideHover;

  FBtnDetachHover := GetDetachBtnRect.Contains(Point(X, Y));
  FBtnHideHover := GetHideBtnRect.Contains(Point(X, Y));

  if (OldDetach <> FBtnDetachHover) or (OldHide <> FBtnHideHover) then
    Invalidate;
end;

procedure TDockPanel.MouseLeave;
begin
  inherited MouseLeave;
  if FBtnDetachHover or FBtnHideHover then begin
    FBtnDetachHover := False;
    FBtnHideHover := False;
    Invalidate;
  end;
end;

procedure TDockPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  if GetHideBtnRect.Contains(Point(X, Y)) then begin
    if Assigned(FOnDockAction) then
      FOnDockAction(Self, FPanelId, dpaHide);
  end else if GetDetachBtnRect.Contains(Point(X, Y)) then begin
    if IsDetached then begin
      if Assigned(FOnDockAction) then
        FOnDockAction(Self, FPanelId, dpaAttach);
    end else begin
      if Assigned(FOnDockAction) then
        FOnDockAction(Self, FPanelId, dpaDetach);
    end;
  end;
end;

function TDockPanel.IsDetached: Boolean;
begin
  Result := Assigned(FFloatingForm) and FFloatingForm.Visible;
end;

procedure TDockPanel.DetachToWindow(ALeft, ATop, AWidth, AHeight: Integer);
begin
  if not Assigned(FFloatingForm) then
    FFloatingForm := TDetachedPanelForm.CreateForPanel(Self, ALeft, ATop, AWidth, AHeight);

  if Assigned(FContent) then begin
    FContent.Parent := FFloatingForm;
    FContent.Align := alClient;
  end;

  FFloatingForm.Show;
  Visible := False; // Hide docked host placeholder
end;

procedure TDockPanel.AttachToHost(AParent: TWinControl);
begin
  if Assigned(FFloatingForm) then begin
    FFloatingForm.Hide;
  end;

  Parent := AParent;
  Align := alClient;
  Visible := True;

  if Assigned(FContent) then begin
    FContent.Parent := Self;
    FContent.Align := alClient;
    ReAlign;
  end;
  Invalidate;
end;

end.
