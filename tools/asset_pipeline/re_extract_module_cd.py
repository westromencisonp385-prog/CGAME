# -*- coding: utf-8 -*-
"""Wanderburg player modules: auto-attack cooldown vs active ability cooldown (research evidence only)."""
import json
import sys
from pathlib import Path

import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
DUMMY = Path(__file__).resolve().parents[3] / "wanderburg_re" / "il2cpp_dump" / "DummyDll"
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-modules-cooldowns.json"
KEYS = ("autoAbilityBaseCooldown", "activeAbilityBaseCooldown", "activeAbilityDuration", "activeAbilityRange", "currentActiveBaseDamage",
        "autoAttackBaseSize", "autoAttackBaseSpeed", "frontSlot", "sideSlot", "backSlot", "topSlot", "crewSlot", "captainSlot", "moduleName", "displayName")


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    ver = next(iter(env.objects)).assets_file.unity_version
    picks = []
    for o in env.objects:
        if o.type.name != "MonoBehaviour":
            continue
        try:
            cls = o.read(check_read=False).m_Script.read().m_ClassName
        except Exception:  # noqa: BLE001
            continue
        if cls.startswith("Module2") and cls not in ("Module2SkinElement", "Module2AnimatedObject"):
            picks.append((cls, o))
    gen = TypeTreeGenerator(ver)
    gen.load_local_dll_folder(str(DUMMY))
    env.typetree_generator = gen
    rows = []
    for cls, o in picks:
        try:
            tt = o.read_typetree()
        except Exception as e:  # noqa: BLE001
            rows.append({"class": cls, "err": str(e)[:100]})
            continue
        rows.append({"class": cls, **{k: (round(tt[k], 2) if isinstance(tt[k], float) else tt[k]) for k in KEYS if k in tt}})
    OUT.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    for r in sorted(rows, key=lambda r: r["class"]):
        slot = next((s for s in ("frontSlot", "sideSlot", "backSlot", "topSlot", "crewSlot", "captainSlot") if r.get(s)), "-")
        print(f"{r['class']:28s} slot={slot:11s} auto_cd={r.get('autoAbilityBaseCooldown')}  active_cd={r.get('activeAbilityBaseCooldown')}  dur={r.get('activeAbilityDuration')} range={r.get('activeAbilityRange')} {r.get('err','')}")


if __name__ == "__main__":
    main()
