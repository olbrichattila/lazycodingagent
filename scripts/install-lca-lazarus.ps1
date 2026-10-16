# Install TerminalEmulator + LCA Design System packages for Lazarus IDE and lazbuild.
param(
    [switch]$LinkOnly,
    [switch]$SkipTerminal
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$TE = Join-Path $Root 'third_party\TerminalEmulator'
$LpkTF = Join-Path $TE 'TerminalFramework\TerminalFramework.lpk'
$LpkView = Join-Path $TE 'ViewLCL\ViewLCL.lpk'
$LpkRuntime = Join-Path $Root 'packages\LcaDesignSystem\LcaDesignSystem.lpk'
$LpkDesign = Join-Path $Root 'packages\LcaDesignSystem\LcaDesignSystemDesign.lpk'

function Resolve-LazBuild {
    if ($env:LAZBUILD) {
        $candidate = $env:LAZBUILD
        if ((Test-Path -LiteralPath $candidate -PathType Container)) {
            $candidate = Join-Path $candidate 'lazbuild.exe'
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }
    foreach ($path in @('C:\lazarus\lazbuild.exe', 'C:\Program Files\Lazarus\lazbuild.exe')) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    Write-Error 'lazbuild not found. Add Lazarus to PATH or set LAZBUILD to lazbuild.exe'
}

$LazBuild = Resolve-LazBuild

if (-not $SkipTerminal) {
    if (-not (Test-Path -LiteralPath $LpkTF)) {
        Write-Error 'Missing submodule: git submodule update --init third_party/TerminalEmulator'
    }
    & $LazBuild --add-package-link $LpkTF
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $LazBuild --add-package-link $LpkView
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $LazBuild $LpkTF
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $LazBuild $LpkView
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& $LazBuild --add-package-link $LpkRuntime
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $LazBuild $LpkRuntime
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $LinkOnly) {
    & $LazBuild --add-package $LpkDesign
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $LazBuild $LpkDesign
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host ''
    Write-Host 'Close Lazarus completely before rebuilding the IDE (required for the component palette).'
    Write-Host 'Rebuilding Lazarus IDE with LcaDesignSystemDesign (runtime stays out of lazarus.exe)...'
    & $LazBuild --build-ide
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host ''
    Write-Host 'IDE rebuild complete. Start Lazarus and open the Component palette page: LCA Design.'
    Write-Host 'If Lazarus hangs on startup, run: scripts\recover-lazarus-ide.bat'
} else {
    Write-Host 'Link-only: runtime packages linked for lazbuild (no IDE design install).'
}

Write-Host 'Done. Open lazycodingagent.lpi in Lazarus or run: lazbuild lazycodingagent.lpi'
