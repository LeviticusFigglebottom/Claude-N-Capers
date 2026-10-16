# Heist runtime: launch options, heist modes, pre-planning assets

Owner: **ENV A**. Code: `heist_launcher.gd`, `heist_runtime.gd`, `heist_mission.gd`,
`variant_resolver.gd`, `preplan_assets.gd`, `preplan_drop.gd`. Contracts: `docs/contracts/test_hooks.md`,
`heist_map.md`, `modifiers.md`, `events.md`. Rows: S11.3, C3 (A2-07, A3-08).

## Launch

```gdscript
var rt: HeistRuntime = await HeistLauncher.launch(heist_id, seed, difficulty, parent, {
	"ai_teammates": 3, "loadouts": {slot: Loadout}, "skip_casing": false,
	"preplan": preplan_result,   # PreplanResult from ENV B (see below)
})
```

The launch is server-side. Run it after the pre-planning vote has settled. In a live co-op session the
host's `launch()` sends the bring-up to every connected client (below); clients never call `launch()`.

## Co-op: client bring-up and replication (A3-07, net.md)

```gdscript
# Client (B's lobby): the counterpart of launch(). Await it before the host launches.
var rt: HeistRuntime = await HeistLauncher.launch_client()   # replica, or null
# ...or once in the lobby (after Net.join): build the replica whenever the host launches.
HeistLauncher.auto_join(null, {}, func(rt: HeistRuntime) -> void: hud.bind(rt.hud_model))
# ...or by hand from the Net.lobby_message(from_peer == 1, HeistLauncher.BRING_UP_KIND, data):
var rt2: HeistRuntime = HeistLauncher.join_running(data)   # synchronous; null on error
```

### Client heist launch: `HeistLauncher.launch_client` (D-049 item, for net.md / test_hooks.md)

`static func launch_client(parent: Node = null, options: Dictionary = {}, timeout_s: float = 0.0) -> HeistRuntime` (await it)

* **When to call:** on a client (`not Net.is_authority()`), after `Net.join()` connected and **before** the
  host calls `HeistLauncher.launch()`: at the latest in the handler of the lobby's own "starting" message
  (lobby messages are reliable and ordered, so the bring-up arrives after it). The host side is unchanged:
  `await HeistLauncher.launch(heist_id, seed, difficulty)` sends the bring-up to every client.
* **What it does:** waits for the next `Net.lobby_message(1, HeistLauncher.BRING_UP_KIND, data)`, builds the
  replica with `join_running(data, parent, options)` inside that handler (synchronously, so the
  replication RPCs right behind it find their nodes), then awaits two physics frames like `launch()`.
  `parent` null = the host's runtime parent path (RPC paths must match; the tree root by default).
  `options` as `join_running` (`map_packed`, `map_scene`, `extra_services`).
