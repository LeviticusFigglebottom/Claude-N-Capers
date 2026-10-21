## Ostrander Federal G2 landmarks (OF-C2 lane B, ENV C): the bronze sunburst and the frieze over the bronze doors, the
## bronze portal round the doors, the lantern skylight's bronze glazing bars and curb skin, the banking counter (the 12
## windows: the 1.05 m ledge, the 1.50 m screen base, bandit glass, the brass grilles of the 6 closed windows, the gate
## piers, the bulkhead, the 12 teller work tops: per-bay modules prop_of_teller_bay[_closed] drawn as two MultiMeshes, and the
## frame prop_of_teller_line) and the bronze portal round the vault door. Design:
## docs/design/heists/ostrander_federal.md (Site: exterior landmarks 1-3; Ground notes; Audio/lighting palette).
## Visual only: every G1 collider stays as built (the lantern glazing keeps its hull, group `see_through` (D-142) and
## meta; the counter keeps every G1 dimension, QC-67 / OF-C3). A piece that replaces a greybox box hides the box's mesh
## and draws the art piece (tools/blender/props/ostrander_landmarks.py) to the same extents. Used by of_art_rooms.gd
## (the one call from build_greybox.gd); `b` = the generator (of_builder_base API).
extends RefCounted

## Facade pieces: wall props on the plaza face of the south wall (z 36.2) centred on the bronze doors, facing +Z.
const FACADE_PIVOT: Vector3 = Vector3(24.0, 0.0, 36.2)
## The sunburst + frieze stand 4 mm off the facade (ostrander_landmarks.py SUN_GAP): their back face is the pivot.
const SUN_PIVOT: Vector3 = FACADE_PIVOT + Vector3(0.0, 0.0, 0.004)
## Map-coordinate pieces: [asset, pivot] (modelled around the pivot in map axes, placed with yaw 0).
const MAP_PIECES: Array = [
	["prop_of_lantern", Vector3(22.0, 8.6, 26.0)],
	["prop_of_teller_line", Vector3(24.0, 0.0, 17.0)],
	["prop_of_vault_portal", Vector3(30.0, -4.0, 12.7)],
	["prop_of_meridian_line", Vector3(24.0, -0.012, 24.7)],
]
## The meridian line (OF-C2 lane A; doc Site landmark 2, Audio/lighting: the oculus throws the sun's disc onto it): the
## greybox strip it replaces, and the disc: a narrow warm spot from the oculus' gilt fillet (its fixture) onto month X.
const MERIDIAN_BOX: String = "Geometry/Building/Visual/Meridian"
const DISC_FROM: Vector3 = Vector3(21.0, 7.95, 29.62)
const DISC_TO: Vector3 = Vector3(24.0, 0.0, 28.9)
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
## The counter's 12 bays (windows 0-11 west to east, ostrander_landmarks.py RUNS / BAYS / CLOSED_WINDOWS): the bay
## modules are modelled about their bay centre at z 17 and drawn as one MultiMesh per module (one draw call per
## material for all its bays, as the one-piece counter was); the closed windows carry the brass grille.
const TELLER_RUNS: Array = [[8.1, 22.9], [25.1, 39.9]]
const TELLER_BAYS: int = 6
const TELLER_Z: float = 17.0
const TELLER_CLOSED: Array[int] = [0, 4, 5, 6, 7, 11]
const MMT: GDScript = preload("res://world/props/multimesh_tiles.gd")
## The hall clock over the teller gate, on the bulkhead's hall face (z 17.5).
const CLOCK_POS: Vector3 = Vector3(24.0, 3.3, 17.5)

var b: Object
var report: PackedStringArray = PackedStringArray()


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	var root: HeistMap = b.get(&"map_root")
	var lm: Node3D = b.call(&"add", b.call(&"n", "Geometry"), b.call(&"node3d", "Landmarks")) as Node3D
	var facade: Node3D = _piece(lm, "Sunburst", "prop_of_sunburst", Transform3D(Basis(Vector3.UP, PI), SUN_PIVOT))
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
	_teller_bays(lm)
	_worktops(root)
	_meridian(root, lm)
	var clock: Node3D = _piece(lm, "HallClock", "prop_clock_harbor", Transform3D(Basis(Vector3.UP, PI), CLOCK_POS))
	clock.set_meta(&"kind", "clock")
	report.append("landmarks: sunburst, portal, lantern, teller line (+ 12 work tops, 6 grilles), vault portal, meridian line + sun disc")


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


