# -*- coding: utf-8 -*-
"""Weaver P1 batch: concept png -> 360 multiview -> mid-poly GLB -> download -> unzip -> manifest.

Usage:
  python weaver_p1_batch.py --asset A01          # single asset full chain
  python weaver_p1_batch.py --asset A01,B01,C04  # sequential batch

No credentials are printed. Every task id / artifact is recorded into
artifacts/ai_candidates/<asset>/manifest.json (schema per ai-asset-generation-plan-v1.md).
"""
import argparse
import json
import re
import sys
import time
import zipfile
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
SKILL_SCRIPTS = (Path(__file__).resolve().parents[2] / ".agents" / "skills" / "weaver-asset-production" / "scripts")
sys.path.insert(0, str(SKILL_SCRIPTS))
from weaver_api_client import WeaverClient, WeaverError  # noqa: E402

RTX = "jasonlyan"
REPO = Path(__file__).resolve().parents[2]
CONCEPT_DIR = REPO / "docs" / "assets" / "2d-candidates"
OUT_ROOT = REPO / "artifacts" / "ai_candidates"

ASSET_CONCEPTS = {
    "A01": "A01-whale-jaw-reclaimer.png",
    "A02": "A02-umbrella-mole.png",
    "A03": "A03-rail-snail.png",
    "A04": "A04-folding-bastion.png",
    "A05": "A05-scrap-whale-crawler.png",
    "A06": "A06-magnetic-spider-crane.png",
    "A07": "A07-pavement-crocodile.png",
    "A08": "A08-mobile-repair-ark.png",
    "B01": "B01-reverse-crab.png",
    "B02": "B02-boiler-hippo.png",
    "B03": "B03-deadline-eel.png",
    "B04": "B04-demolition-pigeon.png",
    "B05": "B05-clause-colossus.png",
    "B06": "B06-trashnado.png",
    "C01": "C01-fold-the-river.png",
    "C02": "C02-weather-after-sales.png",
    "C03": "C03-city-needs-breath.png",
    "C04": "C04-repair-pump-cutaway.png",
    "C05": "C05-facility-escort.png",
    "C06": "C06-camp-service-board.png",
}


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def load_client() -> WeaverClient:
    txt = (Path(r"D:\工作\生图API\weaver") / "鉴权.txt").read_text(encoding="utf-8")
    app_id = re.search(r"vsa_[0-9a-f]+", txt).group()
    secret = re.search(r"vss_[0-9a-f]+", txt).group()
    return WeaverClient(app_id, secret)


def pick(algos: list, prefer: list) -> str:
    for name in prefer:
        if name in algos:
            return name
    return algos[0] if algos else ""


