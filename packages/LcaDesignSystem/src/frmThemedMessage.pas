unit frmThemedMessage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, LCLType,
  LcaTheme,
  LcaPaintButton;

type
  TThemedMessageForm = class(TForm)
    lblMessage: TLabel;
    pnlFooter: TPanel;
    btnFirst: TLcaPaintButton;
    btnSecond: TLcaPaintButton;
    btnThird: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnFirstClick(Sender: TObject);
    procedure btnSecondClick(Sender: TObject);
    procedure btnThirdClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    FModalResultCode: Integer;
    procedure ApplyDialogTheme;
    procedure LayoutFooterButtons;
  public
    function Execute(const ACaption, AText: string; DlgType: TMsgDlgType;
      Buttons: TMsgDlgButtons; ATheme: TThemeKind): Integer;
  end;

implementation

{$R *.lfm}

procedure TThemedMessageForm.FormCreate(Sender: TObject);
begin
  FTheme := tkDark;
  FModalResultCode := mrCancel;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  btnFirst.OnClick := @btnFirstClick;
  btnSecond.OnClick := @btnSecondClick;
  btnThird.OnClick := @btnThirdClick;
end;

procedure TThemedMessageForm.ApplyDialogTheme;
var
  P: TThemePalette;
begin
  P := ThemePalette(FTheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  lblMessage.Font.Color := P.Text;
  pnlFooter.Color := P.Surface;
  ApplyThemedForm(Self, FTheme);
end;

procedure TThemedMessageForm.LayoutFooterButtons;
begin
  btnThird.Visible := False;
  btnSecond.Visible := False;
  btnFirst.Visible := True;
  btnFirst.Left := pnlFooter.ClientWidth - btnFirst.Width - 16;
  btnSecond.Left := btnFirst.Left - btnSecond.Width - 8;
  btnThird.Left := 16;
end;

function TThemedMessageForm.Execute(const ACaption, AText: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; ATheme: TThemeKind): Integer;
begin
  FTheme := ATheme;
  Caption := ACaption;
  lblMessage.Caption := AText;
  FModalResultCode := mrCancel;

  btnFirst.Visible := False;
  btnSecond.Visible := False;
  btnThird.Visible := False;

  if Buttons = [mbOK] then begin
    btnFirst.Caption := 'OK';
    btnFirst.ButtonRole := tbrPrimary;
    btnFirst.Visible := True;
    FModalResultCode := mrOK;
  end else if Buttons = [mbYes, mbNo] then begin
    btnFirst.Caption := 'Yes';
    btnFirst.ButtonRole := tbrPrimary;
    btnFirst.Visible := True;
    btnSecond.Caption := 'No';
    btnSecond.ButtonRole := tbrCancel;
    btnSecond.Visible := True;
    FModalResultCode := mrYes;
  end else if Buttons = [mbYes, mbNo, mbCancel] then begin
    btnFirst.Caption := 'Yes';
    btnFirst.ButtonRole := tbrPrimary;
    btnFirst.Visible := True;
    btnSecond.Caption := 'No';
    btnSecond.ButtonRole := tbrCancel;
    btnSecond.Visible := True;
    btnThird.Caption := 'Cancel';
    btnThird.ButtonRole := tbrCancel;
    btnThird.Visible := True;
    FModalResultCode := mrYes;
  end else begin
    btnFirst.Caption := 'OK';
    btnFirst.ButtonRole := tbrPrimary;
    btnFirst.Visible := True;
    FModalResultCode := mrOK;
  end;

  LayoutFooterButtons;
  ApplyDialogTheme;
  Result := ShowModal;
  if Result = mrNone then
    Result := FModalResultCode;
end;

procedure TThemedMessageForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    if btnThird.Visible then
      ModalResult := mrCancel
    else if btnSecond.Visible then
      ModalResult := mrNo
    else
      ModalResult := mrCancel;
  end;
end;

procedure TThemedMessageForm.btnFirstClick(Sender: TObject);
begin
  if SameText(btnFirst.Caption, 'Yes') then
    ModalResult := mrYes
  else
    ModalResult := mrOK;
end;

procedure TThemedMessageForm.btnSecondClick(Sender: TObject);
begin
  if SameText(btnSecond.Caption, 'No') then
    ModalResult := mrNo
  else
    ModalResult := mrCancel;
end;

procedure TThemedMessageForm.btnThirdClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
