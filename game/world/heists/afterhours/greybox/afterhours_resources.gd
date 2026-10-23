## Afterhours: HeistDef + HeistVariantTable values for ENV C's generator. ENV B owns the values (D-137 QB-2: B sends
## the values block, C pastes it here and regenerates). Source: B's block, game/content/docs/afterhours_values_block.txt
## (round 242; D-143 rulings: $40,000, stealth x1.15, the PAGERS map, van only). make_def() is B's def block verbatim;
## make_variants() is docs/design/heists/afterhours.md §Variable table / §Rare events (slot weights in the scene:
## afterhours_content.py SLOTS) with B's D-143 rule rows (guard_post 2 / 2, security_room_staffed by difficulty).
## Format = rolling_thunder_resources.gd (make_def / make_variants / _from).

const OUT_DIR: String = "res://world/heists/afterhours/"
const SCENE_PATH: String = OUT_DIR + "afterhours.tscn"
const DEF_PATH: String = OUT_DIR + "afterhours_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "afterhours_variants.tres"


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"afterhours"
	d.display_name = "Afterhours"
	d.contact = &"contact.accountant"  # D-075 ruling 6
	# D-117 §4: strings-table keys (ENV B), never literals.
	d.briefing = "heist.afterhours.briefing"
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD
	d.start_mode = &"civilian"  # D-065
	d.map_scene = SCENE_PATH
	d.base_payout = 40000  # D-143
	d.stealth_bonus_mult = 1.15  # S11.1 by heist size (D-141: M)
	d.pager_max_by_difficulty = [4, 3, 3, 2, 2, 1] as Array[int]  # D-143 PAGERS map (D-140)
	d.loot = [&"loot.cash_bricks", &"loot.parcels", &"loot.cash", &"loot.small_valuables"] as Array[StringName]
	d.objectives = [&"casing", &"gear", &"keycard", &"office", &"safe_code", &"safe", &"safe_loot", &"secure",
		&"product", &"count_room", &"escape_wait", &"escape"] as Array[StringName]
	# r299 B: the briefing's step list (OF / RT pattern; ui.briefing.step.afterhours.* are ENV B strings).
	d.briefing_objectives = [&"casing", &"gear", &"keycard", &"ui.briefing.step.afterhours.safe", &"secure",
		&"ui.briefing.step.afterhours.bonus", &"escape"] as Array[StringName]
	d.escape_options = [&"van"] as Array[StringName]  # D-143 (no walk-out)
	d.music_track = &"afterhours"  # music.afterhours.name "Velvet Rope" (ENV B string)
	d.preplanning = {
		"favors": 5,
		"assets": {
			&"asset.body_bag_case_drop": {"point_ids": [&"pp_drop_alley", &"pp_drop_tolley"]},
			&"asset.ammo_bag_drop": {"point_ids": [&"pp_drop_alley", &"pp_drop_roof", &"pp_drop_tolley"]},
			&"asset.doctor_bag_drop": {"point_ids": [&"pp_drop_alley", &"pp_drop_roof", &"pp_drop_tolley"]},
			&"asset.inside_keycard": {"point_ids": [&"pp_insider_keycard"]},  # forces kc_staff_room
			&"asset.propped_door": {"point_ids": [&"pp_back_door"]},  # forces rear_propped
			# B 00e1a1e9: listed explicitly (the library's alternate_entry would also offer the free pp_spawn_foyer)
			&"asset.alternate_entry": {"point_categories": [&"spawn"], "point_ids": [&"pp_spawn_vip", &"pp_spawn_alley"]},
			&"asset.escape_position": {"force_variants": {}, "point_categories": [&"escape"]},
			# asset.gear_drop, asset.count_window (point-limited) and asset.intel_safe_code / asset.intel_product
			# (library, allow-listed to afterhours, D-143) come from the library: no entry needed here.
		},
	}
	return d


