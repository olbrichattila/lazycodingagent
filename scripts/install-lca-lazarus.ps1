# Install TerminalEmulator + LCA Design System packages for Lazarus IDE and lazbuild.
param(
    [switch]$LinkOnly,
    [switch]$SkipTerminal,
    [string]$WidgetSet = $env:LCL_WIDGETSET
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

function Invoke-LazBuild {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($WidgetSet) {
        & $LazBuild --widgetset=$WidgetSet @Args
    } else {
        & $LazBuild @Args
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($WidgetSet) {
    Write-Host "Using LCL widgetset: $WidgetSet"
}

if (-not $SkipTerminal) {
    if (-not (Test-Path -LiteralPath $LpkTF)) {
        Write-Error 'Missing submodule: git submodule update --init third_party/TerminalEmulator'
    }
    Invoke-LazBuild --add-package-link $LpkTF
    Invoke-LazBuild --add-package-link $LpkView
    Invoke-LazBuild $LpkTF
    Invoke-LazBuild $LpkView
}

Invoke-LazBuild --add-package-link $LpkRuntime
Invoke-LazBuild $LpkRuntime

if (-not $LinkOnly) {
    Invoke-LazBuild --add-package $LpkDesign
    Invoke-LazBuild $LpkDesign
    Write-Host ''
    Write-Host 'Close Lazarus completely before rebuilding the IDE (required for the component palette).'
    Write-Host 'Rebuilding Lazarus IDE with LcaDesignSystemDesign (runtime stays out of lazarus.exe)...'
    Invoke-LazBuild --build-ide
    Write-Host ''
    Write-Host 'IDE rebuild complete. Start Lazarus and open the Component palette page: LCA Design.'
    Write-Host 'If Lazarus hangs on startup, run: scripts\recover-lazarus-ide.bat'
} else {
    Write-Host 'Link-only: runtime packages linked for lazbuild (no IDE design install).'
}

if ($WidgetSet) {
    Write-Host "Done. Build the app with: lazbuild --widgetset=$WidgetSet lazycodingagent.lpi"
} else {
    Write-Host 'Done. Open lazycodingagent.lpi in Lazarus or run: lazbuild lazycodingagent.lpi'
}
