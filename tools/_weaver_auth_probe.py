import json
import os
import sys
from pathlib import Path

sys.path.insert(0, r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient

values = {}
for line in Path(r"D:\工作\AI工具\ComfyUI\appid.txt").read_text(encoding="utf-8").splitlines():
    delimiter = ":" if ":" in line else "="
    if delimiter in line:
        key, value = line.split(delimiter, 1)
        values[key.strip().upper().replace(" ", "_")] = value.strip()

client = WeaverClient(
    os.environ.get("WEAVER_APPID") or values.get("APPID") or values.get("APP_ID"),
    os.environ.get("WEAVER_APPSECRET") or values.get("APP_SECRET") or values.get("APPSECRET") or values.get("KEY"),
    os.environ.get("USERNAME") or "jasonlyan",
    "https://ws.visvise.com.cn",
)
result = {}
for name, call in (
    ("quota", client.get_user_quota),
    ("algorithms_3", lambda: client.list_algorithm_model(3)),
    ("algorithms_4", lambda: client.list_algorithm_model(4)),
    ("algorithms_5", lambda: client.list_algorithm_model(5)),
    ("algorithms_6", lambda: client.list_algorithm_model(6)),
    ("algorithms_11", lambda: client.list_algorithm_model(11)),
    ("algorithms_7", lambda: client.list_algorithm_model(7)),
    ("algorithms_1", lambda: client.list_algorithm_model(1)),
    ("algorithms_2", lambda: client.list_algorithm_model(2)),
    ("algorithms_8", lambda: client.list_algorithm_model(8)),
    ("algorithms_9", lambda: client.list_algorithm_model(9)),
    ("algorithms_12", lambda: client.list_algorithm_model(12)),
):
    try:
        response = call()
        result[name] = {
            "code": response.get("code"),
            "msg": response.get("msg"),
            "data": response.get("data"),
        }
    except Exception as exc:
        result[name] = {"error": type(exc).__name__, "message": str(exc)[:300]}
print(json.dumps(result, ensure_ascii=False, indent=2))
