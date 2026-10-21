## A1-08 NPC gunfire: a guard in COMBAT shoots a crew member in LOS (GuardBrain hook -> Gunner);
## L2.5 police don't shoot a downed crew member who isn't shooting; walls block NPC fire.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_physics_frames(1)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _total(c: CrewController) -> float:
	return c.health.health + c.health.armor


func test_a1_08_guard_and_police_have_gunners() -> void:
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	assert_true(g.get_node_or_null("Gunner") is NpcGunner, "guard Gunner")
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	assert_true(p.get_node_or_null("Gunner") is NpcGunner, "police Gunner")


func test_a1_08_combat_guard_shoots_crew_in_los() -> void:
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var c: CrewController = _crew()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0, 6.0)))
	await wait_physics_frames(2)
	var fired: Array[int] = []
	var fcb: Callable = func(src: int, _w: StringName, _s: bool, _p: Vector3) -> void:
		if src == g.net_id:
			fired.append(src)
	EventBus.weapon_fired.connect(fcb)
	var before: float = _total(c)
	_rt.stealth.raise_alarm(&"test", 0)
	var hurt: bool = await wait_until(func() -> bool: return _total(c) < before, 8.0)
	EventBus.weapon_fired.disconnect(fcb)
	assert_eq(g.alert_state, Enums.AlertState.COMBAT, "guard in combat")
	assert_false(fired.is_empty(), "guard fired (weapon_fired)")
	assert_true(hurt, "crew took damage (armor/health dropped from %f to %f)" % [before, _total(c)])
	var dmg: float = g.enemy_def.damage[Enums.Difficulty.ROUTINE]
	assert_true(before - _total(c) <= dmg * float(fired.size()) + 0.01, "per-shot damage from EnemyDef")


func test_a1_08_npc_fire_blocked_by_wall() -> void:
	var c: CrewController = _crew()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -3), Vector3(4, 3, 0.3))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	gun.fire_at(c)
	await wait_seconds(2.0)
	assert_true(shots.is_empty(), "no LOS, no shots")
	assert_near(_total(c), c.health.max_health + c.health.max_armor, 0.001)


## D's GH Tense anim coverage (PD2): guards see the crew through clear glass (D-142) and used to aim at it for good
## without firing (the shot line stopped at the pane). Now the first round goes into a breakable pane and breaks it
## (no hit through intact glass), and the next rounds go through the opening. Armoured glazing (breakable off) still
## stops them.
func test_d142_npc_shoots_out_a_glass_pane() -> void:
	var w: WindowPrefab = await _glass_between(true)
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	var before: float = _total(_crew())
	gun.fire_at(_crew())
	var broke: bool = await wait_until(func() -> bool: return w.broken, 4.0)
	assert_true(broke, "the police shot the pane out")
	assert_false(shots.is_empty() or shots[0], "the first round went into the glass, not the crew")
	await wait_until(func() -> bool: return shots.size() >= 4, 6.0)
	assert_true(shots.size() >= 2, "kept firing through the opening (%d shots)" % shots.size())
	assert_true(_total(_crew()) <= before, "no healing from glass")


func test_d142_npc_holds_fire_at_armoured_glass() -> void:
	var w: WindowPrefab = await _glass_between(false)
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	gun.fire_at(_crew())
	await wait_seconds(2.0)
	assert_true(shots.is_empty(), "no shots into armoured (non-breakable) glazing")
	assert_false(w.broken, "intact")


## Crew at the origin, a Window between it and z = -6 (sill raised so the eye-to-chest line crosses the glass).
func _glass_between(breakable: bool) -> WindowPrefab:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var w: WindowPrefab = (load("res://systems/prefabs/window/window.tscn") as PackedScene).instantiate() as WindowPrefab
	w.breakable = breakable
	_rt.map.add_child(w)
	w.global_position = Vector3(0.0, 0.7, -3.0)
	await wait_physics_frames(3)
	var space: PhysicsDirectSpaceState3D = _rt.map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, -6), Vector3(0, 1.2, 0),
		CombatTweak.data().los_mask)
	var hit: Dictionary = space.intersect_ray(q)
	assert_true(not hit.is_empty() and (hit["collider"] as Node).is_in_group(StealthDirector.GROUP_SEE_THROUGH),
		"setup: the glass is on the line (%s)" % [hit.get("collider")])
	return w


