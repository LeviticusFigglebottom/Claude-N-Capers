# Pre-planning and assets (B2-01, pd2_fidelity C3)

Owner: ENV B. This file covers the asset schema, the per-heist merge, the plan rules, the plan vote, the
screen API and the **hand-off to the heist start**, which ENV A or the host applies (A2-07). Symbols:
**PD2** means faithful to the research (pd2_research.md §4), and **◇** marks a choice of ours.

## Files
```
content/preplanning/
  preplan_asset_def.gd   PreplanAssetDef (Resource): one asset
  preplan_tweak.gd       PreplanTweak: cost scaling, default favors, blueprint colors
  preplan_blueprint.gd   PreplanBlueprint: top-down schematic + PREPLAN points (meters, x/z)
  preplan_board.gd       PreplanBoard: one heist at one difficulty = merged assets + budget + blueprint
  preplan_plan.gd        PreplanPlan: selections, rules, validate(), apply() hand-off, to_dict()/from_dict()
  plan_vote.gd           PlanVote: per-slot plan votes, majority, host breaks ties
content/data/preplanning/
  assets/<name>.tres              generic asset set (id asset.<name>)
  preplan_tweak.tres
  placeholder_blueprint.tres      used while a heist has no blueprints/<heist id>.tres
  blueprints/<heist id>.tres      (none yet) the real schematic per heist
content/ui/preplanning/
  preplanning_screen.tscn/.gd     PreplanningScreen (UiScreen)
  blueprint_view.gd               BlueprintView: Control-drawn blueprint + marker buttons
```

## Asset schema (`PreplanAssetDef`)
| field | meaning |
|---|---|
| `id` | `asset.<name>`. Strings: `item.asset.<name>.name` / `.desc` |
| `effect` | exactly one: `MODIFIERS`, `SPAWN`, `REVEAL`, `FORCE_VARIANT`, `PLAYER_SPAWN` |
| `category` | UI grouping (`supply`, `intel`, `gear`, `entry`, `access`, `escape`; order in the tweak) |
| `base_cost` | spending cash at Routine, × `PreplanTweak.cost_mult[difficulty]`, rounded to `cost_round` (PD2: prices scale with difficulty) |
| `favors` | favors cost (PD2: the team budget per heist day does **not** scale with difficulty) |
| `point_categories` / `point_ids` | location-limited: allowed PREPLAN_POINT categories, or exact point ids. Both empty means a **crew asset** with no map location |
| `max_count` | copies per plan, each on a different point (crew assets: 1) |
| `exclusive_group` | at most one asset of the group per plan (e.g. `player_spawn`) |
| `vote_group` | a PD2 "plan" (vault method, escape): decided by vote, so one option per group |
| `grants` | MODIFIERS: `{registry key: value}`. Registry keys only (`validate()` and the tests use `ModifierKeys.is_known`) |
| `spawn_item` | SPAWN: a deployable id placed at the chosen point |
| `reveal_variant_group` | REVEAL: insider info. The crew learns which slots of this VariantSlot group rolled |
| `force_variant_group/slot` | FORCE_VARIANT: a fixed slot, or empty to take `{"variant_group","variant_slot"}` from the chosen point's params |
| `tags` | `stealth` / `loud` (UI hint only) |

Cost scaling ◇: `[1.0, 2.0, 4.0, 6.5, 9.5, 13.0]`. Routine to Cataclysm is ×13, as in PD2's doctor bag
example ($1,600 on Normal to $20,800 on Death Wish). The steps in between are ours. Default favors: 10 (PD2 Big Bank).

