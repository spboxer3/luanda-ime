@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================
echo   Luanda IME uninstall (schema files)
echo ========================================
echo.
echo Removes luanda / legacy yuce files under %%APPDATA%%\Rime
echo Does not remove Weasel or Python.
echo.
pause

set "RIME=%APPDATA%\Rime"
if exist "%RIME%\luanda.schema.yaml" del /f /q "%RIME%\luanda.schema.yaml"
if exist "%RIME%\yuce.schema.yaml" del /f /q "%RIME%\yuce.schema.yaml"
if exist "%RIME%\lua\luanda_translator.lua" del /f /q "%RIME%\lua\luanda_translator.lua"
if exist "%RIME%\lua\luanda_space.lua" del /f /q "%RIME%\lua\luanda_space.lua"
if exist "%RIME%\lua\luanda_userdict.lua" del /f /q "%RIME%\lua\luanda_userdict.lua"
if exist "%RIME%\lua\yuce_translator.lua" del /f /q "%RIME%\lua\yuce_translator.lua"
if exist "%RIME%\lua\yuce_space.lua" del /f /q "%RIME%\lua\yuce_space.lua"
if exist "%RIME%\lua\yuce_userdict.lua" del /f /q "%RIME%\lua\yuce_userdict.lua"

echo.
echo [hint] Check default.custom.yaml / rime.lua for leftover lines.
echo [hint] Stop python rime_ai_server.py and redeploy Weasel.
echo.
pause
endlocal
