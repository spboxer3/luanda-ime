# 亂打輸入法

在電腦上「照大千鍵盤亂打注音」，由本機小 AI 幫你糾錯、預測中文候選。  
掛在 **小狼毫（Rime）** 底下使用。

目前版本：**0.1.4-Beta**（測試預覽，功能還會再調整）

---

## 安裝前請先準備

1. **小狼毫**（Windows 版 Rime）  
   下載：https://rime.im/download/
2. **Python 3.11 或更新**  
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
├── luanda.schema.yaml      ← 方案
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
| 用大千鍵位打注音 | 出現中文候選（約 2 個鍵就開始補字） |
| **空白鍵** | 輸入一聲 |
| **Enter** | 選定目前反白的候選字 |
| 單獨按一下 **Shift** | 組字中改成「英文按鍵」候選（再按可切回） |
| **Shift + ,**／**Shift + .** | 輸入 **，**／**。**（大千標點在 Shift 層） |
| **Shift + /**、**Shift + ;** 等 | ？、：、「」……等常用標點 |
| **BackSpace** | 一次刪掉一整個音節 |
| **→**／**←** | 候選下一頁／上一頁 |
| **↓**／**↑** | 頁內下一個／上一個候選 |
| 選過的字詞 | 會記進慣用詞，之後同鍵碼優先出現 |

---

## 常見問題

**Q：候選字都沒出現？**  
A：打字時若偵測到服務沒回應，小狼毫會自動叫起 `%APPDATA%\Rime\luanda\start_server_hidden.vbs`（模型載入要幾秒，稍後再打即可）。另有開機啟動；仍不行再手動執行該 vbs。

**Q：選單裡找不到「亂打輸入法」？**  
A：確認 `install.bat` 有跑完，並對小狼毫執行「重新部署」，再用 F4 切換方案。

**Q：可以跟原本的注音一起用嗎？**  
A：可以。它只是小狼毫裡多一個方案，用 F4 切換即可。

---

## 解除安裝

1. 雙擊 **`uninstall.bat`**
2. 小狼毫圖示 → 右鍵 → **重新部署**
3. （可選）在工作管理員結束仍在執行的 `python`／亂打相關程式

---

## 回報問題

若打字異常、候選很怪或安裝失敗，歡迎到 GitHub 開 Issue 告訴我：你的 Windows 版本、小狼毫版本，以及發生了什麼事。
