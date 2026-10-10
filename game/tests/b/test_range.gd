## B1-05 firing range: scene, data-built layout, target hit API, falloff/headshot/TTK math,
## loadout swap -> panel + crew, ENV A's real crew member and weapon runtime (spawn, panel/aim input
## pause, a real CrewIntent shot through the single hit path), the fallback camera + debug hitscan,
## strings.
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"
const P9: StringName = &"weapon.kestrel_p9"
const EXT_MAG: StringName = &"mod.p9_extended_mag"

var _range: FiringRange = null


func after_each() -> void:
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	await wait_frames(2)


func _spawn_range(fallback: bool = false) -> FiringRange:
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	_range.use_fallback_shooter = fallback
	add_child(_range)
	await wait_frames(2)
	return _range


func _lane_at(r: FiringRange, distance_m: float) -> int:
	for i: int in range(r.layout.lane_count()):
		if is_equal_approx(r.layout.lane_target_distances[i], distance_m):
			return i
	fail("no lane at %s m" % distance_m)
	return 0


func _dummy() -> RangeDummyDef:
	var table: RangeDummyTable = load(FiringRange.DUMMIES_PATH) as RangeDummyTable
	return table.dummy(&"range_dummy.light")


func _target(diff: int = Enums.Difficulty.ROUTINE) -> RangeTarget:
	var t: RangeTarget = RangeTarget.new()
	t.setup(_dummy(), diff, load(FiringRange.TWEAK_PATH) as RangeTweak, 0, 10.0)
	add_child(t)
	return t


func _info(amount: float, zone: int = Enums.HitZone.BODY) -> Dictionary:
	return Damage.info(amount, Enums.DamageType.BULLET, zone, P9, Vector3.ZERO, Vector3.FORWARD, 1)


func test_scene_instantiates_headless() -> void:
	var r: FiringRange = await _spawn_range()
	assert_true(r.is_inside_tree())
	assert_true(r.overlay != null, "overlay built")
	# ENV A's crew via RangeCrewBridge when CrewController provides spawn_for_range, otherwise the
	# fallback range camera. Exactly one shooter.
	assert_eq(r.crew != null, RangeCrewBridge.available(), "real crew iff the hook exists")
	if r.crew != null:
		assert_true(r.spectator == null, "real crew spawned -> no fallback range camera")
	else:
		assert_true(r.spectator != null, "no range crew -> fallback range camera")
	assert_eq(r.targets.size(), r.layout.lane_count())
	assert_true(r.level.get_node("Floor").get_child_count() > 0, "greybox floor pieces instanced")
	assert_true(r.level.get_node("Walls").get_child_count() > 0, "greybox wall pieces instanced")
	assert_eq(r.current_weapon_id(), P9)


func test_layout_is_built_from_data() -> void:
	var r: FiringRange = await _spawn_range()
	var expected: PackedFloat32Array = PackedFloat32Array([5, 10, 15, 20, 30, 40, 60, 80, 100])
	assert_eq(r.layout.marker_distances, expected, "range_layout.tres marker distances")
	assert_eq(r.markers.size(), expected.size(), "one marker per distance")
	for i: int in range(r.markers.size()):
		var m: Node3D = r.markers[i]
		assert_near(float(m.get_meta(&"distance_m")), expected[i])
		assert_near(m.position.z, -expected[i], 0.001, "marker at -distance")
	assert_eq(get_tree().get_nodes_in_group(RangeBuilder.MARKER_GROUP).size(), expected.size())
	for t: RangeTarget in r.targets:
		assert_near(t.position.z, -r.layout.lane_target_distances[t.lane], 0.001)
		assert_near(t.position.x, r.layout.lane_x(t.lane), 0.001)
	assert_true(r.layout.length_m() >= 100.0, "range is longer than the last marker")