### Generic set (expressible today)
| id | effect | where | Routine $ | favors |
|---|---|---|---|---|
| `asset.body_bag_case_drop` | SPAWN `deployable.body_bag_case` | `drop_zone` (max 2) | 1,000 | 2 |
| `asset.ammo_bag_drop` | SPAWN `deployable.ammo_bag` | `drop_zone` (max 2) | 1,200 | 2 |
| `asset.doctor_bag_drop` | SPAWN `deployable.doctor_bag` | `drop_zone` (max 2) | 1,600 | 2 |
| `asset.intel_keycards` | REVEAL `keycard` | crew | 1,500 | 1 |
| `asset.intel_cameras` | REVEAL `camera` | crew | 1,200 | 1 |
| `asset.intel_guard_posts` | REVEAL `guard_post` | crew | 1,200 | 1 |
| `asset.extra_cable_ties` | MODIFIERS `stealth.cable_ties_extra` +2 | crew | 800 | 1 |
| `asset.spare_body_bags` | MODIFIERS `stealth.body_bags_extra` +1 | crew | 1,000 | 1 |
| `asset.alternate_entry` | PLAYER_SPAWN (point `spawn_tag`) | `player_spawn`, exclusive | 500 | 1 |
| `asset.escape_position` | FORCE_VARIANT (point's `escape` slot) | `escape`, vote group `escape` | 1,000 | 1 |

Wished for (not expressible yet; each needs a key, a spawn kind or a hook):
* An ECM drop. `deployable.ecm` does not exist, and `stealth.ecm_extra` on TEAM would give every player an ECM.
* A loot-drop / bag-throw position. This needs a SPAWN of a "loot drop zone" (secure zone) prefab.
* A spotter: marks the guards for N seconds at the start. This needs a timed-mark hook.
* An escape-driver upgrade: a faster van return. This needs an escape-timer scalar override.
* Insider assets unlocked by Sixth Sense aced (PD2). This needs a `stealth.insider_assets` FLAG on the profile side.
* Map drawing (PD2 board). P4.

## Per-heist data: `HeistDef.preplanning` (ENV C data, merged by `PreplanBoard.merge`)
```gdscript
preplanning = {
    "favors": 10,                                    # favors budget (default PreplanTweak.default_favors)
    "disable": ["asset.intel_cameras"],              # generic assets this heist does not offer
    &"asset.ammo_bag_drop": {"cost": 900, "favors": 1, "slot": "pp_alley_dumpsters"},   # override
    &"asset.inside_keycard": {"force_variant": {"group": "keycard", "slot": "kc_breakroom"},
                              "cost": 2000, "favors": 3, "category": "access"},       # new asset
    &"asset.zip_ties_drop": {"spawn": "body_bag_case", "slot": "drop_zone", "favors": 1, "cost": 300},
}
```
Entry keys: `cost, favors, slot` (a point id, else a point category), `point_categories, max_count,
exclusive_group, vote_group, grants, spawn` (a deployable id or a bare kind), `reveal_variant_group,
force_variant {group, slot}, effect, category, tags`. Unknown keys and bad grants are reported in
`PreplanBoard.errors` and logged. The existing schema comment in `heist_def.gd` (`{id: {cost, favors,
slot, grants}}`) is a subset of this.

Glasshouse (design doc §Pre-planning) could look like this for ENV C: `asset.inside_keycard` (force
`keycard`/`kc_breakroom`), `asset.propped_door` (force the `back_propped` slot), van position = generic
`asset.escape_position` on the two `escape` points, body bag drop = generic on the alley `drop_zone`, and
alternate entry = generic on a point with `spawn_tag = preplan_spawn_alley`.

## Blueprint and points
`PreplanBlueprint` stores positions as world `Vector2(x, z)` in meters, so a point equals its map marker.
Each point is `{id, category, pos, floor, label, params}`. The categories used are `drop_zone`,
`player_spawn` (`params.spawn_tag`) and `escape` (`params.variant_group/variant_slot`). The screen draws
`blueprints/<heist id>.tres` if it exists, else the **placeholder** (a Glasshouse-like site plan with a
"PLACEHOLDER BLUEPRINT" banner). The placeholder's point ids, spawn tags and slot ids are ours until
ENV C's map exists. `PreplanBlueprint.from_nodes(nodes, base)` already builds points from map nodes in
group `G.PREPLAN_POINT` (metadata below; see QB-PP1).

## Plan rules (`PreplanPlan`)
A selection is `{asset, point (&"" for crew assets), buyer slot}`. `can_add/add` return `&""` or a
reason: `unknown_asset, needs_point, no_point_needed, wrong_point, point_taken` (one asset per point),
`max_count, exclusive, favors` (team budget), `cash` (the buyer's spending cash, checked only for slots
in `cash_by_slot`), or `not_voter`. `validate(cash_by_slot)` re-checks everything; the host runs it on a
received plan. Vote-group options: `vote(slot, asset, point)` casts a vote, and the plan then holds the
**PlanVote winner**, paid by the host ◇ (QB-PP3). `charge_profile(profile, slot)` deducts the slot's
share. Assets are one-use (PD2): they are paid on Confirm, whatever the outcome.

## Plan vote (`PlanVote`)
Per group, `{slot: option}` with option = `"<asset id>@<point id>"`. The majority wins. On a tie the
host's option wins if it is tied, else the first tied option by id text (deterministic on every peer).
Solo: the host's vote decides. AI teammates never vote. `to_dict/from_dict` is JSON-safe for relaying.

## Screen API (MenuFlow wires it: briefing -> pre-planning -> loadout)
```gdscript
var s: PreplanningScreen = load("res://content/ui/preplanning/preplanning_screen.tscn").instantiate()
s.setup(heist_id, difficulty, profile)    # before or after add_child (re-builds)
s.profile_slot = 0; s.save_on_confirm = true
s.confirmed.connect(func(plan: Dictionary) -> void: ...)   # plan = PreplanPlan.apply()
s.back_requested.connect(...)
```
On Confirm the plan is validated, the local share is deducted from `profile.cash`, the profile is
saved (when `save_on_confirm` is set), and `confirmed(apply())` fires. Navigation: arrows/d-pad move
between markers by position. Enter/A opens a point's asset list. Up/down moves in the list, and left
goes back to the marker. Esc/B leaves the list, then the screen. "Crew assets" lists the assets that
have no location.

## Hand-off: `PreplanPlan.apply()` (version 1)
```gdscript
{
  "version": 1, "heist_id": &"glasshouse", "difficulty": 3,
  "favors_budget": 10, "favors_used": 6,
  "cash_spent": {0: 18200},                                   # slot -> spending cash (already charged)
  "modifier_sources": {&"asset.extra_cable_ties": {&"stealth.cable_ties_extra": 2}},
  "spawns": [{"asset": &"asset.ammo_bag_drop", "item": &"deployable.ammo_bag", "point": &"pp_alley_dumpsters"}],
  "reveal_variant_groups": [&"keycard"],
  "force_variants": [{"asset": &"asset.escape_position", "group": &"escape", "slot": &"esc_pell"}],
  "player_spawn_tag": &"preplan_spawn_alley",                 # &"" = default PLAYER spawns
  "plan": {...}                                               # PreplanPlan.to_dict() (selections + votes)
}
```
Application at heist start, on the server (ENV A, A2-07):
* `for src in modifier_sources: Modifiers.set_source(Modifiers.TEAM, src, modifier_sources[src])`
* `spawns`: place `item` at the PREPLAN_POINT node whose name is `point`.
* `force_variants`: VariantResolver forces `slot` active in `group` (like rare-event `force_active`).
* `reveal_variant_groups`: after resolving, tell every peer the active slots (briefing/HUD marker).
* `player_spawn_tag`: use the PLAYER SpawnPoints carrying that tag instead of the untagged ones.

## Questions for the lead
* **QB-PP1** PREPLAN_POINT node contract (heist_map.md): we propose `Marker3D` nodes in group
  `G.PREPLAN_POINT` under a `Preplan` node. The node name is the point id, and the metadata is
  `preplan_category` (`drop_zone`/`player_spawn`/`escape`/...), `preplan_label` (strings key),
  `preplan_floor` and `preplan_params` (`spawn_tag`, `variant_group`, `variant_slot`). Or a lead-owned
  `PreplanPoint` class with those exports. Who bakes the blueprint resource that the menu reads without
  loading the map: ENV C as `world/heists/<id>/<id>_blueprint.tres` exposed through `HeistRegistry`, or
  ENV B under `content/data/preplanning/blueprints/`?
* **QB-PP2** HeistLauncher input: `options["preplan"] = PreplanPlan.apply()` (shape above)? MenuFlow
  already passes it next to `loadouts` when a plan was confirmed (`MenuFlow.build_launch_options`;
  omitted for direct launch); pending the lead's answer, a launcher that does not read it ignores it.
  Back from the loadout screen to pre-planning refunds the plan's local cash share before re-confirm.
* **QB-PP3** Who pays for a voted plan: the host (current stub), split across the voters, or whoever
  placed the winning option?
* **QB-PP4** Co-op lobby: votes and selections need a lobby relay. The Net API has no lobby messages
  yet. We propose `Net.lobby_send(kind, data)` and a `lobby_message(kind, data, from_slot)` signal; the
  host keeps the authoritative PreplanPlan and re-validates.
* **QB-PP5** `HeistDef.preplanning` schema: accept the merge format above (`favors`, `disable`,
  `asset.<id>` overrides) into `heist_def.gd`'s comment / data_schemas.md?
