unit LcaThemedButtonPaint;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, LMessages, LcaTheme;

function ThemedButtonDisplayCaption(const ACaption: string): string;
procedure ApplyThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);

implementation

uses
  Graphics, LCLIntf, Forms
  {$IFDEF WINDOWS}, LcaThemeWin32Buttons{$ENDIF}
  ;

{$IFNDEF WINDOWS}

type
  TLclThemedButtonPaint = class(TComponent)
  private
    FButton: TButton;
    FTheme: TThemeKind;
    FRole: TThemedButtonRole;
    FHover: Boolean;
    FPressed: Boolean;
    FChainedWindowProc: Boolean;
    FPrevWindowProc: TWndMethod;
    FPrevOnMouseDown: TMouseEvent;
    FPrevOnMouseUp: TMouseEvent;
    FPrevOnMouseLeave: TNotifyEvent;
    FPrevOnMouseEnter: TNotifyEvent;
    procedure ButtonWindowProc(var Message: TLMessage);
    procedure HookMouseEvents;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure MouseEnter(Sender: TObject);
    procedure MouseLeave(Sender: TObject);
    procedure InvalidateButton;
    procedure PaintClient;
    function ParentBackgroundColor: TColor;
    function DisplayCaption: string;
    function IsPressed: Boolean;
  public
    constructor Create(AOwner: TButton); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
    class function FindOnButton(ABtn: TButton): TLclThemedButtonPaint;
  end;

class function TLclThemedButtonPaint.FindOnButton(ABtn: TButton): TLclThemedButtonPaint;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(ABtn) then Exit;
  for I := 0 to ABtn.ComponentCount - 1 do
    if ABtn.Components[I] is TLclThemedButtonPaint then
      Exit(TLclThemedButtonPaint(ABtn.Components[I]));
end;

constructor TLclThemedButtonPaint.Create(AOwner: TButton);
begin
  inherited Create(AOwner);
  FButton := AOwner;
  FHover := False;
  FPressed := False;
  FChainedWindowProc := False;
end;

destructor TLclThemedButtonPaint.Destroy;
begin
  if Assigned(FButton) then begin
    if FChainedWindowProc then
      FButton.WindowProc := FPrevWindowProc;
    if Assigned(FPrevOnMouseDown) then
      FButton.OnMouseDown := FPrevOnMouseDown;
    if Assigned(FPrevOnMouseUp) then
      FButton.OnMouseUp := FPrevOnMouseUp;
    if Assigned(FPrevOnMouseLeave) then
      FButton.OnMouseLeave := FPrevOnMouseLeave;
    if Assigned(FPrevOnMouseEnter) then
      FButton.OnMouseEnter := FPrevOnMouseEnter;
  end;
  inherited Destroy;
end;

procedure TLclThemedButtonPaint.InvalidateButton;
begin
  if Assigned(FButton) then
    FButton.Invalidate;
end;

function TLclThemedButtonPaint.ParentBackgroundColor: TColor;
begin
  if Assigned(FButton.Parent) then
    Result := FButton.Parent.Color
  else
    Result := clBtnFace;
end;

function TLclThemedButtonPaint.DisplayCaption: string;
begin
  Result := ThemedButtonDisplayCaption(FButton.Caption);
end;

function TLclThemedButtonPaint.IsPressed: Boolean;
begin
  Result := FPressed and FButton.Enabled;
end;

procedure TLclThemedButtonPaint.PaintClient;
var
  R: TRect;
  Canvas: TControlCanvas;
  Enabled, Focused: Boolean;
begin
  if not Assigned(FButton) then Exit;
  Canvas := TControlCanvas.Create;
  try
    Canvas.Control := FButton;
    R := FButton.ClientRect;
    Canvas.Brush.Color := ParentBackgroundColor;
    Canvas.FillRect(R);
    Enabled := FButton.Enabled;
    Focused := FButton.Focused;
    Canvas.Font.Assign(FButton.Font);
    PaintThemedButton(Canvas, R, FTheme, FRole, DisplayCaption, Enabled, FHover and Enabled,
      IsPressed, Focused, ThemedButtonCornerRadius(FButton), FButton.Font.Size, 0);
  finally
    Canvas.Free;
  end;
