## OF loud hitches (LEAD 2026-10-21): CharacterWarm (world/characters/character_warm.gd), the load-time render-warm ENV A
## calls. heist_cast_paths lists every p5_cast look of a heist (pools + tag_map) as existing scene paths, sorted and
## unique; warm draws a set of looks off-screen (full and CrowdLod proxy), counts each scene once and frees everything.
extends TestCase

const CharacterWarm: GDScript = preload("res://world/characters/character_warm.gd")


func test_heist_cast_paths_cover_the_cast() -> void:
	var paths: PackedStringArray = CharacterWarm.heist_cast_paths(&"ostrander_federal")
	assert_true(paths.size() >= 30, "OF cast looks listed (%d)" % paths.size())
	for want: String in ["bank_vip_client", "security_bodyguard", "npc_bank_teller", "bank_manager", "armored_car_crew"]:
		assert_true(paths.has(CharacterWarm.scene_path(want)), "OF cast includes %s" % want)
	var sorted: PackedStringArray = paths.duplicate()
	sorted.sort()
	assert_eq(paths, sorted, "sorted")
	var uniq: Dictionary = {}
	for p: String in paths:
		assert_false(uniq.has(p), "%s listed once" % p)
		uniq[p] = true
		assert_true(ResourceLoader.exists(p), "%s exists" % p)
	assert_eq(CharacterWarm.heist_cast_paths(&"no_such_heist").size(), 0, "unknown heist: nothing")


func test_warm_draws_each_look_once_and_cleans_up() -> void:
	var paths: PackedStringArray = PackedStringArray([
		CharacterWarm.scene_path("security_officer"), CharacterWarm.scene_path("tac_light_duty"),
		CharacterWarm.scene_path("security_officer"),   # duplicate: drawn once
		"res://world/characters/no_such_look/no_such_look.tscn",
	])
	var warmed: int = await CharacterWarm.warm(self, paths, 1)
	assert_eq(warmed, 2, "two distinct existing looks drawn")
	await get_tree().process_frame
	assert_true(get_node_or_null("CharacterWarm") == null, "the warm viewport is freed")
	assert_eq(await CharacterWarm.warm(self, PackedStringArray(), 1), 0, "nothing to warm")
