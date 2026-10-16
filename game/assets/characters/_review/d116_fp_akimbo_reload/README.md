# D-116: first-person akimbo Warden .45 reload stays in view (P r225 review)
Before (ENV P, env/p-play `game/tests/p/_review/captures/d116/reload_r225/akimbo_frames_40_60_80_100.png`): both
guns and hands went below the frame (the shared `lowered` pose) from about 1.0 to 1.6 s.
After: the reload dips to `_arms_akimbo.RELOAD_DIP`, which keeps the slide tops and the hands in the lower third. The
magwells stay below the frame edge, so the fresh magazines go in out of view. Event frames are unchanged.
Projection under the FP camera (52 deg, 16:9; y 0 = top, 1 = bottom): the muzzle stays at y <= 0.79 and the wrist at
y <= 1.23 throughout (the hip: 0.78 / 1.14). Before the fix they reached 1.79 / 2.03.
- `akimbo_reload_strip_after.png`: the windowed strip (render_fp_handling_strip, Glasshouse, every 10 ticks at
  60 Hz; rows 1-2 = reload, row 3 = draw).
- `akimbo_reload_1_33s_after.png`: reload at 1.33 s (P's empty frame 80).
The left gun is A's second WeaponVisual on hand.L; it is not attached in this review.
