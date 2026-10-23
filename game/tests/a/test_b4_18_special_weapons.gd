## B4-18 (D-055) special weapons runtime: SpecialWeapons params merge, flamethrower cone + FIRE DoT (L3.4),
## saw contact + blade wear, bow draw + projectile + arrow retrieval, launcher blast (L3.6), minigun spin.
extends TestCase

class FakeVisual extends Node3D:
	func get_marker(marker: StringName) -> Node3D:
		return find_child(String(marker), true, false) as Node3D


var _rt: HeistRuntime = null
var _events: Array[Dictionary] = []
var _cb: Callable = Callable()


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)
	_events = []
	_cb = func(v: int, a: int, info: Dictionary) -> void: _events.append({"victim": v, "attacker": a, "info": info})
	EventBus.damage_applied.connect(_cb)


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	ContentDB.clear_cache()
	await wait_frames(2)


func _def(id: StringName, fire_modes: Array[StringName], params: Dictionary, mag: int = 30) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	d.id = id
	d.weapon_class = Enums.WeaponClass.SPECIAL
	d.slot = Enums.WeaponSlot.PRIMARY
	d.fire_modes = fire_modes
	d.params = params
	var st: WeaponStats = WeaponStats.new()
	st.damage = 40.0
	st.fire_rate_rpm = 600.0
	st.mag_size = mag
	st.total_ammo = mag * 4
	st.reload_time_s = 1.0
	st.reload_empty_time_s = 1.0
	st.falloff_start_m = 9999.0
	st.falloff_end_m = 9999.0
	st.falloff_min_mult = 1.0
	d.base = st
	ContentDB.inject(ContentDB.WEAPONS, id, d)
	return d


func _npc(pos: Vector3, facing: Vector3 = Vector3.BACK) -> NpcBase:
	var n: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", pos, facing)
	for nm: String in ["Brain", "Motor", "Gunner"]:
		var c: Node = n.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
	n.max_health = 100000.0
	n.health = 100000.0
	return n


func _events_for(n: NpcBase, type: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		var info: Dictionary = e["info"]
		if int(e["victim"]) == n.net_id and (type < 0 or int(info["type"]) == type):
			out.append(info)
	return out


## Hold the trigger of crew `slot` aimed at `point` for `frames`, then release for `after` frames.
func _hold(slot: int, point: Vector3, frames: int, after: int = 6) -> void:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), point)
	aim.fire = true
	_rt.set_bot_intent(slot, aim)
	await wait_physics_frames(frames)
	var rel: CrewIntent = BotUtil.look_at_intent(c.eye_position(), point)
	_rt.set_bot_intent(slot, rel)
	await wait_physics_frames(after)


func _arm(id: StringName) -> CrewWeapons:
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, id)
	await wait_physics_frames(int(ceil(w.stats(Enums.WeaponSlot.PRIMARY).equip_time_s * 60.0)) + 4)
	return w


func test_params_merge_and_kind() -> void:
	var m: WeaponModDef = WeaponModDef.new()
	m.id = &"mod.test_explosive_arrow"
	m.mod_type = Enums.ModType.AMMO
	m.delta = WeaponStats.make_delta()
	m.params = {"explosion": {"radius_m": 2.0}}
	ContentDB.inject(ContentDB.MODS, m.id, m)
	var d: WeaponDef = _def(&"weapon.test_bow", [&"charge"], {"charge": {"draw_time_s": 0.5}, "projectile": {"speed_mps": 50.0}})
	d.mod_slots = {Enums.ModType.AMMO: [m.id]}
	var plain: Dictionary = SpecialWeapons.params_of(d)
	assert_eq(SpecialWeapons.kind_of(plain), SpecialWeapons.KIND_PROJECTILE, "projectile kind")
	assert_false(plain.has("explosion"), "no explosion without the mod")
	var modded: Dictionary = SpecialWeapons.params_of(d, [m.id] as Array[StringName])
	assert_near(float(SpecialWeapons.block(modded, "explosion").get("radius_m", 0.0)), 2.0, 0.001, "mod params merged")
	assert_near(SpecialWeapons.charge_mult({"charge": {"min_damage_mult": 0.2}}, 0.5, "min_damage_mult"), 0.6, 0.001)
	assert_eq(SpecialWeapons.kind_of({"flame": {}}), SpecialWeapons.KIND_FLAME)
	assert_eq(SpecialWeapons.kind_of({}), SpecialWeapons.KIND_HITSCAN, "plain guns stay hitscan")


