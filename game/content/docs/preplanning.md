# Pre-planning and assets (B2-01, B4-08, pd2_fidelity C3)

Owner: ENV B. **The contract `docs/contracts/preplanning.md` (v1.0, D-038) is authoritative** for the
AssetDef fields, `HeistDef.preplanning`, PREPLAN_POINTs, the PreplanResult launch shape, payment and
votes. This file documents ENV B's implementation of it: our extra fields, the generic library, the
plan rules, the screen API and the dev path. Symbols: **PD2** means faithful to the research
(pd2_research.md §4), and **◇** marks a choice of ours.

## Files
```
content/preplanning/
  preplan_asset_def.gd   PreplanAssetDef (Resource): one asset
  preplan_tweak.gd       PreplanTweak: cost scaling, default favors, blueprint colors
  preplan_blueprint.gd   PreplanBlueprint: top-down schematic + PREPLAN points (meters, x/z)
  preplan_board.gd       PreplanBoard: one heist at one difficulty = merged assets + budget + blueprint
  preplan_plan.gd        PreplanPlan: selections, rules, payment, validate(), apply() -> PreplanResult,
                         resolve_ids() (dev path), receive_vote(), to_dict()/from_dict()
  plan_vote.gd           PlanVote: per-slot plan votes, majority, host breaks ties, Net lobby relay
content/data/preplanning/
  assets/<name>.tres              generic asset set (id asset.<name>)
  preplan_tweak.tres
  placeholder_blueprint.tres      used while a heist has no blueprints/<heist id>.tres
  blueprints/<heist id>.tres      (none yet) the real schematic per heist
content/ui/preplanning/
  preplanning_screen.tscn/.gd     PreplanningScreen (UiScreen)
  blueprint_view.gd               BlueprintView: Control-drawn blueprint + marker buttons
```

