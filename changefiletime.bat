@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ===============================
echo 批量修改文件/文件夹时间 (增强遥测版)
echo 日期格式: YYYY-MM-DD / YYYYMMDD / YYYY/MM/DD
echo 时间格式: 6位=HHMMSS  4位=HHMM(秒=00)  空=00:00:00
echo 仅接受纯数字或空，不支持冒号
echo ===============================

:: -------- 日期输入 --------
:READ_DATE
set "DATE_RAW="
set /p "DATE_RAW=输入日期: "
if "%DATE_RAW%"=="" (
  echo [ERR] 必须输入日期
  goto READ_DATE
)
for /f "tokens=* delims= " %%A in ("%DATE_RAW%") do set "DATE_RAW=%%A"
set "DATE_STD=%DATE_RAW:/=-%"
set "DATE_STD=%DATE_STD:\=-%"

call :AllDigits "%DATE_STD%" _ALL
if "%_ALL%"=="1" if "%DATE_STD:~8,1%"=="" (
  set "DATE_STD=%DATE_STD:~0,4%-%DATE_STD:~4,2%-%DATE_STD:~6,2%"
)

if not "%DATE_STD:~4,1%"=="-" goto BAD_DATE
if not "%DATE_STD:~7,1%"=="-" goto BAD_DATE

set "Y=%DATE_STD:~0,4%" & set "M=%DATE_STD:~5,2%" & set "D=%DATE_STD:~8,2%"
call :AllDigits "%Y%" _Y & call :AllDigits "%M%" _M & call :AllDigits "%D%" _D
if "%_Y%%_M%%_D%" neq "111" goto BAD_DATE

if "%M:~0,1%"=="0" (set /a MV=%M:~1,1%) else set /a MV=%M%
if "%D:~0,1%"=="0" (set /a DV=%D:~1,1%) else set /a DV=%D%
if %MV% LSS 1  goto BAD_DATE
if %MV% GTR 12 goto BAD_DATE
if %DV% LSS 1  goto BAD_DATE
if %DV% GTR 31 goto BAD_DATE

echo [OK] 日期 = %DATE_STD%
goto DATE_OK

:BAD_DATE
echo [ERR] 日期非法
goto READ_DATE

:DATE_OK

:: -------- 时间输入 --------
:READ_TIME
set "TIME_RAW="
set /p "TIME_RAW=输入时间(4位/6位/空): "
if "%TIME_RAW%"=="" (
  set "TIME_STD=00:00:00"
  goto TIME_READY
)
call :AllDigits "%TIME_RAW%" _TD
if "%_TD%"=="0" (
  echo [ERR] 只允许纯数字
  goto READ_TIME
)
call :StrLen "%TIME_RAW%" _TL
if "%_TL%"=="6" (
  set "HH=%TIME_RAW:~0,2%"
  set "MI=%TIME_RAW:~2,2%"
  set "SS=%TIME_RAW:~4,2%"
) else if "%_TL%"=="4" (
  set "HH=%TIME_RAW:~0,2%"
  set "MI=%TIME_RAW:~2,2%"
  set "SS=00"
) else (
  echo [ERR] 长度只能是4或6
  goto READ_TIME
)

if 1%HH% GEQ 124 (echo [ERR] 小时0-23 & goto READ_TIME)
if 1%MI% GEQ 160 (echo [ERR] 分钟0-59 & goto READ_TIME)
if 1%SS% GEQ 160 (echo [ERR] 秒0-59 & goto READ_TIME)

set "TIME_STD=%HH%:%MI%:%SS%"

:TIME_READY
echo [OK] 时间 = %TIME_STD%

:: -------- 确认与执行 --------
set "DT_FULL=%DATE_STD% %TIME_STD%"
echo 目标时间: [%DT_FULL%]
choice /C YN /M "确认执行?"
if errorlevel 2 (
  echo 已取消
  goto END
)

set "LOGSTAMP=%DATE_STD%_%TIME_STD::=%"
set "LOGSTAMP=%LOGSTAMP: =_%"
set "LOGTXT=TimeChange_Failures_%LOGSTAMP%.txt"
set "LOGCSV=TimeChange_Failures_%LOGSTAMP%.csv"

echo 正在处理...

