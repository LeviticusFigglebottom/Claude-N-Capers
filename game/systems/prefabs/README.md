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
| `door` | `Door` | Node3D | `lock: Door.Lock` {NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT} (NONE), `swing: Door.Swing` {INWARD, OUTWARD, DOUBLE} (INWARD), `width_m` (0.0 = 0.9 single / 1.8 DOUBLE), `starts_open` (false), `code_group` (&""), `suspicious_when_open` (false, S4.2), `npc_authorized_tags` ([], A2-01) | NONE `door_open_s`, LOCKPICK `lockpick_door_s`, KEYCARD `keycard_s` | `Frame` (+ `Frame/Collision` StaticBody3D), `Leaf` (hinge pivot, closed = rot 0, extends +X), `Handle`, plus `Leaf2` for DOUBLE (extends −X) | Origin = bottom-centre of the opening. `LeafBody` AnimatableBody3D (layer 2) follows `Leaf` (`LeafBody2` is added at runtime for DOUBLE). INWARD opens toward +Z (away from the UsePoint side). DOUBLE = two leaves opening inward. Placeholder `door_double_placeholder.tscn` is used for DOUBLE. Runtime `NavLink` NavigationLink3D (A2-01) |
| `security_camera` | `SecurityCamera` | Node3D | `fov_deg` (60), `range_m` (20), `pan_deg` (0), `pan_period_s` (8), `destructible` (true) | not interactive | `Mount`, `Head`, `Lens` (Marker3D, −Z = view), `Led` (MeshInstance3D) | Wall: pivot back-centre. Ceiling: top-centre. `Collision` StaticBody3D on layer 5 (hitboxes) |
| `camera_station` | `CameraStation` | Node3D | `operator_spawn: NodePath` | `camera_loop_s` | `Screens` (MeshInstance3D), `Seat` (marker) | `Collision` desk (layer 1). Interactable kind `loop_cameras` |
| `display_case` | `DisplayCase` | Node3D | `loot_id` (&""), `glass_breaks_alarm` (false) | `display_case_open_s` | `Body`, `Glass`, `LootAnchor` | `Collision` (layer 1). Glass break (S9.9): M2 |
| `small_loot` | `SmallLoot` | Node3D | `value: int` (500), `loot_id` (&"") | `small_loot_s` | none | No collision. S10.3 |
| `loot_spawn` | `LootSpawn` | Node3D | `loot_id` (&""), `count: int` (1) | `bag_loot_s` | none | Interaction = bag up the stack (kind `bag_loot`). Bag spawning: A1-07 |
| `keycard_pickup` | `KeycardPickup` | Node3D | none (grants `item.keycard`) | `item_pickup_s` | none | casing_allowed = true. S9.6 |
| `keycard_reader` | `KeycardReader` | Node3D | `targets: Array[NodePath]` ([]) | `keycard_s` | `Panel`, `Led` | Wall-mounted (back-centre). Consumes the keycard |
| `keypad` | `Keypad` | Node3D | `code_group` (&""), `targets: Array[NodePath]` ([]) | `keypad_s` | `Panel`, `Led` | Wall-mounted. S9.7 |
| `code_note` | `CodeNote` | Node3D | `code_group` (&"") | `read_note_s` | none | S9.7 |
| `safe` | `Safe` | Node3D | `size: Safe.Size` {SMALL, MEDIUM, LARGE} (MEDIUM), `methods: Array[StringName]` ([&"drill"]; ids `drill`, `saw`, `c4`, `lockpick`, `code`), `code_group` (&""), `time_lock_s` (0 = none) | `drill_place_s` | `Body`, `Door` (hinge pivot), `DrillPoint` (−Z into the lock), `LootAnchor` | `Collision` sized for MEDIUM (layer 1). S9.8 |
| `drill_point` | `DrillPoint` | Node3D | `device: DrillPoint.Device` {DRILL, THERMAL, SAW} (DRILL), `duration_s` (-1 = `drill_duration_s` / `thermal_duration_s` / `saw_duration_s`), `target: NodePath` | `drill_place_s` | none (device art has `Bit`) | **−Z points into the lock**, so the UsePoint is on its **+Z** side. S9.3/S9.4 |
| `alarm_button` | `AlarmButton` | Node3D | none | not interactive | none | Wall-mounted. `UsePoint` = where the NPC stands |
| `phone` | `Phone` | Node3D | none | not interactive | none | `UsePoint` = where the NPC stands |
| `window` | `WindowPrefab` | Node3D | `breakable` (true), `openable` (false) (`noise` is the common one) | `window_open_s` | `Frame`, `Glass`, optional `Sash` | Origin = bottom-centre of the opening (sill). `GlassBody` StaticBody3D (layer 1). Interactable enabled only if `openable`. S9.9/S9.11 |
| `secure_zone` | `SecureZone` | Node3D | `zone_size_m: Vector3` (4, 3, 8), `vehicle_collision` (true) | not interactive | `Body`, `DoorL`, `DoorR`, `DropAnchor` | `Zone` MapZone SECURE_LOOT. `Collision` = 2×2.2×5 m van body (layer 1), removed when `vehicle_collision` is false. Van rear faces −Z. S10.2 |
| `escape_zone` | `EscapeZone` | Node3D | `escape_type: StringName` (&"van"), `active` (false), `zone_size_m` (4, 3, 4) | not interactive | none | `Zone` MapZone ESCAPE (stays in the group, `monitoring` follows `active`). `activate()` is called by `HeistMission.activate_escape()`. Visual hidden while inactive. C10 |
| `body_container` | `BodyContainer` | Node3D | `capacity: int` (2) | not interactive | `Lid` (pivot), `Inside` | `Zone` MapZone BODY_HIDE (1.8×1.6×1.0). `Collision` body (layer 1). S6.3 |
| `ladder` | `Ladder` | Node3D | `height_m` (3.0) | not interactive | `Top`, `Bottom` | Climb side −Z. The placeholder resizes to `height_m`. A2-04 climbing (below) |
| `zipline` | `Zipline` | Node3D | `end: NodePath` | `zipline_attach_s` | none | P2 |
| `laser_grid` | `LaserGrid` | Node3D | `pattern: StringName` (&"static"; `sweeping`, `timed_off`), `size_m: Vector3` (2, 2, 0.1), `beam_count` (4), `period_s` (4), `off_s` (1.5), `phase_s` (0), `sweep_beams` (1) | not interactive | optional `Beam0..Beam<n-1>` (A drives `visible` + position) | `Trigger` Area3D (layer 10, mask players). S9.10, P2 |

