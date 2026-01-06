@echo off
setlocal enabledelayedexpansion

REM Get the script directory (where this batch file is located)
set "SCRIPT_DIR=%~dp0"

REM Auto-detect username and build source directory path
set "SOURCE_DIR=C:\PROJ\ec-embedded"

REM Build link directory relative to script location
set "LINK_DIR=!SCRIPT_DIR!ec-embedded"

echo.
echo Creating directory junction for ec-embedded...
echo.
echo Source: !SOURCE_DIR!
echo Link:   !LINK_DIR!
echo.

if not exist "!SOURCE_DIR!" (
    echo [ERROR] Source directory does not exist:
    echo   !SOURCE_DIR!
    echo.
    pause
    exit /b 1
)

if exist "!LINK_DIR!" (
    fsutil reparsepoint query "!LINK_DIR!" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO] Directory junction already exists.
        echo [SUCCESS] Junction is working correctly!
        echo.
        pause
        exit /b 0
    ) else (
        echo [WARNING] Directory exists as regular folder (not a junction)
        echo Removing it...
        rmdir /S /Q "!LINK_DIR!"
        if !errorlevel! neq 0 (
            echo [ERROR] Failed to remove directory. It may be in use.
            pause
            exit /b 1
        )
    )
)

echo Creating directory junction...
mklink /J "!LINK_DIR!" "!SOURCE_DIR!"

if !errorlevel! equ 0 (
    echo [SUCCESS] Directory junction created successfully!
    echo.
) else (
    echo [ERROR] Failed to create directory junction!
    echo Try running as Administrator.
    echo.
)

pause
