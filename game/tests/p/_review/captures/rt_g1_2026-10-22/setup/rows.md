| test | item | verdict | detail | owner |
|---|---|---|---|---|
| setup | street -> man-gate (Orchard sidewalk) | PASS | 12.1 s, 0 STUCK row(s) | - |
| setup | man-gate: wait unseen before masking | PASS | 19 s | - |
| setup | man-gate padlock (lockpick) | PASS | gate open true | - |
| setup | through the man-gate into the site (>= 1.0 m) | PASS | 0.8 s, 0 STUCK row(s) | - |
| setup | SignalRig hack (15 s) | PASS | 20.4 s from F, 1 restart(s), signals_rigged true | - |
| setup | setup from plaza spawn | FAIL | gate t=45.7, rig hacked t=66.2, ETA 150 s (84 s spare), alarm '', 1 observers, peak 1.00; CORRECTION: the gate guard (post_site_gate) reached 1.00 at t=66.0 from (-26.7, -14.0), 10.6 m, LOS to the rig stand, 0.2 s before the rig finished: an alarm was pending. The ~20 s hack (15 s + 1 interruption) does not fit his loop gap from a plain wait | C patrol / design (rig on the gate guard loop) |
| setup | street -> man-gate (Orchard sidewalk) | PASS | 18.6 s, 0 STUCK row(s) | - |
