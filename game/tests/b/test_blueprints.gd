## D-115: every shipped heist has a drawn pre-planning blueprint (gallery_night by hand, the rest from
## content/preplanning/tools/blueprint_export.gd): not the placeholder, at least 3 rooms, every map
## PREPLAN point inside the bounds, most points inside a room/building/outdoor shape of their floor,
## and every label a strings key.
extends TestCase

const HEISTS: Array[StringName] = [&"gallery_night", &"glasshouse", &"night_deposit", &"shadow_ledger",
	&"dockside_burn"]
const MIN_INSIDE: float = 0.7
const INSIDE_KINDS: Array[StringName] = [&"room", &"building"]

var _strings: Dictionary = {}


func before_all() -> void:
	PreplanBoard.clear_cache()
	_strings = StringTable.parse_csv(StringTable.CSV_PATH)


func test_each_heist_has_a_drawn_blueprint() -> void:
	for id: StringName in HEISTS:
		var drawn: PreplanBlueprint = PreplanBoard.drawn_blueprint(id)
		assert_eq(drawn.heist_id, id, "%s has blueprints/%s.tres" % [id, id])
		assert_false(drawn.placeholder, "%s drawn blueprint is not the placeholder" % id)
		var bp: PreplanBlueprint = PreplanBoard.blueprint_for(id)
		assert_false(bp.placeholder, "%s board blueprint is not the placeholder" % id)
		assert_true(bp.floor_count() >= 1, "%s has floors" % id)


func test_blueprints_have_rooms() -> void:
	for id: StringName in HEISTS:
		var bp: PreplanBlueprint = PreplanBoard.drawn_blueprint(id)
		var rooms: int = 0
		for s: Dictionary in bp.shapes:
			if StringName(s.get("kind", &"")) == &"room":
				rooms += 1
			var fl: int = int(s.get("floor", -1))
			assert_true(fl >= -1 and fl < bp.floor_count(), "%s shape floor %d in range" % [id, fl])
			assert_true((s.get("rect", Rect2()) as Rect2).get_area() > 0.0, "%s shape has an area" % id)
		assert_true(rooms >= 3, "%s has %d room shapes" % [id, rooms])


func test_map_points_lie_in_bounds_and_mostly_inside_shapes() -> void:
	for id: StringName in HEISTS:
		var bp: PreplanBlueprint = PreplanBoard.blueprint_for(id)
		assert_true(bp.points.size() > 0, "%s has map points" % id)
		var inside: int = 0
		for p: Dictionary in bp.points:
			var pos: Vector2 = p.get("pos", Vector2.ZERO) as Vector2
			assert_true(bp.bounds.has_point(pos), "%s point %s %s inside bounds %s" % [id, p.get("id"), pos, bp.bounds])
			if _in_shape(bp, pos, int(p.get("floor", 0)), INSIDE_KINDS):
				inside += 1
		# Most points (spawns, drops, escapes) are outdoors on streets, alleys and quays, so the 70 %
		# rule counts every drawn shape; room/building hits are reported in the message.
		var drawn: int = 0
		for p2: Dictionary in bp.points:
			if _in_shape(bp, p2.get("pos", Vector2.ZERO) as Vector2, int(p2.get("floor", 0)), []):
				drawn += 1
		assert_true(float(drawn) / float(maxi(bp.points.size(), 1)) >= MIN_INSIDE,
				"%s: %d/%d points on a drawn shape (%d in a room/building)" % [id, drawn, bp.points.size(), inside])


func test_labels_and_floor_names_exist_in_strings() -> void:
	for id: StringName in HEISTS:
		var bp: PreplanBlueprint = PreplanBoard.drawn_blueprint(id)
		for k: StringName in bp.floor_names:
			assert_true(_strings.has(String(k)), "%s floor name %s in strings.csv" % [id, k])
		for s: Dictionary in bp.shapes:
			var key: StringName = StringName(s.get("label", &""))
			if key != &"":
				assert_true(_strings.has(String(key)), "%s label %s in strings.csv" % [id, key])
		for p: Dictionary in PreplanBoard.blueprint_for(id).points:
			var pk: StringName = StringName(p.get("label", &""))
			assert_true(pk != &"" and _strings.has(String(pk)), "%s point label %s in strings.csv" % [id, pk])


## Inside a shape on `fl` (or on every floor); `kinds` empty = any kind.
static func _in_shape(bp: PreplanBlueprint, pos: Vector2, fl: int, kinds: Array[StringName]) -> bool:
	for s: Dictionary in bp.shapes:
		var sf: int = int(s.get("floor", -1))
		if sf >= 0 and sf != fl:
			continue
		if not kinds.is_empty() and not kinds.has(StringName(s.get("kind", &""))):
			continue
		if (s.get("rect", Rect2()) as Rect2).grow(0.25).has_point(pos):
			return true
	return false
