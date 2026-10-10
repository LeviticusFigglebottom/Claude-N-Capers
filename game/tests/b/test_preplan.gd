## B2-01 / B4-08: pre-planning data, board merge (contract preplanning.md v1.0 format), map points,
## plan rules (budget, favors, points, exclusivity), cost scaling and payment (own assets, split
## plans), plan vote tie-break and relay, the PreplanResult v1 shape and resolve_ids().
extends TestCase

const DROP: StringName = &"pp_alley_dumpsters"
const DROP2: StringName = &"pp_alley_hvac"
const KERB: StringName = &"pp_side_kerb"
const SPAWN_W: StringName = &"pp_spawn_alley_west"
const SPAWN_M: StringName = &"pp_spawn_alley_mouth"
const ESC_W: StringName = &"pp_escape_alley_west"
const ESC_S: StringName = &"pp_escape_side_street"


func before_all() -> void:
	PreplanBoard.clear_cache()


func _board(difficulty: int = Enums.Difficulty.ROUTINE, def: HeistDef = null) -> PreplanBoard:
	if def == null:
		def = HeistDef.new()
		def.id = &"test_heist"
	return PreplanBoard.build(&"test_heist", difficulty, def)


func test_generic_assets_are_valid_and_grant_known_keys() -> void:
	var g: Dictionary = PreplanBoard.generic_assets()
	assert_true(g.size() >= 8, "generic set has %d assets" % g.size())
	var files: int = 0
	for f: String in ResourceLoader.list_directory(PreplanBoard.ASSET_DIR):
		if f.ends_with(".tres"):
			files += 1
			var a: PreplanAssetDef = load(PreplanBoard.ASSET_DIR.path_join(f)) as PreplanAssetDef
			assert_eq(a.id, StringName("asset." + f.get_basename()), "id matches file %s" % f)
	assert_eq(g.size(), files)
	for id: Variant in g:
		var a2: PreplanAssetDef = g[id] as PreplanAssetDef
		assert_eq(a2.validate(), [] as Array[String], "valid %s" % id)
		for k: Variant in a2.grants:
			assert_true(ModifierKeys.is_known(StringName(String(k))), "%s grants known key %s" % [id, k])
		if a2.drop != &"":
			assert_true(ContentDB.deployable(a2.drop) != null, "%s drops a real deployable" % id)


func test_every_asset_has_strings() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for id: Variant in PreplanBoard.generic_assets():
		assert_has(table, "item.%s.name" % id)
		assert_has(table, "item.%s.desc" % id)
	var bp: PreplanBlueprint = PreplanBoard.blueprint_for(&"")
	for p: Dictionary in bp.points:
		assert_has(table, String(p["label"]))
		assert_has(table, "ui.preplan.category.%s" % p["category"])
	for r: StringName in [PreplanPlan.R_UNKNOWN, PreplanPlan.R_NEEDS_POINT, PreplanPlan.R_NO_POINT,
			PreplanPlan.R_WRONG_POINT, PreplanPlan.R_POINT_TAKEN, PreplanPlan.R_MAX_COUNT,
			PreplanPlan.R_EXCLUSIVE, PreplanPlan.R_FAVORS, PreplanPlan.R_CASH, PreplanPlan.R_NOT_VOTER]:
		assert_has(table, "ui.preplan.reason.%s" % r)


func test_placeholder_blueprint_used_without_heist_data() -> void:
	var b: PreplanBoard = _board()
	assert_true(b.blueprint.placeholder, "no blueprint for test_heist -> placeholder")
	assert_eq(b.favors_budget, b.tweak.default_favors)
	assert_eq(b.favors_budget, 10, "PD2 default 10 favors")
	assert_true(b.active_point_ids().size() >= 5)
	assert_has(b.assets_for_point(DROP), &"asset.ammo_bag_drop")
	assert_false(b.assets_for_point(DROP).has(&"asset.alternate_entry"))
	assert_has(b.crew_assets(), &"asset.extra_cable_ties")


