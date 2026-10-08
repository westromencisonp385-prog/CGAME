# Blender: register separately-generated part meshes onto a whole-asset reference mesh, then export a rig GLB.
#   blender -b -P blender_register_parts.py -- <asset_dir> <out_glb> <out_png> <target_size>
#
# <asset_dir>/parts/<Part>.glb      separately generated parts (Weaver segment_model_id + component_label)
# <asset_dir>/parts/labels_512.npy  2D split label map of the 360 main view
# <asset_dir>/parts/layout.json     {"mapping": {Part: label}}
# <asset_dir>/weaver/tex/*.glb      whole-asset model, used ONLY as a placement reference (never cut, never exported)
#
# Steps:
#  1. reference: try 8 front-view candidates (yaw x mirror); pick the one whose projected silhouette best matches
#     the union of all labels. Rotate the reference into that frame: image x -> +X, image up -> +Z, view dir +Y.
#  2. each part's target region = reference vertices whose projection lands in that part's labels.
#     Mirrored pairs whose far side is hidden: target = visible twin's region mirrored across the body's mid plane.
#  3. fit each part: 24 axis rotations, scale from extents, translation from centroids; score = symmetric
#     chamfer (KD-tree); refine best with a few ICP steps (scale+translation).
#  4. drop reference; normalize, set pivots at joints, hierarchy RigRoot > Body > parts; export.
import json
import math
import sys
from itertools import permutations, product
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:]
asset_dir, out_glb, out_png, target_size = Path(argv[0]), argv[1], argv[2], float(argv[3])
parts_dir = asset_dir / "parts"
bpy.ops.wm.read_factory_settings(use_empty=True)


def import_joined(path: Path, name: str):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
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
    obj.name = name
    for nm in others:
        if nm in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[nm], do_unlink=True)
    return obj


def verts(o) -> np.ndarray:
    n = len(o.data.vertices)
    a = np.empty(n * 3)
    o.data.vertices.foreach_get("co", a)
    a = a.reshape(n, 3)
    m = np.array(o.matrix_world)
    return a @ m[:3, :3].T + m[:3, 3]


def apply_matrix(o, M: np.ndarray):
    o.matrix_world = Matrix(M.tolist()) @ o.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def sil_grid(xz: np.ndarray, n: int):
    lo, hi = xz.min(0), xz.max(0)
    span = np.maximum(hi - lo, 1e-9)
    ij = ((xz - lo) / span * (n - 1)).astype(int)
    g = np.zeros((n, n), bool)
    g[(n - 1) - ij[:, 1], ij[:, 0]] = True
    g2 = g.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            g2 |= np.roll(np.roll(g, dy, 0), dx, 1)
    return g2


labels = np.load(parts_dir / "labels_512.npy")
layout = json.loads((parts_dir / "layout.json").read_text(encoding="utf-8"))
mapping = {k: v for k, v in layout["mapping"].items() if k != "_extra_body"}
extra = layout["mapping"].get("_extra_body", [])
union = labels > 0
ys, xs = np.nonzero(union)
uy0, uy1, ux0, ux1 = ys.min(), ys.max(), xs.min(), xs.max()
ucrop = union[uy0:uy1 + 1, ux0:ux1 + 1]
N = 96
uimg = np.array([[ucrop[int(r * (ucrop.shape[0] - 1) / (N - 1)), int(c * (ucrop.shape[1] - 1) / (N - 1))] for c in range(N)] for r in range(N)])
u_aspect = (ux1 - ux0) / max(uy1 - uy0, 1)

# ---------- 1. reference frame ----------
ref_path = sorted((asset_dir / "weaver" / "tex").glob("*.glb"))[0]
ref = import_joined(ref_path, "Reference")
P = verts(ref)
P -= P.mean(0)
best = None
for yaw in (0, 90, 180, 270):
    for mirror in (False, True):
        Q = P @ rot_z(yaw).T
        if mirror:
            Q[:, 0] *= -1
        g = sil_grid(Q[:, [0, 2]], N)
        iou = (g & uimg).sum() / max((g | uimg).sum(), 1)
        span = Q.max(0) - Q.min(0)
        score = iou - 0.5 * abs(math.log(max(span[0] / span[2], 1e-3) / u_aspect))
        if best is None or score > best[0]:
            best = (score, yaw, mirror, iou)
