# Blender: joint parts FBX (one mesh per component, shared frame) + textured whole GLB -> rig GLB.
#   blender -b -P blender_joint_rig.py -- <joint.fbx> <textured.glb|-> <map.json> <out_glb> <out_png> <target>
#
# map.json: {"机身躯干": "Body", "左翅膀": "Wing_L", ...}  (component name -> ProceduralRig node name)
# Texturing: textured.glb is the Weaver node_type=8 result of THE SAME joint fbx (merged), so its vertices
# coincide with the joint parts. We transfer UVs + material per part via nearest-face data transfer.
import json
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
joint_fbx, tex_glb, map_json, out_glb, out_png, target = argv[0], argv[1], argv[2], argv[3], argv[4], float(argv[5])
name_map = json.load(open(map_json, encoding="utf-8"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=joint_fbx)
parts = {}
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    o.parent = None
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    key = name_map.get(o.name) or name_map.get(o.name.split(".")[0])
    if key is None:
        key = "Body"
    if key in parts:
        # merge duplicates of the same role (e.g. extra body pieces)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); parts[key].select_set(True)
        bpy.context.view_layer.objects.active = parts[key]
        bpy.ops.object.join()
        continue
    o.name = key
    parts[key] = o

textured = False
SPLIT_RULES = {"WingsAll": "Wing", "RingsAll": "Ring", "ShieldsAll": "Shield", "LegsAll": "Leg"}


def _bounds(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in objs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


def _split_loose(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.mesh.separate(type="LOOSE")
    return [o for o in bpy.context.selected_objects if o.type == "MESH"]


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    return j


def split_combined(parts: dict) -> dict:
    body = parts.get("Body")
    if body is None:
        return parts
    blo, bhi = _bounds([body])
    bc0 = (blo + bhi) / 2
    # side axis = body's shorter horizontal axis (machines are longer front-to-back)
    side_axis0 = 0 if (bhi.x - blo.x) < (bhi.y - blo.y) else 1
    for key, base in SPLIT_RULES.items():
        bc = bc0.copy()
        side_axis = side_axis0
        ob = parts.pop(key, None)
        if ob is None:
            continue
        pieces = _split_loose(ob)
        total = sum(len(p.data.vertices) for p in pieces)
        small = [p for p in pieces if len(p.data.vertices) < total * 0.02]
        big = [p for p in pieces if p not in small]
        def centre(p):
            a, b = _bounds([p]); return (a + b) / 2
        # fold debris into the nearest big piece
        for s in small:
            if big:
                tgt = min(big, key=lambda b: (centre(b) - centre(s)).length)
                big[big.index(tgt)] = _join([tgt, s], tgt.name)
        if base == "Leg":
            groups = {}
            for p in big:
                c = centre(p)
                side = "L" if c[side_axis] >= bc[side_axis] else "R"
                groups.setdefault(side, []).append(p)
            idx = 0
            for side in ("L", "R"):
                g = sorted(groups.get(side, []), key=lambda p: centre(p)[1 - side_axis])
                # cap: at most 3 legs per side; merge neighbours if more
                while len(g) > 3:
                    a = min(range(len(g) - 1), key=lambda i: (centre(g[i]) - centre(g[i + 1])).length)
                    g[a] = _join([g[a], g.pop(a + 1)], g[a].name)
                for p in g:
                    p.name = f"Leg_{idx}"
                    parts[p.name] = p
                    idx += 1
            if idx == 0:
                pass
        else:
            plo_, phi_ = _bounds(big) if big else (blo, bhi)
            span = phi_ - plo_
            pax = 0 if span.x >= span.y else 1
            mid = ((plo_ + phi_) / 2)[pax]
            left = [p for p in big if centre(p)[pax] >= mid]
            right = [p for p in big if p not in left]
            side_axis = pax
            bc = Vector(bc)
            bc[pax] = mid
            if left and right:
                parts[f"{base}_L"] = _join(left, f"{base}_L")
                parts[f"{base}_R"] = _join(right, f"{base}_R")
            elif big:
                # single connected piece spanning both sides: cut at the body mid plane
                one = _join(big, f"{base}_L")
                bpy.ops.object.select_all(action="DESELECT")
                one.select_set(True)
                bpy.context.view_layer.objects.active = one
                bpy.ops.object.mode_set(mode="EDIT")
                bpy.ops.mesh.select_all(action="SELECT")
                no = (1, 0, 0) if side_axis == 0 else (0, 1, 0)
                bpy.ops.mesh.bisect(plane_co=bc, plane_no=no, use_fill=False)
                bpy.ops.mesh.select_all(action="DESELECT")
                bpy.ops.object.mode_set(mode="OBJECT")
                halves = _split_loose(one)
                l2 = [p for p in halves if centre(p)[side_axis] >= bc[side_axis]]
                r2 = [p for p in halves if p not in l2]
                if l2:
                    parts[f"{base}_L"] = _join(l2, f"{base}_L")
                if r2:
                    parts[f"{base}_R"] = _join(r2, f"{base}_R")
    return parts
if tex_glb != "-":
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=tex_glb)
    tex_objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in tex_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tex_objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(tex_objs) > 1:
        bpy.ops.object.join()
    src = bpy.context.view_layer.objects.active
    # align src onto parts by bbox (texture pass may re-normalize the mesh)
    def bounds(objs):
        lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
        for ob in objs:
            for c in ob.bound_box:
                w = ob.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        return lo, hi
    plo, phi = bounds(parts.values())
    slo, shi = bounds([src])
    best = None
    import math
    for yaw in (0, 90, 180, 270):
        src.rotation_euler = (0, 0, math.radians(yaw))
        bpy.context.view_layer.update()
        a, b = bounds([src])
        err = sum(abs((b - a)[i] / max((b - a).length, 1e-6) - (phi - plo)[i] / max((phi - plo).length, 1e-6)) for i in range(3))
        if best is None or err < best[0]:
            best = (err, yaw)
    src.rotation_euler = (0, 0, math.radians(best[1]))
    bpy.context.view_layer.update()
    a, b = bounds([src])
    s = (phi - plo).length / max((b - a).length, 1e-6)
    src.scale = (s, s, s)
    bpy.context.view_layer.update()
    a, b = bounds([src])
    src.location += ((plo + phi) / 2 - (a + b) / 2)
    bpy.context.view_layer.update()
    mat = src.data.materials[0] if src.data.materials else None
    for o in parts.values():
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
        m = o.modifiers.new("uvt", "DATA_TRANSFER")
        m.object = src
        m.use_loop_data = True
        m.data_types_loops = {"UV"}
        m.loop_mapping = "POLYINTERP_NEAREST"
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="uvt")
        o.data.materials.clear()
        if mat is not None:
            o.data.materials.append(mat)
    bpy.data.objects.remove(src, do_unlink=True)
    textured = mat is not None

for o in parts.values():
    for p in o.data.polygons:
        p.use_smooth = True
parts = split_combined(parts)


def bounds(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in objs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


lo, hi = bounds(parts.values())
sc = target / max(hi - lo)
cen = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in parts.values():
    o.location = (o.location - cen) * sc
    o.scale = o.scale * sc
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

root = bpy.data.objects.new("RigRoot", None)
bpy.context.scene.collection.objects.link(root)
body = parts.get("Body") or max(parts.values(), key=lambda ob: len(ob.data.vertices))
blo, bhi = bounds([body])
bc = (blo + bhi) / 2


def set_origin(ob, point):
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


set_origin(body, Vector((bc.x, bc.y, blo.z)))
body.parent = root
for n, ob in parts.items():
    if ob is body:
        continue
    a, b = bounds([ob])
    joint = Vector((min(max(bc.x, a.x), b.x), min(max(bc.y, a.y), b.y), min(max(bc.z, a.z), b.z)))
    if n.startswith(("Leg_", "Tread_")):
        joint.z = b.z
    if n.startswith(("Rotor", "Drum", "Ring")):
        joint = (a + b) / 2
    set_origin(ob, joint)
    mw = ob.matrix_world.copy()
    ob.parent = body
    ob.matrix_world = mw

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=False, export_yup=True,
                          export_apply=False, export_image_format="AUTO")

lo, hi = bounds(parts.values())
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.scene.collection.objects.link(cam)
c = (lo + hi) / 2
d = max(hi - lo) * 2.3
cam.location = c + Vector((d * 0.75, -d, d * 0.6))
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
scn = bpy.context.scene
scn.render.engine = "BLENDER_WORKBENCH"
scn.display.shading.light = "STUDIO"
scn.display.shading.color_type = "TEXTURE" if textured else "RANDOM"
scn.render.resolution_x = 560
scn.render.resolution_y = 460
scn.render.film_transparent = True
scn.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("JOINT_RIG", json.dumps({"parts": sorted(parts), "textured": textured, "dims": [round(v, 3) for v in (hi - lo)]}, ensure_ascii=False))
