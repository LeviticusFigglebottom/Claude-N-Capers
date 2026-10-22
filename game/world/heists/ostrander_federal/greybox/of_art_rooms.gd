## Ostrander Federal G2 room kits, lane B (OF-C2, ENV C): the private-client lounge PC (`lounge_client`), the
## safe-deposit hall SD (`deposit_hall`) and the vault operations office VO (`office_vault_ops`), plus the deposit-box
## walls of SD and VT, then the landmarks (of_landmarks.gd). One call from build_greybox.gd, before the navmesh bake:
##   preload(".../of_art_rooms.gd").new(self).call(&"build")
## Design: docs/design/heists/ostrander_federal.md (Room list; Basement / Ground / Gallery notes; Budgets: density, the
## 44 deposit boxes and the box rows as MultiMeshInstance3D). Kits: game/world/kits/<kit>.tres (the validator's
## density / variety rules); the placements are fixed tables (no RNG; each kit dresses one room, so no `variety` pair).
## * The G1 furniture boxes (Props/MapBuilt) keep their colliders, metas and nav obstructions; their greybox mesh is
##   hidden and an exact-fit art piece (tools/blender/props/ostrander_landmarks.py) is drawn inside the box.
## * Placed floor props get a box collider (catalog AABB, cut at the catalog `top`) and a nav obstruction; rugs, wall,
##   ceiling and "on" items get neither. Every gameplay marker, door swing, use point and review camera stays clear.
## * Deposit boxes: every non-interactive box door of the SD units (both faces) and the VT north / south walls is a
##   MultiMeshInstance3D tile (3 tile sizes per room, Geometry/BoxBanks: fixtures of the unit / wall faces); the 44
##   interactive DepositBox prefabs (20 VT + 24 SD) keep their own visual (they free themselves when looted) and get
##   the flush `prop_of_deposit_drawer` door that sits in the tile grid (columns 0.2 m, the drawer 3 columns x 2 rows at 1.00-1.45 m).
## * The VO code PC (`pc_vault_ops`, HackTerminal) gets the desktop `prop_of_desk_pc` visual (Screen / Panel).
extends RefCounted

const LM: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_landmarks.gd")
## Baked MultiMesh node (the headless generator cannot save a MultiMesh buffer): fills itself on _ready.
const MMT: GDScript = preload("res://world/props/multimesh_tiles.gd")

## [room, MapBuilt box, asset, yaw (deg) of the art piece inside the box]
const MAPBUILT_ART: Array = [
	["PC", "CoffeeTablePC", "prop_of_coffee_table_sq80", 0.0],
	["PC", "CoffeeServicePC", "prop_of_coffee_service_w160", 90.0],
	["SD", "AttendantDesk", "prop_of_attendant_desk_w160", 0.0],
	["SD", "BoxUnit1", "prop_of_box_unit_w950", 0.0],
	["SD", "BoxUnit2", "prop_of_box_unit_w950", 0.0],
	["SD", "BoxUnit3", "prop_of_box_unit_w950", 0.0],
	["SD", "BoothCounterSD", "prop_of_booth_counter_w900", 90.0],
	["SD", "BoothPartition1", "prop_of_booth_partition", 0.0],
	["SD", "BoothPartition2", "prop_of_booth_partition", 0.0],
	["SD", "BoothPartition3", "prop_of_booth_partition", 0.0],
	["VO", "DeskVO", "prop_of_desk_vault_ops", 90.0],
]

