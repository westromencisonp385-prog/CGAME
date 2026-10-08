# Blender: inspect / assemble part GLBs into one rig GLB.
#   blender -b -P blender_assemble_parts.py -- <parts_dir> <out_glb> <out_png> <target_size> [inspect]
# Each <Part>.glb is imported as-is. If the part meshes already share one object space (Weaver
# keeps the source view's frame for segment-based generation), they line up without moves.
# Then: Y-up handled by glTF importer; normalize whole assembly to target size; ground at z=0;
# center xy; pivot of every part is placed at the point of its bbox nearest to the Body bbox
# center (the attachment side), so ProceduralRig rotations hinge at the joint.
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
parts_dir, out_glb, out_png, target = Path(argv[0]), argv[1], argv[2], float(argv[3])
inspect_only = len(argv) > 4 and argv[4] == "inspect"

bpy.ops.wm.read_factory_settings(use_empty=True)


def world_bounds(objs):
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


parts = {}
for glb in sorted(parts_dir.glob("*.glb")):
    if glb.stem in ("assembled",) or glb.stem.endswith("_rig"):
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    others = [o.name for o in new if o.type != "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = glb.stem
    for nm in others:
        if nm in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[nm], do_unlink=True)
    parts[glb.stem] = obj

report = {}
for n, o in parts.items():
    lo, hi = world_bounds([o])
    report[n] = {"lo": [round(v, 3) for v in lo], "hi": [round(v, 3) for v in hi], "size": [round(v, 3) for v in (hi - lo)]}
print("PARTS_BOUNDS", json.dumps(report, ensure_ascii=False))
if inspect_only:
    sys.exit(0)

# ---- place parts from the 2D split layout (front view: image x -> world X, image y(down) -> world -Z) ----
layout_path = parts_dir / "layout.json"
flip_x = False
import math
import numpy as np


def mesh_points(o):
    m = o.matrix_world
    return np.array([tuple(m @ v.co) for v in o.data.vertices])


def silhouette(pts_xz, n=64):
    lo = pts_xz.min(0); hi = pts_xz.max(0)
    span = np.maximum(hi - lo, 1e-6)
    g = np.zeros((n, n), bool)
    ij = ((pts_xz - lo) / span * (n - 1)).astype(int)
    # image row 0 = top -> world z max
    g[(n - 1) - ij[:, 1], ij[:, 0]] = True
    # close small holes from vertex sampling
    g2 = g.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            g2 |= np.roll(np.roll(g, dy, 0), dx, 1)
    return g2, span[0] / span[1]


def orient_part(o, sil_str, aspect_px):
    target = np.array([c == "1" for c in sil_str]).reshape(64, 64)
    pts = mesh_points(o)
    cen = pts.mean(0)
    best = None
    for yaw in (0, 90, 180, 270):
        for mirror in (False, True):
            a = math.radians(yaw)
            R = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
            p = (pts - cen) @ R.T
            if mirror:
                p[:, 0] *= -1
            g, asp = silhouette(p[:, [0, 2]])
            iou = (g & target).sum() / max((g | target).sum(), 1)
            score = iou - 0.35 * abs(math.log(max(asp, 1e-3) / max(aspect_px, 1e-3)))
            if best is None or score > best[0]:
                best = (score, yaw, mirror, iou)
    _s, yaw, mirror, iou = best
    o.rotation_euler = (0, 0, math.radians(yaw))
    if mirror:
        o.scale.x *= -1
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mirror:
        # negative scale flips normals; restore outward normals
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
    return {"yaw": yaw, "mirror": mirror, "iou": round(float(iou), 3)}


orient_report = {}
if layout_path.exists() and "Body" in parts:
    lay = json.loads(layout_path.read_text(encoding="utf-8"))["parts"]
    for n, o in parts.items():
        src = lay.get(n)
        if n.endswith(("_L", "_R")):
            twin = lay.get(n[:-1] + ("R" if n.endswith("_L") else "L"))
            if twin and (src is None or twin["px"] > src["px"] * 3):
                src = twin  # occluded side: use the visible twin's silhouette
        if src is None or "sil" not in src:
            continue
        orient_report[n] = orient_part(o, src["sil"], (src["x1"] - src["x0"]) / max(src["y1"] - src["y0"], 1))
    print("ORIENT", json.dumps(orient_report))
