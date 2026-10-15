# -*- coding: utf-8 -*-
"""將亂打輸入法安裝到小狼毫使用者目錄（不依賴 Downloads 解壓位置）。"""
import glob
import os
import shutil
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RIME_FILES_DIR = os.path.join(BASE_DIR, "rime_files")
RIME_USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "Rime")
LUA_DIR = os.path.join(RIME_USER_DIR, "lua")
# 推論服務 + 模型：固定裝在輸入法使用者目錄下
INSTALL_DIR = os.path.join(RIME_USER_DIR, "luanda")
STARTUP_DIR = os.path.join(
    os.environ.get("APPDATA", ""),
    r"Microsoft\Windows\Start Menu\Programs\Startup",
)
AUTOSTART_NAME = "luanda_ime_server.vbs"

LEGACY_SCHEMA = "yuce.schema.yaml"
LEGACY_LUA = ("yuce_translator.lua", "yuce_space.lua", "yuce_userdict.lua")

RUNTIME_FILES = (
    "rime_ai_server.py",
    "polyphone_boost.json",
    "requirements.txt",
    "start_server_hidden.vbs",
)
MODEL_DIRNAME = "luanda_bopomofo_int8"


def remove_legacy():
    legacy_schema = os.path.join(RIME_USER_DIR, LEGACY_SCHEMA)
    if os.path.exists(legacy_schema):
        os.remove(legacy_schema)
        print(f"[OK] 已移除舊方案: {legacy_schema}")
    for name in LEGACY_LUA:
        path = os.path.join(LUA_DIR, name)
        if os.path.exists(path):
            os.remove(path)
            print(f"[OK] 已移除舊 Lua: {path}")


def stop_running_server():
    ps = (
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
        "Where-Object { $_.CommandLine -match 'rime_ai_server' } | "
        "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
    )
    subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
        check=False,
        capture_output=True,
    )


def install_runtime():
    """複製伺服器與模型到 %APPDATA%\\Rime\\luanda\\"""
    if not os.environ.get("APPDATA"):
        raise RuntimeError("找不到 APPDATA")

    model_src = os.path.join(BASE_DIR, MODEL_DIRNAME)
    model_bin = os.path.join(model_src, "model.bin")
    if not os.path.isfile(model_bin):
        raise FileNotFoundError(
            f"找不到模型 {model_bin}\n"
            "請先把 Release 的 luanda_bopomofo_int8.zip 解壓到與 install.bat 同一層。"
        )

    for name in RUNTIME_FILES:
        src = os.path.join(BASE_DIR, name)
        if not os.path.isfile(src):
            raise FileNotFoundError(f"缺少安裝檔: {src}")

    os.makedirs(INSTALL_DIR, exist_ok=True)

    for name in RUNTIME_FILES:
        src = os.path.join(BASE_DIR, name)
        dst = os.path.join(INSTALL_DIR, name)
        shutil.copy2(src, dst)
        print(f"[OK] 執行檔: {dst}")

    model_dst = os.path.join(INSTALL_DIR, MODEL_DIRNAME)
    if os.path.isdir(model_dst):
        shutil.rmtree(model_dst)
    print(f"[..] 複製模型到 {model_dst} （約數十 MB，請稍候）...")
    shutil.copytree(model_src, model_dst)
    print(f"[OK] 模型: {model_dst}")

    # 寫入路徑說明，方便使用者找
    readme = os.path.join(INSTALL_DIR, "README.txt")
    with open(readme, "w", encoding="utf-8") as f:
        f.write(
            "亂打輸入法 — 本機推論服務安裝目錄\n"
            "請勿刪除此資料夾，否則候選會失效。\n"
            "手動啟動：雙擊 start_server_hidden.vbs\n"
            f"完整路徑：{INSTALL_DIR}\n"
        )
    print(f"[OK] 執行環境已安裝到: {INSTALL_DIR}")
    return INSTALL_DIR


def install_autostart():
    """開機自動從安裝目錄啟動伺服器。"""
    os.makedirs(STARTUP_DIR, exist_ok=True)
    starter = os.path.join(STARTUP_DIR, AUTOSTART_NAME)
    vbs = (
        'Set sh = CreateObject("WScript.Shell")\r\n'
        'installDir = sh.ExpandEnvironmentStrings("%APPDATA%\\Rime\\luanda")\r\n'
        "sh.CurrentDirectory = installDir\r\n"
        'sh.Run "python ""rime_ai_server.py""", 0, False\r\n'
    )
    with open(starter, "w", encoding="utf-8", newline="") as f:
        f.write(vbs)
    print(f"[OK] 開機啟動: {starter}")


