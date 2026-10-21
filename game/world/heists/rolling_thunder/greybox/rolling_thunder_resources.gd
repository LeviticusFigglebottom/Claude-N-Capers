## Rolling Thunder: HeistDef + HeistVariantTable values for ENV C's generator. PLACEHOLDER BLOCK (RT-C1, ENV C): ENV B
## owns these values (D-137 QB-2: B sends the values block, C pastes it here verbatim and regenerates). B's RT-B1 block
## does not exist yet, so this file carries ONLY numbers that are already ruled or written down, and nothing invented:
## * HeistDef identity / mode / loot / objectives / escapes / music: the G0 doc §HeistDef + B's stub
##   (game/content/docs/heists/rolling_thunder.md): contact.reyes, base_payout $30,000 (D-141.1, pinned in
##   test_p5_catalogue), stealth_bonus_mult 1.0 (B's audit: no stealth win), loot cash_bricks / gold / bearer_bonds.
## * Variable table, scalars, rare events: the doc's G0 numbers (§Variable table, §Rare events, the Convoy units table),
##   the same numbers as tools/levelcheck/plans/rolling_thunder_slots.py (--check PASS).
## * Pre-planning: the doc's point lists only. NO costs / favors for the heist assets (asset.signal_insider,
##   asset.intel_route keep their library costs; asset.c4_drop waits on A5-03 + B, D-141.3); the doc's ◇ favors 5 is
##   B's number to confirm.
## Missing from B (RT-B1, listed in the RT-C1 report): the values block itself (rule weights by difficulty, rare effect
## keys for A's mission, the preplanning costs / favors, briefing_objectives / briefing_optional / briefing keys), the
## D-143.5 per-heist allow-lists on signal_insider / intel_route, asset.c4_drop.
## Format = ostrander_federal_resources.gd (make_def / make_variants / _from).

const OUT_DIR: String = "res://world/heists/rolling_thunder/"
const SCENE_PATH: String = OUT_DIR + "rolling_thunder.tscn"
const DEF_PATH: String = OUT_DIR + "rolling_thunder_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "rolling_thunder_variants.tres"


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"rolling_thunder"
	d.display_name = "Rolling Thunder"
	d.contact = &"contact.reyes"
	# D-117 §4: strings-table keys (ENV B), never literals (heist.rolling_thunder.briefing exists on B's side).
	d.briefing = "heist.rolling_thunder.briefing"
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD   # "Loud (ambush start)" (D-075; heist_list.tres mode_key)
	d.map_scene = SCENE_PATH
	d.base_payout = 30000  # D-141.1 (the doc's $85,000 superseded)
	d.stealth_bonus_mult = 1.0  # no stealth win (B's audit, as DB)
	d.loot = [&"loot.cash_bricks", &"loot.gold", &"loot.bearer_bonds"] as Array[StringName]
	# Objective ids = the doc's Objectives `[tag]`s in §HeistDef order (13; strings objective.rolling_thunder.<tag>).
	d.objectives = [&"casing", &"signals", &"charges", &"thermite", &"marshal", &"convoy", &"ambush", &"escort",
		&"trucks", &"cargo", &"secure", &"escape_wait", &"escape"] as Array[StringName]
	# Pre-planning (contracts/preplanning.md; doc §Pre-planning): point lists only, costs / favors are B's (RT-B1).
	d.preplanning = {
		"disable": [&"asset.intel_keycards", &"asset.intel_laptop"],
		"assets": {
			&"asset.alternate_entry": {"point_categories": [&"spawn"],
				"point_ids": [&"pp_spawn_carpark", &"pp_spawn_underpass"]},
			&"asset.ammo_bag_drop": {"point_ids": [&"pp_drop_site", &"pp_drop_carpark", &"pp_drop_diner_yard",
				&"pp_drop_underpass"]},
			&"asset.doctor_bag_drop": {"point_ids": [&"pp_drop_site", &"pp_drop_carpark", &"pp_drop_diner_yard",
				&"pp_drop_underpass"]},
			&"asset.body_bag_case_drop": {"point_ids": [&"pp_drop_site", &"pp_drop_diner_yard"]},
			&"asset.thermite_drop": {"point_ids": [&"pp_drop_site", &"pp_drop_carpark", &"pp_drop_underpass"]},
			&"asset.sniper_position": {"point_ids": [&"pp_perch_roof", &"pp_perch_frame"]},
			&"asset.escape_position": {"point_categories": [&"escape"], "force_variants": {}},
			&"asset.signal_insider": {"point_ids": [&"pp_signals"]},
			&"asset.intel_route": {"reveals": [&"convoy_route", &"marshal_walk"]},
			&"asset.intel_guard_posts": {"reveals": [&"guard_post"]},
			&"asset.intel_cameras": {"reveals": [&"camera"]},
			&"asset.extra_cable_ties": {},
			&"asset.spare_body_bags": {},
			&"asset.lift_power": {},
		},
	}
	d.escape_options = [&"van", &"heli"] as Array[StringName]
	d.music_track = &"rolling_thunder"
	return d


