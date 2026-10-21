# GPU box status (aaron-82, native Windows)

Machine: Windows 10 Home 19045, AMD Radeon RX 9070 XT (driver 32.0.31019.2002), Godot 4.7.2.stable.official.ed1daf0bf win64.
Checkout: `C:\Users\Aaron\caperworks-gpu`, depth-1 trunk clone, cone sparse-index excluding
`game/tests/p/_review/captures/of_g1_2026-10-17/` (two `->` filenames are invalid on Windows).

## GPU-1: OF g2 review shots, Forward+ on real GPU
- Trunk: e960048e
- Command (from repo root):
  `godot\Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- --heist=ostrander_federal --stage=g2 --out=<repo>\docs\levels\ostrander_federal\g2\gpu_forward_plus --warmup=120`
- Renderer: `Vulkan 1.4.349 - Forward+ - Using Device #0: AMD - AMD Radeon RX 9070 XT`
- Exit code: 0
- Wall time: 49 s total, covering startup, level build, warmup and all 35 images (TopDownPlan + 34 rc_* cameras), so about 1.4 s per shot. The tool prints no per-shot timing or FPS.
- Output: `docs/levels/ostrander_federal/g2/gpu_forward_plus/` (35 JPEGs, contact_sheet.jpg, shots.md)
- Notes: no ERRORs. Warnings: `PresidentSafe: content PresidentValuables1/2/3 sits outside the safe body; moved to LootAnchor`
  (systems/prefabs/safe/safe.gd:550), plus `7 RIDs of type "Texture" were leaked` at shutdown.

## GPU-2: real-GPU cast draw counts for D-146
- Trunk: e960048e. Command (from repo root): `godot\Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --resolution 1920x1080 --path game res://world/characters/_tools/heist_cast_perf.tscn -- <args>`
- All three runs were windowed, Forward+ / Vulkan on the RX 9070 XT, with no ERRORs.

| run | args | exit | wall |
|---|---|---|---|
| ostrander_federal | `--heist=ostrander_federal --seed=1037 --detail` | 0 | 55 s |
| ostrander_federal_loud | `... --detail --loud` | 0 | 131 s |
| glasshouse | `--heist=glasshouse --seed=1037 --detail` | 0 | 14 s |

- Console output is in `gpu/perf/<run>.txt`, with PowerShell's stderr wrapper lines removed.
- **No frame times**: heist_cast_perf prints draws/prims/objects per view but no frame timing, so none could be recorded.
- **glasshouse captured no views**: `VIEWS` in heist_cast_perf.gd has no `glasshouse` entry. The run only printed
  the summary line (npcs=11: guard 4, civilian 7) and wrote no PNGs. Add glasshouse views and I'll rerun it.
- **PNGs are from the loud run**: the quiet and loud runs write the same `cast_perf_ostrander_federal_<view>.png` names
  in user://, so the loud run overwrote the quiet one's PNGs. That leaves 6 PNGs (hall_south_eye/high, hall_west_diag, rc_hall_entrance/counter/from_gallery).
- Shutdown warnings in every run: `7 RIDs of type "Texture" were leaked` and 298-492 `ObjectDB instances were leaked at exit`.
## GPU-3: Forward+ g2 review shots for the 5 shipped heists (regression baseline)
- Trunk 59a2924b merged into gpu/renders (merge commit 28dfcd07).
- Command per heist (from repo root): `godot\Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- --heist=<id> --stage=g2 --out=<repo>\docs\levels\<id>\gpu_forward_plus --warmup=120`
- Windowed, Forward+ / Vulkan on RX 9070 XT. No ERRORs or WARNINGs in any run apart from the usual `7 RIDs of type "Texture" were leaked` at shutdown.

| heist | exit | wall | shots |
|---|---|---|---|
| glasshouse | 0 | 27 s | 24 |
| night_deposit | 0 | 35 s | 31 |
| gallery_night | 0 | 32 s | 27 |
| dockside_burn | 0 | 31 s | 27 |
| shadow_ledger | 0 | 28 s | 25 |

- Output: `docs/levels/<id>/gpu_forward_plus/` (shots + contact_sheet.jpg + shots.md). I spot-checked the glasshouse and shadow_ledger contact sheets and they are fully lit with no black frames.

## GPU-4: OF re-render on trunk c04cb710 (round 251)
- Trunk c04cb710 merged into gpu/renders (merge f444436f).
- `--headless --path game --import`: exit 0, 9 s.
- review_shots (same command as GPU-1, `--out=<repo>\docs\levels\ostrander_federal\g2\gpu_r251`): exit 0, 38 s,
  the same 34 shots + contact_sheet as GPU-1, all lit. Warnings: `PresidentSafe` stow warnings, now 4
  (PresidentValuables1/2/3 **and PresidentBonds**, up from 3), plus the usual texture RID leak.
- heist_cast_perf quiet OF (`--heist=ostrander_federal --seed=1037 --detail`): exit 0, 46 s, npcs=29 (guard 10, civilian 19)
  same as GPU-2. Console: `gpu/perf/ostrander_federal_r251.txt`.
- Correction to GPU-1: it was 34 shots (TopDownPlan + 33 rc_*) + contact_sheet, not 35.

**Draw-count delta vs GPU-2 (e960048e -> c04cb710): cast draws went up 50-70% in 5 of 6 views**

| view | draws e960048e (map/cast) | draws c04cb710 (map/cast) |
|---|---|---|
| hall_south_eye | 2088 (1458/630) | 2441 (1424/1017) |
| hall_south_high | 1881 (1287/594) | 2214 (1263/951) |
| hall_west_diag | 2091 (1444/647) | 2493 (1428/1065) |
| rc_hall_entrance | 2157 (1483/674) | 2517 (1444/1073) |
| rc_hall_counter | 2216 (1383/833) | 1752 (1373/379) |
| rc_hall_from_gallery | 1397 (861/536) | 1749 (827/922) |

NPC placement is seeded but animation/tier state at capture time may differ, so check the per-NPC lines in the txt before treating this as a regression.
## GPU-5: C Job A, OF VoxelGI re-bake (tree: env/c-worlds 3c9b2fdf, local branch gpu/of-final)
- `--headless --path game --import`: exit 0.
- `godot\Godot_v4.7.2-stable_win64_console.exe --path game --script res://world/heists/ostrander_federal/greybox/bake_gi.gd`
  (windowed, Vulkan Forward+ on RX 9070 XT): exit 0, 24 s, no ERRORs.
- Output, committed here from gpu/of-final:
  - `ostrander_federal_voxelgi_basement.res`: 1,644,288 octree bytes, err 0
  - `ostrander_federal_voxelgi_ground.res`: 3,895,552 octree bytes, err 0
  - `ostrander_federal_voxelgi_executive.res`: 1,255,712 octree bytes, err 0
- No other files in the tree changed (no .import churn).
## GPU-6: C Job B, OF final shots (tree: env/c-worlds 3c9b2fdf + GPU-5 .res)
1. `review_shots.tscn -- --heist=ostrander_federal --stage=g2 --warmup=60 --out=<repo>\docs\levels\ostrander_federal\g2\final`:
   exit 0, 25 s, 34 shots (TopDownPlan + 33 rc_*) + contact_sheet + shots.md. **No ERRORs or WARNINGs at all**
   (the PresidentSafe stow warnings seen on trunk in GPU-1/GPU-4 are gone on env/c-worlds).
