## B4-13 firing range complete (fidelity P7): armored dummies (shield, frontal plate, staged plates)
## per damage.md, moving targets on deterministic tracks, the falloff graph, and the per-dummy
## DPS/TTK readout equal to shooting the real target.
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"
const P9: StringName = &"weapon.kestrel_p9"
const HERON: StringName = &"weapon.heron_308"
const PLOWMAN: StringName = &"weapon.plowman_12"

var _range: FiringRange = null
var _nodes: Array[Node] = []


func after_each() -> void:
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _spawn_range(fallback: bool = false) -> FiringRange:
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	_range.use_fallback_shooter = fallback
	add_child(_range)
	await wait_frames(2)
	return _range


func _table() -> RangeDummyTable:
	return load(FiringRange.DUMMIES_PATH) as RangeDummyTable


func _target(dummy_id: StringName, diff: int = Enums.Difficulty.ROUTINE) -> RangeTarget:
	var t: RangeTarget = RangeTarget.new()
	t.setup(_table().dummy(dummy_id), diff, load(FiringRange.TWEAK_PATH) as RangeTweak, 0, 15.0)
	add_child(t)
	_nodes.append(t)
	return t


## Bullet from the front (travelling -Z toward a dummy facing +Z) with explicit pierce flags.
func _info(amount: float, zone: int = Enums.HitZone.BODY, shield_pierce: bool = false, pierced: bool = false) -> Dictionary:
	var i: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, zone, P9, Vector3.ZERO, Vector3.FORWARD, 1)
	i["shield_pierce"] = shield_pierce
	i["pierced_armor"] = pierced
	return i


func _count_applied(t: RangeTarget, hit: Callable) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	var on_applied: Callable = func(victim: int, _attacker: int, info: Dictionary) -> void:
		if victim == t.net_id:
			seen.append(info)
	EventBus.damage_applied.connect(on_applied)
	hit.call()
	EventBus.damage_applied.disconnect(on_applied)
	return seen


# --- Data -----------------------------------------------------------------------------------------

func test_dummy_types_are_data() -> void:
	var ids: Array[StringName] = []
	for d: RangeDummyDef in _table().dummies:
		ids.append(d.id)
		assert_true(String(d.enemy_id).begins_with("enemy."), "%s mirrors an EnemyDef id" % d.id)
		assert_true(d.health_for(Enums.Difficulty.ROUTINE) > 0.0, "%s has HP" % d.id)
		assert_true(d.uses_enemy_def(), "%s reads HP from its EnemyDef" % d.id)
	for id: StringName in [&"range_dummy.light", &"range_dummy.heavy", &"range_dummy.bulwark",
			&"range_dummy.wrecker", &"range_dummy.corpsman"]:
		assert_has(ids, id)
	var t: RangeDummyTable = _table()
	assert_true(float(_armor(&"range_dummy.heavy")["frontal_armor_arc_deg"]) > 0.0, "L4.2 frontal arc")
	assert_true(float(_armor(&"range_dummy.heavy")["frontal_armor"]) < 1.0, "L4.2 frontal armour reduces")
	assert_true(bool(_armor(&"range_dummy.bulwark")["shield"]), "L4.5 shield")
	var spm: float = float(_armor(&"range_dummy.bulwark")["shield_pierce_mult"])
	assert_true(spm > 0.0 and spm < 1.0, "L3.4 shield pass-through")
	assert_eq((_armor(&"range_dummy.wrecker")["plate_health"] as Array).size(), 2, "L4.6 faceplate + visor")
	assert_true(float(_armor(&"range_dummy.wrecker")["explosive_mult"]) > 1.0, "L4.6 explosive weakness")
	var light: RangeDummyDef = t.dummy(&"range_dummy.light")
	assert_true(light.uses_enemy_def(), "TAC Light reads ENV A's EnemyDef")
	var e: EnemyDef = light.enemy_def()
	for d: int in range(Enums.Difficulty.size()):
		assert_near(light.health_for(d), e.health[d], 0.0001)
		assert_near(light.headshot_mult_for(d), e.headshot_mult[d], 0.0001)


