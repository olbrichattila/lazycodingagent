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

function Get-WindowsSdkUmx64LibDir {
    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Lib'
    if (-not (Test-Path -LiteralPath $kitsRoot -PathType Container)) {
        return $null
    }
    $versionDir = Get-ChildItem -Path $kitsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $versionDir) {
        return $null
    }
    $um = Join-Path $versionDir.FullName 'um\x64'
    if (Test-Path -LiteralPath $um -PathType Container) {
        return $um
    }
    return $null
}

function Get-WindowsSdkUcrtX64LibDir {
    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Lib'
    if (-not (Test-Path -LiteralPath $kitsRoot -PathType Container)) {
        return $null
    }
    $versionDir = Get-ChildItem -Path $kitsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $versionDir) {
        return $null
    }
    $ucrt = Join-Path $versionDir.FullName 'ucrt\x64'
    if (Test-Path -LiteralPath $ucrt -PathType Container) {
        return $ucrt
    }
    return $null
}

function Get-MsvcUcrtLibDir {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        return $null
    }
    $installRoot = & $vswhere -latest -products * -property installationPath 2>$null
    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        return $null
    }
    $toolsRoot = Join-Path $installRoot 'VC\Tools\MSVC'
    if (-not (Test-Path -LiteralPath $toolsRoot -PathType Container)) {
        return $null
    }
    $verDir = Get-ChildItem -Path $toolsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $verDir) {
        return $null
    }
    $lib = Join-Path $verDir.FullName 'lib\x64'
    if (Test-Path -LiteralPath $lib -PathType Container) {
        return $lib
    }
    return $null
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

    $libDirs = @()
    $umLib = Get-WindowsSdkUmx64LibDir
    if ($umLib) { $libDirs += $umLib }
    $sdkUcrt = Get-WindowsSdkUcrtX64LibDir
    if ($sdkUcrt) { $libDirs += $sdkUcrt }
    $msvcLib = Get-MsvcUcrtLibDir
    if ($msvcLib) { $libDirs += $msvcLib }

    $PrefixArgs.Value += '--opt=-Xe'

    $libSets = @(
        @{ Dir = $umLib; Libs = @('kernel32.lib', 'advapi32.lib', 'user32.lib') },
        @{ Dir = $sdkUcrt; Libs = @('ucrt.lib') },
        @{ Dir = $msvcLib; Libs = @('msvcrt.lib', 'vcruntime.lib') }
    )
    foreach ($set in $libSets) {
        if (-not $set.Dir) { continue }
        foreach ($lib in $set.Libs) {
            $path = Join-Path $set.Dir $lib
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $short = Get-ShortPathName -LongPath $path
                $PrefixArgs.Value += "--opt=-k$short"
            }
        }
    }
    Write-Host 'ci-lazbuild: passing Windows/MSVC import libs for MSVC sqlite3_embed.o'
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
