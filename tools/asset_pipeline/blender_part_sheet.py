# Blender: render each part GLB from front(-Y), side(+X), top(+Z) into a contact sheet row per part.
#   blender -b -P blender_part_sheet.py -- <parts_dir> <out_dir>
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
parts_dir, out_dir = Path(argv[0]), Path(argv[1])
out_dir.mkdir(parents=True, exist_ok=True)

for glb in sorted(parts_dir.glob("*.glb")):
    if glb.stem == "assembled":
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    c = (lo + hi) / 2
    d = max(hi - lo) * 2.6
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(hi - lo) * 1.3
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 300; sc.render.resolution_y = 300
    sc.render.film_transparent = True
    for tag, off in (("front", Vector((0, -d, 0))), ("side", Vector((d, 0, 0))), ("top", Vector((0, 0, d)))):
        cam.location = c + off
        up = "Y" if tag != "top" else "Y"
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Z" if tag != "top" else "Y").to_euler()
        sc.render.filepath = str(out_dir / f"{glb.stem}_{tag}.png")
        bpy.ops.render.render(write_still=True)
print("SHEET_DONE")
