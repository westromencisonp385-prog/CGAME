# -*- coding: utf-8 -*-
"""Read Wanderburg's camera / view / occlusion setup out of data.unity3d (research evidence only).

Dumps:
  1. CAMERA_RIG hierarchy: every Transform (local pos / rot as euler) + every Camera component
  2. All URP renderer data / renderer features (render objects, see-through, outline passes...)
  3. All Shader names (to spot dither / fade / silhouette / occlusion shaders)
  4. Materials grouped by shader (which content uses which shader)
  5. MonoBehaviours whose class names hint at occlusion handling
Output: docs/research/wanderburg-view-occlusion.json
"""
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import UnityPy

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-view-occlusion.json"
HINTS = ("occlu", "fade", "seethrough", "see_through", "xray", "silhou", "dither", "obstruct", "cutout",
         "transparen", "hide", "behind", "reveal", "outline", "camera", "renderfeature", "rendererfeature",
         "renderobjects", "universalrenderer", "sorting", "depth")


def euler(q):
    x, y, z, w = q["x"], q["y"], q["z"], q["w"]
    # Unity ZXY order -> degrees
    sinx = 2 * (w * x - y * z)
    sinx = max(-1.0, min(1.0, sinx))
    ex = math.degrees(math.asin(sinx))
    ey = math.degrees(math.atan2(2 * (w * y + x * z), 1 - 2 * (x * x + y * y)))
    ez = math.degrees(math.atan2(2 * (w * z + x * y), 1 - 2 * (x * x + z * z)))
    return [round(ex, 2), round(ey, 2), round(ez, 2)]


def v3(v):
    return [round(v["x"], 3), round(v["y"], 3), round(v["z"], 3)]


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    for extra in GAME.glob("*.assets"):
        try:
            env.load_file(str(extra))
        except Exception:  # noqa: BLE001
            pass
    by_type = defaultdict(list)
    for obj in env.objects:
        by_type[obj.type.name].append(obj)
    print({k: len(v) for k, v in by_type.items() if k in ("GameObject", "Camera", "Shader", "Material", "MonoBehaviour", "Transform")})
    out = {"cameras": [], "camera_rig": [], "shaders": [], "materials_by_shader": {}, "hint_behaviours": defaultdict(int), "renderer_assets": []}

    # ---- cameras
    for obj in by_type["Camera"]:
        try:
            cam = obj.read_typetree()
        except Exception as e:  # noqa: BLE001
            print("cam err", e)
            continue
        go_name = ""
        chain = []
        try:
            go = obj.read().m_GameObject.read()
            go_name = go.m_Name
            tr = None
            for c in go.m_Component:
                comp = c.component.read() if hasattr(c, "component") else c.read()
                if comp.object_reader.type.name == "Transform":
                    tr = comp
            while tr is not None:
                tgo = tr.m_GameObject.read()
                chain.append({"name": tgo.m_Name, "local_pos": v3(tr.m_LocalPosition.__dict__ if hasattr(tr.m_LocalPosition, "__dict__") else tr.m_LocalPosition),
                              "local_rot_euler": euler(tr.m_LocalRotation.__dict__ if hasattr(tr.m_LocalRotation, "__dict__") else tr.m_LocalRotation),
                              "local_scale": v3(tr.m_LocalScale.__dict__ if hasattr(tr.m_LocalScale, "__dict__") else tr.m_LocalScale)})
                try:
                    tr = tr.m_Father.read() if tr.m_Father.path_id else None
                except Exception:  # noqa: BLE001
                    tr = None
        except Exception as e:  # noqa: BLE001
            print("chain err", e)
        keep = {k: cam[k] for k in ("orthographic", "orthographic size", "field of view", "near clip plane", "far clip plane", "m_Depth", "m_ClearFlags", "m_projectionMatrixMode", "m_FocalLength", "m_SensorSize", "m_LensShift", "m_GateFitMode", "m_TargetEye", "m_AllowMSAA", "m_ForceIntoRT", "m_AllowDynamicResolution") if k in cam}
        keep["culling_mask"] = cam.get("m_CullingMask", {}).get("m_Bits")
        out["cameras"].append({"gameobject": go_name, "camera": keep, "hierarchy_child_to_root": chain, "file": obj.assets_file.name})
        print("CAM", go_name, keep, chain[:4])

    # ---- shaders
    for obj in by_type["Shader"]:
        try:
            tt = obj.read_typetree()
            name = tt.get("m_ParsedForm", {}).get("m_Name") or tt.get("m_Name")
        except Exception:  # noqa: BLE001
            continue
        out["shaders"].append(name)
    out["shaders"] = sorted(set(out["shaders"]))
    print("shaders", len(out["shaders"]))

    # ---- materials grouped by shader
    shader_names = {}
    for obj in by_type["Shader"]:
        try:
            tt = obj.read_typetree()
            shader_names[(obj.assets_file.name, obj.path_id)] = tt.get("m_ParsedForm", {}).get("m_Name") or tt.get("m_Name")
        except Exception:  # noqa: BLE001
            pass
    mats = defaultdict(list)
    for obj in by_type["Material"]:
        try:
            m = obj.read()
            sh = m.m_Shader.read()
            sname = shader_names.get((sh.assets_file.name, sh.object_reader.path_id)) or getattr(sh, "m_Name", "?")
            tt = obj.read_typetree()
            kw = tt.get("m_ValidKeywords") or tt.get("m_ShaderKeywords") or ""
            mats[sname].append({"name": m.m_Name, "keywords": kw if isinstance(kw, list) else str(kw).split(), "render_queue": tt.get("m_CustomRenderQueue"), "tags": tt.get("stringTagMap")})
        except Exception:  # noqa: BLE001
            continue
    out["materials_by_shader"] = {k: {"count": len(v), "examples": v[:12]} for k, v in sorted(mats.items(), key=lambda kv: -len(kv[1]))}

    # ---- monobehaviours: class names hinting at occlusion / render features
    for obj in by_type["MonoBehaviour"]:
        try:
            mb = obj.read(check_read=False)
            cls = mb.m_Script.read().m_ClassName
        except Exception:  # noqa: BLE001
            continue
        low = cls.lower()
        if any(h in low for h in HINTS):
            out["hint_behaviours"][cls] += 1
        if low in ("universalrendererdata", "universalrenderpipelineasset", "renderobjects", "forwardrendererdata") or "feature" in low or "renderer2d" in low:
            entry = {"class": cls, "name": getattr(mb, "m_Name", "")}
            try:
                tt = obj.read_typetree()
                entry["fields"] = {k: tt[k] for k in tt if not isinstance(tt[k], (list, dict)) or k in ("settings", "m_RendererFeatures", "m_OpaqueLayerMask", "m_TransparentLayerMask", "filterSettings", "overrideMaterial", "depthCompareFunction", "enableWrite", "stencilSettings")}
            except Exception as e:  # noqa: BLE001
                entry["err"] = str(e)[:200]
            out["renderer_assets"].append(entry)
    out["hint_behaviours"] = dict(sorted(out["hint_behaviours"].items(), key=lambda kv: -kv[1]))

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
