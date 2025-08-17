@echo off
chcp 65001 >nul
set "OUT_FILE=list_names.txt"

if exist "%OUT_FILE%" del /f /q "%OUT_FILE%"

echo [文件夹] > "%OUT_FILE%"
set /a DC=0
for /d %%D in (*) do (
    set /a DC+=1
    echo %%D >> "%OUT_FILE%"
)
if %DC%==0 echo (无文件夹) >> "%OUT_FILE%"

echo. >> "%OUT_FILE%"
echo [文件] >> "%OUT_FILE%"
set /a FC=0
for /f "delims=" %%F in ('dir /a:-d /b 2^>nul') do (
    set /a FC+=1
    echo %%F >> "%OUT_FILE%"
)
if %FC%==0 echo (无文件) >> "%OUT_FILE%"

echo. >> "%OUT_FILE%"
echo 合计: %DC% 个文件夹, %FC% 个文件 >> "%OUT_FILE%"

echo 已生成: "%OUT_FILE%"
type "%OUT_FILE%"
pause
