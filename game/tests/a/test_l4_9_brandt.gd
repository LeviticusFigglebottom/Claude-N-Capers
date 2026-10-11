## A3-02 L4.9 Commander Brandt + Aegis squad: arrival on eligible difficulty (also solo, D-015),
## resistance stacking (10% +5%/5 s up to 50%), per-hit cap (10% max HP, x6 explosives), cannot be
## killed, retreat at 20% HP or ~3 shields, assault lock (no FADE while he is on the map), "in position"
## as a real destination (tagged / defensive TacticalPoint, squad formation, timeout fallback).
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	tw.assault_groups = []
	tw.control_special_groups = []
	tw.captain_settle_s = 0.2
	tw.captain_position_timeout_s = 0.2  # the destination walk has its own tests
	tw.aegis_resist_step_s = 0.5
	tw.captain_despawn_s = 0.0
	return tw


func _launch(tw: DirectorTweak, difficulty: Enums.Difficulty = Enums.Difficulty.HAZARDOUS, options: Dictionary = {}) -> HeistRuntime:
	options["ai_teammates"] = 0
	options["director_tweak"] = tw
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1491, difficulty, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


## Loud + CONTROL, then Brandt summoned directly.
func _summoned(tw: DirectorTweak) -> AegisCaptain:
	await _launch(tw)
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_true(d.captain.summon(), "Brandt summoned")
	return d.captain


func _hit(npc: NpcBase, amount: float, type: int = Enums.DamageType.BULLET) -> float:
	var info: Dictionary = Damage.info(amount, type, Enums.HitZone.BODY, &"weapon.test", npc.global_position,
		Vector3.FORWARD)
	return float(npc.take_hit(info, 0).get("amount", 0.0))


func test_l4_9_eligibility() -> void:
	await _launch(_tweak(), Enums.Difficulty.TENSE)
	assert_false(_director().captain.eligible(), "Tense: no captain")
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	await _launch(_tweak(), Enums.Difficulty.HAZARDOUS)
	assert_eq(_rt.crew_members().size(), 1, "solo run")
	assert_true(_director().captain.eligible(), "Hazardous solo: eligible (D-015)")


func test_l4_9_arrives_during_assault_on_eligible_difficulty() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 0.5
	tw.anticipation_s = 0.5
	tw.build_s = 30.0
	tw.captain_min_wave = 1
	tw.captain_chance = 1.0
	tw.captain_delay_s = 1.0
	await _launch(tw)
	var d: AssaultDirector = _director()
	var arrived: Array[int] = []
	var cues: Array[StringName] = []
	var on_arrive: Callable = func(id: int) -> void: arrived.append(id)
	var on_cue: Callable = func(cue: StringName, _p: Vector3, _s: int) -> void: cues.append(cue)
	EventBus.captain_arrived.connect(on_arrive)
	EventBus.audio_cue_requested.connect(on_cue)
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return not arrived.is_empty(), 10.0)
	EventBus.captain_arrived.disconnect(on_arrive)
	EventBus.audio_cue_requested.disconnect(on_cue)
	assert_true(ok, "captain_arrived during the assault")
	assert_eq(d.assault_phase, Enums.AssaultPhase.BUILD, "arrived in BUILD")
	var c: AegisCaptain = d.captain
	assert_true(c.active and is_instance_valid(c.brandt), "Brandt on the map")
	if not is_instance_valid(c.brandt):
		return
	assert_eq(arrived[0], c.brandt.net_id, "event carries his net id")
	assert_eq(c.brandt.enemy_def.id, &"enemy.brandt", "Brandt EnemyDef")
	assert_eq(c.alive_shields(), tw.aegis_shields, "10 Aegis shields")
	assert_has(cues, AegisCaptain.CUE_ARRIVAL, "cue.brandt_arrival")
	assert_true(d.captain_active(), "assault locked")
	_rt.hud_model.refresh()
	assert_has(_rt.hud_model.warnings, LocalHudModel.WARNING_CAPTAIN, "HUD warning")
	assert_false(c.summon(), "only once per heist day")


