# Link SynEdit + TurboPower IPro for headless lazbuild (CI or fresh Windows install).
param(
    [string]$LazBuild = $env:LAZBUILD
)

$ErrorActionPreference = 'Stop'

function Resolve-LazBuild {
    param([string]$Candidate)
    if ($Candidate) {
        if (Test-Path -LiteralPath $Candidate -PathType Container) {
            $Candidate = Join-Path $Candidate 'lazbuild.exe'
        }
        if (Test-Path -LiteralPath $Candidate) { return $Candidate }
    }
    $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($path in @('C:\lazarus\lazbuild.exe', 'C:\Program Files\Lazarus\lazbuild.exe')) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'ci-prepare-lazarus-deps: lazbuild not found'
}

function Link-And-Build {
    param([string]$Lpk, [string]$Laz)
    if (-not (Test-Path -LiteralPath $Lpk)) { throw "missing $Lpk" }
    & $Laz --add-package-link $Lpk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $Laz $Lpk
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$LazBuildExe = Resolve-LazBuild -Candidate $LazBuild

$roots = @(
    $env:LAZARUS_DIR,
    'C:\lazarus',
    'C:\Program Files\Lazarus'
) | Where-Object { $_ }

$synLpk = $null
foreach ($root in $roots) {
    $candidate = Join-Path $root 'components\synedit\synedit.lpk'
    if (Test-Path -LiteralPath $candidate) {
        $synLpk = $candidate
        break
    }
}
if (-not $synLpk) { throw 'ci-prepare-lazarus-deps: SynEdit .lpk not found' }

Link-And-Build -Lpk $synLpk -Laz $LazBuildExe
$dsgn = Join-Path (Split-Path $synLpk) 'syneditdsgn.lpk'
if (Test-Path -LiteralPath $dsgn) {
    Link-And-Build -Lpk $dsgn -Laz $LazBuildExe
}

$iproDir = if ($env:TURBOPOWER_IPRO_DIR) { $env:TURBOPOWER_IPRO_DIR } else { Join-Path $env:RUNNER_TEMP 'IPro' }
if (-not (Test-Path -LiteralPath (Join-Path $iproDir '.git'))) {
    if (Test-Path -LiteralPath $iproDir) { Remove-Item -LiteralPath $iproDir -Recurse -Force }
    git clone --depth 1 https://github.com/TurboPack/IPro.git $iproDir
}
$iproLpk = Get-ChildItem -LiteralPath $iproDir -Recurse -Filter 'turbopoweripro.lpk' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $iproLpk) {
    $iproLpk = Get-ChildItem -LiteralPath $iproDir -Recurse -Filter '*.lpk' -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $iproLpk) { throw 'ci-prepare-lazarus-deps: TurboPower IPro .lpk not found' }
Link-And-Build -Lpk $iproLpk.FullName -Laz $LazBuildExe

Write-Host 'ci-prepare-lazarus-deps: SynEdit and TurboPower IPro linked.'
