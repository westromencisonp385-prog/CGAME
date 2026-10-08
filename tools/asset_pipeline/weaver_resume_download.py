# -*- coding: utf-8 -*-
"""Resume: find the latest finished mid-model task on the server for each asset
(by task name "<ID>_mid") and download it, without resubmitting.

Usage: python -u weaver_resume_download.py E02,M01
"""
import hashlib
import json
import sys
import time
import zipfile
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, str(Path(__file__).parent))
import weaver_p2_v2 as p2  # noqa: E402


def main() -> None:
    ids = [a.strip().upper() for a in sys.argv[1].split(",") if a.strip()]
    client = p2.load_client()
    for asset_id in ids:
        rows, total = client.get_model_list(node_type_list=[11], keyword=f"{asset_id}_mid", limit=20, rtx=p2.RTX)
        cands = [r for r in rows if str(r.get("name", "")) == f"{asset_id}_mid"]
        cands.sort(key=lambda r: str(r.get("model_id", "")), reverse=True)
        if not cands:
            print(f"{asset_id}: no server task found")
            continue
        task = cands[0]
        mid_id, status = task.get("model_id"), task.get("status")
        print(f"{asset_id}: latest {mid_id} status={status}")
        if status != 3:
            if status in (1, 2):
                print(f"{asset_id}: still running, waiting")
                client.wait_model(mid_id, rtx=p2.RTX, interval=10, timeout=1800)
            else:
                print(f"{asset_id}: not finished (status {status}), skip")
                continue
        out_dir = p2.OUT_ROOT / asset_id / "weaver"
        zip_path = out_dir / f"{asset_id}_mid.zip"
        if zip_path.exists():
            zip_path.unlink()
        dl = client.download_model(model_id=mid_id, rtx=p2.RTX)
        client.download_file(dl, zip_path)
        with zipfile.ZipFile(zip_path) as zf:
            zf.testzip()
            zf.extractall(out_dir / "glb")
        model = p2.mid_model_path(asset_id)
        head = model.read_bytes()[:20] if model else b""
        binary = head.startswith(b"Kaydara FBX Binary")
        print(f"{asset_id}: model={model.name if model else None} binary_fbx={binary}")
        manifest_path = p2.OUT_ROOT / asset_id / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
            "asset_id": asset_id, "tasks": []}
        manifest["game_slot"] = p2.PLAN[asset_id]["slot"]
        manifest["tasks"] = [t for t in manifest.get("tasks", []) if t.get("endpoint") != "gen_3d_model:11"] + [
            {"tool": "weaver", "endpoint": "gen_3d_model:11", "task_id": mid_id, "output": str(model),
             "output_sha256": hashlib.sha256(model.read_bytes()).hexdigest() if model else "",
             "created": time.strftime("%Y-%m-%d"), "status": "api_candidate", "resumed": True}]
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