## Behaviour (A1-03 stubs + A1-07)

Server-authoritative; every fact is an EventBus emit + `Net.replicate_event` (events.md). Numbers
live in InteractionTweak ("Device jams", "Glass"), StealthTweak and LootTweak.

* `door`: on completion it unlocks if needed and toggles open/closed. NONE opens instantly.
  LOCKPICK uses `interaction.lockpick_speed_mult`. KEYCARD requires and consumes `item.keycard`.
  CODE, ELECTRONIC, BARRED and VAULT block the interaction until `unlock()` (keypad, keycard
  reader, drill). `open()` = `set_open(true)`. `suspicious_when_open`: an `open_door` stimulus while
  open (NPC-opened doors too).
  A2-01 (QA-11) NPC doors: `NpcMotor` (guards, civilians, police) and `CrewAiBrain` scan their
  path (`Door.first_closed_on_path`, InteractionTweak "NPC doors") and call `npc_open(agent)`
  within `npc_door_reach_m`: unlocked doors open after 0.6 s in stealth (instantly in loud);
  a locked door (not BARRED/VAULT) opens for a guard whose SpawnPoint tags meet the new export
  `npc_authorized_tags: Array[StringName]` (keycard post), stays locked and closes again after
  `npc_locked_door_close_s`. Any other closed door stops the NPC in front of it
  (`NpcMotor.blocked_door`, signal `door_blocked(door)`: P3 police breach hook). Signal
  `open_changed(open, by_net_id)`. Child `NavLink` (NavigationLink3D through the doorway) is
  enabled while NPCs can pass (open, unlocked, or authorised) for maps whose bake closes doorways.
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
* `security_camera` (A2-02, S8.1/S4.4): observer (G.OBSERVER + group `security_camera`, default
  `objective_tag` `security_camera`); cone = `fov_deg` / `range_m` via `detection_overrides()`; pans
  `Head` +-`pan_deg`/2 over `pan_period_s`; eye/forward from `Lens`; `Led` dark when off. `take_hit`:
  one hit breaks it unless `titan` (added export) or difficulty >= `camera_titan_min_difficulty` ->
  `camera_disabled(id, &"destroyed")` [R] + `broken_camera` stimulus. `disable(reason)`,
  `set_suppressed(source, on)` (ECM / loop hook). A confirmed camera stimulus starts the S3.5 countdown.
