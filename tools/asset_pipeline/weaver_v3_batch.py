# -*- coding: utf-8 -*-
"""Style v3 3D batch: restyled concept -> fresh 360 -> 2D split -> joint parts mid -> 1 texture -> rig GLB.

Isolated from P2 artifacts: everything lives under artifacts/ai_candidates_v3/<ID>/ so v2 rigs stay as fallback
until a v3 rig passes. Final rigs overwrite game/assets/models/rigged/<slot>_rig.glb (+ manifest).

Usage:
  python -u weaver_v3_batch.py --asset M08            # one
  python -u weaver_v3_batch.py --all --workers 3      # everything that has a v3 concept
"""
import argparse
import json
import shutil
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
import weaver_parts_joint as wj  # noqa: E402
from v3_parts_plan import V3_PARTS  # noqa: E402

for _aid, (_prompt, _parts) in V3_PARTS.items():
    wp.PARTS[_aid] = {"prompt": _prompt, "parts": _parts}

REPO = p2.REPO
V3_IN = REPO / "artifacts" / "weaver" / "inputs_v3"
ROOT = REPO / "artifacts" / "ai_candidates_v3"
QA = REPO / "artifacts" / "qa" / "v3_rig"
MESH_ALGO = "VV-MeshGen-V1.5.0"
TEX_ALGO = "Hy3D-TEX-v3.5-preview"
TEX_RES = 1024

# A01/B01/C04 —— 正式 G1 资产也走部件
EXTRA_SLOTS = {"A01": "player_stage01_whale", "B01": "enemy_crab_b01", "C04": "repair_pump_c04",
               "N05": "enemy_minion_flea", "N06": "enemy_minion_oildrum", "N07": "enemy_minion_bat",
               "N08": "enemy_minion_hedgehog", "N09": "enemy_minion_mantis",
               "EL1": "enemy_elite_rhino", "EL2": "enemy_elite_eel", "BS4": "boss_04_dredge_toad"}
EXTRA_RIG = {"A01": "tracked", "B01": "walker", "C04": "world_spin",
             "N05": "walker", "N06": "walker", "N07": "flyer", "N08": "walker", "N09": "walker",
             "EL1": "walker", "EL2": "walker", "BS4": "walker"}
EXTRA_SIZE = {"A01": 2.4, "B01": 1.5, "C04": 2.6,
              "N05": 1.0, "N06": 1.2, "N07": 1.1, "N08": 1.1, "N09": 1.4,
              "EL1": 2.1, "EL2": 2.2, "BS4": 3.4}


def slot_of(aid: str) -> str:
    return EXTRA_SLOTS.get(aid) or p2.PLAN[aid]["slot"]


def rig_of(aid: str) -> str:
    return EXTRA_RIG.get(aid) or wj.RIG_TYPE.get(aid, "static")


def size_of(aid: str) -> float:
    return EXTRA_SIZE.get(aid) or wj.SIZE.get(aid, 1.6)


