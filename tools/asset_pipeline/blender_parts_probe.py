# -*- coding: utf-8 -*-
"""Blender headless: report loose-part structure of each game GLB (for componentization planning).

Usage: blender --background --python blender_parts_probe.py -- <glb_dir> <out_json>
"""
import json
import sys
from pathlib import Path

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
glb_dir, out_json = Path(argv[0]), Path(argv[1])
report = {}
for glb in sorted(glb_dir.glob("*_formal.glb")):
    if glb.name.startswith(("a01_", "b01_", "c04_")):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    sizes = []
    for o in mesh_objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            stack, comp = [v], 0
            seen.add(v.index)
            while stack:
                cur = stack.pop()
                comp += 1
                for e in cur.link_edges:
                    nb = e.other_vert(cur)
                    if nb.index not in seen:
                        seen.add(nb.index)
                        stack.append(nb)
            sizes.append(comp)
        bm.free()
    sizes.sort(reverse=True)
    total = sum(sizes) or 1
    report[glb.name] = {
        "loose_parts": len(sizes),
        "parts_over_2pct": sum(1 for s in sizes if s / total > 0.02),
        "largest_share": round(sizes[0] / total, 3) if sizes else 0,
        "top5_share": [round(s / total, 3) for s in sizes[:5]],
    }
out_json.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print("PROBE_DONE", len(report))
