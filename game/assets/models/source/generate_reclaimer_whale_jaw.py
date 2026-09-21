"""Generate the original Reclaimer base vehicle and detachable Whale Jaw module.

Run with the repository's Blender 5.2.1 LTS:
    blender --background --python generate_reclaimer_whale_jaw.py

The model is intentionally a small, readable sample for P-04/P-05/P-13.
Gameplay, collision, animation, and final Godot materials remain separate.
"""

from __future__ import annotations

import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector


MODEL_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_GLB = MODEL_ROOT / "reclaimer_whale_jaw.glb"
REPO_ROOT = Path(__file__).resolve().parents[4]
SOURCE_ASSET_ROOT = REPO_ROOT / "docs" / "assets" / "model-sources"
OUTPUT_BLEND = SOURCE_ASSET_ROOT / "reclaimer_whale_jaw.blend"
OUTPUT_ROOT = MODEL_ROOT / "source"


PALETTE = {
    "engineering_yellow": (0.82, 0.48, 0.08, 1.0),
    "oil_blue": (0.035, 0.11, 0.14, 1.0),
    "bone_white": (0.82, 0.76, 0.62, 1.0),
    "coral_warning": (0.78, 0.18, 0.13, 1.0),
    "rubber": (0.018, 0.022, 0.024, 1.0),
    "steel": (0.22, 0.26, 0.26, 1.0),
    "energy_lilac": (0.48, 0.31, 0.78, 1.0),
}


def material(name: str, color: tuple[float, float, float, float], metallic: float = 0.0, roughness: float = 0.68):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return mat


MATERIALS = {name: material(name, color) for name, color in PALETTE.items()}
MATERIALS["steel"].node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.55
MATERIALS["steel"].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.42
MATERIALS["energy_lilac"].node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = PALETTE["energy_lilac"]
MATERIALS["energy_lilac"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.3


def add_bevel(obj: bpy.types.Object, width: float = 0.08, segments: int = 2) -> bpy.types.Object:
    modifier = obj.modifiers.new("Readable wide bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    return obj


def apply_material(obj: bpy.types.Object, material_name: str) -> bpy.types.Object:
    obj.data.materials.append(MATERIALS[material_name])
    return obj


def cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], material_name: str, bevel: float = 0.08):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_material(obj, material_name)
    if bevel:
        add_bevel(obj, bevel)
    return obj


def cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, material_name: str, rotation=(0.0, 0.0, 0.0), vertices: int = 16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply_material(obj, material_name)
    add_bevel(obj, min(radius * 0.16, 0.08), 2)
    return obj


