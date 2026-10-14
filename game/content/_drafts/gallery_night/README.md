# Gallery Night content drafts (GN-B1)

Status: ENV B content is at its final paths. The **HeistDef and the variant table** wait here in
`content/_drafts/gallery_night/` until ENV A moves them to `game/world/heists/gallery_night/`. Nothing in this
folder is live: `HeistRegistry` discovers heists only under `res://world/heists/`. Design source:
`docs/design/heists/gallery_night.md` (G0, D-075; Build rulings B1–B6, D-103/D-104). Build plan:
`docs/process/next_heist.md` §3/§3b. The lead's answers to the first-pass open questions are applied (see
"Lead rulings applied").

## Files

| File | Path | Owner | State |
|---|---|---|---|
| HeistDef | here → `game/world/heists/gallery_night/gallery_night_def.tres` | **ENV A** (`game/world/heists/**`) | draft; `map_scene` points at the not-yet-built `res://world/heists/gallery_night/gallery_night.tscn` |
| Variant table | here → `game/world/heists/gallery_night/gallery_night_variants.tres` | **ENV A** | draft (heist_map.md §1: `<id>_variants.tres` next to the def, by convention) |
| `loot.painting_study` | `game/content/data/loot/painting_study.tres` | ENV B | landed: $700, LIGHT; `test_p5_catalogue` pins 700 |
| `asset.intel_list`, `asset.intel_sensors` | `game/content/data/preplanning/assets/` | ENV B | landed; **the only place their values live** |
| Blueprint | `game/content/data/preplanning/blueprints/gallery_night.tres` | ENV B | landed; 4 floors, site/room shapes, 11 points. The map's `Preplan` markers replace the points once the map exists. |
| Strings | `game/content/data/strings/strings.csv` | ENV B | landed: briefing, music, objectives (+ `hack_loud`), assets, blueprint labels, doc VO, 26 contact radio lines |
| Voice lines | `game/content/data/voice/lines.tres` | ENV B | landed: 64 entries: 5 briefing, 33 mission, 26 radio |
| Tests | `game/tests/b/test_gn_drafts.gd` (new), `game/tests/b/test_contact_radio.gd` (`DRAFT_HEISTS`) | ENV B | see "Tests" |

## Lead rulings applied
1. **Weights:** Tense uses the Routine weights (the base weights, with no Tense row). Hazardous uses the Brutal+
   weights: `sensor_net`, `laser_pattern` and the `patrons`/`escape_eta_s` scalars have a `2:` row equal to their
   `3:`/`4:`/`5:` rows.
2. **`guard_post`:** `pick 1` + `difficulty_add [0, 0, 1, 2, 3, 3]` gives 1/1/2/3/4/4 picks. `rover_none` has
   weight 0 from Hazardous on (`weights_by_difficulty`), so those picks are always real walkers. At Routine/Tense
   `rover_none` competes 1:1 with the four walkers, so P(none) = 0.2. `test_gn_drafts` checks this on 200 seeds
   per difficulty.
3. **`conservator` before `keycard`:** kept.
4. **`xl_crate/xl_loan`, `admin_pa/pa_late`:** kept. The full list of map slot names is below.
5. **`argus_upgrade` `min_difficulty` 4 (Lethal):** kept, at the top level of the event.
6. **One source of truth:** the def's `preplanning.assets` now **references** library assets and changes only what
   is heist-specific. `asset.intel_list`/`asset.intel_sensors` are `{}` (by id). `inside_keycard`, `body_bag_case_drop`,
   `ammo_bag_drop` and `doctor_bag_drop` change only their `point_ids`. `propped_door` changes `point_ids` and
   `max_count 2`. No library value is restated, so the schema forces no duplication. `test_gn_drafts` fails if a
   def entry ever restates a library value (each override must change the merged field).
7. **`objective.gallery_night.hack_loud`:** this is the loud text of the **same** objective `hack`. When the heist
   goes loud, the mission swaps the label (re-add or update `hack` with label key
   `objective.gallery_night.hack_loud`, 120 s / 2–3 interruptions). There's no separate objective id.
   `test_contact_radio._objective_tags` skips `<tag>_loud` keys whose base tag exists.
