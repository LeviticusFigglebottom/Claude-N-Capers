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

The launch is server-side. Run it after the pre-planning vote has settled. Clients learn the chosen
assets from the lobby, and the effects reach them through the usual replication (variants in
`heist_loaded`, modifiers, spawned nodes).

## Heist modes (S11.3, `HeistDef.mode`, mirrored in `HeistRuntime.heist_mode`)

| Mode | Behaviour |
|---|---|
| `STEALTH_OR_LOUD` | Starts in CASING (or STEALTH with `skip_casing`). The alarm moves to LOUD and the assault director starts. |
| `STEALTH_ONLY` | On the alarm: the phase goes to LOUD (guards fight, civilians flee), then `voice_line_requested(&"mercer", &"vo.mercer.abort", {})` [R]. After `StealthTweak.stealth_only_abort_s` (5 s) comes `heist_ended` with `success = false`, `fail_reason = &"stealth_only_alarm"`. The assault director never starts. |
| `LOUD_ONLY` | Starts in LOUD with `went_loud = true` and every crew member masked, so there is no casing. The director starts right away. |

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
