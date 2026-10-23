## C1-07: props library + prefab visual scenes. Every catalog scene loads with the right metas,
## prefab visuals carry the exact contract node names (visual_slots.md), no surface has a null,
## default or greybox material, human-scale kinds have the right heights and pivots follow the
## contract. Run after `godot --import`.
extends TestCase

## Named hero props (style guide §5: the 20k budget): set pieces a level is built around (LEAD r308: the Old Press is
## the safehouse centrepiece).
const HERO_PROPS: Array[StringName] = [&"prop_chandelier_ring", &"prop_sh_old_press"]
const PREFAB_NODES: Dictionary = {
	"door": ["Frame", "Leaf", "Handle"],
	"display_case": ["Body", "Glass", "LootAnchor"],
	"safe": ["Body", "Door", "DrillPoint", "LootAnchor"],
	"keycard_reader": ["Panel", "Led"],
	"keypad": ["Panel", "Led"],
	"security_camera": ["Mount", "Head", "Lens", "Led"],
	"camera_station": ["Screens", "Seat"],
	"window": ["Frame", "Glass", "Sash"],
	"secure_zone": ["Body", "DoorL", "DoorR", "DropAnchor"],
	"ladder": ["Top", "Bottom"],
	"body_container": ["Lid", "Inside"],
	"loot_bag": ["Bag"],
	"drill": ["Bit"],
	# D-111 equipment: deployable visuals (held-form Handle, visual_slots.md D-069), burn point Fire, zipline Line
	"deployable": ["Handle"],
	"burn_point": ["Fire"],
	# RT-C2 convoy (A5-01 / A5-02): the truck's hold is a Safe visual (+ optional Cab), the cab a mover visual (Seat0..n)
	"armored_truck": ["Body", "Door", "DrillPoint", "LootAnchor"],
	"convoy_vehicle": ["Body", "Seat0"],
	"zipline": ["Line"],
	# PO-C throwables (ThrowableDef.model, visual_slots.md Items): body-centre origin, `Pin` hidden at pin_pull
	"throwable": ["Body"],
	"alarm_button": [],
	"phone": [],
	# PO6-17 assault events: per-asset contract nodes in test_assault_event_props.gd
	"assault_event": [],
}
const MESH_NODES: Array[String] = ["Led", "Screens", "Bag", "Bit", "Body"]
const EPS: float = 0.004

var _catalog: Dictionary = {}


func before_all() -> void:
	_catalog = PropCatalog.load_catalog()


func _inst(id: String) -> Node3D:
	var e: Dictionary = _catalog[id]
	var packed: PackedScene = load(String(e["scene"])) as PackedScene
	if packed == null:
		fail("%s: cannot load %s" % [id, e["scene"]])
		return null
	return packed.instantiate() as Node3D


func test_catalog_is_complete() -> void:
	assert_true(_catalog.size() >= 150, "catalog has %d props" % _catalog.size())
	var prefabs: Dictionary = {}
	for id: Variant in _catalog.keys():
		var p: String = String((_catalog[id] as Dictionary).get("prefab", ""))
		if p != "":
			prefabs[p] = true
	for p: String in PREFAB_NODES.keys():
		assert_true(prefabs.has(p), "a visual for prefab `%s`" % p)


func test_scenes_load_with_metas() -> void:
	for id: Variant in _catalog.keys():
		var e: Dictionary = _catalog[id]
		var n: Node3D = _inst(String(id))
		if n == null:
			continue
		assert_true(n.find_child("Model", false, false) != null, "%s: Model instance" % id)
		if String(e["prefab"]) == "":
			assert_eq(String(n.get_meta(&"kind", &"")), String(e["kind"]), "%s kind meta" % id)
			assert_true(String(e["kind"]) != "", "%s has a kind" % id)
			assert_eq(String(n.get_meta(&"mount", &"")), String(e["mount"]), "%s mount meta" % id)
			if bool(e["support"]):
				assert_true(bool(n.get_meta(&"support", false)), "%s support meta" % id)
				assert_true(not n.find_children("*", "StaticBody3D", true, false).is_empty(), "%s: support props need colliders" % id)
			if bool(e["fixture"]):
				assert_true(n.is_in_group(&"fixture") and bool(n.get_meta(&"fixture", false)), "%s fixture group + meta" % id)
		if bool(e["has_light"]):
			assert_true(n.find_child("Light", false, false) is Light3D, "%s: Light inside the fixture" % id)
		n.free()


