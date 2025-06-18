@echo off
REM Prompt for minutes using PowerShell input dialog
setlocal enabledelayedexpansion

for /f "delims=" %%i in ('powershell -NoProfile -Command "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.Interaction]::InputBox('Please enter shutdown delay in minutes:', 'Shutdown Timer', '10')"') do set mins=%%i

REM Validate input
set /a test=%mins% >nul 2>&1
if "%mins%"=="" (
    echo [ERROR] No input. Aborted.
    pause
    exit /b
)
if errorlevel 1 (
    echo [ERROR] Invalid input. Numbers only.
    pause
    exit /b
)
if %mins% LSS 1 (
    echo [ERROR] Please enter a positive integer.
    pause
    exit /b
)

set /a seconds=%mins%*60

REM Schedule forced shutdown
shutdown /s /f /t %seconds%
echo [INFO] Shutdown scheduled in %mins% minute(s) (%seconds% seconds).
echo [INFO] To cancel, open CMD and run: shutdown /a
pause
