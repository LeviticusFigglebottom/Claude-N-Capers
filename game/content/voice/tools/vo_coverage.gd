## VO coverage audit (D-117 §6 "every VO line is said"). Owner: ENV B. Text scans only (no scene instancing).
##
## Inventory: every line of the VoiceLineTable (content/data/voice/lines.tres) plus the `voice.vo.*` keys of
## strings.csv. Trigger sites, from the game code and data under res://{world,systems,content,core}
## (.gd / .tres / .tscn, comments stripped; tests and this tool are not triggers):
##   * literal ids: any quoted "vo.<speaker>.<x>" (say(&"vo..."), consts, tweak exports, dict values);
##   * format builders: a quoted id with %s / %d (StringName("vo.crew.ack_%s" % order)); each placeholder
##     matches one identifier, so the builder covers every table id of that shape;
##   * builder ContactRadio (B7-03): for every heist (each *_def.tres HeistDef found, dev_sandbox included) the
##     radio speaker is ContactRadio.contact_for(); the facts it can get come from the HeistDef (loot, mode) and
##     the heist's <id>_mission.gd objective calls (add_objective / _add states, complete / _complete_once /
##     _skip_if_active / require_items / require_loot, activate, fail, activate_escape). A heist line is said
##     when its event, objective and loot match a fact; a generic line when some fact has no always-ready heist
##     line (empty pool, or every heist line has a cooldown);
##   * builder BriefingModel.voice_lines (B2-02): the briefing lines of every heist and its contact.
## A literal / builder site inside a .gd function counts only when that function can run (LEAD r306, AH gear_line: a
## builder in a function nothing called looked said): its name is referenced anywhere in the scanned code besides its
## own `func` line (a call, a connect(), a call(&"name") string, an override the base calls), or it is an engine
## virtual (ENGINE_VIRTUALS). Class-level sites (consts, vars) and .tres / .tscn sites always count. Tests are not
## scanned, so a function only tests call is dead.
## Owner of a line's trigger: briefing / radio.* lines = B; mission lines of a heist = C; everything else
## (barks, order acks, pager / abort / cuff lines, the dev sandbox) = A. A radio line keyed to a real objective
## (HeistDef lists or the mission) that the mission never moves is C's (the fact is missing). An unsaid generic
## radio line is R (B's reserve, see OWNER_NAMES).
##
## Run: godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd
## (writes content/docs/vo_coverage.md; exit 1 when an id code can say is missing from the table).
## Test: tests/b/test_vo_coverage.gd calls audit() (preloads this script; no class_name, so no import needed).
extends RefCounted

const LINES_PATH: String = "res://content/data/voice/lines.tres"
const REPORT_PATH: String = "res://content/docs/vo_coverage.md"
const SELF_PATHS: Array[String] = [
	"res://content/voice/tools/vo_coverage.gd", "res://content/voice/tools/vo_coverage_cli.gd",
]
## Top folders scanned for trigger sites (res://<dir>).
const SCAN_DIRS: Array[String] = ["world", "systems", "content", "core"]
const SCAN_EXT: Array[String] = ["gd", "tres", "tscn"]
## Godot callbacks the engine calls with no reference in code (the reachability rule above).
const ENGINE_VIRTUALS: Array[String] = ["_ready", "_process", "_physics_process", "_init", "_enter_tree", "_exit_tree",
	"_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input", "_gui_input", "_notification", "_draw",
	"_initialize", "_finalize", "_to_string", "_get", "_set", "_get_property_list", "_validate_property", "_run",
	"_integrate_forces", "_can_drop_data", "_drop_data", "_get_drag_data", "_make_custom_tooltip", "_has_point"]
