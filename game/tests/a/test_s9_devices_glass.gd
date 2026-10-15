## A1-07 / A1-03 behaviour: drills (S9.3), safes, display cases + glass (S9.9, S10.3), windows (S9.11),
## keycard readers (S9.6), alarm button, suspicious doors.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _noises: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	await _launch(909)


func after_each() -> void:
	Engine.time_scale = 1.0
	await _teardown()


func _launch(seed_value: int) -> void:
	_events.clear()
	_noises.clear()
	_rt = await HeistLauncher.launch(&"unit_devices", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	for pair: Array in [
		[EventBus.device_started, &"device_started"], [EventBus.device_jammed, &"device_jammed"],
		[EventBus.device_restarted, &"device_restarted"], [EventBus.device_finished, &"device_finished"],
		[EventBus.glass_broken, &"glass_broken"], [EventBus.small_loot_taken, &"small_loot_taken"],
		[EventBus.alarm_raised, &"alarm_raised"], [EventBus.audio_cue_requested, &"audio_cue_requested"],
	]:
		_listen(pair[0], pair[1])
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append([p, r, k, s]))


func _teardown() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _noises_of(kind: StringName) -> int:
	var n: int = 0
	for e: Array in _noises:
		if e[2] == kind:
			n += 1
	return n


## Stand masked crew 0 at `p`'s UsePoint and hold interact on it for `seconds` (+ margin).
func _use(p: GameplayPrefab, seconds: float) -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func _drill(pos: Vector3, duration: float, target: NodePath = NodePath()) -> DrillPoint:
	return ATestMaps.add_prefab(_rt, "drill_point", pos, func(n: Node) -> void:
		(n as DrillPoint).duration_s = duration
		(n as DrillPoint).target = target) as DrillPoint


## PO-12: a placed drill shows its device (the catalog drill: Body + Bit) while placed, spins the Bit while
## running, shows a red jam mark while jammed and is removed when done.
func test_po12_drill_device_visible_spins_and_jams() -> void:
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -4), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 30.0
		(n as DrillPoint).device_scene = load("res://world/props/drill/prop_drill_device.tscn") as PackedScene) as DrillPoint
	await wait_physics_frames(1)
	assert_true(dp.device_node == null, "no device before placing")
	dp.runner.place(0, dp.effective_duration())
	await wait_frames(2)
	assert_true(dp.device_node != null and dp.device_node.is_visible_in_tree(), "placed: device visible")
	assert_false(dp.interactable.enabled, "running: the spot offers nothing (lead r215: no place prompt, timer panel only)")
	var meshes: Array[Node] = dp.device_node.find_children("*", "MeshInstance3D", true, false) if dp.device_node else []
	assert_true(meshes.size() >= 2, "device has visible meshes (%d)" % meshes.size())
	var bit: Node3D = dp.device_node.find_child("Bit", true, false) as Node3D if dp.device_node else null
	assert_true(bit != null, "device has a Bit")
	if bit != null:
		var b0: Basis = bit.basis
		await wait_frames(10)
		assert_true(not bit.basis.is_equal_approx(b0), "Bit spins while running")
	dp.runner.jams.clear()
	dp.runner.jams.append(dp.runner.progress)
	await wait_physics_frames(2)
	assert_eq(dp.device_state(), DeviceRunner.State.JAMMED, "jammed")
	assert_eq(dp.interactable.availability(null), InteractableComponent.BLOCK_NONE, "jammed: fixable")
	var mark: Node3D = dp.device_node.find_child("JamMark", true, false) as Node3D if dp.device_node else null
	assert_true(mark != null and mark.visible, "jam mark shows while jammed")
	if bit != null:
		var b1: Basis = bit.basis
		await wait_frames(10)
		assert_true(bit.basis.is_equal_approx(b1), "Bit still while jammed")
	dp.runner.fix(0)
	await wait_physics_frames(1)
	assert_false(mark != null and is_instance_valid(mark) and mark.visible, "jam mark hidden after the fix")
	dp.runner.progress = 0.999
	await wait_seconds(0.3)
	assert_eq(dp.device_state(), DeviceRunner.State.DONE, "done")
	assert_ne(dp.interactable.availability(null), InteractableComponent.BLOCK_STATE, "done: no reasonless block")
	await wait_frames(2)
	assert_true(dp.device_node == null, "device removed when done")
	var plain: DrillPoint = _drill(Vector3(3, 1, -4), 30.0)
	await wait_physics_frames(1)
	plain.runner.place(0, plain.effective_duration())
	await wait_frames(2)
	assert_true(plain.device_node != null, "default device from G.PROPS_DIR")


