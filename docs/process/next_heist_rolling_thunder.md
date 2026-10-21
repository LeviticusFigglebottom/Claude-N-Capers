# Next heist: Rolling Thunder build plan (PAPER START D-148; build waits for the Ostrander done check)

Owner: LEAD (drafted by an ENV C helper, 2026-10-21). Status: **paper only**. D-144: Ostrander Federal is the only heist in
build until it passes its D-115-style done check; D-148 (LEAD dispatch, not yet written in decisions.md) starts the RT
paper work now. Design source of truth: `docs/design/heists/rolling_thunder.md` (G0 APPROVED, D-075; QC-80..89; D-141
QB-RT1..5). This file is the *build* plan: what the code already has, what the doc needs that is missing or now wrong,
what is reused vs new (D-147), who builds what, and how we prove it plays.
Audit done read-only against env/c-worlds at trunk round 255 (docs identical to `origin/claude/dreamy-hamilton-pc7vck`).

## 1. Why Rolling Thunder third
Loud with a stealth-start ambush on an open street: first daylight heist, first exterior-only arena, first moving
vehicles. It is the most system-heavy P5 heist (A5-01..03 plus the QC-83/88/89 hooks); Ostrander's groundwork covers the
civilians, rappels and lift, not the convoy. Size: the doc says **M** (15–25 min), `next_heist.md` §1 says **L** (QC-RT3).

## 2. Start gate
1. **Ostrander Federal passes its done check** (D-144 / D-115 points 1-6: G2 final, e2e stealth + loud, P windowed G2
   pass, strings/VO, cast). The remaining OF items come first, including the burnt-scorch close render `rc_burn_close`
   (Job C, pending on the GPU box; env/c-worlds 37ab4ce1).
2. No RT map, generator, prefab or mission code before that. Paper now: RT-L1, RT-C0 (§6). The plan scripts'
   `--check` arithmetic is the only borderline item (QC-RT10).

## 3. Audit of the G0 doc against today's code (read-only, 2026-10-21)
Owners from `tools/ci/owners.json`: A = `game/systems/**` (+ co-owns `game/world/heists/**`, `game/world/props/**`),
B = `game/content/**`, C = `game/world/**`, `game/assets/**`, `tools/blender/**`, `tools/levelcheck/**`, D = characters.

**Exists (RT groundwork already shipped, hidden behind the readiness gate):**
- Menus/data (B): `heist_list.tres` entry hidden until `rolling_thunder_mission.gd` exists
  (`game/tests/b/test_heist_readiness.gd:83`); mode label "Loud (ambush start)"; Board/contact `contact.reyes`
  (`content/data/contacts/reyes.tres`, district `southfield`); accent; 17 strings incl. all 13 `objective.rolling_thunder.*`;
  `base_payout` $30k pinned (`test_p5_catalogue.gd:37,44`, D-141.1); `asset.signal_insider`, `asset.intel_route`
  (`content/data/preplanning/assets/`); loot `cash_bricks`, `gold`, `bearer_bonds`, `thermite`. B's own gap list:
  `game/content/docs/next_heist_prep_rt_ah.md`.
- Cast (D, RT-D1 0621b4f2): `p5_cast.json` heists.rolling_thunder (Vaultline crew a–f, `armored_car_marshal`, escort
  pool `patrol_officer`/`tac_light`/`tac_heavy`, site-guard and street-civilian pools); `npc_visual_tweak.tres:98,166`
  maps `civ_street/bus/diner`, `convoy_t1..3`, `cop_*`, `guard_site_*`, `vl_marshal`.
- Anim hints (A, RT-A1): `sit_vehicle`, `sit_eat`, `cook_stove` hint mapping with fallbacks, `play_vehicle_exit`
  (`systems/anim/anim_driver.gd:75,1017`; `tests/a/test_rt_a1_vehicle_diner_clips.gd`).
- Levelcheck purpose `car_park` 2.2–3.0 m (`game/world/tools/levelcheck/lc_check_scale.gd`, D-075/QC-87a).

**Reusable as-is or by parameters (no new code):**
- C4 and charges: `Safe.charges_required`, `place_c4`, fuse, L3.6 blast, trip mines as shaped charges
  (`safe.gd:87,427-470`); the same on `Door` (`door.gd:98`) and `Padlock.place_c4`. Hand saw on `G.SAW_TARGET`
  (`Safe.saw_cut`, `DrillPoint.saw_cut`); `DrillPoint.Device.SAW` with jams and D-138.3 device art (`prop_saw_device`).
- Setup prefabs: `padlock` (lockpick 8 s / saw / `place_saw_stealth` / `targets`), `hack_terminal` (silent signal rig,
  `duration_s` 15, `interruptions` 0–1), `security_camera` with no operator (confirmed stimulus → S3.5 countdown,
  `security_camera.gd:18`), `safe` SMALL, `small_loot`, `loot_spawn`, `body_container`, `window` (breakable, `see_through`,
  nav link `window.gd:190`), `door` (push_bar, `width_m`, D-122 `NAV_LAYER_BREACH` `door.gd:56`), `ladder` (D-145 free climb,
  `height_m`), `secure_zone`, `escape_zone` van/heli + `arrival_delay_s`.
- Goods lift: `bag_lift` (3 landings, 2 bags, `travel_s` 8) plus DB's dead-lift/breaker mission pattern
  (`dockside_burn_mission.gd:233`) and `asset.lift_power` (`goods_lift` → `lift_powered`). Group name matches the doc.