* **Returns:** the replica `HeistRuntime` (`is_replica == true`, `heist_loaded` already emitted, crew,
  NPCs and map state mirrored from the bring-up snapshot; `rt.hud_model` is the client's LocalHudModel).
  End of heist: the replica receives the host's `heist_ended(result)` [R]; the app flow then calls
  `rt.teardown()` and `Net.leave()` as on the host.
* **Failure modes (returns null, never throws):** called on the authority (host / solo: `Log.error`);
  bring-up rejected (version != `BRING_UP_VERSION`, unknown map: `Log.error`); `timeout_s > 0` elapsed
  without a bring-up (`Log.warn`); connection to the host lost (`multiplayer.server_disconnected`) or the
  session ended (`Net.leave()` -> `Net.session_ended`); `HeistLauncher.cancel_launch_client()` called
  (e.g. the player left the lobby). `timeout_s <= 0` (default) waits indefinitely for one of those.
* While a `launch_client()` is pending, `auto_join()` stands aside (no double replica); do not combine
  them for the same heist.
* **Host lost mid-heist:** the replica's `HeistNetSync` (`rt.net_sync`) emits `host_lost()` once
  (`host_lost_at_s` = heist time). It tears nothing down: the app flow shows its "host left" screen and
  calls `rt.teardown()` + `Net.leave()`. TODO (net round 4): switch to `Net.host_lost` /
  `Net.connection_failed` once `game/core/net.gd` has them.

**Bring-up** (`HeistNetSync.bring_up()`, sent by `launch()` right after `HeistRuntime.start()` and
before any physics frame, through `Net.lobby_send(HeistLauncher.BRING_UP_KIND, data)` because the
client has no heist node yet). `data` (version `HeistLauncher.BRING_UP_VERSION` = 1):

| Key | Meaning |
|---|---|
| `heist_id`, `seed`, `difficulty`, `map_scene` | Same map (`map_scene` = the host's res:// path; else `map_path(heist_id)`). The client calls `GameRng.begin_run(seed)`. |
| `variants` | The host's resolved dict. The client **applies** it (`VariantResolver.apply`), it never rolls. |
| `map_ids` | `{path relative to the map: net_id}` for every map-placed entity with a net id (host claims them in tree order). The client adopts them with `NetIds.adopt`; unresolved paths land in `rt.replica_missing_ids` (+ `Log.error`). |
| `crew_ids` | `{slot: net_id}`. |
| `phase`, `went_loud`, `heist_time_s`, `preplan` | Phase machine state; the normalized PreplanResult (TEAM modifiers re-applied on the client). |
| `runtime_path` | The host's HeistRuntime node path. RPC paths must match: launch under the tree root (the default) on both sides; `join_running(data, null)` picks the same parent. |
| `snapshot` | `{spawns: [descriptor], states: {net_id: state}, services: {...}}`: every dynamic entity and the full discrete state at launch. |

The client builds the runtime with `HeistRuntime.start(..., {"bring_up": data})` (`rt.is_replica == true`):
same services (HUD model, interaction, stealth... all idle behind `Net.is_authority()`), no mission
binding, no AI brains, no director. `heist_loaded` is emitted by the replica itself (not relayed).

**Replication** (`HeistNetSync`, child `NetSync` of HeistRuntime, service `&"net_sync"`; idle in solo):

| What | How | Rate |
|---|---|---|
| Dynamic entities (NPCs, crew, loot bags, deployables, pre-plan drops: any child of `dynamic_root` with a `net_id`) | `_rpc_spawn([{scene, script, name, net_id, xform, params}])`, built by `NetEntityCodec.describe/instantiate`. NPC replicas drop `Brain`/`Motor`/`Gunner`/`NavAgent`; bags are frozen (host physics). | every physics frame (new children) |
| Despawns (bag secured, small loot taken, NPC removed, any replicated id leaving the tree) | `_rpc_despawn(ids)` | every physics frame |
| Discrete state (door open/locked, glass broken, camera off, device state/progress, pickups, deployable uses, NPC alert/alive/health, crew state/mask/vitals/inventory/carried bag, bag carrier/secured) | `_rpc_state(diffs, services)`: only changed keys. Prefabs may implement `_net_state()` / `_apply_net_state(state)` (Door, WindowPrefab, DisplayCase, SecurityCamera do); otherwise `NetEntityCodec.GENERIC_PROPS` are mirrored. | 15 Hz, reliable |
| Service state: interaction session per crew slot (HUD progress / blocked reason), known codes (A2-04), custody timers + highlighted hostage, phase / went_loud, Commander Brandt `{present, resistance}` (ui_hud v1.3) | `InteractionSystem.net_sessions()`, `CodeRegistry.net_state()`, `CustodySystem.net_state()`, `HeistNetSync.captain_state()` and their `apply_*` mirrors | 15 Hz, reliable, on change |
| Transforms: NPCs, crew members the peer does not own (position, look yaw/pitch, crouch), loose bags | `_rpc_xforms` (only what moved) | 15 Hz, unreliable_ordered |
| Own crew member | client-predicted; intent + position at 30 Hz (`CrewController`). Server `teleport()` of a remote human is sent to its owner (`_rpc_owner_teleport`, with a sequence number so stale positions are ignored); a rejected position (> `teleport_reject_m`) is reconciled the same way. | |

RPCs that would reach a client before its bring-up (mask-up at a LOUD_ONLY start, deployable/ammo
HUD syncs at spawn) are skipped while `HeistNetSync.can_rpc(node)` is false: that state travels with
the bring-up snapshot.

Known gaps (P6 / follow-ups): drop-in mid-heist (the bring-up goes only to peers connected at launch);
events relayed for an entity can reach a client just before that entity's spawn (same frame);
remote transforms are applied without interpolation; components added at runtime by server-only code
(the body-bag interactable on corpses, police surrender/trade interactables, brain-built nodes) do not
exist on replicas, so the HUD shows no prompt for them on clients; DeployableSystem inventory rows,
Brandt's per-hit resistance and AssaultDirector internals are not mirrored (the HUD gets the assault
phase from events); a host `teardown()` does not tear clients down (they get `heist_ended` [R]).
Test: `tests/a/test_a3_07_coop_loopback.gd` (host in the test process, client in a second headless
process; see its header for why one process with two SceneMultiplayer branches cannot work).

## Heist modes (S11.3, `HeistDef.mode`, mirrored in `HeistRuntime.heist_mode`)

| Mode | Behaviour |
|---|---|
| `STEALTH_OR_LOUD` | Starts in CASING (or STEALTH with `skip_casing`). The alarm moves to LOUD and the assault director starts. |
| `STEALTH_ONLY` | On the alarm: the phase goes to LOUD (guards fight, civilians flee), then `voice_line_requested(&"mercer", &"vo.mercer.abort", {})` [R]. After `StealthTweak.stealth_only_abort_s` (5 s) comes `heist_ended` with `success = false`, `fail_reason = &"stealth_only_alarm"`. The assault director never starts. |
| `LOUD_ONLY` | Starts in LOUD with `went_loud = true` and every crew member masked, so there is no casing. The director starts right away. |

**Start modes (S1.3, D-065, `HeistDef.start_mode` / `options["start_mode"]`, `HeistRuntime.start_mode`).**
- `&"casing"` (default): the crew starts unmasked (casing).
- `&"civilian"`: every crew member starts civilian (`CrewController.civilian`, `player_mode` &"civilian"). Civilians:
  - can't be detected (laser grids still trip), mask up or fire;
  - use only `civilian_allowed` interactables (block reason `ui.blocked.civilian`).
- A human takes their gear at a `gear_pickup` (`ui.prompt.pick_up_gear`): civilian ends (casing) and `item_picked_up(&"item.gear", slot)` [R] fires.
- **AI teammates** gear up when the first human crew member picks up gear (P5 ruling); they never walk to the bag.
- An alarm masks everyone, which ends civilian mode for all.

**Police start delay (QC-35, D-064).** `HeistMission.police_delay_s` holds the assault director after the heist goes loud. For example, Dockside Burn's cartel phase rolls 60/90/120 s in `_on_mission_start()`. Setting 0 starts the police at once.

`HeistResult.fail_reason` (events.md, D-038 QA-19): `&""` on success; `HeistRuntime.FAIL_STEALTH_ONLY_ALARM`,
`FAIL_ALL_CUSTODY` (for the custody rule) or the caller's reason via `end_heist(false, [], reason)` /
`HeistMission.end_heist(false, reason)`; a failure without a reason reports `FAIL_ABORT` (`&"abort"`).

## Pre-planning (C3): applying a PreplanResult

Contract: `docs/contracts/preplanning.md` v1.0 (D-038). **ENV B resolves** the plan
(`PreplanPlan.apply()` → PreplanResult); **ENV A only applies it** and never reads the asset catalog
(`HeistDef.preplanning` is ENV B/C data). `rt.preplan` is the `PreplanAssets` instance.

### Launch options

| Option | Meaning |
|---|---|
| `options["preplan"]` | The PreplanResult (version 1) from ENV B's menu flow. Applied as given. |
| `options["preplanning"]` | Dev/test shortcut: asset ids, an `Array` or `{id: point_id \| true}`. They are resolved by ENV B: `PreplanPlan.resolve_ids(heist_id, ids)` when ENV B ships it (B4-08). Until then a `PreplanBoard.build(heist_id, difficulty, def)` + `PreplanPlan.add(id, point, 0)` + `apply()` bridge is used: a located asset without a point takes the first allowed point of the board's blueprint. Ignored when `"preplan"` is set. |
| `options["variant_table"]` | Dev/test: a `HeistVariantTable` that replaces the map's `variant_table` for this run (the roll and the mission's rare-event reads), e.g. a duplicate with a group's `pick` narrowed so a `force_variants` pin is the only slot. The map scene and its `.tres` are untouched. Server only (not sent to clients; a replica uses the host's resolved variants). |