func test_s9_3_jams_deterministic_per_seed() -> void:
	var dp: DrillPoint = _drill(Vector3(0, 1, -4), 60.0)
	await wait_physics_frames(1)
	dp.runner.place(0, dp.effective_duration())
	var first: Array[float] = dp.runner.jams.duplicate()
	var restart_a: bool = dp.runner.auto_restart
	assert_true(first.size() >= Tweak.interaction().device_jams_min and first.size() <= Tweak.interaction().device_jams_max,
		"1..2 jams with jam chance 1 (got %d)" % first.size())
	for j: float in first:
		assert_true(j >= 0.15 and j <= 0.9, "jam at %.2f inside 15-90%%" % j)
	assert_false(restart_a, "no auto-restart without the modifier")
	await _teardown()
	await _launch(909)
	dp = _drill(Vector3(0, 1, -4), 60.0)
	await wait_physics_frames(1)
	dp.runner.place(0, dp.effective_duration())
	assert_eq(dp.runner.jams, first, "same seed -> same jams")
	var found_other: bool = false
	for s: int in [910, 911, 912, 913]:
		await _teardown()
		await _launch(s)
		dp = _drill(Vector3(0, 1, -4), 60.0)
		await wait_physics_frames(1)
		dp.runner.place(0, dp.effective_duration())
		if dp.runner.jams != first:
			found_other = true
			break
	assert_true(found_other, "other seeds roll other jams")


func test_s9_3_jam_chance_zero_never_jams() -> void:
	Modifiers.set_source(Modifiers.TEAM, &"test", {&"interaction.device_jam_chance_mult": 0.0})
	var dp: DrillPoint = _drill(Vector3(0, 1, -4), 60.0)
	await wait_physics_frames(1)
	dp.runner.place(0, dp.effective_duration())
	assert_eq(dp.runner.jams.size(), 0)


