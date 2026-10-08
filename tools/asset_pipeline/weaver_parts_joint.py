# -*- coding: utf-8 -*-
"""Part-by-part generation, production path (user rule 2026-10-08).

Per asset:
  1. 2D split of the 360 main view with a part-list prompt   (weaver_parts.py: init_segment, segment.json)
  2. ONE mid-model task with segment_model_id only (Weaver mode 3) -> FBX with one named mesh per part,
     all in one shared frame (no plane cutting, no registration)
  3. ONE texture task on that FBX (node_type=8) -> seams share one texture atlas
  4. blender_joint_rig.py: rename parts to ProceduralRig node names, transfer UVs+material, pivots, export
     game/assets/models/rigged/<slot>_rig.glb and update rig_manifest.json

Usage:
  python -u weaver_parts_joint.py --asset M08
  python -u weaver_parts_joint.py --asset M08,M02,C01,E01,E02,E03 --workers 3
"""
import argparse
import json
import subprocess
import sys
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import weaver_p2_v2 as p2  # noqa: E402
import weaver_parts as wp  # noqa: E402

MESH_ALGO = "VV-MeshGen-V1.5.0"
TEX_ALGO = "Hy3D-TEX-v3.5-preview"
BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
RIG_DIR = p2.REPO / "game" / "assets" / "models" / "rigged"
MANIFEST = RIG_DIR / "rig_manifest.json"
QA = p2.REPO / "artifacts" / "qa" / "parts_rig"
RIG_TYPE = {"M08": "flyer", "M02": "turret", "C01": "tracked", "E01": "walker", "E02": "walker", "E03": "orbit",
            "M01": "turret", "M03": "turret", "M04": "turret", "M05": "turret", "M06": "turret", "M07": "turret",
            "B02": "walker", "B03": "walker", "B04": "walker", "B06": "flyer", "W01": "gate", "W03": "world_spin",
            "W04": "world_spin"}
SIZE = {"M08": 1.4, "M02": 1.4, "C01": 3.0, "E01": 3.2, "E02": 3.2, "E03": 3.0,
        "M01": 1.4, "M03": 1.4, "M04": 1.4, "M05": 1.4, "M06": 1.4, "M07": 1.4,
        "B02": 1.5, "B03": 1.5, "B04": 1.6, "B06": 1.3, "W01": 4.6, "W03": 4.0, "W04": 3.2}


