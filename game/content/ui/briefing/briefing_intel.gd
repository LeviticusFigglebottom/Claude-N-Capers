## Briefing "Known security" (D-115). Owner: ENV B.
## Two halves:
##  - scan(map_path) -> BriefingIntelData: a text scan of a heist map (.tscn): which security prefabs and
##    spawns it holds, outside any VariantSlot (fixed) and per VariantSlot. Tool/test only (exported games
##    ship binary scenes); intel_export.gd writes the result to res://content/data/briefing/intel/<heist>.tres.
##  - lines(...) -> Array[Dictionary]: the briefing lines for a difficulty, from that file, the heist's
##    HeistVariantTable (pick + difficulty_add + weights_by_difficulty, the scalars), StealthTweak (pager cap,
##    Titan cameras) and the HeistDef mode. Every number comes from that data; nothing is written by hand.
##
## Line: { "id": StringName, "key": StringName (strings.csv), "args": Dictionary, "text": String,
##         "min": int, "max": int (counts; 0 for flag lines) }. Order: LINE_ORDER.
##
## Counting (VariantResolver semantics): per slot group, a rule picks n in [pick.x, pick.y] + difficulty_add[d]
## slots (clamped to the slot count; 0 allowed when the rule has `requires`/`excludes`). Slots with weight 0
## at that difficulty are only taken once every weighted slot is. The range is the n_min smallest to the n_max
## largest slot counts. A group without a rule keeps every slot. Rare events and mission-scripted spawns
## (SpawnPoint tag &"scripted") are not counted: they are surprises, not intel.
class_name BriefingIntel
extends RefCounted

const DATA_DIR: String = "res://content/data/briefing/intel"
## Line key id -> strings.csv key (written out so the UI strings test can grep them).
const KEYS: Dictionary = {
	&"guards": &"ui.briefing.sec.guards", &"cartel": &"ui.briefing.sec.cartel",
	&"cameras": &"ui.briefing.sec.cameras", &"cameras_titan": &"ui.briefing.sec.cameras_titan",
	&"operator_always": &"ui.briefing.sec.operator_always", &"operator_maybe": &"ui.briefing.sec.operator_maybe",
	&"pagers": &"ui.briefing.sec.pagers", &"alarm_buttons": &"ui.briefing.sec.alarm_buttons",
	&"keycards": &"ui.briefing.sec.keycards", &"keypads": &"ui.briefing.sec.keypads",
	&"lasers": &"ui.briefing.sec.lasers", &"alarm_cases": &"ui.briefing.sec.alarm_cases",
	&"time_lock": &"ui.briefing.sec.time_lock", &"vault_doors": &"ui.briefing.sec.vault_doors",
	&"safes": &"ui.briefing.sec.safes", &"padlocks": &"ui.briefing.sec.padlocks",
	&"hack_terminals": &"ui.briefing.sec.hack_terminals",
}

const CATEGORIES: Array[StringName] = [
	&"camera", &"guard", &"cartel", &"operator", &"keycard_reader", &"keycard_door", &"keypad", &"code_door",
	&"code_safe", &"vault_door", &"safe", &"laser", &"padlock", &"alarm_button", &"alarm_case", &"hack_terminal",
]
## Line ids, in briefing order.
const LINE_ORDER: Array[StringName] = [
	&"guards", &"cartel", &"cameras", &"operator", &"pagers", &"alarm_buttons", &"keycards", &"keypads",
	&"lasers", &"alarm_cases", &"time_lock", &"vault_doors", &"safes", &"padlocks", &"hack_terminals",
]