func test_s9_3_drill_place_jam_fix_finish_opens_safe() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(0, 0, -6), func(n: Node) -> void:
		var sl: SmallLoot = (load("res://systems/prefabs/small_loot/small_loot.tscn") as PackedScene).instantiate() as SmallLoot
		sl.name = "Cash"
		sl.position = Vector3(0, 0.5, 0)
		n.add_child(sl)) as Safe
	var dp: DrillPoint = _drill(Vector3(3, 1, -4), 20.0, NodePath("../%s" % safe.name))
	await wait_physics_frames(2)
	var cash: SmallLoot = safe.get_node(^"Cash") as SmallLoot
	assert_false(cash.interactable.enabled, "loot inside a closed safe is unusable")
	await _use(dp, Tweak.interaction().drill_place_s)
	assert_eq(_of(&"device_started").size(), 1, "device_started")
	if _of(&"device_started").is_empty():
		return
	assert_eq(int(_of(&"device_started")[0][1]), dp.net_id)
	assert_eq(_of(&"device_started")[0][2], &"drill")
	assert_near(float(_of(&"device_started")[0][3]), 20.0, 0.001, "duration × device_speed_mult")
	var stim_kinds: Array[StringName] = []
	for s: Dictionary in (_rt.service(G.SVC_STEALTH) as StealthDirector).stimuli():
		stim_kinds.append(s["kind"])
	assert_has(stim_kinds, &"drill", "drill stimulus while running")
	var jams: int = dp.runner.jams.size()
	Engine.time_scale = 4.0
	var fixes: int = 0
	while dp.device_state() != DeviceRunner.State.DONE and fixes < 4:
		var ok: bool = await wait_until(func() -> bool:
			return dp.device_state() == DeviceRunner.State.JAMMED or dp.device_state() == DeviceRunner.State.DONE, 30.0)
		assert_true(ok, "drill progresses")
		if dp.device_state() == DeviceRunner.State.JAMMED:
			assert_eq(dp.interactable.kind, &"fix_drill")
			assert_eq(dp.interactable.prompt_key, &"ui.prompt.fix_drill")
			var place_prompt: StringName = dp.get(&"_place_prompt")
			await _use(dp, Tweak.interaction().drill_fix_s)
			fixes += 1
			if dp.device_state() == DeviceRunner.State.RUNNING:
				assert_eq(dp.interactable.prompt_key, place_prompt, "no stale 'fix the drill' prompt while running")
	Engine.time_scale = 1.0
	assert_eq(_of(&"device_jammed").size(), jams, "every rolled jam happened")
	assert_eq(fixes, jams, "each jam fixed by the crew")
	assert_eq(_of(&"device_restarted").size(), jams)
	assert_eq(_of(&"device_finished").size(), 1, "finished")
	assert_true(safe.opened, "target safe opened by the device")
	var door: Node3D = safe.visual_node("Door") as Node3D
	assert_true(absf(door.rotation.y) > 1.0, "safe door swung")
	assert_true(cash.interactable.enabled, "loot usable once open")
	assert_true(_noises_of(&"drill") >= 5, "drill noise every ~2 s in stealth (%d)" % _noises_of(&"drill"))
	for e: Array in _noises:
		if e[2] == &"drill":
			assert_near(float(e[1]), Tweak.stealth().drill_radius_m, 0.001)
	stim_kinds.clear()
	for s: Dictionary in (_rt.service(G.SVC_STEALTH) as StealthDirector).stimuli():
		stim_kinds.append(s["kind"])
	assert_false(stim_kinds.has(&"drill"), "no drill stimulus after finishing")


func test_s9_3_auto_restart_and_silent_devices() -> void:
	Modifiers.set_source(Modifiers.TEAM, &"test", {
		&"interaction.device_auto_restart_chance": 1.0, &"stealth.silent_devices": true,
	})
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-4, 0, -6), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.VAULT) as Door
	var dp: DrillPoint = _drill(Vector3(-4, 1, -5), 30.0, NodePath("../%s" % door.name))
	await wait_physics_frames(2)
	await _use(dp, Tweak.interaction().drill_place_s)
	assert_true(dp.runner.auto_restart, "auto-restart rolled at placement")
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return dp.device_state() == DeviceRunner.State.DONE, 90.0)
	Engine.time_scale = 1.0
	assert_true(ok, "finished without anyone fixing")
	assert_eq(_of(&"device_restarted").size(), _of(&"device_jammed").size(), "every jam auto-restarted")
	for e: Array in _of(&"device_restarted"):
		assert_eq(int(e[2]), -1, "auto restart has no crew slot")
	assert_eq(_noises_of(&"drill"), 0, "stealth.silent_devices")
	assert_false(door.locked, "vault door unlocked")
	assert_true(door.is_open, "and opened")


