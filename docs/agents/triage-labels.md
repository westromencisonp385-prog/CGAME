# Triage Labels

The local tracker uses the canonical skill vocabulary in ticket front matter or status notes:

| Label in mattpocock/skills | Local value | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate this issue |
| `needs-info` | `needs-info` | Waiting for missing information |
| `ready-for-agent` | `ready-for-agent` | Fully specified for an AFK agent |
| `ready-for-human` | `ready-for-human` | Requires a human decision or action |
| `wontfix` | `wontfix` | Deliberately not actioned |

Local wayfinder tickets additionally record `type` (`research`, `prototype`, `grilling`, or `task`) and `mode` (`AFK` or `HITL`).
