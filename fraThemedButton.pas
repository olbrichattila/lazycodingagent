unit fraThemedButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Graphics, ExtCtrls, StdCtrls, LCLType, uAppTypes, uTheme;

type
  { TThemedButtonFrame — designer TFrame with painted face (Qt/Linux-safe) }
  TThemedButtonFrame = class(TFrame)
    pbFace: TPaintBox;
    procedure PbFacePaint(Sender: TObject);
    procedure PbFaceMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure PbFaceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure PbFaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PbFaceMouseLeave(Sender: TObject);
  private
    FCaption: string;
    FRole: TThemedButtonRole;
    FTheme: TThemeKind;
    FHover: Boolean;
    FPressed: Boolean;
    FModalResult: TModalResult;
    FDefault: Boolean;
    FCancel: Boolean;
    procedure SetCaption(const AValue: string);
    procedure SetModalResult(AValue: TModalResult);
    procedure SetRole(AValue: TThemedButtonRole);
    procedure InvalidateFace;
    procedure EnsurePbFace;
    procedure DoButtonClick;
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    function CanFocus: Boolean; override;
    function PreferredWidth: Integer;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property Caption: string read FCaption write SetCaption;
    property ButtonRole: TThemedButtonRole read FRole write SetRole default tbrPrimary;
    property ModalResult: TModalResult read FModalResult write SetModalResult default mrNone;
    property Default: Boolean read FDefault write FDefault default False;
    property Cancel: Boolean read FCancel write FCancel default False;
    property OnClick;
    property Align;
    property Anchors;
    property Height default 28;
    property Left;
    property TabOrder;
    property Top;
    property Visible;
    property Width;
  end;

function EnsureThemedButton(APlaceholder: TButton; ARole: TThemedButtonRole): TThemedButtonFrame;

procedure StylePrimaryButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind); overload;
procedure StyleCancelButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind); overload;
procedure StyleDestructiveButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind); overload;
procedure StylePrimaryButton(APlaceholder: TButton; ATheme: TThemeKind); overload;
procedure StyleCancelButton(APlaceholder: TButton; ATheme: TThemeKind); overload;
procedure StyleDestructiveButton(APlaceholder: TButton; ATheme: TThemeKind); overload;

implementation

uses
  SysUtils;

{$R *.lfm}

function ThemedButtonCompanionName(const APlaceholderName: string): string;
begin
  Result := APlaceholderName + 'Themed';
end;

function EnsureThemedButton(APlaceholder: TButton; ARole: TThemedButtonRole): TThemedButtonFrame;
var
  C: TComponent;
  F: TThemedButtonFrame;
  CompName: string;
begin
  if not Assigned(APlaceholder) then
    Exit(nil);
  CompName := ThemedButtonCompanionName(APlaceholder.Name);
  C := APlaceholder.Owner.FindComponent(CompName);
  if (C <> nil) and (C is TThemedButtonFrame) then
    Exit(TThemedButtonFrame(C));
  F := TThemedButtonFrame.Create(APlaceholder.Owner);
  F.Name := CompName;
  F.Parent := APlaceholder.Parent;
  F.SetBounds(APlaceholder.Left, APlaceholder.Top, APlaceholder.Width, APlaceholder.Height);
  F.Anchors := APlaceholder.Anchors;
  F.Align := APlaceholder.Align;
  F.Caption := APlaceholder.Caption;
  F.TabOrder := APlaceholder.TabOrder;
  F.Visible := APlaceholder.Visible;
  F.Enabled := APlaceholder.Enabled;
  F.Default := APlaceholder.Default;
  F.Cancel := APlaceholder.Cancel;
  F.ModalResult := APlaceholder.ModalResult;
  F.OnClick := APlaceholder.OnClick;
  F.ButtonRole := ARole;
  if F.Width < F.PreferredWidth then
    F.Width := F.PreferredWidth;
  if F.Height < ScaledThemedButtonHeight(F) then
    F.Height := ScaledThemedButtonHeight(F);
  APlaceholder.Visible := False;
  APlaceholder.Enabled := False;
  Result := F;
end;

procedure ApplyThemedButtonFrameTheme(AControl: TControl; ATheme: TThemeKind);
begin
  if AControl is TThemedButtonFrame then
    TThemedButtonFrame(AControl).ApplyTheme(ATheme);
end;

procedure StylePrimaryButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  ABtn.ButtonRole := tbrPrimary;
  ABtn.ApplyTheme(ATheme);
end;

procedure StyleCancelButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  ABtn.ButtonRole := tbrCancel;
  ABtn.ApplyTheme(ATheme);
end;