func test_target_dies_at_dummy_hp() -> void:
	var t: RangeTarget = _target(Enums.Difficulty.ROUTINE)
	assert_near(t.max_health, 80.0)
	var res: Dictionary = t.take_hit(_info(79.0), 1)
	assert_false(bool(res["killed"]))
	assert_near(t.health, 1.0)
	assert_true(t.alive)
	res = t.take_hit(_info(1.0), 1)
	assert_true(bool(res["killed"]), "dies exactly at 80 HP")
	assert_false(t.alive)
	assert_true(t.take_hit(_info(10.0), 1).is_empty(), "a downed target ignores hits")
	t.set_difficulty(Enums.Difficulty.BRUTAL)
	assert_near(t.max_health, 240.0, 0.001, "Brutal HP from range_dummies.tres")
	assert_true(t.alive, "difficulty change resets the target")
	t.queue_free()


func test_target_auto_resets_after_death() -> void:
	var t: RangeTarget = _target()
	t.take_hit(_info(500.0), 1)
	assert_false(t.alive)
	var ok: bool = await wait_until(func() -> bool: return t.alive, t.dummy.respawn_delay_s + 2.0)
	assert_true(ok, "stands back up after respawn_delay_s")
	assert_near(t.health, t.max_health)
	t.queue_free()


func test_headshot_multiplier_applies() -> void:
	var t: RangeTarget = _target(Enums.Difficulty.ROUTINE)
	var res: Dictionary = t.take_hit(_info(35.0, Enums.HitZone.HEAD), 1)
	assert_near(float(res["amount"]), 70.0, 0.001, "Routine: 35 x dummy 2 x weapon bonus 1.0")
	t.set_difficulty(Enums.Difficulty.BRUTAL)
	res = t.take_hit(_info(35.0, Enums.HitZone.HEAD), 1)
	assert_near(float(res["amount"]), 210.0, 0.001, "Brutal x6")
	res = t.take_hit(_info(10.0, Enums.HitZone.BODY), 1)
	assert_near(float(res["amount"]), 10.0, 0.001, "body x1")
	t.set_difficulty(Enums.Difficulty.BRUTAL)
	var bonus: Dictionary = _info(10.0, Enums.HitZone.HEAD)
	bonus["headshot_bonus"] = 1.5
	res = t.take_hit(bonus, 1)
	assert_near(float(res["amount"]), 90.0, 0.001, "head: dummy x6 x weapon bonus 1.5")
	bonus["zone"] = Enums.HitZone.BODY
	res = t.take_hit(bonus, 1)
	assert_near(float(res["amount"]), 10.0, 0.001, "the headshot bonus only applies to HEAD")
	t.queue_free()


func test_headshot_readout_uses_weapon_bonus() -> void:
	var s: WeaponStats = LoadoutResolver.resolve_weapon(P9, [])
	assert_near(s.headshot_mult, 1.0, 0.0001, "P9 weapon headshot bonus is 1.0 (D-026)")
	var ro: Dictionary = RangeMath.readout(s, 80.0, 2.0, 5.0)
	assert_near(float(ro["head_damage"]), 70.0, 0.0001, "35 x 2 x 1.0")
	var bonus: WeaponStats = s.duplicate() as WeaponStats
	bonus.headshot_mult = 1.5
	ro = RangeMath.readout(bonus, 80.0, 2.0, 5.0)
	assert_near(float(ro["head_damage"]), 105.0, 0.0001, "35 x 2 x 1.5")
	var info: Dictionary = RangeDebugGun.make_info(bonus, P9, 5.0, Enums.HitZone.HEAD, Vector3.ZERO, Vector3.FORWARD)
	assert_near(float(info["amount"]), 35.0, 0.0001, "info.amount is body damage")
	assert_near(float(info["headshot_bonus"]), 1.5, 0.0001, "weapon bonus travels in the info")


