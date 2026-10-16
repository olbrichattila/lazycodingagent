unit LcaFormChrome;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, LCLType, LCLIntf, LCLProc, LMessages, Types;

type
  TLcaFormChrome = class(TComponent)
  private
    FForm: TCustomForm;
    FOldWindowProc: TWndMethod;
    FBorderlessApplied: Boolean;
    procedure WndProc(var Message: TLMessage);
    function ResizeHitTest(const P: TPoint): PtrInt;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Attach(AForm: TCustomForm);
    procedure ApplyFrameless;
    class procedure BeginMove(AForm: TCustomForm); static;
  end;

function AttachLcaFormChrome(AForm: TCustomForm): TLcaFormChrome;

implementation

uses
  Math
  {$IFDEF WINDOWS}, Windows{$ENDIF}
  ;

const
  {$IFDEF WINDOWS}
  HTCLIENT = 1;
  HTLEFT = 10;
  HTRIGHT = 11;
  HTTOP = 12;
  HTTOPLEFT = 13;
  HTTOPRIGHT = 14;
  HTBOTTOM = 15;
  HTBOTTOMLEFT = 16;
  HTBOTTOMRIGHT = 17;
  {$ENDIF}

function EdgeSize(AForm: TCustomForm): Integer;
begin
  Result := MulDiv(8, AForm.PixelsPerInch, 96);
  if Result < 4 then
    Result := 4;
end;

constructor TLcaFormChrome.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBorderlessApplied := False;
end;

destructor TLcaFormChrome.Destroy;
begin
  if Assigned(FForm) and Assigned(FOldWindowProc) then
    FForm.WindowProc := FOldWindowProc;
  inherited Destroy;
end;

procedure TLcaFormChrome.Attach(AForm: TCustomForm);
begin
  if FForm = AForm then Exit;
  if Assigned(FForm) and Assigned(FOldWindowProc) then
    FForm.WindowProc := FOldWindowProc;
  FForm := AForm;
  if FForm = nil then Exit;
  FOldWindowProc := FForm.WindowProc;
  FForm.WindowProc := @WndProc;
  ApplyFrameless;
end;

procedure TLcaFormChrome.ApplyFrameless;
begin
  if FForm = nil then Exit;
  FForm.BorderStyle := bsNone;
  FForm.BorderIcons := [];
  FBorderlessApplied := True;
end;

class procedure TLcaFormChrome.BeginMove(AForm: TCustomForm);
begin
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  {$IFDEF WINDOWS}
  ReleaseCapture;
  SendMessage(AForm.Handle, WM_SYSCOMMAND, SC_MOVE or $0002, 0);
  {$ELSE}
  if AForm is TForm then
    TForm(AForm).BeginDrag(False);
  {$ENDIF}
end;

function TLcaFormChrome.ResizeHitTest(const P: TPoint): PtrInt;
var
  E: Integer;
  W, H: Integer;
begin
  {$IFDEF WINDOWS}
  Result := HTCLIENT;
  if FForm = nil then Exit;
  W := FForm.ClientWidth;
  H := FForm.ClientHeight;
  E := EdgeSize(FForm);
  if P.Y < E then begin
    if P.X < E then Exit(HTTOPLEFT);
    if P.X >= W - E then Exit(HTTOPRIGHT);
    Exit(HTTOP);
  end;
  if P.Y >= H - E then begin
    if P.X < E then Exit(HTBOTTOMLEFT);
    if P.X >= W - E then Exit(HTBOTTOMRIGHT);
    Exit(HTBOTTOM);
  end;
  if P.X < E then Exit(HTLEFT);
  if P.X >= W - E then Exit(HTRIGHT);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

procedure TLcaFormChrome.WndProc(var Message: TLMessage);
var
  P: TPoint;
  Hit: PtrInt;
begin
  if FBorderlessApplied and Assigned(FForm) then begin
    {$IFDEF WINDOWS}
    case Message.Msg of
      WM_NCHITTEST:
        begin
          P.X := LongInt(SmallInt(LoWord(LongInt(Message.LParam))));
          P.Y := LongInt(SmallInt(HiWord(LongInt(Message.LParam))));
          P := FForm.ScreenToClient(P);
          if (P.X >= 0) and (P.Y >= 0) and (P.X < FForm.ClientWidth) and
            (P.Y < FForm.ClientHeight) then
          begin
            Hit := ResizeHitTest(P);
            if Hit <> HTCLIENT then begin
              Message.Result := Hit;
              Exit;
            end;
          end;
        end;
    end;
    {$ENDIF}
  end;
  FOldWindowProc(Message);
end;

function AttachLcaFormChrome(AForm: TCustomForm): TLcaFormChrome;
var
  Chrome: TLcaFormChrome;
begin
  Chrome := TLcaFormChrome.Create(AForm);
  Chrome.Attach(AForm);
  Result := Chrome;
end;

end.