8. **Contact radio lines** were drafted on the Glasshouse/Night Deposit pattern (see "Voice lines").
9. **VO entries** were drafted in `lines.tres` (see "Voice lines").
10. **Effect keys for ENV A:** see "Rare-event effect keys".
11. **`small_valuables`:** see "Not data here".

## Map slot names (ENV C / ENV A greybox)
Every group below needs `VariantSlot` nodes (`slot_group`, `slot_id`) with these exact ids. The base weights go
on `VariantSlot.weight`; the table carries only the per-difficulty rows. Rule order (resolver order) is the table
order below.

| # | group | slot ids: base weight | pick |
|---|---|---|---|
| 1 | `centrepiece` | `cp_landing` 0.4, `cp_treasury` 0.35, `cp_store` 0.25 | 1 |
| 2 | `canvas_orchard` | `orchard_calloway` 1, `orchard_benefactors` 1, `orchard_quarantine` 0.7 | 1 |
| 3 | `canvas_widow` | `widow_sallow` 1, `widow_founders` 1, `widow_conservation` 0.7 | 1 |
| 4 | `canvas_saint` | `saint_maritime` 1, `saint_harbour` 1, `saint_store` 0.7 | 1 |
| 5 | `sensor_net` | `sensors_treasury` 0.5, `sensors_upper` 0.35, `sensors_all` 0.15 (Hazardous+ 0.2/0.4/0.4) | 1 |
| 6 | `conservator` | `cons_late` 1, `cons_gone` 1 | 1 |
| 7 | `keycard` | `kc_curator` 1, `kc_security` 0.75, `kc_registrar` 1, `kc_conservator` 1 (only with `cons_late`) | 2 |
| 8 | `code_note` | `code_security_log` 1, `code_curator_planner` 1, `code_admin_postit` 1 | 1 |
| 9 | `guard_post` | `rover_ground` 1, `rover_upper` 1, `rover_basement` 1, `dock_smoker` 1, `rover_none` 1 (an empty slot; 0 from Hazardous) | 1/1/2/3/4/4 |
| 10 | `security_room_staffed` | `sec_staffed` 0.6, `sec_empty` 0.4 (Hazardous 0.65/0.35, Brutal+ 0.75/0.25) | 1 |
| 11 | `camera` | `cam_a` 1, `cam_b` 1, `cam_c` 1 (B6: layout cameras under these slots; C11, C14 outside any slot) | 1 |
| 12 | `laser_pattern` | `lz_static` 0.5, `lz_sweep` 0.2, `lz_timed` 0.3 (Hazardous+ 0.2/0.4/0.4) | 1 |
| 13 | `curator_route` | `curator_hall` 1, `curator_office` 1 | 1 |
| 14 | `court_doors` | `court_doors_open` 1, `court_doors_locked` 1 | 1 |
| 15 | `areaway` | `grate_loose` 1, `grate_padlocked` 1 | 1 |
| 16 | `escape` | `esc_mews` 0.55, `esc_parade` 0.45 | 1 |
| 17 | `xl_crate` | `xl_loan` (any weight; only `late_loan` turns it on) | 0 |
| 18 | `admin_pa` | `pa_late` (any weight; only `late_paperwork` turns it on) | 0 |

**Scalars** (the mission/map read them from the resolved result; no slots): `last_call_s` 480/600/720,
`patrons` 3/5/7/9, `stragglers` 0/1/2, `store_paintings` 4/6/8, `consignment_lockers` 4/6/8, `escape_eta_s`
90/120/150.

**Pre-planning point params** (blueprint and map markers) must name these same slots: `escape/esc_mews`,
`escape/esc_parade`, `keycard/kc_registrar`, `areaway/grate_loose`, `court_doors/court_doors_open`. The spawn tags
are `preplan_spawn_mews` and `preplan_spawn_roof`.

## Rare-event effect keys the mission script must read (ENV A)
`VariantResolver` itself applies only `chance`, the top-level `min_difficulty` and `effects.force_active`.
`gallery_night_mission.gd` must read everything else from `HeistRuntime.variants["rare"]` plus the table:

