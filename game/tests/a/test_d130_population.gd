## D-130 §1 (M stealth heists): guard and civilian counts at load scale with difficulty through C's variant rows
## (difficulty_add on guard AND civilian groups, every extra its own VariantSlot spawn). The runtime spawns every spawn
## point of an active slot, uncapped (director caps gate police / specials only). Ranges per seed from ENV C
## (env/c-worlds a5f115c1; c/test_d130_population pins the expected-value curve). Skipped until C's rows are on the map.
extends TestCase

const SEEDS: Array[int] = [11, 21, 1792002290]
## heist -> {tag set, Routine [min, max], Cataclysm [min, max]} per counted kind.
const ND_GUARD_TAGS: Array[StringName] = [&"guard_hall", &"guard_basement", &"guard_rover"]
const ND_CIV_TAGS: Array[StringName] = [&"civ_manager", &"civ_cleaner"]
const GN_GUARD_TAGS: Array[StringName] = [&"guard_hall", &"guard_rover_ground", &"guard_rover_upper",
	&"guard_rover_basement", &"guard_mews"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_d130_night_deposit_population() -> void:
	if not _has_rule(&"night_deposit", &"cleaner"):
		skip("pending ENV C's D-130 ND rows (cleaner difficulty_add)")
		return
	await _check(&"night_deposit", ND_GUARD_TAGS, [2, 3], [4, 5], ND_CIV_TAGS, [0, 2], [1, 3])


func test_d130_gallery_night_population() -> void:
	if not _has_rule(&"gallery_night", &"gala_extra"):
		skip("pending ENV C's D-130 GN rows (gala_extra)")
		return
	await _check(&"gallery_night", GN_GUARD_TAGS, [1, 2], [5, 5], [], [8, 14], [10, 21])


func _check(heist: StringName, guard_tags: Array[StringName], g_r: Array, g_c: Array, civ_tags: Array[StringName],
		c_r: Array, c_c: Array) -> void:
	for sd: int in SEEDS:
		for diff: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.CATACLYSM]:
			_rt = await HeistLauncher.launch(heist, sd, diff, self, {"crew_ai": false, "ai_teammates": 0})
			await wait_physics_frames(2)
			var g: int = _count(&"guard", guard_tags)
			var c: int = _count(&"civilian", civ_tags)
			var gw: Array = g_r if diff == Enums.Difficulty.ROUTINE else g_c
			var cw: Array = c_r if diff == Enums.Difficulty.ROUTINE else c_c
			var label: String = "%s seed %d %s" % [heist, sd, "Routine" if diff == Enums.Difficulty.ROUTINE else "Cataclysm"]
			print("[d130] %s: %d guards, %d civilians" % [label, g, c])
			assert_true(g >= int(gw[0]) and g <= int(gw[1]), "%s: %d guards in %s" % [label, g, gw])
			assert_true(c >= int(cw[0]) and c <= int(cw[1]), "%s: %d civilians in %s" % [label, c, cw])
			_rt.teardown()
			_rt = null
			await wait_frames(2)


## NPCs of `role` spawned at a SpawnPoint carrying any of `tags` (all of the role when `tags` is empty).
func _count(role: StringName, tags: Array[StringName]) -> int:
	var n: int = 0
	for node: Node in _rt.npcs(role):
		var npc: NpcBase = node as NpcBase
		if npc == null:
			continue
		var t: Array = npc.spawn_info.get("tags", []) as Array
		if tags.is_empty() or tags.any(func(x: StringName) -> bool: return t.has(x)):
			n += 1
	return n


func _has_rule(heist: StringName, group: StringName) -> bool:
	var map: HeistMap = (load(HeistLauncher.map_path(heist)) as PackedScene).instantiate() as HeistMap
	var ok: bool = false
	if map.variant_table != null:
		for r: Dictionary in map.variant_table.rules:
			if StringName(r.get("group", &"")) == group and not (r.get("difficulty_add", []) as Array).is_empty():
				ok = true
	map.free()
	return ok