def empty(name: str, location: tuple[float, float, float], parent: bpy.types.Object | None = None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.35
    obj.location = location
    if parent:
        obj.parent = parent
    return obj


def parent_all(objects: list[bpy.types.Object], root: bpy.types.Object):
    for obj in objects:
        if obj != root:
            obj.parent = root


def make_wheel(name: str, location: tuple[float, float, float], rotation=(math.pi / 2, 0.0, 0.0)):
    wheel = cylinder(name, location, 0.42, 0.28, "rubber", rotation=rotation, vertices=16)
    hub = cylinder(f"{name}_BoneHub", (location[0], location[1], location[2] + 0.03), 0.16, 0.31, "bone_white", rotation=rotation, vertices=12)
    return wheel, hub


def make_base_vehicle() -> bpy.types.Object:
    root = bpy.data.objects.new("Reclaimer_BaseVehicle_P04", None)
    bpy.context.collection.objects.link(root)
    root["asset_id"] = "vehicle.reclaimer.base"
    root["production_requirement"] = "P-04"
    root["axis_contract"] = "X width, Y forward, Z up; meters"

    pieces: list[bpy.types.Object] = []
    pieces.append(cube("Base_Chassis", (0.0, 0.0, 0.68), (1.25, 1.45, 0.34), "oil_blue", 0.14))
    pieces.append(cube("Rear_ServiceDeck", (0.0, -1.03, 1.15), (1.05, 0.42, 0.22), "engineering_yellow", 0.08))
    pieces.append(cube("Cabin", (0.0, -0.30, 1.58), (0.70, 0.64, 0.68), "engineering_yellow", 0.12))
    pieces.append(cube("Cabin_Window_Front", (0.0, 0.35, 1.68), (0.50, 0.05, 0.30), "oil_blue", 0.035))
    pieces.append(cube("Cabin_Window_Left", (-0.72, -0.30, 1.62), (0.035, 0.42, 0.30), "oil_blue", 0.025))
    pieces.append(cube("Cabin_Roof", (0.0, -0.30, 2.31), (0.78, 0.72, 0.10), "bone_white", 0.06))
    pieces.append(cube("Rear_Bumper", (0.0, -1.53, 0.60), (1.03, 0.12, 0.20), "coral_warning", 0.045))

    for side in (-1.0, 1.0):
        wheel, hub = make_wheel(f"Wheel_{'L' if side < 0 else 'R'}_Front", (side * 1.18, 0.68, 0.55))
        pieces.extend((wheel, hub))
        wheel, hub = make_wheel(f"Wheel_{'L' if side < 0 else 'R'}_Rear", (side * 1.18, -0.86, 0.55))
        pieces.extend((wheel, hub))

    pivot = cylinder("Boom_Pivot", (0.0, 1.18, 1.08), 0.32, 1.72, "steel", rotation=(math.pi / 2, 0.0, 0.0), vertices=16)
    pieces.append(pivot)
    boom = cube("Boom_Main", (0.0, 1.62, 1.55), (0.40, 0.95, 0.18), "engineering_yellow", 0.12)
    boom.rotation_euler.x = math.radians(-18)
    pieces.append(boom)
    arm = cube("Arm_Interface", (0.0, 2.52, 1.34), (0.33, 0.55, 0.16), "oil_blue", 0.09)
    arm.rotation_euler.x = math.radians(26)
    pieces.append(arm)
    interface = empty("Module_Interface_Jaw", (0.0, 3.00, 1.16), root)
    interface["socket_type"] = "wide_jaw"
    interface["rotation_axis"] = "X"
    vfx = empty("VFX_MagnetOrigin", (0.0, 2.90, 1.58), root)
    vfx["event_source"] = "whale_pack.preview_or_authoritative_event"
    aim = empty("Aim_Origin", (0.0, 2.76, 1.30), root)
    parent_all(pieces, root)
    return root


def make_jaw_module() -> bpy.types.Object:
    root = bpy.data.objects.new("Reclaimer_WhaleJawModule_P05", None)
    bpy.context.collection.objects.link(root)
    root["asset_id"] = "module.magnet.jaw.whale"
    root["production_requirement"] = "P-05"
    root["functional_pair"] = "F-05"
    root["stage"] = "stage_02_jaw_open"

    pieces: list[bpy.types.Object] = []
    collar = cylinder("Jaw_Mount_Collar", (0.0, 0.12, 0.0), 0.42, 1.45, "steel", rotation=(math.pi / 2, 0.0, 0.0), vertices=16)
    pieces.append(collar)
    coil = cylinder("Jaw_Core_Coil", (0.0, 0.25, 0.0), 0.23, 1.55, "energy_lilac", rotation=(math.pi / 2, 0.0, 0.0), vertices=16)
    pieces.append(coil)

    upper = cube("Jaw_Upper_Stage02", (0.0, 0.95, 0.50), (0.72, 0.74, 0.16), "bone_white", 0.11)
    upper.rotation_euler.x = math.radians(-17)
    lower = cube("Jaw_Lower_Stage02", (0.0, 0.95, -0.50), (0.72, 0.74, 0.16), "engineering_yellow", 0.11)
    lower.rotation_euler.x = math.radians(17)
    pieces.extend((upper, lower))

    for side in (-1.0, 1.0):
        jaw_pivot = cylinder(
            f"Jaw_{'L' if side < 0 else 'R'}_Pivot",
            (side * 0.70, 0.25, 0.0),
            0.17,
            0.22,
            "coral_warning",
            rotation=(0.0, math.pi / 2, 0.0),
            vertices=12,
        )
        pieces.append(jaw_pivot)
        for index, z in enumerate((-0.66, -0.22, 0.22, 0.66)):
            tooth = cube(
                f"Jaw_{'L' if side < 0 else 'R'}_Tooth_{index + 1}",
                (side * 0.30, 1.58 + abs(z) * 0.16, z * 0.82),
                (0.16, 0.22, 0.10),
                "bone_white",
                0.045,
            )
            tooth.rotation_euler.x = math.radians(-10 if z > 0 else 10)
            pieces.append(tooth)

    socket = empty("Jaw_Socket", (0.0, -0.36, 0.0), root)
    socket["socket_type"] = "wide_jaw"
    socket["stage"] = "preview_and_runtime_shared"
    vfx = empty("Jaw_VFX_FieldOrigin", (0.0, 0.60, 0.0), root)
    vfx["event_source"] = "F-05.authoritative_pack_event"
    hit = empty("Jaw_ContactPoint", (0.0, 1.66, 0.0), root)
    hit["purpose"] = "visual_contact_only_until_F-05_is_authoritative"
    parent_all(pieces, root)
    return root


def make_preview_scene(base: bpy.types.Object, jaw: bpy.types.Object):
    bpy.ops.object.camera_add(location=(7.8, 9.6, 7.3))
    camera = bpy.context.object
    camera.name = "PreviewCamera_ThreeQuarterTopDown"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.6
    target = Vector((0.0, 1.85, 0.95))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(3.0, -3.0, 8.0))
    key = bpy.context.object
    key.name = "PreviewKeyWarm"
    key.data.energy = 950
    key.data.shape = "DISK"
    key.data.size = 6.0
    key.data.color = (1.0, 0.76, 0.50)

    bpy.ops.object.light_add(type="AREA", location=(-5.0, 2.0, 4.0))
    fill = bpy.context.object
    fill.name = "PreviewFillCool"
    fill.data.energy = 520
    fill.data.size = 5.0
    fill.data.color = (0.42, 0.60, 0.78)

    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(MODEL_ROOT / "reclaimer_whale_jaw_preview.png")
    scene.world.color = (0.045, 0.055, 0.052)
    scene.render.film_transparent = False


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for data_block in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(data_block):
            if item.users == 0:
                data_block.remove(item)


def export_asset(base: bpy.types.Object, jaw: bpy.types.Object):
    bpy.ops.object.select_all(action="DESELECT")
    export_roots = {base, jaw}
    for obj in bpy.context.scene.objects:
        current = obj
        while current.parent is not None:
            current = current.parent
        if current in export_roots:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = base
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_materials="EXPORT",
    )


def main():
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)
    SOURCE_ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    clean_scene()
    base = make_base_vehicle()
    jaw = make_jaw_module()
    jaw.location = (0.0, 3.00, 1.16)
    make_preview_scene(base, jaw)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    export_asset(base, jaw)
    bpy.context.scene.render.filepath = str(MODEL_ROOT / "reclaimer_whale_jaw_preview.png")
    bpy.ops.render.render(write_still=True)
    print(f"GENERATED_GLB={OUTPUT_GLB}")
    print(f"GENERATED_BLEND={OUTPUT_BLEND}")


if __name__ == "__main__":
    main()