func test_cost_scales_with_difficulty() -> void:
	var routine: PreplanBoard = _board(Enums.Difficulty.ROUTINE)
	var top: PreplanBoard = _board(Enums.Difficulty.CATACLYSM)
	assert_eq(routine.cost_of(&"asset.doctor_bag_drop"), 1600, "PD2 Normal price")
	assert_eq(top.cost_of(&"asset.doctor_bag_drop"), 20800, "PD2 Death Wish price (x13)")
	var prev: int = 0
	for d: int in range(Enums.Difficulty.size()):
		var c: int = _board(d).cost_of(&"asset.ammo_bag_drop")
		assert_true(c > prev, "cost rises with difficulty %d" % d)
		assert_eq(c % 100, 0, "rounded")
		prev = c
	assert_eq(routine.favors_of(&"asset.doctor_bag_drop"), top.favors_of(&"asset.doctor_bag_drop"), "favors don't scale")
	var tw: PreplanTweak = PreplanTweak.new()
	tw.cost_round = 250
	assert_eq(tw.scaled_cost(1000, Enums.Difficulty.BRUTAL), 6500)
	assert_eq(tw.scaled_cost(130, Enums.Difficulty.ROUTINE), 250 * roundi(130.0 / 250.0))


func test_point_rules() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board())
	assert_eq(p.add(&"asset.ammo_bag_drop", &"", 0), PreplanPlan.R_NEEDS_POINT)
	assert_eq(p.add(&"asset.ammo_bag_drop", SPAWN_W, 0), PreplanPlan.R_WRONG_POINT)
	assert_eq(p.add(&"asset.ammo_bag_drop", &"pp_nowhere", 0), PreplanPlan.R_WRONG_POINT)
	assert_eq(p.add(&"asset.extra_cable_ties", DROP, 0), PreplanPlan.R_NO_POINT)
	assert_eq(p.add(&"asset.nope", DROP, 0), PreplanPlan.R_UNKNOWN)
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP, 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP, 0), PreplanPlan.R_POINT_TAKEN, "one asset per point")
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP2, 0), PreplanPlan.OK, "max_count 2")
	assert_eq(p.add(&"asset.ammo_bag_drop", KERB, 0), PreplanPlan.R_MAX_COUNT)
	assert_eq(p.add(&"asset.extra_cable_ties", &"", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.extra_cable_ties", &"", 1), PreplanPlan.R_MAX_COUNT, "crew assets once")
	assert_true(p.remove(&"asset.ammo_bag_drop", DROP))
	assert_false(p.remove(&"asset.ammo_bag_drop", DROP), "already removed")
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP, 0), PreplanPlan.OK, "point free again")


func test_exclusive_group() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board())
	assert_eq(p.add(&"asset.alternate_entry", SPAWN_W, 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.alternate_entry", SPAWN_M, 0), PreplanPlan.R_EXCLUSIVE, "one alternate spawn")
	var b: PreplanBoard = _board()
	var other: PreplanAssetDef = PreplanAssetDef.new()
	other.id = &"asset.test_other_entry"
	other.point_categories = [&"player_spawn"]
	other.exclusive_group = &"player_spawn"
	b.assets[other.id] = other
	var p2: PreplanPlan = PreplanPlan.new(b)
	assert_eq(p2.add(&"asset.alternate_entry", SPAWN_W, 0), PreplanPlan.OK)
	assert_eq(p2.add(other.id, SPAWN_M, 0), PreplanPlan.R_EXCLUSIVE, "different asset, same group")


func test_favors_budget() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board())
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP, 0), PreplanPlan.OK)  # 2
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP2, 0), PreplanPlan.OK)  # 4
	assert_eq(p.add(&"asset.doctor_bag_drop", KERB, 0), PreplanPlan.OK)  # 6
	assert_eq(p.add(&"asset.intel_keycards", &"", 0), PreplanPlan.OK)  # 7
	assert_eq(p.add(&"asset.intel_cameras", &"", 0), PreplanPlan.OK)  # 8
	assert_eq(p.add(&"asset.intel_guard_posts", &"", 0), PreplanPlan.OK)  # 9
	assert_eq(p.add(&"asset.extra_cable_ties", &"", 0), PreplanPlan.OK)  # 10
	assert_eq(p.favors_used(), 10)
	assert_eq(p.favors_left(), 0)
	assert_eq(p.add(&"asset.spare_body_bags", &"", 0), PreplanPlan.R_FAVORS)
	assert_eq(p.validate(), [] as Array[String])


