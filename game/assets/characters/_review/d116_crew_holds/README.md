# D-116 third-person crew weapon holds

`game/world/characters/_tools/render_crew_hold_review.tscn`: Glasshouse launched as the game does. Two crew rigs
stand 1.8 m in front of the player's spawn: Rook with the Corsair, Sable with the Kestrel. Each WeaponVisual is
attached at HandR/Socket exactly as AnimDriver does. Left column: a wide view; right: a close-up.
- `before_glasshouse.png` (rows: idle_alert, walk, aim). Outside aiming, the shared clips hold no weapon: at
  idle_alert the rifle sits in the right fist with the left hand empty, and walking it hangs straight down. The
  pistol dangles.
- `after_glasshouse.png` (rows: idle_alert_rifle / _pistol, hold_rifle / _pistol, aim). Both hold the weapon
  two-handed at a PD2 low ready. The rifle's support hand is cupped under the fore-end on its current LeftHandIK
  (the third-person RIFLE left_ik moved off the pre-B marker, which sat beside the handguard). There is a slow
  weight shift in the idle loops.
A wires these clips (SOURCE `weapon_holds`): idle_alert_<kind> while holding and not aiming; hold_<kind> layered on
the upper body over walk / run / strafe.

## Crew interaction audit (third person)
- `interactions_before.png`: rows interact_low, interact_mid, interact_high, drill_place, pager_answer,
  throw_bag (0.35 and 0.5 s), carry_bag_walk. The rifle went through the forearm (mid), through the head (high and
  the throw release) and behind the head (bag carry).
- `interactions_after.png`: the same rows with the armed variants interact_low/mid/high_armed and throw_bag_armed.
  The weapon stays in a low carry in the right hand while the left hand does the work. In the crouch the carry
  drops with the hips, muzzle down. The bag carry holds the strap in the left hand at the left shoulder.
A plays the *_armed variants whenever the crew member holds a weapon (SOURCE `armed_interactions`).
