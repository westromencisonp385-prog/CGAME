# -*- coding: utf-8 -*-
"""Second pass on Wanderburg view / occlusion (research evidence only).

  1. Camera rig transform chain (Main Camera -> parents): local rotation / position
  2. 'Outline' components (Quick Outline): mode / colour / width, and which objects carry them
  3. Volume profiles: DepthOfField / Bloom / Tonemapping / ColorAdjustments ... override values
  4. Material properties for FlatKit/Stylized Surface (player / enemy samples), Fog_Orthographic, DEFORMER tree/gras,
     Hidden/Obstacle users
Output: docs/research/wanderburg-view-occlusion-2.json
"""
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
DUMMY = Path(__file__).resolve().parents[3] / "wanderburg_re" / "il2cpp_dump" / "DummyDll"
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-view-occlusion-2.json"
WANT_MB = {"Outline", "Outlinable", "Volume", "CameraRig", "UniversalAdditionalCameraData", "DirectionalLightFader", "FadeBehavior", "Outliner"}


def euler(q):
    x, y, z, w = q["x"], q["y"], q["z"], q["w"]
    sinx = max(-1.0, min(1.0, 2 * (w * x - y * z)))
    return [round(math.degrees(math.asin(sinx)), 2),
            round(math.degrees(math.atan2(2 * (w * y + x * z), 1 - 2 * (x * x + y * y))), 2),
            round(math.degrees(math.atan2(2 * (w * z + x * y), 1 - 2 * (x * x + z * z))), 2)]


def r3(v):
    return [round(v["x"], 3), round(v["y"], 3), round(v["z"], 3)]


