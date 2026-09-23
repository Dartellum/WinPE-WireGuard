@echo off
setlocal enabledelayedexpansion

set "CONFFILE=network.conf"

if not exist "%CONFFILE%" (
    echo [ERROR] Configuration file %CONFFILE% not found in %CD%!
    goto :end
)

:: Parse all key=value pairs dynamically from network.conf
for /f "tokens=1,2 delims==" %%a in ('type "%CONFFILE%"') do (
    set "KEY=%%a"
    set "VAL=%%b"
    for /f "tokens=* delims= " %%k in ("!KEY!") do set "KEY=%%k"
    for /f "tokens=* delims= " %%v in ("!VAL!") do set "VAL=%%v"

    if "!KEY!"=="Adapter" set "ADAPTER=!VAL!"
    if "!KEY!"=="Default_Mask" set "DEF_MASK=!VAL!"
    if "!KEY!"=="Default_Gateway" set "DEF_GW=!VAL!"
    if "!KEY!"=="Default_DNS" set "DEF_DNS=!VAL!"
    if "!KEY!"=="DNS" if not defined DEF_DNS set "DEF_DNS=!VAL!"
    if "!KEY!"=="Mask" if not defined DEF_MASK set "DEF_MASK=!VAL!"
    if "!KEY!"=="Gateway" if not defined DEF_GW set "DEF_GW=!VAL!"
    if "!KEY!"=="Tunnel" set "TUNNEL=!VAL!"
    if "!KEY!"=="Backup" set "BACKUP=!VAL!"

    :: Dynamically store all SRV variables (SRV1_Name, SRV2_IP, etc.)
    if "!KEY:~0,3!"=="SRV" set "!KEY!=!VAL!"
)

echo ========================================================
echo   WinPE WireGuard Bare-Metal Automation
echo ========================================================
echo Base Network Parameters loaded from %CONFFILE%:
echo   Default Adapter : %ADAPTER%
echo   Default Mask    : %DEF_MASK%
echo   Default Gateway : %DEF_GW%
if defined DEF_DNS if not "%DEF_DNS%"=="" echo   Default DNS     : %DEF_DNS%
echo   Tunnel Endpoint : %TUNNEL%
echo   Backup Target   : %BACKUP%
echo ========================================================
echo.

:: Automatically scan and dynamically load any hardware drivers in Drivers\
if exist "%CD%\Drivers" (
    echo Scanning and dynamically loading supplementary drivers from Drivers\...
    for /r "%CD%\Drivers" %%i in (*.inf) do (
        echo   [+] Loading: %%~nxi
        drvload "%%i" >nul 2>&1
    )
    echo   Driver initialization complete.
    :: Brief 2-second pause for Windows PnP device manager to bind adapter
    ping 127.0.0.1 -n 3 >nul
    echo.
)

echo Available network interfaces on this physical system:
netsh interface ipv4 show interface
echo.

set /p "CHOICE=Do you want to use the default adapter name '%ADAPTER%'? (Y/N): "
if /i "%CHOICE%"=="N" (
    echo.
    set /p "ADAPTER=Enter the correct adapter name from the list above: "
)

:SERVER_MENU
cls
echo ===============================================================================
echo                 Select Target Physical Server for Restoration
echo ===============================================================================
:: Dynamically list every defined server (supports up to 50 servers)
for /L %%i in (1,1,50) do (
    if defined SRV%%i_Name (
        set "GW_DISP=!SRV%%i_Gateway!"
        if "!GW_DISP!"=="" set "GW_DISP=%DEF_GW%"
        echo  [%%i] !SRV%%i_Name! ^(IP: !SRV%%i_IP!, GW: !GW_DISP!^)
    )
)
echo  [99] Exit
echo ===============================================================================
set "SEL="
set /p "SEL=Enter server number [or 99 to exit]: "

if "%SEL%"=="99" goto :end

