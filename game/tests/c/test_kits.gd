## C1-07: Glasshouse dressing kits + KitPlacer. Every kit id of the room list exists, every kind a
## kit names exists as a catalog prop, and the placer is deterministic, varied per seed/room,
## non-overlapping, inside the room, clear of doors and keep-outs, and within the kit density.
extends TestCase

const KIT_DIR: String = "res://world/kits/"
const GLASSHOUSE_KITS: Array[String] = ["storage_receiving", "electrical_closet", "workshop_jeweler", "restroom_single",
	"corridor_service", "janitor_closet", "sales_floor_jewelry", "salon_private", "break_room", "security_office",
	"corridor_office", "office_open", "office_manager", "storage_archive", "exterior_alley", "exterior_street"]
## Sample clear interiors (Glasshouse room list minus walls): x, ceiling, z.
const SIZES: Dictionary = {
	"storage_receiving": Vector3(4.8, 3.0, 4.3), "electrical_closet": Vector3(1.8, 3.0, 1.8),
	"workshop_jeweler": Vector3(5.3, 3.0, 4.3), "restroom_single": Vector3(2.3, 3.0, 4.3),
	"corridor_service": Vector3(9.0, 3.0, 1.3), "janitor_closet": Vector3(1.3, 2.8, 1.3),
	"sales_floor_jewelry": Vector3(12.8, 3.6, 5.8), "salon_private": Vector3(4.8, 3.2, 5.8),
	"break_room": Vector3(5.3, 3.0, 4.3), "security_office": Vector3(4.8, 3.0, 4.3),
	"corridor_office": Vector3(9.0, 3.0, 1.3), "office_open": Vector3(6.8, 3.0, 5.8),
	"office_manager": Vector3(4.8, 3.0, 5.8), "storage_archive": Vector3(5.8, 3.0, 5.8),
	"exterior_alley": Vector3(20.0, 6.0, 6.0), "exterior_street": Vector3(20.0, 6.0, 7.0),
}
const PURPOSES: Dictionary = {
	"storage_receiving": "storage", "electrical_closet": "electrical", "workshop_jeweler": "workshop",
	"restroom_single": "restroom", "corridor_service": "corridor", "janitor_closet": "storage",
	"sales_floor_jewelry": "sales_floor", "salon_private": "sales_floor", "break_room": "break_room",
	"security_office": "security_room", "corridor_office": "corridor", "office_open": "office",
	"office_manager": "office", "storage_archive": "storage", "exterior_alley": "exterior", "exterior_street": "exterior",
}


func _kit(id: String) -> DressingKit:
	return load(KIT_DIR + id + ".tres") as DressingKit


func _room(id: String) -> KitRoom:
	var s: Vector3 = SIZES[id]
	var r := KitRoom.from_aabb(AABB(Vector3(10.0 - s.x * 0.5, 4.2, -3.0 - s.z * 0.5), s), StringName(id))
	var swing: float = 0.0 if s.x * s.z < 5.0 else -1.0     # closet doors swing out
	if s.x >= 1.6:
		r.add_door(r.xform * r.wall_point(2, s.x - minf(1.2, s.x * 0.5)), 0.9, swing)
	else:
		r.add_door(r.xform * r.wall_point(1, s.z * 0.5), 0.9, swing)
	if s.x > 3.0 and s.z > 2.0:
		r.add_window(r.xform * r.wall_point(0, s.x * 0.5), 1.0, 0.9, 2.1)
	if PURPOSES[id] == "exterior":
		r.walls = [true, false, false, false]
	return r


func test_every_glasshouse_kit_exists() -> void:
	for id: String in GLASSHOUSE_KITS:
		var k: DressingKit = _kit(id)
		assert_true(k != null, "kit %s loads" % id)
		if k == null:
			continue
		assert_eq(String(k.id), id, "kit id")
		assert_eq(String(k.purpose), String(PURPOSES[id]), "%s purpose matches the room list" % id)
		assert_true(not k.required_items.is_empty(), "%s has required items" % id)
		assert_true(k.min_density < k.max_density and k.min_props > 0, "%s density bounds" % id)


func test_kit_kinds_exist_as_props() -> void:
	for id: String in GLASSHOUSE_KITS:
		var k: DressingKit = _kit(id)
		var kinds: Array[String] = []
		for r: StringName in k.required_items:
			kinds.append(String(r))
		for o: Variant in k.optional_items.keys():
			kinds.append(String(o))
		for g: Variant in k.clutter_groups.keys():
			for it: Variant in ((k.clutter_groups[g] as Dictionary)["items"] as Dictionary).keys():
				kinds.append(String(it))
		for kind: String in kinds:
			assert_true(not PropCatalog.ids_of_kind(StringName(kind)).is_empty(), "%s: kind `%s` has a catalog prop" % [id, kind])
		for kind: Variant in k.assets.keys():
			for a: Variant in k.assets[kind]:
				var e: Dictionary = PropCatalog.entry(StringName(String(a)))
				assert_eq(String(e.get("kind", "?")), String(kind), "%s: asset %s is a `%s`" % [id, a, kind])
		for a: Variant in k.ceiling.keys():
			assert_eq(String(PropCatalog.entry(StringName(String(a))).get("place", "")), "ceiling", "%s: ceiling asset %s" % [id, a])


