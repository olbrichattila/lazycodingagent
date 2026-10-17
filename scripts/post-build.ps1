# Copy help/ and assets/ next to the built executable (post lazbuild).
param(
    [string]$ProjDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

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
    if ($Explicit -ne '') { return $Explicit }

    $fpcExe = Find-FpcCommand
    if ($fpcExe) {
        $cpu = & $fpcExe -iTP 2>$null
        $os = & $fpcExe -iTO 2>$null
        if ($cpu -and $os) {
            return Join-Path $ProjectRoot "lib\$cpu-$os"
        }
        throw 'post-build: could not read fpc -iTP / fpc -iTO'
    }

    $win64Out = Join-Path $ProjectRoot 'lib\x86_64-win64'
    $win64Exe = Join-Path $win64Out 'lazycodingagent.exe'
    if (Test-Path -LiteralPath $win64Exe) {
        return $win64Out
    }

    throw 'post-build: set -TargetDir, add fpc to PATH, or install Lazarus FPC under C:\lazarus\fpc\...\bin\x86_64-win64'
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
