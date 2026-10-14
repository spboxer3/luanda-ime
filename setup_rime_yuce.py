# 自動將「亂打輸入法」安裝至 Windows 小狼毫 (%APPDATA%\Rime) 並觸發重新部署
import os
import shutil
import subprocess
import glob

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RIME_FILES_DIR = os.path.join(BASE_DIR, "rime_files")
RIME_USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "Rime")
LUA_DIR = os.path.join(RIME_USER_DIR, "lua")

def install_rime_configs():
    if not os.environ.get("APPDATA"):
        raise RuntimeError("找不到 APPDATA 環境變數，請確認在 Windows 環境下執行。")

    os.makedirs(LUA_DIR, exist_ok=True)

    # 1. 複製 yuce.schema.yaml
    src_schema = os.path.join(RIME_FILES_DIR, "yuce.schema.yaml")
    dst_schema = os.path.join(RIME_USER_DIR, "yuce.schema.yaml")
    shutil.copyfile(src_schema, dst_schema)
    print(f"[OK] 已寫入方案檔: {dst_schema}")

    # 2. 複製 lua 腳本
    for name in ("yuce_translator.lua", "yuce_space.lua"):
        src_lua = os.path.join(RIME_FILES_DIR, "lua", name)
        dst_lua = os.path.join(LUA_DIR, name)
        if os.path.exists(src_lua):
            shutil.copyfile(src_lua, dst_lua)
            print(f"[OK] 已寫入 Lua: {dst_lua}")

    # 3. 確保 rime.lua 相容性（同時支援舊版與新版 librime-lua）
    rime_lua_path = os.path.join(RIME_USER_DIR, "rime.lua")
    lua_entry = 'yuce_translator = require("yuce_translator")\n'
    if not os.path.exists(rime_lua_path):
        with open(rime_lua_path, "w", encoding="utf-8") as f:
            f.write(lua_entry)
    else:
        with open(rime_lua_path, "r", encoding="utf-8") as f:
            content = f.read()
        if "yuce_translator" not in content:
            with open(rime_lua_path, "a", encoding="utf-8") as f:
                f.write("\n" + lua_entry)
    print(f"[OK] 已更新 Lua 入口設定: {rime_lua_path}")

    # 4. 更新或建立 default.custom.yaml
    default_custom_path = os.path.join(RIME_USER_DIR, "default.custom.yaml")
    if not os.path.exists(default_custom_path):
        shutil.copyfile(os.path.join(RIME_FILES_DIR, "default.custom.yaml"), default_custom_path)
        print(f"[OK] 已建立選單設定檔: {default_custom_path}")
    else:
        with open(default_custom_path, "r", encoding="utf-8") as f:
            existing = f.read()
        if "schema: yuce" not in existing:
            with open(default_custom_path, "a", encoding="utf-8") as f:
                f.write('\n  "schema_list/+":\n    - schema: yuce\n')
            print(f"[OK] 已將 schema: yuce 附加至: {default_custom_path}")
        else:
            print(f"[OK] {default_custom_path} 已包含 schema: yuce")

def trigger_weasel_deploy():
    # 自動搜尋 Windows 常見的小狼毫安裝路徑並執行 WeaselDeployer.exe /deploy
    search_patterns = [
        r"C:\Program Files\Rime\weasel-*\WeaselDeployer.exe",
        r"C:\Program Files (x86)\Rime\weasel-*\WeaselDeployer.exe",
        os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Programs\Rime\weasel-*\WeaselDeployer.exe"),
    ]
    deployer_exe = None
    for pattern in search_patterns:
        matches = sorted(glob.glob(pattern))
        if matches:
            deployer_exe = matches[-1]
            break

    if deployer_exe and os.path.exists(deployer_exe):
        print(f"正在呼叫小狼毫自動重新部署: {deployer_exe} /deploy")
        subprocess.run([deployer_exe, "/deploy"], check=False)
        print("[OK] 小狼毫重新部署完成！請按 F4 或 Ctrl+` 切換至「亂打輸入法」。")
    else:
        print("[提示] 未在預設路徑找到 WeaselDeployer.exe，請手動對右下角小狼毫圖示按右鍵 -> 點選「重新部署」。")

if __name__ == "__main__":
    install_rime_configs()
    trigger_weasel_deploy()
