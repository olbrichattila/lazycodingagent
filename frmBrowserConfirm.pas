unit frmBrowserConfirm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, LcaTheme;

function ConfirmSensitiveBrowserAction(const AMessage: string; ATheme: TThemeKind;
  out AAllowForSession: Boolean): Boolean;

implementation

uses
  LcaThemedMessageBox;

function ConfirmSensitiveBrowserAction(const AMessage: string; ATheme: TThemeKind;
  out AAllowForSession: Boolean): Boolean;
var
  Dlg: TForm;
  Lbl: TLabel;
  Chk: TCheckBox;
  BtnOk, BtnCancel: TButton;
  Pnl: TPanel;
begin
  AAllowForSession := False;
  Dlg := TForm.Create(nil);
  try
    Dlg.BorderStyle := bsDialog;
    Dlg.Caption := 'Browser action';
    Dlg.Width := 420;
    Dlg.Height := 200;
    Dlg.Position := poScreenCenter;
    Pnl := TPanel.Create(Dlg);
    Pnl.Parent := Dlg;
    Pnl.Align := alClient;
    Pnl.BevelOuter := bvNone;
    Lbl := TLabel.Create(Dlg);
    Lbl.Parent := Pnl;
    Lbl.Align := alTop;
    Lbl.AutoSize := False;
    Lbl.WordWrap := True;
    Lbl.Height := 72;
    Lbl.Caption := AMessage;
    Chk := TCheckBox.Create(Dlg);
    Chk.Parent := Pnl;
    Chk.Align := alTop;
    Chk.Caption := 'Allow sensitive browser actions for this chat session';
    BtnOk := TButton.Create(Dlg);
    BtnOk.Parent := Pnl;
    BtnOk.Caption := 'OK';
    BtnOk.ModalResult := mrOk;
    BtnOk.Left := Dlg.Width - 180;
    BtnOk.Top := Dlg.Height - 64;
    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := Pnl;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Left := Dlg.Width - 90;
    BtnCancel.Top := Dlg.Height - 64;
    ApplyThemedForm(Dlg, ATheme);
    if Dlg.ShowModal = mrOk then
    begin
      AAllowForSession := Chk.Checked;
      Result := True;
    end
    else
      Result := False;
  finally
    Dlg.Free;
  end;
end;

end.
