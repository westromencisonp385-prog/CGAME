import json
import sys

sys.path.insert(0, r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient
from weaver_credentials import require_credentials

app_id, secret, rtx, base_url = require_credentials()

client = WeaverClient(
    app_id,
    secret,
    rtx,
    base_url,
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
