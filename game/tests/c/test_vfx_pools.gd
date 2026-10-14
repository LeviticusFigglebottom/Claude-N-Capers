## VfxDirector pools (impact_fx.md 1.0 §3): 1000 shots never exceed any cap, decals recycle and fade,
## no orphan nodes, quality scaling, tracer cadence / pellet groups / flags, EventBus wiring. Headless.
extends TestCase

const CLASSES: Array[StringName] = [&"assault_rifle", &"smg", &"pistol", &"shotgun", &"lmg", &"sniper", &"melee"]

var _d: VfxDirector


func before_each() -> void:
	VfxSettings.reset()
	_d = VfxDirector.new()
	_d.listen_to_event_bus = false
	_d.use_game_settings = false
	_d.auto_advance = false
	_d.play_impact_cues = false
	add_child(_d)


func after_each() -> void:
	if is_instance_valid(_d):
		_d.free()
	_d = null
	VfxSettings.reset()


func _shot(i: int, flags: int = 0, cls: StringName = &"") -> void:
	var c: StringName = cls if cls != &"" else CLASSES[i % CLASSES.size()]
	var surf: StringName = ImpactFx.SURFACES[i % ImpactFx.SURFACES.size()]
	var origin: Vector3 = Vector3(float(i % 7), 1.5, 10.0)
	var end: Vector3 = Vector3(float(i % 23) * 0.3, 0.2 + float(i % 11) * 0.2, 0.0)
	var normal: Vector3 = Vector3.BACK if i % 9 != 0 else Vector3.ZERO  # some misses
	_d.on_shot_fx(origin, end, normal, surf if normal != Vector3.ZERO else &"", c, 100 + i % 5, flags)


func _assert_caps(tag: String) -> void:
	var s: Dictionary = _d.stats()
	assert_true(int(s["decals"]) <= int(s["decal_cap"]) and int(s["decal_slots"]) <= int(s["decal_cap"]),
		"%s decals %s" % [tag, s])
	assert_true(int(s["decal_cap"]) <= VfxSettings.DECAL_CAP, "%s decal cap <= 128" % tag)
	assert_true(int(s["tracers"]) <= int(s["tracer_cap"]), "%s tracers %s" % [tag, s])
	assert_true(int(s["muzzle_sets"]) <= int(s["muzzle_cap"]), "%s muzzles %s" % [tag, s])
	assert_true(int(s["lights"]) <= VfxSettings.LIGHT_CAP, "%s lights %s" % [tag, s])
	assert_true(int(s["shells"]) <= int(s["shell_cap"]), "%s shells %s" % [tag, s])
	var ic: Vector2i = s["impact_caps"]
	assert_true(int(s["impact_sets"]) <= ic.y, "%s impact sets %s" % [tag, s])
	assert_true(int(s["explosion_sets"]) <= int(s["explosion_cap"]), "%s explosions %s" % [tag, s])


func test_thousand_shots_stay_capped() -> void:
	for i: int in range(1000):
		_shot(i)
		if i % 3 == 0:
			_d.advance(1.0 / 60.0)
		if i % 50 == 0:
			_d.on_explosion_fx(Vector3(float(i % 5), 0.0, 2.0), 4.0, &"frag")
			_assert_caps("shot %d" % i)
	_assert_caps("end")
	assert_eq(_d.shots, 1000)
	assert_eq(_d.decals.live, VfxSettings.DECAL_CAP, "decal pool full, recycling oldest")
	assert_eq(_d.decals.get_child_count(), VfxSettings.DECAL_CAP, "no decal nodes beyond the cap")
	for s: StringName in _d.impacts._sets.keys():
		assert_true((_d.impacts._sets[s] as Array).size() <= VfxSettings.IMPACT_SETS_PER_SURFACE, String(s))
	assert_true(_d.tracers.spawned > 0 and _d.muzzles.fired > 0 and _d.impacts.fired > 0, "effects fired")


