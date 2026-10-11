## Last phase-4 keys: movement.sprint_speed_mult, weapon.kill_ammo_drop {every_n_kills} (Scrounger aced),
## weapon.ammo_pickup_throwable {base_chance, step} (Pack Mule aced); throwable_count from the loadout.
extends TestCase

var _rt: HeistRuntime = null
var _drop_chance: float = 1.0


func before_each() -> void:
	Modifiers.clear_all()
	_drop_chance = AmmoPickupTweak.data().drop_chance


func after_each() -> void:
	AmmoPickupTweak.data().drop_chance = _drop_chance
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(l: Loadout = null) -> CrewController:
	var loadouts: Dictionary = {0: l} if l != null else {}
	_rt = await HeistLauncher.launch(&"unit_map", 8812, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true, "loadouts": loadouts})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20)))
	await wait_physics_frames(3)
	return c


func _ammo() -> AmmoPickupSystem:
	return _rt.service(AmmoPickupSystem.SERVICE) as AmmoPickupSystem


func test_sprint_speed_mult() -> void:
	var c: CrewController = await _launch()
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = true
	Modifiers.set_source(0, &"skills", {&"movement.sprint_speed_mult": 1.2})
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.4)
	assert_true(c.sprinting, "sprinting")
	assert_near(Vector2(c.velocity.x, c.velocity.z).length(), Tweak.crew().sprint_speed * 1.2, 0.05, "sprint x1.2")


func test_kill_ammo_drop_every_n_kills() -> void:
	var c: CrewController = await _launch()
	AmmoPickupTweak.data().drop_chance = 0.0  # only the skill's extra boxes drop
	Modifiers.set_source(0, &"skills", {&"weapon.kill_ammo_drop": {"every_n_kills": 2}})
	for k: int in range(4):
		var npc: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(3.0 * k, 0.05, -6))
		await wait_physics_frames(1)
		EventBus.npc_killed.emit(npc.net_id, c.net_id, {})
	assert_eq(_ammo().boxes().size(), 2, "every 2nd kill drops an extra box")
	var other: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(0, 0.05, -12))
	await wait_physics_frames(1)
	EventBus.npc_killed.emit(other.net_id, 0, {})
	assert_eq(_ammo().boxes().size(), 2, "kills by nobody in the crew do not count")


func test_ammo_pickup_throwable_and_loadout_count() -> void:
	var throwables: Array = ContentDB.all_throwables()
	if throwables.is_empty():
		skip("no ThrowableDef in content")
		return
	var th: ThrowableDef = throwables[0] as ThrowableDef
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = th.id
	var c: CrewController = await _launch(l)
	var w: CrewWeapons = c.weapons
	assert_eq(w.throwable_count, th.count, "throwable_count starts at ThrowableDef.count")
	w.throwable_count = 0
	Modifiers.set_source(0, &"skills", {&"weapon.ammo_pickup_throwable": {"base_chance": 1.0, "step": 0.0}})
	w.set_ammo(w.equipped_slot, 1, 0)
	_ammo().drop(c.global_position + Vector3(0, 0.05, 0))
	await wait_physics_frames(3)
	assert_eq(_ammo().boxes().size(), 0, "box taken")
	assert_eq(w.throwable_count, 1, "the box held a throwable")
	Modifiers.set_source(0, &"skills", {&"weapon.ammo_pickup_throwable": {"base_chance": 0.0, "step": 0.0}})
	w.set_ammo(w.equipped_slot, 1, 0)
	_ammo().drop(c.global_position + Vector3(0, 0.05, 0))
	await wait_physics_frames(3)
	assert_eq(w.throwable_count, 1, "chance 0: nothing extra")
