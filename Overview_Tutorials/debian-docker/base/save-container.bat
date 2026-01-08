@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Set default image name and export filename
set CONTAINER_NAME=debian-dev-container
set IMAGE_NAME=debian-dev-with-apps
set IMAGE_TAG=latest
set EXPORT_FILENAME=debian-dev-with-apps.tgz
set TEMP_TAR_FILENAME=debian-dev-with-apps.tar

REM Check if container exists
set CONTAINER_EXISTS=0
for /f "tokens=*" %%i in ('docker ps -a --filter "name=%CONTAINER_NAME%" --format "{{.Names}}"') do (
    if "%%i"=="%CONTAINER_NAME%" set CONTAINER_EXISTS=1
)

if !CONTAINER_EXISTS! equ 0 (
    echo.
    echo [ERROR] Container '%CONTAINER_NAME%' does not exist!
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
echo Container: %CONTAINER_NAME%
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
    echo [ERROR] Container '%CONTAINER_NAME%' is currently running!
    echo.
    echo Please stop the container before saving it to ensure a consistent state.
    echo You can stop it using: docker stop %CONTAINER_NAME%
    echo or use stop-container.bat if available.
    echo.
    pause
    exit /b 1
)

echo [INFO] Container is stopped. Committing current state...

REM Commit container to image
echo.
echo Step 1: Committing container to image...
docker commit %CONTAINER_NAME% %IMAGE_NAME%:%IMAGE_TAG%

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
    echo [WARNING] Export file '%EXPORT_FILENAME%' already exists!
    echo.
    set /p OVERWRITE="Do you want to overwrite it? (Y/N): "
    if /i not "!OVERWRITE!"=="Y" (
        echo.
        echo Operation cancelled.
        echo.
        pause
        exit /b 0
    )
    echo.
    echo Removing old export file...
    del "%EXPORT_FILENAME%"
)

REM Clean up any existing temp tar file
if exist "%TEMP_TAR_FILENAME%" (
    del "%TEMP_TAR_FILENAME%"
)

REM Save image to tar file
echo Step 2: Saving image to tar file...
docker save -o "%TEMP_TAR_FILENAME%" %IMAGE_NAME%:%IMAGE_TAG%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to save image to tar file!
    echo.
    pause
    exit /b 1
)

REM Check if tar file was created
if not exist "%TEMP_TAR_FILENAME%" (
    echo.
    echo [ERROR] Tar file was not created!
    echo.
    pause
    exit /b 1
)

REM Compress tar file to tgz
echo Step 3: Compressing tar file to tgz...
cd /d "%CD%"
tar -czf "%EXPORT_FILENAME%" "%TEMP_TAR_FILENAME%"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to compress tar file!
    echo.
    echo The tar file '%TEMP_TAR_FILENAME%' was created but compression failed.
    echo You may need to compress it manually or check if tar.exe is available.
    echo.
    pause
    exit /b 1
)

REM Remove temporary tar file after successful compression
if exist "%EXPORT_FILENAME%" (
    del "%TEMP_TAR_FILENAME%"
    echo [INFO] Temporary tar file removed.
    echo.
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
