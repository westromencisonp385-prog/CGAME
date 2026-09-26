"""Blender 5.2.1 headless structural and visual validator for Weaver assets.

Run with: blender --background --python tools/blender_validate_assets.py -- file...
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "qa" / "weaver"

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

def import_asset(path: Path):
    if path.suffix.lower() == ".glb":
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif path.suffix.lower() == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), use_custom_normals=True)
    else:
        raise ValueError(f"unsupported asset: {path}")

def bounds(objects):
    points=[]
    for obj in objects:
        if obj.type != "MESH": continue
        points.extend(obj.matrix_world @ Vector(c) for c in obj.bound_box)
    if not points: return Vector((-1,-1,-1)), Vector((1,1,1))
    return Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))), Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))

def render(path: Path, objects):
    low, high = bounds(objects); center=(low+high)/2; size=max(high-low); cam_data=bpy.data.cameras.new("QA_Camera"); cam=bpy.data.objects.new("QA_Camera",cam_data); bpy.context.collection.objects.link(cam); bpy.context.scene.camera=cam
    cam.location=center+Vector((size*1.55,-size*1.9,size*1.25)); cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler(); cam_data.type="ORTHO"; cam_data.ortho_scale=size*2.6; cam_data.clip_end=max(1000.0,size*20.0)
    for loc, energy, size_l in [((size*2,-size*2,size*3),1200,size*1.5),((-size,size,size*2),800,size),((0,-size,size*0.5),500,size)]:
        ld=bpy.data.lights.new("QA_Area","AREA"); lo=bpy.data.objects.new("QA_Area",ld); bpy.context.collection.objects.link(lo); lo.location=center+Vector(loc); ld.energy=energy; ld.shape="DISK"; ld.size=size_l; lo.rotation_euler=(center-lo.location).to_track_quat("-Z","Y").to_euler()
    world=bpy.context.scene.world or bpy.data.worlds.new("QA_World"); bpy.context.scene.world=world; world.color=(0.05,0.05,0.05)
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE"; scene.render.resolution_x=720; scene.render.resolution_y=540; scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"; scene.render.film_transparent=False
    destination=OUT/(path.stem+"_turntable.png"); destination.parent.mkdir(parents=True,exist_ok=True); scene.render.filepath=str(destination); bpy.ops.render.render(write_still=True); return destination

def inspect(path: Path):
    reset(); import_asset(path); objects=list(bpy.context.scene.objects); meshes=[o for o in objects if o.type=="MESH"]; armatures=[o for o in objects if o.type=="ARMATURE"]
    triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons); vertices=sum(len(o.data.vertices) for o in meshes); materials=sorted({m.name for o in meshes for m in o.data.materials if m}); uv_meshes=sum(bool(o.data.uv_layers) for o in meshes); actions=sorted(a.name for a in bpy.data.actions)
    screenshot=render(path,objects)
    return {"path":str(path),"bytes":path.stat().st_size,"objects":len(objects),"mesh_objects":len(meshes),"vertices":vertices,"triangles":triangles,"materials":materials,"material_count":len(materials),"uv_meshes":uv_meshes,"armatures":len(armatures),"actions":actions,"screenshot":str(screenshot)}

def main():
    paths=[Path(x) for x in sys.argv[sys.argv.index("--")+1:]] if "--" in sys.argv else []
    results=[]
    for p in paths:
        try: results.append(inspect(p))
        except Exception as exc: results.append({"path":str(p),"error":f"{type(exc).__name__}: {exc}"})
    OUT.mkdir(parents=True,exist_ok=True); (OUT/"blender-validation.json").write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding="utf-8"); print(json.dumps(results,ensure_ascii=False))

if __name__ == "__main__": main()
