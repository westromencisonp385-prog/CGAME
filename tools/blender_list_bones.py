import bpy,sys
from pathlib import Path
p=Path(sys.argv[sys.argv.index('--')+1]); bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.fbx(filepath=str(p))
for o in bpy.context.scene.objects:
 if o.type=='ARMATURE':
  print('ARMATURE',o.name)
  for b in o.data.bones: print('BONE',b.name)
