## Ostrander Federal PO6-17 RNG assault-event markers (D-114 §5, D-136 §3b.6; doc Loud "Assault events"). Owner: ENV C.
## Built by world/heists/shared/assault_markers.gd (contract: docs/levels/_art/po6_17/README.md) under `AssaultEvents`.
## G1: the turret vans, the heli orbit and the three rappel drops. The breaches are deferred: Breach_1/2 sit in the
## 5.5 m arched bays (OF-C2's `prop_breach_window_s100` with a 1.0 m sill), and Breach_3/4 are the doc's new kind "door"
## (the XL / HH doors as their own infill), which assault_markers.gd does not build yet (open question, lead / A).
extends RefCounted

## [name, pos (road, bottom-centre), yaw_deg (+Z = the van's forward)]: Halloran Ave opposite the hall bays.
const TURRET_VANS: Array = [
	["TurretVan_1", Vector3(16.0, -0.75, 51.0), 90.0],
	["TurretVan_2", Vector3(34.0, -0.75, 58.0), -90.0],
]
## [name, centre (flight height), radius]: over the terrace and the lantern, clear of Corvino (x 0) and the garage.
const HELI_ORBITS: Array = [["HeliOrbit_1", Vector3(28.0, 30.0, 24.0), 22.0]]
## [name, pos]: the terrace SW corner (+8.6), the main roof south of the roof plant (+12.2), the plaza east of the steps.
const HELI_DROPS: Array = [
	["HeliDrop_1", Vector3(8.0, 8.6, 32.0)],
	["HeliDrop_2", Vector3(30.0, 12.2, 14.0)],
	["HeliDrop_3", Vector3(36.0, -0.75, 46.0)],
]
const BREACHES: Array = []
