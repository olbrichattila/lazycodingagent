# Build sqlite3 embed object and link LazySqliteStatic for lazbuild.
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Lpk = Join-Path $Root 'packages\LazySqliteStatic\LazySqliteStatic.lpk'

& "$Root\scripts\build-sqlite-static.ps1" -Arch $Arch
& "$Root\scripts\ci-lazbuild.ps1" --add-package-link $Lpk
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
Write-Host 'LazySqliteStatic is linked for lazbuild.'
