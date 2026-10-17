## B4-08: contract preplanning.md v1.0 (D-038): payment (own assets, plans split among the humans),
## the plan-vote lobby relay, resolve_ids() (dev path), map PREPLAN_POINTs and the legacy-format fallback.
extends TestCase

const DROP: StringName = &"pp_alley_dumpsters"
const ESC_W: StringName = &"pp_escape_alley_west"
const ESC_S: StringName = &"pp_escape_side_street"


func before_all() -> void:
	PreplanBoard.clear_cache()


func _board(difficulty: int = Enums.Difficulty.ROUTINE) -> PreplanBoard:
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	return PreplanBoard.build(&"test_heist", difficulty, def)


func test_each_buyer_pays_own_and_plans_split_among_humans() -> void:
	var b: PreplanBoard = _board(Enums.Difficulty.ROUTINE)
	var p: PreplanPlan = PreplanPlan.new(b, 0, [0, 1, 2] as Array[int])
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP, 2), PreplanPlan.OK)
	assert_eq(p.vote(1, &"asset.escape_position", ESC_S), PreplanPlan.OK)
	var c: int = b.cost_of(&"asset.escape_position")
	assert_eq(c, 1000)
	assert_eq(p.cash_cost(0), 334, "host pays a third + the remainder")
	assert_eq(p.cash_cost(1), 333)
	assert_eq(p.cash_cost(2), 333 + b.cost_of(&"asset.ammo_bag_drop"), "own drop + a third")
	assert_eq(p.cash_cost(3), 0, "AI slot never pays")
	assert_eq(p.cash_by_payer(), {0: 334, 1: 333, 2: 333 + 1200})
	var prof: PlayerProfile = PlayerProfile.new()
	prof.cash = 5000
	assert_eq(p.charge_profile(prof, 1), 333)
	assert_eq(prof.cash, 4667)
	# a voter who cannot pay their share blocks the vote when cash-checked
	var q: PreplanPlan = PreplanPlan.new(b, 0, [0, 1] as Array[int])
	assert_eq(q.vote(0, &"asset.escape_position", ESC_S, {0: 10000, 1: 100}), PreplanPlan.R_CASH)
	assert_eq(q.vote(0, &"asset.escape_position", ESC_S, {0: 10000, 1: 500}), PreplanPlan.OK)
	assert_eq(q.validate({0: 10000, 1: 499}).size(), 1, "re-checked on confirm")


func test_votes_relayed_as_lobby_messages() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board(), 0, [0, 1] as Array[int])
	var opt: StringName = PlanVote.option_key(&"asset.escape_position", ESC_W)
	assert_eq(p.receive_vote(1, PlanVote.MSG_CAST, {"option": String(opt)}), PreplanPlan.OK)
	assert_true(p.index_at(ESC_W) >= 0, "remote vote applied")
	assert_eq(p.receive_vote(3, PlanVote.MSG_CAST, {"option": String(opt)}), PreplanPlan.R_NOT_VOTER, "AI slot")
	assert_eq(p.receive_vote(1, PlanVote.MSG_RETRACT, {"group": "escape"}), PreplanPlan.OK)
	assert_eq(p.count_of(&"asset.escape_position"), 0)
	assert_eq(p.receive_vote(0, &"preplan.other", {}), PreplanPlan.R_UNKNOWN)
	# solo: Net.lobby_send delivers locally at once
	var got: Array = []
	var listen: Callable = func(peer: int, kind: StringName, data: Dictionary) -> void: got.append([peer, kind, data])
	Net.lobby_message.connect(listen)
	PlanVote.send_cast(opt)
	PlanVote.send_retract(&"escape")
	Net.lobby_message.disconnect(listen)
	assert_eq(got.size(), 2)
	assert_eq(got[0][1], PlanVote.MSG_CAST)
	assert_eq(String((got[0][2] as Dictionary)["option"]), String(opt))
	assert_eq(got[1][1], PlanVote.MSG_RETRACT)
	assert_true(PlanVote.is_vote_message(PlanVote.MSG_CAST) and not PlanVote.is_vote_message(&"x"))


