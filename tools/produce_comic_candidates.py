"""Generate Weaver 3D candidates for the confirmed comic enemy batch."""
from __future__ import annotations
import json, sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
from weaver_api_client import WeaverClient
from weaver_credentials import require_credentials
from weaver_asset_helpers import cos_object_name, download_metadata, first_model_id, output_urls_or_download, wait_for_model

INPUT = ROOT / "docs/assets/comic-whale-v1"
OUT = ROOT / "artifacts/weaver/comic_candidates"
REPORT = OUT / "report.json"

ASSETS = [
    ("N01", "N01-hydraulic-barricade-crab.png", 12000),
    ("N02", "N02-scrapwheel-hound.png", 12000),
    ("N03", "N03-drum-pack-artillery-beetle.png", 12000),
    ("N04", "N04-mag-rail-repair-bee.png", 9000),
    ("E01", "E01-high-pressure-thunder-boiler-hippo.png", 18000),
    ("E02", "E02-polarity-ring-hunter.png", 18000),
    ("BOSS01", "BOSS01-breakwall-titan.png", 50000),
]

def poll_views(client, row):
    try:
        record = wait_for_model(client, row["view_task_id"], rtx=row["rtx"])
        views = (record.get("image_gen_360_output") or {}).get("output_view") or {}
        row["views"] = {key: views.get(key, "") for key in ("main_view", "back_view", "left_view", "right_view")}
        row["view_status"] = 3 if row["views"].get("main_view") else "error"
    except Exception as exc:
        row["view_status"] = "error"; row["view_error"] = str(exc)[:300]
    return row

def poll_model(client, row):
    try:
        record = wait_for_model(client, row["model_task_id"], rtx=row["rtx"])
        files = []
        for index, url in enumerate(output_urls_or_download(client, record, row["model_task_id"], rtx=row["rtx"]), 1):
            files.append(download_metadata(client, url, OUT / row["asset_id"] / f"high_{index}.zip"))
        row["model_status"] = 3; row["outputs"] = files
    except Exception as exc:
        row["model_status"] = "error"; row["model_error"] = str(exc)[:300]
    return row

def main():
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url)
    credential = client.get_cos_cred(rtx=rtx)
    report = {"schema_version": 1, "style": "graphic_comic_C", "status": "candidate", "assets": []}
    rows = []
    for asset_id, filename, face_num in ASSETS:
        local = INPUT / filename
        source_url = client.upload_file(local, credential, object_name=cos_object_name(credential, f"cgame/comic-whale-v1/{filename}"))
        view_task = client.gen_multi_views(name=f"CGAME_{asset_id}_comic_360", input_view={"main_view": source_url}, params={"image_gen_360_params": {"algorithm_model": "VV-MultiView-V1.0.0", "enable_a_pose": False}}, rtx=rtx)
        rows.append({"asset_id": asset_id, "input": str(local), "input_sha256": __import__("hashlib").sha256(local.read_bytes()).hexdigest(), "rtx": rtx, "view_task_id": view_task})
    with ThreadPoolExecutor(max_workers=7) as pool:
        for future in as_completed([pool.submit(poll_views, client, row) for row in rows]):
            future.result()
    for row in rows:
        if row.get("view_status") != 3: continue
        model_task = client.gen_3d_model(name=f"CGAME_{row['asset_id']}_comic_high", node_type=3, input_view=row["views"], params={"image_gen_model_params": {"algorithm_model": "Hy3D-3.5-0515", "output_model_format": "glb", "face_type": 1, "face_num": next(n for aid, _, n in ASSETS if aid == row["asset_id"]), "strict_mode": True, "skip_360_preprocess": True}}, rtx=rtx)
        row["model_task_id"] = first_model_id(model_task)
    with ThreadPoolExecutor(max_workers=7) as pool:
        for future in as_completed([pool.submit(poll_model, client, row) for row in rows if row.get("model_task_id")]):
            future.result()
    for row in rows:
        row.pop("rtx", None); row.pop("views", None)
    report["assets"] = rows; OUT.mkdir(parents=True, exist_ok=True); REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(REPORT), "assets": [{"id": r["asset_id"], "view": r.get("view_status"), "model": r.get("model_status"), "outputs": len(r.get("outputs", []))} for r in rows]}, ensure_ascii=False))

if __name__ == "__main__": main()
