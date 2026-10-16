# Copy help/ and assets/ next to the built executable (post lazbuild).
param(
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

function Resolve-TargetDir {
    param([string]$ProjectRoot, [string]$Explicit)
    if ($Explicit -ne '') { return $Explicit }
    $fpc = Get-Command fpc -ErrorAction SilentlyContinue
    if (-not $fpc) {
        throw 'post-build: set -TargetDir or add fpc to PATH to auto-detect lib\cpu-os'
    }
    $cpu = & fpc -iTP 2>$null
    $os = & fpc -iTOS 2>$null
    if (-not $cpu -or -not $os) {
        throw 'post-build: could not read fpc -iTP / fpc -iTOS'
    }
    return Join-Path $ProjectRoot "lib\$cpu-$os"
}

function Copy-TreeReplace {
    param(
        [string]$Source,
        [string]$Dest
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "post-build: skip missing $Source"
        return
    }
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Dest -Recurse -Force
}

$outDir = Resolve-TargetDir -ProjectRoot $ProjDir -Explicit $TargetDir
Copy-TreeReplace -Source (Join-Path $ProjDir 'help') -Dest (Join-Path $outDir 'help')
Copy-TreeReplace -Source (Join-Path $ProjDir 'assets') -Dest (Join-Path $outDir 'assets')
Write-Host "post-build: deployed help/ and assets/ to $outDir"
