"""Create intentional low-poly B01 and C04 assets with real pivot animations.

These are authored style anchors. Weaver is used afterward for optional UV/LOD
and motion candidates; generated geometry is not allowed to replace the style
anchor without passing the same Blender/Godot checks.
"""
from __future__ import annotations
import bpy, math, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/"artifacts"/"weaver"/"authored"
PALETTE={"blue":(0.035,0.12,0.16,1),"yellow":(0.78,0.48,0.08,1),"cream":(0.82,0.76,0.62,1),"red":(0.80,0.12,0.08,1),"lilac":(0.48,0.31,0.78,1),"rubber":(0.02,0.025,0.03,1),"steel":(0.22,0.26,0.27,1),"water":(0.16,0.58,0.72,1)}

def clean():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
        for item in list(coll):
            if item.users==0: coll.remove(item)
    for item in list(bpy.data.actions):
        bpy.data.actions.remove(item, do_unlink=True)

def material(name):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=PALETTE[name]; m.use_nodes=True; bs=m.node_tree.nodes.get("Principled BSDF"); bs.inputs["Base Color"].default_value=PALETTE[name]; bs.inputs["Roughness"].default_value=0.86; bs.inputs["Metallic"].default_value=0.0; return m

def parent(obj, root): obj.parent=root; return obj

def cube(name,loc,scale,mat,root,bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material(mat)); parent(o,root)
    if bevel:
        mod=o.modifiers.new("wide intentional bevel","BEVEL"); mod.width=bevel; mod.segments=1
    return o

def cyl(name,loc,radius,depth,mat,root,rot=(0,0,0),verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc,rotation=rot); o=bpy.context.object; o.name=name; o.data.materials.append(material(mat)); parent(o,root); return o

def torus(name,loc,major,minor,mat,root,rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=12,minor_segments=6,location=loc,rotation=rot); o=bpy.context.object; o.name=name; o.data.materials.append(material(mat)); parent(o,root); return o

def empty(name,loc,root):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=loc; o.parent=root; o.empty_display_type="PLAIN_AXES"; o.empty_display_size=.2; return o

def action(obj,name,frames):
    a=bpy.data.actions.new(name); obj.animation_data_create(); obj.animation_data.action=a
    base_loc=obj.location.copy(); base_rot=obj.rotation_euler.copy()
    for f,loc,rot in frames:
        obj.location=Vector(loc); obj.rotation_euler=Vector(rot); obj.keyframe_insert("location",frame=f); obj.keyframe_insert("rotation_euler",frame=f)
    obj.location=base_loc; obj.rotation_euler=base_rot
    track=obj.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,1,a); strip.action_frame_start=frames[0][0]; strip.action_frame_end=frames[-1][0]; strip.frame_start=1; strip.frame_end=max(2,frames[-1][0]-frames[0][0]+1)
    obj.animation_data.action=None
    return a

def export(root,path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        cur=o
        while cur.parent is not None: cur=cur.parent
        if cur==root: o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_apply=True,export_animations=True,export_animation_mode="NLA_TRACKS",export_nla_strips=True,export_materials="EXPORT")

