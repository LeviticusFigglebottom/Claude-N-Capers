## PP-A-2 (D-082): guard domination per D-079 by a real player. The crew walks up by input, masks by
## input, waits for the guard's "!" and shouts by input; the guard kneels and cuffs himself (S5.8) and
## counts as a hostage. No teleports, no bot intents, no state writes after launch. The only setup is the
## map (spawn poses) and the domination skill in the crew's modifiers, like a loadout would give.
extends TestCase

const GUARD_POS: Vector3 = Vector3(0, 0.05, -4)
const CREW_POS: Vector3 = Vector3(0, 0.05, 9)

var _rt: HeistRuntime = null
var _inp: PlayerInputDriver = null
var _events: Array = []
var _conns: Array[Array] = []


func before_each() -> void:
	Modifiers.clear_all()
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_map", 58, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _facing_map(), "crew_ai": false})
	_inp = PlayerInputDriver.new(self)
	await wait_physics_frames(2)
	for pair: Array in [[EventBus.guard_dominated, &"dominated"], [EventBus.hostage_count_changed, &"hostages"]]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null) -> void: _events.append([tag, a, b])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])


func after_each() -> void:
	_inp.release_all()
	for c: Array in _conns:
		if (c[0] as Signal).is_connected(c[1]):
			(c[0] as Signal).disconnect(c[1])
	_conns.clear()
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## basic(1, 0) with the guard facing +Z and player 0 13 m in front of him, facing him (-Z).
static func _facing_map() -> PackedScene:
	var root: Node = ATestMaps.basic(1, 0).instantiate()
	for sp: Node in root.get_node("Spawns").get_children():
		var s: SpawnPoint = sp as SpawnPoint
		if s == null:
			continue
		if s.kind == SpawnPoint.Kind.GUARD:
			s.transform = Transform3D(Basis(Vector3.UP, PI), GUARD_POS)
		elif s.kind == SpawnPoint.Kind.PLAYER and s.name.ends_with("0"):
			s.transform = Transform3D(Basis.IDENTITY, CREW_POS)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _of(tag: StringName) -> Array:
	return _events.filter(func(e: Array) -> bool: return e[0] == tag)


func test_pp_a2_real_shout_dominates_guard_to_hostage() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var brain: GuardBrain = g.get_node("Brain") as GuardBrain
	assert_false(c.is_ai, "slot 0 is the local player")
	assert_true(c.global_position.distance_to(g.global_position) > 12.0, "starts out of domination range")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	assert_true(await wait_until(func() -> bool: return c.masked, 1.0), "masked by holding mask_up")
	var tw: StealthTweak = Tweak.stealth()
	var near_m: float = minf(6.0, ShoutSystem.guard_dominate_range_for(c) - 1.0)
	var arrived: bool = await _inp.walk_until(&"move_forward",
		func() -> bool: return c.global_position.distance_to(g.global_position) <= near_m \
			or brain.dominate_window_left > 0.0, 6.0)
	assert_true(arrived, "walked up to the guard by input (%.1f m)" % c.global_position.distance_to(g.global_position))
	var spotted: bool = await _inp.until(func() -> bool: return brain.dominate_window_left > 0.0, 8.0)
	assert_true(spotted, "the guard spots the masked crew (\"!\", window open)")
	if not spotted:
		return
	var d: float = c.global_position.distance_to(g.global_position)
	var to: Vector3 = g.global_position + Vector3(0, 1.2, 0) - c.eye_position()
	var ang: float = rad_to_deg(c.aim_direction().angle_to(to))
	assert_true(d <= ShoutSystem.guard_dominate_range_for(c), "D-079 range %.1f m <= %.1f m" % [d,
		ShoutSystem.guard_dominate_range_for(c)])
	assert_true(ang <= ShoutSystem.guard_dominate_cone_half_deg(to.length()), "D-079 cone %.1f deg" % ang)
	assert_true(ShoutSystem.ensure(_rt).guard_target_for(c) == g, "the guard is the shout target")
	await _inp.tap(&"shout")
	var ok: bool = await wait_until(func() -> bool: return g.alert_state == Enums.AlertState.DOMINATED, 1.0)
	assert_true(ok, "one real shout in the window dominates (%s)" % Enums.AlertState.keys()[g.alert_state])
	assert_true(await wait_until(func() -> bool: return brain.anim_hint == &"kneel_cuffed", 2.0),
		"he kneels and cuffs himself (%s)" % brain.anim_hint)
	var dom: Array = _of(&"dominated")
	assert_eq(dom.size(), 1, "guard_dominated once")
	if not dom.is_empty():
		assert_eq(dom[0][1], g.net_id)
		assert_eq(dom[0][2], 0, "by slot 0")
	assert_true(g.is_in_group(G.HOSTAGE), "the dominated guard counts as a hostage")
	var hc: Array = _of(&"hostages")
	assert_true(not hc.is_empty() and int(hc[-1][1]) >= 1, "hostage count rose (%s)" % str(hc))
	assert_true(_rt.stealth.is_stealth(), "still stealth (radio call cancelled)")
	assert_true(tw.guard_dominate_window_s > 0.0)


## Control: the same real approach and shout without stealth.can_dominate_guards does not dominate.
func test_pp_a2_real_shout_without_skill_does_nothing() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var brain: GuardBrain = g.get_node("Brain") as GuardBrain
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await _inp.walk_until(&"move_forward", func() -> bool: return c.global_position.distance_to(g.global_position) <= 6.0 \
		or brain.dominate_window_left > 0.0, 6.0)
	await _inp.until(func() -> bool: return brain.dominate_window_left > 0.0 or brain.state_name() == &"alarmed", 8.0)
	await _inp.tap(&"shout")
	await wait_physics_frames(10)
	assert_ne(g.alert_state, Enums.AlertState.DOMINATED, "no skill: not dominated")
	assert_true(_of(&"dominated").is_empty(), "no guard_dominated")
