## A2-05 / S3.7: body-shot kills of guards misfire 10% of the time (GameRng &"misfire"): an NPC
## gunshot NoiseEvent (25 m) from the dead guard alerts nearby NPCs. Headshots, shotguns, non-bullet
## kills and loud kills never misfire.
extends TestCase

var _rt: HeistRuntime = null
var _noises: Array[Dictionary] = []


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1234, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	await wait_physics_frames(1)
	_noises.clear()
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, src: int) -> void:
		_noises.append({"pos": p, "radius": r, "kind": k, "src": src}))


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _spawn_guard(pos: Vector3) -> NpcBase:
	return _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, pos))


func _kill(npc: NpcBase, zone: int, type: int = Enums.DamageType.BULLET, weapon: StringName = &"weapon.kestrel_p9") -> void:
	var info: Dictionary = Damage.info(100000.0, type, zone, weapon, npc.global_position, Vector3.FORWARD)
	npc.take_hit(info, 0)


## Kills `n` freshly spawned guards with `zone`/`type`/`weapon` hits; returns how many misfired.
func _kill_many(n: int, zone: int, type: int = Enums.DamageType.BULLET, weapon: StringName = &"weapon.kestrel_p9") -> int:
	var misfires: int = 0
	for i: int in range(n):
		var g: NpcBase = _spawn_guard(Vector3(float(i % 10) * 2.0, 0.05, -20.0 - floorf(float(i) / 10.0) * 2.0))
		_kill(g, zone, type, weapon)
		if (g.get_node("Brain") as GuardBrain).misfired:
			misfires += 1
	return misfires


func test_s3_7_body_shot_misfire_rate_about_10_percent() -> void:
	await wait_physics_frames(1)
	var n: int = 300
	var m: int = _kill_many(n, Enums.HitZone.BODY)
	assert_true(m >= 15 and m <= 50, "~10%% of %d body-shot kills misfire (got %d)" % [n, m])
	var gun: int = 0
	for d: Dictionary in _noises:
		if d["kind"] == &"gunshot":
			gun += 1
			assert_near(float(d["radius"]), Tweak.stealth().gunshot_npc_radius_m, 0.001, "NPC gunshot radius 25 m")
	assert_eq(gun, m, "one NPC gunshot noise per misfire")
	assert_near(Tweak.stealth().misfire_chance, 0.1, 0.0001, "S3.7: 10%")


func test_s3_7_headshots_melee_and_scripted_deaths_never_misfire() -> void:
	assert_eq(_kill_many(60, Enums.HitZone.HEAD), 0, "headshots")
	assert_eq(_kill_many(60, Enums.HitZone.BODY, Enums.DamageType.MELEE), 0, "melee")
	var g: NpcBase = _spawn_guard(Vector3(0, 0.05, -5))
	g.die()
	assert_false((g.get_node("Brain") as GuardBrain).misfired, "scripted die() is not a hit")
	assert_true(_noises.is_empty(), "no gunshot noise")


func test_s3_7_shotgun_kills_never_misfire() -> void:
	var shotgun: StringName = &""
	for d: Variant in ContentDB.all_weapons():
		var w: WeaponDef = d as WeaponDef
		if w != null and w.weapon_class == Enums.WeaponClass.SHOTGUN:
			shotgun = w.id
			break
	if shotgun == &"":
		skip("no shotgun WeaponDef in content yet")
		return
	assert_eq(_kill_many(60, Enums.HitZone.BODY, Enums.DamageType.BULLET, shotgun), 0, "shotgun kills")


func test_s3_7_misfire_alerts_nearby_guard() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var was: float = tw.misfire_chance
	tw.misfire_chance = 1.0
	var listener: NpcBase = _spawn_guard(Vector3(10, 0.05, -5))
	var victim: NpcBase = _spawn_guard(Vector3(0, 0.05, -5))
	await wait_physics_frames(3)
	_kill(victim, Enums.HitZone.BODY)
	tw.misfire_chance = was
	await wait_physics_frames(2)
	assert_true((victim.get_node("Brain") as GuardBrain).misfired)
	assert_eq(StringName(_noises[0]["kind"]), &"gunshot")
	assert_eq(int(_noises[0]["src"]), victim.net_id, "noise source = the dead guard")
	assert_eq((listener.get_node("Brain") as GuardBrain).state_name(), &"alarmed", "listener reacts to the gunshot")


func test_s3_7_no_misfire_when_loud() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var was: float = tw.misfire_chance
	tw.misfire_chance = 1.0
	_rt.stealth.raise_alarm(&"scripted")
	await wait_physics_frames(2)
	var m: int = _kill_many(5, Enums.HitZone.BODY)
	tw.misfire_chance = was
	assert_eq(m, 0, "loud: no misfire")
