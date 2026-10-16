## Gallery Night PO6-17 RNG assault events (D-114 §5 / D-115 #5): the marker data and the wall / window breach holes
## the generator cuts. Owner: ENV C. Kept out of gallery_night_layout.gd (that file is emitted from the plan tools);
## the markers are built by world/heists/shared/assault_markers.gd (contract: docs/levels/_art/po6_17/README.md).
extends RefCounted

const L: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_layout.gd")

## Turret vans: [name, pos (road, bottom-centre), yaw_deg (+Z = the van's forward)]. Wexley St northbound opposite the
## LD / EG east wall (P3 comes down the street from the north closure), and Aldous Parade eastbound opposite the
## Sculpture Court; clear of the E1 Mews van, the E2 portico limo and the P1-P4 street links.
const TURRET_VANS: Array = [
	["TurretVan_1", Vector3(51.0, 0.0, 14.0), 180.0],    # Wexley St, nose north: x 49.8-52.2, z 11.1-17.1
	["TurretVan_2", Vector3(-6.0, 0.0, 37.5), 90.0],     # Aldous Parade, eastbound: x -9..-3, z 36.3-38.7
]
## Helicopter orbit: [name, centre (y = flight height of the heli pivot), radius]: over the Great Hall and its oculus,
## inside the Grand Wexley Hotel (x 58.4, +22) and the Ostrander (x -16.4, +14).
const HELI_ORBITS: Array = [["HeliOrbit_1", Vector3(22.0, 34.0, 15.0), 24.0]]
## Rappel landing points: [name, pos]. The Great Hall roof (+11.0) south of the oculus, on the police-only P5 roof
## island: it reaches the hall by the existing QC-41 RappelLinkOculus (and the RappelOculus RAPPEL point), no new
## link. And Aldous Parade west of the portico limo.
const HELI_DROPS: Array = [
	["HeliDrop_1", Vector3(22.0, 11.0, 22.0)],
	["HeliDrop_2", Vector3(10.0, 0.0, 37.5)],
]
## Breach points (shared/assault_markers.gd row format): [name, kind, scene, pos on the room-side face (bottom-centre
## of the opening), yaw_deg (-Z into the room), size (w, h), room, depth (0)], plus the plan floor of the wall. Facade
## walls are EXT_T (0.4): `prop_breach_wall_t40` / `prop_breach_window`.
const BREACHES: Array = [
	# AO admin office (upper, next to the SV hack holdout): the north window made the breach window, rope from the
	# roof-deck parapet (+10.1).
	["Breach_1", "window", "prop_breach_window", Vector3(14.0, 5.4, 0.2), 180.0, Vector2(1.0, 2.1), "AO", 0.0],
	# WG Founders' Gallery: a blocked-up doorway in the west wall from the Sculpture Court, north of the French doors.
	["Breach_2", "wall", "prop_breach_wall_t40", Vector3(0.2, 0.0, 9.5), -90.0, Vector2(1.0, 2.2), "WG", 0.0],
	# EB Benefactors' Room: a blocked-up doorway in the Parade wall between the tall windows S1 and S2.
	["Breach_3", "wall", "prop_breach_wall_t40", Vector3(36.0, 0.0, 29.8), 0.0, Vector2(1.0, 2.2), "EB", 0.0],
	# LD Loading Dock: a blocked-up doorway in the Wexley St wall.
	["Breach_4", "wall", "prop_breach_wall_t40", Vector3(43.8, 0.0, 3.0), 90.0, Vector2(1.0, 2.2), "LD", 0.0],
]


## [axis, wall line, a0, a1, y0, y1] of a wall / window breach's opening (the marker sits on the room face).
static func opening(b: Array) -> Array:
	var p: Vector3 = b[3]
	var sz: Vector2 = b[5]
	var yaw: float = float(b[4])
	var along_x: bool = absf(sin(deg_to_rad(yaw))) < 0.5
	var into: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.FORWARD
	var line: float = (p.z - into.z * L.EXT_T * 0.5) if along_x else (p.x - into.x * L.EXT_T * 0.5)
	var c: float = p.x if along_x else p.z
	return ["x" if along_x else "z", line, c - sz.x * 0.5, c + sz.x * 0.5, p.y, p.y + sz.y]


## The breach holes on a wall run (floor f, axis, fixed, a0..a1): [[a0, a1, y0, y1], ...].
static func holes(f: String, axis: String, fixed: float, a0: float, a1: float) -> Array:
	var out: Array = []
	for b: Array in BREACHES:
		var o: Array = opening(b)
		if String(o[0]) == axis and absf(float(o[1]) - fixed) < 0.001 and float(o[2]) > a0 and float(o[3]) < a1 \
				and absf(float(o[4]) - float(L.FFL[f])) < 0.001:
			out.append([float(o[2]), float(o[3]), float(o[4]), float(o[5])])
	return out


## True for a plan opening (window) a breach replaces: the breach scene's Intact state glazes it.
static func replaced(o: Array) -> bool:
	for b: Array in BREACHES:
		var q: Array = opening(b)
		if String(o[2]) == String(q[0]) and absf(float(o[3]) - float(q[1])) < 0.001 \
				and float(o[4]) < float(q[3]) and float(o[5]) > float(q[2]) and float(o[6]) < float(q[5]) and float(o[7]) > float(q[4]):
			return true
	return false
