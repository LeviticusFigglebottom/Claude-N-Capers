# Ostrander Federal: G2 render jobs (OF-C2, ENV C)

Run these **after** the final-stage switch lands on trunk (`game/world/heists/ostrander_federal/stage.txt` = `final`,
GI re-baked). ENV C will announce the sha. All commands run from the repo root, on a tree at that sha, after one
`godot --headless --path game --import`. Godot 4.7.2.

Where each job runs:
1. The PO's GPU box first (Remote Control session; push outputs to the `gpu/renders` branch).
2. Fallback: the env boxes (A / B / C / D), one group each (split below), with xvfb + llvmpipe, opengl3 only, slow.

## Renderer modes

The project sets no `rendering_method`, so a real GPU runs **Forward+** by default. That's the shipped look: VoxelGI,
SSIL, volumetric sun shafts, reflection probes.

The env boxes have no GPU, so they force **Compatibility**, the low-end path that D-146 budgets against:
`--rendering-method gl_compatibility --rendering-driver opengl3`.

| Job | GPU box | Env box fallback |
|---|---|---|
| Review shots (34) + g2/d | **Forward+** (the look the PO sees); also Compatibility, to show the low-end look | Compatibility only |
| D-146 perf captures | **Compatibility** (what the budget measures) **and** Forward+ (frame times) | Compatibility only |

`<OUT>` below is an absolute path inside the repo; the tool writes `<camera>.jpg`, `contact_sheet.jpg` and `shots.md`.

## 1. The 34 review shots

The cameras are `HeistMap.review_cameras` in the generated scene: `TopDownPlan` (the doc's `rc_top_down`) plus 33 `rc_*`.

GPU box, Forward+ (one run, all cameras):

    godot --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- \
      --heist=ostrander_federal --stage=g2 --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final/forward_plus

GPU box, Compatibility (the same, for the low-end look):

    godot --rendering-method gl_compatibility --rendering-driver opengl3 --path game --resolution 1920x1080 \
      res://world/tools/review_shots.tscn -- --heist=ostrander_federal --stage=g2 --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final/compatibility

Env-box fallback: one group per env, xvfb, Compatibility, about 5-20 min per shot on llvmpipe:

    LC_DRIVER=opengl3 xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy \
      --rendering-method gl_compatibility --rendering-driver opengl3 --path game --resolution 1920x1080 \
      res://world/tools/review_shots.tscn -- --heist=ostrander_federal --stage=g2 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final/compatibility --cameras=<group>

| Group | Env | Cameras |
|---|---|---|
| 1 | C | TopDownPlan,rc_ext_plaza,rc_ext_lane,rc_ext_tannery,rc_terrace,rc_roof,rc_sniper_assay,rc_hall_entrance,rc_vestibule |
| 2 | D | rc_hall_counter,rc_hall_from_gallery,rc_atm,rc_teller_workroom,rc_client_lounge,rc_manager_office,rc_loan_office,rc_back_corridor |
| 3 | B | rc_security_room,rc_loading_dock,rc_break_room,rc_officers,rc_operations,rc_vault_ops,rc_server_room,rc_president |
| 4 | A | rc_exec_lounge,rc_boardroom,rc_basement_corridor,rc_concourse,rc_vault,rc_deposit_hall,rc_count_room,rc_records |

`rc_vault_hole` is the 34th shot. It shows the burnt state, so it needs the test-only variant scene first (job 2).
Each group writes its own `contact_sheet.jpg`. ENV C merges the groups and rebuilds one sheet with `--cameras=` over
the full list (no re-render) when they land.

## 2. The burnt-hole shot (rc_vault_hole) + the drops

    godot --headless --path game --script res://world/tools/capture/of_burn_variant.gd -- \
      --out=user://of_burn_test.tscn --drops
    godot --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- \
      --scene=user://of_burn_test.tscn --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final/forward_plus \
      --cameras=rc_vault_hole,rc_teller_workroom,rc_terrace,rc_ext_lane

The last three show the heli drop over the terrace and the second van in Ledger Lane. Add the Compatibility flags for
the low-end copy. On the env-box fallback this runs in group 1 (C).

## 3. g2/d before/after (vault, deposit hall, concourse, ops, roof)

The "after" set for the surfaces / vault lane; the before shots are in `g2/b/` and `g2/c/`. On the GPU box run it
in Forward+ **and** Compatibility (Compatibility is what the before shots used):

    godot [--rendering-method gl_compatibility --rendering-driver opengl3] --path game --resolution 1920x1080 \
      res://world/tools/review_shots.tscn -- --heist=ostrander_federal --stage=g2 --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/d/<forward_plus|compatibility> \
      --cameras=rc_vault,rc_deposit_hall,rc_concourse,rc_vault_ops,rc_operations,rc_count_room,rc_roof,rc_terrace

(These are a subset of job 1; on the env-box fallback, groups 1/3/4 already cover them.)

## 4. D-146 perf captures (real GPU draw counts + frame times)

ENV D's `heist_cast_perf` (on trunk from r251) measures RenderingServer draw calls per view with the peak cast
(Cataclysm, seed 1037). It's the measurement levelcheck `perf` is reconciled against.

Compatibility (the D-146 number):

    godot --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --resolution 1920x1080 \
      --path game res://world/characters/_tools/heist_cast_perf.tscn -- --heist=ostrander_federal --seed=1037 \
      --detail --view=rc_hall_entrance,rc_hall_counter,rc_hall_from_gallery,hall_south_eye,rc_back_corridor,rc_teller_workroom,rc_operations,rc_vault_hole

Forward+ (frame times on real hardware): the same without the two renderer flags.

Add `--loud --seconds=90` for the loud/assault state: police in the hall and the turret vans, the worst case.

Glasshouse (D-146 pulled forward), the same tool in Compatibility, for its 4 former worst views:
`--heist=glasshouse --view=ChandelierLandmark,UpperCorridor,ExtAlleyWest,GaragePerch`.

Paste the console output (per view: frame draws, per-pass lines, ms/frame) into
`docs/levels/ostrander_federal/g2/perf/gpu_<compat|fplus>.txt`. ENV C compares it with levelcheck.