procedure StyleDestructiveButton(ABtn: TThemedButtonFrame; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  ABtn.ButtonRole := tbrDestructive;
  ABtn.ApplyTheme(ATheme);
end;

procedure StylePrimaryButton(APlaceholder: TButton; ATheme: TThemeKind);
begin
  StylePrimaryButton(EnsureThemedButton(APlaceholder, tbrPrimary), ATheme);
end;

procedure StyleCancelButton(APlaceholder: TButton; ATheme: TThemeKind);
begin
  StyleCancelButton(EnsureThemedButton(APlaceholder, tbrCancel), ATheme);
end;

procedure StyleDestructiveButton(APlaceholder: TButton; ATheme: TThemeKind);
begin
  StyleDestructiveButton(EnsureThemedButton(APlaceholder, tbrDestructive), ATheme);
end;

{ TThemedButtonFrame }

constructor TThemedButtonFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  FCaption := 'Button';
  FRole := tbrPrimary;
  FTheme := tkDark;
  FHover := False;
  FPressed := False;
  FModalResult := mrNone;
  Cursor := crHandPoint;
  EnsurePbFace;
end;

procedure TThemedButtonFrame.EnsurePbFace;
begin
  if Assigned(pbFace) then begin
    pbFace.Align := alClient;
    Exit;
  end;
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

procedure TThemedButtonFrame.Loaded;
begin
  inherited Loaded;
  EnsurePbFace;
  if Trim(FCaption) = '' then
    FCaption := 'Button';
  InvalidateFace;
end;

procedure TThemedButtonFrame.Resize;
begin
  inherited Resize;
  if Assigned(pbFace) then
    pbFace.SetBounds(0, 0, ClientWidth, ClientHeight);
  InvalidateFace;
end;

procedure TThemedButtonFrame.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
  if Assigned(pbFace) then
    pbFace.SetBounds(0, 0, ClientWidth, ClientHeight);
end;

function TThemedButtonFrame.PreferredWidth: Integer;
begin
  Result := MeasureThemedButtonWidth(Self, FCaption, FRole, 0);
end;

function TThemedButtonFrame.CanFocus: Boolean;
begin
  Result := Enabled and inherited CanFocus;
end;

procedure TThemedButtonFrame.SetModalResult(AValue: TModalResult);
begin
  FModalResult := AValue;
end;

procedure TThemedButtonFrame.SetCaption(const AValue: string);
var
  NeedW: Integer;
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  NeedW := PreferredWidth;
  if (Width > 0) and (Width < NeedW) then
    Width := NeedW;
  InvalidateFace;
end;

procedure TThemedButtonFrame.SetRole(AValue: TThemedButtonRole);
begin
  if FRole = AValue then Exit;
  FRole := AValue;
  InvalidateFace;
end;

procedure TThemedButtonFrame.InvalidateFace;
begin
  if Assigned(pbFace) then
    pbFace.Invalidate;
end;

procedure TThemedButtonFrame.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  InvalidateFace;
end;

procedure TThemedButtonFrame.PbFacePaint(Sender: TObject);
begin
  if not Assigned(pbFace) then Exit;
  PaintThemedButton(pbFace.Canvas, pbFace.ClientRect, FTheme, FRole, FCaption, Enabled,
    FHover, FPressed, Focused, ThemedButtonCornerRadius(Self),
    ThemedButtonFontSize(Self), ThemedButtonHorizPad(Self));
end;

procedure TThemedButtonFrame.PbFaceMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and Enabled then begin
    FPressed := True;
    MouseCapture := True;
    InvalidateFace;
  end;
end;

procedure TThemedButtonFrame.PbFaceMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not Enabled then Exit;
  if not FHover then begin
    FHover := True;
    InvalidateFace;
  end;
end;

procedure TThemedButtonFrame.PbFaceMouseLeave(Sender: TObject);
begin
  if FHover or FPressed then begin
    FHover := False;
    FPressed := False;
    InvalidateFace;
  end;
end;

procedure TThemedButtonFrame.PbFaceMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  R: TRect;
begin
  if (Button <> mbLeft) or not Enabled then Exit;
  if MouseCapture then begin
    MouseCapture := False;
    FPressed := False;
    R := pbFace.ClientRect;
    if R.Contains(Point(X, Y)) then
      DoButtonClick
    else
      InvalidateFace;
  end;
end;

procedure TThemedButtonFrame.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled then Exit;
  if Key = VK_SPACE then begin
    FPressed := True;
    InvalidateFace;
  end else if Key = VK_RETURN then begin
    DoButtonClick;
  end;
end;

procedure TThemedButtonFrame.DoButtonClick;
var
  F: TCustomForm;
begin
  FPressed := False;
  InvalidateFace;
  Click;
  if FModalResult <> mrNone then begin
    F := GetParentForm(Self);
    if F <> nil then
      F.ModalResult := FModalResult;
  end;
end;

initialization
  ThemedButtonFrameApplyTheme := @ApplyThemedButtonFrameTheme;

end.
