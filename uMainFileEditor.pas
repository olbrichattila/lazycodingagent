unit uMainFileEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Dialogs, LCLType,
  SynEdit, SynEditTypes, SynHighlighterAny,
  uAppTypes, uTheme, uSyntaxScheme, uSynGenericClike;

type
  TMainFileEditor = class
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
    constructor Create(AEditor: TSynEdit; AOwner: TComponent);
    destructor Destroy; override;
    function LoadFile(const APath: string): Boolean;
    function SaveFile: Boolean;
    function PromptSaveIfModified: Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplySyntaxScheme(const AScheme: TSyntaxScheme);
    procedure Clear;
    property FilePath: string read FFilePath;
    property Modified: Boolean read FModified;
    property Editor: TSynEdit read FEditor;
  end;

implementation

constructor TMainFileEditor.Create(AEditor: TSynEdit; AOwner: TComponent);
begin
  inherited Create;
  FEditor := AEditor;
  FTheme := tkDark;
  FScheme := DefaultGenericClikeScheme;
  FModified := False;
  FFilePath := '';

  FHighlighter := CreateGenericClikeHighlighter(AOwner);
  if Assigned(FEditor) then begin
    FEditor.Highlighter := FHighlighter;
    FEditor.OnChange := @EditorChange;
    FEditor.OnKeyDown := @EditorKeyDown;
    FEditor.Options := FEditor.Options + [eoScrollPastEol, eoTabsToSpaces];
    FEditor.TabWidth := 2;
    if FEditor.Font.Name = '' then
      FEditor.Font.Name := 'Consolas';
    if FEditor.Font.Size = 0 then
      FEditor.Font.Size := ScaledEditorFontSize(FEditor);
  end;
end;

destructor TMainFileEditor.Destroy;
begin
  FHighlighter.Free;
  inherited Destroy;
end;

procedure TMainFileEditor.EditorChange(Sender: TObject);
begin
  if not FModified then
    FModified := True;
end;

procedure TMainFileEditor.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('S')) and (ssCtrl in Shift) then begin
    Key := 0;
    SaveFile;
  end;
end;

function TMainFileEditor.LoadFile(const APath: string): Boolean;
begin
  FFilePath := ExpandFileName(APath);
  if not FileExists(FFilePath) then
    Exit(False);
  FEditor.Lines.LoadFromFile(FFilePath);
  FModified := False;
  Result := True;
end;

function TMainFileEditor.SaveFile: Boolean;
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

function TMainFileEditor.PromptSaveIfModified: Boolean;
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

procedure TMainFileEditor.Clear;
begin
  FFilePath := '';
  FModified := False;
  if Assigned(FEditor) then
    FEditor.Clear;
end;

procedure TMainFileEditor.ApplySyntaxScheme(const AScheme: TSyntaxScheme);
begin
  FScheme := AScheme;
  ApplySchemeToSynAnyHighlighter(FHighlighter, FScheme);
  if Assigned(FEditor) then
    FEditor.Invalidate;
end;

procedure TMainFileEditor.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  if Assigned(FEditor) then begin
    FEditor.Color := P.SurfaceAlt;
    FEditor.Font.Color := P.Text;
    FEditor.Font.Size := ScaledEditorFontSize(FEditor);
    ApplyPlatformScrollableTheme(FEditor, ATheme);
  end;
  ApplySyntaxScheme(FScheme);
end;

end.
