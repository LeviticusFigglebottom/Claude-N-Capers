## PO6-05 (PO playtest 2026-10-15): Golden Hour's safe showed its jewelry stack on the floor IN FRONT
## of the door, visible on entry and not pickable. Spec: a safe's loot is INSIDE the body, hidden and
## unusable while the door is shut, then visible and usable (aimable through the open door) once open.
## Covers the Safe prefab and every Safe on the five shipped heist maps.
extends TestCase

const SMALL_LOOT: PackedScene = preload("res://systems/prefabs/small_loot/small_loot.tscn")
const LOOT_SPAWN: PackedScene = preload("res://systems/prefabs/loot_spawn/loot_spawn.tscn")
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"dockside_burn", &"shadow_ledger", &"gallery_night"]
## Variants that put loot in a safe (the roll may otherwise pick the empty slot).
const FORCE: Dictionary = {&"night_deposit": {&"extra_loot": [&"mgr_safe_full"]}}
## A content's art may overhang the body's AABB by this much (m), e.g. a stack's rounded edge.
const ART_TOLERANCE_M: float = 0.05

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _aim(c: CrewController, at: Vector3) -> CrewIntent:
	var d: Vector3 = at - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	return i


## The component the crew resolves when standing at `p`'s UsePoint (else the safe's) aiming at it.
func _aimed_from_front(safe: Safe, p: GameplayPrefab) -> InteractableComponent:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var up: Marker3D = p.use_point if p.use_point != null else safe.use_point
	_rt.teleport_crew(0, up.global_transform)
	await wait_physics_frames(1)
	_rt.set_bot_intent(0, _aim(c, p.interactable.global_position))
	await wait_physics_frames(2)
	var got: InteractableComponent = _rt.interaction.aimed_component(c)
	_rt.clear_bot_intent(0)
	return got


## Asserts the closed / open contract on `safe` (which must still be shut). Returns its content count.
func _check_safe(safe: Safe, label: String) -> int:
	var interior: AABB = safe.interior_aabb()
	var body: AABB = safe.merged_mesh_aabb(safe.visual_node("Body")).grow(ART_TOLERANCE_M)
	assert_true(interior.has_volume(), "%s: the safe visual has a Body mesh" % label)
	var items: Array[GameplayPrefab] = safe.contents()
	for p: GameplayPrefab in items:
		var tag: String = "%s/%s" % [label, p.name]
		assert_true(interior.has_point(safe.xform_to_self(p).origin), "%s: inside the safe body (%s not in %s)" % [
			tag, str(safe.xform_to_self(p).origin), str(interior)])
		var art: AABB = safe.merged_mesh_aabb(p.visual_root)
		if art.has_volume():
			assert_true(body.encloses(art), "%s: its art %s fits in the body %s" % [tag, str(art), str(body)])
		assert_false(p.is_visible_in_tree(), "%s: hidden while the safe is shut" % tag)
		assert_false(p.interactable.enabled, "%s: not usable while the safe is shut" % tag)
		assert_true(await _aimed_from_front(safe, p) != p.interactable, "%s: not aimable while shut" % tag)
	safe.swing_open()
	await wait_physics_frames(1)
	for p: GameplayPrefab in items:
		var tag: String = "%s/%s" % [label, p.name]
		assert_true(p.is_visible_in_tree(), "%s: visible once the safe is open" % tag)
		assert_true(p.interactable.enabled, "%s: usable once the safe is open" % tag)
		assert_true(await _aimed_from_front(safe, p) == p.interactable, "%s: aimable through the open door" % tag)
	return items.size()


func test_po6_05_prefab_snaps_stray_loot_inside_and_hides_until_open() -> void:
	_rt = await HeistLauncher.launch(&"unit_po6_05", 605, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var made: Array[GameplayPrefab] = []
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(-4, 0, -6), func(n: Node) -> void:
		var bags: GameplayPrefab = LOOT_SPAWN.instantiate() as GameplayPrefab
		bags.name = "FloorBags"
		bags.set(&"loot_id", &"loot.jewelry")
		bags.position = Vector3(0, 0, -0.64)  # the Golden Hour bug: on the floor in front of the door
		n.add_child(bags)
		var cash: GameplayPrefab = SMALL_LOOT.instantiate() as GameplayPrefab
		cash.name = "Cash"
		cash.position = Vector3(0.15, 0.4, 0.0)  # already inside: stays put
		n.add_child(cash)
		made.append_array([bags, cash])) as Safe
	await wait_physics_frames(2)
	assert_eq(safe.contents().size(), 2, "both contents found")
	assert_true(made[1].position.is_equal_approx(Vector3(0.15, 0.4, 0.0)), "loot already inside is not moved")
	var anchor: Node3D = safe.visual_node("LootAnchor") as Node3D
	assert_true(safe.xform_to_self(made[0]).origin.is_equal_approx(safe.xform_to_self(anchor).origin),
		"stray loot snapped to LootAnchor")
	assert_eq(await _check_safe(safe, "unit"), 2)


func test_po6_05_every_heist_safe_holds_its_loot_inside() -> void:
	var total: int = 0
	for id: StringName in HEISTS:
		var opts: Dictionary = {"crew_ai": false, "skip_casing": true}
		if FORCE.has(id):
			opts["preplan"] = {"version": 1, "force_variants": FORCE[id]}
		_rt = await HeistLauncher.launch(id, 7, Enums.Difficulty.ROUTINE, self, opts)
		assert_true(_rt != null, "launched %s" % id)
		await wait_physics_frames(3)
		for n: Node in _rt.map.find_children("*", "", true, false):
			var safe: Safe = n as Safe
			if safe == null or safe.opened:
				continue
			total += await _check_safe(safe, "%s:%s" % [id, _rt.map.get_path_to(safe)])
		_rt.teardown()
		_rt = null
		await wait_frames(2)
	# glasshouse 1 + night_deposit manager 4 + dockside 3 + shadow_ledger 3+1+1 + gallery 3
	assert_true(total >= 16, "safe contents checked on the maps: %d" % total)
