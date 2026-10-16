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