## Heists grouped in the report (the shipping five); every other id is "shared".
const REPORT_HEISTS: Array[StringName] = [
	&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night", &"rolling_thunder", &"afterhours",
]
const SHARED: StringName = &"shared"
## Owner codes. R = B's generic radio reserve: a contact's generic radio line that the current heists never reach
## (their heist lines cover every fact), kept for speaker_overrides and new heists (content/docs/radio.md).
const OWNER_NAMES: Dictionary = {"A": "A", "B": "B", "R": "B reserve", "C": "C", "S": "staged heist"}
const UNSAID: String = "UNSAID"
const EV_DONE: StringName = &"radio.objective_done"
const EV_NEW: StringName = &"radio.objective_new"
const EV_FAILED: StringName = &"radio.objective_failed"
const EV_ALARM: StringName = &"radio.alarm"
const EV_ESCAPE_AVAILABLE: StringName = &"radio.escape_available"
const EV_ESCAPE: StringName = &"radio.escape"
const EV_LOOT: StringName = &"radio.loot_secured"
const EV_BRIEFING: StringName = &"briefing"
const EV_MISSION: StringName = &"mission"
## `%s` / `%d` may stand in the speaker or the line segment (BarkTweak: one `vo.%s.<event>_%d` pattern per bark).
const RX_ID: String = "[\"'](vo\\.[A-Za-z0-9_%]+\\.[A-Za-z0-9_%]+)[\"']"
const RX_ADD: String = "\\b(?:add_objective|_add)\\(\\s*&\"(\\w+)\""
const RX_DONE: String = "\\b(?:complete|_complete_once|_skip_if_active|require_items|require_loot)\\(\\s*&\"(\\w+)\""
const RX_NEW: String = "\\bactivate\\(\\s*&\"(\\w+)\""
const RX_FAIL: String = "\\bfail\\(\\s*&\"(\\w+)\""
const RX_STATE: String = "ObjectiveState\\.(\\w+)"
## HeistRuntime's generic stealth-only abort line, and the HeistMission flag (SL-6, env/a-core 47d08435) with which a
## STEALTH_ONLY mission says its own abort line instead (HeistRuntime then skips the generic one).
const GENERIC_ABORT: StringName = &"vo.mercer.abort"
const RX_OWN_ABORT: String = "(?m)^\\s*own_abort_line\\s*=\\s*true"
## The mission's own abort line: the first vo id said in its `_on_alarm`.
const RX_ALARM_LINE: String = "func _on_alarm\\([^)]*\\)[^:]*:[\\s\\S]*?\"(vo\\.[A-Za-z0-9_]+\\.[A-Za-z0-9_]+)\""


## Runs the audit and writes REPORT_PATH; returns the audit.
static func write_report() -> Dictionary:
	var r: Dictionary = audit()
	var f: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(report_markdown(r))
		f.close()
	return r


## The audit. Returns:
##   lines: Array[Dictionary] {id, event, speaker, group, owner, sites: Array[String], reason: String}
##     (table order; sites empty = UNSAID, reason says why for builder lines);
##   missing: Array[Dictionary] {id, site}: ids (or builder patterns) code can say that are not in the table;
##   orphan_strings: Array[String]: voice.vo.* keys of strings.csv with no table line;
##   no_text: Array[String]: table lines whose text_key is not in strings.csv;
##   heists: Array[StringName]: every heist the radio / briefing builders iterated.
static func audit() -> Dictionary:
	var table: VoiceLineTable = load(LINES_PATH) as VoiceLineTable
	var ids: Dictionary = {}
	var rows: Array[Dictionary] = []
	for l: Dictionary in table.lines:
		var id: StringName = StringName(l.get("id", &""))
		var row: Dictionary = {
			"id": id, "event": StringName(l.get("event", &"")), "speaker": StringName(l.get("speaker", &"")),
			"group": group_of(id), "owner": "", "sites": [] as Array[String], "reason": "", "line": l,
		}
		row["owner"] = owner_of(row)
		# RT-B1 (D-151): a line of a heist still staged in heist_list (hidden, no mission yet) waits for that mission;
		# once the heist is offered its lines fall back to the A / B / C rules and must be said.
		if staged_heist_of(id) != &"":
			row["owner"] = "S"
		ids[id] = rows.size()
		rows.append(row)
	var missing: Array[Dictionary] = []
	var files: Array[String] = []
	for d: String in SCAN_DIRS:
		_collect("res://%s" % d, files)
	var heist_files: Dictionary = {}
	var pending: Array[Dictionary] = []  # {raw, site, func} sites inside a .gd function, kept until reachability is known
	for path: String in files:
		if path == LINES_PATH or SELF_PATHS.has(path):
			continue
		_note_heist_file(path, heist_files)
		_scan_file(path, rows, ids, missing, pending)
	var live: Dictionary = _reachable_funcs(pending, files)
	for p: Dictionary in pending:
		if bool(live.get(p["func"], false)):
			_apply_site(String(p["raw"]), String(p["site"]), rows, ids)
		else:
			_note_dead_site(String(p["raw"]), "%s, only in `%s()` which nothing calls" % [p["site"], p["func"]], rows, ids)
	var heists: Array[StringName] = []
	for h: StringName in heist_files:
		if (heist_files[h] as Dictionary).has("def"):
			heists.append(h)
	heists.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var tweak: RadioTweak = RadioTweak.load_default()
	var aborts: Dictionary = {}
	for h: StringName in heists:
		var hf: Dictionary = heist_files[h]
		var def: HeistDef = load(String(hf["def"])) as HeistDef
		if def == null:
			continue
		var facts: Dictionary = radio_facts(def, String(hf.get("mission", "")), tweak)
		_radio_builder(h, facts, table, tweak, rows, ids)
		_briefing_builder(h, def, table, rows, ids)
		var ab: StringName = abort_line(def, String(hf.get("mission", "")))
		if ab != &"":
			aborts[h] = ab
	_abort_builder(aborts, rows, ids)
	var strings: Dictionary = StringTable.parse_csv()
	var orphans: Array[String] = []
	for k: String in strings:
		if k.begins_with("voice.vo.") and not ids.has(StringName(k.trim_prefix("voice."))):
			orphans.append(k)
	orphans.sort()
	var no_text: Array[String] = []
	for row: Dictionary in rows:
		if not strings.has(String((row["line"] as Dictionary).get("text_key", ""))):
			no_text.append(String(row["id"]))
		if (row["sites"] as Array).is_empty() and String(row["reason"]) == "" and row.has("dead"):
			row["reason"] = "built at %s" % row["dead"]
		if (row["sites"] as Array).is_empty() and String(row["reason"]) == "":
			row["reason"] = "nothing says it: no literal id or builder, and no code maps the `%s` fact to its lines" % row["event"]
	return {"lines": rows, "missing": missing, "orphan_strings": orphans, "no_text": no_text, "heists": heists,
		"aborts": aborts}