def log(m: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def stage_360(client, aid: str, d: Path) -> dict:
    """fresh 360 from the v3 concept; QC; return {view: local png}"""
    views = {k: d / f"mv_{k}.png" for k in ("main_view", "back_view", "left_view", "right_view")}
    if all(v.exists() for v in views.values()) and wp.view_is_single_subject(views["main_view"])[0]:
        return views
    concept = V3_IN / f"{aid}-v3.png"
    for attempt in range(1, 3):
        def once():
            cred = client.get_cos_cred(rtx=p2.RTX)
            url = client.upload_file(concept, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{aid}-v3-{int(time.time())}.png")
            algos = client.list_algorithm_model(node_type=7, rtx=p2.RTX)
            algo = "Hy3D-MultiView-v3.0" if "Hy3D-MultiView-v3.0" in algos else algos[0]
            mv = client.gen_multi_views(name=f"{aid}_v3_360", input_view={"main_view": url},
                                        params={"image_gen_360_params": {"algorithm_model": algo, "enable_a_pose": False}}, rtx=p2.RTX)
            log(f"{aid} 360 {mv}")
            info = client.wait_model(mv, rtx=p2.RTX, interval=6, timeout=900)
            out = (info.get("image_gen_360_output") or {}).get("output_view") or {}
            for k, u in out.items():
                if u and k in views:
                    client.download_file(u, views[k])
        wj.retry(once, f"{aid} 360")
        ok, blobs = wp.view_is_single_subject(views["main_view"])
        if ok:
            return views
        log(f"{aid} 360 QC failed ({blobs}), retry {attempt}")
    raise RuntimeError(f"{aid}: 360 QC failed twice")


def stage_split(client, aid: str, d: Path, views: dict) -> dict:
    seg_path = d / "segment.json"
    if seg_path.exists():
        seg = json.loads(seg_path.read_text(encoding="utf-8"))
        if seg.get("components"):
            return seg
    cred = client.get_cos_cred(rtx=p2.RTX)
    url = client.upload_file(views["main_view"], cred, object_name=f"{cred.path_prefix.rstrip('/')}/{aid}-v3-split-{int(time.time())}.png")
    prompt = wp.PARTS[aid]["prompt"]
    last = None
    for attempt, (pr, gran) in enumerate([(prompt, 2), ("", 1)], start=1):
        r = wp.init_segment(client, name=f"{aid}_v3_split", main_view_url=url, prompt=pr, granularity=gran)
        (d / "segment_reply.json").write_text(json.dumps(r, ensure_ascii=False, indent=2), encoding="utf-8")
        comps = wp.components_of(client, r["model_id"], r["reply"]) if r.get("reply") else []
        if comps:
            seg = {"model_id": r["model_id"], "components": comps, "prompt": pr}
            seg_path.write_text(json.dumps(seg, ensure_ascii=False, indent=2), encoding="utf-8")
            return seg
        last = r
        log(f"{aid} split empty (attempt {attempt}); fallback to automatic coarse split")
    raise RuntimeError(f"{aid}: split failed {str(last)[:200]}")


def stage_joint(client, aid: str, d: Path, seg: dict, views: dict) -> tuple[Path, Path]:
    jdir, tdir = d / "joint", d / "joint_tex"
    fbx = next(iter(sorted(jdir.rglob("*.fbx"))), None)
    if fbx is None:
        def mid():
            tid = client.gen_3d_model(name=f"{aid}_v3_joint", node_type=11, rtx=p2.RTX,
                                      params={"image_gen_model_params": {"algorithm_model": MESH_ALGO, "face_type": 1,
                                                                         "output_model_format": "fbx", "segment_model_id": seg["model_id"]}})[0]
            log(f"{aid} joint mid {tid}")
            client.wait_model(tid, rtx=p2.RTX, interval=10, timeout=2400)
            z = d / "joint.zip"
            client.download_file(client.download_model(model_id=tid, rtx=p2.RTX), z)
            with zipfile.ZipFile(z) as zf:
                zf.extractall(jdir)
        wj.retry(mid, f"{aid} joint mid")
        fbx = sorted(jdir.rglob("*.fbx"))[0]
    tglb = next(iter(sorted(tdir.rglob("*.glb"))), None)
    if tglb is None:
        def tex():
            cred = client.get_cos_cred(rtx=p2.RTX)
            pre = cred.path_prefix.rstrip("/")
            zin = d / "joint_texin.zip"
            with zipfile.ZipFile(zin, "w", zipfile.ZIP_DEFLATED) as zf:
                zf.write(fbx, "model.fbx")
            murl = client.upload_file(zin, cred, object_name=f"{pre}/{aid}-v3-texin-{int(time.time())}.zip")
            iv = {k: client.upload_file(p, cred, object_name=f"{pre}/{aid}-v3-tv-{k}-{int(time.time())}.png") for k, p in views.items() if p.exists()}
            tid = client.gen_3d_model(name=f"{aid}_v3_tex", node_type=8, rtx=p2.RTX, input_model=murl, input_model_format="fbx",
                                      input_view=iv, params={"tex_params": {"algorithm_model": TEX_ALGO, "resolution": TEX_RES, "unwarp_uv": False},
                                                             "output_model_format": "glb"})[0]
            log(f"{aid} joint tex {tid}")
            client.wait_model(tid, rtx=p2.RTX, interval=10, timeout=2400)
            z = d / "joint_tex.zip"
            client.download_file(client.download_model(model_id=tid, rtx=p2.RTX), z)
            with zipfile.ZipFile(z) as zf:
                zf.extractall(tdir)
        wj.retry(tex, f"{aid} joint tex")
        tglb = sorted(tdir.rglob("*.glb"))[0]
    return fbx, tglb


SYNONYMS = {"腿": ["腿", "足", "脚", "肢"], "触手": ["触手", "软管", "腿", "足"], "喷": ["喷", "炮", "嘴管"],
            "外壳": ["外壳", "齿轮", "壳", "背"], "鳍": ["鳍", "线圈", "变压器"], "吊机": ["吊机", "吊臂", "起重"],
            "滚筒": ["滚筒", "压路", "滚"], "臂": ["臂", "焊枪", "前肢"],
            "翅": ["翅", "翼"], "环": ["环", "圈"], "挡板": ["挡板", "盾", "板"],
            "盾": ["盾", "板"], "下颚": ["下颚", "颚", "嘴"], "嘴": ["嘴", "颚"], "履带": ["履带", "底盘", "轮"],
            "叶": ["叶", "转子", "风车"], "风扇": ["风扇", "转子", "扇"], "门扇": ["门扇", "门"]}


def _hits(hint: str, name: str) -> bool:
    return any(h in name for h in SYNONYMS.get(hint, [hint]))


def name_map(aid: str, seg: dict, d: Path | None = None) -> dict:
    comps = seg["components"]
    plan = wp.PARTS[aid]["parts"]
    m, used = {}, set()
    for part, hint in plan:
        if part == "Body":
            continue
        for c in comps:
            nm = str(c.get("name", ""))
            if c["label"] not in used and hint and _hits(hint, nm):
                m[nm] = part
                used.add(c["label"])
                break
    body_hint = next((h for p, h in plan if p == "Body"), "")
    for c in comps:
        nm = str(c.get("name", ""))
        if c["label"] not in used and body_hint and _hits(body_hint, nm):
            m[nm] = "Body"
            used.add(c["label"])
            break
    if "Body" not in m.values():
        # biggest unmatched component by mask area (layout px) or first one
        rest = [c for c in comps if c["label"] not in used]
        if rest:
            m[str(rest[0].get("name", rest[0]["label"]))] = "Body"
            used.add(rest[0]["label"])
    k = 0
    for c in comps:
        if c["label"] not in used:
            m[str(c.get("name", c["label"]))] = f"Part_{k}"
            k += 1
    return m


def run(aid: str) -> dict:
    d = ROOT / aid
    d.mkdir(parents=True, exist_ok=True)
    if not (V3_IN / f"{aid}-v3.png").exists():
        return {"asset": aid, "error": "no v3 concept"}
    client = p2.load_client()
    views = stage_360(client, aid, d)
    seg = stage_split(client, aid, d, views)
    log(f"{aid} parts {[(c['label'], c['name']) for c in seg['components']]}")
    fbx, tglb = stage_joint(client, aid, d, seg, views)
    nm = name_map(aid, seg)
    (d / "name_map.json").write_text(json.dumps(nm, ensure_ascii=False, indent=2), encoding="utf-8")
    slot = slot_of(aid)
    QA.mkdir(parents=True, exist_ok=True)
    stage_glb = d / f"{slot}_rig.glb"
    png = QA / f"{aid}_{slot}.png"
    r = subprocess.run([wj.BLENDER, "--background", "--python", str(HERE / "blender_joint_rig.py"), "--", str(fbx), str(tglb),
                        str(d / "name_map.json"), str(stage_glb), str(png), str(size_of(aid))],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    line = next((ln for ln in r.stdout.splitlines() if ln.startswith("JOINT_RIG")), "")
    if not line:
        return {"asset": aid, "error": (r.stdout + r.stderr)[-500:]}
    info = json.loads(line[len("JOINT_RIG"):])
    log(f"{aid} RIG {info}")
    return {"asset": aid, "slot": slot, "rig": rig_of(aid), "stage_glb": str(stage_glb), "png": str(png),
            "parts": [p for p in info["parts"] if p != "Body"], "dims": info["dims"], "textured": info["textured"]}


def install(results: list) -> None:
    """copy staged rigs into the game and update the manifest (only successful ones)."""
    man = json.loads(wj.MANIFEST.read_text(encoding="utf-8")) if wj.MANIFEST.exists() else {}
    for r in results:
        if "stage_glb" not in r:
            continue
        slot = r["slot"]
        for old in wj.RIG_DIR.glob(f"{slot}_rig*"):
            if old.suffix in (".glb", ".png", ".jpg") or old.name.endswith(".import"):
                old.unlink(missing_ok=True)
        shutil.copy2(r["stage_glb"], wj.RIG_DIR / f"{slot}_rig.glb")
        man[slot] = {**man.get(slot, {}), "rig": r["rig"], "file": f"res://assets/models/rigged/{slot}_rig.glb",
                     "parts": r["parts"], "roles": [], "dims": r["dims"], "source": "weaver_segment_joint_v3",
                     "style": "reclaimer_v3"}
    wj.MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--no-install", action="store_true")
    a = ap.parse_args()
    ids = [s.strip().upper() for s in a.asset.split(",") if s.strip()]
    if a.all:
        ids = sorted(p.stem.replace("-v3", "") for p in V3_IN.glob("*-v3.png"))

    def safe(i):
        try:
            return run(i)
        except Exception as exc:  # noqa: BLE001
            log(f"{i} FAILED: {str(exc)[:220]}")
            return {"asset": i, "error": str(exc)[:400]}

    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        res = list(pool.map(safe, ids))
    if not a.no_install:
        install(res)
    (HERE / "logs").mkdir(exist_ok=True)
    (HERE / "logs" / "v3_batch_last.json").write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"V3 SUMMARY ok={sum(1 for r in res if 'stage_glb' in r)}/{len(res)} failed={[r['asset'] for r in res if 'error' in r]}")


if __name__ == "__main__":
    main()
