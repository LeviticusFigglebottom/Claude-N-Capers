# BOARD (team v3, D-086)

Owner: **LEAD** (only the lead edits this file; envs send updates with `send_message`). Newest first in each section.
Read it at the start of every work session.

## Sessions
| Role | Session id | Branch | Focus now |
|---|---|---|---|
| LEAD | session_014E3p2DmSYTneJjytGwKKfc | claude/dreamy-hamilton-pc7vck | merges, rulings, contracts, gates |
| ENV P | session_01FYVVhNtxKAoQmyfnZ9rb3t | env/p-play | PO-2 mouse capture, PO-1 casing exit, PO-3 bumps |
| ENV B | session_0159qCTRV9CsDQs465nGSW28 | env/b-content | PO-4 UI/UX overhaul (style spec first) |
| ENV A | session_015kTjrZsUFn7gLqNVwAXdkh | env/a-core | PO-5 end-to-end windowed playthrough + blockers |

## Trunk / merge rounds
- 2026-10-13: round 35 = all five env branches (a, b, c, d, p) merged as left by the Grok team + D-086/D-087 docs. Gate running.

## Open questions (id → answer)
- (none)

## Cross-env handoffs in flight
- P → B: `MouseCapture` (input_focus.md). B migrates its 4 direct `Input.mouse_mode` writers after P's module is on trunk.
- B ← P: HUD prompt for casing / mask-up (PO-1) and "click to capture" hint (PO-2), via `casing_blocked` signal + `MouseCapture.notifier().changed`.