`PreplanAssets.normalize()` maps the result to the contract keys. ENV B's pre-contract hand-off keys
are accepted too: `spawns[{asset, item, point}]` → `drops`, `player_spawn_tag` → `spawn_tag`,
`reveal_variant_groups` → `reveals`, `force_variants: [{asset, group, slot}]` → `{group: [slots]}`.

### What is applied

| Result key | Effect at launch |
|---|---|
| `modifier_sources` `{asset_id: {key: value}}` | `Modifiers.set_source(Modifiers.TEAM, asset_id, grants)` before the crew spawns, so counts such as cable ties include it. `teardown()` clears it (`Modifiers.clear_all()`). |
| `drops` `[{asset, kind, point, params}]` | One node per drop at the PREPLAN_POINT `point` (below), under `dynamic_root`, with the point's global transform (−Z = facing). |
| `spawn_tag` | The crew spawns at the PLAYER SpawnPoints whose `tags` contain it. SpawnPoints tagged `preplan*` are never default spawns. No match: defaults + an error. |
| `escape_tag` | `HeistMission.activate_escape()` with no tag activates only escapes whose `objective_tag` equals it. |
| `force_variants` `{group: [slot_ids]}` | The VariantResolver pins those slots active (like `force_active`). Pinning changes how the rest of the roll consumes the RNG. |
| `reveals` `[group]` | `rt.preplan.reveals()`; `rt.preplan.revealed_variants(rt.variants)` → `{group: resolved value}` for the HUD/blueprint. |
| `cash_spent`, `plan` | Kept for results/replay (`rt.preplan.cash_spent()`, `rt.preplan.result["plan"]`). ENV A never charges. |

