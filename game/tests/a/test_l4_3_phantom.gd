## A3-01a / L4.3 Phantom (PD2 Cloaker): telegraphs (hum, charge cue, goggles), charge + jump-kick ->
## CLOAKER_DOWNED (no down counted), ~10 s cooldown, sidestep dodge, never kicks the last player
## standing, play dead, Counterstrike hook, ECM feedback immunity, special_spawned [R].
extends TestCase

const DEF: String = "res://systems/ai/data/enemies/phantom.tres"

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(mates: int = 1, loadouts: Dictionary = {}) -> void:
	var opts: Dictionary = {"map_packed": ATestMaps.basic(0, 0), "ai_teammates": mates, "crew_ai": false,
		"skip_casing": true}
	if not loadouts.is_empty():
		opts["loadouts"] = loadouts
	_rt = await HeistLauncher.launch(&"unit_map", 4303, Enums.Difficulty.LETHAL, self, opts)
	_listen(EventBus.special_spawned, &"special")
	_listen(EventBus.audio_cue_requested, &"cue")
	_listen(EventBus.crew_cloaker_downed, &"cloaker")
	await wait_physics_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, _c: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _has_cue(id: StringName) -> bool:
	for e: Array in _events:
		if e[0] == &"cue" and e[1] == id:
			return true
	return false


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _go_loud() -> void:
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)


## Phantom 8 m in front of slot 0; slot 1 (if any) parked 25 m away.
func _setup_phantom(offset: Vector3 = Vector3(0, 0, -8)) -> NpcBase:
	if _rt.crew_members().size() > 1:
		_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(15, 0.05, 15)))
	_go_loud()
	var c: CrewController = _crew(0)
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"phantom",
		Transform3D(Basis.IDENTITY, c.global_position + offset))
	assert_eq(units.size(), 1, "one Phantom spawned")
	return units[0] if not units.is_empty() else null


func _brain(p: NpcBase) -> PhantomBrain:
	return p.get_node("Brain") as PhantomBrain


func test_l4_3_def_scene_and_spawn_event() -> void:
	var def: EnemyDef = load(DEF) as EnemyDef
	assert_eq(def.id, &"enemy.phantom")
	assert_true(def.is_special, "special")
	assert_eq(def.health.size(), 6, "health per difficulty")
	assert_eq(def.headshot_mult.size(), 6, "headshot per difficulty")
	assert_true(bool(def.params.get("ecm_feedback_immune", false)), "ECM feedback immune flag")
	await _launch()
	var p: NpcBase = _setup_phantom()
	assert_eq(p.role, &"special")
	assert_eq(p.enemy_def.id, &"enemy.phantom")
	assert_true(p.get_node_or_null("Brain") is PhantomBrain, "PhantomBrain")
	assert_true(p.find_child("Goggles", true, false) is GeometryInstance3D, "Goggles node (characters.md)")
	var nav: NavigationAgent3D = p.get_node_or_null("NavAgent") as NavigationAgent3D
	assert_true(nav != null and (nav.navigation_layers & 4) != 0, "walks the vent nav layer")
	await wait_physics_frames(2)
	assert_has(_events, [&"special", p.net_id, &"phantom"], "special_spawned(net_id, phantom)")
	assert_true(_rt.npcs(&"special").has(p), "listed as a special")


func test_l4_3_charge_kick_cloaker_downed() -> void:
	await _launch()
	var p: NpcBase = _setup_phantom()
	var b: PhantomBrain = _brain(p)
	var c: CrewController = _crew(0)
	var winding: bool = await wait_until(func() -> bool: return b.mode == &"windup", 5.0)
	assert_true(winding, "winds up a charge in range with LOS (mode %s)" % b.mode)
	assert_true(b.goggles_glowing, "goggles glow green during the charge")
	var gog: GeometryInstance3D = p.find_child("Goggles", true, false) as GeometryInstance3D
	var mat: BaseMaterial3D = gog.material_override as BaseMaterial3D
	assert_near(mat.emission_energy_multiplier, b.tweak.phantom_goggle_energy_charge, 0.001, "emission ramped")
	assert_true(_has_cue(&"cue.phantom_charge"), "cue.phantom_charge")
	assert_true(_has_cue(&"cue.phantom_hum"), "cue.phantom_hum loop")
	var kicked: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CLOAKER_DOWNED, 4.0)
	assert_true(kicked, "jump-kick takes the target down")
	assert_eq(b.last_kick_result, &"hit")
	assert_eq(c.health.downs_used, 0, "L2.8: no down counted")
	assert_eq(c.health.bleedout_left, 0.0, "no bleedout")
	assert_has(_events, [&"cloaker", 0, p.net_id], "crew_cloaker_downed(slot, phantom)")
	assert_false(b.goggles_glowing, "goggles back to idle")


func test_l4_3_kick_cooldown() -> void:
	await _launch()
	var p: NpcBase = _setup_phantom()
	var b: PhantomBrain = _brain(p)
	var c: CrewController = _crew(0)
	var kicked: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CLOAKER_DOWNED, 6.0)
	assert_true(kicked, "first kick")
	assert_near(b.kick_cooldown_left, b.tweak.phantom_kick_cooldown_s, 0.2, "~10 s cooldown")
	c.health.revive(1)
	await wait_seconds(2.5)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "no second kick during the cooldown")
	assert_eq(b.kicks_landed, 1)
	b.kick_cooldown_left = 0.0
	var again: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CLOAKER_DOWNED, 6.0)
	assert_true(again, "kicks again once the cooldown is over")
	assert_eq(c.health.downs_used, 0, "still no down counted")


