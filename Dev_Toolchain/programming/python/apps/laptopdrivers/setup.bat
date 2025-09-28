@echo off
REM Laptop Driver Updater - Installation and Setup Script
REM This script sets up the Python environment and installs required packages

echo ========================================
echo Laptop Driver Updater Setup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or later from https://python.org
    echo Make sure to check "Add to PATH" during installation
    pause
    exit /b 1
)

echo Python found:
python --version
echo.

REM Check Python version (require 3.8+)
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo Checking Python version...
python -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python 3.8 or later is required
    echo Current version: %PYTHON_VERSION%
    pause
    exit /b 1
)

echo Python version is compatible: %PYTHON_VERSION%
echo.

REM Create virtual environment
echo Creating virtual environment...
if exist "venv" (
    echo Virtual environment already exists, skipping creation.
) else (
    python -m venv venv
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo Virtual environment created successfully.
)
echo.

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)

REM Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip

REM Install requirements
echo Installing required packages...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install requirements
    echo Please check the error messages above
    pause
    exit /b 1
)

echo.
echo ========================================
echo Setup completed successfully!
echo ========================================
echo.
echo You can now run the driver updater using:
echo   run_gui.bat     - Run with graphical interface
echo   run_cli.bat     - Run in command-line mode
echo   run_scan.bat    - Scan only (no installation)
echo.
echo For manual execution:
echo   venv\Scripts\activate.bat
echo   python main.py
echo.
pause
