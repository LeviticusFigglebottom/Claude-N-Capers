## A3-03 L1.2 drama: rises with crew damage, downs and nearby combat, decays 0.05/s, scales the
## BUILD/SUSTAIN spawn rate by (1 - 0.5 drama), and FADE comes after drama < 0.2 for the window.
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(options: Dictionary = {}) -> HeistRuntime:
	options["ai_teammates"] = 0
	options["captain"] = false
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1201, Enums.Difficulty.ROUTINE, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	return tw


func test_l1_2_damage_downs_and_nearby_combat_raise_drama() -> void:
	var tw: DirectorTweak = _tweak()
	tw.drama_decay_per_s = 0.0
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_true(d.running, "director running")
	assert_near(d.drama, 0.0, 0.001, "starts calm")
	var crew: CrewController = _rt.crew_members()[0]
	EventBus.damage_applied.emit(crew.net_id, 0, {"amount": 50.0})
	assert_near(d.drama, 50.0 * tw.drama_per_damage, 0.001, "crew damage adds drama")
	var before: float = d.drama
	EventBus.damage_applied.emit(crew.net_id, 0, {"amount": 0.0})
	assert_near(d.drama, before, 0.0001, "a fully absorbed hit adds nothing")
	EventBus.crew_downed.emit(crew.slot, 1)
	assert_near(d.drama, before + tw.drama_per_down, 0.001, "a down adds drama")
	before = d.drama
	EventBus.weapon_fired.emit(0, &"weapon.npc_rifle", false, crew.global_position + Vector3(3, 0, 0))
	assert_near(d.drama, before + tw.drama_per_nearby_shot, 0.0001, "a shot near the crew adds drama")
	before = d.drama
	EventBus.weapon_fired.emit(0, &"weapon.npc_rifle", false, crew.global_position + Vector3(200, 0, 0))
	assert_near(d.drama, before, 0.0001, "a far shot adds nothing")
	d.add_drama(5.0)
	assert_near(d.drama, 1.0, 0.0001, "drama clamps at 1")


func test_l1_2_decays_005_per_second() -> void:
	await _launch({"director_tweak": _tweak()})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	d.drama = 0.8
	var f0: int = Engine.get_physics_frames()
	await wait_physics_frames(Engine.physics_ticks_per_second * 2)
	var secs: float = float(Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second)
	assert_near(d.drama, 0.8 - 0.05 * secs, 0.01, "decays 0.05/s (%.3f after %.2f s)" % [d.drama, secs])


func test_l1_2_spawn_rate_scale() -> void:
	await _launch({"director_tweak": _tweak()})
	var d: AssaultDirector = _director()
	d.drama = 0.0
	assert_near(d._drama_spawn_scale(), 1.0, 0.0001, "no drama: full rate")
	d.drama = 1.0
	assert_near(d._drama_spawn_scale(), 0.5, 0.0001, "max drama: half rate")
	d.drama = 0.4
	assert_near(d._drama_spawn_scale(), 0.8, 0.0001, "1 - 0.5 * drama")


func _sustain_tweak() -> DirectorTweak:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 0.5
	tw.anticipation_s = 0.5
	tw.build_s = 0.5
	tw.sustain_by_stage_s = PackedFloat32Array([0.5, 0.5, 0.5])
	tw.fade_threshold = PackedInt32Array([0, 0, 0, 0, 0, 0])  # never by alive count
	tw.fade_wait_cap_s = 100.0
	tw.drama_fade_window_s = 2.0
	tw.drama_decay_per_s = 0.0
	return tw


func test_l1_2_fade_after_low_drama_window() -> void:
	await _launch({"director_tweak": _sustain_tweak()})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.SUSTAIN, 10.0)
	assert_true(ok, "SUSTAIN reached")
	d.drama = 0.0
	ok = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.FADE, 5.0)
	assert_true(ok, "FADE once drama < 0.2 for the window")


func test_l1_2_high_drama_holds_sustain() -> void:
	await _launch({"director_tweak": _sustain_tweak()})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.SUSTAIN, 10.0)
	assert_true(ok, "SUSTAIN reached")
	d.drama = 0.6
	await wait_seconds(3.5)
	assert_eq(d.assault_phase, Enums.AssaultPhase.SUSTAIN, "high drama keeps the assault going")
	d.drama = 0.1
	ok = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.FADE, 5.0)
	assert_true(ok, "FADE after drama dropped for the window")