2. `--headless --script res://world/tools/capture/of_burn_variant.gd -- --out=user://of_burn_test.tscn --drops`: exit 0, 6 s,
   `of_burn_variant: wrote user://of_burn_test.tscn (0)`.
3. `review_shots.tscn -- --scene=user://of_burn_test.tscn --warmup=60 --out=<repo>\docs\levels\ostrander_federal\g2\final\burnt --cameras=rc_vault_hole,rc_teller_workroom,rc_terrace,rc_ext_lane`:
   exit 0, 13 s, 4 shots + contact_sheet + shots.md.
- Burnt vs final: all 4 JPEGs differ, but only slightly (rc_vault_hole +7 KB, rc_terrace +2 KB, the other two within 0.1 KB). In the
  contact sheet the changes are subtle (drops/debris at the vault hole and on the terrace), with no obvious scorch/fire look. ENV C should confirm this is the intended look.
- Note: burnt/shots.md says "(g1)" in its title, a cosmetic tool label from the `--scene` path.
## GPU-7: ENV P's section 7 pass on the final OF map (tree: env/c-worlds 3c9b2fdf + GPU-5 .res)
- Per run: `godot\Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1280x720 res://tests/p/_review/of_g1_pass.tscn -- --test=<t> [--pattern=lz_*] --seed=1002 --out=<repo>\gpu\renders\p\of_g2_<name>`
  (stdout+stderr to `gpu/renders/p/of_g2_<name>.txt`; I ran it from PowerShell via Start-Process instead of cmd.exe, with the same args).
- **10/10 PASS**. Every run exited by itself, and none had to be closed.

| run | exit | wall | result |
|---|---|---|---|
| of_g2_laser | 0 | 60 s | [OFP] RESULT PASS (laser PASS) |
| of_g2_laser_static | 0 | 62 s | [OFP] RESULT PASS (laser PASS) |
| of_g2_laser_sweep | 0 | 52 s | [OFP] RESULT PASS (laser PASS) |
| of_g2_laser_timed | 0 | 52 s | [OFP] RESULT PASS (laser PASS) |
| of_g2_throws | 0 | 151 s | [OFP] RESULT PASS (throws PASS) |
| of_g2_fire_escape | 0 | 99 s | [OFP] RESULT PASS (fire_escape PASS) |
| of_g2_hole | 0 | 74 s | [OFP] RESULT PASS (hole PASS) |
| of_g2_dock | 0 | 62 s | [OFP] RESULT PASS (dock PASS) |
| of_g2_fire_exit | 0 | 30 s | [OFP] RESULT PASS (fire_exit PASS) |
| of_g2_burn | 0 | 273 s | [OFP] RESULT PASS (burn PASS) |

- ERROR lines in the logs, none of which failed a test:
  - `It's not expect to not find the most reachable polygons` (Godot navmesh pathing): burn x13, hole x8
  - `Condition "!is_inside_tree()" is true. Returning: Transform3D()`: burn x8
  - `Lambda capture at index 1 was freed. Passed "null" instead.`: throws x4, dock x2, fire_exit x1
- Every run also logs the warning `Sub-surface scattering is not supported in viewports with a transparent background`.

## GPU-8.1: ENV D wave review (tree: env/d-art f96168df, local branch gpu/d)
- Import: exit 0, 9 s.
- `--path game --resolution 1280x720 res://world/characters/_tools/render_d145_wave_review.tscn -- --out=<repo>\gpu\renders\d\wave`:
  exit 0, 486 s (routine 240 s game, hazardous 222 s game), `[D145W] RESULT DONE`. No ERRORs.
- Output: `gpu/renders/d/wave/` (sheet, 2 group shots, 8 unit shots, d145_wave_log.txt).
- **Things for D to check:**
  - `d145_wave_routine_unit1.png` (60 KB) and `routine_unit2.png` (141 KB) frame **no unit**: empty sky/ground gradient.
    `routine_unit3.png` frames an interior door/hand, not the officer. The hazardous unit shots and both group shots look right.
  - `hazardous: 0 of 6 units wear a _duty look` (4 patrol_officer, longshot, tac_light_frd), vs `routine: 4 of 4`.
    If hazardous waves are meant to keep the _duty variant, this is a real miss.
## GPU-8.2: ENV D d145_factions cast review (tree: env/d-art f96168df)
- `--path game --script res://world/characters/_tools/render_d130_cast_review.gd -- --pool=d145_factions`: exit 0, 10 s, no ERRORs/WARNINGs.
- Wrote `_review/d145_police/d145_factions_{sheet,lineup_30m,silhouette_30m}.png`, copied to `gpu/renders/d/factions/` (+ render_log.txt).
  The originals were left uncommitted on env/d-art and removed from my tree.
- Sheet: 7 looks (tac_light_frd/_duty, tac_light_sentinel/_duty, tac_light_zero/_duty, tac_light_duty) x front/back/bust,
  all rendered. Cosmetic: the canvas is 9 columns wide, so the right ~22% is empty.
## GPU-8.3: ENV D of_vip cast review (tree: env/d-art f96168df)
- Same script with `-- --pool=of_vip`: exit 0, 10 s, no ERRORs/WARNINGs.
- Wrote `_review/of_d1_cast/of_vip_{sheet,lineup_30m,silhouette_30m,pair}.png` (these are tracked on env/d-art, so the tree shows them modified;
  I copied them to `gpu/renders/d/vip/` (+ render_log.txt) and restored the env/d-art versions in my tree).
- Sheet: 9 looks (bank_vip_client, security_bodyguard, bank_customer/_b, civilian_customer_a/_b, bank_officer/_b, bank_manager), all rendered.
## GPU-8.4: ENV D OF teller/queue review (QC67) (tree: env/d-art f96168df)
- `--path game --fixed-fps 60 --resolution 1280x720 res://world/characters/_tools/render_of_qc67_review.tscn -- --out=<repo>\gpu\renders\d\queue --no-alarm`:
  exit 0, 19 s, `[QC67] RESULT DONE`.
- Output: `gpu/renders/d/queue/`: 6 shots (tellers_w/e x staff/customer side, teller_counter_profile, queue_w_side), qc67_log.txt, render_log.txt.
- Shutdown ERRORs (engine cleanup, not the review): `1 RID allocations of type 'N10RendererRD15MaterialStorage6ShaderE' were leaked at exit`
  and `1 shaders of type SceneForwardClusteredShaderRD were never freed`.
## GPU-8.5: ENV D heist_cast_perf with frame times (tree: env/d-art f96168df)
- `--audio-driver Dummy --resolution 1920x1080 --path game res://world/characters/_tools/heist_cast_perf.tscn -- <args>`, windowed Forward+ on RX 9070 XT.
  - `--heist=glasshouse --detail`: exit 0, 27 s, npcs=11 (guard 4, civilian 7). **Glasshouse views now work (3).**
  - `--heist=ostrander_federal --seed=1037 --loud --seconds=90 --detail`: exit 0, 153 s, npcs=33 (guard 10, civilian 19, police 4).
