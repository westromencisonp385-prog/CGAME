# CGAME Weaver production plan

## Goal
Inspect all project 3D-model and motion requirements, freeze a clear original visual/animation contract where the project is ambiguous, build a local reusable Weaver/VISVISE API skill from the supplied API markdown, then submit and validate the first production batch using the user-provided credentials without persisting secrets.

## Phases
- [complete] Inventory requirements and choose explicit production spec
- [complete] Build and validate Weaver skill and local API reference
- [complete] Authenticate and discover supported models/animation algorithms
- [pending] Produce style-locked authored anchors and API candidates after the new G0 direction
- [in_progress] Redesign the overall UIUX and 3D visual direction before formal asset production
- [pending] Build the 100+ build identity catalog and mechanism-to-visual evidence matrix
- [in_progress] Validate the first A01/B01/C04/river high-quality slice candidate in the real Godot camera
- [in_progress] Close the G1 quality gap against concept sheets and Wanderberg reference evidence
- [complete] Poll, download, and record local validation evidence
- [complete] Update project docs/status and verify repository changes

## Constraints
- Preserve secrets: process environment or user-local credential file only; never print or commit credentials.
- API output must be local and reproducible; model IDs/download URLs are evidence, not completion by themselves.
- Production is limited to clear assets/actions with source image, dimensions, pivot, events, and acceptance checks.
- Distinguish submitted, succeeded, downloaded, and visually validated.
- Treat all current UIUX, Godot geometry, GLB samples, and Weaver candidates as whitebox until the replacement G0 direction is approved.

## Errors
| Error | Attempt | Resolution |
|---|---:|---|
| model_requirements subagent capacity failure | 1 | Respawn with lower-cost model |
| Existing first batch used old local appid.txt and produced single-mesh/no-UV outputs | 1 | Treat as rejected experiment; switch to user env credentials and style-locked inputs |
| Blender validator initially rendered camera away from assets | 1 | Corrected camera look direction and reran validation |
| Weaver high-model/rigging outputs did not satisfy final structure; B01 rigging returned 992103 on GLB | 1 | Documented API boundary; retain authored control assets and require format-correct staged use |
