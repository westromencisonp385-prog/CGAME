# -*- coding: utf-8 -*-
"""Blender headless: Weaver mid FBX -> normalized game GLB.

- 合并为单 mesh 根，原点放在底面中心（脚底落地 y=0）
- 按目标最大边长缩放（米），对齐游戏内尺度
- 中模无材质：按槽位赋工业民俗六色板 PBR 材质（贴图任务完成后由 Godot 侧覆盖）
- 导出 glTF binary（+Y up, Godot 直读），渲染预览，打印 STATS_JSON

Usage:
  blender.exe --background --python blender_to_game_glb.py -- <in.fbx> <out.glb> <out_preview.png> <target_size_m> <palette_key>
"""
import json
import sys

import bmesh  # noqa: F401
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_png, target_size, palette_key = argv[0], argv[1], argv[2], float(argv[3]), argv[4]
keep_materials = len(argv) > 5 and argv[5] == "keep"

# 风格锁六色板（style-lock-industrial-folk-v1）
PALETTES = {
    "enemy": ("#c8553d", 0.62, 0.15),   # tomato red
    "boss": ("#8c4b59", 0.58, 0.25),    # deep lilac-red
    "player": ("#2f4b5c", 0.6, 0.2),    # petrol blue
    "module": ("#d9a441", 0.55, 0.3),   # ochre
    "world": ("#e9dcc0", 0.75, 0.05),   # bone cream
}

bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("no mesh")
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# 清理非 mesh 物体（空节点/骨骼残留）
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)

# 归一化：Blender 坐标 Z-up。底面中心移到原点，最大边缩放到 target_size
xs = [v.co.x for v in obj.data.vertices]
ys = [v.co.y for v in obj.data.vertices]
zs = [v.co.z for v in obj.data.vertices]
dims = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
scale = target_size / max(max(dims), 1e-6)
offset = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)))
for v in obj.data.vertices:
    v.co = (v.co - offset) * scale
obj.data.update()
bpy.ops.object.shade_smooth()
obj.name = "FormalMesh"

# 材质（贴图版保留 Weaver 输出的 PBR 材质）
color_hex, rough, metal = PALETTES.get(palette_key, PALETTES["world"])
if not keep_materials:
    c = tuple(int(color_hex[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    mat = bpy.data.materials.new(f"Formal_{palette_key}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    obj.data.materials.clear()
    obj.data.materials.append(mat)

bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=False, export_apply=True, export_yup=True)

# 预览
scene = bpy.context.scene
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
center = Vector((0, 0, target_size * dims[2] / max(dims) * 0.5))
cam.location = center + Vector((1.0, -1.2, 0.8)).normalized() * (target_size * 2.4)
tgt = bpy.data.objects.new("T", None)
scene.collection.objects.link(tgt)
tgt.location = center
tc = cam.constraints.new("TRACK_TO")
tc.target = tgt
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 640
scene.render.resolution_y = 480
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)

tris = sum(max(len(p.vertices) - 2, 0) for p in obj.data.polygons)
print("STATS_JSON " + json.dumps({
    "src": src, "glb": out_glb, "tris": tris, "verts": len(obj.data.vertices),
    "src_dims": [round(d, 3) for d in dims], "scale": round(scale, 4),
    "final_dims_m": [round(d * scale, 3) for d in dims], "palette": palette_key}, ensure_ascii=False))
