## Ostrander Federal generator data: the HeistDef / HeistVariantTable values (OF-C1). Owner: ENV C (the file); the VALUES
## are ENV B's (D-137 QB-2): everything below the extends line is B's block pasted VERBATIM from env/b-content b6d96a85
## game/content/docs/ostrander_federal_generator_block.txt (OF-B1). Never edit the values here: B sends a new block.
## Used by build_greybox.gd only.
extends RefCounted

## Ostrander Federal: HeistDef + HeistVariantTable values for ENV C's generator (D-137 QB-2: B owns the values, C pastes
## this verbatim into game/world/heists/ostrander_federal/greybox/ostrander_federal_resources.gd and regenerates).
## Format = shadow_ledger_resources.gd (make_def / make_variants / _from / _per_tier). Source: docs/design/heists/
## ostrander_federal.md (§Variable table, §Rare events, §Escape, §Pre-planning, §HeistDef) + D-120/D-137 payout, D-130
## population floors, D-136 rulings, D-117 §4/§5 briefing. ENV B, OF-B1.
##
## Notes for C (map) and A (mission):
## * Slot groups that ADD NPCs (a scalar cannot): `customers` (cust_4 / cust_6 / cust_8, nested like SL's cleaners_1/2/3:
##   each slot holds that many hall customers; pc_clients ride inside cust_6 = 1, cust_8 = 2), `officers` (off_1 / off_2 /
##   off_3), `guard_extra` (gx_hall, gx_basement + empty gx_none), `civ_extra` (cx_hall_1, cx_hall_2, cx_pc, cx_sd + empty
##   cx_none: late customers / a client in PC / one in SD). `vip` (vip_out empty, vip_in = VIP client + Halden bodyguard).
## * Scalars the MISSION reads (no NPCs): time_lock_s, drill_eta_s, escape_eta_s, cash_bags, gold_bags, deposit_boxes.
## * Rare-event effect keys are proposals for A's mission (OF-A6): time_lock_s (set), extra_bonds, timed_spawn_s,
##   perch_s3 + heli_eta_add_s. vip_client uses force_active (resolver-native).
## * D-140 (PO-15, revised 12:25) OF is a GUARDS map: the pager cap stays 4 (StealthTweak; no pager_max_by_difficulty),
##   guards rise from Tense. Guards = 2 fixed + guard_post rovers (2/3/4/4/4/4 of the 4 rover slots) + guard_extra
##   (0/0/0/0/1/2 of gx_hall / gx_basement, gx_none weight 0 so every pick is a real post) = 4 / 5 / 6 / 6 / 7 / 8 on
##   every seed. Routine is exactly 4: security_room_staffed forces sec_empty there (no operator). From Tense the
##   operator (sec_staffed 0.6 / Brutal+ 0.75) and the vip bodyguard come on top of the minimum.
## * D-130 civilians (L heist, D-137 kickoff: same shape as GN/SL, % targets are floors):
##   civilians = 4 tellers + 1 manager + 2 plaza + customers (5.6/6.0/6.4/6.8/6.8/6.8) + officers (1.8/2.0/2.0/2.2/2.2/2.2)
##           + civ_extra (0/0.4/1.0/1.4/2.4/3.4) = 14.4 / 15.4 / 16.4 / 17.4 / 18.4 / 19.4 (+0 / 7 / 14 / 21 / 28 / 35 %),
##           max 8 + 3 + 4 + 7 = 22 < the 30 cap. OF-C1 (LEAD, D-136 §3b.5): + the SD attendant (1, always), and
##           Cataclysm customers 7.5 + civ_extra exactly 3: 15.4 / 16.4 / 17.4 / 18.4 / 19.4 / 20.7, max 22 on every
##           tier. GX_NONE / CX_NONE are the empty slots' weights against the real slots
##           (weight 1 each), solved for those expectations (sequential draws without replacement). Pin the counts in
##           a test like game/tests/c/test_d130_population.gd.
##   No pager_max_by_difficulty (empty = StealthTweak 4; D-140 GUARDS lever) and camera_titan_min_difficulty -1
##   (Lethal): D-130 §2/§3 are the S-heist (GH) rules.

