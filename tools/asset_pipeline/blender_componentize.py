# -*- coding: utf-8 -*-
"""Blender headless: componentize a normalized formal GLB into named, pivoted parts.

Weaver mid models are one fused mesh, so parts are cut with planes (bisect + cap):
  - ground_cut: horizontal cut at ratio*height; loose pieces below become Leg_i / Tread_i
  - cuts: ordered list of {name, axis(x|y|z), ratio, keep(lt|gt), pivot(inner|center|bottom|top)}
          optional "mirror": true -> creates <name>_L (x<ratio) and <name>_R (x>1-ratio)
Front convention: Weaver main_view faces the camera -> Blender -Y is front (y ratio 0 = front).

Every part gets a role material, a baked cavity/height tint in vertex colors (COLOR_0),
and its origin moved to its pivot so Godot can rotate it naturally.
Hierarchy: RigRoot (empty) > Body > parts. Prints STATS_JSON.

Usage:
  blender --background --python blender_componentize.py -- <in.glb> <out.glb> <preview.png> '<spec json>'
"""
import json
import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_png, spec = argv[0], argv[1], argv[2], json.loads(argv[3])

ROLE_COLORS = {
    "body": spec.get("body_color", "#c8553d"),
    "leg": "#2b2b2e",
    "tread": "#2b2b2e",
    "tool": "#e3a52b",
    "wing": "#efe3c8",
    "shield": "#efe3c8",
    "ring": "#2f4b5c",
    "rotor": "#e3a52b",
    "top": "#2f4b5c",
}


def hex_rgb(h):
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (1, 3, 5))