- Console: `gpu/renders/d/perf_<heist>.txt`. PNGs: `gpu/renders/d/perf_<heist>/` (only PNGs written during that run; the OF ones now carry a `_loud` suffix, so there's no overwrite).
- No ERRORs.

| heist | view | frame ms avg / max (120 frames) | draws (map, cast) |
|---|---|---|---|
| glasshouse | sales_floor_entrance | 11.36 / 18.14 | 2274 (1640, 634) |
| glasshouse | ext_harlow_corner | 11.10 / 22.33 | 2289 (2102, 187) |
| glasshouse | ext_shopfront | 11.01 / 16.59 | 2829 (2513, 316) |
| OF loud | hall_south_eye | 18.69 / **114.54** | 2637 (1418, 1219) |
| OF loud | hall_south_high | 16.69 / 92.74 | 2476 (1259, 1217) |
| OF loud | hall_west_diag | 19.94 / 105.24 | 2708 (1432, 1276) |
| OF loud | rc_hall_entrance | 20.26 / 104.37 | 2643 (1439, 1204) |
| OF loud | rc_hall_counter | 16.51 / 102.71 | 1580 (1372, 208) |
| OF loud | rc_hall_from_gallery | 15.89 / 86.67 | 2007 (823, 1184) |

- **Read for D-146:** glasshouse holds ~11 ms (about 90 fps) with tight maxes. OF loud averages 16-20 ms (50-60 fps) on this GPU, and every view has
  90-115 ms hitches within 120 frames. Cast draws run 1180-1280 in 5 of 6 views (vs ~600-680 quiet on trunk e960048e in GPU-2).
## GPU-9: ENV B OF full-flow captures at 1080p (tree: env/b-content 2865f510, local branch gpu/b)
- Import: exit 0, 8 s.
- `--audio-driver Dummy --path game --resolution 1920x1080 --script res://tests/b/render/real_input_run_capture.gd -- <repo>\gpu\renders\b\of_real_input_1080 ostrander_federal`:
  exit 0, 53 s, `RUN DONE`. 13 shots in `of_real_input_1080/ostrander_federal/` (heist select -> briefing -> preplanning -> loadout/pickers ->
  in-heist casing/masked -> tab sheet -> payday -> hub). No ERRORs.
- `--audio-driver Dummy --path game --resolution 1920x1080 --script res://tests/b/render/of_run_capture.gd -- <repo>\gpu\renders\b\of_loud_1080 loud`:
  exit 0, 209 s, `OFRUN DONE 6`. 6 shots at both 1920x1080 and 1280x720 (HUD: drill delivery, vault drill, device saw, device thermal, escape wait; payday),
  plus `profiles/profile_0.json(.bak)` written by the run.
  - Payday: $123,200, loud, 9:49, achievements First Score / Bank Holiday / Burn and Hoist.
  - ERRORs: `It's not expect to not find the most reachable polygons` x4 (navmesh). At exit: 43 Texture RIDs, 66 ShapedText RIDs, 4 Font RIDs leaked, and `1 resources still in use at exit`.
- Console logs: `render_log.txt` in each folder. (If any `Â·` appears in a log, it's the UTF-8 middle dot; the log itself is fine.)
## GPU-10: ENV A OF real-menu playthroughs on the final map
- Tree: local branch gpu/a = env/a-core 30a0d429 + merge of env/c-worlds 11227ecb (clean merge, no conflicts; merge base 3c9b2fdf). Import: exit 0, 7 s.
- Command: `--path game --resolution 1280x720 res://tests/a/e2e/po5_runner.tscn -- --po5-flow=<flow> --po5-out=<repo>\gpu\renders\a\<run> --po5-budget=1800 --po5-heist="Ostrander Federal" --po5-difficulty=Routine --po5-seed=<n> [...]`,
  with stdout+stderr in `gpu/renders/a/<run>.log`.

| run | args | exit | wall | verdict |
|---|---|---|---|---|
| of_stealth_18 | `--po5-flow=of_stealth --po5-seed=18` | 0 | 156 s | `RESULT PASS (code 0)` at 155.1 s |
| of_loud_5 | `--po5-flow=of_loud --po5-seed=5 --po5-crew-dmg=0.25` | 0 | 226 s | `RESULT PASS (code 0)` at 225.4 s |

- Stealth route: casing, keycard, vault_gate, lasers, server, time_lock, code_pc, time_lock_wait, secure, vault_loot, code_hint, escape. 4 security officers, no crew downs.
- Loud route: casing, keycard, code_hint, code_pc, server, vault_gate, lasers, drill_delivery, vault_drill, vault_breach, secure, vault_loot, escape_wait, escape.
  32 police spawned, peak 14 alive (patrol 13, tac_light 12, security 4, bulwark 2, longshot 1), no crew downs.
- **Flag for A/C: the loud run logged `ERROR: It's not expect to not find the most reachable polygons` 1,498 times** (Godot navmesh:
  an agent's target is off the navmesh or in a disconnected region). It was 4-21 per run in GPU-7/GPU-9. The stealth run logged none. It may involve
  the new door_nav_clearance.gd from env/c-worlds or police spawn/escape points.
- Exit-only ERRORs in both runs: Texture/ShapedText/Font RID leaks and `1 resources still in use at exit`.
- 13 PNGs per run in `gpu/renders/a/<run>/`.
## GPU-11a: ENV C Job C, OF burnt re-render with the scorch fix (tree: env/c-worlds 4edf7d91, local branch gpu/c2; includes ac0f4ce7 "projected decals on the TW floor and the VT soffit")
- Import exit 0, 6 s. `of_burn_variant.gd -- --out=user://of_burn_test.tscn --drops`: exit 0, 6 s, `wrote user://of_burn_test.tscn (0)`.
- `review_shots.tscn -- --scene=user://of_burn_test.tscn --warmup=60 --out=<repo>\docs\levels\ostrander_federal\g2\final\burnt --cameras=rc_vault_hole,rc_teller_workroom,rc_terrace,rc_ext_lane`:
  exit 0, 12 s. No ERRORs.
- **The scorch decals render but are very faint.** Sizes vs GPU-6: rc_vault_hole +436 B, rc_teller_workroom +98 B, rc_terrace +37 B, rc_ext_lane -23 B.
  At full res, TW shows only a slight darkening of the carpet around the orange burn ring, and VT shows a faint mottled patch on the soffit just right of the hole.
  At contact-sheet scale, both look the same as GPU-6. If the goal is a visible char/scorch, the decal albedo/opacity (or the
  `modulate`/energy against this lighting) probably needs pushing a lot further.
- Output: the 4 burnt JPEGs + contact_sheet + shots.md, replacing the GPU-6 set at the same path.
## GPU-11b: ENV D wave review re-run, framing fix (tree: env/d-art dd3fab52, local branch gpu/d2)
- Import exit 0, 6 s. `--path game --resolution 1280x720 res://world/characters/_tools/render_d145_wave_review.tscn -- --out=<repo>\gpu\renders\d\wave2`:
  exit 0, 483 s, `[D145W] RESULT DONE`. No ERRORs.
- Framing vs GPU-8.1: **routine_unit1 and routine_unit2 now frame their officers** (60 KB / 141 KB -> 880 KB / 861 KB), and the hazardous
  unit0-3 shots all frame officers. **routine_unit3 still frames an interior door/hand, not the officer** (603 KB, same as before).
- Looks: routine 4 of 4 `_duty`, hazardous 0 of 6 `_duty` (the same as GPU-8.1, and consistent with "duty looks on Routine/Tense" in A's 8aea4ae3, so probably intended).
- Output: `gpu/renders/d/wave2/` (sheet, 2 group shots, 8 unit shots, d145_wave_log.txt, render_log.txt).
## GPU-12: ENV A OF loud-hitch hunt on the RX 9070 XT
- Tree: local branch gpu/a2 = env/a-core 767f858b (contains 8e5412e9) + merge of env/c-worlds 761b3f94 (clean). Import exit 0, 7 s.
- `--path game --resolution 1920x1080 res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud --po5-out=<repo>\gpu\renders\a\of_hitch --po5-budget=240 --po5-heist="Ostrander Federal" --po5-difficulty=Cataclysm --po5-seed=1037 --po5-crew-dmg=0 --po5-hitch-ms=50`
  exit 2, 242 s: **`RESULT FAIL (code 2)`, `FAIL budget 240 s exceeded`**.
  - The heist never ended. The pilot lost time on two unreachable objective markers:
    `FINDING objective deposit_boxes: marker at (15.0, -3.0, 13.3) not reachable` (74.4 s) and
    `FINDING objective bond_safe: marker at (14.7, -4.0, 20.5) not reachable` (176.2 s; goto failed 0.0 s in, from (23.3, -0.3, 15.9)).
  - Cataclysm: police=27, peak_alive=15 (security 9, patrol 9, tac_light 7, tac_heavy 1, longshot 1). Crew took 0 damage (crew-dmg=0).
- **No `HITCHES n of m ... worst x ms` line.** po5_flow.gd prints it only from the `heist_ended` handler (l.70-73), and on a budget exit
  the heist never ends. A should also print it from the budget/_finish path. Derived from the per-hitch lines instead:
  **26 heist frames over 50 ms, worst 2264 ms** (total heist frame count not printed).
- Hitches by frame ms (t = heist time): 2264 @0.1, 865 @1.2, 905 @6.4, 940 @106.6, 843 @213.4, 601 @214.6, 273 @3.9, 147 @0.3, 136 @4.1,
  100 @175.7, 92 @129.6, 90 @3.8, and 14 more between 50 and 90 ms. The first ~7 s are heist-start spikes; the real loud-phase ones are 940 @106.6 and 843/601 @213-215.
- 5 worst HITCH lines:
    [PO5 23.2s] HITCH frame=2264ms t=0.1 process=49.2ms physics=63.3ms draws=2747 objects=3460 nodes=19025 enemies=9 spawned=[] top: anim_driver=24.6ms(30) npc_motor=8.0ms(216) stealth_director=1.5ms(8) civilian_brain=1.0ms(144) custody_system=0.9ms(8) crew_ai_brain=0.8ms(24) guard_brain=0.3ms(72) guard_brain.calm=0.1ms(72)
    [PO5 132.1s] HITCH frame=940ms t=106.6 process=11.3ms physics=25.3ms draws=650 objects=1294 nodes=19056 enemies=10 spawned=[] top: npc_motor=9.8ms(208) crew_ai_brain=8.8ms(24) police_brain=5.2ms(72) anim_driver=3.5ms(29) hud_model=1.3ms(1) hud_model.flush=0.7ms(1) assault_director=0.4ms(8) hud_model.objectives=0.3ms(1)
    [PO5 31.1s] HITCH frame=905ms t=6.4 process=48.1ms physics=60.8ms draws=2230 objects=2977 nodes=19241 enemies=11 spawned=[] top: npc_motor=14.2ms(232) crew_ai_brain=5.2ms(24) anim_driver=1.6ms(32) civilian_brain=0.9ms(144) hud_model=0.7ms(1) door=0.6ms(24) guard_brain=0.4ms(72) hud_model.objectives=0.3ms(1)
    [PO5 25.0s] HITCH frame=865ms t=1.2 process=23.5ms physics=23.9ms draws=2832 objects=4190 nodes=19044 enemies=9 spawned=[] top: npc_motor=6.3ms(216) anim_driver=1.5ms(30) stealth_director=1.0ms(8) crew_ai_brain=0.7ms(24) civilian_brain=0.5ms(144) guard_brain=0.2ms(72) custody_system=0.1ms(8) npc_gunner=0.1ms(72)
    [PO5 239.5s] HITCH frame=843ms t=213.4 process=4.2ms physics=23.6ms draws=1719 objects=2768 nodes=18598 enemies=5 spawned=[] top: npc_motor=7.0ms(168) crew_ai_brain=6.8ms(24) hud_model=1.5ms(1) anim_driver=1.0ms(24) hud_model.flush=0.8ms(1) police_brain=0.4ms(32) hud_model.objectives=0.4ms(1) civilian_brain=0.3ms(128)
- ERRORs: `most reachable polygons` x14, `!is_inside_tree() ... Transform3D()` x5, `Playback can only happen when a node is inside the scene tree` x1,
  `6 resources still in use at exit`.
- Output: `gpu/renders/a/of_hitch.log` + 10 PNGs in `gpu/renders/a/of_hitch/` (menu -> heist start -> auto_6/106/213 -> budget_exceeded).
### Fix-up: GPU-10 and GPU-12 logs
- `*.log` is in .gitignore, so `gpu/renders/a/of_stealth_18.log`, `of_loud_5.log` (GPU-10) and `of_hitch.log` (GPU-12) were skipped by
  their commits. They're force-added now. Future logs will be force-added or saved as `.txt`.
## GPU-13: shader-cache test, GPU-12's command x2 more, back to back, cache kept
- Same tree (gpu/a2 33b80e6e), same command as GPU-12, outputs `gpu/renders/a/of_hitch_run2{,.txt}` and `of_hitch_run3{,.txt}`.
  Both runs: exit 2, 242 s, `RESULT FAIL (code 2)` budget, with the same two unreachable FINDINGs (deposit_boxes, bond_safe). No HITCHES line (budget exit, see GPU-12).
- Caveat: run 1 (GPU-12) was not a truly cold cache. OF loud had already run on this machine many times (GPU-2/4/8/10).

| run | frames > 50 ms | of which t < 8 s (load/start) | worst 5 (ms @ t) |
|---|---|---|---|
| 1 (GPU-12) | 26 | 11 | 2264 @0.1, 940 @106.6, 905 @6.4, 865 @1.2, 843 @213.4 |
| 2 | 32 | 12 | 2448 @0.1, 944 @106.6, 936 @6.3, 910 @1.2, 860 @213.8 |
| 3 | 24 | 8 | 2266 @0.1, 940 @106.6, 923 @6.3, 879 @1.2, 842 @214.3 |

**Verdict: not first-use shader compiles.** Runs 2/3 are no smoother, and the big hitches repeat at the same game time to within about 1 s.

**What they actually are: the runner's own screenshots.** Every frame of 500 ms or more, except the t=0.1 heist-load frame, lands on the same wall-clock instant
(within 0.1 s) as a po5 `shot` line, in all 3 runs:

| hitch (run 1/2/3, ms) | t | coincident shot |
|---|---|---|
| 865 / 910 / 879 | 1.2 | 06_heist_start |
| 905 / 936 / 923 | 6.3-6.4 | 07_auto_6 |
| 940 / 944 / 940 | 106.6 | 08_auto_106 |
| 843 / 860 / 842 | 213.4-214.3 | 09_auto_213/214 |
| 601 / 576 / 615 | 214.4-215.6 | 10_budget_exceeded |

Their process+physics is only 30-50 ms. The other ~850 ms is the synchronous 1920x1080 viewport readback + PNG encode/save in the harness.
**Without screenshots, the worst loud-phase frames are about 90-110 ms** (run1 100 @175.7 / 92 @129.6; run2 108 @176.2 / 106 @129.6; run3 94 @129.6 / 89 @176.7).
Those repeat at about t=129.6 and t=176 in every run, so they are deterministic and worth A's profiling (t=176 is when the pilot fails `bond_safe`).
Suggestions for A: exclude frames that take a screenshot from HITCH (or log `shot=1`), and print HITCHES on budget exit too.
## GPU-14: ENV C scorch round 2 (tree: env/c-worlds 595f57fe, contains f2dab548; local branch gpu/c3)
- Import exit 0, 7 s. `of_burn_variant.gd -- --out=user://of_burn_test.tscn --drops`: exit 0, 6 s.
- `review_shots.tscn -- --scene=user://of_burn_test.tscn --warmup=60 --out=<repo>\docs\levels\ostrander_federal\g2\fix\burn_scorch --cameras=rc_vault_hole,rc_teller_workroom`:
  exit 0, 12 s, no ERRORs. Output: `docs/levels/ostrander_federal/g2/fix/burn_scorch/` (2 JPEGs, contact_sheet, shots.md, render_log.txt).
- Mean luminance vs the GPU-11a burnt shots (same camera, same pixels):
  - **rc_vault_hole soffit around the hole (x650-1300, y380-620): 37.1 -> 34.8 (-6%).** A soot halo around the opening is now visible at full res,
    mostly to the right of and below the glowing rim. Still subtle at contact-sheet scale.
  - **rc_teller_workroom floor around the burn ring (x850-1150, y560-640): 55.7 -> 55.4 (no visible change).** The TW floor scorch still doesn't show
    from this camera. It's about 25 m away at a grazing angle on dark navy carpet. Either the decal needs to be much darker/larger, or a closer TW camera is needed to judge it.
## GPU-15: confirm A's nav fix (OF-done blocker)
- Tree: local branch gpu/a3 = env/a-core ffc264d4 ("NavPath.query: path queries without Godot 4.7's 4096-polygon search cap") + merge of env/c-worlds 595f57fe (clean). Import exit 0, 6 s.
- Same command as GPU-12 with `--po5-out=<repo>\gpu\renders\a\of_hitch_navfix`; log `gpu/renders/a/of_hitch_navfix.txt`.
- **RESULT: `[PO5 241.0s] RESULT FAIL (code 2) flow=auto_loud heist=Ostrander Federal seed=1037`** (`FAIL budget 240 s exceeded`), but for a different reason than GPU-12 (below).
- **Nav fix confirmed:**
  - `"most reachable polygons"` ERRORs: **0** (GPU-12: 14; GPU-10 Routine loud: 1,498).
  - `FINDING ... deposit_boxes ... not reachable`: **gone**. `FINDING ... bond_safe ... not reachable`: **gone**.
  - The pilot now gets much further: DockPersonnelDoor, StairDoorSAB, RecordsDoor, thermal drill parts x2 -> LidDrill placed at 151.0 s and again at 186.9 s.
- **New blocker at the bond safe (why the budget still ran out):**
  - `[PO5 222.8s] pilot: goto (15.9, -3.8, 20.5) FAILED at (13.2, -4.0, 20.1) after 2.1 s`, i.e. the path now exists but ends about 2.7 m short.
  - Then from 223.4 s to the 240.7 s budget, 44x `pilot: use place_drill re-press skipped: aimed <none> (dist 2.22, angle 0.0 deg)`:
    the pilot is 2.22 m from BondSafe/Interactable and facing it, but its aim ray hits no interactable (out of reach/occluded, or the collider sits behind the safe body).
  - Also, 240 s may be tight for a full Cataclysm loud run even when it's clean (GPU-10's Routine loud PASS took 225 s).
- **Frames > 50 ms, excluding the 4 po5 shot frames: 9** (GPU-12 equivalent: 22 non-shot). Of these, 6 are heist start (t < 8 s: 2181 @0.1, 137 @0.3,
  85 @3.8, 85 @5.7, 60 @5.6, 59 @2.0). **Loud phase: only 3, worst 69 ms @163.1, 62 @139.9** (and one more at 50-59 ms). The 90-110 ms ones at t≈130/176 from GPU-13 are gone.
- Other ERRORs: `!is_inside_tree() ... Transform3D()` x5, `Playback can only happen when a node is inside the scene tree` x1, `6 resources still in use at exit`.
- 10 PNGs in `gpu/renders/a/of_hitch_navfix/`.
## GPU-16: OF scorch round 3 (RENDER_SPLIT Job C)
- Tree: env/c-worlds e3107aed (contains 37ab4ce1 "rc_burn_close review camera on the TW burn spot; paler TW ash ring" and d10a885e), local branch gpu/c4. Import exit 0, 8 s.
- `of_burn_variant.gd -- --out=user://of_burn_test.tscn --drops`: exit 0, 8 s. Then `review_shots.tscn -- --scene=user://of_burn_test.tscn --warmup=60
  --out=<repo>\docs\levels\ostrander_federal\g2\fix\burn_scorch_r3 --cameras=rc_burn_close,rc_teller_workroom,rc_vault_hole`: exit 0, 18 s, no ERRORs. Forward+ 1920x1080.
- Output: `docs/levels/ostrander_federal/g2/fix/burn_scorch_r3/` (3 JPEGs, contact_sheet, shots.md, render_log.txt).
- **rc_burn_close: the TW scorch reads clearly now.** It shows a large dark soot/char bloom on the navy carpet all round the cut, heaviest on the near and
  right sides, with the glowing cut rims and the thermal drill on its tripod in frame. The char is dark, not a pale ash ring; any pale ring isn't noticeable against the soot.
- rc_teller_workroom (the long view): floor around the ring 55.4 (GPU-14) -> 56.0, i.e. still no visible change at that distance. rc_burn_close is the camera to judge the scorch by.
- rc_vault_hole soffit: 34.8 -> 34.8 (unchanged from GPU-14; the round-2 soot halo is still there).
## GPU-17: OF done-assessment baseline on trunk e9c8744f (round 255)
- Trunk checkout fast-forwarded to e9c8744f (exactly). Import exit 0, 10 s.
- Same command/seed/difficulty as GPU-15 (auto_loud, Cataclysm, seed 1037, crew-dmg 0, hitch-ms 50, budget 240, 1920x1080 windowed Forward+).
  Log `gpu/renders/a/of_r255.txt`, 9 PNGs in `gpu/renders/a/of_r255/`.
- **RESULT: `[PO5 241.2s] RESULT FAIL (code 2)`**, `FAIL budget 240 s exceeded`.
- **Nav errors ("most reachable polygons"): 0.** No unreachable FINDINGs.
- **BondSafe still fails**, now with A's LOS diagnostic: `goto (15.9, -3.8, 20.5) FAILED at (13.2, -4.0, 20.1)` at 237.6 s, then
  `aimed <none>, wanted .../Loot/BondSafe/Interactable (dist 2.21, angle 0.0 deg, avail '', LOS ray hit /root/HeistRuntime/OstranderFederal/Geometry/Building/Walls/FloorB/BZ0140_1_00 at (13.7, -2.6, 20.3))`.
  **A wall segment (FloorB/BZ0140_1_00) sits between the pilot's stop point and the safe's interactable.** The pilot reached it later than in GPU-15 (237.6 s vs 222.8 s), so only 7 re-press attempts happened before the budget.
- **Hitches > 50 ms: 81 total; 7 are po5 shot frames; 74 non-shot (15 at heist start, t < 8 s; 59 in the loud phase).** GPU-15 had 9 non-shot (3 loud).
  - Non-shot worst: 3193 @0.1 (heist load), 191 @0.3, 148 @94.9, 142 @162.2, 127 @5.8, 124 @139.1, 113 @95.1, 106 @139.2.
  - Shot frames for reference: 948 @1.2, 965 @6.4, 926 @127.3, 346 @207.2.
- **Max frame time:** 3193 ms (heist load, t=0.1). Loud phase, excluding shots: 148 ms. Per-10 s TEL worst_frame (t=22..202):
  68, 45, 63, 90, 91, 95, 61, 51, 148, 48, 75, 926 (shot), 124, 47, 47, 142, 53, 44, 40 ms
  (GPU-15: 33, 44, 30, 35, 50, 44, 43, 33, 59, 32, 45, 857 (shot), 62, 40, 31, 69, 43, 30, 31 ms).
- **This is a CPU regression vs GPU-15 (A ffc264d4 + C 595f57fe), not more enemies.** TEL averages over t >= 20 s:
  physics 36.8 ms avg / 86.0 max (GPU-15: 22.7 / 29.9); process 14.5 / 31.9 (GPU-15: 6.5 / 18.6). Enemies are the same (avg 8.7 vs 8.8, peak 15, police=24 both runs).
  Top contributor in the 62 loud-phase HITCH lines: `anim_driver` 34x, `npc_motor` 21x, crew_ai_brain 4x, police_brain 3x. The heist-load frame has anim_driver=86.2 ms (GPU-12: 24.6).
- **Draw calls:** po5 has no main/total split. The only draw figure it logs is `draws=` on HITCH lines (the frame's total render draws).
  For the 59 loud-phase non-shot hitch frames: min 352, max 2688, avg 929. The heist-load frame: 2747 draws, 3460 objects. For a map/cast split, heist_cast_perf (GPU-8.5 style) would be needed.
## GPU-17b: control, GPU-15 tree vs trunk e9c8744f back to back
- **Machine state** (before the runs, 03:0x local): power plan **Balanced** (381b4222...); i9-12900K 16C/24T, 32 GB (9.4 GB free); RX 9070 XT.
  Temps can't be read without admin/vendor tools. During the runs the CPU ran at about 143% of base clock (turbo), so it wasn't throttled at that moment.
  I did not close the owner's apps (not mine to close). **Background load on this PC, from other local sessions/apps:**
  - 1 python.exe pinned at 100% of a core since 2026-10-16 (stdin script); Chrome about 1-1.2 cores; Steam; Defender; about 15 long-running `grep --line-buffered` log watchers.
  - **From 03:14:28, another local session's `tools/slot.mjs run -- py -3 -I tools/an3_scale_survey.py --jobs 4`** (4 worker processes at about 100% each, 20-min timeout),
    plus a recursive `grep -rhoi` at 03:17. Total CPU was 35-40% (about 9 of 24 threads busy) right after the runs.
- Runs (same command as GPU-15/17), one straight after the other: (1) gpu/a3 2fd5d066 = GPU-15's exact tree, 03:09-03:13; (2) trunk e9c8744f, 03:14-03:18
  (it **started the same minute as the 4-worker survey**). Both `RESULT FAIL (code 2)` budget, 0 nav errors.
  Logs/PNGs: `gpu/renders/a/of_17b_gpu15tree{,.txt}`, `gpu/renders/a/of_17b_r255{,.txt}`.

| run | when | TEL phys avg/max (t >= 20 s) | TEL proc avg/max | enemies avg | non-shot frames > 50 ms (t < 8 / loud) | loud worst (ms @ t) |
|---|---|---|---|---|---|---|
| GPU-15 original (gpu/a3) | 01:28 | 22.7 / 29.9 | 6.5 / 18.6 | 8.8 | 9 (6 / 3) | 69 @163.1, 62 @139.9, 59 @95.8 |
| GPU-17 original (e9c8744f) | 02:19 | 36.8 / 86.0 | 14.5 / 31.9 | 8.7 | 74 (15 / 59) | 148 @94.9, 142 @162.2, 124 @139.1 |
| **17b (1) GPU-15 tree** | 03:09 | **30.0 / 39.2** | **11.9 / 27.0** | 9.2 | **107 (14 / 93)** | 279 @34.2, 251 @34.7, 235 @34.1 |
| **17b (2) e9c8744f** | 03:14 | **45.8 / 109.7** | **17.4 / 47.3** | 8.5 | **210 (12 / 198)** | 181 @60.5, 158 @162.0, 147 @94.7 |

**Verdict: A is right, it's machine state, not code.** GPU-15's exact tree, re-run now, is much worse than its own original run (9 -> 107 non-shot hitches, phys 22.7 -> 30.0 ms),
which is worse than the original GPU-17 run at r255. The metrics track background CPU load, which has been rising over the night (the r255 control overlapped a 4-process
CPU-bound survey and is the worst of all). The GPU-17 "regression" (vs GPU-15) is not evidence of a code change.
**Caveat for GPU-18 and future perf numbers:** this box is shared with other sessions' CPU jobs. I'll log the background CPU load next to each perf run. Only a GPU-15 vs GPU-18
comparison made under similar load is meaningful; ideally both trees get re-run back to back when the box is idle.
## GPU-18: OF loud on trunk 3312326b (round 256: board line) + same-load control
- Trunk fast-forwarded to 3312326b. Same command as GPU-15/17 (auto_loud, Cataclysm, seed 1037, crew-dmg 0, hitch-ms 50, budget 240, 1920x1080 windowed Forward+).
- **Box load:** another local session's `an3_scale_survey.py --jobs 4`, node test runners (val_server, a2_test, b3_test) and the long-running python were all active.
  CPU sampled every 5 s across both 240 s runs (`gpu/renders/a/of_r256_cpu_load.txt`): **avg 32.7%, min 16.6, max 55.7**. So I re-ran GPU-15's tree (gpu/a3) right after r256 as a same-load control.
- Logs/PNGs: `gpu/renders/a/of_r256{,.txt}`, `of_18_gpu15tree{,.txt}`, `of_r256_b480{,.txt}`.

| metric | **r256 (3312326b)** | control: GPU-15 tree, same load | GPU-15 original (01:28, quiet box) |
|---|---|---|---|
| RESULT | FAIL (code 2), budget 240 | FAIL (code 2), budget 240 | FAIL (code 2), budget 240 |
| nav errors ("most reachable") | **0** | 0 | 0 |
| po5 `HITCHES` line | `48 of 43846 heist frames over 50 ms (3 of them screenshot frames), worst 3133 ms, without a shot 3133 ms` | (old po5, no line) | (old po5, no line) |
| non-shot > 50 ms: total / t < 8 s / loud | **45 / 12 / 33** | 110 / 10 / 100 | 9 / 6 / 3 |
| max frame | 3133 ms (heist load, t=0.1) | 2750 ms (heist load) | 2181 ms (heist load) |
| loud worst, non-shot (ms @ t) | **129 @175.3, 125 @147.6, 123 @77.5** | 266 @98.8, 228 @99.2, 194 @98.6 | 69 @163.1, 62 @139.9 |
| TEL phys avg/max (t >= 20 s) | **20.0 / 26.3 ms** | 33.4 / 63.6 | 22.7 / 29.9 |
| TEL proc avg/max | **9.6 / 24.1 ms** | 11.3 / 27.4 | 6.5 / 18.6 |
| draws on loud-phase hitch frames min/avg/max | 986 / 1466 / 2628 | 648 / 1388 / 2842 | n/a |

- **r256 vs the control under the same load: clearly better** (physics -40%, loud-phase hitches 33 vs 100, worst 129 vs 266 ms). So A's anim fix pays off.
  The heist-load frame is still 3.1 s, with `anim_driver=115.2ms(30)` and 78 surface + 49 specialization pipeline compiles in that frame (the new HITCH `pipelines=` field).
  Pipeline compiles in the loud phase are rare (spec+2 @103.8, spec+3 @175.4).
- **Draw calls (main vs total):** po5 still logs only `draws=` (the frame total) on HITCH frames, so there's no main/total split (see above).
- **BondSafe: not reached in r256, so A's marker fix is unverified.**
  - In the 240 s run the heist only started at 49.5 s wall (it was 23-31 s on a quiet box). The pilot did both LidDrill placements (185.8 s, 225.5 s) and the budget ran out before BondSafe. No `aimed <none>`/LOS lines.
    The control (old tree) did reach BondSafe and failed as before: `LOS ray hit .../Walls/FloorB/BZ0140_1_00 at (13.7, -2.5, 20.x)`, dist 2.02.
  - **Extra run, r256 with `--po5-budget=480`** (my addition, to reach BondSafe): `RESULT FAIL (code 2)` budget 480. **This time the pilot took a different route and never went for BondSafe**
    (0 mentions). It did PresidentSafe (place_drill 281 s, fix_drill 368 s, objective president_safe -> 2 at t=424), ServerDrives secured (t=307), LidDrill again (407 s).
    It got STUCK on the SAFlight2W stair, blocked by police (Npc_police13/14), 4 times between 353 and 390 s, and had 4 `goto (3.5, 0.2, -4.3) FAILED` at 322-335 s.
    `HITCHES 1560 of 35747 heist frames over 50 ms (9 screenshot), worst 2755 ms`. The hitches pile up after t=240 (338 / 428 / 477 per minute)
    with 26-29 enemies alive and box CPU at 59% at the end. That's not comparable to the 240 s runs.
  - So A's BondSafe fix needs a run where the pilot actually goes there. Seed 1037's route on r256 doesn't reach it within 240 s on this box, and the 480 s route skipped it.
- Recommendation: re-run r256 (240 s and a longer budget) when the box is idle, for clean perf numbers. For BondSafe, a po5 flag or flow that targets it directly would avoid route variance.
## GPU-19: full OF loud proof attempt (A's new pilot work)
- Tree: local branch gpu/a5 = trunk 18f9b5ff + merge of env/a-core 0210e889 (clean, merge c35bcdd2). Import exit 0, 28 s.
- Same command as GPU-18 with `--po5-budget=1500`. Ran 04:50:14-05:15:17. Log `gpu/renders/a/of_a5_b1500.txt`, 26 PNGs in `gpu/renders/a/of_a5_b1500/`.
- **RESULT: `[PO5 1501.8s] RESULT FAIL (code 2) flow=auto_loud heist=Ostrander Federal seed=1037`** (`FAIL budget 1500 s exceeded`). The phase never left LOUD.
- **Objective EVENTs** (t = heist time): casing 2 @3; keycard, code_hint, code_pc, server, vault_gate, lasers 1->2 @6; vault_drill 1 @51; drill_delivery 2 @147;
  server_drives secured @311 and @450 (objective server_drives -> 2 @450); **president_safe -> 2 @422**; **vault_drill -> 2, vault_breach -> 2 @562**, which made
  **`bond_safe -> 1`**, deposit_boxes -> 1, vault_loot -> 1, gold_cage -> 1 available @562; cash_bricks secured @646 and @650 (secure -> 1).
  **No objective event after t=650** (the last 850 s of the run). **bond_safe never got past 1**, and the pilot never targeted BondSafe (no BondSafe/aimed lines).
- **Where it stalled: bagged vault loot can't get out of the basement.**
  - The pilot bags VaultCash in the vault and calls the Hoist. 3 hoist sends happened, each `Hoist: lift 0 -> 1 with 1 bag(s)`, but no loot_secured follows any of them,
    so nobody takes the bag off the top landing.
  - From 1163 s: `FINDING a bag to take up a ladder and no hoist landing within 15 m (or 6 tries spent)`, then **331x `pilot: RopeLadder ahead with a bag: not climbing (the bag goes by the hoist)`**
    once a second, from 1163 s until the budget ran out at 1500 s. The pilot is stuck at the ladder with a bag.
  - Crew bag-carry: `FINDING slot N carries loot.cash_bricks: leading it to the secure zone` x4, and the leading goto to the secure zone keeps failing at the same spot:
    `goto (3.5, 0.2, -4.3) FAILED at (4.6, 0.0, -1.2) after 10.0 s` (752.9 s, 891.7 s, 1030.5 s; also at 493 s from (8.0, 0.0, -1.0)).
- **STUCK: 15** (mostly police bodies in the path, e.g. `rays: ... Npc_police@(8.1, 0.1, 1.2)` around 705-716 s), with detours.
  **FAILED gotos: 7** (the 5 secure-zone ones above, plus `(25.6, 0.2, 14.6) FAILED at (14.1, 5.0, 7.8) after 20.2 s` @541.5 and `(30.4, -3.8, 19.0) FAILED at (28.1, -4.0, 18.9)` @646.5,
  then `could not reach .../Loot/VaultGold/Interactable (bag_loot)`).
  **"blocks the way": 2** (`Npc_police blocks the way: shoot` @523.6 and @713.2). Empty-mag melee: 1 (`Npc_police in reach with an empty mag: melee` @542.1). A's new engage logic fires.
- **HITCHES:** `HITCHES 778 of 231088 heist frames over 50 ms (20 of them screenshot frames), worst 2789 ms, without a shot 2789 ms` (heist load).
  0.34% of frames over 50 ms across 25 min. Cataclysm escalated to police=67, peak 29 alive (13 bulwark, 2 longshot, corpsman, brandt).
- **CPU load** (5 s samples over the run, `gpu/renders/a/of_a5_b1500_cpu_load.txt`): **avg 29.5%, min 10.5, max 62.9**. Other local sessions' jobs were sharing the box.
  No same-load control: a second 25-min run of an older tree wouldn't reach these phases (BondSafe/vault) anyway. Treat the HITCHES figure as measured under about 30% background load.
## GPU-20: NOT COMPLETED, run stopped at 670 s wall (PC low on memory)
- Tree: local branch gpu/a6 = env/a-core 7c7a014b (contains 7d2cd968). Import exit 0, 28 s. Command as specified (auto_loud, seed 1037, budget 1800, Cataclysm, crew-dmg 0, hitch-ms 50, 1920x1080).
- **The run was killed at about 670 s wall (heist t of about 618) by Claude Code's background-process reaper, because the PC was critically low on memory.**
  This wasn't a Godot/game failure. Godot exited with it, and there's no RESULT line. Afterwards RAM free was 5.9 of 31.8 GB, with Chrome tabs about 6.8 GB and other sessions using the rest.
  **I'm not re-running until the owner OKs it** (memory may still be short).
- Partial log/PNGs: gpu/renders/a/of_a6_b1800_partial{,.txt}. CPU load over the partial run: avg 36.1%, min 18.2, max 49.3 (of_a6_b1800_partial_cpu_load.txt).
- Timeline reached (heist t): same opening as GPU-19 (casing @3, keycard/codes/server/vault_gate/lasers @6, drill_delivery 2 @148); server_drives secured @310 and @497 (-> 2);
  **president_safe -> 2 @510; vault_drill/vault_breach -> 2 @559; bond_safe, deposit_boxes, vault_loot, gold_cage -> 1 @559**; vault_loot -> 1 @618. The run ended before the hoist/secure stage that GPU-20 was meant to test.
## GPU-20b: NOT STARTED, PC out of memory (waiting for the owner)
- Tree ready: local branch gpu/a6b = env/a-core d9dddd87. 7 GB free-RAM gate per the LEAD.
- The gate saw free RAM fall from 7.4-9.0 GB (07:21-08:01) to **4.7 GB at 08:09**, so the run was still waiting at the gate. Then Claude Code's low-memory reaper stopped the waiting job too.
  **Godot never launched; no import, no run.** Free RAM afterwards: 3.6 of 31.8 GB. Biggest users by process name: chrome 11470 MB, claude 2737 MB, svchost 1474 MB, Spotify 1367 MB, node 1245 MB.
- Per the reaper's rule and the LEAD's, I won't retry until memory recovers (>= 10 GB free after a kill). I'm flagging it to the owner, since the memory is going to their apps and other sessions, which I won't close.
## GPU-20b: full OF loud run on env/a-core 0cb810a5: everything done up to escape_wait; FAIL code 1 = po5 heist-time cap
- Tree: local branch gpu/a6b = env/a-core 0cb810a5 ("merge trunk into env/a-core (regression sweep base)"). The RAM gate (8 GB, every 5 min) passed at 12:27:44 (8.8 GB free)
  once the W101 session paused its browser jobs. Import exit 0, 28 s. Run 12:28:12-12:54:16, same command as GPU-20 (budget 1800).
  Log `gpu/renders/a/of_a6b_b1800.txt`, 26 PNGs, load log `of_a6b_b1800_load.txt` (CPU avg 19.4%, max 29%; free RAM 4.8-12.3 GB during the run, no reaper).
- **RESULT: `[PO5 1562.8s] RESULT FAIL (code 1) flow=auto_loud heist=Ostrander Federal seed=1037`.** This is not the wall budget:
  `[PO5 1562.1s] FAIL no heist end within 1500 s; markers ["deposit_boxes" x20, "escape_wait"]`. po5's heist-time cap (1500 s heist time) hit 29 s after escape_wait started.
- **Objective timeline (heist t):** casing 2 @3; keycard/code_hint/code_pc/server/vault_gate/lasers 2 @6; vault_drill 1 @51; drill_delivery 2 @149;
  server_drives secured @325 and @461 (-> 2); **president_safe 2 @437**; **vault_drill/vault_breach 2 @577** (bond_safe/deposit_boxes/vault_loot/gold_cage -> 1);
  cash_bricks secured @675, 1143, 1211, 1274, 1328 (**5 cash**); **vault_loot 2 @1288**; **gold_cage 2 @1355**; **bond_safe 2 @1435**;
  **gold secured @1471 -> secure 2, escape_wait 0 -> 1 @1471**. Deposit boxes were never done (still a marker at the end).
- **loot_secured: 8** (server_drives x2, cash_bricks x5, gold x1).
- **Hoist works now:** the bags left the vault (contrast GPU-19's 331x ladder loop). There were 9 `RopeLadder ahead with a bag` lines, but no stall.
- **STUCK 19** (blockers named on 9: Npc_police 7, Crew 1, wall FloorE/EX0070_2 1). **FAILED gotos 5:** 3 short ones near (7-9, 0, 1.5) @516-527 s while police blocked;
  `goto (24.0, -3.8, 19.0) FAILED at (24.0, 0.0, 18.9) after 60.0 s` -> `could not reach .../VaultCash/Interactable` @583.9 (a 60 s stall above the vault);
  `goto (30.4, -3.8, 19.0) FAILED at (28.2, -4.0, 18.8) after 45.2 s` -> `could not reach .../VaultGold/Interactable` @634.1 (both later succeeded).
  **"blocks the way": 2** (Npc_police12 @327.9, Npc_police2 @523.9). FINDING x3 (crew leading cash to the secure zone; these worked this time, the cash got secured).
- **HITCHES:** `143 of 309031 heist frames over 50 ms (20 of them screenshot frames), worst 2935 ms, without a shot 2935 ms` (heist load). 0.046% of frames
  (GPU-19: 0.34% at about 30% CPU load; this run had about 19% load). Cataclysm: police=67, peak 28 alive. Pilot intake: 0 dmg (crew-dmg 0).
- **Suggestion:** the heist reached escape_wait with all main objectives done. A po5 heist-time cap above 1500 s (or the escape van arriving sooner) should give the
  first full PASS. Deposit boxes remain the one objective the pilot never attempts.