@echo off
setlocal enabledelayedexpansion

set "CONFFILE=network.conf"

if not exist "%CONFFILE%" (
    echo [ERROR] Configuration file %CONFFILE% not found!
    goto :end
)

:: Parse global network variables and server profiles from network.conf
for /f "tokens=1,2 delims==" %%a in ('type "%CONFFILE%"') do (
    if "%%a"=="Adapter" set "ADAPTER=%%b"
    if "%%a"=="Mask" set "MASK=%%b"
    if "%%a"=="Gateway" set "GATEWAY=%%b"
    if "%%a"=="Tunnel" set "TUNNEL=%%b"
    if "%%a"=="Backup" set "BACKUP=%%b"
    if "%%a"=="SRV1_Name" set "SRV1_Name=%%b"
    if "%%a"=="SRV1_IP" set "SRV1_IP=%%b"
    if "%%a"=="SRV1_Config" set "SRV1_Config=%%b"
    if "%%a"=="SRV2_Name" set "SRV2_Name=%%b"
    if "%%a"=="SRV2_IP" set "SRV2_IP=%%b"
    if "%%a"=="SRV2_Config" set "SRV2_Config=%%b"
    if "%%a"=="SRV3_Name" set "SRV3_Name=%%b"
    if "%%a"=="SRV3_IP" set "SRV3_IP=%%b"
    if "%%a"=="SRV3_Config" set "SRV3_Config=%%b"
)

echo ========================================================
echo Base Network Parameters loaded from %CONFFILE%:
echo   Default Adapter : %ADAPTER%
echo   Mask            : %MASK%
echo   Gateway         : %GATEWAY%
echo ========================================================
echo.
echo Available network interfaces on this system:
netsh interface ipv4 show interface
echo.

set /p "CHOICE=Do you want to use the default adapter name '%ADAPTER%'? (Y/N): "
if /i "%CHOICE%"=="N" (
    echo.
    set /p "ADAPTER=Enter the correct adapter name from the list above: "
)

:SERVER_MENU
cls
echo ========================================================
echo                 Select Target Physical Server             
echo ========================================================
echo  [1] %SRV1_Name% (IP: %SRV1_IP%)
echo  [2] %SRV2_Name% (IP: %SRV2_IP%)
echo  [3] %SRV3_Name% (IP: %SRV3_IP%)
echo  [4] Exit
echo ========================================================
set "SEL="
set /p "SEL=Enter server selection [1-4]: "

if "%SEL%"=="4" goto :end
if "%SEL%"=="3" (
    set "IP=%SRV3_IP%"
    set "CHOSEN_CONF=%SRV3_Config%"
    set "CHOSEN_NAME=%SRV3_Name%"
    goto :APPLY
)
if "%SEL%"=="2" (
    set "IP=%SRV2_IP%"
    set "CHOSEN_CONF=%SRV2_Config%"
    set "CHOSEN_NAME=%SRV2_Name%"
    goto :APPLY
)
if "%SEL%"=="1" (
    set "IP=%SRV1_IP%"
    set "CHOSEN_CONF=%SRV1_Config%"
    set "CHOSEN_NAME=%SRV1_Name%"
    goto :APPLY
)

echo.
echo [ERROR] Invalid selection. Please choose 1, 2, 3, or 4.
pause
goto :SERVER_MENU

:APPLY
echo.
echo Applying configuration for %CHOSEN_NAME%...
echo   Adapter : %ADAPTER%
echo   IP      : %IP%
echo   Mask    : %MASK%
echo   Gateway : %GATEWAY%
netsh interface ipv4 set address name="%ADAPTER%" static %IP% %MASK% %GATEWAY%

echo.
echo Verifying IP configuration:
netsh interface ipv4 show config "%ADAPTER%"

echo.
echo Disabling WinPE Firewall...
wpeutil DisableFirewall

echo.
echo Initializing WireGuard tunnel using %CHOSEN_CONF%...
if exist "%CHOSEN_CONF%" (
    wireguard /installtunnelservice "%CD%\%CHOSEN_CONF%"
    echo WireGuard service installed and started successfully for %CHOSEN_NAME%.
) else (
    echo [ERROR] Specified config file "%CHOSEN_CONF%" not found in directory!
)

echo.
echo Waiting for tunnel interface to initialize...
ping 127.0.0.1 -n 10 >nul

echo.
echo Testing connection to backup network (%BACKUP%)...
ping "%BACKUP%"

:end
echo.
pause
endlocal