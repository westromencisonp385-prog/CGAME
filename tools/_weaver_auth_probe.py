"""Read-only Weaver connectivity probe.

The probe reports only response shape and counts; it never prints credentials,
request headers, signed URLs, or response bodies.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))

from weaver_api_client import WeaverClient  # noqa: E402
from weaver_credentials import require_credentials  # noqa: E402


def _summarize(value: object) -> dict[str, object]:
    if isinstance(value, dict):
        return {"ok": True, "type": "object", "keys": sorted(value.keys())}
    if isinstance(value, list):
        return {"ok": True, "type": "list", "count": len(value)}
    return {"ok": True, "type": type(value).__name__}


def main() -> None:
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    results: dict[str, object] = {}
    calls = {
        "quota": lambda: client.get_user_quota(rtx=rtx),
        "algorithms_3": lambda: client.list_algorithm_model(node_type=3, rtx=rtx),
        "algorithms_5": lambda: client.list_algorithm_model(node_type=5, rtx=rtx),
    }
    for name, call in calls.items():
        try:
            results[name] = _summarize(call())
        except Exception as exc:  # noqa: BLE001 - probe must report endpoint failures
            results[name] = {"ok": False, "error_type": type(exc).__name__, "message": str(exc)[:200]}
    print(json.dumps(results, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
