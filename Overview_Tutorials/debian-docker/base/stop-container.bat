@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Docker image name configuration
set DOCKER_IMAGE_NAME=debian-dev:latest

REM Extract image name without tag for container name
for /f "tokens=1 delims=:" %%i in ("%DOCKER_IMAGE_NAME%") do set DOCKER_IMAGE_BASE=%%i
set DOCKER_CONTAINER_NAME=%DOCKER_IMAGE_BASE%-container

REM Check if container exists
docker ps -a --filter "name=!DOCKER_CONTAINER_NAME!" --format "{{.Names}}" | findstr /C:"!DOCKER_CONTAINER_NAME!" >nul
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Container '!DOCKER_CONTAINER_NAME!' does not exist!
    echo.
    pause
    exit /b 1
)

REM Check if container is already stopped
docker ps --filter "name=!DOCKER_CONTAINER_NAME!" --format "{{.Names}}" | findstr /C:"!DOCKER_CONTAINER_NAME!" >nul
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Container '!DOCKER_CONTAINER_NAME!' is already stopped!
    echo.
    pause
    exit /b 0
)

REM Gracefully stop xrdp services before stopping the container
echo.
echo Stopping RDP services gracefully...
docker exec !DOCKER_CONTAINER_NAME! bash -c "pkill -TERM xrdp-sesman 2>/dev/null || true" >nul 2>&1
docker exec !DOCKER_CONTAINER_NAME! bash -c "pkill -TERM xrdp 2>/dev/null || true" >nul 2>&1
timeout /t 2 /nobreak >nul

REM Stop the container
echo Stopping container '!DOCKER_CONTAINER_NAME!'...
docker stop !DOCKER_CONTAINER_NAME!

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to stop container!
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Container '!DOCKER_CONTAINER_NAME!' stopped successfully.
echo.

pause


