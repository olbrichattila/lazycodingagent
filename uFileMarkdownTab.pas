unit uFileMarkdownTab;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls,
  uAppTypes, uTheme, uMarkdownView;

type
  TFileMarkdownTab = class(TPanel)
  private
    FMarkdown: TMarkdownView;
    FFilePath: string;
  public
    constructor Create(AOwner: TComponent); override;
    function LoadFile(const APath: string): Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    property FilePath: string read FFilePath;
  end;

implementation

function TFileMarkdownTab.LoadFile(const APath: string): Boolean;
var
  SL: TStringList;
begin
  FFilePath := ExpandFileName(APath);
  if not FileExists(FFilePath) then
    Exit(False);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FFilePath);
    FMarkdown.SetMarkdown(SL.Text);
    Result := True;
  finally
    SL.Free;
  end;
end;

constructor TFileMarkdownTab.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FMarkdown := TMarkdownView.Create(Self);
  FMarkdown.Parent := Self;
  FMarkdown.Align := alClient;
end;

procedure TFileMarkdownTab.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  Color := P.Surface;
  FMarkdown.ApplyTheme(ATheme);
end;

end.