## Placed props per room: [name, asset, [x, y, z] (world; floor items at the floor, wall items at their centre on the
## wall face, ceiling items at the ceiling, "on" items on the host top), yaw (deg; the prop's front -Z: 0 north,
## 180 south, 90 west, -90 east)].
## PC (x 40-48, z 9-19, floor 0, ceiling 4.2): an armchair group round the G1 coffee table (the variant
## client chairs sit W / E of it), a sofa with side tables and lamps on the south wall, the coffee service, art.
const PC_PROPS: Array = [
	["ArmchairPCN", "prop_armchair", [44.25, 0.0, 12.85], 180.0],
	["ArmchairPCS", "prop_armchair", [44.25, 0.0, 15.15], 0.0],
	["SofaPC", "prop_sofa_w200", [44.6, 0.0, 18.455], 0.0],
	["SideTablePCW", "prop_side_table", [43.05, 0.0, 18.6], 0.0],
	["SideTablePCE", "prop_side_table", [46.15, 0.0, 18.6], 0.0],
	["TableLampPCW", "prop_table_lamp", [43.05, 0.56, 18.6], 0.0],
	["TableLampPCE", "prop_table_lamp", [46.15, 0.56, 18.6], 0.0],
	["PlantPCNW", "prop_plant_tall", [40.5, 0.0, 9.5], 180.0],
	["PlantPCNE", "prop_plant_tall", [47.45, 0.0, 9.5], 180.0],
	["CoffeeMachinePC", "prop_coffee_machine", [47.55, 0.9, 15.95], 90.0],
	["MugPC1", "prop_mug", [47.5, 0.9, 16.45], 90.0],
	["MugPC2", "prop_mug", [47.62, 0.9, 16.62], 90.0],
	["GlasswarePC", "prop_glassware", [47.55, 0.9, 17.0], 90.0],
	["ArtPCN1", "prop_wall_art_c", [41.75, 1.55, 9.1], 180.0],
	["ArtPCN2", "prop_wall_art_a", [46.3, 1.55, 9.1], 180.0],
	["ArtPCW", "prop_wall_art_c", [40.1, 1.55, 15.0], -90.0],
	["ArtPCS", "prop_wall_art_a", [44.6, 1.55, 18.9], 0.0],
	["LeafletRackPC", "prop_leaflet_rack", [45.3, 1.3, 9.1], 180.0],
	["WallLampPCE", "prop_wall_lamp", [47.8, 2.4, 13.0], 90.0],
	["WallLampPCW", "prop_wall_lamp", [40.1, 2.4, 13.4], -90.0],
	["PendantPC1", "prop_pendant_brass", [44.25, 4.2, 14.0], 0.0],
	["PendantPC2", "prop_pendant_brass", [44.6, 4.2, 17.6], 0.0],
	["SwitchPC", "prop_light_switch", [40.1, 1.2, 17.15], -90.0],
]
## Chairs a spawned NPC sits on (OF-C1, D-136 §3b.5: the SD attendant, Spawns/SDAttendant on its Seat): no collider
## and no nav obstruction, so the seated spawn stays on the navmesh (SL npc_seat, D-063 / D-130).
const NPC_SEATS: Array[String] = ["ChairSDAttendant"]
## SD (x 34-48, z 9-25, floor -4, ceiling -0.8): the attendant's desk set, the booth chairs / lamps / slips, a viewing
## table with a chair in each wide aisle, a bench, the clock, a 4000 K panel grid over the aisles.
const SD_PROPS: Array = [
	["ChairSDAttendant", "prop_chair_office", [37.0, -4.0, 9.55], 180.0],
	["MonitorSD", "prop_monitor", [37.2, -3.25, 10.35], 0.0],
	["KeyboardSD", "prop_keyboard_mouse", [37.15, -3.25, 10.06], 0.0],
	["DeskLampSD", "prop_desk_lamp", [36.45, -3.25, 10.3], 0.0],
	["DeskPhoneSD", "prop_phone_desk", [37.66, -3.25, 10.2], 0.0],
	["PapersSD", "prop_papers", [36.78, -3.25, 10.12], 15.0],
	["KeyCabinetSD", "prop_key_cabinet", [38.6, -2.5, 9.1], 180.0],
	["ChairSDBooth1", "prop_chair_consult", [46.6, -4.0, 13.25], -90.0],
	["ChairSDBooth4", "prop_chair_consult", [46.6, -4.0, 20.75], -90.0],
	["LampSDBooth2", "prop_table_lamp", [47.55, -3.1, 15.5], 90.0],
	["LampSDBooth3", "prop_table_lamp", [47.55, -3.1, 18.5], 90.0],
	["SlipsSDBooth1", "prop_deposit_slips", [47.45, -3.1, 13.25], 90.0],
	["SlipsSDBooth4", "prop_deposit_slips", [47.45, -3.1, 20.75], 90.0],
	["TableSDAisle1", "prop_vault_table", [37.0, -4.0, 14.55], 0.0],
	["ChairSDAisle1", "prop_chair_visitor", [37.0, -4.0, 15.2], 0.0],
	["TableSDAisle2", "prop_vault_table", [43.0, -4.0, 19.55], 0.0],
	["ChairSDAisle2", "prop_chair_visitor", [43.0, -4.0, 20.2], 0.0],
	["BenchSD", "prop_vault_bench", [37.4, -4.0, 24.59], 0.0],
	["ClockSD", "prop_clock_harbor", [40.25, -1.85, 24.8], 0.0],
	["PlantSD", "prop_plant_tall", [47.45, -4.0, 9.5], 180.0],
	["ExtinguisherSD", "prop_fire_extinguisher", [40.7, -2.95, 9.1], 180.0],
	["ExitSignSD", "prop_exit_sign", [42.0, -1.65, 9.1], 180.0],
	["MirrorSD", "prop_convex_mirror", [47.8, -1.6, 24.4], 90.0],
]
## SD ceiling panels: x over the aisles, z rows (the 4000 K grid).
const SD_PANEL_X: Array[float] = [37.0, 40.25, 43.5]
const SD_PANEL_Z: Array[float] = [10.6, 14.55, 19.55, 23.55]
## VO (x 42-48, z 9-18, floor 5, ceiling 8.0): the vault-schedule desk set (the G1 desk, the code PC and the keycard
## stay), files and the schedule board on the north wall, a credenza with the key cabinet on the south wall.
const VO_PROPS: Array = [
	["ChairVOVisitor", "prop_chair_visitor", [45.85, 5.0, 12.5], 90.0],
	["FileCabinetVO1", "prop_file_cabinet", [46.25, 5.0, 9.43], 180.0],
	["FileCabinetVO2", "prop_file_cabinet", [46.75, 5.0, 9.43], 180.0],
	["BookshelfVO", "prop_bookshelf", [43.2, 5.0, 9.275], 180.0],
	["ScheduleBoardVO", "prop_bulletin_board", [44.75, 6.55, 9.1], 180.0],
	["CredenzaVO", "prop_credenza", [45.0, 5.0, 17.666], 0.0],
	["BindersVO", "prop_binders", [44.55, 5.75, 17.68], 0.0],
	["PlantSmallVO", "prop_plant_small", [45.55, 5.75, 17.7], 0.0],
	["KeyCabinetVO", "prop_key_cabinet", [46.6, 6.5, 17.9], 0.0],
	["PrinterVO", "prop_printer_mfp", [42.34, 5.0, 16.2], -90.0],
	["PlantVO", "prop_plant_tall", [47.45, 5.0, 17.55], 0.0],
	["BinVO", "prop_bin_office", [44.4, 5.0, 11.55], 0.0],
	["DeskLampVO", "prop_desk_lamp", [45.15, 5.75, 13.05], 90.0],
	["PapersVO", "prop_papers", [44.82, 5.75, 12.2], 90.0],
	["MugVO", "prop_mug", [44.8, 5.75, 13.08], 90.0],
	["ArtVOW", "prop_wall_art_b", [42.1, 6.55, 15.3], -90.0],
	["ArtVOE", "prop_wall_art_a", [47.8, 6.55, 11.0], 90.0],
	["PanelVO1", "prop_ceiling_panel_neutral", [45.0, 8.0, 11.2], 0.0],
	["PanelVO2", "prop_ceiling_panel_neutral", [45.0, 8.0, 15.2], 0.0],
	["SwitchVO", "prop_light_switch", [42.1, 6.2, 14.0], -90.0],
]

