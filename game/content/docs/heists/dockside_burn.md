# Dockside Burn: ENV B content (B5-04)

Owner: ENV B. Heist row 4 of `docs/design/game_overview.md`: `dockside_burn`, **Dockside Burn**, a
cartel cold-storage warehouse. PD2 analog: Firestarter / Rats. **Loud-only**, size M, phase P3.
Faction: pd2_fidelity **L4.10**, the Cartel crew (see "Faction" below).

This is the **content skeleton**. ENV C's G0 level doc (`docs/design/heists/dockside_burn.md`) has
not landed, so nothing here names an objective id, a pre-planning point id or an escape tag.
Everything that waits on C is a `TODO(C-G0)` in the last section. Symbols: **V** means taken from PD2
research, and **◇** marks a choice of ours.

## Content summary
Saltline Cold Storage stands at the end of Pier 14 in the Docks district. On paper it chills fish
for the Ortega Fisheries Co-op, the same cartel front that Night Deposit robs at the bank. Behind
the freezer doors the Co-op keeps arms crates, "product" and the cash from the week's sales.
Hollis Reyes wants it emptied and then burned. There is no stealth path: the floor crew is cartel
(no pagers, no surrender), and the police arrive once the shooting starts.

| What | Where | Status |
|---|---|---|
| Board spot (district `docks`, contact `contact.reyes`) | `data/board/city_map.tres` | already present (B4-06); unchanged |
| Accent `#FF6B1A` (flare orange, style guide §heist palettes) | `data/ui/heist_accents.tres` | already present; WCAG test added |
| Heist list entry (`solo_ai_teammates` 3) | `data/ui/heist_list.tres` | **new** |
| Briefing placeholder (contact, loot, escapes; objectives empty) | `ui/briefing/briefing_ui.tres` | **new** |
| Loot `loot.arms_crate`, `loot.product_crate` | `data/loot/` | **new** |
| Strings: name, subtitle, brief, briefing, loot, `ui.escape.van/boat`, VO | `data/strings/strings.csv` | **new** (appended) |
| Briefing VO (all three contacts + Mercer) and mission VO | `data/voice/lines.tres` | **new** |
| Pre-planning | proposed `HeistDef.preplanning` below (ENV C data) | proposal only |
| Tests | `tests/b/test_p2_heist_content.gd` (Dockside section), `tests/b/test_voice_lines.gd` | **new** |

The menus, Board and broker only list a heist with a HeistDef **and** a map scene (QB-55, D-049),
so Dockside stays invisible until ENV C lands both. Nothing in this skeleton needs a def to load.

## Contact: Hollis "Hammer" Reyes
`game_overview.md` §contacts: Reyes is the fixer for "loud jobs, armored trucks, warehouses", and a
cartel warehouse is all three at once apart from the truck. Odile Vance fences jewelry and art, and
the Accountant runs quiet bank and data jobs. A job you cannot do quietly, which ends with the place
on fire, belongs to Reyes. The city map already gives `dockside_burn` to `contact.reyes`, so the
Board agrees whatever the HeistDef says (the Board uses `HeistDef.contact` first, then the map).

## Board contract
| Field | Value | Src |
|---|---|---|
| Contact | `contact.reyes` | above |
| District / pin | `docks`, anchor `(0.885, 0.62)` (inside the docks polygon) | city_map (B4-06) |
| Base payout (unscaled `HeistDef.base_payout`) | **$100,000** | ◇ |
| Difficulty gating | global Board rules: `difficulty_min_level` `[0,0,0,0,80,80]` plus the build gate (`unlocked_difficulties`) | board_tweak (C1) |
| Pro job | eligible under the global rule: Tense and up, `pro_chance` 0.2; no restart, +20% XP | board_tweak (C1) |
| Broker price | `broker_cost_by_difficulty[d] + 5%` of the contract preview | board_tweak |

