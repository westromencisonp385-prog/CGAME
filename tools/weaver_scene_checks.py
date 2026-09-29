"""Submit and inspect representative Weaver scene/geometry samples.

This is deliberately a small, resumable capability study.  It keeps only
task ids, local output hashes and structural metadata in the ledger; COS URLs
and credentials stay in memory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import zipfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
sys.path.insert(0, str(ROOT / "tools"))

from weaver_api_client import WeaverClient  # noqa: E402
from weaver_asset_helpers import (  # noqa: E402
    cos_object_name,
    download_metadata,
    first_model_id,
    output_urls_or_download,
    wait_for_model,
)
from weaver_credentials import require_credentials  # noqa: E402

IN = ROOT / "artifacts" / "weaver" / "capability-study" / "scenes" / "inputs"
OUT = ROOT / "artifacts" / "weaver" / "capability-study" / "scenes"
LEDGER = OUT / "scene-checks.json"

SCENES = {
    "river_mouth_pump_yard": IN / "river_mouth_pump_yard.png",
    "snap_pipe_bridge_kit": IN / "snap_pipe_bridge_kit.png",
    "salt_sea_wind_farm": IN / "salt_sea_wind_farm.png",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load() -> dict[str, Any]:
    if LEDGER.exists():
        return json.loads(LEDGER.read_text(encoding="utf-8"))
    return {"schema_version": 1, "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "tasks": {}}


def save(data: dict[str, Any]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def archive_report(path: Path) -> dict[str, Any]:
    row: dict[str, Any] = {"path": str(path), "bytes": path.stat().st_size, "sha256": sha256(path)}
    try:
        with zipfile.ZipFile(path) as zf:
            names = zf.namelist()
            row["members"] = names[:80]
            row["member_count"] = len(names)
            row["model_members"] = [n for n in names if n.lower().endswith((".fbx", ".glb", ".obj", ".gltf"))]
    except zipfile.BadZipFile:
        row["members"] = []
        row["member_count"] = 0
        row["archive_error"] = "not a zip archive"
    return row


def extract_model(archive: Path, target: Path) -> Path | None:
    with zipfile.ZipFile(archive) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith((".fbx", ".glb", ".obj", ".gltf"))]
        if not names:
            return None
        target.mkdir(parents=True, exist_ok=True)
        name = names[0]
        out = target / Path(name).name
        out.write_bytes(zf.read(name))
        return out


def fbx_structural_report(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    text = raw.decode("latin1", errors="ignore")
    return {
        "path": str(path),
        "bytes": len(raw),
        "binary_header": raw[:18].startswith(b"Kaydara FBX Binary"),
        "geometry_blocks": text.count("Geometry"),
        "polygon_index_blocks": text.count("PolygonVertexIndex"),
        "material_blocks": text.count("Material::"),
        "texture_blocks": text.count("Texture::"),
        "uv_blocks": text.count("UV"),
        "normal_blocks": text.count("LayerElementNormal"),
    }


def run_high_mid(client: WeaverClient, rtx: str, credential: Any, ledger: dict[str, Any], scene: str, image: Path) -> None:
    image_hash = sha256(image)
    remote = client.upload_file(image, credential, object_name=cos_object_name(credential, f"cgame/capability-study/scenes/{scene}.png"))
    for kind, node_type, params in (
        (
            "high_pbr",
            3,
            {
                "image_gen_model_params": {
                    "algorithm_model": "Hy3D-3.5-0515",
                    "face_type": 1,
                    "face_num": 150000,
                    "output_model_format": "fbx",
                    "enable_pbr": True,
                }
            },
        ),
        (
            "mid",
            11,
            {
                "image_gen_model_params": {
                    "algorithm_model": "VV-MeshGen-V1.5.0",
                    "face_type": 1,
                    "face_num": 30000,
                    "output_model_format": "fbx",
                }
            },
        ),
    ):
        key = f"{scene}:{kind}"
        row = ledger["tasks"].get(key, {})
        if row.get("status") == 3 and row.get("outputs"):
            continue
        ids = client.gen_3d_model(
            name=f"CGAME_scene_{scene}_{kind}", node_type=node_type,
            input_view={"main_view": remote}, params=params, rtx=rtx,
        )
        task_id = first_model_id(ids)
        row.update({"scene": scene, "kind": kind, "node_type": node_type, "algorithm_model": params["image_gen_model_params"]["algorithm_model"], "input_sha256": image_hash, "task_id": task_id, "status": "submitted"})
        ledger["tasks"][key] = row
        save(ledger)
        record = wait_for_model(client, task_id, rtx=rtx, timeout=1800, interval=15)
        row["status"] = record.get("status")
        row["preview"] = None
        preview = record.get("preview_img")
        if isinstance(preview, str) and preview:
            preview_path = OUT / scene / f"{kind}_{task_id}_preview.png"
            try:
                download_metadata(client, preview, preview_path)
                row["preview"] = {"path": str(preview_path), "sha256": sha256(preview_path), "bytes": preview_path.stat().st_size}
            except Exception as exc:  # noqa: BLE001
                row["preview_error"] = f"{type(exc).__name__}: {str(exc)[:160]}"
        outputs = []
        for index, url in enumerate(output_urls_or_download(client, record, task_id, rtx=rtx), 1):
            path = OUT / scene / f"{kind}_{task_id}_{index}.zip"
            try:
                outputs.append(archive_report(download_metadata(client, url, path) and path))
            except Exception as exc:  # noqa: BLE001
                row.setdefault("output_errors", []).append(f"{type(exc).__name__}: {str(exc)[:160]}")
        row["outputs"] = outputs
        save(ledger)


def choose_source(ledger: dict[str, Any]) -> tuple[Path, str] | None:
    for scene in SCENES:
        row = ledger["tasks"].get(f"{scene}:high_pbr", {})
        for output in row.get("outputs", []):
            archive = Path(output.get("path", ""))
            if archive.exists():
                target = OUT / scene / "extracted"
                model = extract_model(archive, target)
                if model and model.suffix.lower() == ".fbx":
                    return model, scene
    return None


def run_postprocess(client: WeaverClient, rtx: str, credential: Any, ledger: dict[str, Any]) -> None:
    selected = choose_source(ledger)
    if not selected:
        ledger["postprocess_error"] = "No downloaded high_pbr FBX was available"
        save(ledger)
        return
    source, scene = selected
    source_hash = sha256(source)
    base_remote = client.upload_file(source, credential, object_name=cos_object_name(credential, f"cgame/capability-study/scenes/{scene}/source_{source_hash[:12]}.fbx"))
    jobs: list[tuple[str, int, dict[str, Any]]] = [
        ("mesh_refine", 10, {"mesh_refine_params": {"algorithm_model": "VV-MeshRefine-V1.0.0", "mode": 1}}),
        ("retopology", 1, {"re_topology_params": {"algorithm_model": "Hy3D-RTP-v2.0", "face_type": 2, "face_num": 10000, "output_model_format": "fbx"}}),
        ("uv", 9, {"uv_params": {"algorithm_model": "VV-UV-v2.6.0", "enable_auto_smoothing": True, "lightmap_resolution": 1024, "uv_island_padding": 2, "pack_into_same_uv_space": True}}),
        ("lod", 2, {"lod_params": {"algorithm_model": "VV-LOD-V1.0.0", "output_model_format": "fbx", "reduce_faces": [{"reduce_level": 1, "reduce_percent": 55, "face_type": 2}, {"reduce_level": 2, "reduce_percent": 45, "face_type": 2}, {"reduce_level": 3, "reduce_percent": 35, "face_type": 2}], "gen_times": 1}}),
        ("2uv", 15, {"auto_luv_params": {"algorithm_model": "VV-AutoLUV-V2.6.0", "mesh_name": "Body_Mesh", "light_map_resolution": 1024, "edge_pixel_count": 2.0, "coord_axis": 2, "out_channel": 1, "split_strategy": 2}}),
    ]
    for key, node_type, params in jobs:
        row = ledger["tasks"].get(f"post:{key}", {})
        if row.get("status") == 3 and row.get("outputs"):
            continue
        try:
            ids = client.gen_3d_model(name=f"CGAME_scene_{scene}_{key}", node_type=node_type, input_model=base_remote, params=params, rtx=rtx)
            task_id = first_model_id(ids)
            row.update({"node_type": node_type, "algorithm_model": next(iter(params.values())).get("algorithm_model"), "input_scene": scene, "input_model_sha256": source_hash, "task_id": task_id, "status": "submitted"})
            ledger["tasks"][f"post:{key}"] = row
            save(ledger)
            record = wait_for_model(client, task_id, rtx=rtx, timeout=1800, interval=15)
            row["status"] = record.get("status")
            row["progress"] = record.get("progress")
            outputs = []
            for index, url in enumerate(output_urls_or_download(client, record, task_id, rtx=rtx), 1):
                path = OUT / "postprocess" / f"{key}_{task_id}_{index}.zip"
                outputs.append(archive_report(download_metadata(client, url, path) and path))
            row["outputs"] = outputs
            save(ledger)
        except Exception as exc:  # noqa: BLE001
            row["status"] = "failed"
            row["error"] = f"{type(exc).__name__}: {str(exc)[:240]}"
            row["input_model_sha256"] = source_hash
            ledger["tasks"][f"post:{key}"] = row
            save(ledger)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-postprocess", action="store_true")
    args = parser.parse_args()
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url=base_url)
    ledger = load()
    ledger["algorithms"] = {}
    for node_type in (3, 11, 10, 1, 9, 2, 15):
        try:
            ledger["algorithms"][str(node_type)] = client.list_algorithm_model(node_type=node_type, rtx=rtx)
        except Exception as exc:  # noqa: BLE001
            ledger["algorithms"][str(node_type)] = {"error": f"{type(exc).__name__}: {str(exc)[:160]}"}
    save(ledger)
    credential = client.get_cos_cred(rtx=rtx)
    for scene, image in SCENES.items():
        if image.exists():
            run_high_mid(client, rtx, credential, ledger, scene, image)
    if not args.skip_postprocess:
        run_postprocess(client, rtx, credential, ledger)
    save(ledger)
    print(json.dumps({"ledger": str(LEDGER), "task_count": len(ledger["tasks"]), "scenes": list(SCENES)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