## Line id -> the scan categories it sums (pagers and the time lock come from the tweak / variant scalars).
const LINE_CATEGORIES: Dictionary = {
	&"guards": [&"guard"], &"cartel": [&"cartel"], &"cameras": [&"camera"], &"operator": [&"operator"],
	&"alarm_buttons": [&"alarm_button"], &"keycards": [&"keycard_reader", &"keycard_door"],
	&"keypads": [&"keypad", &"code_door", &"code_safe"], &"lasers": [&"laser"], &"alarm_cases": [&"alarm_case"],
	&"vault_doors": [&"vault_door"], &"safes": [&"safe"], &"padlocks": [&"padlock"],
	&"hack_terminals": [&"hack_terminal"],
}
## Prefab scene / script path -> category (the scan matches on the path's file name).
const PREFAB_CATEGORY: Dictionary = {
	"security_camera": &"camera", "keycard_reader": &"keycard_reader", "keypad": &"keypad", "safe": &"safe",
	"laser_grid": &"laser", "padlock": &"padlock", "alarm_button": &"alarm_button", "hack_terminal": &"hack_terminal",
	"camera_station": &"camera_station",
}
## SpawnPoint.Kind values (contracts/map/spawn_point.gd); GUARD is the default, so the scene omits it.
## CameraStation.STAFFED_GROUP (a literal: the scan runs in --script tools without autoloads).
const STAFFED_GROUP: StringName = &"security_room_staffed"
const SPAWN_GUARD: int = 1
const SPAWN_CAMERA_OPERATOR: int = 5
const SCRIPTED_TAG: String = "scripted"
const CARTEL_TAG: String = "cartel"
## Door.Lock values (systems/prefabs/door/door.gd).
const DOOR_KEYCARD: int = 2
const DOOR_CODE: int = 3
const DOOR_VAULT: int = 6

static var _attr_re: RegEx = null
static var _ext_re: RegEx = null


# --- Lines (briefing) ---------------------------------------------------------------------------------

static func data_path(heist_id: StringName) -> String:
	return "%s/%s.tres" % [DATA_DIR, heist_id]


## The exported intel for `heist_id`, or null when there is none (heists without a map yet).
static func data_for(heist_id: StringName) -> BriefingIntelData:
	var p: String = data_path(heist_id)
	if heist_id == &"" or not ResourceLoader.exists(p):
		return null
	return load(p) as BriefingIntelData


## The briefing's "Known security" lines for `heist_id` at `difficulty` (see the header). `mode` is
## Enums.HeistMode (a loud-only heist shows no pagers). Empty when the heist has no exported intel.
static func lines(heist_id: StringName, difficulty: int, mode: int, data: BriefingIntelData = null,
		table: HeistVariantTable = null) -> Array[Dictionary]:
	var d: BriefingIntelData = data if data != null else data_for(heist_id)
	var out: Array[Dictionary] = []
	if d == null:
		return out
	var t: HeistVariantTable = table
	if t == null and d.variants_path != "" and ResourceLoader.exists(d.variants_path):
		t = load(d.variants_path) as HeistVariantTable
	var tw: StealthTweak = Tweak.stealth()
	var r: Dictionary = {}
	for id: Variant in LINE_CATEGORIES:
		r[id] = count_range(d, t, LINE_CATEGORIES[id] as Array, difficulty)
	var guards: Vector2i = r[&"guards"]
	var op: Vector2i = r[&"operator"]
	for id: StringName in LINE_ORDER:
		match id:
			&"cameras":
				var titan: bool = difficulty >= tw.camera_titan_min_difficulty
				_add_count(out, id, r[id], &"cameras_titan" if titan else &"cameras")
			&"operator":
				if op.y > 0:
					_add(out, id, &"operator_always" if op.x >= op.y else &"operator_maybe", {}, op)
			&"pagers":
				if mode != Enums.HeistMode.LOUD_ONLY and (guards.y > 0 or op.y > 0):
					var pagers: Vector2i = scalar_range(t, PagerSystem.MAX_ANSWERS_SCALAR, difficulty)
					if pagers.y < 0:
						pagers = Vector2i(tw.pager_max_answers, tw.pager_max_answers)
					_add(out, id, id, {"range": range_text(pagers)}, pagers)
			&"time_lock":
				var tl: Vector2i = time_lock_range(d, t, difficulty)
				if tl.y > 0:
					_add(out, id, id, {"range": range_text(tl)}, tl)
			_:
				_add_count(out, id, r[id])
	return out


