## B4-09 (D-040, Night Deposit) / B4-10 (D-042, Shadow Ledger): ENV B content for the P2 heists:
## loot defs, objective strings from the design docs' `[tag]`s (D-039), briefing lines and the
## placeholder briefing/catalog data used until ENV C's HeistDefs land.
extends TestCase

## Objective `[tag]`s in order of first appearance in the doc's "## Objectives" section (stealth
## list, then loud list). Source: docs/design/heists/night_deposit.md (ENV C, approved in D-040).
## Hardcoded because the doc was not on trunk when this was written; when it is,
## _doc_tags() parses it and the test compares.
const ND_TAGS: Array[String] = [
	"casing", "keycard", "code", "server", "vault_gate", "time_lock", "time_lock_wait",
	"vault_loot", "depository", "secure", "escape", "vault_drill",
]
var _table: Dictionary = {}


func before_all() -> void:
	_table = StringTable.parse_csv()


## Tags from docs/design/heists/<id>.md (empty when the doc is not in this checkout).
func _doc_tags(heist: String) -> Array[String]:
	var out: Array[String] = []
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/heists/%s.md" % heist)
	if not FileAccess.file_exists(doc):
		return out
	var sec: String = FileAccess.get_file_as_string(doc).get_slice("## Objectives", 1).get_slice("\n## ", 0)
	var rx: RegEx = RegEx.create_from_string("`\\[([a-z_]+)\\]`")
	for m: RegExMatch in rx.search_all(sec):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


func _check_objectives(heist: String, tags: Array[String]) -> void:
	var doc_tags: Array[String] = _doc_tags(heist)
	if not doc_tags.is_empty():
		assert_eq(doc_tags, tags, "%s design doc tags" % heist)
	for t: String in tags:
		assert_has(_table, "objective.%s.%s" % [heist, t])
	var prefix: String = "objective.%s." % heist
	for k: String in _table.keys():
		if k.begins_with(prefix):
			assert_has(tags, k.trim_prefix(prefix), "no guessed objective key: %s" % k)
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(StringName(heist), {}) as Dictionary
	var ids: Array[String] = []
	for id: Variant in ph.get("objectives", []) as Array:
		ids.append(String(id))
	assert_eq(ids, tags, "%s briefing placeholder objective ids" % heist)


## Briefing lines: the contact's (orders 1..n) then Mercer's closing line, all with text.
func _check_briefing(heist: StringName, contact_id: StringName, contact_lines: int) -> void:
	var contact: ContactDef = ContactDef.find(contact_id)
	assert_true(contact != null, String(contact_id))
	var lines: Array[Dictionary] = BriefingModel.voice_lines(heist, contact)
	assert_eq(lines.size(), contact_lines + 1, "%s briefing lines" % heist)
	for i: int in range(lines.size()):
		var l: Dictionary = lines[i]
		var speaker: StringName = contact.voice_speaker if i < contact_lines else &"mercer"
		assert_eq(StringName(l["speaker"]), speaker)
		assert_eq(StringName(l["event"]), &"briefing")
		assert_eq(StringName(l["heist"]), heist)
		assert_eq(String(l["text_key"]), "voice.%s" % l["id"])
		assert_has(_table, String(l["text_key"]))
		assert_true(VoiceLineTable.SPEAKERS.has(speaker))
	assert_eq(StringName(lines[-1]["speaker"]), &"mercer", "Mercer closes")
	for k: String in ["name", "subtitle", "brief", "briefing"]:
		assert_has(_table, "heist.%s.%s" % [heist, k])
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(heist, {}) as Dictionary
	assert_eq(StringName(ph.get("contact", &"")), contact_id)
	for e: Variant in ph.get("escape_options", []) as Array:
		assert_has(_table, "ui.briefing.escape.%s" % e)
	for lid: Variant in ph.get("loot", []) as Array:
		assert_true(ContentDB.loot(StringName(lid)) != null, "placeholder loot %s exists" % lid)
	var m: Dictionary = BriefingModel.build(heist, Enums.Difficulty.ROUTINE)
	assert_true(String(m["briefing_text"]).length() > 100, "%s briefing text" % heist)


func _check_loot(id: StringName, weight: Enums.LootWeight) -> void:
	var l: LootDef = ContentDB.loot(id)
	assert_true(l != null, String(id))
	if l == null:
		return
	assert_eq(l.id, id)
	assert_eq(l.weight, weight, "%s weight" % id)
	assert_true(l.value > 0, "%s has a value" % id)
	assert_false(l.conceals)
	assert_has(_table, "item.%s.name" % id)
	assert_has(_table, "item.%s.desc" % id)


# --- B4-09 Night Deposit ---

func test_night_deposit_loot() -> void:
	# MEDIUM is the lead's decision (B4-09); the C doc's QC-13 asked for HEAVY.
	_check_loot(&"loot.cash_bricks", Enums.LootWeight.MEDIUM)
	assert_true(ContentDB.loot(&"loot.cash_bricks").value > ContentDB.loot(&"loot.cash").value,
			"denser than a LIGHT cash bag, so worth more per bag")


func test_night_deposit_objectives_follow_the_design_doc() -> void:
	_check_objectives("night_deposit", ND_TAGS)


func test_night_deposit_briefing() -> void:
	_check_briefing(&"night_deposit", &"contact.accountant", 3)


func test_night_deposit_catalog_placeholder() -> void:
	var data: Dictionary = HeistCatalog.heist_list().heists.get(&"night_deposit", {}) as Dictionary
	assert_eq(int(data.get("placeholder_base_payout", 0)), 90000, "ENV C's proposed base payout")
	assert_eq(int(data.get("placeholder_mode", -1)), Enums.HeistMode.STEALTH_OR_LOUD)