func _armor(dummy_id: StringName) -> Dictionary:
	return _table().dummy(dummy_id).armor()


## Every dummy's armour IS its EnemyDef's (D-052): NpcHitRules.armor_of when A's tree has it, and every
## canonical key the EnemyDef carries is read verbatim.
func test_dummy_armour_comes_from_enemy_def() -> void:
	var rules: Script = NpcHitRules
	for d: RangeDummyDef in _table().dummies:
		var e: EnemyDef = d.enemy_def()
		assert_true(e != null, "%s: ENV A ships %s" % [d.id, d.enemy_id])
		if e == null:
			continue
		var a: Dictionary = d.armor()
		for k: String in ["armor_body_mult", "frontal_armor", "frontal_armor_arc_deg", "explosive_mult",
				"shield", "shield_pierce_mult", "plate_health"]:
			assert_true(a.has(k), "%s armour key %s" % [d.id, k])
			if e.params.has(k) and k != "plate_health":
				assert_eq(a[k], type_convert(e.params[k], typeof(a[k])), "%s.%s from the EnemyDef" % [d.id, k])
		if rules.has_method(&"armor_of"):
			var canon: Dictionary = rules.call(&"armor_of", e)
			for k: String in canon:
				if k != "shield" or e.params.has("shield"):
					assert_eq(str(a[k]), str(canon[k]), "%s.%s == NpcHitRules.armor_of" % [d.id, k])
		var m: RangeDamageModel = RangeDamageModel.from_def(d, Enums.Difficulty.ROUTINE)
		assert_near(m.frontal_armor, float(a["frontal_armor"]), 0.0001)
		assert_near(m.armor_body_mult, float(a["armor_body_mult"]), 0.0001)
		assert_near(m.explosive_mult, float(a["explosive_mult"]), 0.0001)
		assert_eq(m.plate_health.size(), (a["plate_health"] as Array).size())


# --- Shield -----------------------------------------------------------------------------------------

func test_shield_blocks_without_pierce_and_passes_quarter_with_it() -> void:
	var t: RangeTarget = _target(&"range_dummy.bulwark")
	assert_true(t.shield_node != null, "shield built")
	var shb: RangeHitbox = null
	for hb: RangeHitbox in t.hitboxes():
		if hb.part == RangeHitbox.PART_SHIELD:
			shb = hb
	assert_true(shb != null, "shield hitbox")
	assert_eq(Damage.find_target(shb), t.shield_node, "shield hits resolve to the shield node")
	assert_true(shb.global_position.z > t.zone_position(Enums.HitZone.BODY).z + 0.2, "shield in front of the body")
	var hp: float = t.max_health
	var box: Array[Dictionary] = []
	var seen: Array[Dictionary] = _count_applied(t, func() -> void:
		box.append(t.shield_node.take_hit(_info(40.0), 1)))
	var res: Dictionary = box[0]
	assert_eq(seen.size(), 1, "a blocked hit still emits damage_applied once (by the target)")
	assert_true(bool(res["blocked"]), "no shield_pierce -> blocked")
	assert_near(float(res["amount"]), 0.0)
	assert_near(t.health, hp, 0.0001, "blocked: no damage")
	var through: float = 40.0 * t.model.shield_pierce_mult
	res = t.shield_node.take_hit(_info(40.0, Enums.HitZone.BODY, true), 1)
	assert_true(bool(res["pierced_shield"]))
	assert_near(float(res["amount"]), through, 0.0001, "shield_pierce -> x shield_pierce_mult")
	assert_near(t.health, hp - through, 0.0001)
	var boom: Dictionary = _info(20.0)
	boom["type"] = Enums.DamageType.EXPLOSION
	res = t.shield_node.take_hit(boom, 1)
	assert_near(float(res["amount"]), 20.0 * t.model.explosive_mult, 0.0001, "explosions go around the shield")
	var fire: Dictionary = _info(20.0)
	fire["type"] = Enums.DamageType.FIRE
	res = t.shield_node.take_hit(fire, 1)
	assert_near(float(res["amount"]), 20.0 * CombatTweak.data().shield_fire_damage_mult, 0.0001, "fire through the shield")
	var melee: Dictionary = _info(20.0, Enums.HitZone.BODY, true)
	melee["type"] = Enums.DamageType.MELEE
	assert_true(bool(t.shield_node.take_hit(melee, 1)["blocked"]), "melee is blocked by the shield")
	t.reset_target()
	res = t.take_hit(_info(30.0), 1)
	assert_near(float(res["amount"]), 30.0, 0.0001, "a hit that reaches the body (flank) is not shielded")


