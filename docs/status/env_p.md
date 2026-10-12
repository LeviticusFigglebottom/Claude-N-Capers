# ENV P status (Playability)

Newest entry first. Owner: ENV P. Scope: D-076. D-077: commit every 20–30 min; this file says where to resume.

## Current (resume here)
1. **P1-01 step-up and ground feel**: IN PROGRESS.
   - Done (WIP, untested): CrewTweak `step_height_m` 0.35, `max_slope_deg` 45, `step_smooth_rate` 14;
     CrewController `_move_grounded` (step-up via test_move up/forward/down + walkable ray, snap-down
     along step/ramp edges, `_grounded` flag, camera-only `_step_offset` on `Head`).
   - Next: write game/tests/p/test_p1_01_ground.gd (5/10/15/20/30/40 cm step series, ramp, steep
     ramp, stairs up/down, AI slot, camera jitter) with real intents; iterate; run `run_tests.sh a,p`.
2. P1-02 casing-mode audit: not started.
3. P1-03 ADS audit: not started.
- Baseline `tools/ci/run_tests.sh a` before any change: `== 627 tests, 1 failed, 1 skipped ==`
  (failing test name cut off by my log tail; identify on the next full run).

## 2026-10-11: created
- ENV P created by the lead (D-076). Queue: step-up/floor snap, casing-mode audit, ADS audit, then the product
  owner's playtest list.
