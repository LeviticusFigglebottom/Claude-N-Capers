## Night Deposit generator helpers: HeistDef / HeistVariantTable data and output determinism.
## Owner: ENV C (C2). Used by build_greybox.gd only. Design: docs/design/heists/night_deposit.md
## (§Variable table, §Rare events, §HeistDef, §Pre-planning); contract: heist_map.md §5 (D-025).
extends RefCounted

const OUT_DIR: String = "res://world/heists/night_deposit/"
const SCENE_PATH: String = OUT_DIR + "night_deposit.tscn"
const DEF_PATH: String = OUT_DIR + "night_deposit_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "night_deposit_variants.tres"
## D-140 (PAGERS lever, doc §Civilian and guard roster): exactly 4 guards on every seed and difficulty (2 fixed
## posts + 1 rover + the operator or the sec_empty roundsman); the pager cap falls instead, PAGER_MAX by
## Enums.Difficulty (Routine 4). D-130 (civilians): CLEANER_ADD / CLEANER_NONE give expected civilians (night
## manager 0.5 + cleaners) 1.2 / 1.28 / 1.38 / 1.45 / 1.54 / 1.62 = +0 / 7 / 15 / 21 / 28 / 35 %, the second cleaner
## (the other floor's slot) from Lethal. Indexed by Enums.Difficulty; game/tests/c/test_d130_population.gd pins both.
const PAGER_MAX: Array[int] = [4, 3, 3, 2, 2, 1]
const CLEANER_ADD: Array[int] = [0, 0, 0, 0, 1, 1]
## cleaner_none weight by difficulty (Routine 0.3 is the slot's own weight).
const CLEANER_NONE: Array[float] = [0.3, 0.2, 0.1, 0.04, 2.0, 0.9]


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"night_deposit"
	d.display_name = "Nightfall Depository"  # D-117 §1 (id stays night_deposit)
	d.contact = &"contact.accountant"
	# D-117 §4: a strings-table key (ENV B), never a literal.
	d.briefing = "heist.night_deposit.briefing"
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD
	d.map_scene = SCENE_PATH
	d.base_payout = 26000  # D-120
	d.stealth_bonus_mult = 1.15
	d.pager_max_by_difficulty = PAGER_MAX.duplicate()  # D-140
	d.loot = [&"loot.cash", &"loot.cash_bricks", &"loot.small_valuables"] as Array[StringName]
	# Objective ids = the design doc's Objectives `[tag]`s (D-039 rule: ENV B reads them there).
	# The loud vault_drill is the other way into the vault, so it sits before vault_loot (doc: drill -> bag -> depository).
	d.objectives = [&"casing", &"keycard", &"code", &"server", &"vault_gate", &"time_lock",
		&"time_lock_wait", &"vault_drill", &"vault_loot", &"depository", &"secure", &"escape"] \
		as Array[StringName]
	# D-109 (ENV B): briefing subset, loud line and optional objectives shown on the briefing screen.
	d.briefing_objectives = [&"casing", &"keycard", &"code", &"server", &"vault_gate", &"time_lock", &"vault_loot", &"secure", &"escape"]
	d.briefing_loud_key = &"heist.night_deposit.briefing_loud"
	d.briefing_optional = [&"depository"]
	# Pre-planning (contracts/preplanning.md, D-046 final): {"favors", "disable",
	# "assets": {asset_id: overrides}}. Doc §Pre-planning: favors 4; generic drops/entry/escape
	# keep their library data; the insider points carry reveals and the vent. Costs of the
	# heist-only assets are placeholders for ENV B to tune.
	d.preplanning = {
		"favors": 4,
		"disable": [],
		"assets": {
			&"asset.body_bag_case_drop": {"point_categories": [&"drop_zone"]},
			&"asset.ammo_bag_drop": {"point_categories": [&"drop_zone"]},
			&"asset.alternate_entry": {"point_categories": [&"spawn"]},
			&"asset.escape_position": {"point_categories": [&"escape"]},
			&"asset.intel_keycards": {"point_categories": [&"insider"]},
			&"asset.intel_cameras": {"point_categories": [&"insider"]},
			&"asset.insider_code": {"reveals": [&"code_note"], "category": &"intel",
				"point_categories": [&"insider"], "cost": 1500, "favors": 1, "tags": [&"stealth"]},
			&"asset.vent_access": {"force_variants": {&"vent_open": [&"vent_open"]},
				"category": &"access", "point_categories": [&"insider"], "cost": 1000, "favors": 1, "tags": [&"stealth"]},
		},
	}
	d.escape_options = [&"van", &"boat"] as Array[StringName]
	d.music_track = &"night_deposit"
	return d


