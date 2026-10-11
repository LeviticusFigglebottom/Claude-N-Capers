## A3-11 hub support: QC-43 CrewController.spawn_for_hub (no HeistRuntime: civilian, unmasked, no weapon
## drawn, its own InteractionSystem, HUD prompt via LocalHudModel.track) and QC-44 `hub_station` (instant,
## civilian allowed, prompt ui.prompt.station.<id>, station_used / station_requested).
extends TestCase

const STATION_SCENE: String = "res://systems/prefabs/hub_station/hub_station.tscn"

var _root: Node3D = null


func after_each() -> void:
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
	c.set_input_paused(true)  # drive the intent by hand
	return c


func _station(id: StringName, pos: Vector3) -> HubStationPrefab:
	var st: HubStationPrefab = (load(STATION_SCENE) as PackedScene).instantiate() as HubStationPrefab
	st.station_id = id
	_root.add_child(st)
	st.global_position = pos
	st.rotation.y = PI  # its UsePoint (-Z side) faces the crew at the origin
	return st


func _aim(c: CrewController, at: Vector3, interact: bool) -> void:
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), at)
	i.interact = interact
	c.apply_intent(i)


func test_hub_crew_is_civilian_without_runtime() -> void:
	var c: CrewController = await _hub()
	assert_true(HeistRuntime.of(c) == null, "no HeistRuntime")
	assert_true(c.civilian and not c.masked, "unmasked civilian")
	assert_eq(c.player_mode, &"civilian")
	assert_true(c.hub_interaction != null, "own InteractionSystem")
	await wait_frames(3)
	assert_true(c.weapon_visual == null, "no weapon drawn")
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	c.apply_intent(i)
	await wait_seconds(Tweak.crew().mask_up_time_s + 0.3)
	assert_false(c.masked, "S1.3: no mask-up")
	assert_false(c.weapons.can_fire(), "no firing")


func test_station_press_and_hud_prompt() -> void:
	var c: CrewController = await _hub()
	var st: HubStationPrefab = _station(&"board", Vector3(0, 0, -1.6))
	await wait_physics_frames(2)
	var hud: LocalHudModel = LocalHudModel.new()
	hud.name = "LocalHudModel"
	_root.add_child(hud)
	assert_true(st.is_in_group(HubStationPrefab.GROUP), "in group hub_station (D-072)")
	var used: Array = []
	st.station_used.connect(func(id: StringName, who: Node) -> void: used.append([id, who]))
	var req: Array[StringName] = []
	st.station_requested.connect(func(id: StringName) -> void: req.append(id))
	var at: Vector3 = st.interactable.global_position
	_aim(c, at, false)
	await wait_physics_frames(2)
	hud.track(c)
	assert_eq(StringName(hud.interaction.get("text_key", &"")), &"ui.prompt.station.board", "HUD prompt")
	assert_eq(StringName(hud.interaction.get("blocked_reason", &"")), &"", "usable by a civilian")
	_aim(c, at, true)
	await wait_physics_frames(2)
	assert_eq(used.size(), 1, "instant press")
	if used.size() == 1:
		assert_eq(used[0][0], &"board")
		assert_eq(used[0][1], c)
	assert_eq(req, [&"board"] as Array[StringName], "station_requested(id)")
	await wait_physics_frames(3)
	assert_eq(used.size(), 1, "one use per press (release first)")
	_aim(c, at, false)
	await wait_physics_frames(2)
	_aim(c, at, true)
	await wait_physics_frames(2)
	assert_eq(used.size(), 2, "pressed again")


func test_station_out_of_reach() -> void:
	var c: CrewController = await _hub()
	var st: HubStationPrefab = _station(&"armory", Vector3(0, 0, -4.0))
	await wait_physics_frames(2)
	var used: Array[int] = [0]
	st.station_used.connect(func(_id: StringName, _w: Node) -> void: used[0] += 1)
	_aim(c, st.interactable.global_position, true)
	await wait_physics_frames(3)
	assert_eq(used[0], 0, "beyond InteractionTweak.reach_m")
