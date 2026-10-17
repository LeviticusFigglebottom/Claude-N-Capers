## D-130 (PO): S heists get fewer pagers and Titan cameras earlier by difficulty (HeistDef.pager_max_by_difficulty /
## camera_titan_min_difficulty, data_schemas v1.3); cameras detect ~20 % faster (pinned in test_d128_detection_pd2).
## ui_hud v1.18: optional objectives are `side` steps; a data-only objective update says state_changed false.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1300, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	await wait_physics_frames(2)


func _def() -> HeistDef:
	var d: HeistDef = HeistDef.new()
	_rt.map.heist_def = d
	return d


func test_d130_pager_cap_by_difficulty() -> void:
	await _launch()
	var tw: StealthTweak = Tweak.stealth()
	_rt.map.heist_def = null
	assert_eq(PagerSystem.cap_for(_rt), tw.pager_max_answers, "no def: the tweak cap")
	var d: HeistDef = _def()
	assert_eq(PagerSystem.cap_for(_rt), tw.pager_max_answers, "empty pager_max_by_difficulty: the tweak cap")
	d.pager_max_by_difficulty = [4, 4, 3, 3, 2, 1]  # Golden Hour (D-130 §2)
	var want: Array[int] = [4, 4, 3, 3, 2, 1]
	for diff: int in Enums.Difficulty.values():
		_rt.difficulty = diff
		assert_eq(PagerSystem.cap_for(_rt), want[diff], "difficulty %d: %d pagers" % [diff, want[diff]])
	_rt.variants[PagerSystem.MAX_ANSWERS_SCALAR] = 2
	_rt.difficulty = Enums.Difficulty.ROUTINE
	assert_eq(PagerSystem.cap_for(_rt), 2, "a rolled pager_max_answers scalar wins")
	_rt.variants.erase(PagerSystem.MAX_ANSWERS_SCALAR)
	var ps: PagerSystem = _rt.service(G.SVC_PAGERS) as PagerSystem
	ps.max_answers = PagerSystem.cap_for(_rt)
	assert_eq(ps.pagers_max(), 4, "the HUD reads pagers_max() from the service")
	ps.set_answered_total(1)
	assert_eq(ps.pagers_answered(), 1, "and pagers_answered()")


func test_d130_titan_cameras_from_the_heist_def() -> void:
	await _launch()
	var tw: StealthTweak = Tweak.stealth()
	_rt.map.heist_def = null
	assert_eq(SecurityCamera.titan_min_difficulty(_rt), tw.camera_titan_min_difficulty, "no def: the tweak (LETHAL)")
	var d: HeistDef = _def()
	assert_eq(SecurityCamera.titan_min_difficulty(_rt), tw.camera_titan_min_difficulty, "-1: the tweak")
	d.camera_titan_min_difficulty = Enums.Difficulty.HAZARDOUS  # Golden Hour (D-130 §3)
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", Vector3(0, 3, -4)) as SecurityCamera
	assert_true(cam != null, "camera")
	if cam == null:
		return
	_rt.difficulty = Enums.Difficulty.TENSE
	assert_false(cam.is_titan(), "Tense: destructible")
	_rt.difficulty = Enums.Difficulty.HAZARDOUS
	assert_true(cam.is_titan(), "Hazardous: Titan on Golden Hour")
	d.camera_titan_min_difficulty = -1
	assert_eq(cam.is_titan(), Enums.Difficulty.HAZARDOUS >= tw.camera_titan_min_difficulty, "other heists: the tweak")


func test_d130_camera_presets_faster() -> void:
	var p: Dictionary = Tweak.stealth().observer_presets[&"camera"]
	assert_near(float(p["delay_min"]), 1.6, 0.001, "delay_min 2.0 -> 1.6")
	assert_near(float(p["delay_max"]), 2.4, 0.001, "delay_max 3.0 -> 2.4")