# --- Frontal armor ------------------------------------------------------------------------------------

func test_frontal_armor_needs_armor_piercing() -> void:
	var t: RangeTarget = _target(&"range_dummy.heavy")
	var hp: float = t.max_health
	var fa: float = t.model.frontal_armor
	var res: Dictionary = t.take_hit(_info(50.0), 1)
	assert_true(bool(res["frontal_plate"]), "frontal hit")
	assert_near(float(res["amount"]), 50.0 * fa, 0.0001, "non-AP body hit from the front -> x frontal_armor")
	assert_eq(bool(res["blocked"]), fa <= 0.0)
	assert_near(t.health, hp - 50.0 * fa, 0.0001)
	res = t.take_hit(_info(10.0, Enums.HitZone.LIMB), 1)
	assert_near(float(res["amount"]), 10.0 * fa, 0.0001, "limbs are behind the frontal armour too")
	res = t.take_hit(_info(50.0, Enums.HitZone.BODY, false, true), 1)
	assert_true(bool(res["pierced_armor"]))
	assert_near(float(res["amount"]), 50.0, 0.0001, "pierced_armor -> full body damage")
	res = t.take_hit(_info(10.0, Enums.HitZone.HEAD), 1)
	assert_near(float(res["amount"]), 10.0 * t.headshot_mult(), 0.0001, "head is unarmored")
	var back: Dictionary = _info(20.0)
	back["direction"] = Vector3.BACK
	res = t.take_hit(back, 1)
	assert_near(float(res["amount"]), 20.0 * t.model.armor_body_mult, 0.0001, "the plate is frontal only")
	var half: float = deg_to_rad(t.model.frontal_armor_arc_deg * 0.5)
	var side: Dictionary = _info(20.0)
	side["direction"] = -Vector3(sin(half + 0.2), 0.0, cos(half + 0.2))
	assert_false(t.is_frontal(side), "outside the arc")
	var edge: Dictionary = _info(20.0)
	edge["direction"] = -Vector3(sin(half - 0.2), 0.0, cos(half - 0.2))
	assert_true(t.is_frontal(edge), "inside the arc")
	var fire: Dictionary = _info(20.0)
	fire["type"] = Enums.DamageType.FIRE
	res = t.take_hit(fire, 1)
	assert_near(float(res["amount"]), 20.0, 0.0001, "fire ignores armor")
	var crit: Dictionary = _info(10.0, Enums.HitZone.BODY, false, true)
	crit["crit"] = true
	res = t.take_hit(crit, 1)
	assert_near(float(res["amount"]), 10.0 * t.headshot_mult(), 0.0001, "D-027 crit x head mult on the body")


# --- Staged plates ------------------------------------------------------------------------------------

