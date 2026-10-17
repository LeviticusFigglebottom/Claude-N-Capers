# D-116: throw_grenade re-keyed as an overhand lob

The lead's note: at `release`, throw_grenade read as a sideways point. A's capture is `before_a_throw_release.png`,
from env/a-core `game/tests/a/_review/v123/throw_release.png`.

`_throw_grenade` in `tools/blender/characters/_anim_crew3p.py`. The timing is unchanged: 24 f, release@11, done@24.

* The right foot steps forward (stance held from the wind-up through the follow-through).
* Wind-up (f6): the trunk is turned away (twist 28 / chest 20) and leans back. The elbow is up and out, and the hand is
  cocked behind and beside the head.
* Release (f11): the hips drive forward and the trunk is rotated into the throw (twist -24 / chest -18), the head held on
  the target. The left arm is forward and high, with the hand ahead of and just above the head line.
* Follow-through (f16): the hand comes down across the body to the right thigh, and the trunk keeps turning.

Sheets: windowed `render_crew_hold_review` with crew_rook, at t = 0.2 / 0.3667 / 0.5 s (wind-up, release,
follow-through). `after_wind_release_follow.png` is at `--turn=30`, where the right bot is in profile facing right.
`*_back.png` is at `--turn=-60`.
