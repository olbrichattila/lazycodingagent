# lazbuild wrapper for CI (Windows): enforce exit code and verify lazycodingagent.exe.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LpiArgs = @('lazycodingagent.lpi')
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$Root = Split-Path -Parent $ScriptDir

function Resolve-LazBuild {
    if ($env:LAZBUILD) {
        $candidate = $env:LAZBUILD
        if (Test-Path -LiteralPath $candidate -PathType Container) {
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
    throw 'ci-lazbuild: lazbuild not found. Set LAZBUILD or install Lazarus.'
}

$LazBuild = Resolve-LazBuild
Write-Host "ci-lazbuild: $LazBuild $($LpiArgs -join ' ')"

& $LazBuild @LpiArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Get-ChildItem -Path $Root -Recurse -Filter lazycodingagent.exe -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "ci-lazbuild: found $($_.FullName)" }

. (Join-Path $ScriptDir 'resolve-lazycodingagent-output.ps1')
$outDir = Get-LazyCodingAgentOutputDir -ProjectRoot $Root -Context 'ci-lazbuild'
Write-Host "ci-lazbuild: output dir $outDir"
