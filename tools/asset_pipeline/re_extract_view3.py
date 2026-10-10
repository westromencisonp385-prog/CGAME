# -*- coding: utf-8 -*-
"""Wanderburg: which objects carry Outline (Quick Outline) / Outlinable (EPO) and in which mode.
Outline.Mode: 0 OutlineAll, 1 OutlineVisible, 2 OutlineHidden, 3 OutlineAndSilhouette, 4 SilhouetteOnly.
Also: shadow-only / no-shadow renderers on trees & large props (how the original avoids big occluders),
and the ground shader's fixed-shadow material (research only)."""
import json
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

import UnityPy

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-view-occlusion-3.json"
MODES = {0: "OutlineAll", 1: "OutlineVisible", 2: "OutlineHidden", 3: "OutlineAndSilhouette", 4: "SilhouetteOnly"}


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    idx = {}
    by_type = defaultdict(list)
    for o in env.objects:
        idx[(o.assets_file.name, o.path_id)] = o
        by_type[o.type.name].append(o)
    names = {}

    def go_name(f, pid):
        k = (f, pid)
        if k not in names:
            o = idx.get(k)
            try:
                names[k] = o.read().m_Name if o else "?"
            except Exception:  # noqa: BLE001
                names[k] = "?"
        return names[k]

    def parent_path(f, gopid, depth=4):
        out = [go_name(f, gopid)]
        try:
            go = idx[(f, gopid)].read()
            tr = None
            for c in go.m_Components:
                r = c.read()
                if r.object_reader.type.name in ("Transform", "RectTransform"):
                    tr = r
                    break
            while tr is not None and len(out) < depth:
                fa = tr.m_Father
                if not fa.path_id:
                    break
                tr = fa.read()
                out.append(tr.m_GameObject.read().m_Name)
        except Exception:  # noqa: BLE001
            pass
        return "/".join(reversed(out))

    res = {"outline": [], "outline_modes": Counter(), "outlinable": [], "renderer_shadow_modes": {}}
    for o in by_type["MonoBehaviour"]:
        try:
            mb = o.read(check_read=False)
            cls = mb.m_Script.read().m_ClassName
        except Exception:  # noqa: BLE001
            continue
        if cls not in ("Outline", "Outlinable"):
            continue
        raw = o.get_raw_data()
        # header: m_GameObject(PPtr 12) m_Enabled(4 aligned) m_Script(PPtr 12) m_Name(string)
        try:
            off = 0
            gofid, gopid = struct.unpack_from("<iq", raw, off); off += 12
            enabled = struct.unpack_from("<B", raw, off)[0]; off += 4
            off += 12
            nlen = struct.unpack_from("<i", raw, off)[0]; off += 4 + nlen
            off = (off + 3) & ~3
        except Exception:  # noqa: BLE001
            continue
        where = parent_path(o.assets_file.name, gopid)
        if cls == "Outline":
            mode, r, g, b, a, width = struct.unpack_from("<i5f", raw, off)
            res["outline_modes"][MODES.get(mode, str(mode))] += 1
            res["outline"].append({"where": where, "mode": MODES.get(mode, mode), "color": [round(r, 2), round(g, 2), round(b, 2), round(a, 2)], "width": round(width, 2), "enabled": enabled})
        else:
            res["outlinable"].append({"where": where, "enabled": enabled, "raw_len": len(raw)})
    res["outline_modes"] = dict(res["outline_modes"])

    # renderer shadow casting modes on obvious occluders
    occl = ("tree", "TREE", "Tree", "rock", "ROCK", "Rock", "house", "HOUSE", "House", "castle", "CASTLE", "Castle", "tower", "TOWER", "wall", "WALL", "Wall", "palm", "PALM", "cliff", "CLIFF", "mountain", "MOUNTAIN")
    shadow = defaultdict(Counter)
    sample = 0
    for o in by_type["MeshRenderer"]:
        if sample > 60000:
            break
        sample += 1
        try:
            r = o.read()
            n = r.m_GameObject.read().m_Name
        except Exception:  # noqa: BLE001
            continue
        key = next((k.lower() for k in occl if k in n), None)
        if key is None:
            continue
        shadow[key][f"cast={r.m_CastShadows} recv={r.m_ReceiveShadows}"] += 1
    res["renderer_shadow_modes"] = {k: dict(v) for k, v in shadow.items()}
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    print("modes", res["outline_modes"])
    by = defaultdict(list)
    for e in res["outline"]:
        by[e["mode"]].append(e)
    for m, lst in by.items():
        print("==", m, len(lst))
        roots = Counter(x["where"].split("/")[0] + "/" + (x["where"].split("/")[1] if "/" in x["where"] else "") for x in lst)
        print("  roots", roots.most_common(12))
        for x in lst[:10]:
            print("  ", x["where"], x["color"], x["width"], "on" if x["enabled"] else "off")
    print("outlinable", len(res["outlinable"]), [x["where"] for x in res["outlinable"][:10]])
    print("shadow", json.dumps(res["renderer_shadow_modes"]))


if __name__ == "__main__":
    main()
