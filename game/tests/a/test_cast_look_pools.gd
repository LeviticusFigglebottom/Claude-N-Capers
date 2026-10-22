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


func test_nd_hall_basement_rover_share_one_pool() -> void:
	await _launch(&"night_deposit")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"night_deposit"]
	var pool: int = _delivered(m[&"guard_hall"])
	assert_eq(m[&"guard_hall"], m[&"guard_basement"], "one pool lists one set of looks")
	assert_eq(m[&"guard_hall"], m[&"guard_rover"], "one pool lists one set of looks")
	if pool < 2:
		skip("fewer than 2 security_officer looks delivered")
		return
	var npcs: Array[NpcBase] = []
	var tags: Array[StringName] = [&"guard_hall", &"guard_basement", &"guard_rover"]
	for i: int in pool + 1:
		npcs.append(_spawn(&"guard", i, {"tags": [tags[i % tags.size()]]}))
	_check(npcs, pool, "ND guards")


## OF-A6: Ostrander Federal's six guard posts deal one pool of Halden faces (the operator is npc_bank_guard alone).
func test_of_guard_posts_share_one_pool() -> void:
	await _launch(&"ostrander_federal")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"ostrander_federal"]
	var tags: Array[StringName] = [&"guard_lobby", &"guard_vault", &"guard_rover_hall", &"guard_rover_gallery",
		&"guard_rover_basement", &"guard_rover_dock"]
	for t: StringName in tags:
		assert_eq(NpcVisuals.tweak().heist_tag_pools[&"ostrander_federal"][t], &"of_guards", "%s in of_guards" % t)
	var pool: int = _delivered(m[&"guard_lobby"])
	if pool < 2:
		skip("fewer than 2 security_officer looks delivered")
		return
	var npcs: Array[NpcBase] = []
	for i: int in tags.size():
		npcs.append(_spawn(&"guard", i, {"tags": [tags[i]]}))
	_check(npcs, pool, "OF guards")


## RT-D1: the three convoy trucks deal one Vaultline pool, the site posts one Halden pool, the street / bus / diner
## one civilian pool.
func test_rt_pools() -> void:
	await _launch(&"rolling_thunder")
	var tw: NpcVisualTweak = NpcVisuals.tweak()
	var pools: Dictionary = tw.heist_tag_pools[&"rolling_thunder"]
	for t: StringName in [&"convoy_t1", &"convoy_t2", &"convoy_t3"]:
		assert_eq(pools[t], &"rt_convoy", "%s in rt_convoy" % t)
	for t: StringName in [&"guard_site_gate", &"guard_site_frame", &"guard_site_cabins"]:
		assert_eq(pools[t], &"rt_site_guards", "%s in rt_site_guards" % t)
	for t: StringName in [&"civ_street", &"civ_bus", &"civ_diner"]:
		assert_eq(pools[t], &"rt_civilians", "%s in rt_civilians" % t)
	var m: Dictionary = tw.heist_tag_characters[&"rolling_thunder"]
	var pool: int = _delivered(m[&"convoy_t1"])
	if pool < 2:
		skip("fewer than 2 armored_car_crew looks delivered")
		return
	var npcs: Array[NpcBase] = []
	var tags: Array[StringName] = [&"convoy_t1", &"convoy_t2", &"convoy_t3"]
	for i: int in pool:
		npcs.append(_spawn(&"guard", i, {"tags": [tags[i % tags.size()]]}))
	_check(npcs, pool, "RT convoy")


## OF-A6 / D-3 lesson (GH's civ_manager): the shared tag_characters must not dress an OF spawn the heist map covers,
## even when the spawn also carries the shared tag (civ_manager, civ_customer, security_operator).
func test_of_heist_map_beats_the_shared_map() -> void:
	await _launch(&"ostrander_federal")
	var cases: Array = [
		[&"civilian", [&"civ_manager", &"civ_manager_mgr_floor"], "bank_manager"],
		[&"civilian", [&"civ_manager_mgr_vault", &"civ_manager"], "bank_manager"],
		[&"guard", [&"security_operator"], "npc_bank_guard"],
	]
	for i: int in cases.size():
		var c: Array = cases[i]
		var npc: NpcBase = _spawn(c[0], i, {"tags": c[1]})
		var path: String = npc.visual_scene.resource_path if npc.visual_scene != null else "capsule"
		assert_eq(path, NpcVisuals.scene_path(c[2]), "%s -> %s (not the shared map)" % [c[1], c[2]])
	var shared: Array = NpcVisuals.tweak().tag_characters[&"civ_customer"]
	var of_ids: Array = NpcVisuals.tweak().heist_tag_characters[&"ostrander_federal"][&"civ_customer"]
	var cust: NpcBase = _spawn(&"civilian", 5, {"tags": [&"civ_customer"]})
	var cid: StringName = StringName(cust.visual_scene.resource_path.get_file().get_basename())
	assert_true(of_ids.has(cid), "OF civ_customer deals from the OF pool (%s)" % cid)
	assert_true(shared.size() < of_ids.size(), "the OF pool is the bigger one (12 vs the shared 2)")


