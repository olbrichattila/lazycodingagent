unit frmNewWorkspace;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, FileUtil,
  uAppTypes, uTheme, uWorkspaceRegistry;

type
  TNewWorkspaceForm = class(TForm)
    lblDisplayName: TLabel;
    edtDisplayName: TEdit;
    lblFolder: TLabel;
    edtFolder: TEdit;
    btnBrowse: TButton;
    pnlBottom: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormShow(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    FRegistry: TWorkspaceRegistry;
    procedure ApplyTheme(ATheme: TThemeKind);
    function ResolveFolderPath: string;
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      ARegistry: TWorkspaceRegistry; out ADisplayName, AFolderPath: string): Boolean;
  end;

implementation

{$R *.lfm}

class function TNewWorkspaceForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  ARegistry: TWorkspaceRegistry; out ADisplayName, AFolderPath: string): Boolean;
var
  Dlg: TNewWorkspaceForm;
begin
  Dlg := TNewWorkspaceForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FRegistry := ARegistry;
    Dlg.ApplyTheme(ATheme);
    Result := Dlg.ShowModal = mrOk;
    if Result then begin
      ADisplayName := Trim(Dlg.edtDisplayName.Text);
      AFolderPath := Dlg.ResolveFolderPath;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TNewWorkspaceForm.FormShow(Sender: TObject);
begin
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TNewWorkspaceForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlBottom.Color := P.Surface;
  ApplyControlTheme(Self, ATheme);
  edtDisplayName.Color := P.SurfaceAlt;
  edtDisplayName.Font.Color := P.Text;
  edtFolder.Color := P.SurfaceAlt;
  edtFolder.Font.Color := P.Text;
  StyleCancelButton(btnBrowse, ATheme);
  StylePrimaryButton(btnOK, ATheme);
  StyleCancelButton(btnCancel, ATheme);
  ApplyPlatformChrome(Self, ATheme);
end;

function TNewWorkspaceForm.ResolveFolderPath: string;
var
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(edtFolder.Text);
  if (Norm <> '') and not DirectoryExists(Norm) then begin
    if not ForceDirectories(Norm) then
      Norm := '';
  end;
  Result := Norm;
end;

procedure TNewWorkspaceForm.btnBrowseClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtFolder.Text;
  if Dir = '' then
    Dir := GetUserDir;
  if SelectDirectory('Select workspace folder', '', Dir) then begin
    edtFolder.Text := Dir;
    if Trim(edtDisplayName.Text) = '' then
      edtDisplayName.Text := ExtractFileName(ExcludeTrailingPathDelimiter(Dir));
  end;
end;

procedure TNewWorkspaceForm.btnOKClick(Sender: TObject);
var
  Path: string;
  Entry: TWorkspaceEntry;
begin
  Path := ResolveFolderPath;
  if Path = '' then begin
    ShowMessage('Choose a valid project folder.');
    Exit;
  end;
  if not DirectoryExists(Path) then begin
    ShowMessage('Project folder does not exist.');
    Exit;
  end;
  if Assigned(FRegistry) and FRegistry.FindByPath(Path, Entry) then begin
    if MessageDlg('A workspace already uses this folder. Switch to it instead?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;
  ModalResult := mrOk;
end;

procedure TNewWorkspaceForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
