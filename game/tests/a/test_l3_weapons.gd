## A1-08 weapons: L3.8 hit claims (headshot kill), S3.6 one-shot via a real bullet, S4.3/L3.7 gunshot
## noise vs suppressor, S1.1 no firing while casing, semi trigger, RPM cap, reload, L3.2 falloff,
## weapon.damage_mult (A1-12 key).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0)})
	await wait_physics_frames(1)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


## Crew 3 m behind the guard (guard faces -Z), masked.
func _behind_guard(dist: float = 3.0) -> CrewController:
	var c: CrewController = _crew()
	var g: NpcBase = _guard()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0, dist)))
	await wait_physics_frames(3)
	return c


## One trigger pull: press for `frames` physics frames, then release.
func _pull(intent: CrewIntent, frames: int = 2) -> void:
	intent.fire = true
	_rt.set_bot_intent(0, intent)
	await wait_physics_frames(frames)
	var rel: CrewIntent = CrewIntent.new()
	rel.look_yaw = intent.look_yaw
	rel.look_pitch = intent.look_pitch
	_rt.set_bot_intent(0, rel)
	await wait_physics_frames(1)


func _sky_intent() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_pitch = deg_to_rad(60.0)
	return i


func _unsuppressed_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	l.secondary = &"weapon.kestrel_p9"
	return CrewWeapons.build_loadout(l)


func test_a1_08_default_loadout_is_suppressed_kestrel() -> void:
	var c: CrewController = _crew()
	assert_true(c.weapons != null and c.health != null, "Weapons + Health components")
	var w: CrewWeapons = c.weapons
	assert_eq(w.weapon_id(Enums.WeaponSlot.SECONDARY), &"weapon.kestrel_p9")
	assert_true(w.is_suppressed(Enums.WeaponSlot.SECONDARY), "default kestrel has the suppressor (D-025)")
	assert_eq(w.equipped_slot, Enums.WeaponSlot.SECONDARY, "no primary -> secondary equipped")
	var st: WeaponStats = w.stats(Enums.WeaponSlot.SECONDARY)
	assert_eq(w.mag(Enums.WeaponSlot.SECONDARY), st.mag_size, "full magazine")
	assert_eq(w.reserve(Enums.WeaponSlot.SECONDARY), st.total_ammo - st.mag_size, "reserve = total - mag")
	assert_eq(c.loadout.armor, &"armor.tailored_suit", "resolved default stored on crew.loadout")
	assert_true(c.loadout.resolved_secondary != null)


func test_l3_8_bot_headshot_kills_guard_via_hit_claim() -> void:
	var c: CrewController = await _behind_guard(3.0)
	var g: NpcBase = _guard()
	var kills: Array[Dictionary] = []
	var cb: Callable = func(_n: int, killer: int, info: Dictionary) -> void:
		kills.append({"killer": killer, "info": info})
	EventBus.npc_killed.connect(cb)
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), g.head_position())
	await _pull(aim)
	EventBus.npc_killed.disconnect(cb)
	assert_false(g.alive, "guard dead")
	assert_eq(kills.size(), 1, "npc_killed once")
	if kills.size() == 1:
		assert_eq(int(kills[0]["killer"]), c.net_id, "killer = shooter net id")
		var info: Dictionary = kills[0]["info"]
		assert_eq(int(info["zone"]), Enums.HitZone.HEAD, "headshot zone")
		assert_eq(int(info["type"]), Enums.DamageType.BULLET)
		assert_eq(StringName(info["weapon_id"]), &"weapon.kestrel_p9")
	assert_eq(c.weapons.shots_fired, 1, "one shot")


func test_s3_6_calm_guard_dies_to_body_shot() -> void:
	var c: CrewController = await _behind_guard(3.0)
	var g: NpcBase = _guard()
	assert_eq(g.alert_state, Enums.AlertState.CALM)
	var body: Vector3 = g.global_position + Vector3(0, 0.9, 0)
	var dmg: Array[Dictionary] = []
	var cb: Callable = func(_v: int, _a: int, info: Dictionary) -> void: dmg.append(info)
	EventBus.damage_applied.connect(cb)
	await _pull(BotUtil.look_at_intent(c.eye_position(), body))
	EventBus.damage_applied.disconnect(cb)
	assert_false(g.alive, "calm guard one-shot by a body hit")
	assert_true(dmg.size() == 1 and int(dmg[0]["zone"]) == Enums.HitZone.BODY, "body zone")


