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
  | `civilian_allowed` | bool | false (gear_pickup: true). S1.3: civilians (no gear) may use only these |
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
  Prefab `Collision` boxes are fitted to the visual at ready (see "Collision fitting" below).
* Volume prefabs host a child `Zone` (MapZone, `Shape` = BoxShape3D). Its bottom sits at the
  prefab origin (floor) and it is centred on the footprint.

## Prefabs

Scene path = `res://systems/prefabs/<name>/<name>.tscn`. Placeholder = `<name>/<name>_placeholder.tscn`.

| Prefab | Class | Root | Key exports (default) | Time (tweak) | Required visual nodes | Collision / zone / notes |
|---|---|---|---|---|---|---|
| `door` | `Door` | Node3D | `lock: Door.Lock` {NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT} (NONE), `swing: Door.Swing` {INWARD, OUTWARD, DOUBLE} (INWARD), `width_m` (0.0 = 0.9 single / 1.8 DOUBLE), `starts_open` (false), `code_group` (&""), `suspicious_when_open` (false, S4.2), `npc_authorized_tags` ([], A2-01), `push_bar` (false, A2-08) | NONE `door_open_s`, LOCKPICK `lockpick_door_s`, KEYCARD `keycard_s` | `Frame` (+ `Frame/Collision` StaticBody3D), `Leaf` (hinge pivot, closed = rot 0, extends +X), `Handle`, plus `Leaf2` for DOUBLE (extends −X) | Origin = bottom-centre of the opening. `LeafBody` AnimatableBody3D (layer 2) follows `Leaf` (`LeafBody2` is added at runtime for DOUBLE). INWARD opens toward +Z (away from the UsePoint side). DOUBLE = two leaves opening inward. Placeholder `door_double_placeholder.tscn` is used for DOUBLE. Runtime `NavLink` NavigationLink3D (A2-01) |
| `security_camera` | `SecurityCamera` | Node3D | `fov_deg` (60), `range_m` (20), `pan_deg` (0), `pan_period_s` (8), `destructible` (true), `mount_mode` (AUTO = meta `mount`, else WALL; QA-26) | not interactive | `Mount`, `Head`, `Lens` (Marker3D, −Z = view), `Led` (MeshInstance3D) | Wall: pivot back-centre. Ceiling: top-centre. `Collision` StaticBody3D on layer 5 (hitboxes), local z in [−0.45, 0] (never behind the pivot, A2-08); CEILING mount lowers it (and the placeholder) to y ≤ 0 (QA-26, D-043) |
| `camera_station` | `CameraStation` | Node3D | `operator_spawn: NodePath` | `camera_loop_s` | `Screens` (MeshInstance3D), `Seat` (marker) | `Collision` desk (layer 1). Interactable kind `loop_cameras` |
| `display_case` | `DisplayCase` | Node3D | `loot_id` (&""), `glass_breaks_alarm` (false) | `display_case_open_s` | `Body`, `Glass`, `LootAnchor` | `Collision` (layer 1). Glass break (S9.9): M2 |
| `small_loot` | `SmallLoot` | Node3D | `value: int` (500), `loot_id` (&"") | `small_loot_s` | none | No collision. S10.3 |
| `loot_spawn` | `LootSpawn` | Node3D | `loot_id` (&""), `count: int` (1) | `bag_loot_s` | none | Interaction = bag up the stack (kind `bag_loot`). Bag spawning: A1-07 |
| `keycard_pickup` | `KeycardPickup` | Node3D | none (grants `item.keycard`) | `item_pickup_s` | none | casing_allowed = true. S9.6 |
| `deposit_box` | `DepositBox` (SmallLoot) | Node3D | `value` (500), `loot_id` | `small_loot_s` | none | Locked until sawn (G.SAW_TARGET, hand_saw_deposit_box_s). QC-37 |
| `padlock` | `Padlock` | Node3D | `targets: Array[NodePath]` ([]) | `lockpick_door_s` | `Body`, `Shackle` | Lockpick or saw (hand_saw_padlock_s) opens the targets. QC-37 |
| `burn_point` | `BurnPoint` | Node3D | `requires_loot` (loot.thermite), `duration_s` (-1), `fire_volume_size` (6x3x6) | `burn_place_s` | `Fire` (optional); child `FireVolume` | Bag consumed, burn (no jams, device kind thermite), cue.burn_warning + burn_warning_s, device_finished, fire DoT ignoring armour + nav obstacle. QC-38 |
| `gear_pickup` | `GearPickup` | Node3D | none (kind `pick_up_gear`) | `item_pickup_s` | none | civilian_allowed = true; only civilians may use it. S1.3 |
| `hub_station` | `HubStation` | Node3D | `station_id` (&"") | 0 (instant) | none | Safehouse station (QC-44): kind `hub_station`, prompt `ui.prompt.station.<id>`, casing + civilian allowed, silent; `station_used(id, crew)` / `station_requested(id)` |
| `keycard_reader` | `KeycardReader` | Node3D | `targets: Array[NodePath]` ([]) | `keycard_s` | `Panel`, `Led` | Wall-mounted (back-centre). Consumes the keycard |
| `keypad` | `Keypad` | Node3D | `code_group` (&""), `targets: Array[NodePath]` ([]) | `keypad_s` | `Panel`, `Led` | Wall-mounted. S9.7 |
| `code_note` | `CodeNote` | Node3D | `code_group` (&"") | `read_note_s` | none | S9.7 |
| `safe` | `Safe` | Node3D | `size: Safe.Size` {SMALL, MEDIUM, LARGE} (MEDIUM), `methods: Array[StringName]` ([&"drill"]; ids `drill`, `saw`, `c4`, `lockpick`, `code`), `code_group` (&""), `time_lock_s` (0 = none), `reader: NodePath` (empty, A2-08; method id `keycard`) | `drill_place_s` | `Body`, `Door` (hinge pivot), `DrillPoint` (−Z into the lock), `LootAnchor` | `Collision` (layer 1) fitted to `Body`. S9.8 |
| `drill_point` | `DrillPoint` | Node3D | `device: DrillPoint.Device` {DRILL, THERMAL, SAW} (DRILL), `duration_s` (-1 = `drill_duration_s` / `thermal_duration_s` / `saw_duration_s`), `target: NodePath` | `drill_place_s` | none (device art has `Bit`) | **−Z points into the lock**, so the UsePoint is on its **+Z** side. S9.3/S9.4 |
| `alarm_button` | `AlarmButton` | Node3D | none | not interactive | none | Wall-mounted. `UsePoint` = where the NPC stands |
| `phone` | `Phone` | Node3D | none | not interactive | none | `UsePoint` = where the NPC stands |
| `window` | `WindowPrefab` | Node3D | `breakable` (true), `openable` (false) (`noise` is the common one) | `window_open_s` | `Frame`, `Glass`, optional `Sash` | Origin = bottom-centre of the opening (sill). `GlassBody` StaticBody3D (layer 1), fitted at ready to the visual's `Glass` AABB (A2-08). Interactable enabled only if `openable`. S9.9/S9.11 |
| `secure_zone` | `SecureZone` | Node3D | `zone_size_m: Vector3` (4, 3, 8), `vehicle_collision` (true) | not interactive | `Body`, `DoorL`, `DoorR`, `DropAnchor` | `Zone` MapZone SECURE_LOOT. `Collision` = van body fitted to the visual (placeholder 2×2.2×5 m, layer 1), removed when `vehicle_collision` is false. Van rear faces −Z. S10.2 |
| `escape_zone` | `EscapeZone` | Node3D | `escape_type: StringName` (&"van"; one of van, boat, heli, lift, zipline, walk), `active` (false), `zone_size_m` (4, 3, 4), `arrival_delay_s` (0, A3-10), `bag_only` (false, A3-10) | not interactive | art only (not the placeholder): van `Body`, `DoorL`, `DoorR`; heli `Body`, `Rotor`; boat `Body` | `Zone` MapZone ESCAPE (stays in the group, `monitoring` follows `active`). `activate()` is called by `HeistMission.activate_escape()`. Visual hidden while inactive or approaching. C10, QC-19 |
| `body_container` | `BodyContainer` | Node3D | `capacity: int` (2) | not interactive | `Lid` (pivot), `Inside` | `Zone` MapZone BODY_HIDE (1.8×1.6×1.0). `Collision` body (layer 1). S6.3 |
| `ladder` | `Ladder` | Node3D | `height_m` (3.0) | not interactive | `Top`, `Bottom` | Climb side −Z. The placeholder resizes to `height_m`. A2-04 climbing (below) |
| `bag_lift` | `BagLift` | Node3D | `targets: Array[NodePath]` ([]: the OTHER landings; landing 0 = the prefab), `travel_s` (8.0), `capacity: int` (2), `car_size_m: Vector3` (1.2, 1.2, 1.2, A3-09 addition), `door_open_m` (-1 = auto), `door_fold: bool` (false), `panel_path: NodePath` (empty), `copy_panel: bool` (true), `return_fallen_bags: bool` (true) | `bag_lift_send_s` | `Car`, `DoorL`, `DoorR`; optional `Panel` | Pivot = car floor centre at landing 0, car front −Z. `CarBody` AnimatableBody3D floor slab (layer 2) follows the car and is resized to `car_size_m` (x, z). Optional `Panel` Node3D child of the prefab root (outside the car visual) or `panel_path`. Runtime `LandingPanel<i>` InteractableComponents at landings 1..n. QC-11 |
| `hack_terminal` | `HackTerminal` | Node3D | `duration_s` (-1 = `hack_duration_s`), `interruptions: Vector2i` ((-1, -1) = `hack_interruptions`), `targets: Array[NodePath]` ([]), `pause_on_alarm: bool` (false), `pause_on_event: StringName` (&""), `resume_on_event: StringName` (&"") | `hack_start_s` (restart `hack_restart_s`) | `Screen` (MeshInstance3D), `Panel` | Floor rack 0.6 × 2.0 × 1.0 m (placeholder) centred on the pivot, front −Z. `Collision` StaticBody3D (layer 1), fitted to the visual. QC-12 |
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
* QC-37 hand saw (G.SAW_TARGET, `saw_cut(seconds, attacker_net_id)` from the saw weapon's cutting ticks;
  `saw_point()` where the prefab has one): `deposit_box` (opens its take_loot), `padlock` (opens targets),
  `safe` with &"saw" in `methods` (hand_saw_safe_s by size, beaten_by &"saw"), SAW `drill_point`
  (effective_duration x hand_saw_drill_point_mult, opens its target).
