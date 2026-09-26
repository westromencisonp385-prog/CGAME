from __future__ import annotations
import hashlib, json, os, ssl, sys, time, urllib.request, zipfile
from pathlib import Path

sys.path.insert(0, r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.cos_upload import upload_file_to_weaver_cos
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient

ROOT = Path(__file__).resolve().parents[1]
RIG_FBX = ROOT / "artifacts/weaver/api_candidates/b01_rig/extracted/CGAME_b01_reverse_crab_rig_fbx.fbx"
OUT = ROOT / "artifacts/weaver/api_candidates/b01_motion"
REPORT = OUT / "report.json"
MESHES = ["Chassis", "Barrier_L", "Barrier_R", "Barrier_Stripe_L", "Barrier_Stripe_R",
          "Leg_L_B_Foot", "Leg_L_B_Upper", "Leg_L_F_Foot", "Leg_L_F_Upper",
          "Leg_R_B_Foot", "Leg_R_B_Upper", "Leg_R_F_Foot", "Leg_R_F_Upper", "WarningBeacon"]
JOINTS = ["pelvis", "bone_01", "bone_02", "bone_03", "bone_04", "clavicle_l_01"]

def creds():
    vals = {}
    for line in Path(r"D:\工作\AI工具\ComfyUI\appid.txt").read_text(encoding="utf-8").splitlines():
        sep = ":" if ":" in line else "="
        if sep in line:
            k, v = line.split(sep, 1); vals[k.strip().upper().replace(" ", "_")] = v.strip()
    return (os.environ.get("WEAVER_APPID") or vals.get("APPID") or vals.get("APP_ID"),
            os.environ.get("WEAVER_APPSECRET") or vals.get("APP_SECRET") or vals.get("APPSECRET") or vals.get("KEY"))

def model_id(resp):
    data = (resp or {}).get("data") or {}
    return str(data.get("model_id") or ((data.get("model_ids") or [""])[0]))

def wait(client, task_id, timeout=1200):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        rec = client.get_model_detail(task_id)
        if rec and rec.get("status") in (3, 4):
            if rec.get("status") == 4:
                raise RuntimeError(str(rec.get("failed_reason") or rec.get("msg") or "task failed")[:300])
            return rec
        time.sleep(15)
    raise TimeoutError(task_id)

def download(url, dest):
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=180, context=ctx) as src, dest.open("wb") as dst:
        while block := src.read(1024 * 1024): dst.write(block)
    return {"path": str(dest), "bytes": dest.stat().st_size,
            "sha256": hashlib.sha256(dest.read_bytes()).hexdigest()}

def pack(name, extra):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(RIG_FBX, "CGAME_b01_reverse_crab_rig_fbx.fbx")
        z.writestr("CGAME_b01_reverse_crab_rig_fbx.json", json.dumps(extra, ensure_ascii=False, indent=2))
    return path

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    app, secret = creds(); rtx = os.environ.get("WEAVER_RTX") or os.environ.get("USERNAME") or "jasonlyan"
    client = WeaverClient(app, secret, rtx, "https://ws.visvise.com.cn")
    cred_resp = client.get_cos_cred(); cred = cred_resp.get("data") if isinstance(cred_resp, dict) and "data" in cred_resp else cred_resp
    report = {"schema_version": 1, "mesh_names": MESHES, "joint_names": JOINTS, "tasks": []}

    skin_zip = pack("b01_skinning_input.zip", {"config": {"algo_name": "MotusAI-Skinning-V1.0"}, "selection": {"mesh_names": MESHES, "joint_names": JOINTS}})
    skin_src = upload_file_to_weaver_cos(client, str(skin_zip), object_name="cgame/actions/b01_skinning_input.zip", cred_data=cred)
    skin_id = model_id(client.gen_3d_model(name="CGAME_b01_reverse_crab_skinning", node_type=6, input_model=skin_src, params={}))
    skin = wait(client, skin_id); skin_row = {"node_type": 6, "task_id": skin_id, "status": skin.get("status"), "outputs": []}
    for i, url in enumerate(client.extract_output_urls(skin), 1): skin_row["outputs"].append(download(url, OUT / f"{skin_id}_{i}.zip"))
    report["tasks"].append(skin_row)
    if skin_row["outputs"]:
        motion_src = upload_file_to_weaver_cos(client, skin_row["outputs"][0]["path"], object_name="cgame/actions/b01_text_motion_input.zip", cred_data=cred)
        params = {"framing_ai_params": {"algorithm_model": "MotusAI-T2M-V1.5", "output_model_format": "fbx",
            "segments": [{"text": "待机，身体稳定地轻微呼吸", "num_frames": 60},
                         {"text": "向侧面快速冲刺", "num_frames": 90, "overlap_frames_with_prev": 10},
                         {"text": "撞上墙后明显反弹并恢复平衡", "num_frames": 60, "overlap_frames_with_prev": 10}]}}
        motion_id = model_id(client.gen_3d_model(name="CGAME_b01_reverse_crab_text_motion", node_type=4, input_model=motion_src, params=params))
        motion = wait(client, motion_id, 1500); motion_row = {"node_type": 4, "task_id": motion_id, "status": motion.get("status"), "outputs": []}
        for i, url in enumerate(client.extract_output_urls(motion), 1): motion_row["outputs"].append(download(url, OUT / f"{motion_id}_{i}.zip"))
        report["tasks"].append(motion_row)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(REPORT), "tasks": report["tasks"]}, ensure_ascii=False))

if __name__ == "__main__": main()