func test_decals_recycle_oldest_and_fade() -> void:
	var first: Node3D = _d.decals.place(&"concrete", Vector3.ZERO, Vector3.BACK, 0.1)
	_d.advance(1.0)
	for i: int in range(VfxSettings.DECAL_CAP - 1):
		_d.decals.place(&"brick", Vector3(i * 0.01, 1, 0), Vector3.BACK, 0.1)
	assert_eq(_d.decals.live, VfxSettings.DECAL_CAP)
	var reused: Node3D = _d.decals.place(&"wood", Vector3(0, 2, 0), Vector3.BACK, 0.1)
	assert_eq(reused, first, "the oldest decal is recycled when full")
	assert_eq(_d.decals.live, VfxSettings.DECAL_CAP)
	_d.advance(VfxSettings.DECAL_HOLD_S - 1.5)
	assert_eq(_d.decals.live, VfxSettings.DECAL_CAP, "still alive before 60 s")
	for k: int in range(10):
		_d.advance(0.5)
	assert_eq(_d.decals.live, 0, "all faded after 60 s + fade")
	assert_eq(_d.decals.slot_count(), VfxSettings.DECAL_CAP, "slots kept for reuse")


func test_no_orphans_after_free() -> void:
	_d.free()
	await wait_frames(2)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var d: VfxDirector = VfxDirector.new()
	d.listen_to_event_bus = false
	d.use_game_settings = false
	d.auto_advance = false
	d.play_impact_cues = false
	add_child(d)
	for i: int in range(1000):
		d.on_shot_fx(Vector3(0, 1.5, 5), Vector3(i % 13, 1, 0), Vector3.BACK, ImpactFx.SURFACES[i % 13],
			CLASSES[i % CLASSES.size()], i % 4, 0)
		if i % 4 == 0:
			d.advance(1.0 / 60.0)
	VfxSettings.set_quality(VfxSettings.Quality.LOW)  # forces pool rebuilds (queue_free of old sets)
	d.advance(0.1)
	await wait_frames(2)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before, "no orphans while live")
	d.free()
	await wait_frames(2)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before, "no orphans after free")


func test_quality_scales_caps() -> void:
	var high: Dictionary = _d.stats()
	VfxSettings.set_quality(VfxSettings.Quality.LOW)
	_d.advance(0.0)
	var low: Dictionary = _d.stats()
	assert_true(int(low["decal_cap"]) < int(high["decal_cap"]), "decals %s < %s" % [low, high])
	assert_true(int(low["tracer_cap"]) < int(high["tracer_cap"]), "tracers")
	assert_true(int(low["shell_cap"]) < int(high["shell_cap"]), "shells")
	assert_true((low["impact_caps"] as Vector2i).x < (high["impact_caps"] as Vector2i).x, "impact sets")
	assert_true(VfxSettings.scaled_count(10) < 10, "particle counts scale")
	for i: int in range(1000):
		_shot(i)
		if i % 4 == 0:
			_d.advance(1.0 / 60.0)
	_assert_caps("low")
	assert_eq(_d.decals.live, int(low["decal_cap"]))
	VfxSettings.reduce_motion = true
	assert_true(VfxSettings.scaled_count(10) <= 2, "reduce motion halves counts")
	VfxSettings.effects_quality = 1.0
	VfxSettings.reduce_motion = false
	_d.advance(0.0)
	assert_eq(int(_d.stats()["decal_cap"]), VfxSettings.DECAL_CAP, "back to HIGH")


func test_tracer_cadence_and_flags() -> void:
	var o: Vector3 = Vector3(0, 1.5, 20)
	var e: Vector3 = Vector3(0, 1.0, 0)
	for i: int in range(10):
		_d.on_shot_fx(o, e, Vector3.BACK, &"concrete", &"assault_rifle", 7, 0)
		_d.advance(0.01)
	assert_eq(_d.tracers.spawned, 5, "AR: 1 in 2")
	for i: int in range(9):
		_d.on_shot_fx(o, e, Vector3.BACK, &"concrete", &"pistol", 8, 0)
		_d.advance(0.01)
	assert_eq(_d.tracers.spawned, 8, "pistol: 1 in 3")
	for i: int in range(3):
		_d.on_shot_fx(o, e, Vector3.BACK, &"concrete", &"sniper", 9, 0)
		_d.advance(0.01)
	assert_eq(_d.tracers.spawned, 11, "sniper: every shot")
	for i: int in range(6):
		_d.on_shot_fx(o, e, Vector3.BACK, &"concrete", &"sniper", 9, VfxDirector.FLAG_SUPPRESSED)
		_d.advance(0.01)
	assert_eq(_d.tracers.spawned, 11, "suppressed: none")
	var m0: int = _d.muzzles.fired
	var lights0: int = _d.lights.started
	for i: int in range(4):
		_d.on_shot_fx(o, e, Vector3.BACK, &"concrete", &"sniper", 10, VfxDirector.FLAG_FIRST_PERSON)
		_d.advance(0.01)
	assert_eq(_d.tracers.spawned, 11, "first person: P draws the tracer")
	assert_eq(_d.muzzles.fired, m0, "first person: no third-person muzzle")
	assert_eq(_d.lights.started, lights0, "first person: no light")
	assert_eq(_d.impacts.fired, 32, "impacts always")


