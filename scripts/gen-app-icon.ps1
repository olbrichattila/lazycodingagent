# Generate res/lazycodingagent.ico from packages/LcaDesignSystem/res/owl_icon.png
# and lazycodingagent_appicon.res (Windows EXE / taskbar MAINICON).
param(
    [string]$PngPath = (Join-Path $PSScriptRoot '..\packages\LcaDesignSystem\res\owl_icon.png'),
    [string]$IcoPath = (Join-Path $PSScriptRoot '..\res\lazycodingagent.ico')
)

$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$PngPath = [System.IO.Path]::GetFullPath($PngPath)
$IcoPath = [System.IO.Path]::GetFullPath($IcoPath)

if (-not (Test-Path -LiteralPath $PngPath)) {
    Write-Error "PNG not found: $PngPath"
}

$icoDir = Split-Path -Parent $IcoPath
if (-not (Test-Path -LiteralPath $icoDir)) {
    New-Item -ItemType Directory -Path $icoDir -Force | Out-Null
}

$magick = Get-Command magick -ErrorAction SilentlyContinue
if ($magick) {
    & magick convert $PngPath -define icon:auto-resize=16,32,48,256 $IcoPath
    Write-Host "Wrote $IcoPath (ImageMagick)"
} else {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Error 'Need ImageMagick (magick) or Python with Pillow: pip install pillow'
    }
    $py = @"
from PIL import Image
from pathlib import Path
p = Path(r'$PngPath')
o = Path(r'$IcoPath')
img = Image.open(p).convert('RGBA')
img.save(o, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
print(o)
"@
    & $python.Source -c $py
    Write-Host "Wrote $IcoPath (Pillow)"
}

$windres = @(
    (Join-Path $env:LAZARUS_DIR 'fpc\3.2.2\bin\x86_64-win64\windres.exe'),
    'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe',
    'C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $windres) {
    $cmd = Get-Command windres -ErrorAction SilentlyContinue
    if ($cmd) { $windres = $cmd.Source }
}
if (-not $windres) {
    Write-Warning 'windres not found; skip lazycodingagent_appicon.res (Windows EXE will keep prior icon resource).'
    exit 0
}

$rcPath = Join-Path $Root 'lazycodingagent.rc'
$appIconRes = Join-Path $Root 'lazycodingagent_appicon.res'
& $windres -i $rcPath -o $appIconRes
Write-Host "Wrote $appIconRes (windres MAINICON)"
