@echo off
echo Everything CLI - File Manager
echo =============================

:: Check if Python is installed (try py first, then python)
py --version >nul 2>&1
if errorlevel 1 (
    python --version >nul 2>&1
    if errorlevel 1 (
        echo Error: Python is not installed or not in PATH
        echo Please install Python 3.6+ and try again
        pause
        exit /b 1
    )
    set PYTHON_CMD=python
) else (
    set PYTHON_CMD=py
)

:: Install dependencies if needed
echo Installing dependencies...
%PYTHON_CMD% -m pip install -r requirements.txt >nul 2>&1

:: Run the application
echo Starting Everything CLI...
echo.
%PYTHON_CMD% everything_cli.py %*

pause