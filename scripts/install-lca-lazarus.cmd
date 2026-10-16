@echo off
REM Install LCA + terminal Lazarus packages (works when PowerShell script execution is restricted).
setlocal
set "SCRIPT=%~dp0install-lca-lazarus.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
