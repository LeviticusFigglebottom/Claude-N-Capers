## A1-03: gameplay prefab shapes (gameplay_prefabs.md, visual_slots.md) and stub behaviour.
extends TestCase

const SCENE: String = "res://systems/prefabs/%s/%s.tscn"
const COMMON: Dictionary = {&"visual_scene": TYPE_OBJECT, &"objective_tag": TYPE_STRING_NAME}
const COMMON_INTERACTIVE: Dictionary = {
	&"interaction_time_s": TYPE_FLOAT, &"requires_item": TYPE_STRING_NAME, &"stealth_only": TYPE_BOOL,
	&"loud_only": TYPE_BOOL, &"casing_allowed": TYPE_BOOL, &"noise": TYPE_STRING_NAME,
}
## prefab -> [class_name, interactive, has UsePoint, key exports {name: type}, required visual nodes]
const SPECS: Dictionary = {
	"door": ["Door", true, true, {&"lock": TYPE_INT, &"swing": TYPE_INT, &"width_m": TYPE_FLOAT,
		&"starts_open": TYPE_BOOL, &"code_group": TYPE_STRING_NAME, &"suspicious_when_open": TYPE_BOOL},
		["Frame", "Collision", "Leaf", "Handle"]],
	"security_camera": ["SecurityCamera", false, false, {&"fov_deg": TYPE_FLOAT, &"range_m": TYPE_FLOAT,
		&"pan_deg": TYPE_FLOAT, &"pan_period_s": TYPE_FLOAT, &"destructible": TYPE_BOOL},
		["Mount", "Head", "Lens", "Led"]],
	"camera_station": ["CameraStation", true, true, {&"operator_spawn": TYPE_NODE_PATH}, ["Screens", "Seat"]],
	"display_case": ["DisplayCase", true, true, {&"loot_id": TYPE_STRING_NAME, &"glass_breaks_alarm": TYPE_BOOL},
		["Body", "Glass", "LootAnchor"]],
	"small_loot": ["SmallLoot", true, true, {&"value": TYPE_INT, &"loot_id": TYPE_STRING_NAME}, []],
	"loot_spawn": ["LootSpawn", true, true, {&"loot_id": TYPE_STRING_NAME, &"count": TYPE_INT}, []],
	"keycard_pickup": ["KeycardPickup", true, true, {}, []],
	"keycard_reader": ["KeycardReader", true, true, {&"targets": TYPE_ARRAY}, ["Panel", "Led"]],
	"keypad": ["Keypad", true, true, {&"code_group": TYPE_STRING_NAME}, ["Panel", "Led"]],
	"code_note": ["CodeNote", true, true, {&"code_group": TYPE_STRING_NAME}, []],
	"safe": ["Safe", true, true, {&"size": TYPE_INT, &"methods": TYPE_ARRAY}, ["Body", "Door", "DrillPoint", "LootAnchor"]],
	"drill_point": ["DrillPoint", true, true, {&"device": TYPE_INT, &"duration_s": TYPE_FLOAT, &"target": TYPE_NODE_PATH}, []],
	"alarm_button": ["AlarmButton", false, true, {}, []],
	"phone": ["Phone", false, true, {}, []],
	"window": ["WindowPrefab", true, true, {&"breakable": TYPE_BOOL, &"openable": TYPE_BOOL}, ["Frame", "Glass", "Sash"]],
	"secure_zone": ["SecureZone", false, false, {&"zone_size_m": TYPE_VECTOR3}, ["Body", "DoorL", "DoorR", "DropAnchor"]],
	"escape_zone": ["EscapeZone", false, false, {&"escape_type": TYPE_STRING_NAME, &"active": TYPE_BOOL}, []],
	"body_container": ["BodyContainer", false, false, {&"capacity": TYPE_INT}, ["Lid", "Inside"]],
	"ladder": ["Ladder", false, false, {&"height_m": TYPE_FLOAT}, ["Top", "Bottom"]],
	"zipline": ["Zipline", true, true, {&"end": TYPE_NODE_PATH}, []],
	"laser_grid": ["LaserGrid", false, false, {&"pattern": TYPE_STRING_NAME}, []],
}
## Volume prefabs: child `Zone` MapZone kind.
const ZONES: Dictionary = {
	"secure_zone": MapZone.Kind.SECURE_LOOT, "escape_zone": MapZone.Kind.ESCAPE,
	"body_container": MapZone.Kind.BODY_HIDE,
}


func _path(prefab: String) -> String:
	return SCENE % [prefab, prefab]


func _exports(n: Node) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in n.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_EDITOR and int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[StringName(p["name"])] = int(p["type"])
	return out


func _check_exports(prefab: String, n: Node, wanted: Dictionary) -> void:
	var ex: Dictionary = _exports(n)
	for k: StringName in wanted:
		if not ex.has(k):
			fail("%s: missing export %s" % [prefab, k])
		elif ex[k] != wanted[k]:
			fail("%s: export %s has type %d, expected %d" % [prefab, k, ex[k], wanted[k]])


