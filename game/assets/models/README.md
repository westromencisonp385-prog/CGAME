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

## G1 visual candidates

`g1/enemy_b01_reverse_crab_authored.glb` and
`g1/facility_c04_repair_pump_authored.glb` are the authored B01/C04 samples
copied from `artifacts/weaver/authored/`. `EnemyDummy` loads the B01 sample for
the first formal light enemy (`crawler_a`), while `EngineeringTarget` loads the
C04 sample for the repair target. Both paths are presentation-only: procedural
state, collision, hit points, interaction and save data remain authoritative.
They are G1 candidates and still require a real-GPU visual review; loading and
headless tests do not certify final art quality.