## The meridian line: the greybox strip goes (the inlay sits flush in the floor's band, lane A's finish leaves it
## open), and the sun disc: a SpotLight3D (no shadows, 3 deg half angle ~ a 1 m disc) on an `Oculus` fixture node (a
## gilt cap on the oculus fillet, group fixture) aimed at month X (October).
func _meridian(root: HeistMap, lm: Node3D) -> void:
	var mi: MeshInstance3D = root.get_node_or_null(MERIDIAN_BOX) as MeshInstance3D
	if mi == null:
		report.append("ERROR landmarks: no greybox meridian strip")
	else:
		mi.visible = false
	var oc: Node3D = b.call(&"node3d", "Oculus", DISC_FROM) as Node3D
	oc.add_to_group(&"fixture", true)
	oc.set_meta(&"fixture", true)
	b.call(&"add", lm, oc)
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.name = "Cap"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.24, 0.04, 0.24)
	cap.mesh = bm
	var gilt: BaseMaterial3D = (load("res://world/props/materials/pr_of_gilt.tres") as BaseMaterial3D).duplicate()
	gilt.resource_name = "of_oculus_gilt"
	gilt.uv1_triplanar = true
	gilt.uv1_world_triplanar = true
	gilt.uv1_scale = Vector3.ONE * 0.5
	cap.material_override = gilt
	b.call(&"add", oc, cap)
	var sp: SpotLight3D = SpotLight3D.new()
	sp.name = "SunDisc"
	sp.position = Vector3(0.0, -0.05, 0.0)
	b.call(&"add", oc, sp)
	sp.basis = Basis.looking_at((DISC_TO - DISC_FROM).normalized(), Vector3.UP)
	sp.spot_range = DISC_FROM.distance_to(DISC_TO) + 1.0
	sp.spot_angle = 3.2
	sp.spot_angle_attenuation = 0.15
	sp.light_color = Color(1.0, 0.9, 0.72)
	sp.light_energy = 14.0
	sp.layers = 1 | (1 << 20)
	sp.shadow_enabled = false


## The counter bays: `TellerBays` (open windows) and `TellerBaysClosed` (grilles), MultiMeshInstance3D baked via
## multimesh_tiles.gd (the headless generator keeps no MultiMesh buffer), visual only, no visibility range (the counter is
## seen from the whole hall).
func _teller_bays(lm: Node3D) -> void:
	var open: PackedFloat32Array = PackedFloat32Array()
	var closed: PackedFloat32Array = PackedFloat32Array()
	var end_w: PackedFloat32Array = PackedFloat32Array()
	var end_e: PackedFloat32Array = PackedFloat32Array()
	var last: int = TELLER_RUNS.size() * TELLER_BAYS - 1
	var idx: int = 0
	for run: Array in TELLER_RUNS:
		var w: float = (float(run[1]) - float(run[0])) / float(TELLER_BAYS)
		for i: int in range(TELLER_BAYS):
			var cx: float = float(run[0]) + (float(i) + 0.5) * w
			var row: PackedFloat32Array = PackedFloat32Array([cx, 0.0, TELLER_Z, 0.0])
			if idx == 0 and idx in TELLER_CLOSED:
				end_w.append_array(row)   # OF-C2: the run-end modules (ledge short of the side walls' door frames)
			elif idx == last and idx in TELLER_CLOSED:
				end_e.append_array(row)
			elif idx in TELLER_CLOSED:
				closed.append_array(row)
			else:
				open.append_array(row)
			idx += 1
	for spec: Array in [["TellerBays", "prop_of_teller_bay", open], ["TellerBaysClosed", "prop_of_teller_bay_closed", closed],
			["TellerBayEndW", "prop_of_teller_bay_closed_endw", end_w],
			["TellerBayEndE", "prop_of_teller_bay_closed_ende", end_e]]:
		if (spec[2] as PackedFloat32Array).is_empty():
			continue
		var ps: PackedScene = b.call(&"catalog_scene", String(spec[1])) as PackedScene
		if ps == null:
			report.append("ERROR landmarks: no scene for %s" % spec[1])
			continue
		var inst: Node = ps.instantiate()
		var mesh: Mesh = null
		for c: Node in inst.find_children("*", "MeshInstance3D", true, false):
			mesh = (c as MeshInstance3D).mesh
			break
		inst.free()
		if mesh == null:
			report.append("ERROR landmarks: %s has no mesh" % spec[1])
			continue
		var buf: PackedFloat32Array = spec[2]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var box: AABB = mesh.get_aabb()
		var bounds: AABB = AABB()
		for k: int in range(buf.size() / 4):
			var o: AABB = Transform3D(Basis.IDENTITY, Vector3(buf[k * 4], buf[k * 4 + 1], buf[k * 4 + 2])) * box
			bounds = o if k == 0 else bounds.merge(o)
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.set_script(MMT)
		mmi.name = String(spec[0])
		mmi.multimesh = mm
		mmi.set(&"instances", buf)
		mmi.custom_aabb = bounds
		mmi.set_meta(&"kind", "teller_bays")
		b.call(&"add", lm, mmi)


## The 12 teller work tops (Props/MapBuilt/TellerWorktopNN, kind teller_worktop): drawn by the bay modules (one mesh
## with each bay); the greybox mesh is hidden; the box, its metas (hide_behind, kind) and collider stay.
func _worktops(root: HeistMap) -> void:
	for i: int in range(1, 13):
		var mi: MeshInstance3D = root.get_node_or_null("Props/MapBuilt/TellerWorktop%02d/Mesh" % i) as MeshInstance3D
		if mi == null:
			report.append("ERROR landmarks: no TellerWorktop%02d mesh" % i)
			continue
		mi.visible = false


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