func test_l4_9_never_on_low_difficulty() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 0.5
	tw.anticipation_s = 0.5
	tw.build_s = 3.0
	tw.captain_min_wave = 1
	tw.captain_chance = 1.0
	tw.captain_delay_s = 0.5
	await _launch(tw, Enums.Difficulty.ROUTINE)
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_seconds(3.0)
	assert_false(d.captain.spawned_today, "no Brandt on Routine")


func test_l4_9_resistance_stacks_to_50_percent() -> void:
	var tw: DirectorTweak = _tweak()
	var c: AegisCaptain = await _summoned(tw)
	var d: AssaultDirector = _director()
	assert_near(d.aegis_resistance(), 0.0, 0.0001, "not in position yet")
	var pulses: Array[int] = [0]
	var on_cue: Callable = func(cue: StringName, _p: Vector3, _s: int) -> void:
		if cue == AegisCaptain.CUE_PULSE:
			pulses[0] += 1
	EventBus.audio_cue_requested.connect(on_cue)
	var ok: bool = await wait_until(func() -> bool: return c.in_position, 2.0)
	assert_true(ok, "in position")
	assert_near(d.aegis_resistance(), 0.10, 0.001, "+10% on arrival in position")
	await wait_until(func() -> bool: return d.aegis_resistance() > 0.11, 2.0)
	assert_near(d.aegis_resistance(), 0.15, 0.001, "+5% after one step")
	await wait_seconds(6.0)
	EventBus.audio_cue_requested.disconnect(on_cue)
	assert_near(d.aegis_resistance(), 0.50, 0.001, "capped at 50%")
	assert_true(pulses[0] >= 9, "cue.aegis_pulse on every step (%d)" % pulses[0])
	# Every enemy takes less damage.
	var pts: Array[Node3D] = d.valid_spawn_points()
	var cop: NpcBase = d.spawn_enemy(load("res://systems/ai/data/enemies/tac_light.tres") as EnemyDef,
		pts[0].global_transform, pts[0])
	assert_near(_hit(cop, 20.0), 10.0, 0.01, "TAC Light takes 50% less")


func test_l4_9_per_hit_cap_and_cannot_be_killed() -> void:
	var tw: DirectorTweak = _tweak()
	tw.captain_retreat_hp_frac = 0.0  # isolate the cap from the retreat rule
	tw.captain_retreat_shields = -1
	var c: AegisCaptain = await _summoned(tw)
	var b: NpcBase = c.brandt
	var mx: float = b.max_health
	assert_near(_hit(b, 100000.0), 0.1 * mx, 0.01, "bullet capped at 10% max HP")
	assert_near(_hit(b, 100000.0, Enums.DamageType.EXPLOSION), 0.6 * mx, 0.01, "explosive cap x6")
	assert_near(_hit(b, 10.0), 10.0, 0.01, "small hits pass (no resistance yet)")
	for i: int in range(20):
		_hit(b, 100000.0, Enums.DamageType.EXPLOSION)
	assert_true(b.alive and b.health >= 1.0, "cannot be killed (%.1f HP)" % b.health)
	var s: NpcBase = c.shields[0]
	assert_near(_hit(s, 100000.0), 0.1 * s.max_health, 0.01, "shields capped at 10% too")
	assert_true(AegisCaptain.is_aegis_unit(s), "shield flagged aegis")


func test_l4_9_retreat_at_20_percent_hp() -> void:
	var c: AegisCaptain = await _summoned(_tweak())
	var d: AssaultDirector = _director()
	var b: NpcBase = c.brandt
	var retreated: Array[int] = []
	var cb: Callable = func(id: int) -> void: retreated.append(id)
	EventBus.captain_retreated.connect(cb)
	var hits: int = 0
	while c.active and hits < 50:
		_hit(b, 100000.0)
		hits += 1
	EventBus.captain_retreated.disconnect(cb)
	assert_eq(hits, 8, "eight capped hits take him to 20%")
	assert_false(c.active, "retreated")
	assert_eq(c.retreat_reason, AegisCaptain.RETREAT_HP, "reason hp")
	assert_eq(retreated, [b.net_id], "captain_retreated once with his id")
	assert_true(b.health > 0.0, "he was never killed")
	assert_near(d.aegis_resistance(), 0.0, 0.0001, "resistance gone")
	assert_false(d.captain_active(), "assault unlocked")
	_rt.hud_model.refresh()
	assert_false(_rt.hud_model.warnings.has(LocalHudModel.WARNING_CAPTAIN), "HUD warning cleared")


