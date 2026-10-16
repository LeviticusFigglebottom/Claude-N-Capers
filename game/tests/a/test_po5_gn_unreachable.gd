## GN-A1 (D-103) loud pilot: a target whose walk a door the crew cannot open stopped (the lockdown-BARRED Calloway
## shutter, the coded ServerDoor; the navmesh still runs through both doorways) is skipped, per target node and per
## marker, until that door is passable again; a target that is still pathable with no blocking door is retried.
extends TestCase

const FlowScript: GDScript = preload("res://tests/a/e2e/po5_flow_auto_loud.gd")

var _rt: HeistRuntime = null


class NoteSink:
	extends Node
	var notes: Array[String] = []

	func note(msg: String) -> void:
		notes.append(msg)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## A barred door at the doorway of a closed room, a canvas spawn inside it, and the flow wired to the local crew.
func _setup() -> Dictionary:
	_rt = await HeistLauncher.launch(&"unit_map", 1131, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0, Vector2(4, 6)), "crew_ai": false})
	await wait_physics_frames(2)
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.BARRED) as Door
	var canvas: LootSpawn = ATestMaps.add_prefab(_rt, "loot_spawn", Vector3(0, 0, -4), func(p: GameplayPrefab) -> void:
		(p as LootSpawn).loot_id = &"loot.painting_salt_orchard") as LootSpawn
	await ATestMaps.await_nav_synced(_rt)
	await wait_physics_frames(2)
	var sink: NoteSink = NoteSink.new()
	add_child(sink)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()  # loud pilot: masked (an unmasked crew member cannot use a drill: BLOCK_CASING)
	var flow: RefCounted = FlowScript.new()
	flow.set(&"f", sink)
	flow.set(&"p", Po5Pilot.new(sink, crew))
	flow.set(&"rt", _rt)
	var comp: InteractableComponent = canvas.get_node(^"Interactable") as InteractableComponent
	return {"door": door, "comp": comp, "flow": flow, "pilot": flow.get(&"p"), "sink": sink}


func _lift(door: Door) -> void:
	door.unlock()
	door.set_open(true)


func test_po5_gn_blocked_target_skipped_until_its_door_lifts() -> void:
	var s: Dictionary = await _setup()
	var door: Door = s["door"]
	var comp: InteractableComponent = s["comp"]
	var flow: RefCounted = s["flow"]
	(s["pilot"] as Po5Pilot).last_blocked_door = door  # what goto() records when the BARRED door stops the walk
	assert_true(flow.call(&"_has_path", comp.global_position), "the navmesh runs through the doorway (no-path test alone misses it)")
	flow.call(&"_mark_if_unreached", comp)
	assert_true(flow.call(&"_is_unreachable", comp), "blacklisted while the door is barred")
	assert_true(flow.call(&"_is_unreachable", comp), "still skipped on the next decision")
	_lift(door)
	await wait_physics_frames(2)
	assert_false(flow.call(&"_is_unreachable", comp), "retried once the hack lifts the door")
	assert_true((flow.get(&"_unreachable") as Dictionary).is_empty(), "entry cleared")


func test_po5_gn_pathable_target_without_a_blocking_door_is_retried() -> void:
	var s: Dictionary = await _setup()
	_lift(s["door"] as Door)
	await wait_physics_frames(2)
	(s["pilot"] as Po5Pilot).last_blocked_door = null  # a long walk that only hit the leg timeout (33bb7e51)
	s["flow"].call(&"_mark_if_unreached", s["comp"])
	assert_false(s["flow"].call(&"_is_unreachable", s["comp"]), "not blacklisted")


