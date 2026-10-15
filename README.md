# 亂打輸入法

在電腦上用大千注音打字；底層是 **洋蔥注音 plus**，需要時按 **Tab** 才呼叫本機 AI 糾錯。  
掛在 **小狼毫（Rime）** 底下使用。

目前版本：**0.1.4-Beta / 方案 2.0**（洋蔥底 + Tab AI）

---

## 安裝前請先準備

1. **小狼毫**（Windows 版 Rime）  
   下載：https://rime.im/download/
2. **洋蔥注音 plus**（`bopomo_onionplus`）已裝在小狼毫使用者目錄  
3. **Python 3.11 或更新**  
   下載：https://www.python.org/downloads/  
   安裝時請勾選 **Add python.exe to PATH**

---

## 安裝步驟（第一次用也可以）

1. 到本專案的 [Releases（發行頁）](https://github.com/spboxer3/luanda-ime/releases) 下載兩樣東西：
   - 程式壓縮檔（原始碼 zip，或直接下載整個專案）
   - **`luanda_bopomofo_int8.zip`**（模型，一定要有）
2. 把程式解壓到**暫時**資料夾（例如 Downloads）。
3. 把 `luanda_bopomofo_int8` 解壓後放在與 **`install.bat` 同一層**。
4. 雙擊 **`install.bat`**：會把方案與推論服務**複製進小狼毫目錄**，完成後可刪掉 Downloads 解壓包。
5. 若沒有自動部署：小狼毫圖示 → **右鍵 → 重新部署**。
6. 按 **F4** 或 **Ctrl + \`**，選 **「亂打輸入法」**。

安裝後實際位置（請勿刪）：

```text
%APPDATA%\Rime\
├── bopomo_onionplus.*      ← 洋蔥（須已安裝）
├── luanda.schema.yaml      ← 亂打（繼承洋蔥）
├── luanda.custom.yaml      ← Tab→AI 掛鉤
├── lua\luanda_*.lua
└── luanda\                 ← 推論服務 + 模型（開機自動啟動）
    ├── rime_ai_server.py
    ├── start_server_hidden.vbs
    └── luanda_bopomofo_int8\
```

---

## 怎麼打字

| 你做的事 | 會發生什麼 |
|----------|------------|
| 用大千鍵位打注音 | **洋蔥**候選（與洋蔥 plus 相同手感） |
| **空白鍵** | 一聲（洋蔥） |
| 有選字框時按 **Tab** | 觸發本機 **AI 糾錯**，候選前標 `AI` |
| 再按一次 **Tab** | 取消 AI，回到純洋蔥候選 |
| 繼續打字 | 自動退出 AI 模式 |
| **Enter**／數字鍵 | 選定目前反白的候選（同洋蔥） |

---

## 常見問題

**Q：按 Tab 沒有 AI 候選？**  
A：確認推論服務有在跑（`%APPDATA%\Rime\luanda\start_server_hidden.vbs`），模型載入要幾秒；開機啟動也會叫它。

**Q：選單裡找不到「亂打輸入法」？**  
A：確認已安裝洋蔥、`install.bat` 有跑完，並對小狼毫「重新部署」，再用 F4 切換。

**Q：可以跟原本的洋蔥一起用嗎？**  
A：可以。亂打是獨立方案（洋蔥底 + Tab AI），F4 可在兩者間切換。

---

## 解除安裝

1. 雙擊 **`uninstall.bat`**
2. 小狼毫圖示 → 右鍵 → **重新部署**
3. （可選）在工作管理員結束仍在執行的 `python`／亂打相關程式

---

## 回報問題

若打字異常、候選很怪或安裝失敗，歡迎到 GitHub 開 Issue 告訴我：你的 Windows 版本、小狼毫版本，以及發生了什麼事。
