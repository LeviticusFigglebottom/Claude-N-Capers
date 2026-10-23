## Headless pre-planning blueprint exporter (D-115). Owner: ENV B. Tool only, never loaded by the game.
##   /opt/godot/godot --headless --path game --script res://content/preplanning/tools/blueprint_export.gd -- <heist_id> [...]
## Opens each heist's map (HeistRegistry.map_scene_path) read-only (instanced, never saved, never added
## to the tree) and writes res://content/data/preplanning/blueprints/<heist>.tres:
##  - rooms: the map's RoomVolume nodes under `Rooms` (room_id, purpose, floor_index, box shapes), one
##    "room" shape per box; a box also shows on the other floors whose floor level lies inside it
##    (stairs, lifts, double-height halls). Label: ui.preplan.bp.<heist>.<room_id> on the largest box.
##  - building: per floor, the bounding rects of each connected group of that floor's rooms.
##  - outside: the named ground slabs under Geometry/Site/Ground (street / sidewalk / alley by name),
##    else the exterior RoomVolumes; neighbour buildings from Geometry/Site/Blocks.
##  - points: the map's Preplan markers (PreplanBlueprint.from_nodes); the board re-reads them at runtime.
## Generated files: rerun this tool after the map changes instead of editing them by hand.
## The map's gameplay scripts print "Identifier not found" compile errors here (a --script run has no
## autoloads); harmless, only node names, RoomVolume data and collision boxes are read.
## Room names live in strings.csv (ui.preplan.bp.<heist>.<room_id lowercase>); ground slabs and
## neighbour blocks get a label only when ui.preplan.bp.<heist>.<node_name_snake_case> exists.
extends SceneTree

const OUT_DIR: String = "res://content/data/preplanning/blueprints"
const KEY_PREFIX: String = "ui.preplan.bp."
## StringTable.CSV_PATH (StringTable itself needs the Log autoload, which --script runs lack).
const STRINGS_CSV: String = "res://content/data/strings/strings.csv"
const MARGIN_M: float = 6.0
const MIN_AREA_M2: float = 2.0
const JOIN_GAP_M: float = 0.6
## Floor strings keys per heist (floor index order); other heists get floor keys from their levels.
const FLOOR_KEYS: Dictionary = {
	&"glasshouse": [&"ui.preplan.floor.ground", &"ui.preplan.floor.upper"],
	&"night_deposit": [&"ui.preplan.floor.basement", &"ui.preplan.floor.ground"],
	&"shadow_ledger": [&"ui.preplan.floor.level_40", &"ui.preplan.floor.level_41",
		&"ui.preplan.floor.level_42", &"ui.preplan.floor.roof"],
	&"dockside_burn": [&"ui.preplan.floor.landing", &"ui.preplan.floor.ground",
		&"ui.preplan.floor.mezzanine", &"ui.preplan.floor.roof"],
	# OF-B1 pre-staged for C's G1 (ostrander_federal_floors_ascii.py): Basement -4.0, Ground 0.0, Gallery 5.0,
	# Executive 8.6 (+ the hall-roof terrace), Roof 12.2. Room names: ui.preplan.bp.ostrander_federal.<id> (doc room list).
	&"ostrander_federal": [&"ui.preplan.floor.basement", &"ui.preplan.floor.ground",
		&"ui.preplan.floor.gallery", &"ui.preplan.floor.executive", &"ui.preplan.floor.roof"],
	# RT-B1 (doc "Levels"): Underpass -5.0 (exterior, no rooms), Street 0.0, Upper 3.5, Roof 7.0.
	&"rolling_thunder": [&"ui.preplan.floor.underpass", &"ui.preplan.floor.street", &"ui.preplan.floor.upper",
		&"ui.preplan.floor.roof"],
	# AH-B1 (doc "Floor plans"): Ground 0.0, Balcony 4.2 (the old dress circle: VIP, office suite, count room).
	&"afterhours": [&"ui.preplan.floor.ground", &"ui.preplan.floor.balcony"],
}
## Ground slab name fragments (lowercase) -> shape kind; first match wins. Unmatched slabs are streets.
const GROUND_KINDS: Array = [
	["seabed", &""], ["slipbed", &""], ["water", &""], ["pit", &""], ["recessfloor", &""],
	["sidewalk", &"sidewalk"], ["pavement", &"sidewalk"], ["quay", &"sidewalk"], ["pier", &"sidewalk"],
	["landing", &"sidewalk"], ["pontoon", &"sidewalk"], ["slip", &"sidewalk"],
	["alley", &"alley"], ["lane", &"alley"], ["yard", &"alley"], ["lot", &"alley"], ["mews", &"alley"],
	["vista", &"alley"], ["bellweather", &"alley"],
]
## Exterior RoomVolume dressing kits -> kind (when the map has no ground slabs, or above ground).
const EXTERIOR_KINDS: Dictionary = {
	&"exterior_alley": &"alley", &"exterior_lane": &"alley", &"exterior_lot": &"alley",
	&"exterior_yard": &"alley", &"exterior_street": &"street",
}
## Site blocks whose name contains one of these (lowercase) are props, not neighbour buildings.
const BLOCK_SKIP: Array[String] = [
	"car", "van", "truck", "trailer", "hull", "cabin", "gunwale", "wheelhouse", "mast", "hvac",
	"condenser", "ahu", "skylight", "crane", "barrier", "canopy", "hatch", "dumpster", "roofplant",
	"parapet", "kerb", "col2", "col3", "rail", "guard", "chassis", "shore", "boom", "girder", "portal",
]
## A floor slab belongs to a floor when its top is this close to the floor level.
const SLAB_TOLERANCE_M: float = 0.35
const MIN_BLOCK_AREA_M2: float = 20.0