if layout_path.exists() and "Body" in parts:
    lay = json.loads(layout_path.read_text(encoding="utf-8"))["parts"]
    bl = lay["Body"]
    blo, bhi = world_bounds([parts["Body"]])
    k = (bhi.x - blo.x) / max(bl["x1"] - bl["x0"], 1)          # world units per pixel
    bcx_px, bcy_px = (bl["x0"] + bl["x1"]) / 2, (bl["y0"] + bl["y1"]) / 2
    bc = (blo + bhi) / 2
    depth = bhi.y - blo.y

    def fit_scale(name):
        l = lay.get(name)
        if name.endswith(("_L", "_R")):
            twin = lay.get(name[:-1] + ("R" if name.endswith("_L") else "L"))
            if twin and (l is None or twin["px"] > l["px"] * 3):
                l = twin
        if l is None:
            return None
        lo, hi = world_bounds([parts[name]])
        sz = hi - lo
        sx = k * (l["x1"] - l["x0"]) / max(sz.x, 1e-6)
        sz_ = k * (l["y1"] - l["y0"]) / max(sz.z, 1e-6)
        return (sx + sz_) / 2

    scales = {n: fit_scale(n) for n in parts if n != "Body"}
    # mirrored pairs: the far one is occluded in the front view -> reuse the larger scale
    for n in list(scales):
        if n.endswith("_L") or n.endswith("_R"):
            twin = n[:-1] + ("R" if n.endswith("_L") else "L")
            if twin in scales and scales[twin] and scales[n]:
                scales[n] = max(scales[n], scales[twin])
    for n, o in parts.items():
        if n == "Body" or not scales.get(n):
            continue
        s = scales[n]
        lo, hi = world_bounds([o])
        c = (lo + hi) / 2
        o.location = (o.location - c) * s
        o.scale = o.scale * s
        bpy.context.view_layer.update()
        src = lay.get(n)
        if n.endswith(("_L", "_R")):
            twin = lay.get(n[:-1] + ("R" if n.endswith("_L") else "L"))
            if twin and (src is None or twin["px"] > src["px"] * 3):
                src = twin
        cx_px, cy_px = (src["x0"] + src["x1"]) / 2, (src["y0"] + src["y1"]) / 2
        dx = (cx_px - bcx_px) * k
        dz = -(cy_px - bcy_px) * k
        dy = 0.0
        plo, phi = world_bounds([o])
        half_part = (phi.y - plo.y) / 2
        if n.endswith("_L"):
            dy = depth * 0.5 + half_part * 0.6
        elif n.endswith("_R"):
            dy = -(depth * 0.5 + half_part * 0.6)
        o.location += Vector((bc.x + dx, bc.y + dy, bc.z + dz))
        bpy.context.view_layer.update()

# merge BodyExtra_* into Body
body = parts.get("Body")
extras = [o for n, o in parts.items() if n.startswith("BodyExtra")]
if body is not None and extras:
    bpy.ops.object.select_all(action="DESELECT")
    for o in extras + [body]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Body"
    parts = {n: o for n, o in parts.items() if not n.startswith("BodyExtra")}
    parts["Body"] = body

# normalize whole assembly (longest horizontal or height -> target), ground & center
allo = list(parts.values())
lo, hi = world_bounds(allo)
size = hi - lo
scale = target / max(size.x, size.y, size.z)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in allo:
    o.location = (o.location - center) * scale
    o.scale = o.scale * scale
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# hierarchy RigRoot > Body > parts, pivots at joint side
root = bpy.data.objects.new("RigRoot", None)
bpy.context.scene.collection.objects.link(root)
body = parts["Body"]
blo, bhi = world_bounds([body])
bcenter = (blo + bhi) / 2


def set_origin(obj, point):
    cur = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = cur


set_origin(body, Vector((bcenter.x, bcenter.y, blo.z)))
body.parent = root
for n, o in parts.items():
    if n == "Body":
        continue
    plo, phi = world_bounds([o])
    # joint = point of part bbox closest to body center (clamped into part bbox)
    joint = Vector((min(max(bcenter.x, plo.x), phi.x), min(max(bcenter.y, plo.y), phi.y), min(max(bcenter.z, plo.z), phi.z)))
    if n.startswith(("Leg_", "Tread_")):
        joint.z = phi.z  # legs hinge at the hip (top)
    if n.startswith(("Rotor", "Drum", "Ring")):
        joint = (plo + phi) / 2  # spin around own center
    set_origin(o, joint)
    mw = o.matrix_world.copy()
    o.parent = body
    o.matrix_world = mw

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=False, export_yup=True,
                          export_apply=False, export_image_format="AUTO")

# preview
lo, hi = world_bounds(list(parts.values()))
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
c = (lo + hi) / 2; d = max(hi - lo) * 2.2
cam.location = c + Vector((d * 0.8, -d, d * 0.7))
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.rotation_euler = (0.8, 0.2, 0.6)
bpy.context.scene.collection.objects.link(sun)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 520; sc.render.resolution_y = 420
sc.render.film_transparent = True
sc.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("ASSEMBLE_JSON", json.dumps({"parts": sorted(n for n in parts if n != "Body"), "dims": [round(v, 3) for v in (hi - lo)]}))
