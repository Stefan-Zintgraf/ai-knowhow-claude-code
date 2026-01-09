@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Docker image name configuration
set DOCKER_IMAGE_NAME=debian-dev:latest

REM Extract image name without tag for container name
for /f "tokens=1 delims=:" %%i in ("%DOCKER_IMAGE_NAME%") do set DOCKER_IMAGE_BASE=%%i
set DOCKER_CONTAINER_NAME=%DOCKER_IMAGE_BASE%-container

REM Set RDP port mapping (host port -> container port 3389)
set RDP_PORT=11389
REM Set VNC port mapping (host port -> container port 5901)
set VNC_PORT=15901
REM Set SSH port mapping (host port -> container port 22)
set SSH_PORT=2222

REM Read VPN_NETWORK from .env file (if it exists)
set VPN_NETWORK=
if exist ".env" (
    for /f "usebackq eol=# tokens=1,2 delims==" %%a in (".env") do (
        if /i "%%a"=="VPN_NETWORK" set "VPN_NETWORK=%%b"
    )
)

REM VNC checking/starting is currently disabled
REM set USE_VNC=1

REM Check if container exists
for /f "tokens=*" %%i in ('docker ps -a --filter "name=!DOCKER_CONTAINER_NAME!" --format "{{.Names}}"') do set CONTAINER_NAME=%%i
if not defined CONTAINER_NAME (
    echo.
    echo Container '!DOCKER_CONTAINER_NAME!' does not exist. Creating it...
    echo.
    REM Build docker run command with VPN support if configured
    REM Add NET_ADMIN capability to allow VPN routing configuration
    set DOCKER_RUN_CMD=docker run -d -p %RDP_PORT%:3389 -p %VNC_PORT%:5901 -p %SSH_PORT%:22 --user root --cap-add=NET_ADMIN --name !DOCKER_CONTAINER_NAME! --add-host=host.docker.internal:host-gateway
    if not "!VPN_NETWORK!"=="" (
        set DOCKER_RUN_CMD=!DOCKER_RUN_CMD! -e VPN_NETWORK=!VPN_NETWORK!
        echo VPN routing enabled for network: !VPN_NETWORK!
    )
    set DOCKER_RUN_CMD=!DOCKER_RUN_CMD! !DOCKER_IMAGE_NAME!
    !DOCKER_RUN_CMD!
    REM Verify container was created (docker run might return non-zero even on success)
    timeout /t 1 /nobreak >nul
    set CONTAINER_NAME=
    for /f "tokens=*" %%i in ('docker ps -a --filter "name=!DOCKER_CONTAINER_NAME!" --format "{{.Names}}"') do set CONTAINER_NAME=%%i
    if not defined CONTAINER_NAME (
        echo [ERROR] Failed to create container!
        echo.
        pause
        exit /b 1
    )
    echo Container created successfully.
    echo.
)

REM Check if container is already running
set CONTAINER_RUNNING=
for /f "tokens=*" %%i in ('docker ps --filter "name=!DOCKER_CONTAINER_NAME!" --format "{{.Names}}"') do set CONTAINER_RUNNING=%%i
if defined CONTAINER_RUNNING (
    echo.
    echo [WARNING] Container '!DOCKER_CONTAINER_NAME!' is already running!
    echo.
    echo Checking RDP service status...
    docker exec !DOCKER_CONTAINER_NAME! bash -c "ps aux | grep '[x]rdp' | grep -v grep" >nul 2>&1
    set RDP_RUNNING=0
    if %errorlevel% equ 0 (
        set RDP_RUNNING=1
        echo RDP service is running.
    ) else (
        echo RDP service is not running. The container may need to be restarted.
        echo.
    )
    
    if defined USE_VNC (    
        echo Checking VNC service status...
        docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'vncserver -list 2>&1 | grep -q \":1\"'" >nul 2>&1
        set VNC_RUNNING=0
        if %errorlevel% equ 0 (
            set VNC_RUNNING=1
            echo VNC service is running.
        ) else (
            echo VNC service is not running. Starting VNC server...
            docker exec !DOCKER_CONTAINER_NAME! bash -c "service dbus start" >nul 2>&1
            docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'mkdir -p ~/.vnc && if [ ! -f ~/.vnc/passwd ]; then echo dev | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd; fi'" >nul 2>&1
            docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'if [ ! -f ~/.vnc/xstartup ]; then echo \"#!/bin/sh\" > ~/.vnc/xstartup && echo \"unset SESSION_MANAGER\" >> ~/.vnc/xstartup && echo \"unset DBUS_SESSION_BUS_ADDRESS\" >> ~/.vnc/xstartup && echo \"[ -r \\\$HOME/.Xresources ] && xrdb \\\$HOME/.Xresources\" >> ~/.vnc/xstartup && echo \"startxfce4 &\" >> ~/.vnc/xstartup && chmod +x ~/.vnc/xstartup; fi'" >nul 2>&1
            docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'export USER=dev && export HOME=/home/dev && vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth -passwd ~/.vnc/passwd 2>&1'" >nul 2>&1
            timeout /t 2 /nobreak >nul
            docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'vncserver -list 2>&1 | grep -q \":1\"'" >nul 2>&1
            if %errorlevel% equ 0 (
                set VNC_RUNNING=1
                echo VNC server started successfully.
            ) else (
                echo [WARNING] Failed to start VNC server.
            )
        )
    )
     
    echo.
    if !RDP_RUNNING! equ 1 (
        echo Container is ready for RDP connection:
        echo   Address: localhost:%RDP_PORT%
        echo   Username: dev
        echo   Password: dev
        echo.
    ) else (
        echo [WARNING] RDP service may not be running properly.
        echo You may need to restart the container.
        echo.
    )
    if defined USE_VNC (
        if !VNC_RUNNING! equ 1 (
            echo Container is ready for VNC connection:
            echo   Address: localhost:%VNC_PORT%
            echo   Password: dev
            echo.
        ) else (
            echo [WARNING] VNC service may not be running properly.
            echo.
        )
    )
    echo Checking SSH service status...
    docker exec !DOCKER_CONTAINER_NAME! bash -c "ps aux | grep '[s]shd' | grep -v grep" >nul 2>&1
    set SSH_RUNNING=0
    if %errorlevel% equ 0 (
        set SSH_RUNNING=1
        echo SSH service is running.
    ) else (
        echo SSH service is not running.
    )
    echo.
    if !SSH_RUNNING! equ 1 (
        echo Container is ready for SSH connection:
        echo   Address: localhost:%SSH_PORT%
        echo   Username: dev
        echo   Password: dev
        echo.
    )
    pause
    exit /b 0
)