func test_falloff_matches_resolved_stats() -> void:
	var s: WeaponStats = LoadoutResolver.resolve_weapon(P9, [])
	assert_near(RangeMath.pellet_damage(s, 5.0), s.damage, 0.0001, "5 m is before falloff_start")
	assert_near(RangeMath.pellet_damage(s, 40.0), s.damage * s.falloff_min_mult, 0.0001, "40 m is past falloff_end")
	# Kestrel P9 hand values: 35 dmg, falloff 15 -> 30 m to x0.5.
	assert_near(RangeMath.pellet_damage(s, 5.0), 35.0)
	assert_near(RangeMath.pellet_damage(s, 40.0), 17.5)
	assert_near(RangeMath.pellet_damage(s, 22.5), 26.25, 0.0001, "halfway through the ramp")
	var sniper: WeaponStats = WeaponStats.new()
	sniper.damage = 100.0
	sniper.falloff_start_m = 20.0
	sniper.falloff_end_m = 40.0
	sniper.falloff_min_mult = 1.5
	assert_near(RangeMath.pellet_damage(sniper, 60.0), 150.0, 0.0001, "snipers gain damage (L3.2)")


func test_ttk_readout_equals_hand_computed() -> void:
	var r: FiringRange = await _spawn_range()
	r.set_readout_lane(_lane_at(r, 10.0))
	var ro: Dictionary = r.readout()
	assert_true(float(ro["distance_m"]) < 15.0, "10 m lane stays before the P9's falloff start")
	# Routine 80 HP: body 35 -> 3 shots, 2 intervals of 60/480 s; head 70 -> 2 shots.
	assert_eq(int(ro["shots_body"]), 3)
	assert_near(float(ro["ttk_body_s"]), 0.25)
	assert_eq(int(ro["shots_head"]), 2)
	assert_near(float(ro["ttk_head_s"]), 0.125)
	assert_near(float(ro["dps"]), 35.0 * 8.0, 0.001, "35 dmg x 8 shots/s")
	r.set_difficulty(Enums.Difficulty.BRUTAL)
	ro = r.readout()
	assert_eq(int(ro["shots_body"]), 7, "240 HP / 35")
	assert_near(float(ro["ttk_body_s"]), 0.75)
	assert_eq(r.overlay.value_text("ro_ttk_body"), UiText.t(&"ui.range.fmt.ttk", {"shots": 7, "time": "0.75"}))
	# Across a magazine: 1000 HP / 35 = 29 shots, one empty reload (17-round mag, 2.1 s).
	var s: WeaponStats = r.weapon_stats
	assert_near(RangeMath.time_to_kill_s(s, 29), 27.0 * 0.125 + 2.1, 0.0001)


func test_loadout_swap_changes_panel_stats() -> void:
	var r: FiringRange = await _spawn_range()
	var before: String = r.overlay.value_text("mag")
	assert_eq(before, str(r.weapon_stats.mag_size))
	var opt: OptionButton = r.overlay.mod_options.get(int(Enums.ModType.MAGAZINE)) as OptionButton
	assert_true(opt != null, "magazine slot option exists")
	var ids: Array[StringName] = opt.get_meta(&"ids")
	var idx: int = ids.find(EXT_MAG)
	assert_true(idx >= 0)
	opt.select(idx)
	opt.item_selected.emit(idx)
	var expected: WeaponStats = LoadoutResolver.resolve_weapon(P9, [EXT_MAG])
	assert_eq(r.weapon_stats.mag_size, expected.mag_size, "resolved through LoadoutResolver")
	assert_ne(r.overlay.value_text("mag"), before, "panel updates instantly")
	assert_eq(r.overlay.value_text("mag"), str(expected.mag_size))
	if r.crew != null:
		assert_eq(int(RangeCrewBridge.ammo(r.crew)["mag_size"]), expected.mag_size, "crew re-armed")
	else:
		assert_eq(r.spectator.gun.ammo, expected.mag_size, "range gun re-equipped")