* `hub_station` (QC-44, safehouse): an instant press emits `station_used(station_id, crew)` and
  `station_requested(station_id)` (no heist facts). The hub crew (`CrewController.spawn_for_hub`, QC-43) is a
  civilian with its own InteractionSystem, so it needs no HeistRuntime.
* `gear_pickup` (S1.3, start_mode = civilian): a civilian takes their gear. Civilian mode ends (casing:
  can mask up), and it emits `item_picked_up(&"item.gear", slot)`. It stays for the rest of the crew.
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

A2-08 (D-037, Glasshouse feedback):

* `window`: at ready the `GlassBody/Shape` box is replaced by one fitted to the visual's `Glass`:
  the merged AABB of every MeshInstance3D at or under `Glass`, in the prefab's space (with the
  sash closed). Depth is at least `WindowPrefab.GLASS_MIN_DEPTH_M` (0.05 m). The placeholder
  still gives 1.0 × 1.2 m. With no Glass mesh, the saved box stays. `glass_aabb()` exposes it.
* `safe` KEYCARD method: list `&"keycard"` in `methods`. The safe's own Interactable never offers
  it, so a keycard-only safe has its Interactable disabled. Wire the reader either way (both work
  together and the safe opens once):
  1. the keycard_reader's `targets` lists the safe, or
  2. the safe's new `reader: NodePath` points at the reader (`KeycardReader.bind_target(safe)` at ready).

  A completed reader (a keycard, or an ECM on the reader) calls `Safe.open_by_keycard()`. This
  beats the lock (`beaten_by = &"keycard"`), then the time lock applies as for any method. A safe
  without `&"keycard"` in `methods` ignores the call and logs a warning.