func test_resolve_ids_dev_path() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	var res: Dictionary = PreplanPlan.resolve_ids(&"test_heist", [
		&"asset.extra_cable_ties", "asset.ammo_bag_drop", "asset.ammo_bag_drop", "asset.escape_position@" + String(ESC_W),
		&"asset.alternate_entry", &"asset.not_real",
	], Enums.Difficulty.ROUTINE, def)
	var keys: Array[String] = []
	keys.assign(res.keys())
	keys.sort()
	var want: Array[String] = PreplanPlan.RESULT_KEYS.duplicate()
	want.sort()
	assert_eq(keys, want)
	assert_has(res["modifier_sources"], &"asset.extra_cable_ties")
	var drops: Array = res["drops"]
	assert_eq(drops.size(), 2, "two drops on two free drop zones")
	assert_ne(StringName(drops[0]["point"]), StringName(drops[1]["point"]))
	assert_eq(res["force_variants"], {&"escape": [&"esc_alley_west"] as Array[StringName]}, "named point")
	assert_eq(res["spawn_tag"], &"preplan_spawn_alley", "first spawn point in blueprint order")
	assert_eq(res["cash_spent"], {}, "dev path charges nobody")
	var same: PreplanPlan = PreplanPlan.new(_board(), 0, [0] as Array[int])
	same.add(&"asset.extra_cable_ties", &"", 0)
	assert_eq(PreplanPlan.resolve_ids(&"test_heist", [&"asset.extra_cable_ties"], Enums.Difficulty.ROUTINE, def)["modifier_sources"],
			same.apply()["modifier_sources"], "same resolver as the UI")


func test_resolve_ids_dictionary_form_keeps_its_point() -> void:
	# P SL-P1: {asset, point} lost its point (only "asset.x@point" kept it). Both forms resolve the same.
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	var plan: PreplanPlan = PreplanPlan.new(_board(), 0, [0] as Array[int])
	var first: StringName = plan.first_free_point(&"asset.ammo_bag_drop")
	var other: StringName = &""
	for pid: StringName in _board().blueprint.point_ids():
		if pid != first and plan.can_add(&"asset.ammo_bag_drop", pid, 0) == PreplanPlan.OK:
			other = pid
			break
	assert_ne(other, &"", "a second drop zone to name")
	var as_string: Dictionary = PreplanPlan.resolve_ids(&"test_heist", ["asset.ammo_bag_drop@" + String(other),
			"asset.escape_position@" + String(ESC_W)], Enums.Difficulty.ROUTINE, def)
	var as_dict: Dictionary = PreplanPlan.resolve_ids(&"test_heist", [{"asset": &"asset.ammo_bag_drop", "point": other},
			{"asset": &"asset.escape_position", "point": ESC_W}], Enums.Difficulty.ROUTINE, def)
	assert_eq(StringName((as_dict["drops"] as Array)[0]["point"]), other, "the named drop zone, not the first free one")
	assert_eq(as_dict, as_string, "the Dictionary and string forms resolve identically")
	var no_point: Dictionary = PreplanPlan.resolve_ids(&"test_heist", [{"asset": &"asset.ammo_bag_drop"}],
			Enums.Difficulty.ROUTINE, def)
	assert_eq(StringName((no_point["drops"] as Array)[0]["point"]), first, "no point: the first free one, as the string form")