- HeistMission (`systems/heist/heist_mission.gd`): `police_delay_s` (QC-35, :47, set 0 = police at once), `schedule_at`,
  `start_timer`, `spawn_guards` (marshal), `update_objective_data` (`{opened}/{total}`), `say(…, &"reyes")` (D-141.4),
  `spawn_loot`, `activate_escape`, `set_sniper_perches_open`, `rare_effects`, `has_asset`, `crew_spawn_tag`, `variant`,
  `civilians_leave(exit_tag)` (:415).
- VariantResolver: every row of the doc's variable table fits (pick-N, `difficulty_add`, per-difficulty weights,
  `requires`, `force_if`, rare `min_difficulty`; heist_map §5).
- Director/AI: L1.4 spawn rule (`min_crew_distance_m` 15, `director_tweak.gd:32`), `breach_only` (`assault_director.gd:54`),
  sniper perches, Brandt/Aegis, Phantom `vent` layer (`phantom_brain.gd:6`) with DB's culvert nav-link precedent
  (`dockside_burn_layout.gd:867-912`) for the storm drain, `RappelLinks` one-way + chained islands + police spawns on
  islands (`rappel_links.gd`, heist_map v1.3, `test_of_a5_roof_rappel.gd`) for the Skyway (most of QC-89), assault events
  (`assault_event_scheduler.gd`, `events/assault_heli.gd`, `world/heists/shared/assault_markers.gd`), `CivilianRoute`
  (OF-A4, `civilian_brain.gd:26`) for pedestrian loops, casing/PUBLIC/RESTRICTED, hostage trades, AI "in the van" (L6.1).
- OOB (`systems/heist/out_of_bounds_system.gd`), preplan spawn tags, `asset.thermite_drop`, `asset.sniper_position`.
- Map helpers (C): `world/heists/shared/door_nav_clearance.gd`, `npc_seat_spawns.gd`, `escape_van_marker.tscn`; the OF
  generator chain (`of_builder_base.gd` ← `of_shell.gd` ← `of_gameplay.gd` ← `build_greybox.gd`, preloads OF layout:
  copy-adapt, not shared), `of_gameplay.gd _nav_thick`; ND `_palisade` (`night_deposit/greybox/build_greybox.gd:650`),
  DB/SL railings and parapet copings, OF/SL/GN skyline facades (`of_skyline.gd`, `sl_skyline.gd`).
- Levelcheck: bounds, reachability `--variants=all`, walkthrough (3×, `walkthrough.gd:9`), hide_los, bag_line, slopes,
  scale/stair chains, perf (D-146, `perf_d146` meta), viewmodel_lit, variety, density.
- Audio: `cue.burn_warning`, `cue.door_breach`, `cue.escape_arrive_van/heli`, `cue.phantom_hum/charge`, c4 sfx,
  `amb_city_afternoon` (OF).

**Partial (exists, needs extension):**
- **C4 item (A5-03, A + B):** spending and detonation exist; **nothing grants `item.c4`**. Only `keycard_pickup` calls
  `add_item` (`keycard_pickup.gd:152`); no `item_pickup` prefab, no preplan item drop kind (`PreplanAssets.register_drop`
  has no c4 kind), no HUD count (B). `asset.c4_drop` waits on it (D-141.3).
- **burn_point (QC-81, A):** thermite bag delivery exists; no `target: NodePath` → `open_by_device()`, and the fire volume
  is always built (`burn_point.gd:27,101,137`; "ZERO = none" not implemented).
- **Lockdown (A):** no saw multiplier anywhere (`lockdown_saw_mult` absent).
- **Director cap share (QC-83c, A):** only cartel gunmen are subtracted from the police cap (`assault_director.gd:224-228`);
  convoy units are not.
- **Civilians (QC-88, A):** loud = flee from the nearest crew member, then cower (`civilian_brain.gd:437-462`); no flee to
  a `civ_flee` exit and despawn. Panic calls need a phone / alarm / call point (`civilian_targets.gd:23` CALL_POINT_GROUP);
  no "mobile phone" call in place. Workaround: call-point markers on the sidewalks (map).
- **Wrecker on vehicle-wide spawns only (QC-89, A):** `SpawnGroupDef` filters by phase/faction, not by spawn tag.
- **NPC path queries (A):** on trunk, `NavigationAgent3D` (npc_motor) and `map_get_path` (`assault_director.gd:970`,
  `crew_ai_brain.gd:1022`, `civilian_brain.gd:958`, `civilian_targets.gd:239`) still use Godot's 4096-polygon cap. A's fix
  is on `env/a-core` only (ffc264d4, `game/systems/ai/nav/nav_path.gd`, `MAX_POLYGONS = 0`), not yet merged.
- **Escape van (A):** `escape_zone` hides then shows the vehicle (`escape_zone.gd:9-13`); the doc's "drives in through the
  entrance" is cosmetic and would need A5-02.
- **TacticalPoint (A):** no enabled flag (`contracts/map/tactical_point.gd`), so per-layout COVER (children of the
  `ConvoyLayout` sets) cannot be switched at runtime.
- **Levelcheck (C):** `--variants=all` iterates VariantSlots only; the four convoy layouts as pseudo-variants (QC-87c)
  are not built. A ramp-only floor (QC-87b): no rule in `lc_check_scale.gd` fails it (the chain check is stairs-only);
  confirm at G1.
- **Anim (D):** the RT clips are mapped but absent from `tools/blender/characters/anim_humanoid.py` (`sit_vehicle`,
  `vehicle_exit_l/_r`, `sit_eat`, `cook_stove`); `radio_call`, `phone_call`, `walk_text` exist.
