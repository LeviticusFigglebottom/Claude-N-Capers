# D-116 pistol / revolver grip thumb (PO item)

The firing-hand thumb now lies high along the frame's left (support) side, under the slide, wrapping the grip, and is
visible from the FP camera. Before, it stood 40 mm off the frame on the pistol and 60 mm off on akimbo.

* `FPSet.grip_thumb`: PISTOL_THUMB / REVOLVER_THUMB / AKIMBO_THUMB in `tools/blender/characters/_arms_sets.py`.
  The akimbo `Side` now applies its set's thumb (`_arms_akimbo.py`).
* Thumb tip in weapon space (mm, x right, y muzzle, z up): pistol (-40, 27, 27) → (-22, 32, 16); revolver (-19, 33, 8);
  akimbo (-60, 25, 14) → (-21, 47, 17). The thumb radius is about 9 mm, so x ≈ -22 is on the frame face.
* `*_before.png`: ENV P's hip frames. `*_after.png`: windowed `render_fp_handling_strip.tscn --actions=idle`, using P's hip
  tweak, applied only for the render.

## Re-captured with ENV P's own tool (env/p-play 21a1eb4c, plus these arms)

These use `res://tests/p/_review/ads_seq_capture.tscn` (windowed, `--fixed-fps 60`) at P's new levelled hip offset.

* `p_level_hip_ads_5pistols.png`: one row each for kestrel_p9, marshal_357, sparrow_mp, warden_45 and wren_380. The left
  column is the hip (`00_hip`, bottom-right quarter) and the right is settled ADS (`09_in40`, bottom-centre). At the hip
  the thumb lies along the frame's left side under the slide on all five. At ADS it shows on the left under the slide.
* `akimbo_hip_ads_align_on_off.png`: hip, then settled ADS with P's `FpViewmodelOffhand.align` on, then with it off
  (forced w = 0, in a scratch copy only). The left gun is upright at ADS either way.
* `akimbo_ads_in_align_on_off.png`: in2 / in6 / in11 / in22, with align on (top) and off (bottom). They differ only in the
  first frames, while the guns still carry the hip's mirrored inward cant. The clip already plays hand.L as the exact
  mirror of hand.R (`_arms_akimbo.mirror_hand`), so the override can go.
