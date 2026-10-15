@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================
echo   亂打輸入法 安裝程式
echo ========================================
echo.
echo 會安裝到：
echo   %%APPDATA%%\Rime\          ^(小狼毫方案 / Lua^)
echo   %%APPDATA%%\Rime\luanda\   ^(推論服務 + 模型^)
echo 安裝完成後可刪除本解壓資料夾。
echo.

where python >nul 2>nul
if errorlevel 1 (
  echo [錯誤] 找不到 python。請先安裝 Python 3.11+，並勾選 Add python.exe to PATH。
  echo 下載：https://www.python.org/downloads/
  pause
  exit /b 1
)

if not exist "luanda_bopomofo_int8\model.bin" (
  echo [錯誤] 找不到模型資料夾 luanda_bopomofo_int8\
  echo 請從 GitHub Release 下載 luanda_bopomofo_int8.zip 並解壓到與本 install.bat 同一層。
  pause
  exit /b 1
)

echo [1/3] 安裝 Python 依賴（ctranslate2）...
python -m pip install -r requirements.txt
if errorlevel 1 (
  echo [錯誤] pip 安裝失敗
  pause
  exit /b 1
)

echo [2/3] 複製到小狼毫目錄並部署方案...
python setup_rime_luanda.py
if errorlevel 1 (
  echo [錯誤] 安裝失敗。請確認已安裝小狼毫：https://rime.im/download/
  pause
  exit /b 1
)

echo [3/3] 完成。
echo.
echo 使用方式：
echo   1. 若未自動部署：小狼毫圖示右鍵 -^> 重新部署
echo   2. 按 F4 或 Ctrl+` 選擇「亂打輸入法」
echo   3. 開機後會自動啟動推論；若無候選，執行：
echo      %%APPDATA%%\Rime\luanda\start_server_hidden.vbs
echo.
pause
endlocal
