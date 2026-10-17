## GN-B1: Gallery Night content data (HeistDef + variant table at world/heists/gallery_night since C's G1, trunk
## 55ce4d2a; B owns their content values, C the node paths). Pins the lead's rulings on them:
## one source of truth for pre-planning assets (the library holds the values, the def only references or re-points
## them), guard counts per difficulty, Hazardous on the Brutal+ weights, kc_conservator only with cons_late.
extends TestCase

const HEIST: StringName = &"gallery_night"
const DRAFT_DIR: String = "res://content/_drafts/gallery_night/"
## guard_post picks (rovers + smoker, the hall post is fixed) by Enums.Difficulty, lead ruling 2.
const GUARD_PICKS: Array[int] = [1, 1, 2, 3, 4, 4]
const SEEDS: int = 200
## Map slot ids per variant group (README "Map slot names"), stand-ins for the greybox's VariantSlots.
const SLOTS: Dictionary = {
	&"centrepiece": [&"cp_landing", &"cp_store", &"cp_treasury"],
	&"canvas_orchard": [&"orchard_benefactors", &"orchard_calloway", &"orchard_quarantine"],
	&"canvas_widow": [&"widow_conservation", &"widow_founders", &"widow_sallow"],
	&"canvas_saint": [&"saint_harbour", &"saint_maritime", &"saint_store"],
	&"sensor_net": [&"sensors_all", &"sensors_treasury", &"sensors_upper"],
	&"conservator": [&"cons_gone", &"cons_late"],
	&"keycard": [&"kc_conservator", &"kc_curator", &"kc_registrar", &"kc_security"],
	&"code_note": [&"code_admin_postit", &"code_curator_planner", &"code_security_log"],
	&"guard_post": [&"dock_smoker", &"rover_basement", &"rover_ground", &"rover_none", &"rover_upper"],
	&"security_room_staffed": [&"sec_empty", &"sec_staffed"],
	&"camera": [&"cam_a", &"cam_b", &"cam_c"],
	&"laser_pattern": [&"lz_static", &"lz_sweep", &"lz_timed"],
	&"curator_route": [&"curator_hall", &"curator_office"],
	&"court_doors": [&"court_doors_locked", &"court_doors_open"],
	&"areaway": [&"grate_loose", &"grate_padlocked"],
	&"escape": [&"esc_mews", &"esc_parade"],
	&"xl_crate": [&"xl_loan", &"xl_none"],  # QC-62: >= 2 slots per group (validate_level contract_nodes)
	&"admin_pa": [&"pa_late", &"pa_none"],
	&"gala_extra": [&"gx_cloakroom", &"gx_drawings"],  # C a5f115c1: D-130 GN civilian extras
}
## HeistDef.preplanning override key -> PreplanAssetDef property (PreplanAssetDef.with_overrides).
const FIELD_OF: Dictionary = {"params": "drop_params"}

var _def: HeistDef = null
var _table: HeistVariantTable = null
var _slots: Dictionary = {}
var _nodes: Array[Node] = []


func before_all() -> void:
	_def = load(_path("%s_def.tres" % HEIST)) as HeistDef
	_table = load(_path("%s_variants.tres" % HEIST)) as HeistVariantTable
	var ruled: Array[StringName] = []
	for r: Dictionary in _table.rules:
		ruled.append(StringName(r.get("group", &"")))
	for g: StringName in SLOTS:
		if not ruled.has(g):
			continue  # a group C has placed but this branch's table has no rule for yet (no "no rule" warning)
		_slots[g] = []
		for sid: StringName in SLOTS[g]:
			var vs: VariantSlot = VariantSlot.new()
			vs.slot_group = g
			vs.slot_id = sid
			(_slots[g] as Array).append(vs)
			_nodes.append(vs)


func after_all() -> void:
	for n: Node in _nodes:
		n.free()
	_nodes.clear()


func test_drafts_load() -> void:
	assert_true(_def != null, "HeistDef loads")
	assert_true(_table != null, "variant table loads")
	if _def != null:
		assert_eq(_def.id, HEIST)
		assert_eq(_def.base_payout, 57000, "D-120 (C's def lands in the same round)")


