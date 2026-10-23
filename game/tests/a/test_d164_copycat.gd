## D-164 perk.copycat on B's names: tactical reload (kills per weapon slot refill the holstered magazine, a quick swap
## window), headshot heal (any headshot hit, cooldown), dodge ricochet (back at the shooter, cooldown, the top
## difficulties' shorter one), low-health grace (health immunity only, cooldown); and every perk component tolerates
## a partial (mimicked card-9) dict.
extends TestCase

var _rt: HeistRuntime = null
var _victim_id: int = 8700


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1650, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _grant(p: Dictionary, dodge: float = -1.0) -> PerkCopycat:
	Modifiers.set_source(0, &"deck", {PerkCopycat.KEY: p, &"defense.dodge_add": dodge})
	var perks: CrewPerks = PerkHooks.of(_crew())
	perks.refresh()
	return perks.component(PerkCopycat.KEY) as PerkCopycat


func _kill() -> void:
	_victim_id += 1
	EventBus.npc_killed.emit(_victim_id, _crew().net_id, {"type": Enums.DamageType.BULLET})


func _enemy(z: float = -15.0) -> NpcBase:
	var n: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, _crew().global_position + Vector3(0, 0, z)))
	n.get_node("Brain").set_physics_process(false)
	return n


func test_tactical_reload_and_quick_swap() -> void:
	_grant({"tactical_reload_kills": 10, "quick_swap_window_s": 3.0})
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.corsair_ar"
	l.secondary = &"weapon.kestrel_p9"
	_crew().set_loadout(l)
	var w: CrewWeapons = _crew().weapons
	var p: int = Enums.WeaponSlot.PRIMARY
	var s: int = Enums.WeaponSlot.SECONDARY
	if not (w.has_weapon(p) and w.has_weapon(s)):
		skip("the test loadout lacks a primary and a secondary")
		return
	w.equip(p)
	w.set_ammo(s, 0, 200)
	for _i: int in 9:
		_kill()
	assert_eq(w.mag(s), 0, "9 kills: not yet")
	_kill()
	assert_eq(w.mag(s), w.mag_size(s), "10 kills with the primary refill the secondary")
	assert_eq(w.reserve(s), 200 - w.mag_size(s), "from its reserve")
	var normal: float = w.stats(s).equip_time_s
	w.equip(s)
	assert_true(w._equip_left < normal * 0.2, "a swap to it within 3 s is near-instant (%.3f s)" % w._equip_left)
	w.set_ammo(p, 0, 200)
	_kill()
	assert_eq(w.mag(p), 0, "the secondary's own counter starts at 0")


func test_headshot_heal_any_hit_with_cooldown() -> void:
	var c: PerkCopycat = _grant({"headshot_heal": 10.0, "headshot_heal_cooldown_s": 2.0})
	var h: CrewHealth = _crew().health
	var npc: NpcBase = _enemy()
	h.health = h.max_health - 50.0
	npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"test", npc.global_position,
		Vector3.FORWARD), _crew().net_id)
	assert_near(h.health, h.max_health - 40.0, 0.01, "a headshot hit heals 10")
	npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"test", npc.global_position,
		Vector3.FORWARD), _crew().net_id)
	assert_near(h.health, h.max_health - 40.0, 0.01, "not again within 2 s")
	c.heal_cd = 0.0
	npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", npc.global_position,
		Vector3.FORWARD), _crew().net_id)
	assert_near(h.health, h.max_health - 40.0, 0.01, "a body hit: nothing")


func test_dodge_ricochet_back_at_the_shooter() -> void:
	var c: PerkCopycat = _grant({"dodge_ricochet": true, "ricochet_cooldown_s": 0.45}, 1.0)
	var shooter: NpcBase = _enemy()
	var other: NpcBase = _enemy(-5.0)
	var hp: float = shooter.health
	var hp_other: float = other.health
	_crew().health.grace_left = 0.0
	var out: Dictionary = _crew().take_hit(Damage.info(8.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		_crew().global_position, Vector3.FORWARD), shooter.net_id)
	assert_true(bool(out.get("dodged", false)), "dodged")
	assert_true(shooter.health < hp, "the shooter takes the bullet back (%.1f -> %.1f)" % [hp, shooter.health])
	assert_near(other.health, hp_other, 0.001, "not the nearest enemy")
	var after: float = shooter.health
	_crew().health.grace_left = 0.0
	_crew().take_hit(Damage.info(8.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", _crew().global_position,
		Vector3.FORWARD), shooter.net_id)
	assert_near(shooter.health, after, 0.001, "once per 0.45 s")
	assert_near(c.ricochet_cooldown(), 0.45, 0.0001)
	_rt.difficulty = Enums.Difficulty.LETHAL
	assert_near(c.ricochet_cooldown(), 0.35, 0.0001, "0.35 s on the top two difficulties")


func test_grace_health_immunity_below_threshold() -> void:
	var c: PerkCopycat = _grant({"grace_health_threshold": 0.5, "grace_immunity_s": 2.0, "grace_cooldown_s": 15.0})
	var h: CrewHealth = _crew().health
	h.health = h.max_health * 0.6
	h.armor = 0.0
	_hit(h, h.max_health * 0.2)
	assert_near(h.health, h.max_health * 0.4, 0.01, "the crossing hit applies")
	assert_true(c.grace_left > 1.9, "then 2 s of grace")
	_hit(h, 30.0)
	assert_near(h.health, h.max_health * 0.4, 0.01, "no health damage in the grace")
	h.armor = 10.0
	_hit(h, 5.0)
	assert_near(h.armor, 5.0, 0.01, "armor still takes hits")
	assert_near(h.health, h.max_health * 0.4, 0.01)
	c.grace_left = 0.0
	h.health = h.max_health * 0.6
	h.armor = 0.0
	_hit(h, h.max_health * 0.2)
	assert_near(c.grace_left, 0.0, 0.0001, "once per 15 s")


func _hit(h: CrewHealth, amount: float) -> void:
	h.grace_left = 0.0
	h.invuln_left = 0.0
	_crew().take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", _crew().global_position,
		Vector3.FORWARD), 0)


## Mimic: B's resolver merges a card-9 dict alone; every family's component must run on it (defaults fill the rest).
func test_every_component_tolerates_a_partial_dict() -> void:
	var defaults: Dictionary = PerkTweak.data().defaults
	var npc: NpcBase = _enemy()
	for key: StringName in CrewPerks.scripts():
		var fields: Array = (defaults.get(key, {}) as Dictionary).keys()
		var partial: Dictionary = {fields[-1]: (defaults[key] as Dictionary)[fields[-1]]} if not fields.is_empty() \
			else {"mimic": true}
		Modifiers.set_source(0, &"mimic", {key: partial})
		var perks: CrewPerks = PerkHooks.of(_crew())
		perks.refresh()
		assert_true(perks.component(key) != null, "%s runs on a partial dict" % key)
		await wait_physics_frames(2)
		_kill()
		npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"test", npc.global_position,
			Vector3.FORWARD), _crew().net_id)
		_hit(_crew().health, 5.0)
		PerkHooks.on_dodge(_crew().health, {"attacker": npc.net_id, "amount": 1.0})
		PerkHooks.use_throwable(_crew())
		assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "%s: still up" % key)
		Modifiers.clear_source(0, &"mimic")
		perks.refresh()
		_crew().health.reset_full()
