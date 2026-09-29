"""Run the Weaver character / rig / skin / motion capability study.

This is deliberately a small resumable runner. It submits at most nine
Weaver tasks per character (18 total), writes each returned ID before polling,
and never stores credentials or signed URLs in the state file.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))
sys.path.insert(0, str(ROOT / "tools"))
from weaver_api_client import WeaverClient  # noqa: E402
from weaver_asset_helpers import output_urls_or_download  # noqa: E402
from weaver_credentials import require_credentials  # noqa: E402

BLENDER = Path(r"F:\SteamLibrary\steamapps\common\Blender\blender.exe")
BASE = ROOT / "artifacts" / "weaver" / "capability-study" / "characters"
REFS = BASE / "references"
STATE_PATH = BASE / "state.json"

CHARACTERS = {
    "maintenance_driver": {
        "display_name": "维修驾驶员",
        "image": REFS / "character_maintenance_driver_Apose.png",
        "pose_refs": [
            REFS / "character_maintenance_driver_Apose.png",
            REFS / "character_maintenance_driver_stride.png",
        ],
        "prompt_prefix": "一个维修驾驶员",
    },
    "wasteland_mechanic": {
        "display_name": "废土机械师",
        "image": REFS / "character_wasteland_mechanic_Apose.png",
        "pose_refs": [
            REFS / "character_wasteland_mechanic_Apose.png",
            REFS / "character_wasteland_mechanic_attack.png",
        ],
        "prompt_prefix": "一个废土机械师",
    },
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_state() -> dict[str, Any]:
    if STATE_PATH.is_file():
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    return {"version": 1, "characters": {}, "algorithms": {}, "errors": []}


def save_state(state: dict[str, Any]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(STATE_PATH)


def safe_record(value: Any) -> Any:
    """Drop URL-bearing values before writing API records to disk."""
    if isinstance(value, dict):
        return {k: safe_record(v) for k, v in value.items() if "url" not in k.lower() and "token" not in k.lower()}
    if isinstance(value, list):
        return [safe_record(v) for v in value]
    if isinstance(value, str) and value.startswith(("http://", "https://")):
        return "<redacted-url>"
    return value


def raw_model(client: WeaverClient, model_id: str, rtx: str) -> dict[str, Any]:
    rows, _ = client.get_model_list(model_id_list=[model_id], limit=20, rtx=rtx)
    if not rows:
        raise RuntimeError(f"model {model_id} not found after success")
    return rows[0]


def first_file(root: Path, suffix: str) -> Path | None:
    for p in sorted(root.rglob(f"*{suffix}")):
        if p.is_file():
            return p
    return None


def unzip(path: Path, dest: Path) -> Path:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path) as z:
        z.extractall(dest)
    return dest


def blender_names(path: Path) -> tuple[list[str], list[str]]:
    if not BLENDER.is_file():
        return [], []
    script = ROOT / "tools" / "blender_list_bones.py"
    proc = subprocess.run([str(BLENDER), "-b", "--python", str(script), "--", str(path)], capture_output=True, text=True, timeout=180)
    bones = [line[5:].strip() for line in proc.stdout.splitlines() if line.startswith("BONE ")]
    obj_script = ROOT / "tools" / "blender_list_objects.py"
    proc2 = subprocess.run([str(BLENDER), "-b", "--python", str(obj_script), "--", str(path)], capture_output=True, text=True, timeout=180)
    meshes = [line.split(" ", 2)[1] for line in proc2.stdout.splitlines() if line.startswith("MESH ")]
    return meshes, bones


def package_input(model: Path, dest: Path, *, json_data: dict[str, Any]) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    stem = dest.stem
    model_dst = dest.parent / f"{stem}.fbx"
    json_dst = dest.parent / f"{stem}.json"
    shutil.copy2(model, model_dst)
    json_dst.write_text(json.dumps(json_data, ensure_ascii=False, indent=2), encoding="utf-8")
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(model_dst, model_dst.name)
        z.write(json_dst, json_dst.name)
    return dest


def object_name(cred: Any, suffix: str) -> str:
    return f"{str(cred.path_prefix).rstrip('/')}/{suffix.lstrip('/')}"


def download_record(client: WeaverClient, record: dict[str, Any], model_id: str, out_dir: Path, prefix: str, rtx: str) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    urls = output_urls_or_download(client, record, model_id, rtx=rtx)
    for i, url in enumerate(urls, 1):
        suffix = ".zip" if url.lower().split("?", 1)[0].endswith((".zip", ".fbx", ".bvh")) else ".bin"
        path = out_dir / f"{prefix}_{i}{suffix}"
        client.download_file(url, path)
        paths.append(path)
    return paths


def task_entry(ch: dict[str, Any], key: str) -> dict[str, Any]:
    return ch.setdefault("tasks", {}).setdefault(key, {})


def submit_once(state: dict[str, Any], client: WeaverClient, rtx: str, ch: dict[str, Any], key: str, submit: Callable[[], list[str]], wait_timeout: float = 1200) -> dict[str, Any]:
    entry = task_entry(ch, key)
    if entry.get("status") == "succeeded":
        return entry
    if entry.get("status") == "failed":
        return entry
    if not entry.get("model_id"):
        try:
            ids = submit()
            if not ids:
                raise RuntimeError("empty model_ids")
            entry["model_id"] = ids[0]
            entry["submitted_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            save_state(state)
        except Exception as exc:
            entry.update(status="failed", error=f"submit: {type(exc).__name__}: {str(exc)[:300]}")
            save_state(state)
            return entry
    try:
        model = client.wait_model(entry["model_id"], rtx=rtx, interval=8, timeout=wait_timeout)
        entry.update(status="succeeded", model=safe_record(model))
        save_state(state)
    except Exception as exc:
        entry.update(status="failed", error=f"poll: {type(exc).__name__}: {str(exc)[:300]}")
        save_state(state)
    return entry


def run_character(state: dict[str, Any], client: WeaverClient, rtx: str, algorithms: dict[str, str], name: str, spec: dict[str, Any]) -> None:
    ch = state.setdefault("characters", {}).setdefault(name, {"display_name": spec["display_name"], "files": {}, "tasks": {}})
    cdir = BASE / name
    cdir.mkdir(parents=True, exist_ok=True)
    image = spec["image"]
    ch["files"]["reference"] = {"path": str(image), "bytes": image.stat().st_size, "sha256": sha256(image)}
    cred = client.get_cos_cred(rtx=rtx)
    main_url = client.upload_file(image, cred, object_name=object_name(cred, f"character-study/{name}/{image.name}"))

    # 1) Image -> 360 views (node 7)
    mv = submit_once(state, client, rtx, ch, "multi_view", lambda: [client.gen_multi_views(name=f"CGAME_{name}_360", input_view={"main_view": main_url}, params={"image_gen_360_params": {"algorithm_model": algorithms["7"], "enable_a_pose": True, "prompt": spec["prompt_prefix"]}}, rtx=rtx)])
    if mv.get("status") == "succeeded" and "views" not in ch["files"]:
        view_dir = cdir / "multi_view"; view_dir.mkdir(parents=True, exist_ok=True)
        rec = raw_model(client, mv["model_id"], rtx)
        output = rec.get("image_gen_360_output") or {}
        views = output.get("output_view") or {}
        saved = {}
        for view_name, url in views.items():
            if isinstance(url, str) and url.startswith("http"):
                p = view_dir / f"{view_name}.png"; client.download_file(url, p); saved[view_name] = str(p)
        ch["files"]["views"] = saved
        save_state(state)

    # 2) 360 views -> high model (node 3)
    views = ch["files"].get("views") or {"main_view": str(image)}
    view_urls = {k: client.upload_file(Path(v), cred, object_name=object_name(cred, f"character-study/{name}/views/{Path(v).name}")) for k, v in views.items() if Path(v).is_file()}
    high = submit_once(state, client, rtx, ch, "high_model", lambda: client.gen_3d_model(name=f"CGAME_{name}_high", node_type=3, input_view=view_urls, params={"image_gen_model_params": {"algorithm_model": algorithms["3"], "face_type": 1, "face_num": 120000, "output_model_format": "fbx", "enable_pbr": True}}, rtx=rtx))
    if high.get("status") == "succeeded" and "high_zip" not in ch["files"]:
        paths = download_record(client, raw_model(client, high["model_id"], rtx), high["model_id"], cdir / "high_model", "high", rtx)
        if paths:
            ch["files"]["high_zip"] = str(paths[0]); save_state(state)

    high_zip = Path(ch["files"].get("high_zip", ""))
    high_dir = unzip(high_zip, cdir / "high_model" / "extracted") if high_zip.is_file() and high_zip.suffix == ".zip" else None
    high_fbx = first_file(high_dir, ".fbx") if high_dir else None
    if not high_fbx:
        return
    # 3) high model -> rig (node 5)
    rig_in = package_input(high_fbx, cdir / "rigging" / f"{name}_rig_input.zip", json_data={"selection": {}, "config": {"mesh_category": "humanoid", "algo_name": algorithms["5"], "generate_root": False, "temperature": -1, "num_beams": 10, "algo_scenario": 1}})
    rig_url = client.upload_file(rig_in, cred, object_name=object_name(cred, f"character-study/{name}/rig/{rig_in.name}"))
    rig = submit_once(state, client, rtx, ch, "rigging", lambda: client.gen_3d_model(name=f"CGAME_{name}_rig", node_type=5, input_model=rig_url, params={"go_rigging_params": {"algorithm_model": algorithms["5"]}}, rtx=rtx))
    if rig.get("status") == "succeeded" and "rig_zip" not in ch["files"]:
        paths = download_record(client, raw_model(client, rig["model_id"], rtx), rig["model_id"], cdir / "rigging", "rig", rtx)
        if paths:
            ch["files"]["rig_zip"] = str(paths[0]); save_state(state)
    rig_zip = Path(ch["files"].get("rig_zip", ""))
    rig_dir = unzip(rig_zip, cdir / "rigging" / "extracted") if rig_zip.is_file() and rig_zip.suffix == ".zip" else None
    rig_fbx = first_file(rig_dir, ".fbx") if rig_dir else None
    if not rig_fbx:
        return
    meshes, bones = blender_names(rig_fbx)
    ch["rig_report"] = {"mesh_names": meshes, "joint_count": len(bones), "joint_names": bones[:200]}
    save_state(state)
    # 4) rig -> skin (node 6)
    skin_in = package_input(rig_fbx, cdir / "skinning" / f"{name}_skin_input.zip", json_data={"config": {"algo_name": algorithms["6"]}, "selection": {"mesh_names": meshes, "joint_names": bones}})
    skin_url = client.upload_file(skin_in, cred, object_name=object_name(cred, f"character-study/{name}/skin/{skin_in.name}"))
    skin = submit_once(state, client, rtx, ch, "skinning", lambda: client.gen_3d_model(name=f"CGAME_{name}_skin", node_type=6, input_model=skin_url, params={}, rtx=rtx))
    if skin.get("status") == "succeeded" and "skin_zip" not in ch["files"]:
        paths = download_record(client, raw_model(client, skin["model_id"], rtx), skin["model_id"], cdir / "skinning", "skin", rtx)
        if paths:
            ch["files"]["skin_zip"] = str(paths[0]); save_state(state)
    skin_zip = Path(ch["files"].get("skin_zip", ""))
    if not skin_zip.is_file():
        return
    skin_url = client.upload_file(skin_zip, cred, object_name=object_name(cred, f"character-study/{name}/skin/{skin_zip.name}"))
    # 5-8) T2M single and multi segments (four separate submissions)
    prompts = {
        "t2m_idle": "原地待机，重心轻微呼吸起伏，机械臂和工具线圈缓慢巡检，不向前移动",
        "t2m_run": "原地循环跑步动作，双腿快速交替，手臂配合摆动，保持角色在原地",
        "t2m_attack": "原地重击攻击，先蓄力后抬起机械工具臂猛烈砸下，结束回到准备姿势",
    }
    for key, prompt in prompts.items():
        submit_once(state, client, rtx, ch, key, lambda prompt=prompt, key=key: client.gen_3d_model(name=f"CGAME_{name}_{key}", node_type=4, input_model=skin_url, params={"framing_ai_params": {"algorithm_model": algorithms["4_t2m"], "output_model_format": "fbx", "prompt": prompt}}, rtx=rtx))
    segments = [{"text": "从待机姿势开始，检查身上的工具和能量线圈", "num_frames": 60}, {"text": "原地快速跑步，双臂保持平衡", "num_frames": 90, "overlap_frames_with_prev": 10}, {"text": "向前挥动机械工具臂并重击一次，回到待机", "num_frames": 90, "overlap_frames_with_prev": 10}]
    submit_once(state, client, rtx, ch, "t2m_multi", lambda: client.gen_3d_model(name=f"CGAME_{name}_t2m_multi", node_type=4, input_model=skin_url, params={"framing_ai_params": {"algorithm_model": algorithms["4_t2m"], "output_model_format": "fbx", "segments": segments}}, rtx=rtx))
    # 9) Batch Pose, using two locally generated single-subject references.
    pose_urls = [client.upload_file(p, cred, object_name=object_name(cred, f"character-study/{name}/pose/{p.name}")) for p in spec["pose_refs"]]
    pose_key = "pose_batch"
    entry = task_entry(ch, pose_key)
    if not entry.get("model_id") and entry.get("status") != "failed":
        try:
            ids = client.request("weaver/resource/batch_gen_pose", {"name": f"CGAME_{name}_pose_batch", "input_model": skin_url, "input_images": pose_urls, "params": {"algorithm_model": "MotusAI-Posing-V1.0", "output_model_format": "fbx"}}, rtx=rtx)["model_ids"]
            entry["model_id"] = ids[0]; entry["submitted_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()); save_state(state)
        except Exception as exc:
            entry.update(status="failed", error=f"submit: {type(exc).__name__}: {str(exc)[:300]}"); save_state(state)
    if entry.get("model_id") and entry.get("status") not in {"succeeded", "failed"}:
        try:
            model = client.wait_model(entry["model_id"], rtx=rtx, interval=8, timeout=1200)
            entry.update(status="succeeded", model=safe_record(model)); save_state(state)
        except Exception as exc:
            entry.update(status="failed", error=f"poll: {type(exc).__name__}: {str(exc)[:300]}"); save_state(state)


def main() -> int:
    BASE.mkdir(parents=True, exist_ok=True)
    state = load_state()
    app, secret, rtx, base = require_credentials()
    client = WeaverClient(app, secret, base)
    state["quota"] = client.get_user_quota(rtx=rtx)
    algorithms = state.setdefault("algorithms", {})
    for node, key in [(7, "7"), (3, "3"), (5, "5"), (6, "6")]:
        if key not in algorithms:
            algorithms[key] = client.list_algorithm_model(node_type=node, rtx=rtx)[0]
    if "4_t2m" not in algorithms:
        models = client.list_algorithm_model(node_type=4, rtx=rtx, sub_type=2)
        algorithms["4_t2m"] = next((m for m in models if "T2M" in m), models[0])
    save_state(state)
    for name, spec in CHARACTERS.items():
        run_character(state, client, rtx, algorithms, name, spec)
    save_state(state)
    print(json.dumps({"state": str(STATE_PATH), "characters": list(state.get("characters", {})), "task_counts": {k: len(v.get("tasks", {})) for k, v in state.get("characters", {}).items()}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
