# Gallery Night G1: apply rehearsal (GN-C1, 2026-10-14)

Owner: ENV C. Status: **rehearsal only**. The content freeze (D-082) is on. Everything below ran in a throwaway
worktree at `env/c-worlds` a0bce172. Nothing except this file was committed. These notes give the ordered
checklist for applying G1 for real at FREEZE LIFTED, and list every failure and gap the rehearsal found.

Inputs:
- `docs/levels/gallery_night/g1_skeleton.patch` (b1d4882c; sha256 9df5f76df24b…)
- ENV B's draft branch `origin/env/b-gallery-night` @ e401f7cc
- `docs/design/heists/gallery_night.md` (Build rulings B1–B6)
- `docs/process/next_heist.md` §3/§3b/§7
- `docs/contracts/heist_map.md` v1.2

## 1. What was applied

| Step | What | Result |
|---|---|---|
| 1 | `git apply docs/levels/gallery_night/g1_skeleton.patch` | Clean. It adds `game/world/heists/gallery_night/greybox/{build_greybox,gn_builder_base,gn_gameplay,gallery_night_layout}.gd` (+ .uid), `tools/levelcheck/gn_regen_twice.sh` and `tools/levelcheck/plans/gallery_night_emit_layout.py`. |
| 2 | `git checkout origin/env/b-gallery-night -- <content paths>` (list below) | Clean. These are content and data files only. B's UI code changes (`briefing_screen.gd`, `objectives_panel.gd`, `blueprint_view.gd`, `preplanning_screen.gd`, `lobby_state.gd`) and B's `test_contact_radio` / `test_p5_catalogue` edits were **not** taken. They merge with B's own branch. |
| 2b | Copied B's two drafts to the registry path: `game/world/heists/gallery_night/gallery_night_def.tres`, `gallery_night_variants.tres` | The generator picks them up (`DEF_PATH` / `VARIANTS_PATH`). `HeistRegistry` now lists `gallery_night`. |
| 3 | Wiring (scratch, not kept): a stub `gallery_night_mission.gd` attached to `Mission`; real `EscapeZone` + `SecureZone` prefabs under `Slot_esc_mews` / `Slot_esc_parade`; a `LootSpawn` per list-canvas slot (centrepiece + 3 groups, 12 slots) with the B5 objective_tags | See Appendix A. |
| 4 | Generated to `res://world/heists/gallery_night/_rehearsal/wired.tscn` (1.3 s, 851 navmesh polygons); `validate_level --stage=greybox --variants=all` | §3.1 |
| 5 | Copied the scene to the real map path (worktree only); ran `test_heist_readiness` (HEISTS narrowed to gallery_night), B's `test_gn_drafts`, a `VariantResolver` probe (300 seeds × 6 difficulties), `gallery_night_slots.py --check --b-live`, `gn_regen_twice.sh` | §3.2–§3.5 |

B content paths taken in step 2 (all at their final paths except the two drafts):
`game/content/_drafts/gallery_night/{README.md,gallery_night_def.tres,gallery_night_variants.tres}`,
`game/content/data/loot/painting_study.tres` ($700),
`game/content/data/preplanning/assets/{intel_list,intel_sensors}.tres`,
`game/content/data/preplanning/blueprints/gallery_night.tres`,
`game/content/data/strings/strings.csv`,
`game/content/data/voice/lines.tres`,
`game/tests/b/test_gn_drafts.gd` (+ .uid).
All of them applied over a0bce172 with no conflict, because `game/core`, `game/systems` and `game/contracts` are
identical on both branches.

## 2. Checklist for FREEZE LIFTED (ordered; owners per next_heist §3b.6 / §6)

Gate: next_heist §2 (the `gh_loud`, `gh_stealth` and `auto_loud` runs) passes first.