## Variable table (doc §Variable table, §Rare events). Per-difficulty weights (A2-08 / A3-10) apply
## from Brutal up (keys are exact difficulties, so Brutal / Lethal / Cataclysm are listed one by one;
## Routine to Hazardous keep the Routine weights), except the D-130 civilian rows (CLEANER_*).
## guard_post: D-140, exactly one of the three rovers on every seed and difficulty (no difficulty_add).
static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	t.rules = [
		{"group": &"guard_post", "pick": Vector2i(1, 1)},
		{"group": &"camera", "pick": Vector2i(1, 1)},
		{"group": &"security_room_staffed", "pick": Vector2i(1, 1),
			"weights_by_difficulty": _brutal_plus({&"sec_staffed": 0.75, &"sec_empty": 0.25})},
		{"group": &"night_manager", "pick": Vector2i(1, 1)},
		# The carried code needs the manager; pick 1 makes it exclude the written notes (doc row).
		{"group": &"code_note", "pick": Vector2i(1, 1),
			"slot_requires": {&"code_on_manager": {&"night_manager": [&"mgr_in"]}}},
		{"group": &"keycard", "pick": Vector2i(1, 1)},
		{"group": &"server_room", "pick": Vector2i(1, 1)},
		{"group": &"vent_open", "pick": Vector2i(1, 1)},
		{"group": &"laser_pattern", "pick": Vector2i(1, 1),
			"weights_by_difficulty": _brutal_plus({&"laser_static": 0.2, &"laser_sweep": 0.4, &"laser_timed": 0.4})},
		{"group": &"cleaner", "pick": Vector2i(1, 1), "difficulty_add": CLEANER_ADD,
			"weights_by_difficulty": _from_tense(&"cleaner_none", CLEANER_NONE)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
		{"group": &"extra_loot", "pick": Vector2i(1, 1)},
		# Never rolled: only the armored_car_early force_active pins the bay (last, so the other groups
		# keep their draws).
		{"group": &"armored_car", "pick": Vector2i(0, 0)},
	]
	t.rare_events = [
		{"id": &"time_lock_glitch", "chance": 0.04, "good": true, "effects": {"time_lock_s": 10.0}},
		{"id": &"armored_car_early", "chance": 0.08, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"at_s": 720.0, "extra_guards": 2,
				"force_active": {"group": &"armored_car", "slot": &"armored_car_bay"}}},
		{"id": &"fog_lifts", "chance": 0.10, "good": false, "effects": {"at_s": 480.0, "boat_delay_s": 60.0}},
		{"id": &"co_op_courier", "chance": 0.05, "good": true, "effects": {"depository_bags_add": 2}},
	]
	t.scalars = [
		{"id": &"time_lock_s", "values": [60.0, 90.0, 120.0], "weights": PackedFloat32Array([0.4, 0.4, 0.2]),
			"weights_by_difficulty": _brutal_plus(PackedFloat32Array([0.1, 0.4, 0.5]))},
		{"id": &"depository_bags", "values": [3, 4, 5], "weights": PackedFloat32Array([0.4, 0.4, 0.2])},
		{"id": &"deposit_boxes", "values": [4, 6, 8], "weights": PackedFloat32Array([1.0, 1.0, 1.0])},
	]
	return t


## D-130: {Tense..Cataclysm: {slot: weights[d]}} (Routine keeps the slot's own weight).
static func _from_tense(slot: StringName, weights: Array[float]) -> Dictionary:
	var out: Dictionary = {}
	for d: int in range(Enums.Difficulty.TENSE, Enums.Difficulty.CATACLYSM + 1):
		out[d] = {slot: weights[d]}
	return out


## {Brutal: v, Lethal: v, Cataclysm: v} (weights_by_difficulty keys are exact difficulties).
static func _brutal_plus(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	for d: int in [Enums.Difficulty.BRUTAL, Enums.Difficulty.LETHAL, Enums.Difficulty.CATACLYSM]:
		out[d] = v
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


## Drops property overrides that PackedScene.pack records inside nested imported models of an
## editable prop instance (`…/Model` subtrees: the editable flag is only there to override the
## prop's own Light), plus the sub-resources only they used, so a re-imported glb is never shadowed
## by a stale embedded mesh.
static func strip_nested_overrides(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var lines: PackedStringArray = f.get_as_text().split("\n")
	f.close()
	var out: PackedStringArray = PackedStringArray()
	var skipping: bool = false
	for line: String in lines:
		if line.begins_with("["):
			skipping = (line.begins_with("[node ") and line.contains("/Model\"")) \
				or (line.begins_with("[editable ") and line.contains("/Model\""))
			if line.begins_with("[editable ") and skipping:
				skipping = false
				continue
		if not skipping:
			out.append(line)
	# Blocks start at "[" lines; drop sub_resource blocks nothing references any more (repeat: a
	# removed mesh may have been the only user of its materials).
	var blocks: Array[String] = []
	var cur: PackedStringArray = PackedStringArray()
	for line2: String in out:
		if line2.begins_with("[") and not cur.is_empty():
			blocks.append("\n".join(cur))
			cur = PackedStringArray()
		cur.append(line2)
	blocks.append("\n".join(cur))
	var decl: RegEx = RegEx.create_from_string("^\\[sub_resource [^\\n]*id=\"([^\"]+)\"")
	var ref: RegEx = RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var removed: bool = true
	while removed:
		removed = false
		var used: Dictionary = {}
		for blk: String in blocks:
			for m: RegExMatch in ref.search_all(blk):
				used[m.get_string(1)] = true
		var kept: Array[String] = []
		for blk2: String in blocks:
			var d: RegExMatch = decl.search(blk2)
			if d != null and not used.has(d.get_string(1)):
				removed = true
				continue
			kept.append(blk2)
		blocks = kept
	var text: String = "\n".join(blocks)
	var w: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	w.store_string(text)
	w.close()


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
			ids["E|" + m.get_string(2)] = "%d_nd" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "nd_%d" % sub_n
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
