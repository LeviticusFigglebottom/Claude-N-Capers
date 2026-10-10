## A3-01a / L4.4 Stinger (PD2 Taser): ~1 s audible windup, then the tase (TASED, no down): the victim
## cannot move, the weapon auto-fires at max RPM pulled 15 deg up with x3 spread and auto-reloads;
## broken by killing the Stinger or losing LOS; a long tase leaves the victim helpless until revived;
## Shockproof hooks; pairs retarget.
extends TestCase

const DEF: String = "res://systems/ai/data/enemies/stinger.tres"

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _claims: Array[Dictionary] = []


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	_claims.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(mates: int = 1) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4404, Enums.Difficulty.LETHAL, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": mates, "crew_ai": false, "skip_casing": true})
	_listen(EventBus.special_spawned, &"special")
	_listen(EventBus.audio_cue_requested, &"cue")
	_listen(EventBus.crew_tased, &"tased")
	for c: CrewController in _rt.crew_members():
		Modifiers.set_source(c.slot, &"test.immune", {&"defense.damage_taken_mult": 0.0})
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, _c: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _count_cue(id: StringName) -> int:
	var n: int = 0
	for e: Array in _events:
		if e[0] == &"cue" and e[1] == id:
			n += 1
	return n


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


## One Stinger 10 m in front of slot 0 (director path: spawn_npc + enemy_def picks npc_stinger.tscn);
## slot 1 parked 25 m away.
func _spawn_one(offset: Vector3 = Vector3(0, 0, -10)) -> NpcBase:
	if _rt.crew_members().size() > 1:
		_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(15, 0.05, 15)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, _crew(0).global_position + offset),
		{"enemy_def": load(DEF) as EnemyDef})
	return p


func _brain(p: NpcBase) -> StingerBrain:
	return p.get_node("Brain") as StingerBrain


func _tased(c: CrewController) -> bool:
	return c.crew_state == Enums.CrewState.TASED


func test_l4_4_def_scene_pairs() -> void:
	var def: EnemyDef = load(DEF) as EnemyDef
	assert_eq(def.id, &"enemy.stinger")
	assert_true(def.is_special, "special")
	assert_eq(def.health.size(), 6)
	assert_eq(def.damage.size(), 6)
	assert_eq(int(def.params.get("group_size", 1)), 2, "deploys in pairs")
	await _launch()
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"stinger",
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -15)))
	assert_eq(units.size(), 2, "spawn_special spawns the pair")
	for u: NpcBase in units:
		assert_eq(u.role, &"special")
		assert_true(u.get_node_or_null("Brain") is StingerBrain, "StingerBrain")
		assert_true(u.get_node_or_null("Gunner") is NpcGunner, "Gunner (rifle when not tasing)")
		assert_true(u.get_node_or_null("ArcBeam") is Node3D, "ArcBeam VFX node")
	assert_true(units[0].global_position.distance_to(units[1].global_position) > 1.0, "side by side")
	var single: NpcBase = _spawn_one()
	assert_true(single.get_node_or_null("Brain") is StingerBrain, "spawn_npc(any role, enemy_def) uses the def's scene")
	await wait_physics_frames(2)
	assert_has(_events, [&"special", single.net_id, &"stinger"], "special_spawned(net_id, stinger)")
	assert_eq(SpecialSpawner.alive_count(_rt, &"enemy.stinger"), 3, "alive_count")


func test_l4_4_windup_then_tase() -> void:
	await _launch()
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var c: CrewController = _crew(0)
	var winding: bool = await wait_until(func() -> bool: return b.mode == &"windup", 4.0)
	assert_true(winding, "windup in range with LOS (mode %s)" % b.mode)
	var t0: int = Time.get_ticks_msec()
	assert_eq(_count_cue(&"cue.stinger_windup"), 1, "cue.stinger_windup")
	assert_false(_tased(c), "not tased during the windup")
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 3.0)
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	assert_true(tased, "tased after the windup")
	assert_true(dt >= b.tweak.stinger_windup_s - 0.15, "~1 s windup (%.2f s)" % dt)
	assert_has(_events, [&"tased", 0, p.net_id], "crew_tased(slot, stinger)")
	assert_eq(c.health.downs_used, 0, "no down counted")
	assert_true(c.weapons.involuntary_fire, "involuntary fire on")
	assert_eq(b.mode, &"tase")
	var start: Vector3 = c.global_position
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	_rt.set_bot_intent(0, i)
	await wait_seconds(1.2)
	assert_true(c.global_position.distance_to(start) < 0.05, "victim cannot move")
	assert_true(_count_cue(&"cue.stinger_arc") >= 2, "cue.stinger_arc loops")
	assert_true((p.get_node("ArcBeam") as Node3D).visible, "arc beam visible")
	assert_false(b.wants_to_fire, "no rifle fire while tasing")