API: `setup(options, def, heist_id, difficulty)`, `is_active()`, `result`, `asset_ids()`,
`has_asset(id)`, `forced_variants()`, `apply_modifiers()`, `spawn_tag()`, `escape_tag()`, `reveals()`,
`revealed_variants(variants)`, `cash_spent()`, `spawn_drops(map, parent)`, `drops` (point id → node),
static `normalize(raw)`, `resolve_ids(heist_id, difficulty, ids, def)`, `find_point(map, point_id)`,
`source_name(id)`, `register_drop(kind, scene_or_factory)` / `unregister_drop(kind)`.

### PREPLAN_POINT lookup (heist_map.md v1.2)

1. `<Map>/Preplan/<point_id>`: a Marker3D whose **node name is the point id** (the contract).
2. Legacy fallback: any node in group `G.PREPLAN_POINT` named `point_id`, or with an `asset_slot`
   property/metadata equal to it.

### Drops

Kind resolution, in order:
1. `PreplanAssets.register_drop(kind, scene_path_or_factory)` (factory: `Callable(asset_id, drop: Dictionary) -> Node3D`).
2. `deployable.<x>` with a DeployableDef (`DeployableSystem.def_for`): an unowned `DeployablePrefab`
   (`owner_slot = -1`, the def's uses). PD2: pre-planned bags belong to no one.
3. `res://systems/prefabs/<x>/<x>.tscn` (the `deployable.` prefix stripped).
4. A `PreplanDrop` marker (Node3D with `asset_id`, `kind`, `params`, `objective_tag`, `net_id`, group `preplan_drop`).

On every drop: an empty `objective_tag` becomes `asset.<id>` (`find_by_tag(&"asset.<id>")`),
`asset_id` is set if present, and `configure_preplan(asset_id, drop)` is called if the node has it.

### Example

```gdscript
options["preplan"] = {
	"version": 1,
	"modifier_sources": {&"asset.extra_cable_ties": {&"stealth.cable_ties_extra": 2}},
	"drops": [{"asset": &"asset.ammo_bag_drop", "kind": &"deployable.ammo_bag", "point": &"pp_alley_dumpsters", "params": {}}],
	"spawn_tag": &"preplan_spawn_alley", "escape_tag": &"",
	"force_variants": {&"keycard": [&"kc_breakroom"]}, "reveals": [&"keycard"],
	"cash_spent": {0: 2000}, "plan": {},
}
```

## Variant rule fields (A2-08)

New optional fields for `HeistVariantTable` (D-037). For the lead to fold into heist_map.md §5.
A table that does not use them rolls exactly as before: same seed, same result.
Rules still resolve in table order. Every group named in `force_if` or `slot_requires` must be
resolved by an EARLIER rule. A forward or unknown reference is logged with `Log.error`
("contract violation ... not resolved earlier") and counts as "not active".

Conditions share one shape, `{other_group: [slot_ids]}`, with the same meaning as `requires`:
every listed group must have one of its listed slots active (AND across groups, OR within a
list). An empty list means any slot of that group.

### `force_if` (rule): conditional pinning

```gdscript
{"group": &"back_door", "pick": Vector2i(0, 1),
 "force_if": [{"if": {&"smoker": [&"smoker_alley"]}, "then": [&"propped"]}]}
```

`Array` of `{"if": condition, "then": [slot_ids of this rule's group]}`. When an entry's `if`
holds, its `then` slots are pinned active, the same way as a rare `force_active` or a
pre-planning `force_variants`:
* Pinned slots are added first and count toward the rolled pick. The remaining picks are then
  rolled (weighted) until the group reaches the pick count. If the pinned slots already exceed
  it, they are all kept.
* They are applied even when the rule's own `requires` / `excludes` reduce the pick to 0, and
  they ignore `slot_requires`.
* A `then` id that is not a slot of the group gets a warning and is ignored.
* RNG: the pick count is always drawn. Pinning only changes the draws of this group's weighted
  picks when it fires.

This replaces the smoker⇒propped "excludes + mission logic" workaround. Put the `smoker` rule
before `back_door`, then use `force_if` (and `slot_requires`, below, if `propped` must never
appear without the smoker).

### `slot_requires` (rule): per-slot eligibility

```gdscript
{"group": &"keycard", "pick": Vector2i(1, 1),
 "slot_requires": {&"kc_jeweler": {&"staff": [&"jeweler_in"]}}}
```

`{slot_id: condition}` (String or StringName keys). A slot whose condition fails is left out of
the weighted pick for this rule. Slots pinned by `force_active`, `force_variants` or `force_if`
ignore it. If too few eligible slots are left, the group gets fewer than `pick`.

### `min_difficulty` (rare event)

```gdscript
{"id": &"rare.cop_on_scene", "chance": 0.05, "effects": {"force_active": {"group": &"cop_on_scene", "slot": &"cop_front"}},
 "good": false, "min_difficulty": Enums.Difficulty.HAZARDOUS}
```

`int` (`Enums.Difficulty`). The event's chance draw is ALWAYS made. Then, below
`min_difficulty`, the event does not fire: it is not added to `"rare"` and its effects are not
applied. Adding the field therefore never changes other events' or rules' results, at any
difficulty. At or above `min_difficulty` the event behaves as if it had no gate. Use this
instead of the zero-weight carrier slots.

### `weights_by_difficulty` (scalar)

```gdscript
{"id": &"guard_count", "values": [2, 3, 4], "weights": PackedFloat32Array([3, 2, 1]),
 "weights_by_difficulty": {Enums.Difficulty.BRUTAL: PackedFloat32Array([1, 2, 3])}}
```

A `Dictionary` `{difficulty int: PackedFloat32Array}` (a plain Array of numbers is also
accepted). At a listed difficulty it replaces `weights`. Unlisted difficulties use `weights`. As
with `weights`, a size that does not match `values` falls back to a uniform pick.

### `weights_by_difficulty` (rule): per-difficulty slot weights (A3-10, QC-18)

```gdscript
{"group": &"guard_extra", "pick": Vector2i(1, 1),
 "weights_by_difficulty": {
	Enums.Difficulty.BRUTAL: {&"stair_watch": 1.0, &"roof_watch": 1.0, &"extra_none": 0.0},
	Enums.Difficulty.LETHAL: {&"stair_watch": 1.0, &"roof_watch": 1.0, &"extra_none": 0.0}}}
```

The slot-group counterpart of the scalar field above: `{difficulty int: {slot_id: weight}}`
(slot ids as StringName or String). At a listed difficulty, each listed slot uses that weight in
the rule's weighted pick instead of its `VariantSlot.weight`. Slots not listed in the entry, and
difficulties not listed at all, keep `VariantSlot.weight`. Like the scalar field, keys are exact
difficulties: write one entry per difficulty (no "and above"); per-difficulty pick counts stay in
`pick` + `difficulty_add`.
* Determinism: the field changes weights only, never the number or order of draws, so the same
  seed gives the same result, other groups roll exactly as before, and a table without the field
  (or a difficulty without an entry) rolls exactly as before.
* Weight 0 makes a slot unpickable while any slot with a positive weight is left in the pool
  (`RandomNumberGenerator.rand_weighted` semantics, as for `VariantSlot.weight`). Pinned slots
  (`force_active`, `force_variants`, `force_if`) are unaffected.
* A malformed value (`weights_by_difficulty` not a Dictionary, or an entry not a Dictionary) is
  a `Log.error` and is ignored.

## Timed mission events (A3-09)

`HeistMission` helpers for timed events (e.g. Night Deposit's `armored_car_early` at 12:00):

* `elapsed_s: float` (read-only property): heist time since `start()` (`HeistRuntime.heist_time_s`, the sum of
  physics deltas, so it follows `Engine.time_scale`; it stops when the heist ends).
* `schedule_at(time_mark_s, timer_id, callback, after_event = &"") -> bool`: a timer that fires
  at that heist time (a mark already passed fires on the next physics frame). With `after_event`
  (an EventBus signal name) the mark is relative to the FIRST emission of that signal instead
  (one-shot; false and `Log.error` for an unknown signal). Same id rules as `start_timer`: it
  replaces a pending timer with that id, and `cancel_timer` / `timer_left` work on it.
* `spawn_guards(count, spawn_tag) -> Array[Node]`: spawns `count` ordinary guards (pagers,
  patrol graph and tags of their point) at the GUARD SpawnPoints tagged `spawn_tag`, in tree order,
  cycling (a reused point offsets 0.8 m along its X). GUARD SpawnPoints tagged
  `HeistRuntime.SCRIPTED_SPAWN_TAG` (`&"scripted"`) are skipped at load, so tag the armoured-car
  points `[&"scripted", &"armored_car"]`.

```gdscript
func _on_mission_start() -> void:
	if (variant(&"rare") as Array).has(&"armored_car_early"):
		schedule_at(720.0, &"armored_car", func() -> void: spawn_guards(2, &"armored_car"))
```

## Out of bounds (A3-09, QC-14)

`OutOfBoundsSystem` (service `&"out_of_bounds"`, child of HeistRuntime) handles every
`MapZone.Kind.OUT_OF_BOUNDS` zone of the map. It never raises an alarm or makes noise.
* Crew (not in custody) whose body centre (origin + 0.5 m) is in a zone is teleported to the
  nearest PLAYER SpawnPoint tagged `oob_respawn`, else to the nearest PLAYER SpawnPoint. A carried
  bag is dropped first and goes back like a loose bag, so the respawn never moves loot.
  Signal `crew_respawned(slot, spawn)`.
* PLAYER SpawnPoints tagged `oob_respawn` are not used as start spawns (unless the map has no
  other PLAYER spawn).
* Loose bags (not carried, not secured, not frozen on a zipline / lift) remember their last valid
  position: in bounds and at rest (`LootTweak.rest_speed_mps`). While a bag is carried, the
  carrier's last in-bounds standing position (+0.3 m) is used. A bag whose probe point
  (origin + `LootTweak.zone_probe_up_m`) is in a zone goes back there at rest (signal
  `bag_returned(bag)`). A bag that never had a valid position stays put (warning).

## Mission hooks for dominated NPCs (QC, Night Deposit)
Override in `<id>_mission.gd`:
- `_on_civilian_dominated(civilian: Node, crew_slot: int)`: fires on `civilian_intimidated` with the civilian NPC node.
- `_on_guard_dominated(npc: Node, crew_slot: int)`: fires on `guard_dominated` (guards and surrendered cops).

Timed NPC spawns (QC-25, e.g. Night Deposit `armored_car_early`, Brutal+ at 720 s):
```gdscript
func _on_mission_start() -> void:
	if difficulty >= Enums.Difficulty.BRUTAL:
		schedule_at(720.0, &"armored_car_early", func() -> void: spawn_guards(2, &"armored_car"))
```
GUARD SpawnPoints tagged `scripted` are not spawned at load; `spawn_guards(count, tag)` spawns at GUARD
SpawnPoints carrying `tag`.
