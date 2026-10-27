# Compile third_party/sqlite/sqlite3.c to sqlite3.obj for LazySqliteStatic (Windows).
param(
  [ValidateSet('win32', 'win64')]
  [string]$Arch = 'win64'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'third_party\sqlite\sqlite3.c'
if (-not (Test-Path -LiteralPath $Src)) {
  throw "Missing $Src"
}

if ($Arch -eq 'win32') {
  $OutDir = Join-Path $Root 'packages\LazySqliteStatic\lib\i386-win32'
} else {
  $OutDir = Join-Path $Root 'packages\LazySqliteStatic\lib\x86_64-win64'
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Out = Join-Path $OutDir 'sqlite3.obj'

$Gcc = $null
foreach ($c in @(
    'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\gcc.exe',
    'C:\lazarus\fpc\3.2.2\bin\i386-win32\gcc.exe',
    'gcc'
  )) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { $Gcc = $c; break }
}
if (-not $Gcc) { throw 'gcc not found (install MinGW or use Lazarus-bundled FPC gcc)' }

$Defines = @(
  '-Wno-discarded-qualifiers',
  '-DSQLITE_ENABLE_FTS5',
  '-DSQLITE_THREADSAFE=1',
  '-DSQLITE_ENABLE_JSON1'
)
& $Gcc -c -O2 @Defines -o $Out $Src
$SrcObj = Join-Path $Root 'packages\LazySqliteStatic\src\sqlite3_embed.o'
$LibEmbed = Join-Path $OutDir 'sqlite3_embed.o'
Copy-Item -Force $Out $SrcObj
Copy-Item -Force $Out $LibEmbed
Write-Host "Built $Out ($SrcObj and $LibEmbed)"
