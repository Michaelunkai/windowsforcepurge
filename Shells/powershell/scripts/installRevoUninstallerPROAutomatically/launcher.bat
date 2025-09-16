@echo off
title Revo Uninstaller Pro Installation Launcher

:menu
cls
echo ================================================
echo    Revo Uninstaller Pro 5.4 Installation Menu
echo ================================================
echo.
echo Please select an installation method:
echo.
echo 1. PowerShell Script (Recommended - Full features)
echo 2. Simple Batch Installation
echo 3. Quick Install (No prompts)
echo 4. Open source folder
echo 5. Open destination folder  
echo 6. Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto powershell
if "%choice%"=="2" goto batch
if "%choice%"=="3" goto quick
if "%choice%"=="4" goto opensource
if "%choice%"=="5" goto opendest
if "%choice%"=="6" goto exit

echo Invalid choice. Please try again.
pause
goto menu

:powershell
cls
echo Starting PowerShell installation...
echo.
powershell -ExecutionPolicy Bypass -File "install_revo_uninstaller.ps1"
echo.
echo PowerShell installation completed.
pause
goto menu

:batch
cls
echo Starting batch installation...
echo.
call install_revo_simple.bat
goto menu

:quick
cls
echo Starting quick installation...
echo.
call quick_install.cmd
echo.
pause
goto menu

:opensource
start "" "F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual"
goto menu

:opendest
if exist "F:\backup\windowsapps\installed\RevoUninstallerPro" (
    start "" "F:\backup\windowsapps\installed\RevoUninstallerPro"
) else (
    echo Destination folder does not exist yet.
    pause
)
goto menu

:exit
echo Thank you for using the Revo Uninstaller Pro installer!
exit /b 0