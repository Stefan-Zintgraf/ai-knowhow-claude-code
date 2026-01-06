@echo off
setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "LINK_DIR=!SCRIPT_DIR!NinjaTrader 8"

echo Removing directory junction...
echo Link: !LINK_DIR!

if not exist "!LINK_DIR!" (
    echo Directory does not exist
    pause
    exit /b 0
)

fsutil reparsepoint query "!LINK_DIR!" >nul 2>&1
if !errorlevel! equ 0 (
    echo Junction found, removing...
    rmdir "!LINK_DIR!"
    if !errorlevel! equ 0 (
        echo Junction removed successfully!
    ) else (
        echo Failed to remove junction
    )
) else (
    echo Directory is not a junction
)

pause
