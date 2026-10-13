# ENV C status: Worlds & Art

Owner: ENV C. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-12 20:25 ET: IN PROGRESS (ENV C)
### Done
- 4f4ee34a trunk db22c24c merged --no-ff. 811be4d6 public doors casing_allowed (GH MainEntrance, ND AtmStreetDoor)
  + test_public_doors_casing. d97a7371 SalonDoor walk legs. ec180fd1 PP walk tests load P's driver at run time
  (tests/c no longer fails to parse without env/p-play). 2f039639 test_validate_level 20 checks. b573cfa2 Dockside
  fog thinner. tests/c all green, test_p3_loud 10/10, validate_level x3 PASS.
- PP-C-1 rerun (A 488e7685 + P 5b863e1b): stalls are closed doors the harness does not open; see pp_c1.md.
### Next
- Walk harness: aim at the door leaf before interact, rerun. zoom_factor (D-084, low).
### Blockers
- None. LEAD pushes.

## 2026-10-12 19:45 ET: IN PROGRESS (ENV C)
### Done
- 3c3a31c5 interact slots fixed: ND ATM1/ATM2 cash on the ATM front face, kc_break_locker on the G4 kitchen counter,
  DB CageCashA/B UsePoints inside the count cage; test_interact_slots_clear 0 problems on all 3 maps, no allowlist.
- 91c3a3c1 Night Deposit BARRED police gates (Alley, HarborWest, HarborEast, WharfNorth) baked closed at r 0.30,
  spawn islands kept; test_night_deposit_police_gates seeds 1001 + 3071 PASS; validate_level night_deposit PASS
  (x2). barred_doors check waits 8 frames for the link disable (it failed ~1 in 2 full Dockside runs).
- 1acba8c3 PP-C-1 STUCK rows name the nearest door. b0b274a0 (count/total with bags) was already in.
### Next
- PP-C-1 rerun running in /workspace/cnc-team/c/walks-wt (scratch/c-walks = env/c-worlds + A 7cf4240e + P 0a906e03,
  never merged into env/c-worlds), both modes; then zoom_factor (D-084, low).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 19:30 ET: IN PROGRESS (ENV C)
### Done
- 6943ce02 Night Deposit lighting for D 20 m readability: desaturated sodium lamps +20%, cool colour
  ambient, brighter moon, exposure 1.25 (map stays dark). Before/after renders in /workspace/cnc-team/c/renders/.
- 4efb5b21 test_interact_slots_clear: interactables clear of prop collision and aimable from UsePoint
  (3 heists; open ND/DB findings logged). 356d5087 Glasshouse kc_breakroom off locker tops onto break table.
- c7f4ab5a PP-C-2 lighting rows from software renders (Night Deposit, Dockside).
- Prior hour still stands: glasshouse police gates (fbd1e837), bag count/total (b0b274a0), PP-C-1/2 harness.
### In progress (dirty, not committed)
- ND/DB UsePoint aimability tweaks (AtmCash height, kc_break_locker, DB cage cash use inside cage).
- player_input.gd: screen_relative mouse gain + `test_assume_captured` for headless PInputDriver walks
  (P-owned path — local walk aid only until P lands equivalent).
- test_p3_loud re-run against the dirty tree (prior clean tree was 10/10; one dirty run flaked 8/10 on
  captain_arrived / assault phase).
- PP-C-1 stuck audit (walks-wt + main): night_deposit 5 ok / 9 stuck; dockside_burn 2 ok / 12 stuck.
### Next
1. Commit interact/use-point WIP once test_p3_loud is green on the dirty tree.
2. Keep fixing PP-C-1 door/use stuck spots; rerun walks.
3. check_all --env c when the lead lock frees; push env/c-worlds on PASS (D-083 lift).
4. zoom_factor (D-084, low).
### Blockers
- None for local work. check_all lock held by lead (~19:06 start). Not pushed (LEAD pushes).