_s, yaw, mirror, ref_iou = best
R = rot_z(yaw)
if mirror:
    R = np.diag([-1, 1, 1]) @ R
P = P @ R.T
print("REF_FRAME", json.dumps({"yaw": yaw, "mirror": mirror, "iou": round(float(ref_iou), 3)}))
# pixel -> world on the XZ plane
plo, phi = P.min(0), P.max(0)
kx = (phi[0] - plo[0]) / max(ux1 - ux0, 1)
kz = (phi[2] - plo[2]) / max(uy1 - uy0, 1)
px = np.clip(((P[:, 0] - plo[0]) / kx + ux0).astype(int), 0, 511)
py = np.clip((uy1 - (P[:, 2] - plo[2]) / kz).astype(int), 0, 511)
vlab = labels[py, px]
body_mid_y = float(np.median(P[:, 1]))


def target_of(part: str):
    lab = mapping[part]
    labs = lab if isinstance(lab, list) else [lab]
    if part == "Body":
        labs = labs + list(extra)
    T = P[np.isin(vlab, labs)]
    if part.endswith(("_L", "_R")):
        twin = part[:-1] + ("R" if part.endswith("_L") else "L")
        if twin in mapping:
            T2 = P[np.isin(vlab, [mapping[twin]])]
            if len(T2) > 3 * max(len(T), 1):
                # this side is hidden: mirror the twin across the body mid plane, then keep the near/far split
                T = T2.copy()
                T[:, 1] = 2 * body_mid_y - T[:, 1]
    # depth disambiguation for pairs: keep the half on the expected side
    if part.endswith("_L"):
        T = T[T[:, 1] >= body_mid_y] if (T[:, 1] >= body_mid_y).sum() > 30 else T
    elif part.endswith("_R"):
        T = T[T[:, 1] <= body_mid_y] if (T[:, 1] <= body_mid_y).sum() > 30 else T
    return T


# ---------- 2/3. fit parts ----------
ROTS = []
for perm in permutations(range(3)):
    for signs in product((1, -1), repeat=3):
        M = np.zeros((3, 3))
        for i, j in enumerate(perm):
            M[i, j] = signs[i]
        if abs(np.linalg.det(M) - 1) < 1e-6:
            ROTS.append(M)


def kd(points):
    t = KDTree(len(points))
    for i, p in enumerate(points):
        t.insert(p, i)
    t.balance()
    return t


def sample(a, n):
    if len(a) <= n:
        return a
    return a[np.random.default_rng(0).choice(len(a), n, replace=False)]


def chamfer(A, tB, B, tA):
    d1 = np.mean([tB.find(p)[2] for p in A])
    d2 = np.mean([tA.find(p)[2] for p in B])
    return d1 + d2


fit_report = {}
part_objs = {}
for glb in sorted(parts_dir.glob("*.glb")):
    name = glb.stem
    if name in ("assembled",) or name.startswith("BodyExtra") and name not in mapping:
        pass
    if name not in mapping and not name.startswith("BodyExtra"):
        continue
    part_objs[name] = import_joined(glb, name)