| # | Owner | Step | Command / check |
|---|---|---|---|
| 1 | **B** | Merge `env/b-gallery-night` into `env/b-content`, then into trunk. `painting_study` $700 must land **together with** its `test_p5_catalogue` pin (700). Taking only the data file breaks the catalogue test. | `tools/ci/run_tests.sh b test_p5_catalogue`, `… b test_gn_drafts` |
| 2 | **C** | Apply the skeleton on `env/c-worlds`: `git apply docs/levels/gallery_night/g1_skeleton.patch`. Commit `[GN-C1] …`. | `bash tools/levelcheck/gn_regen_twice.sh` (rehearsal: layout current, two regens byte-identical, bd86efdb…) |
| 3 | **A** (B README; C co-owns `game/world/**`) | Move B's drafts: `git mv game/content/_drafts/gallery_night/gallery_night_{def,variants}.tres game/world/heists/gallery_night/`. Delete the `_drafts/gallery_night` folder after its README content is copied (move it to `docs/levels/gallery_night/` or the doc). | `test_gn_drafts` finds the world path first (rehearsal: 6/6 PASS from the world path) |
| 4 | **B** | `test_contact_radio`: move `gallery_night` from `DRAFT_HEISTS` to `HEISTS`. Once the def is registered, Vance resolves. | `run_tests.sh b test_contact_radio` |
| 5 | **C** | Generator, freeze switch: drop the `SCENE_PATH` refusal in `build_greybox._build()` and make `DEFAULT_OUT = SCENE_PATH`. Add `game/world/heists/gallery_night/stage.txt` = `greybox`. Move `gn_regen_twice.sh` into `game/tests/c/test_generator_determinism.gd`, as its header says. | `validate_all.sh gallery_night` now finds the map |
| 6 | **C** | **Fix the exterior door thresholds** (§3.1, F1): add a sill under every ground-floor facade opening. | walkthrough: Portico → GH ≤ 3× straight |
| 7 | **C** | Gameplay layer, replacing every `Placeholder` (`meta todo`) with ENV A prefabs found by class name, as `sl_gameplay.prefab()` does. Port that helper with `place_use_point` / `_obstruct_prefab` (the skeleton has none). Each wall-hung slot needs a **facing** (F3). Order: escape zones + canvases (done in the rehearsal), then doors (B2 table), keycard pickups, code notes, keypad, readers, hack terminal, cameras + `camera_station`, laser grid, shutters (`industrial_door`), vault, safe, `deposit_box` ×8 + `small_loot`, studies, ladders, `bag_lift` ×3, padlock/grate. | `validate_level --stage=greybox --variants=all` |
| 8 | **C** | NPC data: GUARD / CIVILIAN / CAMERA_OPERATOR SpawnPoints with the B1 tags, PatrolGraphs (≥ 3 loops per post), Tactical (COVER, ENTRY ×6, holdouts H1–H4, SNIPER_PERCH, RAPPEL). `HeistRuntime.SCRIPTED_SPAWN_TAG` goes on the `guard_inspection` / `guard_vaultline` spawns. | `patrols`, `test_heist_readiness` test_02 |
| 9 | **A** | §3b.6 systems (unit test each): door relock/BAR (replicated), `keycard_reader.set_disabled`, `laser_grid.set_enabled`, loot alarm groups + `&"sensor"`, hack reconfigure, MapZone kind flip + calm exit/despawn, NPC-carried keycard, staff `npc_authorized_tags`, ambient clip mapping; NpcVisuals tag-first resolution (§3b.1) + gallery tags in `NpcVisualTweak.tag_characters`. | A's unit tests |
| 10 | **A** | `gallery_night_mission.gd` for real: last call, sensors, lockdown, rare-event effect keys (B README table), `find_canvases` areas, Vaultline G1 fallback (B3), `hack_loud` label swap. Replace the Appendix A stub. | `test_heist_readiness` test_01 |
| 11 | **LEAD** | `test_heist_readiness`: add `&"find_canvases"` to `AREA_OBJECTIVES`, or accept a seeded tag (F6). | — |
| 12 | **C** | Lighting (`viewmodel_lit` keys, B1), `walkthrough_whitelist.txt` for intended long routes (roof → Mews), review shots g1 (`LC_DRIVER=opengl3 render_shots.sh gallery_night g1`), blueprint render. | `render_shots.sh` |
| 13 | **P / A** | G1 tests (next_heist §7: laser gaps, balcony throws, Mews→LD heavy bag, pool, ladders, PO-3 snag probe 0); `auto_loud` + stealth e2e flows. | windowed |

