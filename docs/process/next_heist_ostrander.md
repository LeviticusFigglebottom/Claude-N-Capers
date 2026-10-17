# Next heist: Ostrander Federal build plan (DRAFT; LEAD review pending, paper only under D-115)

Owner: LEAD. Status: **planning only** (D-115: no new heist until all five existing heists are "done" per
`docs/process/heist_completion.md`; D-111 polish gate holds too; D-129 restates "planning only").
Design source of truth: `docs/design/heists/ostrander_federal.md` (G0 APPROVED, D-075; QC-60..69). This file is the
*build* plan: what the code already has, what the doc needs that is missing, who builds what, how we prove it plays.
Audit done read-only against round-229 code (`lead/round-229`), 2026-10-16.

## 1. Why Ostrander second (unchanged from next_heist.md §1)
Size L, stealth + loud, first 5-level map (B, G, Gallery, Exec, Roof) and first open-for-business stealth heist.
Gallery Night's groundwork (next_heist.md §3b.6) already covers about half of the new systems it needs (see §3).

## 2. Start gate
1. D-115 closed: every heist_completion.md row "done" (open now: ND-1/2/3, SL-1/2/3/6, DB-2/4/6/7, GN-8 crash and B3,
   A-DB, A-SL, B-GN/DB/SL, GH-1).
2. D-111 polish gate items 1-4 hold.
3. The paper work below (OF-L1, the doc fixes in §3b) can be done before the gate; nothing else.

## 3. Audit of the G0 doc against today's code (read-only helper for the LEAD, 2026-10-16)
**Exists and reusable (no new code):**
- Vault flow (Night Deposit pattern, `game/world/heists/night_deposit/night_deposit_mission.gd`): the time lock runs on a
  mission timer (`start_timer(&"time_lock")`), so a lockdown simply cancels it (`cancel_timer`, `fail(&"time_lock_wait")`),
  disables TL and the hack (`Interactable.enabled`), the vault door is a `Door` VAULT (`unlock()`+`set_open`),
  the server hack starts the time lock on `device_finished`, and there is a `time_lock_glitch` rare event. **QC-64 needs no
  new Safe API if OF uses this pattern** (`Safe.time_lock_s` has no abort; do not use it for the vault).
- Prefabs: `security_camera` (60°, `titan`), `camera_station` + operator, `keycard_reader`, `keycard_pickup`, `hack_terminal`
  (interruptions `Vector2i`, `pause(reason)`/`pause_on_alarm`, `reconfigure`, `clears_alarm_groups`), `laser_grid`
  (`static`/`sweeping`/`timed_off`, `set_enabled`), `door` (NONE/LOCKPICK/KEYCARD/CODE/VAULT/BARRED, `push_bar`, `width_m`,
  `npc_authorized_tags`, `relock`, `suspicious_when_open`), `padlock` (lockpick/saw), `safe` (SMALL/MEDIUM, `methods`),
  `deposit_box` (saw target), `small_loot`, `loot_spawn`, `drill_point` (`Device.THERMAL`, jams), `bag_lift` (cash lift,
  2 bags, `travel_s`), `ladder` (`usable` setter toggles its NavLink), `window` (breakable), `secure_zone`, `escape_zone`
  (`van`/`heli`, `arrival_delay_s`), `body_container`, `alarm_button`, `phone`, `code_note`.
- HeistMission API (`game/systems/heist/heist_mission.gd`): objectives + `update_objective_data` (marker_tags, ui_hud 1.8),
  `require_loot`, timers, `schedule_at` (QC-25 timed spawns), `spawn_guards`, `say`, `find_tagged`, `variant`,
  `pager_cap`, `set_sniper_perches_open`, `rare_effects`, `activate_escape`, `has_asset`, `crew_spawn_tag`.
- VariantResolver: pick-N, `difficulty_add` (guard_post 1/1/2/3/4/4), scalar and rule `weights_by_difficulty`, rare
  `min_difficulty`, requires/conditions. Every OF variable in the doc's table maps onto it.
- Director/AI: pager cap, cuffs, civilian panic → phone/alarm button, cower (`cower_stand`/`cower_seated`), casing
  S1.1 (`casing_rate_mult` 0.35), PUBLIC/RESTRICTED MapZones, QC-41 one-way `RappelLinks` (ND hall skylight precedent for
  the lantern), `breach_only` ENTRY tag, D-122 breach nav layer, assault events (turret van / heli / breach),
  sniper perches.