func test_placer_is_deterministic_and_varies() -> void:
	var k: DressingKit = _kit("break_room")
	var a: Dictionary = KitPlacer.place(_room("break_room"), k, 7)
	var b: Dictionary = KitPlacer.place(_room("break_room"), k, 7)
	assert_eq(a["hash"], b["hash"], "same seed, same layout")
	assert_eq((a["placements"] as Array).size(), (b["placements"] as Array).size(), "same count")
	for i: int in range(mini((a["placements"] as Array).size(), (b["placements"] as Array).size())):
		var pa: Dictionary = a["placements"][i]
		var pb: Dictionary = b["placements"][i]
		assert_eq(pa["asset"], pb["asset"], "same asset #%d" % i)
		assert_true((pa["xform"] as Transform3D).is_equal_approx(pb["xform"]), "same transform #%d" % i)
	var hashes: Dictionary = {}
	for s: int in range(6):
		hashes[KitPlacer.place(_room("break_room"), k, 100 + s)["hash"]] = true
	assert_true(hashes.size() >= 5, "layouts vary per seed (%d distinct of 6)" % hashes.size())
	var other: KitRoom = _room("break_room")
	other.id = &"U9"
	assert_ne(KitPlacer.place(other, k, 7)["hash"], a["hash"], "same seed, other room id -> other layout")


func test_every_kit_places_cleanly() -> void:
	for id: String in GLASSHOUSE_KITS:
		var k: DressingKit = _kit(id)
		for s: int in [1, 2, 3]:
			var room: KitRoom = _room(id)
			var res: Dictionary = KitPlacer.place(room, k, s)
			var ps: Array = res["placements"]
			assert_true((res["missing"] as PackedStringArray).is_empty(), "%s seed %d: missing required %s" % [id, s, res["missing"]])
			assert_true(KitPlacer.overlaps(res).is_empty(), "%s seed %d: overlaps %s" % [id, s, KitPlacer.overlaps(res)])
			assert_true(ps.size() >= k.min_props, "%s seed %d: %d props >= min %d" % [id, s, ps.size(), k.min_props])
			var per: float = float(ps.size()) / room.area()
			assert_true(per >= k.min_density - 1e-4 and per <= k.max_density + 1e-4,
				"%s seed %d: density %.2f within %.2f-%.2f" % [id, s, per, k.min_density, k.max_density])
			var kinds: Dictionary = {}
			for p: Variant in ps:
				var d: Dictionary = p
				kinds[String(d["kind"])] = true
				var box: AABB = d["box"]
				assert_true(box.position.y >= -0.005 and box.end.y <= room.size.y + 0.005, "%s: %s inside floor-ceiling" % [id, d["asset"]])
				assert_true(absf(box.get_center().x) <= room.size.x * 0.5 and absf(box.get_center().z) <= room.size.z * 0.5,
					"%s: %s inside the room" % [id, d["asset"]])
			for r: StringName in k.required_items:
				assert_true(kinds.has(String(r)), "%s seed %d: required %s placed" % [id, s, r])


func test_door_swing_and_keep_out_stay_clear() -> void:
	var room: KitRoom = _room("office_open")
	var keep := AABB(room.xform * Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	room.add_keep_out(keep)
	var res: Dictionary = KitPlacer.place(room, _kit("office_open"), 3)
	var local_keep: AABB = room.xform.affine_inverse() * keep
	var o: Dictionary = room.openings[0]
	var a: Vector3 = room.wall_point(int(o["wall"]), float(o["u"]) - 0.45)
	var b: Vector3 = room.wall_point(int(o["wall"]), float(o["u"]) + 0.45) + KitRoom.wall_normal(int(o["wall"])) * 0.9
	var swing := AABB(a, Vector3.ZERO).expand(b)
	swing.size.y = 2.0
	for p: Variant in res["placements"]:
		var d: Dictionary = p
		var box: AABB = d["box"]
		assert_false(box.grow(-0.003).intersects(local_keep), "%s clear of the keep-out" % d["asset"])
		assert_false(box.grow(-0.003).intersects(swing), "%s clear of the door swing" % d["asset"])


func test_instantiate_links_chairs_and_metas() -> void:
	var room: KitRoom = _room("office_open")
	var res: Dictionary = KitPlacer.place(room, _kit("office_open"), 5)
	var parent := Node3D.new()
	add_child(parent)
	var nodes: Array[Node3D] = KitPlacer.instantiate(res, parent)
	assert_eq(nodes.size(), (res["placements"] as Array).size(), "one node per placement")
	var chairs: int = 0
	for n: Node3D in nodes:
		assert_true(n.has_meta(&"kind"), "%s has a kind meta" % n.name)
		if String(n.get_meta(&"kind")) == "chair":
			chairs += 1
			assert_true(n.has_meta(&"faces"), "%s faces its desk" % n.name)
			var t: Node3D = n.get_node_or_null(NodePath(str(n.get_meta(&"faces")))) as Node3D
			assert_true(t != null and String(t.get_meta(&"kind", &"")) == "desk", "%s faces a desk" % n.name)
			if t != null:
				var to: Vector3 = PropCatalog.aabb(StringName(String(t.scene_file_path.get_file().get_basename()))).get_center()
				to = t.global_transform * to - n.global_position
				var fwd: Vector3 = -n.global_basis.z
				var err: float = rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))))
				assert_true(err <= 20.0, "%s looks at its desk (%.1f deg)" % [n.name, err])
	assert_true(chairs >= 3, "office chairs placed (%d)" % chairs)
	parent.queue_free()