## The abort line a STEALTH_ONLY heist plays on the alarm (&"" for any other mode): its mission's own line when the
## mission sets `own_abort_line = true` (SL-6), else HeistRuntime's generic GENERIC_ABORT.
static func abort_line(def: HeistDef, mission_path: String) -> StringName:
	if def == null or def.mode != Enums.HeistMode.STEALTH_ONLY:
		return &""
	var src: String = strip_comments(FileAccess.get_file_as_string(mission_path)) if mission_path != "" else ""
	if RegEx.create_from_string(RX_OWN_ABORT).search(src) != null:
		var m: RegExMatch = RegEx.create_from_string(RX_ALARM_LINE).search(src)
		if m != null:
			return StringName(m.get_string(1))
	return GENERIC_ABORT


## D-115 (LEAD r228, SL-6): the generic abort is said only for the STEALTH_ONLY heists without their own line. With
## none left, its HeistRuntime literal is not a trigger: the line is B's reserve (kept for new stealth-only heists).
static func _abort_builder(aborts: Dictionary, rows: Array[Dictionary], ids: Dictionary) -> void:
	if not ids.has(GENERIC_ABORT):
		return
	var row: Dictionary = rows[ids[GENERIC_ABORT]]
	var users: Array[String] = []
	for h: StringName in aborts:
		if aborts[h] == GENERIC_ABORT:
			users.append(String(h))
	if not users.is_empty():
		return
	(row["sites"] as Array).clear()
	row["owner"] = "R"
	var own: Array[String] = []
	for h2: StringName in aborts:
		own.append("%s: %s" % [h2, aborts[h2]])
	row["reason"] = "every STEALTH_ONLY heist says its own abort line (HeistMission.own_abort_line): %s" % ", ".join(own)


## "glasshouse" when the id names one of the report heists, else "shared".
## The staged heist (heist_list "hidden": true) whose id `id` names, or &"".
static func staged_heist_of(id: StringName) -> StringName:
	var s: String = String(id)
	var heists: Dictionary = HeistCatalog.heist_list().heists
	for h: Variant in heists:
		if bool((heists[h] as Dictionary).get("hidden", false)) and s.contains(String(h)):
			return StringName(h)
	return &""


static func group_of(id: StringName) -> StringName:
	var s: String = String(id)
	for h: StringName in REPORT_HEISTS:
		if s.contains(String(h)):
			return h
	return SHARED


