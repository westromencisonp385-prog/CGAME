---
name: weaver-asset-production
description: "Use the VISVISE Weaver/VISVISE OpenAPI skill for 3D asset production workflows: HMAC-authenticated API calls, quota and algorithm discovery, COS temporary-credential uploads, asynchronous model submission and polling, signed downloads, resumable files, and schema-accurate request construction."
---

# Weaver asset production

Treat Weaver as a specialized asynchronous 3D service layer, not a final game-asset author. Image-to-3D produces a mesh candidate; UV, texture, LOD, rigging, skinning, and motion are separate jobs with separate input contracts. Preserve a human-authored style/structure control asset and accept an API result only after Blender and Godot checks prove that it keeps the required parts, pivots, materials, actions, and gameplay sockets.

Use the standard-library client in `scripts/weaver_api_client.py` for deterministic, auditable API calls. Keep `app_id` and `secret_key` in environment variables or a secret manager; pass the actual caller's `rtx` on every request. Do not print credentials, signed URLs, request headers, or response bodies containing temporary secrets.

## Proven production parameters (2026-10-07 P1 batch, all verified)

- Mid-model (`node_type=11`) via **explicit `input_view`** (four URLs from a finished 360 task). Do NOT use `params.image_gen_model_params.model_id_360`: server-side meshgen fails with `990017 findModelPath err: file not found`.
- Output format must be **`fbx`** (`output_model_format`). `glb` reliably triggers `990017` on `VV-MeshGen-V1.5.0`; convert to GLB later in Blender/Godot if needed.
- 360 multiview (`gen_multi_views`) with `Hy3D-MultiView-v3.0` completes in ~45-60s per asset; mid-model takes ~10-12 min. Quota cost per asset: 2 model tasks.
- **130400 "主体占比值低于阈值"** at the 360 stage means the input image's subject is too small. Multi-panel design sheets (front/side/action collage) fail; crop a single-view panel with the subject filling >60% of the frame before uploading (see `tools/asset_pipeline/crop_subject.py` and the B01 case).
- Mid-model output is geometry-only (no materials) - PBR texturing is a separate `node_type=8` job.
- Headless verification: `blender.exe --background --python blender_verify.py -- <model> <preview.png>` prints a STATS_JSON line (mesh/vert/tri counts, dims) and renders a Workbench preview; A01/B01/C04 landed at 28k-38k tris, single mesh, clean silhouettes.
- Working end-to-end runner: `tools/asset_pipeline/weaver_p1_batch.py` (batch) + `tools/asset_pipeline/weaver_mid_retry.py` (retry mid-model from a finished 360 task). Artifacts + manifests land in `artifacts/ai_candidates/<asset>/weaver/`.

## Style v3 (2026-10-08): 3D must match the key art and UI v2

1. Restyle every concept first: `tools/asset_pipeline/style_v3_concepts.py` (TiMi multi-image edit of [concept, `docs/assets/style-anchor-industrial-folk-v1.png`]) -> `artifacts/weaver/inputs_v3/<ID>-v3.png`. Same design and parts; chunky faceted slabs, matte cel blocks, shared six-color palette, no rust/grime/bolts.
2. Produce: `tools/asset_pipeline/weaver_v3_batch.py --asset <IDs>` (fresh 360 from the v3 concept, split, joint mid, texture at 1024, rig, install). Part plans live in `tools/asset_pipeline/v3_parts_plan.py`.
3. Never ask the 2D split for both sides of a mirrored pair (the far side is hidden and the VLM QC stalls ~15 min). Ask for one combined part (`WingsAll`, `RingsAll`, `ShieldsAll`, `LegsAll`); `blender_joint_rig.py` splits it into `_L/_R` or individual `Leg_N`.
4. Runtime style layer `scripts/systems/rig_style.gd` (applied in `ProceduralRig.attach`): no metal/normal/specular, toon diffuse, ink outline next_pass sized per mesh scale.

## Componentization rule (user decision 2026-10-08, mandatory)

