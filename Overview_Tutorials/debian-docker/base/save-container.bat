@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Docker image name configuration
set DOCKER_IMAGE_NAME=debian-dev:latest

REM Extract image name without tag for container name
for /f "tokens=1 delims=:" %%i in ("%DOCKER_IMAGE_NAME%") do set DOCKER_IMAGE_BASE=%%i
set DOCKER_CONTAINER_NAME=%DOCKER_IMAGE_BASE%-container

REM Set default image name and export filename for saved image
set CONTAINER_NAME=!DOCKER_CONTAINER_NAME!
set IMAGE_NAME=debian-dev
set IMAGE_TAG=latest
set EXPORT_FILENAME=debian-dev.tgz

REM Check if container exists
set CONTAINER_EXISTS=0
for /f "tokens=*" %%i in ('docker ps -a --filter "name=%CONTAINER_NAME%" --format "{{.Names}}"') do (
    if "%%i"=="%CONTAINER_NAME%" set CONTAINER_EXISTS=1
)

if !CONTAINER_EXISTS! equ 0 (
    echo.
    echo [ERROR] Container '!CONTAINER_NAME!' does not exist!
    echo Please start the container first using start-container.bat
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Saving Docker Container to Image
echo ========================================
echo.
echo Container: !CONTAINER_NAME!
echo Image: %IMAGE_NAME%:%IMAGE_TAG%
echo Export file: %EXPORT_FILENAME%
echo.

REM Check if container is running
set CONTAINER_RUNNING=0
for /f "tokens=*" %%i in ('docker ps --filter "name=%CONTAINER_NAME%" --format "{{.Names}}"') do (
    if "%%i"=="%CONTAINER_NAME%" set CONTAINER_RUNNING=1
)

if !CONTAINER_RUNNING! equ 1 (
    echo.
    echo [ERROR] Container '!CONTAINER_NAME!' is currently running!
    echo.
    echo Please stop the container before saving it to ensure a consistent state.
    echo You can stop it using: docker stop !CONTAINER_NAME!
    echo or use stop-container.bat if available.
    echo.
    pause
    exit /b 1
)

echo [INFO] Container is stopped. Committing current state...

REM Commit container to image
echo.
echo Step 1: Committing container to image...
docker commit !CONTAINER_NAME! %IMAGE_NAME%:%IMAGE_TAG%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to commit container to image!
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] Container committed to image: %IMAGE_NAME%:%IMAGE_TAG%
echo.

REM Check if export file already exists
if exist "%EXPORT_FILENAME%" (
    echo.
    echo [ERROR] Export file '%EXPORT_FILENAME%' already exists!
    echo.
    echo Please remove or rename the existing file before saving.
    echo You can remove it using: del "%EXPORT_FILENAME%"
    echo.
    pause
    exit /b 1
)

REM Save image directly to compressed tgz file
echo Step 2: Saving image directly to compressed tgz file...
echo This may take several minutes depending on image size...
echo.

REM Use a temporary tar file in current directory, then compress and remove it
set TEMP_TAR=docker-save-temp-%RANDOM%.tar
docker save %IMAGE_NAME%:%IMAGE_TAG% -o "%TEMP_TAR%"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to save image!
    echo.
    if exist "%TEMP_TAR%" del "%TEMP_TAR%"
    pause
    exit /b 1
)

REM Check if tar file was created
if not exist "%TEMP_TAR%" (
    echo.
    echo [ERROR] Image save failed - no output file created!
    echo.
    pause
    exit /b 1
)

REM Compress directly to tgz using tar, then remove temp file
tar -czf "%EXPORT_FILENAME%" "%TEMP_TAR%"
set COMPRESS_ERROR=!errorlevel!

REM Clean up temporary tar file
if exist "%TEMP_TAR%" (
    del "%TEMP_TAR%"
)

if !COMPRESS_ERROR! neq 0 (
    echo.
    echo [ERROR] Failed to compress image to tgz file!
    echo.
    echo The image was saved but compression failed.
    echo You may need to compress it manually or check if tar.exe is available.
    echo.
    pause
    exit /b 1
)

REM Check if compressed file was created and get its size
if exist "%EXPORT_FILENAME%" (
    for %%A in ("%EXPORT_FILENAME%") do set FILE_SIZE=%%~zA
    set /a FILE_SIZE_MB=!FILE_SIZE! / 1048576
    echo.
    echo [SUCCESS] Image saved and compressed successfully!
    echo.
    echo Export file: %EXPORT_FILENAME%
    echo File size: !FILE_SIZE_MB! MB
    echo Location: %CD%\%EXPORT_FILENAME%
    echo.
    echo You can now transfer this file to another machine and use load-container.bat to load it.
    echo.
) else (
    echo.
    echo [ERROR] Compressed export file was not created!
    echo.
    pause
    exit /b 1
)

pause