powershell -NoLogo -NoProfile -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$raw='%DT_FULL%';" ^
 "try{ $ts=[datetime]::Parse($raw) }catch{ Write-Host '解析失败:' $_.Exception.Message; exit 2 };" ^
 "$items = Get-ChildItem -LiteralPath . -Recurse -Force;" ^
 "$total=$items.Count; $ok=0; $fail=0;" ^
 "$fails = New-Object System.Collections.Generic.List[Object];" ^
 "function Classify([string]$etype,[string]$msg){" ^
 "  if($etype -eq 'System.UnauthorizedAccessException'){return '权限/只读'}" ^
 "  elseif($etype -eq 'System.IO.IOException' -and $msg -match 'being used'){return '被占用(句柄)'}" ^
 "  elseif($msg -match 'read-only'){return '只读属性'}" ^
 "  else{return '其它'}" ^
 "}" ^
 "foreach($f in $items){" ^
 "  $ro = $false; if($f.Attributes -band [IO.FileAttributes]::ReadOnly){$ro=$true}" ^
 "  if($ro){ try{ $f.Attributes = ($f.Attributes -bxor [IO.FileAttributes]::ReadOnly) }catch{} }" ^
 "  try{ $f.CreationTime=$ts; $f.LastAccessTime=$ts; $f.LastWriteTime=$ts; $ok++ }" ^
 "  catch{" ^
 "     $fail++; $etype=$_.Exception.GetType().FullName; $msg=$_.Exception.Message;" ^
 "     $cat=Classify $etype $msg;" ^
 "     $fails.Add([pscustomobject]@{Path=$f.FullName; ReadOnlyBefore=$ro; ExceptionType=$etype; Message=$msg; Category=$cat})" ^
 "  }" ^
 "}" ^
 "try{ $r=Get-Item -LiteralPath .; $r.CreationTime=$ts; $r.LastAccessTime=$ts; $r.LastWriteTime=$ts }catch{}" ^
 "Write-Host ('总:{0} 成功:{1} 失败:{2}' -f $total,$ok,$fail);" ^
 "if($fail -gt 0){" ^
 "  $groups = $fails | Group-Object Category | Sort-Object Count -Descending;" ^
 "  Write-Host '失败分类:';" ^
 "  foreach($g in $groups){ Write-Host ('  {0} : {1}' -f $g.Name,$g.Count) }" ^
 "  Write-Host '前20条失败示例:';" ^
 "  $fails | Select-Object -First 20 Path,Category,ReadOnlyBefore,ExceptionType | Format-Table -AutoSize | Out-String | Write-Host;" ^
 "  $csvPath = '%LOGCSV%'; $txtPath='%LOGTXT%';" ^
 "  $fails | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath;" ^
 "  ('时间戳={0}' -f $ts) | Out-File -FilePath $txtPath -Encoding UTF8;" ^
 "  ('总={0} 成功={1} 失败={2}' -f $total,$ok,$fail) | Out-File -FilePath $txtPath -Append -Encoding UTF8;" ^
 "  '分类统计:' | Out-File -FilePath $txtPath -Append -Encoding UTF8;" ^
 "  foreach($g in $groups){ ('  {0}={1}' -f $g.Name,$g.Count) | Out-File -FilePath $txtPath -Append -Encoding UTF8 }" ^
 "  '--- 失败详情 (CSV 同名) ---' | Out-File -FilePath $txtPath -Append -Encoding UTF8;" ^
 "  $fails | Select-Object Path,Category,ReadOnlyBefore,ExceptionType,Message | Format-Table -AutoSize | Out-String | Out-File -FilePath $txtPath -Append -Encoding UTF8;" ^
 "  Write-Host ('已生成日志: {0} / {1}' -f $txtPath,$csvPath);" ^
 "}" ^
 "exit 0"

echo 完成(errorlevel=%errorlevel%)
if exist "%LOGTXT%" echo 失败详细: %LOGTXT%
if exist "%LOGCSV%" echo 失败CSV : %LOGCSV%

:END
echo.
echo (结束，按任意键退出)
pause >nul
endlocal
goto :eof

:: ===== 子程序 =====
:AllDigits
setlocal
set "S=%~1"
if "%S%"=="" (endlocal & set "%~2=0" & goto :eof)
for /f "delims=0123456789" %%Q in ("%S%") do (endlocal & set "%~2=0" & goto :eof)
endlocal & set "%~2=1"
goto :eof

:StrLen
setlocal EnableDelayedExpansion
set "S=%~1"
set /a L=0
:SL
set "c=!S:~%L%,1!"
if "!c!"=="" (endlocal & set "%~2=%L%" & goto :eof)
set /a L+=1
goto SL