func test_cash_budget_per_buyer() -> void:
	var b: PreplanBoard = _board(Enums.Difficulty.BRUTAL)
	var p: PreplanPlan = PreplanPlan.new(b)
	var cost: int = b.cost_of(&"asset.ammo_bag_drop")
	var cash: Dictionary = {0: cost + 100, 1: 0}
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP, 0, cash), PreplanPlan.OK)
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP2, 0, cash), PreplanPlan.R_CASH)
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP2, 1, cash), PreplanPlan.R_CASH, "slot 1 has nothing")
	assert_eq(p.add(&"asset.doctor_bag_drop", DROP2, 2, cash), PreplanPlan.OK, "slot 2 is not cash-checked here")
	assert_eq(p.cash_cost(0), cost)
	assert_eq(p.cash_cost(), cost + b.cost_of(&"asset.doctor_bag_drop"))
	var prof: PlayerProfile = PlayerProfile.new()
	prof.cash = cost + 100
	assert_eq(p.charge_profile(prof, 0), cost)
	assert_eq(prof.cash, 100)
	assert_eq(p.charge_profile(prof, 2), 0, "cannot pay -> nothing charged")
	assert_eq(prof.cash, 100)


func test_validate_catches_tampered_plan() -> void:
	var b: PreplanBoard = _board()
	var d: Dictionary = {"selections": [
		{"asset": "asset.ammo_bag_drop", "point": String(DROP), "buyer": 0},
		{"asset": "asset.doctor_bag_drop", "point": String(DROP), "buyer": 1},
		{"asset": "asset.alternate_entry", "point": String(SPAWN_W), "buyer": 0},
		{"asset": "asset.alternate_entry", "point": String(SPAWN_M), "buyer": 0},
	]}
	var p: PreplanPlan = PreplanPlan.from_dict(b, d)
	var errs: Array[String] = p.validate({0: 1000000})
	assert_eq(errs.size(), 2, str(errs))
	assert_true(errs[0].contains(String(PreplanPlan.R_POINT_TAKEN)), errs[0])
	assert_true(errs[1].contains(String(PreplanPlan.R_EXCLUSIVE)), errs[1])
	assert_false(p.validate({0: 100}).is_empty(), "cash re-checked")


func test_heist_def_preplanning_overrides_and_extends() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	def.preplanning = {
		"favors": 6,
		"disable": ["asset.intel_cameras"],
		"assets": {
			&"asset.ammo_bag_drop": {"cost": 500, "favors": 1, "point_ids": ["pp_side_kerb"]},
			&"asset.heist_keycard": {"force_variants": {"keycard": ["kc_breakroom"]}, "cost": 2000,
					"favors": 3, "category": "access", "tags": ["stealth"]},
			&"asset.zip_ties_drop": {"drop": "body_bag_case", "point_categories": ["drop_zone"], "favors": 1,
					"cost": 300, "params": {"count": 2}},
			&"asset.heist_ties": {"grants": {&"stealth.cable_ties_extra": 4}, "cost": 100, "favors": 1},
			&"asset.back_way_out": {"escape_tag": "escape_alley", "cost": 700, "favors": 1},
		},
	}
	var b: PreplanBoard = PreplanBoard.build(&"test_heist", Enums.Difficulty.ROUTINE, def)
	assert_eq(b.errors, [] as Array[String])
	assert_eq(b.favors_budget, 6)
	assert_false(b.assets.has(&"asset.intel_cameras"), "disabled")
	assert_eq(b.cost_of(&"asset.ammo_bag_drop"), 500)
	assert_eq(b.favors_of(&"asset.ammo_bag_drop"), 1)
	assert_eq(b.assets_for_point(KERB).has(&"asset.ammo_bag_drop"), true)
	assert_false(b.assets_for_point(DROP).has(&"asset.ammo_bag_drop"), "slot restricts to one point")
	assert_true(PreplanBoard.generic_assets()[&"asset.ammo_bag_drop"].point_ids.is_empty(), "generic def untouched")
	var kc: PreplanAssetDef = b.asset(&"asset.heist_keycard")
	assert_eq(kc.force_variants, {&"keycard": [&"kc_breakroom"] as Array[StringName]})
	assert_has(b.crew_assets(), &"asset.heist_keycard")
	assert_eq(b.asset(&"asset.zip_ties_drop").drop, &"deployable.body_bag_case")
	var p: PreplanPlan = PreplanPlan.new(b)
	assert_eq(p.add(&"asset.heist_keycard", &"", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.zip_ties_drop", DROP, 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.back_way_out", &"", 0), PreplanPlan.OK)
	var res: Dictionary = p.apply()
	assert_eq(res["force_variants"], {&"keycard": [&"kc_breakroom"] as Array[StringName]})
	assert_eq(res["drops"], [{"asset": &"asset.zip_ties_drop", "kind": &"deployable.body_bag_case", "point": DROP,
			"params": {"count": 2}}])
	assert_eq(res["escape_tag"], &"escape_alley")
	assert_has(b.assets_for_point(DROP), &"asset.zip_ties_drop")
	var ids: Array[StringName] = b.asset_ids()
	assert_true(ids.find(&"asset.ammo_bag_drop") < ids.find(&"asset.heist_keycard"), "supply before access")


