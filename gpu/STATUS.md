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