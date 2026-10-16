GN-8 Gallery Night loud e2e evidence (flow auto_loud, Routine, input-only pilot; ENV A, 2026-10-16)

Headless (godot --headless res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud "--po5-heist=Gallery Night"
--po5-seed=<seed>; screenshots are skipped headless, look via PlayerInput.test_assume_captured):
  PASS seed 4242        escaped t=1043 game s, wall 2083 s  (code at f1cb812d)   gn_loud_headless_seed4242.log
  PASS seed 1792002290  escaped t=597  game s, wall 1109 s  (final code, after the env/a-core merge)
                                                                                  gn_loud_headless_seed1792002290.log
Windowed (xvfb-run, --rendering-driver opengl3, 960x540):
  PASS seed 4242        escaped t=867 game s, wall 1729 s  (code at 6603a9c1)   gn_loud_windowed_seed4242.log,
                        gn8_win_seed4242_{06_start,17_t779,18_payday,23_hub}.jpg

Losses kept for the record (combat, not courier / objective logic):
  seed 1792002290 at f1cb812d: custody t=571 (downed in Stair SS, cuffed)          *_seed1792002290_FAIL.log
  seed 777: custody t=1081 (third down after [secure], walking to the van)          *_seed777_FAIL.log
  seed 2024: crew wipe defending the Argus hack (t=592)                             *_seed2024_FAIL.log
  seed 4242 final code: custody t=605 (downs exhausted in the upper BOH)           *_seed4242_final_FAIL.log
  seed 99 final code: crew held at the escape (escape_wait), escape opened t=1256, then the engine crashed
    (signal 11; "/root: The caller thread can't call propagate_notification()") right after LOUD -> ESCAPE.
                                                                                  *_seed99_CRASH_at_escape.log
  seed 31337: custody t=357; seed 5150 (pre-merge): Salt Orchard bag dropped behind the BARRED LD art door, the
    hack finished at t=1458, 1500 s loop limit.