func test_po5_gn_blocked_marker_yields_per_marker_until_passable() -> void:
	var s: Dictionary = await _setup()
	var door: Door = s["door"]
	var flow: RefCounted = s["flow"]
	var behind: Dictionary = {"id": &"canvases", "position": Vector3(0, 0, -4)}
	var open_one: Dictionary = {"id": &"canvases", "position": Vector3(6, 0, 6)}
	var secure: Dictionary = {"id": &"secure", "position": Vector3(-6, 0, 6)}
	(flow.get(&"_marker_blocked") as Dictionary)[flow.call(&"_marker_key", behind)] = door
	var markers: Array[Dictionary] = [secure, behind, open_one]
	assert_eq(flow.call(&"_pick", markers), open_one, "the other canvas marker of the same objective goes first")
	assert_true(flow.call(&"_is_marker_blocked", behind), "blocked while barred")
	_lift(door)
	await wait_physics_frames(2)
	assert_false(flow.call(&"_is_marker_blocked", behind), "passable again")
	assert_eq(flow.call(&"_pick", markers), behind, "HUD order again once the door is up")
	var escape: Dictionary = {"id": &"escape", "position": Vector3(-8, 0, 8)}
	markers.append(escape)
	assert_eq(flow.call(&"_pick", markers), escape, "GN probe 7: an open escape beats the optional extras")


## GN probe 6 / P's GN-P1 rerun (a): the hack (a FIRST objective) behind the coded ServerDoor, which the navmesh runs
## through: the pilot sees the door on the path before walking, works on it first (its keypad or drill) instead of
## pressing the terminal through the wall, then does the hack once the door is open.
func test_po5_gn_first_objective_behind_a_door_unblocks_it_first() -> void:
	var s: Dictionary = await _setup()
	var door: Door = s["door"]
	var flow: RefCounted = s["flow"]
	ATestMaps.add_prefab(_rt, "drill_point", Vector3(0.6, 1, 0.4), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 60.0)
	await wait_physics_frames(2)
	var hack: Dictionary = {"id": &"hack", "position": Vector3(0, 0, -4)}
	var other: Dictionary = {"id": &"keycard", "position": Vector3(6, 0, 6)}
	var markers: Array[Dictionary] = [hack, other]
	assert_eq(flow.call(&"_path_blocker", Vector3(0, 0, -4)), door, "the closed barred door on the navmesh path")
	var picked: Dictionary = flow.call(&"_pick", markers)
	assert_eq(picked.get("id"), flow.get(&"UNBLOCK_ID"), "the blocking door first")
	assert_true((picked["position"] as Vector3).distance_to(door.global_position) < 0.01, "at that door")
	_lift(door)
	await wait_physics_frames(2)
	assert_true(flow.call(&"_path_blocker", Vector3(0, 0, -4)) == null, "open: nothing on the path")
	assert_eq(flow.call(&"_pick", markers), hack, "then the hack")


## P's GN-P1 rerun (b): an empty mag with reserve left is reloaded (R), not fired dry.
func test_po5_pilot_reloads_an_empty_mag() -> void:
	var s: Dictionary = await _setup()
	var pilot: Po5Pilot = s["pilot"]
	var w: CrewWeapons = pilot.crew.weapons
	var ws: int = w.equipped_slot
	var st: Object = w._states[ws]
	st.set(&"mag", 0)
	var before: int = w.reserve(ws)
	assert_true(before > 0, "reserve left")
	var ok: bool = await pilot._ensure_ammo()
	assert_true(ok, "can shoot again")
	assert_true(w.mag(ws) > 0 and w.reserve(ws) < before, "reloaded from the reserve")


## GN probe 7: a marker that stalled (nothing usable) comes back as soon as something is usable there again (the
## interrupted Argus hack offers restart_hack), instead of staying skipped for the run.
func test_po5_gn_stalled_marker_returns_when_usable_again() -> void:
	var s: Dictionary = await _setup()
	var flow: RefCounted = s["flow"]
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(6, 1, 6), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 60.0) as DrillPoint
	await wait_physics_frames(2)
	var m: Dictionary = {"id": &"hack", "position": Vector3(6, 0, 6)}
	(flow.get(&"_stalls") as Dictionary)[&"hack"] = 60.0
	dp.interactable.enabled = false
	assert_true(flow.call(&"_stalled", m), "nothing usable: still stalled")
	dp.interactable.enabled = true
	assert_false(flow.call(&"_stalled", m), "usable again: picked again")
	assert_eq(float((flow.get(&"_stalls") as Dictionary)[&"hack"]), 0.0, "stall reset")


