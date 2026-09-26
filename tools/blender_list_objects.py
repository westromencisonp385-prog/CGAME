import bpy, sys
from pathlib import Path
path=Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path)) if path.suffix.lower()=='.glb' else bpy.ops.import_scene.fbx(filepath=str(path))
for o in bpy.context.scene.objects:
    if o.type in {'MESH','EMPTY'}:
        print(o.type, o.name, 'parent=',o.parent.name if o.parent else '', 'loc=',tuple(round(x,3) for x in o.location), 'scale=',tuple(round(x,3) for x in o.scale))
