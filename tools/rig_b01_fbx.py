"""Generate a B01 reverse-crab rigging candidate through Weaver."""

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

ZIP = ROOT / "artifacts/weaver/authored/enemy_b01_rig_input.zip"
OUT = ROOT / "artifacts/weaver/api_candidates/b01_rig"
REPORT = OUT / "report.json"


def main() -> None:
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    credential = client.get_cos_cred(rtx=rtx)
    source_url = client.upload_file(
        ZIP,
        credential,
        object_name=cos_object_name(credential, "cgame/actions/b01_rig_input.zip"),
    )
    task_id = first_model_id(
        client.gen_3d_model(
            name="CGAME_b01_reverse_crab_rig_fbx",
            node_type=5,
            input_model=source_url,
            params={
                "go_rigging_params": {
                    "algorithm_model": "MotusAI-Rigging-V2.0",
                    "enable_auto_skinning": False,
                }
            },
            rtx=rtx,
        )
    )
    record = wait_for_model(client, task_id, rtx=rtx)
    output_files = [
        download_metadata(client, url, OUT / f"{task_id}_{index}.zip")
        for index, url in enumerate(output_urls_or_download(client, record, task_id, rtx=rtx), 1)
    ]
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        json.dumps(
            {
                "task_id": task_id,
                "status": record.get("status"),
                "outputs": output_files,
                "note": "FBX+model.json rigging contract",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"report": str(REPORT), "outputs": output_files}, ensure_ascii=False))


if __name__ == "__main__":
    main()