## D-140 twins audit (D p5_cast v12): Glasshouse's five pager carriers share one 10-look pool (gh_guards), so they no
## longer twin on every seed; customers have 12 looks.
func test_gh_guards_share_one_pool() -> void:
	await _launch(&"glasshouse")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"glasshouse"]
	var tags: Array[StringName] = [&"guard_post_floor", &"guard_rover_boh", &"guard_rover_upper", &"guard_alley_smoker",
		&"security_operator"]
	for t: StringName in tags:
		assert_eq(NpcVisuals.tweak().heist_tag_pools[&"glasshouse"][t], &"gh_guards", "%s in gh_guards" % t)
		assert_eq((m[t] as Array).size(), 10, "%s lists 10 looks" % t)
	assert_eq((m[&"civ_customer"] as Array).size(), 12, "GH customers: 12 looks")
	var pool: int = _delivered(m[&"guard_post_floor"])
	if pool < 2:
		skip("fewer than 2 security_officer looks delivered")
		return
	var npcs: Array[NpcBase] = []
	for i: int in tags.size():
		npcs.append(_spawn(&"guard", i, {"tags": [tags[i]]}))
	_check(npcs, pool, "GH guards")


## D p5_cast v14: OF's safe-deposit attendant wears a bank officer look and shares the officers' deal (3 officers +
## 1 attendant on 4 faces: no twins).
func test_of_officers_and_sd_attendant_share_one_pool() -> void:
	await _launch(&"ostrander_federal")
	var m: Dictionary = NpcVisuals.tweak().heist_tag_characters[&"ostrander_federal"]
	assert_eq(m[&"civ_sd_attendant"], m[&"civ_officer"], "the attendant lists the officer looks")
	var tags: Array[StringName] = [&"civ_officer", &"civ_officer", &"civ_officer", &"civ_sd_attendant"]
	for t: StringName in [&"civ_officer", &"civ_sd_attendant"]:
		assert_eq(NpcVisuals.tweak().heist_tag_pools[&"ostrander_federal"][t], &"of_officers", "%s in of_officers" % t)
	var pool: int = _delivered(m[&"civ_officer"])
	if pool < 2:
		skip("fewer than 2 bank_officer looks delivered")
		return
	var npcs: Array[NpcBase] = []
	for i: int in tags.size():
		npcs.append(_spawn(&"civilian", i, {"tags": [tags[i]]}))
	_check(npcs, pool, "OF officers + SD attendant")


## D (RT cast review): the waitress and the cook wear their own looks (staff_waitress / staff_cook before staff_diner),
## the diner booths take p5_cast's 14 civ_diner looks, and counter_wipe is a civilian activity with its own clip.
func test_rt_diner_staff_and_counter_wipe() -> void:
	var rt_tags: Dictionary = NpcVisuals.tweak().heist_tag_characters.get(&"rolling_thunder", {})
	assert_eq(rt_tags.get(&"staff_waitress", []), [&"diner_waitress"], "the waitress")
	assert_eq(rt_tags.get(&"staff_cook", []), [&"diner_cook"], "the cook")
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world/characters/p5_cast.json"))
	var want: Array = (cast["tag_map"]["rolling_thunder"]["civ_diner"] as Array).map(func(x: Variant) -> StringName:
		return StringName(x))
	assert_eq((rt_tags.get(&"civ_diner", []) as Array), want, "civ_diner mirrors p5_cast (no back-bag looks)")
	assert_has(CivilianBrain.KNOWN_ACTIVITIES, &"counter_wipe", "counter_wipe is a known activity")
	assert_eq(AnimDriver.HINT_CLIPS.get(&"counter_wipe", &""), &"counter_wipe", "it plays the counter_wipe clip")