func test_merge_reports_bad_data() -> void:
	var errs: Array[String] = []
	var m: Dictionary = PreplanBoard.merge(PreplanBoard.generic_assets(), {
		"assets": {
			&"asset.ammo_bag_drop": {"price": 5},
			&"asset.broken": "nope",
			&"no_prefix": {},
		},
		"bogus": 1,
	}, errs)
	assert_eq(errs.size(), 4, str(errs))
	assert_true(m["assets"].has(&"asset.ammo_bag_drop"))
	var bad: PreplanAssetDef = PreplanAssetDef.new()
	bad.id = &"asset.bad"
	bad.grants = {&"stealth.not_a_key": 1}
	assert_eq(bad.validate().size(), 1, "unknown modifier key rejected")
	var no_payload: PreplanAssetDef = PreplanAssetDef.new()
	no_payload.id = &"asset.empty"
	assert_eq(no_payload.validate().size(), 1, "a crew asset needs an effect")
	no_payload.drop = &"deployable.ammo_bag"
	assert_eq(no_payload.validate().size(), 1, "a drop needs a point")
	var dep: PreplanAssetDef = PreplanAssetDef.new()
	dep.id = &"asset.feedback"
	dep.grants = {&"stealth.ecm_feedback": true}
	assert_eq(dep.validate().size(), 1, "D-038 QA-16: the deprecated ECM feedback flag is rejected")


func test_vote_majority_and_host_tie_break() -> void:
	var v: PlanVote = PlanVote.new(0, [0, 1, 2, 3] as Array[int])
	assert_eq(v.winner(&"escape"), &"", "no votes")
	v.cast(1, &"escape", &"b")
	assert_eq(v.winner(&"escape"), &"b")
	v.cast(0, &"escape", &"a")
	assert_true(v.is_tied(&"escape"))
	assert_eq(v.winner(&"escape"), &"a", "host breaks the 1:1 tie")
	v.cast(2, &"escape", &"b")
	assert_eq(v.winner(&"escape"), &"b", "majority beats host")
	v.cast(3, &"escape", &"a")
	assert_eq(v.winner(&"escape"), &"a", "2:2 -> host")
	assert_eq(v.progress(&"escape"), Vector2i(4, 4))
	v.retract(0, &"escape")
	assert_eq(v.winner(&"escape"), &"b", "2:1 after the host withdraws")
	assert_false(v.cast(7, &"escape", &"a"), "not a voter")
	var w: PlanVote = PlanVote.new(0, [0, 1, 2] as Array[int])
	w.cast(2, &"escape", &"zeta")
	w.cast(1, &"escape", &"alpha")
	assert_eq(w.winner(&"escape"), &"alpha", "host abstains: first by id text")
	var rt: PlanVote = PlanVote.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())) as Dictionary)
	assert_eq(rt.winner(&"escape"), v.winner(&"escape"), "survives a JSON round trip")
	var solo: PlanVote = PlanVote.new(0, [0] as Array[int])
	solo.cast(0, &"escape", &"x")
	assert_eq(solo.winner(&"escape"), &"x", "solo: the host decides")


func test_plan_vote_group_holds_the_winner() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board(), 0, [0, 1] as Array[int])
	assert_eq(p.vote(1, &"asset.escape_position", ESC_S), PreplanPlan.OK)
	assert_eq(p.count_of(&"asset.escape_position"), 1)
	assert_eq(p.add(&"asset.escape_position", ESC_W, 0), PreplanPlan.OK, "add on a vote asset = vote")
	assert_eq(p.count_of(&"asset.escape_position"), 1, "vote group holds one option")
	assert_eq(int(p.selections[p.index_at(ESC_W)]["buyer"]), PreplanPlan.SPLIT, "plans are split among the humans")
	assert_eq(p.index_at(ESC_S), -1, "1:1 -> host's option")
	assert_eq(p.vote(5, &"asset.escape_position", ESC_S), PreplanPlan.R_NOT_VOTER)
	p.remove(&"asset.escape_position", ESC_W, 0)
	assert_true(p.index_at(ESC_S) >= 0, "host withdrew: slot 1's option wins")


