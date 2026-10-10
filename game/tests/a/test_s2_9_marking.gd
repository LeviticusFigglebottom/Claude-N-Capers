## A2-05 / S2.9: shouting while aiming at a guard, special or camera marks it for the whole crew
## (4.5 s guards, 8 s cameras, x stealth.mark_duration_mult); a shout that intimidates a civilian
## does not mark; StealthDirector.marked_targets(slot) feeds LocalHudModel; Sixth Sense
## (stealth.sixth_sense) marks enemies within 10 m after standing still 3.5 s in stealth.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(civilians: int = 0) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 5, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, civilians), "crew_ai": false})
	await wait_physics_frames(2)


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


## Place crew 0 at `pos`, masked unless `casing`, looking at `at`.
func _aim_from(pos: Vector3, at: Vector3, casing: bool = false) -> CrewIntent:
	if not casing:
		_crew().set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(1)
	var d: Vector3 = at - _crew().eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	return i


func _shout(i: CrewIntent) -> void:
	var s: CrewIntent = CrewIntent.from_dict(i.to_dict())
	s.shout = true
	_rt.set_bot_intent(0, s)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(1)


func _marked_ids(slot: int = 0) -> Array[int]:
	var out: Array[int] = []
	for m: Dictionary in _rt.stealth.marked_targets(slot):
		out.append(int(m["net_id"]))
	return out


func test_s2_9_shout_marks_guard_for_crew_4_5_s() -> void:
	await _launch()
	var g: NpcBase = _guard()
	var i: CrewIntent = await _aim_from(g.global_position + Vector3(0, 0.05, 8.0), g.global_position + Vector3(0, 1.2, 0))
	assert_true(_rt.stealth.marked_targets(0).is_empty())
	await _shout(i)
	var rows: Array[Dictionary] = _rt.stealth.marked_targets(0)
	assert_eq(rows.size(), 1, "guard marked")
	assert_eq(int(rows[0]["net_id"]), g.net_id)
	assert_eq(rows[0]["kind"], &"guard", "kind is a StringName (ui_hud.md v1.1)")
	assert_true((rows[0]["world_pos"] as Vector3).distance_to(g.global_position) < 0.01, "world_pos = target position")
	assert_eq(_marked_ids(2), [g.net_id] as Array[int], "visible to the whole crew")
	assert_true(_rt.stealth.is_marked(g))
	await wait_seconds(0.5)
	var hud: Array = _rt.hud_model.marked_targets
	assert_eq(hud.size(), 1, "LocalHudModel shows the mark")
	await wait_seconds(Tweak.stealth().mark_duration_guard_s - 1.2)
	assert_eq(_marked_ids().size(), 1, "still marked before 4.5 s")
	await wait_seconds(1.0)
	assert_true(_marked_ids().is_empty(), "expired after 4.5 s")


func test_s2_9_mark_duration_mult() -> void:
	await _launch()
	Modifiers.set_source(0, &"test.price_tag", {&"stealth.mark_duration_mult": 2.0})
	var g: NpcBase = _guard()
	var i: CrewIntent = await _aim_from(g.global_position + Vector3(0, 0.05, 8.0), g.global_position + Vector3(0, 1.2, 0))
	await _shout(i)
	await wait_seconds(Tweak.stealth().mark_duration_guard_s + 1.0)
	assert_eq(_marked_ids(), [g.net_id] as Array[int], "x2 duration: still marked at 5.5 s")