func test_s9_9_display_case_break_noise_and_take_loot() -> void:
	var dc: DisplayCase = ATestMaps.add_prefab(_rt, "display_case", Vector3(0, 0, -4), func(n: Node) -> void:
		(n as DisplayCase).loot_id = &"loot.jewelry") as DisplayCase
	await wait_physics_frames(2)
	assert_eq(dc.interactable.kind, &"break_glass")
	await _use(dc, Tweak.interaction().glass_break_s)
	assert_true(dc.glass_broken, "glass broken")
	assert_eq(_of(&"glass_broken").size(), 1, "glass_broken fact")
	if not _of(&"glass_broken").is_empty():
		assert_eq(int(_of(&"glass_broken")[0][1]), dc.net_id)
	assert_false((dc.visual_node("Glass") as Node3D).visible, "Glass hidden")
	assert_eq(_noises_of(&"glass"), 1, "glass noise")
	for e: Array in _noises:
		if e[2] == &"glass":
			assert_near(float(e[1]), Tweak.stealth().glass_break_radius_m, 0.001, "15 m")
	var cues: Array[StringName] = []
	for e: Array in _of(&"audio_cue_requested"):
		cues.append(e[1])
	assert_has(cues, &"cue.glass_break")
	var kinds: Array[StringName] = []
	for s: Dictionary in (_rt.service(G.SVC_STEALTH) as StealthDirector).stimuli():
		kinds.append(s["kind"])
	assert_has(kinds, &"broken_glass", "broken_glass stimulus")
	assert_true(_of(&"alarm_raised").is_empty(), "plain case: no alarm")
	assert_eq(dc.interactable.kind, &"take_loot")
	await _use(dc, Tweak.interaction().small_loot_s)
	assert_eq(_of(&"small_loot_taken").size(), 1, "S10.3 small loot taken")
	if not _of(&"small_loot_taken").is_empty():
		assert_eq(int(_of(&"small_loot_taken")[0][1]), LootManager.loot_info(&"loot.jewelry")["value"], "ContentDB value")
		assert_eq(int(_of(&"small_loot_taken")[0][2]), 0, "slot")
	assert_false(dc.interactable.enabled, "emptied")


func test_s9_9_shooting_alarmed_case_raises_alarm() -> void:
	var dc: DisplayCase = ATestMaps.add_prefab(_rt, "display_case", Vector3(0, 0, -4), func(n: Node) -> void:
		(n as DisplayCase).glass_breaks_alarm = true) as DisplayCase
	await wait_physics_frames(2)
	var col: Node = dc.get_node(^"Collision")
	assert_true(col.get_meta(&"hit_owner") == dc, "hits route to the case")
	dc.apply_damage({"amount": 50.0}, 0)
	await wait_physics_frames(2)
	assert_true(dc.glass_broken)
	assert_eq(_of(&"alarm_raised").size(), 1)
	if not _of(&"alarm_raised").is_empty():
		assert_eq(_of(&"alarm_raised")[0][1], &"glass_alarm")
	await _use(dc, Tweak.interaction().small_loot_s)
	assert_eq(int(_of(&"small_loot_taken")[0][1]) if not _of(&"small_loot_taken").is_empty() else -1,
		LootTweak.get_default().display_case_default_value, "fallback value without loot_id")


func test_s9_11_windows_break_and_open() -> void:
	var w: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(0, 0.9, -4)) as WindowPrefab
	var ow: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(4, 0.9, -4), func(n: Node) -> void:
		(n as WindowPrefab).openable = true) as WindowPrefab
	await wait_physics_frames(2)
	assert_eq(w.interactable.kind, &"break_window")
	w.apply_damage({"amount": 10.0}, 0)
	await wait_physics_frames(1)
	assert_true(w.broken, "shot window breaks")
	assert_eq((w.get_node(^"GlassBody") as StaticBody3D).collision_layer, 0, "no glass collision")
	assert_eq(_of(&"glass_broken").size(), 1)
	assert_eq(_noises_of(&"glass"), 1)
	assert_false(w.interactable.enabled)
	var sash: Node3D = ow.visual_node("Sash") as Node3D
	var y0: float = sash.position.y
	await _use(ow, Tweak.interaction().window_open_s)
	assert_true(ow.is_open, "openable window opened")
	assert_true(sash.position.y > y0 + 0.3, "sash slid up")


