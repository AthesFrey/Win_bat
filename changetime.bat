@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ===============================
echo 批量修改文件/文件夹时间 (硬茬跳过版-仅屏幕输出)
echo 日期格式: YYYY-MM-DD / YYYYMMDD / YYYY/MM/DD
echo 时间格式: 6位=HHMMSS  4位=HHMM(秒=00)  空=当前时间
echo 仅接受纯数字或空，不支持冒号
echo 说明: 碰到无权限/占用/异常对象时会跳过，仅在窗口显示结果
echo ===============================

:: -------- 获取当前日期/时间默认值 --------
for /f %%I in ('powershell -NoLogo -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CUR_DATE=%%I"
for /f %%I in ('powershell -NoLogo -NoProfile -Command "Get-Date -Format HHmmss"') do set "CUR_TIME=%%I"

:: -------- 日期输入 --------
:READ_DATE
set "DATE_RAW="
set /p "DATE_RAW=输入日期 [默认 %CUR_DATE%]: "
if "%DATE_RAW%"=="" set "DATE_RAW=%CUR_DATE%"

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
set /p "TIME_RAW=输入时间(4位/6位，默认当前时间 %CUR_TIME%): "
if "%TIME_RAW%"=="" set "TIME_RAW=%CUR_TIME%"

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

echo [OK] 时间 = %TIME_STD%

:: -------- 确认与执行 --------
set "DT_FULL=%DATE_STD% %TIME_STD%"
echo 目标时间: [%DT_FULL%]
choice /C YN /M "确认执行?"
if errorlevel 2 (
  echo 已取消
  goto END
)

echo 正在处理...(根目录自身将跳过，仅处理其下文件/文件夹)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "try {" ^
 "  $raw='%DT_FULL%';" ^
 "  try { $ts=[datetime]::ParseExact($raw,'yyyy-MM-dd HH:mm:ss',[System.Globalization.CultureInfo]::InvariantCulture) } catch { Write-Host ('解析失败: ' + $_.Exception.Message); exit 2 }" ^
 "  $root=(Get-Item -LiteralPath '.').FullName;" ^
 "  $items=New-Object System.Collections.Generic.List[Object];" ^
 "  $fails=New-Object System.Collections.Generic.List[Object];" ^
 "  function Classify([string]$etype,[string]$msg){" ^
 "    if($etype -match 'UnauthorizedAccess' -or $msg -match 'access.*denied|拒绝访问|策略'){ return '权限/策略限制' }" ^
 "    elseif($etype -match 'PathTooLong'){ return '路径过长' }" ^
 "    elseif($etype -eq 'System.IO.IOException' -and $msg -match 'being used|另一个进程|占用'){ return '被占用(句柄)' }" ^
 "    elseif($msg -match 'read-only|只读'){ return '只读属性' }" ^
 "    else { return '其它' }" ^
 "  }" ^
 "  function AddFail([string]$path,[bool]$ro,[string]$etype,[string]$msg){" ^
 "    $cat=Classify $etype $msg;" ^
 "    $fails.Add([pscustomobject]@{Path=$path; ReadOnlyBefore=$ro; ExceptionType=$etype; Message=$msg; Category=$cat}) | Out-Null" ^
 "  }" ^
 "  function EnumSafe([string]$dir){" ^
 "    $entries=@();" ^
 "    try { $entries=Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop }" ^
 "    catch { AddFail $dir $false $_.Exception.GetType().FullName $_.Exception.Message; return }" ^
 "    foreach($e in $entries){" ^
 "      if($e.Attributes -band [IO.FileAttributes]::ReparsePoint){ continue }" ^
 "      $items.Add($e) | Out-Null;" ^
 "      if($e.PSIsContainer){ EnumSafe $e.FullName }" ^
 "    }" ^
 "  }" ^
 "  EnumSafe $root;" ^
 "  $total=$items.Count; $ok=0;" ^
 "  foreach($f in $items){" ^
 "    $ro=$false;" ^
 "    try { if($f.Attributes -band [IO.FileAttributes]::ReadOnly){ $ro=$true; $f.Attributes=($f.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)) } } catch {}" ^
 "    try { $f.CreationTime=$ts; $f.LastAccessTime=$ts; $f.LastWriteTime=$ts; $ok++ }" ^
 "    catch { AddFail $f.FullName $ro $_.Exception.GetType().FullName $_.Exception.Message }" ^
 "  }" ^
 "  $fail=$fails.Count;" ^
 "  Write-Host ('总:{0} 成功:{1} 跳过/失败:{2} (根目录已跳过)' -f $total,$ok,$fail);" ^
 "  if($fail -gt 0){" ^
 "    $groups=$fails | Group-Object Category | Sort-Object Count -Descending;" ^
 "    Write-Host '失败分类:';" ^
 "    foreach($g in $groups){ Write-Host ('  {0} : {1}' -f $g.Name,$g.Count) }" ^
 "    Write-Host '前20条失败示例:';" ^
 "    $fails | Select-Object -First 20 Path,Category,ReadOnlyBefore,ExceptionType | Format-Table -AutoSize | Out-String | Write-Host;" ^
 "  }" ^
 "  exit 0" ^
 "} catch {" ^
 "  Write-Host ('脚本提前终止: ' + $_.Exception.Message);" ^
 "  exit 10" ^
 "}"

set "PS_RC=%errorlevel%"
echo 完成(errorlevel=%PS_RC%)
if "%PS_RC%"=="0" (
  echo 已完成：结果已显示在本窗口
) else if "%PS_RC%"=="2" (
  echo 时间解析失败，请检查输入格式
) else if "%PS_RC%"=="10" (
  echo PowerShell 主流程提前终止
) else if "%PS_RC%"=="786" (
  echo 检测到策略限制：某个路径/文件被系统策略拦截
)

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


