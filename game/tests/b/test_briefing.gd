## B2-02: briefing screen (pd2_fidelity C2) and BriefingModel.
extends TestCase

const SCENE: String = "res://content/ui/briefing/briefing_screen.tscn"
const HEIST: StringName = &"glasshouse"

var _strings: Dictionary = {}


func before_all() -> void:
	_strings = StringTable.parse_csv()


func _expected_objectives() -> Array:
	var def: HeistDef = HeistRegistry.get_def(HEIST)
	if def != null:
		return Array(def.objectives)
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(HEIST, {}) as Dictionary
	return Array(ph.get("objectives", []))


func _screen(difficulty: int) -> BriefingScreen:
	var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
	s.setup(HEIST, difficulty)
	add_child(s)
	return s


func test_screen_instantiates_for_glasshouse() -> void:
	var s: BriefingScreen = _screen(Enums.Difficulty.ROUTINE)
	await wait_frames(2)
	assert_eq(s.heist_id, HEIST)
	assert_eq(bool(s.model["placeholder"]), HeistRegistry.get_def(HEIST) == null, "def or placeholder")
	assert_true(s.heist_label.text.contains(UiText.t(&"heist.glasshouse.name")), s.heist_label.text)
	assert_true(s.model["contact"] != null, "a contact")
	assert_ne(s.contact_name_label.text, "")
	assert_ne(s.briefing_label.text, "")
	assert_false(s.briefing_label.text.begins_with("heist."), "briefing key resolved: %s" % s.briefing_label.text)
	assert_ne(s.escape_label.text, "")
	assert_true(s.continue_button.has_focus(), "continue has focus for gamepad/keyboard")
	assert_false(s.play_button.focus_neighbor_bottom.is_empty(), "focus chain set")
	s.queue_free()


func test_objectives_rendered() -> void:
	var s: BriefingScreen = _screen(Enums.Difficulty.ROUTINE)
	await wait_frames(1)
	var expected: Array = _expected_objectives()
	assert_true(expected.size() >= 1, "glasshouse has objectives")
	var texts: Array[String] = s.objective_texts()
	var lead: int = BriefingModel.ui_data().briefing_lead_steps
	assert_eq(texts.size(), (BriefingModel.cap_objectives(expected, lead)["shown"] as Array).size(), "D-117 §5 cap")
	for t: String in texts:
		assert_false(t.contains("{"), "no unresolved args: %s" % t)
		assert_false(t.contains("objective."), "key resolved: %s" % t)
	if HeistRegistry.get_def(HEIST) == null:
		assert_eq(texts[0], "1. %s" % _strings["objective.glasshouse.casing"])
	s.queue_free()


func test_loot_values_scale_with_difficulty() -> void:
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.BRUTAL, Enums.Difficulty.CATACLYSM]:
		var m: Dictionary = BriefingModel.build(HEIST, d)
		var mult: float = ContentDB.difficulty(d as Enums.Difficulty).payout_mult
		var loot: Array = m["loot"] as Array
		assert_true(loot.size() >= 1, "glasshouse has loot")
		for l: Dictionary in loot:
			var base: int = ContentDB.loot(StringName(l["loot_id"])).value
			assert_eq(int(l["base"]), base)
			assert_eq(int(l["value"]), roundi(float(base) * mult), "%s at %d" % [l["loot_id"], d])
		var entry_payout: int = 0
		for e: Dictionary in HeistCatalog.entries():
			if StringName(e["id"]) == HEIST:
				entry_payout = int(e["base_payout"])
		assert_eq(int(m["contract_pay"]), HeistCatalog.contract_preview(entry_payout, d))


func test_loot_and_pay_shown_on_screen() -> void:
	var s: BriefingScreen = _screen(Enums.Difficulty.BRUTAL)
	await wait_frames(1)
	var first: Dictionary = (s.model["loot"] as Array)[0] as Dictionary
	var shown: String = ""
	for c: Node in s.loot_box.get_children():
		shown += (c as Label).text + "\n"
	assert_true(shown.contains(UiText.group_digits(int(first["value"]))), shown)
	assert_true(s.pay_label.text.contains(UiText.group_digits(int(s.model["contract_pay"]))), s.pay_label.text)
	assert_true(s.difficulty_label.text.contains(UiText.t(UiText.difficulty_key(Enums.Difficulty.BRUTAL))))
	s.setup(HEIST, Enums.Difficulty.ROUTINE)
	assert_eq(int(s.model["difficulty"]), Enums.Difficulty.ROUTINE, "setup after ready refreshes")
	s.queue_free()


