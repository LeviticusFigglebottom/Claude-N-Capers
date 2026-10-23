## Pure data builder behind the briefing screen (pd2_fidelity C2). Owner: ENV B.
## Reads HeistRegistry's HeistDef when it exists, else the placeholder in briefing_ui.tres plus the
## HeistCatalog entry (payout, mode). Money goes through PayoutCalculator, so the numbers match the
## heist select preview and the payday screen exactly.
##
## build(heist_id, difficulty, def = <registry>, data = <briefing_ui.tres>) -> Dictionary:
##   { "heist_id": StringName, "placeholder": bool, "difficulty": int,
##     "name_key": StringName, "subtitle_key": StringName,
##     "contact": ContactDef or null,
##     "briefing_text": String,
##     "objectives": [{ "id": StringName, "key": StringName, "text": String }]   HeistDef order
##                                        (HeistDef.briefing_objectives when set, D-109)
##     "loud_text": String                HeistDef.briefing_loud_key's text ("" = no loud line)
##     "optional": [same as objectives]   HeistDef.briefing_optional
##     "loot": [{ "loot_id": StringName, "base": int, "value": int, "text": String }]
##                                        value = PayoutCalculator loot line (base x payout_mult)
##     "contract_pay": int,               HeistCatalog.contract_preview(base_payout, difficulty)
##     "mode": int (Enums.HeistMode), "mode_key": StringName,
##     "civilian_start": bool             HeistDef.start_mode == &"civilian" (S1.3, D-065: no gear until the pickup)
##     "escape_options": [{ "id": StringName, "text": String }],
##     "security": Array[Dictionary]     D-115 "Known security": BriefingIntel.lines(heist, difficulty, mode)
##                                        (map scan + variant table + StealthTweak; [] without intel data)
##     "voice_lines": Array[Dictionary]   lines.tres entries (event &"briefing", "heist" == id) for
##                                        the contact's speaker, then the handler's, by "order" }
class_name BriefingModel
extends RefCounted

const DATA_PATH: String = "res://content/ui/briefing/briefing_ui.tres"
const LINES_PATH: String = "res://content/data/voice/lines.tres"
const BRIEFING_EVENT: StringName = &"briefing"
const HANDLER_SPEAKER: StringName = &"mercer"

static var _unresolved_args: RegEx = null


static func ui_data() -> BriefingUiData:
	var d: BriefingUiData = null
	if ResourceLoader.exists(DATA_PATH):
		d = load(DATA_PATH) as BriefingUiData
	if d == null:
		Log.error(&"ui", "briefing data missing: %s" % DATA_PATH)
		d = BriefingUiData.new()
	return d


static func voice_table() -> VoiceLineTable:
	var t: VoiceLineTable = null
	if ResourceLoader.exists(LINES_PATH):
		t = load(LINES_PATH) as VoiceLineTable
	if t == null:
		Log.error(&"ui", "voice line table missing: %s" % LINES_PATH)
		t = VoiceLineTable.new()
	return t