## QC-61: a `walkable` window has a layer-1 NavLink through the opening, enabled only while passable (sash
## open or glass broken); a plain window has none.
func test_qc61_walkable_window_nav_link() -> void:
	var plain: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(-4, 0.0, -4)) as WindowPrefab
	var latched: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(0, 0.0, -4), func(n: Node) -> void:
		(n as WindowPrefab).walkable = true) as WindowPrefab
	var sash: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(4, 0.0, -4), func(n: Node) -> void:
		(n as WindowPrefab).walkable = true
		(n as WindowPrefab).openable = true) as WindowPrefab
	await wait_physics_frames(2)
	assert_true(plain.nav_link() == null, "a plain window has no NavLink")
	for w: WindowPrefab in [latched, sash]:
		assert_true(w.nav_link() != null, "walkable window builds a NavLink")
		assert_eq(w.nav_link().navigation_layers, 1, "layer 1: every agent may use it when passable")
		assert_false(w.nav_link().enabled, "shut window: link disabled")
	latched.break_glass(0)
	await wait_physics_frames(1)
	assert_true(latched.nav_link().enabled, "broken glass: passable")
	sash.set_open(true)
	await wait_physics_frames(1)
	assert_true(sash.nav_link().enabled, "open sash: passable")
	sash.set_open(false)
	await wait_physics_frames(1)
	assert_false(sash.nav_link().enabled, "closed again: link off")
	var tall: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(8, 0.0, -4), func(n: Node) -> void:
		(n as WindowPrefab).openable = true
		(n as WindowPrefab).sash_travel_m = 1.8) as WindowPrefab
	await wait_physics_frames(2)
	var tsash: Node3D = tall.visual_node("Sash") as Node3D
	var ty0: float = tsash.position.y
	tall.set_open(true)
	assert_near(tsash.position.y - ty0, 1.8, 0.001, "per-window sash_travel_m")


func test_s9_6_keycard_reader_opens_targets() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-4, 0, -6), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.ELECTRONIC) as Door
	var kr: KeycardReader = ATestMaps.add_prefab(_rt, "keycard_reader", Vector3(-2.5, 1.2, -6.2), func(n: Node) -> void:
		var arr: Array[NodePath] = [NodePath("../%s" % door.name)]
		(n as KeycardReader).targets = arr) as KeycardReader
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(kr.interactable.availability(c), InteractableComponent.BLOCK_CASING)
	c.set_masked()
	assert_eq(kr.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "needs a keycard")
	c.add_item(&"item.keycard")
	await _use(kr, Tweak.interaction().keycard_s)
	assert_eq(c.item_count(&"item.keycard"), 0, "consumed")
	assert_false(door.locked, "unlocked")
	assert_true(door.is_open, "opened")


func test_alarm_button_phone_and_suspicious_door() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-4, 0, -6), func(n: Node) -> void:
		(n as Door).suspicious_when_open = true) as Door
	var ab: AlarmButton = ATestMaps.add_prefab(_rt, "alarm_button", Vector3(4, 1.2, -6)) as AlarmButton
	var ph: Phone = ATestMaps.add_prefab(_rt, "phone", Vector3(6, 1.0, -6)) as Phone
	await wait_physics_frames(2)
	var st: StealthDirector = _rt.service(G.SVC_STEALTH) as StealthDirector
	door.set_open(true)
	var kinds: Array[StringName] = []
	for s: Dictionary in st.stimuli():
		kinds.append(s["kind"])
	assert_has(kinds, &"open_door", "suspicious open door is a stimulus")
	door.set_open(false)
	kinds.clear()
	for s: Dictionary in st.stimuli():
		kinds.append(s["kind"])
	assert_false(kinds.has(&"open_door"), "closed again")
	assert_true(ab.use_point_position().distance_to(ab.global_position) < 2.0, "use point")
	assert_true(ph.use_point_position().distance_to(ph.global_position) < 2.0, "phone use point")
	ab.press(123)
	await wait_physics_frames(1)
	assert_eq(_of(&"alarm_raised").size(), 1)
	if not _of(&"alarm_raised").is_empty():
		assert_eq(_of(&"alarm_raised")[0][1], &"alarm_button")
		assert_eq(int(_of(&"alarm_raised")[0][2]), 123)
