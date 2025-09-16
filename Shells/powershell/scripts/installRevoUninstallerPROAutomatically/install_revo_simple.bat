@echo off
REM Simple Batch Script to Install Revo Uninstaller Pro
REM Auto setup from cracked source to installed directory

title Revo Uninstaller Pro Installer

echo ========================================
echo Revo Uninstaller Pro 5.4 Auto Installer
echo ========================================
echo.

set "SOURCE=F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual"
set "DEST=F:\backup\windowsapps\installed\RevoUninstallerPro"

echo Source: %SOURCE%
echo Destination: %DEST%
echo.

REM Check if source exists
if not exist "%SOURCE%" (
    echo ERROR: Source directory not found!
    echo Please verify the path: %SOURCE%
    pause
    exit /b 1
)

REM Ask user confirmation
echo WARNING: This will overwrite the destination if it exists.
set /p confirm="Continue? (Y/N): "
if /i not "%confirm%"=="Y" (
    echo Installation cancelled.
    pause
    exit /b 0
)

REM Remove existing destination if it exists
if exist "%DEST%" (
    echo Removing existing installation...
    rmdir /s /q "%DEST%" 2>nul
)

REM Create destination directory
echo Creating destination directory...
mkdir "%DEST%" 2>nul

REM Copy files using robocopy for better performance
echo Copying files... This may take a few minutes.
robocopy "%SOURCE%" "%DEST%" /E /COPY:DAT /R:3 /W:5 /MT:8 /NP

if %errorlevel% leq 1 (
    echo.
    echo Copying license file...
    
    set "LICENSE_SOURCE=%SOURCE%\revouninstallerpro5.lic"
    set "LICENSE_DEST_DIR=C:\ProgramData\VS Revo Group\Revo Uninstaller Pro"
    set "LICENSE_DEST=%LICENSE_DEST_DIR%\revouninstallerpro5.lic"
    
    if exist "%LICENSE_SOURCE%" (
        if not exist "%LICENSE_DEST_DIR%" (
            echo Creating license directory...
            mkdir "%LICENSE_DEST_DIR%" 2>nul
        )
        
        copy "%LICENSE_SOURCE%" "%LICENSE_DEST%" >nul 2>&1
        if %errorlevel% equ 0 (
            echo License file copied successfully!
            echo   From: %LICENSE_SOURCE%
            echo   To: %LICENSE_DEST%
        ) else (
            echo Warning: Could not copy license file. You may need to run as Administrator.
        )
    ) else (
        echo Warning: License file not found. You may need to activate manually.
    )
    
    echo.
    echo ================================
    echo Installation completed successfully!
    echo ================================
    echo.
    echo Revo Uninstaller Pro installed to:
    echo %DEST%
    echo.
    
    REM Try to find and run the main executable
    if exist "%DEST%\RevoUninsPro.exe" (
        echo Main executable found: RevoUninsPro.exe
        set /p runapp="Run Revo Uninstaller Pro now? (Y/N): "
        if /i "%runapp%"=="Y" (
            start "" "%DEST%\RevoUninsPro.exe"
        )
    ) else if exist "%DEST%\RevoUninstaller.exe" (
        echo Main executable found: RevoUninstaller.exe
        set /p runapp="Run Revo Uninstaller Pro now? (Y/N): "
        if /i "%runapp%"=="Y" (
            start "" "%DEST%\RevoUninstaller.exe"
        )
    ) else (
        echo Please check the destination folder for the main executable.
        echo Opening destination folder...
        start "" "%DEST%"
    )
) else (
    echo.
    echo ERROR: File copy failed with error code %errorlevel%
    echo Please check the source and destination paths.
)

echo.
pause