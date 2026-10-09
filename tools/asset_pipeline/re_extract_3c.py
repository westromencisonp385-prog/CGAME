# -*- coding: utf-8 -*-
"""Read Wanderburg's serialized 3C parameters (CameraRig / VM / DriveFeedback / CameraShaker / VMBaseStats).

IL2CPP builds strip MonoBehaviour typetrees; we regenerate them from Il2CppDumper's DummyDll and parse
the real values out of data.unity3d. Output: docs/research/wanderburg-3c-params.json (research evidence only,
values are used as tuning references, nothing is copied into game/).
"""
import json
import sys
from pathlib import Path

import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
DUMMY = Path(__file__).resolve().parents[3] / "wanderburg_re" / "il2cpp_dump" / "DummyDll"
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-3c-params.json"
WANT = {"CameraRig", "VM", "DriveFeedback", "CameraShaker", "VMBaseStats", "OverworldVehicleController", "Harvester"}
SKIP_KEYS = {"m_GameObject", "m_Script", "m_Enabled", "m_EditorHideFlags", "m_EditorClassIdentifier", "m_Name"}


def slim(v, depth=0):
    """Drop PPtrs / big arrays; keep numbers, bools, curves (as key list)."""
    if isinstance(v, dict):
        if set(v.keys()) >= {"m_FileID", "m_PathID"}:
            return None
        if "m_Curve" in v:
            return [[round(k.get("time", 0), 3), round(k.get("value", 0), 3)] for k in v["m_Curve"]][:12]
        out = {}
        for k, x in v.items():
            if k in SKIP_KEYS:
                continue
            s = slim(x, depth + 1)
            if s is not None and s != {} and s != []:
                out[k] = s
        return out
    if isinstance(v, list):
        if len(v) > 24:
            return f"<list {len(v)}>"
        items = [slim(x, depth + 1) for x in v]
        return [i for i in items if i is not None]
    if isinstance(v, float):
        return round(v, 4)
    return v


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    ver = None
    for f in env.files.values():
        ver = getattr(f, "unity_version", None) or ver
        if ver:
            break
    if ver is None:
        obj0 = next(iter(env.objects))
        ver = obj0.assets_file.unity_version
    print("unity", ver)
    hits = []
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            mb = obj.read(check_read=False)
            name = mb.m_Script.read().m_ClassName
        except Exception:  # noqa: BLE001
            continue
        if name in WANT:
            go = ""
            try:
                go = mb.m_GameObject.read().m_Name
            except Exception:  # noqa: BLE001
                pass
            hits.append((name, go, obj))
    print("hits", len(hits))
    gen = TypeTreeGenerator(ver)
    gen.load_local_dll_folder(str(DUMMY))
    env.typetree_generator = gen
    found = {}
    errs = 0
    for name, go, obj in hits:
        try:
            nodes = gen.get_nodes_up("Assembly-CSharp", name)
            tree = obj.read_typetree(nodes)
        except Exception as exc:  # noqa: BLE001
            errs += 1
            if errs < 4:
                print("fail", name, type(exc).__name__, str(exc)[:160])
            continue
        found.setdefault(name, []).append({"gameobject": go, "values": slim(tree)})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(found, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", OUT, {k: len(v) for k, v in found.items()}, "errors", errs)


def _unused():
    found = {}
    env = None
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            mb = obj.read(check_read=False)
            script = mb.m_Script.read()
            name = script.m_ClassName
        except Exception:  # noqa: BLE001
            continue
        if name not in WANT:
            continue
        try:
            tree = obj.read_typetree()
        except Exception as exc:  # noqa: BLE001
            print("fail", name, str(exc)[:120])
            continue
        go = ""
        try:
            go = mb.m_GameObject.read().m_Name
        except Exception:  # noqa: BLE001
            pass
        found.setdefault(name, []).append({"gameobject": go, "values": slim(tree)})
        print("got", name, go)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(found, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", OUT, {k: len(v) for k, v in found.items()})


if __name__ == "__main__":
    main()
