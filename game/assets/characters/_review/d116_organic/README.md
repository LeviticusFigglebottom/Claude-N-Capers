# D-116 follow-up: organic FP handling (secondary-motion layer)

- `glasshouse_<weapon>.png`: windowed in-game strips in Glasshouse, captured with
  `game/world/characters/_tools/render_fp_handling_strip.tscn` (real input, one frame every 0.1 s, cropped to the
  viewmodel). Weapons: Kestrel (pistol), Corsair (rifle), Hornet (smg), Mule (shotgun). The upper block of each strip
  is the tactical reload (3 rounds spent); the lower block is the draw after a swap (it opens on the other weapon's
  holster).
- `motion_curves_before_after.png`: the gun's height (blue, mm) and pitch (red, deg) per frame. The thin line is the
  keyed clip (`FP_ORGANIC=0`) and the thick line is the clip with the layer. It shows the anticipation before moves,
  the overshoot and settle after them, the kicks at mag_out / mag_in / shell_in / bolt_release, and the drift while
  the hands work. Event frames are marked; they are the same in both.
- Layer: `tools/blender/characters/_arms_organic.py`. Clip lengths, key frames and event frames are unchanged, and
  every clip starts and ends on its keyed pose. akimbo and bow are not covered yet.

## Windowed before/after grids, per class

These are `render_crew_hold_review --grid=4` captures from before and after 8a5bf4b6. In each grid, a column is a moment
in the loop.

* Guards (`*_guards.png`: security_officer and security_officer_b):
  * Rows 1-3 are idle at 0/1/2/3 s, idle_alert at 0/0.75/1.5/2.25 s, and walk at 0/0.25/0.5/0.75 of the cycle.
  * After: the head moves to a target and holds there, and the chest and spine turn with it a beat later. The hanging arms
    trail the trunk's turn. On the walk, the wrist lags and the elbow bends just after the forward swing.
* Police (`*_police.png`: tac_light with a rifle, patrol_officer with a pistol): idle_alert_<kind> at 0/0.8/1.6/2.4 s.
  After: the same glance and trunk overlap, and the held weapon follows the trunk a moment late (`lag_weapon`).
* Police walking (`*_police_walk.png`): the hold_<kind> layer over walk.
* `cmp_guard_*_close.png`: close views; the top row is before and the bottom row after.
