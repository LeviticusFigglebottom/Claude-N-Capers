# Gameplay prefabs (A1-03, shape v1)

Owner: **ENV A**. Contracts: `docs/contracts/gameplay_prefabs.md`, `docs/contracts/visual_slots.md`,
`docs/contracts/heist_map.md` §3/§7. ENV C instances these under the map's `Gameplay` node and
sets `visual_scene`. Scene paths, node names and exports below are stable. Behaviour beyond the
stubs listed at the end lands in M2.

## Common rules

* Every prefab root extends `GameplayPrefab` (`gameplay_prefab.gd`): it has `net_id` (claimed in
  `_ready`, server only), `visual_scene: PackedScene` (null = placeholder) and
  `objective_tag: StringName` (used by `HeistRuntime.find_by_tag`).
* `Visual` (Node3D) is empty in the saved scene. At `_ready` the prefab instantiates `visual_scene`
  there, or `<name>_placeholder.tscn` when it is null. The required named nodes are looked up
  with `find_child(name, true, false)`. A missing node logs `Log.error(&"prefab", ...)`.
* **Interactive** prefabs also have `UsePoint` (Marker3D: where the character stands; its −Z faces
  the object) and `Interactable` (InteractableComponent, placed at the focus point), plus these
  exports in the inspector group "Interaction":

  | Export | Type | Default |
  |---|---|---|
  | `interaction_time_s` | float | `-1.0` = InteractionTweak default (column "Time" below) |
  | `requires_item` | StringName | `&""` (keycard_reader: `&"item.keycard"`) |
  | `stealth_only` / `loud_only` | bool | false / false (camera_station: stealth_only true) |
  | `casing_allowed` | bool | false (keycard_pickup: true) |
  | `noise` | StringName | `&"silent"` (`&"quiet"`, `&"loud"`) |

* Forward is −Z (the side facing the room/user) and pivots follow visual_slots.md. The UsePoint
  sits about 0.7 m in front of the object's front face, at the floor. Floor objects have it at
  y = 0 relative to the prefab root. Wall panels (keycard_reader, keypad, alarm_button) assume a
  **1.2 m** mount height (UsePoint y = −1.2), windows assume a **0.9 m** sill (y = −0.9) and
  drill points assume **1.0 m** (y = −1.0). If you mount one at another height, or place a floor
  item on furniture, move `UsePoint` down to the floor with Editable Children. It must be within
  0.25 m of the navmesh (heist_map.md §3).
* Collision layers: 1 world_static, 2 world_dynamic, 5 hitboxes, 10 triggers. The prefab owns
  collision, except the door `Frame` (the visual supplies `Frame/Collision`, a StaticBody3D).
* Volume prefabs host a child `Zone` (MapZone, `Shape` = BoxShape3D). Its bottom sits at the
  prefab origin (floor) and it is centred on the footprint.

## Prefabs

Scene path = `res://systems/prefabs/<name>/<name>.tscn`. Placeholder = `<name>/<name>_placeholder.tscn`.

