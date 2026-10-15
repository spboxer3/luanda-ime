# 「預測」輸入法推論服務：CTranslate2 INT8 + 檔案 IPC（Rime Lua 零行程）
import os
import sys
import json
import time
import threading
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import ctranslate2

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CT2_MODEL_DIR = os.path.join(BASE_DIR, "luanda_bopomofo_int8")
POLYPHONE_FILE = os.path.join(BASE_DIR, "polyphone_boost.json")
PORT = 18989
CACHE_SIZE = 512
# 總候選上限（一次推給 Rime）；畫面上仍每頁 9 個，用 = / - 翻頁
PAGE_SIZE = 9
MAX_CANDIDATES = 45  # 分頁用；等待邏輯維持短等
IPC_DIR = os.path.join(os.environ.get("APPDATA", BASE_DIR), "Rime", "luanda", "ipc")
REQ_FILE = os.path.join(IPC_DIR, "request.txt")
CAND_FILE = os.path.join(IPC_DIR, "candidates.txt")
KEYS_FILE = os.path.join(IPC_DIR, "response_keys.txt")
STATUS_FILE = os.path.join(IPC_DIR, "status.txt")
LOADING_TEXT = "[模型載入中]"
MODEL_READY = threading.Event()

# 大千鍵 → 注音（與 Lua preedit 相同）
ZHUYIN_MAP = {
    "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
    "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
    "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
    "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
    "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
    "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
    "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
    "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
    "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
    "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ",
    "-": "ㄦ",
    "_": "ˉ", " ": "ˉ",
    "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙",
}


def load_polyphone_boost() -> dict[str, list[str]]:
    if not os.path.exists(POLYPHONE_FILE):
        return {}
    with open(POLYPHONE_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {str(k): list(v) for k, v in data.items()}


def keys_to_zhuyin(keys: str) -> str:
    return "".join(ZHUYIN_MAP.get(ch, ch) for ch in keys)


class LRUCache:
    def __init__(self, capacity: int):
        self.capacity = capacity
        self._data: OrderedDict[str, str] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: str):
        with self._lock:
            if key not in self._data:
                return None
            self._data.move_to_end(key)
            return self._data[key]

    def put(self, key: str, value: str) -> None:
        with self._lock:
            if key in self._data:
                self._data.move_to_end(key)
            self._data[key] = value
            if len(self._data) > self.capacity:
                self._data.popitem(last=False)


def load_ct2_engine():
    vocab_file = os.path.join(CT2_MODEL_DIR, "vocab.json")
    if not os.path.exists(vocab_file):
        print(f"[錯誤] 找不到 {CT2_MODEL_DIR}，請先執行 python quantize_to_ct2.py")
        sys.exit(1)

    with open(vocab_file, "r", encoding="utf-8") as f:
        vocab = json.load(f)

    print("正在載入 CTranslate2 INT8 模型...")
    translator = ctranslate2.Translator(
        CT2_MODEL_DIR,
        device="cpu",
        compute_type="int8",
        # 9 候選時略增執行緒，縮短單次推論
        intra_threads=2,
        inter_threads=1,
    )
    valid_tokens = set(vocab)
    translator.translate_batch(
        [["[BOS]", "s", "u", "3", "[EOS]"]],
        target_prefix=[["[BOS]"]],
        beam_size=1,
        num_hypotheses=1,
        max_decoding_length=4,
    )
    print(f"模型就緒 | IPC={IPC_DIR} | http://127.0.0.1:{PORT}")
    return translator, valid_tokens


os.makedirs(IPC_DIR, exist_ok=True)
CACHE = LRUCache(CACHE_SIZE)
INFER_LOCK = threading.Lock()
# 模型稍後在 main 載入；載入前 IPC 可先回「載入中」
TRANSLATOR = None
VALID_TOKENS = set()
POLYPHONE_BOOST = {}


def write_status(status: str) -> None:
    atomic_write(STATUS_FILE, status)


def tokenize_to_tokens(text: str) -> list[str]:
    tokens = ["[BOS]"]
    for ch in text[:126]:
        tokens.append(ch if ch in VALID_TOKENS else "[UNK]")
    tokens.append("[EOS]")
    return tokens