end;

procedure TLclThemedButtonPaint.ButtonWindowProc(var Message: TLMessage);
begin
  case Message.Msg of
    LM_ERASEBKGND:
      begin
        Message.Result := 1;
        Exit;
      end;
    LM_PAINT:
      begin
        PaintClient;
        Message.Result := 0;
        Exit;
      end;
    LM_SETFOCUS, LM_KILLFOCUS, LM_ENABLE:
      InvalidateButton;
  end;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TLclThemedButtonPaint.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FPressed := True;
    InvalidateButton;
  end;
  if Assigned(FPrevOnMouseDown) then
    FPrevOnMouseDown(Sender, Button, Shift, X, Y);
end;

procedure TLclThemedButtonPaint.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FPressed := False;
    InvalidateButton;
  end;
  if Assigned(FPrevOnMouseUp) then
    FPrevOnMouseUp(Sender, Button, Shift, X, Y);
end;

procedure TLclThemedButtonPaint.MouseEnter(Sender: TObject);
begin
  FHover := True;
  InvalidateButton;
  if Assigned(FPrevOnMouseEnter) then
    FPrevOnMouseEnter(Sender);
end;

procedure TLclThemedButtonPaint.MouseLeave(Sender: TObject);
begin
  FHover := False;
  FPressed := False;
  InvalidateButton;
  if Assigned(FPrevOnMouseLeave) then
    FPrevOnMouseLeave(Sender);
end;

procedure TLclThemedButtonPaint.HookMouseEvents;
begin
  if not Assigned(FButton) then Exit;
  FPrevOnMouseDown := FButton.OnMouseDown;
  FPrevOnMouseUp := FButton.OnMouseUp;
  FPrevOnMouseLeave := FButton.OnMouseLeave;
  FPrevOnMouseEnter := FButton.OnMouseEnter;
  FButton.OnMouseDown := @MouseDown;
  FButton.OnMouseUp := @MouseUp;
  FButton.OnMouseLeave := @MouseLeave;
  FButton.OnMouseEnter := @MouseEnter;
end;

procedure TLclThemedButtonPaint.Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  FTheme := ATheme;
  FRole := ARole;
  if not FChainedWindowProc and Assigned(FButton) then begin
    FPrevWindowProc := FButton.WindowProc;
    FButton.WindowProc := @ButtonWindowProc;
    FChainedWindowProc := True;
    HookMouseEvents;
    FButton.ControlStyle := FButton.ControlStyle + [csOpaque];
  end;
  FButton.Invalidate;
end;

procedure ApplyLclThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  Helper: TLclThemedButtonPaint;
begin
  if not Assigned(ABtn) then Exit;
  if csDesigning in ABtn.ComponentState then Exit;
  if csLoading in ABtn.ComponentState then Exit;
  if csReading in ABtn.ComponentState then Exit;
  if not ABtn.HandleAllocated then Exit;
  Helper := TLclThemedButtonPaint.FindOnButton(ABtn);
  if Helper = nil then
    Helper := TLclThemedButtonPaint.Create(ABtn);
  Helper.Apply(ATheme, ARole);
end;

{$ENDIF}

function ThemedButtonDisplayCaption(const ACaption: string): string;
var
  P: Integer;
begin
  Result := ACaption;
  P := Pos('&', Result);
  while P > 0 do begin
    if (P < Length(Result)) and (Result[P + 1] = '&') then
      Delete(Result, P, 1)
    else
      Delete(Result, P, 1);
    P := Pos('&', Result);
  end;
end;

procedure ApplyThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  if not Assigned(ABtn) then Exit;
  if csDesigning in ABtn.ComponentState then Exit;
  if csLoading in ABtn.ComponentState then Exit;
  if csReading in ABtn.ComponentState then Exit;
  {$IFDEF WINDOWS}
  ApplyWin32ThemedButtonPaint(ABtn, ATheme, ARole);
  {$ELSE}
  if not ABtn.HandleAllocated then Exit;
  ApplyLclThemedButtonPaint(ABtn, ATheme, ARole);
  {$ENDIF}
end;

end.