The payout is ◇. Dockside is size M like Night Deposit ($90,000), but loud-only, so it can never earn
the 1.15 stealth bonus. +11% makes up most of that gap. Contract pay by difficulty (×
`payout_mult` 1 / 2 / 2.6 / 4.2 / 7.2 / 9.2, V S10.4, via `HeistCatalog.contract_preview`):

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $100,000 | $200,000 | $260,000 | $420,000 | $720,000 | $920,000 |

Neither the Board nor `BoardTweak` has a per-heist difficulty floor or pro flag, so Dockside uses
the global rules. See Q-DB2.

## Loot
PD2 bag shape: a heavier bag is worth more per bag and less per second of carrying. Values are
base values before `DifficultyDef.payout_mult`. The weight is the existing `Enums.LootWeight` throw
and carry class.

| id | Name | Weight | Base | Tense | Hazardous | Brutal | Lethal | Cataclysm | PD2 analog | Src |
|---|---|---|---|---|---|---|---|---|---|---|
| `loot.arms_crate` | Arms Crate | HEAVY | $2,200 | $4,400 | $5,720 | $9,240 | $15,840 | $20,240 | Firestarter weapons bags | weight ◇, value ◇ |
| `loot.product_crate` | Product Crate | MEDIUM | $1,800 | $3,600 | $4,680 | $7,560 | $12,960 | $16,560 | Rats / Firestarter contraband | weight ◇, value ◇ |
| `loot.cash` (existing) | Cash | LIGHT | $1,200 | $2,400 | $3,120 | $5,040 | $8,640 | $11,040 | Rats cash | existing def |

* The research has no entry for PD2's weapons or contraband bag classes (`pd2_research.md`), so both
  weights are ◇. HEAVY > MEDIUM > LIGHT keeps the ordering the other heists use: cash $1,200 LIGHT,
  cash bricks $1,600 MEDIUM, ledger books $2,400 MEDIUM.
* "Product" is deliberately vague. It is a cold-room crate stencilled as frozen fish, with no drug
  named and no drug art (tasteful, original).
