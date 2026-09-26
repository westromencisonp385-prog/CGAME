---
name: weaver-asset-production
description: "Use the VISVISE Weaver/VISVISE OpenAPI skill for 3D asset production workflows: HMAC-authenticated API calls, quota and algorithm discovery, COS temporary-credential uploads, asynchronous model submission and polling, signed downloads, resumable files, and schema-accurate request construction."
---

# Weaver asset production

Treat Weaver as a specialized asynchronous 3D service layer, not a final game-asset author. Image-to-3D produces a mesh candidate; UV, texture, LOD, rigging, skinning, and motion are separate jobs with separate input contracts. Preserve a human-authored style/structure control asset and accept an API result only after Blender and Godot checks prove that it keeps the required parts, pivots, materials, actions, and gameplay sockets.

Use the standard-library client in `scripts/weaver_api_client.py` for deterministic, auditable API calls. Keep `app_id` and `secret_key` in environment variables or a secret manager; pass the actual caller's `rtx` on every request. Do not print credentials, signed URLs, request headers, or response bodies containing temporary secrets.

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