## Vector2i(min, max) seconds of the heist's time lock: the `time_lock_s` variant scalar (values that can roll
## at `difficulty`), else the map's safe time locks; Vector2i(-1, -1) without one.
static func time_lock_range(d: BriefingIntelData, t: HeistVariantTable, difficulty: int) -> Vector2i:
	var tl: Vector2i = scalar_range(t, &"time_lock_s", difficulty)
	if tl.y < 0 and not d.time_locks_s.is_empty():
		tl = Vector2i(roundi(d.time_locks_s[0]), roundi(d.time_locks_s[d.time_locks_s.size() - 1]))
	return tl


## Vector2i(min, max) of the summed `categories` on the map at `difficulty` (see the header).
static func count_range(d: BriefingIntelData, table: HeistVariantTable, categories: Array,
		difficulty: int) -> Vector2i:
	var n: int = _sum_counts(d.fixed, categories)
	var out: Vector2i = Vector2i(n, n)
	var rules: Dictionary = {}
	if table != null:
		for rule: Dictionary in table.rules:
			rules[StringName(rule.get("group", &""))] = rule
	for g: Variant in d.groups:
		var slots: Dictionary = d.groups[g]
		var rule: Dictionary = rules.get(StringName(g), {}) as Dictionary
		var weighted: Array[int] = []
		var unweighted: Array[int] = []
		var w_over: Dictionary = slot_weights(rule, difficulty)
		var all_sum: int = 0
		for sid: Variant in slots:
			var s: Dictionary = slots[sid]
			var c: int = _sum_counts(s.get("counts", {}) as Dictionary, categories)
			all_sum += c
			var w: float = float(w_over.get(String(sid), s.get("weight", 1.0)))
			if w > 0.0:
				weighted.append(c)
			else:
				unweighted.append(c)
		if rule.is_empty():
			out += Vector2i(all_sum, all_sum)  # no rule: every slot stays active
			continue
		var picks: Vector2i = pick_range(rule, difficulty, slots.size())
		weighted.sort()
		unweighted.sort()
		out.x += _pick_sum(weighted, unweighted, picks.x, false)
		out.y += _pick_sum(weighted, unweighted, picks.y, true)
	return out


## Vector2i(n_min, n_max) slots a rule activates at `difficulty`, clamped to [0, slot_count].
static func pick_range(rule: Dictionary, difficulty: int, slot_count: int) -> Vector2i:
	var pick: Vector2i = rule.get("pick", Vector2i(1, 1))
	var add: int = 0
	var dadd: Array = rule.get("difficulty_add", [])
	if difficulty >= 0 and difficulty < dadd.size():
		add = int(dadd[difficulty])
	var lo: int = clampi(mini(pick.x, pick.y) + add, 0, slot_count)
	var hi: int = clampi(maxi(pick.x, pick.y) + add, 0, slot_count)
	if not (rule.get("requires", {}) as Dictionary).is_empty() or not (rule.get("excludes", {}) as Dictionary).is_empty():
		lo = 0  # the rule may pick nothing
	return Vector2i(lo, hi)


## A rule's weights_by_difficulty entry for `difficulty`: { String(slot_id): weight }.
static func slot_weights(rule: Dictionary, difficulty: int) -> Dictionary:
	var out: Dictionary = {}
	var by_diff: Variant = rule.get("weights_by_difficulty", {})
	if by_diff is Dictionary and (by_diff as Dictionary).has(difficulty):
		var e: Variant = (by_diff as Dictionary)[difficulty]
		if e is Dictionary:
			for k: Variant in e:
				out[String(k)] = float((e as Dictionary)[k])
	return out


