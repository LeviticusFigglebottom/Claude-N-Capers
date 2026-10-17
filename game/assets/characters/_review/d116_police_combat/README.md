# D-116 police combat movement: windowed review (Glasshouse, lit, HeistLauncher)

`render_crew_hold_review.tscn`, tac_light (corsair_ar, rifle) + patrol_officer (kestrel_p9, pistol):

* `move/move_sheet.png` (4 per row): aim_<fam>_walk / _run / _crouch over walk / run / crouch_walk (the weapon_holds
  bone filter); cover_peek_l @0.5 s (low ready) and @2.5 s (out, aimed); cover_peek_r @2.5 s; cover_low @0.6 s (down)
  and @2.5 s (up, aimed over); stagger_<fam> @0.1 / 0.4 / 0.8 / 1.19 s (thrown back, stumble, catch, back on aim f0).
  The single views next to it are the last pose of each name, with close-ups.
* `reload/reload_sheet.png`: reload_smg (hornet_9), reload_shotgun (plowman_12), reload_lmg (rampart_lmg),
  reload_sniper (heron_308) at 0 / 0.6 / 1.2 / 1.8 s.
* `sniper_bolt_before.png` / `sniper_bolt_after.png`: reload_sniper at 0 / 1.2 / 1.5 / 1.7 / 1.87 / 2.0 / 2.2 / 2.55 s.
  Before: the right hand left the grip for the bolt knob, and the 3P gun (at HandR/Socket) pointed at the floor for
  f50-60. After: the right hand stays on the grip and the left hand cycles the bolt over the top.
