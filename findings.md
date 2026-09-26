# Findings

- Repo is Wanderberg / Reclaimer, Godot 4.7.2 Mobile/Jolt. 3D formal production is currently gated by a 2D direction freeze, but the user has now authorized explicit self-selection and production.
- Current formal visual gate: G1 one player vehicle/whale-jaw stage, one enemy, one riverbank, one repair facility; G2 one complete comedy action and repair reversal.
- Current 3D/action requirements include P-04, P-05, P-06, P-07, P-08, P-09, P-12, P-13, plus F-05/F-06/F-12/F-14 action/event contracts.
- User supplied Weaver/VISVISE APPID and APPSECRET in chat. Secrets must remain process-local.
- User rejected the first smooth/grungy AI-like visual direction. Locked a stronger v1 style anchor: industrial folk low-poly, large asymmetric silhouette, matte five-color blocks, ink-like edge treatment, no generic industrial toy detailing. Anchor: docs/assets/style-anchor-industrial-folk-v1.png.
- Full 20-entry model/action inventory is in docs/assets/weaver-production-queue.json. G1 self-selection is A01 whale jaw, B01 reverse crab, C04 repair pump, river reversal biome, and prepare/contact/afterglow comedy sequence.
- Existing authored whale GLB is structurally stronger than the first Weaver high-model outputs: 109 objects, 67 meshes, 9,620 triangles, 7 materials, UV on all meshes. First Weaver high outputs were single-mesh, no UV, no animation, so they are rejected as final assets.
- Authored B01/C04 style anchors now exist at artifacts/weaver/authored/*.glb with Blender actions and low-poly material slots; Blender 5.2.1 validation report is artifacts/qa/weaver/blender-validation.json.
- New user credentials passed quota/algorithm read-only checks; production scripts must use process env overrides, never the old local appid.txt as the source of truth.
- Weaver boundary is now documented in docs/api/weaver-api-purpose.md. It is a specialized async service layer, not a final game-asset author. The first A01 candidate remained a single mesh/no UV/no action; B01/C04 authored GLBs successfully produced UV/LOD candidates, while B01 rigging failed with 992103 Input format error on GLB input.
