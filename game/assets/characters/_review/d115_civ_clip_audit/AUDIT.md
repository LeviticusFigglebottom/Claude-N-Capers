# D-115 civilian outfit clip audit (lead queue D-115 item 2)

Windowed Godot renders (opengl3 under xvfb) of the new D-115 civilians, posed with the shared humanoid
clips at the time where the outfit is under the most strain. Script:
`game/world/characters/_tools/render_d115_civ_clip_audit.gd` (pass sheet keys after `--` to render only those).
Each sheet has one column per civilian, in this order: vossberg, sales_b, clerk, dock_worker, dock_worker_b,
dock_packer, cleaner_sl_b. Row 1 is a front three-quarter view and row 2 a back three-quarter view.
`zoom_*` sheets are close-ups on one bone. `before_*` / `reported_*` are crops of the first pass, kept as evidence.

Clips (names from `char_anim_humanoid/SOURCE.txt`): hands_up, surrender (end = kneeling, hands on the head),
kneel_cuffed, cower, cower_stand (both flinch peaks), cower_seated, flee (the civilian panic run), and the deaths
civilians reach: death_front/_b, death_back/_b, death_side, death_kneel (from surrender), death_kneel_cuffed,
death_crouch (from cower), death_seated_slump and death_seated_fall.

## Results

OK = no visible clipping. **fixed** = clipped on the first pass and is clean after the fix (re-rendered).
**reported** = still clips, and the cause is in the clip, not in the outfit (see below). "minor" = a few pixels
at review distance.

| civilian | hands_up | surrender | kneel_cuffed | cower | cower_stand | cower_seated | flee | death_front/_b | death_back/_b | death_side | death_kneel | death_kneel_cuffed | death_crouch | death_seated_* |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| manager_vossberg (Greta) | OK | fixed (F1) | fixed (F1) | OK | OK | reported (R2) | OK | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | reported (R2) |
| civilian_sales_b | OK | fixed (F1) | fixed (F1) | OK | OK | reported (R2) | OK | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | reported (R2) |
| civilian_clerk (lanyard OK in every pose) | OK | fixed (F1) | fixed (F1) | OK | fixed (F4) | reported (R2) | OK, minor hem notch | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | reported (R2) |
| dock_worker | fixed (F2) | fixed (F1, F2); reported (R1) | fixed (F1) | reported (R1) | OK | reported (R1) | OK | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | OK |
| dock_worker_b | fixed (F2) | fixed (F1, F2); reported (R1) | fixed (F1) | reported (R1) | OK | reported (R1) | OK | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | OK |
| dock_packer (beanie) | OK | fixed (F1) | fixed (F1) | OK | OK | OK | OK | fixed (F1) | OK | OK | fixed (F1) | fixed (F1) | fixed (F1) | OK |
| npc_cleaner_sl_b | OK | fixed (F1) | fixed (F1) | OK | fixed (F3) | reported (R2) | minor (R3) | fixed (F1) | minor (R3) | minor (R3) | fixed (F1) | fixed (F1) | fixed (F1), minor (R3) | reported (R2) |

## Fixes (D-owned source; the cast, cleaner_sl and npc_bank_cleaner rebuilt)

- **F1: skin showing through the shoe soles.** This affected every civilian whose soles face the camera
  (kneeling, lying face down). Evidence: `before_kneel_cuffed_soles.png` and `zoom_kneel_cuffed_feet.png`. There
  were two causes. (a) In `_outfit_build.cull_covered` the cover ray started 0.4 mm *outside* the skin. A sole's
  flat bottom is coplanar with the foot's sole at z = 0, so the ray started beyond the sole and the skin was kept.
  The ray now starts 0.8 mm inside the skin (`COVER_START`). (b) In `_outfit_garments.shoes` the instep arch
  lifted the whole sole bottom, so the foot's skin hung below it. Now only the outer welt band steps up, and a new
  inner ring keeps the bottom on the ground. This adds about 80 tris per character. After the fix, no foot skin
  is left under the soles (checked with a Blender ray probe).
- **F2: hi-vis vest armholes dragged up the raised arms.** Visible on dock_worker in hands_up and surrender, and
  slightly on dock_worker_b. Evidence: `before_vest_armholes.png` and `zoom_hands_up_chest.png`.
  `char_dock_workers._torso_weights` keeps at most 20 % of an upper_arm / forearm weight on the vest and its tape,
  and moves the rest to that side's clavicle.
- **F3: the cleaner's tabard was broken by the thighs, and its hem swung loose behind the legs.** Visible in
  cower_stand. Evidence: `before_cower_seated_vests_tabard.png` and `cower_stand_flinch1.png`. `_npc.tabard`
  now weights like the closed skirt: thigh_max 0.95, back_relax 0.6, and a new `skirt_weights(front_ramp=)` that
  lays the front panel on the thigh from just below the crease.
- **F4: the clerk's long cardigan.** Its back hem was broken by the seat in cower_stand. It now has
  `flare=0.09, base=0.013` (it was `0.05 / 0.011`).

## Reported (not fixable in the outfit: the shared clips are not changed here)

- **R1: hands sink into the hard hat** in surrender, cower and cower_seated (dock_worker, dock_worker_b).
  Evidence: `reported_surrender_hardhats.png` and `zoom_surrender_head.png`. The clips place the hands on the
  skull, and the hat shell stands about 2.4 cm off the head. Possible fixes, owned by the clip or the game side:
  a hand-on-head offset per headwear class (an IK lift of about 3 cm when the Headwear has a hard hat), or
  hiding the hat in those states. The beanie (packer) is fine.
- **R2: jacket and tabard fronts break up on the lap** in cower_seated and death_seated_slump / _fall
  (vossberg, sales_b, clerk, cleaner_sl_b). Evidence: `before_cower_seated_jackets.png`,
  `zoom_cower_seated_lap.png` and `zoom_cower_seated_lap_top.png`. The clip folds the trunk down onto the thighs,
  so belly and thigh overlap in body space, and no garment between them can stay outside both. I tried stronger
  front tail weights (`skirt_weights` front_thigh 0.92, front ramp 0.4). They made no visible difference, so I
  reverted them. A fix needs less trunk curl or less hip flexion in cower_seated / death_seated_*. With a chair
  and desk in place the lap is mostly hidden.
- **R3: the tabard sides still part over a sharply flexed thigh** in flee, death_back, death_side and
  death_crouch (cleaner_sl_b, cleaner_sl, bank cleaner). This is minor at review distance. The tabard is a single
  closed tube, so this is the same limit as the skirt in the same poses.

## Note for rollout

F1 is in shared helpers (`cull_covered`, `shoes`). Every other character picks it up on its next rebuild.
Only the D-115 cast, cleaner_sl and npc_bank_cleaner were rebuilt here. `*_lod.res` churn from assemble.sh was
reverted as instructed.
