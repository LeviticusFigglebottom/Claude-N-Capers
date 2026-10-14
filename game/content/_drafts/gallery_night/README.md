# Gallery Night content drafts (GN-B1 prep)

Status: **DRAFT**, paper only while the content freeze (D-082) is on. Nothing here is live: `HeistRegistry`
discovers heists only under `res://world/heists/`, `ContentDB` reads only `res://content/data/`, and `PreplanBoard`
reads only `content/data/preplanning/`. Design source: `docs/design/heists/gallery_night.md` (G0, D-075; Build
rulings B1-B6, D-103/D-104) and `docs/process/next_heist.md` §3/§3b.

Every draft parses (`ResourceLoader.load`) and was checked headless: the HeistDef preplanning merges cleanly
against the real asset library (`PreplanAssetDef.validate()` passes for every merged asset), the variant table
resolves at all six difficulties with stand-in VariantSlots (`kc_conservator` never rolls without `cons_late`), and
every string key the drafts reference is in `strings.csv` or `strings_gallery_night.csv`.

## Files and where they go

| Draft | Final path | Owner of the destination | Notes |
|---|---|---|---|
| `gallery_night_def.tres` | `game/world/heists/gallery_night/gallery_night_def.tres` | **ENV A** (`game/world/heists/**`; ENV C if re-activated) | HeistDef. `map_scene` already points at `res://world/heists/gallery_night/gallery_night.tscn` (doesn't exist yet). `HeistRegistry` finds it by convention once it's in that folder. |
| `gallery_night_variants.tres` | `game/world/heists/gallery_night/gallery_night_variants.tres` | **ENV A** | HeistVariantTable. Contract heist_map.md §1: `<id>_variants.tres` next to the def. No path field links them (convention only). |
| `painting_study.tres` | `game/content/data/loot/painting_study.tres` (replaces the existing file) | **ENV B** | Only `value` changes: 1100 → **700** (D-081/D-103 §3b.5). Weight stays LIGHT (0). **`game/tests/b/test_p5_catalogue.gd:18` pins 1100**, so change it to 700 in the same commit when the freeze lifts. |
| `intel_list.tres` | `game/content/data/preplanning/assets/intel_list.tres` | **ENV B** | New library asset (QC-59): reveals `centrepiece`, `canvas_orchard`, `canvas_widow`, `canvas_saint`. QB-53 hides it on heists that don't have those groups. |
| `intel_sensors.tres` | `game/content/data/preplanning/assets/intel_sensors.tres` | **ENV B** | New library asset (QC-59): reveals `sensor_net`. |
| `gallery_night_blueprint.tres` | `game/content/data/preplanning/blueprints/gallery_night.tres` (new folder, `PreplanBoard.BLUEPRINT_DIR`) | **ENV B** | Drawn schematic: 4 floors (Basement/Ground/Upper/Roof = floor index 0-3 = `HeistMap.floor_heights` order), site and room shapes, all 11 doc points. When the map exists, `PreplanBlueprint.from_map_scene` replaces `points` with the map's `Preplan` Marker3Ds and keeps these shapes. The drafted point positions are approximate, read off the doc's plans. |
| `strings_gallery_night.csv` | rows appended to `game/content/data/strings/strings.csv` | **ENV B** | 107 new keys, header `keys,en` as in strings.csv. None duplicates an existing key. Reused, not duplicated: `heist.gallery_night.name/subtitle/brief`, all five `item.loot.painting_*` name/desc, `item.asset.inside_keycard/propped_door/...`, `ui.preplan.floor.ground/upper`. |

The library assets the HeistDef overrides (`asset.inside_keycard`, `asset.propped_door`, `asset.body_bag_case_drop`,
`asset.ammo_bag_drop`, `asset.doctor_bag_drop`) need no file changes; the def overrides their `point_ids` per heist.
`asset.intel_list` / `asset.intel_sensors` also appear in the def with the doc's full field set. If the library files
above never land, the def entries still create them as heist-only assets. If they do land, the entries are identical
overrides and change nothing.

### Base slot weights for the map's VariantSlots (ENV A/C)
The resolver takes base weights from `VariantSlot.weight` in the map. The table only carries per-difficulty overrides
(`weights_by_difficulty`, the shadow_ledger pattern). Set these weights on the slots:

| group | slot: weight |
|---|---|
| `centrepiece` | `cp_landing` 0.4, `cp_treasury` 0.35, `cp_store` 0.25 |
| `canvas_orchard` | `orchard_calloway` 1, `orchard_benefactors` 1, `orchard_quarantine` 0.7 |
| `canvas_widow` | `widow_sallow` 1, `widow_founders` 1, `widow_conservation` 0.7 |
| `canvas_saint` | `saint_maritime` 1, `saint_harbour` 1, `saint_store` 0.7 |
| `sensor_net` | `sensors_treasury` 0.5, `sensors_upper` 0.35, `sensors_all` 0.15 (Brutal+ 0.2/0.4/0.4 in the table) |
| `keycard` (pick 2) | `kc_curator` 1, `kc_security` 0.75, `kc_registrar` 1, `kc_conservator` 1 |
| `code_note` | all 1 |
| `guard_post` | all 1, `rover_none` included (P(none) = 0.2 at Routine/Tense; the table zeroes `rover_none` from Hazardous) |
| `security_room_staffed` | `sec_staffed` 0.6, `sec_empty` 0.4 (Hazardous 0.65/0.35, Brutal+ 0.75/0.25 in the table) |
| `camera`, `curator_route`, `conservator`, `court_doors`, `areaway` | all 1 (equal) |
| `laser_pattern` | `lz_static` 0.5, `lz_sweep` 0.2, `lz_timed` 0.3 (Brutal+ 0.2/0.4/0.4 in the table) |
| `escape` | `esc_mews` 0.55, `esc_parade` 0.45 |
| `xl_crate`, `admin_pa` | one slot each (`xl_loan`, `pa_late`), weight irrelevant: pick 0, only a rare event's `force_active` turns it on |

Scalars (`last_call_s`, `patrons`, `stragglers`, `store_paintings`, `consignment_lockers`, `escape_eta_s`) are fully
in the table.

### Objective table for the mission script (not expressible in HeistDef)
`marker_tags` per Build rulings B5. String key = `objective.gallery_night.<id>`.

| objective id | marker_tags | notes |
|---|---|---|
| `casing` | `casing_hall` | optional |
| `find_canvases` | starts `[]`, grows per found slot; data `found` | string uses `{found}` |
| `keycard` | `keycard` | |
| `server_code` | `code_note` | |
| `hack` | `hack` | loud text: use key `objective.gallery_night.hack_loud` (same id, extra string) |
| `treasury` | `treasury_door` | |
| `art_store` | `vault_reader` | |
| `centrepiece` | `canvas_lantern` | |
| `canvases` | `canvas_orchard`, `canvas_widow`, `canvas_saint` | |
| `secure` | `secure_mews` / `secure_parade` | string uses `{count}/{total}`; Lantern Bearer + 1 list canvas, studies never count |
| `extras`, `lockers`, `curator_safe` | `lockers`, `curator_safe` | optional |
| `lockdown` | `shutter` | loud, completes at once |
| `server_door` | `server_door` | loud |
| `vault_drill` | `vault_drill` | loud |
| `escape_wait`, `escape` | `escape_mews` / `escape_parade` | |

Fail reasons (B3): `HeistRuntime.FAIL_ALL_CUSTODY` (`&"all_custody"`) and `FAIL_ABORT` (`&"abort"`) only. Never
`stealth_only_alarm`: `mode` stays STEALTH_OR_LOUD (the default, so not written in the .tres).

## What the data classes cannot express (missing fields)

1. **`HeistDef` has no `marker_tags` / per-objective data.** `objectives` is a plain `Array[StringName]`. The
   marker tags, optional flags and loud/stealth split live only in the mission script's `add_objective(...)` calls.
   See the objective table above for `gallery_night_mission.gd` (ENV A).
2. **`HeistDef` has no fail-reason field.** "Custody and abort only" is mission behaviour: never call
   `end_heist(false, &"stealth_only_alarm")`.
3. **`HeistDef` has no difficulty data** (per-difficulty guard counts, operator chance, civilian counts). They are
   expressed in the variant table (`difficulty_add`, `weights_by_difficulty`) plus the map's VariantSlot weights.
   The Titan cameras from Lethal (S8.1) are not table data: the map/mission or a DifficultyDef handles them.
4. **`HeistDef` has no `floor_heights` / `floor_names`.** These are `HeistMap` fields on the map root
   (`[-4.2, 0.0, 5.4, 9.0]`, `["Basement", "Ground", "Upper", "Roof"]`), set by ENV A/C in the .tscn. The blueprint
   draft mirrors them as `floor_names` string keys.
5. **`HeistDef` has no `variants` / `blueprint` path fields.** Both are found by convention (`<id>_variants.tres` next
   to the def, `blueprints/<id>.tres`), so the def references neither file.
6. **`HeistDef.escape_options` can't say "limo".** Both escapes are `&"van"` (D-075 ruling 8: van type, limo
   visual). The two escapes are variant slots (`esc_mews`, `esc_parade`), not escape types.
