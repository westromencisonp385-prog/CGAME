"""Author-created G1 formal slice assets for Wanderberg / Reclaimer.

This generator intentionally does not import the old whitebox or any extracted
reference geometry.  It builds the three slice identities from explicit
mechanical parts, hand-authored color blocks, pivots, state sockets, and
collision proxies.  The output remains a review candidate until the Godot
camera/LOD/performance gate is passed.

Run with the pinned Blender executable:
    blender --background --python generate_g1_formal_slice.py
"""

from __future__ import annotations

import math
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector


MODEL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE_ROOT = REPO_ROOT / "docs" / "assets" / "model-sources"
OUTPUT_ROOT = MODEL_ROOT / "formal_slice"
OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
SOURCE_ROOT.mkdir(parents=True, exist_ok=True)


COLORS = {
    "oil_blue": (0.026, 0.105, 0.145, 1),
    "oil_blue_light": (0.055, 0.18, 0.22, 1),
    "ochre": (0.88, 0.49, 0.075, 1),
    "ochre_light": (1.0, 0.68, 0.16, 1),
    "bone": (0.86, 0.80, 0.66, 1),
    "bone_shadow": (0.56, 0.49, 0.38, 1),
    "tomato": (0.84, 0.12, 0.075, 1),
    "tomato_dark": (0.32, 0.035, 0.025, 1),
    "lilac": (0.46, 0.18, 0.85, 1),
    "lilac_dark": (0.14, 0.045, 0.24, 1),
    "rubber": (0.018, 0.021, 0.022, 1),
    "steel": (0.23, 0.28, 0.28, 1),
    "steel_light": (0.46, 0.50, 0.48, 1),
    "concrete": (0.45, 0.47, 0.44, 1),
    "water": (0.04, 0.50, 0.72, 1),
    "glass": (0.035, 0.16, 0.20, 1),
}


def make_materials(atlas_path: Path | None = None) -> dict[str, bpy.types.Material]:
    result = {}
    swatches = {
        "oil_blue": (0.02, 0.02),
        "oil_blue_light": (0.02, 0.02),
        "ochre": (0.52, 0.02),
        "ochre_light": (0.52, 0.02),
        "bone": (0.02, 0.52),
        "bone_shadow": (0.02, 0.52),
        "tomato": (0.52, 0.52),
        "tomato_dark": (0.52, 0.52),
    }
    for name, color in COLORS.items():
        mat = bpy.data.materials.new(f"MAT_{name}")
        mat.diffuse_color = color
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = 0.56 if name not in {"glass", "lilac"} else 0.32
        principled.inputs["Metallic"].default_value = 0.45 if name in {"steel", "steel_light"} else 0.0
        if name in {"lilac", "water"}:
            principled.inputs["Emission Color"].default_value = color
            principled.inputs["Emission Strength"].default_value = 1.1
        if atlas_path is not None and name in swatches:
            # Use the authored atlas as a restrained surface layer. Generated
            # coordinates keep the exported GLB self-contained; the atlas is
            # cropped by mapping into one of its four deterministic swatches.
            nodes = mat.node_tree.nodes
            links = mat.node_tree.links
            texcoord = nodes.new("ShaderNodeTexCoord")
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (0.44, 0.44, 1.0)
            mapping.inputs["Location"].default_value = (swatches[name][0], swatches[name][1], 0.0)
            image = bpy.data.images.load(str(atlas_path), check_existing=True)
            image_node = nodes.new("ShaderNodeTexImage")
            image_node.image = image
            mix = nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs["Fac"].default_value = 0.28
            mix.inputs["Color1"].default_value = color
            links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
            links.new(mapping.outputs["Vector"], image_node.inputs["Vector"])
            links.new(image_node.outputs["Color"], mix.inputs["Color2"])
            links.new(mix.outputs["Color"], principled.inputs["Base Color"])
        result[name] = mat
    return result