## Deposit-box banks: [name, room, face origin (left end, floor), along (unit), outward normal, columns of 0.2 m,
## prefab door centres (along, m from the origin)]. SD units: x 35.7-44.7 on each face (pilasters at the ends); the
## interactive boxes are on the south faces (HallBox01-24 at x 36.0 + 1.2 k). VT: the north wall (z 13.3) either side
## of the ladder bay (x 22.5-25.3), the south wall (z 24.8); the frames are the `prop_of_box_bank_w*` pieces.
const COL_W: float = 0.2
const BANKS: Array = [
	["Unit1S", "SD", Vector3(35.7, -4.0, 12.3), Vector3.RIGHT, Vector3.BACK, 45, [0.3, 1.5, 2.7, 3.9, 5.1, 6.3, 7.5, 8.7]],
	["Unit1N", "SD", Vector3(35.7, -4.0, 11.8), Vector3.RIGHT, Vector3.FORWARD, 45, []],
	["Unit2S", "SD", Vector3(35.7, -4.0, 17.3), Vector3.RIGHT, Vector3.BACK, 45, [0.3, 1.5, 2.7, 3.9, 5.1, 6.3, 7.5, 8.7]],
	["Unit2N", "SD", Vector3(35.7, -4.0, 16.8), Vector3.RIGHT, Vector3.FORWARD, 45, []],
	["Unit3S", "SD", Vector3(35.7, -4.0, 22.3), Vector3.RIGHT, Vector3.BACK, 45, [0.3, 1.5, 2.7, 3.9, 5.1, 6.3, 7.5, 8.7]],
	["Unit3N", "SD", Vector3(35.7, -4.0, 21.8), Vector3.RIGHT, Vector3.FORWARD, 45, []],
	["VaultN1", "VT", Vector3(14.7, -4.0, 13.3), Vector3.RIGHT, Vector3.BACK, 39, [0.3, 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3]],
	["VaultN2", "VT", Vector3(25.3, -4.0, 13.3), Vector3.RIGHT, Vector3.BACK, 16, [0.3, 1.1, 1.9]],
	["VaultS", "VT", Vector3(14.7, -4.0, 24.8), Vector3.RIGHT, Vector3.FORWARD, 94,
		[1.3, 3.3, 5.3, 7.3, 9.3, 11.3, 13.3, 15.3, 17.3]],
]
## VT bank frames: [bank, asset (width)].
const BANK_FRAMES: Dictionary = {"VaultN1": "prop_of_box_bank_w780", "VaultN2": "prop_of_box_bank_w320",
	"VaultS": "prop_of_box_bank_w1880"}
