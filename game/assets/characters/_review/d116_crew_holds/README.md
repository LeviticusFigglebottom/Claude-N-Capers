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
