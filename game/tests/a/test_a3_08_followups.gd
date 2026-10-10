## A3-08 follow-ups (D-038): QA-17 crew_cuffed / crew_uncuffed [R], QA-19 HeistResult.fail_reason,
## QB-46 CrewController.set_input_paused, QB-47 camera + WeaponVisual + mask (CrewView), QB-48
## LocalHudModel tracked_crew mode without a HeistRuntime, QB-49 gamepad look (look_* actions).
## (QA-16 ECM feedback: test_s8_6_ecm_feedback.gd; QA-18 PreplanResult: test_c3_preplanning.gd.)
extends TestCase

var _rt: HeistRuntime = null
var _root: Node3D = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	for a: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		Input.action_release(a)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


func _launch(options: Dictionary = {}, def: HeistDef = null) -> void:
	var o: Dictionary = {"map_packed": ATestMaps.basic(0, 0) if def == null else ATestMaps.with_heist_def(def),
		"ai_teammates": 1, "skip_casing": true, "crew_ai": false}
	o.merge(options, true)
	_rt = await HeistLauncher.launch(&"unit_map", 31, Enums.Difficulty.ROUTINE, self, o)
	await wait_frames(2)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _range_root() -> void:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "RangeRoot"
	add_child(_root)
	await wait_frames(1)


# --- QA-17 -----------------------------------------------------------------------------------------

func test_qa_17_cuff_events() -> void:
	await _launch()
	_listen(EventBus.crew_cuffed, &"cuffed")
	_listen(EventBus.crew_uncuffed, &"uncuffed")
	var cuffs: CrewCuffs = CrewCuffs.of(_crew(), true)
	await wait_frames(1)
	assert_true(cuffs.cuff(777), "cuffed")
	assert_eq(_of(&"cuffed"), [[&"cuffed", 0, 777]] as Array[Array], "crew_cuffed(crew_slot, by_net_id)")
	cuffs.free_crew(1)
	assert_eq(_of(&"uncuffed"), [[&"uncuffed", 0, 1]] as Array[Array], "crew_uncuffed(crew_slot, by_crew_slot)")
	cuffs.cooldown_left = 0.0
	assert_true(cuffs.cuff(777))
	cuffs.cuffed_left = 0.01
	await wait_physics_frames(3)
	assert_eq(_of(&"uncuffed").size(), 2)
	assert_eq(int(_of(&"uncuffed")[1][2]), -1, "-1 = freed themselves")
	cuffs.cooldown_left = 0.0
	assert_true(cuffs.cuff(777))
	_crew().set_crew_state(Enums.CrewState.DOWNED)
	assert_eq(_of(&"uncuffed").size(), 3, "another state change ending the cuffs also reports crew_uncuffed")
	assert_eq(_of(&"cuffed").size(), 3)


# --- QA-19 -----------------------------------------------------------------------------------------

func test_qa_19_fail_reason_success_and_defaults() -> void:
	await _launch()
	_listen(EventBus.heist_ended, &"ended")
	var r: Dictionary = _rt.end_heist(true)
	assert_eq(r.get("fail_reason", null), &"", "success -> &\"\"")
	assert_eq(_of(&"ended").size(), 1)
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	await _launch()
	r = _rt.end_heist(false)
	assert_eq(r["fail_reason"], HeistRuntime.FAIL_ABORT, "a failure without a reason is an abort")
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	await _launch()
	r = _rt.end_heist(false, [], HeistRuntime.FAIL_ALL_CUSTODY)
	assert_eq(r["fail_reason"], &"all_custody")
	assert_eq(_rt.end_heist(true), {}, "only the first end counts")


func test_qa_19_fail_reason_mission_and_stealth_only() -> void:
	await _launch()
	_listen(EventBus.heist_ended, &"ended")
	_rt.mission.end_heist(false, &"vault_destroyed")
	assert_eq((_of(&"ended")[0][1] as Dictionary)["fail_reason"], &"vault_destroyed", "HeistMission.end_heist reason")
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	_events.clear()
	var def: HeistDef = HeistDef.new()
	def.id = &"unit_mode"
	def.mode = Enums.HeistMode.STEALTH_ONLY
	await _launch({}, def)
	_rt.stealth.raise_alarm(&"test", 0)
	_rt.stealth_abort_left = minf(_rt.stealth_abort_left, 0.05)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"ended").is_empty(), 2.0)
	assert_true(ok, "stealth-only abort ends the heist")
	if ok:
		var res: Dictionary = _of(&"ended")[0][1]
		assert_false(bool(res["success"]))
		assert_eq(res["fail_reason"], HeistRuntime.FAIL_STEALTH_ONLY_ALARM)


# --- QB-46 -----------------------------------------------------------------------------------------

