## LEAD (D's DB/SL cast audit): looks are dealt per shared POOL. Every Shadow Ledger guard post plus the operator
## share one deal, the two SL cleaner tags another, and cartel gunmen deal their EnemyDef alternates round-robin
## (not hash(name)). No twins while the live count <= the pool's delivered looks; past it, no look over its share.
extends TestCase

const SL_GUARD_TAGS: Array[StringName] = [&"guard_reception", &"guard_roof", &"guard_rover_l41", &"guard_rover_l42",
	&"guard_stair", &"security_operator"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(heist: StringName) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 5151, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	_rt.heist_id = heist
	await wait_physics_frames(2)


func _spawn(role: StringName, i: int, info: Dictionary) -> NpcBase:
	return _rt.spawn_npc(role, Transform3D(Basis.IDENTITY, Vector3(i * 1.5 - 6.0, 0.05, -8.0)), info)


## Delivered looks of a tag's id list (undelivered ids are skipped by the deal).
func _delivered(ids: Array) -> int:
	var n: int = 0
	for id: Variant in ids:
		if ResourceLoader.exists(NpcVisuals.scene_path(String(id))):
			n += 1
	return n


func _check(npcs: Array[NpcBase], pool: int, what: String) -> void:
	var seen: Dictionary = {}
	for k: int in npcs.size():
		var path: String = npcs[k].visual_scene.resource_path if npcs[k].visual_scene != null else ""
		assert_true(path != "", "%s %d dressed" % [what, k])
		if k < pool:
			assert_false(seen.has(path), "%s: no twin among the first %d (%s twice)" % [what, pool, path.get_file()])
		seen[path] = int(seen.get(path, 0)) + 1
	for p: String in seen:
		assert_true(int(seen[p]) <= ceili(float(npcs.size()) / pool), "%s: %s not over its share" % [what, p.get_file()])


func test_sl_guard_posts_and_operator_share_one_pool() -> void:
	await _launch(&"shadow_ledger")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"shadow_ledger"]
	var pool: int = _delivered(m[&"guard_reception"])
	if pool < 2:
		skip("fewer than 2 Northgate looks delivered")
		return
	var npcs: Array[NpcBase] = []
	for i: int in SL_GUARD_TAGS.size():  # one per post: per-tag dealing would twin the first look of every post
		npcs.append(_spawn(&"guard", i, {"tags": [SL_GUARD_TAGS[i]]}))
	_check(npcs, pool, "SL guards")


func test_sl_cleaners_share_one_pool() -> void:
	await _launch(&"shadow_ledger")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"shadow_ledger"]
	var pool: int = _delivered(m[&"civ_cleaner_l41"])
	if pool < 2:
		skip("fewer than 2 SL cleaner looks delivered")
		return
	var npcs: Array[NpcBase] = [_spawn(&"civilian", 0, {"tags": [&"civ_cleaner_l41"]}),
		_spawn(&"civilian", 1, {"tags": [&"civ_cleaner_l42"]})]
	_check(npcs, pool, "SL cleaners")


func test_db_cartel_alternates_dealt_round_robin() -> void:
	await _launch(&"dockside_burn")
	var def: EnemyDef = load(CartelBrain.ENEMY_DEF) as EnemyDef
	var pool: int = 1
	for a: Variant in def.params.get("visual_alternates", []) as Array:
		pool += 1 if ResourceLoader.exists(String(a)) else 0
	if pool < 2:
		skip("no cartel alternates delivered")
		return
	var npcs: Array[NpcBase] = []
	for i: int in pool + 2:
		npcs.append(_spawn(CartelBrain.ROLE, i, {"enemy_def": def, "tags": [CartelBrain.SPAWN_TAG]}))
	_check(npcs, pool, "DB cartel")
	var d: Dictionary = NetEntityCodec.describe(npcs[1])
	assert_eq(int((d["params"] as Dictionary)["look"]), int(npcs[1].spawn_info["look"]), "the pick rides the descriptor")


func test_db_packer_tag_wears_the_packer() -> void:
	await _launch(&"dockside_burn")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"dockside_burn"]
	assert_eq(m[&"civ_worker_packer"], [&"dock_packer"], "packing-table spawn -> dock_packer")
	assert_false((m[&"civ_worker"] as Array).has(&"dock_packer"), "forklift posts: dock_worker / _b only")
	if not ResourceLoader.exists(NpcVisuals.scene_path("dock_packer")):
		skip("dock_packer not delivered")
		return
	var p: NpcBase = _spawn(&"civilian", 0, {"tags": [&"civ_worker_packer"]})
	assert_true(p.visual_scene != null and p.visual_scene.resource_path.contains("dock_packer"), "wears dock_packer")
