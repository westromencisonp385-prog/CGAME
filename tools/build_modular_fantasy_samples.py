"""Original editable modular fantasy candidates. Run with Blender --background --python.

No third-party mesh inputs. Geometry, assembly contracts and keyed mechanical motion
are deliberately authored here; no claim of game integration or final art approval.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/assets/modular-fantasy-v1"
sys.path.insert(0, str(ROOT / "tools"))
from generate_style_locked_assets import clean, action, export

PI = math.pi
PALETTE = {
    "petrol": "253F48", "ochre": "E5AD39", "bone": "EADFC2",
    "tomato": "D9533D", "ink": "14272E", "steel": "708F91",
    "mint": "79C9B5", "violet": "A597C9", "glass": "132E39",
}
parts = []
root = None


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    # Blender stores linear color; using sRGB literals directly washes out the palette.
    rgb = [int(PALETTE[name][i:i+2], 16) / 255 for i in (0, 2, 4)]
    rgb = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = .84
    bs.inputs["Metallic"].default_value = 0
    return m


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.parent = parent
    o.empty_display_size = .16
    return o


def assembly(name, loc, stage, axis, limits, purpose, removed, power, explode):
    o = empty(name, loc, root)
    o["minimum_stage"] = stage
    o["purpose"] = purpose
    o["rotation_axis"] = axis
    parts.append({"name": name, "minimum_stage": stage, "pivot_m": list(loc),
                  "motion_axis_local": axis, "limits": limits,
                  "purpose": purpose, "removal_consequence": removed,
                  "power_input": power, "exploded_offset_m": list(explode)})
    empty("socket_" + name, loc, root)["accepts"] = name
    return o


def mesh(name, verts, faces, color, parent, bevel=.025):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    me.materials.append(mat(color))
    if bevel:
        mod = o.modifiers.new("Painted edge chamfer", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return o


def box(name, loc, size, color, parent, bevel=.045):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.parent = parent
    o.location = loc
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat(color))
    if bevel:
        mod = o.modifiers.new("Functional edge chamfer", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return o


def cylinder(name, loc, radius, length, color, parent, axis="Z", vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length)
    o = bpy.context.object
    o.name = name
    o.parent = parent
    o.location = loc
    o.rotation_euler = {"X": (0, PI/2, 0), "Y": (PI/2, 0, 0), "Z": (0, 0, 0)}[axis]
    o.data.materials.append(mat(color))
    bevel = o.modifiers.new("Machined rim", "BEVEL")
    bevel.width = .025
    bevel.segments = 1
    return o


def beam(name, start, end, radius, color, parent):
    a, b = Vector(start), Vector(end)
    o = cylinder(name, (a+b)/2, radius, (b-a).length, color, parent, vertices=10)
    o.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return o


def panel(name, points, depth, color, parent):
    # Authored side silhouette extruded through local Y; polygon order is X/Z.
    n = len(points)
    verts = [(x, y, z) for y in (-depth/2, depth/2) for x, z in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    return mesh(name, verts, faces, color, parent)


def arc(name, center, radius, width, depth, start, end, color, parent, steps=32, plane="XZ"):
    verts = []
    for i in range(steps+1):
        a = start + (end-start)*i/steps
        for r, d in ((radius-width/2, -depth/2), (radius+width/2, -depth/2),
                     (radius+width/2, depth/2), (radius-width/2, depth/2)):
            if plane == "XZ":
                p = (center[0]+r*math.cos(a), center[1]+d, center[2]+r*math.sin(a))
            elif plane == "YZ":
                p = (center[0]+d, center[1]+r*math.cos(a), center[2]+r*math.sin(a))
            else:
                p = (center[0]+r*math.cos(a), center[1]+r*math.sin(a), center[2]+d)
            verts.append(p)
    faces = [(3, 2, 1, 0), tuple(range(steps*4, steps*4+4))]
    for i in range(steps):
        for j in range(4):
            faces.append((i*4+j, i*4+(j+1)%4, (i+1)*4+(j+1)%4, (i+1)*4+j))
    return mesh(name, verts, faces, color, parent, .018)


def keys(obj, clip, channel, values):
    base = obj.location.copy(), obj.rotation_euler.copy()
    frames = []
    for frame, val in values:
        loc, rot = base[0].copy(), base[1].copy()
        if channel.startswith("r"):
            rot["xyz".index(channel[1])] += math.radians(val)
        else:
            loc["xyz".index(channel[1])] += val
        frames.append((frame, tuple(loc), tuple(rot)))
    action(obj, clip, frames)
    obj.animation_data.nla_tracks[-1].mute = True


def cab(parent, loc, size=1):
    c = empty("Driver_Cab", loc, parent)
    c.scale = (size,)*3
    panel("Cab_CantedShell", [(-.5, 0),(.46, 0),(.6,.7),(.22,1.1),(-.5,.96)], .82, "ochre", c)
    for side in (-1, 1):
        w = panel("Cab_Glass", [(-.34,.38),(.41,.38),(.39,.68),(.14,.9),(-.34,.81)], .025, "glass", c)
        w.location.y = side*.425
        box("Window_Mullion", (.02,side*.45,.63), (.055,.04,.47), "bone", c, .008)
    box("Cab_WeatherVisor", (0,0,1.04), (1.14,1.03,.10), "bone", c)
    cylinder("Beacon_Base", (-.28,0,1.15), .10,.12,"ink",c)
    cylinder("Beacon", (-.28,0,1.24), .085,.10,"tomato",c)
    return c


def make_whale():
    core = assembly("Reactor_Cradle", (0,0,2.45),1,"fixed",[0,0],"Compression chamber and physical hoop axle","No energy distribution","fuel cell → mechanical bus",(0,0,0))
    panel("Keel_ArmoredSpine", [(-2,-.8),(1.9,-.8),(2.3,-.3),(1.6,.15),(-1.4,.32),(-2.3,-.25)],1.3,"petrol",core)
    cylinder("Heart_PressureVessel", (.8,0,.1),.62,1.7,"ochre",core,"X")
    for x in (.08,.8,1.52):
        arc("PressureVessel_Band",(x,0,.1),.65,.10,.12,0,2*PI,"bone",core,plane="YZ")
    cab(core, (.8,-.15,.7), .9)
    for sign in (-1,1):
        pod=assembly("DrivePod_"+str(sign),(1,sign*1.65,.75),1,"Z",[-25,25],"Paired radial ground rollers; differential steering","Lose turning authority on this side","mechanical bus → half shaft",(0,sign*1.4,-.2))
        panel("DrivePod_Shell", [(-1.4,-.05),(1.3,-.05),(1.5,.55),(.8,.9),(-.95,.72)],.75,"petrol",pod)
        for x in (-.8,0,.8):
            cylinder("Drive_Roller",(x,sign*.45,.02),.45,.28,"ink",pod,"Y")
            cylinder("Drive_Hub",(x,sign*.61,.02),.22,.035,"ochre",pod,"Y")
        beam("Drive_LoadArm",(0,-sign*.1,.5),(0,-sign*1.1,1.05),.13,"steel",pod)
        keys(pod,"idle","rz",[(1,-1),(32,1),(64,-1)])
    # Two sculpted jaw shells share an actual rear hinge and preserve open negative space.
    for upper in (False,True):
        sign=1 if upper else -1
        jaw=assembly("Upper_Jaw" if upper else "Lower_Jaw",(.25,0,2.55),1,"Y",[-28,28],"Curved shell guides scrap through open mouth","Cannot seal/compress mixed load","reactor → jaw ram",(-1.2,0,sign*1.5))
        points=[(0,.10*sign),(-.8,.72*sign),(-2.25,1.45*sign),(-3.3,1.25*sign),(-3.6,.88*sign),(-2.5,.98*sign),(-1.4,.43*sign)]
        shell=panel("Jaw_SweptOuterShell",points,1.68,"ochre" if upper else "petrol",jaw)
        for side in (-1,1):
            p=panel("Jaw_EdgeRail",[(x,z) for x,z in points],.075,"bone",jaw)
            p.location.y=side*.88
            for i in range(4):
                x=-1.25-i*.48; z=sign*(.49+i*.145)
                tooth=panel("Replaceable_MagnetTooth",[(x,z),(x-.30,z+sign*.10),(x-.33,z-sign*.25),(x-.1,z-sign*.28)],.16,"bone",jaw)
                tooth.location.y=side*.61
        cylinder("Jaw_PivotBearing",(0,0,0),.34,2.15,"tomato",jaw,"Y")
        keys(jaw,"attack","ry",[(1,0),(14,-sign*22),(24,sign*8),(38,0),(60,0)])
        keys(jaw,"deploy","ry",[(1,sign*12),(45,-sign*8),(60,0)])
    hoop=assembly("Gimbal_MagneticHoop",(.55,0,3.25),2,"X",[-35,35],"Open hoop suspends payload away from wheels","Lose orbiting hold; direct jaw still works","reactor → paired trunnion coils",(0,0,2.3))
    arc("Hoop_MainShell",(0,0,0),2.22,.30,.32,0,2*PI,"petrol",hoop,48,"YZ")
    arc("Hoop_LaminatedInnerRail",(-.19,0,0),2.03,.07,.10,0,2*PI,"bone",hoop,48,"YZ")
    for i in range(8):
        a=i*PI/4
        arc("CoilSegment",(0,0,0),2.25,.42,.5,a+.06,a+.32,"ochre" if i%2 else "tomato",hoop,4,"YZ")
    beam("Hoop_TrunnionAxle",(0,-2.3,0),(0,2.3,0),.10,"steel",hoop)
    # Split axle stays outside central aperture, not a solid spoke through the negative shape.
    bpy.data.objects.remove(bpy.data.objects["Hoop_TrunnionAxle"],do_unlink=True)
    for y in (-2.25,2.25):
        cylinder("Gimbal_Trunnion",(0,y,0),.26,.50,"tomato",hoop,"Y")
    keys(hoop,"idle","rx",[(1,-5),(32,5),(64,-5)])
    keys(hoop,"attack","rx",[(1,0),(14,24),(24,-18),(44,0),(60,0)])
    rear=assembly("Rear_PressurePress",(2.5,0,2.4),3,"X translation",[-.35,.6],"Rear press turns held mass into launchable bale","Lose high-mass compression and recoil brake","pressure vessel → paired press cylinders",(2,0,0))
    for side in (-1,1):
        beam("Press_RamBarrel",(-.7,side*.63,0),(.4,side*.63,0),.21,"ochre",rear)
        beam("Press_RamRod",(.3,side*.63,0),(1.1,side*.63,0),.10,"bone",rear)
    panel("Press_RibbedBackplate",[(.7,-.8),(1.18,-.65),(1.25,.85),(.6,1.1)],1.5,"tomato",rear)
    for z in (-.45,0,.45): box("Press_CoolingSlat",(1.28,0,z),(.12,1.8,.10),"ink",rear,.02)
    keys(rear,"attack","lx",[(1,0),(14,.5),(24,-.3),(40,0),(60,0)])
    for side in (-1,1):
        fin=assembly("Stabilizer_"+str(side),(.4,side*1.4,2.1),3,"X",[-45,45],"Deployable lateral brace catches press recoil","Cannot fire heavy bale while turning","hydraulic bus → lateral wing hinge",(0,side*1.8,.4))
        wing=panel("Swept_StabilizerBlade",[(-1.15,0),(.9,.15),(.2,1.0),(-.8,.6)],.13,"bone",fin)
        wing.rotation_euler.x=side*PI/2
        wing.location.y=side*.65
        cylinder("Fin_LockPin",(0,0,0),.23,.45,"tomato",fin,"X")
        keys(fin,"deploy","rx",[(1,side*50),(36,0),(60,0)])


def make_titan():
    gate=assembly("Gate_LoadFrame",(0,0,3.65),1,"fixed",[0,0],"Two side columns carry the lintel; aperture stays clear","No closed load path","foot generator → lintel bus",(0,0,0))
    for sign in (-1,1):
        p=panel("Gate_SplayedColumn",[(sign*.77,-1.15),(sign*1.22,-1.22),(sign*1.4,1.4),(sign*.84,1.72)],.65,"petrol",gate)
        box("Column_InnerTrim",(sign*.87,-.355,.22),(.09,.06,2.5),"bone",gate,.01)
    panel("Gate_CrownedLintel",[(-1.4,1.3),(1.4,1.3),(1.12,1.96),(.1,2.17),(-1.2,1.89)],.90,"ochre",gate)
    for sign in (-1,1):
        cylinder("Lintel_HingeCap",(sign*1.35,0,1.3),.28,1.12,"tomato",gate,"Y")
        leg=assembly("Telescopic_Leg_"+str(sign),(sign*.98,0,2.5),1,"Z translation",[-.25,.55],"Independent piston leg steps across debris","One support lost; brace needed to swing hammer","lintel bus → leg pump",(sign*1.1,0,-.8))
        box("Leg_OuterSlide",(0,0,-.55),(.52,.60,1.2),"ochre",leg)
        box("Leg_ExposedRam",(0,0,-1.23),(.23,.30,.75),"steel",leg)
        cylinder("Ankle_Pin",(0,0,-1.60),.25,.86,"tomato",leg,"Y")
        panel("Foot_SplitShoe",[(-.53,-2.1),(.72,-2.1),(.82,-1.7),(.05,-1.54),(-.46,-1.8)],1.12,"petrol",leg)
        box("Toe_ContactPad",(.48,-.02,-2.10),(.6,1.2,.13),"bone",leg)
        keys(leg,"idle","lz",[(1,0),(32,.06*sign),(64,0)])
        keys(leg,"deploy","lz",[(1,.4),(35,0),(60,0)])
    cab(gate,(-.58,-.7,1.55),.65)
    left=assembly("Shield_FoldingWing",(-1.48,0,4.62),2,"Z",[-15,105],"Accordion shield locks into side wall","Left flank exposed; no deployable cover","lintel bus → wing hinge",(-2.1,0,.2))
    panel("Shield_FirstFold",[(0,.2),(-1.15,.72),(-2.3,.45),(-2.05,-1.9),(-1.30,-2.25),(-.48,-1.6)],.20,"ochre",left)
    for y in (-.135,.135):
        p=panel("Shield_FoldedFacet",[(-.25,-.18),(-1.15,.46),(-1.30,-2.02),(-.54,-1.46)],.055,"bone",left);p.location.y=y
        p=panel("Shield_DiagonalScar",[(-1.43,.35),(-1.73,.27),(-1.89,-1.64),(-1.64,-1.73)],.06,"tomato",left);p.location.y=y*1.2
    cylinder("Shield_LongHinge",(-.05,0,-.55),.16,2.45,"ink",left,"Z")
    keys(left,"deploy","rz",[(1,70),(45,0),(60,0)])
    right=assembly("Counterweight_Pennant",(1.35,0,4.8),2,"X",[-60,15],"Short opposite wing balances large folding shield","Pitch recovery worsens after blocks","lintel bus → counterweight hinge",(1.5,0,1))
    panel("Counterweight_Arrow",[(0,0),(.65,.30),(1.75,-.2),(1.35,-.55),(.62,-.45),(.45,-1.3),(.02,-.82)],.35,"bone",right)
    cylinder("Counterweight_Pivot",(0,0,0),.29,.9,"tomato",right,"Y")
    keys(right,"deploy","rx",[(1,-50),(45,0),(60,0)])
    hammer=assembly("Hammer_Pendulum",(1.5,-.55,4.7),3,"Y",[-95,30],"Huge hinged hammer folds behind the gate and swings outside aperture","No siege impact; shield build remains mobile","lintel reservoir → hammer torque axle",(2.1,-.6,.5))
    beam("Hammer_MainLever",(0,0,0),(1.85,0,-1.72),.18,"petrol",hammer)
    beam("Hammer_TensionLink",(.15,.18,0),(2.05,.18,-1.52),.065,"bone",hammer)
    head=panel("Hammer_WedgeHead",[(1.4,-1.4),(2.43,-1.16),(3,-1.78),(2.66,-2.45),(1.42,-2.52),(1.12,-2.05)],1.22,"tomato",hammer)
    panel("Hammer_ContactShoe",[(2.62,-1.46),(3.1,-1.75),(2.8,-2.53),(2.39,-2.65)],1.38,"bone",hammer)
    cylinder("Hammer_TorqueAxle",(0,0,0),.40,1.1,"ochre",hammer,"Y")
    keys(hammer,"attack","ry",[(1,0),(15,-80),(24,28),(32,20),(54,0),(60,0)])
    keys(hammer,"idle","ry",[(1,0),(32,2),(64,0)])
    rear=assembly("Reservoir_Backpack",(0,.65,4.1),3,"fixed",[0,0],"Two accumulator cylinders recharge a single hammer strike","Long hammer recharge, no chained smash","leg pumps → accumulators → torque axle",(0,1.65,.4))
    for sign in (-1,1):
        cylinder("Accumulator",(sign*.5,.3,.10),.32,1.7,"ochre",rear)
        for z in (-.5,.5): arc("Accumulator_Strap",(sign*.5,.3,z),.34,.07,.09,0,2*PI,"ink",rear,16,"XY")
    beam("Reservoir_Crossfeed",(-.5,.3,.95),(.5,.3,.95),.12,"tomato",rear)


def make_worm():
    # Every segment is independent: their curved rest arrangement is inspectable and reversible.
    coordinates=[(-3.0,0,1.05),(-1.5,.42,1.15),(0,.1,1.32),(1.4,-.58,1.35),(2.85,-.55,1.2),(4.15,.08,.98)]
    for i, pos in enumerate(coordinates):
        stage = 1 if i<2 else 2 if i<4 else 3
        seg=assembly(f"Spine_Segment_{i:02d}",pos,stage,"Z",[-32,32],"Articulated spine transfers torque and bends around obstacles","Tail beyond this socket detaches; drill still runs at lower sustained torque","front motor" if i==0 else f"Spine_Segment_{i-1:02d} → spline coupling",(i*.40,(-1 if i%2 else 1)*1.4,.25))
        seg.rotation_euler.z = [.15,.07,-.29,-.19,.25,.36][i]
        cylinder("Spline_Core",(0,0,0),.43,1.65,"ink",seg,"X")
        # Faceted clamshell armor is open underneath for maintenance and articulated movement.
        arc("Segment_ArchShell",(0,0,0),.8,.23,1.05,-.23,PI+.23,"ochre" if i%2==0 else "petrol",seg,12,"YZ")
        arc("Segment_Rim",(-.57,0,0),.81,.09,.095,-.24,PI+.24,"bone",seg,12,"YZ")
        collar=empty(f"Gimbal_Collar_{i:02d}",(.65,0,0),seg)
        collar["joint_axis"]="X roll ±18 degrees"
        arc("Collar_OuterRing",(0,0,0),.6,.16,.22,0,2*PI,"tomato",collar,20,"YZ")
        for side in (-1,1):
            cylinder("Collar_Trunnion",(0,side*.66,0),.13,.20,"bone",collar,"Y")
            fin=panel("DriveFin",[(-.45,-.32),(.42,-.32),(.70,-.98),(.1,-1.08),(-.60,-.76)],.12,"petrol" if i%2==0 else "ochre",seg)
            fin.location.y=side*.68
            fin.rotation_euler.x=side*math.radians(30)
            beam("Fin_DriveLink",(-.22,side*.52,-.28),(.12,side*1.08,-.75),.07,"steel",seg)
        keys(seg,"idle","rz",[(1,-2),(32,2),(64,-2)])
        keys(seg,"attack","rz",[(1,0),(12,-8 if i%2 else 8),(24,8 if i%2 else -8),(45,0),(60,0)])
        keys(collar,"idle","rx",[(1,-8),(32,8),(64,-8)])
        if i==1: cab(seg,(-.1,-.15,.65),.68)
        if i in (2,4):
            cylinder("Torque_Flywheel",(0,0,.87),.40,.18,"tomato",seg,"Z")
            box("Flywheel_Hood",(.1,0,1.10),(.7,.75,.13),"bone",seg)
    drill=assembly("Front_FlutedDrill",(-3.9,0,1.1),1,"X",[0,360],"Three continuous helical cutting flights pull debris into flutes","Cannot penetrate; segmented body remains a carrier","front motor → axial chuck",(-2,0,0))
    # Conical three-start helicoid, solid thickness, not a stack of decorative disks.
    cylinder("Drill_Chuck",(.1,0,0),.58,.45,"tomato",drill,"X")
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.03,radius2=.52,depth=2.15)
    o=bpy.context.object;o.name="Drill_TaperedCore";o.parent=drill;o.location=(-1.0,0,0);o.rotation_euler.y=PI/2;o.data.materials.append(mat("petrol"))
    for flight in range(3):
        verts=[]
        for i in range(49):
            t=i/48; x=-2.10+2.15*t; angle=t*PI*2.05+flight*PI*2/3
            r=.07+.80*t
            for inner, offset in ((True,-.045),(False,-.045),(False,.045),(True,.045)):
                radius=r*(.54 if inner else 1)
                verts.append((x+offset,math.cos(angle)*radius,math.sin(angle)*radius))
        faces=[(3,2,1,0),(192,193,194,195)]
        for i in range(48):
            for j in range(4):faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
        mesh("HelicalCuttingFlight",verts,faces,"bone" if flight==0 else "ochre",drill,.013)
    keys(drill,"attack","rx",[(1,0),(12,40),(36,540),(60,720)])
    keys(drill,"idle","rx",[(1,0),(64,60)])
    tail=assembly("Tail_AnchorCrown",(4.75,.25,1.0),3,"X",[-30,30],"Split tail anchor resists drill torque while turning","No planted drilling mode; recoil slides the body","last spine spline → differential tail brace",(1.7,.2,.4))
    for side in (-1,1):
        p=panel("Tail_SplitAnchor",[(-.2,.35),(.7,1.05),(1.35,.90),(.98,.32),(.45,-.2)],.18,"tomato",tail);p.location.y=side*.45;p.rotation_euler.x=side*.45
    cylinder("Tail_TorqueJoint",(0,0,0),.35,.65,"bone",tail,"X")
    keys(tail,"deploy","rx",[(1,-25),(40,20),(60,0)])


def descendants(o):
    return [o]+[child for c in o.children for child in descendants(c)]


def render_setup(bounds):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=40
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1400;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="Standard"
    scene.view_settings.look="Medium High Contrast" if "Medium High Contrast" in [x.name for x in scene.view_settings.bl_rna.properties['look'].enum_items] else "None"
    scene.view_settings.exposure=0;scene.view_settings.gamma=1
    scene.world.color=(.17,.17,.17)
    low,high=bounds
    center=(low+high)/2
    extent=max(high.x-low.x,high.y-low.y,high.z-low.z)
    bpy.ops.object.camera_add(location=center+Vector((-extent*1.05,-extent*1.35,extent*.86)))
    camera=bpy.context.object;camera.name="Review_Camera"
    camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO";camera.data.ortho_scale=extent*1.38;scene.camera=camera
    for name,loc,power,size in [("Warm_Key",(-6,-8,12),1800,7),("Cool_Fill",(6,-3,8),900,6),("Rim",(3,7,11),2000,6)]:
        bpy.ops.object.light_add(type="AREA",location=loc)
        light=bpy.context.object;light.name=name;light.data.energy=power;light.data.shape="DISK";light.data.size=size
        light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
    floor=box("Review_Floor",(center.x,center.y,low.z-.12),(200,200,.15),"bone",None,0)
    floor.data.materials.clear()
    m=bpy.data.materials.new("Review_Backdrop");m.diffuse_color=(.115,.155,.17,1);m.use_nodes=True;m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.115,.155,.17,1);m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=1;floor.data.materials.append(m)
    return camera


def bounds_of(objects):
    bpy.context.view_layer.update()
    vs=[o.matrix_world @ Vector(corner) for o in objects if o.type=="MESH" for corner in o.bound_box]
    return Vector(tuple(min(v[i] for v in vs) for i in range(3))),Vector(tuple(max(v[i] for v in vs) for i in range(3)))


def produce(asset_id, builder):
    global root,parts
    clean();parts=[]
    root=empty(asset_id)
    root["status"]="candidate"
    root["forward_axis"]="-X Blender / -X glTF"
    root["units"]="meters"
    builder()
    # Exploded motion follows the same detachable assembly roots used by manifests.
    for p in parts:
        obj=bpy.data.objects[p["name"]]
        base=obj.location.copy();rot=obj.rotation_euler.copy();end=base+Vector(p["exploded_offset_m"])
        action(obj,"exploded",[(1,tuple(base),tuple(rot)),(60,tuple(end),tuple(rot))])
        obj.animation_data.nla_tracks[-1].mute=True
    visuals=[o for o in descendants(root) if o.type=="MESH"]
    # Each mesh gets a deterministic projectable UV map for paintover; no fake painted textures.
    bpy.ops.object.select_all(action="DESELECT")
    for o in visuals:o.select_set(True)
    bpy.context.view_layer.objects.active=visuals[0]
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode="OBJECT")
    low,high=bounds_of(visuals)
    proxies=empty("Collision_Proxies",parent=root)
    for p in parts:
        obj=bpy.data.objects[p["name"]]
        geom=[o for o in descendants(obj) if o.type=="MESH"]
        a,b=bounds_of(geom)
        proxy=box("COL_"+p["name"],(a+b)/2,b-a,"ink",proxies,0)
        proxy.hide_render=True;proxy.display_type="WIRE";proxy["collision_only"]=True
        p["collision_proxy"]=proxy.name
    # Export only visual and socket descendants; proxies remain editable in .blend.
    proxies.parent=None
    for obj in descendants(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:track.mute=False
    export(root,OUT/(asset_id+".glb"))
    for obj in descendants(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:track.mute=True
    bpy.context.scene.frame_set(1)
    camera=render_setup((low,high))
    scene=bpy.context.scene
    scene.render.filepath=str(OUT/(asset_id+"_assembled.png"));bpy.ops.render.render(write_still=True)
    # Store growth proof at fixed scale/camera: new silhouettes come from added assemblies.
    for stage in (1,2):
        for p in parts:
            for obj in descendants(bpy.data.objects[p["name"]]):obj.hide_render=p["minimum_stage"]>stage
        scene.render.filepath=str(OUT/(asset_id+f"_stage_{stage}.png"));bpy.ops.render.render(write_still=True)
    for p in parts:
        for obj in descendants(bpy.data.objects[p["name"]]):obj.hide_render=False
    for p in parts:bpy.data.objects[p["name"]].location+=Vector(p["exploded_offset_m"])
    camera.data.ortho_scale*=1.28
    scene.render.filepath=str(OUT/(asset_id+"_exploded.png"));bpy.ops.render.render(write_still=True)
    for p in parts:bpy.data.objects[p["name"]].location-=Vector(p["exploded_offset_m"])
    camera.data.ortho_scale/=1.28
    bpy.ops.object.select_all(action="DESELECT");root.select_set(True);bpy.context.view_layer.objects.active=root
    proxies.parent=root
    scene.frame_start=1;scene.frame_end=64
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(asset_id+".blend")))
    tris=sum(len(poly.vertices)-2 for o in visuals for poly in o.data.polygons)
    manifest={"asset_id":asset_id,"status":"candidate","authoring":"original procedural authored geometry; no external meshes",
              "blender":bpy.app.version_string,"coordinate_system":"Blender Z up, forward -X, meters; glTF exporter converts to Y up",
              "requirements":["P006","P015","P022"],"mesh_count":len(visuals),"base_triangles":tris,
              "evaluated_triangles":sum(len(poly.vertices)-2 for o in visuals for poly in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.polygons),
              "materials":list(PALETTE),"uv_mesh_count":sum(bool(o.data.uv_layers) for o in visuals),
              "bounds_m":{"min":list(low),"max":list(high)},"assemblies":parts,
              "growth":"stage 1 foundation, stage 2 distinct middle assemblies, stage 3 full structure; no root scale change",
              "clips":["idle","attack","deploy","exploded"],"clip_notes":"NLA clips use independent assembly transforms. Sources save all tracks muted for inspection. Colliders are in blend only; engine must build physics bodies from proxies.",
              "quality_state":"Structural candidate, actual render inspected separately. Not approved final art; no Godot collision/LOD/performance acceptance.",
              "limits":["Flat authored material zones with UVs, no hand-painted texture maps yet","No deforming skin or IK; rigid mechanical clips","No damage variants or LODs","Physics and inter-component power behavior remain gameplay contracts, not simulated by this mesh"]}
    assert len(parts)>=7 and all(bpy.data.objects.get(p["name"]) for p in parts)
    assert manifest["uv_mesh_count"]==len(visuals)
    assert all(p["removal_consequence"] and p["power_input"] for p in parts)
    (OUT/(asset_id+"_manifest.json")).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    print("ASSET_COMPLETE",asset_id,len(visuals),manifest["evaluated_triangles"],flush=True)


if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    selected=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    for asset,builder in [("hoop_leviathan",make_whale),("origami_gate_titan",make_titan),("screw_worm",make_worm)]:
        if not selected or asset in selected:produce(asset,builder)