def make_mat(role):
    name = f"Rig_{role}"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    c = hex_rgb(ROLE_COLORS.get(role, ROLE_COLORS["body"]))
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.7 if role in ("leg", "tread") else 0.6
    bsdf.inputs["Metallic"].default_value = 0.25 if role in ("tool", "ring", "rotor") else 0.08
    # multiply by vertex color so the exporter keeps COLOR_0 meaningful
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs[6].default_value = (*c, 1.0)
    nt.links.new(vc.outputs["Color"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    return m


def bounds(objs):
    xs, ys, zs = [], [], []
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def bisect_keep(obj, axis, value, keep):
    """Cut obj with a plane on axis=value, keep 'lt' or 'gt' side, cap the hole."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    n = Vector((1 if axis == "x" else 0, 1 if axis == "y" else 0, 1 if axis == "z" else 0))
    co = Vector((0, 0, 0))
    setattr(co, axis, value)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n,
                                 clear_inner=(keep == "gt"), clear_outer=(keep == "lt"))
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        try:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
        except Exception:
            pass
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(obj.data.vertices)


def duplicate(obj, name):
    d = obj.copy()
    d.data = obj.data.copy()
    d.name = name
    bpy.context.scene.collection.objects.link(d)
    return d


def set_origin(obj, point):
    offset = point - obj.location
    obj.data.transform(__import__("mathutils").Matrix.Translation(-offset))
    obj.location = point
    bpy.context.view_layer.update()


def pivot_point(obj, mode, body_center):
    lo, hi = bounds([obj])
    c = (lo + hi) / 2
    if mode == "top":
        return Vector((c.x, c.y, hi.z))
    if mode == "bottom":
        return Vector((c.x, c.y, lo.z))
    if mode == "inner":
        # the point of the part bbox closest to the body center (hinge side)
        p = Vector(c)
        for ax in "xy":
            if abs(getattr(hi, ax) - getattr(lo, ax)) > 1e-4:
                bc = getattr(body_center, ax)
                setattr(p, ax, getattr(lo, ax) if abs(getattr(lo, ax) - bc) < abs(getattr(hi, ax) - bc) else getattr(hi, ax))
        return p
    return c


def bake_tint(obj, ground_h):
    """Cavity + height darkening into a POINT color attribute 'Col'."""
    me = obj.data
    if "Col" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Col"])
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    vals = []
    for v in bm.verts:
        acc, n = 0.0, 0
        for e in v.link_edges:
            d = e.other_vert(v).co - v.co
            if d.length > 1e-7:
                acc += v.normal.dot(d.normalized())
                n += 1
        concave = acc / n if n else 0.0  # >0 concave crease
        vals.append(concave)
    srt = sorted(vals)
    hi = srt[int(len(srt) * 0.97)] if srt else 1.0
    lo = srt[int(len(srt) * 0.03)] if srt else -1.0
    wz = [(obj.matrix_world @ v.co).z for v in bm.verts]
    for i, v in enumerate(bm.verts):
        cav = max(0.0, vals[i]) / max(hi, 1e-4)
        edge = max(0.0, -vals[i]) / max(-lo, 1e-4)
        h = min(max(wz[i] / max(ground_h, 1e-4), 0.0), 1.0)
        k = (1.0 - 0.45 * min(cav, 1.0)) * (0.78 + 0.22 * h) * (1.0 + 0.12 * min(edge, 1.0))
        k = min(k, 1.15)
        attr.data[i].color = (k, k, k, 1.0)
    bm.free()


# ---------------------------------------------------------------- run
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != body:
        bpy.data.objects.remove(o, do_unlink=True)
body.name = "Body"
lo, hi = bounds([body])
size = hi - lo
height = size.z
_bm = bmesh.new()
_bm.from_mesh(body.data)
bmesh.ops.remove_doubles(_bm, verts=_bm.verts, dist=max(height * 0.0015, 1e-4))
total_verts = len(_bm.verts)
_bm.free()


def abs_value(axis, ratio):
    return getattr(lo, axis) + getattr(size, axis) * ratio


parts = []  # (obj, role)

# 1) ground cut -> legs / treads
gc = spec.get("ground_cut")
if gc:
    z0 = lo.z + height * gc
    lower = duplicate(body, "Lower")
    bisect_keep(lower, "z", z0, "lt")
    bisect_keep(body, "z", z0, "gt")
    bpy.ops.object.select_all(action="DESELECT")
    lower.select_set(True)
    bpy.context.view_layer.objects.active = lower
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # 贴图版 GLB 在 UV 接缝处顶点断开，先焊接再按连通块分离；UV 坐标保留在面角上不受影响
    bpy.ops.mesh.remove_doubles(threshold=max(height * 0.0015, 1e-4))
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = [o for o in bpy.context.selected_objects]
    min_leg = total_verts * spec.get("min_leg_share", 0.012)
    big = [p for p in pieces if len(p.data.vertices) >= min_leg]
    small = [p for p in pieces if p not in big]
    if small:
        # merge tiny fragments back into body instead of deleting (keeps silhouette closed)
        bpy.ops.object.select_all(action="DESELECT")
        for s in small:
            s.select_set(True)
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
        body = bpy.context.view_layer.objects.active
        body.name = "Body"
    body_c = (bounds([body])[0] + bounds([body])[1]) / 2
    for i, p in enumerate(sorted(big, key=lambda o: (bounds([o])[0].y, bounds([o])[0].x))):
        plo, phi = bounds([p])
        ext = phi - plo
        is_leg = ext.z > 0.55 * max(ext.x, ext.y) or len(big) >= 4
        role = "leg" if is_leg else "tread"
        p.name = f"{'Leg' if is_leg else 'Tread'}_{i}"
        set_origin(p, Vector(((plo.x + phi.x) / 2, (plo.y + phi.y) / 2, phi.z)) if is_leg else (plo + phi) / 2)
        parts.append((p, role))

# 2) ordered plane cuts on the body
for cut in spec.get("cuts", []):
    sides = []
    if cut.get("mirror"):
        sides = [(f"{cut['name']}_L", cut["ratio"], "lt"), (f"{cut['name']}_R", 1.0 - cut["ratio"], "gt")]
    else:
        sides = [(cut["name"], cut["ratio"], cut.get("keep", "lt"))]
    for name, ratio, keep in sides:
        value = abs_value(cut["axis"], ratio)
        part = duplicate(body, name)
        n_part = bisect_keep(part, cut["axis"], value, keep)
        if n_part < total_verts * 0.004:
            bpy.data.objects.remove(part, do_unlink=True)
            continue
        bisect_keep(body, cut["axis"], value, "gt" if keep == "lt" else "lt")
        body_c = (bounds([body])[0] + bounds([body])[1]) / 2
        set_origin(part, pivot_point(part, cut.get("pivot", "inner"), body_c))
        parts.append((part, cut.get("role", "tool")))

# 3) body pivot at ground center
blo, bhi = bounds([body])
set_origin(body, Vector(((blo.x + bhi.x) / 2, (blo.y + bhi.y) / 2, lo.z)))

# 4) materials + tint（源带贴图则保留原材质；纯色中模才上角色色 + 凹陷明暗）
all_objs = [(body, "body")] + parts
textured = any(img.size[0] > 0 for img in bpy.data.images if img.name not in ("Render Result", "Viewer Node"))
for o, role in all_objs:
    if not textured:
        o.data.materials.clear()
        o.data.materials.append(make_mat(role))
        bake_tint(o, height)
    for poly in o.data.polygons:
        poly.use_smooth = True

# 5) hierarchy (refresh depsgraph first: origin changes leave matrix_world stale)
bpy.context.view_layer.update()
root = bpy.data.objects.new("RigRoot", None)
bpy.context.scene.collection.objects.link(root)
body.parent = root
bpy.context.view_layer.update()
for o, _ in parts:
    o.parent = body
    o.matrix_parent_inverse = body.matrix_world.inverted()
bpy.context.view_layer.update()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=False,
                          export_yup=True, export_apply=False,
                          export_vertex_color="NONE" if textured else "ACTIVE",
                          export_all_vertex_colors=False, export_image_format="AUTO")

# 6) preview: color each part distinctly so segmentation can be reviewed (flat mode only)
palette = [(0.85, 0.25, 0.17), (0.17, 0.55, 0.85), (0.95, 0.75, 0.15), (0.3, 0.75, 0.35),
           (0.7, 0.3, 0.8), (0.95, 0.5, 0.2), (0.2, 0.8, 0.8), (0.9, 0.9, 0.85)]
for i, (o, _) in enumerate(all_objs):
    if textured:
        break
    pm = bpy.data.materials.new(f"Prev_{i}")
    pm.diffuse_color = (*palette[i % len(palette)], 1.0)
    o.data.materials.clear()
    o.data.materials.append(pm)
scene = bpy.context.scene
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
center = Vector((0, 0, height * 0.45))
dist = max(size) * 2.3
cam.location = center + Vector((0.9, -1.3, 0.85)).normalized() * dist
tgt = bpy.data.objects.new("T", None)
scene.collection.objects.link(tgt)
tgt.location = center
cam.constraints.new("TRACK_TO").target = tgt
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE" if textured else "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 480
scene.render.resolution_y = 400
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)

print("STATS_JSON " + json.dumps({
    "glb": out_glb, "parts": [o.name for o, _ in parts], "roles": [r for _, r in parts],
    "dims": [round(size.x, 3), round(size.y, 3), round(size.z, 3)]}, ensure_ascii=False))