func test_plates_then_weak_point_then_head() -> void:
	var t: RangeTarget = _target(&"range_dummy.wrecker")
	var hs: float = t.headshot_mult()
	assert_true(hs > 1.0)
	var hp: float = t.max_health
	var face: float = t.model.plate_health[0]
	var visor: float = t.model.plate_health[1]
	assert_eq(t.plates_left(), 2)
	var plate_hb: RangeHitbox = null
	for hb: RangeHitbox in t.hitboxes():
		if hb.zone == Enums.HitZone.WEAKPOINT:
			plate_hb = hb
	assert_true(plate_hb != null and plate_hb.collision_layer != 0, "face plate hittable")
	assert_eq(Damage.find_target(plate_hb), t)
	assert_true(plate_hb.global_position.z > t.zone_position(Enums.HitZone.HEAD).z, "plate in front of the head")
	# Head is immune while plates remain.
	var res: Dictionary = t.take_hit(_info(10.0, Enums.HitZone.HEAD), 1)
	assert_near(float(res["amount"]), 10.0, 0.0001, "headshot-immune while plated (x1)")
	hp -= 10.0
	var crit: Dictionary = _info(10.0, Enums.HitZone.HEAD)
	crit["crit"] = true
	res = t.take_hit(crit, 1)
	assert_near(float(res["amount"]), 10.0, 0.0001, "crit cleared on the armoured head")
	hp -= 10.0
	var boom: Dictionary = _info(100.0)
	boom["type"] = Enums.DamageType.EXPLOSION
	res = t.take_hit(boom, 1)
	assert_near(float(res["amount"]), 100.0 * t.model.explosive_mult, 0.0001, "L4.6 explosive_mult")
	hp -= 100.0 * t.model.explosive_mult
	# Faceplate: 60 % then the rest (excess lost), health untouched.
	var first: float = face * 0.6
	res = t.take_hit(_info(first, Enums.HitZone.WEAKPOINT), 1)
	assert_eq(int(res["plate_stage"]), 0)
	assert_near(float(res["plate_health_after"]), face - first, 0.0001)
	assert_near(t.health, hp, 0.0001, "plate hits never touch health")
	res = t.take_hit(_info(first, Enums.HitZone.WEAKPOINT), 1)
	assert_true(bool(res["plate_broken"]), "faceplate broken")
	assert_near(float(res["amount"]), face - first, 0.0001, "excess lost")
	assert_eq(t.plates_left(), 1)
	# Visor.
	res = t.take_hit(_info(visor, Enums.HitZone.WEAKPOINT), 1)
	assert_true(bool(res["plate_broken"]) and int(res["plate_stage"]) == 1, "visor broken")
	assert_eq(t.plates_left(), 0)
	assert_eq(plate_hb.collision_layer, 0, "weak point gone: the head is exposed")
	res = t.take_hit(_info(10.0, Enums.HitZone.HEAD), 1)
	assert_near(float(res["amount"]), 10.0 * hs, 0.0001, "head mult after the plates")
	res = t.take_hit(_info(10.0, Enums.HitZone.WEAKPOINT), 1)
	assert_near(float(res["amount"]), 10.0, 0.0001, "WEAKPOINT without plates counts x1 (damage.md)")
	t.reset_target()
	assert_eq(t.plates_left(), 2, "reset restores the plates")
	assert_true(plate_hb.collision_layer != 0)


# --- Moving targets ------------------------------------------------------------------------------------

func test_track_offset_is_deterministic() -> void:
	assert_near(RangeTrack.offset_at(0.0, 2.0, 4.0), 0.0)
	assert_near(RangeTrack.offset_at(1.0, 2.0, 4.0), 2.0, 0.0001, "moves +X at speed")
	assert_near(RangeTrack.offset_at(2.0, 2.0, 4.0), 4.0, 0.0001, "end of the track")
	assert_near(RangeTrack.offset_at(3.0, 2.0, 4.0), 2.0, 0.0001, "turns back")
	assert_near(RangeTrack.offset_at(6.0, 2.0, 4.0), -4.0, 0.0001)
	assert_near(RangeTrack.offset_at(8.0, 2.0, 4.0), 0.0, 0.0001, "period 4*half/speed")
	assert_near(RangeTrack.offset_at(8.0 * 37.0 + 1.0, 2.0, 4.0), 2.0, 0.0001, "periodic")
	for i: int in range(200):
		var t: float = float(i) * 0.037
		assert_true(absf(RangeTrack.offset_at(t, 3.5, 4.0)) <= 4.0 + 0.0001, "stays on the track")
	var a: RangeTrack = RangeTrack.new()
	var b: RangeTrack = RangeTrack.new()
	a.setup(3.5, 4.0, 0.6)
	b.setup(3.5, 4.0, 0.6)
	for i: int in range(100):
		a.advance(1.0 / 60.0)
	b.set_time(100.0 / 60.0)
	assert_near(a.carriage.position.x, b.carriage.position.x, 0.0001, "same time -> same position")
	a.free()
	b.free()