func test_prefab_visuals_have_contract_nodes() -> void:
	for id: Variant in _catalog.keys():
		var e: Dictionary = _catalog[id]
		var prefab: String = String(e["prefab"])
		if prefab == "":
			continue
		var n: Node3D = _inst(String(id))
		if n == null:
			continue
		var need: Array = (PREFAB_NODES.get(prefab, []) as Array).duplicate()
		if prefab == "door" and String(id).contains("double"):
			need.append("Leaf2")
			need.append("Handle2")
		for node_name: Variant in need:
			var c: Node = n.find_child(String(node_name), true, false)
			assert_true(c is Node3D, "%s: node `%s`" % [id, node_name])
			if c != null and String(node_name) in MESH_NODES and prefab != "display_case" and prefab != "safe" and prefab != "secure_zone":
				assert_true(c is MeshInstance3D, "%s: `%s` is a MeshInstance3D" % [id, node_name])
		var bodies: Array[Node] = n.find_children("*", "CollisionObject3D", true, false)
		if prefab == "door":
			var frame: Node = n.find_child("Frame", true, false)
			assert_true(frame != null and frame.get_node_or_null(^"Collision") is StaticBody3D, "%s: Frame/Collision StaticBody3D" % id)
			assert_eq(bodies.size(), 1, "%s: only the frame collides" % id)
		elif prefab == "assault_event" and String(id).begins_with("prop_breach_"):
			pass  # PO6-17: breach points are architecture (the Intact infill collides), test_assault_event_props.gd
		else:
			assert_eq(bodies.size(), 0, "%s: prefab visuals carry no collision (the prefab owns it)" % id)
		n.free()


func test_led_and_screens_are_single_material_meshes() -> void:
	for id: Variant in _catalog.keys():
		var n: Node3D = _inst(String(id))
		if n == null:
			continue
		for node_name: String in ["Led", "Screens"]:
			var mi: MeshInstance3D = n.find_child(node_name, true, false) as MeshInstance3D
			if mi != null:
				assert_eq(mi.mesh.get_surface_count(), 1, "%s/%s: one surface (A swaps material_override)" % [id, node_name])
		n.free()


func test_no_null_default_or_greybox_material() -> void:
	var checked: int = 0
	for id: Variant in _catalog.keys():
		var n: Node3D = _inst(String(id))
		if n == null:
			continue
		for c: Node in n.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			for i: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(i)
				checked += 1
				assert_true(m != null, "%s/%s surface %d has a material" % [id, mi.name, i])
				if m == null:
					continue
				var path: String = m.resource_path
				assert_true(path.begins_with("res://world/materials/") or path.begins_with("res://world/props/materials/"),
					"%s/%s/%d uses a library or prop material (%s)" % [id, mi.name, i, path])
				assert_false(path.contains("/grey_"), "%s/%s/%d: no greybox material" % [id, mi.name, i])
				var bm: BaseMaterial3D = m as BaseMaterial3D
				if bm != null:
					assert_true(bm.albedo_texture != null or bool(m.get_meta(&"untextured_ok", false)),
						"%s/%s/%d: textured or untextured_ok (%s)" % [id, mi.name, i, path])
		n.free()
	assert_true(checked > 500, "checked %d surfaces" % checked)