## 2026-10-12 19:00 ET: IN PROGRESS (ENV C)
### Done
- fbd1e837 test_glasshouse_police_gates: the 4 BARRED gates are shut before the alarm, open by the first assault, and every
  police spawn reaches both holdouts (workshop G2, G4/G10 corner); seeds 1001 + 3071 PASS. validate_level glasshouse PASS.
- b0b274a0 secure objective data gains `count` (bags secured) and `total` (bags required) in glasshouse, night_deposit
  and dockside_burn (+ dockside launch assert); tests/c launch 7/7.
- f966a008 PP-C-2 headless hand-play (prompt reach + cover gaps), notes docs/levels/pp_c2_handplay.md.
- ee7e83b2 PP-C-1 walks: D-085 human door-centre mode beside the AI corner mode.
### Next
- PP-C-1 rerun in the scratch worktree /workspace/cnc-team/c/walks-wt (env/c-worlds + A 946384de + P d1858e83, never
  merged into env/c-worlds), both modes; then zoom_factor (D-084, low priority).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 18:45 ET: IN PROGRESS (ENV C)
### Done
- 0b13456f Glasshouse: AlleyGate, HarlowWestGate, HarlowEastGate, PellNorthGate baked closed in the navmesh
  (agent_radius 0.30 per D-085; obstruction = leaf + 0.6 m). The police spawns behind them became separate islands
  whose big polygons' centroids were > 1.5 m from the spawn, so _prune_islands now also keeps an island whose
  polygon contains the marker. validate_level glasshouse [final]: PASS (all 20 checks, barred_doors included).
  Targeted tests: tests/c glasshouse 10/10, test_coop_loopback 1/1, test_p1_vertical_slice 10/10.
- 65580d9c Dockside police gates open before the first assault (test, seeds 1001 + 3007); 63164285 .wiplogs/ removed;
  51cfb287 cue.payday_tick; 7359ab85 PP-C-1 harness + docs/levels/pp_c1.md.
### Next
- PP-C-1 rerun once ENV P's capsule slide fix lands; then zoom_factor (D-084, low priority).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 18:05 ET: IN PROGRESS (ENV C, Dockside G2 gameplay)
### Done
- a00cdf3b reverts the Shadow Ledger WIP merge 0b68bd67 (does not build); reapply once it builds.
- fd0bcc24 Dockside G2: game/tests/c/test_dockside_burn_routes.gd (D-070: every holdout has >= 2 non-breach_only
  police approaches on the baked navmesh from legal spawns; H1 platform stair + ST door, H2 SP mouth + C2 south,
  H3 quay W + E, H4 gate + yard W/E); the cartel hold (police_delay_s) is compressed by the same factor as a
  `director_tweak` override's first_control_s (shipped tweak: unchanged 60/90/120 s); cue.burn_warning now 3
  variations (audio_cues v1.2) + registry test.
- Box results: test_p3_loud 10/10 PASS (was 8/10: test_08 captain, test_10 assault never started under the
  cartel hold); tests/c dockside 15/15; validate_level dockside_burn PASS; walkthrough PASS; yard arena
  (35.5, -18.5) open, 11 clear directions. Hall open floor >= 12 m + crate cover, burn_point/padlock prefabs,
  barred doors baked closed: already in the db-wip merge, all checks green.
### Next
- check_all --env c (queued on the lock), then PP-C-1 (real-input walk via game/tests/p/p_input_driver.gd).
### Blockers / for LEAD
- Ferro St (P1e/P1w), Bellweather (P2), Pier 10 (P3) police spawns have NO navmesh path anywhere until the
  mission opens the police gates (door NavLinks); fine in play, but any pre-gate director pick there stalls.

## 2026-10-12 17:40 ET: IN PROGRESS (ENV C, hourly checkpoint)
### Done
- Unshallowed the box clone and merged both backups into env/c-worlds locally (--no-ff, no conflicts, no conflict markers):
  2cbda054 = backup/2026-10-12/env-c-db-wip (Dockside G2 WIP + the 8 uncommitted files, .wiplogs/), 0b68bd67 = backup/2026-10-12/env-c-sl
  (Shadow Ledger G2 WIP, still does not build). Not pushed; not yet through check_all.
