# -*- coding: utf-8 -*-
"""Part-by-part generation (user rule 2026-10-08): never plane-cut a fused mesh.

Pipeline per asset:
  1. reuse the asset's 360 multiview (already on disk from P2) -> upload main view
  2. Weaver 2D split (VV-SplitMask, SSE /component/init_segment) with a prompt listing the planned parts
  3. map each segment component to a planned part (by name / position) -> one node_type=11 mid model per label
     (segment_model_id + component_label), fbx output
  4. texture each part (node_type=8, part model + same multiview)
  5. tools/asset_pipeline/blender_assemble_parts.py assembles parts at their native positions (Weaver keeps the
     shared object space of the source views) into RigRoot>Body>parts GLB named for ProceduralRig.

Usage:
  python -u weaver_parts.py --asset M08 --split-only     # inspect components first
  python -u weaver_parts.py --asset M08                  # full
"""
import argparse
import json
import sys
import time
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, str(Path(__file__).parent))
import weaver_p2_v2 as p2  # noqa: E402
from weaver_api_client import _json_bytes  # noqa: E402

SPLIT_ALGO = "VV-SplitMask-V1.0.0"
MESH_ALGO = "VV-MeshGen-V1.5.0"
TEX_ALGO = "Hy3D-TEX-v3.5-preview"

# 每资产的部件规划：name = ProceduralRig 识别的节点名；hint = 给 2D 拆分的中文描述
PARTS = {
    "M08": {"prompt": "拆成：机身躯干、左翅膀、右翅膀、拆迁锤头。每个翅膀单独一个部件。",
            "parts": [("Body", "机身"), ("Wing_L", "左翅"), ("Wing_R", "右翅"), ("Tool", "锤")]},
    "M02": {"prompt": "拆成：蜗牛壳状滚筒、车身底盘、前端工具。滚筒单独一个部件。",
            "parts": [("Body", "底盘"), ("Drum", "滚筒"), ("Tool", "工具")]},
    "C01": {"prompt": "拆成三个部件：张开的鲸鱼大嘴下颚、车身（含上颚和驾驶室）、底部的履带底盘。",
            "parts": [("Body", "车身"), ("Jaw", "下颚"), ("Tread_0", "履带")]},
    "E01": {"prompt": "拆成：躯干、左臂、右臂、头部、履带底盘。左右臂各自单独。",
            "parts": [("Body", "躯干"), ("Arm_L", "左臂"), ("Arm_R", "右臂"), ("Head", "头"), ("Tread_0", "履带")]},
    "E02": {"prompt": "拆成：锅炉躯干、大嘴下颚、烟囱、四条腿。每条腿单独一个部件。",
            "parts": [("Body", "躯干"), ("Jaw", "嘴"), ("Stack", "烟囱"), ("Leg_0", "腿"), ("Leg_1", "腿"), ("Leg_2", "腿"), ("Leg_3", "腿")]},
    "E03": {"prompt": "拆成：中心核心躯干、左侧极性环、右侧极性环。两个环各自单独。",
            "parts": [("Body", "核心"), ("Ring_L", "左环"), ("Ring_R", "右环")]},
    # ---- 模块 ----
    "M01": {"prompt": "拆成：钻机车身底盘、顶部伞状钻头工具。",
            "parts": [("Body", "车身"), ("Tool", "钻")]},
    "M03": {"prompt": "拆成：堡垒车身、左侧折叠盾板、右侧折叠盾板。两块盾各自单独。",
            "parts": [("Body", "车身"), ("Shield_L", "左"), ("Shield_R", "右")]},
    "M04": {"prompt": "拆成：爬行车身、前端抓取工具臂。",
            "parts": [("Body", "车身"), ("Tool", "臂")]},
    "M05": {"prompt": "拆成：车身底座、吊臂。吊臂单独一个部件。",
            "parts": [("Body", "底座"), ("Boom", "吊臂")]},
    "M06": {"prompt": "拆成：鳄鱼车身、鳄鱼下颚。下颚单独一个部件。",
            "parts": [("Body", "车身"), ("Jaw", "下颚")]},
    "M07": {"prompt": "拆成：方舟车身、维修吊机臂。吊机臂单独一个部件。",
            "parts": [("Body", "车身"), ("Crane", "吊")]},
    # ---- 敌人 ----
    "B02": {"prompt": "拆成：蟹身躯干、左侧挡板、右侧挡板、每条腿各自单独。",
            "parts": [("Body", "躯干"), ("Shield_L", "左"), ("Shield_R", "右"), ("Leg_0", "腿"), ("Leg_1", "腿"), ("Leg_2", "腿"), ("Leg_3", "腿"), ("Leg_4", "腿"), ("Leg_5", "腿")]},
    "B03": {"prompt": "拆成：犬身躯干、头部、四条腿各自单独。",
            "parts": [("Body", "躯干"), ("Head", "头"), ("Leg_0", "腿"), ("Leg_1", "腿"), ("Leg_2", "腿"), ("Leg_3", "腿")]},
    "B04": {"prompt": "拆成：甲虫躯干、背上炮管、每条腿各自单独。",
            "parts": [("Body", "躯干"), ("Barrel", "炮"), ("Leg_0", "腿"), ("Leg_1", "腿"), ("Leg_2", "腿"), ("Leg_3", "腿")]},
    "B06": {"prompt": "拆成：蜂身躯干、左翅膀、右翅膀。两个翅膀各自单独。",
            "parts": [("Body", "躯干"), ("Wing_L", "左"), ("Wing_R", "右")]},
    # ---- 可动景物 ----
    "W01": {"prompt": "拆成：门框、门扇。门扇单独一个部件。",
            "parts": [("Body", "门框"), ("Door", "门扇")]},
    "W03": {"prompt": "拆成：涡轮塔身、旋转叶片转子。转子单独一个部件。",
            "parts": [("Body", "塔"), ("Rotor", "叶")]},
    "W04": {"prompt": "拆成：气泵机身、旋转风扇转子。转子单独一个部件。",
            "parts": [("Body", "机身"), ("Rotor", "风扇")]},
}


