# Dockside Burn: ENV B content (B5-04)

Owner: ENV B. Heist row 4 of `docs/design/game_overview.md`: `dockside_burn`, **Dockside Burn**, Ortega
Cold Storage. PD2 analog: Firestarter / Rats. **Loud-only**, size M, phase P3. Faction: pd2_fidelity
**L4.10**, the Cartel crew (see "Faction" below).

Source: ENV C's G0 level doc `docs/design/heists/dockside_burn.md`, approved in **D-064** (read at
`8e3efe5`). Objective ids, VO ids, point ids, loot ids (QC-39) and the pre-planning assets (QC-40) come
from it. Symbols: **V** means taken from the doc or the PD2 research, and **◇** marks a choice of ours.

## Content summary
Ortega Cold Storage, Pier 9, is the freezer warehouse of the Ortega Fisheries Co-op, the cartel front
from Night Deposit. Reyes wants the Co-op's cash and rifles, and its product burned. It is loud from
the first frame. The Co-op's own gunmen (no pagers, no surrender) hold the yard until the police
arrive after `police_delay_s`.

| What | Where |
|---|---|
| Board spot (district `docks`, contact `contact.reyes`) | `data/board/city_map.tres` (B4-06, unchanged) |
| Accent `#FF6B1A` flare orange (style guide; WCAG AA as is) | `data/ui/heist_accents.tres` (unchanged) |
| Heist list entry (`solo_ai_teammates` 3) | `data/ui/heist_list.tres` |
| Briefing placeholder (contact, loot, escapes, the doc's objectives) | `ui/briefing/briefing_ui.tres` |
| Loot `loot.weapon_crate`, `loot.contraband`, `loot.thermite` | `data/loot/` |
| Pre-planning assets (QC-40) | `data/preplanning/assets/` (5 new) |
| Thermite excluded from bag XP | `data/tweak/payout.tres` `xp_loot_excluded_ids` |
| Strings: heist, objectives, loot, assets, point labels, VO | `data/strings/strings.csv` |
| Briefing and mission VO (the doc's 31 ids + Vance/Accountant briefing sets) | `data/voice/lines.tres` |
| Tests | `tests/b/test_p2_heist_content.gd` (Dockside section), `tests/b/test_voice_lines.gd` |

The menus, Board and broker list a heist only once it has a HeistDef **and** a map scene (QB-55,
D-049). The tests check the proposal while the def is missing, and check the def once it lands.

## Contact: Hollis "Hammer" Reyes
`game_overview.md` §contacts: Reyes is the fixer for "loud jobs, armored trucks, warehouses". Odile
Vance fences jewelry and art, and the Accountant runs quiet bank and data jobs. The G0 doc and the
city map both name `contact.reyes`.

## Board contract and payout
| Field | Value | Src |
|---|---|---|
| Contact | `contact.reyes` | doc, city map |
| District / pin | `docks`, anchor `(0.885, 0.62)` (inside the docks polygon) | city_map (B4-06) |
| Base payout (`HeistDef.base_payout`, unscaled) | **$24,000** (D-120: bags carry the run) | D-120 |
| Required to escape | **the burn + 4 bags secured** (cash bricks and/or weapon crates) | doc "Loot path" |
| Bonus | bags beyond 4, all product (`loot.contraband`, does not count toward the 4), dispatch-safe and desk small loot | doc |
| Difficulty gating | global Board rules: `difficulty_min_level` `[0,0,0,0,80,80]` plus the build gate | board_tweak (C1) |
| Pro job | eligible under the global rule: Tense+, `pro_chance` 0.2; no restart, +20% XP | board_tweak (C1) |
| Broker price | `broker_cost_by_difficulty[d] + 10%` of the contract preview (D-115) | board_tweak |

Contract pay by difficulty (× `payout_mult` 1 / 2 / 2.6 / 4.2 / 7.2 / 9.2, via `HeistCatalog.contract_preview`):

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $24,000 | $48,000 | $62,400 | $100,800 | $172,800 | $220,800 |

The required 4 bags add $32,000 (4 cash bricks) to $34,000 (4 crates) at Routine (D-120 values; the $24,000 base payout lets the bags carry the run), before the
multiplier. The Board card has no field for the requirement. It shows in the briefing (objectives
`burn` and `secure`) and in the HUD's objective panel. There is no per-heist difficulty floor or pro
flag in `BoardTweak`, so Dockside uses the global rules (Q-DB2).

## Loot (QC-39)
Base values before `DifficultyDef.payout_mult`. Weight is the `Enums.LootWeight` throw/carry class
(HEAVY: ×0.75 speed, no sprint, 3 m throw, per the doc).

| id | Name | Weight | Base | Tense | Hazardous | Brutal | Lethal | Cataclysm | Role | Src |
|---|---|---|---|---|---|---|---|---|---|---|
| `loot.cash_bricks` (existing) | Cash Bricks | MEDIUM | $8,000 | $16,000 | $20,800 | $33,600 | $57,600 | $73,600 | required (counts toward 4); strongroom pallets or count-room cage | B4-09 def |
| `loot.weapon_crate` | Weapon Crate | HEAVY | $8,500 | $17,000 | $22,100 | $35,700 | $61,200 | $78,200 | required (counts toward 4); 2 containers × 2 crates | weight V, value ◇ (doc) |
| `loot.contraband` | Contraband | MEDIUM | $7,000 | $14,000 | $18,200 | $29,400 | $50,400 | $64,400 | bonus only; burns with the room | weight V, value ◇ (doc) |
| `loot.thermite` | Thermite Bag | HEAVY | $0 | – | – | – | – | – | **tool bag**, consumed by the burn point | V (doc) |

**Tool bag.** `LootDef` has no "tool" flag. Zero value already means no cash: `PayoutCalculator`
multiplies `value` by `payout_mult`. Bag XP counts every secured bag except
`PayoutTweak.xp_loot_excluded_ids`, so `loot.thermite` is now listed there, next to `loot.body_bag`.
`test_dockside_burn_loot` checks that a thermite line adds no cash and no XP. Keeping it out of the
`[secure]` count is the mission's job (ENV A/C), and the HeistDef's `loot` list omits it so the
briefing does not show it as loot. If a thermite bag is ever secured, it still appears as a $0 line
on the payday screen, as a body bag would. See Q-DB5.

Small loot: the doc places the O2 dispatch safe (×3) and desk cash (O1, O2, M1) without a per-item
range. ◇ $600–1,500 is proposed in `data/README.md` until C sets the prefab values.

## Objectives (doc `[tag]`s, D-039 rule)
`objective.dockside_burn.<tag>`, in the doc's order: `cartel` (optional), `breach`, `product`,
`burn`, `strongroom`, `count_cage`, `containers`, `secure` (`{count}/{total}`), `escape_wait`,
`escape`. They are also the briefing placeholder's ids and the proposed `HeistDef.objectives`.

## Briefing VO (event `briefing`, priority 90)
| id | order |
|---|---|
| `vo.reyes.briefing_dockside_burn_1..3` (doc) | 1–3 |
| `vo.vance.briefing_dockside_burn_1..2` (ours) | 1–2 |
| `vo.accountant.briefing_dockside_burn_1..2` (ours) | 1–2 |
| `vo.mercer.briefing_dockside_burn_1..2` (doc) | 100–101 (Mercer closes) |

The Vance and Accountant sets are not in the doc. They follow Glasshouse, so the briefing still
plays if a broker or fallback pick changes the contact.

## Mission VO (event `mission`, priority 90, cooldown 0)
Every id from the doc's "VO line ids" list: 31 in total, including the 5 briefing ids above. The
coordinator counted 30; the doc lists Reyes 5 and Mercer 2 + 24. `say()` context: only the two ETA
lines use `{seconds}`.

| id | trigger (doc "Mission script notes") |
|---|---|
| `vo.mercer.dockside_burn_intro` | start (cartel unaware) |
| `vo.reyes.dockside_burn_contact_intro` | after the intro |
| `vo.mercer.dockside_burn_cartel_awake` | first `npc_alerted` of a cartel NPC |
| `vo.mercer.dockside_burn_police_called` | the director starts (after `police_delay_s`) |
| `vo.mercer.dockside_burn_breach` | `[breach]` done |
| `vo.mercer.dockside_burn_product_found` | `[product]` done |
| `vo.mercer.dockside_burn_thermite_reminder` | product found, thermite not moving |
| `vo.mercer.dockside_burn_burn_started` / `_burn_done` | thermite placed / `device_finished(&"thermite")` (shutters) |
| `vo.mercer.dockside_burn_strongroom_drill` / `_drill_jam` / `_strongroom_open` | the thermal drill on SR |
| `vo.mercer.dockside_burn_count_cage` | `cash_countroom`: the cage |
| `vo.mercer.dockside_burn_lift_dead` | `lift_dead` and bags in M1 |
| `vo.mercer.dockside_burn_containers_hint` / `_weapons_found` | the yard containers |
| `vo.mercer.dockside_burn_sniper_crane` / `_sniper_roof` | Longshot at S1 / S2 |
| `vo.mercer.dockside_burn_gangway` | `gangway_down` police from the east |
| `vo.mercer.dockside_burn_reinforcements` | rare `cartel_reinforcements` |
| `vo.mercer.dockside_burn_fog_lifts` | rare `fog_lifts` |
| `vo.mercer.dockside_burn_required_secured` | `[burn]` + `[secure]` done (escape called) |
| `vo.mercer.dockside_burn_van_eta` / `_boat_eta` | `{seconds}` |
| `vo.mercer.dockside_burn_escape` | escape arrived |
| `vo.reyes.dockside_burn_payday` | success (payday) |

The skeleton's extra lines (`no_dominate`, `police_inbound`, `cartel_warning`, `escape_eta`, and the
`{escape}` form of `escape`) were dropped or renamed to the doc's ids before push.

## Pre-planning (QC-40)
Five new **library** assets in `data/preplanning/assets/`. Values ◇ are the doc's.

| Asset | Effect | Where | Routine $ / favors |
|---|---|---|---|
| `asset.sniper_position` | `effect force_variant` (the point's `player_perch` slot) + `drop deployable.ammo_bag` | `point_ids` `pp_perch_roof`, `pp_perch_stack`; exclusive `player_perch` | 2,000 / 2 |
| `asset.thermite_drop` | `drop loot.thermite`: a **loot bag** at the point | `point_ids` `pp_drop_gatehouse`, `pp_drop_lane`, `pp_drop_quay` | 1,500 / 1 |
| `asset.gangway_raised` | `effect force_variant` (`east_gangway` / `gangway_up`) | `point_ids` `pp_gangway` | 2,500 / 2 |
| `asset.intel_containers` | `reveals weapons_containers` | crew | 1,500 / 1 |
| `asset.lift_power` | `force_variants {goods_lift: [lift_powered]}` | crew | 1,000 / 1 |

* The doc's `category: loud` is not a UI category (`PreplanTweak.category_order` is supply, intel,
  gear, entry, access, escape). The perch and thermite use `supply`. The `loud` hint lives in `tags`.
* **Loot-bag drop (no schema change).** `drop` is already a StringName "spawn kind", so
  `&"loot.thermite"` is valid data, and the PreplanResult carries `{"kind": &"loot.thermite"}`.
  ENV A has to spawn a `LootBag` of that LootDef for kinds starting `loot.`
  (`PreplanAssets.register_drop`; until then the `PreplanDrop` fallback node appears). That is a
  contract clarification for the lead and ENV A (`docs/contracts/preplanning.md` lists only
  deployable examples), not a new field.
* The located assets are limited by Dockside's point ids. The crew assets name Dockside-only
  variant groups, so QB-53 hides them elsewhere (`test_dockside_burn_assets_stay_on_dockside`).
* **Point labels:** `ui.preplan.point.<id>` for all 13 points. **`pp_drop_quay` and
  `pp_escape_boat` already exist for Night Deposit** ("Quay bollards", "Boat: quay steps"), so
  Dockside's labels are `ui.preplan.point.dockside_burn.pp_drop_quay` and
  `ui.preplan.point.dockside_burn.pp_escape_boat`. ENV C sets those keys as the Marker3D `label`
  metadata, or renames the two points (Q-DB6).

## Proposed HeistDef (for ENV C: `world/heists/dockside_burn/dockside_burn_def.tres`)
Every field of `contracts/data/heist_def.gd`, aligned with the doc's "HeistDef (proposed data)" and
"Pre-planning" sections:
```
[resource]
script = ExtResource("<heist_def.gd>")
id = &"dockside_burn"
display_name = "Dockside Burn"
contact = &"contact.reyes"
briefing = "heist.dockside_burn.briefing"
mode = 2
map_scene = "res://world/heists/dockside_burn/dockside_burn.tscn"
base_payout = 24000
stealth_bonus_mult = 1.0
loot = Array[StringName]([&"loot.cash_bricks", &"loot.weapon_crate", &"loot.contraband"])
objectives = Array[StringName]([&"cartel", &"breach", &"product", &"burn", &"strongroom", &"count_cage", &"containers", &"secure", &"escape_wait", &"escape"])
preplanning = {
"assets": {
&"asset.ammo_bag_drop": {
"point_ids": [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay", &"pp_drop_platform"]
},
&"asset.doctor_bag_drop": {
"point_ids": [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay", &"pp_drop_platform"]
},
&"asset.gangway_raised": {},
&"asset.intel_containers": {},
&"asset.lift_power": {},
&"asset.sniper_position": {},
&"asset.thermite_drop": {}
},
"disable": [&"asset.body_bag_case_drop", &"asset.spare_body_bags", &"asset.intel_cameras", &"asset.intel_keycards"],
"favors": 5
}
escape_options = Array[StringName]([&"van", &"boat"])
music_track = &"dockside_burn"
```
Notes for C:
* `mode = 2` is LOUD_ONLY.
* `briefing` is a strings.csv key, which `BriefingModel` resolves. Literal text also works.
* `stealth_bonus_mult = 1.0`: a loud-only job never earns the stealth bonus.
* The five new assets carry their fields in the library, so `{}` is enough. Listing the doc's inline
  fields instead also works, except `"category": &"loud"`, which is not a UI category. Leave that out.
* The `asset.intel_containers` and `asset.lift_power` entries need `weapons_containers` and
  `goods_lift` in `dockside_burn_variants.tres`, or the board reports an error.
* `asset.alternate_entry` and `asset.escape_position` need no entry: they work from the points'
  params, as on every heist.
* `asset.intel_guard_posts` and `asset.extra_cable_ties` stay on (doc).
* The two drop zones on the perch points take only `asset.sniper_position`, because ammo and doctor
  are limited to the four drop points.
* `loot` leaves out `loot.thermite`, which is a tool. Add `loot.small_valuables` only if the map
  uses it (it has no LootDef).

## Faction (pd2_fidelity L4.10)
The on-site enemies are `enemy.cartel_gunman` (ENV A, QC-36): no pagers, not dominatable, no cuffs.
They start unalerted, and the police director starts after `police_delay_s` (QC-35). The VO covers
both stages (`cartel_awake`, `police_called`, `reinforcements`). ENV B's data does not depend on
the faction id or roster.

## Remaining dependencies (not B's)
1. ENV C: the HeistDef (block above), the map, `dockside_burn_variants.tres` (groups
   `weapons_containers`, `goods_lift`, `player_perch`, `east_gangway`, `escape`), the point `label`
   metadata (Q-DB6), and `dockside_burn_mission.gd` `say()`ing the ids above
   (`test_every_mission_say_has_a_line` enforces them).
2. ENV A: `loot.*` drop kinds spawn a loot bag (QC-40), the `burn_point` consuming `loot.thermite`
   (QC-38), excluding thermite from `[secure]`, the director start hook (QC-35), and
   `enemy.cartel_gunman` (QC-36).

## Open questions (for the lead)
* Q-DB2: Should the Board get per-heist gating, such as a minimum difficulty or a pro-only or
  never-pro flag, as PD2 has? Today all heists share the global rules.
* Q-DB3: Should loud jobs get an armor bag drop? `deployable.armor_bag` is card-gated (QB-58), and a
  drop would bypass the gate. Not proposed.
* Q-DB5: Should `LootDef` get an explicit `is_tool` flag, rather than value 0 plus the XP exclusion
  list, so the payday screen and `[secure]` can skip tool bags generically? That is a schema
  change, so it is the lead's call.
* Q-DB6: For `pp_drop_quay` and `pp_escape_boat`, which are shared with Night Deposit, should C
  rename the points or set the qualified label keys?
* Q-DB7: closed by D-120: $24,000 (a loud bag heist; full clear ≈ 81% bags).