## Vector2i(min, max) of a variant scalar's values that can roll at `difficulty` (weight > 0), rounded;
## Vector2i(-1, -1) when the table has no such scalar.
static func scalar_range(table: HeistVariantTable, id: StringName, difficulty: int) -> Vector2i:
	if table == null:
		return Vector2i(-1, -1)
	for sc: Dictionary in table.scalars:
		if StringName(sc.get("id", &"")) != id:
			continue
		var values: Array = sc.get("values", [])
		var weights: PackedFloat32Array = sc.get("weights", PackedFloat32Array())
		var by_diff: Variant = sc.get("weights_by_difficulty", {})
		if by_diff is Dictionary and (by_diff as Dictionary).has(difficulty):
			weights = (by_diff as Dictionary)[difficulty]
		var lo: int = 0
		var hi: int = -1
		for i: int in range(values.size()):
			if weights.size() == values.size() and weights[i] <= 0.0:
				continue
			var v: int = roundi(float(values[i]))
			lo = v if hi < 0 else mini(lo, v)
			hi = maxi(hi, v)
		return Vector2i(lo, hi) if hi >= 0 else Vector2i(-1, -1)
	return Vector2i(-1, -1)


## "3" or "2–4" (ui.briefing.sec.range).
static func range_text(r: Vector2i) -> String:
	if r.x == r.y:
		return str(r.x)
	return UiText.t(&"ui.briefing.sec.range", {"min": r.x, "max": r.y})


static func _sum_counts(counts: Dictionary, categories: Array) -> int:
	var n: int = 0
	for c: Variant in categories:
		n += int(counts.get(c, 0))
	return n


static func _pick_sum(weighted: Array[int], unweighted: Array[int], n: int, largest: bool) -> int:
	# VariantResolver takes weighted slots first; zero-weight slots only once those run out.
	var from_w: int = mini(n, weighted.size())
	var from_u: int = mini(n - from_w, unweighted.size())
	return _sum_end(weighted, from_w, largest) + _sum_end(unweighted, from_u, largest)


static func _sum_end(sorted: Array[int], k: int, largest: bool) -> int:
	var s: int = 0
	for i: int in range(k):
		s += sorted[sorted.size() - 1 - i] if largest else sorted[i]
	return s


static func _add_count(out: Array[Dictionary], id: StringName, r: Vector2i, key_id: StringName = &"") -> void:
	if r.y <= 0:
		return
	_add(out, id, key_id if key_id != &"" else id, {"range": range_text(r)}, r)


static func _add(out: Array[Dictionary], id: StringName, key_id: StringName, args: Dictionary, r: Vector2i) -> void:
	var key: StringName = KEYS[key_id]
	out.append({"id": id, "key": key, "args": args, "text": UiText.t(key, args), "min": r.x, "max": r.y})


# --- Scan (tool / test) -------------------------------------------------------------------------------