func test_flame_cone_fire_damage_and_burn() -> void:
	_def(&"weapon.test_flame", [&"auto"], {"flame": {"range_m": 10.0, "cone_deg": 30.0, "dot_damage_per_s": 20.0,
		"dot_duration_s": 2.0, "panic_chance": 1.0, "panic_s": 1.0}}, 100)
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = await _arm(&"weapon.test_flame")
	var front: NpcBase = _npc(Vector3(0, 0.05, -5))
	var side: NpcBase = _npc(Vector3(6, 0.05, 0))
	var far: NpcBase = _npc(Vector3(0, 0.05, -14))
	await wait_physics_frames(3)
	await _hold(0, CombatSystem.target_center(front), 3, 2)
	var ev: Array[Dictionary] = _events_for(front, Enums.DamageType.FIRE)
	assert_true(ev.size() >= 1, "flame hits inside the cone")
	if not ev.is_empty():
		assert_true(bool(ev[0].get("pierced_armor", false)), "L3.4: fire ignores armor")
	assert_eq(_events_for(side).size(), 0, "outside the cone")
	assert_eq(_events_for(far).size(), 0, "beyond range")
	assert_true(front.get_node_or_null(BurnStatus.NODE_NAME) != null, "the target burns")
	assert_true(front.is_stunned(), "panic roll at chance 1 stuns")
	assert_true(w.mag(Enums.WeaponSlot.PRIMARY) < 100, "flame uses fuel")
	var before: int = _events_for(front, Enums.DamageType.FIRE).size()
	await wait_physics_frames(70)
	assert_true(_events_for(front, Enums.DamageType.FIRE).size() > before, "DoT keeps burning after the trigger")
	assert_true(c != null)


func test_saw_cuts_only_on_contact_and_wears_the_blade() -> void:
	_def(&"weapon.test_saw", [&"auto"], {"saw": {"range_m": 1.8, "wear_per_tick_npc": 2.0}}, 40)
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = await _arm(&"weapon.test_saw")
	await _hold(0, Vector3(0, 1.4, -10), 10)
	assert_eq(w.mag(Enums.WeaponSlot.PRIMARY), 40, "cutting air costs no blade")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -1.2))
	await wait_physics_frames(3)
	await _hold(0, CombatSystem.target_center(npc), 2, 2)
	var ev: Array[Dictionary] = _events_for(npc)
	assert_true(ev.size() >= 1, "the saw cuts an enemy in reach")
	if not ev.is_empty():
		assert_true(bool(ev[0].get("pierced_armor", false)), "the saw ignores armor")
	var used: int = 40 - w.mag(Enums.WeaponSlot.PRIMARY)
	assert_eq(used, ev.size() * 2, "wear_per_tick_npc rounds per cutting tick")


func test_bow_draw_projectile_hit_and_retrieve() -> void:
	_def(&"weapon.test_bow", [&"charge"], {"charge": {"draw_time_s": 0.2, "min_damage_mult": 0.25, "min_speed_mult": 0.5},
		"projectile": {"speed_mps": 70.0, "gravity_mult": 0.0, "retrievable": true, "pickup_radius_m": 1.0}}, 1)
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = await _arm(&"weapon.test_bow")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -8))
	await wait_physics_frames(3)
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(npc))
	aim.fire = true
	_rt.set_bot_intent(0, aim)
	await wait_physics_frames(20)
	assert_near(w.charge, 1.0, 0.001, "full draw after draw_time_s")
	_rt.hud_model.refresh()
	assert_near(_rt.hud_model.weapon_charge, 1.0, 0.001, "ui_hud v1.5 weapon_charge")
	assert_eq(w.mag(Enums.WeaponSlot.PRIMARY), 1, "holding the draw does not shoot")
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(npc)))
	await wait_physics_frames(3)
	assert_eq(w.mag(Enums.WeaponSlot.PRIMARY), 0, "release looses the arrow")
	assert_eq(get_tree().get_nodes_in_group(WeaponProjectile.GROUP).size(), 1, "one projectile in flight")
	await wait_physics_frames(15)
	var ev: Array[Dictionary] = _events_for(npc, Enums.DamageType.BULLET)
	assert_eq(ev.size(), 1, "the arrow hits once")
	if ev.size() == 1:
		assert_near(float(ev[0]["amount"]), 40.0, 0.5, "full-draw damage")
	var arrows: Array[Node] = get_tree().get_nodes_in_group(WeaponProjectile.GROUP)
	assert_eq(arrows.size(), 1, "a retrievable arrow stays")
	if arrows.size() == 1:
		assert_true((arrows[0] as WeaponProjectile).stuck, "stuck where it landed")
		var reserve: int = w.reserve(Enums.WeaponSlot.PRIMARY)
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, (arrows[0] as Node3D).global_position - Vector3(0, 0.9, 0)))
		await wait_physics_frames(3)
		assert_eq(w.reserve(Enums.WeaponSlot.PRIMARY), reserve + 1, "walking over it returns the arrow")
		assert_eq(get_tree().get_nodes_in_group(WeaponProjectile.GROUP).size(), 0, "picked up")


