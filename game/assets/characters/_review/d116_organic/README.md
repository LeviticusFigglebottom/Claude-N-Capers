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
