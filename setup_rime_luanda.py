# Install Luanda IME into Weasel (%APPDATA%\Rime)
import os
import shutil
import subprocess
import glob

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RIME_FILES_DIR = os.path.join(BASE_DIR, "rime_files")
RIME_USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "Rime")
LUA_DIR = os.path.join(RIME_USER_DIR, "lua")

LEGACY_SCHEMA = "yuce.schema.yaml"
LEGACY_LUA = ("yuce_translator.lua", "yuce_space.lua", "yuce_userdict.lua")


def remove_legacy():
    legacy_schema = os.path.join(RIME_USER_DIR, LEGACY_SCHEMA)
    if os.path.exists(legacy_schema):
        os.remove(legacy_schema)
        print(f"[OK] removed legacy schema: {legacy_schema}")
    for name in LEGACY_LUA:
        path = os.path.join(LUA_DIR, name)
        if os.path.exists(path):
            os.remove(path)
            print(f"[OK] removed legacy lua: {path}")


def install_rime_configs():
    if not os.environ.get("APPDATA"):
        raise RuntimeError("APPDATA not found")

    os.makedirs(LUA_DIR, exist_ok=True)
    remove_legacy()

    src_schema = os.path.join(RIME_FILES_DIR, "luanda.schema.yaml")
    dst_schema = os.path.join(RIME_USER_DIR, "luanda.schema.yaml")
    shutil.copyfile(src_schema, dst_schema)
    print(f"[OK] schema: {dst_schema}")

    for name in ("luanda_translator.lua", "luanda_space.lua", "luanda_userdict.lua"):
        src_lua = os.path.join(RIME_FILES_DIR, "lua", name)
        dst_lua = os.path.join(LUA_DIR, name)
        if os.path.exists(src_lua):
            shutil.copyfile(src_lua, dst_lua)
            print(f"[OK] lua: {dst_lua}")

    rime_lua_path = os.path.join(RIME_USER_DIR, "rime.lua")
    entries = [
        'luanda_translator = require("luanda_translator")\n',
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
        print(f"[OK] created: {default_custom_path}")
    else:
        with open(default_custom_path, "r", encoding="utf-8") as f:
            existing = f.read()
        if "schema: yuce" in existing and "schema: luanda" not in existing:
            existing = existing.replace("schema: yuce", "schema: luanda")
            with open(default_custom_path, "w", encoding="utf-8") as f:
                f.write(existing)
            print(f"[OK] renamed schema yuce -> luanda in {default_custom_path}")
        elif "schema: luanda" not in existing:
            with open(default_custom_path, "a", encoding="utf-8") as f:
                f.write('\n  "schema_list/+":\n    - schema: luanda\n')
            print(f"[OK] appended schema: luanda to {default_custom_path}")
        else:
            print(f"[OK] already has schema: luanda")


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
        print(f"deploy: {deployer_exe} /deploy")
        subprocess.run([deployer_exe, "/deploy"], check=False)
        print("[OK] deploy done. Switch to Luanda IME with F4 / Ctrl+`")
    else:
        print("[hint] WeaselDeployer.exe not found; right-click tray icon -> Redeploy")


if __name__ == "__main__":
    install_rime_configs()
    trigger_weasel_deploy()
