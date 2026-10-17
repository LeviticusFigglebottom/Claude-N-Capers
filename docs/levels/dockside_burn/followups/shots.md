# Review shots: dockside_burn DB-1 follow-ups

Rendered by `res://world/tools/review_shots.tscn` (opengl3 under xvfb, llvmpipe), one camera per run, 1920x1080.
`before/` is the G2 state (sniper_crane / landing_stage are the G2 shots of 3d44dc97, unchanged since), `after/` the
DB-1 state. The chamber shots were rendered on the current map to check the C1 / C2 variety (no chamber change).

| camera | before | after | what changed |
|---|---|---|---|
| ExtYardEast | [before](before/ext_yard_east.jpg) | [after](after/ext_yard_east.jpg) | The Pier 10 crane: catalog `veh_gantry_crane` (legs on rail bogies, braces, A-frame + apex stays, box boom, trolley + spreader on the boom tail, floods) over the unchanged colliders; the `prop_beacon_hazard` beacons on the portal beams. |
| SniperCrane | [before](before/sniper_crane.jpg) | [after](after/sniper_crane.jpg) | The camera now stands just west of the S1 cab's open front (inside, the cab roof blocks the cameras check's sky ray); the view over the yard / apron is clear (the trolley and spreader are parked behind the cab). The near beam is the west girder's collider, as before. |
| LandingStage | [before](before/landing_stage.jpg) | [after](after/landing_stage.jpg) | The trawler: catalog `veh_trawler_dockside` (hull, wheelhouse with the S4 roof, mast + outriggers, stern A-frame, net drum, deck gear, fenders) over the unchanged colliders; it still closes the east view. |
| ChamberA | [current](before/chamber_a.jpg) | - | C1: frosted cartons on the racking, frosted panels. |
| ChamberB | [current](before/chamber_b.jpg) | - | C2 (ead0eb41): blue fish-box stacks, half-empty bays, bare steel panels, colder light: told apart from C1 at a glance; every C2 point of the doc's room row is in. |