### Next (LEAD queue 18:10, D-082 playability first)
1. Dockside Burn G2 gameplay milestone (P3 unblock): import on the box, then >= 2 non-breach police routes per holdout, hall open floor
   >= 12 m with crate cover, cue.burn_warning, remove QC-35/38 fallbacks, test_p3_loud green, validate_level + check_all --env c, push on PASS.
2. PP-C-1: real-input walk of every heist (stuck spots, nav holes, reachability), rows into docs/process/playability_pass.md.
3. Shadow Ledger G2 build fix. Frozen (D-076/D-082): C5-01 stems, safehouse C4-0x, P5.
### Blockers
- None for local work. Push to env/c-worlds needs a check_all PASS and the PO's OK; LEAD reports the box has no GitHub push credentials yet.
- Box load: ENV B check_all is running (8 cores, ~2 GB RAM free), so keep to 1-2 heavy Godot/Blender jobs.

## 2026-10-12: CORRECTION + RESUME (ENV C, new agent on the box)
The 2026-10-11 13:45 handoff below said the SL/DB WIP was "lost with this container". **That is out of date.** The work
was redone in the WSL helper worktrees and backed up to GitHub on 2026-10-12. These are raw snapshots and have not been through check_all:
- `backup/2026-10-12/env-c-db-wip` 1e09a054: Dockside Burn G2 gameplay WIP (c/db-wip 9fecaf9e) + the 8 uncommitted files
  (dockside_burn.tscn, db_gameplay.gd, layout, 2 tests, validation/walkthrough md, .wiplogs/). Padlock/burn_point/
  deposit_box prefabs, QC-35 police delay, BARRED doorways baked closed + barred_doors check. **Top priority.**
- `backup/2026-10-12/env-c-sl` eb07ae4f: Shadow Ledger G2 art pass (sl_art accumulator, 19 tower props, 26 kits).
  **Does not build yet.**
- `backup/2026-10-12/env-c-stash` 95412d3b: C5-01 music stems WIP (paused, D-076).
### Next
1. Once LEAD posts that Godot and Blender are set up on the box: Dockside G2 from db-wip. Remaining work: >= 2 non-breach police
   routes per holdout, hall cover, cue.burn_warning, test_p3_loud green. Then push the gameplay milestone, which unlocks P3 sign-off.
2. Shadow Ledger G2: get it building, then finish it. 3. C4-01/C4-02 safehouse hub.
### Blockers
- (Resolved 17:35: LEAD posted Godot 4.7.2 + Blender 4.5.14 ready on the box.)

## 2026-10-11 (new account, session 2): IN PROGRESS (kept current per D-077)
### In progress
- **Shadow Ledger G2**: helper in worktree ~/caper/env-c-sl, branch c/sl-wip (local only). Brief: port the
  Night Deposit G2 approach (sl_art.gd / sl_dress.gd / shadow_ledger_dressing.gd / bake_gi.gd), the 13:45 entry's
  requirements, stage final, g2 shots + contact sheet in docs/levels/shadow_ledger/g2/, plus a stuck-spot audit.
  Next step if resumed: `git log c/sl-wip`, continue from the last commit, then validate_level final.
