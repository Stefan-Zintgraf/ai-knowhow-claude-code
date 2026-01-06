@echo off
setlocal enabledelayedexpansion

REM Check if container exists
docker ps -a --filter "name=debian-dev-container" --format "{{.Names}}" | findstr /C:"debian-dev-container" >nul
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Container 'debian-dev-container' does not exist!
    echo.
    pause
    exit /b 1
)

REM Check if container is already stopped
docker ps --filter "name=debian-dev-container" --format "{{.Names}}" | findstr /C:"debian-dev-container" >nul
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Container 'debian-dev-container' is already stopped!
    echo.
    pause
    exit /b 0
)

REM Stop the container
echo.
echo Stopping container 'debian-dev-container'...
docker stop debian-dev-container

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to stop container!
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Container 'debian-dev-container' stopped successfully.
echo.

pause