static func build(heist_id: StringName, difficulty: int, def: HeistDef = null,
		data: BriefingUiData = null, use_registry: bool = true) -> Dictionary:
	var d: BriefingUiData = data if data != null else ui_data()
	var h: HeistDef = def
	if h == null and use_registry:
		h = HeistRegistry.get_def(heist_id)
	var ph: Dictionary = d.placeholder_heists.get(heist_id, {}) as Dictionary
	var entry: Dictionary = _catalog_entry(heist_id)
	var base_payout: int = h.base_payout if h != null else int(entry.get("base_payout", 0))
	var mode: int = int(h.mode) if h != null else int(entry.get("mode", Enums.HeistMode.STEALTH_OR_LOUD))
	var contact_id: StringName = h.contact if h != null else StringName(ph.get("contact", &""))
	var briefing_src: String = h.briefing if h != null else String(ph.get("briefing", ""))
	var objectives: Array = Array(h.objectives) if h != null else Array(ph.get("objectives", []))
	# D-109 (lead ruling): a def may name a short briefing list; the loud branch collapses to one line and
	# the optional extras go under their own sub-head. Empty briefing_objectives = every objective.
	if h != null and not h.briefing_objectives.is_empty():
		objectives = Array(h.briefing_objectives)
	var capped: Dictionary = cap_objectives(objectives, d.briefing_lead_steps)
	var loud_key: StringName = h.briefing_loud_key if h != null else &""
	var optional: Array = Array(h.briefing_optional) if h != null else []
	var loot: Array = Array(h.loot) if h != null else Array(ph.get("loot", []))
	var escapes: Array = Array(h.escape_options) if h != null else Array(ph.get("escape_options", []))
	var contact: ContactDef = _contact(contact_id, d)
	return {
		"heist_id": heist_id,
		"placeholder": h == null,
		"difficulty": difficulty,
		"name_key": StringName("heist.%s.name" % heist_id),
		"subtitle_key": StringName("heist.%s.subtitle" % heist_id),
		"contact": contact,
		"briefing_text": briefing_text(heist_id, briefing_src),
		"objectives": _numbered(objective_lines(heist_id, capped["shown"] as Array), capped["numbers"] as Array),
		"objectives_more": int(capped["more"]),
		"loud_text": UiText.t(loud_key) if loud_key != &"" and is_key(String(loud_key)) else "",
		"optional": objective_lines(heist_id, optional),
		"loot": loot_lines(loot, difficulty),
		"contract_pay": HeistCatalog.contract_preview(base_payout, difficulty),
		"mode": mode,
		"mode_key": HeistCatalog.mode_key(heist_id, mode),
		"civilian_start": h != null and h.start_mode == &"civilian",
		"escape_options": escape_lines(escapes),
		"security": BriefingIntel.lines(heist_id, difficulty, mode),
		"voice_lines": voice_lines(heist_id, contact),
	}


## D-117 §5: the first `lead` objectives plus the final one (keeping its real step number) when the list is longer
## than lead + 1. {shown: Array, numbers: Array[int] (1-based), more: int (steps left out)}. lead <= 0 = all.
static func cap_objectives(objectives: Array, lead: int) -> Dictionary:
	var n: int = objectives.size()
	var numbers: Array = range(1, n + 1)
	if lead <= 0 or n <= lead + 1:
		return {"shown": objectives.duplicate(), "numbers": numbers, "more": 0}
	var shown: Array = objectives.slice(0, lead)
	shown.append(objectives[n - 1])
	var nums: Array = numbers.slice(0, lead)
	nums.append(n)
	return {"shown": shown, "numbers": nums, "more": n - lead - 1}


static func _numbered(lines: Array, numbers: Array) -> Array:
	for i: int in range(mini(lines.size(), numbers.size())):
		if lines[i] is Dictionary:
			(lines[i] as Dictionary)["index"] = int(numbers[i])
	return lines


## HeistDef.briefing is literal text, or a strings.csv key (a translated key wins). Empty falls back
## to `heist.<id>.briefing`, then `heist.<id>.brief`.
static func briefing_text(heist_id: StringName, src: String) -> String:
	if src != "" and is_key(src):
		return UiText.t(StringName(src))
	if src != "":
		return src
	for k: String in ["heist.%s.briefing" % heist_id, "heist.%s.brief" % heist_id]:
		if is_key(k):
			return UiText.t(StringName(k))
	return ""