for name, o in part_objs.items():
    key = "Body" if name.startswith("BodyExtra") else name
    T = target_of(key) if not name.startswith("BodyExtra") else P[np.isin(vlab, [int(name.split("_")[1])])]
    if len(T) < 20:
        fit_report[name] = {"error": "empty target", "n": int(len(T))}
        continue
    Ts = sample(T, 700)
    tT = kd(Ts)
    V = verts(o)
    Vc = V - V.mean(0)
    Vs = sample(Vc, 700)
    t_ext = Ts.max(0) - Ts.min(0)

    def bbox_fit(M):
        Vr = Vs @ M.T
        ext = Vr.max(0) - Vr.min(0)
        s = float(np.median((t_ext / np.maximum(ext, 1e-6))[[0, 2]]))
        cen_t = (Ts.max(0) + Ts.min(0)) / 2
        cen_v = (Vr.max(0) + Vr.min(0)) / 2 * s
        t = cen_t - cen_v
        A = Vr * s + t
        return chamfer(A, tT, Ts, kd(A)), s, t

    # same frame as the reference (Weaver keeps one canonical frame for the source views)
    Mref = R
    c_ref, s, t = bbox_fit(Mref)
    M = Mref
    mode = "frame"
    diag = float(np.linalg.norm(t_ext))
    if c_ref / max(diag, 1e-6) > 0.18:
        for Mx in ROTS:
            c2, s2, t2 = bbox_fit(Mx @ Mref)
            if c2 < c_ref * 0.7:
                c_ref, s, t, M, mode = c2, s2, t2, Mx @ Mref, "search"
    final = c_ref
    H = np.eye(4)
    H[:3, :3] = M * s
    H[:3, 3] = t - (V.mean(0) @ (M * s).T)
    apply_matrix(o, H)
    fit_report[name] = {"mode": mode, "chamfer": round(float(final) / max(diag, 1e-6), 4), "n_target": int(len(T))}
print("FIT", json.dumps(fit_report))

# ---------- 4. finalize ----------
bpy.data.objects.remove(ref, do_unlink=True)
parts = dict(part_objs)
extras = [o for n, o in parts.items() if n.startswith("BodyExtra")]
if extras and "Body" in parts:
    bpy.ops.object.select_all(action="DESELECT")
    for x in extras + [parts["Body"]]:
        x.select_set(True)
    bpy.context.view_layer.objects.active = parts["Body"]
    bpy.ops.object.join()
    parts = {n: o for n, o in parts.items() if not n.startswith("BodyExtra")}
    parts["Body"] = bpy.context.view_layer.objects.active
    parts["Body"].name = "Body"


def world_bounds(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in objs:
        for cc in ob.bound_box:
            w = ob.matrix_world @ Vector(cc)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


# glTF exports Y-up from Blender Z-up; game front = -Z in Godot == +Y... keep: model faces image-left? -> face -Y
allo = list(parts.values())
lo, hi = world_bounds(allo)
sc = target_size / max(hi - lo)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for ob in allo:
    ob.location = (ob.location - center) * sc
    ob.scale = ob.scale * sc
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

root = bpy.data.objects.new("RigRoot", None)
bpy.context.scene.collection.objects.link(root)
body = parts["Body"]
blo, bhi = world_bounds([body])
bcen = (blo + bhi) / 2


def set_origin(ob, point):
    cur = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = cur


set_origin(body, Vector((bcen.x, bcen.y, blo.z)))
body.parent = root
for n, ob in parts.items():
    if n == "Body":
        continue
    a, b = world_bounds([ob])
    joint = Vector((min(max(bcen.x, a.x), b.x), min(max(bcen.y, a.y), b.y), min(max(bcen.z, a.z), b.z)))
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

lo, hi = world_bounds(list(parts.values()))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.scene.collection.objects.link(cam)
c = (lo + hi) / 2
d = max(hi - lo) * 2.2
cam.location = c + Vector((-d * 0.55, -d, d * 0.55))
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
scn = bpy.context.scene
scn.render.engine = "BLENDER_WORKBENCH"
scn.display.shading.light = "STUDIO"
scn.display.shading.color_type = "TEXTURE"
scn.render.resolution_x = 560
scn.render.resolution_y = 460
scn.render.film_transparent = True
scn.render.filepath = out_png
bpy.ops.render.render(write_still=True)
cam.location = c + Vector((0, -d, 0))
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Z").to_euler()
scn.render.filepath = out_png.replace(".png", "_front.png")
bpy.ops.render.render(write_still=True)
print("REGISTER_JSON", json.dumps({"parts": sorted(n for n in parts if n != "Body"), "dims": [round(v, 3) for v in (hi - lo)]}))
