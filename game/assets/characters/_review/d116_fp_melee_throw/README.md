# D-116 FP audit: knife swing and grenade throw (first person, windowed, Glasshouse)
`knife_throw_before.png` / `knife_throw_after.png` come from render_fp_handling_strip `--actions=melee,throw`: real
input, one frame every 4 ticks at 60 Hz. Row 1 and the first three of row 2 are the quick knife swing (melee.folding_knife).
The rest is the frag throw (pressed 0.4 s, then released).

Knife (`_arms_melee`, melee_knife):
- Before: the thumb stuck out straight, 72 mm off the handle, and read as a pointing finger. At the hit, the blade
  pointed away from the camera and hid behind the fist. The follow-through went 40 deg below the eye and out of frame.
- After: the thumb wraps over the index and middle fingers (`MELEE_THUMB`; all three melee sets). The hit is lower
  centre with the blade across the view. The follow-through ends at the lower left edge, still in view. The recovery
  back to idle is unchanged (hit@6 .. done@18).
- `knife_grip_after_blender.png`: idle, hit (f6) and follow (f9) from the crew camera (Blender review).

Throwable (`_arms_items` THROW_POSES):
- Before: the held grenade (idle) sat 32 deg below the eye, out of frame (the edge is 26 deg). The pin pull was at
  the edge, the wind-up behind the camera, and the follow-through 44 deg down.
- After: the grenade is held in the lower third (screen y 0.90), the pin pull at y 0.83, the wind-up at the top right
  edge, the release near the centre, the follow-through at the bottom edge (y 0.98). Event frames are unchanged.