| event | key | meaning |
|---|---|---|
| `curator_tipsy` | `force_active` {keycard, kc_curator} | (resolver) the curator's card is one of the two cards |
|  | `curator_card_on_bar` (bool) | at last call, move `kc_curator` to a casing-allowed pickup on the GH bar (not on her lanyard) |
| `late_loan` | `force_active` {xl_crate, xl_loan} | (resolver) the LD loan crate slot is active |
|  | `extra_studies` (int, 2) | spawn that many `loot.painting_study` in the `xl_crate` |
| `insurance_inspection` | `timed_spawn` {`after`: `last_call`, `delay_s`: 180, `spawn_tag`: `guard_inspection`} | spawn the inspectors + escorts at LD 180 s after last call (QC-25 hook); they walk to the centrepiece slot and raise the alarm if it is empty |
| `vaultline_early` | `requires` {centrepiece: [cp_landing, cp_treasury]} | **gate:** the event is void unless the active centrepiece is one of these (rare events roll before rules, so the resolver can't check it) |
|  | `timed_spawn` {`at_s`: 720, `spawn_tag`: `guard_vaultline`} | spawn the Vaultline crew at LD at 12:00 elapsed; they move the canvas to `cp_store` (B3; `TODO(QC-57)`) |
| `argus_upgrade` | `force_active` {sensor_net, sensors_all} | (resolver) every hung frame is alarmed |
|  | `extra_hack_interruptions` (int, 1) | the stealth hack gets +1 interruption (1–2 → 2–3) |
| `late_paperwork` | `force_active` {admin_pa, pa_late} | (resolver) the PA slot (`civ_admin` spawn + desk) is active |

`timed_spawn` sub-keys: `spawn_tag` (always); exactly one of `at_s` (heist clock) or `after` (a mission moment,
here `last_call`) + `delay_s`. Use `HeistRuntime.SCRIPTED_SPAWN_TAG` on those GUARD SpawnPoints so they don't spawn
at load.

## Objective table for the mission script (not expressible in HeistDef)
`marker_tags` per Build rulings B5. Label key = `objective.gallery_night.<id>`.

| objective id | marker_tags | notes |
|---|---|---|
| `casing` | `casing_hall` | optional |
| `find_canvases` | starts `[]`, grows per found slot; data `found` | label uses `{found}` |
| `keycard` | `keycard` | |
| `server_code` | `code_note` | |
| `hack` | `hack` | stealth label `…hack`; **on going loud the mission swaps the label to `…hack_loud`** |
| `treasury` | `treasury_door` | |
| `art_store` | `vault_reader` | |
| `centrepiece` | `canvas_lantern` | |
| `canvases` | `canvas_orchard`, `canvas_widow`, `canvas_saint` | |
| `secure` | `secure_mews` / `secure_parade` | `{count}/{total}`; Lantern Bearer + 1 list canvas; studies never count |
| `extras`, `lockers`, `curator_safe` | `lockers`, `curator_safe` | optional |
| `lockdown` | `shutter` | loud, completes at once |
| `server_door` | `server_door` | loud |
| `vault_drill` | `vault_drill` | loud |
| `escape_wait`, `escape` | `escape_mews` / `escape_parade` | |

Fail reasons (B3): `HeistRuntime.FAIL_ALL_CUSTODY` (`&"all_custody"`) and `FAIL_ABORT` (`&"abort"`) only. Never
`stealth_only_alarm`. `mode` stays STEALTH_OR_LOUD (the default).

## Voice lines (`lines.tres`)
- **Briefing** (event `briefing`, `heist gallery_night`, priority 90): `vo.vance.briefing_gallery_night_1..3`
  (order 1–3) and `vo.mercer.briefing_gallery_night_1..2` (order 100–101), like Dockside Burn.
- **Mission** (event `mission`, priority 90, no `heist` key, like Glasshouse/Dockside): every VO id the doc lists:
  3 Vance (`contact_intro`, `centrepiece`, `payday`) and 30 Mercer (`intro`, `canvas_found_{saint,widow,orchard,lantern}`,
  `last_call_soon`, `last_call`, `guests_gone`, `keycard`, `code_found`, `sensors_warning`, `hack_started`,
  `hack_interrupted`, `sensors_off`, `lasers`, `treasury_open`, `art_store_open`, `curator_keycard`, `inspectors`,
  `vaultline`, `last_pager` `{answered}`, `lockdown`, `shutters_up`, `vault_drill`, `drill_jam`,
  `required_secured`, `van_eta` `{seconds}`, `limo_eta` `{seconds}`, `sniper_hotel`, `escape`).
- **Contact radio** (Vance, `heist gallery_night`, ContactRadio pattern): `radio.objective_done` for all 18 doc
  objectives, `radio.objective_new` for `canvases`, `vault_drill`, `escape_wait` and `escape`, plus
  `radio.escape_available`, `radio.escape`, and `radio.loot_secured` (Lantern Bearer, study, generic).
  Priorities come from RadioTweak (50/45/70/75/20). The loot lines have a 30 s cooldown.

**Event names the doc doesn't define.** The doc lists VO ids only, never `VoiceLineTable` events. Every line
therefore uses an existing event: `briefing`, `mission` (played by id from the mission script's `say()`, D-048) or a
`radio.*` event. No new event name was needed. The doc also leaves undefined the **mission moment** that plays each
`mission` line. That is ENV A's call when writing the script. The obvious triggers: `last_call_soon` at
`last_call_s` − 60, `last_call`/`guests_gone` at the last-call flip and at +60 s, `canvas_found_*` on the
`[find_canvases]` area entry, `inspectors`/`vaultline` on the timed spawns, `sniper_hotel` on the first S1 Longshot
spawn, `van_eta`/`limo_eta` by the active `escape` slot.

## Tests
- **`game/tests/b/test_gn_drafts.gd` (new).** It loads the def/table from `world/heists/gallery_night/` once they
  exist there, else from this folder. It checks:
  - the drafts load;
  - no def preplanning entry restates a library value, and `intel_*` are referenced by id only;
  - the merge is clean (`validate()` on every asset, 5 favors);
  - guard picks are 1/1/2/3/4/4 with `rover_none` ~20% at Routine/Tense and never from Hazardous;
  - Hazardous weights equal Brutal+ and Tense has no row;
  - two keycards, `kc_conservator` only with `cons_late`, and the rare-event `min_difficulty` values at the top level.
- **`game/tests/b/test_contact_radio.gd`.** `DRAFT_HEISTS = {gallery_night: vance}` joins the radio-line coverage and
  well-formedness checks, but not `test_each_heist_uses_its_contact`: `contact_for` can't resolve Vance until the def
  is registered. **When ENV A lands the def, move `gallery_night` from `DRAFT_HEISTS` to `HEISTS`.**
  `_objective_tags` ignores `<tag>_loud` text variants.

## Not data here
- **`small_valuables`** (CO safe ×3, TR vitrines ×2, consignment lockers 4–8, CK cash box, GS till) has **no
  LootDef**. Per the doc, the values live on the map prefabs (`small_loot` / `deposit_box` / `display_case` /
  `safe` params, ◇ $600–2,400 per item), set by whoever builds the greybox (ENV C, else ENV A).
- HeistDef has no field for marker_tags, fail reasons, floor heights or difficulty data. These live in the
  mission script, on the HeistMap root (`floor_heights [-4.2, 0.0, 5.4, 9.0]`,
  `floor_names ["Basement", "Ground", "Upper", "Roof"]`) and in the variant table. `escape_options` is `[van]`
  (the limo is a van-type escape, D-075 ruling 8).
- Engine features QC-51..QC-55 and QC-57 (zone flip, carried keycard, laser `set_enabled`, frame-sensor alarm
  groups, hack reconfigure, NPC-carried bag) are ENV A system work. The table only rolls the variables.

## Ruled by the lead (2026-10-14)
1. **Body bag weight** stays HEAVY (PD2 `being` carry type: x0.5 speed / jump, no run, x0.5 throw); the
   next_heist.md line saying MEDIUM was the error and is fixed on trunk. No data change.
2. **Glasshouse `drill_relock`** (min_difficulty inside `effects`, ignored by the resolver): routed to ENV A.
3. **Music name** "Laylight": approved.