func test_moving_lanes_in_range() -> void:
	var r: FiringRange = await _spawn_range(true)
	var moving: Array[RangeTarget] = []
	for t: RangeTarget in r.targets:
		var track: RangeTrack = t.get_parent().get_parent() as RangeTrack
		if track != null:
			moving.append(t)
			assert_true(track.speed_mps >= 2.0 and track.speed_mps <= 5.0, "P7: lateral tracks 2-5 m/s")
	assert_true(moving.size() >= 2, "moving-target lanes from range_layout.tres")
	var t0: RangeTarget = moving[0]
	var tr: RangeTrack = t0.get_parent().get_parent() as RangeTrack
	await wait_physics_frames(5)
	assert_near(tr.carriage.position.x, RangeTrack.offset_at(tr.time_s + tr.phase_s, tr.speed_mps, tr.track_half_m), 0.0001)
	var x0: float = t0.global_position.x
	tr.set_time(tr.time_s + 0.1)
	assert_true(absf(t0.global_position.x - x0) > 0.0, "target rides the carriage")
	var armory: int = 0
	for t: RangeTarget in r.targets:
		if t.model.shield or t.model.has_frontal_armor() or not t.model.plate_health.is_empty():
			armory += 1
	assert_true(armory >= 3, "armory lanes: shield, frontal plate, plates")
	assert_eq(r.overlay.readout_option.item_count, r.targets.size(), "every target selectable for the readout")


# --- Falloff graph ------------------------------------------------------------------------------------

func test_falloff_graph_samples_equal_range_math() -> void:
	var r: FiringRange = await _spawn_range(true)
	for id: StringName in [P9, PLOWMAN, HERON]:
		r.select_weapon(id)
		var g: RangeFalloffGraph = r.overlay.falloff_graph
		var pts: PackedVector2Array = g.samples()
		assert_true(pts.size() >= r.tweak.graph_samples, "%s sampled" % id)
		for p: Vector2 in pts:
			assert_near(p.y, RangeMath.shot_damage(r.weapon_stats, p.x), 0.001, "%s at %s m" % [id, p.x])
		assert_near(pts[pts.size() - 1].x, r.tweak.graph_max_distance_m, 0.0001)
		assert_near(g.marker_distance_m, r.readout_distance(), 0.15, "marker at the readout distance")
	r.select_weapon(PLOWMAN)
	var has_start: bool = false
	for p: Vector2 in r.overlay.falloff_graph.samples():
		has_start = has_start or is_equal_approx(p.x, r.weapon_stats.falloff_start_m)
	assert_true(has_start, "falloff breakpoints are exact samples")


# --- TTK readout == shooting the target ----------------------------------------------------------------

