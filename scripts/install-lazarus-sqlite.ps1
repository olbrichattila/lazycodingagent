# Build sqlite3 embed object and link LazySqliteStatic for lazbuild.
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$LazBuild = if ($env:LAZBUILD) { $env:LAZBUILD } else { 'lazbuild' }

& "$Root\scripts\build-sqlite-static.ps1" -Arch $Arch

$lazArgs = @(
  '--add-package-link',
  "$Root\packages\LazySqliteStatic\LazySqliteStatic.lpk"
)
if ($env:LAZARUS_DIR) {
  $lazArgs = @('--lazarusdir', $env:LAZARUS_DIR) + $lazArgs
  if ($env:LAZARUS_PRIMARY_CONFIG) {
    $lazArgs = @('--primary-config-path', $env:LAZARUS_PRIMARY_CONFIG) + $lazArgs
  }
}
& $LazBuild @lazArgs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
Write-Host 'LazySqliteStatic is linked for lazbuild.'
