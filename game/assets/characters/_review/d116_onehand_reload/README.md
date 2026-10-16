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
