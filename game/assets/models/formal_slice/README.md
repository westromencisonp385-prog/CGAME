# G1 formal slice asset candidates

This directory contains the first **author-created** A01/B01/C04 3D candidate
pack. It is generated from `source/generate_g1_formal_slice.py` with the pinned
Blender executable and is intentionally separate from the old whitebox and
`reclaimer_whale_jaw.glb` sample.

The concept boards are used as visual truth for silhouette, colour blocking,
mechanical pivots, and action readability:

- `docs/assets/2d-candidates/A01-whale-jaw-reclaimer.png`
- `docs/assets/2d-candidates/B01-reverse-crab.png`
- `docs/assets/2d-candidates/C04-repair-pump-cutaway.png`

The GLBs are **candidate** assets. They have explicit state layers, gameplay
sockets, LOD contracts, and collision-collection contracts, but they are not
yet `integrated` or `final`. Godot camera, runtime LOD, collision, and
prepare-contact-aftermath animation still need their G1 checks.

Outputs:

- `a01_whale_jaw_formal.glb` — magnetic whale-jaw player machine.
- `b01_reverse_crab_formal.glb` — sideways-charge barricade enemy.
- `c04_repair_pump_formal.glb` — broken/repair/restored facility candidate.
- `g1_formal_slice_preview.png` — Blender three-quarter review render.
- `a01_whale_jaw_formal_preview.png`, `b01_reverse_crab_formal_preview.png`,
  `c04_repair_pump_formal_preview.png` — individual review renders.
- `painted_surface_atlas.png` — deterministic hand-painted paint/chip/hazard
  atlas reserved for the next UV/material pass.
- `manifest.json` — hashes, Blender version, concept sources, mechanisms, and
  remaining acceptance gates.

Import passed in Godot **4.7.2 stable**, Mobile. The current actual Blender
runtime is **5.2.2 LTS**, recorded in the manifest. A01 exports separate upper
and lower jaw prepare/contact/aftermath animation actions; these are cosmetic
candidates and do not control gameplay results.

No extracted Wanderburg geometry, old whitebox mesh, generated model service
output, or baked concept-board text is included.

The atlas is an authored texture input, but is not yet bound to the GLB
materials. The current candidate intentionally keeps controlled PBR blocks so
silhouette and mechanism remain readable while the UV/damage-state pass is
reviewed.