## Which env's code must say the line: "B" (briefing, contact radio), "C" (heist mission), "A" (the rest).
static func owner_of(row: Dictionary) -> String:
	var ev: StringName = row["event"]
	if ev == EV_BRIEFING or String(ev).begins_with("radio."):
		return "B"
	if ev == EV_MISSION and StringName(row["group"]) != SHARED:
		return "C"
	return "A"


## The radio facts heist `def` can produce (its mission script at `mission_path`):
## {heist, speaker, events: {event: true}, done / new / failed: {objective id: true}, objectives: {id: true},
##  def_objectives: {id: true} (HeistDef lists + mission), loot: {loot id: true}}.
static func radio_facts(def: HeistDef, mission_path: String, tweak: RadioTweak) -> Dictionary:
	var c: ContactDef = ContactRadio.contact_for(def.id, tweak)
	var src: String = strip_comments(FileAccess.get_file_as_string(mission_path)) if mission_path != "" else ""
	var states: Dictionary = {}
	var rx_add: RegEx = RegEx.create_from_string(RX_ADD)
	var rx_state: RegEx = RegEx.create_from_string(RX_STATE)
	for m: RegExMatch in rx_add.search_all(src):
		var args: String = _call_args(src, m.get_end())
		var sm: RegExMatch = rx_state.search(args)
		var st: String = sm.get_string(1) if sm != null else "ACTIVE"
		var oid: StringName = StringName(m.get_string(1))
		if not states.has(oid):
			states[oid] = {}
		(states[oid] as Dictionary)[st] = true
	var done: Dictionary = {}
	var new: Dictionary = {}
	var failed: Dictionary = {}
	var done_ids: Array[StringName] = _matches(src, RX_DONE)
	done_ids.append_array(_helper_completions(src))
	for oid: StringName in done_ids:
		if states.has(oid) and (states[oid] as Dictionary).keys() != ["COMPLETED"]:
			done[oid] = true
	for oid: StringName in _matches(src, RX_NEW):
		if states.has(oid) and (states[oid] as Dictionary).has("HIDDEN"):
			new[oid] = true
	for oid: StringName in _matches(src, RX_FAIL):
		if states.has(oid):
			failed[oid] = true
	var loot: Dictionary = {}
	for lid: StringName in def.loot:
		if not tweak.ignored_loot.has(lid):
			loot[lid] = true
	# Objective ids the HeistDef names (objectives + briefing lists) or the mission adds: a radio line keyed to one
	# of these that stays unsaid waits on the mission (C), not on B's data.
	var def_objectives: Dictionary = states.duplicate()
	for list: Array[StringName] in [def.objectives, def.briefing_objectives, def.briefing_optional]:
		for oid: StringName in list:
			def_objectives[oid] = true
	var events: Dictionary = {}
	# A stealth-only heist's alarm is the abort: its abort line (abort_line(): HeistRuntime's generic one, or the
	# mission's own with own_abort_line) is a comms speaker and always wins.
	if def.mode != Enums.HeistMode.STEALTH_ONLY:
		events[EV_ALARM] = true
		for tag: Variant in tweak.assault_tags.values():
			events[StringName(tag)] = true
	if src.contains("activate_escape("):
		events[EV_ESCAPE_AVAILABLE] = true
		events[EV_ESCAPE] = true
	if not loot.is_empty():
		events[EV_LOOT] = true
	for pair: Array in [[EV_DONE, done], [EV_NEW, new], [EV_FAILED, failed]]:
		if not (pair[1] as Dictionary).is_empty():
			events[pair[0]] = true
	return {
		"heist": def.id, "speaker": c.voice_speaker if c != null else &"", "events": events, "done": done,
		"new": new, "failed": failed, "objectives": states, "def_objectives": def_objectives, "loot": loot,
	}


