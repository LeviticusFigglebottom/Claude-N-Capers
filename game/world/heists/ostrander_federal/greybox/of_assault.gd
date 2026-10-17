## Ostrander Federal PO6-17 RNG assault-event markers (D-114 §5, D-136 §3b.6; doc Loud "Assault events"). Owner: ENV C.
## Built by world/heists/shared/assault_markers.gd (contract: docs/levels/_art/po6_17/README.md) under `AssaultEvents`.
## G1: the turret vans, the heli orbit and the three rappel drops here; the breaches Breach_1/2 (prop_breach_window in
## the hall bays W1 / E2) are layout rows (ostrander_federal_layout.gd ASSAULT_BREACHES, with their wall slots). QC-i:
## no "door" breach kind; the XL / HH doors are breached as doors (D-122) and stay police ENTRY TacticalPoints.
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
