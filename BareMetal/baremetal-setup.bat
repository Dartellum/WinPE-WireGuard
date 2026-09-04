@echo off
    setlocal enabledelayedexpansion

    set "CONFFILE=network.conf"

    if not exist "%CONFFILE%" (
        echo [ERROR] Configuration file %CONFFILE% not found in %CD%!
        goto :end
    )

    :: Parse global network variables and server profiles from network.conf
    for /f "tokens=1,2 delims==" %%a in ('type "%CONFFILE%"') do (
        set "KEY=%%a"
        set "VAL=%%b"
        for /f "tokens=* delims= " %%k in ("!KEY!") do set "KEY=%%k"
        for /f "tokens=* delims= " %%v in ("!VAL!") do set "VAL=%%v"

        if "!KEY!"=="Adapter" set "ADAPTER=!VAL!"
        if "!KEY!"=="Default_Mask" set "DEF_MASK=!VAL!"
        if "!KEY!"=="Default_Gateway" set "DEF_GW=!VAL!"
        if "!KEY!"=="Mask" if not defined DEF_MASK set "DEF_MASK=!VAL!"
        if "!KEY!"=="Gateway" if not defined DEF_GW set "DEF_GW=!VAL!"
        if "!KEY!"=="Tunnel" set "TUNNEL=!VAL!"
        if "!KEY!"=="Backup" set "BACKUP=!VAL!"

        :: Server 1
        if "!KEY!"=="SRV1_Name" set "SRV1_Name=!VAL!"
        if "!KEY!"=="SRV1_IP" set "SRV1_IP=!VAL!"
        if "!KEY!"=="SRV1_Mask" set "SRV1_Mask=!VAL!"
        if "!KEY!"=="SRV1_Gateway" set "SRV1_Gateway=!VAL!"
        if "!KEY!"=="SRV1_Config" set "SRV1_Config=!VAL!"

        :: Server 2
        if "!KEY!"=="SRV2_Name" set "SRV2_Name=!VAL!"
        if "!KEY!"=="SRV2_IP" set "SRV2_IP=!VAL!"
        if "!KEY!"=="SRV2_Mask" set "SRV2_Mask=!VAL!"
        if "!KEY!"=="SRV2_Gateway" set "SRV2_Gateway=!VAL!"
        if "!KEY!"=="SRV2_Config" set "SRV2_Config=!VAL!"

        :: Server 3
        if "!KEY!"=="SRV3_Name" set "SRV3_Name=!VAL!"
        if "!KEY!"=="SRV3_IP" set "SRV3_IP=!VAL!"
        if "!KEY!"=="SRV3_Mask" set "SRV3_Mask=!VAL!"
        if "!KEY!"=="SRV3_Gateway" set "SRV3_Gateway=!VAL!"
        if "!KEY!"=="SRV3_Config" set "SRV3_Config=!VAL!"
    )

    echo ========================================================
    echo   WinPE WireGuard Bare-Metal Automation
    echo ========================================================
    echo Base Network Parameters loaded from %CONFFILE%:
    echo   Default Adapter : %ADAPTER%
    echo   Default Mask    : %DEF_MASK%
    echo   Default Gateway : %DEF_GW%
    echo   Tunnel Endpoint : %TUNNEL%
    echo   Backup Target   : %BACKUP%
    echo ========================================================
    echo.
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
    if defined SRV1_Name echo  [1] %SRV1_Name% ^(IP: %SRV1_IP%, GW: %SRV1_Gateway%^)
    if defined SRV2_Name echo  [2] %SRV2_Name% ^(IP: %SRV2_IP%, GW: %SRV2_Gateway%^)
    if defined SRV3_Name echo  [3] %SRV3_Name% ^(IP: %SRV3_IP%, GW: %SRV3_Gateway%^)
    echo  [4] Exit
    echo ===============================================================================
    set "SEL="
    set /p "SEL=Enter server selection [1-4]: "

    if "%SEL%"=="4" goto :end

    if "%SEL%"=="1" if defined SRV1_Name (
        set "CHOSEN_NAME=%SRV1_Name%"
        set "IP=%SRV1_IP%"
        set "CHOSEN_MASK=%SRV1_Mask%"
        set "CHOSEN_GW=%SRV1_Gateway%"
        set "CHOSEN_CONF=%SRV1_Config%"
        goto :APPLY
    )
    if "%SEL%"=="2" if defined SRV2_Name (
        set "CHOSEN_NAME=%SRV2_Name%"
        set "IP=%SRV2_IP%"
        set "CHOSEN_MASK=%SRV2_Mask%"
        set "CHOSEN_GW=%SRV2_Gateway%"
        set "CHOSEN_CONF=%SRV2_Config%"
        goto :APPLY
    )
    if "%SEL%"=="3" if defined SRV3_Name (
        set "CHOSEN_NAME=%SRV3_Name%"
        set "IP=%SRV3_IP%"
        set "CHOSEN_MASK=%SRV3_Mask%"
        set "CHOSEN_GW=%SRV3_Gateway%"
        set "CHOSEN_CONF=%SRV3_Config%"
        goto :APPLY
    )

    echo.
    echo [ERROR] Invalid selection.
    pause
    goto :SERVER_MENU

    :APPLY
    :: Fallback to default mask and gateway if not specifically set per server
    if "%CHOSEN_MASK%"=="" set "CHOSEN_MASK=%DEF_MASK%"
    if "%CHOSEN_GW%"=="" set "CHOSEN_GW=%DEF_GW%"

    echo.
    echo ========================================================
    echo Applying Physical NIC Configuration for: %CHOSEN_NAME%
    echo   Adapter         : %ADAPTER%
    echo   Static IP       : %IP%
    echo   Subnet Mask     : %CHOSEN_MASK%
    echo   Default Gateway : %CHOSEN_GW%
    echo ========================================================
    netsh interface ipv4 set address name="%ADAPTER%" static %IP% %CHOSEN_MASK% %CHOSEN_GW%

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
        echo Testing ping to WireGuard Concentrator (%TUNNEL%)...
        ping "%TUNNEL%"
    )

    if defined BACKUP (
        echo.
        echo Testing connection across WireGuard to Backup Network (%BACKUP%)...
        ping "%BACKUP%"
    )

    :end
    echo.
    echo Configuration sequence completed.
    pause
    endlocal
