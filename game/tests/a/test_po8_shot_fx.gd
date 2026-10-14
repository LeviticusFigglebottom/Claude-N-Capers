## PO-8 (D-105, impact_fx.md 1.0 §1-§2): EventBus.shot_fx once per hitscan ray / pellet with the impact
## point, normal and surface (metadata/surface on the hit body), a miss at max range (surface &"", normal ZERO),
## suppressed / first-person / headshot flags, NPC shots, melee (&"melee") and explosion_fx.
## Host + client parity is in test_po8_shot_fx_loopback.gd.
extends TestCase

var _rt: HeistRuntime = null
var _shots: Array[Dictionary] = []
var _blasts: Array[Dictionary] = []


func before_each() -> void:
	_shots = []
	_blasts = []
	EventBus.shot_fx.connect(_on_shot_fx)
	EventBus.explosion_fx.connect(_on_explosion_fx)


func after_each() -> void:
	if EventBus.shot_fx.is_connected(_on_shot_fx):
		EventBus.shot_fx.disconnect(_on_shot_fx)
	if EventBus.explosion_fx.is_connected(_on_explosion_fx):
		EventBus.explosion_fx.disconnect(_on_explosion_fx)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _on_shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
		shooter: int, flags: int) -> void:
	_shots.append({"origin": origin, "end": end, "normal": normal, "surface": surface, "class": weapon_class,
		"shooter": shooter, "flags": flags})


func _on_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	_blasts.append({"pos": pos, "radius": radius, "kind": kind})


func _launch(guards: int = 0, secondary: StringName = &"", melee: StringName = &"") -> CrewController:
	var l: Loadout = null
	if secondary != &"" or melee != &"":
		l = Loadout.new()
		l.secondary = secondary if secondary != &"" else &"weapon.kestrel_p9"
		l.melee = melee
		l = CrewWeapons.build_loadout(l)
	var opts: Dictionary = {"map_packed": ATestMaps.basic(guards, 0), "crew_ai": false, "ai_teammates": 0,
		"skip_casing": true}
	if l != null:
		opts["loadouts"] = {0: l}
	_rt = await HeistLauncher.launch(&"unit_map", 8108, Enums.Difficulty.ROUTINE, self, opts)
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	_shots.clear()
	return c


## One trigger pull aimed with `intent`.
func _pull(intent: CrewIntent) -> void:
	intent.fire = true
	_rt.set_bot_intent(0, intent)
	await wait_physics_frames(2)
	var rel: CrewIntent = CrewIntent.new()
	rel.look_yaw = intent.look_yaw
	rel.look_pitch = intent.look_pitch
	_rt.set_bot_intent(0, rel)
	await wait_physics_frames(1)


func _of(shooter: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _shots:
		if int(s["shooter"]) == shooter:
			out.append(s)
	return out


func test_crew_shotgun_one_fx_per_pellet_on_metal_wall() -> void:
	var c: CrewController = await _launch(0, &"weapon.mule_12")
	var wall: StaticBody3D = ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -4.0), Vector3(8, 3, 0.3))
	wall.set_meta(&"surface", &"metal")
	await wait_physics_frames(2)
	var st: WeaponStats = c.weapons.stats(Enums.WeaponSlot.SECONDARY)
	assert_true(st != null and st.pellets > 1, "mule_12 is a multi-pellet shotgun")
	await _pull(BotUtil.look_at_intent(c.eye_position(), Vector3(0, c.eye_position().y, -4.0)))
	var mine: Array[Dictionary] = _of(c.net_id)
	assert_eq(c.weapons.shots_fired, 1, "one shot")
	assert_eq(mine.size(), st.pellets if st != null else -1, "one shot_fx per pellet")
	for s: Dictionary in mine:
		var end: Vector3 = s["end"]
		assert_near(end.z, -3.85, 0.02, "pellet ends on the wall face (%s)" % end)
		assert_true((s["normal"] as Vector3).distance_to(Vector3(0, 0, 1)) < 0.01, "wall normal (%s)" % s["normal"])
		assert_eq(StringName(s["surface"]), &"metal", "metadata/surface of the wall")
		assert_eq(StringName(s["class"]), &"shotgun", "weapon class")
		assert_eq(int(s["flags"]) & ShotFx.FLAG_SUPPRESSED, 0, "unsuppressed")
		assert_eq(int(s["flags"]) & ShotFx.FLAG_FIRST_PERSON != 0, c.is_local(), "first-person flag = local human")
		assert_eq(int(s["flags"]) & ShotFx.FLAG_HEADSHOT, 0, "no headshot on a wall")
	var ends: Dictionary = {}
	for s: Dictionary in mine:
		ends[s["end"]] = true
	assert_true(ends.size() > 1, "pellets spread (%d distinct ends)" % ends.size())


func test_miss_ends_at_max_range_with_no_surface() -> void:
	var c: CrewController = await _launch(0)
	var i: CrewIntent = CrewIntent.new()
	i.look_pitch = deg_to_rad(60.0)
	var eye: Vector3 = c.eye_position()
	await _pull(i)
	var mine: Array[Dictionary] = _of(c.net_id)
	assert_eq(mine.size(), 1, "one pellet, one shot_fx")
	if mine.size() == 1:
		var s: Dictionary = mine[0]
		assert_near((s["end"] as Vector3).distance_to(eye), CombatTweak.data().hitscan_max_range_m, 0.5, "end at max range")
		assert_eq(s["normal"], Vector3.ZERO, "miss: normal ZERO")
		assert_eq(StringName(s["surface"]), &"", "miss: surface &\"\"")
		assert_eq(StringName(s["class"]), &"pistol", "kestrel_p9 is a pistol")
		assert_true(int(s["flags"]) & ShotFx.FLAG_SUPPRESSED != 0, "default kestrel is suppressed (D-025)")