func test_l4_9_retreat_when_formation_drops() -> void:
	var c: AegisCaptain = await _summoned(_tweak())
	var shields: Array[NpcBase] = c.shields.duplicate()
	var killed: int = 0
	for s: NpcBase in shields:
		if not c.active:
			break
		s.die()
		killed += 1
	assert_false(c.active, "retreated")
	assert_eq(c.retreat_reason, AegisCaptain.RETREAT_FORMATION, "reason formation")
	assert_eq(killed, shields.size() - 3, "retreats when 3 shields remain")
	for s: NpcBase in shields:
		if s.alive:
			assert_false(AegisCaptain.is_aegis_unit(s), "remaining shields break up")


func test_l4_9_assault_locked_while_present() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 0.5
	tw.anticipation_s = 0.5
	tw.build_s = 0.5
	tw.sustain_by_stage_s = PackedFloat32Array([0.5, 0.5, 0.5])
	tw.fade_wait_cap_s = 0.5
	tw.fade_threshold = PackedInt32Array([100, 100, 100, 100, 100, 100])  # would fade at once
	tw.captain_min_wave = 1
	tw.captain_chance = 1.0
	tw.captain_delay_s = 0.1
	await _launch(tw)
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return d.captain_active(), 5.0)
	assert_true(ok, "Brandt arrived")
	await wait_seconds(3.0)
	assert_eq(d.assault_phase, Enums.AssaultPhase.SUSTAIN, "no FADE while Brandt is on the map")
	d.captain.retreat(&"test")
	ok = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.FADE, 3.0)
	assert_true(ok, "the assault resumes and fades after he retreats")


## A TacticalPoint tagged captain_position near the crew is the squad's destination: Brandt and his
## shields walk there (formation slots), resistance only starts once he arrives.
func test_l4_9_moves_to_a_defensive_point_before_stacking() -> void:
	var tw: DirectorTweak = _tweak()
	tw.captain_position_timeout_s = 100.0
	tw.aegis_shields = 4
	tw.captain_retreat_shields = -1
	await _launch(tw)
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var spawn: Vector3 = d.valid_spawn_points()[0].global_position
	var crew: Vector3 = _rt.crew_members()[0].global_position
	var tp: TacticalPoint = TacticalPoint.new()
	tp.name = "BrandtHold"
	tp.kind = TacticalPoint.Kind.COVER
	tp.tags = [tw.captain_position_tag] as Array[StringName]
	_rt.map.add_child(tp)
	var dir: Vector3 = Vector3(crew.x - spawn.x, 0.0, crew.z - spawn.z)
	tp.global_position = Vector3(spawn.x, crew.y, spawn.z) + dir.normalized().cross(Vector3.UP) * 3.0  # beside the spawn
	var c: AegisCaptain = d.captain
	assert_true(c.summon(), "Brandt summoned")
	assert_eq(c.position_point, tp, "the tagged point is the destination")
	var bb: PoliceBrain = c.brandt.get_node("Brain") as PoliceBrain
	assert_true(bb.has_order() and bb.order_position.distance_to(tp.global_position) < 0.01, "Brandt ordered there")
	for i: int in range(c.shields.size()):
		var sb: PoliceBrain = c.shields[i].get_node("Brain") as PoliceBrain
		assert_true(sb.order_position.distance_to(c.formation_slot(i, c.shields.size())) < 0.01, "shield %d in formation" % i)
	await wait_physics_frames(5)
	assert_false(c.in_position, "not in position before arriving")
	assert_near(d.aegis_resistance(), 0.0, 0.0001, "no resistance on the way")
	var ok: bool = await wait_until(func() -> bool: return c.in_position, 15.0)
	assert_true(ok, "arrives (at %s, spawn %s, point %s, mode %s, alert %d, motor %s)" % [c.brandt.global_position, spawn, tp.global_position,
		bb.mode, c.brandt.alert_state, (c.brandt.get_node("Motor") as NpcMotor).target])
	assert_true(c.reached_destination, "in position by arrival, not the timeout")
	assert_true(AegisCaptain.flat_dist(c.brandt.global_position, tp.global_position) <= tw.captain_position_arrive_m + 0.05,
		"Brandt at the point")
	assert_near(d.aegis_resistance(), 0.10, 0.001, "stacking starts on arrival")
	c.retreat(&"test")
	assert_false(bb.has_order(), "orders cleared on retreat")