func test_take_hit_is_the_single_hit_path() -> void:
	var t: RangeTarget = _target()
	assert_true(t.net_id != Ids.INVALID, "target has a net id")
	assert_eq(Ids.lookup(t.net_id), t)
	assert_true(t.is_in_group(G.RANGE_TARGET), "joins G.RANGE_TARGET")
	assert_false(t.has_method(&"apply_damage"), "no second public hit API")
	var seen: Array[Dictionary] = []
	var on_applied: Callable = func(victim: int, attacker: int, info: Dictionary) -> void:
		seen.append({"victim": victim, "attacker": attacker, "info": info})
	EventBus.damage_applied.connect(on_applied)
	var res: Dictionary = t.take_hit(_info(30.0), 7)
	EventBus.damage_applied.disconnect(on_applied)
	assert_eq(seen.size(), 1, "the target emits damage_applied exactly once itself")
	assert_eq(int(seen[0]["victim"]), t.net_id)
	assert_eq(int(seen[0]["attacker"]), 7)
	assert_near(float((seen[0]["info"] as Dictionary)["amount"]), 30.0, 0.001)
	assert_near(t.health, 50.0, 0.001, "applied once, not again through the event")
	assert_false(bool(res["killed"]))
	EventBus.damage_applied.emit(t.net_id, 1, _info(30.0))
	assert_near(t.health, 50.0, 0.001, "targets never act on damage_applied")
	t.queue_free()


func test_hitboxes_resolve_through_damage_helper() -> void:
	var t: RangeTarget = _target()
	for hb: RangeHitbox in t.hitboxes():
		assert_eq(Damage.find_target(hb), t)
		assert_eq(Damage.zone_of(hb), int(hb.zone))
	t.queue_free()


func test_fallback_debug_hitscan_hits_target() -> void:
	var r: FiringRange = await _spawn_range(true)
	assert_true(r.crew == null and r.spectator != null, "fallback shooter forced")
	var lane: int = _lane_at(r, 10.0)
	var t: RangeTarget = r.targets[lane]
	var steady: WeaponStats = r.weapon_stats.duplicate() as WeaponStats
	steady.spread_deg_hip = 0.0
	steady.spread_deg_ads = 0.0
	r.spectator.gun.equip(P9, steady, false)
	r.spectator.look_at_point(t.zone_position(Enums.HitZone.BODY))
	await wait_physics_frames(2)
	r.spectator.request_shot()
	await wait_physics_frames(3)
	assert_near(t.health, t.max_health - 35.0, 0.001, "one body hit, no falloff at 10 m")
	assert_eq(int(r.last_shot.get("zone", -1)), int(Enums.HitZone.BODY))
	assert_near(float(r.last_shot.get("distance_m", 0.0)), r.spectator.global_position.distance_to(t.zone_position(Enums.HitZone.BODY)), 0.2)
	assert_eq(r.spectator.gun.ammo, steady.mag_size - 1)
	assert_eq(r.readout_lane, lane)


func test_range_strings_exist() -> void:
	var table: Dictionary = StringTable.parse_csv()
	var rx: RegEx = RegEx.create_from_string("&?\"((?:ui|item)\\.[a-z0-9_.]+)\"")
	var found: int = 0
	for f: String in DirAccess.get_files_at("res://content/range"):
		if not f.ends_with(".gd"):
			continue
		for m: RegExMatch in rx.search_all(FileAccess.get_file_as_string("res://content/range".path_join(f))):
			found += 1
			assert_has(table, m.get_string(1), "used in %s" % f)
	assert_true(found > 40, "found %d keys" % found)
	for z: int in range(Enums.HitZone.size()):
		assert_has(table, String(RangeOverlay.zone_key(z)))
	assert_has(table, String(_dummy().name_key))
	for kind: StringName in [ContentDB.WEAPONS, ContentDB.MODS]:
		for res: Resource in ContentDB.all_of(kind):
			assert_has(table, String(UiText.item_key(StringName(res.get(&"id")))), "loadout swap option name")