* **Small loot ◇ (proposal):** $600–1,500 per item before the difficulty multiplier (loose bills
  and watches in the counting room and the foreman's office). It is reported the QB-52 way
  (`HeistResult.small_loot` from the prefab, no LootDef), and recorded in `data/README.md`. ENV C's
  G0 doc confirms or replaces the range.
* Spawn counts, which crates are required and the bag minimum are **TODO(C-G0)**.

## Briefing
`ui/briefing/briefing_ui.tres` has a placeholder entry (contact Reyes, loot, escapes `van` and
`boat`). The `objectives` list is **empty** on purpose. Once the HeistDef exists, the def wins.
Strings: `heist.dockside_burn.name` "Dockside Burn", `.subtitle` "Saltline Cold Storage", `.brief`,
`.briefing`.

Briefing VO (event `briefing`, priority 90, `heist` `dockside_burn`). Every contact has a set, as for
Glasshouse, so the briefing still plays if a broker or fallback pick changes the contact:

| id | order |
|---|---|
| `vo.reyes.briefing_dockside_burn_1..3` | 1–3 (the contact) |
| `vo.vance.briefing_dockside_burn_1..2` | 1–2 |
| `vo.accountant.briefing_dockside_burn_1..2` | 1–2 |
| `vo.mercer.briefing_dockside_burn_1` | 100 (Mercer closes) |

## Mission VO (event `mission`, priority 90, cooldown 0)
These lines are **not tied to an objective id**. ENV C's `dockside_burn_mission.gd` may `say()` them
as they are. Text is `voice.<id>` in strings.csv.

| id | When | Context |
|---|---|---|
| `vo.mercer.dockside_burn_intro` | heist start (masked; loud from the first second) | none |
| `vo.reyes.dockside_burn_contact_intro` | right after the intro | none |
| `vo.mercer.dockside_burn_cartel_warning` | first cartel unit seen or first shot | none |
| `vo.mercer.dockside_burn_no_dominate` | a player shouts at a cartel unit (L4.10: can't be dominated) | none |
| `vo.mercer.dockside_burn_cartel_reinforcements` | a cartel reinforcement wave arrives | none |
| `vo.mercer.dockside_burn_police_inbound` | the police response starts (first assault anticipation) | none |
| `vo.mercer.dockside_burn_escape_eta` | escape called | `{seconds}` |
| `vo.mercer.dockside_burn_escape` | escape available | `{escape}`: `ui.escape.van` / `ui.escape.boat` (new) |

**TODO(C-G0), objective-bound lines (not drafted):** a line for each objective `[tag]` the G0 doc
defines, for example "crates found", the freezer or vault door (opening method, drill or saw
jams), "burn started", "fire spreading / get out", "required bags secured" and the bag count.
Their ids follow `vo.mercer.dockside_burn_<line>` and are written once C's `say()` ids exist
(`test_every_mission_say_has_a_line` then enforces them).

## Pre-planning (proposal for `HeistDef.preplanning`, ENV C data)
PD2 offers loud jobs supply drops (ammo and medic bags), a spawn choice and an escape choice. Every
asset below already exists in the library (`data/preplanning/assets/`). Dockside needs **no new
asset**.

| Asset | Where | Routine $ / favors (library) | Why |
|---|---|---|---|
| `asset.ammo_bag_drop` | `drop_zone` points (max 2) | 1,200 / 2 | loud supply |
| `asset.doctor_bag_drop` | `drop_zone` points (max 2) | 1,600 / 2 | loud supply |
| `asset.alternate_entry` | `spawn` points, exclusive `spawn`, the point's `params.spawn_tag` | 500 / 1 | start position |
| `asset.escape_position` | `escape` points, vote group `escape` (cost split), the point's `params.variant_group/variant_slot` | 1,000 / 1 | escape vehicle choice (van at the pier gate or boat at the quay) |
| `asset.extra_cable_ties` | crew | 800 / 1 | civilian hostages for trades (L6) |

**Disabled** (rule: every library asset tagged only `stealth` that is not already limited by
`point_ids`): `asset.body_bag_case_drop`, `asset.intel_cameras`, `asset.intel_guard_posts`,
`asset.intel_keycards`, `asset.intel_laptop`, `asset.spare_body_bags`. The `point_ids`-limited
stealth assets (`gondola_left_hung`, `riser_panel`, `inside_keycard`, `propped_door`) can never
appear on Dockside's points anyway. Favors: **6** ◇ (exactly both drops plus entry plus escape).
`test_dockside_burn_preplan_proposal` builds this block on synthetic points and checks that the rule
holds.

**TODO(C-G0):** point ids and their params (`drop_zone` ×2+, `spawn` with `params.spawn_tag`,
`escape` with `params.variant_group`/`variant_slot` for van and boat), plus any heist-only asset C
wants to add, for example a "crane" or "forklift" pre-positioned to shorten a bag route.

## Proposed HeistDef (for ENV C: `world/heists/dockside_burn/dockside_burn_def.tres`)
Every field of `contracts/data/heist_def.gd`:
```
[resource]
script = ExtResource("<heist_def.gd>")
id = &"dockside_burn"
display_name = "Dockside Burn"
contact = &"contact.reyes"
briefing = "heist.dockside_burn.briefing"
mode = 2
map_scene = "res://world/heists/dockside_burn/dockside_burn.tscn"
base_payout = 100000
stealth_bonus_mult = 1.0
loot = Array[StringName]([&"loot.arms_crate", &"loot.product_crate", &"loot.cash"])
objectives = Array[StringName]([])
preplanning = {
"assets": {
&"asset.alternate_entry": {
"point_categories": [&"spawn"]
},
&"asset.ammo_bag_drop": {
"point_categories": [&"drop_zone"]
},
&"asset.doctor_bag_drop": {
"point_categories": [&"drop_zone"]
},
&"asset.escape_position": {
"point_categories": [&"escape"]
},
&"asset.extra_cable_ties": {}
},
"disable": [&"asset.body_bag_case_drop", &"asset.intel_cameras", &"asset.intel_guard_posts", &"asset.intel_keycards", &"asset.intel_laptop", &"asset.spare_body_bags"],
"favors": 6
}
escape_options = Array[StringName]([&"van", &"boat"])
music_track = &"dockside_burn"
```
Notes for C:
* `mode = 2` is `Enums.HeistMode.LOUD_ONLY`.
* `briefing` is a strings.csv key. `BriefingModel.briefing_text` resolves keys, and a key keeps the
  text translatable. Literal text, as the other defs use, also works.
* `stealth_bonus_mult = 1.0`, because a loud-only job never pays the stealth bonus. The default 1.15
  would be harmless but misleading.
* `objectives` stays **empty until the G0 doc**. Every id must have `objective.dockside_burn.<id>` in
  strings.csv. ENV B adds those strings from the doc's `[tag]`s, as it did for D-039.
* `loot`: add `loot.small_valuables` only if the map uses it (Night Deposit lists it; it has no
  LootDef, and `BriefingModel` skips unknown ids).
* `escape_options`: `van` and `boat` have briefing strings (`ui.briefing.escape.*`) and VO strings
  (`ui.escape.*`). Any other id needs both from ENV B.
* `music_track`: ENV C's audio id. `&"dockside_burn"` follows the other heists.

## Faction (pd2_fidelity L4.10)
The on-site enemies are the **Cartel crew**, ENV A's faction (P3), and not Security Officers:
* **no pagers**: the pager VO and the stealth flow never trigger, which matches loud-only;
* **cannot be dominated**: `vo.mercer.dockside_burn_no_dominate` covers the failed shout;
* the police assault director still runs on top (L1), so `police_inbound` marks the hand-over.

The faction id (for example `faction.cartel`), its unit roster and how it mixes with the police
waves belong to ENV A. Nothing in ENV B's data depends on them. Cartel civilians and workers, if C
places any, count for `civilian_kill_penalty` like any civilian (ENV A's rule).

## TODO list waiting on ENV C's G0 doc
1. **Objective ids**: `HeistDef.objectives`, the `objective.dockside_burn.<tag>` strings, and the
   briefing placeholder `objectives`. The test then switches from "no guessed keys" to `_check_objectives`.
2. **Mission VO ids** for objective events (above). Ids come from `dockside_burn_mission.gd` `say()` calls.
3. **Pre-planning point ids** and their params (`drop_zone`, `spawn` + `spawn_tag`, `escape` +
   `variant_group/variant_slot`), and the final `preplanning` block.
4. **Escape tags/slots** for van and boat (the variant group name and slot ids), the ETA timing,
   and whether both are offered on every difficulty.
5. **Loot placement**: spawn counts, which bags are required, the bag minimum, and confirmation of
   the small-loot range.
6. **"Burn" mechanic**: if the fire is an objective with a timer, Mercer's lines and
   `{seconds}` context are added then.

## Open questions (for the lead)
* Q-DB1: The lore tie-in, Saltline as the Ortega Fisheries Co-op's cold store (the Night Deposit
  cartel front). Is that fine with ENV C's G0 doc, or should the cartel get its own name?
* Q-DB2: Should the Board get per-heist gating, such as a minimum difficulty or a pro-only or
  never-pro flag, as PD2 has? Today all heists share the global rules.
* Q-DB3: Should loud jobs get an armor bag drop pre-plan asset? `deployable.armor_bag` exists but is
  card-gated (QB-58), so a drop would bypass the gate. Not proposed.
* Q-DB4: Is $100,000 right for an M loud-only job? (Night Deposit $90,000, Shadow Ledger $110,000.)