static func scan(heist_id: StringName, map_path: String) -> BriefingIntelData:
	var nodes: Array[Dictionary] = parse_scene(map_path)
	var out: BriefingIntelData = BriefingIntelData.new()
	out.heist_id = heist_id
	out.map_path = map_path
	if not nodes.is_empty():
		out.variants_path = String((nodes[0]["props"] as Dictionary).get("variant_table", ""))
	var slots: Dictionary = {}  # node path -> {group, id, weight, counts}
	for n: Dictionary in nodes:
		if String(n["script"]).ends_with("/variant_slot.gd"):
			var props: Dictionary = n["props"] as Dictionary
			slots[n["path"]] = {
				"group": StringName(_unquote(String(props.get("slot_group", "\"\"")))),
				"id": StringName(_unquote(String(props.get("slot_id", "\"\"")))),
				"weight": float(String(props.get("weight", "1.0"))), "counts": {},
			}
	var cats_at: Dictionary = {}  # node path -> Array[StringName]
	for n: Dictionary in nodes:
		var cats: Array[StringName] = categories_of(n)
		var props: Dictionary = n["props"] as Dictionary
		if slots.has(n["path"]) and props.has("prefab"):
			cats.append_array(categories_of({"instance": String(props["prefab"]), "script": "", "props": {}}))
		if not cats.is_empty():
			cats_at[n["path"]] = cats
	var fixed: Dictionary = {}
	var locks: Array[float] = []
	var has_station: bool = false
	var has_operator: bool = false
	for n: Dictionary in nodes:
		if not cats_at.has(n["path"]):
			continue
		var cats: Array[StringName] = cats_at[n["path"]]
		var props: Dictionary = n["props"] as Dictionary
		# A reader / keypad that opens a keycard / code door is that door's lock: count the lock once.
		for pair: Array in [[&"keycard_reader", &"keycard_door"], [&"keypad", &"code_door"]]:
			if cats.has(pair[0]) and _targets_have(String(n["path"]), String(props.get("targets", "")), cats_at, pair[1]):
				cats.erase(pair[0])
		has_station = has_station or cats.has(&"camera_station")
		has_operator = has_operator or cats.has(&"operator")
		cats.erase(&"camera_station")
		cats.erase(&"operator")
		var tl: float = float(String(props.get("time_lock_s", "0")))
		if tl > 0.0 and not locks.has(tl):
			locks.append(tl)
		var slot_path: String = _slot_ancestor(String(n["path"]), slots)
		var into: Dictionary = fixed if slot_path == "" else (slots[slot_path] as Dictionary)["counts"] as Dictionary
		for c: StringName in cats:
			into[c] = int(into.get(c, 0)) + 1
	# Camera operator (CameraStation): a CAMERA_OPERATOR spawn and a station; when the map has the
	# security_room_staffed group, its slots whose id does not end in "empty" staff the room.
	if has_station and has_operator:
		var staffed: bool = false
		for sp: Variant in slots:
			var s: Dictionary = slots[sp]
			if StringName(s["group"]) == STAFFED_GROUP:
				staffed = true
				if not String(s["id"]).ends_with("empty"):
					(s["counts"] as Dictionary)[&"operator"] = 1
		if not staffed:
			fixed[&"operator"] = 1
	out.fixed = fixed
	var groups: Dictionary = {}
	for sp: Variant in slots:
		var s: Dictionary = slots[sp]
		if not (s["counts"] as Dictionary).is_empty():
			groups[s["group"]] = {}
	for sp: Variant in slots:
		var s: Dictionary = slots[sp]
		if groups.has(s["group"]):
			(groups[s["group"]] as Dictionary)[s["id"]] = {"weight": s["weight"], "counts": s["counts"]}
	out.groups = groups
	locks.sort()
	out.time_locks_s = locks
	return out