func test_ui_hud_1_18_side_steps_and_state_changed() -> void:
	await _launch()
	var m: HeistMission = HeistMission.new()
	_rt.add_child(m)
	m._bind(_rt)
	var seen: Array[Dictionary] = []
	var cb: Callable = func(id: StringName, state: int, data: Dictionary) -> void:
		seen.append({"id": id, "state": state, "data": data})
	EventBus.objective_updated.connect(cb)
	m.add_objective(&"bonus", &"obj.bonus", Enums.ObjectiveState.ACTIVE, {"optional": true})
	m.add_objective(&"main", &"obj.main", Enums.ObjectiveState.ACTIVE, {})
	m.add_objective(&"kept", &"obj.kept", Enums.ObjectiveState.ACTIVE, {"optional": true, "side": false})
	m.update_objective_data(&"bonus", {"count": 1})
	m.complete(&"bonus")
	EventBus.objective_updated.disconnect(cb)
	m._unbind()
	m.queue_free()
	assert_eq(seen.size(), 5, "five facts")
	if seen.size() < 5:
		return
	assert_true(bool(seen[0]["data"].get("side", false)), "an optional objective is a side step")
	assert_false(bool(seen[1]["data"].get("side", false)), "a main step is not")
	assert_false(bool(seen[2]["data"].get("side", true)), "an explicit side: false stays")
	assert_true(bool(seen[0]["data"]["state_changed"]), "added: state_changed")
	assert_false(bool(seen[3]["data"]["state_changed"]), "data-only update: state_changed false")
	assert_eq(int(seen[3]["state"]), Enums.ObjectiveState.ACTIVE, "same state")
	assert_true(bool(seen[4]["data"]["state_changed"]), "completed: state_changed")


## D-130 §1 runtime: VariantResolver's difficulty_add works the same on a civilian group as on a guard group, and
## every spawn point of an active slot spawns (no cap clips stealth spawns). C's per-heist rows are pinned once they land.
func test_d130_difficulty_add_scales_guards_and_civilians() -> void:
	var counts: Dictionary = {}
	for diff: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.CATACLYSM]:
		_rt = await HeistLauncher.launch(&"unit_map", 1301, diff, self,
			{"map_packed": _scaled_map(), "ai_teammates": 0, "crew_ai": false})
		await wait_physics_frames(2)
		counts[diff] = [_rt.npcs(&"guard").size(), _rt.npcs(&"civilian").size()]
		_rt.teardown()
		_rt = null
		await wait_frames(2)
	assert_eq(counts[Enums.Difficulty.ROUTINE], [2, 3], "Routine: the baseline (2 guards, 3 civilians)")
	assert_eq(counts[Enums.Difficulty.CATACLYSM], [3, 4], "Cataclysm: +1 guard slot, +1 civilian slot")


## 2 guards + 3 civilians always, plus guard_extra (2 slots) and civilian_extra (2 slots) picked 0 + difficulty_add.
func _scaled_map() -> PackedScene:
	var groups: Dictionary = {&"guard_extra": [&"g_a", &"g_b"], &"civilian_extra": [&"c_a", &"c_b"]}
	var table: HeistVariantTable = HeistVariantTable.new()
	table.rules = [
		{"group": &"guard_extra", "pick": Vector2i(0, 0), "difficulty_add": [0, 0, 0, 0, 0, 1]},
		{"group": &"civilian_extra", "pick": Vector2i(0, 0), "difficulty_add": [0, 0, 0, 0, 0, 1]},
	]
	var root: HeistMap = ATestMaps.basic(2, 3, groups, table).instantiate() as HeistMap
	var i: int = 0
	for vs: Node in root.get_node("Variants").get_children():
		var slot: VariantSlot = vs as VariantSlot
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = "Extra%d" % i
		sp.kind = SpawnPoint.Kind.GUARD if slot.slot_group == &"guard_extra" else SpawnPoint.Kind.CIVILIAN
		sp.position = Vector3(-8 + 4 * i, 0.05, 4)
		slot.get_node("Content").add_child(sp)
		sp.owner = root
		i += 1
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps
