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

## Crouch walk with hold_<kind> layered (third person)
The capture tool's `--layer=crouch_walk` plays crouch_walk and copies hold_<kind>'s upper bones over it (spine,
chest, neck, head, clavicles, arms, hands, fingers): the bone filter A uses. Two stride phases (0.25 and 0.6 s) per
sheet; A = LMG / SMG / rifle, B = akimbo / sniper / pistol.
- `crouch_walk_A_before.png` / `crouch_walk_B_before.png`: plain crouch_walk; the weapon hangs from one hand.
- `crouch_walk_A_after.png` / `crouch_walk_B_after.png`: the layer, 3/4 front.
- `crouch_walk_A_side.png` / `crouch_walk_B_side.png`: the layer in profile (`--turn=90`).
The layer works as authored. crouch_walk's hips pitch only 2.7 deg forward (the hold's stand: -0.9 deg), so the
held weapon keeps its standing angle relative to the trunk. No weapon goes through the knees. Model check over every
frame (weapon segment against the thigh and shin capsules): the least clearance is 160 mm (LMG), then 201 mm
(sniper; its muzzle drops to 0.46 m at the knee's forward swing). No clip change is needed.

## Crew states (third person, _anim_crew3p)
`crew_states.png`: crew_wren (an akimbo pair: a single warden_45 in each hand) and crew_sable (kestrel_p9). Rows:
- aim_akimbo 0.5; fire_akimbo 0.05; fire_akimbo_l 0.05;
- reload_akimbo 0.27 (rolled in: the magazines drop), 0.6 (grips over the belt pouches), 1.0 (seated);
- downed 0.5; downed_fire 0.05; downed_reload 0.5 and 0.85;
- downed_getup 0.66 and 1.0; downed_arrested 0.5 and 0.75;
- crew_cuffed 1.0; crew_cuffed_free 0.3.
The review keeps the weapons attached. In game, A hides the weapon at downed_arrested `disarm` and while cuffed.