7. **Rare events can't use `requires`.** `VariantResolver` honours only top-level `chance`, `min_difficulty` and
   `effects.force_active`. `vaultline_early`'s `requires centrepiece: [cp_landing, cp_treasury]` is written as
   `effects.requires`, so **the mission script must check it** (rare events roll before any rule, so the resolver
   could not gate on `centrepiece` even if it read the key). The other effect keys are mission-interpreted
   conventions in the same way: `curator_card_on_bar`, `extra_studies`, `timed_spawn` {`after`/`delay_s`/`at_s`,
   `spawn_tag`}, `extra_hack_interruptions`. Glasshouse/shadow_ledger already use free-form effect keys like this.
8. **Frame sensors, lockdown, last call, NPC-carried keycard and Vaultline bag** (QC-51..QC-55, QC-57) are engine
   features with no data fields yet (`loot_spawn.alarm_on_take`/`alarm_group`, `MapZone` kind flip, `laser_grid.set_enabled`,
   `keycard_reader.set_disabled`, hack reconfigure). The variant table can only roll the variables.
9. **`small_valuables` has no LootDef.** The doc says prefab values (ENV C/A). No draft.
10. **VO lines need `content/data/voice/lines.tres` entries** (`VoiceLineTable`: id, speaker, event, priority,
    cooldown_s, text_key). The CSV holds only the text. The event bindings (which `EventBus` fact or mission call plays
    each line) belong to whoever writes the mission script, so no lines.tres draft is included here.

