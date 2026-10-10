# Contract: pre-planning and assets (v1.0, D-038)

PD2 rows: C3 (assets, favors, plans, votes), C1/C2 (board and briefing hand-off).

| Producer | What |
|---|---|
| **ENV B** | Global asset library `game/content/data/preplanning/assets/*.tres` (AssetDef data), menu UI, voting, payment, and **resolution**: `PreplanPlan.apply()` → `PreplanResult` (below). Single source of truth for what an asset does. |
| **ENV C** | Per-heist availability and overrides in `HeistDef.preplanning`, `PREPLAN_POINT` markers in the map, a top-down blueprint image `docs/levels/<id>/blueprint.png` + `game/world/heists/<id>/<id>_blueprint.png` (reuses the plan renderer). |
| **ENV A** | Applies a `PreplanResult` at launch: modifiers, drops, spawn and escape tags, forced variants, reveals. Never re-resolves the catalog. |

## AssetDef fields (library entry; per-heist overrides merge over it)

| Field | Type | Meaning |
|---|---|---|
| `id` | StringName | `asset.<name>` |
| `cost` | int | spending cash at Routine; scaled by the DifficultyDef asset multiplier |
| `favors` | int | favor cost (per-day budget from `HeistDef.preplanning.favors`) |
| `max_count` | int | per heist |
| `point_categories` / `point_ids` | Array | location-limited asset; both empty = crew asset (no map location) |
| `vote_group` | StringName | non-empty = a **plan** (one option per group by majority vote, host breaks ties) |
| `grants` | Dictionary | modifier keys (registry only) → TEAM source `asset.<id>` |
| `drop` | StringName | spawn kind at the chosen point (`deployable.ammo_bag`, `deployable.body_bag_case`...) + optional `params` |
| `spawn_tag` | StringName | crew spawns at PLAYER SpawnPoints with this tag |
| `escape_tag` | StringName | restricts escape activation to escapes with this objective_tag |
| `force_variants` | `{group: [slot_ids]}` | or empty, to take `variant_group`/`variant_slot` from the chosen point's params |
| `reveals` | Array[StringName] | variant groups shown on the HUD/blueprint (insider info) |

`HeistDef.preplanning` (ENV C data): `{ "favors": int, "disable": [asset ids], "assets": { asset_id: {override fields} } }`.
A new id under `"assets"` adds a heist-only asset (needs `effect`/payload). `favors` is the heist's design budget
(typically 3–4); tests read it from the def, never hard-code it (D-046).

## PREPLAN_POINT (map)

`Marker3D` nodes under `<Map>/Preplan` (new optional contract node, heist_map.md v1.2), in group
`G.PREPLAN_POINT`. **The node name is the point id.** Metadata: `category` (`drop_zone`, `player_spawn`,
`escape`, `insider`, ...), `label` (strings key), `floor` (int), `params` (Dictionary, e.g.
`{spawn_tag, variant_group, variant_slot}`). ENV B reads points by instancing the map scene from
`HeistRegistry.map_scene_path(id)` without adding it to the tree.

## Launch: `options["preplan"] = PreplanResult` (version 1)

```
{ "version": 1,
  "modifier_sources": { asset_id: { key: value } },        # A: Modifiers.set_source(TEAM, asset_id, ...)
  "drops": [ { "asset": id, "kind": StringName, "point": point_id, "params": {} } ],
  "spawn_tag": StringName,                                 # &"" = default spawns
  "escape_tag": StringName,                                # &"" = mission default
  "force_variants": { group: [slot_ids] },
  "reveals": [ group ],
  "cash_spent": { crew_slot: int },                        # already charged by ENV B
  "plan": { ... } }                                        # PreplanPlan.to_dict(), for results/replay
```
ENV A's dev option `options["preplanning"]` (asset ids) may stay for tests, but it must produce the same
PreplanResult through ENV B's resolver (`PreplanPlan.resolve_ids(heist_id, ids)`), not through its own logic.

## Payment and votes
* Each player pays for the assets **they** place. A voted plan's cost is split equally among the human
  crew members. AI never pays.
* Votes in co-op go through `Net.lobby_send(kind, data)` / `Net.lobby_message` (core, D-038). Solo: the
  host decides alone.
