@echo off
REM Main Deep System Cleanup Executor
REM This batch file runs the main cleanup PowerShell script

echo Main Deep System Cleanup Executor
echo ================================
echo This will run the complete deep system cleanup process.
echo Make sure you want to proceed before continuing!
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Error: This script must be run as Administrator!
    echo Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Starting deep system cleanup...
echo.

REM Run the main PowerShell script with bypass execution policy
PowerShell.exe -ExecutionPolicy Bypass -File "%~dp0main_cleanup.ps1"

echo.
echo Script execution completed.
echo Please restart your computer to complete the cleanup process.
echo.
pause