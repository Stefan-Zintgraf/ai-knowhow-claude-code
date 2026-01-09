@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

REM Docker image name configuration
set DOCKER_IMAGE_NAME=debian-dev:latest

REM Extract image name without tag for container name
for /f "tokens=1 delims=:" %%i in ("%DOCKER_IMAGE_NAME%") do set DOCKER_IMAGE_BASE=%%i
set DOCKER_CONTAINER_NAME=%DOCKER_IMAGE_BASE%-container

REM Parse command-line arguments
set FORCE_REBUILD=0
set NO_CACHE=
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="-r" (
    set FORCE_REBUILD=1
    set NO_CACHE=--no-cache
    shift
    goto parse_args
)
if /i "%~1"=="--rebuild" (
    set FORCE_REBUILD=1
    set NO_CACHE=--no-cache
    shift
    goto parse_args
)
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
shift
goto parse_args

:show_help
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   -r, --rebuild    Force a complete rebuild from scratch (removes existing image
echo                    and builds without cache)
echo   -h, --help       Show this help message
echo.
echo Examples:
echo   %~nx0              Build normally (prompts if image exists)
echo   %~nx0 -r           Force complete rebuild from scratch
echo   %~nx0 --rebuild    Force complete rebuild from scratch
echo.
pause
exit /b 0

:args_done

REM Check if .env file exists
if not exist ".env" (
    echo.
    echo [ERROR] .env file not found!
    echo.
    echo Please create a .env file based on .env.example:
    echo   copy .env.example .env
    echo.
    echo Then edit .env and set your desired username and password.
    echo.
    pause
    exit /b 1
)

REM Check if .env.example exists (for reference)
if not exist ".env.example" (
    echo [WARNING] .env.example file not found. Creating a default one...
    (
        echo # =============================================================================
        echo # Docker Build Configuration - Environment Variables Example
        echo # =============================================================================
        echo #
        echo # This file contains example environment variables for building the Debian
        echo # development Docker image.
        echo #
        echo # USAGE:
        echo #   1. Copy this file to .env:
        echo #        copy .env.example .env
        echo #
        echo #   2. Edit .env and set your desired values ^(credentials, etc.^)
        echo #
        echo #   3. Run build-docker-image.bat to build the Docker image
        echo #
        echo # SECURITY NOTE:
        echo #   The .env file is gitignored to keep your credentials out of version control.
        echo #   Never commit the .env file to a repository!
        echo #
        echo # =============================================================================
        echo # Required Variables
        echo # =============================================================================
        echo.
        echo DOCKER_USERNAME=dev
        echo DOCKER_PASSWORD=dev
        echo.
        echo # =============================================================================
        echo # Optional Variables
        echo # =============================================================================
        echo.
        echo # VNC_PASSWORD: VNC server password ^(optional^)
        echo # If not set, DOCKER_PASSWORD will be used as the VNC password
        echo # VNC_PASSWORD=dev
        echo.
        echo # VPN_NETWORK: VPN network CIDR for container access ^(optional^)
        echo # Set this to your OpenVPN network subnet to enable VPN routing in containers
        echo # Example: VPN_NETWORK=10.8.0.0/24
        echo # Leave empty or unset to disable VPN routing
        echo # VPN_NETWORK=
        echo.
    ) > .env.example
)

REM Read credentials from .env file
set DOCKER_USERNAME=
set DOCKER_PASSWORD=
set VNC_PASSWORD=

