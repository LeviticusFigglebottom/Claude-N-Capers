## D-115: every shipped heist has a drawn pre-planning blueprint (gallery_night by hand, the rest from
## content/preplanning/tools/blueprint_export.gd): not the placeholder, at least 3 rooms, every map
## PREPLAN point inside the bounds, most points inside a room/building/outdoor shape of their floor,
## and every label a strings key.
extends TestCase

const HEISTS: Array[StringName] = [&"gallery_night", &"glasshouse", &"night_deposit", &"shadow_ledger",
	&"dockside_burn", &"ostrander_federal", &"rolling_thunder"]  # RT since D-169 (offered: no longer staged)
const MIN_INSIDE: float = 0.7
const INSIDE_KINDS: Array[StringName] = [&"room", &"building"]
## Names allowed outside the drawn plan. Empty since LEAD r304 (names stay inside; one with no clear spot inside is
## left out). Shrink-only.
const FRAME_CROSSING_ALLOWED: Array[String] = []

var _strings: Dictionary = {}
## RT-B1: staged heists (RT) join the walk through the test-only fixture until they are offered.
var _fx: RefCounted = preload("res://tests/b/staged_heist_fixture.gd").new()


func before_all() -> void:
	PreplanBoard.clear_cache()
	_strings = StringTable.parse_csv(StringTable.CSV_PATH)
	_fx.call(&"stage")


func after_all() -> void:
	_fx.call(&"unstage")


func _heists() -> Array[StringName]:
	var out: Array[StringName] = HEISTS.duplicate()
	out.append_array(_fx.get(&"staged") as Array[StringName])
	return out


func test_each_heist_has_a_drawn_blueprint() -> void:
	for id: StringName in _heists():
		var drawn: PreplanBlueprint = PreplanBoard.drawn_blueprint(id)
		assert_eq(drawn.heist_id, id, "%s has blueprints/%s.tres" % [id, id])
		assert_false(drawn.placeholder, "%s drawn blueprint is not the placeholder" % id)
		var bp: PreplanBlueprint = PreplanBoard.blueprint_for(id)
		assert_false(bp.placeholder, "%s board blueprint is not the placeholder" % id)
		assert_true(bp.floor_count() >= 1, "%s has floors" % id)


func test_blueprints_have_rooms() -> void:
	for id: StringName in _heists():
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
	for id: StringName in _heists():
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
	for id: StringName in _heists():
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


## Lead r222: point labels never sit on another label, a marker, the scale bar or the north arrow (every heist,
## every floor, the 1080p and the 720p view).
func test_point_labels_do_not_collide() -> void:
	for job: Array in _label_jobs():
		var heist: StringName = job[0]
		var view: BlueprintView = BlueprintView.new()
		view.size = job[1]
		add_child(view)
		view.setup(PreplanBoard.build(heist, Enums.Difficulty.ROUTINE))
		for fl: int in range(view.board.blueprint.floor_count()):
			view.set_floor(fl)
			await wait_frames(2)
			var shown: Array[Rect2] = []
			var marks: Array[Rect2] = []
			for pid: Variant in view.markers:
				var b: Button = view.markers[pid] as Button
				if b.visible:
					marks.append(b.get_rect())
				var l: Label = view.marker_labels[pid] as Label
				if l.visible and b.visible:
					shown.append(Rect2(l.position, l.size))
			var furniture: Array[Rect2] = view._furniture_rects()
			var sc: float = float(view._transform()["scale"])
			var frame: Rect2 = Rect2(view.world_to_view(view.board.blueprint.bounds.position),
					view.board.blueprint.bounds.size * sc).grow(1.0)
			for i: int in range(shown.size()):
				# LEAD r304 (AH floor 0: "Gear: patrons' restroom duct" hung in the left margin): inside the drawn plan.
				assert_true(frame.encloses(shown[i]), "%s floor %d @%s: label %d leaves the plan" % [heist, fl, view.size, i])
				for f: Rect2 in furniture:
					assert_false(shown[i].intersects(f), "%s floor %d @%s: label %d on the scale bar / north arrow"
							% [heist, fl, view.size, i])
				for m: Rect2 in marks:
					assert_false(shown[i].intersects(m.grow(-1.0)), "%s floor %d: label %d over a marker" % [heist, fl, i])
				for j: int in range(i + 1, shown.size()):
					assert_false(shown[i].intersects(shown[j].grow(-1.0)), "%s floor %d: labels %d/%d collide" % [heist, fl, i, j])
				for zr: Rect2 in view._zone_label_rects():  # lead r242: no point label printed over a drawn zone name
					if not view.is_zone_yielded(zr) and shown[i].intersects(zr):
						assert_true(shown[i].intersection(zr).get_area() <= 4.0, "%s floor %d @%s: label %d over a zone name"
								% [heist, fl, view.size, i])
		view.queue_free()
		await wait_frames(1)


func _label_jobs() -> Array[Array]:
	var out: Array[Array] = []
	for heist: StringName in _heists():  # LEAD r304: OF, RT and AH too (their labels were never checked)
		for sz: Vector2 in [Vector2(1130, 730), Vector2(755, 487), Vector2(347, 400)]:  # + the 720p briefing view
			out.append([heist, sz])
	return out