| Prefab | Class | Root | Key exports (default) | Time (tweak) | Required visual nodes | Collision / zone / notes |
|---|---|---|---|---|---|---|
| `door` | `Door` | Node3D | `lock: Door.Lock` {NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT} (NONE), `swing: Door.Swing` {INWARD, OUTWARD, DOUBLE} (INWARD), `width_m` (0.0 = 0.9 single / 1.8 DOUBLE), `starts_open` (false), `code_group` (&""), `suspicious_when_open` (false, S4.2) | NONE `door_open_s`, LOCKPICK `lockpick_door_s`, KEYCARD `keycard_s` | `Frame` (+ `Frame/Collision` StaticBody3D), `Leaf` (hinge pivot, closed = rot 0, extends +X), `Handle`, plus `Leaf2` for DOUBLE (extends −X) | Origin = bottom-centre of the opening. `LeafBody` AnimatableBody3D (layer 2) follows `Leaf` (`LeafBody2` is added at runtime for DOUBLE). INWARD opens toward +Z (away from the UsePoint side). DOUBLE = two leaves opening inward. Placeholder `door_double_placeholder.tscn` is used for DOUBLE. Nav link/obstacle toggling: M2 |
| `security_camera` | `SecurityCamera` | Node3D | `fov_deg` (60), `range_m` (20), `pan_deg` (0), `pan_period_s` (8), `destructible` (true) | not interactive | `Mount`, `Head`, `Lens` (Marker3D, −Z = view), `Led` (MeshInstance3D) | Wall: pivot back-centre. Ceiling: top-centre. `Collision` StaticBody3D on layer 5 (hitboxes) |
| `camera_station` | `CameraStation` | Node3D | `operator_spawn: NodePath` | `camera_loop_s` | `Screens` (MeshInstance3D), `Seat` (marker) | `Collision` desk (layer 1). Interactable kind `loop_cameras` |
| `display_case` | `DisplayCase` | Node3D | `loot_id` (&""), `glass_breaks_alarm` (false) | `display_case_open_s` | `Body`, `Glass`, `LootAnchor` | `Collision` (layer 1). Glass break (S9.9): M2 |
| `small_loot` | `SmallLoot` | Node3D | `value: int` (500), `loot_id` (&"") | `small_loot_s` | none | No collision. S10.3 |
| `loot_spawn` | `LootSpawn` | Node3D | `loot_id` (&""), `count: int` (1) | `bag_loot_s` | none | Interaction = bag up the stack (kind `bag_loot`). Bag spawning: A1-07 |
| `keycard_pickup` | `KeycardPickup` | Node3D | none (grants `item.keycard`) | `item_pickup_s` | none | casing_allowed = true. S9.6 |
| `keycard_reader` | `KeycardReader` | Node3D | `targets: Array[NodePath]` ([]) | `keycard_s` | `Panel`, `Led` | Wall-mounted (back-centre). Consumes the keycard |
| `keypad` | `Keypad` | Node3D | `code_group` (&"") | `keypad_s` | `Panel`, `Led` | Wall-mounted. S9.7 |
| `code_note` | `CodeNote` | Node3D | `code_group` (&"") | `read_note_s` | none | S9.7 |
| `safe` | `Safe` | Node3D | `size: Safe.Size` {SMALL, MEDIUM, LARGE} (MEDIUM), `methods: Array[StringName]` ([&"drill"]; ids `drill`, `saw`, `c4`, `lockpick`, `code`) | `drill_place_s` | `Body`, `Door` (hinge pivot), `DrillPoint` (−Z into the lock), `LootAnchor` | `Collision` sized for MEDIUM (layer 1). S9.8 |
| `drill_point` | `DrillPoint` | Node3D | `device: DrillPoint.Device` {DRILL, THERMAL, SAW} (DRILL), `duration_s` (-1 = `drill_duration_s` / `thermal_duration_s` / `saw_duration_s`), `target: NodePath` | `drill_place_s` | none (device art has `Bit`) | **−Z points into the lock**, so the UsePoint is on its **+Z** side. S9.3/S9.4 |
| `alarm_button` | `AlarmButton` | Node3D | none | not interactive | none | Wall-mounted. `UsePoint` = where the NPC stands |
| `phone` | `Phone` | Node3D | none | not interactive | none | `UsePoint` = where the NPC stands |
| `window` | `WindowPrefab` | Node3D | `breakable` (true), `openable` (false) (`noise` is the common one) | `window_open_s` | `Frame`, `Glass`, optional `Sash` | Origin = bottom-centre of the opening (sill). `GlassBody` StaticBody3D (layer 1). Interactable enabled only if `openable`. S9.9/S9.11 |
| `secure_zone` | `SecureZone` | Node3D | `zone_size_m: Vector3` (4, 3, 8), `vehicle_collision` (true) | not interactive | `Body`, `DoorL`, `DoorR`, `DropAnchor` | `Zone` MapZone SECURE_LOOT. `Collision` = 2×2.2×5 m van body (layer 1), removed when `vehicle_collision` is false. Van rear faces −Z. S10.2 |
| `escape_zone` | `EscapeZone` | Node3D | `escape_type: StringName` (&"van"), `active` (false), `zone_size_m` (4, 3, 4) | not interactive | none | `Zone` MapZone ESCAPE (stays in the group, `monitoring` follows `active`). `activate()` is called by `HeistMission.activate_escape()`. Visual hidden while inactive. C10 |
| `body_container` | `BodyContainer` | Node3D | `capacity: int` (2) | not interactive | `Lid` (pivot), `Inside` | `Zone` MapZone BODY_HIDE (1.8×1.6×1.0). `Collision` body (layer 1). S6.3 |
| `ladder` | `Ladder` | Node3D | `height_m` (3.0) | not interactive | `Top`, `Bottom` | Climb side −Z. The placeholder resizes to `height_m`. Climbing: M2 |
| `zipline` | `Zipline` | Node3D | `end: NodePath` | `zipline_attach_s` | none | P2 |
| `laser_grid` | `LaserGrid` | Node3D | `pattern: StringName` (&"static"; `sweeping`, `timed_off`), `size_m: Vector3` (2, 2, 0.1) | not interactive | none | `Trigger` Area3D (layer 10, mask players). S9.10, P2 |

