unit fraThemedPicker;

{$mode objfpc}{$H+}

{ Themed stand-in for a combo box. The menu opens upward so a control sitting
  on the bottom edge of the window is not covered by a downward native list. }

interface

uses
  Classes, SysUtils, Types, Controls, Forms, Graphics, ExtCtrls, LCLType, LMessages,
  LazUTF8, uAppTypes, uTheme;

type
  TThemedPickerFrame = class(TFrame)
    pbFace: TPaintBox;
    procedure PbFacePaint(Sender: TObject);
    procedure PbFaceMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure PbFaceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure PbFaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PbFaceMouseLeave(Sender: TObject);
  private
    FItems: TStringList;
    FItemIndex: Integer;
    FPlaceholder: string;
    FTheme: TThemeKind;
    FHover: Boolean;
    FPressed: Boolean;
    FOpen: Boolean;
    FSuppressOpen: Boolean;
    FPopup: TForm;
    FFocusBefore: TWinControl;
    FOnChange: TNotifyEvent;
    procedure SetItemIndex(AValue: Integer);
    procedure SetPlaceholder(const AValue: string);
    procedure ItemsChanged(Sender: TObject);
    procedure EnsurePbFace;
    procedure EnsurePopup;
    procedure InvalidateFace;
    function CurrentCaption: string;
    procedure OpenPopup;
    procedure ClosePopup(ARestoreFocus: Boolean);
    procedure UserInput(Sender: TObject; Msg: Cardinal);
    procedure KeyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AppDeactivated(Sender: TObject);
    function PopupVisible: Boolean;
    function PickerScreenRect: TRect;
    function PopupScreenRect: TRect;
  protected
    procedure SetEnabled(Value: Boolean); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    function PreferredWidth: Integer;
    procedure PickIndex(AIndex: Integer);
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    property Items: TStringList read FItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    property Placeholder: string read FPlaceholder write SetPlaceholder;
    property Theme: TThemeKind read FTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

{$R *.lfm}

const
  PickerMenuPad = 4;
  PickerMenuMaxRows = 8;