func test_play_briefing_emits_valid_voice_lines() -> void:
	var s: BriefingScreen = _screen(Enums.Difficulty.ROUTINE)
	await wait_frames(1)
	var table: VoiceLineTable = load(BriefingModel.LINES_PATH) as VoiceLineTable
	var got: Array[Dictionary] = []
	var cb: Callable = func(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
		got.append({"speaker": speaker, "id": line_id, "ctx": ctx})
	EventBus.voice_line_requested.connect(cb)
	assert_true(s.play_briefing(), "glasshouse has briefing lines")
	assert_true(s.playing)
	assert_eq(s.play_button.text, UiText.t(&"ui.briefing.stop"))
	var guard: int = 0
	while s.playing and guard < 50:
		s.next_line()
		guard += 1
	EventBus.voice_line_requested.disconnect(cb)
	var expected: int = (s.model["voice_lines"] as Array).size()
	assert_true(expected >= 2, "contact lines + handler line")
	assert_eq(got.size(), expected)
	var contact: ContactDef = s.model["contact"] as ContactDef
	assert_eq(got[0]["speaker"], contact.voice_speaker, "the contact speaks first")
	assert_eq(got[got.size() - 1]["speaker"], &"mercer", "the handler closes")
	for g: Dictionary in got:
		var line: Dictionary = table.line(StringName(g["id"]))
		assert_false(line.is_empty(), "line %s exists in lines.tres" % g["id"])
		assert_eq(line.get("event"), &"briefing")
		assert_eq(line.get("speaker"), g["speaker"])
		assert_has(_strings, String(line.get("text_key", "")))
		var ctx: Dictionary = g["ctx"] as Dictionary
		assert_eq(ctx.get("local"), true, "briefing VO is a local UI fact")
		assert_eq(ctx.get("source"), &"briefing")
		assert_eq(ctx.get("heist_id"), HEIST)
	assert_false(s.playing, "playback ends after the last line")
	assert_true(s.subtitle_label.text.contains(UiText.t(&"contact.mercer")), s.subtitle_label.text)
	s.queue_free()


func test_stop_and_continue_signals() -> void:
	var s: BriefingScreen = _screen(Enums.Difficulty.BRUTAL)
	await wait_frames(1)
	var got: Array = []
	s.continue_requested.connect(func(h: StringName, d: int) -> void: got.append([h, d]))
	var backs: Array = []
	s.back_requested.connect(func() -> void: backs.append(true))
	s.toggle_briefing()
	assert_true(s.playing)
	s.toggle_briefing()
	assert_false(s.playing, "second press stops")
	s.play_briefing()
	s.continue_button.pressed.emit()
	assert_eq(got, [[HEIST, Enums.Difficulty.BRUTAL]])
	assert_false(s.playing, "continue stops the briefing")
	s.back_button.pressed.emit()
	assert_eq(backs.size(), 1)
	s.queue_free()


## GN-B1 capture: a long playback line grew the contact column and pushed Back / Continue off the screen.
func test_long_subtitle_keeps_the_nav_on_screen() -> void:
	var saved: Vector2i = get_window().size
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		var s: BriefingScreen = _screen(Enums.Difficulty.ROUTINE)
		await wait_frames(2)
		s.subtitle_label.text = "The Halberd Gallery, darling. Aldous Parade. ".repeat(12)
		await wait_frames(3)
		var vis: Rect2 = get_viewport().get_visible_rect().grow(1.0)
		for b: Button in [s.back_button, s.continue_button, s.play_button]:
			assert_true(vis.encloses(b.get_global_rect()), "%s %s on screen at %s" % [b.text, b.get_global_rect(), size])
		s.queue_free()
		await wait_frames(1)
	get_window().size = saved


func test_model_from_a_heist_def() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = HEIST
	def.contact = &"contact.vance"
	def.briefing = "Literal briefing text."
	def.mode = Enums.HeistMode.LOUD_ONLY
	def.base_payout = 10000
	def.objectives = [&"casing", &"no_such_step", &"secure"] as Array[StringName]
	def.loot = [&"loot.cash"] as Array[StringName]
	def.escape_options = [&"boat", &"zeppelin"] as Array[StringName]
	var m: Dictionary = BriefingModel.build(HEIST, Enums.Difficulty.BRUTAL, def)
	assert_false(bool(m["placeholder"]))
	assert_eq((m["contact"] as ContactDef).id, &"contact.vance")
	assert_eq(m["briefing_text"], "Literal briefing text.")
	assert_eq(m["mode_key"], &"ui.heist_select.modes_loud_only")
	assert_eq(int(m["contract_pay"]), HeistCatalog.contract_preview(10000, Enums.Difficulty.BRUTAL))
	var obj: Array = m["objectives"] as Array
	assert_eq(String((obj[0] as Dictionary)["text"]), String(_strings["objective.glasshouse.casing"]))
	assert_eq(String((obj[1] as Dictionary)["text"]), "No such step", "missing key falls back to the id")
	assert_eq(String((obj[2] as Dictionary)["text"]), "Secure two bags", "counters stripped")
	var esc: Array = m["escape_options"] as Array
	assert_eq(String((esc[0] as Dictionary)["text"]), String(_strings["ui.briefing.escape.boat"]))
	assert_eq(String((esc[1] as Dictionary)["text"]), "Zeppelin")
	var lines: Array = m["voice_lines"] as Array
	assert_true(lines.size() >= 2)
	# Glasshouse's own contact (D-117 §6: briefing sets of contacts a heist does not have were removed).
	assert_eq(StringName((lines[0] as Dictionary)["speaker"]), &"vance")


## D-109 (lead ruling): briefing_objectives replaces the list, the loud branch is one line, extras sit under
## "Optional"; an empty briefing_objectives keeps every objective (the other heists stay as they are).
func test_briefing_subset_loud_line_and_optional() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = HEIST
	def.objectives = [&"casing", &"keycard", &"secure", &"escape"] as Array[StringName]
	var full: Dictionary = BriefingModel.build(HEIST, Enums.Difficulty.ROUTINE, def)
	assert_eq((full["objectives"] as Array).size(), 4, "no subset: every objective")
	assert_eq(String(full["loud_text"]), "")
	assert_true((full["optional"] as Array).is_empty())
	def.briefing_objectives = [&"casing", &"secure"] as Array[StringName]
	def.briefing_loud_key = &"objective.glasshouse.keycard"
	def.briefing_optional = [&"escape"] as Array[StringName]
	var m: Dictionary = BriefingModel.build(HEIST, Enums.Difficulty.ROUTINE, def)
	var obj: Array = m["objectives"] as Array
	assert_eq(obj.size(), 2)
	assert_eq(StringName((obj[1] as Dictionary)["id"]), &"secure")
	assert_eq(String(m["loud_text"]), String(_strings["objective.glasshouse.keycard"]))
	assert_eq(StringName(((m["optional"] as Array)[0] as Dictionary)["id"]), &"escape")
	var s: BriefingScreen = _screen(Enums.Difficulty.ROUTINE)
	await wait_frames(1)
	s.model = m
	s.call(&"_fill_objectives")
	await wait_frames(1)
	assert_eq(s.objective_texts().size(), 2, "the timeline is the subset")
	var shown: Array[String] = []
	for c: Node in s.extras_box.get_children():
		if c is Label and not c.is_queued_for_deletion():
			shown.append((c as Label).text)
	assert_has(shown, UiText.t(&"ui.briefing.if_loud", {"text": String(m["loud_text"])}))
	assert_has(shown, UiText.t(&"ui.briefing.optional"))
	assert_has(shown, UiText.t(&"ui.briefing.optional_line", {"text": String(((m["optional"] as Array)[0] as Dictionary)["text"])}))
	s.queue_free()
	await wait_frames(1)


func test_briefing_text_key_or_literal() -> void:
	assert_eq(BriefingModel.briefing_text(HEIST, "heist.glasshouse.briefing"), String(_strings["heist.glasshouse.briefing"]))
	assert_eq(BriefingModel.briefing_text(HEIST, "Plain words."), "Plain words.")
	assert_eq(BriefingModel.briefing_text(HEIST, ""), String(_strings["heist.glasshouse.briefing"]))
	assert_eq(BriefingModel.briefing_text(&"nowhere", ""), "")


func test_briefing_strings_exist() -> void:
	for k: String in ["ui.briefing.title", "ui.briefing.play", "ui.briefing.stop", "ui.briefing.continue",
			"ui.briefing.objectives", "ui.briefing.loot", "ui.briefing.escape", "ui.briefing.blueprint",
			"ui.briefing.blueprint_pending", "ui.briefing.subtitle", "ui.briefing.contract_pay",
			"heist.glasshouse.briefing"]:
		assert_has(_strings, k)
	for e: StringName in [&"van", &"boat", &"heli", &"walk"]:
		assert_has(_strings, "ui.briefing.escape.%s" % e)
	for o: Variant in _expected_objectives():
		if not String(o).contains("."):
			assert_has(_strings, "objective.glasshouse.%s" % o)


## C (GN-B1): canvases are carried rolled, not bagged; the briefing's loot price line must not say "per bag".
func test_loot_line_prices_each_not_per_bag() -> void:
	var t: String = UiText.t(&"ui.briefing.loot_line", {"loot": "Calloway's Study", "value": "$700"})
	assert_eq(t, "Calloway's Study: $700 each")
	assert_false(t.contains("bag"))


## D-109 windowed pass: Escape sat below the fold of the job column (ND, SL at 720p and 1080p); it is one line
## in the header now, under Approach.
func test_escape_line_sits_in_the_header() -> void:
	var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
	s.setup(&"night_deposit", Enums.Difficulty.HAZARDOUS)
	add_child(s)
	await wait_frames(2)
	assert_eq(s.escape_label.get_parent(), s.mode_label.get_parent(), "escape beside approach")
	var opts: String = "%s, %s" % [UiText.t(&"ui.briefing.escape.van"), UiText.t(&"ui.briefing.escape.boat")]
	assert_eq(s.escape_label.text, UiText.t(&"ui.briefing.escape_line", {"options": opts}))
	s.queue_free()


## r224 GN capture: the briefing's blueprint panel draws the heist's real pre-planning blueprint (read-only),
## not the "floor plans arrive" placeholder, for every heist that has one.
func test_briefing_shows_the_real_blueprint() -> void:
	for h: StringName in [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night"]:
		var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
		s.setup(h, Enums.Difficulty.ROUTINE)
		add_child(s)
		await wait_frames(2)
		assert_true(s.blueprint_view.visible, "%s: real blueprint shown" % h)
		assert_false(s.blueprint_view.board.blueprint.placeholder, "%s: not the placeholder" % h)
		assert_true(s.blueprint_view.size.x > 100.0 and s.blueprint_view.size.y > 100.0, "%s: fills the panel" % h)
		for b: Variant in s.blueprint_view.markers.values():
			assert_eq((b as Control).focus_mode, Control.FOCUS_NONE, "%s: markers are not focus stops" % h)
		s.queue_free()
		await wait_frames(1)


## B5-05 / S1.3: a civilian-start heist says so in the briefing (no shipped heist starts civilian yet, so the def is
## flipped in memory for the check).
func test_civilian_start_flag() -> void:
	var def: HeistDef = HeistRegistry.get_def(&"glasshouse")
	assert_true(def != null, "glasshouse def")
	if def == null:
		return
	assert_false(bool(BriefingModel.build(&"glasshouse", Enums.Difficulty.ROUTINE)["civilian_start"]), "casing start: no flag")
	var was: StringName = def.start_mode
	def.start_mode = &"civilian"
	assert_true(bool(BriefingModel.build(&"glasshouse", Enums.Difficulty.ROUTINE)["civilian_start"]))
	var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
	s.setup(&"glasshouse", Enums.Difficulty.ROUTINE)
	add_child(s)
	await wait_frames(2)
	assert_true(s.mode_label.text.contains(UiText.t(&"ui.briefing.civilian_start")), "shown: %s" % s.mode_label.text)
	def.start_mode = was
	s.queue_free()
	await wait_frames(1)
