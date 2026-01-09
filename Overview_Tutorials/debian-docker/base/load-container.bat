@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Docker image name configuration
set DOCKER_IMAGE_NAME=debian-dev:latest

REM Extract image name without tag for container name
for /f "tokens=1 delims=:" %%i in ("%DOCKER_IMAGE_NAME%") do set DOCKER_IMAGE_BASE=%%i
set DOCKER_CONTAINER_NAME=%DOCKER_IMAGE_BASE%-container

REM Set default image name and export filename for loaded image
set IMAGE_NAME=debian-dev
set IMAGE_TAG=latest
set EXPORT_FILENAME=debian-dev.tgz

REM Check if export file exists
if not exist "%EXPORT_FILENAME%" (
    echo.
    echo [ERROR] Export file '%EXPORT_FILENAME%' not found!
    echo.
    echo Please make sure the file exists in the current directory:
    echo   %CD%\%EXPORT_FILENAME%
    echo.
    echo If the file has a different name, please rename it to '%EXPORT_FILENAME%'
    echo or modify this script to use the correct filename.
    echo.
    pause
    exit /b 1
)

REM Get file size for display
REM Use PowerShell to avoid 32-bit overflow in CMD arithmetic for large files
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Item -LiteralPath '%EXPORT_FILENAME%').Length"`) do set FILE_SIZE=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[math]::Round((Get-Item -LiteralPath '%EXPORT_FILENAME%').Length / 1MB, 2)"`) do set FILE_SIZE_MB=%%A

echo.
echo ========================================
echo Loading Docker Image from File
echo ========================================
echo.
echo Export file: %EXPORT_FILENAME%
echo File size: !FILE_SIZE_MB! MB
echo Image: %IMAGE_NAME%:%IMAGE_TAG%
echo.

REM Fail fast if Docker daemon isn't reachable (otherwise image checks will lie)
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Docker does not appear to be running or the current Docker context is not reachable.
    echo.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

REM Check if image already exists (robust on Windows; avoids docker inspect quirks)
set IMAGE_ID=
for /f "usebackq delims=" %%I in (`docker images -q "%IMAGE_NAME%:%IMAGE_TAG%" 2^>nul`) do set IMAGE_ID=%%I
if not "%IMAGE_ID%"=="" goto :image_already_exists

REM Image does not exist, continue with loading
goto :image_not_found

:image_already_exists
echo.
echo [ERROR] Image '%IMAGE_NAME%:%IMAGE_TAG%' already exists!
echo.
echo Please remove the existing image first if you want to load a new one.
echo You can remove it using: docker rmi %IMAGE_NAME%:%IMAGE_TAG%
echo.
echo Or use a different image name/tag by modifying this script.
echo.
pause
exit /b 1

:image_not_found
REM Load image from file:
REM - docker load can handle gzipped tar files (.tgz) directly
REM - If direct load fails, the file might be a tgz containing an inner tar, so we extract and load that
echo Step 1: Loading image from compressed tgz file...
echo This may take a few minutes depending on file size...
echo.
docker load -i "%EXPORT_FILENAME%"

if %errorlevel% neq 0 goto :load_fallback
goto :load_ok

:load_fallback
echo.
echo [INFO] Direct load failed; attempting to extract an embedded .tar and load that...
echo.

REM Find the first embedded .tar inside the archive
set INNER_TAR=
for /f "usebackq delims=" %%F in (`tar -tf "%EXPORT_FILENAME%" ^| findstr /R "\.tar$"`) do (
    set INNER_TAR=%%F
    goto :have_inner_tar
)

echo [ERROR] Could not find an embedded .tar inside '%EXPORT_FILENAME%'.
echo.
echo This usually means the file is not a Docker image export created by 'docker save'.
echo.
pause
exit /b 1

:have_inner_tar
REM Normalize path separators for Windows commands
set INNER_TAR_WIN=!INNER_TAR:/=\!

REM Clean up any previous extracted tar
if exist "!INNER_TAR_WIN!" del /f /q "!INNER_TAR_WIN!" >nul 2>&1

REM Extract just the embedded tar
tar -xzf "%EXPORT_FILENAME%" "!INNER_TAR!" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to extract embedded tar '!INNER_TAR!' from '%EXPORT_FILENAME%'.
    echo.
    pause
    exit /b 1
)

REM Load image from extracted tar
echo Step 2: Loading image from extracted tar...
echo.
docker load -i "!INNER_TAR_WIN!"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to load image from extracted tar '!INNER_TAR_WIN!'.
    echo.
    pause
    exit /b 1
)

REM Clean up extracted tar after successful load
if exist "!INNER_TAR_WIN!" (
    del /f /q "!INNER_TAR_WIN!" >nul 2>&1
)

:load_ok

echo.
echo [SUCCESS] Image loaded successfully!
echo.

REM Verify the image was loaded
docker images --format "{{.Repository}}:{{.Tag}}" | findstr /C:"%IMAGE_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo Available images:
    docker images | findstr "%IMAGE_NAME%"
    echo.
    echo You can now use this image to create a container.
    echo.
    echo Example: Use start-container.bat and modify it to use '%IMAGE_NAME%:%IMAGE_TAG%'
    echo          instead of '!DOCKER_IMAGE_NAME!'
    echo.
) else (
    echo [WARNING] Image verification failed, but load command succeeded.
    echo Please check 'docker images' to verify the image was loaded.
    echo.
)

pause
