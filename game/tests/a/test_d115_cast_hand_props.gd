## D-115 (characters.md v1.16): NpcVisualTweak.heist_tag_characters mirrors ENV D's p5_cast.json for the four
## D-115 heists (DB: civ_worker only; cartel and police dress by EnemyDef / director); every listed character is
## delivered except the known pending ones; a missing id is skipped by the pick. Hand props attach on clip start
## at the json's socket and go on the next clip.
extends TestCase

const AD: Script = preload("res://tests/a/test_anim_driver.gd")
const CAST_PATH: String = "res://world/characters/p5_cast.json"
## Cast entries ahead of ENV D's delivery on this branch (D-SL-2 second cleaner).
## Ids listed ahead of ENV D's delivery (the deal skips them until their scenes exist; LEAD DB/SL cast audit).
const PENDING: Array[String] = ["npc_cleaner_sl_b", "npc_cleaner_sl_c", "npc_northgate_guard_c", "npc_northgate_guard_d",
	"npc_northgate_guard_e", "npc_northgate_guard_f", "security_officer_c", "security_officer_d",
	"dock_worker_c",  # D 45894565 (merged by the LEAD with A's map)
	# D-130 cast pools (D a04f3536, p5_cast v6), merged by the LEAD with A's map:
	"gallery_guard_c", "gallery_guard_d", "gallery_guard_e", "gallery_guard_f", "gallery_guard_g", "gallery_guard_h",
	"gallery_guard_i", "gallery_patron_h", "gallery_patron_i", "gallery_patron_j", "npc_northgate_guard_g",
	"npc_northgate_guard_h", "npc_northgate_guard_i", "npc_cleaner_sl_d", "security_officer_e", "security_officer_f",
	"npc_bank_cleaner_b"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


func test_d115_tag_map_mirrors_cast() -> void:
	var cast: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH)) as Dictionary)["heists"]
	var tw: NpcVisualTweak = NpcVisuals.tweak()
	for heist: String in ["glasshouse", "night_deposit", "shadow_ledger", "dockside_burn"]:
		var m: Dictionary = tw.heist_tag_characters.get(StringName(heist), {})
		assert_false(m.is_empty(), "%s has a tag map" % heist)
		var roles: Dictionary = cast[heist]
		for role: String in roles:
			if heist == "dockside_burn" and role != "civ_worker":
				continue
			assert_true(m.has(StringName(role)), "%s/%s mapped" % [heist, role])
			for id: Variant in roles[role]:
				var tag: StringName = StringName(role)
				if heist == "dockside_burn" and String(id) == "dock_packer":
					tag = &"civ_worker_packer"  # LEAD: the packing-table spawn has its own tag
				assert_true((m.get(tag, []) as Array).has(StringName(String(id))),
					"%s/%s wears %s (cast)" % [heist, role, id])
	assert_eq(tw.heist_tag_characters[&"gallery_night"][&"civ_admin"], [&"gallery_admin"], "GN admin = gallery_admin")
	# D b95cc5e4 (p5_cast v4): tag_map.gallery_night is mirrored (staff_cs / staff_admin are A's extra tags); since D-130
	# (p5_cast v6) every cast id must be in A's list, so A's map may land before or after D's cast file.
	var gn_cast: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH)) as Dictionary) \
		.get("tag_map", {}).get("gallery_night", {})
	var gn: Dictionary = tw.heist_tag_characters[&"gallery_night"]
	assert_false(gn_cast.is_empty(), "p5_cast v4 has tag_map.gallery_night")
	for tag: String in gn_cast:
		var have: Array = gn.get(StringName(tag), [])
		for id: Variant in gn_cast[tag]:
			assert_true(have.has(StringName(String(id))), "GN %s mirrors the cast tag_map (%s)" % [tag, id])
	assert_eq(gn[&"staff_cs"], [&"gallery_conservator"], "staff_cs wears the conservator")
	# heist_tag_pools: the tags of one pool list the same ids (one shared round-robin deal, no twins up to the pool size).
	for heist: Variant in tw.heist_tag_pools:
		var pools: Dictionary = tw.heist_tag_pools[heist]
		var first: Dictionary = {}
		for tag: Variant in pools:
			var pool: StringName = pools[tag]
			var lst: Array = tw.heist_tag_characters[heist].get(tag, [])
			if not first.has(pool):
				first[pool] = lst
			assert_eq(lst, first[pool], "%s pool %s: %s lists the pool's ids" % [heist, pool, tag])
	assert_eq((gn[&"guard_hall"] as Array).size(), 9, "D-130: 9 GN guard looks")
	for heist: Variant in tw.heist_tag_characters:
		var m: Dictionary = tw.heist_tag_characters[heist]
		for tag: Variant in m:
			for id: Variant in m[tag]:
				if not PENDING.has(String(id)):
					assert_true(ResourceLoader.exists(NpcVisuals.scene_path(String(id))),
						"%s/%s: %s delivered" % [heist, tag, id])


