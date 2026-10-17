## D-130 (data_schemas v1.3): the heist select's difficulty card and the briefing intel say "Titan cameras" from the heist's
## effective camera_titan_min_difficulty (def value if >= 0, else StealthTweak's) and "N pagers" from the def's
## pager_max_by_difficulty (none when empty). Golden Hour's row is C's generator data (round 231).
extends TestCase

const GH_PAGERS: Array[int] = [4, 4, 3, 3, 2, 1]
## D-140 (PO-15, revised): the PAGERS maps' caps (C's generator rows). GN and OF are GUARDS maps: no table, cap 4.
const D140_PAGERS: Dictionary = {
	&"night_deposit": [4, 3, 3, 2, 2, 1],
	&"shadow_ledger": [4, 3, 3, 2, 2, 1],
}
const D140_GUARDS_MAPS: Array[StringName] = [&"gallery_night", &"ostrander_federal"]


func test_gh_def_carries_the_d130_row() -> void:
	var gh: HeistDef = HeistRegistry.get_def(&"glasshouse")
	assert_eq(gh.pager_max_by_difficulty, GH_PAGERS, "D-130 GH pagers by difficulty")
	assert_eq(gh.camera_titan_min_difficulty, Enums.Difficulty.HAZARDOUS, "D-130 GH Titan from Hazardous")


func _note(heist: StringName, d: int) -> String:
	return HeistSelect.stealth_note(heist, d, int(HeistRegistry.get_def(heist).mode))


func test_card_note_follows_the_def() -> void:
	var sep: String = UiText.t(&"ui.heist_select.stealth_note_sep")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.ROUTINE), "", "GH Routine: no Titan, 4 pagers unsaid (D-140)")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.TENSE), "", "GH Tense: cap 4, unsaid")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.HAZARDOUS), "Titan cameras" + sep + "3 pagers", "GH Hazardous")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.LETHAL), "Titan cameras" + sep + "2 pagers", "GH Lethal")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.CATACLYSM), "Titan cameras" + sep + "1 pager", "singular")
	var tw_min: int = Tweak.stealth().camera_titan_min_difficulty
	# ND's pager / guard part is covered by the D-140 tests (it changes when C's ND row lands); Titan only here.
	assert_false(_note(&"night_deposit", tw_min - 1).contains("Titan"), "ND below the tweak's Titan tier")
	assert_true(_note(&"night_deposit", tw_min).begins_with("Titan cameras"), "ND: Titan from the tweak's tier")
	assert_eq(_note(&"dockside_burn", Enums.Difficulty.CATACLYSM), "", "loud-only: no stealth note")


func test_briefing_intel_reads_the_def() -> void:
	var lines: Array[Dictionary] = BriefingIntel.lines(&"glasshouse", Enums.Difficulty.HAZARDOUS, Enums.HeistMode.STEALTH_OR_LOUD)
	var keys: Array[StringName] = []
	var pager_text: String = ""
	for l: Dictionary in lines:
		keys.append(StringName(l.get("base_key", l.get("key", &""))))
		if StringName(l.get("id", &"")) == &"pagers":
			pager_text = String(l.get("text", ""))
	assert_has(keys, &"ui.briefing.sec.cameras_titan", "GH Hazardous: Titan cameras in the intel (%s)" % [keys])
	assert_true(pager_text.contains("3"), "GH Hazardous intel: 3 pager answers (%s)" % pager_text)
	lines = BriefingIntel.lines(&"glasshouse", Enums.Difficulty.ROUTINE, Enums.HeistMode.STEALTH_OR_LOUD)
	keys.clear()
	for l: Dictionary in lines:
		keys.append(StringName(l.get("base_key", l.get("key", &""))))
	assert_has(keys, &"ui.briefing.sec.cameras", "GH Routine: plain cameras")


func test_heist_select_shows_the_note() -> void:
	var hs: HeistSelect = (load("res://content/ui/menus/heist_select.tscn") as PackedScene).instantiate() as HeistSelect
	add_child(hs)
	await wait_frames(2)
	assert_true(hs.select_heist_id(&"glasshouse"))
	hs.select_difficulty(Enums.Difficulty.ROUTINE)
	assert_false(hs.stealth_label.visible, "GH Routine: nothing below the usual (%s)" % hs.stealth_label.text)
	hs.select_difficulty(Enums.Difficulty.BRUTAL)
	assert_true(hs.stealth_label.visible and hs.stealth_label.text.ends_with("3 pagers"), hs.stealth_label.text)
	hs.select_difficulty(Enums.Difficulty.TENSE)
	var pressed: Array[int] = []
	for i: int in range(hs.difficulty_buttons.size()):
		if hs.difficulty_buttons[i].button_pressed:
			pressed.append(i)
	assert_eq(pressed, [Enums.Difficulty.TENSE] as Array[int], "a programmatic pick leaves one tab pressed")
	assert_true(hs.select_heist_id(&"dockside_burn"))
	assert_false(hs.stealth_label.visible, "loud-only: hidden")
	hs.queue_free()
	await wait_frames(1)


