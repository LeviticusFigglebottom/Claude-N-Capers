## Dockside Burn generator helpers: HeistDef / HeistVariantTable data and output determinism.
## Owner: ENV C (C3). Used by build_greybox.gd only. Design: docs/design/heists/dockside_burn.md
## (§Variable table, §Rare events, §HeistDef, §Pre-planning; APPROVED D-064); contracts: heist_map.md §5
## (D-025), preplanning.md (D-038, D-046 final: nested "assets", crew-spawn category `spawn`).
extends RefCounted

const OUT_DIR: String = "res://world/heists/dockside_burn/"
const SCENE_PATH: String = OUT_DIR + "dockside_burn.tscn"
const DEF_PATH: String = OUT_DIR + "dockside_burn_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "dockside_burn_variants.tres"


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"dockside_burn"
	d.display_name = "Dockside Burn"
	d.contact = &"contact.reyes"
	# String key (ENV B B5-04: the briefing text lives in the strings table).
	d.briefing = "heist.dockside_burn.briefing"
	d.mode = Enums.HeistMode.LOUD_ONLY
	d.map_scene = SCENE_PATH
	# D-064 (Q7): $95k base and the loot values are placeholders; ENV B balances them in P6.
	d.base_payout = 24000  # D-120
	d.stealth_bonus_mult = 1.0
	# QC-39 (shipped, ENV B): loot.weapon_crate (HEAVY, $2,000) and loot.contraband (MEDIUM, $1,400) are LootDefs in
	# content/data/loot/ (the thermite bag is a tool bag, not payout loot).
	d.loot = [&"loot.cash_bricks", &"loot.weapon_crate", &"loot.contraband"] as Array[StringName]
	# Objective ids = the design doc's Objectives `[tag]`s (D-039 rule: ENV B reads them there).
	d.objectives = [&"cartel", &"breach", &"product", &"burn", &"strongroom", &"count_cage", &"containers",
		&"secure", &"escape_wait", &"escape"] as Array[StringName]
	# D-109 (ENV B): briefing subset, loud line and optional objectives shown on the briefing screen.
	# B's DB audit: the cash rolls strongroom / count-room cage (60/40), so the briefing names both (B's step key).
	d.briefing_objectives = [&"cartel", &"breach", &"product", &"burn", &"ui.briefing.step.dockside_burn.cash", &"secure",
		&"escape_wait", &"escape"]
	d.briefing_optional = [&"containers"]
	# Pre-planning (contracts/preplanning.md, D-046 final): {"favors", "disable", "assets": {asset_id:
	# overrides}}. Doc §Pre-planning (ENV B B5-04 values): favors 5; the library drops are limited to this
	# map's points; the alternate entries (lane, pontoon) and the escape vote use their points' params.
	# Heist-only assets (QC-40; ENV B ships their PreplanAssetDefs and strings): costs are Routine prices
	# (placeholders for B to tune). No `category` on the two loud assets (not a UI category; B decides).
	var drops: Array[StringName] = [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay", &"pp_drop_platform"]
	d.preplanning = {
		"favors": 5,
		"disable": [&"asset.body_bag_case_drop", &"asset.spare_body_bags", &"asset.intel_cameras", &"asset.intel_keycards"],
		"assets": {
			&"asset.ammo_bag_drop": {"point_ids": drops.duplicate()},
			&"asset.doctor_bag_drop": {"point_ids": drops.duplicate()},
			&"asset.alternate_entry": {"point_categories": [&"spawn"], "point_ids": [&"pp_spawn_lane", &"pp_spawn_pontoon"]},
			&"asset.escape_position": {"point_categories": [&"escape"]},
			&"asset.intel_guard_posts": {"reveals": [&"guard_post"]},
			&"asset.extra_cable_ties": {},
			&"asset.sniper_position": {"effect": &"force_variant", "drop": &"ammo_bag",
				"point_ids": [&"pp_perch_roof", &"pp_perch_stack"], "exclusive_group": &"player_perch", "max_count": 1,
				"cost": 2000, "favors": 2, "tags": [&"loud"]},
			&"asset.thermite_drop": {"drop": &"loot.thermite", "point_ids": [&"pp_drop_gatehouse", &"pp_drop_lane", &"pp_drop_quay"],
				"max_count": 1, "cost": 1500, "favors": 1, "tags": [&"loud"]},
			&"asset.gangway_raised": {"effect": &"force_variant", "point_ids": [&"pp_gangway"], "max_count": 1,
				"cost": 2500, "favors": 2, "category": &"access"},
			&"asset.intel_containers": {"reveals": [&"weapons_containers"], "cost": 1500, "favors": 1, "category": &"intel"},
			&"asset.lift_power": {"force_variants": {&"goods_lift": [&"lift_powered"]}, "cost": 1000, "favors": 1,
				"category": &"access"},
		},
	}
	d.escape_options = [&"van", &"boat"] as Array[StringName]
	d.music_track = &"dockside_burn"
	return d


## Variable table (doc §Variable table, §Rare events). Resolver A2-08 / A3-10: force_if, rare
## min_difficulty and per-difficulty slot / scalar weights (keys are exact difficulties). Deviations
## (G1 report): `night_shift` is a slot group (a scalar cannot add NPCs; Shadow Ledger's cleaners
## precedent); the S3 / S4 rare perches are carrier groups pinned by their rare events (pick 0);
## `extra_container_pick` (rolled, used only with `extra_container`) chooses the third weapons
## container among the four others, so the resolver stays the only code that rolls (D-006).
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	# Cartel posts: 3 (Routine / Tense), 4 (Hazardous / Brutal), 5 (Lethal), 6 (Cataclysm).
	var posts_add: Array[int] = [0, 0, 1, 1, 2, 3]
	t.rules = [
		{"group": &"guard_post", "pick": Vector2i(3, 3), "difficulty_add": posts_add},
		{"group": &"cash_location", "pick": Vector2i(1, 1)},
		{"group": &"weapons_containers", "pick": Vector2i(2, 2)},
		{"group": &"product_location", "pick": Vector2i(1, 1)},
		{"group": &"warehouse_entry", "pick": Vector2i(1, 1)},
		{"group": &"east_gangway", "pick": Vector2i(1, 1)},
		# With the cash in the strongroom the lift does not matter: always powered.
		{"group": &"goods_lift", "pick": Vector2i(1, 1),
			"force_if": [{"if": {&"cash_location": [&"cash_strongroom"]}, "then": [&"lift_powered"]}]},
		{"group": &"player_perch", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
		{"group": &"night_shift", "pick": Vector2i(1, 1)},
		# Never rolled: only the rare events' force_active pins the perches (S3 fog_lifts, S4 harbor_unit).
		{"group": &"perch_viaduct", "pick": Vector2i(0, 0)},
		{"group": &"perch_trawler", "pick": Vector2i(0, 0)},
	]
	t.rare_events = [
		{"id": &"informant_tip", "chance": 0.06, "good": true, "effects": {"reveal_groups": [&"weapons_containers"]}},
		{"id": &"extra_container", "chance": 0.05, "good": true, "effects": {"weapons_containers_add": 1}},
		{"id": &"police_tipped", "chance": 0.06, "good": false, "effects": {"police_delay_s": 0.0}},
		{"id": &"cartel_reinforcements", "chance": 0.08, "good": false, "min_difficulty": Enums.Difficulty.HAZARDOUS,
			"effects": {"at_s": 180.0, "gunmen": 4}},
		{"id": &"fog_lifts", "chance": 0.10, "good": false,
			"effects": {"at_s": 360.0, "boat_delay_s": 30.0, "force_active": {"group": &"perch_viaduct", "slot": &"viaduct_on"}}},
		{"id": &"harbor_unit", "chance": 0.06, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"force_active": {"group": &"perch_trawler", "slot": &"trawler_on"}}},
	]
	var delay_w: Dictionary = {
		Enums.Difficulty.TENSE: PackedFloat32Array([0.2, 0.4, 0.4]),
		Enums.Difficulty.HAZARDOUS: PackedFloat32Array([0.3, 0.5, 0.2]),
		Enums.Difficulty.BRUTAL: PackedFloat32Array([0.5, 0.4, 0.1]),
		Enums.Difficulty.LETHAL: PackedFloat32Array([0.7, 0.3, 0.0]),
		Enums.Difficulty.CATACLYSM: PackedFloat32Array([1.0, 0.0, 0.0]),
	}
	t.scalars = [
		{"id": &"police_delay_s", "values": [60.0, 90.0, 120.0], "weights": PackedFloat32Array([0.1, 0.3, 0.6]),
			"weights_by_difficulty": delay_w},
		{"id": &"cash_bags", "values": [4, 6, 8], "weights": PackedFloat32Array([0.3, 0.5, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"product_bags", "values": [4, 6, 8], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
		{"id": &"escape_eta_s", "values": [90.0, 120.0, 150.0], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.2, 0.4, 0.4]))},
		{"id": &"extra_container_pick", "values": [0, 1, 2, 3], "weights": PackedFloat32Array([1.0, 1.0, 1.0, 1.0])},
	]
	return t


## {difficulty: value} for every difficulty from `first` up (the resolver keys are exact).
static func _from(first: int, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	for dv: int in range(first, Enums.Difficulty.CATACLYSM + 1):
		out[dv] = value
	return out


# --- Determinism --------------------------------------------------------------------------------

static func read_uid(path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return ""
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var first: String = f.get_line()
	f.close()
	var rx: RegEx = RegEx.create_from_string("uid=\"(uid://[a-z0-9]+)\"")
	var m: RegExMatch = rx.search(first)
	return m.get_string(1) if m != null else ""


## Rewrites the random parts of a saved .tscn (ext/sub resource ids, node unique_ids) as
## sequential values so reruns are byte-identical, and keeps the scene's previous uid.
static func normalize_scene(path: String, old_uid: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var ids: Dictionary = {}
	var ext_n: int = 0
	var sub_n: int = 0
	var decl: RegEx = RegEx.create_from_string("^\\[(ext_resource|sub_resource) [^\\n]*id=\"([^\"]+)\"")
	for line: String in text.split("\n"):
		var m: RegExMatch = decl.search(line)
		if m == null:
			continue
		if m.get_string(1) == "ext_resource":
			ext_n += 1
			ids["E|" + m.get_string(2)] = "%d_db" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "db_%d" % sub_n
	var out: PackedStringArray = PackedStringArray()
	var ref_ext: RegEx = RegEx.create_from_string("ExtResource\\(\"([^\"]+)\"\\)")
	var ref_sub: RegEx = RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var uid_rx: RegEx = RegEx.create_from_string(" unique_id=[0-9]+")
	var node_n: int = 0
	for line2: String in text.split("\n"):
		var l: String = line2
		var m2: RegExMatch = decl.search(l)
		if m2 != null:
			var key: String = ("E|" if m2.get_string(1) == "ext_resource" else "S|") + m2.get_string(2)
			l = l.replace("id=\"%s\"" % m2.get_string(2), "id=\"%s\"" % ids[key])
		l = replace_refs(l, ref_ext, ids, "E|", "ExtResource")
		l = replace_refs(l, ref_sub, ids, "S|", "SubResource")
		if l.begins_with("[node ") and uid_rx.search(l) != null:
			node_n += 1
			l = uid_rx.sub(l, " unique_id=%d" % (100000 + node_n))
		if l.begins_with("[gd_scene") and old_uid != "":
			var hdr: RegEx = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"")
			l = hdr.sub(l, "uid=\"%s\"" % old_uid)
		out.append(l)
	var w: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	w.store_string("\n".join(out))
	w.close()


static func replace_refs(line: String, rx: RegEx, ids: Dictionary, prefix: String, fn: String) -> String:
	var out: String = ""
	var last: int = 0
	for m: RegExMatch in rx.search_all(line):
		var key: String = prefix + m.get_string(1)
		var rep: String = "%s(\"%s\")" % [fn, ids[key]] if ids.has(key) else m.get_string(0)
		out += line.substr(last, m.get_start() - last) + rep
		last = m.get_end()
	return out + line.substr(last)
