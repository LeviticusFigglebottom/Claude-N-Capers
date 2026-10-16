## X-5 (heist_completion.md): tellers and desk staff pushed off their activity marks stayed displaced (a crew yield
## brings them back only within the motor's arrive distance, 0.4 m, past the 0.3 m hold window; a drift while
## alerted). Now a mark-bound CALM IDLE civilian (CivilianBrain.mark_bound: not a wander activity) goes back once it
## stands still for civilian_mark_return_s: near, it slides onto the mark (NpcMotor.mark_anchor), farther it walks
## there first, and it faces its spawn facing again. Wanderers keep their own spot; a panicked one runs as before.
extends TestCase

const MARK: Vector3 = Vector3(4.0, 0.05, 4.0)

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _civ(activity: StringName, pos: Vector3 = MARK, yaw: float = PI * 0.5) -> NpcBase:
	if _rt == null:
		_rt = await HeistLauncher.launch(&"unit_x5_mark", 11, Enums.Difficulty.ROUTINE, self,
			{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis(Vector3.UP, yaw), pos), {"idle_activity": activity})
	await wait_physics_frames(5)
	return civ


func _facing(n: Node3D) -> Vector3:
	var f: Vector3 = -n.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func test_x5_teller_slides_back_after_a_small_push() -> void:
	var civ: NpcBase = await _civ(&"teller")
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	var face0: Vector3 = _facing(civ)
	assert_true(b.mark_bound() and b.on_mark() and m.holding(), "the teller is held on its mark")
	civ.global_position += Vector3(0.5, 0.0, 0.3)  # shoved 0.58 m off (past the 0.3 m hold window)
	civ.rotation.y += 1.2
	await wait_physics_frames(2)
	assert_false(b.on_mark(), "pushed off its mark")
	await wait_seconds(Tweak.stealth().civilian_mark_return_s + 1.5)
	var d: float = _flat(civ.global_position, MARK)
	print("X-5 teller small push: back at %s (%.3f m), facing dot %.3f" % [civ.global_position, d, _facing(civ).dot(face0)])
	assert_true(d <= 0.02, "the teller is back on its mark (%.3f m)" % d)
	assert_true(b.on_mark() and m.holding(), "held there again")
	assert_true(_facing(civ).dot(face0) > 0.97, "facing its counter again")
	assert_eq(b.anim_hint, &"teller", "back to its activity")


func test_x5_desk_clerk_walks_back_after_a_big_push() -> void:
	var civ: NpcBase = await _civ(&"desk_work")
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	assert_eq(b.anim_hint, &"teller", "no seat here: desk_work stands (PO6-06)")
	civ.global_position += Vector3(-2.5, 0.0, 0.0)
	await wait_seconds(Tweak.stealth().civilian_mark_return_s + 0.4)
	assert_eq(b.anim_hint, &"walk", "walking back to its mark")
	var back: bool = await wait_until(func() -> bool: return _flat(civ.global_position, MARK) <= 0.02, 6.0)
	print("X-5 clerk big push: back %s at %s" % [back, civ.global_position])
	assert_true(back, "the clerk walked back onto its mark (at %s)" % civ.global_position)
	await wait_physics_frames(2)
	assert_true(b.on_mark(), "held on it")
	assert_eq(b.anim_hint, &"teller", "back to its (standing) activity")


func test_x5_mark_returns_after_a_crew_yield() -> void:
	var civ: NpcBase = await _civ(&"teller")
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	# A PO-5 yield: the motor steps aside, then goes "home" and stops within arrive_distance (0.4 m) of it.
	m._yield_point = MARK + Vector3(1.0, 0.0, 0.0)
	m._yield_home = MARK
	await wait_seconds(1.2)
	assert_true(_flat(civ.global_position, MARK) > 0.6, "stepped aside")
	m._yield_point = Vector3.INF
	m._yield_home = Vector3.INF
	m.go_to(MARK + Vector3(0.38, 0.0, 0.0), Tweak.stealth().npc_yield_speed)  # the yield's return, 0.38 m short
	var back: bool = await wait_until(func() -> bool: return _flat(civ.global_position, MARK) <= 0.02, 6.0)
	assert_true(back, "back on the exact mark after the yield (at %s)" % civ.global_position)
	assert_true(b.on_mark(), "held")


func test_x5_wanderer_and_panicked_are_not_pulled_back() -> void:
	var w: NpcBase = await _civ(&"browse", Vector3(-4, 0.05, 4))
	var wb: CivilianBrain = w.get_node(^"Brain") as CivilianBrain
	assert_false(wb.mark_bound(), "a browsing customer wanders: no permanent mark")
	var p0: Vector3 = w.global_position + Vector3(1.5, 0.0, 0.0)
	w.global_position = p0
	await wait_seconds(2.5)
	if wb.mode == CivilianBrain.Mode.IDLE:
		assert_true(_flat(w.global_position, p0) < 0.3, "a wanderer keeps the spot it stands on")
	var t: NpcBase = await _civ(&"teller", Vector3(4, 0.05, -4))
	var tb: CivilianBrain = t.get_node(^"Brain") as CivilianBrain
	tb._panic(Vector3(2, 0, -4))
	await wait_seconds(Tweak.stealth().civilian_mark_return_s + 1.0)
	assert_true(_flat(t.global_position, Vector3(4, 0.05, -4)) > 0.5, "a panicked teller runs, not back to its mark")
	assert_false(tb.on_mark(), "not held while panicked")