func test_apply_output_shape() -> void:
	var b: PreplanBoard = _board(Enums.Difficulty.HAZARDOUS)
	var p: PreplanPlan = PreplanPlan.new(b, 0, [0, 1] as Array[int])
	assert_eq(p.add(&"asset.extra_cable_ties", &"", 1), PreplanPlan.OK)
	assert_eq(p.add(&"asset.ammo_bag_drop", DROP, 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.intel_keycards", &"", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.alternate_entry", SPAWN_W, 0), PreplanPlan.OK)
	assert_eq(p.vote(0, &"asset.escape_position", ESC_S), PreplanPlan.OK)
	var h: Dictionary = p.apply()
	var keys: Array[String] = []
	keys.assign(h.keys())
	keys.sort()
	var want: Array[String] = PreplanPlan.RESULT_KEYS.duplicate()
	want.sort()
	assert_eq(keys, want, "exactly the PreplanResult v1 keys")
	assert_eq(int(h["version"]), PreplanPlan.HANDOFF_VERSION)
	var plan_d: Dictionary = h["plan"]
	assert_eq(plan_d["heist_id"], &"test_heist")
	assert_eq(int(plan_d["difficulty"]), Enums.Difficulty.HAZARDOUS)
	assert_eq(int(plan_d["favors_used"]), 1 + 2 + 1 + 1 + 1)
	var mods: Dictionary = h["modifier_sources"]
	assert_eq(mods.keys(), [&"asset.extra_cable_ties"])
	for src: Variant in mods:
		assert_true(String(src).begins_with("asset."), "TEAM source asset.<id>")
		for key: Variant in mods[src]:
			assert_true(ModifierKeys.is_known(key), "known key %s" % key)
	assert_eq(int(mods[&"asset.extra_cable_ties"][&"stealth.cable_ties_extra"]), 2)
	assert_eq(h["drops"], [{"asset": &"asset.ammo_bag_drop", "kind": &"deployable.ammo_bag", "point": DROP, "params": {}}])
	assert_eq(h["reveals"], [&"keycard"] as Array[StringName])
	assert_eq(h["force_variants"], {&"escape": [&"esc_pell"] as Array[StringName]}, "from the escape point's params")
	assert_eq(h["spawn_tag"], &"preplan_spawn_alley", "from the spawn point's params")
	assert_eq(h["escape_tag"], &"")
	var cash: Dictionary = h["cash_spent"]
	var plan_cost: int = b.cost_of(&"asset.escape_position")
	assert_eq(int(cash[1]), b.cost_of(&"asset.extra_cable_ties") + plan_cost / 2, "own asset + half the plan")
	assert_eq(int(cash[0]), p.cash_cost(0))
	assert_eq(int(cash[0]) + int(cash[1]), p.cash_cost(), "every dollar paid once")
	var rt: PreplanPlan = PreplanPlan.from_dict(b, JSON.parse_string(JSON.stringify(plan_d)) as Dictionary)
	assert_eq(rt.apply(), h, "plan dict survives JSON and round-trips to the same result")


func test_modifier_sources_apply_to_team() -> void:
	var p: PreplanPlan = PreplanPlan.new(_board())
	p.add(&"asset.spare_body_bags", &"", 0)
	var mods: Dictionary = p.apply()["modifier_sources"]
	for src: Variant in mods:
		Modifiers.set_source(Modifiers.TEAM, StringName(src), mods[src])
	assert_near(Modifiers.add(2, &"stealth.body_bags_extra"), 1.0, 0.0001, "TEAM grant reaches every slot")
	Modifiers.clear_source(Modifiers.TEAM, &"asset.spare_body_bags")