def make_handpainted_surface_atlas() -> Path:
    """Create a deterministic, small authored atlas for the next UV pass.

    This is deliberately block-painted (edge marks, hazard bands, bolts) rather
    than noise-generated. The current candidate GLBs use controlled material
    blocks; the atlas is shipped as a reviewable texture input for the G1 UV
    pass, so it cannot silently turn into random AI grime.
    """
    size = 512
    image = bpy.data.images.new("G1_Handpainted_Surface_Atlas", width=size, height=size, alpha=True)
    pixels = [0.0] * (size * size * 4)
    def fill(x0, y0, x1, y1, color):
        r, g, b, a = color
        for y in range(max(0, y0), min(size, y1)):
            for x in range(max(0, x0), min(size, x1)):
                index = (y * size + x) * 4
                pixels[index:index + 4] = [r, g, b, a]
    def stripe(x0, y0, x1, y1, color, step=24, width=10):
        r, g, b, a = color
        for y in range(y0, y1):
            for x in range(x0, x1):
                if ((x - x0) + (y - y0)) % step < width:
                    index = (y * size + x) * 4
                    pixels[index:index + 4] = [r, g, b, a]
    fill(0, 0, size, size, (0.055, 0.065, 0.066, 1.0))
    fill(16, 16, 240, 240, COLORS["oil_blue"])
    stripe(16, 16, 240, 240, COLORS["oil_blue_light"], 46, 5)
    fill(272, 16, 496, 240, COLORS["ochre"])
    stripe(272, 16, 496, 240, COLORS["ochre_light"], 42, 6)
    fill(16, 272, 240, 496, COLORS["bone"])
    stripe(16, 272, 240, 496, COLORS["bone_shadow"], 58, 4)
    fill(272, 272, 496, 496, COLORS["tomato_dark"])
    stripe(272, 272, 496, 496, COLORS["tomato"], 38, 14)
    # Intentional hand marks: bolts and two edge chips per swatch.
    for cx, cy in ((40, 40), (206, 206), (296, 40), (478, 206), (40, 296), (206, 478), (296, 296), (478, 478)):
        for y in range(cy - 6, cy + 7):
            for x in range(cx - 6, cx + 7):
                if (x - cx) ** 2 + (y - cy) ** 2 <= 36:
                    index = (y * size + x) * 4
                    pixels[index:index + 4] = [0.78, 0.73, 0.58, 1.0]
    image.pixels = pixels
    destination = OUTPUT_ROOT / "painted_surface_atlas.png"
    image.filepath_raw = str(destination)
    image.file_format = "PNG"
    image.save()
    return destination


MATS: dict[str, bpy.types.Material] = {}


def set_parent(obj: bpy.types.Object, parent: bpy.types.Object | None) -> bpy.types.Object:
    if parent is not None:
        obj.parent = parent
    return obj


