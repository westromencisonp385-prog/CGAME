# -*- coding: utf-8 -*-
"""提取 .doc 老格式 Word 文档文本（伪解析：WordDocument 流 UTF-16 扫描）"""
from pathlib import Path
import olefile, re, sys, os
sys.stdout.reconfigure(encoding="utf-8")

def doc_text(path):
    ole = olefile.OleFileIO(path)
    data = ole.openstream("WordDocument").read()
    txt = data.decode("utf-16-le", errors="ignore")
    pat = re.compile(r"[\u4e00-\u9fffA-Za-z0-9 _\-/:.,(){}\[\]\"'=|+*&%$#@!?~^<>\n\r\t]{4,}")
    chunks = pat.findall(txt)
    return "\n".join(chunks)

src = r"D:\工作\生图API\生成模型"
out = str(Path(__file__).parent / "doc_extract")
os.makedirs(out, exist_ok=True)
for fn in os.listdir(src):
    if fn.endswith(".doc"):
        t = doc_text(os.path.join(src, fn))
        name = fn.replace(".doc", "").replace("+", "_") + ".txt"
        with open(os.path.join(out, name), "w", encoding="utf-8") as f:
            f.write(t)
        print(f"[OK] {fn} -> {len(t)} chars")
