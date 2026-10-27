# Install pinned FPC + Lazarus 4.8 from SourceForge for GitHub Actions (Chocolatey lags behind IDE).
param(
    [string]$InstallDir = $env:CI_LAZARUS_ROOT
)

$ErrorActionPreference = 'Stop'

$SfBase = 'https://downloads.sourceforge.net/project/lazarus/Lazarus%20Windows%2064%20bits/Lazarus%204.8'
$InstallerName = 'lazarus-4.8-fpc-3.2.2-win64.exe'
$MinInstallerBytes = 150MB

function Test-LazarusInstallerFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $info = Get-Item -LiteralPath $Path
    if ($info.Length -lt $MinInstallerBytes) {
        return $false
    }
    $header = [System.IO.File]::ReadAllBytes($Path)[0..1]
    return ($header[0] -eq 0x4D -and $header[1] -eq 0x5A)
}

function Get-LazarusInstaller {
    param(
        [string]$DestPath,
        [string]$Url
    )

    if (Test-LazarusInstallerFile -Path $DestPath) {
        $len = (Get-Item -LiteralPath $DestPath).Length
        Write-Host "ci-install-lazarus-windows: reusing valid installer ($len bytes)"
        return
    }

    if (Test-Path -LiteralPath $DestPath) {
        Write-Host "ci-install-lazarus-windows: removing invalid cached installer"
        Remove-Item -LiteralPath $DestPath -Force
    }

    Write-Host "ci-install-lazarus-windows: downloading $Url"
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & curl.exe -fL --retry 3 --retry-delay 5 -o $DestPath $Url
        if ($LASTEXITCODE -ne 0) {
            throw "ci-install-lazarus-windows: curl.exe failed with exit code $LASTEXITCODE"
        }
    } else {
        # SourceForge serves HTML to browser-like user agents; pose as curl.
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -UserAgent 'curl/8.0'
    }

    if (-not (Test-LazarusInstallerFile -Path $DestPath)) {
        $size = if (Test-Path -LiteralPath $DestPath) { (Get-Item -LiteralPath $DestPath).Length } else { 0 }
        throw @"
ci-install-lazarus-windows: downloaded file is not a valid Lazarus installer ($size bytes).
Likely an HTML interstitial from SourceForge; use curl.exe -fL or -UserAgent curl.
"@
    }

    $len = (Get-Item -LiteralPath $DestPath).Length
    Write-Host "ci-install-lazarus-windows: download OK ($len bytes)"
}

if (-not $InstallDir) {
    $InstallDir = 'C:\lazarus'
}

$workDir = if ($env:CI_LAZARUS_WORKDIR) { $env:CI_LAZARUS_WORKDIR } else { Join-Path $env:RUNNER_TEMP 'lazarus-ci-win64' }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$lazBuild = Join-Path $InstallDir 'lazbuild.exe'
if (Test-Path -LiteralPath $lazBuild) {
    Write-Host "ci-install-lazarus-windows: Lazarus already present at $InstallDir"
} else {
    $installerPath = Join-Path $workDir $InstallerName
    $url = "$SfBase/$InstallerName"
    Get-LazarusInstaller -DestPath $installerPath -Url $url

    if (Test-Path -LiteralPath $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
    }

    Write-Host "ci-install-lazarus-windows: installing to $InstallDir"
    $proc = Start-Process -FilePath $installerPath -ArgumentList @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        "/DIR=$InstallDir"
    ) -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "ci-install-lazarus-windows: installer exit code $($proc.ExitCode)"
    }
    if (-not (Test-Path -LiteralPath $lazBuild)) {
        throw "ci-install-lazarus-windows: lazbuild not found after install: $lazBuild"
    }
}

$env:LAZARUS_DIR = $InstallDir
$env:LAZBUILD = $lazBuild
if (-not $env:LAZARUS_PRIMARY_CONFIG) {
    $primaryConfig = Join-Path $workDir 'primary-config'
    New-Item -ItemType Directory -Path $primaryConfig -Force | Out-Null
    $env:LAZARUS_PRIMARY_CONFIG = $primaryConfig
}

& $env:LAZBUILD --version

if ($env:GITHUB_ENV) {
    function Format-GithubEnvPath {
        param([string]$Path)
        if (-not $Path) { return $Path }
        return $Path.Replace('\', '/')
    }

    @(
        "LAZARUS_DIR=$(Format-GithubEnvPath $InstallDir)"
        "LAZBUILD=$(Format-GithubEnvPath $lazBuild)"
        "LAZARUS_PRIMARY_CONFIG=$(Format-GithubEnvPath $env:LAZARUS_PRIMARY_CONFIG)"
    ) | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8NoBOM
}

Write-Host "ci-install-lazarus-windows: ready (LAZARUS_DIR=$InstallDir, LAZBUILD=$lazBuild)"
