@echo off
REM -- Clear Recent Items --

echo Clearing the "Recent Items" folder...
del /f /q "%AppData%\Microsoft\Windows\Recent\*" 2>nul
REM Check if the deletion was successful
if %errorlevel% neq 0 (
    echo Error clearing "Recent Items" folder. Please check permissions or folder existence.
)

REM -- Clear Quick Access --

echo Deleting Quick Access data...
del /f /q "%AppData%\Microsoft\Windows\Recent\AutomaticDestinations\*" 2>nul
REM Check if the deletion was successful
if %errorlevel% neq 0 (
    echo Error deleting Quick Access data. Please check permissions or folder existence.
)

REM -- Restart Explorer --

echo Restarting Explorer to apply changes...
taskkill /f /im explorer.exe >nul 2>&1
REM Check if Explorer process was killed successfully
if %errorlevel% neq 0 (
    echo Error killing Explorer. Trying to restart Explorer manually...
)
start explorer.exe

REM -- Completion --

echo Operation completed. Recent Items and Quick Access have been cleared.
pause