func test_l4_4_involuntary_fire() -> void:
	await _launch()
	var c: CrewController = _crew(0)
	c.weapons.fired.connect(func(claim: Dictionary) -> void: _claims.append(claim))
	var p: NpcBase = _spawn_one()
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 5.0)
	assert_true(tased, "tased")
	var ws: int = c.weapons.equipped_slot
	var st: WeaponStats = c.weapons.stats(ws)
	c.weapons.set_ammo(ws, 3, 60)
	_claims.clear()
	var before: int = c.weapons.shots_fired
	var fired: bool = await wait_until(func() -> bool: return c.weapons.shots_fired >= before + 3, 2.0)
	assert_true(fired, "weapon fires on its own while tased")
	var reloaded: bool = await wait_until(func() -> bool: return c.weapons.reloading, 2.0)
	assert_true(reloaded, "auto-reload when empty")
	assert_true(not _claims.is_empty(), "fired claims")
	if not _claims.is_empty():
		var d: Vector3 = _claims[0]["direction"]
		var pitch: float = rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
		assert_near(pitch, rad_to_deg(c.look_pitch) + _brain(p).tweak.stinger_pitch_up_deg, 1.0, "pulled 15 deg up")
	assert_near(c.weapons.involuntary_spread_mult, 3.0, 0.001, "spread x3")
	var full: bool = await wait_until(func() -> bool: return not c.weapons.reloading and c.weapons.mag(ws) > 0, 6.0)
	assert_true(full, "reload completes")
	var n0: int = c.weapons.shots_fired
	var t0: int = Time.get_ticks_msec()
	await wait_until(func() -> bool: return c.weapons.shots_fired >= n0 + 3, 3.0)
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var interval: float = 60.0 / st.fire_rate_rpm
	assert_true(dt <= interval * 3.0 + 0.25, "max RPM (%.2f s for 3 shots, interval %.2f)" % [dt, interval])


func test_l4_4_kill_breaks_tase() -> void:
	await _launch()
	var c: CrewController = _crew(0)
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 5.0)
	assert_true(tased, "tased")
	p.die({}, 0)
	await wait_physics_frames(1)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "killing the Stinger frees the victim")
	assert_false(c.weapons.involuntary_fire, "involuntary fire off")
	assert_eq(b.last_break_reason, &"killed")
	assert_true(c.weapons.can_fire(), "can fire again")


func test_l4_4_los_loss_breaks_tase() -> void:
	await _launch()
	var c: CrewController = _crew(0)
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 5.0)
	assert_true(tased, "tased")
	var mid: Vector3 = (c.global_position + p.global_position) * 0.5
	ATestMaps.add_wall(_rt.map, Vector3(mid.x, 1.5, mid.z), Vector3(6, 3, 0.4))
	var freed: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.NORMAL, 1.0)
	assert_true(freed, "LOS loss breaks the tase")
	assert_eq(b.last_break_reason, &"los")


func test_l4_4_long_tase_helpless_and_retarget() -> void:
	await _launch()
	var c: CrewController = _crew(0)
	var mate: CrewController = _crew(1)
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var tw: SpecialTweak = b.tweak.duplicate() as SpecialTweak
	tw.stinger_helpless_after_s = 1.5
	b.tweak = tw
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 5.0)
	assert_true(tased, "tased")
	var ended: bool = await wait_until(func() -> bool: return b.last_break_reason == &"helpless", 3.0)
	assert_true(ended, "long tase ends the beam")
	assert_eq(c.crew_state, Enums.CrewState.TASED, "victim stays helpless until revived")
	assert_false(c.weapons.involuntary_fire, "no more auto-fire")
	assert_eq(c.health.downs_used, 0, "downs silently: no down counted")
	var retarget: bool = await wait_until(func() -> bool: return b.combat_target == mate, 3.0)
	assert_true(retarget, "retargets the next standing crew member")
	c.health.revive(1)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "revive frees the helpless victim")


func test_l4_4_pair_takes_two_targets() -> void:
	await _launch()
	var c: CrewController = _crew(0)
	var mate: CrewController = _crew(1)
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, c.global_position + Vector3(3, 0, 0)))
	await wait_physics_frames(2)
	SpecialSpawner.spawn_special(_rt, &"stinger", Transform3D(Basis.IDENTITY, c.global_position + Vector3(1.5, 0, -10)))
	var both: bool = await wait_until(func() -> bool: return _tased(c) and _tased(mate), 6.0)
	assert_true(both, "the pair tases two different crew members")


func test_l4_4_shockproof_backfire() -> void:
	await _launch()
	Modifiers.set_source(0, &"test.shockproof", {&"defense.shockproof": {"backfire_chance": 1.0}})
	var c: CrewController = _crew(0)
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var done: bool = await wait_until(func() -> bool: return b.last_break_reason == &"backfire", 4.0)
	assert_true(done, "the tase backfires")
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "not tased")
	assert_true(p.is_stunned(), "Stinger knocked back")


func test_l4_4_shockproof_counter() -> void:
	await _launch()
	Modifiers.set_source(0, &"test.shockproof",
		{&"defense.shockproof": {"backfire_chance": 0.0, "can_interact_counter": true, "counter_window": 2.0}})
	var c: CrewController = _crew(0)
	var p: NpcBase = _spawn_one()
	var b: StingerBrain = _brain(p)
	var tased: bool = await wait_until(func() -> bool: return _tased(c), 5.0)
	assert_true(tased, "tased")
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	_rt.set_bot_intent(0, i)
	var freed: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.NORMAL, 1.0)
	assert_true(freed, "interact within the window shocks back")
	assert_eq(b.last_break_reason, &"counter")
	assert_true(p.is_stunned(), "Stinger knocked back")
