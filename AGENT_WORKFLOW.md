# 「預測」輸入法 (Rime + Transformer) 本地 Agent 自動化實作指南

本專案包含將訓練好的注音按鍵糾錯 Transformer 模型（`vocab.json`, `model.safetensors`, `generation_config.json`, `config.json`）整合至 Windows 小狼毫（Rime / Weasel）並命名為**「預測」**輸入法的完整原始碼與自動化部署腳本。

## 專案目錄結構

```text
rime_yuce_project/
├── AGENT_WORKFLOW.md             # 給本地 AI Agent 的標準實作流程說明（本檔案）
├── requirements.txt              # 本地推論伺服器所需 Python 套件
├── rime_ai_server.py             # 本地端常駐 AI 推論 HTTP 伺服器 (127.0.0.1:18989)
├── setup_rime_yuce.py            # 自動將「預測」方案寫入 %APPDATA%\Rime 並觸發重新部署的腳本
├── start_server_hidden.vbs       # Windows 背景無黑框啟動 rime_ai_server.py 的腳本
├── local_test_client.py          # 測試伺服器是否正常回應候選詞的驗證腳本
├── final_bopomofo_model/         # 放置從 Google Drive 下載的 4 個模型檔案
│   └── PLACE_MODEL_FILES_HERE.txt
├── rime_files/                   # 小狼毫 (Rime) 設定檔原始碼模板
│   ├── yuce.schema.yaml          # 「預測」輸入法主方案設定檔
│   ├── default.custom.yaml       # 註冊「預測」至小狼毫 F4 選單的補丁
│   └── lua/
│       └── yuce_translator.lua   # 小狼毫 librime-lua 橋接腳本
└── colab_training/               # (備用) Colab-MCP 遠端訓練的 4 階段 Cell 腳本
    ├── cell_01_env_and_drive.py
    ├── cell_02_tokenizer_data.py
    ├── cell_03_model_train.py
    └── cell_04_eval_unassign.py
```

---

## 本地 Agent 標準執行步驟 (Step-by-Step Instructions for Agent)

當使用者要求你（本地 AI Agent）實作並部署「預測」輸入法時，請依序執行以下步驟：

### Step 1: 確認模型檔案就位
檢查 `./final_bopomofo_model/` 資料夾內是否包含以下 4 個檔案：
- `vocab.json`
- `model.safetensors`
- `generation_config.json`
- `config.json`
*(若使用者將這 4 個檔案放在下載資料夾或其他路徑，請先將它們複製到 `./final_bopomofo_model/` 中。)*

### Step 2: 安裝本地端依賴套件
在終端機執行：
```powershell
pip install -r requirements.txt
```

### Step 3: 執行小狼毫「預測」方案自動安裝與重新部署
執行安裝腳本，將 `rime_files/` 下的方案與 Lua 腳本寫入 `%APPDATA%\Rime`，並自動尋找 `WeaselDeployer.exe /deploy` 觸發小狼毫重新部署：
```powershell
python setup_rime_yuce.py
```

### Step 4: 啟動本地端「預測」AI 推論伺服器並驗證
1. 在背景啟動 `rime_ai_server.py`（或直接執行 `wscript.exe start_server_hidden.vbs`）。
2. 執行驗證腳本確認伺服器正常回傳中文候選詞：
```powershell
python local_test_client.py
```
3. 回報使用者：已在小狼毫安裝好**「預測」**輸入法，按下 `F4` 或 `` Ctrl + ` `` 即可選擇「預測」開始打字。
