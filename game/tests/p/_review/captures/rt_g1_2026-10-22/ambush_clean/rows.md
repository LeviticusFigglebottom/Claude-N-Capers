| test | item | verdict | detail | owner |
|---|---|---|---|---|
| ambush_clean | street -> man-gate (Orchard sidewalk) | PASS | 12.1 s, 0 STUCK row(s) | - |
| ambush_clean | man-gate padlock (lockpick) | PASS | gate open true | - |
| ambush_clean | through the man-gate into the site (>= 1.0 m) | PASS | 0.8 s, 0 STUCK row(s) | - |
| ambush_clean | SignalRig hack (15 s) | PASS | 20.4 s from F, 1 restart(s), signals_rigged true | - |
| ambush_clean | clean stop (north) | PASS | stopped true at t=156.8 (ETA 150, waited 107 s), layout 'north_clean', clean_stop true, signals_rigged true, alerted false, alarm '' | - |
| ambush_clean | clean stop: the ambush springs (window +8 s) | PASS | loud true at t=164.8 | - |
| ambush_clean | T1 rear UsePoint reachable (north_clean) | PASS | use (-7.8, 0.0, -32.0), nav end (-7.8, 0.2, -32.0) | - |
| ambush_clean | T2 rear UsePoint reachable (north_clean) | PASS | use (-7.8, 0.0, -44.0), nav end (-7.8, 0.2, -44.0) | - |
| ambush_clean | the mixer leaves / the Tannery gate passable (§7.6, QC-RT1) | BLOCKED: C r277 | SiteTanneryGateW locked, SiteTanneryGateE locked; MixerTruck at (-34.0, 0.0, -16.5); layout 'north_clean' | A mission (_mixer_move layouts) / C map |