func test_every_prefab_has_contract_shape() -> void:
	for prefab: String in SPECS:
		var spec: Array = SPECS[prefab]
		var ps: PackedScene = load(_path(prefab)) as PackedScene
		assert_true(ps != null, "%s scene loads" % prefab)
		if ps == null:
			continue
		var p: GameplayPrefab = ps.instantiate() as GameplayPrefab
		assert_true(p != null, "%s root is a GameplayPrefab" % prefab)
		if p == null:
			continue
		add_child(p)
		await wait_frames(1)
		assert_eq((p.get_script() as Script).get_global_name(), StringName(spec[0]), "%s class_name" % prefab)
		assert_true(p.net_id != 0, "%s claimed a net_id" % prefab)
		assert_true(p.visual_root != null, "%s has Visual" % prefab)
		assert_true(p.using_placeholder and p.visual_instance != null, "%s placeholder instanced" % prefab)
		if p.visual_instance != null:
			assert_true(p.visual_instance.owner == null, "%s placeholder is runtime-only" % prefab)
		for nm: String in spec[4]:
			assert_true(p.visual_node(nm) != null, "%s visual has `%s`" % [prefab, nm])
		for nm: String in p.required_visual_nodes():
			assert_true(p.visual_node(nm) != null, "%s visual has required `%s`" % [prefab, nm])
		_check_exports(prefab, p, COMMON)
		var interactive: bool = spec[1]
		if interactive:
			_check_exports(prefab, p, COMMON_INTERACTIVE)
			assert_true(p.get_node_or_null(^"Interactable") is InteractableComponent, "%s Interactable" % prefab)
			assert_eq(bool(p.get(&"casing_allowed")), prefab == "keycard_pickup", "%s casing_allowed default" % prefab)
			assert_true(p.interactable.interaction_time_s >= 0.0, "%s interaction time resolved" % prefab)
		else:
			assert_true(p.get_node_or_null(^"Interactable") == null, "%s is not interactive" % prefab)
		_check_exports(prefab, p, spec[3])
		if spec[2]:
			_check_use_point(prefab, p)
		if ZONES.has(prefab):
			var z: MapZone = p.get_node_or_null(^"Zone") as MapZone
			assert_true(z != null, "%s has Zone MapZone" % prefab)
			if z != null:
				assert_eq(z.kind, ZONES[prefab], "%s zone kind" % prefab)
				assert_true(z.get_node_or_null(^"Shape") is CollisionShape3D, "%s zone shape" % prefab)
		p.queue_free()
		await wait_frames(1)


func _check_use_point(prefab: String, p: GameplayPrefab) -> void:
	var up: Marker3D = p.get_node_or_null(^"UsePoint") as Marker3D
	assert_true(up != null, "%s has UsePoint Marker3D" % prefab)
	if up == null:
		return
	var to_obj: Vector3 = -up.position
	to_obj.y = 0.0
	var facing: Vector3 = -up.basis.z
	assert_true(facing.dot(to_obj.normalized()) > 0.9, "%s UsePoint -Z faces the object" % prefab)
	var d: float = Vector2(up.position.x, up.position.z).length()
	assert_true(d > 0.5 and d < 1.3, "%s UsePoint distance %.2f" % [prefab, d])


func test_custom_visual_missing_nodes_fails_loudly() -> void:
	var art: Node3D = Node3D.new()
	art.name = "BadArt"
	var ps: PackedScene = PackedScene.new()
	ps.pack(art)
	art.free()
	var door: Door = (load(_path("door")) as PackedScene).instantiate() as Door
	door.visual_scene = ps
	Log.capture = true
	Log.captured.clear()
	add_child(door)
	await wait_frames(1)
	Log.capture = false
	assert_false(door.using_placeholder, "custom visual used")
	var found: bool = false
	for l: String in Log.captured:
		if l.contains("missing required node `Leaf`"):
			found = true
	assert_true(found, "missing Leaf is logged as an error")
	door.queue_free()
	await wait_frames(1)


func test_double_door_has_two_leaves() -> void:
	var door: Door = (load(_path("door")) as PackedScene).instantiate() as Door
	door.swing = Door.Swing.DOUBLE
	add_child(door)
	await wait_frames(1)
	assert_true(door.visual_node("Leaf2") != null, "Leaf2")
	assert_near(door.effective_width(), Door.DOUBLE_WIDTH_M)
	assert_true(door.get_node_or_null(^"LeafBody2") is AnimatableBody3D, "second leaf body")
	door.queue_free()
	await wait_frames(1)


# --- Behaviour through the InteractionSystem --------------------------------------------

