# -*- coding: utf-8 -*-
"""Weaver P2 batch: generate the four models the game actually needs, wired into
the whitebox slots found in gameplay (heavy enemy block, light enemy wedge,
ranged enemy, player stage-02 whale). Reuses the P1 chain:
concept png -> 360 multiview -> mid model (fbx) -> download -> unzip -> manifest.

Usage:
  python weaver_p2_batch.py --asset B02            # single
  python weaver_p2_batch.py --asset B02,B03,B04,C01
  python weaver_p2_batch.py --list                 # show plan and exit
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
from weaver_api_client import WeaverClient, WeaverError  # noqa: E402

RTX = "jasonlyan"
REPO = Path(__file__).resolve().parents[2]
CONCEPT_DIR = REPO / "docs" / "assets" / "2d-candidates"
OUT_ROOT = REPO / "artifacts" / "ai_candidates"
GAME_MODELS = REPO / "game" / "assets" / "models" / "formal_slice"

# 游戏接线位 -> 概念稿。用途来自当前白模清单：
#   heavy 敌人现在是 BoxMesh 大盒子（boss/重装敌人） -> B05 条款巨人
#   light 敌人现在是六棱楔（普通敌人）       -> B02 锅炉河马
#   ranged 敌人现在是同款楔（远程敌人）       -> B03 死线鳗
#   玩家二阶鲸形态（stage_02_whale）尚无模型  -> C01 叠河
P2_PLAN = {
    "B02": {"concept": "B02-boiler-hippo.png", "slot": "enemy_light", "game_name": "enemy_light_formal.glb"},
    "B03": {"concept": "B03-deadline-eel.png", "slot": "enemy_ranged", "game_name": "enemy_ranged_formal.glb"},
    "B05": {"concept": "B05-clause-colossus.png", "slot": "enemy_heavy", "game_name": "enemy_heavy_formal.glb"},
    "C01": {"concept": "C01-fold-the-river.png", "slot": "player_stage02_whale", "game_name": "player_stage02_whale_formal.glb"},
}


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def load_client() -> WeaverClient:
    txt = (Path(r"D:\工作\生图API\weaver") / "鉴权.txt").read_text(encoding="utf-8")
    app_id = re.search(r"vsa_[0-9a-f]+", txt).group()
    secret = re.search(r"vss_[0-9a-f]+", txt).group()
    return WeaverClient(app_id, secret)


def process_asset(client: WeaverClient, asset_id: str, mv_algos: list, mesh_algos: list) -> dict:
    plan = P2_PLAN[asset_id]
    concept = CONCEPT_DIR / plan["concept"]
    out_dir = OUT_ROOT / asset_id / "weaver"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT_ROOT / asset_id / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
        "asset_id": asset_id, "tasks": [], "concept_refs": [], "style_lock_version": "reclaimer-v1"}
    manifest["concept_refs"] = [f"docs/assets/2d-candidates/{plan['concept']}"]
    manifest["game_slot"] = plan["slot"]

    import hashlib
    input_sha = hashlib.sha256(concept.read_bytes()).hexdigest()

    log(f"{asset_id} step1 upload concept ({plan['slot']})")
    cred = client.get_cos_cred(rtx=RTX)
    view_url = client.upload_file(concept, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-concept.png")

    mv_algo = "Hy3D-MultiView-v3.0" if "Hy3D-MultiView-v3.0" in mv_algos else mv_algos[0]
    log(f"{asset_id} step2 gen_multi_views algo={mv_algo}")
    mv_id = client.gen_multi_views(
        name=f"{asset_id}_360", input_view={"main_view": view_url},
        params={"image_gen_360_params": {"algorithm_model": mv_algo, "enable_a_pose": False}}, rtx=RTX)
    log(f"{asset_id} 360 task={mv_id}")
    mv = client.wait_model(mv_id, rtx=RTX, interval=6, timeout=900)
    out_view = (mv.get("image_gen_360_output") or {}).get("output_view") or {}
    saved_urls = {k: v for k, v in out_view.items() if isinstance(v, str) and v.startswith("http")}
    saved_views = {}
    for view_name, url in saved_urls.items():
        p = client.download_file(url, out_dir / f"{asset_id}_mv_{view_name}.png")
        saved_views[view_name] = str(p)
    log(f"{asset_id} 360 done, views: {list(saved_views) or 'none'}")

    mesh_algo = "VV-MeshGen-V1.5.0" if "VV-MeshGen-V1.5.0" in mesh_algos else mesh_algos[0]
    log(f"{asset_id} step3 mid model algo={mesh_algo} format=fbx (input_view mode)")
    mid_ids = client.gen_3d_model(
        name=f"{asset_id}_mid", node_type=11, rtx=RTX, input_view=saved_urls,
        params={"image_gen_model_params": {
            "algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
            "output_model_format": "fbx"}})
    mid_id = mid_ids[0]
    log(f"{asset_id} mid task={mid_id}, waiting (<=1800s)")
    client.wait_model(mid_id, rtx=RTX, interval=10, timeout=1800)

    log(f"{asset_id} step4 download")
    dl_url = client.download_model(model_id=mid_id, rtx=RTX)
    zip_path = client.download_file(dl_url, out_dir / f"{asset_id}_mid.zip")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(out_dir / "glb")
    models = sorted((out_dir / "glb").rglob("*.fbx")) + sorted((out_dir / "glb").rglob("*.glb")) + sorted((out_dir / "glb").rglob("*.gltf"))
    if not models:
        listed = [str(p.relative_to(out_dir)) for p in (out_dir / "glb").rglob("*")][:12]
        raise WeaverError(f"{asset_id}: no model in zip, files={listed}")
    model = models[0]
    out_sha = hashlib.sha256(model.read_bytes()).hexdigest()
    log(f"{asset_id} model={model.name} size={model.stat().st_size}")

    manifest["tasks"] = [t for t in manifest["tasks"] if t.get("tool") != "weaver"] + [
        {"tool": "weaver", "endpoint": "gen_multi_views", "task_id": mv_id,
         "input_sha256": input_sha, "output": saved_views, "created": time.strftime("%Y-%m-%d"),
         "status": "api_candidate"},
        {"tool": "weaver", "endpoint": "gen_3d_model:11", "task_id": mid_id,
         "params": {"algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
                    "output_model_format": "fbx", "input_view_from_360": mv_id},
         "output": str(model), "output_sha256": out_sha, "game_slot": plan["slot"],
         "created": time.strftime("%Y-%m-%d"), "status": "api_candidate"}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"{asset_id} manifest updated")
    return {"asset": asset_id, "slot": plan["slot"], "mv_id": mv_id, "mid_id": mid_id, "model": str(model)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", help="comma separated, e.g. B02,B03,B05,C01")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    if args.list:
        for k, v in P2_PLAN.items():
            print(f"{k}: {v['concept']} -> slot={v['slot']} -> game/{v['game_name']}")
        return
    if not args.asset:
        raise SystemExit("require --asset")
    assets = [a.strip().upper() for a in args.asset.split(",") if a.strip()]
    unknown = [a for a in assets if a not in P2_PLAN]
    if unknown:
        raise SystemExit(f"unknown assets: {unknown}; plan: {list(P2_PLAN)}")

    client = load_client()
    quota = client.get_user_quota(rtx=RTX)
    log(f"quota: {quota}")
    mv_algos = client.list_algorithm_model(node_type=7, rtx=RTX)
    mesh_algos = client.list_algorithm_model(node_type=11, rtx=RTX)
    log(f"360 algos={mv_algos}; mid algos={mesh_algos}")
    if not mv_algos or not mesh_algos:
        raise SystemExit("no available algorithm models")

    results = []
    for asset_id in assets:
        try:
            results.append(process_asset(client, asset_id, mv_algos, mesh_algos))
        except Exception as exc:  # noqa: BLE001
            log(f"{asset_id} FAILED: {exc}")
            results.append({"asset": asset_id, "error": str(exc)})
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