func test_s2_9_not_aiming_or_casing_does_not_mark() -> void:
	await _launch()
	var g: NpcBase = _guard()
	var i: CrewIntent = await _aim_from(g.global_position + Vector3(0, 0.05, 8.0), g.global_position + Vector3(6, 1.2, 0))
	await _shout(i)
	assert_true(_marked_ids().is_empty(), "aim far off the guard: no mark")
	_rt.teardown()
	await wait_frames(1)
	await _launch()
	g = _guard()
	i = await _aim_from(g.global_position + Vector3(0, 0.05, 8.0), g.global_position + Vector3(0, 1.2, 0), true)
	await _shout(i)
	assert_true(_marked_ids().is_empty(), "casing: no mark without stealth.casing_can_mark")
	Modifiers.set_source(0, &"test.casing", {&"stealth.casing_can_mark": true})
	await wait_seconds(Tweak.stealth().shout_cooldown_s + 0.1)
	await _shout(i)
	assert_eq(_marked_ids(), [g.net_id] as Array[int], "casing_can_mark: marks while casing")


func test_s2_9_dead_guard_mark_drops() -> void:
	await _launch()
	var g: NpcBase = _guard()
	var i: CrewIntent = await _aim_from(g.global_position + Vector3(0, 0.05, 8.0), g.global_position + Vector3(0, 1.2, 0))
	await _shout(i)
	assert_eq(_marked_ids().size(), 1)
	g.die()
	await wait_physics_frames(2)
	assert_true(_marked_ids().is_empty(), "a dead guard is no longer marked")


func test_s2_9_camera_marked_8_s() -> void:
	await _launch()
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", Vector3(-6.0, 2.6, -8.0)) as SecurityCamera
	await wait_physics_frames(2)
	_rt.isolate_npc(null)
	await wait_physics_frames(1)
	var i: CrewIntent = await _aim_from(Vector3(-6.0, 0.05, 2.0), cam.eye_position())
	await _shout(i)
	var rows: Array[Dictionary] = _rt.stealth.marked_targets(0)
	assert_eq(rows.size(), 1, "camera marked")
	assert_eq(int(rows[0]["net_id"]), cam.net_id)
	assert_eq(rows[0]["kind"], &"camera")
	await wait_seconds(Tweak.stealth().mark_duration_guard_s + 1.0)
	assert_eq(_marked_ids().size(), 1, "cameras stay marked longer than guards")
	await wait_seconds(Tweak.stealth().mark_duration_camera_s - Tweak.stealth().mark_duration_guard_s)
	assert_true(_marked_ids().is_empty(), "camera mark expired after 8 s")


func test_s2_9_shout_at_civilian_intimidates_without_marking() -> void:
	await _launch(1)
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var g: NpcBase = _guard()
	# Civilian within shout_all_within_m (any direction) while aiming at the guard.
	var i: CrewIntent = await _aim_from(civ.global_position + Vector3(0, 0.05, 3.0), g.global_position + Vector3(0, 1.2, 0))
	var affected: Array[Node] = []
	(_rt.service(ShoutSystem.SERVICE) as ShoutSystem).shouted.connect(func(_s: int, a: Array[Node]) -> void: affected.assign(a))
	await _shout(i)
	assert_has(affected, civ, "civilian intimidated (S7.1)")
	assert_true(_marked_ids().is_empty(), "no mark when a civilian was affected")


func test_s2_9_sixth_sense_marks_enemies_within_10_m_when_still() -> void:
	await _launch()
	var near: NpcBase = _guard()
	var far: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, near.global_position + Vector3(0, 0, -15.0)))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, near.global_position + Vector3(0, 0.05, 8.0)))
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_seconds(Tweak.stealth().sixth_sense_still_s + 0.5)
	assert_true(_marked_ids().is_empty(), "no Sixth Sense without the skill")
	Modifiers.set_source(0, &"test.gut_feeling", {&"stealth.sixth_sense": true})
	await wait_seconds(Tweak.stealth().sixth_sense_still_s - 0.5)
	assert_true(_marked_ids().is_empty(), "not before 3.5 s still")
	await wait_seconds(1.0)
	assert_eq(_marked_ids(), [near.net_id] as Array[int], "guard within 10 m marked, the one at 23 m not")
	assert_false(_rt.stealth.is_marked(far))