## Security categories of one scanned node ({instance, script, props}).
static func categories_of(n: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var props: Dictionary = n.get("props", {}) as Dictionary
	var inst: String = String(n.get("instance", "")).get_file().get_basename()
	var script: String = String(n.get("script", "")).get_file().get_basename()
	var base: String = inst if inst != "" else script
	if PREFAB_CATEGORY.has(base):
		out.append(PREFAB_CATEGORY[base])
	match base:
		"spawn_point":
			var kind: int = int(String(props.get("kind", str(SPAWN_GUARD))))
			var tags: String = String(props.get("tags", ""))
			if kind == SPAWN_CAMERA_OPERATOR:
				out.append(&"operator")
			elif kind == SPAWN_GUARD and not tags.contains("&\"%s\"" % SCRIPTED_TAG):
				out.append(&"cartel" if tags.contains("&\"%s\"" % CARTEL_TAG) else &"guard")
		"door":
			match int(String(props.get("lock", "0"))):
				DOOR_KEYCARD:
					out.append(&"keycard_door")
				DOOR_CODE:
					out.append(&"code_door")
				DOOR_VAULT:
					out.append(&"vault_door")
		"safe":
			if String(props.get("methods", "")).contains("&\"code\""):
				out.append(&"code_safe")
		"display_case":
			if String(props.get("glass_breaks_alarm", "false")) == "true":
				out.append(&"alarm_case")
	return out


## [{ "path": String (from the root, "." = root), "instance": res path or "", "script": res path or "",
##    "props": { name: raw value text (first line) } }] for every [node] of a text scene.
static func parse_scene(path: String) -> Array[Dictionary]:
	_compile()
	var out: Array[Dictionary] = []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var ext: Dictionary = {}
	var cur: Dictionary = {}
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("["):
			cur = {}
			if line.begins_with("[ext_resource"):
				var m: RegExMatch = _ext_re.search(line)
				if m != null:
					ext[m.get_string(2)] = m.get_string(1)
			elif line.begins_with("[node "):
				cur = _node_header(line, ext)
				out.append(cur)
			continue
		if cur.is_empty():
			continue
		var eq: int = line.find(" = ")
		if eq <= 0 or line.begins_with(" ") or line.begins_with("\t") or line.begins_with("\""):
			continue
		var key: String = line.substr(0, eq)
		var val: String = line.substr(eq + 3)
		if key == "script":
			cur["script"] = _ext_path(val, ext)
		elif val.begins_with("ExtResource("):
			(cur["props"] as Dictionary)[key] = _ext_path(val, ext)
		else:
			(cur["props"] as Dictionary)[key] = val
	return out


static func _node_header(line: String, ext: Dictionary) -> Dictionary:
	var attrs: Dictionary = {}
	for m: RegExMatch in _attr_re.search_all(line):
		attrs[m.get_string(1)] = m.get_string(2) if m.get_string(2) != "" else m.get_string(3)
	var name: String = String(attrs.get("name", ""))
	var path: String = "."
	if attrs.has("parent"):
		var parent: String = String(attrs["parent"])
		path = name if parent == "." else "%s/%s" % [parent, name]
	var inst: String = ""
	if attrs.has("instance"):
		inst = _ext_path(String(attrs["instance"]), ext)
	return {"path": path, "instance": inst, "script": "", "props": {}}


static func _ext_path(val: String, ext: Dictionary) -> String:
	var a: int = val.find("ExtResource(\"")
	if a < 0:
		return ""
	var b: int = val.find("\"", a + 13)
	return String(ext.get(val.substr(a + 13, b - a - 13), ""))


## True when one of a node's `targets` (raw `Array[NodePath]([NodePath("../X")])` text, relative to the node)
## is a scanned node of `category`.
static func _targets_have(path: String, raw: String, cats_at: Dictionary, category: StringName) -> bool:
	var parts: PackedStringArray = raw.split("NodePath(\"")
	for i: int in range(1, parts.size()):
		var rel: String = parts[i].get_slice("\"", 0)
		var base: PackedStringArray = path.split("/") if path != "." else PackedStringArray()
		for seg: String in rel.split("/"):
			if seg == "..":
				if not base.is_empty():
					base.remove_at(base.size() - 1)
			elif seg != "." and seg != "":
				base.append(seg)
		var target: String = "/".join(base) if not base.is_empty() else "."
		if cats_at.has(target) and (cats_at[target] as Array).has(category):
			return true
	return false


static func _slot_ancestor(path: String, slots: Dictionary) -> String:
	var p: String = path
	while p.contains("/"):
		p = p.get_base_dir()
		if slots.has(p):
			return p
	return ""


static func _unquote(v: String) -> String:
	return v.trim_prefix("&").trim_prefix("\"").trim_suffix("\"")


static func _compile() -> void:
	if _attr_re != null:
		return
	_attr_re = RegEx.create_from_string("(\\w+)=(?:\"([^\"]*)\"|(ExtResource\\(\"[^\"]*\"\\)))")
	_ext_re = RegEx.create_from_string("path=\"([^\"]+)\".*id=\"([^\"]+)\"")