func test_qb_46_set_input_paused() -> void:
	await _launch()
	var c: CrewController = _crew()
	var pin: PlayerInput = c.get_node_or_null(^"PlayerInput") as PlayerInput
	assert_true(pin != null and pin.enabled, "local human has an enabled PlayerInput")
	var i: CrewIntent = CrewIntent.new()
	i.fire = true
	i.move = Vector2(0, 1)
	i.look_yaw = 0.7
	c.apply_intent(i)
	await wait_physics_frames(1)
	c.set_input_paused(true)
	assert_false(pin.enabled, "PlayerInput paused")
	assert_false(c.intent.fire, "idle intent: no buttons")
	assert_eq(c.intent.move, Vector2.ZERO, "idle intent: no movement")
	assert_near(c.intent.look_yaw, c.look_yaw, 0.0001, "idle intent keeps the look direction")
	await wait_physics_frames(3)
	assert_false(c.intent.fire, "PlayerInput builds no intents while paused")
	c.look_yaw = 1.25
	c.set_input_paused(false)
	assert_true(pin.enabled, "resumed")
	await wait_physics_frames(2)
	assert_near(c.intent.look_yaw, 1.25, 0.0001, "resuming re-reads the crew's look direction")


# --- QB-47 -----------------------------------------------------------------------------------------

func test_qb_47_local_camera_current_and_weapon_visual() -> void:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.corsair_ar"
	l.secondary = &"weapon.kestrel_p9"
	await _launch({"loadouts": {0: l, 1: l}})
	var c: CrewController = _crew()
	var cam: Camera3D = c.get_node(^"Head/Camera") as Camera3D
	assert_true(cam.current, "local human's camera is current")
	assert_eq(cam.get_viewport().get_camera_3d(), cam, "viewport camera")
	assert_false((_crew(1).get_node(^"Head/Camera") as Camera3D).current, "AI teammate's camera is not")
	assert_true(c.weapon_visual is WeaponVisual, "WeaponVisual attached")
	if not (c.weapon_visual is WeaponVisual):
		return
	assert_eq(c.weapon_visual.get_parent(), cam, "under the camera")
	assert_eq((c.weapon_visual as WeaponVisual).weapon.id, c.weapons.weapon_id(c.weapons.equipped_slot), "equipped weapon")
	assert_true((c.weapon_visual as WeaponVisual).get_marker(&"Muzzle") != null, "Muzzle marker for CrewWeapons")
	assert_true(_crew(1).weapon_visual == null, "no viewmodel for the AI teammate")
	var other: int = Enums.WeaponSlot.SECONDARY if c.weapons.equipped_slot == Enums.WeaponSlot.PRIMARY else Enums.WeaponSlot.PRIMARY
	assert_true(c.weapons.equip(other), "weapon switch")
	assert_eq((c.weapon_visual as WeaponVisual).weapon.id, c.weapons.weapon_id(other), "rebuilt on switch")
	var l2: Loadout = Loadout.new()
	l2.secondary = &"weapon.warden_45"
	c.set_loadout(l2)
	assert_eq((c.weapon_visual as WeaponVisual).weapon.id, &"weapon.warden_45", "rebuilt on set_loadout")
	await wait_frames(1)
	assert_eq(cam.get_children().filter(func(n: Node) -> bool: return n is WeaponVisual).size(), 1, "one viewmodel")


func test_qb_47_mask_at_head_socket_when_masked() -> void:
	var l: Loadout = Loadout.new()
	l.mask = &"mask.gilded_heron"
	await _launch({"loadouts": {0: l, 1: l}})
	var c: CrewController = _crew()
	var view: CrewView = CrewView.of(c)
	assert_true(view != null, "View component")
	assert_true(view.mask_node() == null, "no mask while unmasked")
	c.set_masked()
	_crew(1).set_masked()
	await wait_frames(1)
	var m: Node3D = view.mask_node()
	assert_true(m != null, "mask attached once masked")
	if m != null:
		assert_eq(m.get_parent().name, &"Socket", "at Head/Socket")
		assert_eq(m.get_parent().get_parent().name, &"Head")
		assert_true(c.get_node_or_null(^"Visual/Head/Socket/Mask") != null, "capsule placeholder path Visual/Head/Socket")
		for n: Node in m.find_children("*", "VisualInstance3D", true, false):
			assert_eq((n as VisualInstance3D).layers, CrewView.FIRST_PERSON_HIDDEN_LAYER, "hidden from the own camera")
		var cam: Camera3D = c.get_node(^"Head/Camera") as Camera3D
		assert_eq(cam.cull_mask & CrewView.FIRST_PERSON_HIDDEN_LAYER, 0, "own camera culls that layer")
	var m1: Node3D = CrewView.of(_crew(1)).mask_node()
	assert_true(m1 != null, "teammate's mask")
	if m1 != null:
		for n: Node in m1.find_children("*", "VisualInstance3D", true, false):
			assert_ne((n as VisualInstance3D).layers, CrewView.FIRST_PERSON_HIDDEN_LAYER, "visible on teammates")