## 3. Findings

### 3.1 validate_level (greybox, `--variants=all`)

**Skeleton as shipped** (no def, no mission, no zones): FAIL in `contract_nodes` (5) and `walkthrough` (1).
- `heist_def` not assigned
- `variant_table` not assigned
- no ESCAPE MapZone
- no SECURE_LOOT MapZone
- Mission has no script
- no walkthrough targets

Every geometry check PASSES on the bare shell:
- floating, clipping, scale, slopes, navmesh, barred_doors, reachability
- patrols, lasers, camera_spine, camera_screen, viewmodel_lit
- door_frame_gap, frame_proud, seam_gaps, furniture_logic

**Wired rehearsal scene:** `contract_nodes` PASS. FAIL in clipping (1), navmesh (3), reachability (48) and walkthrough
(120: 48 of 168 walks ok; 108 DETOUR, 12 UNREACHABLE). A full run takes ~30 s.

| Id | Finding | Cause | Fix (owner) |
|---|---|---|---|
| **F1** | **The Parade and Mews doors are not navigable.** The bronze doors, LD personnel door and LD roller have no navmesh link between inside and outside. Probe: crossing the VE doorway (2 m) is a 74 m path; the LD doors 147 m. Only the court French doors connect, so every Portico/Mews/Roof walk detours through the Sculpture Court (Portico → EB 89 m for 15 m; Mews → EB 164 m for 34 m; Roof → Mews escape 152 m for 28 m). | `_build_slabs` insets the G slab by half the facade (it ends at z 29.8 / starts at z 0.2), and the exterior grade starts at the wall's centre line (z 30.0 / ends at 0.0). Under each opening a **0.2 m strip has no floor**; the ray down at (20.5, 29.9) and (41, 0.1) hits nothing. The court works only because the basement facade wall (x 0) tops out at FFL 0.0 under the French doors. | C: a sill box (wall thickness × opening width, y −0.3…0.0) under every G facade opening (D, R, A). Do it in `_build_walls` from `L.OPENINGS`. |
| F2 | `orchard_calloway` LootSpawn clips the UG1 W facade by 0.20 m. It is 0.30 m off navmesh, so the canvas and UsePoint are unreachable (36 rows). | Rehearsal placement put the prefab origin on the slot anchor (x 0.3, i.e. 0.1 m proud of the 0.2 m inner face). The prefab's body is deeper than that. | C: offset wall-hung canvases from their wall by the prefab depth (F3). |
| F3 | `cp_landing` UsePoint is 1.0–1.2 m from navmesh (12 rows, all spawns). | `gallery_night_layout.SLOTS` rows carry **no yaw or wall normal**. The default UsePoint (−Z, 0.9 m) lands off the landing. Every wall-hung slot has the same issue: 4 canvas groups, key cabinet, code notes, readers. | C: add a yaw column to SLOTS (`gallery_night_slots.py` + emitter) and place UsePoints with `place_use_point`. |
| F4 | `widow_conservation`, `saint_harbour` and `orchard_benefactors` DETOUR (3.0–7.3×) | F1. | Re-check after F1. Whitelist only the roof spawns if their ratio stays over 3× after F1. |

### 3.2 test_heist_readiness (worktree copy at the real map path; HEISTS narrowed to gallery_night)

It **launches** through `HeistLauncher` with B's def, the table and the stub mission (Routine, seed 4242, 3 AI
teammates). Both tests FAIL:
- **test_01:** `find_canvases` has empty marker_tags (**F6**). `keycard`, `server_code`, `hack`, `treasury`, `art_store`
  and `extras` resolve to no node. Their prefabs are not placed yet (checklist 7). `canvas_lantern`,
  `canvas_orchard/widow/saint`, `secure_<esc>` and `escape_<esc>` **resolve**, so the B5 tags work end to end.
- **test_02:** "gallery_night spawned NPCs" fails. The skeleton has no GUARD/CIVILIAN/CAMERA_OPERATOR spawns (checklist 8).

