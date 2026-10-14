## D-105 (impact_fx.md §1): every collision body of ENV A's prefabs that bullets can hit carries a
## `metadata/surface` id that ShotFx.surface_of resolves (Area3D triggers are skipped).
extends TestCase

const SCENE: String = "res://systems/prefabs/%s/%s.tscn"
const LOOT_BAG_SCENE: String = "res://systems/loot/loot_bag.tscn"
const DOOR_PLACEHOLDER: String = "res://systems/prefabs/door/door_placeholder.tscn"
## prefab -> expected surface of every non-Area3D CollisionObject3D under it.
const EXPECTED: Dictionary = {
	"window": &"glass",
	"display_case": &"glass",
	"safe": &"metal",
	"camera_station": &"metal",
	"hack_terminal": &"metal",
	"bag_lift": &"metal",
	"body_container": &"metal",
	"secure_zone": &"metal",
	"security_camera": &"metal",
}

## [lock, leaf_surface export, styled visual file name ("" = placeholder), expected leaf surface]
const STYLE_CASES: Array = [
	[Door.Lock.VAULT, &"", "", &"metal"],
	[Door.Lock.BARRED, &"", "", &"metal"],
	[Door.Lock.NONE, &"", "prop_door_single_steel_t20", &"metal"],
	[Door.Lock.NONE, &"", "prop_door_double_bronze_t40", &"metal"],
	[Door.Lock.NONE, &"", "prop_door_double_grille_t20", &"metal"],
	[Door.Lock.NONE, &"", "prop_door_single_glass_t20", &"glass"],
	[Door.Lock.KEYCARD, &"", "prop_door_single_walnut_t20", &"wood"],
	[Door.Lock.VAULT, &"wood", "", &"wood"],
	[Door.Lock.NONE, &"glass", "prop_door_single_steel_t20", &"glass"],
]

var _fake_n: int = 0