- **Dockside Burn G2**: helper in ~/caper/env-c-db, branch c/db-wip (local only). Order: nav/gameplay first (barred
  gates baked closed + generic validate check "no nav path through a BARRED doorway", >= 2 non-breach approaches
  per holdout, A's burn_point/padlock/deposit_box, cue.burn_warning, test_p3_loud green), then the art pass.
  Next step if resumed: `git log c/db-wip`, continue from the last commit.
- Integration: ENV C merges c/sl-wip and c/db-wip into env/c-worlds, runs check_all --env c, pushes on PASS.
### Paused (D-076)
- C5-01 music stems: WIP in `git stash` on ~/caper/env-c ("C5-01 music stems WIP"): music_parts.py (shared
  parts, moved out of music_glasshouse.py) + music_night_deposit/shadow_ledger/dockside_burn.py. Not built or
  validated; build.py multi-track support and MusicTrackEntry.source_track / MusicDirector.set_ducked not started.
- C4-02 safehouse greybox: not started (helper stopped before any edit).
### Notes
- Baseline check_all --env c on 0771daef: FAIL, only test_b4_18_special_weapons::test_parts_animator_drives_named_parts
  (ENV B test: "Breech open while reloading" expected -0.698 got -0.591), 1673 tests / 1 failed; validate_all 4/4 pass.

## 2026-10-11 13:45 UTC: HANDOFF (session shut down by the PO; account move)
Branch env/c-worlds is the source of truth. Everything listed under Done is pushed and passed a clean push_gate.
### Done (on origin)
- Glasshouse G3 signed off (D-059 punch list, D-061 operator and code note, keycard/code/drill safe, D-066 secure_zones check).
- Night Deposit G2 FINAL (adff154, 19/19, trunk round 31): ENV A deposit_box/padlock prefabs, brightness hook.
- Dockside Burn G1 (P3 gate map, D-070); music table and preview (65c299a); brightness hook; cues v1.2/v1.3 (213795a, b4ca0ef).
- Safehouse G0 approved (docs/design/heists/safehouse.md; hub_map.md v1.0, D-072).
- P5 G0 docs approved (D-075): gallery_night, ostrander_federal (was meridian), afterhours, rolling_thunder.
- push_gate.sh: per-run mktemp logs, plus a conflict-marker step (6622218). zfight report shows the triangle count only.
### In progress: NOT pushed at handoff (SUPERSEDED: redone in WSL and backed up 2026-10-12, see the newest entry)
- **Shadow Ledger G2:** the agent had dressing, props and VoxelGI done, stage final, 26/~30 g2 shots rendered, and was at lint/ownership. Redo from the brief:
  - KitPlacer dressing, upscale palette, rain/night exterior;
  - saw_target via A's prefabs on the server cage (safe methods [code, saw]);
  - ENV D notes: M5 bed duvet, ≥ 1.08 m of mattress ahead of the pelvis root, pillows 0.45 m behind it; office seat 0.47 / desk 0.74;
  - Northgate guards; the IT contractor's laptop holds the code;
  - loot.painting is LIGHT in the doc;
  - HeistWorldEnvironment.
- **Dockside Burn G2:** just started (layout fixes). Lead requirements:
  - fog-free top-down shots; blueprint room names (Packing Hall, Cold Chamber A/B, Spine, Anteroom, Loading Hall); crop floor0;
  - hall open floor ≥ 12 m with crate cover;
  - every holdout gets ≥ 2 non-breach_only police routes;
  - barred/vault gates baked closed in the navmesh, plus a new validate check: no nav path through a BARRED doorway;
  - keep the yard arena at (35, 0, −18) open;
  - A's burn_point/padlock/deposit_box replace the placeholders; remove the QC-35/38 fallbacks;
  - wire cue.burn_warning;
  - keep test_p3_loud green.
### Queue (lead order)
1. Shadow Ledger G2 and Dockside G2 (the P3 sign-off item).
2. **C5-01 stems:** night_deposit, shadow_ledger, dockside_burn. vault_hymn/long_con/last_call alias those stems via a source-track field on MusicTrackEntry. MusicDirector nodes in those maps.
3. **C4-02 safehouse greybox** to hub_map.md v1.0:
   - res://world/hub/safehouse/safehouse.tscn, a SafehouseMap root;
   - 8 stations, using A's HubStationPrefab;
   - add MusicDirector.set_ducked(bool) (−6 dB).
4. **P5 G1s** in order gallery_night, ostrander_federal, afterhours, rolling_thunder. The gallery camera_spine and camera_screen validate checks are built at G1.
5. **Backlog:**
   - Night Deposit G3: a lit "Harbor Savings & Loan" sign; cash-brick pallet in the vault cage; teller personal touches.
   - Glasshouse polish: car props in the garage, the stray bracket by the neon V, the security-office bins.
   - Cues: npc_melee_swing, radio_squelch.
   - say() lines use HeistDef.contact as the speaker.
   - Fix the nav-timing test flakes (test_bad_fixture_fails_exactly_expected, test_one_way_island_*): condition waits instead of frame budgets.
### Notes for the next session
- With 4 cores, run at most 2 render-heavy jobs at once. Use worktrees for parallel work; seed each with a copied `game/.godot`, then run --import once.
- Never let agents hand-resolve generated docs in a merge. Grep for conflict markers before every push (push_gate does this now).
- Verify any agent's "PUSH_GATE: PASS" claim yourself; one agent fabricated a pass this session.

## 2026-10-11: C1-08 Glasshouse G2 final, C2 Night Deposit / Shadow Ledger G1 follow-ups, C1-04 validator checks
### Done
- C1-08 **Glasshouse G2 final** (stage=final). validate_level final passes all 18 checks, including the new
  `cameras` check. P1 gate 4/4. Includes 23 review shots, a labelled contact sheet and the blueprint
  re-render in docs/levels/glasshouse/g2/. VoxelGI re-baked.
- C1-04 validator: stair handrail detection (lc_stair_rails), laser crouch-under, review-camera
  placement check (cameras >= 0.5 m inside their room), and floor_name support in review_shots
  (D-054). Also push_gate.sh (463942f), which runs validate_all before every push.
- C2 Night Deposit: stair handrails (55eec68), review cameras moved inside their rooms (0679122).
- C2 Shadow Ledger: G1 (9065410) and follow-up (7d0fc5b).
- C1-06 / C1-07: batch-3 weapon cues (09c05a3, ca5022d), batch-3 materials (630c68d), catalog
  texel/zfight pass (ee11936).
### In progress
- Waiting on the lead's review of the Glasshouse G2 final set.
### Blocked
- Night Deposit / Shadow Ledger G2 art passes: SAW_TARGET from ENV A.
### Questions for lead
- QC-34: garage perch. The parapet is the 1.0 m guard and the extra steel rail is removed in the
  perch bay. Is that interpretation right?
### Ready for integration
- yes. push_gate PASS: import, banned/ownership, gdlint, tests c 123/123, integration 4/4, and
  validate_all (glasshouse final, night_deposit and shadow_ledger greybox).

## 2026-10-10 17:00 UTC: C1-00, C1-01, C1-02, C1-03 (G1), C1-04, C1-06, C1-07 (part), D-026, D-034
### Done
- C1-00 counter style samples + comparison sheet (6b289a6). The product owner chose GSR (D-035).
- C1-01 / C1-02: Blender lib + build.py with determinism, glb post-import, greybox kit (5bb86b1),
  texgen + material library v1 (4f18b5d), audiogen (1ad4bfe). Mask naming (af59831).
- C1-04 `validate_level` (8ca1b48), plus fixes for the D-025 nav values, chained U-stairs/ramp collision
  and readable plan renders (f7bb9ba).
- C1-06 P1 cues, MusicDirector, Glasshouse stems (1ad4bfe). Test de-flake (4f72fc2).
- D-026: 9 weapon materials (a6fa9eb), pistol reload cues (f38e00f). D-034: weapon-family cues
  (14fe2ce), 4 materials + darker blacks (5ea9652).
- C1-03 G1 Glasshouse greybox (0152852 + f7bb9ba). Generated map, full contract tree, variants,
  mission, def. validate_level greybox (all variants) PASS in 13.7 s; walkthrough PASS; 23 shots +
  floor plans in docs/levels/glasshouse/g1/.
- C1-05 WIP handed to ENV D (31950a7).
### In progress
- —
### Blocked
- P1 gate steps 4/8 on Glasshouse: blocked on gate-test bot placement (QC-6, lead).
### Questions for lead
- QC-6: gate steps 4/8 teleport the bot behind the shopfront glass or inside the corridor. Make the
  teleports LOS-checked, or move the floor post?
- QC-7: approve the G1 deviations from G0 (sent by message: merged patrol graph, customers as a slot
  group, carrier slots for rare events, workshop ceiling override, small door shifts).
- QC-8: keep or drop `test_glasshouse_gate.gd` (ENV A's sandbox gate on Glasshouse)? Not pushed.
- QC-9: relax the 0.04 albedo floor for black polymer/rubber?
- QC-10: validator tolerances: provisional 3M-triangle perf budget, vault ceiling 2.6–6.0, review
  shots as JPEG (§8 says PNG).
### Ready for integration
- yes, all of the above. `check_all.sh --env c`: everything passes (import, lint, .import validity,
  banned patterns, ownership, 508/512 tests, validate_level glasshouse) except the gate steps 4/8
  (QC-6, gate-side), which fail in both test_p1_vertical_slice and the unpushed local copy.

## 2026-10-10 (session 1, interim): C1-03 G0, C1-01..06 in progress
### Done
- **G0 draft: `docs/design/heists/glasshouse.md`.** Written from the §9 template; review requested.
  The ASCII plans are generated by `tools/levelcheck/plans/*.py` so the dimensions are exact.
  **No geometry is built until G0 is approved.**
- **Rendering check: screenshots work in this container.**
  - Out of the box, Vulkan fails (no `VK_KHR_surface`), and Godot falls back to OpenGL3 on llvmpipe
    (Mesa 25.2) under `xvfb-run`. That renders correctly.
  - After `apt-get update && apt-get install -y mesa-vulkan-drivers` (lavapipe), **Vulkan Forward+ on
    llvmpipe works under xvfb**, so review shots use the shipping renderer.
  - Command: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --resolution 1920x1080 <scene>`.
- Baseline `tools/ci/check_all.sh --env c`: PASS.
### In progress (parallel subagents; not yet committed)
- C1-01 pipeline: `tools/blender/lib` + `build.py` + determinism check, glb post-import script,
  `tools/texgen` (own tileable noise, ORM, trim sheet, LUT), `tools/audiogen` synth core.
- C1-02 greybox kit + greybox materials.
- C1-04 `validate_level` + walkthrough + review_shots renderer.
- C1-06 P1 cues + MusicDirector + Glasshouse stems. C1-07 material library v1 foundation.
- Next: C1-05 characters (they start once the Blender lib lands).
### Blocked
- C1-03 G1 geometry: waiting on G0 approval.
### Questions for lead
- QC-1: The `noise` package in tools/requirements.txt does not build on Python 3.13 (the session-start
  pip install fails on it). texgen implements its own tileable noise in numpy. Please remove `noise`
  from requirements.txt.
- QC-2: Please add `apt-get install -y mesa-vulkan-drivers` (plus `xvfb`) to the setup scripts
  (tools/setup is lead-owned) so every session can render Forward+ review shots.
- QC-3: You asked for the pipeline how-to at `docs/art/pipeline.md`, but owners.json does not give
  ENV C that path. I am writing it at `tools/blender/PIPELINE.md`. Either add `docs/art/pipeline.md`
  to ENV C's globs or move/link it on merge.
- QC-4: Audio bus layout: ENV C ships `game/world/audio/default_bus_layout.tres`. Please set
  `audio/buses/default_bus_layout="res://world/audio/default_bus_layout.tres"` in project.godot
  (lead-owned). Until then the runtime applies it if the buses are missing.
- QC-5: G0 proposes base_payout $40,000 for Glasshouse (HeistDef). Confirm, or have B set the
  economy number.
### Ready for integration
- no (G0 doc only; review requested). `check_all.sh --env c`: PASS at baseline.
