unit uGlobalConfigBootstrap;

{$mode ObjFPC}{$H+}

interface

procedure EnsureGlobalConfigReady;

function GlobalConfigImportCompleted: Boolean;

implementation

uses
  SysUtils, uAppDatabase, uGlobalConfigKeys, uAppSettingsCodec, uGlobalConfigLegacy,
  uLegacyGlobalConfigImporter;

function LegacyConfigFilesPresent: Boolean;
begin
  Result := FileExists(LegacyConfigIniPath) or FileExists(LegacyWorkspaceRegistryPath);
end;

function GlobalConfigImportCompleted: Boolean;
var
  V: string;
begin
  if GlobalConfigUseLegacyStorage then
    Exit(True);
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Result := TAppDatabase.GlobalSettings.TryGet(KEY_MIGRATION_IMPORTED, V) and (Trim(V) <> '');
end;

procedure MarkFreshInstallImported;
begin
  SettingsSetString(TAppDatabase.GlobalSettings, KEY_MIGRATION_IMPORTED,
    FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
end;

procedure EnsureGlobalConfigReady;
begin
  if GlobalConfigUseLegacyStorage then
    Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  if GlobalConfigImportCompleted then
    Exit;
  if LegacyConfigFilesPresent then
    TLegacyGlobalConfigImporter.Run
  else
    MarkFreshInstallImported;
end;

end.