const OUT_DIR: String = "res://world/heists/ostrander_federal/"
const SCENE_PATH: String = OUT_DIR + "ostrander_federal.tscn"
const DEF_PATH: String = OUT_DIR + "ostrander_federal_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "ostrander_federal_variants.tres"
## D-140: extra guards (gx_hall / gx_basement) on Lethal (1) and Cataclysm (2), always real posts (gx_none weight 0);
## D-130: extra civilians (cx_*) from Tense; see the header.
const GUARD_EXTRA_ADD: Array[int] = [0, 0, 0, 0, 1, 2]
const GX_NONE: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const CIV_EXTRA_ADD: Array[int] = [0, 1, 1, 2, 3, 3]
const CX_NONE: Array[float] = [6.0, 6.0, 0.0, 2.0, 1.0, 0.0]


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"ostrander_federal"
	d.display_name = "Ostrander Federal"
	d.contact = &"contact.accountant"
	# D-117 §4: strings-table keys (ENV B), never literals.
	d.briefing = "heist.ostrander_federal.briefing"
	d.briefing_loud_key = &"heist.ostrander_federal.briefing_loud"
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD
	d.map_scene = SCENE_PATH
	d.base_payout = 80000  # D-137 (D-120 shape; the doc's $160k superseded)
	d.stealth_bonus_mult = 1.25  # S11.1 by heist size (proposed to the lead): S 1.10 / M 1.15 / L 1.25
	d.loot = [&"loot.cash_bricks", &"loot.gold", &"loot.bearer_bonds", &"loot.server_drives",
		&"loot.small_valuables"] as Array[StringName]  # small_valuables: deposit boxes / drawers, def-less (as ND, SL)
	# Objective ids = the design doc's Objectives `[tag]`s (stealth, then loud), doc §HeistDef order.
	d.objectives = [&"casing", &"keycard", &"code_hint", &"code_pc", &"server", &"vault_gate", &"lasers",
		&"time_lock", &"time_lock_wait", &"vault_loot", &"gold_cage", &"secure", &"deposit_boxes", &"bond_safe",
		&"president_safe", &"server_drives", &"drill_delivery", &"vault_drill", &"vault_breach", &"escape_wait",
		&"escape"] as Array[StringName]
	# D-117 §5: 6 rows, nothing cut, the win step (secure) and the escape visible. The two ui.briefing.step keys merge
	# code_pc | server and vault_gate + time_lock + time_lock_wait (strings on env/b-content 526f7edf).
	d.briefing_objectives = [&"casing", &"keycard", &"ui.briefing.step.ostrander_federal.code",
		&"ui.briefing.step.ostrander_federal.vault", &"secure", &"escape"]
	d.briefing_optional = [&"gold_cage", &"deposit_boxes", &"bond_safe", &"president_safe", &"server_drives"]
	# Pre-planning (contracts/preplanning.md, D-046 final). Doc §Pre-planning: favors 8 (size L). The four QC-66
	# assets are library defs on env/b-content 66afd539 (costs there); listed here so the board limits them to OF's
	# points. propped_door / inside_keycard take this map's points (their forced slot from the point params).
	d.preplanning = {
		"favors": 8,
		"disable": [],
		"assets": {
			&"asset.alternate_entry": {"point_categories": [&"spawn"],
				"point_ids": [&"pp_spawn_lane", &"pp_spawn_tannery"]},
			&"asset.body_bag_case_drop": {"point_ids": [&"pp_drop_lane", &"pp_drop_restroom", &"pp_drop_lockers"]},
			&"asset.ammo_bag_drop": {"point_ids": [&"pp_drop_lane", &"pp_drop_lockers", &"pp_drop_terrace"]},
			&"asset.doctor_bag_drop": {"point_ids": [&"pp_drop_lane", &"pp_drop_lockers", &"pp_drop_terrace"]},
			&"asset.escape_position": {"point_categories": [&"escape"], "force_variants": {}},
			&"asset.propped_door": {"point_ids": [&"pp_fire_exit", &"pp_dock_door"], "exclusive_group": &"side_door",
				"max_count": 1, "force_variants": {}},
			&"asset.inside_keycard": {"point_ids": [&"pp_vault_ops"], "cost": 2500, "favors": 2, "force_variants": {}},
			&"asset.thermal_drill_drop": {"point_ids": [&"pp_drill_terrace", &"pp_drill_dock"], "force_variants": {}},
			&"asset.fire_escape_ladder": {"point_ids": [&"pp_fire_escape"], "force_variants": {}},
			&"asset.intel_code_pc": {"reveals": [&"code_pc"]},
			&"asset.manager_schedule": {"reveals": [&"manager_route", &"keycard"]},
			&"asset.intel_cameras": {"reveals": [&"camera"]},
			&"asset.intel_guard_posts": {"reveals": [&"guard_post", &"guard_extra"]},
			&"asset.intel_keycards": {"reveals": [&"keycard"]},
			&"asset.extra_cable_ties": {},
			&"asset.spare_body_bags": {},
		},
	}
	d.escape_options = [&"van", &"heli"] as Array[StringName]
	d.music_track = &"ostrander_federal"
	return d


