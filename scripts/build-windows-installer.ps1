# Build LazyCodingAgent Windows installer with Inno Setup (ISCC).
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

function Find-FpcCommand {
    $onPath = Get-Command fpc -ErrorAction SilentlyContinue
    if ($onPath) {
        return $onPath.Source
    }
    $fixed = @(
        'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe',
        'C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe'
    )
    foreach ($p in $fixed) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    $globs = @()
    if ($env:LAZARUS_DIR) {
        $globs += Join-Path $env:LAZARUS_DIR 'fpc\*\bin\x86_64-win64\fpc.exe'
    }
    $globs += 'C:\lazarus\fpc\*\bin\x86_64-win64\fpc.exe'
    foreach ($pattern in $globs) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName } -Descending |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    return $null
}

function Resolve-TargetDir {
    param([string]$ProjectRoot, [string]$Explicit)
    if ($Explicit -ne '') { return (Resolve-Path -LiteralPath $Explicit).Path }

    $fpcExe = Find-FpcCommand
    if ($fpcExe) {
        $cpu = & $fpcExe -iTP 2>$null
        $os = & $fpcExe -iTO 2>$null
        if ($cpu -and $os) {
            $dir = Join-Path $ProjectRoot "lib\$cpu-$os"
            if (Test-Path -LiteralPath $dir) {
                return (Resolve-Path -LiteralPath $dir).Path
            }
            throw "build-windows-installer: build output directory not found: $dir"
        }
        throw 'build-windows-installer: could not read fpc -iTP / fpc -iTO'
    }

    $win64Out = Join-Path $ProjectRoot 'lib\x86_64-win64'
    $win64Exe = Join-Path $win64Out 'lazycodingagent.exe'
    if (Test-Path -LiteralPath $win64Exe) {
        return (Resolve-Path -LiteralPath $win64Out).Path
    }

    throw 'build-windows-installer: set -TargetDir, add fpc to PATH, or install Lazarus FPC under C:\lazarus\fpc\...\bin\x86_64-win64'
}

function Format-IsccDefinePath {
    param([string]$Path)
    # Inno preprocessor treats backslashes as escapes in /D values (e.g. D:\a\... -> \a).
    return ($Path -replace '\\', '/')
}

function Resolve-Iscc {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    foreach ($path in @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        )) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'build-windows-installer: ISCC.exe not found. Install Inno Setup 6 or add ISCC to PATH.'
}

if ($Version -match '[^\d\.\-\+a-zA-Z]') {
    throw "build-windows-installer: invalid version string: $Version"
}

$sourceDir = Resolve-TargetDir -ProjectRoot $ProjDir -Explicit $TargetDir
$exePath = Join-Path $sourceDir 'lazycodingagent.exe'
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "build-windows-installer: missing $exePath (run lazbuild and post-build.ps1 first)"
}

$repoDir = (Resolve-Path -LiteralPath $ProjDir).Path
$issPath = Join-Path $ProjDir 'installer\lazycodingagent.iss'
if (-not (Test-Path -LiteralPath $issPath)) {
    throw "build-windows-installer: missing $issPath"
}

$distDir = Join-Path $ProjDir 'dist'
if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$iscc = Resolve-Iscc
$setupName = "LazyCodingAgent-$Version-win64-Setup.exe"
$setupPath = Join-Path $distDir $setupName

Write-Host "build-windows-installer: ISCC $iscc"
Write-Host "build-windows-installer: version=$Version source=$sourceDir"

$sourceDirIscc = Format-IsccDefinePath $sourceDir
$repoDirIscc = Format-IsccDefinePath $repoDir

& $iscc `
    "/DMyAppVersion=$Version" `
    "/DSourceDir=$sourceDirIscc" `
    "/DRepoDir=$repoDirIscc" `
    $issPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath $setupPath)) {
    throw "build-windows-installer: expected output not found: $setupPath"
}

Write-Host "build-windows-installer: $setupPath"
Write-Output $setupPath