- **Cast tags (D/A):** no look or tag for the diner cook and waitress (`staff_diner`), the attendant (`staff_booth`), the
  escorts (`convoy_lead`, `convoy_rear`); escorts may fall back to the EnemyDef look (check, D-103 §3b.1).
- **Prefab visuals (C):** car/van generators have fixed paint (`exterior.py _car`, `prefab_visuals.py _van`); the neon
  generator hard-codes "VOSSBERG" (`exterior.py _neon`). All three need parameters (§3c).

**Missing:**
- **A5-01 `armored_truck`**, **A5-02 `convoy_vehicle`** (+ the `ConvoyLayout` sets and the mixer move), QC-83
  `HeistMission.raise_alarm(reason)` (only `StealthDirector.raise_alarm`, `stealth_director.gd:108`), `spawn_units(…,
  seated, vehicle)` + dismount, convoy detection → `&"ambush"` instead of a pager, QC-88 `civ_flee` exits.
- Map: no `game/world/heists/rolling_thunder/`; no plan scripts (`tools/levelcheck/plans/rolling_thunder_*`: the doc says
  the site plan "comes from" `rolling_thunder_site_ascii.py`, which does not exist); def, variants, mission, blueprint.
- 15 of the 26 kits the room list names (§3c). New props/vehicles (§3c). Assault events (none in the doc).
- B (per its prep doc): VO text (0 of the doc's 42 lines), briefing steps, preplan/room labels (D-141.5, after G1), achievements,
  briefing intel + blueprint (need the map), `asset.c4_drop`, cue ids for audio_cues v1.4 (QC-85).
- Look/audio (C): music `rolling_thunder` stems, 3–4 ambiences, 5 cues, `lut_rolling_thunder`, style-guide row.

**Wrong (doc vs later rulings or current contracts):**
1. **D-141.1:** HeistDef section says base_payout **$85,000**; the ruling and the test pin **$30,000**.
2. **next_heist.md §7 (D-104) doors on routes ≥ 1.0 m:** the legend gives personnel doors **0.9 m** (stair-A street door,
   lobby doors, CP fire door, diner side door, R fire exit, cabins, yard). Raise every route door to ≥ 1.0 m.
3. **heist_map v1.4 / D-121:** "navmesh obstacles (carved, QC-82)" after the stop. The contract allows no runtime rebake,
   and the layout (clean vs crash) is only known at the stop. Needs a pre-baked scheme (QC-RT1).
4. **D-146 (+ add. 6):** the budget table has only "draw calls ≤ 2,500"; it needs total ≤ 4,000 incl. shadow passes,
   judged in Forward+ on the GPU box with the Cataclysm cast. Its shadow list (sun, 2 underpass, 1 per deck ×3, diner,
   site mast) is 8, exactly the cap, if one view sees it all.
5. **D-114 §5 / D-115 #6:** no assault events defined (turret van, heli, breach points).
6. **D-142:** no clear/opaque glazing list. Clear: diner shopfronts and U1, the man-gate mesh panel, the car-park mesh
   infill, the rail palisade bars (all `see_through`); Ashby's "dressing glass" stays opaque.
7. **D-122:** the breachable shell doors and gates (car park, diner, site gates, yard gates) must be on
   `NAV_LAYER_BREACH`, not plain ENTRY.
8. **D-138:** the G1 truck placeholder ("a `safe` LARGE inside a static truck mesh + a `drill_point` SAW") is fine only with
   the DrillPoint as the safe's child (PO6-01, one visible saw) and the cargo inside; never a stand-in lock.
9. **D-143.5:** `signal_insider` / `intel_route` should carry the per-heist allow-list (`heists: [rolling_thunder]`).
10. **Unbuildable as written:** the bullion roof-hatch thermite needs the crew on a ~3 m truck roof with no mantle and no
    ladder (QC-RT2).

## 3b. Proposed rulings for the build (for the LEAD; not adopted)
1. **Convoy navigation:** bake the street navmesh per layout for the arm's tiles only (2 layouts per route; the resolver
   deletes the other route's), and enable the matching region pair at the stop on sync nav (D-121). Per-layout COVER needs
   a TacticalPoint enabled flag (A). Avoidance-only obstacles are not acceptable (bots and police walk into trucks).
2. **A5-02 scope:** convoy + mixer drive-in as designed (≤ 8 movers, then static); escape van stays a pop-in.
3. **Bullion hatch:** a fold-down step ladder on the truck's rear (a `ladder` child, usable once loud) up to a 1.0 m
   roof walk, or a ground-level burn_point on the rear doors ("thermite on the lock"). C prefers the ground-level one.
4. **Civilians:** reuse `civilians_leave(&"civ_flee")` at the alarm for the street plus cower for the rest; call points on
   the sidewalks for panic calls. A builds only the despawn-at-exit if `civilians_leave` cannot run in LOUD.
5. **D-147 substitutions** (doc changes, C): street trees → `prop_planter_street`; dumper → `prop_forklift`; jukebox,
   cycle racks, bunting, wheel stops dropped; the stalled bus → a second lorry (tractor + `veh_reefer_trailer`).
6. **Gate for a heist with no stealth win:** the P5 "ghost run" becomes a *clean-setup run* (signals rigged, marshal handled,
   no early alarm, clean stop) followed by the loud bot to escape, 5 seeds (QC-RT4).

## 3c. D-147 reuse-first: catalog cover per RT area
Ids are catalog ids (`game/world/props/prop_catalog.json`, 520 entries; generators in `tools/blender/props/`) or kit ids
(`game/world/kits/*.tres`, scripts `tools/blender/props/_kits*.py`). "Var." = a parametric variant of an existing
generator or kit. Architecture (walls, slabs, stairs, ramps, kerbs, piers, deck) is generator geometry, not a prop.

**Car park (CP-G, CP-2, CP-R, STA/STB, LF, AB, CWC, CPL, X6)**
| Area | Covered by (reuse) | Genuinely new (justification) |
|---|---|---|
| CP-G / CP-2 decks | `veh_car_sedan_*` ×3 (MultiMesh), `prop_led_batten_cold`, `prop_fire_extinguisher`, `prop_exit_sign`, `arch_column_sq40_*`; var. `_car` gains paints for 12–18 cars per deck | kit `car_park_deck` (no parking kit); `prop_car_park_barrier` (barrier arm + height bar variants, also the 4.4 m underpass bar: no road barrier in the catalog) |
| CP-R roof | kit var. `car_park_roof` ← `car_park_deck`; `prop_street_lamp` (columns), `veh_heli_escape` | heli-pad marking (texgen decal) |
| STA/STB, head houses | `arch_stair_u_f350`, `prop_door_single_steel_t20`, `prop_exit_sign` | — |
| LF goods lift | `bag_lift` + `prop_cash_lift_car_w240`, `prop_lift_breaker` (breaker in CPL) | — |
| AB booth | kit var. `attendant_booth` ← `security_office`; `prop_desk_office`, `prop_monitor`, `prop_kettle`, `prop_radiator_heater`; var. `prop_atm` → pay station (`safe` SMALL visual) | — |
| CWC, CPL | `restroom_single`; kit var. `plant_carpark` ← `plant_room` (`prop_boiler`, `prop_water_tank`, `prop_switchboard`) | — |
| X6 forecourt | `exterior_street`, `prop_bollard_steel`, railing builder (DB/GN `railing`) | — |

**Halfway Diner (DR, K, BC, ST, E, W1/W2, R, SC, OF, U1–U5, J, YD)**
| Area | Covered by (reuse) | Genuinely new (justification) |
|---|---|---|
| DR dining | `prop_counter_sales` (0.9 m), `prop_stool_shop`, `prop_cash_register` (till), `prop_display_case_round` (pie case), `prop_pendant_brass`, `prop_window_shop_w300_h240`, `prop_door_double_glass_t20`; var. `prop_neon_vossberg` → "HALFWAY · OPEN 24 HRS" (text/colour params) | kit `diner_dining`; `prop_diner_booth` (high-back fixed booth with table; nothing seats `sit_eat`/`cower_seated` in pairs) |
| K kitchen | `prop_packing_table_steel` (prep), `prop_fridge`, `prop_microwave`, `prop_bin_kitchen`, `prop_door_slide_coldstore_w240_h360` (walk-in, dressing), `prop_wall_cabinet` | kit `kitchen_commercial`; `prop_cookline` (griddle/fryer/hood modules: no cooking appliance exists; the cook needs it) |
| BC, R, ST, E, W1/W2, U4, J, U2, U3, U5, OF | `corridor_service`, `storage_receiving`, `electrical_closet`, `restroom_single`, `janitor_closet`, `storage_archive`, `break_room`, `office_manager` (+ `prop_safe_wall_small`) | — |
| U1 function room | `prop_table_break`, `prop_chair_break`, `prop_bar_lounge_w300`, `prop_window_shop_w300_h240` | kit `function_room` (assembled from existing props) |
| YD yard | kit var. `exterior_yard_small` ← `exterior_alley`; `prop_dumpster` (bins = `body_container`), `prop_crate_wood`, `prop_ibc_tote` (waste oil), `prop_chair_break`, `prop_ashtray_stand` | — |

**Tanner's Reach site (C1–C4, MG, FG, F1, X4)**
| Area | Covered by (reuse) | Genuinely new (justification) |
|---|---|---|
| C1 site office | kit var. `site_office` ← `office_small`; `prop_plan_chest`, `prop_whiteboard`, `prop_kettle`, `prop_coat_rail`, `prop_cash_stack` (petty cash) | — |
| C2 welfare, C3 WC | `break_room`; kit var. `site_wc` ← `restroom_multi` (`prop_toilet`, `prop_basin_pedestal`) | — |
| C4 tool store | kit var. `site_tool_store` ← `storage_supplies`; `prop_tool_wall`, `prop_gas_cylinders`, `prop_shelving_parts`, `prop_loot_thermite_drum` | — |
| Cabin shells | builder boxes + `prop_window_w100_h60_frosted`, `prop_door_single_steel_t04` | material `steel_cabin` (texgen; corrugated cabin skin) |
| MG magazine | builder steel box, `prop_door_single_steel_t04`, `prop_padlock_brass` | `prop_c4_box` (the `item_pickup` visual; no charge box exists, A5-03 needs one) |
| FG / F1 frame | `arch_column_sq40_h350`, var. `prop_pallet_loaded` → block pallet, `prop_forklift` (for the dumper), `prop_skip` (var.: `body_container` nodes, fit unverified) | kits `site_frame_ground`, `site_frame_slab`; `prop_scaffold` (stair-tower cladding, tube guard rail + toe board + mesh; also F1 edge protection: no scaffold in the catalog); `prop_site_clutter` (formwork stack, rebar bundle, mortar mixer: one generator) |
| X4 yard, hoarding | `prop_mast_sodium` (masts; var. with a `prop_security_camera_wall` mount), `prop_beacon_hazard`, `prop_traffic_cone`, `prop_barrier_roadworks` | kit `exterior_site`; material `plywood_painted` + hoarding graphic (texgen); `prop_rt_tower_crane` (landmark 3; `veh_gantry_crane` is a quay gantry) |
| Controller X | var. `prop_lift_breaker` → street cabinet (`hack_terminal` visual, door for the padlock) | — |

**Streets, underpass, plaza, rail (X1, X2, X3, X5), closures, neighbours**
| Area | Covered by (reuse) | Genuinely new (justification) |
|---|---|---|
| X1 Orchard / junction / Tannery W | `exterior_street`, `prop_street_lamp`, `prop_bin_street`, `prop_of_news_kiosk`, `veh_car_sedan_*`, `prop_bollard_*`; materials `asphalt`, `concrete`, `metal_painted` (Skyway green), `steel_plate_riveted`; var. `prop_led_linear` → sodium tubes | `prop_traffic_signal` (heads + gantry with red/amber/green states; a gameplay read for `[signals]`; S2 rail gantry is a variant); `prop_rt_skyway_girder` (landmark 1 fascia + name band; deck and piers are builder); road-marking decals (texgen) |
| X2 east arm / underpass / cut | kit var. `exterior_underpass` ← `exterior_lane`; `prop_bulkhead_caged`, `prop_led_batten_cold`, ND `_palisade` (rail palisades) | `prop_rail_track` (track panels + sleepers on the bank; dressing, nothing similar); the 4.4 m height bar is a `prop_car_park_barrier` variant (counted once) |
| X3 plaza | `exterior_plaza` (OF kit, same id: bus shelter, benches, kiosk, planters, bollards), `prop_bus_shelter`, `prop_bench_stone`, `prop_planter_street` (for the trees); var. `prop_atm` → ticket machine | `prop_rt_clock_pillar` (landmark 2; reuses the `prop_clock_harbor` face code on a 6 m cast-iron column) |
| X5 rail lane, P_NE | `exterior_lane` (DB), var. `veh_van_secure` → rail maintenance van, `prop_door_double_grille_t20` (palisade gate) | — |
| Closures | `prop_barrier_jersey` (water-filled), `prop_barrier_roadworks`, `prop_beacon_hazard`, `veh_reefer_trailer` / `veh_flatbed_trailer` | `veh_lorry` (tractor unit; rigid TM-truck + arrow-board variant; no road tractor exists) |
| Neighbour facades | skyline/facade builders (`of_skyline.gd`), `arch_wall_ext_shop_*`, `prop_door_shutter_steel_face_w200` (laundromat), `prop_door_roller_steel_w360_h450` (tyres), `brick_red` | — |

**Convoy, escapes, gameplay visuals**
| Area | Covered by (reuse) | Genuinely new (justification) |
|---|---|---|
| Escorts, scout car | var. `_car`: police patrol car (livery + light bar), TAC SUV (height/length params), Vaultline scout car | — |
| Trucks | `prop_saw_device`, `prop_cash_bags`, `prop_cash_pallet`, `prop_of_gold_skid`, `prop_of_gold_bars`, `prop_safe_wall_small` (cab safe) | `veh_armored_truck` (cash 7.5 m / bullion 9 m with `RoofHatch`; A5-01's visual slots; no armoured truck exists) + Vaultline livery material |
| Ram truck | — | `veh_mixer_truck` (Reyes's mixer: arena cover + the ram) |
| Escapes E1–E3, assault | `veh_van_secure` (var. council van for E2), `escape_van_marker.tscn`, `veh_heli_escape`, `prop_secure_*`, `prop_turret_van`, `prop_police_helicopter`, `prop_breach_window` | — |
| Look / audio | `amb_city_afternoon` (var. remix → `amb_skyway_street`), the cues in §3 | `amb_underpass`, `amb_diner`, `amb_site`; 5 cues (`convoy_approach`, `convoy_brake`, `mixer_ram`, `signal_click`, `truck_doors_open`); music stems; `lut_rolling_thunder` |

**Totals.** Kits: 11 reused as-is, 8 kit variants, 7 new (`car_park_deck`, `diner_dining`, `kitchen_commercial`,
`function_room`, `site_frame_ground`, `site_frame_slab`, `exterior_site`; `exterior_plaza` is reused under its OF id).
Catalog/arch ids: **94 reused** (88 as-is, 6 only through a variant), **10 generator variants** (`_car`, `_van`, `_neon`,
`prop_atm`, `prop_lift_breaker`, `prop_pallet_loaded`, `prop_led_linear`, `prop_mast_sodium`, `prop_skip`, and
`prop_ladder_steel_h360_g00` → h350 if the 3.6 m does not fit), and **14 new generators**: `veh_armored_truck`, `veh_mixer_truck`, `veh_lorry`,
`prop_traffic_signal`, `prop_rt_skyway_girder`, `prop_rt_clock_pillar`, `prop_rt_tower_crane`, `prop_diner_booth`,
`prop_cookline`, `prop_scaffold`, `prop_site_clutter`, `prop_c4_box`, `prop_car_park_barrier`, `prop_rail_track`.
Materials/decals new: 6 (`plywood_painted` + graphic, `steel_cabin`, Vaultline livery, road markings, bay lines, heli pad).
Audio/look new: 3 ambiences, 5 cues, music, LUT. Dropped by D-147 (§3b.5): bus, trees, dumper, jukebox, cycle racks,
bunting, wheel stops.

## 4. Rules the build must satisfy (OF §4, carried over)
- Every objective carries `marker_tags` (ui_hud 1.8), the convoy marker included (it moves until the stop: B mocks it).
- Every spawn tag maps in `heist_tag_characters.rolling_thunder` (no capsules, PO-5.7): add `staff_diner`, `staff_booth`,
  `convoy_lead`, `convoy_rear`; check the shared map does not win.
- Key lights `viewmodel_lit`; ≤ 8 lights per 6 m tile (D-112); `perf_d146` on from G1; D-146 judged on the GPU box.
- Director caps per crew (D-099), Routine/Tense escorts carry no armour (D-145 §3: patrol cars only, as the doc has).
- Bags per D-102: cash MEDIUM (×0.75, no sprint, 4 m throw), gold HEAVY (×0.5, 2 m throw), bonds LIGHT; thermite is a tool.
- Saw jams per D-114 §2 (none in the first/last 10 %); saw noise is a stimulus, never an alarm by itself (D-114 §1).
- D-141.2: RT is exempt from D-130 §1 / D-140; pager cap 4, civilians 6/9/12 + `rush_hour` (≤ 22, D-141 add. QC-h).
- Every written VO line is said (D-117 §6); briefing via keys + objective list (D-117 §4/§5); Reyes on `vo.reyes.*`.
- No soft lock (D-093): the placed saw is always available, so trucks always open; the thermite bag respawns if lost
  (`spawn_loot(…, respawn = true)`); a dead lift has the breaker and the ramps.
- D-121: convoy movers server-authoritative; layout nav changes on sync nav; the crash is scripted, never physics.
- Counts against the doc: COVER ~70 per layout, `civilians` 6/9/12, 4 holdouts, 6 police spawn groups, 13 preplan points.
- `validate_level` PASS + PO-3 snag probe 0 + P walk with no STUCK before G2; loud e2e through ESCAPE on ≥ 3 seeds per
  stop type (clean, crash, early alarm).

## 5. Staffing
As OF (D-129): C map/art/audio/levelcheck; A prefabs, director/civilian hooks, mission (A co-owns `game/world/heists/**`);
B values (QB-2: B sends the values block, C's generator writes the `.tres`), strings, VO, UI; D clips and looks; P
real-input verification. The convoy systems (RT-A2..A5) are the critical path.

## 6. Work breakdown (proposed; starts at the §2 gate except RT-L1/RT-C0). RT-A1/RT-D1 are the shipped groundwork ids.
| Id | Owner | Task | Size |
|---|---|---|---|
| RT-L1 | LEAD | Write D-147/D-148; adopt §3b; roadmap rows (A5-04.., RT C rows); settle size M/L; `docs/process` ownership of this file | S |
| RT-C0 | C | Doc fixes (§3 Wrong 1-10, §3b once ruled): payout, doors ≥ 1.0 m, D-146 budget table, D-142 glazing list, D-122 breach layer, assault events (turret van on Tannery W, heli over the junction span, breach points on the car park and diner), substitutions, hatch access | S |
| RT-C1 | C | Plan scripts `tools/levelcheck/plans/rolling_thunder_{site_ascii,floors_ascii,slots,content,geometry}.py` (`--check`: rooms tile, doors on walls, stair/ramp arithmetic) + `rolling_thunder_emit_layout.py` → greybox generator `game/world/heists/rolling_thunder/greybox/` (copy-adapt the OF chain) → **G1**: 4 floor levels, all contract nodes, the 18 variables (slot groups + scalars) + 8 rare events, 4 `ConvoyLayout` sets (placeholders `TODO(A5-01/02/03)`, `TODO(QC-81)`), 4 holdouts, 6 police groups + entries, perches S1–S4, 13 preplan points, review cams, `door_nav_clearance`, `_nav_thick`; `validate_level --stage=greybox --variants=all`; walkthrough; nav polygon report | L |
| RT-C1b | C | Levelcheck: convoy layouts as pseudo-variants (QC-87c) in reachability + walkthrough; ramp-only floor confirmed (QC-87b); `test_rt_loud_nav_targets.gd` (OF clone, per layout); RT in `test_door_clearance_maps.gd` | M |
| RT-C2 | C | **G2**: 14 new generators, 6 materials, 7 new + 8 variant kits, 4 landmarks, daylight (sun 245°/9° 3800 K, dust haze), GI/probes/occluders, 28 review shots, music stems + 3 ambiences + 5 cues, LUT; `validate_level` final; D-146 on the GPU box | L |
| RT-A2 | A | A5-01 `armored_truck` (Safe LARGE composition, `G.SAW_TARGET`, `charges_required` 4, `lockdown()` ×1.5, cab doors, cargo on open, visual nodes) + QC-81 `burn_point.target` and no-fire volume; tests | M |
| RT-A3 | A (B) | A5-03 rest: `item_pickup` (generalised keycard_pickup), preplan item drop kind (`item.c4`, `params.count`); B: HUD `item.c4` count, `asset.c4_drop`; tests | S-M |
| RT-A4 | A | A5-02 `convoy_vehicle` (Path3D mover, braking, `vehicle_stopped`, seats, replicated) + layout switch per QC-RT1 (nav region pair, TacticalPoint enable); tests | L |
| RT-A5 | A | QC-83: `raise_alarm(reason)`, `spawn_units(enemy, count, tag, seated, vehicle)` + dismount, convoy units in the director cap (generalise the cartel rule), detection → ambush; QC-88/89 leftovers (§3b.4, `wrecker_ok`); tests | M |
| RT-A6 | A | `rolling_thunder_mission.gd`: setup clock, marshal, signals, early alarm, clean/crash stop, trucks, lift, 3 escapes, 8 rare events, every VO line, assault event rows; e2e loud ×3 seeds per stop type + the clean-setup run | L |
| RT-B1 | B | Values block (QB-2 shape: def, variant rows, preplanning incl. allow-list), ~42 VO texts (9 Reyes, 33 Mercer), briefing steps, labels (after G1, D-141.5), achievements, intel + blueprint, cue ids to the LEAD (audio_cues v1.4) | M |
| RT-D2 | D | Clips `sit_vehicle`, `vehicle_exit_l/_r`, `sit_eat`, `cook_stove`; diner cook + waitress looks; tag rows for staff/escorts; cower placements (characters v1.9) | M |
| RT-P1 | P | Windowed real-input pass on G1 (§7 tests, setup timing from each spawn under D-128 fills, hauls under D-102), then on G2; snag probe 0 | M |

Order: OF done check (incl. `rc_burn_close`) → RT-L1/C0 now (paper) → at the gate RT-A2..A5 and RT-C1 in parallel (each A
API with a unit test before the map needs it; C's greybox uses the placeholders) → RT-C1b → RT-A6/B1 on the greybox →
**G1** (validate greybox PASS incl. layouts, walkthrough, snag 0, P no STUCK, lead review) → RT-C2/D2 → **G2** (validate
final, shots, D-146 on the GPU box, lead review) → P on G2 → **final**: D-115-style done check + roadmap P5 (G3, the
clean-setup run and the loud bot on 5 seeds).

## 7. G1 traversal requirements (player r 0.35, stand 1.8 / crouch 1.2, step 0.35, slope 45°, apex 1.08 m (HEAVY 0.27),
## D-145 free-climb ladders, no bags on ladders, no mantle; NPC agent r 0.3, climb 0.3, slope 40°)
1. **Levels:** `floor_heights [-5.0, 0.0, 3.5, 7.0]`. Underpass reached by the 32 m road ramp (8.9°) and both sidewalk
   ramps (≥ 3 m wide, no steps); Skyway +9.0, Ashby +14.4 and the rail bank +1.2 police-only and unlisted.
2. **Car park:** stairs A/B 1.2 m, 2 × 10 @ 0.175 / 0.28, collide as ramps, level landings at every door; R1/R2 6.0 m wide,
   8.3°, 3.2 m headroom, thin 1.1 m guards both sides; lift car takes 2 bags with sills ≤ 0.02 m at all 3 landings; the
   1.1 m façade barrier is ≥ 1.1 m above every standable surface within 0.5 m of it (no wheel stop or kerb to jump from).
3. **Roofs and parapets:** car park roof, diner roof and Skyway parapets with copings ≥ 50° (GN §7.5); OOB 0.5 m beyond;
   heli pad 12 × 14 m clear of the lighting columns; head-house doors ≥ 1.0 m; HH stair B always unlocked.
4. **Doors on routes ≥ 1.0 m** (all doc 0.9 m doors raised, §3 Wrong 2); diner front 1.8 m; NPC idle points ≥ 1 m off door
   centrelines; seats within 1 m of `sit`/`sit_eat` spawns (X-5); `door_nav_clearance.add()` in the RT bake.
5. **Throws (MEDIUM 4 m, HEAVY 2 m, 3 pitches):** Orchard sidewalk → west bays over the barrier; Deck 2 south barrier →
   forecourt (3.5 m); forecourt railing → trench toward E2 (2–5 m); F1 edge protection → FG (3.5 m); pad edge → E3 hover
   zone. No ledge, toe board or awning catches a bag. If HEAVY fails over a 1.1 m barrier, the doc says so (no hidden fix).
6. **Site:** hoarding 2.4 m solid with nothing within 0.5 m to jump from; Orchard vehicle gate 5 m (padlock, breachable),
   man-gate ≥ 1.0 m with the 1.2 × 1.0 m mesh panel in `see_through`; Tannery gate passable once the mixer leaves (same
   nav scheme as the convoy, QC-RT1). Scaffold stair 1.2 m, half landing 1.2 m, mesh/rails < 0.2 m widened by `_nav_thick`
   in the bake; ladder 3.5 m with ≥ 1.0 m clear landings top (a gap in the edge protection) and foot; formwork aisles ≥ 1.0 m.
7. **Street:** kerbs ≤ 0.15 m; shelters, benches, kiosk and parked cars leave ≥ 1.0 m sidewalk lanes; every vehicle
   collider true to its visual (hard cover; escort-car glass as soft cover per the doc).
8. **Convoy layouts (4):** every route and objective reachable in each (QC-87c); each truck's rear-step UsePoint, DrillPoint
   and LootAnchor reachable with ≥ 1.0 m clear behind; trench queue leaves ≥ 1.0 m at both walls; crash skews leave
   ≥ 1.0 m gaps; the bullion hatch reachable without a mantle (QC-RT2).
9. **Underpass and rail:** 4.6 m soffit; the 4.4 m height bar clears the tallest truck (◇ ≤ 3.6 m) and the E2 van; cut walls
   5 m; palisades 1.8 m, unclimbable, see-through and bullet-transparent (a movement-only collider: unverified that one
   exists; ask A).
10. **Skyway:** police island (spawn P_SKY + S1); two RAPPEL points at (−13, −26) and (13, 20) within ~0.3 m of the island
    edge at parapet gaps, rays landing on sidewalk navmesh 9.0 m below (heist_map v1.3); no crew route up.
11. **Police-only perches** S2–S4 are sniper islands (exempt from reachability, as OF's `SNIPER_POSTS`); no crew route.
12. **Police entries:** closure ENTRYs with ≥ 4 m vehicle-wide lanes past each closure vehicle (Wrecker, Bulwark); the
    rail-lane gate breachable; building ENTRYs `breach_only`; loud-breachable shell doors on `NAV_LAYER_BREACH` (D-122);
    broken shopfront bays police-only (keep a crew-only collision plane, GN §7.10) unless the LEAD wants a crew route.
13. **Storm drain:** a `vent`-layer NavigationLink3D pair (DB culvert precedent), not a navmesh tunnel.
14. **Escapes:** E1 in the west aisle with ≥ 1.0 m all round; E2 behind a ≥ 4 m lorry gap; E3 reachable step-free from
    both head houses.
15. **Navmesh size:** keep the whole map ≤ 3,500 polygons with the active layout pair (OF 4,165 is the only map over
    Godot's 4096 cap; GN 2,870, DB 2,464; ENV C status r254), report it every regen; A's uncapped `NavPath` (env/a-core,
    not yet on trunk) is the real fix and `test_rt_loud_nav_targets.gd` checks reachability uncapped. Thin colliders under 2 cells (0.2 m) widened in the bake only (`of_gameplay.gd _nav_thick`).
16. **Walkthrough 3×:** only R1 + R2 to the roof is whitelisted (doc). Watch the hoarding detours (plaza → magazine), the
    rail lane (reached only through the CP fire door: make it crew-openable from inside or whitelist), plaza → U2.
17. **D-146:** main ≤ 2,500, total ≤ 4,000, ≤ 8 shadowed lights in view, Forward+ on the GPU box with the Cataclysm loud
    cast (add. 6). Worst views per the doc (`rc_ext_junction`, `rc_ext_tannery_west`, `rc_sniper_skyway`). Levers in D-146.4
    order; parked cars, columns, lamp posts and barriers as MultiMesh; occluders on the car park, diner, hoarding, Ashby,
    Skyway deck.
**G1 tests (ENV P, windowed real input):** both car-park stairs, R1/R2 and the lift; the site ladder up/down and the scaffold
stair with a bag; each §7.5 throw at 3 pitches; plaza → controller → magazine → H1 masked under the marshal's walk on
`convoy_eta_s` 150; T1 → E1 and T3 → E2 with a HEAVY bag (east, clean); underpass in/out both ends; Skyway rappel lands;
PO-3 snag probe = 0 on all four layouts.

## 8. Questions for the LEAD / PO
1. **QC-RT1 convoy nav:** per-layout pre-baked nav regions swapped at the stop (§3b.1), or another scheme? Same for the
   mixer and the Tannery gate. Also needs a TacticalPoint enabled flag (A).
2. **QC-RT2 bullion hatch:** truck-rear ladder to the roof, or a ground-level thermite point on the rear doors (§3b.3)?
3. **QC-RT3 size:** M (doc, 15–25 min) or L (`next_heist.md` §1)? It sets the e2e time budgets and D-120 checks.
4. **QC-RT4 P5 gate:** accept the clean-setup run in place of the ghost run for a heist with no stealth win (§3b.6)?
5. **QC-RT5 path cap:** A's uncapped `NavPath` (env/a-core ffc264d4) must reach trunk before RT G1; is C's ≤ 3,500-polygon
   target then an early warning only (C's preference) or a hard G1 rule?
6. **QC-RT6 D-147 substitutions** (§3b.5): OK to change the doc (trees, dumper, bus, jukebox, racks, bunting, wheel stops)?
7. **QC-RT7 civilians:** reuse `civilians_leave` + call points (§3b.4) instead of a new QC-88 system?
8. **QC-RT8 A5-02 scope:** convoy + mixer drive-in, escape van pop-in (§3b.2)? Or the G1 pre-placed convoy permanently?
9. **QC-RT9 PD2 fidelity (no in-repo cite found):** the early-alarm "truck lockdown, saws ×1.5" and the 8 s ambush window
   are original choices; confirm they stay.
10. **QC-RT10 paper scope:** may C write the plan scripts with `--check` before the OF done check (they only verify the G0
    arithmetic), or does that wait for the gate?
11. **QC-RT11:** D-147 and D-148 are not in `decisions.md` yet; this file sits in LEAD-owned `docs/process/` (expect
    `check_ownership.py c` to flag it on merge).

## 9. Open risks
- **Nav size:** an open 184 × 162 m street with three buildings, ~45 parked cars and a carved convoy will likely exceed
  OF's 4,165 polygons (estimate, unverified until G1).
- **D-146 outdoors:** one low sun over the whole map plus the Skyway deck; the sun cascades are the cost to watch. Only the
  GPU box can judge (add. 6).
- **System load on A:** A5-01..03 plus QC-83/88/89 and the layout switch is the largest new-system set of any heist.
- **Movers:** trucks pushing crew/civilians during the drive-in; replication jitter; deterministic stop placement (D-121).
- **Cast budget (D-132):** up to 11 convoy units + police cap + ≤ 22 civilians in one daylight view.
- **Long HEAVY hauls** (E2 ≈ 125 m on `route_north`) with bots on `carry_bag`: pacing for solo + 3 bots (D-145 §2).
- **HEAVY throws over 1.1 m barriers** may fail at 2 m; the holdout bag routes then change.
- **Daylight readability:** first sun-axis LUT and bloom; glare must never blind (doc rule).
- **Art volume:** 14 new generators, 4 of them hero vehicles (20–40k tris each) and 3 landmarks.
- **Shared ownership:** `game/world/heists/**` is co-owned by A (mission) and C (map); agree file splits early (OF pattern).
