## D-163 name-independent systems: ThrownItem KIND_SMOKE + SmokeZones (crew in a cloud avoid bullets, enemies in it
## lose accuracy, no LOS blocking, the cloud ends), PerkHooks.on_dodge, the generic pooled absorb (the strongest offer
## per pool, pools add), TagPairs (aim-line tag, duration / extend, cooldown / cut, kill attribution, replication).
extends TestCase

var _rt: HeistRuntime = null


class DodgeProbe extends PerkComponent:
	var dodges: int = 0

	func on_dodge() -> void:
		dodges += 1


class AbsorbProbe extends PerkComponent:
	var offer: Dictionary = {}

	func absorb_for(_target: CrewController) -> Dictionary:
		return offer


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1630, Enums.Difficulty.ROUTINE, self,
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


func _smoke(pos: Vector3, extra: Dictionary = {}) -> ThrownItem:
	var item: ThrownItem = ThrownItem.new()
	item.name = "TestSmoke"
	item.params = {"velocity": Vector3.ZERO, "kind": ThrownItem.KIND_SMOKE, "attacker": 0, "owner_slot": 0,
		"throwable_id": &""}
	item.params.merge(extra, true)
	_rt.dynamic_root.add_child(item, true)
	item.global_position = pos
	NetIds.claim(item)
	item._start_smoke()
	return item


func _bullet(c: CrewController, amount: float = 10.0) -> Dictionary:
	c.health.grace_left = 0.0
	return c.health.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		c.global_position, Vector3.FORWARD), 0)


func _probe(slot: int, comp: PerkComponent, key: StringName) -> void:
	comp.setup(_crew(slot), key, {})
	PerkHooks.of(_crew(slot)).components[key] = comp


# --- Smoke -------------------------------------------------------------------------------------

func test_smoke_cloud_avoids_bullets_and_ends() -> void:
	var c: CrewController = _crew()
	Modifiers.set_source(0, &"deck", {&"defense.dodge_add": -1.0})
	var cloud: ThrownItem = _smoke(c.global_position, {"crew_bullet_avoid": 1.0, "smoke_s": 0.5})
	assert_eq(SmokeZones.clouds(c), [cloud] as Array[ThrownItem], "one live cloud")
	assert_true(SmokeZones.in_smoke(c), "the crew stands in it")
	var probe: DodgeProbe = DodgeProbe.new()
	_probe(0, probe, &"perk.test_dodge")
	var out: Dictionary = _bullet(c)
	assert_true(bool(out.get("dodged", false)), "avoid 1.0: the bullet is avoided (a dodge)")
	assert_eq(probe.dodges, 1, "PerkHooks.on_dodge ran")
	_crew(1).global_position = c.global_position + Vector3(20, 0, 0)
	assert_false(SmokeZones.crew_avoids(_crew(1)), "outside the cloud nothing is avoided")
	cloud.params["crew_bullet_avoid"] = 0.0
	out = _bullet(c)
	assert_false(bool(out.get("dodged", false)), "avoid 0.0: it lands")
	assert_true(await wait_until(func() -> bool: return SmokeZones.clouds(c).is_empty(), 3.0), "the cloud ends")
	assert_false(SmokeZones.in_smoke(c))


func test_smoke_lowers_enemy_accuracy_only_inside() -> void:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var inside: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -20)), null)
	var outside: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"),
		Transform3D(Basis.IDENTITY, Vector3(12, 0.05, -20)), null)
	_smoke(Vector3(0, 0.5, -20), {"npc_accuracy_mult": 0.3})
	assert_near(SmokeZones.npc_accuracy_mult(inside), 0.3, 0.0001, "inside: the param")
	assert_near(SmokeZones.npc_accuracy_mult(outside), 1.0, 0.0001, "12 m away (radius 6): untouched")
	_smoke(Vector3(12, 0.5, -20))
	assert_near(SmokeZones.npc_accuracy_mult(outside), SmokeZones.NPC_ACCURACY_MULT, 0.0001, "default 0.5")


func test_smoke_has_no_fuse() -> void:
	var cloud: ThrownItem = _smoke(_crew().global_position, {"smoke_s": 5.0, "fuse_s": 0.0})
	await wait_physics_frames(4)
	assert_true(is_instance_valid(cloud) and cloud.pool_left > 0.0, "a smoke item never detonates")


# --- Pooled absorb -------------------------------------------------------------------------------

func test_absorb_takes_the_best_offer_per_pool_and_adds_pools() -> void:
	var a: AbsorbProbe = AbsorbProbe.new()
	a.offer = {&"p1": 4.0}
	_probe(0, a, &"perk.test_a")
	var b: AbsorbProbe = AbsorbProbe.new()
	b.offer = {&"p1": 6.0, &"p2": 2.0}
	_probe(1, b, &"perk.test_b")
	assert_near(PerkHooks.absorb(_crew()), 8.0, 0.0001, "p1 = max(4, 6), + p2 2")
	var h: CrewHealth = _crew().health
	h.health = h.max_health
	h.armor = 0.0
	Modifiers.set_source(0, &"deck", {&"defense.dodge_add": -1.0})
	_bullet(_crew(), 20.0)
	assert_near(h.health, h.max_health - 12.0, 0.01, "a 20 hit takes 12")


# --- TagPairs ------------------------------------------------------------------------------------