var _strings: Dictionary = {}


func _init() -> void:
	_strings = _read_keys(STRINGS_CSV)
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	var failed: int = 0
	for id: String in ids:
		if not export_heist(StringName(id)):
			failed += 1
	quit(1 if failed > 0 or ids.is_empty() else 0)


func export_heist(heist_id: StringName) -> bool:
	var path: String = HeistRegistry.map_scene_path(heist_id)
	if path == "" or not ResourceLoader.exists(path):
		printerr("blueprint_export: no map scene for %s" % heist_id)
		return false
	var root: Node = (load(path) as PackedScene).instantiate()
	var bp: PreplanBlueprint = build(heist_id, root)
	root.free()
	if bp == null:
		printerr("blueprint_export: %s has no Rooms" % heist_id)
		return false
	var out: String = "%s/%s.tres" % [OUT_DIR, heist_id]
	var err: int = ResourceSaver.save(bp, out)
	print("blueprint_export: %s -> %s (%s)" % [heist_id, out, error_string(err)])
	_report(bp)
	return err == OK


func build(heist_id: StringName, root: Node) -> PreplanBlueprint:
	var holder: Node = root.get_node_or_null(^"Rooms")
	if holder == null:
		return null
	var rooms: Array[Dictionary] = []
	for n: Node in holder.get_children():
		var rv: RoomVolume = n as RoomVolume
		if rv == null:
			continue
		var boxes: Array[AABB] = []
		for c: Node in rv.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				var size: Vector3 = (cs.shape as BoxShape3D).size
				boxes.append(_global(cs) * AABB(-size * 0.5, size))
		if not boxes.is_empty():
			rooms.append({"id": rv.room_id, "purpose": rv.purpose, "floor": rv.floor_index,
				"kit": rv.dressing_kit, "boxes": boxes})
	var point_nodes: Array[Node] = PreplanBlueprint.map_points(root)
	var levels: Array[float] = _floor_levels(rooms, point_nodes)
	var floor_count: int = levels.size()
	var ground_floor: int = _closest_level(levels, 0.0)

	var bp: PreplanBlueprint = PreplanBlueprint.new()
	bp.heist_id = heist_id
	bp.placeholder = false
	bp.grid_step_m = 2.0
	bp.floor_names = _floor_names(heist_id, levels, ground_floor)

	# Bounds: every indoor room box and every point, plus a margin, snapped to 2 m (the outdoor
	# volumes run far down the streets and would shrink the building on the board).
	var area: Rect2 = Rect2()
	var first: bool = true
	for r: Dictionary in rooms:
		if r["purpose"] == &"exterior":
			continue
		for b: AABB in r["boxes"]:
			area = _rect(b) if first else area.merge(_rect(b))
			first = false
	for p: Node in point_nodes:
		var pos: Vector3 = _global(p as Node3D).origin
		area = area.expand(Vector2(pos.x, pos.z))
	area = area.grow(MARGIN_M)
	var x0: float = floorf(area.position.x / 2.0) * 2.0
	var z0: float = floorf(area.position.y / 2.0) * 2.0
	bp.bounds = Rect2(x0, z0, ceilf((area.end.x - x0) / 2.0) * 2.0, ceilf((area.end.y - z0) / 2.0) * 2.0)

	var shapes: Array[Dictionary] = []
	# Outside, drawn under everything else on every floor.
	var ground: Node = root.get_node_or_null(^"Geometry/Site/Ground")
	var has_ground: bool = ground != null and ground.get_child_count() > 0
	if has_ground:
		_add_ground(heist_id, ground, bp.bounds, shapes)
	var blocks: Node = root.get_node_or_null(^"Geometry/Site/Blocks")
	var inside: Array[Rect2] = []
	for r: Dictionary in rooms:
		if r["purpose"] != &"exterior":
			for b: AABB in r["boxes"]:
				inside.append(_rect(b))
	if blocks != null:
		_add_blocks(heist_id, blocks, bp.bounds, inside, shapes)
	var slabs: Array[AABB] = []
	var slab_root: Node = root.get_node_or_null(^"Geometry/Building/Slabs")
	if slab_root != null:
		_collect_boxes(slab_root, slabs)
	var ext_above: Array[Dictionary] = []
	for r: Dictionary in rooms:
		if r["purpose"] != &"exterior":
			continue
		var fl: int = int(r["floor"])
		var elevated: bool = fl > ground_floor
		if has_ground and not elevated:
			continue
		var kind: StringName = EXTERIOR_KINDS.get(r["kit"], &"sidewalk")
		var entry: Dictionary = {"room": r, "kind": kind, "floor": fl if elevated else -1}
		if elevated:
			ext_above.append(entry)
		else:
			_add_room_shapes(heist_id, r, kind, -1, bp.bounds, shapes)

	# Per floor: building footprint(s), elevated outdoor decks, then rooms (largest first).
	for f: int in range(floor_count):
		var floor_rects: Array[Rect2] = []
		var floor_rooms: Array[Dictionary] = []
		for r: Dictionary in rooms:
			if r["purpose"] == &"exterior":
				continue
			var on: Array[AABB] = _boxes_on_floor(r, f, levels)
			if on.is_empty():
				continue
			floor_rooms.append({"room": r, "boxes": on})
			for b: AABB in on:
				floor_rects.append(_rect(b))
		if not floor_rects.is_empty():
			for sb: AABB in slabs:
				if absf(sb.end.y - levels[f]) <= SLAB_TOLERANCE_M:
					floor_rects.append(_rect(sb))
		var decks: Array[Dictionary] = []
		for e: Dictionary in ext_above:
			if int(e["floor"]) == f:
				decks.append(e)
				for b: AABB in (e["room"] as Dictionary)["boxes"]:
					floor_rects.append(_rect(b))
		# Unlabelled: a footprint shares its corner (where labels are drawn) with its first room.
		for fp: Rect2 in _footprints(floor_rects):
			shapes.append({"kind": &"building", "rect": _snap(fp), "floor": f, "label": &""})
		for e: Dictionary in decks:
			_add_room_shapes(heist_id, e["room"], e["kind"], f, bp.bounds, shapes)
		floor_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _area(a["boxes"]) > _area(b["boxes"]))
		for fr: Dictionary in floor_rooms:
			var r2: Dictionary = (fr["room"] as Dictionary).duplicate()
			r2["boxes"] = fr["boxes"]
			_add_room_shapes(heist_id, r2, &"room", f, bp.bounds, shapes)
	bp.shapes = shapes
	return PreplanBlueprint.from_nodes(point_nodes, bp)


