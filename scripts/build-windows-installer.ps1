# Build LazyCodingAgent Windows installer with Inno Setup (ISCC).
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-TargetDir {
    param([string]$ProjectRoot, [string]$Explicit)
    if ($Explicit -ne '') { return (Resolve-Path -LiteralPath $Explicit).Path }
    $fpc = Get-Command fpc -ErrorAction SilentlyContinue
    if (-not $fpc) {
        throw 'build-windows-installer: set -TargetDir or add fpc to PATH to auto-detect lib\cpu-os'
    }
    $cpu = & fpc -iTP 2>$null
    $os = & fpc -iTOS 2>$null
    if (-not $cpu -or -not $os) {
        throw 'build-windows-installer: could not read fpc -iTP / fpc -iTOS'
    }
    $dir = Join-Path $ProjectRoot "lib\$cpu-$os"
    if (-not (Test-Path -LiteralPath $dir)) {
        throw "build-windows-installer: build output directory not found: $dir"
    }
    return (Resolve-Path -LiteralPath $dir).Path
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

& $iscc `
    "/DMyAppVersion=$Version" `
    "/DSourceDir=$sourceDir" `
    "/DRepoDir=$repoDir" `
    $issPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath $setupPath)) {
    throw "build-windows-installer: expected output not found: $setupPath"
}

Write-Host "build-windows-installer: $setupPath"
Write-Output $setupPath