## Variable table (doc §Variable table), resolved in LC.GROUP_ORDER. Per-difficulty weights are exact-difficulty keys.
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	# laser_pattern: Routine-Hazardous the slot weights (0.5 / 0.2 / 0.3), Brutal+ 0.2 / 0.4 / 0.4
	var lasers: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"lz_static": 0.2, &"lz_sweep": 0.4, &"lz_timed": 0.4})
	# security_room_staffed (B, D-143): Routine 0 / 1 (D-140 (a): Routine guards <= 4), Tense 0.6 / 0.4,
	# Hazardous+ 0.75 / 0.25
	var staffed: Dictionary = _from(Enums.Difficulty.HAZARDOUS, {&"sec_staffed": 0.75, &"sec_empty": 0.25})
	staffed[Enums.Difficulty.ROUTINE] = {&"sec_staffed": 0.0, &"sec_empty": 1.0}
	staffed[Enums.Difficulty.TENSE] = {&"sec_staffed": 0.6, &"sec_empty": 0.4}
	t.rules = [
		{"group": &"gear_drop", "pick": Vector2i(1, 1)},
		{"group": &"dj_set", "pick": Vector2i(1, 1)},
		# kc_dj_booth: the DJ's bag is on the booth only while he is off stage
		{"group": &"keycard", "pick": Vector2i(1, 1),
			"slot_requires": {&"kc_dj_booth": {&"dj_set": [&"dj_break"]}}},
		{"group": &"code_note", "pick": Vector2i(1, 1)},
		{"group": &"count_room", "pick": Vector2i(1, 1)},
		{"group": &"product_location", "pick": Vector2i(1, 1)},
		{"group": &"laser_pattern", "pick": Vector2i(1, 1), "weights_by_difficulty": lasers},
		{"group": &"guard_post", "pick": Vector2i(2, 2)},  # D-143: exactly 2 rovers, no difficulty_add
		{"group": &"security_room_staffed", "pick": Vector2i(1, 1), "weights_by_difficulty": staffed},
		{"group": &"camera", "pick": Vector2i(1, 1)},
		# the alley smoker props the rear door
		{"group": &"rear_door", "pick": Vector2i(1, 1),
			"force_if": [{"if": {&"guard_post": [&"alley_smoker"]}, "then": [&"rear_propped"]}]},
		{"group": &"open_window", "pick": Vector2i(1, 1)},
		{"group": &"side_gate", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
	]
	t.rare_events = [
		{"id": &"count_left_open", "chance": 0.03, "good": true, "effects": {"safe_open": true}},
		{"id": &"extra_product", "chance": 0.06, "good": true, "effects": {"extra_product": 2}},
		{"id": &"vip_party", "chance": 0.08, "good": false,
			"effects": {"vip_patrons": 6, "guard_extra": 1, "bottle_service_mult": 2}},
		{"id": &"off_duty_cop", "chance": 0.06, "good": false, "min_difficulty": Enums.Difficulty.HAZARDOUS,
			"effects": {"off_duty_cop": true}},
		{"id": &"co_op_pickup", "chance": 0.08, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"couriers": 2, "courier_time_s": 840.0}},
		{"id": &"rooftop_watch", "chance": 0.08, "good": false, "effects": {"perch_s3": true}},
	]
	t.scalars = [
		{"id": &"product_bags", "values": [3, 4, 5], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
		{"id": &"safe_bags", "values": [4, 5, 6], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		# patrons: Routine / Tense 12-14, Hazardous 16, Brutal 18, Lethal+ 20 (doc §Totals per difficulty)
		{"id": &"crowd", "values": [12, 14, 16, 18, 20], "weights": PackedFloat32Array([0.5, 0.5, 0.0, 0.0, 0.0]),
			"weights_by_difficulty": {
				Enums.Difficulty.HAZARDOUS: PackedFloat32Array([0.0, 0.0, 1.0, 0.0, 0.0]),
				Enums.Difficulty.BRUTAL: PackedFloat32Array([0.0, 0.0, 0.0, 1.0, 0.0]),
				Enums.Difficulty.LETHAL: PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 1.0]),
				Enums.Difficulty.CATACLYSM: PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 1.0]),
			}},
		# x 5 dancers: Routine / Tense 4, Hazardous / Brutal 5, Lethal+ 6 (doc §Totals per difficulty)
		{"id": &"dance_clusters", "values": [4, 5, 6], "weights": PackedFloat32Array([1.0, 0.0, 0.0]),
			"weights_by_difficulty": {
				Enums.Difficulty.HAZARDOUS: PackedFloat32Array([0.0, 1.0, 0.0]),
				Enums.Difficulty.BRUTAL: PackedFloat32Array([0.0, 1.0, 0.0]),
				Enums.Difficulty.LETHAL: PackedFloat32Array([0.0, 0.0, 1.0]),
				Enums.Difficulty.CATACLYSM: PackedFloat32Array([0.0, 0.0, 1.0]),
			}},
	]
	return t


## {difficulty: value} for every difficulty from `first` up (the resolver keys are exact).
static func _from(first: int, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	for dv: int in range(first, Enums.Difficulty.CATACLYSM + 1):
		out[dv] = value
	return out
