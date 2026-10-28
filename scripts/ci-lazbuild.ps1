# lazbuild wrapper for CI (Windows): enforce exit code and verify lazycodingagent.exe.
#
# Windows: prefer scripts\ci-lazbuild.bat when PowerShell blocks .\ci-lazbuild.ps1.
param(
    [bool]$VerifyExe = $true,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LpiArgs = @('lazycodingagent.lpi')
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$Root = Split-Path -Parent $ScriptDir

function Get-NativePathForLazbuild {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    return $Path.Replace('/', '\')
}

function Get-ShortPathName {
    param([string]$LongPath)
    if (-not (Test-Path -LiteralPath $LongPath)) {
        return $LongPath
    }
    $fso = New-Object -ComObject Scripting.FileSystemObject
    if (Test-Path -LiteralPath $LongPath -PathType Leaf) {
        return $fso.GetFile($LongPath).ShortPath
    }
    return $fso.GetFolder($LongPath).ShortPath
}

function Add-MsvcEmbedLinkOpts {
    param([ref]$PrefixArgs, [string[]]$LpiArgs)

    $buildingMain = $LpiArgs | Where-Object { $_ -match 'lazycodingagent\.lpi$' }
    if (-not $buildingMain) {
        return
    }
    $embedObj = Join-Path $Root 'packages\LazySqliteStatic\src\sqlite3_embed.o'
    if (-not (Test-Path -LiteralPath $embedObj -PathType Leaf)) {
        return
    }
    Write-Host 'ci-lazbuild: MSVC sqlite3_embed.o — internal linker + uSqliteWinEmbedBridge'
    if ($env:LCA_WIN_LINK_XE -eq '1') {
        $PrefixArgs.Value += '--opt=-Xe'
        Write-Host 'ci-lazbuild: LCA_WIN_LINK_XE=1 — using link.exe for final PE link'
    }
}

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

$prefixArgs = @()
if (-not [string]::IsNullOrWhiteSpace($env:LAZARUS_DIR) -and
    -not [string]::IsNullOrWhiteSpace($env:LAZARUS_PRIMARY_CONFIG)) {
    $lazarusDir = Get-NativePathForLazbuild -Path $env:LAZARUS_DIR
    $primaryConfig = Get-NativePathForLazbuild -Path $env:LAZARUS_PRIMARY_CONFIG
    $prefixArgs += "--lazarusdir=$lazarusDir"
    $prefixArgs += "--primary-config-path=$primaryConfig"
}
if (-not [string]::IsNullOrWhiteSpace($env:LCL_WIDGETSET)) {
    $prefixArgs += "--widgetset=$($env:LCL_WIDGETSET)"
}

Add-MsvcEmbedLinkOpts -PrefixArgs ([ref]$prefixArgs) -LpiArgs $LpiArgs

$allArgs = $prefixArgs + $LpiArgs
Write-Host "ci-lazbuild: $LazBuild $($allArgs -join ' ')"

& $LazBuild @allArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not $VerifyExe) {
    return
}

Get-ChildItem -Path $Root -Recurse -Filter lazycodingagent.exe -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "ci-lazbuild: found $($_.FullName)" }

. (Join-Path $ScriptDir 'resolve-lazycodingagent-output.ps1')
$outDir = Get-LazyCodingAgentOutputDir -ProjectRoot $Root -Context 'ci-lazbuild'
Write-Host "ci-lazbuild: output dir $outDir"
