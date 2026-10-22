| test | item | verdict | detail | owner |
|---|---|---|---|---|
| breach | street -> man-gate (Orchard sidewalk) | PASS | 12.1 s, 0 STUCK row(s) | - |
| breach | man-gate padlock (lockpick) | PASS | gate open true | - |
| breach | through the man-gate into the site (>= 1.0 m) | PASS | 0.8 s, 0 STUCK row(s) | - |
| breach | SignalRig hack (15 s) | PASS | 20.4 s from F, 1 restart(s), signals_rigged true | - |
| breach | clean stop (north) | PASS | stopped true at t=156.5 (ETA 150, waited 106 s), layout 'north_clean', clean_stop true, signals_rigged true, alerted false, alarm '' | - |
| breach | clean stop: the ambush springs (window +8 s) | PASS | loud true at t=164.5 | - |
| breach | T1 rear UsePoint reachable (north_clean) | PASS | use (-7.8, 0.0, -32.0), nav end (-7.8, 0.2, -32.0) | - |
| breach | T2 rear UsePoint reachable (north_clean) | PASS | use (-7.8, 0.0, -44.0), nav end (-7.8, 0.2, -44.0) | - |
| breach | T3 rear UsePoint reachable (north_clean) | PASS | use (-7.8, 0.0, -56.0), nav end (-7.8, 0.2, -56.0) | - |
| breach | T1 (no lockdown) by the placed saw | PASS | placed true, opened true after 130 s heist time, 1 jam(s) fixed | - |
| breach | street -> man-gate (Orchard sidewalk) | PASS | 4.6 s, 0 STUCK row(s) | - |
| breach | man-gate | NOTE | gate SiteManGate:<Node3D#558211541842> padlock Padlock:<Node3D#558312205144> | - |
| breach | through the man-gate into the site (>= 1.0 m) | PASS | 1.1 s, 0 STUCK row(s) | - |
| breach | thermite bag from the tool store (lockpick) | PASS | door open true, 26 s | - |
| breach | T2 thermite carried and placed | PASS | 42 s carry from the tool store, placed true | - |
| breach | T2 by thermite | PASS | opened true 78 s after placing | - |
| breach | street -> man-gate (Orchard sidewalk) | PASS | 8.1 s, 0 STUCK row(s) | - |
| breach | man-gate | NOTE | gate SiteManGate:<Node3D#558211541842> padlock Padlock:<Node3D#558312205144> | - |
| breach | through the man-gate into the site (>= 1.0 m) | PASS | 1.1 s, 0 STUCK row(s) | - |
| breach | magazine C4 box (run stopped) | STUCK | loud: the padlock took place_saw and the harness did not wait the cut; with MagazineDoor shut the nav path to C4Box ran through MagWallN from outside, 12 STUCK at (-23.5, 0.0, -52.5): the 0.2 m magazine walls are not in the bake | C bake (MagWall* < 2 cells, _nav_thick) / harness fixed 9684b7286 |
