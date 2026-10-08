# -*- coding: utf-8 -*-
"""Weaver node_type=8 texture pass for P2 assets.

Input: <ID>/weaver/glb/<ID>_mid.fbx (zipped) + the 4 multiview PNGs from the 360 step.
Output: <ID>/weaver/tex/  (zip extracted; expect FBX/GLB with UV + base color texture)

Usage:
  python -u weaver_texture.py --asset B03            # single trial
  python -u weaver_texture.py --all --workers 3
"""
import argparse
import json
import sys
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, str(Path(__file__).parent))
import weaver_p2_v2 as p2  # noqa: E402

ALGO = "Hy3D-TEX-v3.5-preview"


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def tex_dir(asset_id: str) -> Path:
    return p2.OUT_ROOT / asset_id / "weaver" / "tex"


def textured_model(asset_id: str) -> Path | None:
    d = tex_dir(asset_id)
    if not d.exists():
        return None
    for ext in ("*.glb", "*.fbx", "*.obj"):
        hits = sorted(d.rglob(ext))
        if hits:
            return hits[0]
    return None


def run(asset_id: str) -> dict:
    if textured_model(asset_id) is not None:
        return {"asset": asset_id, "skipped": True, "model": str(textured_model(asset_id))}
    base = p2.OUT_ROOT / asset_id / "weaver"
    mid = p2.mid_model_path(asset_id)
    if mid is None:
        return {"asset": asset_id, "error": "no mid model"}
    client = p2.load_client()
    cred = client.get_cos_cred(rtx=p2.RTX)
    prefix = cred.path_prefix.rstrip("/")
    # model zip: same-stem model.fbx inside
    zpath = base / f"{asset_id}_tex_in.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(mid, "model.fbx")
    model_url = client.upload_file(zpath, cred, object_name=f"{prefix}/{asset_id}-texin-{int(time.time())}.zip")
    views = {}
    for key in ("main_view", "back_view", "left_view", "right_view"):
        png = base / f"{asset_id}_mv_{key}.png"
        if png.exists():
            views[key] = client.upload_file(png, cred, object_name=f"{prefix}/{asset_id}-tex-{key}-{int(time.time())}.png")
    if "main_view" not in views:
        concept = p2.PLAN[asset_id]["concept"]
        views["main_view"] = client.upload_file(concept, cred, object_name=f"{prefix}/{asset_id}-tex-concept.png")
    log(f"{asset_id} submit tex views={list(views)}")
    last_err = ""
    for attempt in range(1, 5):
        try:
            ids = client.gen_3d_model(name=f"{asset_id}_tex", node_type=8, rtx=p2.RTX,
                                      input_model=model_url, input_model_format="fbx", input_view=views,
                                      params={"tex_params": {"algorithm_model": ALGO, "resolution": 2048, "unwarp_uv": False},
                                              "output_model_format": "glb"})
            tid = ids[0]
            log(f"{asset_id} tex task {tid}")
            client.wait_model(tid, rtx=p2.RTX, interval=10, timeout=1800)
            out_zip = base / f"{asset_id}_tex.zip"
            if out_zip.exists():
                out_zip.unlink()
            client.download_file(client.download_model(model_id=tid, rtx=p2.RTX), out_zip)
            with zipfile.ZipFile(out_zip) as zf:
                zf.testzip()
                zf.extractall(tex_dir(asset_id))
            m = textured_model(asset_id)
            files = sorted(str(p.relative_to(tex_dir(asset_id))) for p in tex_dir(asset_id).rglob("*") if p.is_file())
            log(f"{asset_id} DONE model={m.name if m else None} files={files[:8]}")
            return {"asset": asset_id, "task": tid, "model": str(m) if m else None, "files": files}
        except Exception as exc:  # noqa: BLE001
            last_err = str(exc)
            log(f"{asset_id} attempt {attempt} failed: {last_err[:200]}")
            if "glb" in last_err.lower() or "990017" in last_err:
                # glb output known to fail on some nodes; fall back to fbx
                pass
            time.sleep((90 if "120041" in last_err else 30) * attempt)
    return {"asset": asset_id, "error": last_err}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--workers", type=int, default=3)
    a = ap.parse_args()
    ids = list(p2.PLAN) if a.all else [s.strip().upper() for s in a.asset.split(",") if s.strip()]
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        res = list(pool.map(run, ids))
    (Path(__file__).parent / "logs" / "tex_last.json").write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"TEX SUMMARY ok={sum(1 for r in res if r.get('model'))}/{len(res)}")


if __name__ == "__main__":
    main()
