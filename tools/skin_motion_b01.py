"""Run B01 skinning and text-to-motion candidates through Weaver."""

from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path
from typing import Any

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

RIG_FBX = ROOT / "artifacts/weaver/api_candidates/b01_rig/extracted/CGAME_b01_reverse_crab_rig_fbx.fbx"
OUT = ROOT / "artifacts/weaver/api_candidates/b01_motion"
REPORT = OUT / "report.json"
MESHES = [
    "Chassis",
    "Barrier_L",
    "Barrier_R",
    "Barrier_Stripe_L",
    "Barrier_Stripe_R",
    "Leg_L_B_Foot",
    "Leg_L_B_Upper",
    "Leg_L_F_Foot",
    "Leg_L_F_Upper",
    "Leg_R_B_Foot",
    "Leg_R_B_Upper",
    "Leg_R_F_Foot",
    "Leg_R_F_Upper",
    "WarningBeacon",
]
JOINTS = ["pelvis", "bone_01", "bone_02", "bone_03", "bone_04", "clavicle_l_01"]


def pack(name: str, extra: dict[str, Any]) -> Path:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as handle:
        handle.write(RIG_FBX, "CGAME_b01_reverse_crab_rig_fbx.fbx")
        handle.writestr(
            "model.json",
            json.dumps(extra, ensure_ascii=False, indent=2),
        )
    return path


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    credential = client.get_cos_cred(rtx=rtx)
    report: dict[str, Any] = {
        "schema_version": 1,
        "mesh_names": MESHES,
        "joint_names": JOINTS,
        "tasks": [],
    }

    skin_zip = pack(
        "b01_skinning_input.zip",
        {
            "config": {"algo_name": "MotusAI-Skinning-V1.0"},
            "selection": {"mesh_names": MESHES, "joint_names": JOINTS},
        },
    )
    skin_source_url = client.upload_file(
        skin_zip,
        credential,
        object_name=cos_object_name(credential, "cgame/actions/b01_skinning_input.zip"),
    )
    skin_task_id = first_model_id(
        client.gen_3d_model(
            name="CGAME_b01_reverse_crab_skinning",
            node_type=6,
            input_model=skin_source_url,
            params={},
            rtx=rtx,
        )
    )
    skin_record = wait_for_model(client, skin_task_id, rtx=rtx)
    skin_files = [
        download_metadata(client, url, OUT / f"{skin_task_id}_{index}.zip")
        for index, url in enumerate(
            output_urls_or_download(client, skin_record, skin_task_id, rtx=rtx),
            1,
        )
    ]
    skin_row: dict[str, Any] = {
        "node_type": 6,
        "task_id": skin_task_id,
        "status": skin_record.get("status"),
        "outputs": skin_files,
    }
    report["tasks"].append(skin_row)

    if skin_files:
        motion_source_url = client.upload_file(
            skin_files[0]["path"],
            credential,
            object_name=cos_object_name(credential, "cgame/actions/b01_text_motion_input.zip"),
        )
        motion_task_id = first_model_id(
            client.gen_3d_model(
                name="CGAME_b01_reverse_crab_text_motion",
                node_type=4,
                input_model=motion_source_url,
                params={
                    "framing_ai_params": {
                        "algorithm_model": "MotusAI-T2M-V1.5",
                        "output_model_format": "fbx",
                        "segments": [
                            {"text": "待机，身体稳定地轻微呼吸", "num_frames": 60},
                            {"text": "向侧面快速冲刺", "num_frames": 90, "overlap_frames_with_prev": 10},
                            {"text": "撞上墙后明显反弹并恢复平衡", "num_frames": 60, "overlap_frames_with_prev": 10},
                        ],
                    }
                },
                rtx=rtx,
            )
        )
        motion_record = wait_for_model(client, motion_task_id, rtx=rtx, timeout=1500)
        motion_files = [
            download_metadata(client, url, OUT / f"{motion_task_id}_{index}.zip")
            for index, url in enumerate(
                output_urls_or_download(client, motion_record, motion_task_id, rtx=rtx),
                1,
            )
        ]
        report["tasks"].append(
            {
                "node_type": 4,
                "task_id": motion_task_id,
                "status": motion_record.get("status"),
                "outputs": motion_files,
            }
        )

    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(REPORT), "tasks": report["tasks"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