func test_shotgun_pellet_group() -> void:
	var o: Vector3 = Vector3(0, 1.5, 8)
	var shells0: int = _d.shells.live
	for p: int in range(9):
		_d.on_shot_fx(o, Vector3(p * 0.1 - 0.4, 1.0, 0), Vector3.BACK, &"wood", &"shotgun", 3, 0)
	assert_eq(_d.muzzles.fired, 1, "one flash per pellet group")
	assert_eq(_d.shells.live - shells0, 1, "one casing per pellet group")
	assert_eq(_d.tracers.spawned, 3, "1 in 3 pellets")
	assert_eq(_d.impacts.fired, 9)
	_d.advance(0.5)
	for p: int in range(9):
		_d.on_shot_fx(o, Vector3(p * 0.1 - 0.4, 1.0, 0), Vector3.BACK, &"wood", &"shotgun", 3, 0)
	assert_eq(_d.muzzles.fired, 2, "next frame = next blast")


func test_suppressed_muzzle_is_puff_only() -> void:
	var s: Node3D = _d.muzzles.fire(Vector3.ZERO, Vector3.FORWARD, &"pistol", true)
	assert_false((s.get_node("Star") as Node3D).visible, "no flash when suppressed")
	s = _d.muzzles.fire(Vector3.ZERO, Vector3.FORWARD, &"pistol", false)
	assert_true((s.get_node("Star") as Node3D).visible, "flash")
	_d.advance(MuzzleFx.FLASH_S + 0.01)
	assert_false((s.get_node("Star") as Node3D).visible, "flash gone after 0.05 s")
	assert_eq(VfxLights.LAYERS & (1 << 20), 1 << 20, "lights on viewmodel_lit (layer 21)")


func test_shells_land_and_expire() -> void:
	_d.shells.eject(&"assault_rifle", Vector3(0, 1.5, 0), Vector3.FORWARD)
	assert_eq(_d.shells.live, 1)
	for i: int in range(60):
		_d.advance(1.0 / 30.0)
	assert_true(_d.shells._rest[0] >= 0.0, "landed after two contacts")
	assert_true(_d.shells._pos[0].y < 1.0, "fell")
	_d.advance(ShellFx.REST_S + 0.1)
	assert_eq(_d.shells.live, 0, "expired")
	_d.shells.eject(&"melee", Vector3.ZERO, Vector3.FORWARD)
	assert_eq(_d.shells.live, 0, "melee ejects nothing")


func test_event_bus_wiring() -> void:
	var d: VfxDirector = (load("res://world/vfx/vfx_director.tscn") as PackedScene).instantiate() as VfxDirector
	d.auto_advance = false
	d.play_impact_cues = false
	add_child(d)
	EventBus.shot_fx.emit(Vector3(0, 1, 5), Vector3.ZERO, Vector3.BACK, &"metal", &"smg", 1, 0)
	EventBus.explosion_fx.emit(Vector3.ZERO, 5.0, &"frag")
	assert_eq(d.shots, 1, "shot_fx reaches the director")
	assert_eq(d.explosions.fired, 1, "explosion_fx reaches the director")
	assert_eq(d.decals.live, 2, "bullet hole + scorch")
	d.free()
	EventBus.shot_fx.emit(Vector3(0, 1, 5), Vector3.ZERO, Vector3.BACK, &"metal", &"smg", 1, 0)  # no dangling handler


