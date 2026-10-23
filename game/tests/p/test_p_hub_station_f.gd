## PO (2026-10-23): "the 'press F' buttons in the safehouse don't seem to work". The real hub walker
## (CrewController.spawn_for_hub, no HeistRuntime) with LIVE input (PlayerInput + PInputDriver, not a hand-built intent
## as A's test_a3_11_hub): aimed at a hub_station within reach, a tap of F uses it (station_used), and does not shout.
## Root cause: PlayerInput gated F on rt.interaction, which is null in the hub (no HeistRuntime), so F was never an
## interact; it now falls back to the walker's HubInteraction. Owner: ENV P.
extends TestCase

const STATION_SCENE: String = "res://systems/prefabs/hub_station/hub_station.tscn"

var _root: Node3D = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(2)


func _hub() -> CrewController:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "HubRoot"
	add_child(_root)
	ATestMaps.add_wall(_root, Vector3(0, -0.1, 0), Vector3(20, 0.2, 20))  # floor
	await wait_frames(1)
	var c: CrewController = CrewController.spawn_for_hub(_root, Transform3D.IDENTITY, null) as CrewController
	await wait_physics_frames(3)
	_inp = PInputDriver.new(self)
	return c


func _station(id: StringName, pos: Vector3) -> HubStationPrefab:
	var st: HubStationPrefab = (load(STATION_SCENE) as PackedScene).instantiate() as HubStationPrefab
	st.station_id = id
	_root.add_child(st)
	st.global_position = pos
	st.rotation.y = PI  # its UsePoint (-Z side) faces the crew at the origin
	return st


## Turn the walker's PlayerInput to look at `at` (the mouse-look path: add_look on the input's own yaw / pitch).
func _look_at(c: CrewController, at: Vector3) -> void:
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	var to: Vector3 = at - c.eye_position()
	var want_pitch: float = atan2(to.y, Vector2(to.x, to.z).length())
	var want_yaw: float = atan2(-to.x, -to.z)
	pin.add_look(wrapf(want_yaw - c.look_yaw, -PI, PI), want_pitch - c.look_pitch)
	await wait_physics_frames(6)


func test_f_uses_a_station_in_the_hub() -> void:
	var c: CrewController = await _hub()
	var st: HubStationPrefab = _station(&"board", Vector3(0, 0, -1.6))
	var used: Array[StringName] = []
	st.station_used.connect(func(id: StringName, _who: Node) -> void: used.append(id))
	var comp: InteractableComponent = st.interactable
	await _look_at(c, comp.global_position)
	assert_true(c.hub_interaction.aimed_component(c) == comp, "the station is aimed at (prompt shown)")
	var shouts: Array[int] = [0]
	await _inp.tap(&"interact")
	for _k: int in 20:
		await wait_physics_frames(1)
		if c.intent != null and c.intent.shout:
			shouts[0] += 1
	assert_eq(used, [&"board"] as Array[StringName], "F in the hub uses the station (station_used)")
	assert_eq(shouts[0], 0, "and is not a shout")


func test_f_with_nothing_aimed_is_still_a_shout() -> void:
	var c: CrewController = await _hub()
	_station(&"armory", Vector3(0, 0, -6.0))  # out of reach
	var shouted: Array[bool] = [false]
	_inp.press(&"interact")
	for _k: int in 5:
		await wait_physics_frames(1)
		shouted[0] = shouted[0] or (c.intent != null and c.intent.shout)
	_inp.release(&"interact")
	assert_true(shouted[0], "F at nothing stays a shout")
