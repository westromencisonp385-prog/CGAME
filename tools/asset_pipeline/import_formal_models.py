# -*- coding: utf-8 -*-
"""Import finished Weaver mid models into the Godot project.

For each PLAN asset with a mid model: run Blender normalize/export -> 
game/assets/models/formal_slice/<slot>_formal.glb + preview. Also writes the
generic gameplay slots used by EnemyDummy (enemy_light / enemy_ranged / enemy_heavy).

Usage:
  python -u import_formal_models.py            # all finished
  python -u import_formal_models.py B02,B04    # subset
"""
import json
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, str(Path(__file__).parent))
import weaver_p2_v2 as p2  # noqa: E402

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
SCRIPT = str(Path(__file__).parent / "blender_to_game_glb.py")
GAME_DIR = p2.REPO / "game" / "assets" / "models" / "formal_slice"
PREVIEW_DIR = p2.REPO / "artifacts" / "qa" / "formal_import"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

# 槽位 -> (目标最大边长 m, 色板)。尺度参照：玩家车身约 2.6m，普通敌人约 1.4m
SLOT_SPEC = {
    "enemy_light_v1": (1.5, "enemy"), "enemy_light_v2": (1.5, "enemy"),
    "enemy_ranged_v1": (1.6, "enemy"), "enemy_flyer_v1": (1.3, "enemy"),
    "boss_01_kanoning": (3.2, "boss"), "boss_02": (3.2, "boss"), "boss_03": (3.0, "boss"),
    "player_stage02_whale": (3.0, "player"),
    "biome_gate": (4.6, "world"), "camp_board": (2.4, "world"),
    "wind_turbine": (4.0, "world"), "mountain_air_pump": (3.2, "world"),
}
MODULE_SPEC = (1.4, "module")
# 通用敌人槽位（EnemyDummy 当前按 kind 取）：用哪个 P2 资产填
GENERIC_ALIASES = {"enemy_light": "B02", "enemy_ranged": "B04", "enemy_heavy": "B03"}


def convert(asset_id: str) -> dict:
    plan = p2.PLAN[asset_id]
    tex_hits = sorted((p2.OUT_ROOT / asset_id / "weaver" / "tex").glob("*.glb"))
    src = tex_hits[0] if tex_hits else p2.mid_model_path(asset_id)
    keep = "keep" if tex_hits else "flat"
    if src is None:
        return {"asset": asset_id, "skipped": "no mid model yet"}
    slot = plan["slot"]
    size, palette = SLOT_SPEC.get(slot, MODULE_SPEC if slot.startswith("module_") else (2.0, "world"))
    out_glb = GAME_DIR / f"{slot}_formal.glb"
    out_png = PREVIEW_DIR / f"{asset_id}_{slot}.png"
    cmd = [BLENDER, "--background", "--python", SCRIPT, "--", str(src), str(out_glb), str(out_png), str(size), palette, keep]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    stats = None
    for line in proc.stdout.splitlines():
        if line.startswith("STATS_JSON "):
            stats = json.loads(line[len("STATS_JSON "):])
    if stats is None or not out_glb.exists():
        tail = (proc.stdout + proc.stderr)[-600:]
        return {"asset": asset_id, "error": f"blender failed rc={proc.returncode}: {tail}"}
    return {"asset": asset_id, "slot": slot, "textured": keep == "keep", "glb": str(out_glb), "preview": str(out_png), **{k: stats[k] for k in ("tris", "final_dims_m")}}


def main() -> None:
    ids = [a.strip().upper() for a in sys.argv[1].split(",")] if len(sys.argv) > 1 else list(p2.PLAN)
    results = []
    for asset_id in ids:
        if asset_id not in p2.PLAN:
            continue
        t0 = time.time()
        res = convert(asset_id)
        res["sec"] = round(time.time() - t0, 1)
        print(json.dumps(res, ensure_ascii=False), flush=True)
        results.append(res)
    # 通用槽位别名：复制对应 P2 产物
    for generic, asset_id in GENERIC_ALIASES.items():
        src_slot = p2.PLAN[asset_id]["slot"]
        src = GAME_DIR / f"{src_slot}_formal.glb"
        if src.exists():
            (GAME_DIR / f"{generic}_formal.glb").write_bytes(src.read_bytes())
            print(f"alias {generic} <- {asset_id} ({src_slot})", flush=True)
    ok = sum(1 for r in results if "glb" in r)
    print(f"IMPORT SUMMARY ok={ok} skipped={sum(1 for r in results if 'skipped' in r)} failed={sum(1 for r in results if 'error' in r)}")


if __name__ == "__main__":
    main()