func test_headshot_flag_and_flesh() -> void:
	var c: CrewController = await _launch(1)
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0, 3.0)))
	await wait_physics_frames(3)
	_shots.clear()
	await _pull(BotUtil.look_at_intent(c.eye_position(), g.head_position()))
	var mine: Array[Dictionary] = _of(c.net_id)
	assert_eq(mine.size(), 1, "one shot_fx")
	if mine.size() == 1:
		assert_true(int(mine[0]["flags"]) & ShotFx.FLAG_HEADSHOT != 0, "headshot flag")
		assert_eq(StringName(mine[0]["surface"]), &"flesh", "a character is flesh")
		assert_true((mine[0]["end"] as Vector3).distance_to(g.head_position()) < 0.6, "ends at the head")
	assert_false(g.alive, "and the shot really killed the guard")


func test_npc_shot_emits() -> void:
	var c: CrewController = await _launch(0)
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	_shots.clear()
	gun.call(&"_fire", c)
	var theirs: Array[Dictionary] = _of(p.net_id)
	assert_eq(theirs.size(), 1, "one shot_fx per NPC shot")
	if theirs.size() == 1:
		var s: Dictionary = theirs[0]
		var wid: StringName = p.enemy_def.weapon if p.enemy_def != null else &""
		assert_eq(StringName(s["class"]), ShotFx.npc_weapon_class(wid), "NPC weapon class (%s)" % wid)
		assert_true([&"pistol", &"smg", &"ar", &"shotgun", &"lmg", &"sniper"].has(StringName(s["class"])), "a gun class")
		assert_eq(int(s["flags"]) & ShotFx.FLAG_FIRST_PERSON, 0, "NPC is never first person")
		assert_true((s["origin"] as Vector3).distance_to(p.eye_position()) < 1.5, "origin at the NPC")
		assert_true((s["end"] as Vector3).distance_to(p.eye_position()) > 3.0, "ends downrange")
	# Hit vs miss both emit: fire until both outcomes were seen (hit chance < 1 at 6 m on ROUTINE varies).
	var outcomes: Dictionary = {}
	var cb: Callable = func(_t: Node, hit: bool) -> void: outcomes[hit] = true
	gun.shot.connect(cb)
	_shots.clear()
	for k: int in range(12):
		gun.call(&"_fire", c)
	gun.shot.disconnect(cb)
	assert_eq(_of(p.net_id).size(), 12, "every NPC shot emits once")
	for s: Dictionary in _of(p.net_id):
		if StringName(s["surface"]) == &"flesh":
			assert_true((s["end"] as Vector3).distance_to(c.global_position + Vector3(0, 1.0, 0)) < 1.2, "a hit ends on the crew")


func test_melee_emits_melee_class() -> void:
	var c: CrewController = await _launch(0, &"", &"melee.folding_knife")
	var n: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -1.2), Vector3(0, 0, 1))
	n.max_health = 100000.0
	n.health = 100000.0
	await wait_physics_frames(2)
	_shots.clear()
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(n))
	i.melee = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.05)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(n)))
	await wait_seconds(0.8)
	var mine: Array[Dictionary] = _of(c.net_id)
	assert_eq(mine.size(), 1, "one shot_fx per melee hit")
	if mine.size() == 1:
		assert_eq(StringName(mine[0]["class"]), ShotFx.CLASS_MELEE, "weapon_class &\"melee\"")
		assert_eq(StringName(mine[0]["surface"]), &"flesh", "melee on a character")
		assert_eq(int(mine[0]["flags"]) & ShotFx.FLAG_FIRST_PERSON != 0, c.is_local(), "first-person flag")


func test_explosion_emits_explosion_fx() -> void:
	var c: CrewController = await _launch(0)
	Explosion.apply(c, Vector3(5, 0.5, 5), 3.0, 10.0, 0, Safe.C4_ITEM)
	assert_eq(_blasts.size(), 1, "one explosion_fx")
	if _blasts.size() == 1:
		assert_eq(_blasts[0]["pos"], Vector3(5, 0.5, 5))
		assert_near(float(_blasts[0]["radius"]), 3.0, 0.0001)
		assert_eq(StringName(_blasts[0]["kind"]), &"c4")
	assert_eq(ShotFx.explosion_kind(&"deployable.trip_mine"), &"trip_mine")
	assert_eq(ShotFx.explosion_kind(&""), &"explosion")


func test_surface_lookup_rules() -> void:
	assert_eq(ShotFx.surface_of(null), &"", "nothing hit")
	var root: Node3D = Node3D.new()
	root.set_meta(&"surface", &"wood")
	var mid: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	root.add_child(mid)
	mid.add_child(body)
	add_child(root)
	assert_eq(ShotFx.surface_of(body), &"wood", "tag on a parent (<= 3 up)")
	var plain: StaticBody3D = StaticBody3D.new()
	add_child(plain)
	assert_eq(ShotFx.surface_of(plain), &"concrete", "default concrete")
	var hb: Hitbox = Hitbox.new()
	hb.hit_zone = Enums.HitZone.WEAKPOINT
	add_child(hb)
	assert_eq(ShotFx.surface_of(hb), &"armor", "weak-point plate is armor")
	root.queue_free()
	plain.queue_free()
	hb.queue_free()
	assert_eq(ShotFx.weapon_class_id(ContentDB.weapon(&"weapon.mule_12")), &"shotgun")
	assert_eq(ShotFx.npc_weapon_class(&"weapon.npc_rifle"), &"ar")
	assert_eq(ShotFx.npc_weapon_class(&"weapon.npc_minigun"), &"lmg")
	assert_eq(ShotFx.npc_weapon_class(&"weapon.npc_sniper"), &"sniper")
