@echo off
setlocal
set "ROOT=%~dp0.."
set "GLYPH_DIR=%ROOT%\packages\LcaDesignSystem\res\glyphs"
set "OUT_RES=%ROOT%\packages\LcaDesignSystem\res\lca_design_glyphs.res"

set "LAZRES="
if defined LAZRES goto :have_lazres
if exist "C:\lazarus\tools\lazres.exe" set "LAZRES=C:\lazarus\tools\lazres.exe"
if not defined LAZRES if exist "C:\Program Files\Lazarus\tools\lazres.exe" set "LAZRES=C:\Program Files\Lazarus\tools\lazres.exe"
:have_lazres
if not defined LAZRES (
  echo lazres not found
  exit /b 1
)

if not exist "%GLYPH_DIR%\*.png" (
  echo No PNG glyphs in %GLYPH_DIR%
  exit /b 1
)

del /f /q "%OUT_RES%" 2>nul
pushd "%GLYPH_DIR%"
for %%F in (*.png) do set "ARGS=!ARGS! %%F"
popd
if not defined ARGS (
  echo No PNG glyphs found
  exit /b 1
)
setlocal EnableDelayedExpansion
pushd "%GLYPH_DIR%"
"%LAZRES%" "%OUT_RES%" *.png
set ERR=!ERRORLEVEL!
popd
if !ERR! neq 0 exit /b !ERR!
echo Wrote %OUT_RES%
exit /b 0