- Content stubs: `heist.ostrander_federal.name/subtitle/brief` (strings.csv 2672-2674), Board entry (`contact.accountant`,
  district `financial`), `heist_list` entry (3 AI teammates), accent `#6FCF97` (QC-69 accent confirmed in data),
  loot defs `loot.cash_bricks` (MEDIUM $8,000), `loot.gold` (HEAVY $14,000), `loot.bearer_bonds` (LIGHT $7,000),
  `loot.server_drives` (MEDIUM $7,500), `loot.body_bag`.
- Cast delivered (ENV D, `game/world/characters/p5_cast.json` heists.ostrander_federal): `npc_bank_teller(_b)`,
  `bank_manager`, **`bank_officer`, `bank_officer_b` (QC-67 done)**, `security_officer(_b)`, `npc_bank_guard`,
  `bank_customer(_b)`, `civilian_customer_a/b`, `armored_car_crew(_b)`.
- Levelcheck: `hall` purpose 6-9 m (lc_check_scale.gd:47), `industrial_door`, camera_spine/camera_screen, lasers,
  barred_doors, viewmodel_lit, walkthrough whitelist, bounds, perf, variety.

**Reusable from Gallery Night's §3b.6 groundwork (built for GN, general):**
- **NPC-carried keycard (QC-52 = OF QC-62):** `KeycardPickup.carrier_tag` (released on dead/tied/intimidated/dominated,
  stays on the corpse, `carried_item_s` take). Put `carrier_tag = civ_manager_*` on the `kc_on_manager` slot's pickup.
- **Door relock/BAR** (`Door.relock(Lock.BARRED)`) for the lockdown vault gate; **`KeycardReader.set_disabled`** for the
  dead gate reader; **`LaserGrid.set_enabled(false)`** for `[lasers]`; **hack `pause`/`reconfigure`** for the lockdown.
- **NPC door authorisation for staff roles** (`npc_authorized_tags`, VAULT doors too): tellers/BC doors, teller gate, dock
  personnel door, PC service door.
- **Mission-driven NPC errands** (GN QC-57 Vaultline couriers, polled stops) → `armored_car_early` crew LD → BB → gate.
- **NpcVisualTweak `heist_tag_characters`** (D-103 §3b.1) and ambient clip mapping (`teller`→`teller_count`, `desk`,
  `smoke`, `walk_text`, `look`, seated cower).
- Also from DB: `burn_point.requires_loot` + `asset.thermite_drop` (a tool-bag preplan drop: the shape for
  `asset.thermal_drill_drop`); `padlock.place_saw`. From SL: heli escape, tower-floor stair rules, 45°-coping precedent.

**Partial:**
- `drill_point`: THERMAL + jams exist; **no `requires_loot`/`requires_count`** (QC-60). burn_point's single-bag check is
  the template.
- Timed loot spawn: `LootManager.spawn_bag(loot_id, xform)` exists, **no `HeistMission.spawn_loot(loot_id, tag, count)`**
  wrapper (the mission contract allows only the HeistMission API).
- QC-61 floor breach: `Ladder.usable` toggles (check it replicates and hides/no-collides when off); **`bag_lift` has no
  enable/disable, no generic `GameplayPrefab.set_enabled`**, RappelLinks are built at load (no runtime-enabled police link
  down the hole). Nav link changes must land deterministically (D-121 sync nav).
- QC-63: codes via `CodeRegistry.reveal(group)` exist (code_note); **`hack_terminal` has no `reveals_code_group`**; a
  runtime "intel note reveals a variant group" (the planner `[code_hint]` → `code_pc`) does not exist (PreplanAssets
  `reveals` is start-of-run only). Mission-side workaround: marker_tags on `code_pc` after the planner is read.
- QC-68: one-way rappel exists; **a police spawn on an off-navmesh roof island (P5 Corvino +16) chained by two rappels
  (setback → roof/terrace → lantern 8.6 m)** is untested; director spawn/path rules may reject an island spawn.