func test_crit_applies_head_mult_on_any_zone() -> void:
	var t: RangeTarget = _target()
	var hm: float = t.headshot_mult()
	var bi: Dictionary = _info(10.0)
	bi["crit"] = true
	var body: Dictionary = t.take_hit(bi, 0)
	assert_near(float(body["amount"]), 10.0 * hm, 0.001, "body crit = body x head mult")
	t.reset_target()
	var hi: Dictionary = _info(10.0, Enums.HitZone.HEAD)
	hi["crit"] = true
	var head: Dictionary = t.take_hit(hi, 0)
	assert_near(float(head["amount"]), 10.0 * hm * hm, 0.001, "head crit stacks")
	t.queue_free()


# --- ENV A's real crew member + weapon runtime (QB-25, D-026) ------------------------------------

func _crew_range() -> FiringRange:
	if not RangeCrewBridge.available():
		skip("CrewController.spawn_for_range not in this tree (fallback covered above)")
		return null
	var r: FiringRange = await _spawn_range()
	await wait_physics_frames(10)  # settle on the floor
	return r


## Intent looking from the crew's eye at `p` (crew_intent.md: absolute yaw/pitch, -Z forward).
func _intent_at(crew: Node, p: Vector3, fire: bool) -> CrewIntent:
	var d: Vector3 = (p - RangeCrewBridge.eye_position(crew)).normalized()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = asin(clampf(d.y, -1.0, 1.0))
	i.aim = true
	i.fire = fire
	return i


func test_crew_spawns_with_camera_and_paused_input() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	assert_true(r.crew.get_parent() == r, "crew member lives in the range")
	assert_true(RangeCrewBridge.net_id(r.crew) > 0, "crew has a net id")
	assert_eq(r.shooter_net_id(), RangeCrewBridge.net_id(r.crew))
	var cam: Camera3D = RangeCrewBridge.camera(r.crew)
	assert_true(cam != null and cam.current, "crew first-person camera is active")
	assert_eq(get_viewport().get_camera_3d(), cam)
	assert_true(r.viewmodel != null and r.viewmodel.get_parent() == cam, "weapon viewmodel on the camera")
	assert_eq(r.crew.get(&"weapon_visual"), r.viewmodel, "crew muzzle comes from the viewmodel")
	assert_true(r.mode_input != null, "panel/aim mode input")
	assert_false(r.aim_mode)
	assert_false(RangeCrewBridge.input_enabled(r.crew), "panel mode pauses the crew input")
	r.set_aim_mode(true)
	await wait_physics_frames(1)
	assert_true(RangeCrewBridge.input_enabled(r.crew), "aim mode resumes it (fire not held)")
	assert_false(r.overlay.interactive, "panels read-only while aiming")
	r.set_aim_mode(false)
	assert_false(RangeCrewBridge.input_enabled(r.crew), "back to the panels pauses it again")
	assert_false(bool(r.crew.get(&"intent").get(&"fire")), "neutral intent while paused")
	assert_true(r.overlay.interactive)


func test_loadout_swap_reaches_crew() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	r.set_mod(int(Enums.ModType.MAGAZINE), EXT_MAG)
	var expected: WeaponStats = LoadoutResolver.resolve_weapon(P9, [EXT_MAG])
	var lo: Loadout = r.crew.get(&"loadout") as Loadout
	assert_true(lo != null and lo.resolved_secondary != null, "crew got a resolved loadout")
	assert_eq(lo.resolved_secondary.mag_size, expected.mag_size, "set_loadout(resolved) reached the crew")
	var a: Dictionary = RangeCrewBridge.ammo(r.crew)
	assert_eq(int(a["mag_size"]), expected.mag_size)
	assert_eq(int(a["mag"]), expected.mag_size, "re-armed with a full magazine")
	var other: StringName = &""
	for w: WeaponDef in ContentDB.all_weapons():
		if w.id != P9 and w.slot == Enums.WeaponSlot.PRIMARY:
			other = w.id
			break
	if other != &"":
		r.select_weapon(other)
		lo = r.crew.get(&"loadout") as Loadout
		assert_eq(lo.primary, other, "weapon swap reaches the crew")
		var w_obj: Object = r.crew.get(&"weapons") as Object
		assert_eq(int(w_obj.get(&"equipped_slot")), int(Enums.WeaponSlot.PRIMARY), "crew equips the new weapon")