The test picks heists only by `res://world/heists/<id>/<id>.tscn` + the registry def. It cannot target a scratch
scene path, so the rehearsal had to copy the scene there. At FREEZE LIFTED it runs as is.

### 3.3 VariantResolver on B's table (300 seeds × 6 difficulties against the wired scene)

- **Slot ids: no mismatch.** 18 rule groups ↔ 18 scene groups, 49 slots. Every id resolved on every seed exists in
  the scene. Every `weights_by_difficulty` / `slot_requires` key and every rare `force_active {group, slot}` names a
  real slot.
- `guard_post` picks are 1/1/2/3/4/4 by difficulty. `rover_none` is 48/300 at Routine (~0.16–0.2) and never from
  Hazardous. `kc_conservator` appears only with `cons_late`. `xl_crate` / `admin_pa` are empty unless `late_loan` /
  `late_paperwork` fire (≈ 5%).
- Rare events respect `min_difficulty`: insurance and vaultline from Hazardous, argus from Lethal.
- **`vaultline_early` fires with `cp_store` active.** The resolver ignores `effects.requires`, as B documents. The
  mission must void it (checklist 10).
- `escape_eta_s` resolves to floats (90.0/120.0/150.0); the other scalars are ints. Mission code should `int()` it.

### 3.4 Other checks
- `gallery_night_slots.py --check --b-live`: **PASS**, with the same NOTE lines as before. B's rule order is the valid
  one. The doc's Variable table still lacks the Hazardous rows. `xl_crate` / `admin_pa` base weights are 1/1 on B's
  side vs 1/0 in the doc; that is harmless with pick 0.
- Every point id in the def's preplanning (`pp_drop_*`, `pp_insider_registrar`, `pp_grate`, `pp_court_doors`) exists
  as a `Preplan` marker. The `preplan_spawn_mews` / `_roof` spawn tags exist.
- `test_gn_drafts` (B): 6/6 PASS with the def at the world path.
- `gn_regen_twice.sh`: PASS, deterministic.

### 3.5 Contract and API gaps that block a check (from the §3 audit)
- **F5, `casing_hall` cannot be a marker.** `HeistRuntime.find_by_tag` (and the HUD, `LocalHudModel`) read the
  `objective_tag` *property*. The skeleton's placeholders are plain `Marker3D`s with meta, so a bare marker never
  resolves. Either ENV A adds a tiny contract node with `objective_tag` (preferred, reusable), or C ships a
  `world/`-owned marker script. The readiness test skips `casing` (`AREA_OBJECTIVES`), so only the HUD is affected.
- **F6, `find_canvases` starts with `marker_tags: []`** (B5, no spoilers). `test_heist_readiness` requires non-empty
  tags for every non-area objective. The lead decides: add it to `AREA_OBJECTIVES`, or the mission seeds the tag of
  any slot already revealed by `asset.intel_list`.
- **F7, no prefab helper in the skeleton.** `gn_builder_base` lacks `prefab()` / `place_use_point()` / `_set_prop()`.
  Port them from `sl_gameplay.gd` (the rehearsal used a 20-line stand-in). The skeleton also builds no `door`
  prefabs: openings are holes (barred_doors/door_frame_gap pass vacuously).
- **Blocked until ENV A's §3b.6 APIs exist:**
  - the last-call zone flip (QC-51)
  - the curator's carried card (QC-52), so the `kc_curator` slot has nothing to place
  - landing curtain enable (QC-53)
  - frame-sensor alarm groups (QC-54); the G1 fallback is `raise_alarm(&"scripted")`
  - hack reconfigure (QC-55)
  - door relock/BAR for lockdown and last call
  - NPC staff door authorisation
  - Vaultline NPC bag (QC-57); the G1 fallback is B3

  `validate_level` itself is not blocked: it has no check that needs them. `auto_loud` / stealth e2e and the readiness
  gate are blocked.
- Missing validators named in B1 (`camera_spine`, `camera_screen`, `slopes`) **exist and pass** on the shell.
  The `lc` rule "no walkable slope < 50° outside the play mesh" (§7.5) passes; copings are 56°.