## Behaviour (A1-03 stubs + A1-07)

Server-authoritative; every fact is an EventBus emit + `Net.replicate_event` (events.md). Numbers
live in InteractionTweak ("Device jams", "Glass"), StealthTweak and LootTweak.

* `door`: on completion it unlocks if needed and toggles open/closed. NONE opens instantly.
  LOCKPICK uses `interaction.lockpick_speed_mult`. KEYCARD requires and consumes `item.keycard`.
  CODE, ELECTRONIC, BARRED and VAULT block the interaction until `unlock()` (keypad, keycard
  reader, drill). `open()` = `set_open(true)`. `suspicious_when_open`: an `open_door` stimulus while
  open. Nav link / obstacle toggling: M2.
* `keycard_pickup`: grants `item.keycard`, emits `item_picked_up` and frees itself.
* `keycard_reader`: consumes the keycard, calls `unlock()` then `set_open(true)` / `open()` on each
  of `targets`, Led goes green. Single use.
* `small_loot`: emits `small_loot_taken(value, slot)` and frees itself.
* `display_case`: Interactable = smash (kind `break_glass`, `glass_break_s`, instant by default) or
  open with `requires_item` (kind `open_case`, no shatter). Shooting it (`apply_damage`, the
  `Collision` body carries `hit_owner`) also shatters. Shatter: `Glass` hidden, `glass_broken`,
  `cue.glass_break`, noise `&"glass"` 15 m, `broken_glass` stimulus; `glass_breaks_alarm` ->
  `alarm_raised(&"glass_alarm")`. Then the same Interactable takes the loot (kind `take_loot`,
  `small_loot_s`) -> `small_loot_taken(value, slot)`; value = ContentDB `loot_id` value, else
  `LootTweak.display_case_default_value`.
* `window`: `openable` -> kind `open_window` slides `Sash` up (GlassBody off while open); else
  `breakable` -> kind `break_window`. `apply_damage` on a breakable window shatters it like a case
  (GlassBody collision off).
* `loot_spawn`: kind `bag_loot`, not while carrying; each completion spawns a LootBag of `loot_id`
  (`moved = true`) on the crew member's back; disabled at `remaining == 0`.
* `drill_point` / `safe`: `DeviceRunner` (drill_point/device_runner.gd). Place (drill_place_s) ->
  runs `duration_s` × `interaction.device_speed_mult` (safe: `safe_drill_duration_s[size]`), jams
  rolled at placement on GameRng `&"devices"` (1-3 candidates × `device_jam_chance_mult`, 15-90 %),
  jammed -> same Interactable becomes kind `fix_drill` (drill_fix_s); auto-restart chance
  `interaction.device_auto_restart_chance` rolled at placement and per fix (restart after 5-10 s).
  Running in stealth: noise `&"drill"` (`drill_radius_m`) every `device_noise_interval_s` unless
  `stealth.silent_devices`, and a `drill` stimulus. Events device_started/jammed/restarted/finished,
  cues drill_loop/jam/done. Finish -> `target.open_by_device()`, else `unlock()` + open.
  `Safe.open_by_device()` swings `Door` and enables the loot prefabs placed under the safe
  (disabled while closed). Safe `lockpick` needs `interaction.can_lockpick_safes`; saw/c4/code: P2.
* `secure_zone`: its `Zone` (like any SECURE_LOOT MapZone) secures bags resting in it 0.5 s
  (LootManager).
* `body_container`: body bags in its `Zone` are hidden from stealth up to `capacity`
  (`store_bag` / `release_bag`, `stored`).
* `escape_zone`: `activate()`; while active, once every human crew member not in custody is inside
  `Zone`, `HeistRuntime.end_heist(true, escaped)` (AI teammates not in custody come along; with no
  humans slot 0 counts as the human). `escaping_slots(rt)` exposes the check.
* `alarm_button`: `use_point_position()`, `press(by_net_id)` -> `alarm_raised(&"alarm_button")`.
* `phone`: `use_point_position()`, `call_police(by_net_id)` -> `alarm_raised(&"phone_call")`.

Still `# A1-03 behaviour (M2/P2)`: camera_station, security_camera, keypad, code_note, ladder,
zipline, laser_grid.
