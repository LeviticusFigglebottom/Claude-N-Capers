## A3-04 / L5.2 Turncoat converts: with `ability.converts_max` a tied cop is converted (interaction
## &"convert") into an ally AI (CONVERTED, health x ability.convert_health_mult) that fights police.
extends TestCase

var _rt: HeistRuntime = null
var _saved_hit: float = 0.6


func before_each() -> void:
	_saved_hit = CustodyTweak.data().convert_hit_chance
	_rt = await HeistLauncher.launch(&"unit_map", 5252, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	await wait_physics_frames(1)


func after_each() -> void:
	CustodyTweak.data().convert_hit_chance = _saved_hit
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## A tied cop at `pos` (surrendered to slot 0, tied by slot 0); the crew stands 1 m away.
func _tied_cop(pos: Vector3) -> NpcBase:
	_crew().set_masked()
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)
	var s: PoliceSurrender = PoliceSurrender.of(cop, true)
	s.surrender(0)
	s.tie(0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0, 1)))
	await wait_physics_frames(2)
	return cop


func test_l5_2_needs_converts_max() -> void:
	var cop: NpcBase = await _tied_cop(Vector3(0, 0.05, 0))
	var conv: InteractableComponent = cop.get_node(PoliceSurrender.CONVERT_NAME) as InteractableComponent
	assert_eq(conv.kind, &"convert")
	assert_eq(conv.availability(_crew()), InteractableComponent.BLOCK_STATE, "no converts without the skill")
	Modifiers.set_source(0, &"test", {&"ability.converts_max": 1.0})
	assert_eq(conv.availability(_crew()), InteractableComponent.BLOCK_NONE, "converts_max 1")


func test_l5_2_convert_by_interaction() -> void:
	Modifiers.set_source(0, &"test", {&"ability.converts_max": 1.0, &"ability.convert_health_mult": 2.0})
	var cop: NpcBase = await _tied_cop(Vector3(0, 0.05, 0))
	var base_max: float = cop.max_health
	ATestMaps.hold_interact(_rt, 0, cop.net_id)
	var ok: bool = await wait_until(func() -> bool: return cop.alert_state == Enums.AlertState.CONVERTED,
		CustodyTweak.data().convert_s + 2.0)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_true(ok, "converted")
	var s: PoliceSurrender = PoliceSurrender.of(cop)
	assert_eq(s.converted_by_slot, 0, "owned by slot 0")
	assert_near(cop.max_health, base_max * 2.0, 0.001, "health x convert_health_mult")
	assert_near(cop.health, cop.max_health, 0.001, "full health")
	assert_false(cop.is_in_group(G.HOSTAGE), "no longer a hostage")
	assert_false(cop.is_in_group(G.ENEMY), "no longer an enemy")
	assert_true(cop.is_in_group(PoliceSurrender.CONVERT_GROUP), "ally group")
	assert_true(cop.get_node_or_null(ConvertedAllyBrain.NODE_NAME) is ConvertedAllyBrain, "ally brain")
	assert_eq(PoliceSurrender.live_converts(_rt, 0), 1)
	var second: NpcBase = await _tied_cop(Vector3(6, 0.05, 0))
	var conv2: InteractableComponent = second.get_node(PoliceSurrender.CONVERT_NAME) as InteractableComponent
	assert_eq(conv2.availability(_crew()), InteractableComponent.BLOCK_STATE, "cap reached (converts_max 1)")


func test_l5_2_convert_fights_police() -> void:
	Modifiers.set_source(0, &"test", {&"ability.converts_max": 1.0})
	CustodyTweak.data().convert_hit_chance = 1.0
	var ally: NpcBase = await _tied_cop(Vector3(0, 0.05, 0))
	assert_true(PoliceSurrender.of(ally).convert_to(0), "convert_to")
	var enemy: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -8)))
	var hp: float = enemy.health
	var ok: bool = await wait_until(func() -> bool: return enemy.health < hp or not enemy.alive, 4.0)
	assert_true(ok, "the convert shoots the police")
	var brain: ConvertedAllyBrain = ally.get_node(ConvertedAllyBrain.NODE_NAME) as ConvertedAllyBrain
	assert_true(brain.hits > 0, "hits landed")
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_false(dir.alive_units().has(ally), "a convert is not a police unit")
	assert_true(dir.alive_units().has(enemy) or not enemy.alive, "the enemy is")
