@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================
echo   亂打輸入法 解除安裝
echo ========================================
echo.
echo 將移除：
echo   %%APPDATA%%\Rime\luanda\          ^(推論 + 模型^)
echo   %%APPDATA%%\Rime\luanda*.yaml/lua ^(方案檔^)
echo   開機啟動捷徑
echo 不會移除小狼毫本體或 Python。
echo.
pause

echo [*] 結束推論程序...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'rime_ai_server' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

set "RIME=%APPDATA%\Rime"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if exist "%RIME%\luanda\" (
  rmdir /s /q "%RIME%\luanda"
  echo [OK] 已刪除 %RIME%\luanda\
)
if exist "%STARTUP%\luanda_ime_server.vbs" (
  del /f /q "%STARTUP%\luanda_ime_server.vbs"
  echo [OK] 已刪除開機啟動
)

if exist "%RIME%\luanda.schema.yaml" del /f /q "%RIME%\luanda.schema.yaml"
if exist "%RIME%\yuce.schema.yaml" del /f /q "%RIME%\yuce.schema.yaml"
if exist "%RIME%\lua\luanda_translator.lua" del /f /q "%RIME%\lua\luanda_translator.lua"
if exist "%RIME%\lua\luanda_space.lua" del /f /q "%RIME%\lua\luanda_space.lua"
if exist "%RIME%\lua\luanda_userdict.lua" del /f /q "%RIME%\lua\luanda_userdict.lua"
if exist "%RIME%\lua\yuce_translator.lua" del /f /q "%RIME%\lua\yuce_translator.lua"
if exist "%RIME%\lua\yuce_space.lua" del /f /q "%RIME%\lua\yuce_space.lua"
if exist "%RIME%\lua\yuce_userdict.lua" del /f /q "%RIME%\lua\yuce_userdict.lua"

echo.
echo [提示] default.custom.yaml / rime.lua 若還有 luanda 相關行可自行刪除。
echo [提示] 請對小狼毫圖示右鍵 → 重新部署。
echo.
pause
endlocal