## Tile rows above the floor: [bottom, height, tile] ("m" rows pair into "l" doors by the pattern; "s" small doors).
const ROWS: Array = [
	[0.1, 0.225, "m"], [0.325, 0.225, "m"], [0.55, 0.225, "m"], [0.775, 0.225, "m"], [1.0, 0.225, "m"],
	[1.225, 0.225, "m"], [1.45, 0.15, "s"], [1.6, 0.15, "s"], [1.75, 0.15, "s"],
]
## Rows taken by an interactive box door (1.00-1.45).
const PREFAB_ROWS: Array[int] = [4, 5]
const TILE_ASSETS: Dictionary = {"s": "prop_of_box_door_s", "m": "prop_of_box_door_m", "l": "prop_of_box_door_l"}
## The tiles sit on the face (front 17 mm proud, as the drawer).
const TILE_SINK: float = 0.0
## Box-door tiles draw to this distance (the SD hall is 16 m deep, the vault 20 m wide).
const TILE_VIS: float = 28.0
## Interior props (placed and the G1 furniture art) draw to this distance.
const ROOM_VIS: float = 22.0
## Near-range wrappers of the catalog props placed here (generated by _near_scene).
const NEAR_DIR: String = "res://world/heists/ostrander_federal/art/props_near_b/"

var b: Object
var report: PackedStringArray = PackedStringArray()
var _tiles: int = 0
var _near: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	var root: HeistMap = b.get(&"map_root")
	var props: Node3D = b.call(&"n", "Props")
	var art: Node3D = b.call(&"add", props, b.call(&"node3d", "ArtRoomsB")) as Node3D
	for row: Array in MAPBUILT_ART:
		_mapbuilt_art(root, row)
	var counts: Dictionary = {}
	counts["PC"] = _place_all(_folder(art, "PC"), PC_PROPS)
	counts["SD"] = _place_all(_folder(art, "SD"), SD_PROPS) + _sd_panels(_folder(art, "SD"))
	counts["VO"] = _place_all(_folder(art, "VO"), VO_PROPS)
	_banks(b.call(&"add", b.call(&"n", "Geometry"), b.call(&"node3d", "BoxBanks")) as Node3D)
	_box_prefab_visuals(root)
	_code_pc(root)
	report.append("rooms B: PC %d, SD %d, VO %d placed props; %d box-door tiles in %d banks"
		% [counts["PC"], counts["SD"], counts["VO"], _tiles, BANKS.size()])
	var lm: RefCounted = LM.new(b)
	lm.call(&"build")
	report.append_array(lm.get(&"report"))
	var errs: PackedStringArray = b.get(&"errors")
	for line: String in report:
		printerr("art B: " + line)
		if line.begins_with("ERROR"):
			errs.append(line)
	b.set(&"errors", errs)


