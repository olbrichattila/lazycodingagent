unit uBrowserReadConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uBrowserReadTypes;

function LoadBrowserReadConfig: TBrowserReadConfig;
function LoadBrowserReadConfigFromIni: TBrowserReadConfig;
procedure SaveBrowserReadExecutablePath(const APath: string);
procedure SaveBrowserReadConfigToGlobalDb(const AConfig: TBrowserReadConfig);
procedure SetBrowserReadIniPathForTests(const APath: string);
procedure ClearBrowserReadIniPathForTests;

function BrowserReadTestLocalAllowed: Boolean;

implementation

uses
  IniFiles
  {$IFDEF LCL}
  , Forms
  {$ENDIF}
  , uAppDatabase, uGlobalConfigLegacy, uRepositoryInterfaces;

var
  GTestBrowserIniPath: string = '';

procedure SetBrowserReadIniPathForTests(const APath: string);
begin
  GTestBrowserIniPath := APath;
end;

procedure ClearBrowserReadIniPathForTests;
begin
  GTestBrowserIniPath := '';
end;

function BrowserReadIniPath: string;
begin
  if GTestBrowserIniPath <> '' then
    Exit(GTestBrowserIniPath);
  {$IFDEF LCL}
  if Assigned(Application) then
    Exit(GetAppConfigFile(False));
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
    '.config/lazycodingagent/config.ini';
end;

function LoadBrowserReadConfigFromIni: TBrowserReadConfig;
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
    Result.MaxSessions := I.ReadInteger('BrowserRead', 'MaxSessions',
      BROWSER_DEFAULT_MAX_SESSIONS);
    if Result.MaxSessions < 1 then
      Result.MaxSessions := 1;
    if Result.MaxSessions > 8 then
      Result.MaxSessions := 8;
    Result.IdleTimeoutMs := I.ReadInteger('BrowserRead', 'IdleTimeoutMs',
      BROWSER_DEFAULT_IDLE_TIMEOUT_MS);
    if Result.IdleTimeoutMs < 60000 then
      Result.IdleTimeoutMs := 60000;
  finally
    I.Free;
  end;
end;

function LoadBrowserReadConfigFromDb: TBrowserReadConfig;
var
  Repo: IBrowserReadRepository;
begin
  Result := DefaultBrowserReadConfig;
  Result.AllowLocalhost := BrowserReadTestLocalAllowed;
  Repo := TAppDatabase.GlobalBrowserRead;
  Result.ExecutablePath := Repo.LoadExecutablePath;
  Result.MaxConcurrent := Repo.LoadMaxConcurrent;
  if Result.MaxConcurrent < 1 then
    Result.MaxConcurrent := 1;
  if Result.MaxConcurrent > 4 then
    Result.MaxConcurrent := 4;
  Result.MaxSessions := Repo.LoadMaxSessions;
  if Result.MaxSessions < 1 then
    Result.MaxSessions := 1;
  if Result.MaxSessions > 8 then
    Result.MaxSessions := 8;
  Result.IdleTimeoutMs := Repo.LoadIdleTimeoutMs;
  if Result.IdleTimeoutMs < 60000 then
    Result.IdleTimeoutMs := 60000;
end;

function LoadBrowserReadConfig: TBrowserReadConfig;
begin
  if GlobalConfigUseLegacyStorage then
    Exit(LoadBrowserReadConfigFromIni);
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Result := LoadBrowserReadConfigFromDb;
end;

procedure SaveBrowserReadConfigToGlobalDb(const AConfig: TBrowserReadConfig);
var
  Repo: IBrowserReadRepository;
  MaxC, MaxS, Idle: Integer;
begin
  Repo := TAppDatabase.GlobalBrowserRead;
  Repo.SaveExecutablePath(AConfig.ExecutablePath);
  MaxC := AConfig.MaxConcurrent;
  if MaxC < 1 then MaxC := 1;
  if MaxC > 4 then MaxC := 4;
  Repo.SaveMaxConcurrent(MaxC);
  MaxS := AConfig.MaxSessions;
  if MaxS < 1 then MaxS := 1;
  if MaxS > 8 then MaxS := 8;
  Repo.SaveMaxSessions(MaxS);
  Idle := AConfig.IdleTimeoutMs;
  if Idle < 60000 then Idle := 60000;
  Repo.SaveIdleTimeoutMs(Idle);
end;

procedure SaveBrowserReadExecutablePath(const APath: string);
var
  I: TIniFile;
  Path: string;
  Dir: string;
  Cfg: TBrowserReadConfig;
begin
  if GlobalConfigUseLegacyStorage then
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
    Exit;
  end;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Cfg := LoadBrowserReadConfigFromDb;
  Cfg.ExecutablePath := Trim(APath);
  SaveBrowserReadConfigToGlobalDb(Cfg);
end;

function BrowserReadTestLocalAllowed: Boolean;
begin
  Result := SameText(GetEnvironmentVariable('LCA_BROWSER_READ_TEST_LOCAL'), '1');
end;

end.
