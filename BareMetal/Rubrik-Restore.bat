@echo off
setlocal
title Rubrik Bare-Metal Recovery Assistant

echo.
echo ===============================================================================
echo  Launching Rubrik Bare-Metal Recovery Assistant...
echo ===============================================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Rubrik-Restore.ps1"

endlocal
