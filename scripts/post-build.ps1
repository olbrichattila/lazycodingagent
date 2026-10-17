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
    $os = & fpc -iTO 2>$null
    if (-not $cpu -or -not $os) {
        throw 'post-build: could not read fpc -iTP / fpc -iTO'
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
    $srcFull = [System.IO.Path]::GetFullPath($Source)
    $destFull = [System.IO.Path]::GetFullPath($Dest)
    if ($srcFull -eq $destFull) {
        return
    }
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Dest -Recurse -Force
}

$outDir = Resolve-TargetDir -ProjectRoot $ProjDir -Explicit $TargetDir
foreach ($destRoot in @($outDir, $ProjDir)) {
    Copy-TreeReplace -Source (Join-Path $ProjDir 'help') -Dest (Join-Path $destRoot 'help')
    Copy-TreeReplace -Source (Join-Path $ProjDir 'assets') -Dest (Join-Path $destRoot 'assets')
    Write-Host "post-build: deployed help/ and assets/ to $destRoot"
}
