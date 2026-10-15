@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ========================================
echo   亂打輸入法 0.1.3-Beta 安裝程式
echo ========================================
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
  echo 請從 GitHub Release 下載 luanda_bopomofo_int8.zip 並解壓到本目錄。
  pause
  exit /b 1
)

echo [1/4] 安裝 Python 依賴（ctranslate2）...
python -m pip install -r requirements.txt
if errorlevel 1 (
  echo [錯誤] pip 安裝失敗
  pause
  exit /b 1
)

echo [2/4] 寫入小狼毫方案「亂打輸入法」...
python setup_rime_luanda.py
if errorlevel 1 (
  echo [錯誤] 方案安裝失敗。請確認已安裝小狼毫：https://rime.im/download/
  pause
  exit /b 1
)

echo [3/4] 啟動本地推論伺服器（背景）...
wscript.exe "%~dp0start_server_hidden.vbs"
timeout /t 2 /nobreak >nul

echo [4/4] 完成。
echo.
echo 使用方式：
echo   1. 若小狼毫未自動部署，請對右下角圖示右鍵 -^> 重新部署
echo   2. 按 F4 或 Ctrl+` 選擇「亂打輸入法」
echo   3. 開機後若無候選，再執行一次 start_server_hidden.vbs
echo.
pause
endlocal