func _instance(path: String, setup: Callable = Callable()) -> Node3D:
	var ps: PackedScene = load(path) as PackedScene
	assert_true(ps != null, "%s loads" % path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if setup.is_valid():
		setup.call(n)
	add_child(n)
	await wait_physics_frames(2)
	return n


func _bodies(root: Node) -> Array[CollisionObject3D]:
	var out: Array[CollisionObject3D] = []
	if root is CollisionObject3D and not root is Area3D:
		out.append(root as CollisionObject3D)
	for c: Node in root.find_children("*", "CollisionObject3D", true, false):
		if not c is Area3D:
			out.append(c as CollisionObject3D)
	return out


func _leaf_bodies(d: Door) -> Array[CollisionObject3D]:
	var out: Array[CollisionObject3D] = []
	for b: CollisionObject3D in _bodies(d):
		if String(b.name).begins_with("LeafBody"):
			out.append(b)
	return out


## A door visual that is the placeholder saved under a styled file name (only the name differs).
func _styled_visual(file_name: String) -> PackedScene:
	var inst: Node = (load(DOOR_PLACEHOLDER) as PackedScene).instantiate()
	var ps: PackedScene = PackedScene.new()
	assert_eq(ps.pack(inst), OK, "pack styled door visual")
	inst.free()
	_fake_n += 1  # a fresh path each time (two resources may not share a cached path)
	ps.resource_path = "res://tests/a/_d105_fake/%d/%s.tscn" % [_fake_n, file_name]
	return ps


func test_d105_prefab_bodies_carry_their_surface() -> void:
	for prefab: String in EXPECTED:
		var setup: Callable = Callable()
		var top: Marker3D = null
		if prefab == "bag_lift":  # a lift needs a landing
			top = Marker3D.new()
			top.name = "D105LiftTop"
			top.position = Vector3(0.0, 4.0, 0.0)
			add_child(top)
			setup = func(n: Node) -> void: (n as BagLift).targets = [NodePath("../D105LiftTop")] as Array[NodePath]
		var p: Node3D = await _instance(SCENE % [prefab, prefab], setup)
		if p == null:
			continue
		var bodies: Array[CollisionObject3D] = _bodies(p)
		assert_true(not bodies.is_empty(), "%s has a collision body" % prefab)
		for b: CollisionObject3D in bodies:
			assert_eq(ShotFx.surface_of(b), EXPECTED[prefab], "%s/%s surface" % [prefab, p.get_path_to(b)])
		p.queue_free()
		if top != null:
			top.queue_free()
	await wait_frames(1)


func test_d105_loot_bag_is_fabric() -> void:
	var bag: Node3D = await _instance(LOOT_BAG_SCENE)
	if bag == null:
		return
	assert_eq(ShotFx.surface_of(bag), &"fabric", "loot bag surface")
	for b: CollisionObject3D in _bodies(bag):
		assert_eq(ShotFx.surface_of(b), &"fabric", "loot bag body %s" % b.name)
	bag.queue_free()
	await wait_frames(1)


func test_d105_door_leaf_default_wood_frame_metal() -> void:
	var d: Door = await _instance(SCENE % ["door", "door"]) as Door
	var leaves: Array[CollisionObject3D] = _leaf_bodies(d)
	assert_eq(leaves.size(), 1, "one leaf body")
	for b: CollisionObject3D in _bodies(d):
		var want: StringName = &"wood" if leaves.has(b) else &"metal"  # placeholder Frame/Collision: metal
		assert_eq(ShotFx.surface_of(b), want, "door/%s surface" % d.get_path_to(b))
	d.queue_free()
	await wait_frames(1)


func test_d105_double_door_both_leaves() -> void:
	var d: Door = await _instance(SCENE % ["door", "door"], func(n: Node) -> void:
		(n as Door).swing = Door.Swing.DOUBLE) as Door
	var leaves: Array[CollisionObject3D] = _leaf_bodies(d)
	assert_eq(leaves.size(), 2, "two leaf bodies")
	for b: CollisionObject3D in leaves:
		assert_eq(ShotFx.surface_of(b), &"wood", "double door %s surface" % b.name)
	d.queue_free()
	await wait_frames(1)


func test_d105_door_leaf_surface_by_style() -> void:
	for i: int in range(STYLE_CASES.size()):
		var c: Array = STYLE_CASES[i]
		var visual: PackedScene = _styled_visual(c[2]) if c[2] != "" else null
		var d: Door = await _instance(SCENE % ["door", "door"], func(n: Node) -> void:
			var dd: Door = n as Door
			dd.lock = c[0]
			dd.leaf_surface = c[1]
			dd.visual_scene = visual) as Door
		assert_eq(d.leaf_surface_id(), c[3], "case %d leaf_surface_id" % i)
		var leaves: Array[CollisionObject3D] = _leaf_bodies(d)
		assert_eq(leaves.size(), 1, "case %d one leaf body" % i)
		for b: CollisionObject3D in leaves:
			assert_eq(ShotFx.surface_of(b), c[3], "case %d leaf surface" % i)
		d.queue_free()
		await wait_frames(1)


## A visual's own `Collision` body replacing the prefab's box inherits the prefab's surface unless tagged.
func test_d105_visual_collision_inherits_surface() -> void:
	for tagged: bool in [false, true]:
		var root: Node3D = Node3D.new()
		for nm: String in ["Lid", "Inside"]:
			var m: Node3D = Node3D.new()
			m.name = nm
			root.add_child(m)
			m.owner = root
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Collision"
		if tagged:
			body.set_meta(ShotFx.SURFACE_META, &"wood")
		root.add_child(body)
		body.owner = root
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		body.add_child(cs)
		cs.owner = root
		var ps: PackedScene = PackedScene.new()
		assert_eq(ps.pack(root), OK, "pack visual")
		root.free()
		var p: GameplayPrefab = await _instance(SCENE % ["body_container", "body_container"],
			func(n: Node) -> void: (n as GameplayPrefab).visual_scene = ps) as GameplayPrefab
		assert_true(p.visual_collision != null, "visual supplies the collision")
		if p.visual_collision != null:
			assert_eq(ShotFx.surface_of(p.visual_collision), &"wood" if tagged else &"metal",
				"visual collision surface (tagged %s)" % tagged)
		p.queue_free()
		await wait_frames(1)
