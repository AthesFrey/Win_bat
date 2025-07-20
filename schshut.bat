@echo off
setlocal EnableDelayedExpansion
set /p "mins=Enter minutes (>=1, blank=cancel): "
if "!mins!"=="" goto :EOF
echo !mins!| findstr /R "^[0-9][0-9]*$" >nul || goto :EOF
if !mins! LSS 1 goto :EOF
set /a seconds=!mins!*60
echo Scheduling shutdown in !mins! minute^(s^) (!seconds! s)...
"%SystemRoot%\System32\shutdown.exe" /s /f /t !seconds!
echo Cancel: shutdown /a
pause
