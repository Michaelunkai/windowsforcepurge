@echo off
echo Starting automated Windows 11 upgrade...
echo.
echo WARNING: This will upgrade your Windows 11 installation automatically.
echo Make sure you have backed up important data before proceeding.
echo.
echo The system will restart automatically when the upgrade is complete.
echo After restart, a terminal will open automatically to run DISM cleanup.
echo.
pause

REM Run the PowerShell script with administrator privileges
powershell.exe -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0AutoUpgradeWindows11.ps1\"' -Verb RunAs"

echo.
echo Upgrade process initiated. Check the log file at F:\Downloads\upgrade\upgrade_log.txt for progress.
pause