## Text audit (ND 1080p): zone names never overlap each other and sit inside their zone, every heist, every floor,
## 1080p and 720p view.
func test_zone_names_fit_and_do_not_overlap() -> void:
	for job: Array in _label_jobs():
		var view: BlueprintView = BlueprintView.new()
		view.size = job[1]
		add_child(view)
		view.setup(PreplanBoard.build(job[0], Enums.Difficulty.ROUTINE))
		for fl: int in range(view.board.blueprint.floor_count()):
			view.set_floor(fl)
			var zs: Array[Array] = view._zone_labels()
			for i: int in range(zs.size()):
				for j: int in range(i + 1, zs.size()):
					assert_false((zs[i][2] as Rect2).intersects(zs[j][2] as Rect2), "%s floor %d @%s: '%s' / '%s' overlap"
							% [job[0], fl, view.size, zs[i][0], zs[j][0]])
		view.queue_free()
		await wait_frames(1)


## LEAD r226: names too big for their zones (DB's container footprints, the west lane) sit beside the zone with a
## leader line instead of disappearing; each shows once and clears every other name at 1080p and 720p.
func test_narrow_zones_are_named_beside() -> void:
	for sz: Vector2 in [Vector2(1130, 730), Vector2(755, 487)]:
		var view: BlueprintView = BlueprintView.new()
		view.size = sz
		add_child(view)
		view.setup(PreplanBoard.build(&"dockside_burn", Enums.Difficulty.ROUTINE))
		var fl: int = -1
		for i: int in range(view.board.blueprint.floor_count()):
			view.set_floor(i)
			for z: Array in view._zone_labels():
				if String(z[0]) == UiText.t(&"ui.preplan.bp.dockside_burn.yard").to_upper():
					fl = i
		assert_true(fl >= 0, "the yard floor exists")
		view.set_floor(fl)
		var texts: Array[String] = []
		for z2: Array in view._zone_labels():
			texts.append(String(z2[0]))
			if z2[3] != null:
				var lead: Array = z2[3] as Array
				assert_true((z2[2] as Rect2).grow(1.0).has_point(lead[0] as Vector2), "leader starts at the plate")
		for k: StringName in [&"ui.preplan.bp.dockside_burn.containers_west", &"ui.preplan.bp.dockside_burn.containers_east"]:
			var t: String = UiText.t(k).to_upper()
			assert_eq(texts.count(t), 1, "%s named once @%s (%s)" % [t, sz, texts])
		view.queue_free()
		await wait_frames(1)


## OF-B1 dry run: the briefing opens the blueprint on the floor the crew starts on (the default spawn point's floor),
## not floor 0 (OF opened on its basement; SL starts on the roof).
func test_entry_floor_is_the_default_spawn() -> void:
	var want: Dictionary = {&"glasshouse": 0, &"night_deposit": 1, &"shadow_ledger": 3, &"dockside_burn": 1,
		&"gallery_night": 1}
	for heist: StringName in want:
		var bp: PreplanBlueprint = PreplanBoard.build(heist, Enums.Difficulty.ROUTINE).blueprint
		assert_eq(bp.entry_floor(), int(want[heist]), "%s entry floor" % heist)
	var empty: PreplanBlueprint = PreplanBlueprint.new()
	assert_eq(empty.entry_floor(), 0, "no spawn point: floor 0")


## RT-B1 720p / 4K pass: a name placed beside a narrow zone on the map's edge straddled the outer frame line (RT's
## "SITE WELFARE CABIN"). Names sit wholly inside or wholly outside the drawn bounds, every heist, floor and size.
func test_zone_names_do_not_straddle_the_frame() -> void:
	var checked: int = 0
	for sz: Vector2 in [Vector2(1130, 730), Vector2(755, 487), Vector2(540, 520)]:
		for id: StringName in _heists():
			var view: BlueprintView = BlueprintView.new()
			view.size = sz
			add_child(view)
			view.setup(PreplanBoard.build(id, Enums.Difficulty.ROUTINE))
			var s: float = float(view._transform()["scale"])
			var bp: PreplanBlueprint = view.board.blueprint
			var frame: Rect2 = Rect2(view.world_to_view(bp.bounds.position), bp.bounds.size * s)
			for fl: int in range(bp.floor_count()):
				view.set_floor(fl)
				for z: Array in view._zone_labels():
					var r: Rect2 = z[2] as Rect2
					var key: String = "%s/%d/%dx%d/%s" % [id, fl, sz.x, sz.y, z[0]]
					# LEAD r304 (AH: "STAFF RESTROOMS" below the plan, "VIP RESTROOMS" in the margin): inside the plan.
					if not frame.grow(1.0).encloses(r) and not FRAME_CROSSING_ALLOWED.has(key):
						fail("%s: outside the plan" % key)
					checked += 1
			view.queue_free()
			await wait_frames(1)
	assert_true(checked > 100, "names checked: %d" % checked)
