@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================
echo   亂打輸入法 解除安裝（方案檔）
echo ========================================
echo.
echo 將移除 %%APPDATA%%\Rime 下的 yuce 相關檔案。
echo 不會移除小狼毫本體或 Python。
echo.
pause

set "RIME=%APPDATA%\Rime"
if exist "%RIME%\yuce.schema.yaml" del /f /q "%RIME%\yuce.schema.yaml"
if exist "%RIME%\lua\yuce_translator.lua" del /f /q "%RIME%\lua\yuce_translator.lua"
if exist "%RIME%\lua\yuce_space.lua" del /f /q "%RIME%\lua\yuce_space.lua"

echo.
echo [提示] default.custom.yaml / rime.lua 請自行檢查是否還留有 yuce 相關行。
echo [提示] 請手動結束可能仍在執行的 python rime_ai_server.py，並重新部署小狼毫。
echo.
pause
endlocal