def add_bevel(obj: bpy.types.Object, width: float = 0.06, segments: int = 2) -> bpy.types.Object:
    if width <= 0:
        return obj
    mod = obj.modifiers.new("Authored_edge_softness", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return obj


def apply_mat(obj: bpy.types.Object, name: str) -> bpy.types.Object:
    obj.data.materials.append(MATS[name])
    return obj


def cube(name: str, loc, scale, mat: str, parent=None, bevel=0.05, rotation=(0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_mat(obj, mat)
    add_bevel(obj, bevel)
    set_parent(obj, parent)
    return obj


def cylinder(name: str, loc, radius: float, depth: float, mat: str, parent=None, rotation=(0, 0, 0), vertices=16, bevel=0.025) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply_mat(obj, mat)
    add_bevel(obj, min(bevel, radius * 0.22))
    set_parent(obj, parent)
    for poly in obj.data.polygons:
        poly.use_smooth = vertices >= 12
    return obj


def torus(name: str, loc, major: float, minor: float, mat: str, parent=None, rotation=(math.pi / 2, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply_mat(obj, mat)
    set_parent(obj, parent)
    return obj


def empty(name: str, loc=(0, 0, 0), parent=None, role: str | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.28
    obj.location = loc
    set_parent(obj, parent)
    if role:
        obj["contract_role"] = role
    return obj


def wedge(name: str, loc, size, mat: str, parent=None, rotation=(0, 0, 0), point_forward=True) -> bpy.types.Object:
    """A deliberately chunky six-vertex wedge for authored plates/teeth."""
    sx, sy, sz = size
    verts = [(-sx, -sy, -sz), (sx, -sy, -sz), (-sx, sy, -sz), (sx, sy, -sz),
             (-sx, -sy, sz), (sx, -sy, sz), (0.0, sy, sz * 0.82), (0.0, -sy, sz * 0.82)]
    faces = [(0, 1, 3, 2), (4, 6, 5), (0, 4, 5, 1), (2, 3, 6), (0, 2, 6, 4), (1, 5, 6, 3), (0, 7, 1), (0, 4, 7), (1, 7, 5)]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rotation
    apply_mat(obj, mat)
    add_bevel(obj, 0.035, 2)
    set_parent(obj, parent)
    return obj


def profile_plate(name: str, profile: list[tuple[float, float]], width: float, mat: str, parent=None) -> bpy.types.Object:
    """Extrude an intentionally designed Y/Z profile across the machine width."""
    count = len(profile)
    verts = [(-width, y, z) for y, z in profile] + [(width, y, z) for y, z in profile]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, nxt + count, index + count))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    apply_mat(obj, mat)
    add_bevel(obj, 0.055, 3)
    set_parent(obj, parent)
    return obj


def tooth(name: str, loc, length: float, upper: bool, parent=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.0 if upper else 0.15, radius2=0.15 if upper else 0.0, depth=length, location=loc)
    obj = bpy.context.object
    obj.name = name
    apply_mat(obj, "bone")
    add_bevel(obj, 0.024, 2)
    set_parent(obj, parent)
    return obj


def hydraulic(name: str, a, b, barrel_radius: float, mat: str, parent=None) -> tuple[bpy.types.Object, bpy.types.Object]:
    """Create an authored cylinder pair aligned from a to b."""
    a_v, b_v = Vector(a), Vector(b)
    axis = b_v - a_v
    mid = (a_v + b_v) * 0.5
    quat = axis.to_track_quat("Z", "Y")
    barrel = cylinder(f"{name}_Barrel", mid, barrel_radius, axis.length * 0.62, mat, parent, quat.to_euler(), 12, 0.018)
    rod = cylinder(f"{name}_Rod", a_v.lerp(b_v, 0.72), barrel_radius * 0.42, axis.length * 0.62, "bone", parent, quat.to_euler(), 10, 0.012)
    return barrel, rod


def add_contract_nodes(root: bpy.types.Object, asset_id: str, requirement: str, functional: str) -> None:
    root["asset_id"] = asset_id
    root["production_requirement"] = requirement
    root["functional_dependency"] = functional
    root["axis_contract"] = "X width, Y forward, Z up; meters"
    state = empty("StateLayers", parent=root, role="state_visibility")
    for label in ("Uninstalled", "Preview", "Installed", "Execute", "Stagger", "Repair"):
        layer = empty(f"State_{label}", parent=state, role="state_layer")
        layer["state_name"] = label.lower()
    sockets = empty("Sockets", parent=root, role="integration_sockets")
    for name, role in (("InstantiationPoint_Active", "active_vfx_mount"), ("InstantiationPoint_Passive_A", "passive_vfx_mount"),
                       ("InstantiationPoint_Passive_B", "passive_vfx_mount"), ("Generic_CooldownElement", "cooldown_feedback"),
                       ("TelegraphOrigin", "telegraph_origin"), ("Contact", "contact_event"), ("RepairTarget", "repair_target")):
        empty(name, parent=sockets, role=role)
    lods = empty("LOD_Contracts", parent=root, role="lod_contract")
    for level in (0, 1, 2):
        node = empty(f"LOD{level}", parent=lods, role="lod")
        node["target_pixels"] = [128, 64, 24][level]
    coll = empty("Collision_Proxies", parent=root, role="collision_proxy_collection")
    coll.hide_render = True
    coll.hide_viewport = True
    root["review_status"] = "candidate"


def make_track(root: bpy.types.Object, side: float, y: float, length: float = 1.65) -> None:
    side_name = "L" if side < 0 else "R"
    cube(f"Track_{side_name}_Shell", (side * 1.22, y, 0.58), (0.27, length, 0.43), "rubber", root, 0.12)
    cube(f"Track_{side_name}_Rail", (side * 1.22, y, 0.62), (0.30, length * 0.80, 0.09), "steel", root, 0.03)
    for i in range(9):
        tread = cube(f"Track_{side_name}_Tread_{i + 1:02d}", (side * 1.22, y - length * 0.82 + i * (length * 1.64 / 8), 0.55), (0.32, 0.075, 0.055), "steel_light", root, 0.018)
        tread.rotation_euler.x = math.radians(4 if i % 2 else -4)
    for wheel_i, wheel_y in enumerate((y - length * 0.74, y, y + length * 0.74)):
        cylinder(f"Track_{side_name}_Wheel_{wheel_i}", (side * 1.23, wheel_y, 0.56), 0.27 if wheel_i else 0.31, 0.33, "steel", root, (0, math.pi / 2, 0), 16, 0.022)
        cylinder(f"Track_{side_name}_Hub_{wheel_i}", (side * 1.40, wheel_y, 0.56), 0.10, 0.035, "bone_shadow", root, (0, math.pi / 2, 0), 12, 0.01)


def make_a01() -> bpy.types.Object:
    root = bpy.data.objects.new("A01_WhaleJawReclaimer_FORMAL", None)
    bpy.context.collection.objects.link(root)
    add_contract_nodes(root, "vehicle.a01.magnetic_whale_jaw.formal", "P-04/P-05/P-13", "F-05")
    root["mechanism_signature"] = "magnetize -> compress -> throw"
    root["silhouette_rule"] = "mouth void 60 percent of read; cab remains identity anchor"

    chassis = empty("Chassis", parent=root, role="base_vehicle")
    cube("Chassis_Main", (0, 0, 0.78), (1.30, 1.52, 0.34), "oil_blue", chassis, 0.14)
    wedge("Chassis_Nose_Wedge", (0, 1.18, 0.84), (1.04, 0.46, 0.30), "oil_blue_light", chassis, (0, 0, 0))
    cube("ServiceDeck", (0, -1.03, 1.22), (1.06, 0.46, 0.22), "ochre", chassis, 0.07)
    cube("RearBumper", (0, -1.54, 0.66), (1.04, 0.13, 0.19), "tomato", chassis, 0.04)
    cube("RearCounterweight", (0, -1.28, 1.18), (0.78, 0.22, 0.27), "oil_blue_light", chassis, 0.07)
    for side in (-1, 1):
        make_track(chassis, side, 0.0)

    cabin = empty("Cabin", parent=root, role="identity_cabin")
    cube("Cabin_Lower", (0, -0.38, 1.62), (0.72, 0.66, 0.60), "ochre", cabin, 0.12)
    cube("Cabin_Window_Front", (0, 0.31, 1.72), (0.52, 0.045, 0.31), "glass", cabin, 0.026)
    cube("Cabin_Window_L", (-0.735, -0.38, 1.70), (0.035, 0.43, 0.30), "glass", cabin, 0.025)
    cube("Cabin_Window_R", (0.735, -0.38, 1.70), (0.035, 0.43, 0.30), "glass", cabin, 0.025)
    cube("Cabin_Roof", (0, -0.38, 2.28), (0.80, 0.74, 0.11), "bone", cabin, 0.055)
    cylinder("Cabin_Beacon", (0.48, -0.38, 2.53), 0.12, 0.20, "tomato", cabin, vertices=16, bevel=0.02)
    cylinder("Cabin_BeaconCap", (0.48, -0.38, 2.66), 0.10, 0.075, "tomato", cabin, vertices=16, bevel=0.015)
    for side in (-1, 1):
        cube(f"Cabin_Ladder_{side}", (side * 0.84, -0.72, 1.20), (0.035, 0.06, 0.40), "steel_light", cabin, 0.015)
        for step_i in range(3):
            cube(f"Cabin_Ladder_{side}_Step_{step_i}", (side * 0.84, -0.72 + step_i * 0.18, 1.05 + step_i * 0.18), (0.07, 0.04, 0.025), "steel_light", cabin, 0.01)

    boom = empty("WhaleJawBoom", parent=root, role="module_boom")
    cylinder("Boom_Pivot", (0, 1.15, 1.18), 0.34, 1.76, "steel", boom, (math.pi / 2, 0, 0), 20, 0.03)
    b = cube("Boom_Main", (0, 1.65, 1.55), (0.43, 0.94, 0.18), "ochre", boom, 0.12, (math.radians(-16), 0, 0))
    cube("Boom_Inset", (0, 1.70, 1.53), (0.25, 0.73, 0.035), "oil_blue_light", boom, 0.02, (math.radians(-16), 0, 0))
    cube("Arm_Interface", (0, 2.55, 1.38), (0.35, 0.56, 0.17), "oil_blue", boom, 0.09, (math.radians(22), 0, 0))
    hydraulic("BoomHydraulic_L", (-0.36, 1.16, 1.22), (-0.42, 2.10, 1.73), 0.11, "steel_light", boom)
    hydraulic("BoomHydraulic_R", (0.36, 1.16, 1.22), (0.42, 2.10, 1.73), 0.11, "steel_light", boom)
    hydraulic("BoomHose_L", (-0.50, 1.08, 1.18), (-0.52, 2.22, 1.62), 0.037, "tomato", boom)

    jaw = empty("MagneticWhaleJaw", loc=(0, 2.95, 1.30), parent=root, role="active_module")
    jaw["stage_0"] = "closed_compact"
    jaw["stage_2"] = "open_pack_and_release"
    cube("Jaw_CavityBack", (0, 0.04, 0.04), (0.96, 0.10, 0.68), "rubber", jaw, 0.08)
    torus("Magnetic_Core_Ring", (0, 0.05, 0), 0.39, 0.095, "lilac", jaw)
    cylinder("Magnetic_Core_Disc", (0, 0.05, 0), 0.30, 0.10, "lilac_dark", jaw, (math.pi / 2, 0, 0), 20, 0.02)
    for side in (-1, 1):
        side_name = "L" if side < 0 else "R"
        # cheek plates and visible pivots deliberately use clean, repeated authorship
        cube(f"Jaw_{side_name}_Cheek", (side * 0.76, 0.60, 0), (0.18, 0.66, 0.77), "oil_blue", jaw, 0.08, (0, 0, math.radians(side * -8)))
        cylinder(f"Jaw_{side_name}_Pivot", (side * 0.88, 0.08, 0), 0.19, 0.22, "steel_light", jaw, (0, math.pi / 2, 0), 16, 0.025)
        torus(f"Jaw_{side_name}_PivotRing", (side * 0.99, 0.08, 0), 0.19, 0.055, "lilac", jaw, (0, math.pi / 2, 0))
        hydraulic(f"Jaw_{side_name}_Hydraulic", (side * 0.72, -0.18, 0), (side * 0.66, 0.78, 0.48), 0.095, "ochre", jaw)
    profile_plate("Jaw_UpperShell", [(-0.12, 0.28), (0.10, 0.99), (0.72, 1.16), (1.44, 0.96), (1.94, 0.61), (1.98, 0.42), (1.55, 0.42), (0.75, 0.63), (0.03, 0.49)], 1.03, "oil_blue", jaw)
    profile_plate("Jaw_LowerShell", [(-0.10, -0.20), (0.17, -0.67), (0.91, -0.76), (1.76, -0.57), (1.94, -0.34), (1.48, -0.33), (0.58, -0.43), (0.04, -0.25)], 1.03, "oil_blue", jaw)
    profile_plate("Jaw_UpperBoneRim", [(1.55, 0.62), (1.94, 0.61), (1.98, 0.42), (1.55, 0.42)], 1.055, "bone", jaw)
    profile_plate("Jaw_LowerBoneRim", [(1.46, -0.54), (1.76, -0.57), (1.94, -0.34), (1.48, -0.33)], 1.055, "bone", jaw)
    for row, z, upper in (("Upper", 0.25, True), ("Lower", -0.16, False)):
        for i, x in enumerate((-0.78, -0.39, 0, 0.39, 0.78)):
            new_tooth = tooth(f"Jaw_{row}_Tooth_{i + 1:02d}", (x, 1.79, z), 0.35 if i in (0, 4) else 0.40, upper, jaw)
            new_tooth["readability"] = "mouth_edge"
    for side in (-1, 1):
        for i, x in enumerate((-0.52, 0.0, 0.52)):
            cube(f"Jaw_{'L' if side < 0 else 'R'}_Panel_{i}", (side * 1.02, 0.64 + i * 0.28, -0.22 + i * 0.18), (0.025, 0.11, 0.13), "ochre_light", jaw, 0.018)
    empty("Jaw_Socket", (0, -0.43, 0), jaw, "module_socket")
    empty("Jaw_ContactPoint", (0, 1.62, 0), jaw, "contact_event")
    empty("Jaw_VFX_FieldOrigin", (0, 0.13, 0), jaw, "magnetic_field")
    empty("VFX_JawCompression", (0, 0.84, 0), jaw, "compression_feedback")
    empty("VFX_JawRelease", (0, 1.52, 0), jaw, "release_feedback")
    # Animator-ready authored pivots. Reparent while preserving local mesh pose.
    for label, z in (("Upper", 0.10), ("Lower", -0.10)):
        pivot = empty(f"Jaw_{label}Pivot", (0, 0, z), jaw, "mechanical_animation_pivot")
        pivot["rotation_axis"] = "X"
        for obj in list(bpy.context.scene.objects):
            if obj.parent == jaw and obj.name.startswith(f"Jaw_{label}") and obj != pivot:
                pose = obj.location.copy()
                obj.parent = pivot
                obj.location = pose - pivot.location
        for frame, angle in ((1, 0), (12, -0.16 if label == "Upper" else 0.16), (20, 0.10 if label == "Upper" else -0.10), (32, 0)):
            pivot.rotation_euler.x = angle
            pivot.keyframe_insert(data_path="rotation_euler", frame=frame)
        if pivot.animation_data and pivot.animation_data.action:
            pivot.animation_data.action.name = f"A01_{label}_PrepareContactAftermath"
        pivot.rotation_euler.x = 0
    return root


def crab_panel(parent: bpy.types.Object, name: str, loc, side_sign=1):
    panel = cube(name, loc, (0.40, 0.38, 0.33), "bone", parent, 0.07, (0, math.radians(6), math.radians(side_sign * 8)))
    cube(f"{name}_OrangeBand", (loc[0] + side_sign * 0.02, loc[1] + 0.39, loc[2]), (0.36, 0.025, 0.12), "tomato", parent, 0.016, (0, math.radians(6), math.radians(side_sign * 8)))
    cube(f"{name}_OrangeBand2", (loc[0] + side_sign * 0.05, loc[1] + 0.28, loc[2]), (0.36, 0.022, 0.10), "tomato", parent, 0.014, (0, math.radians(6), math.radians(side_sign * 8)))
    # Broad diagonal top/side safety bands read from the actual top-down camera.
    cube(f"{name}_TopSafetyBand", (loc[0], loc[1], loc[2] + 0.345), (0.42, 0.095, 0.012), "tomato", parent, 0.009, (0, 0, math.radians(36)))
    cube(f"{name}_SideSafetyBand", (loc[0] + side_sign * 0.41, loc[1], loc[2]), (0.014, 0.13, 0.32), "tomato", parent, 0.009, (math.radians(32), 0, 0))
    return panel


def make_b01() -> bpy.types.Object:
    root = bpy.data.objects.new("B01_ReverseCrabBarricade_FORMAL", None)
    bpy.context.collection.objects.link(root)
    add_contract_nodes(root, "enemy.b01.reverse_crab_barricade.formal", "P-06/P-13", "F-12")
    root["mechanism_signature"] = "sideways_charge -> wall_shove OR anchor_break"
    root["telegraph_shape"] = "wide red wedge aligned to lateral motion"

    body = empty("CrabBody", parent=root, role="enemy_body")
    cube("Crab_Core", (0, 0, 1.18), (0.82, 0.92, 0.55), "ochre", body, 0.15)
    cube("Crab_Rear_Plate", (0, -0.96, 1.24), (0.73, 0.16, 0.40), "tomato", body, 0.06)
    cube("Crab_Front_Plate", (0, 0.95, 1.20), (0.76, 0.12, 0.36), "bone", body, 0.05)
    cube("Crab_Sign_Inset", (0, -1.145, 1.27), (0.40, 0.025, 0.20), "tomato_dark", body, 0.02)
    # The warning board is geometry, not baked text; Godot can localize the label later.
    cube("Crab_Sign_Arrow", (0, -1.18, 1.27), (0.22, 0.018, 0.045), "ochre_light", body, 0.01)
    cylinder("Crab_Beacon", (0, 0, 2.08), 0.24, 0.32, "tomato", body, vertices=20, bevel=0.03)
    cylinder("Crab_Beacon_Cap", (0, 0, 2.29), 0.20, 0.08, "tomato", body, vertices=20, bevel=0.02)
    for side in (-1, 1):
        for leg_i, y in enumerate((-0.72, 0.0, 0.72)):
            name = f"Leg_{'L' if side < 0 else 'R'}_{leg_i + 1}"
            hip = (side * 0.82, y, 1.20)
            knee = (side * 1.22, y + side * 0.10, 0.70)
            foot = (side * 1.52, y + side * 0.16, 0.27)
            hydraulic(f"{name}_Upper", hip, knee, 0.115, "steel", body)
            hydraulic(f"{name}_Lower", knee, foot, 0.085, "tomato", body)
            cube(f"{name}_Foot", foot, (0.22, 0.18, 0.09), "rubber", body, 0.04, (0, math.radians(side * -12), math.radians(side * 8)))
            cylinder(f"{name}_Joint", knee, 0.12, 0.22, "steel_light", body, (0, math.pi / 2, 0), 14, 0.02)
    for side in (-1, 1):
        side_name = "L" if side < 0 else "R"
        # Four broad barricade petals carry the action silhouette.
        for i, y in enumerate((-0.67, -0.22, 0.23, 0.68)):
            crab_panel(body, f"Barricade_{side_name}_{i + 1}", (side * 0.86, y, 1.12), side)
    empty("TelegraphAim", (1.72, 0.0, 0.46), root, "lateral_charge_direction")
    empty("Weakpoint_LeftAnchor", (-1.18, 0.05, 0.26), root, "break_anchor")
    empty("Weakpoint_RightAnchor", (1.18, 0.05, 0.26), root, "break_anchor")
    empty("Contact_SideCharge", (1.66, 0.0, 0.42), root, "contact_event")
    empty("Drop_Scrap", (0, -0.35, 0.16), root, "drop")
    return root


def make_c04() -> bpy.types.Object:
    root = bpy.data.objects.new("C04_RepairPump_FORMAL", None)
    bpy.context.collection.objects.link(root)
    add_contract_nodes(root, "facility.c04.repair_pump.formal", "P-07/P-13", "F-15")
    root["mechanism_signature"] = "disassemble -> seal -> pressure -> restore"
    root["state_contract"] = "broken / repair / restored"
    body = empty("PumpBody", parent=root, role="repair_facility")
    cube("Pump_Base", (0, 0, 0.30), (0.95, 0.72, 0.18), "concrete", body, 0.08)
    cylinder("Pump_MainHousing", (0, 0, 1.02), 0.72, 1.15, "ochre", body, (math.pi / 2, 0, 0), 20, 0.07)
    cylinder("Pump_BlueBand", (0, 0, 1.02), 0.75, 0.19, "oil_blue_light", body, (math.pi / 2, 0, 0), 20, 0.025)
    torus("Pump_RepairSeal", (0, 0.12, 1.02), 0.55, 0.10, "water", body)
    cylinder("Pump_Impeller", (0, -0.13, 1.02), 0.35, 0.14, "steel", body, (math.pi / 2, 0, 0), 12, 0.025)
    for side in (-1, 1):
        cylinder(f"Pump_Pipe_{side}", (side * 1.02, 0.0, 1.02), 0.25, 0.78, "oil_blue_light", body, (0, math.pi / 2, 0), 16, 0.035)
        torus(f"Pump_Flange_{side}", (side * 1.38, 0.0, 1.02), 0.30, 0.07, "steel_light", body, (0, math.pi / 2, 0))
        cylinder(f"Pump_ValveWheel_{side}", (side * 0.78, -0.08, 1.80), 0.28, 0.10, "tomato", body, (math.pi / 2, 0, 0), 16, 0.018)
        for i in range(4):
            cube(f"Pump_ValveSpoke_{side}_{i}", (side * 0.78 + math.cos(i * math.pi / 2) * 0.22, -0.08 + math.sin(i * math.pi / 2) * 0.22, 1.80), (0.035, 0.16, 0.035), "tomato", body, 0.01, (0, 0, i * math.pi / 2))
    # Pressure gauge: backing, face, and an unmistakable red pointer.
    cylinder("PressureGauge_Back", (0.0, -0.75, 1.98), 0.30, 0.14, "steel", body, (math.pi / 2, 0, 0), 16, 0.02)
    cylinder("PressureGauge_Face", (0.0, -0.84, 1.98), 0.25, 0.04, "bone", body, (math.pi / 2, 0, 0), 20, 0.01)
    wedge("PressureGauge_Pointer", (0.03, -0.88, 2.00), (0.025, 0.02, 0.16), "tomato", body, (0, math.radians(-28), 0))
    for state, z, mat in (("Broken", 2.48, "tomato_dark"), ("Repair", 2.54, "ochre_light"), ("Restored", 2.60, "water")):
        layer = empty(f"Pump_State_{state}", (0, 0, z), root, "facility_state")
        layer["state"] = state.lower()
        cylinder(f"Pump_StateLamp_{state}", (0, 0, 0), 0.10, 0.04, mat, layer, (math.pi / 2, 0, 0), 12, 0.01)
    empty("Pump_Interact", (0, -0.92, 0.92), root, "repair_interaction")
    empty("Pump_WaterOut", (0, 1.36, 1.02), root, "restored_flow_origin")
    return root


def setup_preview(a01: bpy.types.Object, b01: bpy.types.Object, c04: bpy.types.Object) -> None:
    a01.location = (-3.5, 1.0, 0)
    b01.location = (3.2, 1.0, 0)
    c04.location = (0.0, -3.15, 0)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.object
    ground.name = "PreviewGround"
    apply_mat(ground, "concrete")
    bpy.ops.object.camera_add(location=(9.5, 13.0, 11.0))
    camera = bpy.context.object
    camera.name = "G1_ThreeQuarterCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 16.0
    camera.rotation_euler = (Vector((0, -0.2, 1.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=(2.5, 1.5, 10.0))
    key = bpy.context.object
    key.name = "WarmKey"
    key.data.energy = 1350
    key.data.shape = "DISK"
    key.data.size = 6.0
    key.data.color = (1.0, 0.76, 0.49)
    bpy.ops.object.light_add(type="AREA", location=(-6.0, 3.5, 5.0))
    fill = bpy.context.object
    fill.name = "CoolFill"
    fill.data.energy = 900
    fill.data.size = 5.0
    fill.data.color = (0.38, 0.60, 0.84)
    bpy.ops.object.light_add(type="AREA", location=(0.0, -6.0, 4.0))
    rim = bpy.context.object
    rim.name = "RimLight"
    rim.data.energy = 750
    rim.data.size = 4.0
    rim.data.color = (0.62, 0.32, 0.90)
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUTPUT_ROOT / "g1_formal_slice_preview.png")
    scene.world.color = (0.028, 0.038, 0.045)


def render_candidate(root: bpy.types.Object, filename: str, local_target, view_sign: float, ortho_scale: float) -> None:
    """Render one review image from the action-facing side of the asset."""
    roots = [obj for obj in (bpy.data.objects.get("A01_WhaleJawReclaimer_FORMAL"), bpy.data.objects.get("B01_ReverseCrabBarricade_FORMAL"), bpy.data.objects.get("C04_RepairPump_FORMAL")) if obj]
    previous = {}
    for obj in bpy.context.scene.objects:
        ancestor = obj
        while ancestor.parent is not None:
            ancestor = ancestor.parent
        if ancestor in roots:
            previous[obj] = obj.hide_render
            obj.hide_render = ancestor != root
    target = root.location + Vector(local_target)
    camera = bpy.context.scene.camera
    camera.location = target + Vector((6.4, view_sign * 10.5, 6.0))
    camera.data.ortho_scale = ortho_scale
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = str(OUTPUT_ROOT / filename)
    bpy.ops.render.render(write_still=True)
    for obj, hidden in previous.items():
        obj.hide_render = hidden


def select_tree(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in bpy.context.scene.objects:
        current = obj
        while current.parent is not None:
            current = current.parent
        if current == root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_root(root: bpy.types.Object, filename: str) -> None:
    previous_location = root.location.copy()
    root.location = (0, 0, 0)
    select_tree(root)
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT_ROOT / filename), export_format="GLB", use_selection=True, export_apply=True, export_animations=True, export_materials="EXPORT")
    root.location = previous_location


def clean_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(blend: Path) -> None:
    outputs = {}
    for path in (OUTPUT_ROOT / "a01_whale_jaw_formal.glb", OUTPUT_ROOT / "b01_reverse_crab_formal.glb", OUTPUT_ROOT / "c04_repair_pump_formal.glb", OUTPUT_ROOT / "g1_formal_slice_preview.png", OUTPUT_ROOT / "a01_whale_jaw_formal_preview.png", OUTPUT_ROOT / "b01_reverse_crab_formal_preview.png", OUTPUT_ROOT / "c04_repair_pump_formal_preview.png", OUTPUT_ROOT / "painted_surface_atlas.png", blend, Path(__file__)):
        rel = path.relative_to(REPO_ROOT).as_posix()
        outputs[rel] = {"bytes": path.stat().st_size, "sha256": hash_file(path)}
    manifest = {
        "manifest_version": 1,
        "status": "candidate",
        "slice": "G1 industrial-folk formal asset skeleton",
        "source_script": Path(__file__).relative_to(REPO_ROOT).as_posix(),
        "blender_actual": bpy.app.version_string,
        "axis_contract": "X width, Y forward, Z up; meters",
        "concept_sources": [
            "docs/assets/2d-candidates/A01-whale-jaw-reclaimer.png",
            "docs/assets/2d-candidates/B01-reverse-crab.png",
            "docs/assets/2d-candidates/C04-repair-pump-cutaway.png",
        ],
        "reference_policy": "Original authored geometry. Concept boards define silhouette, color blocking, and action readability; no extracted geometry or old whitebox mesh is included.",
        "palette": list(COLORS.keys()),
        "assets": [
            {"id": "vehicle.a01.magnetic_whale_jaw.formal", "file": "a01_whale_jaw_formal.glb", "mechanism": "magnetize -> compress -> throw", "contract_nodes": ["Jaw_Socket", "Jaw_ContactPoint", "Jaw_VFX_FieldOrigin", "VFX_JawCompression", "VFX_JawRelease"]},
            {"id": "enemy.b01.reverse_crab_barricade.formal", "file": "b01_reverse_crab_formal.glb", "mechanism": "sideways_charge -> wall_shove OR anchor_break", "contract_nodes": ["TelegraphAim", "Weakpoint_LeftAnchor", "Weakpoint_RightAnchor", "Contact_SideCharge", "Drop_Scrap"]},
            {"id": "facility.c04.repair_pump.formal", "file": "c04_repair_pump_formal.glb", "mechanism": "disassemble -> seal -> pressure -> restore", "contract_nodes": ["Pump_Interact", "Pump_WaterOut", "Pump_State_Broken", "Pump_State_Repair", "Pump_State_Restored"]},
        ],
        "outputs": outputs,
        "acceptance": {
            "next_gate": "G1 Godot real-camera no-VFX image and collision/LOD/action review",
            "not_claimed": ["final", "integrated", "production-approved"],
            "visual_checks_done": ["author-created geometry", "explicit material blocks", "deterministic handpainted atlas bound", "mechanical sockets", "three-quarter render"],
            "remaining": ["runtime camera framing", "LOD runtime cost", "collision walk-through", "prepare-contact-aftermath animation synchronization"],
        },
    }
    (OUTPUT_ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    global MATS
    clean_scene()
    atlas_path = make_handpainted_surface_atlas()
    MATS = make_materials(atlas_path)
    a01 = make_a01()
    b01 = make_b01()
    c04 = make_c04()
    setup_preview(a01, b01, c04)
    blend = SOURCE_ROOT / "g1_formal_slice.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    export_root(a01, "a01_whale_jaw_formal.glb")
    export_root(b01, "b01_reverse_crab_formal.glb")
    export_root(c04, "c04_repair_pump_formal.glb")
    bpy.context.scene.render.filepath = str(OUTPUT_ROOT / "g1_formal_slice_preview.png")
    bpy.ops.render.render(write_still=True)
    render_candidate(a01, "a01_whale_jaw_formal_preview.png", (0, 1.25, 1.1), 1.0, 6.5)
    render_candidate(b01, "b01_reverse_crab_formal_preview.png", (0, 0.0, 1.1), 1.0, 4.2)
    render_candidate(c04, "c04_repair_pump_formal_preview.png", (0, 0.0, 1.15), -1.0, 4.2)
    write_manifest(blend)
    print(f"FORMAL_BLEND={blend}")
    print(f"FORMAL_OUTPUT={OUTPUT_ROOT}")
    print(f"A01_OBJECTS={len([o for o in bpy.context.scene.objects if o.name.startswith(('A01_', 'Chassis', 'Cabin', 'Boom', 'Jaw', 'Track_'))])}")
    print(f"TOTAL_OBJECTS={len(bpy.context.scene.objects)}")


if __name__ == "__main__":
    main()
