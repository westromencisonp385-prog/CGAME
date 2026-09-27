# Reclaimer model samples

This folder contains an original, low-poly 3D sample for the first G1 art slice:

- `reclaimer_whale_jaw.glb` is the Godot import candidate.
- `../../../docs/assets/model-sources/reclaimer_whale_jaw.blend` is the editable Blender 5.2.1 LTS source.
- `reclaimer_whale_jaw_preview.png` is a three-quarter top-down inspection render.
- `source/generate_reclaimer_whale_jaw.py` is the reproducible generator.
- `manifest.json` records the generation tool, asset IDs, palette, and hashes.

The sample is deliberately limited to presentation requirements P-04 and P-05. It
does not replace the current gameplay whitebox and it does not make F-05
authoritative. `Jaw_Socket`, `Jaw_ContactPoint`, and `Jaw_VFX_FieldOrigin` are
visual integration points for a later Godot scene.

The design language follows the project's original direction: engineering yellow,
oil blue, bone white, coral warning marks, broad readable volumes, restrained
materials, and visible mechanical pivots. It is inspired by the extracted
reference's layered module structure and stylized color blocking, with newly
modeled geometry and materials.
