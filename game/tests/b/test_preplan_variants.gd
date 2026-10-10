## B4-08 (D-049): pre-planning board vs the heist's variant groups (QB-53) and strings for every
## registered heist's pre-planning assets (QB-54).
extends TestCase


func before_all() -> void:
	PreplanBoard.clear_cache()


func _board() -> PreplanBoard:
	var def: HeistDef = HeistDef.new()
	def.id = &"test_heist"
	return PreplanBoard.build(&"test_heist", Enums.Difficulty.ROUTINE, def)


## QB-53 (D-049): library assets whose reveals / force_variants name a variant group the heist does
## not have are hidden by the board; groups come from the heist's HeistVariantTable + point params.
func test_assets_for_missing_variant_groups_are_hidden() -> void:
	var groups: Array[StringName] = PreplanBoard.heist_variant_groups(&"glasshouse")
	assert_has(groups, &"keycard", "rule group from glasshouse_variants.tres")
	assert_has(groups, &"camera")
	assert_false(groups.has(&"laptop"))
	var bp: PreplanBlueprint = PreplanBlueprint.new()
	bp.heist_id = &"glasshouse"
	bp.points.append({"id": &"pp_x", "category": &"insider", "pos": Vector2.ZERO, "floor": 0,
			"label": &"ui.preplan.point.pp_x", "params": {"variant_group": &"vent_open", "variant_slot": &"v1"}})
	assert_has(PreplanBoard.heist_variant_groups(&"glasshouse", bp), &"vent_open", "point params count")
	var def: HeistDef = HeistDef.new()
	def.id = &"glasshouse"
	var b: PreplanBoard = PreplanBoard.build(&"glasshouse", Enums.Difficulty.ROUTINE, def, null, bp)
	assert_eq(b.errors, [] as Array[String])
	assert_false(b.assets.has(&"asset.intel_laptop"), "no laptop group: hidden")
	assert_has(b.hidden_assets, &"asset.intel_laptop")
	assert_true(b.assets.has(&"asset.intel_keycards"), "keycard group exists: kept")
	assert_true(b.assets.has(&"asset.intel_guard_posts"))
	assert_false(b.crew_assets().has(&"asset.intel_laptop"))
	var p: PreplanPlan = PreplanPlan.new(b)
	assert_ne(p.add(&"asset.intel_laptop", &"", 0), PreplanPlan.OK, "can't be bought")
	# A heist that lists such an asset itself gets a data error, not a silent hide.
	def.preplanning = {"assets": {&"asset.intel_laptop": {"cost": 900}}}
	var b2: PreplanBoard = PreplanBoard.build(&"glasshouse", Enums.Difficulty.ROUTINE, def, null, bp)
	assert_true(b2.assets.has(&"asset.intel_laptop"))
	assert_eq(b2.errors.size(), 1, str(b2.errors))
	# No variant table on disk: groups unknown, nothing hidden.
	assert_eq(PreplanBoard.heist_variant_groups(&"test_heist"), [] as Array[StringName])
	assert_true(_board().assets.has(&"asset.intel_laptop"))


## QB-54 (D-049): every asset a registered HeistDef.preplanning lists (and every library asset) has
## name/desc strings; Night Deposit's heist-only assets are covered even before its def is on trunk.
func test_every_heist_preplan_asset_has_strings() -> void:
	var table: Dictionary = StringTable.parse_csv()
	var ids: Array[String] = ["asset.insider_code", "asset.vent_access"]  # Night Deposit (ENV C)
	for id: Variant in PreplanBoard.generic_assets():
		ids.append(String(id))
	var heists: int = 0
	for def: HeistDef in HeistRegistry.all():
		heists += 1
		var pre: Dictionary = def.preplanning
		var listed: Variant = pre.get("assets", {})
		for id: Variant in listed as Dictionary if listed is Dictionary else {}:
			ids.append(String(id))
		for k: Variant in pre:  # legacy top-level "asset.<id>" keys (PreplanBoard.merge tolerates them)
			if String(k).begins_with(PreplanBoard.ASSET_PREFIX):
				ids.append(String(k))
	assert_true(heists >= 1, "registry has heists")
	for id: String in ids:
		assert_has(table, "item.%s.name" % id, "%s name" % id)
		assert_has(table, "item.%s.desc" % id, "%s desc" % id)
