"""Submit and download the A01 style-anchor Weaver candidates.

This script intentionally performs live generation only when run explicitly.
Importing it and running the offline checks never contacts Weaver.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))

from weaver_api_client import WeaverClient  # noqa: E402
from weaver_credentials import require_credentials  # noqa: E402
from weaver_asset_helpers import (  # noqa: E402
    cos_object_name,
    download_metadata,
    first_model_id,
    output_urls_or_download,
    wait_for_model,
)

INPUT = ROOT / "artifacts/weaver/inputs/player_a01-style-v4.png"
OUT = ROOT / "artifacts/weaver/api_candidates/player_a01"
REPORT = ROOT / "artifacts/weaver/api_candidates/player_a01-report.json"


def main() -> None:
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    credential = client.get_cos_cred(rtx=rtx)

    source_url = client.upload_file(
        INPUT,
        credential,
        object_name=cos_object_name(credential, "cgame/style-v4/player_a01.png"),
    )
    view_task_id = client.gen_multi_views(
        name="CGAME_style_v4_player_a01_360",
        input_view={"main_view": source_url},
        params={
            "image_gen_360_params": {
                "algorithm_model": "VV-MultiView-V1.0.0",
                "enable_a_pose": False,
            }
        },
        rtx=rtx,
    )
    view_record = wait_for_model(client, view_task_id, rtx=rtx)
    views = (view_record.get("image_gen_360_output") or {}).get("output_view") or {}
    input_view = {
        key: value
        for name in ("main_view", "back_view", "left_view", "right_view")
        for key, value in [(name, views.get(name))]
        if isinstance(value, str) and value
    }
    if "main_view" not in input_view:
        raise RuntimeError("360 task completed without a main_view")

    model_task_id = first_model_id(
        client.gen_3d_model(
            name="CGAME_style_v4_player_a01_high",
            node_type=3,
            input_view=input_view,
            params={
                "image_gen_model_params": {
                    "algorithm_model": "Hy3D-3.5-0515",
                    "output_model_format": "glb",
                    "face_type": 1,
                    "face_num": 30000,
                    "strict_mode": True,
                    "skip_360_preprocess": True,
                }
            },
            rtx=rtx,
        )
    )
    model_record = wait_for_model(client, model_task_id, rtx=rtx)
    output_urls = output_urls_or_download(client, model_record, model_task_id, rtx=rtx)
    files = [
        download_metadata(client, url, OUT / f"{model_task_id}_{index}.zip")
        for index, url in enumerate(output_urls, 1)
    ]

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        json.dumps(
            {
                "asset_id": "player.machine.a01_whale_jaw",
                "style_anchor": "docs/assets/style-anchor-industrial-folk-v1.png",
                "view_task_id": view_task_id,
                "model_task_id": model_task_id,
                "model_status": model_record.get("status"),
                "outputs": files,
                "review": "pending_blender_and_godot_style_check",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"report": str(REPORT), "outputs": [item["path"] for item in files]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
