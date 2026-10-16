# D-116: book reading angle (sit_chair_read, sit_bed_read)

The lead's note: "the book sits flat and low in the lap"; it should be raised about 10 cm and tilted toward his face.

* `READ_RAISE` and `READ_TILT` in `tools/blender/characters/_anim_humanoid.py` (`_reading`), set per clip as (chair, bed).
* Chair: raised 10 cm (world up) to mid-chest. Its top edge is tipped 34° past square-to-sight-line toward the face, so the
  pages angle up at his eyes.
* Bed: he is reclined, so the book already sat at the chest. It rises 3 cm and tips 8°. The full 10 cm put it over his
  face (checked).
* Shots: windowed `render_crew_hold_review --props=book` with npc_kessler (front and 25° turn). The chair shots use
  `--chair=prop_armchair` at t=3 s and t=6 s; the bed shot uses t=3 s.
