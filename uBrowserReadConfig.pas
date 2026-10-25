unit uBrowserReadConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uBrowserReadTypes;

function LoadBrowserReadConfig: TBrowserReadConfig;
procedure SaveBrowserReadExecutablePath(const APath: string);

function BrowserReadTestLocalAllowed: Boolean;

implementation

uses
  IniFiles
  {$IFDEF LCL}
  , Forms
  {$ENDIF}
  ;

function BrowserReadIniPath: string;
begin
  {$IFDEF LCL}
  if Assigned(Application) then
    Exit(GetAppConfigFile(False));
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
    '.config/lazycodingagent/config.ini';
end;

function LoadBrowserReadConfig: TBrowserReadConfig;
var
  I: TIniFile;
  Path: string;
begin
  Result := DefaultBrowserReadConfig;
  Result.AllowLocalhost := BrowserReadTestLocalAllowed;
  Path := BrowserReadIniPath;
  if Path = '' then Exit;
  I := TIniFile.Create(Path);
  try
    Result.ExecutablePath := Trim(I.ReadString('BrowserRead', 'ExecutablePath', ''));
    Result.MaxConcurrent := I.ReadInteger('BrowserRead', 'MaxConcurrent',
      BROWSER_READ_DEFAULT_MAX_CONCURRENT);
    if Result.MaxConcurrent < 1 then
      Result.MaxConcurrent := 1;
    if Result.MaxConcurrent > 4 then
      Result.MaxConcurrent := 4;
  finally
    I.Free;
  end;
end;

procedure SaveBrowserReadExecutablePath(const APath: string);
var
  I: TIniFile;
  Path: string;
  Dir: string;
begin
  Path := BrowserReadIniPath;
  if Path = '' then Exit;
  Dir := ExtractFilePath(Path);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  I := TIniFile.Create(Path);
  try
    I.WriteString('BrowserRead', 'ExecutablePath', Trim(APath));
  finally
    I.Free;
  end;
end;

function BrowserReadTestLocalAllowed: Boolean;
begin
  Result := SameText(GetEnvironmentVariable('LCA_BROWSER_READ_TEST_LOCAL'), '1');
end;

end.