def start_server():
    stop_running_server()
    vbs = os.path.join(INSTALL_DIR, "start_server_hidden.vbs")
    if not os.path.isfile(vbs):
        raise FileNotFoundError(vbs)
    subprocess.run(["wscript.exe", vbs], check=False)
    print(f"[OK] 已從安裝目錄啟動伺服器: {INSTALL_DIR}")


def install_rime_configs():
    if not os.environ.get("APPDATA"):
        raise RuntimeError("找不到 APPDATA 環境變數，請確認在 Windows 環境下執行。")

    onion = os.path.join(RIME_USER_DIR, "bopomo_onionplus.schema.yaml")
    if not os.path.isfile(onion):
        raise FileNotFoundError(
            "找不到洋蔥注音 plus（bopomo_onionplus.schema.yaml）。\n"
            "亂打 2.0 以洋蔥為底，請先安裝洋蔥後再執行 install.bat。"
        )

    os.makedirs(LUA_DIR, exist_ok=True)
    remove_legacy()

    for name in ("luanda.schema.yaml", "luanda.custom.yaml"):
        src = os.path.join(RIME_FILES_DIR, name)
        dst = os.path.join(RIME_USER_DIR, name)
        shutil.copyfile(src, dst)
        print(f"[OK] 方案: {dst}")

    for name in (
        "luanda_translator.lua",
        "luanda_tab_ai.lua",
        "luanda_space.lua",
        "luanda_userdict.lua",
    ):
        src_lua = os.path.join(RIME_FILES_DIR, "lua", name)
        dst_lua = os.path.join(LUA_DIR, name)
        if os.path.exists(src_lua):
            shutil.copyfile(src_lua, dst_lua)
            print(f"[OK] Lua: {dst_lua}")

    rime_lua_path = os.path.join(RIME_USER_DIR, "rime.lua")
    # 使用 lua_processor@*module 時不強制寫入 rime.lua；保留舊 require 以免殘留引用報錯
    entries = [
        'luanda_translator = require("luanda_translator")\n',
        'luanda_tab_ai = require("luanda_tab_ai")\n',
        'luanda_space = require("luanda_space")\n',
    ]
    if not os.path.exists(rime_lua_path):
        with open(rime_lua_path, "w", encoding="utf-8") as f:
            f.writelines(entries)
    else:
        with open(rime_lua_path, "r", encoding="utf-8") as f:
            content = f.read()
        lines = [ln for ln in content.splitlines(True) if "yuce_" not in ln]
        content = "".join(lines)
        for entry in entries:
            key = entry.split("=")[0].strip()
            if key not in content:
                content = content.rstrip() + "\n" + entry
        with open(rime_lua_path, "w", encoding="utf-8") as f:
            f.write(content if content.endswith("\n") else content + "\n")
    print(f"[OK] rime.lua: {rime_lua_path}")

    default_custom_path = os.path.join(RIME_USER_DIR, "default.custom.yaml")
    if not os.path.exists(default_custom_path):
        shutil.copyfile(os.path.join(RIME_FILES_DIR, "default.custom.yaml"), default_custom_path)
        print(f"[OK] 已建立: {default_custom_path}")
    else:
        with open(default_custom_path, "r", encoding="utf-8") as f:
            existing = f.read()
        if "schema: yuce" in existing and "schema: luanda" not in existing:
            existing = existing.replace("schema: yuce", "schema: luanda")
            with open(default_custom_path, "w", encoding="utf-8") as f:
                f.write(existing)
            print(f"[OK] schema yuce → luanda: {default_custom_path}")
        elif "schema: luanda" not in existing:
            with open(default_custom_path, "a", encoding="utf-8") as f:
                f.write('\n  "schema_list/+":\n    - schema: luanda\n')
            print(f"[OK] 已附加 schema: luanda")
        else:
            print("[OK] 選單已包含 schema: luanda")


def trigger_weasel_deploy():
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
        print(f"正在重新部署小狼毫: {deployer_exe}")
        subprocess.run([deployer_exe, "/deploy"], check=False)
        print("[OK] 部署完成。請按 F4 / Ctrl+` 切換「亂打輸入法」。")
    else:
        print("[提示] 未找到 WeaselDeployer.exe，請手動：小狼毫圖示右鍵 → 重新部署")


def main():
    print(f"安裝目標（推論）: {INSTALL_DIR}")
    print(f"安裝目標（方案）: {RIME_USER_DIR}")
    install_runtime()
    install_rime_configs()
    install_autostart()
    trigger_weasel_deploy()
    start_server()
    print()
    print("完成。之後可刪除 Downloads 裡的解壓資料夾，不影響使用。")
    print(f"若候選消失，請執行: {os.path.join(INSTALL_DIR, 'start_server_hidden.vbs')}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"[錯誤] {exc}", file=sys.stderr)
        sys.exit(1)
