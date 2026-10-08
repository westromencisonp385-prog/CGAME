# -*- coding: utf-8 -*-
"""Blender headless verification: import model, print stats JSON, render preview.

Usage:
  blender.exe --background --python blender_verify.py -- <model_file> <out_png>
"""
import json
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
model_path, out_png = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
if model_path.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=model_path)
elif model_path.lower().endswith((".glb", ".gltf")):
    bpy.ops.import_scene.gltf(filepath=model_path)
else:
    raise SystemExit(f"unsupported: {model_path}")

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
verts = sum(len(m.data.vertices) for m in meshes)
polys = sum(len(m.data.polygons) for m in meshes)
tris = sum(max(len(p.vertices) - 2, 0) for m in meshes for p in m.data.polygons)
mats = sorted({m.name for o in meshes for m in o.data.materials if m})
imgs = sorted({i.name for i in bpy.data.images if i.name not in ("Render Result", "Viewer Node")})

xs, ys, zs = [], [], []
for o in meshes:
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        xs.append(w.x); ys.append(w.y); zs.append(w.z)
dim = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
center = Vector((sum(xs) / len(xs), sum(ys) / len(ys), sum(zs) / len(zs)))

scene = bpy.context.scene
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
dist = max(dim) * 2.2 + 1.0
cam.location = center + Vector((1.0, -1.2, 0.55)).normalized() * dist
track = cam.constraints.new("TRACK_TO")
empty = bpy.data.objects.new("Target", None)
scene.collection.objects.link(empty)
empty.location = center
track.target = empty
scene.camera = cam

sun_data = bpy.data.lights.new("Sun", type="SUN")
sun_data.energy = 3.0
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (0.7, 0.2, 0.9)

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 960
scene.render.filepath = out_png
scene.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)

print("STATS_JSON " + json.dumps({
    "model": model_path, "meshes": len(meshes), "verts": verts, "polys": polys, "tris": tris,
    "materials": mats, "images": imgs, "dims_xyz_m": [round(d, 3) for d in dim],
    "render": out_png}, ensure_ascii=False))