func _launch() -> HeistRuntime:
	var ps: PackedScene = ATestMaps.basic(0)
	return await HeistLauncher.launch(&"unit_prefabs", 303, Enums.Difficulty.ROUTINE, self, {"map_packed": ps})


func _place(rt: HeistRuntime, prefab: String, pos: Vector3, setup: Callable = Callable()) -> GameplayPrefab:
	var p: GameplayPrefab = (load(_path(prefab)) as PackedScene).instantiate() as GameplayPrefab
	p.position = pos
	if setup.is_valid():
		setup.call(p)
	rt.map.get_node(^"Gameplay").add_child(p)
	return p


## Hold interact on `p` from its UsePoint for `seconds`, then release.
func _use(rt: HeistRuntime, p: GameplayPrefab, seconds: float, mask: bool = true) -> void:
	var crew: CrewController = rt.crew_controller(0) as CrewController
	rt.teleport_crew(0, p.use_point.global_transform)
	if mask:
		crew.set_masked()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = crew.look_yaw
	i.interact = true
	i.interact_target_net_id = p.net_id
	rt.set_bot_intent(0, i)
	await wait_physics_frames(int(ceil(seconds * Engine.physics_ticks_per_second)) + 3)
	rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_unlocked_door_opens_instantly() -> void:
	var rt: HeistRuntime = await _launch()
	var door: Door = _place(rt, "door", Vector3(0, 0, 0)) as Door
	await wait_frames(1)
	assert_false(door.is_open, "starts closed")
	await _use(rt, door, 0.0)
	assert_true(door.is_open, "opened")
	var leaf: Node3D = door.visual_node("Leaf") as Node3D
	assert_near(leaf.rotation.y, -deg_to_rad(Tweak.interaction().door_open_angle_deg), 0.001, "INWARD swing")
	var body: AnimatableBody3D = door.get_node(^"LeafBody") as AnimatableBody3D
	assert_true(body.global_transform.is_equal_approx(leaf.global_transform), "leaf body follows Leaf")
	assert_eq(body.collision_layer, 2, "world_dynamic")
	rt.teardown()
	await wait_frames(1)


func test_keycard_pickup_then_keycard_door() -> void:
	var rt: HeistRuntime = await _launch()
	var card: GameplayPrefab = _place(rt, "keycard_pickup", Vector3(3, 0, 0))
	var door: Door = _place(rt, "door", Vector3(-3, 0, 0), func(n: Node) -> void: (n as Door).lock = Door.Lock.KEYCARD) as Door
	await wait_frames(1)
	var picked: Array = []
	var cb: Callable = func(item: StringName, slot: int) -> void: picked.append([item, slot])
	EventBus.item_picked_up.connect(cb)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	await _use(rt, card, Tweak.interaction().item_pickup_s, false)  # casing_allowed
	EventBus.item_picked_up.disconnect(cb)
	assert_eq(crew.item_count(&"item.keycard"), 1, "keycard granted while casing")
	assert_eq(picked, [[&"item.keycard", 0]], "item_picked_up fact")
	assert_false(is_instance_valid(card), "pickup freed")
	await _use(rt, door, Tweak.interaction().keycard_s)
	assert_true(door.is_open, "keycard door opened")
	assert_false(door.locked, "unlocked")
	assert_eq(crew.item_count(&"item.keycard"), 0, "keycard consumed")
	rt.teardown()
	await wait_frames(1)


func test_small_loot_pickup() -> void:
	var rt: HeistRuntime = await _launch()
	var loot: SmallLoot = _place(rt, "small_loot", Vector3(0, 0, 3)) as SmallLoot
	await wait_frames(1)
	var got: Array = []
	var cb: Callable = func(value: int, slot: int) -> void: got.append([value, slot])
	EventBus.small_loot_taken.connect(cb)
	await _use(rt, loot, Tweak.interaction().small_loot_s)
	EventBus.small_loot_taken.disconnect(cb)
	assert_eq(got, [[500, 0]], "small_loot_taken(value, slot)")
	assert_false(is_instance_valid(loot), "small loot freed")
	rt.teardown()
	await wait_frames(1)


func test_mission_activates_escape_zone() -> void:
	var rt: HeistRuntime = await _launch()
	var ez: EscapeZone = _place(rt, "escape_zone", Vector3(8, 0, 8)) as EscapeZone
	await wait_physics_frames(2)
	assert_false(ez.active, "inactive at start")
	assert_false(ez.zone.monitoring, "zone not monitoring while inactive")
	assert_has(get_tree().get_nodes_in_group(G.ESCAPE_ZONE), ez.zone, "zone in escape group")
	rt.mission.activate_escape()
	await wait_physics_frames(2)
	assert_true(ez.active, "activated by HeistMission.activate_escape")
	assert_true(ez.zone.monitoring, "zone monitoring")
	assert_eq(rt.phase, Enums.HeistPhase.ESCAPE)
	rt.teardown()
	await wait_frames(1)
