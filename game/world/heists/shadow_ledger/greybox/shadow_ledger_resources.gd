## Shadow Ledger generator helpers: HeistDef / HeistVariantTable data and output determinism.
## Owner: ENV C (C2). Used by build_greybox.gd only. Design: docs/design/heists/shadow_ledger.md
## (§Variable table, §Rare events, §HeistDef, §Pre-planning); contract: heist_map.md §5 (D-025),
## preplanning.md (D-038, D-046 final: nested "assets", crew-spawn category `spawn`).
extends RefCounted

const OUT_DIR: String = "res://world/heists/shadow_ledger/"
const SCENE_PATH: String = OUT_DIR + "shadow_ledger.tscn"
const DEF_PATH: String = OUT_DIR + "shadow_ledger_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "shadow_ledger_variants.tres"
## D-130 (population by difficulty, doc §roster "Totals per difficulty"): `late_staff` adds one seated member of staff
## (K4 assistant or K8 associate) from Tense up; LATE_NONE is the empty `ls_none` slot's weight per difficulty against
## 1 + 1, so P(one late worker) = 0 / 0.25 / 0.25 / 0.33 / 0.44 / 0.67 (Routine..Cataclysm). With the pre-D-130
## cleaners / Moor / contractor rows, expected civilians 2.26 / 2.50 / 3.04 / 3.63 / 3.74 / 3.96 (+0 / 11 / 34 / 60 /
## 65 / 75 %), each tier above the one below and above its pre-D-130 count. Guards keep their rows (2 / 2.5 / 3.5 /
## 4 / 5 / 5, already +150 % at Lethal). game/tests/c/test_d130_population.gd pins the counts.
const LATE_ADD: Array[int] = [0, 1, 1, 1, 1, 1]
const LATE_NONE: Array[float] = [6.0, 6.0, 6.0, 4.0, 2.5, 1.0]


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"shadow_ledger"
	d.display_name = "Shadow Ledger"
	d.contact = &"contact.accountant"
	# D-117 §4: a strings-table key (ENV B), never a literal.
	d.briefing = "heist.shadow_ledger.briefing"
	d.mode = Enums.HeistMode.STEALTH_ONLY
	d.map_scene = SCENE_PATH
	d.base_payout = 70000  # D-120
	d.stealth_bonus_mult = 1.15
	# D-140 (PO-15, revised; SL = PAGERS lever): 4 guards always; the pager cap falls from Tense (Routine..Cataclysm).
	d.pager_max_by_difficulty = [4, 3, 3, 2, 2, 1] as Array[int]
	d.loot = [&"loot.ledger_laptop", &"loot.ledger_drives", &"loot.ledger_books", &"loot.painting",
		&"loot.cash", &"loot.small_valuables"] as Array[StringName]  # small_valuables: the 7 def-less pieces (D-120)
	# Objective ids = the design doc's Objectives `[tag]`s (D-039 rule: ENV B reads them there).
	d.objectives = [&"casing", &"laptop", &"keycard", &"server_door", &"cage_code", &"cage", &"hack",
		&"drives", &"secure", &"study_safe", &"paintings", &"archive_safe", &"escape"] as Array[StringName]
	# D-109 (ENV B): briefing subset, loud line and optional objectives shown on the briefing screen.
	# B's strings audit (LEAD-approved, 2026-10-16): 6 rows (D-117 §5).
	d.briefing_objectives = [&"laptop", &"keycard", &"cage", &"hack", &"secure", &"escape"]
	d.briefing_optional = [&"study_safe", &"paintings", &"archive_safe"]
	# Pre-planning (contracts/preplanning.md, D-046 final): {"favors", "disable", "assets": {asset_id:
	# overrides}}. Doc §Pre-planning: favors 6, no loud drops. Location assets are limited to this map's
	# points; the gondola / riser assets take their forced slot from the chosen point's params
	# (`force_variants` empty, contract wording). New asset ids (QC-16) carry placeholder costs for B.
	d.preplanning = {
		"favors": 6,
		"disable": [&"asset.ammo_bag_drop", &"asset.doctor_bag_drop"],
		"assets": {
			&"asset.alternate_entry": {"point_categories": [&"spawn"], "point_ids": [&"pp_spawn_service"],
				"spawn_tag": &"preplan_spawn_service"},
			&"asset.body_bag_case_drop": {"point_categories": [&"drop_zone"]},
			&"asset.escape_position": {"point_categories": [&"escape"], "force_variants": {}},
			&"asset.gondola_left_hung": {"point_ids": [&"pp_gondola_west", &"pp_gondola_north"], "force_variants": {},
				"cost": 2500, "favors": 1, "max_count": 1, "tags": [&"stealth"]},
			&"asset.riser_panel": {"point_ids": [&"pp_riser_l41", &"pp_riser_l42"], "force_variants": {},
				"cost": 2000, "favors": 1, "max_count": 1, "tags": [&"stealth"]},
			&"asset.intel_cameras": {"reveals": [&"camera"]},
			&"asset.intel_guard_posts": {"reveals": [&"guard_post", &"guard_extra"]},
			&"asset.intel_keycards": {"reveals": [&"keycard"]},
			&"asset.intel_laptop": {"reveals": [&"laptop"], "cost": 1500, "favors": 1, "max_count": 1, "tags": [&"stealth"]},
			&"asset.spare_body_bags": {},
			&"asset.extra_cable_ties": {},
		},
	}
	d.escape_options = [&"heli", &"zipline", &"lift"] as Array[StringName]
	d.music_track = &"shadow_ledger"
	return d


