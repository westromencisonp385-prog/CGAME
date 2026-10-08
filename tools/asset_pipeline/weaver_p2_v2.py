# -*- coding: utf-8 -*-
"""Weaver P2 batch (v2): full whitebox replacement plan.

20 个 3D 模型槽位（原画设定稿全覆盖，含模块/Boss/召唤物/门/钥匙/王冠/群系景物）
+ 每资产产出贴图任务（node_type 8 PBR 贴图，中模后追加）。

Usage:
  python weaver_p2_v2.py --plan                 # show full plan
  python weaver_p2_v2.py --asset B02            # single full chain (360+mid)
  python weaver_p2_v2.py --asset B02,B05        # batch
  python weaver_p2_v2.py --texture B02          # PBR texture for finished mid model
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
COMIC_DIR = REPO / "docs" / "assets" / "comic-whale-v1"
SINGLE_DIR = REPO / "artifacts" / "weaver" / "inputs"
OUT_ROOT = REPO / "artifacts" / "ai_candidates"

# ============ 模型槽位总表（20）============
# 每项：概念稿（有则用原画，无则用最贴切概念稿+提示词变体）、游戏槽位
# 敌人 B01 已有（G1），玩家 A01 已有，水泵 C04 已有 —— 不重跑。
PLAN = {
    # ---- 普通敌人（light 楔形白模替换）----
    "B02": {"concept": SINGLE_DIR / "B02-single.png", "slot": "enemy_light_v1", "label": "液压路障蟹"},
    "B03": {"concept": COMIC_DIR / "N02-scrapwheel-hound.png", "slot": "enemy_light_v2", "label": "废料轮犬"},
    "B04": {"concept": COMIC_DIR / "N03-drum-pack-artillery-beetle.png", "slot": "enemy_ranged_v1", "label": "鼓包炮甲虫"},
    "B06": {"concept": COMIC_DIR / "N04-mag-rail-repair-bee.png", "slot": "enemy_flyer_v1", "label": "磁轨维修蜂"},
    # ---- Boss（heavy 大盒白模替换，10 顺位全量）----
    "E01": {"concept": COMIC_DIR / "BOSS01-breakwall-titan.png", "slot": "boss_01_kanoning", "label": "破壁泰坦"},
    "E02": {"concept": COMIC_DIR / "E01-high-pressure-thunder-boiler-hippo.png", "slot": "boss_02", "label": "高压雷锅河马"},
    "E03": {"concept": COMIC_DIR / "E02-polarity-ring-hunter.png", "slot": "boss_03", "label": "极性环猎手"},
    # ---- 玩家二阶鲸形态 ----
    "C01": {"concept": SINGLE_DIR / "C01-single.png", "slot": "player_stage02_whale", "label": "叠河鲸"},
    # ---- 模块 8 件（改装台/装配位白模替换）----
    # 2d-candidates 是多面板设定板，直接喂 360 会生成多个主体；统一改用单主体提取图
    "M01": {"concept": SINGLE_DIR / "M01-single.png", "slot": "module_umbrella_mole", "label": "伞鼠钻机"},
    "M02": {"concept": SINGLE_DIR / "M02-single.png", "slot": "module_rail_snail", "label": "轨道蜗牛"},
    "M03": {"concept": SINGLE_DIR / "M03-single.png", "slot": "module_folding_bastion", "label": "折叠堡垒"},
    "M04": {"concept": SINGLE_DIR / "M04-single.png", "slot": "module_scrap_crawler", "label": "废料鲸爬"},
    "M05": {"concept": SINGLE_DIR / "M05-single.png", "slot": "module_spider_crane", "label": "磁蛛吊机"},
    "M06": {"concept": SINGLE_DIR / "M06-single.png", "slot": "module_road_croc", "label": "铺路鳄"},
    "M07": {"concept": SINGLE_DIR / "M07-single.png", "slot": "module_repair_ark", "label": "移动维修方舟"},
    "M08": {"concept": SINGLE_DIR / "M08-single.png", "slot": "module_demolition_pigeon", "label": "拆迁鸽"},
    # ---- 群系世界物 ----
    "W01": {"concept": SINGLE_DIR / "W01-single.png", "slot": "biome_gate", "label": "群系锁门"},
    "W02": {"concept": SINGLE_DIR / "W02-single.png", "slot": "camp_board", "label": "营地服务板"},
    "W03": {"concept": SINGLE_DIR / "W03-single.png", "slot": "wind_turbine", "label": "盐风涡轮"},
    "W04": {"concept": SINGLE_DIR / "W04-single.png", "slot": "mountain_air_pump", "label": "高山气泵"},
}
# C05 在 P2 计划中同时覆盖 biome_gate 槽位；E-boss 槽位对齐 ContentRoster.BOSS_ROSTER 顺位。


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def load_client() -> WeaverClient:
    txt = (Path(r"D:\工作\生图API\weaver") / "鉴权.txt").read_text(encoding="utf-8")
    return WeaverClient(re.search(r"vsa_[0-9a-f]+", txt).group(), re.search(r"vss_[0-9a-f]+", txt).group())


def mid_model_path(asset_id: str) -> Path | None:
    out_dir = OUT_ROOT / asset_id / "weaver" / "glb"
    if not out_dir.exists():
        return None
    models = sorted(out_dir.rglob("*.fbx")) + sorted(out_dir.rglob("*.glb")) + sorted(out_dir.rglob("*.gltf"))
    return models[0] if models else None


def process_asset(client: WeaverClient, asset_id: str, mv_algos: list, mesh_algos: list) -> dict:
    plan = PLAN[asset_id]
    concept: Path = plan["concept"]
    if not concept.exists():
        raise WeaverError(f"{asset_id}: concept missing {concept}")
    out_dir = OUT_ROOT / asset_id / "weaver"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT_ROOT / asset_id / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
        "asset_id": asset_id, "tasks": [], "concept_refs": [], "style_lock_version": "reclaimer-v1"}
    manifest["concept_refs"] = [str(concept.relative_to(REPO))]
    manifest["game_slot"] = plan["slot"]
    manifest["label"] = plan["label"]
    input_sha = hashlib.sha256(concept.read_bytes()).hexdigest()

    log(f"{asset_id} [{plan['label']}] step1 upload")
    cred = client.get_cos_cred(rtx=RTX)
    view_url = client.upload_file(concept, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-concept.png")

    mv_algo = "Hy3D-MultiView-v3.0" if "Hy3D-MultiView-v3.0" in mv_algos else mv_algos[0]
    log(f"{asset_id} step2 360 algo={mv_algo}")
    mv_id = client.gen_multi_views(
        name=f"{asset_id}_360", input_view={"main_view": view_url},
        params={"image_gen_360_params": {"algorithm_model": mv_algo, "enable_a_pose": False}}, rtx=RTX)
    mv = client.wait_model(mv_id, rtx=RTX, interval=6, timeout=900)
    out_view = (mv.get("image_gen_360_output") or {}).get("output_view") or {}
    saved_urls = {k: v for k, v in out_view.items() if isinstance(v, str) and v.startswith("http")}
    saved_views = {}
    for view_name, url in saved_urls.items():
        p = client.download_file(url, out_dir / f"{asset_id}_mv_{view_name}.png")
        saved_views[view_name] = str(p)
    log(f"{asset_id} 360 done views={list(saved_views)}")

    mesh_algo = "VV-MeshGen-V1.5.0" if "VV-MeshGen-V1.5.0" in mesh_algos else mesh_algos[0]
    log(f"{asset_id} step3 mid model algo={mesh_algo}")
    mid_ids = client.gen_3d_model(
        name=f"{asset_id}_mid", node_type=11, rtx=RTX, input_view=saved_urls,
        params={"image_gen_model_params": {
            "algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
            "output_model_format": "fbx"}})
    mid_id = mid_ids[0]
    client.wait_model(mid_id, rtx=RTX, interval=10, timeout=1800)

    log(f"{asset_id} step4 download")
    dl_url = client.download_model(model_id=mid_id, rtx=RTX)
    zip_path = client.download_file(dl_url, out_dir / f"{asset_id}_mid.zip")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(out_dir / "glb")
    model = mid_model_path(asset_id)
    if model is None:
        raise WeaverError(f"{asset_id}: no model in zip")
    log(f"{asset_id} model={model.name} size={model.stat().st_size}")

    manifest["tasks"] = [t for t in manifest["tasks"] if t.get("tool") != "weaver"] + [
        {"tool": "weaver", "endpoint": "gen_multi_views", "task_id": mv_id,
         "input_sha256": input_sha, "output": saved_views, "created": time.strftime("%Y-%m-%d"),
         "status": "api_candidate"},
        {"tool": "weaver", "endpoint": "gen_3d_model:11", "task_id": mid_id,
         "params": {"algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
                    "output_model_format": "fbx", "input_view_from_360": mv_id},
         "output": str(model), "output_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
         "game_slot": plan["slot"], "created": time.strftime("%Y-%m-%d"), "status": "api_candidate"}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"asset": asset_id, "slot": plan["slot"], "mv_id": mv_id, "mid_id": mid_id, "model": str(model)}


def texture_asset(client: WeaverClient, asset_id: str, tex_algos: list) -> dict:
    """对已完成的中模跑 PBR 贴图任务（node_type 8）。"""
    plan = PLAN[asset_id]
    model = mid_model_path(asset_id)
    if model is None:
        raise WeaverError(f"{asset_id}: no mid model; run mesh first")
    out_dir = OUT_ROOT / asset_id / "weaver"
    manifest_path = OUT_ROOT / asset_id / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    log(f"{asset_id} texture upload model")
    cred = client.get_cos_cred(rtx=RTX)
    model_url = client.upload_file(model, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-mid.fbx")
    tex_algo = tex_algos[0]
    log(f"{asset_id} step5 PBR texture algo={tex_algo}")
    tex_ids = client.gen_3d_model(
        name=f"{asset_id}_tex", node_type=8, rtx=RTX, input_model=model_url,
        params={"texture_gen_params": {"algorithm_model": tex_algo}})
    tex_id = tex_ids[0]
    client.wait_model(tex_id, rtx=RTX, interval=10, timeout=1800)
    dl_url = client.download_model(model_id=tex_id, rtx=RTX)
    zip_path = client.download_file(dl_url, out_dir / f"{asset_id}_tex.zip")
    tex_dir = out_dir / "textures"
    tex_dir.mkdir(exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(tex_dir)
    files = [str(p) for p in sorted(tex_dir.rglob("*")) if p.is_file()]
    log(f"{asset_id} textures={len(files)}")
    manifest["tasks"] = [t for t in manifest["tasks"] if "gen_3d_model:8" not in str(t.get("endpoint", ""))] + [
        {"tool": "weaver", "endpoint": "gen_3d_model:8", "task_id": tex_id,
         "params": {"algorithm_model": tex_algo, "input_model": model_url},
         "output": files, "created": time.strftime("%Y-%m-%d"), "status": "api_candidate"}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"asset": asset_id, "tex_id": tex_id, "files": files}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", help="comma separated asset ids from PLAN")
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--texture", help="comma separated; run PBR texture for finished mid models")
    args = ap.parse_args()
    if args.plan:
        total = len(PLAN)
        print(f"model slots: {total}, texture tasks: {total}, api tasks: {total * 3}")
        for k, v in PLAN.items():
            print(f"  {k}: {v['label']} -> {v['slot']}  ({v['concept'].name})")
        return
    client = load_client()
    quota = client.get_user_quota(rtx=RTX)
    log(f"quota: {quota}")
    if args.texture:
        tex_algos = client.list_algorithm_model(node_type=8, rtx=RTX)
        log(f"texture algos={tex_algos}")
        results = []
        for asset_id in [a.strip().upper() for a in args.texture.split(",") if a.strip()]:
            try:
                results.append(texture_asset(client, asset_id, tex_algos))
            except Exception as exc:  # noqa: BLE001
                log(f"{asset_id} TEX FAILED: {exc}")
                results.append({"asset": asset_id, "error": str(exc)})
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    if not args.asset:
        raise SystemExit("require --asset or --texture or --plan")
    mv_algos = client.list_algorithm_model(node_type=7, rtx=RTX)
    mesh_algos = client.list_algorithm_model(node_type=11, rtx=RTX)
    log(f"360 algos={mv_algos}; mid algos={mesh_algos}")
    results = []
    for asset_id in [a.strip().upper() for a in args.asset.split(",") if a.strip()]:
        if asset_id not in PLAN:
            results.append({"asset": asset_id, "error": "unknown id"})
            continue
        try:
            results.append(process_asset(client, asset_id, mv_algos, mesh_algos))
        except Exception as exc:  # noqa: BLE001
            log(f"{asset_id} FAILED: {exc}")
            results.append({"asset": asset_id, "error": str(exc)})
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
