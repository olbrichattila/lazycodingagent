# Build sqlite3 embed object and link LazySqliteStatic for lazbuild.
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$LazBuild = if ($env:LAZBUILD) { $env:LAZBUILD } else { 'lazbuild' }

& "$Root\scripts\build-sqlite-static.ps1" -Arch $Arch
& $LazBuild --add-package-link "$Root\packages\LazySqliteStatic\LazySqliteStatic.lpk"
Write-Host 'LazySqliteStatic is linked for lazbuild.'
