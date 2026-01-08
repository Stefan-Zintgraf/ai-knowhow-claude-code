@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Set default image name and export filename
set IMAGE_NAME=debian-dev-with-apps
set IMAGE_TAG=latest
set EXPORT_FILENAME=debian-dev-with-apps.tgz
set TEMP_TAR_FILENAME=debian-dev-with-apps.tar

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
for %%A in ("%EXPORT_FILENAME%") do set FILE_SIZE=%%~zA
set /a FILE_SIZE_MB=!FILE_SIZE! / 1048576

echo.
echo ========================================
echo Loading Docker Image from File
echo ========================================
echo.
echo Export file: %EXPORT_FILENAME%
echo File size: !FILE_SIZE_MB! MB
echo Image: %IMAGE_NAME%:%IMAGE_TAG%
echo.

REM Check if image already exists
docker images --format "{{.Repository}}:{{.Tag}}" | findstr /C:"%IMAGE_NAME%:%IMAGE_TAG%" >nul 2>&1
if %errorlevel% equ 0 (
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
)

REM Decompress tgz file to tar
echo Step 1: Decompressing tgz file...
echo This may take a few minutes depending on file size...
echo.

REM Clean up any existing temp tar file
if exist "%TEMP_TAR_FILENAME%" (
    del "%TEMP_TAR_FILENAME%"
)

cd /d "%CD%"
tar -xzf "%EXPORT_FILENAME%"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to decompress tgz file!
    echo.
    echo Please check:
    echo   1. The file is not corrupted
    echo   2. You have enough disk space
    echo   3. tar.exe is available (Windows 10+)
    echo.
    pause
    exit /b 1
)

REM Check if tar file was extracted
if not exist "%TEMP_TAR_FILENAME%" (
    echo.
    echo [ERROR] Tar file was not extracted from tgz!
    echo.
    pause
    exit /b 1
)

REM Load image from tar file
echo Step 2: Loading image from tar file...
echo This may take a few minutes depending on file size...
echo.
docker load -i "%TEMP_TAR_FILENAME%"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to load image from tar file!
    echo.
    echo Please check:
    echo   1. The file is not corrupted
    echo   2. You have enough disk space
    echo   3. Docker is running properly
    echo.
    REM Clean up temp tar file
    if exist "%TEMP_TAR_FILENAME%" (
        del "%TEMP_TAR_FILENAME%"
    )
    pause
    exit /b 1
)

REM Clean up temporary tar file after successful load
if exist "%TEMP_TAR_FILENAME%" (
    del "%TEMP_TAR_FILENAME%"
    echo [INFO] Temporary tar file removed.
    echo.
)

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
    echo          instead of 'debian-dev:latest'
    echo.
) else (
    echo [WARNING] Image verification failed, but load command succeeded.
    echo Please check 'docker images' to verify the image was loaded.
    echo.
)

pause
