unit uWebSearchSecrets;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function WebSearchSecretsIniPath: string;
function GetWebSearchApiKey(const AConnectionId: string): string;
procedure SetWebSearchApiKey(const AConnectionId, AApiKey: string);
procedure ClearWebSearchApiKey(const AConnectionId: string);
function WebSearchApiKeyIsSet(const AConnectionId: string): Boolean;
procedure SetWebSearchSecretsIniPathForTests(const APath: string);
procedure ClearWebSearchSecretsIniPathForTests;

implementation

uses
  IniFiles
  {$IFDEF LCL}
  , Forms
  {$ENDIF}
  ;

var
  GTestSecretsIniPath: string = '';

procedure SetWebSearchSecretsIniPathForTests(const APath: string);
begin
  GTestSecretsIniPath := APath;
end;

procedure ClearWebSearchSecretsIniPathForTests;
begin
  GTestSecretsIniPath := '';
end;

function WebSearchSecretsIniPath: string;
begin
  if GTestSecretsIniPath <> '' then
    Exit(GTestSecretsIniPath);
  {$IFDEF LCL}
  if Assigned(Application) then
    Exit(GetAppConfigFile(False));
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
    '.config/lazycodingagent/config.ini';
end;

function SecretSectionName(const AConnectionId: string): string;
begin
  Result := 'WebSearchSecret_' + AConnectionId;
end;

function GetWebSearchApiKey(const AConnectionId: string): string;
var
  I: TIniFile;
  Path: string;
begin
  Result := '';
  if Trim(AConnectionId) = '' then Exit;
  Path := WebSearchSecretsIniPath;
  if Path = '' then Exit;
  I := TIniFile.Create(Path);
  try
    Result := I.ReadString(SecretSectionName(AConnectionId), 'ApiKey', '');
  finally
    I.Free;
  end;
end;

procedure SetWebSearchApiKey(const AConnectionId, AApiKey: string);
var
  I: TIniFile;
  Path, Dir: string;
begin
  if Trim(AConnectionId) = '' then Exit;
  Path := WebSearchSecretsIniPath;
  if Path = '' then Exit;
  Dir := ExtractFilePath(Path);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  I := TIniFile.Create(Path);
  try
    if Trim(AApiKey) = '' then
      I.DeleteKey(SecretSectionName(AConnectionId), 'ApiKey')
    else
      I.WriteString(SecretSectionName(AConnectionId), 'ApiKey', AApiKey);
  finally
    I.Free;
  end;
end;

procedure ClearWebSearchApiKey(const AConnectionId: string);
begin
  SetWebSearchApiKey(AConnectionId, '');
end;

function WebSearchApiKeyIsSet(const AConnectionId: string): Boolean;
begin
  Result := Trim(GetWebSearchApiKey(AConnectionId)) <> '';
end;

end.
