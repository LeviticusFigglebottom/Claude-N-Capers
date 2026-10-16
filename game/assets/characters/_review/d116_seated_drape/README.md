# D-116: seated robes and long coats (third person, windowed, Glasshouse)
The lead rejected `before_kessler_sit_chair_read.png`: no book, no chair (sitting on a ledge), the robe hem standing out
as a flat stiff panel past the knees, and a thin pale loop from the hands to the floor.

Fixes:
1. **Drape:** `_outfit_garments.jacket` with a hem below the knee (Kessler's robe and coat, Rook's coat) uses seated
   drape weights (`_outfit.skirt_weights` shin_max, SEATED_SHIN = 0.8, SEATED_CENTRE = 0.008 m):
   - the front lies on the thighs;
   - past the knee the cloth follows the shins and falls;
   - the back stays on the hips under the seat, and hangs behind the calves below the knee;
   - each front-split edge stays on its own leg.
   Coats that end above the knee are unchanged.
2. **The loop:** the robe is open below the sash wrap, and seated the opening gapes. Single-sided, the far panel seen
   from inside was culled and only its folded hem edge was drawn: the floating strip (`debug_surfaces_loop.png`, one
   flat colour per surface; the strip is the robe's silk_ice). Long-garment cloths now render both faces
   (`make_materials.DOUBLE_SIDED`: char_silk_ice, char_coat_ice, char_crew_rook_coat, char_coat_camel,
   char_coat_command; cull_mode = 2).
3. **Pyjama piping** (Kessler's robe) starts at the robe hem. Under the robe the trousers are culled but the piping
   on them was not.
4. **The book** (`hand_book`, HandR/Socket) now lists sit_chair_read in `hand_props.json`.

Shots (render_crew_hold_review: `--props=book`, `--chair=<scene>`, `--close_h`):
- `after_sit_chair_read.png`: Kessler (robe) and Kessler (coat) in world/props/salon/prop_armchair.tscn with the book,
  at 3.0 s and 7.6 s (the page turn); wide and close.
- `after_sit_chair.png`: Rook's coat and both Kessler looks in the armchair.
- `after_sit_bed_read.png`: on a stand-in mattress (prop_bench_upholstered; there is no bed prop). Legs out, the robe
  wraps the legs.
- `after_walk_idle.png`: the same coats walking and idle (side view): no gaping or tearing on strides.