## Lead ruling 6: the library assets hold the values; a def entry only references them ({}) or changes what is
## heist-specific (points, copies). Restating a library value is a duplicate and fails here.
func test_def_preplanning_does_not_restate_library_values() -> void:
	if _def == null:
		fail("no def")
		return
	var lib: Dictionary = PreplanBoard.generic_assets()
	var entries: Dictionary = _def.preplanning.get("assets", {}) as Dictionary
	for id: Variant in entries:
		var base: PreplanAssetDef = lib.get(StringName(id)) as PreplanAssetDef
		assert_true(base != null, "%s is a library asset" % id)
		if base == null:
			continue
		var entry: Dictionary = entries[id]
		var errs: Array[String] = []
		var merged: PreplanAssetDef = base.with_overrides(entry, errs)
		assert_eq(errs, [] as Array[String], "%s overrides" % id)
		for k: Variant in entry:
			var prop: String = String(FIELD_OF.get(String(k), String(k)))
			assert_ne(merged.get(prop), base.get(prop), "%s restates the library's %s" % [id, k])
	for id: StringName in [&"asset.intel_list", &"asset.intel_sensors"]:
		assert_eq(entries.get(id), {}, "%s is referenced by id only" % id)


func test_def_preplanning_merges_cleanly() -> void:
	if _def == null:
		fail("no def")
		return
	var errs: Array[String] = []
	var merged: Dictionary = PreplanBoard.merge(PreplanBoard.generic_assets(), _def.preplanning, errs)
	for id: Variant in merged["assets"]:
		errs.append_array((merged["assets"][id] as PreplanAssetDef).validate())
	assert_eq(errs, [] as Array[String])
	assert_eq(int(merged.get("favors", 0)), 5)


## Lead ruling 2: 1 pick at Routine/Tense (rover_none ~20%), 2 at Hazardous, 3 at Brutal, 4 at Lethal+.
func test_guard_post_picks_per_difficulty() -> void:
	for d: int in range(GUARD_PICKS.size()):
		var none: int = 0
		for s: int in range(SEEDS):
			var picked: Array = _roll(d, s).get(&"guard_post", [])
			assert_eq(picked.size(), GUARD_PICKS[d], "difficulty %d seed %d picks" % [d, s])
			if picked.has(&"rover_none"):
				none += 1
		if d >= Enums.Difficulty.HAZARDOUS:
			assert_eq(none, 0, "no rover_none from Hazardous (difficulty %d)" % d)
		else:
			var share: float = float(none) / SEEDS
			assert_true(share > 0.1 and share < 0.3, "rover_none ~20%% at difficulty %d (got %.2f)" % [d, share])


## Lead ruling 1: Tense keeps the Routine (base) weights, Hazardous uses the Brutal+ weights.
func test_hazardous_uses_brutal_weights_tense_routine() -> void:
	if _table == null:
		fail("no table")
		return
	var haz: int = Enums.Difficulty.HAZARDOUS
	var bru: int = Enums.Difficulty.BRUTAL
	for group: StringName in [&"sensor_net", &"laser_pattern"]:
		var wbd: Dictionary = _rule(group).get("weights_by_difficulty", {})
		assert_true(wbd.has(haz), "%s has Hazardous weights" % group)
		assert_eq(wbd.get(haz), wbd.get(bru), "%s Hazardous = Brutal+" % group)
		assert_false(wbd.has(Enums.Difficulty.TENSE), "%s Tense uses the base (Routine) weights" % group)
	for id: StringName in [&"patrons", &"escape_eta_s"]:
		var sc: Dictionary = _scalar(id)
		var wbd: Dictionary = sc.get("weights_by_difficulty", {})
		assert_true(wbd.has(haz), "%s has Hazardous weights" % id)
		assert_eq(wbd.get(haz), wbd.get(bru), "%s Hazardous = Brutal+" % id)
		assert_false(wbd.has(Enums.Difficulty.TENSE), "%s Tense uses the base (Routine) weights" % id)


func test_keycards_and_rare_event_gates() -> void:
	for d: int in range(GUARD_PICKS.size()):
		for s: int in range(40):
			var r: Dictionary = _roll(d, s)
			var cards: Array = r.get(&"keycard", [])
			assert_eq(cards.size(), 2, "two keycards")
			if cards.has(&"kc_conservator"):
				assert_has(r.get(&"conservator", []), &"cons_late", "kc_conservator needs cons_late")
	var gates: Dictionary = {&"insurance_inspection": 2, &"vaultline_early": 2, &"argus_upgrade": 4}
	for ev: Dictionary in _table.rare_events:
		var id: StringName = StringName(ev["id"])
		if gates.has(id):
			assert_eq(int(ev.get("min_difficulty", -1)), int(gates[id]), "%s min_difficulty (top level)" % id)
		assert_false((ev.get("effects", {}) as Dictionary).has("min_difficulty"), "%s: min_difficulty is top level" % id)
		# Round 125: a rare event's condition is top level (VariantResolver ignores it inside effects).
		for key: String in ["requires", "excludes"]:
			assert_false((ev.get("effects", {}) as Dictionary).has(key), "%s: %s is top level" % [id, key])
	var vl: Dictionary = {}
	for ev: Dictionary in _table.rare_events:
		if StringName(ev["id"]) == &"vaultline_early":
			vl = ev
	assert_eq(vl.get("requires", {}), {&"centrepiece": [&"cp_landing", &"cp_treasury"]}, "vaultline_early condition")
	var fired: int = 0
	for s: int in range(400):
		var r: Dictionary = _roll(Enums.Difficulty.BRUTAL, s)
		if (r.get("rare", []) as Array).has(&"vaultline_early"):
			fired += 1
			var cp: Array = r.get(&"centrepiece", [])
			assert_true(cp.has(&"cp_landing") or cp.has(&"cp_treasury"), "vaultline_early only with a far centrepiece: %s" % [cp])
	assert_true(fired > 0, "vaultline_early fires on some seeds")


