OF-A6 phase 2: Ostrander Federal e2e on the REAL menus (windowed, llvmpipe, 960x540), 2026-10-20, ENV A.
Harness: game/tests/a/e2e/run_po5.sh <of_stealth|of_loud> <seed> <budget> <out> "Ostrander Federal"
  po5_flow.gd clicks main menu -> Safehouse -> Planning Table -> Ostrander Federal -> Routine -> Briefing -> Continue ->
  Confirm plan -> Start Heist (seed via --po5-seed), then po5_flow_of_stealth.gd / po5_flow_of_loud.gd play the same
  X4 routes as test_x4_of_stealth.gd / test_x4_of_loud.gd (stated harness shortcuts in x4_stealth_flow.gd / x4_of_loud.gd)
  on the menu-launched runtime, assert the win and click the payday back to the hub.
Menu note: OF is still `hidden` in trunk's heist_list.tres; these runs used ENV B's env/b-content heist_list.tres
  (OF un-hidden, solo_ai_teammates 3), applied locally and not committed by A.
Loud: CREW_DMG=0.25 (D-133 harness-only crew_damage_taken_mult), Routine, assault events ON, 3 lobby AI teammates.

Results (all RESULT PASS, code 0; heist seconds; downs = crew_downed on any slot):
  stealth seed 18  rack line, lz_timed, heli terrace         route 394.8 s  no alarm/laser/pager, never loud
  stealth seed 7   exec PC, sweep lasers, van at the dock     route 222.0 s  no alarm/laser/pager, never loud
  stealth seed 6   vault-ops PC, static grid, Tannery van     route 276.7 s  no alarm/laser/pager, never loud
  loud seed 5      drop_terrace, van at the dock              escape 584.0 s  0 downs, peak 13 police
  loud seed 1      drop_dock, heli over the terrace           escape 628.7 s  0 downs, peak 15 police
  loud seed 6      drop_terrace, van on Tannery Street        escape 626.7 s  0 downs, peak 12 police
Loud order checked: drill_delivery < vault_drill < vault_breach < secure < escape_wait < escape; escape before
heist_ended(success, not stealth); >= 2 hoist trips; bot never in custody.
Not covered: stealth seed 3 (manager card, mgr_vault basement) waits on C's mgr_vault CivilianRoute (fcc83280).
Files: <run>_log_excerpt.txt (objective/result lines), <run>_payday.png, of_ld5 planning table / briefing / hub.
