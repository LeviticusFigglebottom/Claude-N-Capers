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