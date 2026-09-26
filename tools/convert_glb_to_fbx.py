import bpy, sys
from pathlib import Path
src=Path(sys.argv[sys.argv.index('--')+1]); dst=Path(sys.argv[sys.argv.index('--')+2]); bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(src)); bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type=='MESH': o.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(dst),use_selection=True,object_types={'MESH'},bake_anim=False,apply_scale_options='FBX_SCALE_ALL')
print(dst)