func test_impact_cue_guarded() -> void:
	_d.play_impact_cues = true
	var got: Array[StringName] = []
	var cb: Callable = func(id: StringName, _p: Vector3, _n: int) -> void: got.append(id)
	EventBus.audio_cue_requested.connect(cb)
	var per_frame_max: int = 0
	for f: int in range(20):
		var before: int = got.size()
		for i: int in range(10):
			_d.on_shot_fx(Vector3(0, 1, 5), Vector3(i, 0, 0), Vector3.BACK, ImpactFx.SURFACES[(f * 10 + i) % 13],
				&"smg", 1, 0)
		_d.advance(1.0 / 60.0)
		per_frame_max = maxi(per_frame_max, got.size() - before)
	EventBus.audio_cue_requested.disconnect(cb)
	var reg: AudioCueRegistry = AudioCueLib.registry()
	for id: StringName in got:
		assert_true(reg.has_cue(id), "only registered cues are requested (%s)" % id)
	assert_true(per_frame_max <= VfxDirector.MAX_IMPACT_CUES_PER_FRAME, "per-frame cap (%d)" % per_frame_max)
	assert_true(got.size() <= int(VfxSettings.IMPACT_CUES_PER_S) + 8, "rate limited (%d)" % got.size())
	if reg.has_cue(&"cue.impact_concrete"):
		assert_true(got.size() > 0, "impact cues requested once they exist")


func test_first_person_shot_is_impact_only() -> void:
	var fp: int = VfxDirector.FLAG_FIRST_PERSON
	for cls: StringName in [&"assault_rifle", &"sniper", &"shotgun", &"pistol"]:
		_d.on_shot_fx(Vector3(0, 1.5, 6), Vector3(0, 1, 0), Vector3.BACK, &"brick", cls, 5, fp)
		_d.advance(0.02)
	assert_eq(_d.impacts.fired, 4, "impact debris for every FP shot")
	assert_eq(_d.decals.live, 4, "bullet holes for every FP shot")
	assert_eq(_d.tracers.spawned, 0, "no tracer (ENV P draws it)")
	assert_eq(_d.muzzles.fired, 0, "no muzzle flash/smoke (ENV P draws it)")
	assert_eq(_d.shells.live, 0, "no casing (ENV P ejects it)")
	assert_eq(_d.lights.started, 0, "no light")


func test_standalone_scenes_for_viewmodel() -> void:
	var mf: MuzzleFlash = (load("res://world/vfx/muzzle_flash.tscn") as PackedScene).instantiate() as MuzzleFlash
	add_child(mf)
	mf.scale = Vector3.ONE * 0.12
	mf.flash()
	assert_true(mf.is_flashing(), "flash visible")
	assert_true((mf.get_node("Flame") as Node3D).scale.z > 1.0, "flame ~1 m along -Z at size 1")
	await wait_seconds(0.2)
	assert_false(mf.is_flashing(), "self-timed hide")
	mf.free()
	var tr: TracerFx = (load("res://world/vfx/tracer.tscn") as PackedScene).instantiate() as TracerFx
	add_child(tr)
	tr.spawn(Vector3(0, 1, 0), Vector3(0, 1, -30))
	assert_eq(tr.live, 1)
	await wait_seconds(0.4)
	assert_eq(tr.live, 0, "self-advancing tracer finished")
	tr.free()


func test_quality_from_game_settings() -> void:
	var gs: GameSettings = GameSettings.new()
	gs.set_value(GameSettings.VIDEO, &"effects_quality", &"low")
	VfxSettings.sync_from_game_settings(gs)
	assert_near(VfxSettings.effects_quality, GameSettings.EFFECTS_SCALE[GameSettings.EFFECTS_LOW], 0.001, "low")
	gs.set_value(GameSettings.VIDEO, &"effects_quality", &"high")
	gs.set_value(GameSettings.ACCESSIBILITY, &"reduce_motion", true)
	VfxSettings.sync_from_game_settings(gs)
	assert_near(VfxSettings.effects_quality, GameSettings.EFFECTS_SCALE[GameSettings.EFFECTS_MEDIUM], 0.001,
		"reduce motion steps quality down")
	assert_true(VfxSettings.reduce_motion, "reduce motion mirrored")
	_d.advance(0.0)
	assert_true(_d.decals.cap() < VfxSettings.DECAL_CAP, "director re-applied caps")