* `camera_station` (A2-02, S8.2): spawns the operator (guard, `no_patrol`) at `operator_spawn` when the
  room is staffed (`room_staffed(variants)`); killing/dominating him -> `cameras_loop_disabled` [R] +
  `camera_disabled(id, &"operator")` per camera, `Screens` dark. Broken camera while on duty: 30 %
  (GameRng `cameras`) dispatch of the nearest calm guard after 10 s (`guard_dispatched`). Loop
  interaction gated on `stealth.camera_loop` (P3: `loop_requested`).

A2-04 (S9.4, S9.7, S9.8, S9.10, S9.11):

* Codes: runtime service `codes` (`CodeRegistry`, interaction/code_registry.gd). `code_for(group)` =
  4 digits rolled once per run from GameRng `&"codes"` (one base draw + per-group derivation, so
  query order never matters). Known codes are crew-wide: `reveal(group, slot)`, `is_known(group)`,
  `known_codes()` (HUD: {group: "0427"}).
* `code_note`: kind `read_note` (read_note_s) -> `reveal`, `item_picked_up(&"item.code_note", slot)`
  [R]; stays readable; `code_text()`. `configure_variant({"code_group": ...})` for `code_note`
  variant slots with `prefab` set.
* `keypad`: blocked `ui.blocked.code_unknown` until the group is known; kind `enter_code` (keypad_s)
  -> unlock + open `targets` and every Door with `lock == CODE` and the same `code_group`
  (`open_by_device()` for safes). Led green, single use. Empty `code_group` = no code needed.
  `configure_variant` like the note.
* `safe`: one Interactable; per crew member the first usable method in code, lockpick (SMALL +
  `interaction.can_lockpick_safes`, safe_lockpick_s), drill / saw (DeviceRunner, time by size from
  safe_drill_duration_s / safe_saw_duration_s), c4 (consumes `item.c4`, c4_place_s, fuse c4_fuse_s,
  noise `&"explosion"` c4_noise_radius_m, cue.c4_explode). Kinds `enter_code`, `lockpick`,
  `place_drill`, `place_saw`, `place_c4`, `fix_drill`, `start_time_lock`. `time_lock_s` > 0: beating
  the lock arms the time lock; a hold (time_lock_start_s, interrupted = redo) starts it, then
  `device_started(id, &"time_lock", s)` ... `device_finished` and the door swings. `swing_open()`
  forces it. P2 simplification: no pause/hack of a running time lock.
* Saws: DeviceRunner kind `saw` (drill_point SAW or a safe listing `saw`): noise `&"saw"`
  (StealthTweak.saw_radius_m), `drill` stimulus + a `saw` stimulus (10 m, S4.1).
* `laser_grid`: runtime `BeamArea<i>` Area3Ds (layer triggers, mask players); any crew body in an
  active beam -> `laser_tripped(grid net_id)` [R], cue.laser_trip, `raise_alarm(&"laser")`, once;
  casing / civilian mode included, ECM irrelevant, nothing once loud. static / timed_off (off for the
  last `off_s` of each `period_s`) = horizontal beams; sweeping = vertical beams ping-ponging across
  the width once per `period_s`.
* `zipline`: needs a carried bag (`ui.blocked.requires_bag`); the bag leaves the crew
  (`loot_dropped`), slides frozen from the Interactable to `end` at zipline_speed_mps and is released
  there (a secure zone there secures it). Player zipline: P3 hook.
* `ladder`: a masked NORMAL crew member within ladder_grab_radius_m of Bottom/Top holding interact
  (or moving forward facing the ladder) is moved at ladder_climb_speed_mps along Bottom ->
  (Bottom.xz, Top.y) -> Top (reverse going down) by a HeistRuntime crew tick handler; casing crew
  cannot climb (S1.1). `is_climbing(slot)`, `start_climb(crew, up)`. Remote-human climbing: later.