func test_launcher_blast_on_impact() -> void:
	var gl: WeaponDef = _def(&"weapon.test_gl", [&"semi"], {"projectile": {"speed_mps": 40.0, "gravity_mult": 0.0},
		"explosion": {"radius_m": 3.0}}, 6)
	gl.anim_set = &"launcher"
	var cues: Array[StringName] = []
	var cue_cb: Callable = ACombatSpecials.record_cues(cues)
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	await _arm(&"weapon.test_gl")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -10))
	var side: NpcBase = _npc(Vector3(1.5, 0.05, -10))
	await wait_physics_frames(3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	await wait_physics_frames(20)
	assert_eq(_events_for(npc, Enums.DamageType.EXPLOSION).size(), 1, "L3.6: impact explodes")
	assert_eq(_events_for(side, Enums.DamageType.EXPLOSION).size(), 1, "splash hits a neighbour")
	assert_eq(get_tree().get_nodes_in_group(WeaponProjectile.GROUP).size(), 0, "grenade gone")
	EventBus.audio_cue_requested.disconnect(cue_cb)
	assert_has(cues, &"cue.weapon_launcher_explode", "audio_cues v1.1 launcher explode cue")


func test_minigun_spins_up_before_firing_and_slows_the_crew() -> void:
	_def(&"weapon.test_minigun", [&"auto"], {"spin": {"spin_up_s": 0.5, "spin_down_s": 0.5, "move_speed_mult": 0.4}}, 200)
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = await _arm(&"weapon.test_minigun")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), Vector3(0, 1.4, -10))
	aim.fire = true
	_rt.set_bot_intent(0, aim)
	await wait_physics_frames(15)
	assert_eq(w.mag(Enums.WeaponSlot.PRIMARY), 200, "no shots while spinning up")
	assert_near(w.move_speed_mult, 0.4, 0.001, "slowed while spinning")
	_rt.hud_model.refresh()
	assert_true(_rt.hud_model.weapon_spin > 0.0, "ui_hud v1.5 weapon_spin")
	await wait_physics_frames(30)
	assert_true(w.mag(Enums.WeaponSlot.PRIMARY) < 200, "fires once spun up")
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), Vector3(0, 1.4, -10)))
	await wait_physics_frames(45)
	assert_near(w.spin, 0.0, 0.001, "spins down")
	assert_near(w.move_speed_mult, 1.0, 0.001, "speed restored")


func test_parts_animator_drives_named_parts() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var vis: FakeVisual = FakeVisual.new()
	for nm: String in ["Rotor", "Breech"]:
		var p: Node3D = Node3D.new()
		p.name = nm
		vis.add_child(p)
	add_child(vis)
	var bare: Node3D = Node3D.new()
	assert_true(WeaponPartsAnimator.attach(bare, c.weapons) == null, "needs a get_marker visual")
	bare.free()
	var a: WeaponPartsAnimator = WeaponPartsAnimator.attach(vis, c.weapons)
	assert_true(a != null and a.has_part(&"Rotor") and a.has_part(&"Breech") and not a.has_part(&"Lever"), "parts found")
	c.weapons.spin = 1.0
	c.weapons.reloading = true
	c.weapons.reload_left = 100.0
	var rotor: Node3D = vis.get_node("Rotor") as Node3D
	var breech: Node3D = vis.get_node("Breech") as Node3D
	var open_x: float = -deg_to_rad(FpViewmodelTweak.data().breech_open_deg)
	# The ramp is delta-timed: poll for the open breech instead of counting frames (flaked under load).
	var opened: Callable = func() -> bool:
		return absf(breech.rotation.x - open_x) < 0.005 and rotor.transform.basis.get_euler().length() > 0.01
	await wait_until(opened, 3.0)
	assert_true(rotor.transform.basis.get_euler().length() > 0.01, "Rotor spins with the minigun spin")
	assert_near(breech.rotation.x, open_x, 0.01, "Breech open while reloading")
	c.weapons.spin = 0.0
	c.weapons.reloading = false
	vis.queue_free()