func test_points_read_from_the_map_scene() -> void:
	var map: Node3D = Node3D.new()
	map.name = "TestMap"
	map.position = Vector3(100, 0, 0)
	var pre: Node3D = Node3D.new()
	pre.name = "Preplan"
	pre.position = Vector3(1, 0, 2)
	map.add_child(pre)
	pre.owner = map
	var pts: Array = [["pp_drop_roof", &"drop_zone", Vector3(3, 6, 4), 1, {}],
			["pp_back_lot", &"spawn", Vector3(-5, 0, 0), 0, {"spawn_tag": &"preplan_spawn_lot"}],
			["pp_van_lot", &"escape", Vector3(40, 0, 30), 0, {"variant_group": &"escape", "variant_slot": &"esc_lot"}]]
	for d: Array in pts:
		var m: Marker3D = Marker3D.new()
		m.name = String(d[0])
		m.position = d[2]
		m.set_meta(&"category", d[1])
		m.set_meta(&"floor", d[3])
		m.set_meta(&"label", &"ui.preplan.point.pp_side_kerb")
		m.set_meta(&"params", d[4])
		m.add_to_group(G.PREPLAN_POINT, true)
		pre.add_child(m)
		m.owner = map
	var ps: PackedScene = PackedScene.new()
	assert_eq(ps.pack(map), OK)
	map.free()
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	var path: String = BTestUtil.profile_root().path_join("preplan_map.tscn")
	assert_eq(ResourceSaver.save(ps, path), OK)
	var def: HeistDef = HeistDef.new()
	def.id = &"test_map_heist"
	def.map_scene = path
	PreplanBoard.clear_cache()
	var b: PreplanBoard = PreplanBoard.build(&"test_map_heist", Enums.Difficulty.ROUTINE, def)
	assert_eq(b.blueprint.point_ids(), [&"pp_drop_roof", &"pp_back_lot", &"pp_van_lot"] as Array[StringName])
	assert_eq(b.blueprint.point(&"pp_drop_roof")["pos"], Vector2(104, 6), "map-root-relative x/z")
	assert_eq(int(b.blueprint.point(&"pp_drop_roof")["floor"]), 1)
	assert_true(b.blueprint.bounds.has_point(Vector2(141, 32)), "bounds grow to show every point")
	assert_true(get_tree().root.find_child("TestMap", true, false) == null, "map never entered the tree")
	var res: Dictionary = PreplanPlan.resolve_ids(&"test_map_heist", [&"asset.alternate_entry", &"asset.escape_position",
			&"asset.ammo_bag_drop"], Enums.Difficulty.ROUTINE, def)
	assert_eq(res["spawn_tag"], &"preplan_spawn_lot")
	assert_eq(res["force_variants"], {&"escape": [&"esc_lot"] as Array[StringName]})
	assert_eq(StringName((res["drops"] as Array)[0]["point"]), &"pp_drop_roof")
	DirAccess.remove_absolute(path)
	PreplanBoard.clear_cache()


func test_glasshouse_board_builds_with_fallback_points() -> void:
	PreplanBoard.clear_cache()
	var def: HeistDef = HeistRegistry.get_def(&"glasshouse")
	var b: PreplanBoard = PreplanBoard.build(&"glasshouse", Enums.Difficulty.ROUTINE)
	assert_eq(b.errors, [] as Array[String], "no merge errors")
	assert_true(b.blueprint.point_ids().size() >= 5, "points from the map or the placeholder")
	if def != null and PreplanBoard.is_legacy_format(def.preplanning):
		assert_eq(b.assets.size(), PreplanBoard.generic_assets().size(), "pre-contract data ignored")
	assert_true(PreplanBoard.is_legacy_format({&"asset.x": {}}))
	assert_false(PreplanBoard.is_legacy_format({"assets": {}}))
	assert_false(PreplanBoard.is_legacy_format({}))


## Item: apply() emits exactly the PreplanResult v1 keys listed in docs/contracts/preplanning.md, and
## resolve_ids() works with exactly (heist_id, ids) as the contract calls it.
func test_result_keys_match_the_contract_doc() -> void:
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/contracts/preplanning.md")
	if FileAccess.file_exists(doc):
		var block: String = FileAccess.get_file_as_string(doc).get_slice("## Launch", 1).get_slice("```", 1)
		var rx: RegEx = RegEx.create_from_string("(?m)^\\{?\\s*\"([a-z_]+)\":")
		var keys: Array[String] = []
		for m: RegExMatch in rx.search_all(block):
			keys.append(m.get_string(1))
		assert_eq(keys, PreplanPlan.RESULT_KEYS, "RESULT_KEYS = the contract's list")
	var res: Dictionary = PreplanPlan.resolve_ids(&"test_heist", [&"asset.extra_cable_ties"])
	var got: Array[String] = []
	for k: Variant in res:
		got.append(String(k))
	got.sort()
	var want: Array[String] = PreplanPlan.RESULT_KEYS.duplicate()
	want.sort()
	assert_eq(got, want, "apply() keys")