func test_blueprint_from_nodes() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var m: Marker3D = Marker3D.new()
	m.name = "pp_roof"
	m.position = Vector3(3, 4.2, -2)
	m.set_meta(&"category", &"drop_zone")
	m.set_meta(&"floor", 1)
	m.set_meta(&"label", &"ui.preplan.point.pp_alley_hvac")
	m.set_meta(&"params", {"spawn_tag": &"x"})
	root.add_child(m)
	var bp: PreplanBlueprint = PreplanBlueprint.from_nodes([m] as Array[Node], PreplanBoard.blueprint_for(&""))
	assert_eq(bp.point_ids(), [&"pp_roof"] as Array[StringName])
	assert_eq(bp.category_of(&"pp_roof"), &"drop_zone")
	assert_eq(bp.point(&"pp_roof")["pos"], Vector2(3, -2))
	assert_eq(int(bp.point(&"pp_roof")["floor"]), 1)
	assert_eq(bp.point(&"pp_roof")["label"], &"ui.preplan.point.pp_alley_hvac")
	assert_eq(bp.point(&"pp_roof")["params"], {"spawn_tag": &"x"})
	assert_true(bp.shapes.size() > 0, "schematic kept from base")
	root.queue_free()


## Contract: points are the Marker3Ds under <Map>/Preplan, read by instancing the map scene without
## adding it to the tree; the board falls back to the placeholder when the map has none.


## D-046 QC-20/QC-23: top-level `asset.*` overrides merge like `assets{}`; favors come from the HeistDef.
func test_top_level_asset_overrides_and_heist_favors() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	def.preplanning = {
		"favors": 4,
		"disable": [&"asset.intel_cameras"],
		&"asset.inside_keycard": {"cost": 1500, "favors": 1, "effect": "force_variant", "point_categories": [&"insider"]},
		"assets": {&"asset.ammo_bag_drop": {"favors": 3}},
	}
	var b: PreplanBoard = PreplanBoard.build(&"test_heist", Enums.Difficulty.ROUTINE, def)
	assert_eq(b.errors, [] as Array[String])
	assert_eq(b.favors_budget, 4)
	assert_eq(b.favors_of(&"asset.ammo_bag_drop"), 3, "assets{} override")
	assert_eq(b.asset(&"asset.inside_keycard").effect, &"force_variant", "top-level override")
	assert_false(b.assets.has(&"asset.intel_cameras"))
	var a: PreplanAssetDef = PreplanAssetDef.new()
	a.id = &"asset.x"
	a.effect = &"teleport"
	assert_false(a.validate().is_empty(), "unknown effect rejected")


## D-046 QC-22: force_variant library assets take the chosen point's variant into force_variants.
func test_force_variant_library_assets() -> void:
	for id: StringName in [&"asset.inside_keycard", &"asset.propped_door"]:
		var a: PreplanAssetDef = PreplanBoard.generic_assets().get(id) as PreplanAssetDef
		assert_true(a != null, "%s in the library" % id)
		if a == null:
			continue
		assert_eq(a.effect, &"force_variant")
		assert_true(a.is_located())
		assert_eq(a.validate(), [] as Array[String])
	var bp: PreplanBlueprint = PreplanBlueprint.new()
	bp.points = [{"id": &"pp_insider_breakroom", "category": &"insider", "label": &"", "floor": 0, "pos": Vector2.ZERO,
		"params": {"variant_group": &"keycard", "variant_slot": &"kc_breakroom"}}]
	var b: PreplanBoard = PreplanBoard.build(&"", Enums.Difficulty.ROUTINE, null, null, bp)
	var p: PreplanPlan = PreplanPlan.new(b)
	assert_eq(p.add(&"asset.inside_keycard", &"pp_insider_breakroom", 0), PreplanPlan.OK)
	var res: Dictionary = p.apply()
	assert_eq(res["force_variants"], {&"keycard": [&"kc_breakroom"] as Array[StringName]})


## D-046 QC-22: strings for the Glasshouse PREPLAN_POINTs (glasshouse.tscn `Preplan`) and the new assets.
func test_glasshouse_point_and_asset_strings() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for pid: String in ["pp_alley_dumpsters", "pp_alley_hvac", "pp_side_kerb", "pp_spawn_alley_west",
			"pp_spawn_alley_mouth", "pp_escape_alley_west", "pp_escape_side_street", "pp_insider_breakroom", "pp_back_door"]:
		assert_has(table, "ui.preplan.point.%s" % pid)
	for a: String in ["inside_keycard", "propped_door"]:
		assert_has(table, "item.asset.%s.name" % a)
		assert_has(table, "item.asset.%s.desc" % a)
	for c: String in ["drop_zone", "player_spawn", "escape", "access", "insider"]:
		assert_has(table, "ui.preplan.category.%s" % c)