## D-070: bow pull-back turns StringUpper negative / StringLower positive; a crossbow latches its halves while
## a bolt is loaded (Upper -18.74 deg, Lower +, x1.3049 along Y); the revolver Speedloader shows only reloading.
func test_d070_string_halves_and_speedloader() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var vis: FakeVisual = FakeVisual.new()
	for nm: String in ["StringUpper", "StringLower", "Speedloader"]:
		var p: Node3D = Node3D.new()
		p.name = nm
		vis.add_child(p)
	add_child(vis)
	var a: WeaponPartsAnimator = WeaponPartsAnimator.attach(vis, c.weapons)
	var up: Node3D = vis.get_node("StringUpper") as Node3D
	var lo: Node3D = vis.get_node("StringLower") as Node3D
	var sl: Node3D = vis.get_node("Speedloader") as Node3D
	a.crossbow = false
	c.weapons.charge = 1.0
	await wait_frames(2)
	assert_true(up.rotation.x < -0.01 and lo.rotation.x > 0.01, "bow pull-back: Upper negative, Lower positive")
	c.weapons.charge = 0.0
	await wait_frames(2)
	assert_false(sl.visible, "Speedloader hidden at rest")
	a.crossbow = true
	var ws: int = c.weapons.equipped_slot
	c.weapons.set_ammo(ws, 1, 10)
	await wait_frames(2)
	assert_near(up.rotation.x, -deg_to_rad(tw.crossbow_latch_deg), 0.01, "latched: Upper -18.74 deg")
	assert_near(lo.rotation.x, deg_to_rad(tw.crossbow_latch_deg), 0.01, "latched: Lower +18.74 deg")
	assert_near(up.transform.basis.get_scale().y, tw.crossbow_latch_stretch, 0.01, "stretched along local Y")
	c.weapons.set_ammo(ws, 0, 10)
	await wait_frames(2)
	assert_near(up.rotation.x, 0.0, 0.001, "shot: relaxed")
	c.weapons.reloading = true
	c.weapons.reload_left = 100.0
	await wait_seconds(tw.crossbow_latch_s + 0.2)
	assert_near(lo.rotation.x, deg_to_rad(tw.crossbow_latch_deg), 0.01, "latched by the reload")
	assert_true(sl.visible, "Speedloader shown while reloading")
	c.weapons.reloading = false
	vis.queue_free()


## A4-04 batch 1 (ratchet UNTESTED): weapon.saw_damage_mult / weapon.saw_wear_mult / weapon.saw_shield_pierce
## (class-qualified keys: granted as "<key>.all").
func _saw_tick(params: Dictionary, grants: Dictionary) -> Array:
	for k: String in grants:
		Modifiers.set_source(0, &"test.saw", {StringName(k + ".all"): grants[k]})
	_def(&"weapon.test_saw", [&"auto"], {"saw": params}, 40)
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = await _arm(&"weapon.test_saw")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -1.2))
	await wait_physics_frames(3)
	await _hold(0, CombatSystem.target_center(npc), 2, 2)
	Modifiers.clear_source(0, &"test.saw")
	return [_events_for(npc), 40 - w.mag(Enums.WeaponSlot.PRIMARY)]


func test_a4_04_saw_damage_mult() -> void:
	var r: Array = await _saw_tick({"range_m": 1.8}, {"weapon.saw_damage_mult": 2.0})
	var ev: Array[Dictionary] = r[0]
	assert_true(not ev.is_empty(), "the saw cut")
	if not ev.is_empty():
		assert_near(float(ev[0]["amount"]), 80.0, 0.5, "x2 saw damage (40 base)")


func test_a4_04_saw_wear_mult() -> void:
	var r: Array = await _saw_tick({"range_m": 1.8, "wear_per_tick_npc": 2.0}, {"weapon.saw_wear_mult": 0.5})
	var ev: Array[Dictionary] = r[0]
	assert_true(not ev.is_empty(), "the saw cut")
	assert_eq(int(r[1]), ev.size(), "wear 2 x 0.5 = one round per cutting tick")


func test_a4_04_saw_shield_pierce() -> void:
	var r: Array = await _saw_tick({"range_m": 1.8, "shield_pierce": false}, {})
	var ev: Array[Dictionary] = r[0]
	assert_true(not ev.is_empty() and not bool(ev[0].get("shield_pierce", true)), "a blade without shield pierce")
	_events.clear()
	var r2: Array = await _saw_tick({"range_m": 1.8, "shield_pierce": false}, {"weapon.saw_shield_pierce": true})
	var ev2: Array[Dictionary] = r2[0]
	assert_true(not ev2.is_empty() and bool(ev2[0].get("shield_pierce", false)), "the skill flag pierces shields")