func test_real_crew_shot_damages_target_once() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var lane: int = _lane_at(r, 10.0)
	var t: RangeTarget = r.targets[lane]
	r.set_readout_lane(0 if lane != 0 else 1)
	var crew: Node = r.crew
	var crew_id: int = RangeCrewBridge.net_id(crew)
	var aim_at: Vector3 = t.zone_position(Enums.HitZone.BODY)
	var mag_before: int = int(RangeCrewBridge.ammo(crew)["mag"])
	var seen: Array[Dictionary] = []
	var on_applied: Callable = func(victim: int, attacker: int, info: Dictionary) -> void:
		if victim == t.net_id:
			seen.append({"attacker": attacker, "info": info})
	EventBus.damage_applied.connect(on_applied)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, false))
	await wait_physics_frames(2)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, true))  # trigger press (semi-auto: one shot)
	await wait_physics_frames(6)
	crew.call(&"apply_intent", _intent_at(crew, aim_at, false))
	await wait_physics_frames(2)
	EventBus.damage_applied.disconnect(on_applied)
	assert_eq(seen.size(), 1, "one trigger press -> exactly one damage_applied (single hit path)")
	if seen.is_empty():
		return
	assert_eq(int(seen[0]["attacker"]), crew_id, "attacker is the crew's net id")
	var dmg: float = float((seen[0]["info"] as Dictionary)["amount"])
	assert_near(dmg, 35.0, 0.001, "P9 body hit at ~10 m: 35, no falloff")
	assert_near(t.health, t.max_health - 35.0, 0.001, "damage applied once, not twice")
	assert_eq(int(RangeCrewBridge.ammo(crew)["mag"]), mag_before - 1, "one round from the real weapon runtime")
	assert_eq(int(r.last_shot.get("attacker_net_id", -1)), crew_id, "last shot from damage_applied")
	assert_eq(int(r.last_shot.get("zone", -1)), int(Enums.HitZone.BODY))
	assert_near(float(r.last_shot.get("distance_m", 0.0)), RangeCrewBridge.eye_position(crew).distance_to(aim_at), 0.3)
	assert_eq(r.readout_lane, lane, "readout follows the hit lane")
	assert_eq(r.overlay.value_text("ls_damage"), "35")
	await wait_frames(1)
	var a: Dictionary = RangeCrewBridge.ammo(crew)
	assert_eq(r.overlay.ammo_text(), UiText.t(&"ui.range.ammo_reserve",
			{"ammo": int(a["mag"]), "mag": int(a["mag_size"]), "reserve": int(a["reserve"])}), "overlay ammo from the crew")


func test_range_ignores_other_attackers() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var t: RangeTarget = r.targets[0]
	t.take_hit(_info(10.0), RangeCrewBridge.net_id(r.crew) + 1000)
	assert_true(r.last_shot.is_empty(), "hits by someone else are not the range's last shot")
	t.take_hit(_info(10.0), r.shooter_net_id())
	assert_false(r.last_shot.is_empty(), "hits by the range shooter are")


func test_reset_rearms_crew() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var w: Object = r.crew.get(&"weapons") as Object
	var ws: int = int(w.get(&"equipped_slot"))
	w.call(&"set_ammo", ws, 2, 5)
	r.reset_targets()
	var a: Dictionary = RangeCrewBridge.ammo(r.crew)
	assert_eq(int(a["mag"]), int(a["mag_size"]), "full magazine after reset")
	assert_true(int(a["reserve"]) > 5, "reserve refilled")
