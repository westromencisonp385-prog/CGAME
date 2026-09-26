# CGAME Weaver production plan

## Goal
Inspect all project 3D-model and motion requirements, freeze a clear original visual/animation contract where the project is ambiguous, build a local reusable Weaver/VISVISE API skill from the supplied API markdown, then submit and validate the first production batch using the user-provided credentials without persisting secrets.

## Phases
- [complete] Inventory requirements and choose explicit production spec
- [complete] Build and validate Weaver skill and local API reference
- [complete] Authenticate and discover supported models/animation algorithms
- [in_progress] Produce style-locked authored anchors and API candidates
- [complete] Poll, download, and record local validation evidence
- [pending] Update project docs/status and verify repository changes

## Constraints
- Preserve secrets: process environment only; never print or commit credentials.
- API output must be local and reproducible; model IDs/download URLs are evidence, not completion by themselves.
- Production is limited to clear assets/actions with source image, dimensions, pivot, events, and acceptance checks.
- Distinguish submitted, succeeded, downloaded, and visually validated.

## Errors
| Error | Attempt | Resolution |
|---|---:|---|
| model_requirements subagent capacity failure | 1 | Respawn with lower-cost model |
| Existing first batch used old local appid.txt and produced single-mesh/no-UV outputs | 1 | Treat as rejected experiment; switch to user env credentials and style-locked inputs |
| Blender validator initially rendered camera away from assets | 1 | Corrected camera look direction and reran validation |
| Weaver high-model/rigging outputs did not satisfy final structure; B01 rigging returned 992103 on GLB | 1 | Documented API boundary; retain authored control assets and require format-correct staged use |
