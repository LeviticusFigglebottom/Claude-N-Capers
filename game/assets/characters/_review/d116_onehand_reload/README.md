# D-116 follow-up: one-handed reloads with the support hand in frame

Windowed Glasshouse strips (`_tools/render_fp_handling_strip.tscn`, real input, one frame per 5 ticks at 60 Hz,
cropped to the viewmodel). The upper block is the tactical reload; the lower block is the draw after a swap.
- `glasshouse_kestrel_p9.png`: the pistol comes up showing its side and magwell and the old magazine drops out.
  The left hand rises into frame with the new magazine, seats it with the palm (`kestrel_seat_full.png`), and drops
  away (`kestrel_after_seat_full.png`).
- `glasshouse_marshal_357.png`: the cylinder swings out and the left hand cradles it. Muzzle up, the palm strikes the
  ejector rod; muzzle down, the speedloader goes in and is twisted and dropped; the cylinder closes. The left hand is
  in frame throughout.
Framing math (P's one-handed hip offset and rotation applied): pistol magwell at ~0.70 and the seating palm at ~0.78
of the screen height; wrist 0.34 m from the eye.
- `glasshouse_marshal_357_v2.png` / `marshal_eject_full_v2.png` (lead review of v1): the heel strikes the ejector rod
  with the fingers curled (no flat palm). The muzzle-up tilt is capped at 50 deg, so the top third shows the world,
  and the left hand is 0.31 m from the eye. The left forearm still crosses the lower-left as it reaches over the
  gun.
- v3 (lead review of v2): `glasshouse_marshal_357_v3.png`, `marshal_eject_full_v3.png`,
  `marshal_loader_release_full_v3.png`. The rod hand's elbow points straight down, so the forearm rises from the
  bottom edge instead of cutting the lower-left wedge (moving the hold right or rolling the cylinder runs out of
  arm reach). The speedloader hand curls round the loader, the trip to the pouch is a loose fist, the release
  flick keeps the fingers curled, and the crane-closing fingers curl against the cylinder: no splayed or flat
  palm anywhere.
