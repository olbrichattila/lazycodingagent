unit uGlobalConfigLegacy;

{$mode ObjFPC}{$H+}

interface

const
  ENV_LEGACY_STORAGE = 'LAZYCODINGAGENT_LEGACY_STORAGE';

function GlobalConfigUseLegacyStorage: Boolean;
function LegacyConfigIniPath: string;
function LegacyWorkspaceRegistryPath: string;
procedure SetLegacyConfigPathsForTests(const AIniPath, ARegistryPath: string);
procedure ClearLegacyConfigPathsForTests;

implementation

uses
  SysUtils;

var
  GTestIniPath: string = '';
  GTestRegistryPath: string = '';

procedure SetLegacyConfigPathsForTests(const AIniPath, ARegistryPath: string);
begin
  GTestIniPath := AIniPath;
  GTestRegistryPath := ARegistryPath;
end;

procedure ClearLegacyConfigPathsForTests;
begin
  GTestIniPath := '';
  GTestRegistryPath := '';
end;

function GlobalConfigUseLegacyStorage: Boolean;
begin
  Result := SameText(SysUtils.GetEnvironmentVariable(ENV_LEGACY_STORAGE), '1');
end;

function LazarusStyleConfigDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config' + PathDelim;
end;

function LegacyConfigIniPath: string;
begin
  if GTestIniPath <> '' then
    Exit(GTestIniPath);
  Result := LazarusStyleConfigDir + 'lazycodingagent' + PathDelim + 'config.ini';
end;

function LegacyWorkspaceRegistryPath: string;
begin
  if GTestRegistryPath <> '' then
    Exit(GTestRegistryPath);
  Result := LazarusStyleConfigDir + 'lazycodingagent' + PathDelim + 'lazycodingagent' + PathDelim +
    'workspaces.json';
end;

end.