## 4. Effort estimate (agent sessions, after the freeze lifts)

| Owner | Work | Estimate |
|---|---|---|
| B | Merge drafts + tests (checklist 1, 4) | 0.5 |
| C | Checklist 2, 5, 6 (apply, freeze switch, sills) | 0.5 |
| C | Checklist 7–8 (gameplay layer ≈ 120 prefab instances, slot facings, NPC spawns/patrols/tactical) to validate_level PASS | 2–3 |
| C | Checklist 12 (lights, whitelist, review shots, blueprint) | 1 |
| A | Checklist 3, 9 (drafts move + 9 system APIs with unit tests + NpcVisuals tag order) | 3–4 (parallel with C) |
| A | Checklist 10 (full mission script) + e2e flows | 1.5–2 |
| LEAD/P | Checklist 11, 13 | 1 |

Critical path: C's gameplay layer (7–8) and A's systems (9) run in parallel, then the mission (10). Expect G1 lead
review ≈ 4–5 sessions after FREEZE LIFTED.

## Appendix A: rehearsal wiring (reference, not committed)

Stub mission (`game/world/heists/gallery_night/gallery_night_mission.gd`, extends `HeistMission`): adds
`casing [casing_hall]`, `find_canvases []`, `keycard`, `server_code [code_note]`, `hack`, `treasury [treasury_door]`,
`art_store [vault_reader]`, `centrepiece [canvas_lantern]`, `canvases [canvas_orchard, canvas_widow, canvas_saint]`,
`secure [secure_mews|secure_parade]`, `extras [lockers, curator_safe]` and hidden `escape [escape_mews|escape_parade]`
(label `objective.gallery_night.<id>`). `_on_alarm` adds `lockdown [shutter]` (completed), `server_door`,
`vault_drill` and `escape_wait`. `loot_secured`: the Lantern Bearer + 1 list canvas → complete `secure`,
`activate_escape()`. It compiles and launches; a GN-A1 starting point only.

Generator edits:
- `build_greybox._build()` attaches the script to `Mission`.
- `gn_gameplay.build_variants()`:
  - escape slots get `EscapeZone` (objective_tag `escape_<short>`, `escape_type van`, 3×3×4 m) and `SecureZone`
    (`secure_<short>`, 2×2.5×2 m, no vehicle collision) at `L.ESCAPE_ZONES`
  - the four canvas groups get a `LootSpawn` (`loot_id`, objective_tag `canvas_lantern|orchard|widow|saint`) at the
    slot anchor (hence F2/F3)
- The prefabs are found by contract class name, as `sl_builder_base.prefab_scene`.

Commands (from the repo root; Godot at /opt/godot/godot):
```
/opt/godot/godot --headless --path game --script res://world/heists/gallery_night/greybox/build_greybox.gd -- --out=res://world/heists/gallery_night/_rehearsal/wired.tscn
/opt/godot/godot --headless --path game res://world/tools/validate_level.tscn -- --heist=gallery_night --stage=greybox --variants=all --scene=res://world/heists/gallery_night/_rehearsal/wired.tscn --report=<scratch>/val.md --walkthrough-report=<scratch>/wt.md
/opt/godot/godot --headless --path game res://tests/framework/runner.tscn -- --dir=integration --filter=test_heist_readiness
/opt/godot/godot --headless --path game res://tests/framework/runner.tscn -- --dir=b --filter=test_gn_drafts
python3 tools/levelcheck/plans/gallery_night_slots.py --check --b-live
bash tools/levelcheck/gn_regen_twice.sh
```
The resolver probe ran as a scene, not with `--script`: autoloads (`GameRng`) are not compile-time identifiers in
`--script` mode, and `VariantResolver` fails to compile there.

## 5. F1–F7 status (GN-C1 round 3, 2026-10-14)

