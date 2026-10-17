## D-130 (data_schemas v1.3): the heist select's difficulty card and the briefing intel say "Titan cameras" from the heist's
## effective camera_titan_min_difficulty (def value if >= 0, else StealthTweak's) and "N pagers" from the def's
## pager_max_by_difficulty (none when empty). Golden Hour's row is C's generator data (round 231).
extends TestCase

const GH_PAGERS: Array[int] = [4, 4, 3, 3, 2, 1]


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
	assert_eq(_note(&"night_deposit", tw_min), "Titan cameras", "ND: the tweak default, no pager line (empty def)")
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