func test_l2_5_police_hold_fire_on_downed_non_shooter() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	c.health.armor = 0.0
	c.take_hit(CombatSystem.make_damage_info(1000.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"", c.global_position, Vector3.FORWARD), 0)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	gun.fire_at(c)
	await wait_seconds(2.0)
	assert_true(shots.is_empty(), "police don't shoot a downed crew member who isn't shooting")
	var bleed0: float = c.health.bleedout_health
	# Shooting back makes the downed crew member a target again.
	var on: CrewIntent = CrewIntent.new()
	on.look_pitch = deg_to_rad(60.0)
	on.fire = true
	var off: CrewIntent = CrewIntent.new()
	off.look_pitch = on.look_pitch
	for k: int in range(6):
		_rt.set_bot_intent(0, on)
		await wait_physics_frames(2)
		_rt.set_bot_intent(0, off)
		await wait_seconds(0.5)
	_rt.clear_bot_intent(0)
	assert_false(shots.is_empty(), "police fire at a downed shooter")
	if shots.has(true):
		assert_true(c.health.bleedout_health < bleed0 or c.crew_state == Enums.CrewState.CUSTODY, "bleedout health drops")


## D-111 (PD2 enemies reload; P: reload_rifle never showed): the magazine runs dry, the NPC reloads for
## reload_time() without firing, the reload cue goes out (replicated; AnimDriver plays reload_rifle / _pistol), then it
## fires on.
func test_d111_police_reload_when_the_magazine_is_empty() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	assert_true(gun.mag_size() > 0, "police carry a magazine")
	gun.rounds_left = 2
	var shots: Array[bool] = []
	gun.shot.connect(func(_t: Node, hit: bool) -> void: shots.append(hit))
	var cues: Array[StringName] = []
	var on_cue: Callable = func(id: StringName, _pos: Vector3, src: int) -> void:
		if src == p.net_id:
			cues.append(id)
	EventBus.audio_cue_requested.connect(on_cue)
	gun.fire_at(c)
	assert_true(await wait_until(func() -> bool: return gun.reload_left > 0.0, 6.0), "the magazine ran dry: reloading")
	assert_eq(shots.size(), 2, "two rounds, then the reload")
	assert_true(cues.has(NpcGunner.CUE_RELOAD_RIFLE) or cues.has(NpcGunner.CUE_RELOAD_PISTOL),
		"reload cue for the animation / sound (%s)" % [cues])
	var during: int = shots.size()
	await wait_seconds(gun.reload_time() * 0.8)
	assert_eq(shots.size(), during, "no fire while reloading")
	assert_true(await wait_until(func() -> bool: return shots.size() > during, gun.reload_time() + 3.0), "fires again after")
	assert_eq(gun.rounds_left, gun.mag_size() - (shots.size() - during), "a full magazine")
	EventBus.audio_cue_requested.disconnect(on_cue)
	Modifiers.clear_all()


## PERF (windowed npc_gunner HITCH hunt): with FrameProf on, a shot books its costly calls under npc_gunner.* sub-keys
## (inside the npc_gunner tick), so a stall names the call that held it; with FrameProf off nothing is booked.
func test_perf_gunner_frame_prof_sub_scopes() -> void:
	var c: CrewController = _crew()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	var was: bool = FrameProf.enabled
	FrameProf.totals.clear()
	FrameProf.enabled = true
	gun.fire_at(c)
	var fired: bool = await wait_until(func() -> bool: return shots.size() >= 3 and shots.has(true), 8.0)
	FrameProf.enabled = was
	gun.hold_fire()
	var t: Dictionary = FrameProf.totals.duplicate()
	FrameProf.totals.clear()
	FrameProf.reset_frame()
	assert_true(fired, "police fired and hit (%s)" % [shots])
	for k: StringName in [&"npc_gunner", &"npc_gunner.los", &"npc_gunner.fired", &"npc_gunner.fx", &"npc_gunner.hit"]:
		assert_true(t.has(k), "FrameProf booked %s (%s)" % [k, t.keys()])
	var parts: int = int(t.get(&"npc_gunner.los", 0)) + int(t.get(&"npc_gunner.fired", 0)) \
		+ int(t.get(&"npc_gunner.fx", 0)) + int(t.get(&"npc_gunner.hit", 0))
	assert_true(parts <= int(t.get(&"npc_gunner", 0)), "sub-scopes nest inside npc_gunner (%d <= %d us)" % [
		parts, int(t.get(&"npc_gunner", 0))])
	var before: int = shots.size()
	gun.fire_at(c)
	await wait_until(func() -> bool: return shots.size() > before, 4.0)
	gun.hold_fire()
	assert_true(FrameProf.totals.is_empty(), "FrameProf off: nothing booked")
