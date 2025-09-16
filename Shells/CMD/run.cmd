@echo off
set f=%1
if "%f%"=="" for %%i in (*.ahk) do set f=%%i
if not exist "%f%" echo File not found: %f% & exit /b 1
findstr /c:"MsgBox(" /c:"Array(" /c:"#Requires.*v2" "%f%" >nul
if %errorlevel%==0 (
    start "" /B "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "%f%"
) else (
    start "" /B "C:\Program Files\AutoHotkey\AutoHotkey.exe" "%f%"
)
