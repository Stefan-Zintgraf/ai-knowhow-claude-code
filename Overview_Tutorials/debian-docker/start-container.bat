@echo off
setlocal enabledelayedexpansion

REM Set RDP port mapping (host port -> container port 3389)
set RDP_PORT=11389

REM Check if container exists
for /f "tokens=*" %%i in ('docker ps -a --filter "name=debian-dev-container" --format "{{.Names}}"') do set CONTAINER_NAME=%%i
if not defined CONTAINER_NAME (
    echo.
    echo Container 'debian-dev-container' does not exist. Creating it...
    echo.
    docker run -d -p %RDP_PORT%:3389 --user root --name debian-dev-container debian-dev:latest
    REM Verify container was created (docker run might return non-zero even on success)
    timeout /t 1 /nobreak >nul
    set CONTAINER_NAME=
    for /f "tokens=*" %%i in ('docker ps -a --filter "name=debian-dev-container" --format "{{.Names}}"') do set CONTAINER_NAME=%%i
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
for /f "tokens=*" %%i in ('docker ps --filter "name=debian-dev-container" --format "{{.Names}}"') do set CONTAINER_RUNNING=%%i
if defined CONTAINER_RUNNING (
    echo.
    echo [WARNING] Container 'debian-dev-container' is already running!
    echo.
    echo Checking RDP service status...
    docker exec debian-dev-container bash -c "ps aux | grep '[x]rdp' | grep -v grep" >nul 2>&1
    set RDP_RUNNING=0
    if %errorlevel% equ 0 (
        set RDP_RUNNING=1
        echo RDP service is running.
    ) else (
        echo RDP service is not running. The container may need to be restarted.
        echo.
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
    pause
    exit /b 0
)

REM Start the container
echo.
echo Starting container 'debian-dev-container'...
docker start debian-dev-container

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
docker exec debian-dev-container bash -c "ps aux | grep '[x]rdp' | grep -v grep" >nul 2>&1
if %errorlevel% equ 0 (
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
    echo Please check the logs with: docker logs debian-dev-container
    echo.
)

pause