func _folder(parent: Node3D, nm: String) -> Node3D:
	var f: Node3D = parent.get_node_or_null(nm) as Node3D
	if f == null:
		f = b.call(&"add", parent, b.call(&"node3d", nm)) as Node3D
	return f


# --- G1 furniture -> art -----------------------------------------------------------------------------

func _mapbuilt_art(root: HeistMap, row: Array) -> void:
	var body: Node3D = root.get_node_or_null("Props/MapBuilt/" + String(row[1])) as Node3D
	if body == null:
		report.append("ERROR %s: no MapBuilt box %s" % [row[0], row[1]])
		return
	var mi: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
	if mi != null:
		mi.visible = false
	var ps: PackedScene = _near_scene(String(row[2]))
	if ps == null:
		return
	var vis: Node3D = ps.instantiate() as Node3D
	vis.name = "Visual"
	vis.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row[3]))), Vector3.ZERO)
	b.call(&"add", body, vis)
	# the G1 box stays the gameplay collider: a support prop's own collision is switched off (as of_dress_a.gd)
	var shapes: Array[Node] = vis.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty():
		root.set_editable_instance(vis, true)
		for m: Node in vis.find_children("*", "", true, false):
			if m.scene_file_path != "":
				root.set_editable_instance(m, true)
		for co: Node in vis.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
		for s: Node in shapes:
			(s as CollisionShape3D).disabled = true


## Interior props draw to ROOM_VIS at most (as Shadow Ledger's near-range wrappers, sl_dress.near_scene_path): the hall
## views look through the lounge, the deposit hall and the gallery offices (no occluders yet); none of these rooms is
## deeper than 21 m. A catalog scene whose meshes draw further gets a wrapper in NEAR_DIR (generated, byte-stable).
func _near_scene(asset: String) -> PackedScene:
	if _near.has(asset):
		return _near[asset]
	var base: PackedScene = b.call(&"catalog_scene", asset) as PackedScene
	if base == null:
		return null
	var out: PackedScene = base
	var inst: Node = base.instantiate()
	var body: PackedStringArray = []
	var editable: PackedStringArray = []
	for m: Node in inst.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = m as GeometryInstance3D
		if gi.visibility_range_end > 0.0 and gi.visibility_range_end <= ROOM_VIS:
			continue
		body.append('\n[node name="%s" parent="%s"]\nvisibility_range_end = %.1f\nvisibility_range_end_margin = %.1f\n'
			% [m.name, String(inst.get_path_to(m.get_parent())), ROOM_VIS, ROOM_VIS * 0.1] + "visibility_range_fade_mode = 1\n")
		var a: Node = m.get_parent()
		while a != inst:
			if a.scene_file_path != "" and not editable.has(String(inst.get_path_to(a))):
				editable.append(String(inst.get_path_to(a)))
			a = a.get_parent()
	if not body.is_empty():
		var text: String = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="%s" id="1_base"]\n' \
			% base.resource_path + '\n[node name="%s" instance=ExtResource("1_base")]\n' % inst.name + "".join(body)
		editable.sort()
		for e: String in editable:
			text += '\n[editable path="%s"]\n' % e
		var path: String = NEAR_DIR + asset + ".tscn"
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path) != text:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NEAR_DIR))
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_string(text)
			f.close()
		out = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	inst.free()
	_near[asset] = out
	return out


# --- Placed props ------------------------------------------------------------------------------------

func _place_all(parent: Node3D, rows: Array) -> int:
	var n: int = 0
	for r: Array in rows:
		if _place(parent, String(r[0]), String(r[1]), b.call(&"v3", r[2]), float(r[3])) != null:
			n += 1
	return n