func test_tag_pairs_tag_extend_cooldown_and_replicate() -> void:
	var holder: CrewController = _crew()
	var mate: CrewController = _crew(1)
	mate.global_position = holder.global_position + holder.aim_direction().normalized() * 6.0
	await wait_physics_frames(2)
	var tp: TagPairs = TagPairs.of(_rt)
	assert_eq(tp.tag(holder, 18.0, 11.0, 60.0), 1, "the teammate on the aim line is tagged")
	assert_eq(tp.tagged_of(0), 1)
	assert_eq(tp.tag(holder, 18.0, 11.0, 60.0), -1, "recharging: no second tag")
	assert_eq(tp.paired_holders(1), [0] as Array[int], "the tagged teammate's kill counts for the holder's pair")
	assert_eq(tp.paired_holders(0), [0] as Array[int], "and the holder's own")
	tp.extend(0, 2.0)
	assert_near(float(tp.pairs[0]["left"]), 13.0, 0.01, "+2 s")
	tp.cut_cooldown(0, 2.0)
	assert_near(tp.cooldown_left(0), 58.0, 0.01, "-2 s")
	var mirror: TagPairs = TagPairs.new()
	mirror.apply_net_state(bytes_to_var(var_to_bytes(tp.net_state())) as Dictionary)
	assert_eq(mirror.tagged_of(0), 1, "replicated")
	mirror.free()
	tp.pairs[0]["left"] = 0.05
	await wait_physics_frames(6)
	assert_eq(tp.tagged_of(0), -1, "the pair ends")
	assert_eq(tp.paired_holders(1), [] as Array[int])


func test_tag_needs_a_teammate_in_reach() -> void:
	var holder: CrewController = _crew()
	_crew(1).global_position = holder.global_position + holder.aim_direction().normalized() * 30.0
	await wait_physics_frames(2)
	assert_eq(TagPairs.of(_rt).tag(holder, 18.0, 11.0, 60.0), -1, "30 m: out of reach")
	assert_eq(TagPairs.of(_rt).cooldown_left(0), 0.0, "a miss costs no cooldown")


# --- Presentation hooks (C's VfxDirector) ------------------------------------------------------

## The signals are the LEAD's on EventBus; until they are declared there the test adds them as user signals.
func _ensure_signal(sig: StringName, args: Array[Dictionary]) -> bool:
	if EventBus.has_signal(sig):
		return false
	EventBus.add_user_signal(sig, args)
	return true


func test_fx_hooks_smoke_cloud_and_tether() -> void:
	var added: Array[StringName] = []
	if _ensure_signal(ThrownItem.SIGNAL_SMOKE_FX, [{"name": "position", "type": TYPE_VECTOR3},
			{"name": "radius", "type": TYPE_FLOAT}, {"name": "duration_s", "type": TYPE_FLOAT}]):
		added.append(ThrownItem.SIGNAL_SMOKE_FX)
	if _ensure_signal(TagPairs.SIGNAL_TETHER_FX, [{"name": "a_slot", "type": TYPE_INT},
			{"name": "b_slot", "type": TYPE_INT}, {"name": "active", "type": TYPE_BOOL}]):
		added.append(TagPairs.SIGNAL_TETHER_FX)
	var smoke: Array = []
	var tether: Array = []
	var on_smoke: Callable = func(p: Vector3, r: float, d: float) -> void: smoke.append([p, r, d])
	var on_tether: Callable = func(a: int, b: int, on: bool) -> void: tether.append([a, b, on])
	EventBus.connect(ThrownItem.SIGNAL_SMOKE_FX, on_smoke)
	EventBus.connect(TagPairs.SIGNAL_TETHER_FX, on_tether)
	var pos: Vector3 = _crew().global_position
	_smoke(pos, {"radius_m": 4.0, "smoke_s": 10.0})
	assert_eq(smoke.size(), 1, "smoke_cloud_fx once on landing")
	assert_near(float(smoke[0][1]), 4.0, 0.0001, "the cloud's radius (B's 4 m)")
	assert_near(float(smoke[0][2]), 10.0, 0.0001, "its duration")
	assert_true((smoke[0][0] as Vector3).distance_to(pos) < 0.01, "at the cloud")
	var mirror: TagPairs = TagPairs.new()
	mirror.apply_net_state({0: [1, 11.0, 60.0]})
	assert_eq(tether, [[0, 1, true]], "a client sees the pair form")
	mirror.apply_net_state({0: [-1, 0.0, 50.0]})
	assert_eq(tether[-1], [0, 1, false], "and end")
	mirror.free()
	var holder: CrewController = _crew()
	_crew(1).global_position = holder.global_position + holder.aim_direction().normalized() * 6.0
	await wait_physics_frames(2)
	tether.clear()
	var tp: TagPairs = TagPairs.of(_rt)
	tp.tag(holder, 18.0, 0.1, 60.0)
	assert_eq(tether, [[0, 1, true]], "the server: on tag")
	await wait_physics_frames(10)
	assert_eq(tether[-1], [0, 1, false], "the server: on expiry")
	EventBus.disconnect(ThrownItem.SIGNAL_SMOKE_FX, on_smoke)
	EventBus.disconnect(TagPairs.SIGNAL_TETHER_FX, on_tether)
	for sig: StringName in added:
		EventBus.remove_user_signal(sig)