## Objective ids -> strings `objective.<heist>.<id>` (an id containing a dot is already a key).
## A missing key falls back to the id made readable ("drill_safe" -> "Drill safe"); counters such as
## "({count}/{total})" are stripped because nothing is counted before the heist.
static func objective_lines(heist_id: StringName, ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in ids:
		var oid: StringName = StringName(raw)
		var key: StringName = oid if String(oid).contains(".") else StringName("objective.%s.%s" % [heist_id, oid])
		var text: String = strip_counters(UiText.t(key)) if is_key(String(key)) else humanize(oid)
		out.append({"id": oid, "key": key, "text": text})
	return out


## One line per loot id with its unscaled LootDef value and the PayoutCalculator-scaled value. An id without a LootDef
## (small loot such as loot.small_valuables, QB-52; D-120 keeps it def-less so display cases pay
## LootTweak.display_case_default_value) still lists by its display string, `"small": true` and no value, when the
## string exists; otherwise it is skipped.
static func loot_lines(ids: Array, difficulty: int) -> Array[Dictionary]:
	var known: Array[LootDef] = []
	var probe_loot: Array = []
	var small: Array[Dictionary] = []
	for raw: Variant in ids:
		if not ContentDB.has(&"loot", StringName(raw)):
			var key: StringName = UiText.item_key(StringName(raw))
			if UiText.has(key):
				small.append({"loot_id": StringName(raw), "base": 0, "value": 0, "text": UiText.t(key), "small": true})
			continue
		var l: LootDef = ContentDB.loot(StringName(raw))
		if l == null:
			continue
		known.append(l)
		probe_loot.append({"loot_id": l.id, "value": l.value})
	var probe: Dictionary = {
		"success": true, "stealth": false, "difficulty": difficulty, "contract_pay": 0,
		"loot": probe_loot, "small_loot": 0, "crew": [],
	}
	var scaled: Array = PayoutCalculator.compute(probe)["loot_lines"] as Array
	var out: Array[Dictionary] = []
	for i: int in range(known.size()):
		var line: Dictionary = scaled[i] as Dictionary
		out.append({
			"loot_id": known[i].id, "base": int(line["base"]), "value": int(line["value"]),
			"text": UiText.t(UiText.item_key(known[i].id)),
		})
	out.append_array(small)
	return out


static func escape_lines(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in ids:
		var eid: StringName = StringName(raw)
		var key: String = "ui.briefing.escape.%s" % eid
		out.append({"id": eid, "text": UiText.t(StringName(key)) if is_key(key) else humanize(eid)})
	return out


## Briefing lines for `heist_id`: the contact's own lines, then the handler's (Mercer), each by
## "order". Lines whose text key is missing are dropped.
static func voice_lines(heist_id: StringName, contact: ContactDef, table: VoiceLineTable = null) -> Array[Dictionary]:
	var t: VoiceLineTable = table if table != null else voice_table()
	var out: Array[Dictionary] = []
	var speakers: Array[StringName] = []
	if contact != null and contact.voice_speaker != &"":
		speakers.append(contact.voice_speaker)
	if not speakers.has(HANDLER_SPEAKER):
		speakers.append(HANDLER_SPEAKER)
	for sp: StringName in speakers:
		var mine: Array[Dictionary] = []
		for l: Dictionary in t.lines_for(BRIEFING_EVENT, sp):
			if StringName(l.get("speaker", &"")) != sp or StringName(l.get("heist", &"")) != heist_id:
				continue
			if not is_key(String(l.get("text_key", ""))):
				continue
			mine.append(l)
		mine.sort_custom(_order_less)
		out.append_array(mine)
	return out


static func mode_key(mode: int) -> StringName:
	return HeistCatalog.mode_key(&"", mode)


## True when `key` resolves to text (translation or the strings.csv fallback).
static func is_key(key: String) -> bool:
	return key != "" and not key.contains(" ") and UiText.t(StringName(key)) != key


## "drill_safe" -> "Drill safe" (debug fallback for ids without a strings key).
static func humanize(id: StringName) -> String:
	var s: String = String(id).get_slice(".", String(id).get_slice_count(".") - 1).replace("_", " ")
	return s.substr(0, 1).to_upper() + s.substr(1)


## Removes "(...{arg}...)" groups and any remaining "{arg}" placeholders.
static func strip_counters(text: String) -> String:
	if _unresolved_args == null:
		_unresolved_args = RegEx.create_from_string("\\s*\\([^)]*\\{[a-z_]+\\}[^)]*\\)|\\{[a-z_]+\\}")
	return _unresolved_args.sub(text, "", true).strip_edges()


static func _contact(contact_id: StringName, d: BriefingUiData) -> ContactDef:
	if contact_id != &"" and ResourceLoader.exists(ContactDef.path_for(contact_id)):
		var c: ContactDef = ContactDef.find(contact_id)
		if c != null:
			return c
	elif contact_id != &"":
		Log.warn(&"ui", "briefing: unknown contact '%s'; using %s" % [contact_id, d.fallback_contact])
	return ContactDef.find(d.fallback_contact) if d.fallback_contact != &"" else null


static func _catalog_entry(heist_id: StringName) -> Dictionary:
	for e: Dictionary in HeistCatalog.entries():
		if StringName(e["id"]) == heist_id:
			return e
	return {}


static func _order_less(a: Dictionary, b: Dictionary) -> bool:
	var oa: int = int(a.get("order", 0))
	var ob: int = int(b.get("order", 0))
	if oa != ob:
		return oa < ob
	return ContentDB.id_less(a.get("id", &""), b.get("id", &""))