func _place(parent: Node3D, nm: String, asset: String, pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _near_scene(asset)
	if ps == null:
		report.append("ERROR %s: no scene for %s" % [nm, asset])
		return null
	var cat: Dictionary = PropCatalog.entry(StringName(asset))
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos)
	inst.transform = xf
	b.call(&"add", parent, inst)
	var place: String = String(cat.get("place", "floor"))
	var mount: String = String(cat.get("mount", ""))
	if mount != "" or place in ["on", "ceiling", "wall_mount", "above_door", "rug"]:
		return inst
	if nm in NPC_SEATS:   # a sitter's chair: no collider, no nav obstruction (SL npc_seat precedent)
		inst.set_meta(&"npc_seat", true)
		for co: Node in inst.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
			for cs: Node in co.find_children("*", "CollisionShape3D", true, false):
				(cs as CollisionShape3D).disabled = true
		(b.get(&"map_root") as Node).set_editable_instance(inst, true)   # keep the overrides in the saved scene
		return inst
	_collide(inst, cat, xf)
	return inst


## Box collider from the catalog AABB (cut at its `top` for a host) + a nav obstruction (as sl_dress.gd), unless the
## prop brings its own collision.
func _collide(inst: Node3D, cat: Dictionary, xf: Transform3D) -> void:
	var a: Array = cat.get("aabb", [])
	if a.size() != 6:
		return
	var bb: AABB = AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))
	var top: float = float(cat.get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		bb.size.y = top - bb.position.y
	if inst.find_children("*", "CollisionObject3D", true, false).is_empty():
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		b.call(&"add", inst, body)
		SurfaceTags.tag(body, StringName(String(cat.get("surface", ""))))
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(maxf(bb.size.x, 0.01), maxf(bb.size.y, 0.01), maxf(bb.size.z, 0.01))
		cs.shape = shape
		cs.position = bb.get_center()
		b.call(&"add", body, cs)
	b.call(&"obstruct", xf, bb)


func _sd_panels(parent: Node3D) -> int:
	var n: int = 0
	for x: float in SD_PANEL_X:
		for z: float in SD_PANEL_Z:
			n += 1
			_place(parent, "PanelSD%02d" % n, "prop_ceiling_panel_neutral", Vector3(x, -0.8, z), 0.0)
	return n


# --- Deposit boxes -----------------------------------------------------------------------------------

## The MultiMesh box-door banks (one MultiMeshInstance3D per room and tile size), the VT bank frames: built-in
## fixtures of the unit / wall faces, so under Geometry/BoxBanks/<bank> (a node at the bank's origin), not props.
func _banks(banks: Node3D) -> void:
	var meshes: Dictionary = {}
	for t: String in TILE_ASSETS:
		meshes[t] = _tile_mesh(String(TILE_ASSETS[t]))
	var rooms: Dictionary = {}  # room -> [node, {tile: [xforms]}]
	for bank: Array in BANKS:
		var nm: String = String(bank[0])
		var room: String = String(bank[1])
		var origin: Vector3 = bank[2]
		if not rooms.has(room):
			var rn: Node3D = b.call(&"add", banks, b.call(&"node3d", room, origin)) as Node3D
			rooms[room] = [rn, {"s": [], "m": [], "l": []}]
		var rnode: Node3D = rooms[room][0]
		var lists: Dictionary = rooms[room][1]
		var rel: Vector3 = origin - rnode.position
		var along: Vector3 = bank[3]
		var nrm: Vector3 = bank[4]
		var ncols: int = int(bank[5])
		var basis: Basis = Basis(Vector3.UP, atan2(-nrm.x, -nrm.z))  # the tile's front (-Z) faces the normal
		var taken: Dictionary = {}
		for uc: float in bank[6]:
			var c0: int = roundi((uc - 0.3) / COL_W)
			for c: int in range(c0, c0 + 3):
				for r: int in PREFAB_ROWS:
					taken[Vector2i(c, r)] = true
		for r: int in range(ROWS.size()):
			var row: Array = ROWS[r]
			var c: int = 0
			while c < ncols:
				if taken.has(Vector2i(c, r)):
					c += 1
					continue
				var kind: String = String(row[2])
				var span: int = 1
				if kind == "m" and c + 1 < ncols and not taken.has(Vector2i(c + 1, r)) and _pairs(nm, r, c):
					kind = "l"
					span = 2
				var u: float = (float(c) + float(span) * 0.5) * COL_W
				var y: float = float(row[0]) + float(row[1]) * 0.5
				var p: Vector3 = rel + along * u + Vector3.UP * y - nrm * TILE_SINK
				(lists[kind] as Array).append(Transform3D(basis, p))
				c += span
		if BANK_FRAMES.has(nm):
			var w: float = float(ncols) * COL_W
			var fps: PackedScene = b.call(&"catalog_scene", String(BANK_FRAMES[nm])) as PackedScene
			if fps != null:
				var frame: Node3D = fps.instantiate() as Node3D
				frame.name = "Frame" + nm
				frame.transform = Transform3D(basis, rel + along * (w * 0.5))
				b.call(&"add", rnode, frame)
	# one MultiMeshInstance3D per room and tile size (one draw call each: the tiles have one material)
	for room2: String in rooms:
		for t2: String in ["s", "m", "l"]:
			var xfs: Array = rooms[room2][1][t2]
			if xfs.is_empty() or meshes[t2] == null:
				continue
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[t2]
			var buf: PackedFloat32Array = PackedFloat32Array()
			var bounds: AABB = AABB()
			var mesh_box: AABB = (meshes[t2] as Mesh).get_aabb()
			for i: int in range(xfs.size()):
				var xf: Transform3D = xfs[i]
				buf.append_array(PackedFloat32Array([xf.origin.x, xf.origin.y, xf.origin.z, xf.basis.get_euler().y]))
				bounds = xf * mesh_box if i == 0 else bounds.merge(xf * mesh_box)
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			mmi.set_script(MMT)
			mmi.name = "Doors" + t2.to_upper()
			mmi.multimesh = mm
			mmi.set(&"instances", buf)
			mmi.custom_aabb = bounds
			mmi.visibility_range_end = TILE_VIS
			mmi.visibility_range_end_margin = TILE_VIS * 0.1
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.set_meta(&"kind", "box_doors")
			b.call(&"add", rooms[room2][0], mmi)
			_tiles += xfs.size()


## Deterministic door pattern: some medium doors pair into a large one (no RNG; a small integer hash of the cell).
static func _pairs(bank: String, r: int, c: int) -> bool:
	if c % 2 != 0:
		return false
	var h: int = (bank.hash() & 0xFFFF) + r * 73 + c * 31
	return h % 5 < 2


## The door mesh of a tile asset (its single MeshInstance3D).
func _tile_mesh(asset: String) -> Mesh:
	var ps: PackedScene = b.call(&"catalog_scene", asset) as PackedScene
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	var mesh: Mesh = null
	for c: Node in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = (c as MeshInstance3D).mesh
		break
	inst.free()
	if mesh == null:
		report.append("ERROR boxes: %s has no mesh" % asset)
	return mesh


## The 44 DepositBox prefabs (VaultBoxN/S, HallBox): the flush drawer door that sits in the tile grid.
func _box_prefab_visuals(root: HeistMap) -> void:
	var ps: PackedScene = load("res://world/props/deposit_box/prop_of_deposit_drawer.tscn") as PackedScene
	var n: int = 0
	for c: Node in root.get_node("Gameplay/Loot").get_children():
		if String(c.get_meta(&"kind", "")) == "deposit_box" \
				and (String(c.name).begins_with("VaultBox") or String(c.name).begins_with("HallBox")):
			c.set(&"visual_scene", ps)
			n += 1
	if n != 44:
		report.append("ERROR boxes: %d deposit boxes re-skinned (expected 44)" % n)


## pc_vault_ops: the desktop PC visual on the VO desk.
func _code_pc(root: HeistMap) -> void:
	var pc: Node = root.get_node_or_null("Variants/Group_code_pc/Slot_pc_vault_ops/CodePC")
	if pc == null:
		report.append("ERROR VO: no code PC")
		return
	pc.set(&"visual_scene", load("res://world/props/hack_terminal/prop_of_desk_pc.tscn") as PackedScene)