func test_pivots_follow_the_contract() -> void:
	for id: Variant in _catalog.keys():
		var e: Dictionary = _catalog[id]
		var bb: AABB = PropCatalog.aabb(StringName(String(id)))
		var mount: String = String(e["mount"])
		var prefab: String = String(e["prefab"])
		if prefab in ["door", "window", "drill", "ladder", "throwable", "assault_event"]:
			continue
		if mount == "wall":
			assert_near(bb.end.z, 0.0, EPS, "%s: wall item back at the pivot" % id)
			if prefab == "":
				assert_true(bb.position.z < -0.003, "%s: wall item sticks out into the room (-Z)" % id)
		elif mount == "ceiling":
			assert_near(bb.end.y, 0.0, EPS, "%s: ceiling item top at the pivot" % id)
		else:
			assert_near(bb.position.y, 0.0, EPS, "%s: floor item bottom at the pivot" % id)
			assert_true(absf(bb.get_center().x) < bb.size.x * 0.25, "%s: pivot near the footprint centre (X)" % id)


func test_human_scale() -> void:
	for id: Variant in _catalog.keys():
		var e: Dictionary = _catalog[id]
		var bb: AABB = PropCatalog.aabb(StringName(String(id)))
		match String(e["kind"]):
			"desk":
				assert_true(bb.end.y >= 0.72 and bb.end.y <= 0.76, "%s desk top %.3f" % [id, bb.end.y])
			"counter_service":
				assert_near(bb.end.y, 0.9, 0.02, "%s counter top" % id)
			"chair":
				var n: Node3D = _inst(String(id))
				var seat: Node3D = n.find_child("Seat", true, false) as Node3D
				assert_true(seat != null, "%s: Seat marker" % id)
				if seat != null:
					assert_near(seat.position.y, 0.45, 0.03, "%s seat height" % id)
				n.free()
			"door":
				assert_near(bb.size.y, 2.2 + 0.07, 0.03, "%s frame height (2.2 opening + architrave)" % id)
	var door: Node3D = _inst("prop_door_single_walnut_t20")
	var leaf: Node3D = door.find_child("Leaf", true, false) as Node3D
	assert_near(leaf.position.x, -0.45, 0.001, "single leaf hinge at -0.45 (0.9 leaf)")
	door.free()


func test_triangle_budgets() -> void:
	for id: Variant in _catalog.keys():
		var n: Node3D = _inst(String(id))
		if n == null:
			continue
		var tris: int = 0
		for c: Node in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (c as MeshInstance3D).mesh
			for i: int in range(mesh.get_surface_count()):
				var idx: PackedInt32Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3
		var hero: bool = String(id).begins_with("prop_display_case") or String(id).begins_with("veh_") or StringName(id) in HERO_PROPS
		assert_true(tris >= 12 and tris <= (20000 if hero else 8000), "%s: %d triangles within style guide §5" % [id, tris])
		n.free()


## PO-C: throwables are held in the hand and fly as ThrownItem's Visual: origin at the body centre (inside the
## AABB, near its middle), +Y up the fuse (taller than wide), hand-sized, and every grenade has its `Pin`.
func test_throwables_follow_the_items_contract() -> void:
	var kinds: Dictionary = {}
	for id: Variant in _catalog.keys():
		var e: Dictionary = _catalog[id]
		if String(e["prefab"]) != "throwable":
			continue
		kinds[String(e["kind"])] = true
		var bb: AABB = PropCatalog.aabb(StringName(String(id)))
		assert_true(bb.has_point(Vector3.ZERO), "%s: origin inside the body" % id)
		var c: Vector3 = bb.get_center()
		assert_true(absf(c.x) < bb.size.x * 0.3 and absf(c.y) < bb.size.y * 0.3 and absf(c.z) < bb.size.z * 0.3,
			"%s: origin near the body centre (%s)" % [id, c])
		assert_true(bb.size.y >= bb.size.x and bb.size.y >= bb.size.z, "%s: +Y up the fuse / blade" % id)
		assert_true(bb.size.y >= 0.06 and bb.size.y <= 0.3, "%s: hand-sized (%.3f m tall)" % [id, bb.size.y])
		if String(e["kind"]) in ["frag", "concussion", "incendiary"]:
			var n: Node3D = _inst(String(id))
			assert_true(n.find_child("Pin", true, false) is Node3D, "%s: `Pin` node" % id)
			n.free()
	for k: String in ["frag", "concussion", "incendiary", "throwing_knife", "injector", "flask"]:
		assert_true(kinds.has(k), "a throwable visual for kind `%s`" % k)
