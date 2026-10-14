## Glasshouse generator helpers: HeistDef / HeistVariantTable data and output determinism.
## Owner: ENV C (C1-03). Used by build_greybox.gd only. Design: docs/design/heists/glasshouse.md
## (§Variable table, §Rare events, §HeistDef, §Pre-planning); contract: heist_map.md §5 (D-025).
extends RefCounted

const OUT_DIR: String = "res://world/heists/glasshouse/"
const SCENE_PATH: String = OUT_DIR + "glasshouse.tscn"
const DEF_PATH: String = OUT_DIR + "glasshouse_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "glasshouse_variants.tres"


# --- Resources --------------------------------------------------------------------------------

static func make_def() -> HeistDef:
	var d: HeistDef = null
	if ResourceLoader.exists(DEF_PATH):
		d = load(DEF_PATH) as HeistDef
	if d == null:
		d = HeistDef.new()
	d.id = &"glasshouse"
	d.display_name = "Glasshouse"
	d.contact = &"contact.vance"
	d.briefing = "Vossberg Jewelers, corner of Harlow Avenue and Pell Street. Thursday's consignment of " \
		+ "loose stones and estate pieces sits in the workshop safe overnight. Odile Vance has buyers. " \
		+ "Keycard or drill, two bags minimum, out by the van."
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD
	d.map_scene = SCENE_PATH
	d.base_payout = 40000
	d.stealth_bonus_mult = 1.15
	d.loot = [&"loot.jewelry", &"loot.cash"] as Array[StringName]
	d.objectives = [&"casing", &"keycard", &"workshop_door", &"safe", &"safe_loot", &"secure", &"escape"] \
		as Array[StringName]
	# Pre-planning (contracts/preplanning.md, D-046 reversal): {"favors", "disable",
	# "assets": {asset_id: overrides}}. Generic assets keep their library data; the two
	# heist-only assets force a variant slot from the chosen point's params.
	d.preplanning = {
		"favors": 4,
		"disable": [] as Array[StringName],
		"assets": {
			&"asset.body_bag_case_drop": {"point_categories": [&"drop_zone"]},
			&"asset.alternate_entry": {"point_categories": [&"spawn"]},
			&"asset.escape_position": {"point_categories": [&"escape"]},
			&"asset.inside_keycard": {"effect": "force_variant", "category": &"access",
				"point_categories": [&"insider"], "cost": 1500, "favors": 1, "tags": [&"stealth"]},
			&"asset.propped_door": {"effect": "force_variant", "category": &"access",
				"point_categories": [&"access"], "cost": 1000, "favors": 1, "tags": [&"stealth"]},
		},
	}
	d.escape_options = [&"van"] as Array[StringName]
	d.music_track = &"glasshouse"
	return d


static func make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = null
	if ResourceLoader.exists(VARIANTS_PATH):
		t = load(VARIANTS_PATH) as HeistVariantTable
	if t == null:
		t = HeistVariantTable.new()
	var brutal_plus: Array[int] = [0, 0, 0, 1, 1, 1]
	t.rules = [
		{"group": &"guard_post", "pick": Vector2i(1, 1), "difficulty_add": brutal_plus},
		{"group": &"back_door", "pick": Vector2i(1, 1), "excludes": {&"guard_post": [&"alley_smoker"]}},
		{"group": &"open_window", "pick": Vector2i(1, 1)},
		{"group": &"keycard", "pick": Vector2i(1, 1)},
		{"group": &"jeweler", "pick": Vector2i(1, 1), "excludes": {&"keycard": [&"kc_jeweler"]}},
		{"group": &"admin_clerk", "pick": Vector2i(1, 1)},
		{"group": &"salon", "pick": Vector2i(1, 1)},
		{"group": &"extra_loot", "pick": Vector2i(1, 1)},
		{"group": &"escape", "pick": Vector2i(1, 1)},
		{"group": &"customers", "pick": Vector2i(2, 4), "difficulty_add": brutal_plus},
		{"group": &"manager_present", "pick": Vector2i(1, 1)},
		{"group": &"safe_state", "pick": Vector2i(1, 1)},
		{"group": &"estate", "pick": Vector2i(1, 1)},
		{"group": &"camera", "pick": Vector2i(1, 3), "difficulty_add": [0, 0, 0, 1, 1, 2] as Array[int]},
		{"group": &"security_room_staffed", "pick": Vector2i(1, 1)},
		{"group": &"code_note", "pick": Vector2i(1, 1)},
	]
	t.rare_events = [
		{"id": &"safe_left_open", "chance": 0.03, "good": true,
			"effects": {"force_active": {"group": &"safe_state", "slot": &"safe_open"}}},
		{"id": &"estate_consignment", "chance": 0.06, "good": true,
			"effects": {"force_active": {"group": &"estate", "slot": &"estate_bag"}}},
		{"id": &"drill_relock", "chance": 0.10, "good": false, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"extra_device_jams": 1, "max_device_jams": 4}},
		{"id": &"nervous_manager", "chance": 0.05, "good": false,
			"effects": {"force_active": {"group": &"manager_present", "slot": &"mgr_in"}, "manager_alarm_direct": true}},
	]
	t.scalars = []
	return t


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
			ids["E|" + m.get_string(2)] = "%d_gh" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "gh_%d" % sub_n
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