## Variable table (doc §Variable table), resolved in this order. Per-difficulty weights are exact-difficulty keys
## (Brutal, Lethal and Cataclysm listed one by one via _from).
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	# guard_post: 2 / 3 / 4 / 4 / 4 / 4 rovers (D-140 GUARDS; 4 rover slots).
	var rovers: Array[int] = [1, 2, 3, 3, 3, 3]
	var staffed: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"sec_staffed": 0.75, &"sec_empty": 0.25})
	staffed[Enums.Difficulty.ROUTINE] = {&"sec_staffed": 0.0, &"sec_empty": 1.0}  # D-140: Routine guards <= 4
	var lasers: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"lz_static": 0.2, &"lz_sweep": 0.4, &"lz_timed": 0.4})
	# D-130: customers 5.6 / 6.0 / 6.4 / 6.8 (Brutal+), officers 1.8 / 2.0 / 2.0 / 2.2 (Brutal+).
	var customers: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"cust_4": 0.1, &"cust_6": 0.4, &"cust_8": 0.5})
	customers[Enums.Difficulty.TENSE] = {&"cust_4": 0.3, &"cust_6": 0.4, &"cust_8": 0.3}
	customers[Enums.Difficulty.HAZARDOUS] = {&"cust_4": 0.2, &"cust_6": 0.4, &"cust_8": 0.4}
	# OF-C1 (LEAD: the D-136 §3b.5 SD attendant, +1 on every tier): Cataclysm 7.5 customers with exactly 3 of the 4
	# civ_extra slots, so its max stays 22 (QC-h) and its mean (20.7) stays >= 1.33 x Routine (15.4).
	customers[Enums.Difficulty.CATACLYSM] = {&"cust_4": 0.05, &"cust_6": 0.15, &"cust_8": 0.8}
	var officers: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"off_1": 0.2, &"off_2": 0.4, &"off_3": 0.4})
	officers[Enums.Difficulty.TENSE] = {&"off_1": 0.3, &"off_2": 0.4, &"off_3": 0.3}
	officers[Enums.Difficulty.HAZARDOUS] = {&"off_1": 0.3, &"off_2": 0.4, &"off_3": 0.3}
	t.rules = [
		# Manager route first: the keycard on him follows his route (mission: civ_manager_<route> carries the card).
		{"group": &"manager_route", "pick": Vector2i(1, 1)},
		{"group": &"keycard", "pick": Vector2i(1, 1)},
		{"group": &"code_pc", "pick": Vector2i(1, 1)},
		{"group": &"officers", "pick": Vector2i(1, 1), "weights_by_difficulty": officers},
		{"group": &"server_room", "pick": Vector2i(1, 1)},
		{"group": &"guard_post", "pick": Vector2i(1, 1), "difficulty_add": rovers},
		{"group": &"security_room_staffed", "pick": Vector2i(1, 1), "weights_by_difficulty": staffed},
		{"group": &"camera", "pick": Vector2i(1, 1)},
		{"group": &"laser_pattern", "pick": Vector2i(1, 1), "weights_by_difficulty": lasers},
		{"group": &"customers", "pick": Vector2i(1, 1), "weights_by_difficulty": customers},
		{"group": &"side_door", "pick": Vector2i(1, 1)},
		{"group": &"fire_escape", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
		{"group": &"drill_delivery", "pick": Vector2i(1, 1)},
		{"group": &"president_safe", "pick": Vector2i(1, 1)},
		# vip_client (rare) pins vip_in; vip_out (empty) is the slot's weight 1 otherwise (vip_in weight 0).
		{"group": &"vip", "pick": Vector2i(1, 1)},
		# D-130, last so the earlier groups keep their draws.
		{"group": &"guard_extra", "pick": Vector2i(0, 0), "difficulty_add": GUARD_EXTRA_ADD,
			"weights_by_difficulty": _per_tier(&"gx_none", GX_NONE)},
		{"group": &"civ_extra", "pick": Vector2i(0, 0), "difficulty_add": CIV_EXTRA_ADD,
			"weights_by_difficulty": _per_tier(&"cx_none", CX_NONE)},
	]
	t.rare_events = [
		{"id": &"time_lock_glitch", "chance": 0.04, "good": true, "effects": {"time_lock_s": 30.0}},
		{"id": &"bond_delivery", "chance": 0.05, "good": true, "effects": {"extra_bonds": 2}},
		{"id": &"vip_client", "chance": 0.06, "good": false,
			"effects": {"force_active": {"group": &"vip", "slot": &"vip_in"}}},
		{"id": &"armored_car_early", "chance": 0.08, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"timed_spawn_s": 900.0}},
		{"id": &"tower_sniper", "chance": 0.06, "good": false, "min_difficulty": Enums.Difficulty.HAZARDOUS,
			"effects": {"perch_s3": true, "heli_eta_add_s": 30.0}},
	]
	t.scalars = [
		{"id": &"time_lock_s", "values": [150.0, 210.0, 270.0], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.1, 0.4, 0.5]))},
		{"id": &"drill_eta_s", "values": [45.0, 60.0, 90.0], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
		{"id": &"escape_eta_s", "values": [90.0, 120.0, 150.0], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"cash_bags", "values": [6, 8, 10], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"gold_bags", "values": [2, 3, 4], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
		{"id": &"deposit_boxes", "values": [6, 9, 12], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
	]
	return t


## {difficulty: value} for every difficulty from `first` up (the resolver keys are exact).
static func _from(first: int, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	for dv: int in range(first, Enums.Difficulty.CATACLYSM + 1):
		out[dv] = value
	return out


## D-130: {Tense..Cataclysm: {slot: weights[d]}} (Routine keeps the slot's own weight).
static func _per_tier(slot: StringName, weights: Array[float]) -> Dictionary:
	var out: Dictionary = {}
	for dv: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
		out[dv] = {slot: weights[dv]}
	return out

## Slot weights C sets in the scene (VariantSlot.weight): manager_route mgr_floor 0.45 / mgr_gallery 0.3 / mgr_vault
## 0.25; keycard kc_on_manager 2 / kc_manager_desk 1 / kc_vault_ops 0.75 / kc_security 0.75; code_pc pc_ao1 1 / pc_ao2 1
## / pc_ao3 1 / pc_ops 0.75 / pc_vault_ops 1 / pc_exec 0.75; officers off_1 0.4 / off_2 0.4 / off_3 0.2; server_room
## srv_gallery 0.55 / srv_basement 0.45; guard_post rover_hall / rover_gallery / rover_basement / rover_dock 1 each;
## security_room_staffed sec_staffed 0.6 / sec_empty 0.4; camera cam_a / cam_b / cam_c 1; laser_pattern lz_static 0.5 /
## lz_sweep 0.2 / lz_timed 0.3; customers cust_4 0.4 / cust_6 0.4 / cust_8 0.2; side_door door_fire_propped 0.3 /
## door_dock_open 0.3 / door_none 0.4; fire_escape fe_down 0.45 / fe_up 0.55; escape esc_van_dock 0.45 / esc_van_tannery
## 0.3 / esc_heli_terrace 0.25; drill_delivery drop_terrace 0.5 / drop_dock 0.5; president_safe ps_bonds 0.5 / ps_empty
## 0.5; vip vip_out 1 / vip_in 0; guard_extra gx_hall 1 / gx_basement 1 / gx_none 0 (D-140: never picked);
## civ_extra cx_hall_1 / cx_hall_2 / cx_pc / cx_sd 1 each / cx_none 6.
