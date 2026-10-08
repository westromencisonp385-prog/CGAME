# -*- coding: utf-8 -*-
"""Retry mid-model for a finished 360 task, using explicit input_view (docs method 1).

Usage: python weaver_mid_retry.py --mv-id Model... --asset A01
"""
import argparse
import hashlib
import json
import re
import sys
import time
import zipfile
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
from weaver_api_client import WeaverClient, WeaverError

RTX = "jasonlyan"
REPO = Path(__file__).resolve().parents[2]
OUT_ROOT = REPO / "artifacts" / "ai_candidates"


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mv-id", required=True)
    ap.add_argument("--asset", required=True)
    ap.add_argument("--mesh-algo", default="VV-MeshGen-V1.5.0")
    ap.add_argument("--output-format", default="fbx", choices=["fbx", "obj", "glb"])
    args = ap.parse_args()
    asset_id = args.asset.upper()

    txt = (Path(r"D:\工作\生图API\weaver") / "鉴权.txt").read_text(encoding="utf-8")
    client = WeaverClient(re.search(r"vsa_[0-9a-f]+", txt).group(), re.search(r"vss_[0-9a-f]+", txt).group())

    rows, _ = client.get_model_list(model_id_list=[args.mv_id], limit=20, rtx=RTX)
    if not rows:
        raise SystemExit(f"360 task {args.mv_id} not found")
    out_view = (rows[0].get("image_gen_360_output") or {}).get("output_view") or {}
    views = {k: v for k, v in out_view.items() if isinstance(v, str) and v.startswith("http")}
    if "main_view" not in views:
        raise SystemExit(f"no usable views in 360 output: {list(out_view)}")
    log(f"views: {sorted(views)}")

    log(f"creating mid task (input_view mode, algo={args.mesh_algo}, {args.output_format})")
    mid_ids = client.gen_3d_model(
        name=f"{asset_id}_mid", node_type=11, rtx=RTX, input_view=views,
        params={"image_gen_model_params": {
            "algorithm_model": args.mesh_algo, "face_type": 1, "face_num": 0,
            "output_model_format": args.output_format}})
    mid_id = mid_ids[0]
    log(f"mid task={mid_id}, waiting (<=1800s)")
    model = client.wait_model(mid_id, rtx=RTX, interval=10, timeout=1800)

    log("downloading")
    dl_url = client.download_model(model_id=mid_id, rtx=RTX)
    out_dir = OUT_ROOT / asset_id / "weaver"
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = client.download_file(dl_url, out_dir / f"{asset_id}_mid.zip")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(out_dir / "glb")
    exts = (args.output_format.lower(),)
    glbs = []
    for ext in exts:
        glbs += sorted((out_dir / "glb").rglob(f"*.{ext}"))
    if not glbs:
        glbs = sorted((out_dir / "glb").rglob("*.glb")) + sorted((out_dir / "glb").rglob("*.gltf")) + sorted((out_dir / "glb").rglob("*.fbx"))
    if not glbs:
        listed = [str(p.relative_to(out_dir)) for p in (out_dir / "glb").rglob("*")][:12]
        raise WeaverError(f"no model in zip, files={listed}")
    glb = glbs[0]
    log(f"glb={glb.name} size={glb.stat().st_size}")

    manifest_path = OUT_ROOT / asset_id / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
        "asset_id": asset_id, "tasks": [], "concept_refs": [], "style_lock_version": "reclaimer-v1"}
    manifest["tasks"] = [t for t in manifest["tasks"] if not str(t.get("endpoint", "")).startswith("gen_3d_model:11")] + [
        {"tool": "weaver", "endpoint": "gen_3d_model:11", "task_id": mid_id,
         "params": {"algorithm_model": args.mesh_algo, "face_type": 1, "face_num": 0,
                    "output_model_format": "glb", "input_view_from_360": args.mv_id},
         "output": str(glb), "output_sha256": hashlib.sha256(glb.read_bytes()).hexdigest(),
         "created": time.strftime("%Y-%m-%d"), "status": "api_candidate"}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"manifest updated -> {manifest_path}")
    print(json.dumps({"asset": asset_id, "mv_id": args.mv_id, "mid_id": mid_id, "glb": str(glb)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