## Markdown report (content/docs/vo_coverage.md).
static func report_markdown(r: Dictionary) -> String:
	var out: PackedStringArray = []
	out.append("# VO coverage (D-117 §6)")
	out.append("")
	out.append("**Generated. Do not edit.** Regenerate with")
	out.append("`godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd` (ENV B tool,")
	out.append("`content/voice/tools/vo_coverage.gd`; the test is `tests/b/test_vo_coverage.gd`).")
	out.append("")
	out.append("A line is said when a trigger site can emit its id: a literal id in game code or data, a format builder")
	out.append("(`%s` = one identifier), or one of B's builders (ContactRadio from each heist's HeistDef and mission")
	out.append("objective calls; BriefingModel.voice_lines). Owner = whose code must say it (B: briefing / radio;")
	out.append("C: heist mission lines; A: barks, acks and system lines; B reserve: generic radio lines no current heist")
	out.append("reaches, kept for RadioTweak.speaker_overrides and new heists). Heists iterated: %s." % ", ".join(
			PackedStringArray(r["heists"] as Array)))
	out.append("")
	out.append("## Summary")
	out.append("")
	out.append("| Group | Lines | Said | Unsaid | Unsaid A | Unsaid B | Unsaid B reserve | Unsaid C |")
	out.append("|---|---|---|---|---|---|---|---|")
	var groups: Array[StringName] = REPORT_HEISTS.duplicate()
	groups.append(SHARED)
	for g: StringName in groups:
		var c: Dictionary = counts(r, g)
		out.append("| %s | %d | %d | %d | %d | %d | %d | %d |" % [
				g, c["lines"], c["said"], c["unsaid"], c["A"], c["B"], c["R"], c["C"]])
	out.append("")
	out.append("Missing (code can say it, the table has no such line): %d." % (r["missing"] as Array).size())
	for m: Dictionary in r["missing"]:
		out.append("- `%s` at %s" % [m["id"], m["site"]])
	out.append("")
	for owner: String in ["A", "B", "R", "C", "S"]:
		var un: Array[Dictionary] = unsaid(r, owner)
		out.append("## Unsaid, owner %s (%d)" % [OWNER_NAMES[owner], un.size()])
		out.append("")
		if un.is_empty():
			out.append("None.")
		else:
			out.append("| Line | Event | Why |")
			out.append("|---|---|---|")
			for row: Dictionary in un:
				out.append("| `%s` | %s | %s |" % [row["id"], row["event"], row["reason"]])
		out.append("")
	if not (r["orphan_strings"] as Array).is_empty():
		out.append("## Strings without a line (%d)" % (r["orphan_strings"] as Array).size())
		out.append("")
		out.append("`voice.vo.*` keys in strings.csv with no VoiceLineTable line: nothing can say them (remove them).")
		out.append("")
		for k: String in r["orphan_strings"]:
			out.append("- `%s`" % k)
		out.append("")
	if not (r["no_text"] as Array).is_empty():
		out.append("## Lines without text (%d)" % (r["no_text"] as Array).size())
		out.append("")
		for k: String in r["no_text"]:
			out.append("- `%s`" % k)
		out.append("")
	for g: StringName in groups:
		out.append("## %s" % g)
		out.append("")
		out.append("| Line | Event | Owner | Trigger site(s) |")
		out.append("|---|---|---|---|")
		for row: Dictionary in r["lines"]:
			if StringName(row["group"]) != g:
				continue
			var sites: Array = row["sites"]
			var s: String = "<br>".join(PackedStringArray(sites)) if not sites.is_empty() else "**%s**: %s" % [UNSAID, row["reason"]]
			out.append("| `%s` | %s | %s | %s |" % [row["id"], row["event"], row["owner"], s])
		out.append("")
	return "\n".join(out)


## {lines, said, unsaid, A, B, C (unsaid per owner)} for group `g` (&"" = every line).
static func counts(r: Dictionary, g: StringName = &"") -> Dictionary:
	var c: Dictionary = {"lines": 0, "said": 0, "unsaid": 0, "A": 0, "B": 0, "R": 0, "C": 0, "S": 0}
	for row: Dictionary in r["lines"]:
		if g != &"" and StringName(row["group"]) != g:
			continue
		c["lines"] += 1
		if (row["sites"] as Array).is_empty():
			c["unsaid"] += 1
			c[row["owner"]] += 1
		else:
			c["said"] += 1
	return c