func test_s4_3_unsuppressed_shot_is_45m_noise_suppressed_is_not() -> void:
	var c: CrewController = await _behind_guard(10.0)
	var radii: Array[float] = []
	var fired: Array[bool] = []
	var cb: Callable = func(_p: Vector3, r: float, kind: StringName, src: int) -> void:
		if kind == &"gunshot" and src == c.net_id:
			radii.append(r)
	var fcb: Callable = func(src: int, _w: StringName, suppressed: bool, _p: Vector3) -> void:
		if src == c.net_id:
			fired.append(suppressed)
	_rt.noise_made.connect(cb)
	EventBus.weapon_fired.connect(fcb)
	await _pull(_sky_intent())
	assert_eq(fired, [true] as Array[bool], "weapon_fired(suppressed=true)")
	for r: float in radii:
		assert_true(r <= 1.0, "suppressed shot noise <= 1 m (got %f)" % r)
	radii.clear()
	c.weapons.set_loadout(_unsuppressed_loadout())
	await wait_seconds(0.2)
	await _pull(_sky_intent())
	assert_eq(radii.size(), 1, "one noise event")
	if radii.size() == 1:
		assert_near(radii[0], Tweak.stealth().gunshot_player_radius_m, 0.001, "45 m player gunshot")
	assert_near(Tweak.stealth().gunshot_player_radius_m, 45.0, 0.001)
	_rt.noise_made.disconnect(cb)
	EventBus.weapon_fired.disconnect(fcb)


func test_s1_1_casing_crew_cannot_fire() -> void:
	var c: CrewController = _crew()
	assert_true(c.is_casing())
	var fired: Array[int] = []
	var fcb: Callable = func(src: int, _w: StringName, _s: bool, _p: Vector3) -> void: fired.append(src)
	EventBus.weapon_fired.connect(fcb)
	await _pull(_sky_intent(), 5)
	EventBus.weapon_fired.disconnect(fcb)
	assert_eq(c.weapons.shots_fired, 0, "no shot while casing")
	assert_true(fired.is_empty(), "no weapon_fired")
	assert_eq(c.weapons.mag(Enums.WeaponSlot.SECONDARY), c.weapons.mag_size(Enums.WeaponSlot.SECONDARY), "no ammo used")


func test_l3_semi_held_trigger_fires_once() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var i: CrewIntent = _sky_intent()
	i.fire = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(1.0)
	_rt.clear_bot_intent(0)
	assert_eq(c.weapons.shots_fired, 1, "semi: one shot per press")


func test_l3_rpm_caps_fire_rate() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var on: CrewIntent = _sky_intent()
	on.fire = true
	var off: CrewIntent = _sky_intent()
	var frames: int = Engine.physics_ticks_per_second  # 1 s of presses every other frame
	for k: int in range(frames):
		_rt.set_bot_intent(0, on if k % 2 == 0 else off)
		await wait_physics_frames(1)
	_rt.clear_bot_intent(0)
	var rpm: float = c.weapons.stats(Enums.WeaponSlot.SECONDARY).fire_rate_rpm
	var cap: int = int(ceil(rpm / 60.0)) + 1
	assert_true(c.weapons.shots_fired <= cap, "<= %d shots in 1 s at %d rpm (got %d)" % [cap, rpm, c.weapons.shots_fired])
	assert_true(c.weapons.shots_fired >= int(rpm / 60.0) - 2, "but close to the rpm (got %d)" % c.weapons.shots_fired)


func test_l3_reload_refills_from_reserve_with_tactical_and_empty_times() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var w: CrewWeapons = c.weapons
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = w.stats(ws)
	for k: int in range(3):
		await _pull(_sky_intent())
		await wait_seconds(0.15)
	assert_eq(w.mag(ws), st.mag_size - 3, "3 rounds used")
	var reserve0: int = w.reserve(ws)
	var r: CrewIntent = CrewIntent.new()
	r.reload = true
	_rt.set_bot_intent(0, r)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_true(w.reloading, "reloading")
	assert_near(w.reload_left, st.reload_time_s, 0.05, "tactical reload time")
	await wait_seconds(st.reload_time_s - 0.25)
	assert_true(w.reloading and w.mag(ws) == st.mag_size - 3, "not done before the reload time")
	await wait_seconds(0.4)
	assert_false(w.reloading, "reload done")
	assert_eq(w.mag(ws), st.mag_size, "mag full")
	assert_eq(w.reserve(ws), reserve0 - 3, "taken from reserve")
	# Empty: a dry trigger pull starts the (longer) empty reload.
	w.set_ammo(ws, 0, 5)
	await _pull(_sky_intent())
	assert_true(w.reloading, "dry fire starts a reload")
	assert_near(w.reload_left, st.reload_empty_time_s, 0.1, "empty reload time")
	await wait_seconds(st.reload_empty_time_s + 0.2)
	assert_eq(w.mag(ws), 5, "only what the reserve had")
	assert_eq(w.reserve(ws), 0)