## Variable table (doc §Variable table). Resolver A2-08 / A3-10: force_if, slot_requires, rare
## min_difficulty and per-difficulty slot / scalar weights (keys are exact difficulties, so Brutal,
## Lethal and Cataclysm are listed one by one). The doc's `cleaners` scalar is a slot group here
## (a scalar cannot add NPCs): cleaners_1/2/3 = 1/2/3 cleaners, same weights as the doc row.
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	var cleaners: Dictionary = _from(Enums.Difficulty.BRUTAL, {&"cleaners_1": 0.0, &"cleaners_2": 0.5, &"cleaners_3": 0.5})
	cleaners[Enums.Difficulty.HAZARDOUS] = {&"cleaners_1": 0.2, &"cleaners_2": 0.6, &"cleaners_3": 0.2}
	t.rules = [
		{"group": &"late_partner", "pick": Vector2i(1, 1)},
		# With Moor in, the laptop is on her desk (rule 1); otherwise weighted (rule 2).
		{"group": &"laptop", "pick": Vector2i(1, 1),
			"force_if": [{"if": {&"late_partner": [&"moor_late"]}, "then": [&"lap_moor"]}]},
		{"group": &"server_room", "pick": Vector2i(1, 1)},
		{"group": &"keycard", "pick": Vector2i(2, 2)},
		{"group": &"code_note", "pick": Vector2i(1, 1),
			"slot_requires": {&"code_contractor": {&"server_room": [&"srv_contractor"]}}},
		# D-140 (PO-15, revised; SL = PAGERS lever): exactly 4 guards on every seed and difficulty: the reception guard,
		# both rovers and one watch post (stair or roof; extra_none never). The pager cap does the scaling (make_def).
		{"group": &"guard_post", "pick": Vector2i(2, 2)},
		{"group": &"guard_extra", "pick": Vector2i(1, 1),
			"weights_by_difficulty": _from(Enums.Difficulty.ROUTINE, {&"extra_none": 0.0})},
		{"group": &"security_room_staffed", "pick": Vector2i(1, 1)},
		{"group": &"camera", "pick": Vector2i(1, 1)},
		{"group": &"laser_pattern", "pick": Vector2i(1, 1),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, {&"lz_static": 0.2, &"lz_sweep": 0.4, &"lz_timed": 0.4})},
		{"group": &"vent_open", "pick": Vector2i(1, 1)},
		{"group": &"gondola", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
		{"group": &"cleaners", "pick": Vector2i(1, 1), "weights_by_difficulty": cleaners},
		# kessler_sleepover (rare) pins kessler_in.
		{"group": &"kessler", "pick": Vector2i(1, 1)},
		# D-130: a seated late worker from Tense (K4 assistant / K8 associate; `ls_none` sets the odds). Last, so the
		# earlier groups keep their draws.
		{"group": &"late_staff", "pick": Vector2i(0, 0), "difficulty_add": LATE_ADD,
			"weights_by_difficulty": _per_tier(&"ls_none", LATE_NONE)},
	]
	t.rare_events = [
		{"id": &"ledger_printout", "chance": 0.06, "good": true, "effects": {"extra_books": 1}},
		# Doc: requires srv_contractor. Row-level `requires` (resolver A3-10) so the event never rolls otherwise;
		# `requires_slot` stays for the mission's own check.
		{"id": &"cage_left_open", "chance": 0.03, "good": true, "requires": {&"server_room": [&"srv_contractor"]},
			"effects": {"requires_slot": &"srv_contractor"}},
		{"id": &"kessler_sleepover", "chance": 0.05, "good": false,
			"effects": {"force_active": {"group": &"kessler", "slot": &"kessler_in"}}},
		{"id": &"timelock_extended", "chance": 0.10, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"time_lock_add_s": 60.0}},
	]
	t.scalars = [
		{"id": &"time_lock_s", "values": [90.0, 120.0], "weights": PackedFloat32Array([0.7, 0.3]),
			"weights_by_difficulty": _from(Enums.Difficulty.BRUTAL, PackedFloat32Array([0.3, 0.7]))},
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
			ids["E|" + m.get_string(2)] = "%d_sl" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "sl_%d" % sub_n
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