for /f "usebackq eol=# tokens=1,2 delims==" %%a in (".env") do (
    REM Read key-value pairs, skip comment lines (handled by eol=#)
    if /i "%%a"=="DOCKER_USERNAME" set "DOCKER_USERNAME=%%b"
    if /i "%%a"=="DOCKER_PASSWORD" set "DOCKER_PASSWORD=%%b"
    if /i "%%a"=="VNC_PASSWORD" set "VNC_PASSWORD=%%b"
)

REM Check if credentials were found
if "!DOCKER_USERNAME!"=="" (
    echo [ERROR] DOCKER_USERNAME not found in .env file!
    pause
    exit /b 1
)

if "!DOCKER_PASSWORD!"=="" (
    echo [ERROR] DOCKER_PASSWORD not found in .env file!
    pause
    exit /b 1
)

REM If VNC_PASSWORD is not set, use DOCKER_PASSWORD as fallback
if "!VNC_PASSWORD!"=="" (
    set "VNC_PASSWORD=!DOCKER_PASSWORD!"
)

REM Check if Docker image already exists
docker images !DOCKER_IMAGE_NAME! --format "{{.Repository}}:{{.Tag}}" 2>nul | findstr /C:"!DOCKER_IMAGE_NAME!" >nul
if !errorlevel! equ 0 (
    if !FORCE_REBUILD! equ 1 (
        REM Force rebuild: automatically remove existing image
        echo.
        echo [INFO] Force rebuild requested. Removing existing image and associated containers...
        echo.
        
        REM Find and stop all containers using this image
        for /f "tokens=*" %%c in ('docker ps -a --filter "ancestor=!DOCKER_IMAGE_NAME!" --format "{{.ID}}" 2^>nul') do (
            echo Stopping container %%c...
            docker stop %%c >nul 2>&1
            echo Removing container %%c...
            docker rm %%c >nul 2>&1
        )
        
        REM Force remove the image
        echo Removing image...
        docker rmi -f !DOCKER_IMAGE_NAME!
        if !errorlevel! neq 0 (
            echo [ERROR] Failed to remove existing image.
            pause
            exit /b 1
        )
        echo Existing image removed successfully.
        echo.
    ) else (
        REM Normal mode: prompt user
        echo.
        echo [WARNING] Docker image '!DOCKER_IMAGE_NAME!' already exists!
        echo.
        echo What would you like to do?
        echo   1. Remove the existing image and build a new one
        echo   2. Cancel and exit
        echo.
        set /p choice="Enter your choice (1 or 2): "
        
        if "!choice!"=="1" (
            echo.
            echo Removing existing image and associated containers...
            
            REM Find and stop all containers using this image
            for /f "tokens=*" %%c in ('docker ps -a --filter "ancestor=!DOCKER_IMAGE_NAME!" --format "{{.ID}}" 2^>nul') do (
                echo Stopping container %%c...
                docker stop %%c >nul 2>&1
                echo Removing container %%c...
                docker rm %%c >nul 2>&1
            )
            
            REM Force remove the image
            echo Removing image...
            docker rmi -f !DOCKER_IMAGE_NAME!
            if !errorlevel! neq 0 (
                echo [ERROR] Failed to remove existing image.
                pause
                exit /b 1
            )
            echo Existing image removed successfully.
            echo.
        ) else (
            echo.
            echo Build cancelled by user.
            pause
            exit /b 0
        )
    )
)

REM Check if Dockerfile exists
if not exist "Dockerfile" (
    echo [ERROR] Dockerfile not found in current directory!
    pause
    exit /b 1
)

REM Build the Docker image
echo.
echo Building Docker image with the following credentials:
echo   Username: !DOCKER_USERNAME!
echo   Password: ********
if "!VNC_PASSWORD!"=="!DOCKER_PASSWORD!" (
    echo   VNC Password: (same as user password)
) else (
    echo   VNC Password: ********
)
echo   SSH Server: Enabled
if !FORCE_REBUILD! equ 1 (
    echo   Rebuild mode: Complete rebuild from scratch (no cache)
)
echo.
echo This may take several minutes...
echo.

REM Build command
set BUILD_ARGS=--build-arg DOCKER_USERNAME=!DOCKER_USERNAME! --build-arg DOCKER_PASSWORD=!DOCKER_PASSWORD! --build-arg VNC_PASSWORD=!VNC_PASSWORD!

if !FORCE_REBUILD! equ 1 (
    docker build --no-cache !BUILD_ARGS! -t !DOCKER_IMAGE_NAME! .
) else (
    docker build !BUILD_ARGS! -t !DOCKER_IMAGE_NAME! .
)

REM Verify the image was created successfully (check if image exists, not just exit code)
timeout /t 1 /nobreak >nul
docker images !DOCKER_IMAGE_NAME! --format "{{.Repository}}:{{.Tag}}" 2>nul | findstr /C:"!DOCKER_IMAGE_NAME!" >nul
if errorlevel 1 (
    echo.
    echo [ERROR] Docker image build failed or image was not created!
    echo.
) else (
    echo.
    echo [SUCCESS] Docker image '!DOCKER_IMAGE_NAME!' built successfully!
    echo.
    echo To run the container with RDP access:
    echo   docker run -d -p 13389:3389 --name !DOCKER_CONTAINER_NAME! !DOCKER_IMAGE_NAME! tail -f /dev/null
    echo.
    echo Then start the RDP service:
    echo   docker exec !DOCKER_CONTAINER_NAME! service xrdp start
    echo.
    echo Connect via Remote Desktop to: localhost:13389
    echo   Username: !DOCKER_USERNAME!
    echo   Password: (the password you set in .env)
    echo.
    echo Or connect via VNC to: localhost:15901
    if "!VNC_PASSWORD!"=="!DOCKER_PASSWORD!" (
        echo   Password: (same as user password from .env)
    ) else (
        echo   Password: (VNC_PASSWORD from .env)
    )
    echo.
)

pause

