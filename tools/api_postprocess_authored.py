"""Run UV, LOD, and optional rigging post-process candidates through Weaver."""

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
    output_urls,
    output_urls_or_download,
    wait_for_model,
)

OUT = ROOT / "artifacts/weaver/api_postprocess"
REPORT = OUT / "report.json"


def sha(path: str | Path) -> str:
    import hashlib

    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def zip_model(source: str | Path, zip_path: str | Path, extra: dict[str, Any] | None = None) -> Path:
    """Pack a model and the required model.json contract into a Weaver input zip."""

    source_path = Path(source)
    archive = Path(zip_path)
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as handle:
        handle.write(source_path, source_path.name)
        if extra is not None:
            # Weaver's rigging/skinning contract uses the literal model.json
            # filename alongside the model archive member.
            handle.writestr(
                "model.json",
                json.dumps(extra, ensure_ascii=False, indent=2),
            )
    return archive


def lod_urls(record: dict[str, Any]) -> list[str]:
    lod = record.get("lod_output") or {}
    if isinstance(lod, dict):
        urls = [
            str(item.get("download_url"))
            for item in lod.get("lod_files") or []
            if isinstance(item, dict) and item.get("download_url")
        ]
        if urls:
            return urls
    return output_urls(record)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    credential = client.get_cos_cred(rtx=rtx)

    api_zip = next((ROOT / "artifacts/weaver/api_candidates/player_a01").glob("Model*.zip"), None)
    assets: list[tuple[str, Path]] = []
    if api_zip:
        assets.append(("player.a01_api_candidate", api_zip))
    for asset_id, file_path in (
        (
            "enemy.b01_authored",
            ROOT / "artifacts/weaver/authored/enemy_b01_reverse_crab_authored.glb",
        ),
        (
            "facility.c04_authored",
            ROOT / "artifacts/weaver/authored/facility_c04_repair_pump_authored.glb",
        ),
    ):
        archive = zip_model(file_path, OUT / f"{asset_id}_input.zip")
        assets.append((asset_id, archive))

    report: dict[str, Any] = {
        "schema_version": 1,
        "purpose": "Weaver postprocess candidates; authored GLB remains style authority until comparison passes",
        "assets": [],
    }
    for asset_id, local_path in assets:
        row: dict[str, Any] = {
            "asset_id": asset_id,
            "input": str(local_path),
            "input_sha256": sha(local_path),
        }
        try:
            source_url = client.upload_file(
                local_path,
                credential,
                object_name=cos_object_name(credential, f"cgame/postprocess/{asset_id}.zip"),
            )
            uv_task_id = first_model_id(
                client.gen_3d_model(
                    name=f"CGAME_{asset_id}_uv",
                    node_type=9,
                    input_model=source_url,
                    params={
                        "uv_params": {
                            "algorithm_model": "Hy3D-UV-v3.0",
                            "enable_auto_smoothing": True,
                        }
                    },
                    rtx=rtx,
                )
            )
            row["uv_task_id"] = uv_task_id
            uv_record = wait_for_model(client, uv_task_id, rtx=rtx)
            uv_urls = output_urls_or_download(client, uv_record, uv_task_id, rtx=rtx)
            row["uv_outputs"] = [
                download_metadata(client, url, OUT / asset_id / f"uv_{index}.zip")
                for index, url in enumerate(uv_urls, 1)
            ]

            if uv_urls:
                lod_task_id = first_model_id(
                    client.gen_3d_model(
                        name=f"CGAME_{asset_id}_lod",
                        node_type=2,
                        input_model=uv_urls[0],
                        params={
                            "lod_params": {
                                "algorithm_model": "VV-LOD-V1.0.0",
                                "output_model_format": "fbx",
                                "gen_times": 1,
                                "reduce_faces": [
                                    {"reduce_level": 1, "reduce_percent": 50, "face_type": 1},
                                    {"reduce_level": 2, "reduce_percent": 25, "face_type": 1},
                                    {"reduce_level": 3, "reduce_percent": 13, "face_type": 1},
                                ],
                            }
                        },
                        rtx=rtx,
                    )
                )
                row["lod_task_id"] = lod_task_id
                lod_record = wait_for_model(client, lod_task_id, rtx=rtx)
                row["lod_outputs"] = [
                    download_metadata(client, url, OUT / asset_id / f"lod_{index}.fbx")
                    for index, url in enumerate(
                        lod_urls(lod_record) or output_urls_or_download(client, lod_record, lod_task_id, rtx=rtx),
                        1,
                    )
                ]

            if asset_id == "enemy.b01_authored" and uv_urls:
                rig_archive = zip_model(
                    ROOT / "artifacts/weaver/authored/enemy_b01_reverse_crab_authored.glb",
                    OUT / f"{asset_id}_rig_input.zip",
                    {
                        "config": {
                            "mesh_category": "tetrapod",
                            "algo_name": "MotusAI-Rigging-V2.0",
                        }
                    },
                )
                rig_source_url = client.upload_file(
                    rig_archive,
                    credential,
                    object_name=cos_object_name(credential, f"cgame/postprocess/{asset_id}_rig.zip"),
                )
                rig_task_id = first_model_id(
                    client.gen_3d_model(
                        name=f"CGAME_{asset_id}_rig",
                        node_type=5,
                        input_model=rig_source_url,
                        params={
                            "go_rigging_params": {
                                "algorithm_model": "MotusAI-Rigging-V2.0",
                                "enable_auto_skinning": False,
                            }
                        },
                        rtx=rtx,
                    )
                )
                row["rig_task_id"] = rig_task_id
                rig_record = wait_for_model(client, rig_task_id, rtx=rtx)
                row["rig_outputs"] = [
                    download_metadata(client, url, OUT / asset_id / f"rig_{index}.zip")
                    for index, url in enumerate(output_urls_or_download(client, rig_record, rig_task_id, rtx=rtx), 1)
                ]
        except Exception as exc:  # noqa: BLE001 - retain per-asset status in the ledger
            row["error"] = f"{type(exc).__name__}: {str(exc)[:300]}"
        report["assets"].append(row)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps({"report": str(REPORT), "assets": report["assets"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
