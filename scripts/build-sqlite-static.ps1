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

function Test-RealGcc {
  param([string]$GccPath)

  if (-not (Test-Path -LiteralPath $GccPath -PathType Leaf)) {
    return $false
  }
  $binDir = Split-Path -Parent $GccPath
  if (Test-Path -LiteralPath (Join-Path $binDir 'cc1.exe') -PathType Leaf) {
    return $true
  }
  $libexec = Join-Path $binDir 'libexec\gcc'
  if (Test-Path -LiteralPath $libexec -PathType Container) {
    $cc1 = Get-ChildItem -Path $libexec -Recurse -Filter 'cc1.exe' -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($cc1) {
      return $true
    }
  }
  $testC = Join-Path $env:TEMP "sqlite-gcc-test-$([Guid]::NewGuid().ToString('N')).c"
  $testO = Join-Path $env:TEMP "sqlite-gcc-test-$([Guid]::NewGuid().ToString('N')).obj"
  try {
    Set-Content -LiteralPath $testC -Value 'int x(void){return 0;}' -Encoding ASCII
    & $GccPath -c -o $testO $testC 2>$null
    return ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $testO -PathType Leaf))
  } finally {
    Remove-Item -LiteralPath $testC, $testO -Force -ErrorAction SilentlyContinue
  }
}

function Get-ChocolateyMingwGccCandidates {
  $candidates = @(
    'C:\tools\mingw64\bin\gcc.exe',
    'C:\mingw64\bin\gcc.exe'
  )
  $chocoLib = 'C:\ProgramData\chocolatey\lib\mingw'
  if (Test-Path -LiteralPath $chocoLib -PathType Container) {
    foreach ($gcc in Get-ChildItem -Path $chocoLib -Recurse -Filter 'gcc.exe' -ErrorAction SilentlyContinue) {
      $candidates += $gcc.FullName
    }
  }
  $candidates | Select-Object -Unique
}

function Resolve-RealGcc {
  if ($env:SQLITE_CC) {
    if (Test-RealGcc -GccPath $env:SQLITE_CC) {
      return $env:SQLITE_CC
    }
    throw "SQLITE_CC is set but is not a working MinGW gcc: $($env:SQLITE_CC)"
  }

  foreach ($path in Get-ChocolateyMingwGccCandidates) {
    if (Test-RealGcc -GccPath $path) {
      return $path
    }
  }

  $pathGcc = Get-Command gcc -ErrorAction SilentlyContinue
  if ($pathGcc -and $pathGcc.Source) {
    $src = $pathGcc.Source
    if ($src -notmatch '\\fpc\\' -and (Test-RealGcc -GccPath $src)) {
      return $src
    }
  }

  throw @'
Real MinGW gcc not found for sqlite3.c (FPC windres gcc stub cannot compile C).
Install MinGW (e.g. choco install mingw) or set SQLITE_CC to gcc.exe with cc1.
'@
}

$Gcc = Resolve-RealGcc
Write-Host "build-sqlite-static: using $Gcc"

$Defines = @(
  '-DSQLITE_ENABLE_FTS5',
  '-DSQLITE_THREADSAFE=1',
  '-DSQLITE_ENABLE_JSON1'
)
& $Gcc -c -O2 @Defines -o $Out $Src
if ($LASTEXITCODE -ne 0) {
  throw "gcc failed compiling sqlite3.c (exit $LASTEXITCODE)"
}
if (-not (Test-Path -LiteralPath $Out -PathType Leaf)) {
  throw "gcc did not produce $Out"
}

$SrcObj = Join-Path $Root 'packages\LazySqliteStatic\src\sqlite3_embed.o'
$LibEmbed = Join-Path $OutDir 'sqlite3_embed.o'
Copy-Item -Force $Out $SrcObj
Copy-Item -Force $Out $LibEmbed
Write-Host "Built $Out ($SrcObj and $LibEmbed)"
