# -*- coding: utf-8 -*-
"""Run blender_componentize.py over every formal GLB with a per-asset part spec.

Rig type follows Wanderburg DriveFeedback.DrivingType (Wheel/Leg/Track) plus
module/boss tool parts (CannonFeedback / Module2AnimatedObject style).

Output: game/assets/models/rigged/<slot>_rig.glb + artifacts/qa/rig_preview/<slot>.png
Also writes game/assets/models/rigged/rig_manifest.json consumed by Godot ProceduralRig.
"""
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
SCRIPT = str(Path(__file__).parent / "blender_componentize.py")
REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "game" / "assets" / "models" / "formal_slice"
OUT = REPO / "game" / "assets" / "models" / "rigged"
PREV = REPO / "artifacts" / "qa" / "rig_preview"
OUT.mkdir(parents=True, exist_ok=True)
PREV.mkdir(parents=True, exist_ok=True)

RED, BOSS, MOD, WORLD, BLUE = "#c8553d", "#8c4b59", "#d9a441", "#e9dcc0", "#2f4b5c"

# rig: walker | tracked | flyer | turret | world_spin | static
SPECS = {
    "enemy_light_v1": {"rig": "walker", "body_color": RED, "ground_cut": 0.34,
                       "cuts": [{"name": "Shield", "axis": "x", "ratio": 0.2, "mirror": True, "pivot": "inner", "role": "shield"}]},
    "enemy_light_v2": {"rig": "walker", "body_color": RED, "ground_cut": 0.3,
                       "cuts": [{"name": "Head", "axis": "y", "ratio": 0.22, "keep": "lt", "pivot": "inner", "role": "tool"}]},
    "enemy_ranged_v1": {"rig": "walker", "body_color": RED, "ground_cut": 0.3, "min_leg_share": 0.03,
                        "cuts": [{"name": "Barrel", "axis": "z", "ratio": 0.78, "keep": "gt", "pivot": "bottom", "role": "tool"}]},
    "enemy_flyer_v1": {"rig": "flyer", "body_color": RED, "ground_cut": None,
                       "cuts": [{"name": "Wing", "axis": "x", "ratio": 0.3, "mirror": True, "pivot": "inner", "role": "wing"}]},
    "boss_01_kanoning": {"rig": "walker", "body_color": BOSS, "ground_cut": 0.24,
                         "cuts": [{"name": "Arm", "axis": "x", "ratio": 0.26, "mirror": True, "pivot": "inner", "role": "tool"},
                                  {"name": "Head", "axis": "z", "ratio": 0.8, "keep": "gt", "pivot": "bottom", "role": "top"}]},
    "boss_02": {"rig": "walker", "body_color": BOSS, "ground_cut": 0.22,
                "cuts": [{"name": "Stack", "axis": "z", "ratio": 0.78, "keep": "gt", "pivot": "bottom", "role": "top"},
                         {"name": "Jaw", "axis": "y", "ratio": 0.18, "keep": "lt", "pivot": "inner", "role": "tool"}]},
    "boss_03": {"rig": "orbit", "body_color": BOSS, "ground_cut": None,
                "cuts": [{"name": "Ring", "axis": "x", "ratio": 0.3, "mirror": True, "pivot": "center", "role": "ring"}]},
    "player_stage02_whale": {"rig": "tracked", "body_color": BLUE, "ground_cut": 0.2,
                             "cuts": [{"name": "Jaw", "axis": "y", "ratio": 0.3, "keep": "lt", "pivot": "inner", "role": "tool"},
                                      {"name": "Stack", "axis": "z", "ratio": 0.8, "keep": "gt", "pivot": "bottom", "role": "top"}]},
    "module_umbrella_mole": {"rig": "turret", "body_color": MOD, "ground_cut": 0.18, "min_leg_share": 0.05,
                             "cuts": [{"name": "Tool", "axis": "z", "ratio": 0.62, "keep": "gt", "pivot": "bottom", "role": "tool"}]},
    "module_rail_snail": {"rig": "turret", "body_color": MOD, "ground_cut": 0.2, "min_leg_share": 0.06,
                          "cuts": [{"name": "Drum", "axis": "z", "ratio": 0.6, "keep": "gt", "pivot": "center", "role": "rotor"}]},
    "module_folding_bastion": {"rig": "turret", "body_color": MOD, "ground_cut": 0.2, "min_leg_share": 0.025,
                               "cuts": [{"name": "Shield", "axis": "x", "ratio": 0.3, "mirror": True, "pivot": "inner", "role": "shield"}]},
    "module_scrap_crawler": {"rig": "turret", "body_color": MOD, "ground_cut": 0.22, "min_leg_share": 0.05,
                             "cuts": [{"name": "Tool", "axis": "y", "ratio": 0.28, "keep": "lt", "pivot": "inner", "role": "tool"}]},
    "module_spider_crane": {"rig": "turret", "body_color": MOD, "ground_cut": 0.22, "min_leg_share": 0.05,
                            "cuts": [{"name": "Boom", "axis": "z", "ratio": 0.55, "keep": "gt", "pivot": "bottom", "role": "tool"}]},
    "module_road_croc": {"rig": "turret", "body_color": MOD, "ground_cut": 0.22, "min_leg_share": 0.05,
                         "cuts": [{"name": "Jaw", "axis": "y", "ratio": 0.25, "keep": "lt", "pivot": "inner", "role": "tool"}]},
    "module_repair_ark": {"rig": "turret", "body_color": MOD, "ground_cut": 0.2, "min_leg_share": 0.05,
                          "cuts": [{"name": "Crane", "axis": "z", "ratio": 0.65, "keep": "gt", "pivot": "bottom", "role": "tool"}]},
    "module_demolition_pigeon": {"rig": "flyer", "body_color": MOD, "ground_cut": None,
                                 "cuts": [{"name": "Wing", "axis": "x", "ratio": 0.3, "mirror": True, "pivot": "inner", "role": "wing"}]},
    "biome_gate": {"rig": "gate", "body_color": WORLD, "ground_cut": None,
                   "cuts": [{"name": "Door", "axis": "x", "ratio": 0.5, "keep": "lt", "pivot": "inner", "role": "shield"}]},
    "wind_turbine": {"rig": "world_spin", "body_color": WORLD, "ground_cut": None,
                     "cuts": [{"name": "Rotor", "axis": "z", "ratio": 0.6, "keep": "gt", "pivot": "center", "role": "rotor"}]},
    "mountain_air_pump": {"rig": "world_spin", "body_color": WORLD, "ground_cut": None,
                          "cuts": [{"name": "Rotor", "axis": "z", "ratio": 0.7, "keep": "gt", "pivot": "center", "role": "rotor"}]},
    "camp_board": {"rig": "static", "body_color": WORLD, "ground_cut": None, "cuts": []},
}