## Unsaid rows whose owner is `owner` ("" = any).
static func unsaid(r: Dictionary, owner: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in r["lines"]:
		if (row["sites"] as Array).is_empty() and (owner == "" or String(row["owner"]) == owner):
			out.append(row)
	return out


static func summary_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	var groups: Array[StringName] = REPORT_HEISTS.duplicate()
	groups.append(SHARED)
	for g: StringName in groups:
		var c: Dictionary = counts(r, g)
		parts.append("%s %d/%d said (unsaid A%d B%d R%d C%d)" % [g, c["said"], c["lines"], c["A"], c["B"], c["R"], c["C"]])
	return "vo_coverage: %s; missing %d -> %s" % ["; ".join(parts), (r["missing"] as Array).size(), REPORT_PATH]


## GDScript source without comments (a `#` outside a string to the end of its line).
static func strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for ln: String in src.split("\n"):
		out.append(_code_part(ln))
	return "\n".join(out)


static func _code_part(ln: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < ln.length():
		var ch: String = ln[i]
		if quote != "":
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			return ln.substr(0, i)
		i += 1
	return ln


static func _collect(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if SCAN_EXT.has(f.get_extension()):
			out.append("%s/%s" % [dir, f])
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect("%s/%s" % [dir, sub], out)


## Records <id>_def.tres (a HeistDef) and <id>_mission.gd per heist id.
static func _note_heist_file(path: String, heist_files: Dictionary) -> void:
	var f: String = path.get_file()
	var key: String = ""
	var id: String = ""
	if f.ends_with("_def.tres"):
		id = f.trim_suffix("_def.tres")
		if not FileAccess.get_file_as_string(path).contains("script_class=\"HeistDef\""):
			return
		key = "def"
	elif f.ends_with("_mission.gd"):
		id = f.trim_suffix("_mission.gd")
		key = "mission"
	else:
		return
	if not heist_files.has(StringName(id)):
		heist_files[StringName(id)] = {}
	(heist_files[StringName(id)] as Dictionary)[key] = path


static func _scan_file(path: String, rows: Array[Dictionary], ids: Dictionary, missing: Array[Dictionary],
		pending: Array[Dictionary]) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if not text.contains("vo."):
		return
	var rx: RegEx = RegEx.create_from_string(RX_ID)
	var rx_func: RegEx = RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)")
	var is_gd: bool = path.get_extension() == "gd"
	var rel: String = path.trim_prefix("res://")
	var n: int = 0
	var fn: String = ""  # the .gd function the line is in ("" = class level)
	for ln: String in text.split("\n"):
		n += 1
		if is_gd:
			var fm: RegExMatch = rx_func.search(ln)
			if fm != null:
				fn = fm.get_string(1)
			elif ln != "" and not ln.begins_with("\t") and not ln.begins_with(" ") and not ln.begins_with("#"):
				fn = ""  # back at class level (var / const / signal / class)
		if not ln.contains("vo."):
			continue
		var code: String = _code_part(ln) if is_gd else ln
		for m: RegExMatch in rx.search_all(code):
			var raw: String = m.get_string(1)
			var site: String = "%s:%d" % [rel, n]
			if raw.contains("%"):
				if _apply_pattern(raw, site, rows, false) == 0:
					missing.append({"id": raw, "site": site})
			elif not ids.has(StringName(raw)):
				missing.append({"id": raw, "site": site})
			if fn != "" and not ENGINE_VIRTUALS.has(fn):
				pending.append({"raw": raw, "site": site, "func": fn})
			else:
				_apply_site(raw, site, rows, ids)


## Records a site of literal / builder `raw` on the table rows it names.
static func _apply_site(raw: String, site: String, rows: Array[Dictionary], ids: Dictionary) -> void:
	if raw.contains("%"):
		_apply_pattern(raw, site, rows)
	elif ids.has(StringName(raw)):
		_add_site(rows[ids[StringName(raw)]], site)


## A site in a function nothing calls: no site, but the row's reason names it (kept when a live site comes later).
static func _note_dead_site(raw: String, why: String, rows: Array[Dictionary], ids: Dictionary) -> void:
	var targets: Array[Dictionary] = []
	if raw.contains("%"):
		var rx: RegEx = RegEx.create_from_string("^%s$" % _escape(raw).replace("%s", "\\w+").replace("%d", "\\d+"))
		for row: Dictionary in rows:
			if rx.search(String(row["id"])) != null:
				targets.append(row)
	elif ids.has(StringName(raw)):
		targets.append(rows[ids[StringName(raw)]])
	for row: Dictionary in targets:
		row["dead"] = why


## Function name -> true when it can run: referenced in any scanned file besides its own `func` lines.
static func _reachable_funcs(pending: Array[Dictionary], files: Array[String]) -> Dictionary:
	var names: Dictionary = {}
	for p: Dictionary in pending:
		names[String(p["func"])] = true
	var out: Dictionary = {}
	if names.is_empty():
		return out
	var alt: String = "|".join(PackedStringArray(names.keys()))
	var rx_ref: RegEx = RegEx.create_from_string("\\b(%s)\\b" % alt)
	var rx_def: RegEx = RegEx.create_from_string("(?m)^\\s*(?:static\\s+)?func\\s+(%s)\\b" % alt)
	for path: String in files:
		if SELF_PATHS.has(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if path.get_extension() == "gd":
			text = strip_comments(text)
		var defs: Dictionary = {}
		for d: RegExMatch in rx_def.search_all(text):
			defs[d.get_start(1)] = true
		for m: RegExMatch in rx_ref.search_all(text):
			if not defs.has(m.get_start(1)):
				out[m.get_string(1)] = true
	return out


## Marks every table id of the builder's shape (only counts with `mark` false); returns how many matched.
static func _apply_pattern(raw: String, site: String, rows: Array[Dictionary], mark: bool = true) -> int:
	var rx: RegEx = RegEx.create_from_string("^%s$" % _escape(raw).replace("%s", "\\w+").replace("%d", "\\d+"))
	var hits: int = 0
	for row: Dictionary in rows:
		if rx.search(String(row["id"])) != null:
			if mark:
				_add_site(row, "%s (builder `%s`)" % [site, raw])
			hits += 1
	return hits


static func _escape(s: String) -> String:
	return s.replace(".", "\\.")


static func _add_site(row: Dictionary, site: String) -> void:
	var sites: Array = row["sites"]
	if not sites.has(site):
		sites.append(site)


## Objective ids completed through a mission helper that completes its own first parameter (GH's
## `_check_cases(&"salon", TAG)` -> `complete(objective_id)`, C 762934d5): every literal first argument at a call of
## such a helper counts as completed.
static func _helper_completions(src: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var rx_func: RegEx = RegEx.create_from_string("(?m)^func (\\w+)\\((\\w+)\\s*:")
	var funcs: Array[RegExMatch] = rx_func.search_all(src)
	for i: int in range(funcs.size()):
		var f: RegExMatch = funcs[i]
		var body_end: int = funcs[i + 1].get_start() if i + 1 < funcs.size() else src.length()
		var body: String = src.substr(f.get_end(), body_end - f.get_end())
		var param: String = f.get_string(2)
		var name: String = f.get_string(1)
		if not RegEx.create_from_string("\\b(?:complete|_complete_once)\\(\\s*%s\\s*\\)" % param).search(body):
			continue
		for id: StringName in _matches(src, "\\b%s\\(\\s*&\"(\\w+)\"" % name):
			if not out.has(id):
				out.append(id)
	return out


static func _matches(src: String, pattern: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for m: RegExMatch in RegEx.create_from_string(pattern).search_all(src):
		var id: StringName = StringName(m.get_string(1))
		if not out.has(id):
			out.append(id)
	return out


## The rest of a call's argument list from `from` (just after its first argument) to its closing paren.
static func _call_args(src: String, from: int) -> String:
	var depth: int = 1
	var i: int = from
	while i < src.length() and depth > 0:
		var ch: String = src[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		i += 1
	return src.substr(from, i - from)


## ContactRadio (B7-03) through RadioLinePicker's rules, for heist `h` with `facts` (radio_facts()).
static func _radio_builder(h: StringName, facts: Dictionary, table: VoiceLineTable, tweak: RadioTweak,
		rows: Array[Dictionary], ids: Dictionary) -> void:
	var sp: StringName = facts["speaker"]
	if sp == &"":
		return
	var picker: RadioLinePicker = RadioLinePicker.new(table, tweak.no_repeat_depth)
	for ev: StringName in facts["events"]:
		for ctx: Dictionary in _contexts(ev, facts):
			var pool: Array[Dictionary] = picker.heist_lines(ev, sp, h, ctx)
			var label: String = _ctx_label(ctx)
			var always_ready: bool = false
			for l: Dictionary in pool:
				_add_site(rows[ids[StringName(l["id"])]], "ContactRadio %s%s via %s" % [ev, label, h])
				if float(l.get("cooldown_s", 0.0)) <= 0.0:
					always_ready = true
			if always_ready:
				continue
			for l: Dictionary in picker.generic_lines(ev, sp):
				_add_site(rows[ids[StringName(l["id"])]], "ContactRadio %s%s via %s (generic)" % [ev, label, h])
	# Why the radio lines of this heist that stay unsaid are unsaid.
	for row: Dictionary in rows:
		var l: Dictionary = row["line"]
		if not String(row["event"]).begins_with("radio.") or StringName(l.get("heist", &"")) != h:
			continue
		if not (row["sites"] as Array).is_empty():
			continue
		row["reason"] = _radio_reason(l, facts, sp)
		var oid: StringName = StringName(l.get("objective", &""))
		if StringName(l.get("speaker", &"")) == sp and oid != &"" and (facts["def_objectives"] as Dictionary).has(oid):
			row["owner"] = "C"
	# Generic lines of this speaker: name the events no heist of theirs produces.
	for row: Dictionary in rows:
		var l: Dictionary = row["line"]
		if not String(row["event"]).begins_with("radio.") or l.has("heist") or StringName(row["speaker"]) != sp:
			continue
		if (row["sites"] as Array).is_empty() and String(row["reason"]) == "":
			row["owner"] = "R"
			row["reason"] = "generic %s line: every %s fact has an always-ready heist line, or no heist with %s on the radio has the fact" % [
				row["event"], row["event"], sp]


static func _radio_reason(l: Dictionary, facts: Dictionary, sp: StringName) -> String:
	var ev: StringName = StringName(l.get("event", &""))
	var oid: StringName = StringName(l.get("objective", &""))
	if StringName(l.get("speaker", &"")) != sp:
		return "speaker %s is not on the radio for %s (%s is)" % [l.get("speaker"), facts["heist"], sp]
	if not (facts["events"] as Dictionary).has(ev):
		return "%s never gets a %s fact" % [facts["heist"], ev]
	if oid != &"":
		if not (facts["objectives"] as Dictionary).has(oid):
			if (facts["def_objectives"] as Dictionary).has(oid):
				return "HeistDef objective `%s` is never added by %s's mission" % [oid, facts["heist"]]
			return "objective `%s` is not an objective of %s" % [oid, facts["heist"]]
		var need: String = {EV_DONE: "completes", EV_NEW: "goes HIDDEN -> ACTIVE", EV_FAILED: "fails"}.get(ev, "?")
		return "the mission never %s objective `%s`" % [need, oid]
	if l.has("loot") and not (facts["loot"] as Dictionary).has(StringName(l["loot"])):
		return "loot `%s` is not in %s's HeistDef.loot" % [l["loot"], facts["heist"]]
	return "no fact selects it"


## The fact contexts of radio event `ev` for a heist.
static func _contexts(ev: StringName, facts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key: Dictionary = {EV_DONE: "done", EV_NEW: "new", EV_FAILED: "failed"}
	if key.has(ev):
		for oid: StringName in facts[key[ev]]:
			out.append({"objective": oid})
	elif ev == EV_LOOT:
		for lid: StringName in facts["loot"]:
			out.append({"loot_id": lid})
	else:
		out.append({})
	return out


static func _ctx_label(ctx: Dictionary) -> String:
	if ctx.has("objective"):
		return " [%s]" % ctx["objective"]
	if ctx.has("loot_id"):
		return " (%s)" % ctx["loot_id"]
	return ""


## BriefingModel.voice_lines (B2-02): what "Play Briefing" plays for `h`.
static func _briefing_builder(h: StringName, def: HeistDef, table: VoiceLineTable, rows: Array[Dictionary],
		ids: Dictionary) -> void:
	var contact: ContactDef = ContactDef.find(def.contact) if def.contact != &"" else null
	for l: Dictionary in BriefingModel.voice_lines(h, contact, table):
		_add_site(rows[ids[StringName(l["id"])]], "BriefingModel.voice_lines via %s (%s)" % [h, def.contact])
	for row: Dictionary in rows:
		var l: Dictionary = row["line"]
		if StringName(row["event"]) == EV_BRIEFING and StringName(l.get("heist", &"")) == h and (row["sites"] as Array).is_empty():
			row["reason"] = "the %s briefing plays %s and Mercer only (HeistDef.contact = %s)" % [
				h, contact.voice_speaker if contact != null else &"?", def.contact]
