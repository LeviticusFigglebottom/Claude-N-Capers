## D-103 §3b.1: a SpawnPoint tag with a character beats the EnemyDef's default character (EnemyDef stays the fallback).
## Heist-scoped tags (NpcVisualTweak.heist_tag_characters) come first, so Gallery Night's guard_hall wears gallery_guard
## while Night Deposit's guard_hall keeps its own look.
extends TestCase

## Characters ENV D has announced but not shipped yet (NpcVisuals falls through to the next rule meanwhile).
## D-130 cast pools (D a04f3536), merged by the LEAD with A's map.
const PENDING_CHARACTERS: Array[String] = ["gallery_guard_c", "gallery_guard_d", "gallery_guard_e", "gallery_guard_f",
	"gallery_guard_g", "gallery_guard_h", "gallery_guard_i", "gallery_patron_h", "gallery_patron_i", "gallery_patron_j",
	"gallery_waiter_b", "gallery_attendant_c"]  # + D 48a7cc3a (p5_cast v7)
const GUARD_DEF: String = "res://systems/ai/data/enemies/security_officer.tres"

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1110, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _guard(pos: Vector3, tags: Array) -> NpcBase:
	return _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, pos), {"enemy_def": load(GUARD_DEF) as EnemyDef, "tags": tags})


static func _path(npc: NpcBase) -> String:
	return npc.visual_scene.resource_path if npc != null and npc.visual_scene != null else "capsule"


func test_gn_tag_beats_the_enemy_def() -> void:
	await _launch()
	var plain: NpcBase = _guard(Vector3(-2, 0.05, -4), [])
	assert_eq(_path(plain), NpcVisuals.scene_path("security_officer"), "no tag: the EnemyDef character")
	var tagged: NpcBase = _guard(Vector3(0, 0.05, -4), [&"civ_manager"])
	assert_eq(_path(tagged), NpcVisuals.scene_path("civilian_manager"), "a mapped tag wins over the EnemyDef")
	var unmapped: NpcBase = _guard(Vector3(2, 0.05, -4), [&"no_such_tag"])
	assert_eq(_path(unmapped), NpcVisuals.scene_path("security_officer"), "unmapped tag: EnemyDef fallback")


func test_gn_heist_scoped_tags_only_apply_to_their_heist() -> void:
	await _launch()
	var elsewhere: NpcBase = _guard(Vector3(-2, 0.05, -4), [&"guard_hall"])
	assert_eq(_path(elsewhere), NpcVisuals.scene_path("security_officer"), "guard_hall outside Gallery Night: unchanged")
	_rt.heist_id = &"gallery_night"
	var gn: NpcBase = _guard(Vector3(0, 0.05, -4), [&"guard_hall"])
	# D-130: guard_hall deals from the 9-look gn_guards pool (the delivered ones).
	assert_true(_path(gn).contains("/gallery_guard"), "Gallery Night guard_hall wears a gallery guard (%s)" % _path(gn))
	var cur: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -4)), {"tags": [&"civ_curator"]})
	assert_eq(_path(cur), NpcVisuals.scene_path("gallery_curator"), "the curator")
	var tw: NpcVisualTweak = NpcVisuals.tweak()
	for tag: Variant in tw.heist_tag_characters[&"gallery_night"]:
		for cid: Variant in tw.heist_tag_characters[&"gallery_night"][tag]:
			if PENDING_CHARACTERS.has(String(cid)):
				continue
			assert_true(ResourceLoader.exists(NpcVisuals.scene_path(String(cid))), "%s -> %s exists" % [tag, cid])
