## D-130 (data_schemas v1.3): the heist select's difficulty card and the briefing intel say "Titan cameras" from the heist's
## effective camera_titan_min_difficulty (def value if >= 0, else StealthTweak's) and "N pagers" from the def's
## pager_max_by_difficulty (none when empty). Golden Hour's row is C's generator data (round 231).
extends TestCase

const GH_PAGERS: Array[int] = [4, 4, 3, 3, 2, 1]
## D-140 (PO-15) pager caps for the bank-type stealth heists (C's generator rows; OF from B's values block).
const D140_PAGERS: Dictionary = {
	&"night_deposit": [4, 4, 3, 3, 2, 2],
	&"gallery_night": [4, 4, 4, 3, 3, 2],
	&"shadow_ledger": [4, 4, 4, 3, 3, 2],
	&"ostrander_federal": [4, 4, 4, 3, 3, 2],
}


func test_gh_def_carries_the_d130_row() -> void:
	var gh: HeistDef = HeistRegistry.get_def(&"glasshouse")
	assert_eq(gh.pager_max_by_difficulty, GH_PAGERS, "D-130 GH pagers by difficulty")
	assert_eq(gh.camera_titan_min_difficulty, Enums.Difficulty.HAZARDOUS, "D-130 GH Titan from Hazardous")


func _note(heist: StringName, d: int) -> String:
	return HeistSelect.stealth_note(heist, d, int(HeistRegistry.get_def(heist).mode))


func test_card_note_follows_the_def() -> void:
	var sep: String = UiText.t(&"ui.heist_select.stealth_note_sep")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.ROUTINE), "4 pagers", "GH Routine: no Titan, 4 pagers")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.HAZARDOUS), "Titan cameras" + sep + "3 pagers", "GH Hazardous")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.LETHAL), "Titan cameras" + sep + "2 pagers", "GH Lethal")
	assert_eq(_note(&"glasshouse", Enums.Difficulty.CATACLYSM), "Titan cameras" + sep + "1 pager", "singular")
	var tw_min: int = Tweak.stealth().camera_titan_min_difficulty
	assert_eq(_note(&"night_deposit", tw_min - 1), "", "ND below the tweak's Titan tier: nothing to say")
	var nd_cap: int = BriefingIntel.pager_cap(&"night_deposit", tw_min)
	var nd_want: String = "Titan cameras" + ("" if nd_cap < 0 else sep + "%d pagers" % nd_cap)
	assert_eq(_note(&"night_deposit", tw_min), nd_want, "ND: the tweak's Titan tier, pagers from its def (D-140)")
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
	assert_true(hs.stealth_label.visible and hs.stealth_label.text == "4 pagers", hs.stealth_label.text)
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


## D-140: the card and the briefing intel say "N pagers" for ND / GN / SL / OF at every difficulty, from the def's row.
## Skips a heist whose def (or row) has not landed yet (C's generator rows; OF after G1).
func test_d140_bank_heists_show_pagers() -> void:
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
			assert_true(_note(heist, d).contains(line), "%s d%d card: %s" % [heist, d, _note(heist, d)])
			var pager_text: String = ""
			for l: Dictionary in BriefingIntel.lines(heist, d, int(def.mode)):
				if StringName(l.get("id", &"")) == &"pagers":
					pager_text = String(l.get("text", ""))
			assert_true(pager_text.contains(str(n)), "%s d%d intel: %s" % [heist, d, pager_text])
	if not missing.is_empty():
		skip("D-140 rows not landed yet: %s" % ", ".join(missing))