## D-109: the briefing names the main path, one loud line and the optional extras, all from the def.
func test_briefing_subset() -> void:
	var all: Array = Array(_def.objectives)
	assert_true(_def.briefing_objectives.size() >= 5 and _def.briefing_objectives.size() < all.size())
	for id: StringName in _def.briefing_objectives + _def.briefing_optional:
		if String(id).contains("."):  # a briefing-only step (ui.briefing.step.<heist>.<step>), a strings key as-is
			assert_true(String(id).begins_with("ui.briefing.step.%s." % HEIST) and StringTable.has(id),
					"%s is a GN briefing step string" % id)
		else:
			assert_has(all, id, "%s is a def objective" % id)
	assert_eq(_def.briefing_objectives[_def.briefing_objectives.size() - 1], &"escape")
	assert_true(StringTable.has(_def.briefing_loud_key), "loud line string")
	var m: Dictionary = BriefingModel.build(HEIST, Enums.Difficulty.HAZARDOUS, _def)
	var capped: Dictionary = BriefingModel.cap_objectives(Array(_def.briefing_objectives),
			BriefingModel.ui_data().briefing_lead_steps)
	assert_eq((m["objectives"] as Array).size(), (capped["shown"] as Array).size(), "D-117 §5 cap")
	assert_eq(int(m["objectives_more"]), int(capped["more"]))
	assert_ne(String(m["loud_text"]), "")
	assert_eq((m["optional"] as Array).size(), _def.briefing_optional.size())


# --- helpers ------------------------------------------------------------------------------

## The registered def's folder (the drafts folder only on a branch from before G1).
func _path(file: String) -> String:
	var world: String = HeistRegistry.def_path(HEIST).get_base_dir().path_join(file)
	return world if ResourceLoader.exists(world) else DRAFT_DIR + file


func _roll(difficulty: int, seed_i: int) -> Dictionary:
	GameRng.begin_run(7000 + seed_i)
	return VariantResolver.resolve(_table, _slots, difficulty)


func _rule(group: StringName) -> Dictionary:
	for r: Dictionary in _table.rules:
		if StringName(r.get("group", &"")) == group:
			return r
	return {}


func _scalar(id: StringName) -> Dictionary:
	for sc: Dictionary in _table.scalars:
		if StringName(sc.get("id", &"")) == id:
			return sc
	return {}


## Lead (lift prep): every GN objective id has its briefing line and its HUD label, both from
## `objective.gallery_night.<id>` (the hack's loud text is `hack_loud`), with no raw key or "{arg}" left.
func test_every_objective_has_briefing_and_hud_text() -> void:
	var ids: Array[StringName] = []
	ids.assign(_def.objectives)
	for id: StringName in _def.briefing_objectives + _def.briefing_optional + [&"hack_loud"]:
		if not ids.has(id):
			ids.append(id)
	var lines: Array[Dictionary] = BriefingModel.objective_lines(HEIST, ids)
	for i: int in range(ids.size()):
		var step: bool = String(ids[i]).contains(".")  # briefing-only step key: no HUD objective behind it
		var key: StringName = ids[i] if step else StringName("objective.%s.%s" % [HEIST, ids[i]])
		assert_true(StringTable.has(key), "%s has a string" % key)
		var brief: String = String(lines[i]["text"])
		assert_false(brief.contains("{") or brief.begins_with("objective.") or brief.begins_with("ui."),
				"briefing line for %s: %s" % [ids[i], brief])
		if step:
			continue
		var hud: String = ObjectivesPanel.objective_text({"id": ids[i], "text_key": key, "args": {}})
		assert_false(hud.contains("{") or hud.begins_with("objective.") or hud == "", "HUD label for %s: %s" % [ids[i], hud])