func test_qb_47_range_crew_viewmodel_and_external_bridge() -> void:
	await _range_root()
	var c: CrewController = CrewController.spawn_for_range(_root, Transform3D.IDENTITY, null) as CrewController
	await wait_frames(2)
	var cam: Camera3D = c.get_node(^"Head/Camera") as Camera3D
	assert_true(cam.current, "range crew camera current")
	assert_true(c.weapon_visual is WeaponVisual, "range crew gets the viewmodel")
	var def: WeaponDef = ContentDB.weapon(&"weapon.kestrel_p9")
	var theirs: WeaponVisual = RangeCrewBridge.attach_viewmodel(c, def, [] as Array[StringName], Vector3(0.1, -0.1, -0.3))
	await wait_frames(2)
	assert_eq(c.weapon_visual, theirs, "an external WeaponVisual under the camera wins")
	assert_eq(cam.get_children().filter(func(n: Node) -> bool: return n is WeaponVisual).size(), 1, "ours removed")
	c.set_loadout(null)
	await wait_frames(1)
	assert_eq(c.weapon_visual, theirs, "and ours is not re-attached")


# --- QB-48 -----------------------------------------------------------------------------------------

func test_qb_48_hud_tracked_crew_without_runtime() -> void:
	await _range_root()
	assert_true(HeistRuntime.current() == null, "no heist running")
	var c: CrewController = CrewController.spawn_for_range(_root, Transform3D.IDENTITY, null) as CrewController
	var hud: LocalHudModel = LocalHudModel.new()
	hud.name = "LocalHudModel"
	_root.add_child(hud)
	var fired: Array[int] = [0]
	hud.inventory_changed.connect(func() -> void: fired[0] += 1)
	hud.track(c)
	assert_eq(hud.tracked_crew, c)
	assert_eq(hud.tracked_slot_resolved, c.slot)
	assert_true(hud.masked, "masked from the crew member")
	var ws: int = c.weapons.equipped_slot
	assert_eq(hud.equipped_slot, ws)
	assert_eq(int((hud.ammo[ws] as Dictionary)["mag"]), c.weapons.mag(ws), "ammo from the crew's weapons")
	assert_near(hud.health, c.health.health, 0.001, "vitals from crew.health")
	c.cable_ties = 7
	fired[0] = 0
	hud.refresh()
	assert_eq(hud.cable_ties, 7)
	assert_eq(fired[0], 1, "group signal fires once (v1.1 binding shape)")
	assert_true(hud.is_in_group(G.LOCAL_HUD_MODEL))
	c.free()
	hud.refresh()
	assert_true(hud.tracked_crew == null, "a freed crew member drops back to slot mode")


# --- QB-49 -----------------------------------------------------------------------------------------

func test_qb_49_gamepad_look_delta() -> void:
	var pin: PlayerInput = PlayerInput.new()
	pin.gamepad_look_speed = 2.0
	pin.gamepad_deadzone = 0.2
	pin.gamepad_curve = 1.0
	assert_eq(pin.gamepad_look_delta(Vector2(0.15, 0.0), 1.0), Vector2.ZERO, "inside the deadzone")
	var right: Vector2 = pin.gamepad_look_delta(Vector2(1.0, 0.0), 0.5)
	assert_near(right.x, -1.0, 0.001, "full right -> yaw decreases at speed (like mouse right)")
	assert_near(right.y, 0.0, 0.001)
	var up: Vector2 = pin.gamepad_look_delta(Vector2(0.0, -1.0), 1.0)
	assert_near(up.y, 2.0, 0.001, "stick up -> pitch up")
	pin.gamepad_invert_y = true
	assert_near(pin.gamepad_look_delta(Vector2(0.0, -1.0), 1.0).y, -2.0, 0.001, "invert Y")
	var half: Vector2 = pin.gamepad_look_delta(Vector2(0.6, 0.0), 1.0)
	assert_near(half.x, -1.0, 0.001, "rescaled past the deadzone: (0.6-0.2)/0.8 = 0.5")
	pin.free()


func test_qb_49_gamepad_look_actions_turn_the_crew() -> void:
	for a: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		assert_true(InputMap.has_action(a), "%s in project.godot" % a)
	await _launch()
	var c: CrewController = _crew()
	var yaw0: float = c.look_yaw
	Input.action_press(&"look_right", 1.0)
	Input.action_press(&"look_up", 1.0)
	await wait_physics_frames(10)
	Input.action_release(&"look_right")
	Input.action_release(&"look_up")
	await wait_physics_frames(2)
	assert_true(c.look_yaw < yaw0 - 0.05, "right stick turns right (yaw %.3f -> %.3f)" % [yaw0, c.look_yaw])
	assert_true(c.look_pitch > 0.05, "right stick up looks up (pitch %.3f)" % c.look_pitch)
