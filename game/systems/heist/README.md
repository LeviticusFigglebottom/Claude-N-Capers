# Heist runtime: launch options, heist modes, pre-planning assets

Owner: **ENV A**. Code: `heist_launcher.gd`, `heist_runtime.gd`, `heist_mission.gd`,
`variant_resolver.gd`, `preplan_assets.gd`, `preplan_drop.gd`. Contracts: `docs/contracts/test_hooks.md`,
`heist_map.md`, `modifiers.md`, `events.md`. Rows: S11.3, C3 (A2-07).

## Launch

```gdscript
var rt: HeistRuntime = await HeistLauncher.launch(heist_id, seed, difficulty, parent, {
	"ai_teammates": 3, "loadouts": {slot: Loadout}, "skip_casing": false,
	"preplanning": [&"asset.body_bag_drop", &"asset.van_position"],   # see below
})
```

The launch is server-side. Run it after the pre-planning vote has settled. Clients learn the chosen
assets from the lobby, and the effects reach them through the usual replication (variants in
`heist_loaded`, modifiers, spawned nodes).

## Heist modes (S11.3, `HeistDef.mode`, mirrored in `HeistRuntime.heist_mode`)

| Mode | Behaviour |
|---|---|
| `STEALTH_OR_LOUD` | Starts in CASING (or STEALTH with `skip_casing`). The alarm moves to LOUD and the assault director starts. |
| `STEALTH_ONLY` | On the alarm: the phase goes to LOUD (guards fight, civilians flee), then `voice_line_requested(&"mercer", &"vo.mercer.abort", {})` [R]. After `StealthTweak.stealth_only_abort_s` (5 s) comes `heist_ended` with `success = false`. The assault director never starts. |
| `LOUD_ONLY` | Starts in LOUD with `went_loud = true` and every crew member masked, so there is no casing. The director starts right away. |

## Pre-planning assets (C3)

### Catalog: `HeistDef.preplanning`

`{ asset_id: AssetDef }`. Ids follow `asset.<name>` (groups.md), e.g. `&"asset.body_bag_drop"`.
A bare id also works: the modifier source and tag become `asset.<id>` either way.

AssetDef keys. ENV A reads only the effect keys. `cost`, `favors`, `type` and any display keys
belong to ENV B's UI. Effects apply independently, so one asset can combine several of them.

| Key | Type | Effect at launch |
|---|---|---|
| `cost` / `favors` | int | UI only (spending cash / blueprint favors). |
| `type` | StringName | UI and informational: `&"modifier"`, `&"drop"`, `&"spawn"`, `&"escape"`, `&"variant"`, `&"insider"`. |
| `grants` | `{modifier_key: value}` | `Modifiers.set_source(Modifiers.TEAM, &"asset.<id>", grants)` is applied before the crew spawns, so counts such as cable ties and body bags include it. `HeistRuntime.teardown()` clears it through `Modifiers.clear_all()`. |
| `slot` + `drop` | StringName + StringName | Spawns a drop of kind `drop` (`&"ammo_bag"`, `&"doctor_bag"`, `&"body_bag_case"`...) at the PREPLAN_POINT `slot`. Optional `"scene": String` (a PackedScene path) and `"params": Dictionary`. |
| `spawn_tag` | StringName | The crew spawns at the PLAYER SpawnPoints whose `tags` contain it, e.g. `&"preplan_spawn_alley"`, instead of the defaults. SpawnPoints tagged `preplan*` are never default spawns. If no SpawnPoint matches, the defaults are used and an error is logged. |
| `escape_tag` | StringName | `HeistMission.activate_escape()` called with no tag activates only the escapes whose `objective_tag` equals it. A mission that passes an explicit tag keeps it. |
| `force_variants` | `{group: [slot_ids]}` | The VariantResolver pins those slots active, like a rare `force_active`. Examples: `asset.inside_keycard` forces `keycard: [kc_breakroom]`, and `asset.van_position` forces the `escape` slot. Pinning changes how the rest of the roll consumes the RNG, so a seed's other rolls may differ. |
| `reveals` | `[groups]` | Insider info: `rt.preplan.revealed_variants(rt.variants)` returns `{group: resolved value}` for the HUD/map. Clients get the full variants in `heist_loaded`. |

### Launch option `options["preplanning"]`

* `Array` of asset ids: each id is looked up in `HeistDef.preplanning`. Unknown ids get a warning and are ignored.
* `Dictionary` `{ id: true | AssetDef }`. With `true`, the catalog entry is used. With a Dictionary,
  its keys are merged over the catalog entry, so a launch can choose, say, a different `slot` for a
  location-limited asset. If the heist has no catalog entry for the id, the Dictionary is the whole definition.

Assets apply in the String order of their ids. For `spawn_tag` and `escape_tag`, the first chosen asset that sets the key wins.

### PREPLAN_POINT matching (ENV C)

Any `Node3D` inside the map in group `G.PREPLAN_POINT` (`&"preplan_point"`). Its slot name is
checked in this order:
1. an `asset_slot` property (a script export),
2. `asset_slot` node metadata,
3. the node name.

The drop spawns under `HeistRuntime.dynamic_root` and takes the point's global transform, so the
point's −Z is the drop's facing.

### Drops

`PreplanAssets.register_drop(kind, scene_path_or_factory)` registers how a drop kind is built. A
factory is a `Callable(asset_id: StringName, def: Dictionary) -> Node3D`. The owning system
registers its prefab here; the deployables are the expected case. An unregistered kind looks for
`res://systems/prefabs/<kind>/<kind>.tscn`. If that does not exist either, the drop is a
`PreplanDrop` marker: a Node3D with `asset_id`, `kind`, `params`, `objective_tag` and `net_id`,
in group `preplan_drop`.

On every spawned drop:
* an empty `objective_tag` is set to `asset.<id>`, so `find_by_tag(&"asset.<id>")` works,
* `asset_id` is set if the node has that property,
* `configure_preplan(asset_id, def)` is called if the node has that method.

`rt.preplan.drops` maps each asset id to its node.

### Example

```gdscript
def.preplanning = {
	&"asset.zip_ties_drop": {"cost": 1000, "favors": 1, "type": &"modifier", "grants": {&"stealth.cable_ties_extra": 2}},
	&"asset.body_bag_drop": {"cost": 2000, "favors": 2, "type": &"drop", "slot": &"alley_dumpsters", "drop": &"body_bag_case"},
	&"asset.spawn_alley": {"cost": 0, "favors": 1, "type": &"spawn", "spawn_tag": &"preplan_spawn_alley"},
	&"asset.van_position": {"cost": 500, "favors": 1, "type": &"escape", "force_variants": {&"escape": [&"van_alley"]}},
	&"asset.inside_keycard": {"cost": 3000, "favors": 2, "type": &"insider", "force_variants": {&"keycard": [&"kc_breakroom"]}, "reveals": [&"keycard"]},
}
```