## One shape per box; the largest box carries the room's label.
func _add_room_shapes(heist_id: StringName, r: Dictionary, kind: StringName, fl: int, bounds: Rect2,
		shapes: Array[Dictionary]) -> void:
	var boxes: Array = r["boxes"]
	var biggest: int = -1
	var best: float = -1.0
	for i: int in range(boxes.size()):
		var a: float = _rect(boxes[i]).get_area()
		if a > best:
			best = a
			biggest = i
	var key: StringName = StringName("%s%s.%s" % [KEY_PREFIX, heist_id, String(r["id"]).to_lower()])
	for i: int in range(boxes.size()):
		var rc: Rect2 = _snap(_rect(boxes[i]).intersection(bounds))
		if rc.get_area() < MIN_AREA_M2:
			continue
		shapes.append({"kind": kind, "rect": rc, "floor": fl, "label": key if i == biggest else &""})


func _add_ground(heist_id: StringName, ground: Node, bounds: Rect2, shapes: Array[Dictionary]) -> void:
	var by_kind: Dictionary = {&"street": [], &"sidewalk": [], &"alley": []}
	for n: Node in ground.get_children():
		var kind: StringName = &"street"
		var lname: String = String(n.name).to_lower()
		for pair: Array in GROUND_KINDS:
			if lname.contains(String(pair[0])):
				kind = pair[1]
				break
		if kind == &"":
			continue
		for rc: Rect2 in _body_rects(n, bounds):
			(by_kind[kind] as Array).append({"kind": kind, "rect": rc, "floor": -1,
				"label": _key_if(heist_id, StringName(String(n.name).to_snake_case()))})
	for kind: StringName in [&"street", &"sidewalk", &"alley"]:
		for s: Dictionary in by_kind[kind]:
			shapes.append(s)