func test_l3_2_falloff_reduces_damage_at_range() -> void:
	var w: CrewWeapons = _crew().weapons
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = w.stats(ws)
	assert_near(CombatSystem.falloff_mult(st, st.falloff_start_m - 1.0), 1.0, 0.0001, "no falloff before start")
	var mid: float = (st.falloff_start_m + st.falloff_end_m) * 0.5
	assert_near(CombatSystem.falloff_mult(st, mid), lerpf(1.0, st.falloff_min_mult, 0.5), 0.0001, "linear")
	assert_near(CombatSystem.falloff_mult(st, st.falloff_end_m + 50.0), st.falloff_min_mult, 0.0001, "min past end")
	assert_true(w.damage_at(ws, st.falloff_end_m + 5.0) < w.damage_at(ws, 2.0), "less damage at range")
	assert_near(w.damage_at(ws, 2.0), st.damage, 0.0001, "full damage up close")
	var sniper: WeaponStats = WeaponStats.new()
	sniper.falloff_start_m = 10.0
	sniper.falloff_end_m = 50.0
	sniper.falloff_min_mult = 1.5
	assert_true(CombatSystem.falloff_mult(sniper, 60.0) > 1.0, "snipers gain damage with range (min_mult > 1)")


func test_a1_08_weapon_damage_mult_modifier_changes_damage() -> void:
	var c: CrewController = await _behind_guard(3.0)
	var g: NpcBase = _guard()
	g.notify_crew_spotted(c)  # ALARMED: no one-shot rule
	await wait_physics_frames(1)
	var ws: int = Enums.WeaponSlot.SECONDARY
	var base: float = c.weapons.damage_at(ws, 3.0)
	Modifiers.set_source(0, &"test", {&"weapon.damage_mult.pistol": 1.5})
	assert_near(c.weapons.damage_at(ws, 3.0), base * 1.5, 0.0001, "pistol-qualified mult applies")
	Modifiers.set_source(0, &"test", {&"weapon.damage_mult.shotgun": 3.0})
	assert_near(c.weapons.damage_at(ws, 3.0), base, 0.0001, "other class does not")
	Modifiers.set_source(0, &"test", {&"weapon.damage_mult.all": 0.5})
	var dmg: Array[float] = []
	var cb: Callable = func(v: int, _a: int, info: Dictionary) -> void:
		if v == g.net_id:
			dmg.append(float(info["amount"]))
	EventBus.damage_applied.connect(cb)
	await _pull(BotUtil.look_at_intent(c.eye_position(), g.global_position + Vector3(0, 0.9, 0)))
	EventBus.damage_applied.disconnect(cb)
	assert_eq(dmg.size(), 1, "hit")
	if dmg.size() == 1:
		assert_near(dmg[0], base * 0.5, 0.01, "damage_applied amount scaled by weapon.damage_mult.all")
	assert_true(g.alive, "alerted guard survives a half-damage body shot")
	assert_near(g.health, g.max_health - base * 0.5, 0.01)


func test_l3_8_server_rejects_bad_claims() -> void:
	var c: CrewController = await _behind_guard(3.0)
	var g: NpcBase = _guard()
	var w: CrewWeapons = c.weapons
	var claim: Dictionary = {
		"seq": 1000, "weapon_slot": Enums.WeaponSlot.SECONDARY, "weapon_id": &"weapon.kestrel_p9",
		"origin": c.eye_position() + Vector3(0, 0, 10), "direction": Vector3.FORWARD,
		"hits": [{"target_id": g.net_id, "zone": Enums.HitZone.HEAD, "distance": 3.0, "position": g.head_position()}],
	}
	var res: Dictionary = CombatSystem.validate_and_apply(claim, c)
	assert_false(bool(res["accepted"]), "origin far from the shooter's eye is rejected")
	assert_eq(StringName(res["reason"]), &"origin")
	claim["origin"] = c.eye_position()
	claim["weapon_id"] = &"weapon.other"
	assert_eq(StringName(CombatSystem.validate_and_apply(claim, c)["reason"]), &"weapon", "wrong weapon id")
	claim["weapon_id"] = &"weapon.kestrel_p9"
	w.set_ammo(Enums.WeaponSlot.SECONDARY, 0, 10)
	assert_eq(StringName(CombatSystem.validate_and_apply(claim, c)["reason"]), &"ammo", "empty magazine")
	w.set_ammo(Enums.WeaponSlot.SECONDARY, 5, 10)
	var wall: StaticBody3D = ATestMaps.add_wall(_rt.map, c.global_position + Vector3(0, 1.5, -1.5), Vector3(4, 3, 0.2))
	await wait_physics_frames(2)
	var res2: Dictionary = CombatSystem.validate_and_apply(claim, c)
	assert_true(bool(res2["accepted"]), "shot itself accepted")
	assert_true((res2["results"] as Array).is_empty(), "hit behind a wall is not applied (LOS)")
	assert_true(g.alive)
	wall.queue_free()
	await wait_physics_frames(2)
	claim["seq"] = 1000
	assert_eq(StringName(CombatSystem.validate_and_apply(claim, c)["reason"]), &"stale_seq", "replayed seq")
	claim["seq"] = 1001
	assert_eq(StringName(CombatSystem.validate_and_apply(claim, c)["reason"]), &"rate", "faster than the RPM")
	await wait_seconds(0.2)
	claim["seq"] = 1002
	assert_true(bool(CombatSystem.validate_and_apply(claim, c)["accepted"]), "valid claim")
	assert_false(g.alive, "applied")