def run(slot: str) -> dict:
    spec = SPECS[slot]
    src = SRC / f"{slot}_formal.glb"
    if not src.exists():
        return {"slot": slot, "error": "missing source"}
    out = OUT / f"{slot}_rig.glb"
    prev = PREV / f"{slot}.png"
    cmd = [BLENDER, "--background", "--python", SCRIPT, "--", str(src), str(out), str(prev), json.dumps(spec)]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
    stats = None
    for line in p.stdout.splitlines():
        if line.startswith("STATS_JSON "):
            stats = json.loads(line[11:])
    if not stats:
        return {"slot": slot, "error": (p.stdout + p.stderr)[-700:]}
    res = {"slot": slot, "rig": spec["rig"], "file": f"res://assets/models/rigged/{slot}_rig.glb",
           "parts": stats["parts"], "roles": stats["roles"], "dims": stats["dims"], "sec": round(time.time() - t0, 1)}
    print(json.dumps(res, ensure_ascii=False), flush=True)
    return res


def main() -> None:
    only = sys.argv[1].split(",") if len(sys.argv) > 1 and sys.argv[1] else list(SPECS)
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(run, only))
    man_path = OUT / "rig_manifest.json"
    man = json.loads(man_path.read_text(encoding="utf-8")) if man_path.exists() else {}
    for r in results:
        if "file" in r:
            man[r["slot"]] = r
        else:
            print("FAIL", r["slot"], r["error"][-300:], flush=True)
    man_path.write_text(json.dumps(man, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"RIG SUMMARY ok={sum(1 for r in results if 'file' in r)}/{len(results)}")


if __name__ == "__main__":
    main()