## GN probe 8: a bag put down to clear the way is fetched before the optional extras (secure goes first while one lies
## loose; _fetch_bag knows the bag's real kind, pick_bag), and the pilot stands a step back from it to aim at it.
func test_po5_gn_loose_bag_goes_first_and_is_aimed_from_a_step_back() -> void:
	var s: Dictionary = await _setup()
	var flow: RefCounted = s["flow"]
	var pilot: Po5Pilot = s["pilot"]
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, Vector3(6, 0.3, 6)))
	await wait_physics_frames(3)
	assert_eq(flow.call(&"_loose_bag"), bag.interactable, "a loose bag")
	var secure: Dictionary = {"id": &"secure", "position": Vector3(-6, 0, 6)}
	var extras: Dictionary = {"id": &"extras", "position": Vector3(8, 0, 8)}
	var markers: Array[Dictionary] = [extras, secure]
	assert_eq(flow.call(&"_pick", markers), secure, "carry the loose bag in before the extras")
	var stand: Vector3 = pilot._use_stand(bag.interactable)
	assert_true(pilot.flat_dist(stand, bag.global_position) >= 0.9, "not on top of the bag")


## GN probe 9: a bot carrying a canvas the pilot put down: the pilot leads it to the secure zone (once per bag, capped).
func test_po5_gn_pilot_leads_a_bag_carrying_bot_to_the_zone() -> void:
	var s: Dictionary = await _setup()
	var flow: RefCounted = s["flow"]
	var zone: Node3D = ATestMaps.add_prefab(_rt, "secure_zone", Vector3(-6, 0, 8))
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, bot.global_position + Vector3(0.5, 0.3, 0)))
	await wait_physics_frames(3)
	assert_true(zone != null and (s["pilot"] as Po5Pilot).secure_zone() != null, "a secure zone")
	assert_true(loot.carry(bag, bot), "the bot carries it")
	assert_true(await flow.call(&"_escort_mate_bag"), "pilot leads it")
	assert_true(float((flow.get(&"_escort_s") as Dictionary).get(bag.get_instance_id(), 0.0)) > 0.0, "escort time counted")
	(flow.get(&"_escort_s") as Dictionary)[bag.get_instance_id()] = 999.0
	assert_false(await flow.call(&"_escort_mate_bag"), "capped per bag")


## ENV C (GN Locker1): a wall-mounted prefab's marker sits on the wall; the pilot stands at the prefab's UsePoint, not
## at the navmesh point nearest the wall marker (which may be on the far side of the wall).
func test_po5_marker_stand_uses_prefab_use_point() -> void:
	var s: Dictionary = await _setup()
	var flow: RefCounted = s["flow"]
	var comp: InteractableComponent = s["comp"]
	var owner_n: Node3D = comp.owner_node() as Node3D
	var up: Node3D = owner_n.get_node_or_null(^"UsePoint") as Node3D
	if up == null:
		up = Node3D.new()
		up.name = "UsePoint"
		owner_n.add_child(up)
	up.global_position = owner_n.global_position + Vector3(0, 0, 1.0)  # inside the room, toward the door
	var marker: Vector3 = comp.global_position + Vector3(0, 0.9, -0.3)  # on the wall behind, 0.9 m up
	var stand: Vector3 = flow.call(&"_marker_stand", marker)
	var want: Vector3 = (s["pilot"] as Po5Pilot).stand_point(up.global_position)
	assert_true(stand.distance_to(want) < 0.05, "stands at the UsePoint (%s vs %s)" % [stand, want])
	var far: Vector3 = flow.call(&"_marker_stand", Vector3(20, 1, 20))
	assert_true(far.distance_to((s["pilot"] as Po5Pilot).stand_point(Vector3(20, 1, 20))) < 0.05,
		"no prefab near: nearest navmesh point")
