@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   WinPE WireGuard Tunnel Teardown Utility
echo ========================================================
echo.

set "FOUND=0"
set "WG_BIN=%~dp0wireguard.exe"

if not exist "!WG_BIN!" (
    where wireguard.exe >nul 2>&1
    if !errorlevel! equ 0 (
        set "WG_BIN=wireguard.exe"
    ) else (
        echo [WARNING] wireguard.exe not found in %~dp0 or PATH. Falling back to sc.exe.
    )
)

:: Check if user specified a specific tunnel on the command line
if not "%~1"=="" (
    set "TARGET=%~1"
    set "TARGET=!TARGET:.conf=!"
    echo Stopping and removing specified tunnel service: [!TARGET!]...
    if exist "!WG_BIN!" (
        "!WG_BIN!" /uninstalltunnelservice "!TARGET!" >nul 2>&1
    )
    sc stop "WireGuardTunnel$!TARGET!" >nul 2>&1
    sc delete "WireGuardTunnel$!TARGET!" >nul 2>&1
    set "FOUND=1"
    goto :VERIFY
)

:: Scan system for any active or registered WireGuardTunnel services
echo Scanning for registered WireGuard tunnel services...
for /f "tokens=2 delims=$" %%a in ('sc query state= all 2^>nul ^| findstr /i "WireGuardTunnel\$"') do (
    set "TNAME=%%a"
    for /f "tokens=* delims= " %%k in ("!TNAME!") do set "TNAME=%%k"
    if defined TNAME (
        set "FOUND=1"
        echo   [-] Found active tunnel service: WireGuardTunnel$!TNAME!
        echo       Uninstalling tunnel service [!TNAME!]...
        if exist "!WG_BIN!" (
            "!WG_BIN!" /uninstalltunnelservice "!TNAME!" >nul 2>&1
        )
        sc stop "WireGuardTunnel$!TNAME!" >nul 2>&1
        sc delete "WireGuardTunnel$!TNAME!" >nul 2>&1
    )
)

:: Fallback check: if no services returned by sc, check local directory configs
if "!FOUND!"=="0" (
    echo No active WireGuard services reported by Service Control Manager.
    echo Checking local directory for standard configuration profiles...
    for %%f in ("%~dp0*.conf") do (
        set "BNAME=%%~nf"
        if not "!BNAME!"=="network" (
            echo   [-] Attempting teardown for profile: !BNAME!...
            if exist "!WG_BIN!" (
                "!WG_BIN!" /uninstalltunnelservice "!BNAME!" >nul 2>&1
            )
            sc stop "WireGuardTunnel$!BNAME!" >nul 2>&1
            sc delete "WireGuardTunnel$!BNAME!" >nul 2>&1
        )
    )
)

:VERIFY
echo.
echo Verifying WireGuard service status...
sc query state= all 2>nul | findstr /i "WireGuardTunnel\$" >nul 2>&1
if !errorlevel! equ 0 (
    echo [!] WARNING: One or more WireGuardTunnel services may still be running:
    sc query state= all 2>nul | findstr /i "SERVICE_NAME.*WireGuardTunnel"
) else (
    echo [OK] WireGuard tunnel service(s) successfully stopped and uninstalled.
    echo      The Wintun virtual adapter has been cleanly removed.
)

echo.
echo You may now safely re-run baremetal-setup.bat or Connect-WG.bat.
echo.
endlocal