## Fire `s` at a real RangeTarget of `dummy_id` from the front (through its shield when it has one),
## the way the readout assumes, until it dies. Returns the shot count (0 = never died).
func _shoot_until_dead(dummy_id: StringName, s: WeaponStats, distance: float, head: bool) -> int:
	var t: RangeTarget = _target(dummy_id, Enums.Difficulty.HAZARDOUS)
	for shot: int in range(1, RangeDamageModel.MAX_SIM_SHOTS + 1):
		var progressed: bool = false
		for p: int in range(maxi(s.pellets, 1)):
			if not t.alive:
				break
			var zone: int = Enums.HitZone.BODY
			if head and t.shield_node == null:  # through a shield the shield hitbox (BODY) is hit
				zone = Enums.HitZone.WEAKPOINT if t.plates_left() > 0 else Enums.HitZone.HEAD
			var info: Dictionary = RangeDamageModel.readout_info(s, distance, zone)
			var res: Dictionary = t.shield_node.take_hit(info, 1) if t.shield_node != null else t.take_hit(info, 1)
			progressed = progressed or float(res.get("amount", 0.0)) > 0.0
		if not t.alive:
			return shot
		if not progressed:
			return 0
	return 0


func test_ttk_readout_equals_simulated_shots() -> void:
	for wid: StringName in [P9, HERON, PLOWMAN]:
		var s: WeaponStats = LoadoutResolver.resolve_weapon(wid, [])
		for def: RangeDummyDef in _table().dummies:
			var ro: Dictionary = RangeDamageModel.from_def(def, Enums.Difficulty.HAZARDOUS).readout(s, 12.0)
			var body: int = _shoot_until_dead(def.id, s, 12.0, false)
			var head: int = _shoot_until_dead(def.id, s, 12.0, true)
			assert_eq(int(ro["shots_body"]), body, "%s vs %s body" % [wid, def.id])
			assert_eq(int(ro["shots_head"]), head, "%s vs %s head" % [wid, def.id])
			assert_near(float(ro["ttk_body_s"]) if body > 0 else 0.0, RangeMath.time_to_kill_s(s, body) if body > 0 else 0.0, 0.0001)
	# Spot checks of the armor math in the readout.
	var p9: WeaponStats = LoadoutResolver.resolve_weapon(P9, [])
	var heron: WeaponStats = LoadoutResolver.resolve_weapon(HERON, [])
	var bul: RangeDamageModel = RangeDamageModel.from_def(_table().dummy(&"range_dummy.bulwark"), Enums.Difficulty.HAZARDOUS)
	assert_true(bool(bul.readout(p9, 12.0)["body_blocked"]), "P9 cannot get through the shield")
	assert_near(float(bul.readout(heron, 12.0)["body_damage"]), heron.damage * bul.shield_pierce_mult, 0.001,
			"Heron through the shield x shield_pierce_mult")
	var heavy: RangeDamageModel = RangeDamageModel.from_def(_table().dummy(&"range_dummy.heavy"), Enums.Difficulty.HAZARDOUS)
	assert_true(bool(heavy.readout(p9, 12.0)["body_blocked"]), "P9 body vs frontal plate")
	assert_false(bool(heavy.readout(p9, 12.0)["head_blocked"]), "P9 head vs frontal plate")
	var wr: RangeDamageModel = RangeDamageModel.from_def(_table().dummy(&"range_dummy.wrecker"), Enums.Difficulty.HAZARDOUS)
	var w_head: int = int(wr.readout(heron, 12.0)["shots_head"])
	var hd: float = RangeMath.shot_damage(heron, 12.0)
	var plate_shots: int = 0
	for php: float in wr.plate_health:
		plate_shots += ceili(php / hd - RangeMath.EPS)
	assert_eq(w_head, plate_shots + ceili(wr.health / (hd * heron.headshot_mult * wr.headshot_mult) - RangeMath.EPS),
			"plates then head")


