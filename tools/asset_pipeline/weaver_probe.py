# -*- coding: utf-8 -*-
"""Weaver API 连通性探测：只查配额（零成本），验证签名/鉴权/网络。不打印凭证。"""
from pathlib import Path
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
from weaver_api_client import WeaverClient, WeaverError

txt = open(r"D:\工作\生图API\weaver\鉴权.txt", encoding="utf-8").read()
app_id = re.search(r"vsa_[0-9a-f]+", txt).group()
secret = re.search(r"vss_[0-9a-f]+", txt).group()

try:
    c = WeaverClient(app_id, secret)
    quota = c.get_user_quota(rtx="jasonlyan")
    print(f"模型配额: {quota.get('model_quota')}, 动画配额: {quota.get('animation_quota')}, "
          f"图片处理配额: {quota.get('image_processing_quota')}")
    print("Weaver 通道 OK")
except (WeaverError, Exception) as e:
    print(f"FAIL: {e}")
