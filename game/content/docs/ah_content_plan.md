# Afterhours: ENV B content plan (paper; reuse-first D-147; same shape as rt_content_plan.md)

LEAD 2026-10-21: paper only, no Afterhours data on env/b-content until it is scheduled. Source of truth:
`docs/design/heists/afterhours.md` (C's doc: Loot table, Objectives, Variable table, Rare events, Escape,
Pre-planning, HeistDef). Checklist = OF-B1 and `next_heist_prep_rt_ah.md`. "Reuse" = an existing id / file /
pattern; "new" = B writes it.

## 1. Def values and variant data (B values; C's generator writes the files)

| Item | Value | Reuse / new |
|---|---|---|
| `base_payout` | $75,000 (doc placeholder; P6 balance against the D-120 shape) | check vs the bags below |
| Loot | `loot.cash_bricks` (safe, 4-6 bags), `loot.parcels` (product, 3-5), `loot.cash` (count room, 2); `loot.body_bag` | **reuse, no new loot ids** |
| **Loot values (doc is stale)** | the doc's loot table lists pre-D-120 bases ($1,600 / $1,500 / $1,200); the LootDefs are **8,000 / 7,500 / 6,500** (S10.6) | **C to update the doc table**; no B change |
| Small loot | till $600, drop safe $900 x3, bottle-service $800, desk drawer $1,200, tip jar $300 (~12 pickups; D-068 range) | B values for the prefabs (doc's list is fine) |
| Contact | `contact.accountant` (D-075; 111 Accountant lines, radio set exists) | reuse |
| Mode | STEALTH_OR_LOUD, `start_mode &"civilian"` (D-065) | reuse (GN / OF casing patterns) |
| Escape | **doc's HeistDef says `escape_options [van, walk]`, but its Escape section and D-075 say no walk-out** | flag to C: `[van]` |
| D-148 XP | `base_xp_by_heist[&"afterhours"]`: **2,500** (M: office + safe + optional product / count room) | new row in payout.tres |
| Stealth bonus | M heist: `stealth_bonus_mult` 1.15 (as ND / GN / SL, S11.1) | reuse value |
| Difficulty rows | `guard_post` pick 1 / 2 / 3 via difficulty_add (doc); the D-145 special limits; pager cap from the tweak | reuse |
| Variant / scalar values | gear_drop, dj_set 0.65/0.35, keycard (5 slots, pick 1), code_note (4, pick 1), count_room 0.6/0.4, product_location, product_bags 3-5, safe_bags 4/5/6, laser_pattern, guard_post, security_room_staffed, camera, rear_door 0.35/0.65 (+ force_if), open_window, side_gate, escape 0.55/0.45, crowd 12-20, dance_clusters 4-6 | values block to C (doc's table is the draft) |
| Rare events | count_left_open 3%, extra_product 6%, vip_party 8%, off_duty_cop 6% (Hazardous+), co_op_pickup 8% (Brutal+), rooftop_watch 8% | names + briefing "surprises" strings (new) |

## 2. Strings (`strings.csv`)

| Group | Count | Status |
|---|---|---|
| `heist.afterhours.*` | 4 | **exist**; re-read the briefing prose against the final doc (civilian start, 3 bags) |
| `objective.afterhours.*` | 12 = every doc tag (casing, gear, keycard, office, safe_code, safe, safe_loot, secure, product, count_room, escape_wait, escape) | **exist**; check `secure` carries `{count}/{total}` |
| `ui.briefing.step.afterhours.*` | ~2 merges ("get into the office: keycard + code or drill", "the product and the count room are a bonus") | new (OF pattern) |
| `ui.preplan.point.afterhours.<point>` | 15 points (3 spawns, 4 gear drops, insider keycard, back door, count window, 3 drops, 2 escapes) | new |
| Blueprint labels (rooms G1-G25, U1-U13, streets) | ~25 from the G1 map | new (generated, as OF) |
| Escape names | van (alley), van (Tolley St) | reuse generic or 2 new |
| Rare-event / surprise names | 6 | new |
| Item / loot names | gear bag (`item.item.gear.name` exists), keycard, code note, cash bricks, parcels ("Sealed Parcels"), cash | **reuse** |
| Civilian-mode prompts / blocked reasons | civilian mode exists (GN / OF casing): `ui.blocked.civilian` "You need your gear" | **reuse** |

## 3. Voice (Mercer + the Accountant; `lines.tres` + `voice.vo.*`; `test_vo_coverage`)

From the doc's mission notes (each line said by the mission, or deleted):
- **Mercer:** intro (civilian), gear location, gear picked up, keycard found, office open, code found, safe open,
  drill started / jam / done, product found, count room, last pager (4th), lasers, music cut (alarm), crowd out,
  required loot secured, van ETA, escape, couriers arriving, off-duty cop spotted. (~21)
- **The Accountant (radio):** intro / casing, objective-new and secure lines in the contact-radio pattern (OF's
  Accountant radio set is the template). (~6-8)
- **Reuse:** the generic last-pager line is replaced by the heist's own (`own_last_pager_line`, OF pattern); generic
  assault and escape-arrived lines.
- Total ≈ **27-30 new lines**.

## 4. Briefing and pre-planning

- **Briefing intel** (`briefing/intel/afterhours.tres`): `intel_export.gd` on the G1 map (guards + the rope / door
  bouncers, cameras, the operator, crowd size per difficulty, laser grid, keycard / code locks, surprises). Needs the
  map. The D-142 glazing tip if the club has notable glass (the count window).
- **Blueprint** (`preplanning/blueprints/afterhours.tres`): 2 floors (Ground / Balcony). Needs the map.
- **Pre-planning assets:** **every asset exists**: library (body-bag case, ammo, doctor, inside keycard, propped
  door, alternate entry, escape position, intel cameras / keycards / guard posts, extra cable ties, spare body bags)
  and the heist ones **`asset.gear_drop`, `asset.count_window`, `asset.intel_safe_code`, `asset.intel_product`**
  (already in data). Favors 5. Costs from the doc (◇ 1,000 / 1,500 / 1,500 / 1,200, 1 favor each).

## 5. Achievements (+ mask-part rewards; payday e2e copy of test_of_payday_e2e)

| id | condition | fields |
|---|---|---|
| `achievement.ah_last_call` | stealth clear without the keycard door breached and the safe opened by code | `stealth` + `objectives_open_method` (exists; safe = code) |
| `achievement.ah_no_witness` | stealth clear, no kills, no civilian kills | `stealth`, `max_kills: 0`, `max_civilian_kills: 0` (exist) |
| `achievement.ah_full_count` | secure every bag offered (safe + product + count room) | `all_loot_secured` (exists) |
| `achievement.ah_product` | secure ≥ 3 parcels | `loot_min` (exists) |
| `achievement.ah_quick` | clear in under N min | `max_time_s` (exists) |
| `achievement.ah_cataclysm` | any clear on Cataclysm | `difficulty_min: 5` (exists) |

All six use **existing** condition fields. Rewards: one mask part each (D's catalog).

## 6. UI checks before / at G1 (no data)

- **Civilian start on every spawn** (D-065): the casing HUD + onboarding card already ship (GN / OF); check the
  "CASING" tag and the gear-pickup line with the club's light show (contrast: the r249 label scrim on marker labels,
  teammate names) on the dark, strobing dance floor.
- **Stampede** (loud): crowd flee + subtitle density (Mercer "music cut" + "crowd out" + police); the subtitle stack
  cap and the Tab sheet clearance (06ca21f0).
- **Loud escape rule** (second assault's FADE or 300 s): the objective line shows "ESCAPE mm:ss" only once the timer
  is known; check the HUD with an open-ended wait (no seconds).
- Real-input menu pass 720p / 1080p / 3440x1440 and the payday e2e once A's phase-2 e2e is green; un-hide then.

## 7. Order (once Afterhours is scheduled)

1. Def values + variant values block to C (§1), with the two doc fixes (loot table, escape options).
2. Strings that need no map (§2), voice lines (§3) + `test_vo_coverage`.
3. Achievements (§5) + tests, D's parts.
4. After C's G1: briefing intel, blueprint, blueprint labels, preplan wiring.
5. Extend the B tests (`test_heist_text_audit`, `test_heist_achievements`, `test_briefing_intel`,
   `test_heist_readiness`, `test_p5_catalogue`, `test_vo_coverage`) and the payday e2e.
