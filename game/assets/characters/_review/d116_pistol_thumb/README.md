# D-116 pistol / revolver grip thumb (PO item)

The firing-hand thumb now lies high along the frame's left (support) side, under the slide, wrapping the grip, and is
visible from the FP camera. Before, it stood 40 mm off the frame on the pistol and 60 mm off on akimbo.

* `FPSet.grip_thumb`: PISTOL_THUMB / REVOLVER_THUMB / AKIMBO_THUMB in `tools/blender/characters/_arms_sets.py`.
  The akimbo `Side` now applies its set's thumb (`_arms_akimbo.py`).
* Thumb tip in weapon space (mm, x right, y muzzle, z up): pistol (-40, 27, 27) → (-22, 32, 16); revolver (-19, 33, 8);
  akimbo (-60, 25, 14) → (-21, 47, 17). The thumb radius is about 9 mm, so x ≈ -22 is on the frame face.
* `*_before.png`: ENV P's hip frames. `*_after.png`: windowed `render_fp_handling_strip.tscn --actions=idle`, using P's hip
  tweak, applied only for the render.
