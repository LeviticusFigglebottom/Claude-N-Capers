# D-116: Dockside Burn / Shadow Ledger cast polish (windowed, Glasshouse; render_crew_hold_review)
- `cartel_a_b_c.png`: the existing three Co-op gunmen.
- `cartel_d_e_f.png`: the new ones. _f is the balaclava read (beanie and gaiter over the nose), _e the big man in the
  flare oilskin jacket with a cream beanie and a slung pump-gun, _d the woman in a cream roll-neck under the puffer vest.
- `northgate_a_b_c_d.png`, left to right: _d (tall, young, blond), _c (older, heavy-set, bald, glasses), _b (the
  woman, chignon), the original. All wear the same Northgate suit, pin, earpiece and radio.
- `packer_cleaners_sl.png`, left to right: dock_packer in processing whites (white smock, yellow rubber apron and
  gloves, white boots, hygiene cap), then npc_cleaner_sl_c (young man, glasses), _b (grey-haired woman) and the
  original, all in the same Calder uniform.
Pools (p5_cast.json): DB cartel 6 looks, SL guards and operator 4, SL cleaners 3. test_p5_cast
test_db_sl_pooled_variety checks that no two looks in a pool share a face.

## Round 2: Shadow Ledger and Night Deposit
- `halden_c_d_northgate_e_f.png`, left to right: security_officer_d (young man, deep skin), _c (woman, dark bob under
  the cap), npc_northgate_guard_f (40s, side-parted brown hair, stubble), _e (woman, 50s, deep skin, dark bob).
  Northgate now has 6 faces (Lethal: 5 guards + the operator), Halden 4 (the ND hall, basement and rover pool).
- `kessler_sit_chair_read.png`: npc_kessler in sit_chair_read at 3.0 and 7.6 s (the page turn). Seated upright on the
  Seat height, head down to the book over the lap. The book is A's hand prop (HandProps), not attached in this tool.
  Known limit: the long robe's hem stands out stiffly over the knees when seated (the robe skinning follows the thighs).