func test_range_readout_per_dummy_and_selected_lane() -> void:
	var r: FiringRange = await _spawn_range(true)
	var rows: Array[Dictionary] = r.dummy_readouts()
	assert_eq(rows.size(), r.dummy_table.dummies.size(), "one row per dummy type")
	for row: Dictionary in rows:
		assert_eq(r.overlay.dummy_value_text(StringName(row["id"])), RangeOverlay.dummy_row_text(row["readout"] as Dictionary))
	# Select the shield lane: the readout comes from that target's model.
	var lane: int = -1
	for t: RangeTarget in r.targets:
		if t.model.shield:
			lane = t.lane
	assert_true(lane >= 0)
	r.set_readout_lane(lane)
	var ro: Dictionary = r.readout()
	assert_true(bool(ro["body_blocked"]), "default P9 vs shield")
	assert_eq(r.overlay.value_text("ro_body"), UiText.t(&"ui.range.blocked"))
	assert_eq(r.overlay.value_text("ro_armor"), FiringRange.armor_text(r.targets[lane].model))
	r.set_difficulty(Enums.Difficulty.BRUTAL)
	assert_near(float(r.readout()["health"]), r.dummy_table.dummy(&"range_dummy.bulwark").health_for(Enums.Difficulty.BRUTAL), 0.001,
			"difficulty selector drives dummy HP")


func test_fallback_gun_breaks_wrecker_plate() -> void:
	var r: FiringRange = await _spawn_range(true)
	var t: RangeTarget = null
	for x: RangeTarget in r.targets:
		if not x.model.plate_health.is_empty():
			t = x
	assert_true(t != null, "wrecker lane")
	var steady: WeaponStats = r.weapon_stats.duplicate() as WeaponStats
	steady.spread_deg_hip = 0.0
	steady.spread_deg_ads = 0.0
	r.spectator.gun.equip(P9, steady, false)
	r.spectator.look_at_point(t.zone_position(Enums.HitZone.WEAKPOINT))
	await wait_physics_frames(2)
	r.spectator.request_shot()
	await wait_physics_frames(3)
	assert_eq(int(r.last_shot.get("zone", -1)), int(Enums.HitZone.WEAKPOINT), "the face plate is hit first")
	assert_eq(int(r.last_shot.get("plate_stage", -1)), 0)
	assert_near(t.health, t.max_health, 0.0001, "plate soaked the shot")
	assert_true(r.overlay.value_text("ls_result").length() > 0)


# --- ENV A's real crew --------------------------------------------------------------------------------

func test_real_crew_shot_at_shield_single_damage_applied() -> void:
	if not RangeCrewBridge.available():
		skip("CrewController.spawn_for_range not in this tree")
		return
	var r: FiringRange = await _spawn_range()
	await wait_physics_frames(10)
	var t: RangeTarget = null
	for x: RangeTarget in r.targets:
		if x.model.shield:
			t = x
	var crew: Node = r.crew
	# Walk the crew in front of the shield dummy (5 m) so the shot is frontal and in range.
	(crew as Node3D).global_position = Vector3(t.global_position.x, 0.0, t.global_position.z + 5.0)
	await wait_physics_frames(5)
	var aim_at: Vector3 = t.zone_position(Enums.HitZone.BODY)
	var seen: Array[Dictionary] = []
	var on_applied: Callable = func(victim: int, _attacker: int, info: Dictionary) -> void:
		if victim == t.net_id:
			seen.append(info)
	EventBus.damage_applied.connect(on_applied)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, false))
	await wait_physics_frames(2)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, true))
	await wait_physics_frames(6)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, false))
	await wait_physics_frames(2)
	EventBus.damage_applied.disconnect(on_applied)
	assert_eq(seen.size(), 1, "one trigger press -> exactly one damage_applied")
	if seen.is_empty():
		return
	assert_true(bool(seen[0].get("via_shield", false)), "the crew's hitscan hit the shield first")
	assert_true(bool(seen[0].get("blocked", false)), "P9 blocked by the shield")
	assert_near(t.health, t.max_health, 0.0001)


func _intent_at(crew: Node, p: Vector3, fire: bool) -> CrewIntent:
	var d: Vector3 = (p - RangeCrewBridge.eye_position(crew)).normalized()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = asin(clampf(d.y, -1.0, 1.0))
	i.aim = true
	i.fire = fire
	return i