func _add_blocks(heist_id: StringName, blocks: Node, bounds: Rect2, inside: Array[Rect2],
		shapes: Array[Dictionary]) -> void:
	var kept: Array[Rect2] = []
	for n: Node in blocks.get_children():
		var lname: String = String(n.name).to_lower()
		var skip: bool = false
		for frag: String in BLOCK_SKIP:
			if lname.contains(frag):
				skip = true
				break
		if skip:
			continue
		for rc: Rect2 in _body_rects(n, bounds):
			if rc.get_area() < MIN_BLOCK_AREA_M2 or _covered(rc, kept, 0.9) or _covered(rc, inside, 0.5):
				continue
			kept.append(rc)
			shapes.append({"kind": &"neighbour", "rect": rc, "floor": -1,
				"label": _key_if(heist_id, StringName(String(n.name).to_snake_case()))})


## Box collision rects (x, z) of a body, clipped to the bounds; none below MIN_AREA_M2.
func _body_rects(n: Node, bounds: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Node in n.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		var rc: Rect2 = _snap(_rect(_global(cs) * AABB(-size * 0.5, size)).intersection(bounds))
		if rc.get_area() >= MIN_AREA_M2:
			out.append(rc)
	return out


## Every box collision (world AABB) under `n`, recursively.
static func _collect_boxes(n: Node, out: Array[AABB]) -> void:
	for c: Node in n.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			var size: Vector3 = (cs.shape as BoxShape3D).size
			out.append(_global(cs) * AABB(-size * 0.5, size))
		_collect_boxes(c, out)


## True when `frac` of rc's area lies inside one of `rects`.
static func _covered(rc: Rect2, rects: Array[Rect2], frac: float) -> bool:
	for o: Rect2 in rects:
		if rc.intersection(o).get_area() >= rc.get_area() * frac:
			return true
	return false


## Floor level per floor index: the lowest room box bottom of that floor (median of the rooms),
## else the lowest PREPLAN point on it.
static func _floor_levels(rooms: Array[Dictionary], points: Array[Node]) -> Array[float]:
	var per: Dictionary = {}
	var top: int = 0
	for r: Dictionary in rooms:
		var f: int = int(r["floor"])
		top = maxi(top, f)
		if r["purpose"] == &"exterior":
			continue
		var low: float = INF
		for b: AABB in r["boxes"]:
			low = minf(low, b.position.y)
		if not per.has(f):
			per[f] = []
		(per[f] as Array).append(low)
	var pts: Dictionary = {}
	for p: Node in points:
		var f2: int = int(p.get_meta(&"floor", 0))
		top = maxi(top, f2)
		var y: float = _global(p as Node3D).origin.y
		pts[f2] = minf(float(pts.get(f2, INF)), y)
	var out: Array[float] = []
	for f3: int in range(top + 1):
		if per.has(f3):
			var arr: Array = per[f3]
			arr.sort()
			out.append(float(arr[arr.size() / 2]))
		elif pts.has(f3):
			out.append(float(pts[f3]))
		else:
			out.append(out[f3 - 1] + 3.6 if f3 > 0 else 0.0)
	return out


static func _closest_level(levels: Array[float], y: float) -> int:
	var best: int = 0
	for i: int in range(levels.size()):
		if absf(levels[i] - y) < absf(levels[best] - y):
			best = i
	return best


static func _floor_names(heist_id: StringName, levels: Array[float], ground_floor: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if FLOOR_KEYS.has(heist_id) and (FLOOR_KEYS[heist_id] as Array).size() == levels.size():
		for k: StringName in FLOOR_KEYS[heist_id]:
			out.append(k)
		return out
	for i: int in range(levels.size()):
		if i < ground_floor:
			out.append(&"ui.preplan.floor.basement")
		elif i == ground_floor:
			out.append(&"ui.preplan.floor.ground")
		elif i == levels.size() - 1 and i > ground_floor + 1:
			out.append(&"ui.preplan.floor.roof")
		else:
			out.append(&"ui.preplan.floor.upper")
	return out


## A room's boxes shown on floor f: all of them on its own floor; on another floor the boxes whose
## height spans that floor's level (at least 2 m above it).
static func _boxes_on_floor(r: Dictionary, f: int, levels: Array[float]) -> Array[AABB]:
	var out: Array[AABB] = []
	for b: AABB in r["boxes"]:
		if int(r["floor"]) == f:
			out.append(b)
		elif levels[f] >= b.position.y - 0.3 and levels[f] <= b.end.y - 2.0:
			out.append(b)
	return out


## Bounding rects of the groups of touching rects (gap <= JOIN_GAP_M), merged until stable.
static func _footprints(rects: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = rects.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for i: int in range(out.size()):
			for j: int in range(i + 1, out.size()):
				if out[i].grow(JOIN_GAP_M * 0.5).intersects(out[j].grow(JOIN_GAP_M * 0.5)):
					out[i] = out[i].merge(out[j])
					out.remove_at(j)
					changed = true
					break
			if changed:
				break
	return out


static func _read_keys(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2 and row[0] != "keys":
			out[row[0]] = row[1]
	return out


func _key_if(heist_id: StringName, suffix: StringName) -> StringName:
	var key: String = "%s%s.%s" % [KEY_PREFIX, heist_id, suffix]
	return StringName(key) if _strings.has(key) else &""


static func _area(boxes: Array) -> float:
	var a: float = 0.0
	for b: AABB in boxes:
		a += _rect(b).get_area()
	return a


static func _rect(b: AABB) -> Rect2:
	return Rect2(b.position.x, b.position.z, b.size.x, b.size.z)


## Rounds to 5 cm so the .tres stays readable.
static func _snap(r: Rect2) -> Rect2:
	var p: Vector2 = (r.position * 20.0).round() / 20.0
	var e: Vector2 = (r.end * 20.0).round() / 20.0
	return Rect2(p, e - p)


## Transform relative to the topmost ancestor (the map is not in the tree).
static func _global(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func _report(bp: PreplanBlueprint) -> void:
	for f: int in range(bp.floor_count()):
		var counts: Dictionary = {}
		for s: Dictionary in bp.shapes:
			if int(s.get("floor", -1)) == f:
				var k: StringName = s["kind"]
				counts[k] = int(counts.get(k, 0)) + 1
		print("  floor %d %s: %s" % [f, bp.floor_names[f], counts])
	var outside: Dictionary = {}
	for s2: Dictionary in bp.shapes:
		if int(s2.get("floor", -1)) < 0:
			outside[s2["kind"]] = int(outside.get(s2["kind"], 0)) + 1
	print("  all floors: %s; bounds %s; %d points" % [outside, bp.bounds, bp.points.size()])