## Open questions

1. **Tense/Hazardous weights.** The doc gives `patrons`, `sensor_net`, `laser_pattern` and `escape_eta_s` weights
   only for Routine and Brutal+. The draft uses the Routine weights for Tense and Hazardous. Should Hazardous
   interpolate?
2. **Guard count at Tense.** The Variable table says Routine/Tense pick 1 (2 guards with the hall post). The totals
   table says Tense is "1 + 1-2 = 2-3". The draft follows the Variable table (`difficulty_add [0,0,1,2,3,3]`).
3. **Rule order.** `conservator` moved before `keycard`, because `kc_conservator`'s `slot_requires` must reference an
   earlier group (heist_map.md v1.1). Every other rule follows the doc's table order. Does that reordering need a doc
   note?
4. **Optional groups `xl_crate` / `admin_pa`.** These are new group names, invented here for the `late_loan` crate and
   the `late_paperwork` PA (one slot each, `pick 0`, forced by the rare event). The map must create VariantSlots
   `xl_crate/xl_loan` and `admin_pa/pa_late`, or the lead picks other names.
5. **`argus_upgrade` min_difficulty.** The doc says "Lethal" = index 4. Should Cataclysm (5) be the only one? The
   draft uses 4.
6. **The body bag is HEAVY in data, but D-102/B1 say MEDIUM.** `content/data/loot/body_bag.tres` has `weight = 2`
   (HEAVY), and `systems/tweak/loot_tweak.gd` has `body_bag_weight = HEAVY`. That isn't Gallery Night-specific, and
   no draft is made here. The lead should rule on who changes it (the tweak is the effective value).
7. **Glasshouse `drill_relock` puts `min_difficulty` inside `effects`.** The resolver reads it only at the event's
   top level, so the event currently fires at every difficulty. That's not this task's file, but worth a ticket
   (ENV A). The Gallery Night draft puts it at the top level (the shadow_ledger form).
8. **Library vs heist-only intel assets.** Should `asset.intel_list` / `asset.intel_sensors` be library files (as
   drafted, reusable by Ostrander) or only heist entries in the def (the doc's ◇ block)? Library files make them appear
   on the generic `test_heist` board (no variant table means nothing is hidden). Check `game/tests/b/test_preplan*.gd`
   for asset-count assumptions before landing them.
9. **The `hack_loud` key.** The loud hack has a different text, but the objective id `hack` is shared. The draft adds
   `objective.gallery_night.hack_loud` for the mission to pass as the loud label. OK, or does the lead want a separate
   objective id?
10. **Contact radio lines** (`voice.vo.vance.gallery_night_radio_<objective>[_new]`, the ContactRadio pattern used by
    glasshouse/night_deposit) are not drafted. They are only the doc-listed VO ids. Write them with the lines.tres pass?
11. **Music name** `Laylight` (the obvious "Last Call" is already `music.last_call.name`).

## Not done here (by instruction)
No edits outside this folder: strings.csv, tests, lines.tres and game/world are untouched. Nothing was committed or
pushed.
