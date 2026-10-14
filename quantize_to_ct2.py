# 檔案名稱：quantize_to_ct2.py
import os
import json
import shutil
import ctranslate2
from transformers import BartForConditionalGeneration

SRC_MODEL_DIR = "./final_bopomofo_model"
OUT_CT2_DIR = "./luanda_bopomofo_int8"

class VocabTokenizerStub:
    """提供 CT2 BartLoader 所需的最小 tokenizer 介面（get_vocab / 特殊 token / id 轉 token）"""
    def __init__(self, vocab_list, config):
        self.vocab_list = vocab_list
        self.bos_token = vocab_list[config.bos_token_id]
        self.eos_token = vocab_list[config.eos_token_id]
        self.unk_token = "[UNK]"

    def get_vocab(self):
        return {tok: idx for idx, tok in enumerate(self.vocab_list)}

    def convert_ids_to_tokens(self, idx):
        return self.vocab_list[idx]

class CustomBartCT2Converter(ctranslate2.converters.TransformersConverter):
    """自訂轉換器：直接讀取我們的 vocab.json 而不依賴標準 AutoTokenizer"""
    def load_model(self, model_class, model_name_or_path, **kwargs):
        model = super().load_model(model_class, model_name_or_path, **kwargs)
        # transformers 5.x 的 BartConfig 已移除 normalize_before，但 CT2 轉換器仍會讀取；BART 為 post-norm
        if not hasattr(model.config, "normalize_before"):
            model.config.normalize_before = False
        self._config = model.config
        return model

    def load_tokenizer(self, tokenizer_class, model_name_or_path, **kwargs):
        vocab_path = os.path.join(model_name_or_path, "vocab.json")
        with open(vocab_path, "r", encoding="utf-8") as f:
            vocab_list = json.load(f)
        return VocabTokenizerStub(vocab_list, self._config)

def main():
    if not os.path.exists(SRC_MODEL_DIR):
        print(f"找不到 {SRC_MODEL_DIR} 資料夾！")
        return

    print("正在將模型轉換為 CTranslate2 INT8 極速量化格式...")
    converter = CustomBartCT2Converter(SRC_MODEL_DIR)
    converter.convert(
        output_dir=OUT_CT2_DIR,
        quantization="int8",
        force=True
    )
    # 將原本的 vocab.json 一併複製過去供本地推論讀取
    shutil.copyfile(
        os.path.join(SRC_MODEL_DIR, "vocab.json"),
        os.path.join(OUT_CT2_DIR, "vocab.json")
    )
    print(f"壓縮完成！極速版模型已儲存於：{OUT_CT2_DIR}")

if __name__ == "__main__":
    main()