- Civilian behaviour: wander is random within `civilian_wander_radius_m` on **one floor** (`civilian_wander_floor_dy_m`).
  The doc's manager routes (`mgr_gallery` crosses Gallery ↔ Exec; `mgr_vault` WC break 40-70 s), teller rotation to BR on
  the Gallery level (40-80 s), officers' coffee runs (50-90 s) need **ordered, timed, cross-floor civilian routes**. Not built.
- Preplan: `asset.thermite_drop` precedent; `params.count` (2 bags) on a drop is new; `force_variant` exists.
- NpcVisualTweak: shared `civ_manager` maps to `civilian_manager` (GH) and `civ_customer` lacks bank_customer: OF needs its
  own `heist_tag_characters.ostrander_federal` block (guards, operator, tellers, manager, officers, customers, VIP, Vaultline).

**Missing:**
- The map (`game/world/heists/ostrander_federal/` does not exist), `ostrander_federal_def.tres`, variant table, mission
  script, blueprint, plan scripts (`tools/levelcheck/plans/ostrander_federal_floors_ascii.py`, `_site_ascii.py`).
- Levelcheck: `teller_worktop` scale kind (0.95-1.05 m; only `counter_transaction` 1.05-1.1 exists); the GA solid-base LOS
  sample (crouched crew on GA hidden from the hall floor); camera-free bag line per camera layout (camera_spine config).
- Loot: `loot.thermal_drill_part` (HEAVY, `is_tool`, $0, QC-65); a `loot.small_valuables` decision (deposit boxes are
  prefab small loot; recommend no def).
- Preplan assets: `asset.thermal_drill_drop`, `asset.intel_code_pc`, `asset.manager_schedule`,
  `asset.fire_escape_ladder` (QC-66) + per-heist `propped_door`/`inside_keycard` params; blueprint tres.
- Strings: `objective.ostrander_federal.<tag>` ×21, `heist.ostrander_federal.briefing` + briefing_objectives (D-117 §4/§5),
  ~40 VO lines (Accountant + Mercer), preplan point labels.
- Audio/look: music track `ostrander_federal` stems, 4 ambiences, per-heist alarm bell, `lut_ostrander_federal`,
  style-guide palette row (QC-69, LEAD).
- New kits (6): `banking_hall_grand`, `vestibule_bronze`, `lounge_client`, `deposit_hall`, `office_vault_ops`,
  `exterior_plaza`; the burn-through set piece (lid drop, dust, the hole mesh); a cosmetic drop heli / second van.
