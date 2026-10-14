# 本地端測試腳本：驗證 rime_ai_server.py 是否正常運作
import urllib.request
import urllib.parse

def test_query(keys: str):
    url = f"http://127.0.0.1:18989/?keys={urllib.parse.quote(keys)}"
    try:
        with urllib.request.urlopen(url, timeout=3.0) as resp:
            body = resp.read().decode("utf-8").strip()
            print(f"測試輸入按鍵: {keys} -> 預測候選詞: {body.splitlines()}")
    except Exception as e:
        print(f"連線失敗 ({e})，請確認是否已啟動 python rime_ai_server.py")

if __name__ == "__main__":
    # 測試「你好」(su3cl3) 與誤觸版 (su3ck3)
    test_query("su3cl3")
    test_query("su3ck3")
