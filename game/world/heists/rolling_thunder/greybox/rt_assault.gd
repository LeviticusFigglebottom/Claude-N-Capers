## Rolling Thunder PO6-17 RNG assault-event markers (D-114 §5 / D-115 #5; RT plan §6 RT-C0: a turret van on Tannery
## West, a heli over the junction span, breach points on the car park and the diner). Owner: ENV C. Built by
## world/heists/shared/assault_markers.gd (contract: docs/levels/_art/po6_17/README.md) under `AssaultEvents`.
## G1: the turret vans and the heli orbit / drops here; the breaches are "door" breaches (markers only, meta `door`) on
## the car park's stair-A street door and fire door and the diner's front door; they stay police ENTRY points too. The
## design doc has no assault-event section yet (RT-C0 open): these rows are C's G1 proposal for the LEAD.
extends RefCounted

## [name, pos (road, bottom-centre), yaw_deg (+Z = the van's forward)]: Tannery West (facing east, out of the sun) and
## the Orchard south arm.
const TURRET_VANS: Array = [
	["TurretVan_1", Vector3(-58.0, 0.0, -4.0), 90.0],
	["TurretVan_2", Vector3(-6.0, 0.0, 48.0), 180.0],
]
## [name, centre (flight height), radius]: over the junction span, above the Skyway deck (+9.0).
const HELI_ORBITS: Array = [["HeliOrbit_1", Vector3(10.0, 34.0, -6.0), 26.0]]
## [name, pos]: the car-park roof east bays (+7.0), the plaza, the forecourt.
const HELI_DROPS: Array = [
	["HeliDrop_1", Vector3(44.0, 7.0, -26.0)],
	["HeliDrop_2", Vector3(-46.0, 0.0, 24.0)],
	["HeliDrop_3", Vector3(46.0, 0.0, -12.6)],
]
## [name, kind, scene id, pos (room-side face), yaw, size, room, depth, door]: door breaches (no scene, no obstruction).
const BREACHES: Array = [
	["Breach_1", "door", "", Vector3(16.15, 0.0, -46.0), -90.0, Vector2(1.1, 2.1), "STA", 0.0,
		"Gameplay/Doors/StairAStreetDoor"],
	["Breach_2", "door", "", Vector3(51.8, 0.0, -35.0), 90.0, Vector2(1.1, 2.1), "CP-G", 0.0,
		"Gameplay/Doors/CarParkFireDoor"],
	["Breach_3", "door", "", Vector3(18.5, 0.0, 14.2), 180.0, Vector2(1.8, 2.1), "DR", 0.0,
		"Gameplay/Doors/DinerFrontDoor"],
]