def log(m: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def retry(fn, what: str, tries=3):
    last = ""
    for i in range(1, tries + 1):
        try:
            return fn()
        except Exception as exc:  # noqa: BLE001
            last = str(exc)
            log(f"{what} attempt {i} failed: {last[:180]}")
            time.sleep((90 if "120041" in last else 30) * i)
    raise RuntimeError(f"{what}: {last}")


def ensure_split(asset_id: str) -> dict:
    out = p2.OUT_ROOT / asset_id / "parts"
    if not (out / "segment.json").exists():
        wp.run(asset_id, split_only=True, workers=1)
    return json.loads((out / "segment.json").read_text(encoding="utf-8"))


def name_map(asset_id: str, seg: dict) -> dict:
    mapping = wp.match_parts(seg["components"], wp.PARTS[asset_id]["parts"])
    by_label = {c["label"]: c["name"] for c in seg["components"]}
    m = {}
    for part, lab in mapping.items():
        if part == "_extra_body":
            for x in lab:
                m[by_label[x]] = "Body"
        else:
            m[by_label[lab]] = part
    return m


def run(asset_id: str) -> dict:
    out = p2.OUT_ROOT / asset_id / "parts"
    out.mkdir(parents=True, exist_ok=True)
    main_png = p2.OUT_ROOT / asset_id / "weaver" / f"{asset_id}_mv_main_view.png"
    if main_png.exists() and not wp.view_is_single_subject(main_png)[0]:
        import shutil
        for sub in ("joint", "joint_tex"):
            shutil.rmtree(out / sub, ignore_errors=True)
        for f in ("segment.json", "segment_reply.json", "layout.json", "joint.zip", "joint_tex.zip"):
            (out / f).unlink(missing_ok=True)
    seg = ensure_split(asset_id)
    client = p2.load_client()
    jdir = out / "joint"
    fbx = next(iter(sorted(jdir.rglob("*.fbx"))), None)
    if fbx is None:
        def mid():
            tid = client.gen_3d_model(name=f"{asset_id}_joint", node_type=11, rtx=p2.RTX,
                                      params={"image_gen_model_params": {"algorithm_model": MESH_ALGO, "face_type": 1,
                                                                         "output_model_format": "fbx",
                                                                         "segment_model_id": seg["model_id"]}})[0]
            log(f"{asset_id} joint mid {tid}")
            client.wait_model(tid, rtx=p2.RTX, interval=10, timeout=2400)
            z = out / "joint.zip"
            client.download_file(client.download_model(model_id=tid, rtx=p2.RTX), z)
            with zipfile.ZipFile(z) as zf:
                zf.extractall(jdir)
        retry(mid, f"{asset_id} joint mid")
        fbx = sorted(jdir.rglob("*.fbx"))[0]
    tdir = out / "joint_tex"
    tglb = next(iter(sorted(tdir.rglob("*.glb"))), None)
    if tglb is None:
        def tex():
            cred = client.get_cos_cred(rtx=p2.RTX)
            prefix = cred.path_prefix.rstrip("/")
            zin = out / "joint_texin.zip"
            with zipfile.ZipFile(zin, "w", zipfile.ZIP_DEFLATED) as zf:
                zf.write(fbx, "model.fbx")
            murl = client.upload_file(zin, cred, object_name=f"{prefix}/{asset_id}-joint-texin-{int(time.time())}.zip")
            views = {}
            for key in ("main_view", "back_view", "left_view", "right_view"):
                png = p2.OUT_ROOT / asset_id / "weaver" / f"{asset_id}_mv_{key}.png"
                if png.exists():
                    views[key] = client.upload_file(png, cred, object_name=f"{prefix}/{asset_id}-jt-{key}-{int(time.time())}.png")
            tid = client.gen_3d_model(name=f"{asset_id}_joint_tex", node_type=8, rtx=p2.RTX, input_model=murl,
                                      input_model_format="fbx", input_view=views,
                                      params={"tex_params": {"algorithm_model": TEX_ALGO, "resolution": 2048, "unwarp_uv": False},
                                              "output_model_format": "glb"})[0]
            log(f"{asset_id} joint tex {tid}")
            client.wait_model(tid, rtx=p2.RTX, interval=10, timeout=2400)
            z = out / "joint_tex.zip"
            client.download_file(client.download_model(model_id=tid, rtx=p2.RTX), z)
            with zipfile.ZipFile(z) as zf:
                zf.extractall(tdir)
        retry(tex, f"{asset_id} joint tex")
        tglb = sorted(tdir.rglob("*.glb"))[0]
    nm = name_map(asset_id, seg)
    (out / "name_map.json").write_text(json.dumps(nm, ensure_ascii=False, indent=2), encoding="utf-8")
    slot = p2.PLAN[asset_id]["slot"]
    QA.mkdir(parents=True, exist_ok=True)
    out_glb = RIG_DIR / f"{slot}_rig.glb"
    png = QA / f"{asset_id}_{slot}.png"
    r = subprocess.run([BLENDER, "--background", "--python", str(HERE / "blender_joint_rig.py"), "--", str(fbx), str(tglb),
                        str(out / "name_map.json"), str(out_glb), str(png), str(SIZE.get(asset_id, 1.6))],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    line = next((ln for ln in r.stdout.splitlines() if ln.startswith("JOINT_RIG")), "")
    if not line:
        return {"asset": asset_id, "error": (r.stdout + r.stderr)[-600:]}
    info = json.loads(line[len("JOINT_RIG"):])
    log(f"{asset_id} RIG {info}")
    return {"asset": asset_id, "slot": slot, "rig": RIG_TYPE.get(asset_id, "static"),
            "file": f"res://assets/models/rigged/{slot}_rig.glb", "parts": [p for p in info["parts"] if p != "Body"],
            "dims": info["dims"], "textured": info["textured"], "source": "weaver_segment_joint"}


def update_manifest(results: list) -> None:
    man = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for r in results:
        if "file" in r:
            old = man.get(r["slot"], {})
            man[r["slot"]] = {**old, "rig": r["rig"], "file": r["file"], "parts": r["parts"],
                              "roles": [], "dims": r["dims"], "source": r["source"]}
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True)
    ap.add_argument("--workers", type=int, default=3)
    a = ap.parse_args()
    ids = [s.strip().upper() for s in a.asset.split(",") if s.strip()]
    def safe(i):
        try:
            return run(i)
        except Exception as exc:  # noqa: BLE001
            log(f"{i} FAILED: {str(exc)[:200]}")
            return {"asset": i, "error": str(exc)[:400]}

    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        res = list(pool.map(safe, ids))
    update_manifest(res)
    (HERE / "logs" / "parts_joint_last.json").write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"JOINT SUMMARY ok={sum(1 for r in res if 'file' in r)}/{len(res)}")


if __name__ == "__main__":
    main()
