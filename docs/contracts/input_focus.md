# Contract: input focus and mouse capture

Version **1.0** (D-087). Owner: LEAD. Producer: ENV P (`MouseCapture`). Consumers: ENV B (every UI screen), ENV A.

## Rule
`MouseCapture` (`game/systems/player/mouse_capture.gd`, `class_name MouseCapture`, static API) is the **only** code that
writes `Input.mouse_mode`. Anything else that writes it is a contract violation.

The mouse is **captured** exactly when all of these hold:
1. gameplay is active: at least one local human crew's `PlayerInput` is live in a heist or the walkable safehouse;
2. no release is held (see API);
3. the game window has focus.

Otherwise it is **visible** (`MOUSE_MODE_VISIBLE`). When the conditions become true but the OS refuses capture (no user
gesture yet, focus just returned), the next left click in the game viewport captures and is **not** passed on as `fire`.

## API (static)
| Call | Who | Meaning |
|---|---|---|
| `MouseCapture.set_gameplay_active(owner: Object, active: bool)` | ENV P PlayerInput (local human only) | declare/clear live gameplay; several owners allowed (split-screen-safe) |
| `MouseCapture.push_release(key: StringName)` | any UI needing a cursor (pause, options, payday, menus, chat, drop-in dialog, station screens) | hold the cursor visible; idempotent per key |
| `MouseCapture.pop_release(key: StringName)` | same UI, on close / `tree_exiting` | drop that hold |
| `MouseCapture.is_captured() -> bool` | PlayerInput, HUD | effective state (tests can read it) |
| `signal changed(captured: bool)` (on `MouseCapture.notifier()`) | HUD (crosshair / "click to resume" hint) | state changes |

Screens release in `_ready`/open and pop in `_exit_tree`/close so a freed screen never leaves the cursor stuck.
While captured, gameplay ignores focused GUI controls (no hidden focused Control may eat gameplay input; PI-13 rule).

## Keys (StringName, lowercase): `pause`, `options`, `payday`, `menu`, `chat`, `dropin`, `station`, `scoreboard` (scoreboard does NOT release; listed only to say so).

## Tests
ENV P: windowed test (xvfb, not headless) that launches a heist, asserts `Input.mouse_mode == MOUSE_MODE_CAPTURED`
and that mouse motion turns the camera, opens/closes pause and asserts visible → captured.
