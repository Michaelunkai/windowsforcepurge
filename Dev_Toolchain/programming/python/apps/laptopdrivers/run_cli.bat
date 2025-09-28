@echo off
REM Run Laptop Driver Updater in CLI mode

echo Starting Laptop Driver Updater (CLI Mode)...
echo.

REM Check if virtual environment exists
if not exist "venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found
    echo Please run setup.bat first to install dependencies
    pause
    exit /b 1
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo WARNING: Not running as administrator
    echo Some driver installations may fail without administrator privileges
    echo.
    echo To run as administrator:
    echo 1. Right-click on this batch file
    echo 2. Select "Run as administrator"
    echo.
    set /p "continue=Continue anyway? (y/N): "
    if /i not "%continue%"=="y" exit /b 1
)

REM Run the application in CLI mode
python main.py --no-gui

REM Keep window open
pause
