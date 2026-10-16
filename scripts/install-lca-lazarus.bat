@echo off
REM Install LCA + terminal Lazarus packages (same as install-lca-lazarus.cmd).
call "%~dp0install-lca-lazarus.cmd" %*
exit /b %ERRORLEVEL%
