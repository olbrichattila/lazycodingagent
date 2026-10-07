unit uFileEditorTab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, Dialogs, LCLType,
  SynEdit, SynEditTypes, SynHighlighterAny,
  uAppTypes, uTheme, uSyntaxScheme, uSynGenericClike;

type
  TFileEditorTab = class(TPanel)
  private
    FEditor: TSynEdit;
    FHighlighter: TSynAnySyn;
    FFilePath: string;
    FModified: Boolean;
    FTheme: TThemeKind;
    FScheme: TSyntaxScheme;
    procedure EditorChange(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
    function LoadFile(const APath: string): Boolean;
    function SaveFile: Boolean;
    function PromptSaveIfModified: Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplySyntaxScheme(const AScheme: TSyntaxScheme);
    property FilePath: string read FFilePath;
    property Modified: Boolean read FModified;
    property Editor: TSynEdit read FEditor;
  end;

implementation

constructor TFileEditorTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FTheme := tkDark;
  FScheme := DefaultGenericClikeScheme;
  FModified := False;

  FHighlighter := CreateGenericClikeHighlighter(Self);

  FEditor := TSynEdit.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alClient;
  FEditor.BorderStyle := bsNone;
  FEditor.Gutter.Visible := False;
  FEditor.Options := FEditor.Options + [eoScrollPastEol, eoTabsToSpaces];
  FEditor.TabWidth := 2;
  FEditor.Font.Name := 'Consolas';
  FEditor.Font.Size := 10;
  FEditor.Highlighter := FHighlighter;
  FEditor.OnChange := @EditorChange;
  FEditor.OnKeyDown := @EditorKeyDown;
end;

procedure TFileEditorTab.EditorChange(Sender: TObject);
begin
  if not FModified then
    FModified := True;
end;

procedure TFileEditorTab.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('S')) and (ssCtrl in Shift) then begin
    Key := 0;
    SaveFile;
  end;
end;

function TFileEditorTab.LoadFile(const APath: string): Boolean;
begin
  FFilePath := ExpandFileName(APath);
  if not FileExists(FFilePath) then
    Exit(False);
  FEditor.Lines.LoadFromFile(FFilePath);
  FModified := False;
  Result := True;
end;

function TFileEditorTab.SaveFile: Boolean;
begin
  if FFilePath = '' then
    Exit(False);
  try
    FEditor.Lines.SaveToFile(FFilePath);
    FModified := False;
    Result := True;
  except
    on E: Exception do begin
      MessageDlg('Could not save file: ' + E.Message, mtError, [mbOK], 0);
      Result := False;
    end;
  end;
end;

function TFileEditorTab.PromptSaveIfModified: Boolean;
var
  R: Integer;
begin
  if not FModified then
    Exit(True);
  R := MessageDlg(Format('Save changes to %s?', [ExtractFileName(FFilePath)]),
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if R = mrCancel then
    Exit(False);
  if R = mrYes then
    Exit(SaveFile);
  Result := True;
end;

procedure TFileEditorTab.ApplySyntaxScheme(const AScheme: TSyntaxScheme);
begin
  FScheme := AScheme;
  ApplySchemeToSynAnyHighlighter(FHighlighter, FScheme);
  FEditor.Invalidate;
end;

procedure TFileEditorTab.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Surface;
  FEditor.Color := P.SurfaceAlt;
  FEditor.Font.Color := P.Text;
  ApplySyntaxScheme(FScheme);
  ApplyPlatformScrollableTheme(FEditor, ATheme);
end;

end.