def detokenize_tokens(tokens: list[str]) -> str:
    chars = []
    for t in tokens:
        if t in ("[BOS]", "[PAD]"):
            continue
        if t == "[EOS]":
            break
        chars.append(t)
    return "".join(chars)


def count_syllables(keys: str) -> int:
    """依聲調鍵估算音節數（一個音節≈一個字）。"""
    n = sum(1 for ch in keys if ch in "3467_ ")
    if keys and keys[-1] not in "3467_ ":
        n += 1  # 未完成的尾音節
    return max(1, n)


def estimate_max_len(keys: str) -> int:
    syll = count_syllables(keys)
    # 略留餘裕，避免長句被截斷；上限避免極端過長
    return max(syll + 2, min(64, syll + 6))


def is_syllable_complete(keys: str) -> bool:
    """字根未完聲調時用較輕 beam，完整音節才上 9 候選。"""
    return bool(keys) and keys[-1] in "3467_ "


def rank_by_expected_length(candidates: list[str], expected: int) -> list[str]:
    """把長度接近音節數的候選排前面，並丟掉過短結果（避免中間字被吃掉）。"""
    if expected <= 1:
        return candidates

    def sort_key(text: str):
        length = len(text)
        if length == expected:
            return (0, 0)
        if length == expected + 1:
            return (1, 0)
        if length == expected - 1:
            return (2, 0)
        if length < expected - 1:
            return (4, expected - length)  # 過短最後
        return (3, length - expected)

    ranked = sorted(candidates, key=sort_key)
    # 完整句：優先保留長度 >= expected-1；若全被濾掉則退回 ranked
    kept = [c for c in ranked if len(c) >= max(1, expected - 1)]
    return kept if kept else ranked


def last_zhuyin_syllable(zhuyin: str) -> str:
    tone_marks = set("ˉˊˇˋ˙")
    last_tone = -1
    for i in range(len(zhuyin) - 1, -1, -1):
        if zhuyin[i] in tone_marks:
            last_tone = i
            break
    if last_tone < 0:
        return zhuyin
    prev = 0
    for i in range(last_tone - 1, -1, -1):
        if zhuyin[i] in tone_marks:
            prev = i + 1
            break
    return zhuyin[prev : last_tone + 1]


def merge_polyphone_boost(clean_keys: str, candidates: list[str]) -> list[str]:
    """模型常漏破音字（如 ㄔㄤˊ→長）；以表補強並放到前面。"""
    zhuyin = keys_to_zhuyin(clean_keys)
    merged: list[str] = []
    expected = count_syllables(clean_keys)

    exact = POLYPHONE_BOOST.get(zhuyin, [])
    if exact:
        merged.extend(exact)
    elif expected == 1:
        # 僅單字時做末音節補強，避免多字句被替末字搞亂長度
        syll = last_zhuyin_syllable(zhuyin)
        merged.extend(POLYPHONE_BOOST.get(syll, []))

    merged.extend(candidates)
    return list(dict.fromkeys(c for c in merged if c))[:MAX_CANDIDATES]


def predict(clean_keys: str) -> str:
    if not MODEL_READY.is_set() or TRANSLATOR is None:
        return LOADING_TEXT

    cached = CACHE.get(clean_keys)
    if cached is not None:
        return cached

    source_tokens = tokenize_to_tokens(clean_keys)
    max_len = estimate_max_len(clean_keys)
    expected = count_syllables(clean_keys)
    complete = is_syllable_complete(clean_keys)
    # 字根階段少算以求快；完整音節拉高 beam，供多頁翻閱
    beam = MAX_CANDIDATES if complete else PAGE_SIZE
    hyps = MAX_CANDIDATES if complete else PAGE_SIZE

    with INFER_LOCK:
        cached = CACHE.get(clean_keys)
        if cached is not None:
            return cached
        results = TRANSLATOR.translate_batch(
            [source_tokens],
            target_prefix=[["[BOS]"]],
            beam_size=beam,
            num_hypotheses=hyps,
            max_decoding_length=max_len,
            min_decoding_length=max(1, expected) if complete and expected >= 2 else 1,
        )

    candidates = [detokenize_tokens(hyp) for hyp in results[0].hypotheses]
    candidates = [c for c in candidates if c]
    if complete:
        candidates = merge_polyphone_boost(clean_keys, candidates)
        candidates = rank_by_expected_length(candidates, expected)
    candidates = list(dict.fromkeys(candidates))[:MAX_CANDIDATES]
    result_text = "\n".join(candidates)
    CACHE.put(clean_keys, result_text)
    return result_text