- Cast: a VIP client look (`bank_vip_client`, QC-67) and the Halden bodyguard tag.
- **Assault events (D-114 §5, D-115 #6): the design doc defines none.**
- Roadmap rows (none mention OF; B6-01/D3-01 still say `meridian_federal`).

**Wrong (doc or data vs rulings):**
- **D-120 economy:** the doc's loot table (cash $1,600, gold $2,800, bonds $1,400, drives $1,800) predates the ×4-5 bag
  values now in data; `base_payout` $160,000 is pinned by `game/tests/b/test_p5_catalogue.gd:35,42` (160000…1472000).
  Max bag value is ≈ $180k (10 cash + 4 gold + 4 bonds + 2 drives) + boxes, so $160k breaks "bags 39-81 % of a full clear".
- **D-102:** ghost line step 6 says cash bags are "MEDIUM, sprint allowed"; MEDIUM is ×0.75, **no sprint** (only LIGHT
  sprints). The 6 × ~25 s trip timing must be re-derived (≈ 33 s/trip).
- **D-104 §7.1:** laser bypass gap "≥ 0.8 m clear width" → must be ≥ 1.0 m; crouch beams centre ≥ 1.30 m.
- **GN §7.5 rule:** parapet coping "45° sloped" equals max walkable slope (45°) → ≥ 50°. Lantern glazing "> 40°, cannot be
  walked" is wrong for a 45° player → ≥ 50°, and the 0.6 m curb is jumpable (apex 1.08 m) → sloped curb top or a wall.
- Doc takes the card in "2 s"; the shipped carried-card take is `carried_item_s` 1.0 s (GN). One value for all carried cards.
- `armored_car_early` crew "LD → lift → CQ": NPCs cannot ride `bag_lift`; route them by SA.

## 3b. Proposed lead rulings for the build (to adopt as a D-entry)
1. **Vault = ND pattern.** Time lock on a mission timer + Door VAULT; lockdown = cancel timer, disable TL/hack
   (`pause(&"lockdown")`), `KeycardReader.set_disabled(true)`, vault gate `relock(BARRED)`. QC-64 closed with no Safe API.
2. **QC-62 = QC-52.** The manager's card is a `keycard_pickup` with `carrier_tag`; take time = `carried_item_s` (doc → 1 s).
3. **D-120 re-price (B + LEAD):** B proposes `base_payout` for OF on the D-120 shape (≈ $70-90k, above SL's $70k as the
   bigger L job) and updates test_p5_catalogue; doc loot table follows data (D-117 §3 "docs follow data").
4. **Civilian routes (new A system, general, reused by Afterhours):** a `CivilianRoute` (ordered PatrolPoint stops with
   dwell s and cross-floor nav, a "away" window the HUD/intel can name) for the manager, the rotating teller and officers.
   Fallback if A is short: one-floor routes + the GN errand pattern in the mission script.
5. **Descope the SD escort** (customers led down SB by an attendant): the SD attendant and 0-1 customer spawn in SD.
   The `mgr_vault` manager walks SB alone. PD2 has no escorted customer flows.
6. **Assault events (D-114 §5):** C adds to the doc: turret van on Halloran Ave, police heli over the terrace (rappel), and
   breach points (hall arched bays, XL terrace doors, the HH roof door); A wires rows (X-3 pattern).
7. **D-122:** every loud-breachable locked shell door (dock roller/personnel, fire exit, HH, XL doors, bronze doors at
   lockdown) is on `NAV_LAYER_BREACH`; the BARRED vault gate and the vault door are **not** breachable (only the floor).
8. **D-102/D-104 doc fixes** (C): sprint line, laser gap 1.0 m, coping/glazing ≥ 50°, the ghost-line timing re-derived.
9. **No stealth-only fail** (D-103 §3b.3): fail = custody/abort only. The drill parts respawn at the drop if destroyed
   or lost off-map, and the hoist must stay usable (D-093: no soft lock).
10. **Escape rule:** loud escape opens on `[secure]` + `escape_eta_s` (doc), not ND's fades rule; one rule per heist, written.
11. **D-128 detection:** the doc's "hidden" claims (crouched behind the 1.05 m ledge with a 1.2 m crouch capsule, GA solid base)
    are verified with A's LOS sample on the detection sample points, not by eye; adjust the ledge/base if they fail.

## 4. Rules the build must satisfy (next_heist.md §4 + heist_completion lessons)
- Every objective carries `marker_tags` (ui_hud 1.8); casing objectives too; OF joins `test_heist_readiness.gd` HEISTS.
- Public doors casing-allowed; staff doors that are "unlocked during hours" (PC service door, LO hall door) are NONE.
- Every spawn tag maps via `heist_tag_characters.ostrander_federal` (no capsules, PO-5.7); D-3 lesson: check the shared
  map does not win (GH's `civ_manager`).
- Key lights `viewmodel_lit` (layer 21); ≤ 8 lights per 6 m tile (D-112); first L map → perf validator on every review cam.
- Director caps per crew (D-099): Routine = SWAT + shields; Brandt/Aegis Lethal+; Wrecker HP D-125; +25 % D-127.
- Bags per D-102: cash/drives MEDIUM (no sprint, 4 m throw), gold + drill parts HEAVY (×0.5, 2 m throw), bonds LIGHT.
- Drill jams 1-2, none in first/last 10 % (D-114 §2); drill noise is a stimulus, not an alarm (D-114 §1).
- Every written VO line is said by the mission or deleted (D-117 §6); briefing via keys + objective list (D-117 §4/§5).
- Own music stems + ambiences (X-1/X-2 lesson); assault events (X-3); stealth and loud e2e flows (X-4) on the real menus.
- Count against the doc, not "some": GN-2/3/4 shipped 5/12 patrons, 2/8 BODY_HIDE, 6/50 COVER. OF targets: customers
  4-8 + 2 plaza, BODY_HIDE 8, COVER ~70, cameras C1-C16, 6 code-PC desks.
- X-5 lesson: every `desk_work`/`sit`/`teller` idle has a seat or counter within 1 m (SL-3: Kessler 4.1 m off); NPC idle
  points ≥ 1 m off door centrelines; nav agent radius vs the 0.35 NPC capsule.
- Doc durations are the build's (A-SL/A-DB lesson: saws, drills, hacks per doc or a doc change): hack 45 s/1, rack 90 s/2,
  lasers 20 s, padlock 8 s, lift 8 s, hoist 6 s, thermal 360 s.
- Objective counts match (SL-5): `[secure]` = 6 (4 on Routine) from `difficulty`; tools never count (`is_tool`).
- D-121: burn-through nav changes on sync nav; corpse anchors; bag rests server-authoritative.
- `validate_level` PASS + PO-3 snag probe 0 + P walk with no STUCK rows before G2; GN-8 crash lesson: run the loud e2e
  through LOUD → ESCAPE on ≥ 3 seeds before calling it done.

## 5. Staffing
Team per D-129: A, B, C, D, P all active. C builds the map (G1 greybox → G2); D the VIP look + any missing clips; A systems +
mission; B data/strings/UI; P real-input verification. A also co-owns `game/world/heists/**` (owners.json) for mission files.

## 6. Work breakdown (proposed; starts at the §2 gate except OF-L1)
| Id | Owner | Task |
|---|---|---|
| OF-L1 | LEAD | Adopt §3b as a D-entry; roadmap rows (rename meridian in B6-01/D3-01); palette row + LUT (QC-69); add OF to test_heist_readiness |
| OF-C0 | C | Doc fixes (§3b.5-8, D-102 sprint, gap 1.0 m, coping/glazing ≥ 50°, assault events, ghost-line timing, loot table follows data) |
| OF-C1 | C | Plan scripts (`ostrander_federal_floors_ascii.py --check`, site) → G1 greybox: 5 levels, all contract nodes (slots for all 20 variables, 16 cams, 5 holdouts, 5 police spawns + breach_only ENTRYs, perches S1-S3, preplan points), marker objective_tags, the lid/hole/hoist/rope ladder pre-placed disabled, validate_level |
| OF-C2 | C | G2 art: 6 new kits, sunburst/lantern/meridian landmarks, sun-disc light curve, GI per band, 34 review shots, music stems + 4 ambiences + bank bell, burn-through set piece |
| OF-C3 | C | Levelcheck: `teller_worktop` kind, GA solid-base LOS sample, camera-free bag line per `cam_a/b/c`, laser gap ≥ 1.0 m |
| OF-D1 | D | `bank_vip_client` look + Halden bodyguard; verify teller_count / cower placements (QC-67); confirm manager name Lionel Ashgrove |
| OF-A1 | A | `drill_point.requires_loot` + `requires_count` (QC-60) + `HeistMission.spawn_loot(loot_id, tag, count)`; unit tests |
| OF-A2 | A | Runtime enable for pre-placed prefabs (QC-61): `GameplayPrefab.set_enabled` (hidden, no collision, no interaction, nav links off; replicated) for `ladder`/`bag_lift`; runtime one-way rappel link down the hole; D-121 sync; tests |
| OF-A3 | A | `hack_terminal.reveals_code_group` + a runtime variant-group reveal from an intel note (QC-63); tests |
| OF-A4 | A | `CivilianRoute` (§3b.4): ordered, timed, cross-floor civilian stops; manager/teller/officer; panic/intimidate interrupts; test |
| OF-A5 | A | QC-68: police spawn on a roof island + rappel chain (setback → roof/terrace → lantern); director spawn/path test |
| OF-A6 | A | `ostrander_federal_mission.gd`: stealth + lockdown + drill delivery + burn-through + hoist + 3 escapes + 5 rare events + every VO line; tag map block; assault event rows; e2e stealth (ghost line roll) + loud flows, 3 seeds each |
| OF-B1 | B | `ostrander_federal_def.tres` values (D-120 payout), variant table data, `loot.thermal_drill_part`, 4 new preplan assets + overrides, blueprint, objective/briefing/VO/preplan strings, test_p5_catalogue update |
| OF-P1 | P | Real-menu windowed pass on G1 (traversal §7 tests, ghost line timing under D-102/D-128) then on G2; snag probe 0 |

Order: OF-L1/C0 now (paper) → at the gate A1-A5 and C1 in parallel (A's APIs each with a unit test, before the map needs
them) → A6/B1 on the greybox → P1 on G1 → C2/D1 → P1 again on G2 → D-115-style "done" check.

## 7. G1 traversal requirements (player numbers per next_heist.md §7: r 0.35, stand 1.8 / crouch 1.2, step 0.35,
## slope 45°, apex 1.08 m, heavy 0.27, ladders masked only, no bags, no mantle)
1. Laser grid (VC x 21): bypass gap ≥ 1.0 m at the south wall; crouch-under beams lower face ≥ 1.215 m; sweep/timed
   windows long enough to cross 4 m with a MEDIUM bag (×0.75 speed).
2. Teller counter: crew crouched behind the 1.05 m ledge must test hidden on the detection sample points (1.2 m capsule);
   raise the solid front or lower the hide claim. Teller gate and TW staff doors ≥ 1.0 m.
3. GA throw spot (5.0 m): guard collider true to the 1.1 m visual (solid to 1.0 m); MEDIUM (4 m) and HEAVY (2 m) throws
   at 3 pitches land on the hall floor, not on the 1.0 m base ledge.
4. Terrace east parapet throw to E2 (8.6 m drop): coping ≥ 50°, and a HEAVY 2 m throw clears the coping and lands inside
   or beside the E2 secure zone; no ledge or awning catches bags.
5. Roofs: all copings ≥ 50°; lantern glazing ≥ 50° with a sloped curb top (no standing on the 0.6 m curb); OOB 0.5 m
   beyond every parapet; no walkable slope < 50° outside the play mesh; P5 setback (+16) unreachable from +12.2.
6. Fire-escape arrival `fe`: the 0.6 m step over the lowered coping becomes 2 × ≤ 0.35 m steps; 1.1 m rails each side;
   drop ladder 3.0 m and the caged ladder 3.6 m with ≥ 1.0 m level landings at both tops.
7. The hole (24, 14): 1.2 m opening, rope ladder 4.0 m with a ≥ 1.0 m clear landing on the vault floor; the hoist car fits
   the opening; falling into the hole is survivable or prevented by a rail; bags thrown down land in VT.
8. Dock: Ledger Lane ↔ LD personnel/roller doors step-free (≤ 0.35 m) or a ramp ≤ 45°; the LD → E1 throw (4 m MEDIUM)
   reaches the van zone; same for the Tannery fire exit → E2 bay with a HEAVY bag.
9. Plaza: 5 × 0.15 m steps collide as a ramp; the AV street door is step-free to the plaza.
10. Stairs SA/SB collide as ramps; landings level at every door; handrail colliders thin.
11. RC shelving aisles ≥ 1.0 m clear between colliders (crew and the rover_basement loop); cash cage and bullion cage
    gates ≥ 1.0 m; ≥ 60 % of the vault floor clear between the cages, the hoist and the door.
12. Doors on routes ≥ 1.0 m (stair doors, BC doors, PC service door, LK and cubicle doors used by the ghost line, J1, SV, EA,
    XL); NPC idle points ≥ 1 m off door centrelines; the cash lift car takes 2 bags without a snag.
13. Queue rails and velvet ropes: one simple collider per run; check-writing tables and benches leave ≥ 1.0 m lanes.
**G1 tests (ENV P, windowed real input):** laser gap walk + crouch with a bag; GA and terrace throws at 3 pitches;
fire escape up, HH door, SA down; the hole ladder up/down + hoist cycle; lane → LD → E1 with a MEDIUM and a HEAVY bag;
fire exit → E2 with HEAVY; the ghost line timed solo on Cataclysm (2 ECM, 1 tie) under D-102 speeds and D-128 fills;
PO-3 snag probe = 0.

## 8. Open questions for the LEAD
1. D-120: OF `base_payout` (doc $160k, test pins it) — accept B re-pricing on the D-120 shape? (§3b.3)
2. Civilian routes: build `CivilianRoute` (A, general) or accept one-floor wander + mission errands? (§3b.4)
3. SD escort descope (§3b.5) and Vaultline crew by SA instead of the cash lift — OK?
4. Assault events for OF are not in the doc (D-115 #6): C to write them in OF-C0?
5. PD2 fidelity check (no in-repo cite found): Big Bank-style lockdown that aborts a running time lock and forces a
   floor drill is an original choice; confirm it stays (it matches ND's shipped lockdown).