func test_l4_3_sidestep_dodges_the_kick() -> void:
	await _launch()
	var p: NpcBase = _setup_phantom()
	var b: PhantomBrain = _brain(p)
	var c: CrewController = _crew(0)
	var winding: bool = await wait_until(func() -> bool: return b.mode == &"windup", 5.0)
	assert_true(winding, "windup")
	var side: Vector3 = b.charge_dir.cross(Vector3.UP).normalized()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, c.global_position + side * 3.0))
	var done: bool = await wait_until(func() -> bool: return b.last_kick_result != &"", 5.0)
	assert_true(done, "charge resolved")
	assert_eq(b.last_kick_result, &"dodged", "a sidestep off the committed line dodges")
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "not taken down")
	assert_true(b.kick_cooldown_left > 0.0, "a miss also costs the cooldown")


func test_l4_3_never_kicks_last_player_standing() -> void:
	# Solo, no AI: the only player is always the last one standing.
	await _launch(0)
	var p: NpcBase = _setup_phantom(Vector3(0, 0, -5))
	var b: PhantomBrain = _brain(p)
	var c: CrewController = _crew(0)
	await wait_seconds(3.0)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "solo player never kicked")
	assert_ne(b.mode, &"windup", "no charge")
	assert_eq(b.kicks_landed, 0)
	assert_eq(b.mode, &"standoff", "keeps a standoff")
	assert_false(b.can_kick(c), "can_kick false for the last player")


func test_l4_3_no_kick_when_teammate_already_helpless() -> void:
	await _launch(1)
	var mate: CrewController = _crew(1)
	mate.health.incapacitate(Enums.CrewState.TASED, 1)
	var p: NpcBase = _setup_phantom(Vector3(0, 0, -5))
	var b: PhantomBrain = _brain(p)
	await wait_seconds(2.5)
	assert_eq(_crew(0).crew_state, Enums.CrewState.NORMAL, "last standing (teammate tased) not kicked")
	assert_eq(b.kicks_landed, 0)
	mate.health.revive(0)
	var kicked: bool = await wait_until(func() -> bool:
		return _crew(0).crew_state == Enums.CrewState.CLOAKER_DOWNED \
			or mate.crew_state == Enums.CrewState.CLOAKER_DOWNED, 6.0)
	assert_true(kicked, "kicks once two players are standing again")


func test_l4_3_counterstrike_knocks_down() -> void:
	await _launch()
	Modifiers.set_source(0, &"test.counter", {&"defense.cloaker_counter": true})
	var p: NpcBase = _setup_phantom()
	var b: PhantomBrain = _brain(p)
	var i: CrewIntent = CrewIntent.new()
	i.melee = true
	_rt.set_bot_intent(0, i)
	var done: bool = await wait_until(func() -> bool: return b.last_kick_result != &"", 6.0)
	assert_true(done, "charge resolved")
	assert_eq(b.last_kick_result, &"countered", "melee held during the charge counters")
	assert_eq(_crew(0).crew_state, Enums.CrewState.NORMAL, "not taken down")
	assert_true(p.is_stunned(), "Phantom knocked down")


func test_l4_3_play_dead() -> void:
	await _launch()
	var p: NpcBase = _setup_phantom(Vector3(0, 0, -20))
	var b: PhantomBrain = _brain(p)
	await wait_until(func() -> bool: return b.is_active(), 2.0)
	var tw: SpecialTweak = b.tweak.duplicate() as SpecialTweak
	tw.phantom_play_dead_chance = 1.0
	tw.phantom_play_dead_s = Vector2(0.6, 0.6)
	b.tweak = tw
	p.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", p.global_position, Vector3.FORWARD), 0)
	assert_true(b.is_playing_dead(), "drops on a hit (play dead)")
	assert_true(p.alive, "still alive while playing dead")
	var up: bool = await wait_until(func() -> bool: return not b.is_playing_dead(), 2.0)
	assert_true(up, "gets up later")
	p.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", p.global_position, Vector3.FORWARD), 0)
	assert_false(b.is_playing_dead(), "play dead limited per life (phantom_play_dead_max)")


func test_l4_3_ecm_feedback_immune() -> void:
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.ecm"
	await _launch(1, {0: l})
	var p: NpcBase = _setup_phantom(Vector3(0, 0, -6))
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, _crew(0).global_position + Vector3(3, 0, -6)))
	await wait_physics_frames(2)
	var sys: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	var ecm_prefab: DeployablePrefab = sys.place(_crew(0)) as DeployablePrefab
	assert_true(ecm_prefab != null, "ECM placed")
	if ecm_prefab == null:
		return
	await wait_physics_frames(2)
	var ecm: EcmSystem = HeistRuntime.get_service(&"ecm") as EcmSystem
	ecm.trigger_feedback(ecm_prefab, 0)
	assert_true(cop.is_stunned(), "a normal unit is stunned by feedback")
	assert_false(p.is_stunned(), "the Phantom is immune to ECM feedback")
