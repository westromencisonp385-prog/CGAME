# Issue tracker: Local Markdown

This repository keeps engineering decisions and implementation tickets as local Markdown. The canonical route is the existing `docs/wayfinder/` map and its child tickets; moving it to a second tracker would create duplicate sources of truth. The GitHub repository is the code remote and publication mirror, not the current issue tracker.

This is a project-specific local-tracker override: do not create a parallel `.scratch/` tree for the existing wayfinder effort.

## Conventions

- The map lives at `docs/wayfinder/map.md`.
- Child decision tickets live at `docs/wayfinder/tickets/`, one Markdown file per ticket.
- Ticket front matter records `type`, `mode`, `status`, `triage`, and `blocked_by`. `status` is the wayfinder lifecycle (`open`/`claimed`/`resolved`); `triage` uses the canonical labels in `docs/agents/triage-labels.md`.
- A ticket is unblocked when every ticket named in `blocked_by` is resolved.
- Resolutions are appended to the ticket and summarized in the map's `Decisions so far` section.
- Do not delete unresolved tickets or close them merely because an implementation exists; the route documents decisions, not completion claims.

## When a skill says "publish to the issue tracker"

Update the existing map or add a child ticket under `docs/wayfinder/` using the conventions above. Keep the current path as the only local tracker surface.

## GitHub publication

The code remote is `https://github.com/westromencisonp385-prog/CGAME.git`. Pushes and pull requests are separate from the local decision tracker and must still distinguish draft, pushed, merged, and deployed states.