## D-140: the card says "N pagers" on the PAGERS maps (ND / SL) where the def's row is below 4 (Tense up); the briefing
## intel's pager count follows the row everywhere; the GUARDS maps (GN / OF) keep the cap 4 and the card says nothing.
## Skips a map whose row has not landed (C).
func test_d140_pager_line_on_pagers_maps() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for heist: StringName in D140_PAGERS:
		var def: HeistDef = HeistRegistry.get_def(heist)
		if def == null or def.pager_max_by_difficulty.is_empty():
			missing.append(String(heist))
			continue
		var want: Array = D140_PAGERS[heist] as Array
		assert_eq(Array(def.pager_max_by_difficulty), want, "%s: the D-140 pager row" % heist)
		for d: int in range(want.size()):
			var n: int = int(want[d])
			var line: String = UiText.t(&"ui.heist_select.pager_one" if n == 1 else &"ui.heist_select.pagers", {"n": n})
			if n < 4:
				assert_true(_note(heist, d).contains(line), "%s d%d card: %s" % [heist, d, _note(heist, d)])
			else:
				assert_false(_note(heist, d).contains("pager"), "%s d%d card: cap 4 unsaid" % [heist, d])
			var pager_text: String = ""
			for l: Dictionary in BriefingIntel.lines(heist, d, int(def.mode)):
				if StringName(l.get("id", &"")) == &"pagers":
					pager_text = String(l.get("text", ""))
			assert_true(pager_text.contains(str(n)), "%s d%d intel: %s" % [heist, d, pager_text])
	for heist: StringName in D140_GUARDS_MAPS:
		var def: HeistDef = HeistRegistry.get_def(heist)
		if def == null:
			continue
		assert_true(def.pager_max_by_difficulty.is_empty(), "%s: GUARDS map, no pager table" % heist)
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			assert_false(_note(heist, d).contains("pager"), "%s d%d: no pager line" % [heist, d])
	if not missing.is_empty():
		skip("D-140 rows not landed yet: %s" % ", ".join(missing))


## D-140: on the GUARDS maps (GN / OF: no pager row) the card says "More guards: N" (N = the minimum carriers over
## seeds) wherever the difficulty fields more than Routine, and nothing where it does not; never on a PAGERS map.
func test_d140_guard_line_on_guards_maps() -> void:
	var probed: PackedStringArray = PackedStringArray()
	for heist: StringName in D140_GUARDS_MAPS:
		var def: HeistDef = HeistRegistry.get_def(heist)
		if def == null or BriefingIntel.guard_range(heist, Enums.Difficulty.ROUTINE).x < 0:
			continue
		var base: int = BriefingIntel.guard_range(heist, Enums.Difficulty.ROUTINE).x
		var mins: Array[int] = []
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			var n: int = BriefingIntel.guard_range(heist, d).x
			mins.append(n)
			var line: String = UiText.t(&"ui.heist_select.more_guards", {"n": n})
			if d > Enums.Difficulty.ROUTINE and n > base:
				assert_true(_note(heist, d).contains(line), "%s d%d card: %s" % [heist, d, _note(heist, d)])
			else:
				assert_false(_note(heist, d).contains("More guards"), "%s d%d: no added guards, no line" % [heist, d])
		probed.append("%s %s" % [heist, mins])
	for heist: StringName in [&"glasshouse", &"night_deposit", &"shadow_ledger"]:
		for d: int in range(Enums.Difficulty.CATACLYSM + 1):
			var note: String = _note(heist, d)
			if not HeistRegistry.get_def(heist).pager_max_by_difficulty.is_empty():
				assert_false(note.contains("More guards"), "%s d%d: a PAGERS map says pagers, not guards" % [heist, d])
	assert_true(UiText.t(&"ui.heist_select.more_guards", {"n": 5}) == "More guards: 5")
	print("D140 guard minimums: ", ", ".join(probed))