* `keycard_reader`: targets that have `open_by_keycard()` get that call instead of
  `unlock()` + open. `bind_target(node)` adds a runtime target. Every target is opened once.
* `door` `push_bar` (fire exits): while closed, the door opens only from the inside, the front
  (−Z, UsePoint) side. That means the user's position in the door's local space has z < 0 (pair it
  with `swing` INWARD, so it opens away from the pusher toward +Z, the outside). From outside, the
  crew interaction is blocked with `Door.BLOCK_PUSH_BAR_OUTSIDE` (`ui.blocked.push_bar_outside`,
  a string for ENV B). `can_npc_open` / `passable_for` / `npc_open` are false for outside NPCs, so
  they treat it as locked from that side, and the `NavLink` is one-way (−Z → +Z) while it is
  closed. Opening from inside still follows `lock`. Once open, it is a normal door and either
  side may close it. `is_inside(node)` exposes the side test.
* `security_camera`: the `Collision` box was moved 2.5 cm forward (centre z −0.225, size 0.45).
  It now spans z [−0.45, 0], entirely in front of the wall-mount pivot.

A3-09 (D-040, Night Deposit) / A3-10 (D-042, Shadow Ledger):

* `bag_lift` (QC-11): landing 0 is the prefab itself (the car starts there), landings 1..n are the
  `targets` markers (place each at the car-floor centre of its floor, −Z = car front; the car keeps
  its `Car` rest offset at every landing). One panel per landing: `Interactable` at landing 0 and
  runtime `LandingPanel<i>` children at the same offset from landing i (ENV C dresses those panels;
  only landing 0's `Panel` is in the visual). Kind `send_lift` where the car stands (goes to the
  next landing, (i + 1) % count), `call_lift` elsewhere (brings it there). Blocked while moving
  (BLOCK_STATE) or with more than `capacity` bags in the car (`BagLift.BLOCK_LIFT_FULL` =
  `ui.blocked.lift_full`). Loose bags whose origin is inside the `car_size_m` box (centred on the car
  floor) ride with the car: frozen, no collision, not pick-up-able, for `travel_s`, then released in
  place. Doors `DoorL`/`DoorR` slide apart along local X by `door_travel()` while the car stands:
  `door_open_m` when ≥ 0, else `InteractionTweak.bag_lift_door_open_m` when > 0, else
  `car_size_m.x / 2 − bag_lift_door_margin_m` (0.45 m for the 1.2 m car), so it scales with the car.
  For car-sized shafts set `door_fold`: open leaves fold to `bag_lift_door_fold_scale` of their width
  with the outer edge fixed, so they never leave the car's side walls. Panel: `Panel` is optional in
  the visual. A separate panel (`panel_path`, else a `Panel` Node3D child of the prefab root) keeps the
  panel out of the car visual (so the car's clipping box is the car alone): the visual's `Panel` is
  hidden, landing 0's `Interactable` moves onto the panel, and with `copy_panel` the panel is duplicated
  at landings 1..n as `LandingPanelVisual<i>` (same offset from the landing). Shaft
  (`return_fallen_bags`): a loose bag inside the car's footprint column falling more than
  `bag_lift_fall_m` below the car floor (thrown into the open shaft while the car is away, or lying
  where the car comes down; column down to `bag_lift_pit_depth_m` below the lowest landing) is put
  back `bag_lift_return_front_m` in front of the car at the landing where it entered the shaft
  (`returned_bags` counts them; vertical shafts). Cues `cue.bag_lift_start`, `cue.bag_lift_arrive`. API: `send(to, slot)`, `landing`,
  `destination`, `is_moving()`, `travel_left()`, `bags_in_car()`, `landing_transform(i)`. P2
  limitation: the car is not replicated to clients yet.
* `hack_terminal` (QC-12): kind `start_hack` (hack_start_s) runs `duration_s` silently (no noise, no
  stimulus). The interruption count is rolled at the start on GameRng `&"devices"` in
  `interruptions` [x, y]; interruption k of n sits at (k + 1) / (n + 1) ± `hack_interruption_jitter`
  of a segment (defaults 60 s with 2 = 3 × 20 s, Night Deposit). Interrupted -> kind `restart_hack`
  (hack_restart_s, no auto-restart). Events device_started(id, &"hack", duration) / device_jammed /
  device_restarted / device_finished [R]; cues `cue.hack_start` (also on restart),
  `cue.hack_interrupt`, `cue.hack_done`. Finish -> every `targets` node opens like a finished drill
  (`open_by_device()` -> a Safe arms its time lock; else `unlock()` + open). `Screen` gets a state
  colour material_override (idle / running / interrupted / done). Pause (lockdowns): mission scripts
  call `pause(reason)` / `resume(reason)` (stacked by reason: paused while any is held); paused = the
  run timer frozen, the interaction blocked (`HackTerminal.BLOCK_PAUSED` = `ui.blocked.disabled`), the
  screen shows the interrupted colour; pausing a RUNNING hack emits `device_jammed` + `cue.hack_interrupt`,
  the final resume `device_restarted(net_id, -1)` + `cue.hack_start`. HUD: `is_paused()`, `is_jammed()`,
  `pause_reasons()`. Exports `pause_on_alarm` (reason `&"alarm"` on `alarm_raised`), `pause_on_event` /
  `resume_on_event` (EventBus signal names; reason = the pause signal's name). Shadow Ledger: `duration_s` 45,
  `interruptions` (1, 2).
* `escape_zone` (QC-19): `escape_type` from `EscapeZone.ESCAPE_TYPES` (warning otherwise).
  `arrival_delay_s`: `activate()` starts the approach; until arrival the visual is hidden and nobody
  escapes; `arrival_time_left()` / `has_arrived()` for the HUD; arrival plays `cue.escape_arrive`.
  `bag_only`: once arrived its `Zone` also joins the SECURE_LOOT group (bags resting in it are
  secured as usual) and the zone never ends the heist.
* `ladder` (S10.1b, QC-17): a crew member carrying a bag cannot start a climb (interact, walking
  into it, or `start_climb`). Throw the bag up/down, or use a `bag_lift` / `zipline`.
* Device cues without their own EventBus fact (keypad_accept, c4_armed / c4_explode,
  time_lock_start / time_lock_done, zipline_attach, laser_trip, bag lift, hack) are all emitted as
  `audio_cue_requested(cue_id, pos, prefab net_id)` [R] (test_a3_09_device_cues.gd).

Collision fitting (lead item 6, ENV C props pass):

* Prefabs with a prefab-owned `Collision` box declare the export
  `collision_size_override: Vector3` (default `Vector3.ZERO` = auto): `display_case`, `safe`,
  `camera_station`, `hack_terminal`, `body_container`, `secure_zone` (van) and `security_camera`
  (hitbox). At ready (`GameplayPrefab._fit_collision`, before `_prefab_ready`) the box is chosen in
  this order:
  1. `collision_size_override` with all components > 0: a box of that size placed on the pivot
     (floor: bottom-centre, wall: back-centre, extending toward −Z; ceiling: top-centre, extending
     toward −Y). A visual-supplied `Collision` is turned off.
  2. The visual scene has a `Collision` StaticBody3D (anywhere under the visual root): it is used
     instead. It gets the prefab body's layer and mask and the `hit_owner` meta. The prefab's own body
     is disabled (layer/mask 0, shapes disabled). `collision_body()` returns the active body.
  3. Otherwise, the merged AABB of every MeshInstance3D in the visual (the safe uses only `Body`, so
     the swinging `Door` is not boxed), in prefab space, measured with the art at rest. It is clipped
     to the room side of the pivot (visual_slots.md): floor objects y ≥ 0, wall mounts z ≤ 0, ceiling
     mounts y ≤ 0. Each axis is at least `GameplayPrefab.COLLISION_MIN_EXTENT_M` (0.05 m).
     `fitted_collision_aabb()` exposes it. A visual without meshes keeps the saved box.
* The placeholders give the old sizes: display case 1 × 1.3 × 0.6, safe 0.8 × 1.2 × 0.7,
  body container 1.8 × 1.15 × 1 (lid included), van 2 × 2.2 × 5.04 (rear doors included), hack rack
  0.6 × 2 × 1.04. The camera station is now 1.6 × 1.3 × 0.8 (desk and screens) and the camera hitbox
  is 0.12 × 0.22 × 0.45 (z in [−0.45, 0]).
  A wall camera clips at z ≤ 0. A ceiling camera with real art clips at y ≤ 0. The wall-authored
  placeholder is fitted as a wall mount, and `apply_mount` then lowers both it and `Collision` (QA-26).
* Not fitted: `window` (`GlassBody` already follows `Glass`, A2-08; it now shares
  `merged_mesh_aabb` / `xform_to_self` with this code), `door` (the leaf follows `width_m`, the
  frame collision comes from the visual), `bag_lift` (the `CarBody` floor slab is gameplay-sized), and the
  `Zone` / laser `Trigger` volumes (sized by their exports). `phone`, `alarm_button`,
  `keycard_reader`, `keypad`, `code_note`, `deployable`, `small_loot`, `keycard_pickup` and
  `loot_spawn` have no collision of their own.
* `safe` C4: when the fuse ends, the safe also calls `Explosion.apply` at the visual's `DrillPoint`
  (the lock, else 0.6 m up). It uses radius `interaction.c4_blast_radius_m` (3 m), damage
  `interaction.c4_blast_damage` (300), weapon id `item.c4`, and the attacker is the crew member who
  placed it. Under Explosion's rules, a crew-attributed blast never hurts crew members. NPCs and
  `take_hit` targets in the radius and in LOS take L3.6 falloff damage
  (test_prefab_collision_fit.gd).