REM Start the container
echo.
echo Starting container '!DOCKER_CONTAINER_NAME!'...
docker start !DOCKER_CONTAINER_NAME!

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to start container!
    echo.
    pause
    exit /b 1
)

echo Container started successfully.
echo.

REM Wait a moment for container to fully start and RDP service to initialize
echo Waiting for RDP service to start...
timeout /t 3 /nobreak >nul

REM Check if RDP is running (the entrypoint should start it automatically)
docker exec !DOCKER_CONTAINER_NAME! bash -c "ps aux | grep '[x]rdp' | grep -v grep" >nul 2>&1
set RDP_RUNNING=0
if %errorlevel% equ 0 (
    set RDP_RUNNING=1
)

REM Start VNC server (if enabled)
if defined USE_VNC (
    echo Starting VNC server...
    docker exec !DOCKER_CONTAINER_NAME! bash -c "service dbus start" >nul 2>&1
    REM Use start_vnc.sh to set up VNC files (password and xstartup), then kill the blocking tail process and restart vncserver
    docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'export VNC_PASSWORD=dev && export VNC_RESOLUTION=1920x1080 && /usr/bin/start_vnc.sh > /tmp/vnc_setup.log 2>&1 & VNC_PID=$! && sleep 3 && kill $VNC_PID 2>&1 || pkill -f \"tail -f /dev/null\" 2>&1 || true'" >nul 2>&1
    docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'vncserver -kill :1 2>&1 || true; sleep 1; export USER=dev && export HOME=/home/dev && vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth -passwd ~/.vnc/passwd 2>&1'" >nul 2>&1
    timeout /t 3 /nobreak >nul

    REM Check if VNC is running
    docker exec !DOCKER_CONTAINER_NAME! bash -c "su - dev -c 'vncserver -list 2>&1 | grep -q \":1\"'" >nul 2>&1
    set VNC_RUNNING=0
    if %errorlevel% equ 0 (
        set VNC_RUNNING=1
    )
) else (
    set VNC_RUNNING=0
)

if !RDP_RUNNING! equ 1 (
    echo.
    echo [SUCCESS] Container and RDP service are running!
    echo.
    echo You can now connect via RDP:
    echo   Address: localhost:%RDP_PORT%
    echo   Username: dev
    echo   Password: dev
    echo.
) else (
    echo.
    echo [WARNING] Container started, but RDP service may not be running properly.
    echo The container entrypoint should start xrdp automatically.
    echo Please check the logs with: docker logs !DOCKER_CONTAINER_NAME!
    echo.
)

if defined USE_VNC (
    if !VNC_RUNNING! equ 1 (
        echo [SUCCESS] VNC service is running!
        echo.
        echo You can now connect via VNC:
        echo   Address: localhost:%VNC_PORT%
        echo   Password: dev
        echo.
    ) else (
        echo [WARNING] VNC service may not be running properly.
        echo.
    )
)

REM Check SSH server status (it should start automatically via entrypoint)
echo Checking SSH server status...
timeout /t 2 /nobreak >nul
docker exec !DOCKER_CONTAINER_NAME! bash -c "ps aux | grep '[s]shd' | grep -v grep" >nul 2>&1
set SSH_RUNNING=0
if %errorlevel% equ 0 (
    set SSH_RUNNING=1
)

if !SSH_RUNNING! equ 1 (
    echo [SUCCESS] SSH service is running!
    echo.
    echo You can now connect via SSH:
    echo   Address: localhost:%SSH_PORT%
    echo   Username: dev
    echo   Password: dev
    echo.
) else (
    echo [WARNING] SSH service may not be running properly.
    echo.
)

pause
