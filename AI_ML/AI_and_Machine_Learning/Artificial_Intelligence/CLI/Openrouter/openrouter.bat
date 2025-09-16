@echo off
chcp 65001 >nul
set PATH=%PATH%;C:\Users\micha\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\Python313\Scripts

if "%~1"=="" (
    echo Usage: openrouter.bat "model-name" "your message"
    echo Example: openrouter.bat "deepseek/deepseek-r1:free" "Hello!"
    echo.
    echo Popular models:
    echo   deepseek/deepseek-r1:free
    echo   openai/gpt-oss-20b:free  
    echo   meta-llama/llama-3.3-70b-instruct:free
    echo   qwen/qwen3-235b-a22b:free
    echo   anthropic/claude-3.5-sonnet
    echo   openai/gpt-5
    goto :eof
)

if "%~2"=="" (
    echo Please provide a message as the second argument
    goto :eof
)

echo Using model: %~1
echo Message: %~2
echo.
echo %~2 | openrouter-cli run "%~1"