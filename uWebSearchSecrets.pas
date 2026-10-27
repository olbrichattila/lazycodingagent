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
  , uAppDatabase, uRepositoryInterfaces, uGlobalConfigLegacy;

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

function GetWebSearchApiKeyFromDb(const AConnectionId: string): string;
var
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
begin
  Result := '';
  if Trim(AConnectionId) = '' then Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.LoadConnections(Rows);
  for I := 0 to High(Rows) do
    if SameText(Rows[I].Id, AConnectionId) then
      Exit(Rows[I].ApiKey);
end;

procedure SetWebSearchApiKeyInDb(const AConnectionId, AApiKey: string);
var
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
  Found: Boolean;
begin
  if Trim(AConnectionId) = '' then Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.LoadConnections(Rows);
  Found := False;
  for I := 0 to High(Rows) do
    if SameText(Rows[I].Id, AConnectionId) then
    begin
      Rows[I].ApiKey := AApiKey;
      Found := True;
      Break;
    end;
  if not Found then
  begin
    I := Length(Rows);
    SetLength(Rows, I + 1);
    Rows[I].Id := AConnectionId;
    Rows[I].Name := 'Connection';
    Rows[I].Provider := 'brave';
    Rows[I].Enabled := True;
    Rows[I].Priority := I + 1;
    Rows[I].TimeoutMs := 10000;
    Rows[I].ApiKey := AApiKey;
  end;
  Repo.SaveConnections(Rows);
end;

function GetWebSearchApiKey(const AConnectionId: string): string;
var
  I: TIniFile;
  Path: string;
begin
  Result := '';
  if Trim(AConnectionId) = '' then Exit;
  if not GlobalConfigUseLegacyStorage then
    Exit(GetWebSearchApiKeyFromDb(AConnectionId));
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
  if not GlobalConfigUseLegacyStorage then
  begin
    SetWebSearchApiKeyInDb(AConnectionId, AApiKey);
    Exit;
  end;
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