def slim(v, depth=0):
    if depth > 6:
        return "..."
    if isinstance(v, dict):
        if set(v.keys()) >= {"m_FileID", "m_PathID"}:
            return {"pptr": v["m_PathID"]} if v["m_PathID"] else None
        if "m_Curve" in v:
            return [[round(k.get("time", 0), 3), round(k.get("value", 0), 3)] for k in v["m_Curve"]][:10]
        out = {}
        for k, x in v.items():
            if k in ("m_GameObject", "m_Script", "m_EditorHideFlags", "m_EditorClassIdentifier"):
                continue
            s = slim(x, depth + 1)
            if s is not None and s != {} and s != []:
                out[k] = s
        return out
    if isinstance(v, list):
        if len(v) > 40:
            return f"<list {len(v)}>"
        return [slim(x, depth + 1) for x in v]
    if isinstance(v, float):
        return round(v, 4)
    return v


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    ver = next(iter(env.objects)).assets_file.unity_version
    gen = TypeTreeGenerator(ver)
    gen.load_local_dll_folder(str(DUMMY))
    env.typetree_generator = gen
    # index by (file, path_id)
    idx = {}
    by_type = defaultdict(list)
    for obj in env.objects:
        idx[(obj.assets_file.name, obj.path_id)] = obj
        by_type[obj.type.name].append(obj)
    go_tt = {}

    def go_name(file, pid):
        key = (file, pid)
        if key not in go_tt:
            o = idx.get(key)
            try:
                go_tt[key] = o.read_typetree() if o else {}
            except Exception:  # noqa: BLE001
                go_tt[key] = {}
        return go_tt[key].get("m_Name", "?")

    tr_tt = {}

    def transform_of_go(file, gopid):
        g = go_tt.get((file, gopid)) or {}
        if not g:
            go_name(file, gopid)
            g = go_tt.get((file, gopid)) or {}
        for c in g.get("m_Component", []):
            p = c.get("component", c)
            o = idx.get((file, p.get("m_PathID")))
            if o is not None and o.type.name in ("Transform", "RectTransform"):
                return o
        return None

    def chain(file, gopid):
        out = []
        t = transform_of_go(file, gopid)
        guard = 0
        while t is not None and guard < 12:
            guard += 1
            try:
                tt = t.read_typetree()
            except Exception:  # noqa: BLE001
                break
            out.append({"name": go_name(file, tt["m_GameObject"]["m_PathID"]), "local_pos": r3(tt["m_LocalPosition"]),
                        "local_rot_euler": euler(tt["m_LocalRotation"]), "local_scale": r3(tt["m_LocalScale"])})
            fp = tt.get("m_Father", {}).get("m_PathID", 0)
            t = idx.get((file, fp)) if fp else None
        return out

    def path_name(file, gopid):
        names = [x["name"] for x in chain(file, gopid)]
        return "/".join(reversed(names))

    res = {"cameras": [], "outline": {"modes": Counter(), "examples": []}, "volumes": [], "materials": {}, "camera_rig": []}

    # 1. cameras
    for o in by_type["Camera"]:
        try:
            tt = o.read_typetree()
        except Exception:  # noqa: BLE001
            continue
        gp = tt["m_GameObject"]["m_PathID"]
        res["cameras"].append({"name": go_name(o.assets_file.name, gp), "ortho": tt.get("orthographic"), "size": tt.get("orthographic size"),
                               "near": tt.get("near clip plane"), "far": tt.get("far clip plane"), "file": o.assets_file.name,
                               "chain_child_to_root": chain(o.assets_file.name, gp)})
    # 2/3. monobehaviours
    for o in by_type["MonoBehaviour"]:
        try:
            mb = o.read(check_read=False)
            cls = mb.m_Script.read().m_ClassName
        except Exception:  # noqa: BLE001
            continue
        if cls not in WANT_MB and not cls.endswith(("DepthOfField", "Bloom", "Tonemapping", "ColorAdjustments", "Vignette", "WhiteBalance", "SplitToning", "ShadowsMidtonesHighlights", "LiftGammaGain", "ChromaticAberration", "FilmGrain", "PaniniProjection", "LensDistortion", "MotionBlur", "ColorCurves", "ChannelMixer")):
            continue
        try:
            tt = o.read_typetree()
        except Exception as e:  # noqa: BLE001
            tt = {"_err": str(e)[:120]}
        gp = tt.get("m_GameObject", {}).get("m_PathID", 0) if isinstance(tt, dict) else 0
        where = path_name(o.assets_file.name, gp) if gp else getattr(mb, "m_Name", "")
        if cls == "Outline":
            mode = tt.get("outlineMode")
            res["outline"]["modes"][str(mode)] += 1
            if len(res["outline"]["examples"]) < 60:
                res["outline"]["examples"].append({"where": where, "mode": mode, "color": tt.get("outlineColor"), "width": tt.get("outlineWidth"), "precompute": tt.get("precomputeOutline")})
        elif cls in ("CameraRig", "UniversalAdditionalCameraData"):
            res["camera_rig"].append({"class": cls, "where": where, "values": slim(tt)})
        else:
            res["volumes"].append({"class": cls, "where": where, "name": getattr(mb, "m_Name", ""), "values": slim(tt)})
    res["outline"]["modes"] = dict(res["outline"]["modes"])

    # 4. materials
    shader_name = {}
    for o in by_type["Shader"]:
        try:
            tt = o.read_typetree()
            shader_name[(o.assets_file.name, o.path_id)] = tt.get("m_ParsedForm", {}).get("m_Name") or tt.get("m_Name")
        except Exception:  # noqa: BLE001
            pass
    want_sh = ("FlatKit/Stylized Surface", "Shader Graphs/Fog_Orthographic", "Shader Graphs/DEFORMER", "Hidden/Obstacle", "Shader Graphs/GROUND SHADER GRAPH 9")
    pick_names = ("PLAYER", "Player", "VEHICLE", "Vehicle", "ENEMY", "Enemy", "TANK", "Tank", "CASTLE", "TREE", "Tree", "nolight", "Fog", "DEFORM", "tree", "gras")
    for o in by_type["Material"]:
        try:
            tt = o.read_typetree()
            sp = tt["m_Shader"]["m_PathID"]
            fid = tt["m_Shader"]["m_FileID"]
        except Exception:  # noqa: BLE001
            continue
        sname = shader_name.get((o.assets_file.name, sp))
        if sname is None:
            for (f, p), n in shader_name.items():
                if p == sp:
                    sname = n
                    break
        if not sname or not sname.startswith(want_sh):
            continue
        name = tt.get("m_Name", "")
        bucket = res["materials"].setdefault(sname, [])
        if len(bucket) >= 6 and not any(k in name for k in pick_names):
            continue
        if len(bucket) >= 14:
            continue
        props = tt.get("m_SavedProperties", {})
        floats = {k: round(v, 4) for k, v in (props.get("m_Floats") or []) if not k.startswith("_Queue")}
        colors = {k: [round(c[x], 3) for x in ("r", "g", "b", "a")] for k, c in (props.get("m_Colors") or [])}
        tex = [k for k, t in (props.get("m_TexEnvs") or []) if t.get("m_Texture", {}).get("m_PathID")]
        bucket.append({"name": name, "keywords": tt.get("m_ValidKeywords") or tt.get("m_ShaderKeywords"), "queue": tt.get("m_CustomRenderQueue"),
                       "floats": floats, "colors": colors, "textures": tex})
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
    print("wrote", OUT)
    for c in res["cameras"]:
        print("CAM", c["name"], c["ortho"], c["size"], c["near"], c["far"], c["chain_child_to_root"][:4])
    print("OUTLINE", res["outline"]["modes"])


if __name__ == "__main__":
    main()