def atomic_write(path: str, text: str) -> None:
    """Robust write: unique tmp + retries (Weasel may briefly lock IPC files)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = f"{path}.{os.getpid()}.{time.time_ns()}.tmp"
    last_err: Exception | None = None
    for _ in range(8):
        try:
            with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            os.replace(tmp, path)
            return
        except OSError as exc:
            last_err = exc
            try:
                if os.path.exists(tmp):
                    os.remove(tmp)
            except OSError:
                pass
            time.sleep(0.05)
    # Last resort: direct overwrite (non-atomic)
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        return
    except OSError:
        if last_err:
            raise last_err
        raise


def write_response(raw_keys: str, candidates: str) -> None:
    # 先寫候選再寫 keys，Lua 以 keys 檔作為「本次已就緒」訊號
    atomic_write(CAND_FILE, candidates)
    atomic_write(KEYS_FILE, raw_keys)


def ipc_poll_loop():
    last_keys = None
    last_mtime = None
    while True:
        try:
            if not os.path.exists(REQ_FILE):
                time.sleep(0.02)
                continue
            mtime = os.path.getmtime(REQ_FILE)
            if mtime == last_mtime:
                time.sleep(0.01)
                continue
            with open(REQ_FILE, "r", encoding="utf-8") as f:
                raw = f.read().strip()
            last_mtime = mtime
            if not raw or len(raw) < 2:
                continue
            # 同一內容若已回過可跳過；但允許快取命中極速重寫，方便 Lua 等到
            if raw == last_keys and CACHE.get(raw.replace("_", " ")) is not None:
                write_response(raw, CACHE.get(raw.replace("_", " ")))
                continue
            last_keys = raw
            clean = raw.replace("_", " ")
            result = predict(clean)
            write_response(raw, result)
        except Exception as exc:
            print(f"[IPC] {exc}")
            time.sleep(0.05)


class RimeHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        query = parse_qs(urlparse(self.path).query)
        raw_keys = query.get("keys", [""])[0]
        clean_keys = raw_keys.replace("_", " ")
        body = b""
        if clean_keys and len(clean_keys) >= 2:
            body = predict(clean_keys).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if body:
            self.wfile.write(body)


def bootstrap_model() -> None:
    global TRANSLATOR, VALID_TOKENS, POLYPHONE_BOOST
    write_status("loading")
    write_response("", LOADING_TEXT)
    TRANSLATOR, VALID_TOKENS = load_ct2_engine()
    POLYPHONE_BOOST = load_polyphone_boost()
    print(f"破音字補強條目: {len(POLYPHONE_BOOST)}")
    MODEL_READY.set()
    write_status("ready")
    # 載入完成後立刻處理目前組字請求，方便候選從「載入中」換成真結果
    try:
        if os.path.exists(REQ_FILE):
            with open(REQ_FILE, "r", encoding="utf-8") as f:
                raw = f.read().strip()
            if raw and len(raw) >= 2:
                write_response(raw, predict(raw.replace("_", " ")))
    except Exception as exc:
        print(f"[IPC] flush after load: {exc}")


if __name__ == "__main__":
    os.makedirs(IPC_DIR, exist_ok=True)
    # 先佔埠；已有實例則立刻退出，避免第二份寫 loading 把 ready 蓋掉、搶 IPC
    try:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), RimeHandler)
    except OSError:
        print(f"[luanda] already running on port {PORT}, exit")
        sys.exit(0)

    write_status("loading")
    write_response("", LOADING_TEXT)
    # 先開 IPC，讓小狼毫在載入期間就能收到「模型載入中」
    threading.Thread(target=ipc_poll_loop, name="luanda-ipc", daemon=True).start()
    bootstrap_model()
    server.serve_forever()
