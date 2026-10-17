## Ostrander Federal G2 landmarks (OF-C2 lane B, ENV C): the bronze sunburst and the frieze over the bronze doors, the
## bronze portal round the doors, the lantern skylight's bronze glazing bars and curb skin, the banking counter (the 12
## windows: the 1.05 m ledge, the 1.50 m screen base, bandit glass, the brass grilles of the 6 closed windows, the gate
## piers, the bulkhead, the 12 teller work tops) and the bronze portal round the vault door. Design:
## docs/design/heists/ostrander_federal.md (Site: exterior landmarks 1-3; Ground notes; Audio/lighting palette).
## Visual only: every G1 collider stays as built (the lantern glazing keeps its hull, group `see_through` (D-142) and
## meta; the counter keeps every G1 dimension, QC-67 / OF-C3). A piece that replaces a greybox box hides the box's mesh
## and draws the art piece (tools/blender/props/ostrander_landmarks.py) to the same extents. Used by of_art_rooms.gd
## (the one call from build_greybox.gd); `b` = the generator (of_builder_base API).
extends RefCounted

## Facade pieces: wall props on the plaza face of the south wall (z 36.2) centred on the bronze doors, facing +Z.
const FACADE_PIVOT: Vector3 = Vector3(24.0, 0.0, 36.2)
## Map-coordinate pieces: [asset, pivot] (modelled around the pivot in map axes, placed with yaw 0).
const MAP_PIECES: Array = [
	["prop_of_lantern", Vector3(22.0, 8.6, 26.0)],
	["prop_of_teller_line", Vector3(24.0, 0.0, 17.0)],
	["prop_of_vault_portal", Vector3(30.0, -4.0, 12.7)],
]
## G1 greybox boxes the art pieces replace (their meshes are hidden; collision untouched).
const HIDE_MESHES: Array[String] = [
	"Geometry/Building/Counter/ScreenBaseW", "Geometry/Building/Counter/CustomerLedgeW",
	"Geometry/Building/Counter/ScreenBaseE", "Geometry/Building/Counter/CustomerLedgeE",
	"Geometry/Building/Counter/GatePier0", "Geometry/Building/Counter/GatePier1",
	"Geometry/Building/Counter/Bulkhead", "Geometry/Building/Counter/GateHeader",
]
## Glass the landmarks own: the lantern glazing (both faces seen: the terrace and the hall) and the bandit glass.
const GLASS_BODIES: Array[String] = [
	"Geometry/Building/Lantern/Glazing", "Geometry/Building/Counter/BanditGlassW",
	"Geometry/Building/Counter/BanditGlassE",
]
## The counter's two runs (x) and its 6 windows each; the closed windows (index 0-11, west to east) carry a grille.
## Staffed: the bays of the teller stations x 13 / 15 / 17 and 31 / 33 / 35 (Ground plan `t`; spawns Teller1-4).
const RUNS: Array = [[8.1, 22.9], [25.1, 39.9]]
const BAYS: int = 6
const CLOSED_WINDOWS: Array[int] = [0, 4, 5, 6, 7, 11]
## The hall clock over the teller gate, on the bulkhead's hall face (z 17.5).
const CLOCK_POS: Vector3 = Vector3(24.0, 3.3, 17.5)

