@echo off
setlocal enabledelayedexpansion

REM Change to the script's directory
cd /d "%~dp0"

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
        echo # Docker build arguments for user credentials
        echo # Copy this file to .env and set your desired username and password
        echo # The .env file is gitignored to keep credentials out of version control
        echo.
        echo DOCKER_USERNAME=dev
        echo DOCKER_PASSWORD=dev
    ) > .env.example
)

REM Read credentials from .env file
set DOCKER_USERNAME=
set DOCKER_PASSWORD=

for /f "usebackq eol=# tokens=1,2 delims==" %%a in (".env") do (
    REM Read key-value pairs, skip comment lines (handled by eol=#)
    if /i "%%a"=="DOCKER_USERNAME" set "DOCKER_USERNAME=%%b"
    if /i "%%a"=="DOCKER_PASSWORD" set "DOCKER_PASSWORD=%%b"
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

REM Check if Docker image already exists
docker images debian-dev:latest --format "{{.Repository}}:{{.Tag}}" 2>nul | findstr /C:"debian-dev:latest" >nul
if %errorlevel% equ 0 (
    echo.
    echo [WARNING] Docker image 'debian-dev:latest' already exists!
    echo.
    echo What would you like to do?
    echo   1. Remove the existing image and build a new one
    echo   2. Cancel and exit
    echo.
    set /p choice="Enter your choice (1 or 2): "
    
    if "!choice!"=="1" (
        echo.
        echo Removing existing image...
        docker rmi debian-dev:latest
        if !errorlevel! neq 0 (
            echo [ERROR] Failed to remove existing image. It may be in use by a container.
            echo Please stop and remove any containers using this image first.
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
echo   VNC Password: (same as user password)
echo.
echo This may take several minutes...
echo.

docker build --build-arg DOCKER_USERNAME=!DOCKER_USERNAME! --build-arg DOCKER_PASSWORD=!DOCKER_PASSWORD! --build-arg VNC_PASSWORD=!DOCKER_PASSWORD! -t debian-dev:latest .

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Docker image 'debian-dev:latest' built successfully!
    echo.
    echo To run the container with RDP access:
    echo   docker run -d -p 13389:3389 --name debian-dev-container debian-dev:latest tail -f /dev/null
    echo.
    echo Then start the RDP service:
    echo   docker exec debian-dev-container service xrdp start
    echo.
    echo Connect via Remote Desktop to: localhost:13389
    echo   Username: !DOCKER_USERNAME!
    echo   Password: (the password you set in .env)
    echo.
    echo Or connect via VNC to: localhost:15901
    echo   Password: (same as user password from .env)
    echo.
) else (
    echo.
    echo [ERROR] Docker image build failed!
    echo.
)

pause