func test_d115_pick_skips_undelivered() -> void:
	var npc: NpcBase = NpcBase.new()
	for i: int in 8:
		npc.name = "Cleaner%d" % i
		var ps: PackedScene = NpcVisuals._pick(npc, [&"no_such_character_x", &"npc_cleaner_sl"])
		assert_true(ps != null and ps.resource_path.contains("npc_cleaner_sl"), "undelivered id skipped (%d)" % i)
	assert_true(NpcVisuals._pick(npc, [&"no_such_character_x"]) == null, "all undelivered: no pick")
	npc.free()


func test_d115_hand_props_attach_and_detach() -> void:
	assert_eq(HandProps.props_for(&"phone_call").size(), 1, "phone_call holds one prop")
	assert_eq(HandProps.props_for(&"bartender_pour").size(), 2, "bartender_pour: bottle + glass")
	var rig: Node3D = AD._test_rig()
	add_child(rig)
	_nodes.append(rig)
	var r: Node3D = rig.get_node("Skeleton3D/HandR/Socket")
	var l: Node3D = rig.get_node("Skeleton3D/HandL/Socket")
	assert_eq(HandProps.sync(rig, &"bartender_pour"), PackedStringArray(["bottle", "glass"]), "both attached")
	assert_true(r.get_node_or_null("HandProp_bottle") != null, "bottle at HandR/Socket")
	assert_true(l.get_node_or_null("HandProp_glass") != null, "glass at HandL/Socket")
	assert_eq((r.get_node("HandProp_bottle") as Node3D).transform, Transform3D.IDENTITY, "identity child")
	var bottle: Node = r.get_node("HandProp_bottle")
	HandProps.sync(rig, &"bartender_pour")
	assert_true(r.get_node("HandProp_bottle") == bottle, "same clip again: kept, not re-made")
	HandProps.sync(rig, &"phone_call")
	assert_true(r.get_node_or_null("HandProp_phone") != null, "phone in")
	assert_true(r.get_node_or_null("HandProp_bottle") == null and l.get_node_or_null("HandProp_glass") == null,
		"pour props gone")
	HandProps.sync(rig, &"death_front")
	assert_eq(r.get_child_count() + l.get_child_count(), 0, "death clip: no props")


func test_d115_anim_driver_attaches_on_clip() -> void:
	var t: TestCase = AD.new()
	add_child(t)
	_nodes.append(t)
	var npc: NpcBase = t.call(&"_npc", &"civilian")
	_nodes.append(npc)
	var d: AnimDriver = AnimDriver.of(npc)
	npc.get_node("Brain").set(&"anim_hint", &"smoke")
	d.tick(0.016)
	assert_eq(d.clip, &"smoke")
	assert_eq(d.hand_props, PackedStringArray(["cigarette"]), "smoke: cigarette")
	var sock: Node = AnimDriver.socket_of(npc, "HandR")
	assert_true(sock != null and sock.get_node_or_null("HandProp_cigarette") != null, "at HandR/Socket")
	npc.get_node("Brain").set(&"anim_hint", &"idle")
	d.tick(0.016)
	assert_eq(d.hand_props.size(), 0, "idle: none")
	assert_true(sock.get_node_or_null("HandProp_cigarette") == null, "cigarette gone")


## D-115 GN polish (LEAD): a tag's looks are dealt round-robin in spawn order (no twins while the live count is
## at most the look count), the pick rides the spawn descriptor ("look") and a replica wears the same look.
func test_d115_tag_looks_dealt_without_twins() -> void:
	var specs: Array[Dictionary] = []
	for i: int in 4:
		specs.append({"kind": SpawnPoint.Kind.CIVILIAN, "tags": [&"civ_customer"], "pos": Vector3(i * 2.0 - 3.0, 0.05, -6)})
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 4242, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_tagged_spawns(specs), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	_nodes.append(rt)
	await wait_physics_frames(3)
	var looks: Array = NpcVisuals.tweak().tag_characters[&"civ_customer"]
	var seen: Dictionary = {}
	var civs: Array[NpcBase] = []
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if (npc.spawn_info.get("tags", []) as Array).has(&"civ_customer"):
			civs.append(npc)
	assert_eq(civs.size(), 4, "four tagged customers")
	for npc: NpcBase in civs:
		var path: String = npc.visual_scene.resource_path if npc.visual_scene != null else ""
		seen[path] = int(seen.get(path, 0)) + 1
		var d: Dictionary = NetEntityCodec.describe(npc)
		assert_eq(int((d["params"] as Dictionary)["look"]), int(npc.spawn_info["look"]), "look in the descriptor")
	assert_eq(seen.size(), mini(looks.size(), 4), "every look used before any repeats (%s)" % seen)
	for path: String in seen:
		assert_true(int(seen[path]) <= ceili(4.0 / looks.size()), "no look worn more than its share")
	var replica: NpcBase = NpcBase.new()
	replica.name = "ReplicaCustomer"
	replica.spawn_info = {"tags": [&"civ_customer"], "replica": true, "look": int(civs[1].spawn_info["look"])}
	assert_eq(NpcVisuals._pick(replica, looks, "civ_customer"), civs[1].visual_scene, "replica wears the dealt look")
	replica.free()
	rt.teardown()
