# AH-B1: Afterhours values block (QB-2 shape, PAPER)

ENV B -> ENV C (cc LEAD), 2026-10-21. **Paper only: no Afterhours data on env/b-content until it is scheduled.**
C's generator writes `afterhours_def.tres` / `_variants.tres` from this block (QB-2, D-137); B writes its own files
(strings, VO, achievements, payout row) when the gate opens. Sources: `docs/design/heists/afterhours.md` (G0 + the
D-075 rulings), `game/content/docs/ah_content_plan.md`. Same shape as `rt_b1_values.md`. **This supersedes
ah_content_plan.md §1 where they differ: base_payout is $40k** (D-143, pinned by `test_p5_catalogue`), not the
doc's $75k.

## 1. HeistDef values

| Field | Value | Why |
|---|---|---|
| `id` / display | `afterhours` / "Afterhours" (string exists) | — |
| `contact` | `contact.accountant` (D-075 ruling 6), district `midtown` | pinned by `test_p5_catalogue` |
| `mode` / `start_mode` | STEALTH_OR_LOUD, `&"civilian"` (D-065) | every player spawn is civilian |
| `base_payout` | **40,000** (D-143) | D-120 shape: the 3 required safe bags (24k unscaled) are 38% of a minimum clear (64k); a full clear's bags (6 safe + 5 parcels + 2 cash = 98.5k) are 71% of 138.5k |
| `loot` | `[loot.cash_bricks, loot.parcels, loot.cash]` | no new LootDef |
| `escape_options` | **`[van]`** | the doc's HeistDef says `[van, walk]`, but its Escape section and D-075 say no walk-out: **C to fix the doc line** |
| `music_track` | `afterhours` ("Velvet Rope", string exists) | — |
| `stealth_bonus_mult` | 1.15 (M heist, as ND / GN / SL, S11.1) | — |
| `pager_max_by_difficulty` | none (tweak default; 4 answered pagers, the 4th has its own line) | D-130 |
| `objectives` | `[casing, gear, keycard, office, safe_code, safe, safe_loot, secure, product, count_room, escape_wait, escape]` (12; every string exists) | doc |
| `briefing_objectives` | `[casing, gear, ui.briefing.step.afterhours.office, secure, ui.briefing.step.afterhours.bonus, escape]` | merged steps (OF pattern, D-117 §4) |
| D-148 XP | `PayoutTweak.base_xp_by_heist[&"afterhours"] = 2500` (B's payout.tres) | size M: office + safe + optional product and count room |
| Loot values | LootDefs are 8,000 / 7,500 / 6,500 (S10.6): **the doc's loot table still lists the pre-D-120 $1,600 / $1,500 / $1,200; C to update** | — |

## 2. Variant rows (C writes them; B's values)

Difficulties: R Routine, T Tense, H Hazardous, B Brutal, L Lethal, C Cataclysm.

| Group | Slots / scalar | Weights |
|---|---|---|
| `gear_drop` | `gear_wc`, `gear_cloak`, `gear_booth`, `gear_van` | 1 / 1 / 1 / 1 (forced by `asset.gear_drop`) |
| `dj_set` | `dj_on`, `dj_break` | 0.65 / 0.35 |
| `keycard` | `kc_staff_room`, `kc_bouncer_board`, `kc_vip_bar`, `kc_count_room`, `kc_dj_booth` | 1 / 1 / 1 / 0.75 / 0.75, pick 1; `kc_dj_booth` `slot_requires {dj_set: [dj_break]}`; `asset.inside_keycard` forces `kc_staff_room` |
| `code_note` | `code_staff_board`, `code_bouncer_log`, `code_count_board`, `code_office_blotter` | 1 / 1 / 1 / 0.5, pick 1 (revealed by `asset.intel_safe_code`) |
| `count_room` | `count_running`, `count_done` | 0.6 / 0.4 |
| `product_location` | `prod_stock`, `prod_green`, `prod_private` | 1 / 0.8 / 1 (revealed by `asset.intel_product`) |
| `product_bags` (scalar) | 3, 4, 5 | uniform |
| `safe_bags` (scalar) | 4, 5, 6 | R-H 0.4 / 0.4 / 0.2; B-C 0.2 / 0.4 / 0.4 |
| `laser_pattern` | `lz_static`, `lz_sweep`, `lz_timed` | R-H 0.5 / 0.2 / 0.3; B-C 0.2 / 0.4 / 0.4 |
| `guard_post` | `rover_floor`, `rover_boh`, `rover_upper`, `alley_smoker` | 1 each; pick 1, `difficulty_add` [0, 0, 1, 1, 2, 2] (1 R/T, 2 H/B, 3 L/C) |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | R/T 0.6 / 0.4; H-C 0.75 / 0.25 |
| `camera` | `cam_a`, `cam_b`, `cam_c` | 1 / 1 / 1, pick 1 (`asset.intel_cameras` reveals) |
| `rear_door` | `rear_propped`, `rear_locked` | 0.35 / 0.65; `force_if {guard_post: alley_smoker} => rear_propped`; `asset.propped_door` forces `rear_propped` |
| `open_window` | `ow_count_open`, `ow_count_latched` | 0.4 / 0.6 (forced by `asset.count_window`) |
| `side_gate` | `gate_open`, `gate_chained` | 0.4 / 0.6 |
| `escape` | `esc_alley`, `esc_tolley` | 0.55 / 0.45 |
| `crowd` (scalar, patrons) | 12, 14, 16, 18, 20 | R 12/14 at 0.5/0.5, T 14, H 16, B 18, L/C 20 |
| `dance_clusters` (scalar, x 5 dancers) | 4, 5, 6 | R/T 4, H/B 5, L/C 6 (the doc's totals: 20 / 25 / 25 / 30 dancers) |

## 3. Rare events (keys + values)

| id | good/bad | chance | min difficulty | effect (doc) | Briefing "surprise" string (bad only, `ui.briefing.sec.event.afterhours.<id>`) |
|---|---|---|---|---|---|
| `count_left_open` | good | 0.03 | — | the safe is open; `[safe_code]` / `[safe]` skipped | — |
| `extra_product` | good | 0.06 | — | +2 `loot.parcels` | — |
| `vip_party` | bad | 0.08 | — | +6 VIP patrons, a second rope bouncer (pager) | "a VIP party upstairs (an extra bouncer on the balcony)" |
| `off_duty_cop` | bad | 0.06 | Hazardous | an off-duty cop in a balcony booth (radios on a masked player) | "an off-duty cop among the guests" |
| `co_op_pickup` | bad | 0.08 | Brutal | 2 Co-op couriers at 14:00 at the loading door | "Co-op couriers due for the product" |
| `rooftop_watch` | bad | 0.08 | — | the Keston Row sniper perch in loud | "a police marksman on the Keston Row roofs" |

## 4. Pre-planning (HeistDef.preplanning; the doc's block, unchanged)

Every asset already exists in data. `asset.gear_drop` and `asset.count_window` are limited by their AH-only points;
`asset.intel_safe_code` and `asset.intel_product` already carry `heists = [&"afterhours"]` (D-143.5). **No asset
work is needed.** Favors 5.

| Asset | cost | favors | max | Status |
|---|---|---|---|---|
| `asset.gear_drop` | 1,000 | 1 | 1 | exists (4 points `pp_gear_*`) |
| `asset.count_window` | 1,500 | 1 | 1 | exists (`pp_count_window`) |
| `asset.intel_safe_code` | 1,500 | 1 | 1 | exists, reveals `code_note` |
| `asset.intel_product` | 1,200 | 1 | 1 | exists, reveals `product_location` |
| library (body-bag case, ammo, doctor, inside keycard, propped door) | as their defs | — | — | points in the doc's block |

## 5. Briefing

- Prose (`heist.afterhours.briefing`, exists): re-read it against the final doc. It should cover: the Accountant, the
  Velvet, Crale's office safe, a civilian start (get your gear first), **3 bags**, the product and the count room as
  a bonus, and a van in the alley or on Tolley St.
- Steps (new strings): `ui.briefing.step.afterhours.office` "Get into Crale's office: the keycard, then the safe by
  code or drill", `ui.briefing.step.afterhours.bonus` "The product and the count room's cash are a bonus".
- Known security (BriefingIntel, after G1): bouncers (fixed + rovers per difficulty), the camera operator (60 / 75%),
  cameras, the laser grid, the crowd size, and the surprises (§3).

## 6. Cast tag rows (A / D own `npc_visual_tweak.tres`; proposed `heist_tag_characters[&"afterhours"]`)

```
# D batch 1 (env/d-art 9dad4f12): 6 bouncer looks (b = woman / bun, d = older head doorman, e = young / hoodie,
# f = polo + glasses: the camera-operator type), 4 bartender looks.
&"guard_door": [&"club_bouncer_d", &"club_bouncer"]   &"guard_rope": [&"club_bouncer_b", &"club_bouncer_c"]
&"guard_floor": [&"club_bouncer", &"club_bouncer_e"]  &"guard_upper": [&"club_bouncer_c", &"club_bouncer"]
&"guard_boh": [&"club_bouncer_e", &"club_bouncer_b"]  &"guard_alley": [&"club_bouncer_e", &"club_bouncer_b"]
&"guard_camera": [&"club_bouncer_f"]
&"civ_bar_main": [&"club_bartender", &"club_bartender_b", &"club_bartender_c"]
&"civ_bar_east": [&"club_bartender_c", &"club_bartender"]   &"civ_bar_vip": [&"club_bartender_d"]
&"civ_box_office": [&"club_bartender_b"]  &"civ_count": [&"club_bartender_d"]
&"civ_dj_stage": [&"club_dj"]             &"civ_dj_green": [&"club_dj"]
# D batch 2 (b4f08e3a): 12 patron looks, a-l.
&"civ_patron": [&"club_patron", &"club_patron_b", &"club_patron_c", &"club_patron_d", &"club_patron_e",
	&"club_patron_f", &"club_patron_g", &"club_patron_h", &"club_patron_i", &"club_patron_j", &"club_patron_k",
	&"club_patron_l"]
# D batch 3 (21dfc4fe): the dance-floor pool, 12 looks a-l (dance_a/b/c checked for clipping).
&"civ_dancer": [&"club_dancer", &"club_dancer_b", &"club_dancer_c", &"club_dancer_d", &"club_dancer_e",
	&"club_dancer_f", &"club_dancer_g", &"club_dancer_h", &"club_dancer_i", &"club_dancer_j", &"club_dancer_k",
	&"club_dancer_l"]
&"civ_offduty": [&"frd_agent"]
```
These are the doc's roster (D's `p5_cast.json` roles). The camera operator uses `club_bouncer_f` (the tag name `guard_camera` is a proposal: A / D pick the real
CAMERA_OPERATOR tag). B only needs the tags to exist so BriefingIntel counts staff and patrons as civilians.

## 7. Strings (new rows; written when the gate opens)

Existing and kept: `heist.afterhours.*` (4), `objective.afterhours.*` (12), `music.afterhours.name`,
`item.asset.gear_drop.*`, `item.asset.count_window.*`, `item.asset.intel_safe_code.*`, `item.asset.intel_product.*`.

| Key | Text (proposed) |
|---|---|
| `ui.briefing.step.afterhours.office` / `.bonus` | §5 |
| `ui.preplan.point.afterhours.pp_spawn_foyer` | Foyer: the front door |
| `ui.preplan.point.afterhours.pp_spawn_vip` | On the list: the VIP lounge |
| `ui.preplan.point.afterhours.pp_spawn_alley` | Alley: the delivery door |
| `ui.preplan.point.afterhours.pp_gear_wc` | Gear: the guests' washroom |
| `ui.preplan.point.afterhours.pp_gear_cloak` | Gear: the cloakroom |
| `ui.preplan.point.afterhours.pp_gear_booth` | Gear: the reserved booth |
| `ui.preplan.point.afterhours.pp_gear_van` | Gear: in the van |
| `ui.preplan.point.afterhours.pp_insider_keycard` | Staff room: a keycard left out |
| `ui.preplan.point.afterhours.pp_back_door` | The alley door |
| `ui.preplan.point.afterhours.pp_count_window` | Count room window |
| `ui.preplan.point.afterhours.pp_drop_alley` | Alley: by the dumpsters |
| `ui.preplan.point.afterhours.pp_drop_roof` | Back roof: by the ladder |
| `ui.preplan.point.afterhours.pp_drop_tolley` | Tolley Street: the staff door |
| `ui.preplan.point.afterhours.pp_escape_alley` | Van: the alley |
| `ui.preplan.point.afterhours.pp_escape_tolley` | Van: Tolley Street |
| `ui.briefing.sec.event.afterhours.<id>` (4 bad events) | §3 |
| `achievement.ah_*.name` / `.desc` (12) | §9 |

15 point labels = every `pp_*` id in the doc's pre-planning table.

## 8. Voice (Mercer + the Accountant + the DJ; `lines.tres` + `voice.vo.*`, `test_vo_coverage`)

Each line below is said by a mission hook (the doc's mission notes) or deleted. Ids follow the OF pattern
(`ah_<event>`); the text is a first draft for the lead's voice pass.

| Id | Speaker | Draft |
|---|---|---|
| `ah_intro` | Mercer | "You're guests tonight. Have a look around; nobody inside knows your faces." |
| `ah_gear_where` (per slot: wc / cloak / booth / van) | Mercer | "Your gear's in the washroom duct." / "...behind the cloakroom counter." / "...under the reserved booth." / "...in the van." |
| `ah_gear_got` | Mercer | "Got the gear. Mask up when you're out of sight." |
| `ah_keycard` / `ah_office` | Mercer | "That's the office card." / "You're in Crale's office." |
| `ah_code` / `ah_safe_open` | Mercer | "That's the combination." / "Safe's open. Bag the cash." |
| `ah_drill_on` / `ah_drill_jam` / `ah_drill_done` | Mercer | "Drill's on the safe." / "Drill's jammed." / "Drill's through." |
| `ah_product` / `ah_count_room` | Mercer | "There's the Co-op's product. Worth taking." / "Count room's running. Cash on the tables." |
| `ah_lasers` | Mercer | "Laser grid. Watch the pattern." |
| `ah_last_pager` | Mercer | "That's the last pager they'll believe." (own_last_pager_line) |
| `ah_music_cut` | Mercer | "Music's off, lights are up, and the safe just locked itself. Drill it." (the doc's line) |
| `ah_crowd_out` | Mercer | "The crowd's out. Now it's just us and them." |
| `ah_secured` | Mercer | "That's three. Anything else is a bonus." |
| `ah_van_eta` / `ah_escape` | Mercer | "Van's coming round." / "Van's here. Go." |
| `ah_couriers` / `ah_offduty` | Mercer | "Two of the Co-op's men at the loading door." / "Off-duty cop in the booth. He'll call it in." |
| `ah_acc_intro` / `ah_acc_casing` | Accountant | "Crale keeps the week's money in his office. Bring me three bags." / "Take your time. The music covers a lot." |
| `ah_acc_secured` / `ah_acc_payday` | Accountant | "The numbers are good." / "A pleasure doing business." |
| `ah_dj_*` (2) | DJ (new `dj` speaker) | the doc's QC-72 speaker: a set intro and a "lights up" line at the alarm |

About 28 lines (the plan's 27-30). The generic assault, escape-arrived and objective-new radio lines are reused.

## 9. Achievements (6; existing condition keys only)

| id | condition |
|---|---|
| `achievement.ah_last_call` | `{"event": &"heist_completed", "heist": &"afterhours", "stealth": true, "objectives_open_method": {&"safe": &"code"}, "count": 1}` (a stealth clear, the safe opened by its code; as Glasshouse's safe achievement) |
| `achievement.ah_no_witness` | `{..., "stealth": true, "max_kills": 0, "max_civilian_kills": 0, "count": 1}` |
| `achievement.ah_full_count` | `{..., "all_loot_secured": true, "count": 1}` |
| `achievement.ah_product` | `{..., "loot_min": {&"loot.parcels": 3}, "count": 1}` |
| `achievement.ah_quick` | `{..., "max_time_s": 720.0, "count": 1}` ◇ |
| `achievement.ah_cataclysm` | `{..., "difficulty_min": 5, "count": 1}` |

`ah_last_call` uses `objectives_open_method` (Glasshouse / Shadow Ledger use the same key). It needs the AH mission to
record `open_method` on `[safe]` (`&"code"` / `&"drill"`), as GH's mission does: **a note for C's mission script**.
Tests:
`test_heist_achievements` rows plus an AH payday e2e copied from `test_of_payday_e2e` (the D-148 level pin and the
co-op parity test).

## 10. Open for the LEAD / C

1. C: fix the doc's HeistDef `escape_options` to `[van]` and the loot table's base values (§1).
2. LEAD: confirm `base_payout` 40,000 (D-143) over the doc's 75,000 placeholder.
3. A / D: the §6 tag rows when AH is scheduled.
4. C: the AH mission records `open_method` on `[safe]` (code / drill) for `ah_last_call` (§9).