## A plain Node3D with `take_hit` (no net id, no hitbox script) wrapping a world-layer body.
static func make_take_hit_target(parent: Node, pos: Vector3) -> Node3D:
	var gs: GDScript = GDScript.new()
	gs.source_code = """extends Node3D
var hits: Array[Dictionary] = []
var attackers: Array[int] = []


func take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	hits.append(info)
	attackers.append(attacker_net_id)
	var out: Dictionary = info.duplicate()
	out["killed"] = false
	return out
"""
	gs.reload()
	var t: Node3D = Node3D.new()
	t.set_script(gs)
	t.name = "TakeHitTarget"
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 0.2)
	cs.shape = box
	body.add_child(cs)
	t.add_child(body)
	parent.add_child(t)
	t.global_position = pos
	return t


func test_l3_8_headshot_single_take_hit_path_with_bonus() -> void:
	var c: CrewController = await _behind_guard(3.0)
	var g: NpcBase = _guard()
	g.notify_crew_spotted(c)  # ALARMED: no one-shot rule, so the zone multiplier is visible
	await wait_physics_frames(1)
	var events: Array[Dictionary] = []
	var cb: Callable = func(v: int, a: int, info: Dictionary) -> void:
		if v == g.net_id:
			events.append({"a": a, "info": info})
	EventBus.damage_applied.connect(cb)
	var ws: int = Enums.WeaponSlot.SECONDARY
	var dist: float = c.eye_position().distance_to(g.head_position())
	var expected: float = c.weapons.damage_at(ws, dist) * g.enemy_def.headshot_mult[Enums.Difficulty.ROUTINE] \
		* c.weapons.headshot_bonus(ws)
	await _pull(BotUtil.look_at_intent(c.eye_position(), g.head_position()))
	EventBus.damage_applied.disconnect(cb)
	assert_eq(events.size(), 1, "exactly one damage_applied (emitted by the target only)")
	if events.size() == 1:
		var info: Dictionary = events[0]["info"]
		assert_eq(int(info["zone"]), Enums.HitZone.HEAD, "head zone via Hitbox.get_hit_zone()")
		assert_eq(int(events[0]["a"]), c.net_id)
		assert_near(float(info["headshot_bonus"]), c.weapons.headshot_bonus(ws), 0.0001, "bonus carried in info")
		assert_near(float(info["amount"]), expected, 0.05, "body x EnemyDef head mult x weapon bonus")
	var hb: Node = g.get_node("Hitboxes/Head")
	assert_true(hb is Hitbox and Damage.find_target(hb) == g, "Hitbox routes to the NPC")
	assert_eq(Damage.zone_of(hb), Enums.HitZone.HEAD)


func test_a1_08_plain_take_hit_target_is_hit() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var t: Node3D = make_take_hit_target(_rt.map, Vector3(0, 1.0, -4))
	await wait_physics_frames(3)
	var dmg_events: Array[int] = []
	var cb: Callable = func(v: int, _a: int, _i: Dictionary) -> void: dmg_events.append(v)
	EventBus.damage_applied.connect(cb)
	await _pull(BotUtil.look_at_intent(c.eye_position(), Vector3(0, 1.0, -4)))
	EventBus.damage_applied.disconnect(cb)
	var hits: Array = t.get(&"hits")
	assert_eq(hits.size(), 1, "take_hit called exactly once")
	if hits.size() == 1:
		var info: Dictionary = hits[0]
		assert_near(float(info["amount"]), c.weapons.damage_at(Enums.WeaponSlot.SECONDARY, 4.0), 0.5, "body damage")
		assert_eq(int(info["attacker_net_id"]), c.net_id)
		assert_eq((t.get(&"attackers") as Array)[0], c.net_id)
	assert_true(dmg_events.is_empty(), "the shooter never emits damage_applied")