def make_crab():
    root=bpy.data.objects.new("Enemy_B01_ReverseCrab",None); bpy.context.collection.objects.link(root); root["asset_id"]="enemy.b01_reverse_crab"; root["style"]="industrial_folk_low_poly"
    body=cube("Chassis",(0,0,1.25),(1.35,.62,.48),"blue",root,.08)
    cube("Barrier_L",(-1.25,0,1.28),(.28,.70,.48),"cream",root,.05); cube("Barrier_R",(1.25,0,1.28),(.28,.70,.48),"cream",root,.05)
    cube("Barrier_Stripe_L",(-1.25,0,1.28),(.29,.72,.12),"red",root,.02); cube("Barrier_Stripe_R",(1.25,0,1.28),(.29,.72,.12),"red",root,.02)
    cyl("WarningBeacon",(0,0,2.2),.38,.32,"red",root,verts=12)
    legs=[]
    for side in (-1,1):
        for fore in (-1,1):
            y=fore*.45; x=side*1.18
            upper=cube(f"Leg_{'L' if side<0 else 'R'}_{'F' if fore>0 else 'B'}_Upper",(x,y,.86),(.16,.18,.48),"steel",root,.04); upper.rotation_euler.y=side*math.radians(18)
            foot=cube(f"Leg_{'L' if side<0 else 'R'}_{'F' if fore>0 else 'B'}_Foot",(side*1.45,y,.35),(.22,.25,.14),"cream",root,.03); legs.append(upper)
    cube("CountermeasureSocket",(0,-.66,1.25),(.30,.05,.22),"lilac",root,.02)
    for name,frames in {
        "enemy_idle":[(1,(0,0,0),(0,0,0)),(24,(0,0,.03),(0,0,math.radians(2))),(48,(0,0,0),(0,0,0))],
        "enemy_telegraph":[(1,(0,0,0),(0,0,0)),(18,(0,0,.08),(0,0,math.radians(-8))),(36,(0,0,0),(0,0,0))],
        "enemy_attack":[(1,(0,0,0),(0,0,0)),(12,(0,0,.1),(0,0,math.radians(-10))),(28,(1.25,0,.05),(0,0,math.radians(14))),(44,(0,0,0),(0,0,0))],
        "enemy_stagger":[(1,(0,0,0),(0,0,0)),(10,(-.12,0,.05),(0,0,math.radians(12))),(22,(.1,0,0),(0,0,math.radians(-8))),(36,(0,0,0),(0,0,0))],
        "enemy_engineering_countered":[(1,(0,0,0),(0,0,0)),(18,(0,0,.15),(0,math.radians(-12),0)),(42,(0,0,0),(0,0,0))],
        "enemy_defeat":[(1,(0,0,0),(0,0,0)),(30,(0,-.1,-.35),(math.radians(75),0,math.radians(18)))],
        "enemy_retreat":[(1,(0,0,0),(0,0,0)),(45,(-2.5,0,0),(0,0,0))]
    }.items(): action(root,name,frames)
    for socket in ("attack_origin","telegraph_origin","countermeasure_socket","hit_recoil_origin"): empty(socket,(0,0,1.2),root)
    path=OUT/"enemy_b01_reverse_crab_authored.glb"; export(root,path); return path

def make_pump():
    root=bpy.data.objects.new("Facility_C04_RepairPump",None); bpy.context.collection.objects.link(root); root["asset_id"]="facility.c04_repair_pump"; root["states"]="broken,repair_in_progress,restored"
    cube("PumpBody",(0,0,1.0),(1.0,.62,.85),"yellow",root,.10); cube("Base",(0,0,.18),(1.25,.8,.18),"steel",root,.05)
    for x in (-1.35,1.35): cyl("InletSocket" if x<0 else "OutletSocket",(x,0,.8),.42,.8,"water",root,rot=(0,math.pi/2,0)); torus("ValveWheel",(x*.78,0,1.55),.32,.07,"red",root,rot=(math.pi/2,0,0))
    cyl("PressureGauge",(-.65,-.66,1.75),.35,.12,"cream",root,rot=(math.pi/2,0,0)); torus("ReplaceableSeal",(0,-.67,1.0),.46,.10,"lilac",root,rot=(math.pi/2,0,0)); piston=cyl("PumpPiston",(0,-.02,1.0),.17,.72,"steel",root)
    cyl("Exhaust",(.55,0,2.05),.2,.38,"steel",root); empty("RepairInteract",(0,-.9,0.4),root); empty("FlowOrigin",(1.75,0,.8),root)
    action(piston,"pump_cough",[(1,(0,0,1),(0,0,0)),(8,(0,0,.72),(0,0,0)),(16,(0,0,1),(0,0,0))]); action(piston,"pump_repair",[(1,(0,0,1),(0,0,0)),(48,(0,0,1.4),(0,0,0))]); action(piston,"pump_flow",[(1,(0,0,1),(0,0,0)),(60,(0,0,.85),(0,0,0))])
    path=OUT/"facility_c04_repair_pump_authored.glb"; export(root,path); return path

def main():
    OUT.mkdir(parents=True,exist_ok=True); clean(); crab=make_crab(); clean(); pump=make_pump(); print(crab); print(pump)

if __name__=="__main__": main()