:: Validate that the selected server actually exists in network.conf
if not defined SRV%SEL%_Name (
    echo.
    echo [ERROR] Invalid selection "%SEL%". That server is not defined in %CONFFILE%.
    pause
    goto :SERVER_MENU
)

:: Dynamically pull the selected server's values
set "CHOSEN_NAME=!SRV%SEL%_Name!"
set "IP=!SRV%SEL%_IP!"
set "CHOSEN_MASK=!SRV%SEL%_Mask!"
set "CHOSEN_GW=!SRV%SEL%_Gateway!"
set "CHOSEN_DNS=!SRV%SEL%_DNS!"
set "CHOSEN_CONF=!SRV%SEL%_Config!"

:: Fallback to defaults if mask, gateway, or DNS were omitted for this server
if "%CHOSEN_MASK%"=="" set "CHOSEN_MASK=%DEF_MASK%"
if "%CHOSEN_GW%"=="" set "CHOSEN_GW=%DEF_GW%"
if "%CHOSEN_DNS%"=="" set "CHOSEN_DNS=%DEF_DNS%"

:APPLY
echo.
echo ========================================================
echo Applying Physical NIC Configuration for: %CHOSEN_NAME%
echo   Adapter         : %ADAPTER%
echo   Static IP       : %IP%
echo   Subnet Mask     : %CHOSEN_MASK%
echo   Default Gateway : %CHOSEN_GW%
if defined CHOSEN_DNS if not "%CHOSEN_DNS%"=="" (
    echo   DNS Server      : %CHOSEN_DNS%
)
echo ========================================================
netsh interface ipv4 set address name="%ADAPTER%" static %IP% %CHOSEN_MASK% %CHOSEN_GW%

if defined CHOSEN_DNS if not "%CHOSEN_DNS%"=="" (
    echo Setting DNS server...
    netsh interface ipv4 set dns name="%ADAPTER%" static %CHOSEN_DNS% validate=no
)

echo.
echo Verifying Physical IP configuration:
netsh interface ipv4 show config "%ADAPTER%"

echo.
echo Disabling WinPE Firewall...
wpeutil DisableFirewall

echo.
echo Initializing WireGuard tunnel using profile: %CHOSEN_CONF%...
if exist "%CHOSEN_CONF%" (
    wireguard /installtunnelservice "%CD%\%CHOSEN_CONF%"
    echo WireGuard service installed and started successfully for %CHOSEN_NAME%.
) else (
    echo [ERROR] Specified config file "%CHOSEN_CONF%" not found in %CD%!
    goto :end
)

echo.
echo Waiting 5 seconds for tunnel interface to initialize...
ping 127.0.0.1 -n 6 >nul

if defined TUNNEL (
    echo.
    echo Testing ping to WireGuard Concentrator [!TUNNEL!]...
    ping "!TUNNEL!"
)

if defined BACKUP (
    echo.
    echo Testing connection across WireGuard to Backup Network [!BACKUP!]...
    ping "!BACKUP!"
)

:end
echo.
echo ===============================================================================
echo  Bare-Metal Recovery Setup Completed Successfully!
echo ===============================================================================
echo  WireGuard Profile : %CHOSEN_CONF%
echo  Physical Interface: %ADAPTER% (%IP%)
echo.
echo  Available Options:
echo    [1] Launch Rubrik Recovery Assistant (Rubrik-Restore.bat)
echo    [2] Exit to Command Prompt (run Rubrik-Restore.bat manually when ready)
echo.
set /p "NEXT_ACTION=Select an option [1]: "
if "%NEXT_ACTION%"=="" set "NEXT_ACTION=1"
if "%NEXT_ACTION%"=="1" (
    if exist "%~dp0Rubrik-Restore.bat" (
        call "%~dp0Rubrik-Restore.bat"
    ) else if exist "%CD%\Rubrik-Restore.bat" (
        call "%CD%\Rubrik-Restore.bat"
    )
)

endlocal
