import subprocess, sys, os
subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pypinyin", "transformers", "datasets", "accelerate", "torch", "tqdm"])
from google.colab import drive
drive.mount('/content/drive')
SAVE_DIR = "/content/drive/MyDrive/bopomofo_ime_project"
os.makedirs(SAVE_DIR, exist_ok=True)
