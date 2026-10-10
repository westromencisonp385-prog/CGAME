# -*- coding: utf-8 -*-
"""Wanderburg controls research: input bindings + auto-attack parameters (research evidence only).
  1. InputActionAsset JSON (action maps / actions / bindings)
  2. AttackModuleV2 serialized values (attackMode / interval / range / rotation speed / alignment tolerance)
  3. AutoTurret values, OverworldVehicleController values
Output: docs/research/wanderburg-controls.json
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
DUMMY = Path(__file__).resolve().parents[3] / "wanderburg_re" / "il2cpp_dump" / "DummyDll"
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-controls.json"
MODES = ["Free", "Locked", "Rotate", "LimitedRotate", "FreeRandomInArea"]
ATTACK_KEYS = ("attackMode", "attackInterval", "attackRange", "maxRotationAngle", "targetAlignmentTolerance", "preAimMultiplier",
               "turretRotationSpeed", "projectilesPerAttack", "projectileInterval", "imprecision", "ally", "hasNoAttacks", "isLaser", "ballista", "isRocket", "isAirStrike", "multiBarrel")


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    ver = next(iter(env.objects)).assets_file.unity_version
    idx = {}
    mbs = []
    cls_of = {}
    for o in env.objects:
        idx[(o.assets_file.name, o.path_id)] = o
        if o.type.name == "MonoBehaviour":
            try:
                cls_of[(o.assets_file.name, o.path_id)] = o.read(check_read=False).m_Script.read().m_ClassName
                mbs.append(o)
            except Exception:  # noqa: BLE001
                pass
    gen = TypeTreeGenerator(ver)
    gen.load_local_dll_folder(str(DUMMY))
    env.typetree_generator = gen
    names = {}

    def go_path(o, gp):
        out = []
        f = o.assets_file.name
        pid = gp
        for _ in range(4):
            g = idx.get((f, pid))
            if g is None:
                break
            try:
                gt = g.read_typetree()
            except Exception:  # noqa: BLE001
                break
            out.append(gt.get("m_Name", "?"))
            tr = None
            for c in gt.get("m_Component", []):
                cp = c.get("component", c)
                t = idx.get((f, cp.get("m_PathID")))
                if t is not None and t.type.name in ("Transform", "RectTransform"):
                    tr = t
                    break
            if tr is None:
                break
            tt = tr.read_typetree()
            fp = tt.get("m_Father", {}).get("m_PathID", 0)
            if not fp:
                break
            ft = idx.get((f, fp))
            if ft is None:
                break
            pid = ft.read_typetree()["m_GameObject"]["m_PathID"]
        return "/".join(reversed(out))

    res = {"input_assets": [], "attack_modules": [], "auto_turrets": [], "vehicle_controller": [], "classes": Counter()}
    for o in mbs:
        cls = cls_of[(o.assets_file.name, o.path_id)]
        mb = None
        res["classes"][cls] += 1
        if cls == "InputActionAsset":
            try:
                tt = o.read_typetree()
            except Exception as e:  # noqa: BLE001
                res["input_assets"].append({"name": "", "err": str(e)[:200]})
                continue
            maps = []
            for m in tt.get("m_ActionMaps", []):
                acts = {a["m_Id"]: {"name": a["m_Name"], "type": a.get("m_Type"), "bindings": []} for a in m.get("m_Actions", [])}
                for b in m.get("m_Bindings", []):
                    a = acts.get(b.get("m_Action")) or next((x for x in acts.values() if x["name"] == b.get("m_Action")), None)
                    if a is not None:
                        a["bindings"].append(b.get("m_Path") or ("<composite " + b.get("m_Name", "") + ">"))
                maps.append({"map": m.get("m_Name"), "actions": list(acts.values())})
            res["input_assets"].append({"name": tt.get("m_Name"), "maps": maps})
        elif cls in ("AttackModuleV2", "AutoTurret", "OverworldVehicleController"):
            try:
                tt = o.read_typetree()
            except Exception:  # noqa: BLE001
                continue
            where = go_path(o, tt.get("m_GameObject", {}).get("m_PathID", 0))
            if cls == "AttackModuleV2":
                v = {k: tt.get(k) for k in ATTACK_KEYS if k in tt}
                if isinstance(v.get("attackMode"), int):
                    v["attackMode"] = MODES[v["attackMode"]] if v["attackMode"] < len(MODES) else v["attackMode"]
                res["attack_modules"].append({"where": where, **{k: (round(x, 3) if isinstance(x, float) else x) for k, x in v.items()}})
            elif cls == "AutoTurret":
                res["auto_turrets"].append({"where": where, **{k: round(tt[k], 3) for k in ("range", "damage", "attackInterval", "lifeTime", "turretRotationSpeed") if k in tt}})
            else:
                res["vehicle_controller"].append({"where": where, **{k: (round(x, 3) if isinstance(x, float) else x) for k, x in tt.items() if isinstance(x, (int, float, bool))}})
    res["classes"] = {k: v for k, v in res["classes"].most_common() if any(h in k for h in ("Input", "Attack", "Turret", "Ability", "Module", "Control", "Player", "Auto"))}
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
    for a in res["input_assets"]:
        print("INPUT", a.get("name"), a.get("err", ""))
        for m in a.get("maps", []):
            print("  MAP", m["map"])
            for x in m["actions"]:
                print("    ", x["name"], x["type"], x["bindings"][:8])
    am = [x for x in res["attack_modules"] if not x.get("ally")]
    print("ATTACK modules", len(res["attack_modules"]))
    print(" modes", Counter(str(x.get("attackMode")) for x in res["attack_modules"]))
    for x in res["attack_modules"][:40]:
        print("  ", x)
    print("TURRETS", res["auto_turrets"][:6])
    print("VEH", [ {k: v for k, v in x.items() if k in ('where','maxSpeed','turnSpeed','boostSpeedMultiplier','maxNitro','nitroConsumptionRate','nitroRegenRate','controllerDeadzone')} for x in res["vehicle_controller"]])
    print("CLASSES", res["classes"])


if __name__ == "__main__":
    main()
