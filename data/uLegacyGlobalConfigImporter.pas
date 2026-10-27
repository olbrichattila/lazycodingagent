unit uLegacyGlobalConfigImporter;

{$mode ObjFPC}{$H+}

interface

uses
  uBrowserReadTypes;

type
  TLegacyGlobalConfigImporter = class
  public
    class procedure Run;
  end;

implementation

uses
  SysUtils, uAppDatabase, uGlobalConfigKeys, uAppSettingsCodec, uGlobalConfigLegacy,
  uWorkspaceState, uWorkspaceRegistry, uWebSearchConfig, uWebSearchTypes, uBrowserReadConfig;

function BackupSuffix: string;
begin
  Result := FormatDateTime('yyyymmdd-hhnnss', Now);
end;

procedure TryBackupFile(const APath: string);
var
  Dest: string;
begin
  if (APath = '') or not FileExists(APath) then
    Exit;
  Dest := APath + '.bak.' + BackupSuffix;
  if not RenameFile(APath, Dest) then
    raise Exception.CreateFmt('Could not rename legacy file to %s', [Dest]);
end;

class procedure TLegacyGlobalConfigImporter.Run;
var
  State: TWorkspaceState;
  Registry: TWorkspaceRegistry;
  IniPath, JsonPath, ImportedAt: string;
  Cfg: TWebSearchGlobalConfig;
  BrowserCfg: TBrowserReadConfig;
begin
  if GlobalConfigUseLegacyStorage then
    Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  if TAppDatabase.GlobalSettings.TryGet(KEY_MIGRATION_IMPORTED, ImportedAt) and (Trim(ImportedAt) <> '') then
    Exit;

  State := TWorkspaceState.Create;
  Registry := TWorkspaceRegistry.Create;
  try
    IniPath := LegacyConfigIniPath;
    JsonPath := LegacyWorkspaceRegistryPath;
    if FileExists(IniPath) then
      State.LoadLegacyIni;
    if FileExists(JsonPath) then
      Registry.LoadLegacyJson;
    Registry.MigrateFromLegacyIni(State.WorkspaceName, State.WorkspaceRoot);
    if (Registry.ActiveWorkspaceId = '') and (Trim(State.ActiveWorkspaceId) <> '') then
      Registry.ActiveWorkspaceId := State.ActiveWorkspaceId;

    State.SaveToGlobalDb;
    Registry.SaveToGlobalDb;

    if FileExists(IniPath) then
    begin
      Cfg := LoadWebSearchConfigFromIniFile(IniPath);
      SaveWebSearchConfigToGlobalDb(Cfg);
      SetBrowserReadIniPathForTests(IniPath);
      try
        BrowserCfg := LoadBrowserReadConfigFromIni;
        SaveBrowserReadConfigToGlobalDb(BrowserCfg);
      finally
        ClearBrowserReadIniPathForTests;
      end;
    end;

    SettingsSetString(TAppDatabase.GlobalSettings, KEY_MIGRATION_IMPORTED,
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));

    TryBackupFile(IniPath);
    TryBackupFile(JsonPath);
  finally
    Registry.Free;
    State.Free;
  end;
end;

end.