type
  TPickerPopupForm = class(TForm)
  private
    FPicker: TThemedPickerFrame;
    FHover: Integer;
    FTopIndex: Integer;
    FVisibleRows: Integer;
    FRowHeight: Integer;
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseLeave(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    function NeedScroll: Boolean;
    function HitIndex(X, Y: Integer): Integer;
    procedure PaintItems;
    procedure SetTopIndex(AValue: Integer);
  public
    constructor CreatePopup(APicker: TThemedPickerFrame);
    function MeasureRowHeight: Integer;
    function RowsThatFit(AMaxHeight: Integer): Integer;
    function ContentWidth: Integer;
    procedure PrepareOpen(AVisibleRows: Integer);
    procedure MoveHover(ADelta: Integer);
    procedure AcceptHover;
  end;

function Ellipsize(ACanvas: TCanvas; const AText: string; AMaxWidth: Integer): string;
var
  N: Integer;
begin
  Result := AText;
  if (AMaxWidth <= 0) or (ACanvas.TextWidth(Result) <= AMaxWidth) then Exit;
  N := UTF8Length(Result);
  while (N > 0) and (ACanvas.TextWidth(UTF8Copy(Result, 1, N) + '…') > AMaxWidth) do
    Dec(N);
  if N <= 0 then
    Result := '…'
  else
    Result := UTF8Copy(Result, 1, N) + '…';
end;

function MeasureCaptionWidth(AControl: TControl; const AText: string): Integer;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := ThemedButtonFontSize(AControl);
    Bmp.Canvas.Font.Style := [];
    Result := Bmp.Canvas.TextWidth(AText);
  finally
    Bmp.Free;
  end;
end;

procedure DrawChevron(ACanvas: TCanvas; ACX, ACY: Integer; AUp: Boolean; AColor: TColor);
var
  Pts: array[0..2] of TPoint;
begin
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := 1;
  if AUp then begin
    Pts[0] := Point(ACX - 4, ACY + 2);
    Pts[1] := Point(ACX + 4, ACY + 2);
    Pts[2] := Point(ACX, ACY - 3);
  end else begin
    Pts[0] := Point(ACX - 4, ACY - 2);
    Pts[1] := Point(ACX + 4, ACY - 2);
    Pts[2] := Point(ACX, ACY + 3);
  end;
  ACanvas.Polygon(Pts);
end;

{ TPickerPopupForm }

constructor TPickerPopupForm.CreatePopup(APicker: TThemedPickerFrame);
begin
  inherited CreateNew(APicker);
  FPicker := APicker;
  FHover := -1;
  FTopIndex := 0;
  FVisibleRows := 1;
  FRowHeight := 32;
  BorderStyle := bsNone;
  BorderIcons := [];
  ShowInTaskBar := stNever;
  Position := poDesigned;
  PopupMode := pmExplicit;
  FormStyle := fsStayOnTop;
  KeyPreview := True;
  DoubleBuffered := True;
  OnPaint := @FormPaint;
  OnMouseDown := @FormMouseDown;
  OnMouseMove := @FormMouseMove;
  OnMouseLeave := @FormMouseLeave;
  OnMouseWheel := @FormMouseWheel;
end;

function TPickerPopupForm.MeasureRowHeight: Integer;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := 9;
    Result := Bmp.Canvas.TextHeight('Ag') + 12;
    if Result < 28 then
      Result := 28;
  finally
    Bmp.Free;
  end;
end;

function TPickerPopupForm.RowsThatFit(AMaxHeight: Integer): Integer;
var
  Inner: Integer;
begin
  FRowHeight := MeasureRowHeight;
  if FPicker.Items.Count = 0 then
    Exit(1);
  Inner := AMaxHeight - PickerMenuPad * 2;
  if FRowHeight < 1 then
    FRowHeight := 28;
  Result := Inner div FRowHeight;
  if Result < 1 then
    Result := 1;
  if Result > FPicker.Items.Count then
    Result := FPicker.Items.Count;
  if Result > PickerMenuMaxRows then
    Result := PickerMenuMaxRows;
end;

function TPickerPopupForm.ContentWidth: Integer;
var
  Bmp: TBitmap;
  I, W: Integer;
begin
  Result := 120;
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := 9;
    Bmp.Canvas.Font.Style := [fsBold];
    for I := 0 to FPicker.Items.Count - 1 do begin
      W := Bmp.Canvas.TextWidth(FPicker.Items[I]) + 32;
      if NeedScroll then
        W := W + 10;
      if W > Result then
        Result := W;
    end;
  finally
    Bmp.Free;
  end;
end;

function TPickerPopupForm.NeedScroll: Boolean;
begin
  Result := FPicker.Items.Count > FVisibleRows;
end;

procedure TPickerPopupForm.PrepareOpen(AVisibleRows: Integer);
begin
  if AVisibleRows < 1 then
    AVisibleRows := 1;
  FVisibleRows := AVisibleRows;
  FRowHeight := MeasureRowHeight;
  FHover := FPicker.ItemIndex;
  FTopIndex := 0;
  if FPicker.ItemIndex >= 0 then begin
    if FPicker.ItemIndex >= FVisibleRows then
      FTopIndex := FPicker.ItemIndex - FVisibleRows + 1;
  end;
  Color := ThemePalette(FPicker.Theme).Surface;
end;

procedure TPickerPopupForm.SetTopIndex(AValue: Integer);
var
  MaxTop: Integer;
begin
  MaxTop := FPicker.Items.Count - FVisibleRows;
  if MaxTop < 0 then
    MaxTop := 0;
  if AValue < 0 then
    AValue := 0;
  if AValue > MaxTop then
    AValue := MaxTop;
  if FTopIndex = AValue then Exit;
  FTopIndex := AValue;
  Invalidate;
end;

procedure TPickerPopupForm.MoveHover(ADelta: Integer);
var
  HoverIndex, Count: Integer;
begin
  Count := FPicker.Items.Count;
  if Count = 0 then Exit;
  if FHover < 0 then begin
    if ADelta > 0 then
      HoverIndex := 0
    else
      HoverIndex := Count - 1;
  end else begin
    HoverIndex := FHover + ADelta;
    if HoverIndex < 0 then
      HoverIndex := 0;
    if HoverIndex >= Count then
      HoverIndex := Count - 1;
  end;
  FHover := HoverIndex;
  if FHover < FTopIndex then
    SetTopIndex(FHover)
  else if FHover >= FTopIndex + FVisibleRows then
    SetTopIndex(FHover - FVisibleRows + 1);
  Invalidate;
end;

procedure TPickerPopupForm.AcceptHover;
begin
  if (FHover >= 0) and (FHover < FPicker.Items.Count) then
    FPicker.PickIndex(FHover);
end;

function TPickerPopupForm.HitIndex(X, Y: Integer): Integer;
var
  Row, RightLimit: Integer;
begin
  Result := -1;
  if FPicker.Items.Count = 0 then Exit;
  RightLimit := ClientWidth - 1;
  if NeedScroll then
    RightLimit := ClientWidth - 10;
  if (X < 1) or (X >= RightLimit) then Exit;
  if Y < PickerMenuPad then Exit;
  Row := (Y - PickerMenuPad) div FRowHeight;
  if (Row < 0) or (Row >= FVisibleRows) then Exit;
  Result := FTopIndex + Row;
  if (Result < 0) or (Result >= FPicker.Items.Count) then
    Result := -1;
end;

procedure TPickerPopupForm.PaintItems;
var
  P: TThemePalette;
  I, Y, TextTop, TextRight: Integer;
  R: TRect;
  ItemText: string;
  Selected, Hot: Boolean;
begin
  P := ThemePalette(FPicker.Theme);
  Canvas.Brush.Color := P.Surface;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := P.BorderStrong;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  Canvas.Brush.Style := bsSolid;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;

  if FPicker.Items.Count = 0 then begin
    Canvas.Font.Style := [];
    Canvas.Font.Color := P.TextMuted;
    ItemText := FPicker.Placeholder;
    if ItemText = '' then
      ItemText := 'Nothing to choose';
    TextTop := PickerMenuPad + (FRowHeight - Canvas.TextHeight(ItemText)) div 2;
    Canvas.TextOut(12, TextTop, Ellipsize(Canvas, ItemText, ClientWidth - 24));
    Exit;
  end;

  TextRight := ClientWidth - 12;
  if NeedScroll then
    TextRight := ClientWidth - 18;

  Y := PickerMenuPad;
  for I := FTopIndex to FTopIndex + FVisibleRows - 1 do begin
    if I >= FPicker.Items.Count then Break;
    R := Rect(1, Y, ClientWidth - 1, Y + FRowHeight);
    if NeedScroll then
      R.Right := ClientWidth - 10;
    Selected := I = FPicker.ItemIndex;
    Hot := I = FHover;
    if Selected or Hot then begin
      Canvas.Brush.Color := P.AccentActive;
      Canvas.FillRect(R);
    end;
    if Selected then
      Canvas.Font.Style := [fsBold]
    else
      Canvas.Font.Style := [];
    if Selected and (FPicker.Theme = tkLight) then
      Canvas.Font.Color := P.Accent
    else
      Canvas.Font.Color := P.Text;
    ItemText := Ellipsize(Canvas, FPicker.Items[I], TextRight - 12);
    TextTop := Y + (FRowHeight - Canvas.TextHeight(ItemText)) div 2;
    Canvas.TextOut(12, TextTop, ItemText);
    Inc(Y, FRowHeight);
  end;

  if NeedScroll and (FPicker.Items.Count > 0) then begin
    R := Rect(ClientWidth - 8, PickerMenuPad, ClientWidth - 3, ClientHeight - PickerMenuPad);
    Canvas.Brush.Color := P.Border;
    Canvas.FillRect(R);
    TextTop := R.Height * FVisibleRows div FPicker.Items.Count;
    if TextTop < 12 then
      TextTop := 12;
    if FPicker.Items.Count > FVisibleRows then
      Y := R.Top + (R.Height - TextTop) * FTopIndex div (FPicker.Items.Count - FVisibleRows)
    else
      Y := R.Top;
    Canvas.Brush.Color := P.TextMuted;
    Canvas.FillRect(Rect(R.Left, Y, R.Right, Y + TextTop));
  end;
end;

procedure TPickerPopupForm.FormPaint(Sender: TObject);
begin
  PaintItems;
end;

procedure TPickerPopupForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  if Button <> mbLeft then Exit;
  Idx := HitIndex(X, Y);
  if Idx >= 0 then
    FPicker.PickIndex(Idx);
end;

procedure TPickerPopupForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  Idx := HitIndex(X, Y);
  if Idx = FHover then Exit;
  FHover := Idx;
  Invalidate;
end;

procedure TPickerPopupForm.FormMouseLeave(Sender: TObject);
begin
  if FHover = -1 then Exit;
  FHover := -1;
  Invalidate;
end;

procedure TPickerPopupForm.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then
    SetTopIndex(FTopIndex - 1)
  else if WheelDelta < 0 then
    SetTopIndex(FTopIndex + 1);
  Handled := True;
end;

{ TThemedPickerFrame }

constructor TThemedPickerFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  ParentBackground := False;
  FTheme := tkDark;
  FItemIndex := -1;
  FPlaceholder := 'Select';
  FHover := False;
  FPressed := False;
  FOpen := False;
  FSuppressOpen := False;
  Cursor := crHandPoint;
  TabStop := True;
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  EnsurePbFace;
  Application.AddOnUserInputHandler(@UserInput, True);
  Application.AddOnKeyDownBeforeHandler(@KeyBefore, True);
  Application.AddOnDeactivateHandler(@AppDeactivated, True);
end;

destructor TThemedPickerFrame.Destroy;
begin
  Application.RemoveOnUserInputHandler(@UserInput);
  Application.RemoveOnKeyDownBeforeHandler(@KeyBefore);
  Application.RemoveOnDeactivateHandler(@AppDeactivated);
  FPopup := nil;
  if Assigned(FItems) then
    FItems.OnChange := nil;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TThemedPickerFrame.EnsurePbFace;
begin
  if Assigned(pbFace) then Exit;
  pbFace := TPaintBox.Create(Self);
  pbFace.Parent := Self;
  pbFace.Align := alClient;
  pbFace.Cursor := crHandPoint;
  pbFace.OnPaint := @PbFacePaint;
  pbFace.OnMouseDown := @PbFaceMouseDown;
  pbFace.OnMouseUp := @PbFaceMouseUp;
  pbFace.OnMouseMove := @PbFaceMouseMove;
  pbFace.OnMouseLeave := @PbFaceMouseLeave;
end;

procedure TThemedPickerFrame.EnsurePopup;
var
  Popup: TPickerPopupForm;
begin
  if Assigned(FPopup) then Exit;
  Popup := TPickerPopupForm.CreatePopup(Self);
  FPopup := Popup;
end;

procedure TThemedPickerFrame.InvalidateFace;
begin
  if Assigned(pbFace) then
    pbFace.Invalidate;
end;

function TThemedPickerFrame.CurrentCaption: string;
begin
  if Assigned(FItems) and (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
    Result := FItems[FItemIndex]
  else
    Result := FPlaceholder;
end;

function TThemedPickerFrame.PreferredWidth: Integer;
begin
  Result := MeasureCaptionWidth(Self, CurrentCaption) + ScaledThemedTabMetric(Self, 44);
  if Result < 88 then
    Result := 88;
end;

procedure TThemedPickerFrame.SetPlaceholder(const AValue: string);
begin
  if FPlaceholder = AValue then Exit;
  FPlaceholder := AValue;
  InvalidateFace;
end;

procedure TThemedPickerFrame.SetItemIndex(AValue: Integer);
begin
  if not Assigned(FItems) then Exit;
  if AValue < -1 then
    AValue := -1;
  if AValue >= FItems.Count then
    AValue := FItems.Count - 1;
  if FItemIndex = AValue then Exit;
  FItemIndex := AValue;
  InvalidateFace;
  if PopupVisible then
    FPopup.Invalidate;
end;

procedure TThemedPickerFrame.ItemsChanged(Sender: TObject);
begin
  if not Assigned(FItems) then Exit;
  if FItemIndex >= FItems.Count then
    FItemIndex := FItems.Count - 1;
  if PopupVisible then
    ClosePopup(False);
  InvalidateFace;
end;

procedure TThemedPickerFrame.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  Color := ThemePalette(ATheme).Surface;
  if PopupVisible then
    FPopup.Color := ThemePalette(ATheme).Surface;
  InvalidateFace;
  if PopupVisible then
    FPopup.Invalidate;
end;

function TThemedPickerFrame.PopupVisible: Boolean;
begin
  Result := Assigned(FPopup) and FPopup.Visible;
end;

function TThemedPickerFrame.PickerScreenRect: TRect;
var
  P: TPoint;
begin
  if not HandleAllocated then
    Exit(Rect(0, 0, 0, 0));
  P := ClientToScreen(Point(0, 0));
  Result := Rect(P.X, P.Y, P.X + Width, P.Y + Height);
end;

function TThemedPickerFrame.PopupScreenRect: TRect;
var
  P: TPoint;
begin
  if not PopupVisible then
    Exit(Rect(0, 0, 0, 0));
  P := FPopup.ClientToScreen(Point(0, 0));
  Result := Rect(P.X, P.Y, P.X + FPopup.ClientWidth, P.Y + FPopup.ClientHeight);
end;

procedure TThemedPickerFrame.ClosePopup(ARestoreFocus: Boolean);
var
  Restore: TWinControl;
begin
  if not PopupVisible then begin
    FOpen := False;
    Exit;
  end;
  Restore := FFocusBefore;
  FFocusBefore := nil;
  FOpen := False;
  FPopup.Hide;
  InvalidateFace;
  if ARestoreFocus and Assigned(Restore) and (Restore <> FPopup) and
     not (csDestroying in Restore.ComponentState) and Restore.HandleAllocated and
     Restore.CanFocus then
    Restore.SetFocus;
end;

procedure TThemedPickerFrame.OpenPopup;
var
  Popup: TPickerPopupForm;
  Anchor: TPoint;
  WA: TRect;
  Mon: TMonitor;
  SpaceAbove, SpaceBelow, Rows, PopupW, PopupH, MaxW: Integer;
  OpenUp: Boolean;
  ParentForm: TCustomForm;
begin
  if not Enabled or not HandleAllocated then Exit;
  if PopupVisible then Exit;
  EnsurePopup;
  Popup := TPickerPopupForm(FPopup);
  ParentForm := GetParentForm(Self);
  Popup.PopupMode := pmExplicit;
  if Assigned(ParentForm) then
    Popup.PopupParent := ParentForm;

  Anchor := ClientToScreen(Point(0, 0));
  Mon := Screen.MonitorFromPoint(Anchor);
  if Assigned(Mon) then
    WA := Mon.WorkareaRect
  else
    WA := Rect(0, 0, Screen.Width, Screen.Height);
  if (WA.Right <= WA.Left) or (WA.Bottom <= WA.Top) then
    WA := Rect(0, 0, Screen.Width, Screen.Height);

  SpaceAbove := Anchor.Y - WA.Top - 8;
  SpaceBelow := WA.Bottom - (Anchor.Y + Height) - 8;
  if SpaceBelow < 0 then
    SpaceBelow := 0;
  OpenUp := SpaceAbove >= Popup.MeasureRowHeight + PickerMenuPad * 2;
  if OpenUp then
    Rows := Popup.RowsThatFit(SpaceAbove)
  else
    Rows := Popup.RowsThatFit(SpaceBelow);
  Popup.PrepareOpen(Rows);
  PopupH := Rows * Popup.FRowHeight + PickerMenuPad * 2;
  PopupW := Popup.ContentWidth;
  if PopupW < Width then
    PopupW := Width;
  MaxW := WA.Right - WA.Left - 16;
  if MaxW < 80 then
    MaxW := 80;
  if PopupW > MaxW then
    PopupW := MaxW;
  if PopupW > 520 then
    PopupW := 520;

  Popup.SetBounds(Anchor.X, Anchor.Y, PopupW, PopupH);
  if Popup.Left + PopupW > WA.Right - 4 then
    Popup.Left := WA.Right - 4 - PopupW;
  if Popup.Left < WA.Left + 4 then
    Popup.Left := WA.Left + 4;
  if OpenUp then
    Popup.Top := Anchor.Y - PopupH - 4
  else
    Popup.Top := Anchor.Y + Height + 4;
  if Popup.Top < WA.Top + 2 then
    Popup.Top := WA.Top + 2;

  FFocusBefore := Screen.ActiveControl;
  FOpen := True;
  InvalidateFace;
  Popup.Show;
  if Popup.CanFocus then
    Popup.SetFocus;
end;

procedure TThemedPickerFrame.PickIndex(AIndex: Integer);
begin
  ClosePopup(True);
  if not Assigned(FItems) then Exit;
  if (AIndex < 0) or (AIndex >= FItems.Count) then Exit;
  if AIndex = FItemIndex then Exit;
  FItemIndex := AIndex;
  InvalidateFace;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TThemedPickerFrame.UserInput(Sender: TObject; Msg: Cardinal);
var
  P: TPoint;
  IsClick: Boolean;
begin
  if not PopupVisible then Exit;
  IsClick := (Msg = LM_LBUTTONDOWN) or (Msg = LM_RBUTTONDOWN) or (Msg = LM_MBUTTONDOWN) or
    (Msg = LM_LBUTTONDBLCLK) or (Msg = LM_RBUTTONDBLCLK) or (Msg = LM_MBUTTONDBLCLK);
  P := Mouse.CursorPos;
  if IsClick then begin
    if PopupScreenRect.Contains(P) then Exit;
    if PickerScreenRect.Contains(P) then
      FSuppressOpen := True;
    ClosePopup(False);
  end else if Msg = LM_MOUSEWHEEL then begin
    if not PopupScreenRect.Contains(P) then
      ClosePopup(False);
  end;
end;

procedure TThemedPickerFrame.KeyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Popup: TPickerPopupForm;
begin
  if not PopupVisible then Exit;
  Popup := TPickerPopupForm(FPopup);
  case Key of
    VK_ESCAPE:
      begin
        ClosePopup(True);
        Key := 0;
      end;
    VK_UP:
      begin
        Popup.MoveHover(-1);
        Key := 0;
      end;
    VK_DOWN:
      begin
        Popup.MoveHover(1);
        Key := 0;
      end;
    VK_RETURN, VK_SPACE:
      begin
        Popup.AcceptHover;
        Key := 0;
      end;
  end;
end;

procedure TThemedPickerFrame.AppDeactivated(Sender: TObject);
begin
  if PopupVisible then
    ClosePopup(False);
end;

procedure TThemedPickerFrame.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  if PopupVisible and ((ALeft <> Left) or (ATop <> Top) or (AWidth <> Width) or
     (AHeight <> Height)) then
    ClosePopup(False);
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TThemedPickerFrame.SetEnabled(Value: Boolean);
begin
  inherited SetEnabled(Value);
  if not Value then
    ClosePopup(False);
  InvalidateFace;
end;

procedure TThemedPickerFrame.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled or PopupVisible then Exit;
  if Key in [VK_SPACE, VK_RETURN, VK_DOWN, VK_UP] then begin
    OpenPopup;
    Key := 0;
  end;
end;

procedure TThemedPickerFrame.PbFacePaint(Sender: TObject);
var
  P: TThemePalette;
  R: TRect;
  Fill, BorderCol, TextCol: TColor;
  CapText: string;
  TextTop, ChevronX, Rad: Integer;
begin
  if not Assigned(pbFace) then Exit;
  P := ThemePalette(FTheme);
  if Assigned(Parent) then
    pbFace.Canvas.Brush.Color := Parent.Color
  else
    pbFace.Canvas.Brush.Color := P.Surface;
  pbFace.Canvas.FillRect(pbFace.ClientRect);

  R := pbFace.ClientRect;
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  Dec(R.Right);
  Dec(R.Bottom);
  Rad := ThemedButtonCornerRadius(Self);

  if not Enabled then begin
    Fill := P.SurfaceAlt;
    TextCol := P.TextMuted;
    BorderCol := P.Border;
  end else begin
    if FPressed or FHover or FOpen then begin
      if FTheme = tkDark then
        Fill := P.Border
      else
        Fill := P.HeaderBg;
    end else
      Fill := P.SurfaceAlt;
    if (not Assigned(FItems)) or (FItemIndex < 0) or (FItems.Count = 0) then
      TextCol := P.TextMuted
    else
      TextCol := P.Text;
    if FOpen then
      BorderCol := P.Accent
    else if FHover then
      BorderCol := P.BorderStrong
    else
      BorderCol := P.Border;
  end;

  pbFace.Canvas.Brush.Color := Fill;
  pbFace.Canvas.Pen.Color := Fill;
  pbFace.Canvas.Pen.Width := 1;
  pbFace.Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
  pbFace.Canvas.Brush.Style := bsClear;
  pbFace.Canvas.Pen.Color := BorderCol;
  pbFace.Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
  pbFace.Canvas.Brush.Style := bsSolid;

  CapText := CurrentCaption;
  pbFace.Canvas.Font.Name := 'Segoe UI';
  pbFace.Canvas.Font.Size := ThemedButtonFontSize(Self);
  pbFace.Canvas.Font.Style := [];
  pbFace.Canvas.Font.Color := TextCol;
  ChevronX := R.Right - ScaledThemedTabMetric(Self, 14);
  CapText := Ellipsize(pbFace.Canvas, CapText, ChevronX - R.Left - ScaledThemedTabMetric(Self, 16));
  TextTop := R.Top + ((R.Bottom - R.Top - pbFace.Canvas.TextHeight('Ag')) div 2);
  pbFace.Canvas.TextOut(R.Left + ScaledThemedTabMetric(Self, 10), TextTop, CapText);
  if Enabled then
    DrawChevron(pbFace.Canvas, ChevronX, (R.Top + R.Bottom) div 2, not FOpen, TextCol);
end;

procedure TThemedPickerFrame.PbFaceMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (Button <> mbLeft) or not Enabled then Exit;
  FPressed := True;
  InvalidateFace;
  if FSuppressOpen then begin
    FSuppressOpen := False;
    FPressed := False;
    InvalidateFace;
    Exit;
  end;
  if not PopupVisible then
    OpenPopup;
end;

procedure TThemedPickerFrame.PbFaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not Enabled then Exit;
  if not FHover then begin
    FHover := True;
    InvalidateFace;
  end;
end;

procedure TThemedPickerFrame.PbFaceMouseLeave(Sender: TObject);
begin
  if FHover or FPressed then begin
    FHover := False;
    FPressed := False;
    InvalidateFace;
  end;
end;

procedure TThemedPickerFrame.PbFaceMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  if FPressed then begin
    FPressed := False;
    InvalidateFace;
  end;
end;

end.