def process_asset(client: WeaverClient, asset_id: str, mv_algos: list, mesh_algos: list, concept_override: Path | None = None) -> dict:
    concept = concept_override or (CONCEPT_DIR / ASSET_CONCEPTS[asset_id])
    out_dir = OUT_ROOT / asset_id / "weaver"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT_ROOT / asset_id / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
        "asset_id": asset_id, "tasks": [], "concept_refs": [], "style_lock_version": "reclaimer-v1"}

    import hashlib
    input_sha = hashlib.sha256(concept.read_bytes()).hexdigest()
    manifest["concept_refs"] = [f"docs/assets/2d-candidates/{ASSET_CONCEPTS[asset_id]}"]

    # 1) upload concept -> COS
    log(f"{asset_id} step1 upload concept")
    cred = client.get_cos_cred(rtx=RTX)
    view_url = client.upload_file(concept, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-concept.png")
    log(f"{asset_id} uploaded -> {view_url.split('.myqcloud.com')[-1][:48]}...")

    # 2) image -> 360 multiview (node_type 7 via gen_multi_views)
    mv_algo = pick(mv_algos, ["Hy3D-MultiView-v3.0", "VV-MultiView-V1.0.0"])
    log(f"{asset_id} step2 gen_multi_views algo={mv_algo}")
    mv_id = client.gen_multi_views(
        name=f"{asset_id}_360", input_view={"main_view": view_url},
        params={"image_gen_360_params": {"algorithm_model": mv_algo, "enable_a_pose": False}}, rtx=RTX)
    log(f"{asset_id} 360 task={mv_id}, waiting (<=900s)")
    mv = client.wait_model(mv_id, rtx=RTX, interval=6, timeout=900)
    out_view = (mv.get("image_gen_360_output") or {}).get("output_view") or {}
    saved_views = {}
    saved_urls = {}
    for view_name, url in out_view.items():
        if isinstance(url, str) and url.startswith("http"):
            p = client.download_file(url, out_dir / f"{asset_id}_mv_{view_name}.png")
            saved_views[view_name] = str(p)
            saved_urls[view_name] = url
    log(f"{asset_id} 360 done, views saved: {list(saved_views) or 'none'}")

    # 3) 360 -> mid model (node_type 11, explicit input_view mode; model_id_360 mode
    #    fails server-side with 990017, glb output also fails -> fbx is the stable path)
    mesh_algo = pick(mesh_algos, ["VV-MeshGen-V1.5.0"])
    log(f"{asset_id} step3 gen mid model algo={mesh_algo} format=fbx (input_view mode)")
    mid_ids = client.gen_3d_model(
        name=f"{asset_id}_mid", node_type=11, rtx=RTX, input_view=saved_urls,
        params={"image_gen_model_params": {
            "algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
            "output_model_format": "fbx"}})
    mid_id = mid_ids[0]
    log(f"{asset_id} mid task={mid_id}, waiting (<=1800s)")
    model = client.wait_model(mid_id, rtx=RTX, interval=10, timeout=1800)

    # 4) download zip + unzip
    log(f"{asset_id} step4 download产物")
    dl_url = client.download_model(model_id=mid_id, rtx=RTX)
    zip_path = client.download_file(dl_url, out_dir / f"{asset_id}_mid.zip")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(out_dir / "glb")
    glbs = sorted((out_dir / "glb").rglob("*.fbx")) + sorted((out_dir / "glb").rglob("*.glb")) + sorted((out_dir / "glb").rglob("*.gltf"))
    if not glbs:
        listed = [str(p.relative_to(out_dir)) for p in (out_dir / "glb").rglob("*")][:12]
        raise WeaverError(f"{asset_id}: no glb in zip, files={listed}")
    glb = glbs[0]
    out_sha = hashlib.sha256(glb.read_bytes()).hexdigest()
    log(f"{asset_id} glb={glb.name} size={glb.stat().st_size}")

    # 5) manifest
    manifest["tasks"] = [t for t in manifest["tasks"] if t.get("tool") != "weaver"] + [
        {"tool": "weaver", "endpoint": "gen_multi_views", "task_id": mv_id,
         "input_sha256": input_sha, "output": saved_views, "created": time.strftime("%Y-%m-%d"),
         "status": "api_candidate"},
        {"tool": "weaver", "endpoint": "gen_3d_model:11", "task_id": mid_id,
         "params": {"algorithm_model": mesh_algo, "face_type": 1, "face_num": 0,
                    "output_model_format": "glb", "model_id_360": mv_id},
         "output": str(glb), "output_sha256": out_sha,
         "created": time.strftime("%Y-%m-%d"), "status": "api_candidate"}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"{asset_id} manifest updated -> {manifest_path}")
    return {"asset": asset_id, "mv_id": mv_id, "mid_id": mid_id, "glb": str(glb)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True, help="comma separated asset ids, e.g. A01 or A01,B01,C04")
    ap.add_argument("--concept-override", action="append", default=[],
                    help="asset=path, use a fixed cropped concept image instead of the original")
    args = ap.parse_args()
    overrides = {}
    for item in args.concept_override:
        k, _, v = item.partition("=")
        overrides[k.strip().upper()] = Path(v.strip())
    assets = [a.strip().upper() for a in args.asset.split(",") if a.strip()]
    unknown = [a for a in assets if a not in ASSET_CONCEPTS]
    if unknown:
        raise SystemExit(f"unknown assets: {unknown}")

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
            results.append(process_asset(client, asset_id, mv_algos, mesh_algos, overrides.get(asset_id)))
        except Exception as exc:  # noqa: BLE001 - batch continues on per-asset failure
            log(f"{asset_id} FAILED: {exc}")
            results.append({"asset": asset_id, "error": str(exc)})
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