## Asset fields (`PreplanAssetDef`)
The contract's AssetDef fields: `id`, `cost`, `favors`, `max_count`, `point_categories` / `point_ids`,
`vote_group`, `grants`, `drop` (+ `drop_params`, the contract's optional `params`), `spawn_tag`,
`escape_tag`, `force_variants` (`{group: [slot ids]}`), `reveals`. An asset may combine effects.
Ours on top (UI and rules only, never in the PreplanResult): `category` (UI grouping, order in
`PreplanTweak.category_order`), `exclusive_group` (at most one asset of the group per plan, e.g. `spawn`)
and `tags` (`stealth` / `loud` hint). `effect` (D-046 QC-22): `force_variant` declares that the asset forces
the chosen point's variant (needs a location); empty = the effect follows from the other fields.
Strings: `item.asset.<name>.name` / `.desc`.

**HeistDef.preplanning shape (contract v1.0, kept by revised D-046).** `{favors, disable, assets: {id:
overrides}}`; a Dictionary with none of those keys is the pre-D-038 shape (ignored with a warning). Favors
come from `preplanning.favors`, else `PreplanTweak.default_favors` (QC-23: never hard-code 10). Point
category for crew spawns: `spawn`.

**Point params ◇.** A located asset takes the chosen point's `params.spawn_tag`, `params.escape_tag` and
`params.variant_group` + `params.variant_slot` (a forced variant) for each of those fields it leaves
empty (the contract's "or empty, to take variant_group/variant_slot from the chosen point's params",
applied uniformly). That is how the generic `asset.alternate_entry` and `asset.escape_position` work on
any heist. `validate()`: an asset needs an effect or a location, grants must be registry keys and never
the deprecated `stealth.ecm_feedback` (D-038 QA-16), and a `drop` needs a location.

Cost scaling ◇: `cost` is the Routine price × `PreplanTweak.cost_mult[difficulty]`
`[1.0, 2.0, 4.0, 6.5, 9.5, 13.0]`, rounded to `cost_round`. Routine to Cataclysm is ×13, as in PD2's doctor
bag example ($1,600 on Normal to $20,800 on Death Wish). (The contract mentions a DifficultyDef asset
multiplier; DifficultyDef has none yet, so the tweak holds it.) Default favors: 10 (PD2 Big Bank).

### Generic set (expressible today)
| id | effect (AssetDef fields) | where | Routine $ | favors |
|---|---|---|---|---|
| `asset.body_bag_case_drop` | `drop` `deployable.body_bag_case` | `drop_zone` (max 2) | 1,000 | 2 |
| `asset.ammo_bag_drop` | `drop` `deployable.ammo_bag` | `drop_zone` (max 2) | 1,200 | 2 |
| `asset.doctor_bag_drop` | `drop` `deployable.doctor_bag` | `drop_zone` (max 2) | 1,600 | 2 |
| `asset.intel_keycards` | `reveals` `keycard` | crew | 1,500 | 1 |
| `asset.intel_cameras` | `reveals` `camera` | crew | 1,200 | 1 |
| `asset.intel_guard_posts` | `reveals` `guard_post` | crew | 1,200 | 1 |
| `asset.extra_cable_ties` | `grants` `stealth.cable_ties_extra` +2 | crew | 800 | 1 |
| `asset.spare_body_bags` | `grants` `stealth.body_bags_extra` +1 | crew | 1,000 | 1 |
| `asset.alternate_entry` | spawn tag from the point's `params.spawn_tag` | `spawn`, exclusive | 500 | 1 |
| `asset.escape_position` | forced variant from the point's `params.variant_group/variant_slot` | `escape`, vote group `escape` (cost split) | 1,000 | 1 |
| `asset.intel_laptop` (B4-10) | `reveals` `laptop` | crew | 1,500 ◇ | 1 ◇ |
| `asset.gondola_left_hung` (B4-10) | forced variant from the point's params (`gondola` / `gon_west_l41` or `gon_north_l42`) | `point_ids` `pp_gondola_west`, `pp_gondola_north`; exclusive `gondola` | 2,000 ◇ | 2 ◇ |
| `asset.inside_keycard` (D-046) | `effect` `force_variant`: the point's params (`keycard` / `kc_breakroom`) | `point_ids` `pp_insider_breakroom` (Glasshouse) | 1,500 | 1 |
| `asset.propped_door` (D-046) | `effect` `force_variant`: the point's params (`back_door` / `back_propped`) | `point_ids` `pp_back_door` (Glasshouse) | 1,000 | 1 |
| `asset.riser_panel` (B4-10) | forced variant from the point's params (`vent_open` / `vent_l41` or `vent_l42`) | `point_ids` `pp_riser_l41`, `pp_riser_l42`; exclusive `vent_open` | 1,500 ◇ | 2 ◇ |

The gondola and riser assets are limited by `point_ids` (Shadow Ledger's insider points, D-042), not by
the `insider` category, so they never appear on another heist's insider points (Night Deposit's
`pp_vent` / `pp_insider_*`). One variant group has one slot, hence the exclusive groups.
**Variant groups (QB-53, D-049).** The board hides a library asset whose `reveals` or `force_variants`
names a variant group the heist does not have (`PreplanBoard.hidden_assets`), so `asset.intel_laptop`
(reveals `laptop`) only shows where a `laptop` group exists; no `disable` is needed. The heist's groups
(`PreplanBoard.heist_variant_groups`) are the rule groups and rare-event `force_active` groups of
`world/heists/<id>/<id>_variants.tres` plus the `variant_group` params of its pre-planning points. A
heist with no variant table hides nothing (groups unknown). An asset listed in the heist's own
`preplanning.assets` that names a missing group is a board error instead.

## Per-heist data: `HeistDef.preplanning` (ENV C data, merged by `PreplanBoard.merge`)
Contract format:
```gdscript
preplanning = {
    "favors": 10,                                    # favors budget (default PreplanTweak.default_favors)
    "disable": ["asset.intel_cameras"],              # library assets this heist does not offer
    "assets": {
        &"asset.ammo_bag_drop": {"cost": 900, "favors": 1, "point_ids": ["pp_alley_dumpsters"]},  # override
        &"asset.inside_keycard": {"force_variants": {"keycard": ["kc_breakroom"]},
                                  "cost": 2000, "favors": 3, "category": "access"},             # new asset
        &"asset.propped_door": {"force_variants": {"back_door": ["back_propped"]}, "cost": 1500, "favors": 2},
    },
}
```
Entry keys are the AssetDef field names (`drop` also accepts a bare deployable name, `force_variants`
also `{group: slot}`, `params` sets `drop_params`) plus `category`, `tags`, `exclusive_group`. Unknown
keys and bad grants are reported in `PreplanBoard.errors` and logged. A non-empty `preplanning` with
none of the keys `favors` / `disable` / `assets` is the pre-D-038 format: the board logs one warning
and ignores it (Glasshouse's data until ENV C migrates it).

## Points
`PreplanBoard.blueprint_for(heist_id, def)`: the drawn schematic (`blueprints/<heist id>.tres`, else the
**placeholder**, a Glasshouse-like site plan with a "PLACEHOLDER BLUEPRINT" banner) supplies shapes and
bounds. Points come from the map when it has any: `PreplanBlueprint.from_map_scene` instances
`HeistRegistry.map_scene_path(id)` (or `def.map_scene`) **without adding it to the tree**, reads the
`Marker3D` children of `<Map>/Preplan` (node name = point id; metadata `category`, `label`, `floor`,
`params`), takes their x/z relative to the map root, grows the bounds to show every point and frees the
instance. The result is cached per heist (`PreplanBoard.clear_cache()`). Without map points the
schematic's own points are used (the placeholder's ids, tags and slots are ours). Categories in use:
`drop_zone`, `spawn` (`params.spawn_tag`) and `escape` (`params.variant_group/variant_slot`).
ENV C's blueprint image (`<id>_blueprint.png`) is not drawn yet; the screen draws the schematic.

## Plan rules (`PreplanPlan`)
A selection is `{asset, point (&"" for crew assets), buyer}`; `buyer` is a crew slot, or
`PreplanPlan.SPLIT` (-1) for a voted plan. `can_add/add` return `&""` or a reason: `unknown_asset,
needs_point, no_point_needed, wrong_point, point_taken` (one asset per point), `max_count, exclusive,
favors` (team budget), `cash` (a cash-checked slot cannot pay its share), or `not_voter`.
`validate(cash_by_slot)` re-checks everything; the host runs it on a received plan.

**Payment (contract).** Each player pays for the assets they place. A voted plan's cost is split
equally among the human crew (`PlanVote.voters`); the integer remainder goes to the host ◇. AI never
pays. `cash_cost(slot)` is a slot's share, `cash_by_payer()` every paying slot's share (=
`cash_spent`), `charge_profile(profile, slot)` deducts it. Assets are one-use (PD2): paid on Confirm,
whatever the outcome. A slot is only cash-checked when it is in `cash_by_slot` (peers check their own).

## Plan vote (`PlanVote`)
Per group, `{slot: option}` with option = `"<asset id>@<point id>"`. The majority wins. On a tie the
host's option wins if it is tied, else the first tied option by id text (deterministic on every peer).
AI teammates never vote. **Relay (contract):** the screen sends `PlanVote.send_cast(option)` /
`send_retract(group)` through `Net.lobby_send(kind, data)` (kinds `preplan.vote_cast` {option} and
`preplan.vote_retract` {group}); every peer, the sender included, applies votes in its
`Net.lobby_message(from_peer, kind, data)` handler with `PreplanPlan.receive_vote(slot, kind, data)`
(not cash-checked; confirm re-validates). Solo: Net delivers locally at once, so the host decides alone.

## Screen API (MenuFlow wires it: briefing -> pre-planning -> loadout)
```gdscript
var s: PreplanningScreen = load("res://content/ui/preplanning/preplanning_screen.tscn").instantiate()
s.setup(heist_id, difficulty, profile)    # before or after add_child (re-builds)
s.profile_slot = 0; s.save_on_confirm = true
s.confirmed.connect(func(result: Dictionary) -> void: ...)   # PreplanResult = PreplanPlan.apply()
s.back_requested.connect(...)
```
On Confirm the plan is validated, the local share is deducted from `profile.cash`, the profile is
saved (when `save_on_confirm` is set), and `confirmed(apply())` fires. MenuFlow passes it as
`options["preplan"]`; Back from the loadout refunds `cash_spent[local slot]`. Navigation: arrows/d-pad
move between markers by position. Enter/A opens a point's asset list. Up/down moves in the list, and
left goes back to the marker. Esc/B leaves the list, then the screen. "Crew assets" lists the assets
that have no location.

## PreplanResult: `PreplanPlan.apply()` (contract shape, version 1)
```gdscript
{ "version": 1,
  "modifier_sources": {&"asset.extra_cable_ties": {&"stealth.cable_ties_extra": 2}},
  "drops": [{"asset": &"asset.ammo_bag_drop", "kind": &"deployable.ammo_bag", "point": &"pp_alley_dumpsters", "params": {}}],
  "spawn_tag": &"preplan_spawn_alley",          # &"" = default spawns
  "escape_tag": &"",                            # &"" = mission default
  "force_variants": {&"escape": [&"esc_pell"]},
  "reveals": [&"keycard"],
  "cash_spent": {0: 1500, 1: 500},              # slot -> spending cash, already charged
  "plan": {"heist_id", "difficulty", "favors_budget", "favors_used", "selections", "votes"} }
```
Exactly these keys (`PreplanPlan.RESULT_KEYS`). ENV A applies it and never re-resolves the catalog.

**Dev path:** `PreplanPlan.resolve_ids(heist_id, ids, difficulty = ROUTINE, def = null) -> Dictionary`
builds the same PreplanResult from asset ids without UI (ENV A's `options["preplanning"]`). An id may
name its point as `"asset.<id>@<point id>"`; otherwise a located asset takes the first free allowed point
in blueprint order. Slot 0 buys everything and votes alone; nothing is charged (`cash_spent` = {}).
Rejected ids are logged.

## Wished for (not expressible yet)
* An ECM drop. `deployable.ecm` does not exist, and `stealth.ecm_extra` on TEAM would give every player an ECM.
* A loot-drop / bag-throw position: a `drop` of a "loot drop zone" (secure zone) kind.
* A spotter: marks the guards for N seconds at the start. This needs a timed-mark hook.
* An escape-driver upgrade: a faster van return. This needs an escape-timer scalar override.
* Insider assets unlocked by Sixth Sense aced (PD2). This needs a `stealth.insider_assets` FLAG on the profile side.
* Map drawing (PD2 board). P4.

## Answered questions
QB-PP1..5 were answered by D-038 and the contract (points under `<Map>/Preplan`, `options["preplan"]`,
split plan cost, `Net.lobby_send` / `lobby_message`, the `{favors, disable, assets}` format).