Any asset that needs moving parts (enemies, bosses, player forms, modules, animated props) is produced **part by part**:

1. Plan the part list and pivots first (legs, treads, tool arm, jaw, wings, shields, rings, rotor, door leaf...), named so `ProceduralRig` recognizes them: `Body`, `Leg_N`, `Tread_N`, `Arm_L/R`, `Jaw`, `Tool`, `Barrel`, `Boom`, `Crane`, `Wing_L/R`, `Shield_L/R`, `Ring_L/R`, `Rotor`, `Drum`, `Stack`, `Head`, `Door`.
2. Production path (verified 2026-10-08, 19 assets): `tools/asset_pipeline/weaver_parts_joint.py --asset <IDs>`
   - QC the 360 main view first (`weaver_parts.view_is_single_subject`): multi-panel or board-like views are regenerated from the single-subject concept. Never split or mesh a bad 360.
   - Weaver 2D split (`/weaver/component/init_segment`, SSE, `VV-SplitMask-V1.0.0`, `split_type=1`, `granularity=2`) with a Chinese prompt that lists the planned parts. Keep prompts short; asking for too many tiny parts can fail QC ("no bbox in any view").
   - ONE mid-model task with `segment_model_id` only (mode 3). The FBX contains one named mesh per component, already in one shared frame. Do not use per-label generation (mode 4) for assembly: each part comes back re-normalized in its own frame.
   - ONE texture task (node_type=8) on that FBX so seams share an atlas, then `blender_joint_rig.py` renames parts, transfers UVs/material, sets pivots and exports `<slot>_rig.glb` + manifest entry.
3. Verify with `game/tests/parts_rig_view.gd -- <slot...>` (idle/move/attack frames) and `tests/c13_ingame_check.gd`.

Do **not** plane-cut a fused Weaver mid model into parts. `tools/asset_pipeline/blender_componentize.py` is a legacy fallback only, not the production path.

## Workflow

1. Read `references/api-index.md` to select the endpoint and exact request shape. Read `../../../../CGAME/docs/api/weaver-api-docs.md` (or the bundled full source copy when working outside CGAME) when a field is not covered by the index.
2. Instantiate `WeaverClient(app_id, secret_key, base_url=...)`; keep `rtx` request-scoped.
3. Call `get_user_quota()` and `list_algorithm_model()` before a production submission when the workflow needs quota/model selection.
4. Call `get_cos_cred()` then `upload_file()` for local inputs. Upload models as zip files and pass the returned COS URL into the documented field.
5. Submit with `gen_3d_model()` or `gen_multi_views()` using the exact documented `params` nesting. Record returned IDs without logging secrets.
6. Poll each returned model ID with `wait_model()` until status `3` (success) or `4` (failure). LOD and Pose return multiple IDs; text-to-motion returns one ID containing multiple candidate outputs.
7. Use `download_model()` for a fresh signed URL, then `download_file()` for a resumable local download.

Load only the branch reference you need: [auth and jobs](references/api-auth-jobs.md), [models and geometry](references/api-models.md), [animation](references/api-animation.md), or [2D/errors](references/api-2d-and-errors.md). The complete source remains authoritative at `docs/api/weaver-api-docs.md`.

For the CGAME-specific boundary and the evidence from the first production pass, read `docs/api/weaver-api-purpose.md` before submitting a new generation or animation task.

The client only uses Python's standard library. It does not invent or normalize API schemas: unknown endpoint payloads remain available through `request()`. See `references/api-index.md` for endpoint paths, node types, status codes, COS signing notes, and disclosure pointers. The complete source document is authoritative for all fields and examples.

## Completion checks

- Every request body matches the source schema and its HMAC is computed over the exact bytes sent.
- Every async ID is polled individually and terminal status is checked.
- Local downloads exist with the expected byte count; interrupted downloads resume with HTTP Range.
- Validation passes with `quick_validate.py`; no live Weaver/COS call is made during validation.
