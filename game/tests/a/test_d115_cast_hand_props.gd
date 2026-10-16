## D-115 (characters.md v1.16): NpcVisualTweak.heist_tag_characters mirrors ENV D's p5_cast.json for the four
## D-115 heists (DB: civ_worker only; cartel and police dress by EnemyDef / director); every listed character is
## delivered except the known pending ones; a missing id is skipped by the pick. Hand props attach on clip start
## at the json's socket and go on the next clip.
extends TestCase

const AD: Script = preload("res://tests/a/test_anim_driver.gd")
const CAST_PATH: String = "res://world/characters/p5_cast.json"
## Cast entries ahead of ENV D's delivery on this branch (D-SL-2 second cleaner).
const PENDING: Array[String] = ["npc_cleaner_sl_b"]

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
				assert_true((m.get(StringName(role), []) as Array).has(StringName(String(id))),
					"%s/%s wears %s (cast)" % [heist, role, id])
	assert_eq(tw.heist_tag_characters[&"gallery_night"][&"civ_admin"], [&"gallery_admin"], "GN admin = gallery_admin")
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
