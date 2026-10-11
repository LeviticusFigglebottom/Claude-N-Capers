# Contract: gameplay prefabs (v1.1)

Producer: **ENV A** (`game/systems/prefabs/<name>/<name>.tscn`). Consumer: **ENV C** places them in
maps and assigns `visual_scene`. All prefabs are networked (server-authoritative), have a `net_id`,
ship a placeholder visual, and work with **no** visual assigned (placeholder used).

## Common shape

```
<Prefab> (Node3D, script with class_name)
├── Visual            instantiated from exported `visual_scene` (see visual_slots.md)
├── UsePoint          Marker3D where the interacting character stands, facing -Z toward the object
├── Interactable      InteractableComponent (ENV A) if interactive
└── ...               collision, nav obstacle, audio emitters
```

Common exports on every interactive prefab:

| Export | Type | Meaning |
|---|---|---|
| `visual_scene` | PackedScene | art (ENV C/B). Null = placeholder |
| `interaction_time_s` | float | base hold time (modified by Modifiers) |
| `requires_item` | StringName | e.g. `&"item.keycard"`, `&"item.crowbar"`, `&""` none |
| `stealth_only` / `loud_only` | bool | availability by phase |
| `casing_allowed` | bool | usable while unmasked (default false) |
| `noise` | StringName | noise profile id: `&"silent"`, `&"quiet"`, `&"loud"` (stealth alert radius) |
| `objective_tag` | StringName | lets mission scripts find it |

## Phase-1 prefab list (ENV A ships these in P1)

| Prefab | Purpose | Key exports |
|---|---|---|
| `door` | hinged door; may be locked | `lock: {NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT}`, `swing: {INWARD, OUTWARD, DOUBLE}`, `width_m`, `starts_open`, `code_group` |
| `security_camera` | observer | `fov_deg` (default 60), `range_m` (default 20), `pan_deg`, `pan_period_s`, `destructible` |
| `camera_station` | security-room console: kill/dominate the operator → all cameras off; interact to loop (skill) | `operator_spawn` (NodePath) |
| `display_case` | glass case; break (loud-ish noise) or open (key) to get small loot | `loot_id`, `glass_breaks_alarm` |
| `small_loot` | instant/short pickup cash/jewelry/valuables → no bag | `value`, `loot_id` |
| `loot_spawn` | spawns a bag/stack the crew must bag up/carry | `loot_id`, `count` |
| `keycard_pickup` | picks up a keycard item | — |
| `keycard_reader` | opens bound door(s) | `targets: Array[NodePath]` |
| `keypad` + `code_note` | code door + note revealing the code | `code_group` |
| `safe` | lockable safe (drill/lockpick/C4/code) | `size: {SMALL, MEDIUM, LARGE}`, `methods` |
| `drill_point` | where a drill/saw is placed; jams per Modifiers | `device: {DRILL, THERMAL, SAW}`, `duration_s` |
| `alarm_button` | panic button staff run to | — |
| `phone` | civilians/guards run here to call police | — |
| `window` | breakable glass / openable window | `breakable`, `openable`, `noise` |
| `secure_zone` | wraps a MapZone SECURE_LOOT with a vehicle/drop visual | `visual_scene` (van/drop point) |
| `escape_zone` | escape area; activated by mission | `escape_type` |
| `body_container` | dumpster/closet to hide bagged bodies | `capacity` |
| `ladder` | climbable | `height_m` |
| `zipline` | bag zipline (P2) | `end: NodePath` |
| `laser_grid` | trips alarm (P2) | `pattern` |

Characters (guards, civilians, police, specials, crew) are prefabs too (`npc_*`, `crew_member`) and
take `visual_scene` from `characters.md` art.

New prefab requests from ENV C go to the lead as a status-file question.

## v1.1 additions (QA-13, D-038)
| Prefab | New exports / nodes |
|---|---|
| `door` | `npc_authorized_tags: Array[StringName]` (guard posts allowed through keycard doors); `one_way` (push-bar: opens only from its +Z side; A2-08) |
| `security_camera` | `titan: bool` (indestructible) |
| `keypad` | `targets: Array[NodePath]` |
| `safe` | `code_group`, `time_lock_s`, KEYCARD method bound to a reader (A2-08) |
| `laser_grid` | `beam_count`, `period_s`, `off_s`, `phase_s`, `sweep_beams`; optional visual nodes `Beam0..n` (horizontal for static/timed_off, vertical for sweeping) |
| `deployable` (runtime only) | `res://systems/prefabs/deployable/deployable.tscn` (`DeployablePrefab`): `kind`, `deployable_id`; visual = `DeployableDef.model`, else a `Body` placeholder |
| `bag_lift` (P2, Night Deposit) | Cash/bag lift between floors: `targets: Array[NodePath]` (landing markers), `travel_s`, `capacity` (bags). Bags placed in the car + interact to send. Visual: `Car`, `DoorL/DoorR`, `Panel`. (QC-11, D-040) |
| `hack_terminal` (P2) | Timed silent hack (server rack, time-lock override): `duration_s`, `interruptions` (like drill jams: rolled count; fix = re-interact), `targets`. Visual: `Screen` (A swaps materials for progress), `Panel`. (QC-12, D-040) |
| `escape_zone` (v1.2, QC-19) | `escape_type`: one of `&"van"`, `&"boat"`, `&"heli"`, `&"lift"`, `&"zipline"`, `&"walk"`. `arrival_delay_s` (heli/boat approach after activation; 0 = present). `bag_only` (zipline: bags secured by line, crew leave by another escape). Visual nodes per type: van `Body/DoorL/DoorR`, heli `Body/Rotor`, boat `Body`. (D-042) |

## v1.3 (D-057, B4-18)
| Item | Contract |
|---|---|
| group `saw_target` | Prefabs a saw can cut (deposit boxes, ATMs, padlocks, chained doors). Implement `saw_cut(seconds: float, attacker_net_id: int) -> void` (server); the prefab accumulates cut time and opens itself. Group name constant in `G`. |

## v1.4 (S1.3 civilian mode, D-065)
| Item | Contract |
|---|---|
| `gear_pickup` prefab | kind `&"pick_up_gear"`, prompt `ui.prompt.pick_up_gear`; emits `item_picked_up(&"item.gear", slot)`; not consumed (every crew member uses it). Switches that player civilian → casing. |
| common export `civilian_allowed: bool` | Default false; true on `gear_pickup`. While a player is in civilian mode, interactions without it are blocked with `ui.blocked.civilian`. |
| civilian rules | Undetectable (detection ×0); cannot mask up or fire until gear is picked up; laser grids still trip; an alarm masks everyone and ends civilian mode. |
