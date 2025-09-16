@echo off
echo ====================================
echo    RAM Optimizer Pro Launcher
echo ====================================
echo.
echo Select an option:
echo 1. GUI Mode (Graphical Interface)
echo 2. Service Mode (Background monitoring)
echo 3. Manual Cleanup (One-time optimization)
echo 4. Memory Info (Current status)
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" (
    echo Starting GUI Mode...
    python main.py gui
) else if "%choice%"=="2" (
    echo Starting Service Mode...
    echo Press Ctrl+C to stop the service
    python main.py service
) else if "%choice%"=="3" (
    echo Performing Manual Cleanup...
    python main.py clean
    pause
) else if "%choice%"=="4" (
    echo Current Memory Information...
    python main.py info
    pause
) else if "%choice%"=="5" (
    echo Goodbye!
    exit
) else (
    echo Invalid choice. Please try again.
    pause
    goto :eof
)

pause 