The C-owned findings are fixed **in the skeleton**. `docs/levels/gallery_night/g1_skeleton.patch` was re-exported as
one format-patch commit on top of this tree (12 files, +2905 lines; patch 146 445 bytes, sha256 `9eff548c5e2a…`). It
still adds files only: the four greybox scripts (+ .uid), `game/world/kits/objective_marker.gd` (+ .uid),
`tools/levelcheck/gn_regen_twice.sh` and `tools/levelcheck/plans/gallery_night_emit_layout.py`. The slot list it
emits from is on trunk: `tools/levelcheck/plans/gallery_night_slots.py` now has the yaw column and the extended
`--check`. Checklist step 2 is unchanged (`git apply`). Steps 6 and part of 7 are now done in the patch.

| Id | Status | What changed |
|---|---|---|
| F1 | **Fixed** | `build_greybox._build_sills`: a sill box goes under every walk-through facade opening (doors, arches, the LD roller, the areaway passage, the roof ladder top). It spans the opening's fitted width. On G it fills the inner half of the wall, because the grade starts at the centre line. On B and R it fills the full thickness. The court French doors are skipped: they already stand on the basement wall, which tops out at FFL 0.0. |
| F2 | **Fixed** | `orchard_calloway` / `widow_sallow` / `widow_founders` sit at x 0.3 (0.1 m off the 0.2 m face) facing east. `saint_maritime` / `saint_harbour` sit at x 43.7 facing west. `orchard_benefactors` moves to the EB west (donor) wall at x 32.25. `cp_landing` is at z 8.25 facing south, `cp_treasury` faces north, and `kc_security` faces west. The VariantSlot carries the yaw, and the prefab that replaces the placeholder inherits it. G1 still has to offset the `loot_spawn` origin by its own depth (F2's last line), using the slot's −Z. |
| F3 | **Fixed** | `gallery_night_slots.py`: yaw column (front = −Z, 0 N / 90 W / 180 S / −90 E), `WALL_HUNG`, `USE_POINT_GROUPS`. `--check` now fails a wall-hung slot that is more than 0.3 m from its room wall's face, has no wall on that edge, or does not face away from it. It also fails an interactive slot whose UsePoint (0.9 m in front) is not ≥ 0.3 m inside its room. `gn_gameplay._slot_use_point` puts a `UsePoint` on each interactive placeholder, on the floor it stands on (the GH half landing for `cp_landing`). `validate_level` `navmesh`: every UsePoint is on the navmesh. |
| F4 | **Mostly fixed** (walk numbers below) | `orchard_benefactors` / `saint_harbour` are ≤ 2.5× from the Portico and Mews. The roof spawns are 2.2–3.25× (via Stair SS, BC and the arches). `widow_conservation` is 1.6× from the Portico, but 4.2–4.5× from the Mews and up to 3.8× from the roof. The cause is the plan: one Mews entry at LD's east end and the only stair at the far west. Whitelist those routes in checklist 12, or add the fire-escape ladder's nav link (Mews ↔ roof). |
| F5 | **Fixed (C side)** | `game/world/kits/objective_marker.gd` (no `class_name`) is a `Marker3D` with an exported `objective_tag`. `HeistRuntime.find_by_tag` and `LocalHudModel` read that property. Placeholders of tagged content carry the B5 tags: `canvas_lantern|orchard|widow|saint`, `keycard`, `code_note`, `escape_<short>` / `secure_<short>` on the zone placeholders. `Gameplay/Markers/CasingHall` is `casing_hall` at the GH stair foot (22, 0, 15.4). ENV A may still promote this to a contract node; the property name is the same. |
| F6 | Open (LEAD) | Not C's. |
| F7 | **Fixed** | Ported from `sl_gameplay` / `sl_builder_base`: `prefab()`, `place_use_point()`, `_set_prop()` / `_enum_value()`, `prefab_scene()` (by class name), `kit_scene()`, `obstruct()`. Every B2 door is a `door` prefab, 42 in all (the `court_doors` slots build theirs: NONE / LOCKPICK). Each takes the B2 lock, swing (INWARD; DOUBLE for doubles), `push_bar` (LD personnel, head house, bronze), `starts_open` (bronze), `npc_authorized_tags`, `code_group argus` (SV), LOCKPICK 8 s and `leaf_surface` metal / glass. Visual: `arch_door_<single|double|service>_<t20|t40>` by wall thickness. Wall holes are cut to the kit opening (1.0 / 2.0 / 1.2 × 2.2 m) on the door centre. The bronze doors are two doubles with a 0.2 m pier, and the BC → LD door is a 1.2 m service door, since the corridor is 1.8 m clear. Where the 0.3 m Stair SS / head-house wall carries a door, it is built 0.4 m thick on x 3.05, with its stair face kept at 2.85. Public openings with no leaf in B2 (CK, PWW/PWM, DC, the arches) stay open. The 9 gameplay windows (EB S ×3 + E ×2, SL S ×4) are breakable `window` prefabs with `prop_window_w120_h210`; their holes are 1.2 × 2.1 m from the plan sill. The LD roller has no kit visual yet (placeholder `DockRollerDoor`, `industrial_door` at G1); it is baked closed (D-073), so the Mews enters through the personnel door. VAULT doors stay open in the bake: the art store has no other way in (reachability). |

**validate_level** (`--stage=greybox --variants=all`, scene generated to `user://gn_scratch/after.tscn`; 888 navmesh
polygons, previously 851):
- FAIL only `contract_nodes` (5: the freeze items `heist_def`, `variant_table`, ESCAPE / SECURE_LOOT MapZone, mission
  script) and `walkthrough`.
- PASS: floating, clipping, scale, slopes, navmesh, barred_doors, reachability (50 variant configurations, 40 800
  queries; rehearsal: 48 fails), patrols, lasers, camera_spine, camera_screen, viewmodel_lit, seam_gaps,
  furniture_logic, and door_frame_gap / frame_proud on **51 measured prefabs** (rehearsal: vacuous). Leaf surfaces:
  glass 2, metal 6, wood 34, no mismatch WARN.
- walkthrough: **514 / 756 walks ok, 242 DETOUR, 0 UNREACHABLE**. The rehearsal's wired scene had 48 / 168 ok,
  108 DETOUR and 12 UNREACHABLE. On the slot UsePoints alone (14 per spawn):

  | Spawns | Slot walks ok | Remaining DETOURs |
  |---|---|---|
  | Portico | 56 / 56 | none |
  | Mews | 24 / 56 | anything upstairs or west |
  | Roof | 30 / 56 | the rooms straight below |

  The remaining DETOURs are the stair-core / single-entry routes above (whitelist candidates, checklist 12); the
  Portico's are the SL windows and AT (via the grand stair).

Nav probe (same pairs as §3.1; rehearsal skeleton → now):

| Pair | Straight (m) | Path before (m) | Path now (m) |
|---|---|---|---|
| VE doorway | 2 | 74.3 | 2.2 |
| LD personnel doorway | 2 | 148.3 | 2.0 |
| Areaway passage → PL | 2.5 | unreached | 2.5 |
| Portico → EB | 13.5 | 91.2 | 30.8 |
| Portico → GH | 15 | 70.9 | 15.0 |
| Mews → EB | 34 | 162.7 | 45.0 |
| Mews → LD | 16.3 | 159.7 | 22.6 |
| Roof → Mews escape | 28.4 | 150.2 | 77.8 |

**Other checks:**
- `gn_regen_twice.sh`: layout current; two regens byte-identical (`2322d9de478f7d71`, 518 955 bytes). The patch
  applied to this tree reproduces it.
- `gallery_night_slots.py --check` and `--check --b-live`: PASS.
- `gallery_night_floors_ascii.py --check`: PASS.
- `gdlint` on every .gd in the patch: clean.

**Still open for G1 (checklist 7–8):**
- the readers / keypad / hack terminal / drill points that carry `treasury_door`, `vault_reader`, `server_door`,
  `vault_drill`, `hack`
- the shutters and the roller (`industrial_door`)
- the lift landings (`bag_lift`)
- the ladders' nav links
- NPC spawns, patrols and tactical points
- `saint_maritime`: on the UG3 east wall at z 15 it is not in the UG3 screen's shadow from C10 (32.4, 12.4); the
  canvas would need z ≥ 15.7. `camera_screen` passes today only because the cameras are placeholders. Decide at G1:
  move the slot or the screen.
