## B4-09 (D-040, Night Deposit) / B4-10 (D-042, Shadow Ledger): ENV B content for the P2 heists:
## loot defs, objective strings from the design docs' `[tag]`s (D-039), briefing lines and the
## placeholder briefing/catalog data used until ENV C's HeistDefs land.
## B5-04 (Dockside Burn, P3, loud-only; G0 doc D-064): content per game/content/docs/heists/dockside_burn.md.
## ENV C's HeistDef and map are not required: the Dockside tests fall back to the proposal while
## `HeistRegistry.get_def(&"dockside_burn")` is null, and check the def when it exists.
extends TestCase

## Objective `[tag]`s in order of first appearance in the doc's "## Objectives" section (stealth
## list, then loud list). Source: docs/design/heists/night_deposit.md (ENV C, approved in D-040).
## Hardcoded because the doc was not on trunk when this was written; when it is,
## _doc_tags() parses it and the test compares.
const ND_TAGS: Array[String] = [
	"casing", "keycard", "code", "server", "vault_gate", "time_lock", "time_lock_wait",
	"vault_loot", "depository", "secure", "escape", "vault_drill",
]
## Source: docs/design/heists/shadow_ledger.md (ENV C, approved in D-042), same rule as ND_TAGS.
const SL_TAGS: Array[String] = [
	"casing", "laptop", "keycard", "server_door", "cage_code", "cage", "hack", "drives", "secure",
	"study_safe", "paintings", "archive_safe", "escape",
]
const SL_ASSETS: Array[StringName] = [&"asset.intel_laptop", &"asset.gondola_left_hung", &"asset.riser_panel"]
const DB_HEIST: StringName = &"dockside_burn"
## Source: docs/design/heists/dockside_burn.md (ENV C, approved in D-064, read at 8e3efe5), same rule
## as ND_TAGS (the doc is not on this branch's trunk yet).
const DB_TAGS: Array[String] = [
	"cartel", "breach", "product", "burn", "strongroom", "count_cage", "containers", "secure", "escape_wait",
	"escape",
]
## Placeholder HeistDef.base_payout (lead, B5-04 / doc QC open question 7); the def wins once it exists.
const DB_BASE_PAYOUT: int = 95000
## The content doc's contract pay table for DB_BASE_PAYOUT, Routine..Cataclysm.
const DB_PAY_TABLE: Array[int] = [95000, 190000, 247000, 399000, 684000, 874000]
## QC-40: the doc's five new pre-planning assets (library, ENV B).
const DB_NEW_ASSETS: Array[StringName] = [
	&"asset.gangway_raised", &"asset.intel_containers", &"asset.lift_power", &"asset.sniper_position",
	&"asset.thermite_drop",
]
## The doc's Preplan points: [id, category, params].
const DB_POINTS: Array = [
	[&"pp_spawn_gate", &"spawn", {}],
	[&"pp_spawn_lane", &"spawn", {"spawn_tag": &"preplan_spawn_lane"}],
	[&"pp_spawn_pontoon", &"spawn", {"spawn_tag": &"preplan_spawn_pontoon"}],
	[&"pp_drop_gatehouse", &"drop_zone", {}],
	[&"pp_drop_lane", &"drop_zone", {}],
	[&"pp_drop_quay", &"drop_zone", {}],
	[&"pp_drop_platform", &"drop_zone", {}],
	[&"pp_escape_gate", &"escape", {"variant_group": &"escape", "variant_slot": &"esc_van_gate"}],
	[&"pp_escape_lane", &"escape", {"variant_group": &"escape", "variant_slot": &"esc_van_lane"}],
	[&"pp_escape_boat", &"escape", {"variant_group": &"escape", "variant_slot": &"esc_boat"}],
	[&"pp_perch_roof", &"drop_zone", {"variant_group": &"player_perch", "variant_slot": &"perch_roof"}],
	[&"pp_perch_stack", &"drop_zone", {"variant_group": &"player_perch", "variant_slot": &"perch_stack"}],
	[&"pp_gangway", &"insider", {"variant_group": &"east_gangway", "variant_slot": &"gangway_up"}],
]
## Point ids shared with Night Deposit: their labels use heist-qualified keys (QB for C, B5-04).
const DB_SHARED_POINT_IDS: Array[StringName] = [&"pp_drop_quay", &"pp_escape_boat"]
## The proposed HeistDef.preplanning (content doc), aligned with the G0 doc's block. The five new
## assets carry their fields in the library, so the def only lists them.
const DB_PREPLAN: Dictionary = {
	"favors": 5,
	"disable": [&"asset.body_bag_case_drop", &"asset.spare_body_bags", &"asset.intel_cameras", &"asset.intel_keycards"],
	"assets": {
		&"asset.ammo_bag_drop": {"point_ids": [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay", &"pp_drop_platform"]},
		&"asset.doctor_bag_drop": {"point_ids": [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay", &"pp_drop_platform"]},
		&"asset.gangway_raised": {},
		&"asset.intel_containers": {},
		&"asset.lift_power": {},
		&"asset.sniper_position": {},
		&"asset.thermite_drop": {},
	},
}

var _table: Dictionary = {}


func before_all() -> void:
	_table = StringTable.parse_csv()


## Tags from docs/design/heists/<id>.md (empty when the doc is not in this checkout).
func _doc_tags(heist: String) -> Array[String]:
	var out: Array[String] = []
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/heists/%s.md" % heist)
	if not FileAccess.file_exists(doc):
		return out
	var sec: String = FileAccess.get_file_as_string(doc).get_slice("## Objectives", 1).get_slice("\n## ", 0)
	var rx: RegEx = RegEx.create_from_string("`\\[([a-z_]+)\\]`")
	for m: RegExMatch in rx.search_all(sec):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


func _check_objectives(heist: String, tags: Array[String]) -> void:
	var doc_tags: Array[String] = _doc_tags(heist)
	if not doc_tags.is_empty():
		assert_eq(doc_tags, tags, "%s design doc tags" % heist)
	for t: String in tags:
		assert_has(_table, "objective.%s.%s" % [heist, t])
	var prefix: String = "objective.%s." % heist
	for k: String in _table.keys():
		if k.begins_with(prefix):
			assert_has(tags, k.trim_prefix(prefix), "no guessed objective key: %s" % k)
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(StringName(heist), {}) as Dictionary
	var ids: Array[String] = []
	for id: Variant in ph.get("objectives", []) as Array:
		ids.append(String(id))
	assert_eq(ids, tags, "%s briefing placeholder objective ids" % heist)


## Briefing lines: the contact's (orders 1..n) then Mercer's closing line(s), all with text.
func _check_briefing(heist: StringName, contact_id: StringName, contact_lines: int, handler_lines: int = 1) -> void:
	var contact: ContactDef = ContactDef.find(contact_id)
	assert_true(contact != null, String(contact_id))
	var lines: Array[Dictionary] = BriefingModel.voice_lines(heist, contact)
	assert_eq(lines.size(), contact_lines + handler_lines, "%s briefing lines" % heist)
	for i: int in range(lines.size()):
		var l: Dictionary = lines[i]
		var speaker: StringName = contact.voice_speaker if i < contact_lines else &"mercer"
		assert_eq(StringName(l["speaker"]), speaker)
		assert_eq(StringName(l["event"]), &"briefing")
		assert_eq(StringName(l["heist"]), heist)
		assert_eq(String(l["text_key"]), "voice.%s" % l["id"])
		assert_has(_table, String(l["text_key"]))
		assert_true(VoiceLineTable.SPEAKERS.has(speaker))
	assert_eq(StringName(lines[-1]["speaker"]), &"mercer", "Mercer closes")
	for k: String in ["name", "subtitle", "brief", "briefing"]:
		assert_has(_table, "heist.%s.%s" % [heist, k])
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(heist, {}) as Dictionary
	assert_eq(StringName(ph.get("contact", &"")), contact_id)
	for e: Variant in ph.get("escape_options", []) as Array:
		assert_has(_table, "ui.briefing.escape.%s" % e)
	for lid: Variant in ph.get("loot", []) as Array:
		assert_true(ContentDB.loot(StringName(lid)) != null, "placeholder loot %s exists" % lid)
	var m: Dictionary = BriefingModel.build(heist, Enums.Difficulty.ROUTINE)
	assert_true(String(m["briefing_text"]).length() > 100, "%s briefing text" % heist)


func _check_loot(id: StringName, weight: Enums.LootWeight) -> void:
	var l: LootDef = ContentDB.loot(id)
	assert_true(l != null, String(id))
	if l == null:
		return
	assert_eq(l.id, id)
	assert_eq(l.weight, weight, "%s weight" % id)
	assert_true(l.value > 0, "%s has a value" % id)
	assert_false(l.conceals)
	assert_has(_table, "item.%s.name" % id)
	assert_has(_table, "item.%s.desc" % id)


# --- B4-09 Night Deposit ---

func test_night_deposit_loot() -> void:
	# MEDIUM is the lead's decision (B4-09); the C doc's QC-13 asked for HEAVY.
	_check_loot(&"loot.cash_bricks", Enums.LootWeight.MEDIUM)
	assert_true(ContentDB.loot(&"loot.cash_bricks").value > ContentDB.loot(&"loot.cash").value,
			"denser than a LIGHT cash bag, so worth more per bag")


func test_night_deposit_objectives_follow_the_design_doc() -> void:
	_check_objectives("night_deposit", ND_TAGS)


func test_night_deposit_briefing() -> void:
	_check_briefing(&"night_deposit", &"contact.accountant", 3)


# --- B4-10 Shadow Ledger ---

func test_shadow_ledger_loot() -> void:
	_check_loot(&"loot.ledger_laptop", Enums.LootWeight.LIGHT)
	_check_loot(&"loot.ledger_drives", Enums.LootWeight.MEDIUM)
	# MEDIUM is the lead's decision (B4-10); the C doc's QC-15 asked for LIGHT.
	_check_loot(&"loot.ledger_books", Enums.LootWeight.MEDIUM)
	_check_loot(&"loot.painting", Enums.LootWeight.LIGHT)  # lead ruling: cut and rolled = LIGHT (PD2)


func test_shadow_ledger_objectives_follow_the_design_doc() -> void:
	_check_objectives("shadow_ledger", SL_TAGS)


func test_shadow_ledger_briefing() -> void:
	_check_briefing(&"shadow_ledger", &"contact.accountant", 3)


func test_shadow_ledger_assets_validate() -> void:
	PreplanBoard.clear_cache()
	var g: Dictionary = PreplanBoard.generic_assets()
	for id: StringName in SL_ASSETS:
		assert_true(g.has(id), String(id))
		if not g.has(id):
			continue
		var a: PreplanAssetDef = g[id] as PreplanAssetDef
		assert_eq(a.validate(), [] as Array[String], "valid %s" % id)
		assert_true(a.grants.is_empty(), "%s grants nothing" % id)
		assert_has(_table, "item.%s.name" % id)
		assert_has(_table, "item.%s.desc" % id)
	var laptop: PreplanAssetDef = g[&"asset.intel_laptop"] as PreplanAssetDef
	assert_false(laptop.is_located(), "crew asset")
	assert_eq(laptop.reveals, [&"laptop"] as Array[StringName])
	assert_has(_table, "ui.preplan.category.insider")


## The gondola/riser assets take their forced slot from the chosen point's params (doc's
## Pre-planning table), never from a point of another kind.
func test_shadow_ledger_entry_assets_force_the_point_slot() -> void:
	var bp: PreplanBlueprint = PreplanBlueprint.new()
	bp.heist_id = &"shadow_ledger"
	var rows: Array = [
		[&"pp_gondola_west", {"variant_group": &"gondola", "variant_slot": &"gon_west_l41"}],
		[&"pp_gondola_north", {"variant_group": &"gondola", "variant_slot": &"gon_north_l42"}],
		[&"pp_riser_l41", {"variant_group": &"vent_open", "variant_slot": &"vent_l41"}],
		[&"pp_riser_l42", {"variant_group": &"vent_open", "variant_slot": &"vent_l42"}],
		[&"pp_insider_code", {}],
	]
	for i: int in range(rows.size()):
		bp.points.append({"id": rows[i][0], "category": &"insider", "pos": Vector2(i * 4, 0), "floor": 0,
				"label": StringName("ui.preplan.point.%s" % rows[i][0]), "params": rows[i][1]})
		if String(rows[i][0]) != "pp_insider_code":
			assert_has(_table, "ui.preplan.point.%s" % rows[i][0])
	var def: HeistDef = HeistDef.new()
	def.id = &"shadow_ledger"
	var b: PreplanBoard = PreplanBoard.build(&"shadow_ledger", Enums.Difficulty.ROUTINE, def, null, bp)
	assert_eq(b.errors, [] as Array[String])
	assert_false(b.assets_for_point(&"pp_insider_code").has(&"asset.gondola_left_hung"), "point ids only")
	assert_false(b.assets_for_point(&"pp_insider_code").has(&"asset.riser_panel"), "point ids only")
	var p: PreplanPlan = PreplanPlan.new(b)
	assert_eq(p.add(&"asset.riser_panel", &"pp_gondola_west", 0), PreplanPlan.R_WRONG_POINT)
	assert_eq(p.add(&"asset.gondola_left_hung", &"pp_gondola_north", 0), PreplanPlan.OK)
	assert_ne(p.add(&"asset.gondola_left_hung", &"pp_gondola_west", 0), PreplanPlan.OK, "one gondola slot")
	assert_eq(p.add(&"asset.riser_panel", &"pp_riser_l41", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.intel_laptop", &"", 0), PreplanPlan.OK)
	var r: Dictionary = p.apply()
	var fv: Dictionary = r["force_variants"] as Dictionary
	assert_eq(fv.get(&"gondola"), [&"gon_north_l42"] as Array[StringName])
	assert_eq(fv.get(&"vent_open"), [&"vent_l41"] as Array[StringName])
	assert_has(r["reveals"] as Array, &"laptop")


# --- B5-04 Dockside Burn (D-064 G0 doc; ENV C's HeistDef and map may still be missing) ---

## A synthetic board on the doc's Preplan points with the proposed preplanning (no map needed).
func _db_board() -> PreplanBoard:
	var bp: PreplanBlueprint = PreplanBlueprint.new()
	bp.heist_id = DB_HEIST
	for i: int in range(DB_POINTS.size()):
		var row: Array = DB_POINTS[i] as Array
		bp.points.append({"id": row[0], "category": row[1], "pos": Vector2(i * 4, 0), "floor": 1,
				"label": StringName("ui.preplan.point.%s" % row[0]), "params": row[2]})
	var def: HeistDef = HeistDef.new()
	def.id = DB_HEIST
	def.mode = Enums.HeistMode.LOUD_ONLY
	def.preplanning = DB_PREPLAN.duplicate(true)
	return PreplanBoard.build(DB_HEIST, Enums.Difficulty.ROUTINE, def, null, bp)


## QC-39: weapon crates HEAVY, contraband MEDIUM (cash is the existing cash bricks), and the thermite
## tool bag: HEAVY, value 0, and no payout or bag XP.
func test_dockside_burn_loot() -> void:
	_check_loot(&"loot.weapon_crate", Enums.LootWeight.HEAVY)
	_check_loot(&"loot.contraband", Enums.LootWeight.MEDIUM)
	var crate: LootDef = ContentDB.loot(&"loot.weapon_crate")
	var product: LootDef = ContentDB.loot(&"loot.contraband")
	var bricks: LootDef = ContentDB.loot(&"loot.cash_bricks")
	if crate == null or product == null or bricks == null:
		return
	assert_true(crate.value > bricks.value, "HEAVY crate worth more per bag than MEDIUM cash bricks")
	assert_true(product.value < bricks.value, "product is a discounted bonus")
	var thermite: LootDef = ContentDB.loot(&"loot.thermite")
	assert_true(thermite != null, "loot.thermite")
	if thermite == null:
		return
	assert_eq(thermite.weight, Enums.LootWeight.HEAVY)
	assert_eq(thermite.value, 0, "tool bag: no value")
	assert_true(thermite.is_tool, "D-068: a tool, not profit")
	assert_has(_table, "item.loot.thermite.name")
	var with_tool: Dictionary = {
		"success": true, "stealth": false, "difficulty": Enums.Difficulty.BRUTAL, "contract_pay": DB_BASE_PAYOUT,
		"loot": [{"loot_id": &"loot.weapon_crate", "value": crate.value}, {"loot_id": &"loot.thermite", "value": 0}],
		"small_loot": 0, "crew": [],
	}
	var without: Dictionary = with_tool.duplicate(true)
	(without["loot"] as Array).pop_back()
	var a: Dictionary = PayoutCalculator.compute(with_tool)
	var b: Dictionary = PayoutCalculator.compute(without)
	assert_eq(int(a["loot"]), int(b["loot"]), "thermite adds no cash")
	assert_eq(int(a["xp_total"]), int(b["xp_total"]), "thermite adds no bag XP")
	assert_eq((a["loot_lines"] as Array).size(), (b["loot_lines"] as Array).size(), "no payday line for a tool")
	var tw: PayoutTweak = load("res://content/data/tweak/payout.tres") as PayoutTweak
	assert_false(tw.xp_loot_excluded_ids.has(&"loot.thermite"), "is_tool replaces the exclusion list entry")
	var def: HeistDef = HeistRegistry.get_def(DB_HEIST)
	if def == null:
		return
	assert_false(def.loot.has(&"loot.thermite"), "the tool bag is not payout loot")
	for id: StringName in def.loot:
		if id != &"loot.small_valuables":  # small loot: no LootDef (QB-52)
			assert_true(ContentDB.loot(id) != null, "dockside_burn def loot %s exists" % id)


## Reyes (the contact) has 3 lines and Mercer closes with 2; the other contacts also have a set (as
## for Glasshouse), so the briefing plays whoever ends up offering the contract.
func test_dockside_burn_briefing() -> void:
	_check_briefing(DB_HEIST, &"contact.reyes", 3, 2)
	for c: ContactDef in ContactDef.all():
		if c.is_handler:
			continue
		var own: int = 0
		for l: Dictionary in BriefingModel.voice_lines(DB_HEIST, c):
			if StringName(l["speaker"]) == c.voice_speaker:
				own += 1
		assert_true(own >= 2, "%s has Dockside Burn briefing lines" % c.id)
	var def: HeistDef = HeistRegistry.get_def(DB_HEIST)
	if def == null:
		return
	assert_eq(int(def.mode), Enums.HeistMode.LOUD_ONLY, "Dockside Burn is loud-only (game_overview row 4)")
	for e: StringName in def.escape_options:
		assert_has(_table, "ui.briefing.escape.%s" % e)


func test_dockside_burn_objectives_follow_the_design_doc() -> void:
	_check_objectives(String(DB_HEIST), DB_TAGS)
	var def: HeistDef = HeistRegistry.get_def(DB_HEIST)
	if def == null:
		return
	var ids: Array[String] = []
	for id: StringName in def.objectives:
		ids.append(String(id))
	assert_eq(ids, DB_TAGS, "HeistDef objectives follow the doc")


## Board: Reyes' pin in the docks, the placeholder payout through PayoutCalculator, the global
## difficulty gates and pro eligibility (no per-heist overrides exist).
func test_dockside_burn_board_contract() -> void:
	var city: BoardCityMap = BoardCityMap.load_default()
	assert_eq(city.heist_contact(DB_HEIST), &"contact.reyes")
	assert_eq(city.heist_district(DB_HEIST), &"docks")
	var poly: PackedVector2Array = city.districts[&"docks"]["polygon"] as PackedVector2Array
	assert_true(Geometry2D.is_point_in_polygon(city.heist_anchor(DB_HEIST), poly), "pin inside the docks")
	for d: int in range(DB_PAY_TABLE.size()):
		assert_eq(HeistCatalog.contract_preview(DB_BASE_PAYOUT, d), DB_PAY_TABLE[d], "doc pay table, difficulty %d" % d)
	var def: HeistDef = HeistRegistry.get_def(DB_HEIST)
	var base: int = def.base_payout if def != null else DB_BASE_PAYOUT
	var entry: Dictionary = {"id": DB_HEIST, "base_payout": base, "mode": Enums.HeistMode.LOUD_ONLY, "def": def}
	var heist_pool: Array[Dictionary] = BoardContracts.pool_from([entry] as Array[Dictionary], city)
	var contact: StringName = StringName(heist_pool[0]["contact"])
	assert_true(ContactDef.find(contact) != null, "contact %s" % contact)
	if def == null or def.contact == &"":
		assert_eq(contact, &"contact.reyes", "map contact while the def is missing")
	var tweak: BoardTweak = BoardTweak.load_default()
	var allowed: Array[int] = BoardContracts.allowed_difficulties(0, tweak)
	assert_false(allowed.has(Enums.Difficulty.LETHAL), "Lethal needs level 80")
	var pros: int = 0
	for bucket: int in range(200):
		var c: Dictionary = BoardContracts.contract_for(0, bucket, allowed, heist_pool, tweak, city)
		var d: int = int(c["difficulty"])
		assert_has(allowed, d)
		assert_eq(StringName(c["district"]), &"docks")
		assert_eq(int(c["payout"]), HeistCatalog.contract_preview(base, d))
		if bool(c["is_pro"]):
			pros += 1
			assert_true(d >= tweak.pro_min_difficulty, "pro only from Tense")
	assert_true(pros > 0, "Dockside Burn can roll as a pro job")


## QC-40: the five new assets validate and have strings; on the doc's points the proposed block
## offers each where the doc says, and the plan shapes the PreplanResult (incl. the loot-bag drop).
func test_dockside_burn_preplan() -> void:
	PreplanBoard.clear_cache()
	var lib: Dictionary = PreplanBoard.generic_assets()
	for id: StringName in DB_NEW_ASSETS:
		assert_true(lib.has(id), String(id))
		if not lib.has(id):
			return
		assert_eq((lib[id] as PreplanAssetDef).validate(), [] as Array[String], "valid %s" % id)
		assert_has((lib[id] as PreplanAssetDef).tags, &"loud")
		assert_has(_table, "item.%s.name" % id)
		assert_has(_table, "item.%s.desc" % id)
	for row: Variant in DB_POINTS:
		var pid: StringName = (row as Array)[0]
		var key: String = "ui.preplan.point.%s%s" % ["dockside_burn." if DB_SHARED_POINT_IDS.has(pid) else "", pid]
		assert_has(_table, key, "label for %s" % pid)
	var b: PreplanBoard = _db_board()
	assert_eq(b.errors, [] as Array[String])
	assert_eq(b.favors_budget, 5)
	for id: Variant in DB_PREPLAN["disable"] as Array:
		assert_false(b.assets.has(StringName(id)), "disabled %s" % id)
	assert_true(b.assets_for_point(&"pp_drop_lane").has(&"asset.thermite_drop"))
	assert_false(b.assets_for_point(&"pp_drop_platform").has(&"asset.thermite_drop"), "no thermite up the stair")
	assert_true(b.assets_for_point(&"pp_drop_platform").has(&"asset.ammo_bag_drop"))
	assert_false(b.assets_for_point(&"pp_perch_roof").has(&"asset.ammo_bag_drop"), "perches take the sniper asset only")
	assert_eq(b.assets_for_point(&"pp_perch_stack"), [&"asset.sniper_position"] as Array[StringName])
	assert_has(b.crew_assets(), &"asset.intel_containers")
	assert_has(b.crew_assets(), &"asset.lift_power")
	var p: PreplanPlan = PreplanPlan.new(b)
	assert_eq(p.add(&"asset.sniper_position", &"pp_perch_roof", 0), PreplanPlan.OK)
	assert_ne(p.add(&"asset.sniper_position", &"pp_perch_stack", 0), PreplanPlan.OK, "one perch")
	assert_eq(p.add(&"asset.thermite_drop", &"pp_drop_lane", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.gangway_raised", &"pp_gangway", 0), PreplanPlan.OK)
	assert_eq(p.add(&"asset.lift_power", &"", 0), PreplanPlan.R_FAVORS, "5 favors: a real choice")
	var r: Dictionary = p.apply()
	var fv: Dictionary = r["force_variants"] as Dictionary
	assert_eq(fv.get(&"player_perch"), [&"perch_roof"] as Array[StringName])
	assert_eq(fv.get(&"east_gangway"), [&"gangway_up"] as Array[StringName])
	var kinds: Dictionary = {}
	for d: Dictionary in r["drops"] as Array:
		kinds[StringName(d["point"])] = StringName(d["kind"])
	assert_eq(kinds.get(&"pp_perch_roof"), &"deployable.ammo_bag", "the perch comes with an ammo bag")
	assert_eq(kinds.get(&"pp_drop_lane"), &"loot.thermite", "loot-bag drop kind (QC-40)")
	var q: PreplanPlan = PreplanPlan.new(b)
	assert_eq(q.add(&"asset.intel_containers", &"", 0), PreplanPlan.OK)
	assert_eq(q.add(&"asset.lift_power", &"", 0), PreplanPlan.OK)
	var r2: Dictionary = q.apply()
	assert_has(r2["reveals"] as Array, &"weapons_containers")
	assert_eq((r2["force_variants"] as Dictionary).get(&"goods_lift"), [&"lift_powered"] as Array[StringName])


## The Dockside-only assets never show on another registered heist: the located ones by point_ids,
## the crew ones by their variant groups (QB-53).
func test_dockside_burn_assets_stay_on_dockside() -> void:
	var lib: Dictionary = PreplanBoard.generic_assets()
	var db_points: Array[StringName] = []
	for row: Variant in DB_POINTS:
		db_points.append((row as Array)[0] as StringName)
	for id: StringName in DB_NEW_ASSETS:
		var a: PreplanAssetDef = lib.get(id) as PreplanAssetDef
		if a == null:
			continue
		if a.is_located():
			assert_true(a.point_categories.is_empty(), "%s limited by point_ids" % id)
			for pid: StringName in a.point_ids:
				assert_has(db_points, pid, "%s point" % id)
		else:
			assert_false(a.reveals.is_empty() and a.force_variants.is_empty(), "%s hides by variant group" % id)
	var checked: int = 0
	for def: HeistDef in HeistRegistry.all():
		if def.id == DB_HEIST or not ResourceLoader.exists(PreplanBoard.variants_path(def.id)):
			continue
		checked += 1
		var b: PreplanBoard = PreplanBoard.build(def.id, Enums.Difficulty.ROUTINE, def, null, PreplanBlueprint.new())
		for id: StringName in [&"asset.intel_containers", &"asset.lift_power"]:
			assert_false(b.assets.has(id), "%s hidden on %s" % [id, def.id])
	if checked == 0:
		skip("no other heist with a variant table in this checkout")


## UI: the heist list entry and an accent whose raw colour already passes WCAG AA for text (4.5:1).
func test_dockside_burn_ui() -> void:
	assert_eq(HeistCatalog.heist_list().solo_ai_for(DB_HEIST), 3, "loud-only: a full bot crew for solo")
	assert_true(UiAccent.table().accents.has(DB_HEIST))
	for bg: Color in [UiAccent.panel_bg(), UiAccent.app_bg()]:
		assert_true(UiAccent.contrast_ratio(UiAccent.for_heist(DB_HEIST), bg) >= 4.5, "flare orange readable as is")
	for k: String in ["name", "subtitle", "brief", "briefing"]:
		assert_has(_table, "heist.%s.%s" % [DB_HEIST, k])
