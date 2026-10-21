# Ostrander Federal: G2 GPU render jobs (OF-C2, ENV C)

All renders run on the PO's GPU box (RX 9070 XT; LEAD dispatches; outputs go to the `gpu/renders` branch). The env
boxes don't render review shots any more (LEAD, 2026-10-20).

The shipping renderer is **Forward+** (D-146 addendum 6). The project sets no `rendering_method`, so a plain run is
Forward+. Compatibility runs (flags below) are optional low-end checks only.

Run from the repo root, on a tree at the sha ENV C announces for the job, after one
`godot --headless --path game --import`. Godot 4.7.2.

## Job A: GI re-bake (before the final 34 shots, when ENV C asks)

VoxelGI bakes need Vulkan (Compatibility has no VoxelGI). The bake is deterministic; commit the 3 `.res` files it
writes under `game/world/heists/ostrander_federal/`.

    godot --path game --script res://world/heists/ostrander_federal/greybox/bake_gi.gd

## Job B: the 34 review shots (final)

    godot --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- \
      --heist=ostrander_federal --stage=g2 --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final

That renders `TopDownPlan` + the 34 `rc_*` cameras, `contact_sheet.jpg` and `shots.md` (`rc_burn_close` only reads in the burnt scene). Then the burnt shots
(`rc_vault_hole`, `rc_burn_close` and the views onto them) from a test-only variant scene (`--drops` also shows the heli drop and the
second van):

    godot --headless --path game --script res://world/tools/capture/of_burn_variant.gd -- \
      --out=user://of_burn_test.tscn --drops
    godot --path game --resolution 1920x1080 res://world/tools/review_shots.tscn -- \
      --scene=user://of_burn_test.tscn --warmup=60 \
      --out=$PWD/docs/levels/ostrander_federal/g2/final/burnt \
      --cameras=rc_vault_hole,rc_teller_workroom,rc_burn_close,rc_terrace,rc_ext_lane

## Job C: spot re-renders while fixing (any time, on request)

The same as Job B with `--cameras=<a,b,...>` and `--out=$PWD/docs/levels/ostrander_federal/g2/fix/<topic>`.

## Job D: perf evidence (D-146, optional)

    godot --audio-driver Dummy --resolution 1920x1080 --path game \
      res://world/characters/_tools/heist_cast_perf.tscn -- --heist=ostrander_federal --seed=1037 --loud --seconds=90 \
      --detail --view=rc_hall_entrance,rc_hall_counter,rc_hall_from_gallery,hall_south_eye,rc_back_corridor,rc_teller_workroom,rc_operations,rc_vault_hole

Save the output to `docs/levels/ostrander_federal/g2/perf/gpu_fplus_loud.txt`. For the low-end figure, add
`--rendering-method gl_compatibility --rendering-driver opengl3` and save to `gpu_compat_loud.txt`.
