@echo off
REM Master owl_icon.png -> owl_icon.bmp + owl_icon.res + lazycodingagent.ico + appicon.res
setlocal
set "ROOT=%~dp0.."
set "PNG=%ROOT%\packages\LcaDesignSystem\res\owl_icon.png"
set "BMP=%ROOT%\packages\LcaDesignSystem\res\owl_icon.bmp"
set "OWLRES=%ROOT%\packages\LcaDesignSystem\res\owl_icon.res"
set "ICO=%ROOT%\res\lazycodingagent.ico"
set "RC=%ROOT%\lazycodingagent.rc"
set "APPICON=%ROOT%\lazycodingagent_appicon.res"

python "%~dp0write_bmp_ico.py" "%PNG%" "%BMP%" 128
if errorlevel 1 exit /b 1

set "LAZRES="
if exist "C:\lazarus\tools\lazres.exe" set "LAZRES=C:\lazarus\tools\lazres.exe"
if not defined LAZRES if exist "C:\Program Files\Lazarus\tools\lazres.exe" set "LAZRES=C:\Program Files\Lazarus\tools\lazres.exe"
if not defined LAZRES (
  echo lazres not found
  exit /b 1
)
pushd "%ROOT%\packages\LcaDesignSystem\res"
"%LAZRES%" owl_icon.res owl_icon.bmp=OWL_ICON
if errorlevel 1 (
  popd
  exit /b 1
)
popd

python "%~dp0write_bmp_ico.py" "%PNG%" "%ICO%"
if errorlevel 1 exit /b 1

set "WINDRES="
if exist "C:\lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe" set "WINDRES=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe"
if not defined WINDRES if exist "C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe" set "WINDRES=C:\Program Files\Lazarus\fpc\3.2.2\bin\x86_64-win64\windres.exe"
if not defined WINDRES (
  echo windres not found
  exit /b 1
)
for %%I in ("%WINDRES%") do set "FPCBIN=%%~dpI"
if not exist "%FPCBIN%gcc.exe" (
  echo FPC preprocessor not found: %FPCBIN%gcc.exe
  exit /b 1
)
pushd "%ROOT%"
"%WINDRES%" --preprocessor="%FPCBIN%gcc.exe" -J rc -O res -i "%RC%" -o "%APPICON%"
set "WINDRES_ERR=%ERRORLEVEL%"
popd
if not "%WINDRES_ERR%"=="0" exit /b %WINDRES_ERR%

echo Wrote %BMP%, %OWLRES%, %ICO%, %APPICON%