def log(m: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def init_segment(client, *, name: str, main_view_url: str, prompt: str, granularity: int = 2) -> dict:
    """SSE call; returns {'model_id', 'reply'}."""
    payload = {"name": name, "algorithm_model": SPLIT_ALGO, "input_view": {"main_view": main_view_url},
               "split_type": 1, "granularity": granularity}
    if prompt:
        payload["prompt"] = prompt[:200]
    body = _json_bytes(payload)
    headers = client._headers("POST", body, p2.RTX)
    headers["Accept"] = "text/event-stream"
    req = urllib.request.Request(client.base_url + "/weaver/component/init_segment", data=body, headers=headers, method="POST")
    model_id, reply, event = None, None, None
    with urllib.request.urlopen(req, timeout=600) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").rstrip("\r\n")
            if line.startswith("event:"):
                event = line[6:].strip()
            elif line.startswith("data:"):
                data_txt = line[5:].strip()
                try:
                    data = json.loads(data_txt)
                except json.JSONDecodeError:
                    data = data_txt
                if event == "pre_create" and isinstance(data, dict):
                    model_id = data.get("model_id")
                elif event == "thinking":
                    log(f"  split thinking: {str(data)[:80]}")
                elif event == "error":
                    raise RuntimeError(f"split error: {data}")
                elif event == "reply":
                    reply = data
                    break
    return {"model_id": model_id, "reply": reply}


def components_of(client, seg_model_id: str, reply: dict | None) -> list[dict]:
    if reply:
        mv = reply.get("main_view_data") or reply.get("main_view") or {}
        sd = mv.get("segment_data") or mv
        comps = sd.get("components") or []
        if comps:
            return comps
    # 回落：按 model_id 单查资产
    try:
        info = client.request("weaver/resource/get_model_info", {"model_id": seg_model_id}, rtx=p2.RTX) or {}
        return ((info.get("segment_output") or {}).get("main_view") or {}).get("components", [])
    except Exception:  # noqa: BLE001
        return []


def match_parts(components: list[dict], plan: list) -> dict:
    """plan part name -> component label. 名称包含提示词关键字优先，否则按顺序兜底。"""
    used, mapping = set(), {}
    for part, hint in plan:
        for c in components:
            if c["label"] in used:
                continue
            nm = str(c.get("name", ""))
            if hint and hint[:1] in nm and (hint in nm or len(hint) == 1 or hint[:2] in nm):
                mapping[part] = c["label"]
                used.add(c["label"])
                break
    rest = [c for c in components if c["label"] not in used]
    for part, _hint in plan:
        if part not in mapping and rest:
            mapping[part] = rest.pop(0)["label"]
    # 余下未规划的部件并入 Body（不丢几何）
    mapping["_extra_body"] = [c["label"] for c in rest]
    return mapping


def write_layout(out: Path, mapping: dict) -> None:
    import base64
    import io
    import numpy as np
    from PIL import Image
    rp = out / "segment_reply.json"
    if not rp.exists():
        return
    rep = json.loads(rp.read_text(encoding="utf-8"))["reply"]
    lab = np.array(Image.open(io.BytesIO(base64.b64decode(rep["main_view_data"]["segment_data"]["mask_image"])))).astype(np.int64)
    layout = {}
    for part, label in mapping.items():
        labels = label if isinstance(label, list) else [label]
        if part == "_extra_body":
            continue
        ys, xs = np.nonzero(np.isin(lab, labels))
        if len(xs) == 0:
            continue
        crop = np.isin(lab[ys.min():ys.max() + 1, xs.min():xs.max() + 1], labels).astype(np.uint8) * 255
        sil = np.array(Image.fromarray(crop).resize((64, 64), Image.BILINEAR)) > 100
        layout[part] = {"x0": int(xs.min()), "x1": int(xs.max()), "y0": int(ys.min()), "y1": int(ys.max()),
                        "px": int(len(xs)), "sil": "".join("1" if v else "0" for v in sil.flatten())}
    (out / "layout.json").write_text(json.dumps({"shape": list(lab.shape), "parts": layout,
                                                 "mapping": {k: v for k, v in mapping.items()}}, indent=2), encoding="utf-8")
    small = np.array(Image.fromarray(lab.astype(np.int32)).resize((512, 512), Image.NEAREST)).astype(np.int32)
    small[small == 65535] = 0
    np.save(out / "labels_512.npy", small)


def gen_part(client, asset_id: str, seg_id: str, part: str, label: int, out_dir: Path, views: dict) -> dict:
    target = out_dir / f"{part}.glb"
    if target.exists():
        return {"part": part, "label": label, "file": str(target), "skipped": True}
    for attempt in range(1, 4):
        try:
            mid = client.gen_3d_model(name=f"{asset_id}_{part}", node_type=11, rtx=p2.RTX,
                                      params={"image_gen_model_params": {"algorithm_model": MESH_ALGO, "face_type": 1,
                                                                         "output_model_format": "fbx", "segment_model_id": seg_id,
                                                                         "component_label": int(label)}})[0]
            log(f"{asset_id}.{part} mid task {mid}")
            client.wait_model(mid, rtx=p2.RTX, interval=10, timeout=1800)
            zmid = out_dir / f"{part}_mid.zip"
            client.download_file(client.download_model(model_id=mid, rtx=p2.RTX), zmid)
            mdir = out_dir / f"{part}_mid"
            with zipfile.ZipFile(zmid) as zf:
                zf.extractall(mdir)
            fbx = sorted(mdir.rglob("*.fbx"))[0]
            # texture
            cred = client.get_cos_cred(rtx=p2.RTX)
            zin = out_dir / f"{part}_texin.zip"
            with zipfile.ZipFile(zin, "w", zipfile.ZIP_DEFLATED) as zf:
                zf.write(fbx, "model.fbx")
            murl = client.upload_file(zin, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-{part}-texin-{int(time.time())}.zip")
            tex = client.gen_3d_model(name=f"{asset_id}_{part}_tex", node_type=8, rtx=p2.RTX, input_model=murl,
                                      input_model_format="fbx", input_view=views,
                                      params={"tex_params": {"algorithm_model": TEX_ALGO, "resolution": 1024, "unwarp_uv": False},
                                              "output_model_format": "glb"})[0]
            log(f"{asset_id}.{part} tex task {tex}")
            client.wait_model(tex, rtx=p2.RTX, interval=10, timeout=1800)
            ztex = out_dir / f"{part}_tex.zip"
            client.download_file(client.download_model(model_id=tex, rtx=p2.RTX), ztex)
            tdir = out_dir / f"{part}_tex"
            with zipfile.ZipFile(ztex) as zf:
                zf.extractall(tdir)
            glb = sorted(tdir.rglob("*.glb"))[0]
            target.write_bytes(glb.read_bytes())
            log(f"{asset_id}.{part} DONE")
            return {"part": part, "label": label, "file": str(target), "mid": mid, "tex": tex}
        except Exception as exc:  # noqa: BLE001
            log(f"{asset_id}.{part} attempt {attempt} failed: {str(exc)[:160]}")
            time.sleep((90 if "120041" in str(exc) else 30) * attempt)
    return {"part": part, "label": label, "error": "failed"}


def view_is_single_subject(png: Path) -> tuple[bool, int]:
    """多面板检测：前景（非白/非透明）大连通块数 > 1 视为多主体。"""
    import numpy as np
    from PIL import Image
    im = Image.open(png).convert("RGBA").resize((256, 256))
    a = np.asarray(im).astype(int)
    fg = (a[..., 3] > 30) & ((a[..., :3].min(-1) < 235))
    # 连通块（4 邻接，简单 BFS）
    seen = np.zeros_like(fg)
    big = 0
    h, w = fg.shape
    for y in range(h):
        for x in range(w):
            if fg[y, x] and not seen[y, x]:
                stack = [(y, x)]
                seen[y, x] = True
                n = 0
                while stack:
                    cy, cx = stack.pop()
                    n += 1
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                if n > fg.sum() * 0.08:
                    big += 1
    if fg.mean() > 0.55:
        ys, xs = np.nonzero(fg)
        box = (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
        rectangularity = fg.sum() / max(box, 1)
        touches = (xs.min() < 8) + (ys.min() < 8) + (xs.max() > 247) + (ys.max() > 247)
        if rectangularity > 0.88 and touches >= 2:
            return False, -1  # board / background sheet, not a single cut-out subject
    return big <= 1, big


def regen_360(client, asset_id: str) -> None:
    """用单主体原画重做图生360，覆盖本地四视图。"""
    base = p2.OUT_ROOT / asset_id / "weaver"
    concept = p2.PLAN[asset_id]["concept"]
    cred = client.get_cos_cred(rtx=p2.RTX)
    url = client.upload_file(concept, cred, object_name=f"{cred.path_prefix.rstrip('/')}/{asset_id}-re360-{int(time.time())}.png")
    algos = client.list_algorithm_model(node_type=7, rtx=p2.RTX)
    algo = "Hy3D-MultiView-v3.0" if "Hy3D-MultiView-v3.0" in algos else algos[0]
    mv_id = client.gen_multi_views(name=f"{asset_id}_360_redo", input_view={"main_view": url},
                                   params={"image_gen_360_params": {"algorithm_model": algo, "enable_a_pose": False}}, rtx=p2.RTX)
    log(f"{asset_id} redo 360 {mv_id}")
    info = client.wait_model(mv_id, rtx=p2.RTX, interval=6, timeout=900)
    views = (info.get("image_gen_360_output") or {}).get("output_view") or {}
    for key, u in views.items():
        if u:
            client.download_file(u, base / f"{asset_id}_mv_{key}.png")


def run(asset_id: str, split_only: bool, workers: int) -> dict:
    spec = PARTS[asset_id]
    base = p2.OUT_ROOT / asset_id / "weaver"
    out = p2.OUT_ROOT / asset_id / "parts"
    out.mkdir(parents=True, exist_ok=True)
    client = p2.load_client()
    main_png = base / f"{asset_id}_mv_main_view.png"
    if main_png.exists():
        ok, blobs = view_is_single_subject(main_png)
        if not ok:
            log(f"{asset_id} 360 main view has {blobs} subjects (multi-panel) -> regenerating 360")
            regen_360(client, asset_id)
            ok, blobs = view_is_single_subject(main_png)
            if not ok:
                raise RuntimeError(f"{asset_id}: 360 still multi-subject ({blobs}); fix the concept input")
    cred = client.get_cos_cred(rtx=p2.RTX)
    prefix = cred.path_prefix.rstrip("/")
    views = {}
    for key in ("main_view", "back_view", "left_view", "right_view"):
        png = base / f"{asset_id}_mv_{key}.png"
        if png.exists():
            views[key] = client.upload_file(png, cred, object_name=f"{prefix}/{asset_id}-parts-{key}-{int(time.time())}.png")
    if "main_view" not in views:
        views["main_view"] = client.upload_file(p2.PLAN[asset_id]["concept"], cred, object_name=f"{prefix}/{asset_id}-parts-main.png")
    seg_path = out / "segment.json"
    if seg_path.exists():
        seg = json.loads(seg_path.read_text(encoding="utf-8"))
    else:
        log(f"{asset_id} 2D split…")
        r = init_segment(client, name=f"{asset_id}_split", main_view_url=views["main_view"], prompt=spec["prompt"])
        (out / "segment_reply.json").write_text(json.dumps(r, ensure_ascii=False, indent=2), encoding="utf-8")
        if not r.get("reply"):
            raise RuntimeError(f"{asset_id}: 2D split returned no reply (part QC failed); adjust prompt")
        comps = components_of(client, r["model_id"], r["reply"])
        seg = {"model_id": r["model_id"], "components": comps}
        seg_path.write_text(json.dumps(seg, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"{asset_id} components: {[(c['label'], c.get('name')) for c in seg['components']]}")
    mapping = match_parts(seg["components"], spec["parts"])
    log(f"{asset_id} mapping: {mapping}")
    write_layout(out, mapping)
    if split_only:
        return {"asset": asset_id, "segment": seg, "mapping": mapping}
    jobs = [(part, mapping[part]) for part, _ in spec["parts"] if part in mapping]
    jobs += [(f"BodyExtra_{lab}", lab) for lab in mapping["_extra_body"]]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(lambda j: gen_part(client, asset_id, seg["model_id"], j[0], j[1], out, views), jobs))
    (out / "parts.json").write_text(json.dumps({"asset": asset_id, "slot": p2.PLAN[asset_id]["slot"], "segment": seg["model_id"],
                                                "mapping": mapping, "results": results}, ensure_ascii=False, indent=2), encoding="utf-8")
    ok = sum(1 for r in results if "file" in r)
    log(f"{asset_id} PARTS ok={ok}/{len(results)}")
    return {"asset": asset_id, "ok": ok, "total": len(results)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True)
    ap.add_argument("--split-only", action="store_true")
    ap.add_argument("--workers", type=int, default=3)
    a = ap.parse_args()
    for aid in [s.strip().upper() for s in a.asset.split(",") if s.strip()]:
        print(json.dumps(run(aid, a.split_only, a.workers), ensure_ascii=False)[:1500], flush=True)


if __name__ == "__main__":
    main()