var b: Object
var report: PackedStringArray = PackedStringArray()


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	var root: HeistMap = b.get(&"map_root")
	var lm: Node3D = b.call(&"add", b.call(&"n", "Geometry"), b.call(&"node3d", "Landmarks")) as Node3D
	var facade: Node3D = _piece(lm, "Sunburst", "prop_of_sunburst", Transform3D(Basis(Vector3.UP, PI), FACADE_PIVOT))
	facade.set_meta(&"landmark", "sunburst")
	_piece(lm, "BronzePortal", "prop_of_bronze_portal", Transform3D(Basis(Vector3.UP, PI), FACADE_PIVOT)) \
		.set_meta(&"landmark", "bronze_doors")
	for mp: Array in MAP_PIECES:
		var asset: String = String(mp[0])
		var nm: String = asset.trim_prefix("prop_of_").to_pascal_case()
		_piece(lm, nm, asset, Transform3D(Basis.IDENTITY, mp[1] as Vector3)).set_meta(&"landmark", asset.trim_prefix("prop_of_"))
	for path: String in HIDE_MESHES:
		var mi: MeshInstance3D = root.get_node_or_null(path + "/Mesh") as MeshInstance3D
		if mi == null:
			report.append("ERROR landmarks: no greybox mesh %s" % path)
			continue
		mi.visible = false
	var glass: Material = _glass()
	for gp: String in GLASS_BODIES:
		var gm: MeshInstance3D = root.get_node_or_null(gp + "/Mesh") as MeshInstance3D
		if gm == null:
			report.append("ERROR landmarks: no glass mesh %s" % gp)
			continue
		gm.material_override = glass
	_grilles(lm)
	_worktops(root)
	var clock: Node3D = _piece(lm, "HallClock", "prop_clock_harbor", Transform3D(Basis(Vector3.UP, PI), CLOCK_POS))
	clock.set_meta(&"kind", "clock")
	report.append("landmarks: sunburst, portal, lantern, teller line (%d grilles, 12 work tops), vault portal"
		% CLOSED_WINDOWS.size())


func _piece(parent: Node3D, nm: String, asset: String, xf: Transform3D) -> Node3D:
	var ps: PackedScene = b.call(&"catalog_scene", asset) as PackedScene
	if ps == null:
		report.append("ERROR landmarks: no scene for %s" % asset)
		return Node3D.new()
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	inst.transform = xf
	b.call(&"add", parent, inst)
	return inst


## The brass grille of each closed window: on the hall face of the bandit glass, centred on its bay.
func _grilles(lm: Node3D) -> void:
	var g: Node3D = b.call(&"add", lm, b.call(&"node3d", "TellerGrilles")) as Node3D
	var idx: int = 0
	for run: Array in RUNS:
		var w: float = (float(run[1]) - float(run[0])) / float(BAYS)
		for i: int in range(BAYS):
			if idx in CLOSED_WINDOWS:
				var cx: float = float(run[0]) + (float(i) + 0.5) * w
				_piece(g, "Grille%02d" % (idx + 1), "prop_of_teller_grille", Transform3D(Basis.IDENTITY, Vector3(cx, 0.0, 17.0)))
			idx += 1


## The 12 teller work tops (Props/MapBuilt/TellerWorktopNN, kind teller_worktop): the art cabinet inside each box, the
## greybox mesh hidden; the box, its metas (hide_behind, kind) and collider stay.
func _worktops(root: HeistMap) -> void:
	for i: int in range(1, 13):
		var body: Node3D = root.get_node_or_null("Props/MapBuilt/TellerWorktop%02d" % i) as Node3D
		if body == null:
			report.append("ERROR landmarks: no TellerWorktop%02d" % i)
			continue
		var mi: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
		if mi != null:
			mi.visible = false
		var ps: PackedScene = b.call(&"catalog_scene", "prop_of_teller_worktop") as PackedScene
		var vis: Node3D = ps.instantiate() as Node3D
		vis.name = "Visual"
		b.call(&"add", body, vis)


## Clear glass for the landmark glazing: the library glass_clear, world triplanar at 1 repeat / m (512 px/m, the style
## guide target; its 512 px tile, LIB_512), both faces (the lantern is seen from the terrace and from the hall).
static func _glass() -> Material:
	var src: BaseMaterial3D = load("res://world/materials/glass_clear.tres") as BaseMaterial3D
	var m: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	m.resource_name = "of_glass_landmark"
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.86, 0.9, 0.9, 0.55)
	return m