func test_l4_9_destination_choice_and_timeout_fallback() -> void:
	var tw: DirectorTweak = _tweak()
	tw.captain_position_timeout_s = 0.5
	tw.captain_retreat_shields = -1
	await _launch(tw)
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var c: AegisCaptain = d.captain
	var crew: Vector3 = _rt.crew_members()[0].global_position
	# Untagged: the COVER / SHIELD_ANCHOR point whose distance to the crew is closest to pref_m.
	var picked: TacticalPoint = c.pick_position()
	if picked != null:
		var dd: float = AegisCaptain.flat_dist(picked.global_position, crew)
		assert_true(dd >= tw.captain_position_min_m and dd <= tw.captain_position_max_m, "in the band (%.1f m)" % dd)
	# A far tagged point: he never gets there in time, the timeout puts him in position anyway.
	var tp: TacticalPoint = TacticalPoint.new()
	tp.kind = TacticalPoint.Kind.SHIELD_ANCHOR
	tp.tags = [tw.captain_position_tag] as Array[StringName]
	_rt.map.add_child(tp)
	tp.global_position = crew + Vector3(0, 0, 60)
	assert_eq(c.pick_position(), tp, "a tagged point wins")
	assert_true(c.summon())
	var ok: bool = await wait_until(func() -> bool: return c.in_position, 3.0)
	assert_true(ok, "timeout fallback")
	assert_false(c.reached_destination, "not by arrival")


## ui_hud v1.3 (D-049): LocalHudModel captain_present / captain_resistance + captain_changed, assigned
## and emitted only on change; the server value comes from HeistNetSync.captain_state().
func test_l4_9_hud_captain_changed() -> void:
	var tw: DirectorTweak = _tweak()
	tw.aegis_resist_step_s = 100.0  # one value while in position
	var c: AegisCaptain = await _summoned(tw)
	var hud: LocalHudModel = _rt.hud_model
	var fired: Array[int] = [0]
	var cb: Callable = func() -> void: fired[0] += 1
	hud.captain_changed.connect(cb)
	hud.refresh()
	assert_true(hud.captain_present, "present on arrival")
	assert_near(hud.captain_resistance, 0.0, 0.0001, "no resistance before in position")
	var ok: bool = await wait_until(func() -> bool: return c.in_position, 2.0)
	assert_true(ok, "in position")
	hud.refresh()
	assert_near(hud.captain_resistance, 0.10, 0.001, "server resistance mirrored")
	var st: Dictionary = _rt.net_sync.captain_state()
	assert_true(bool(st["present"]), "net state present")
	assert_near(float(st["resistance"]), 0.10, 0.001, "net state resistance")
	assert_true(_rt.net_sync.services_state().has(HeistNetSync.SVC_CAPTAIN), "replicated in services")
	var n: int = fired[0]
	assert_true(n >= 1, "captain_changed fired")
	hud.refresh()
	hud.refresh()
	assert_eq(fired[0], n, "no signal without a change")
	c.retreat(&"test")
	hud.refresh()
	assert_false(hud.captain_present, "gone after the retreat")
	assert_near(hud.captain_resistance, 0.0, 0.0001, "resistance 0 when absent")
	assert_eq(fired[0], n + 1, "one captain_changed for both properties")
	hud.captain_changed.disconnect(cb)
	assert_true(hud.snapshot().has(&"captain_resistance"), "in snapshot()")
