# -*- coding: utf-8 -*-
"""Probe failed weaver task details."""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
from weaver_api_client import WeaverClient

txt = (Path(r"D:\工作\生图API\weaver") / "鉴权.txt").read_text(encoding="utf-8")
client = WeaverClient(re.search(r"vsa_[0-9a-f]+", txt).group(), re.search(r"vss_[0-9a-f]+", txt).group())

for mid in sys.argv[1:]:
    rows, _ = client.get_model_list(model_id_list=[mid], limit=20, rtx="jasonlyan")
    for row in rows:
        slim = {k: v for k, v in row.items() if k not in ("input_view",)}
        print(mid, "->", str(slim)[:600])