## Variable table (doc §Variable table), resolved in this order. Per-difficulty weights are exact-difficulty keys.
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	# truck_count (Convoy units table): Routine/Tense 0.7 / 0.3, Hazardous/Brutal 0.4 / 0.6, Lethal+ 0.2 / 0.8
	var trucks: Dictionary = _from(Enums.Difficulty.HAZARDOUS, {&"trucks_2": 0.4, &"trucks_3": 0.6})
	for dv: int in [Enums.Difficulty.LETHAL, Enums.Difficulty.CATACLYSM]:
		trucks[dv] = {&"trucks_2": 0.2, &"trucks_3": 0.8}
	t.rules = [
		{"group": &"convoy_route", "pick": Vector2i(1, 1)},
		{"group": &"truck_count", "pick": Vector2i(1, 1), "weights_by_difficulty": trucks},
		{"group": &"cargo_t3", "pick": Vector2i(1, 1), "requires": {&"truck_count": [&"trucks_3"]}},
		{"group": &"controller", "pick": Vector2i(1, 1)},
		{"group": &"site_stores", "pick": Vector2i(1, 1)},
		# guard_post: 1 (Routine/Tense), 2 (Hazardous+)
		{"group": &"guard_post", "pick": Vector2i(1, 1), "difficulty_add": [0, 0, 1, 1, 1, 1] as Array[int]},
		# camera: 1 (Routine-Hazardous), 2 (Brutal+)
		{"group": &"camera", "pick": Vector2i(1, 1), "difficulty_add": [0, 0, 0, 1, 1, 1] as Array[int]},
		{"group": &"cop_on_scene", "pick": Vector2i(1, 1)},
		{"group": &"marshal_walk", "pick": Vector2i(1, 1)},
		{"group": &"goods_lift", "pick": Vector2i(1, 1)},
		{"group": &"player_perch", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
	]
	t.rare_events = [
		{"id": &"bonds_courier", "chance": 0.08, "good": true, "effects": {"bonds_courier": true}},
		{"id": &"informant_tip", "chance": 0.06, "good": true,
			"effects": {"reveal": [&"convoy_route", &"marshal_walk"]}},
		# gold_rush pins trucks_3 (+ t3_bullion: one force_active per event; the second pin is A's mission, RT-A6)
		{"id": &"gold_rush", "chance": 0.04, "good": true,
			"effects": {"force_active": {"group": &"truck_count", "slot": &"trucks_3"}, "cargo_t3": &"t3_bullion"}},
		{"id": &"marshal_early", "chance": 0.08, "good": false, "effects": {"marshal_lead_s": 90.0}},
		{"id": &"convoy_early", "chance": 0.06, "good": false, "effects": {"convoy_eta_add_s": -45.0}},
		{"id": &"crane_sniper", "chance": 0.08, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"perch_s3": true}},
		{"id": &"armored_escort", "chance": 0.06, "good": false, "min_difficulty": Enums.Difficulty.LETHAL,
			"effects": {"wrecker_escort": true}},
		{"id": &"rush_hour", "chance": 0.06, "good": false, "effects": {"civilians": 12, "extra_diner_customers": 2}},
	]
	t.scalars = [
		{"id": &"cash_bags", "values": [4, 5, 6], "weights": PackedFloat32Array([0.3, 0.5, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"gold_bags", "values": [3, 4], "weights": PackedFloat32Array([0.5, 0.5])},
		{"id": &"convoy_eta_s", "values": [150.0, 180.0, 210.0], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
		{"id": &"police_delay_s", "values": [45.0, 60.0, 90.0], "weights": PackedFloat32Array([0.1, 0.3, 0.6]),
			"weights_by_difficulty": {
				Enums.Difficulty.TENSE: PackedFloat32Array([0.2, 0.4, 0.4]),
				Enums.Difficulty.HAZARDOUS: PackedFloat32Array([0.3, 0.5, 0.2]),
				Enums.Difficulty.BRUTAL: PackedFloat32Array([0.5, 0.4, 0.1]),
				Enums.Difficulty.LETHAL: PackedFloat32Array([0.7, 0.3, 0.0]),
				Enums.Difficulty.CATACLYSM: PackedFloat32Array([1.0, 0.0, 0.0]),
			}},
		{"id": &"escape_eta_s", "values": [90.0, 120.0, 150.0], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"civilians", "values": [6, 9, 12], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
	]
	return t


## {difficulty: value} for every difficulty from `first` up (the resolver keys are exact).
static func _from(first: int, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	for dv: int in range(first, Enums.Difficulty.CATACLYSM + 1):
		out[dv] = value
	return out
