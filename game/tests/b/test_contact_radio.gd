## B7-03: contact radio (ContactRadio / RadioLinePicker / RadioTweak) and SubtitleOverlay.
## Facts are driven by emitting EventBus signals directly (what every peer receives from [R] relays); the radio and
## overlay clocks are stepped by hand (auto_process = false).
extends TestCase

const HEISTS: Dictionary = {
	&"glasshouse": &"vance", &"night_deposit": &"accountant", &"shadow_ledger": &"accountant",
	&"dockside_burn": &"reyes", &"gallery_night": &"vance",
}
## Heists whose radio lines exist before their HeistDef is registered (`contact_for` cannot resolve them yet).
## Move each into HEISTS when its def lands (Gallery Night did with C's G1, trunk 55ce4d2a).
const DRAFT_HEISTS: Dictionary = {}
## Strings key suffixes of an objective's text variants, not objectives of their own: the loud text
## (objective.gallery_night.hack_loud) and Gallery Night's last-call casing text (casing_last_call; the mission
## re-adds `casing` with it, so the radio line keyed to it was never said: removed by the D-117 §6 VO audit).
const TEXT_VARIANT_SUFFIXES: Array[String] = ["_loud", "_last_call"]
const RADIO_EVENTS: Array[StringName] = [
	&"radio.objective_done", &"radio.objective_new", &"radio.objective_failed", &"radio.alarm",
	&"radio.assault_build", &"radio.assault_sustain", &"radio.assault_fade", &"radio.escape_available",
	&"radio.escape", &"radio.loot_secured",
]
const CONTACT_SPEAKERS: Array[StringName] = [&"vance", &"reyes", &"accountant", &"mercer"]

var _strings: Dictionary = {}
var _table: VoiceLineTable = null
var _saved_settings: GameSettings = null


func before_all() -> void:
	_strings = StringTable.parse_csv()
	_table = load(ContactRadio.LINES_PATH) as VoiceLineTable
	_saved_settings = GameSettings.current()


func before_each() -> void:
	GameSettings.set_current(GameSettings.new())
	GameRng.begin_run(1234)


func after_each() -> void:
	for c: Node in get_children():
		if c is ContactRadio or c is SubtitleOverlay:
			c.queue_free()
	GameSettings.set_current(_saved_settings)
	await wait_frames(1)


func _radio(heist: StringName) -> ContactRadio:
	var r: ContactRadio = ContactRadio.new()
	r.auto_process = false
	r.setup(heist)
	add_child(r)
	return r


## Steps the radio clock and returns the line ids it spoke.
func _run(r: ContactRadio, seconds: float, step: float = 0.25) -> Array[StringName]:
	var out: Array[StringName] = []
	var cb: Callable = func(_sp: StringName, id: StringName, _ev: StringName) -> void: out.append(id)
	r.line_spoken.connect(cb)
	var t: float = 0.0
	while t < seconds:
		r.advance(step)
		t += step
	r.line_spoken.disconnect(cb)
	return out


func _first_sight(ids: Array[StringName], state: int = Enums.ObjectiveState.ACTIVE) -> void:
	for id: StringName in ids:
		EventBus.objective_updated.emit(id, state, {})


# --- Contacts and data --------------------------------------------------------------------

func test_each_heist_uses_its_contact() -> void:
	var tw: RadioTweak = RadioTweak.load_default()
	for heist: StringName in HEISTS:
		var c: ContactDef = ContactRadio.contact_for(heist, tw)
		assert_true(c != null, "contact for %s" % heist)
		if c != null:
			assert_eq(c.voice_speaker, HEISTS[heist], "%s radio speaker" % heist)
	assert_eq(ContactRadio.contact_for(&"no_such_heist", tw).voice_speaker, &"mercer", "fallback is the handler")
	var custom: RadioTweak = tw.duplicate() as RadioTweak
	custom.speaker_overrides = {&"glasshouse": &"contact.reyes"}
	assert_eq(ContactRadio.contact_for(&"glasshouse", custom).voice_speaker, &"reyes", "override wins")


func test_generic_lines_per_contact_and_fact() -> void:
	var p: RadioLinePicker = RadioLinePicker.new(_table)
	for sp: StringName in CONTACT_SPEAKERS:
		for ev: StringName in RADIO_EVENTS:
			assert_true(p.generic_lines(ev, sp).size() >= 3, "%s has >= 3 generic %s lines" % [sp, ev])


## Every objective `[tag]` of the four heists (design doc, else the objective.<heist>.* strings) has a radio line
## from that heist's contact; escape and loot have heist lines too.
func test_every_heist_objective_has_a_radio_line() -> void:
	var p: RadioLinePicker = RadioLinePicker.new(_table)
	var heists: Dictionary = _radio_heists()
	for heist: StringName in heists:
		var sp: StringName = heists[heist]
		var tags: Array[String] = _objective_tags(heist)
		assert_true(tags.size() >= 7, "%s objective tags found (%d)" % [heist, tags.size()])
		for tag: String in tags:
			var n: int = 0
			for ev: StringName in [&"radio.objective_done", &"radio.objective_new"]:
				n += p.heist_lines(ev, sp, heist, {"objective": StringName(tag)}).size()
			assert_true(n >= 1, "%s objective [%s] has a radio line" % [heist, tag])
		for ev: StringName in [&"radio.escape_available", &"radio.escape", &"radio.loot_secured"]:
			assert_true(p.heist_lines(ev, sp, heist, {}).size() >= 1, "%s has a heist %s line" % [heist, ev])


## Every radio line is well formed and every vo.* id the radio data or B code uses has its voice.<id> text.
func test_every_vo_id_used_has_strings() -> void:
	var radio: int = 0
	var heists: Dictionary = _radio_heists()
	for l: Dictionary in _table.lines:
		var ev: String = String(l.get("event", &""))
		if not ev.begins_with("radio."):
			continue
		radio += 1
		var id: String = String(l["id"])
		assert_has(_strings, "voice.%s" % id, "text of %s" % id)
		assert_true(String(_strings.get("voice.%s" % id, "")).length() > 3, "non-empty text for %s" % id)
		assert_eq(int(l["priority"]), RadioTweak.load_default().priority_of(StringName(ev)), "priority of %s" % id)
		if l.has("heist"):
			assert_true(heists.has(StringName(l["heist"])), "heist of %s" % id)
			assert_eq(StringName(l["speaker"]), heists.get(StringName(l["heist"]), &""), "%s is spoken by the heist's contact" % id)
		if l.has("objective"):
			assert_has(_objective_tags(StringName(l["heist"])), String(l["objective"]), "objective of %s is a doc tag" % id)
		if l.has("loot"):
			assert_true(ContentDB.has(&"loot", StringName(l["loot"])), "loot of %s" % id)
	assert_true(radio >= 150, "radio lines: %d" % radio)
	var rx: RegEx = RegEx.create_from_string("&\"(vo\\.[a-z]+\\.[a-z0-9_]+)\"")
	for path: String in ["res://content/radio/contact_radio.gd", "res://content/ui/hud/subtitle_overlay.gd"]:
		for m: RegExMatch in rx.search_all(FileAccess.get_file_as_string(path)):
			assert_has(_strings, "voice.%s" % m.get_string(1), "used in %s" % path)
	assert_has(_strings, String(SubtitleOverlay.SPEAKER_KEY))


# --- Selection ----------------------------------------------------------------------------

func test_heist_line_overrides_generic() -> void:
	var p: RadioLinePicker = RadioLinePicker.new(_table)
	var rng: RandomNumberGenerator = GameRng.stream(&"radio")
	var l: Dictionary = p.pick(&"radio.objective_done", &"vance", &"glasshouse", {"objective": &"safe"}, 0.0, rng)
	assert_eq(l.get("id"), &"vo.vance.glasshouse_radio_safe", "the heist line for [safe]")
	var g: Dictionary = p.pick(&"radio.objective_done", &"vance", &"glasshouse", {"objective": &"nothing"}, 1.0, rng)
	assert_false(g.has("heist"), "unknown objective -> generic line")
	assert_eq(StringName(g.get("speaker")), &"vance")
	var other: Dictionary = p.pick(&"radio.objective_done", &"vance", &"night_deposit", {"objective": &"safe"}, 2.0, rng)
	assert_false(other.has("heist"), "another heist's lines never leak")
	var loot: Dictionary = p.pick(&"radio.loot_secured", &"reyes", &"dockside_burn", {"loot_id": &"loot.weapon_crate"},
			3.0, rng)
	assert_eq(StringName(loot.get("heist", &"")), &"dockside_burn", "heist loot line")
	assert_true(not loot.has("loot") or StringName(loot["loot"]) == &"loot.weapon_crate", "loot filter")


func test_cooldown_and_no_repeat() -> void:
	var p: RadioLinePicker = RadioLinePicker.new(_table, 2)
	var rng: RandomNumberGenerator = GameRng.stream(&"radio")
	var picks: Array[StringName] = []
	for i: int in range(9):
		picks.append(StringName(p.pick(&"radio.alarm", &"reyes", &"", {}, float(i), rng).get("id")))
	for i: int in range(1, picks.size()):
		assert_ne(picks[i], picks[i - 1], "no line twice in a row (%d)" % i)
		if i >= 2:
			assert_ne(picks[i], picks[i - 2], "no-repeat depth 2 (%d)" % i)
	# Heist loot lines: cooldown_s 30 -> after both Glasshouse loot lines played, generic Vance lines fill in.
	var q: RadioLinePicker = RadioLinePicker.new(_table, 2)
	var ctx: Dictionary = {"loot_id": &"loot.jewelry"}
	var a: Dictionary = q.pick(&"radio.loot_secured", &"vance", &"glasshouse", ctx, 0.0, rng)
	var b: Dictionary = q.pick(&"radio.loot_secured", &"vance", &"glasshouse", ctx, 1.0, rng)
	var c: Dictionary = q.pick(&"radio.loot_secured", &"vance", &"glasshouse", ctx, 2.0, rng)
	assert_eq(StringName(a.get("heist", &"")), &"glasshouse")
	assert_eq(StringName(b.get("heist", &"")), &"glasshouse")
	assert_ne(a.get("id"), b.get("id"))
	assert_false(c.has("heist"), "heist lines on cooldown -> generic")
	var d: Dictionary = q.pick(&"radio.loot_secured", &"vance", &"glasshouse", ctx, 40.0, rng)
	assert_eq(StringName(d.get("heist", &"")), &"glasshouse", "cooldown over -> heist line again")
	# All candidates cooling down -> nothing.
	var tw: VoiceLineTable = VoiceLineTable.new()
	tw.lines = [{"id": &"vo.reyes.x", "speaker": &"reyes", "event": &"radio.alarm", "cooldown_s": 10.0, "priority": 1}]
	var only: RadioLinePicker = RadioLinePicker.new(tw)
	assert_eq(only.pick(&"radio.alarm", &"reyes", &"", {}, 0.0, rng).get("id"), &"vo.reyes.x")
	assert_eq(only.pick(&"radio.alarm", &"reyes", &"", {}, 5.0, rng), {}, "on cooldown")
	assert_eq(only.pick(&"radio.alarm", &"reyes", &"", {}, 10.0, rng).get("id"), &"vo.reyes.x", "single line repeats")


func _script(r: ContactRadio) -> Array[StringName]:
	var out: Array[StringName] = []
	_first_sight([&"breach", &"product", &"burn", &"secure"])
	EventBus.objective_updated.emit(&"burn", Enums.ObjectiveState.HIDDEN, {})
	out.append_array(_run(r, 1.0))
	EventBus.alarm_raised.emit(&"camera", 0)
	out.append_array(_run(r, 8.0))
	for i: int in range(6):
		EventBus.loot_secured.emit(100 + i, &"loot.cash_bricks", 5000)
		out.append_array(_run(r, 14.0))
	for phase: int in [Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN, Enums.AssaultPhase.FADE]:
		EventBus.assault_phase_changed.emit(phase, 0)
		out.append_array(_run(r, 8.0))
	return out


func test_deterministic_per_seed() -> void:
	GameRng.begin_run(77)
	var a: ContactRadio = _radio(&"dockside_burn")
	var first: Array[StringName] = _script(a)
	a.queue_free()
	await wait_frames(1)
	GameRng.begin_run(77)
	var b: ContactRadio = _radio(&"dockside_burn")
	var second: Array[StringName] = _script(b)
	assert_true(first.size() >= 8, "lines spoken: %s" % [first])
	assert_eq(second, first, "same seed, same facts -> same lines")
	b.queue_free()
	await wait_frames(1)
	var differs: bool = false
	for s: int in [5, 6, 7, 8, 9]:
		GameRng.begin_run(s)
		var c: ContactRadio = _radio(&"dockside_burn")
		differs = differs or _script(c) != first
		c.queue_free()
		await wait_frames(1)
	assert_true(differs, "another seed picks other variants")


# --- Facts -> events ---------------------------------------------------------------------

func test_facts_map_to_radio_events() -> void:
	var r: ContactRadio = _radio(&"glasshouse")
	var events: Array[StringName] = []
	r.line_spoken.connect(func(_s: StringName, _id: StringName, ev: StringName) -> void: events.append(ev))
	_first_sight([&"safe", &"safe_loot"])
	EventBus.objective_updated.emit(&"safe_loot", Enums.ObjectiveState.HIDDEN, {})
	_run(r, 8.0)
	assert_eq(events, [] as Array[StringName], "first sight of objectives is silent")
	EventBus.objective_updated.emit(&"safe", Enums.ObjectiveState.COMPLETED, {})
	_run(r, 8.0)
	EventBus.objective_updated.emit(&"safe_loot", Enums.ObjectiveState.ACTIVE, {})
	_run(r, 8.0)
	EventBus.alarm_raised.emit(&"glass_alarm", 0)
	_run(r, 8.0)
	EventBus.alarm_raised.emit(&"camera", 0)
	_run(r, 8.0)
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.ANTICIPATION, 0)
	_run(r, 8.0)
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 0)
	_run(r, 8.0)
	EventBus.heist_phase_changed.emit(Enums.HeistPhase.LOUD, Enums.HeistPhase.ESCAPE)
	_run(r, 8.0)
	EventBus.audio_cue_requested.emit(&"cue.escape_arrive_van", Vector3.ZERO, 5)
	_run(r, 8.0)
	EventBus.loot_secured.emit(1, &"loot.body_bag", 0)
	_run(r, 8.0)
	EventBus.loot_secured.emit(2, &"loot.jewelry", 9000)
	_run(r, 8.0)
	assert_eq(events, [&"radio.objective_done", &"radio.objective_new", &"radio.alarm", &"radio.assault_build",
		&"radio.escape_available", &"radio.escape", &"radio.loot_secured"] as Array[StringName],
		"one line per fact; alarm once; anticipation silent; body bags ignored")


func test_radio_emits_local_voice_line_with_hook_context() -> void:
	var r: ContactRadio = _radio(&"dockside_burn")
	var got: Array = []
	var cb: Callable = func(sp: StringName, id: StringName, ctx: Dictionary) -> void: got.append([sp, id, ctx])
	EventBus.voice_line_requested.connect(cb)
	EventBus.alarm_raised.emit(&"camera", 0)
	_run(r, 2.0)
	EventBus.voice_line_requested.disconnect(cb)
	assert_eq(got.size(), 1)
	if got.size() == 1:
		assert_eq(got[0][0], &"reyes", "Dockside is Reyes")
		assert_true(String(got[0][1]).begins_with("vo.reyes.radio_alarm_"))
		var ctx: Dictionary = got[0][2]
		assert_eq(ctx.get("source"), ContactRadio.SOURCE)
		assert_eq(ctx.get("radio"), true, "squelch hook flag for C's voice player")
		assert_eq(ctx.get("heist_id"), &"dockside_burn")


func test_settle_priority_and_heist_end() -> void:
	var r: ContactRadio = _radio(&"glasshouse")
	assert_true(r.request(&"radio.loot_secured", {"loot_id": &"loot.jewelry"}))
	assert_true(r.request(&"radio.alarm"), "higher priority replaces the waiting fact")
	assert_false(r.request(&"radio.objective_done", {"objective": &"safe"}), "lower priority than the waiting alarm")
	var spoken: Array[StringName] = _run(r, 0.5)
	assert_eq(spoken.size(), 0, "nothing before settle_s")
	spoken = _run(r, 1.0)
	assert_eq(spoken.size(), 1)
	EventBus.heist_ended.emit({"heist_id": &"glasshouse", "success": true})
	assert_false(r.request(&"radio.escape"), "silent after the heist ended")


# --- Mission-line suppression -------------------------------------------------------------

func test_mission_line_suppresses_radio() -> void:
	var r: ContactRadio = _radio(&"glasshouse")
	# The mission says its escape line in the same frame as the phase change: the radio stays quiet.
	EventBus.heist_phase_changed.emit(Enums.HeistPhase.LOUD, Enums.HeistPhase.ESCAPE)
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.glasshouse_escape", {})
	assert_true(r.is_suppressed())
	assert_eq(_run(r, 2.0).size(), 0, "waiting fact dropped by the mission line")
	assert_false(r.request(&"radio.loot_secured", {"loot_id": &"loot.jewelry"}), "dropped while suppressed")
	_run(r, maxf(r.tweak.mission_suppress_s, r.tweak.max_s))
	assert_false(r.is_suppressed(), "suppression is brief")
	assert_true(r.request(&"radio.loot_secured", {"loot_id": &"loot.jewelry"}))
	assert_eq(_run(r, 2.0).size(), 1, "the radio speaks again")
	# The mission line right after the fact (inside settle_s) still wins.
	EventBus.alarm_raised.emit(&"camera", 0)
	r.advance(0.25)
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.glasshouse_lockdown", {})
	assert_eq(_run(r, 3.0).size(), 0, "no doubling with a mission line inside the settle window")
	# Non-comms speakers (guards, crew AI) and our own lines never suppress.
	_run(r, 10.0)
	EventBus.voice_line_requested.emit(&"guard", &"vo.guard.cuff_warning", {})
	EventBus.voice_line_requested.emit(&"vance", &"vo.vance.radio_alarm_1", {"source": ContactRadio.SOURCE})
	assert_false(r.is_suppressed())


# --- Subtitles ----------------------------------------------------------------------------

func _overlay() -> SubtitleOverlay:
	var o: SubtitleOverlay = SubtitleOverlay.new()
	o.auto_process = false
	add_child(o)
	return o


## Options parity: Accessibility > Subtitles off hides every in-heist line; on again shows them.
func test_subtitles_off_hides_lines() -> void:
	var s: GameSettings = GameSettings.current()
	var o: SubtitleOverlay = _overlay()
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitles", false)
	assert_false(o.show_line(&"reyes", &"vo.reyes.radio_alarm_1", {"source": ContactRadio.SOURCE}), "off: no radio line")
	assert_true(o.rows.is_empty())
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitles", true)
	assert_true(o.show_line(&"reyes", &"vo.reyes.radio_alarm_1", {"source": ContactRadio.SOURCE}), "on again")
	o.queue_free()


func test_subtitle_size_follows_setting() -> void:
	var s: GameSettings = GameSettings.current()
	var o: SubtitleOverlay = _overlay()
	assert_eq(o.font_size(), o.tweak.font_size_for("medium"), "default medium")
	assert_true(o.show_line(&"reyes", &"vo.reyes.radio_alarm_1", {"source": ContactRadio.SOURCE}))
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitle_size", "large")
	assert_eq(o.font_size(), 36)
	var lbl: Label = o.rows[0]["text"] as Label
	assert_eq(lbl.get_theme_font_size(&"font_size"), 36, "existing rows follow live")
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitle_size", "small")
	assert_eq(lbl.get_theme_font_size(&"font_size"), 22)
	assert_true(o.show_line(&"mercer", &"vo.mercer.glasshouse_intro", {}))
	assert_eq((o.rows[1]["speaker"] as Label).get_theme_font_size(&"font_size"), 22, "new rows use the setting")


func test_subtitle_rows_speaker_text_timing() -> void:
	var o: SubtitleOverlay = _overlay()
	assert_true(o.show_line(&"accountant", &"vo.mercer.shadow_ledger_escape", {"escape": &"ui.escape.heli"}))
	var row: Dictionary = o.rows[0]
	assert_true((row["speaker"] as Label).text.begins_with("The Accountant"), "speaker name")
	assert_true((row["text"] as Label).text.contains("helicopter"), "ctx string keys are translated")
	var acc: Color = ContactDef.find(&"contact.accountant").accent_color
	assert_true(UiAccent.contrast_ratio(row["color"] as Color, UiAccent.over(o.tweak.panel_color, Color.BLACK)) >= 4.5)
	assert_near((row["color"] as Color).h, acc.h, 0.05, "contact accent hue")
	assert_false(o.show_line(&"guard", &"vo.guard.cuff_warning", {}), "guards are not subtitled by default")
	assert_false(o.show_line(&"vance", &"vo.vance.briefing_glasshouse_1", {"source": &"briefing"}), "no briefing")
	var short_t: float = o.tweak.display_s("Go.")
	var long_t: float = o.tweak.display_s("x".repeat(80))
	assert_true(long_t > short_t, "time scales with length")
	o.advance(float(row["total"]) - o.tweak.fade_s * 0.5)
	assert_true((row["panel"] as Control).modulate.a < 0.99, "fading at the end")
	o.advance(o.tweak.fade_s)
	assert_eq(o.rows.size(), 0, "gone after its time")
	for i: int in range(4):
		o.show_line(&"reyes", StringName("vo.reyes.radio_alarm_%d" % (i % 3 + 1)), {"source": ContactRadio.SOURCE})
	assert_eq(o.rows.size(), o.tweak.max_lines, "oldest rows dropped")


func test_radio_lines_reach_the_overlay_and_stay_clear_of_the_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var r: ContactRadio = ContactRadio.spawn(layer, &"night_deposit")
	r.auto_process = false
	r.overlay.auto_process = false
	await wait_frames(1)
	EventBus.alarm_raised.emit(&"camera", 0)
	_run(r, 2.0)
	assert_eq(r.overlay.rows.size(), 1, "the radio line is subtitled")
	assert_true((r.overlay.rows[0]["speaker"] as Label).text.begins_with("The Accountant"))
	# Clear of the vitals (bottom-left) and ammo (bottom-right) panels at the base size, up to hud_scale 1.5.
	var base: Vector2 = Vector2(1920, 1080)
	var half: float = r.tweak.width_px * 0.5
	for s: float in [1.0, 1.5]:
		var vitals_right: float = 48.0 + 340.0 * s
		var ammo_left: float = base.x - 48.0 - 340.0 * s
		assert_true(base.x * 0.5 - half >= vitals_right, "clear of vitals at scale %s" % s)
		assert_true(base.x * 0.5 + half <= ammo_left, "clear of ammo at scale %s" % s)
	assert_eq(r.overlay.anchor_left, 0.5)
	assert_eq(r.overlay.anchor_top, 1.0)
	layer.queue_free()


# --- helpers ------------------------------------------------------------------------------

## D-039: objective ids = the heist design doc's Objectives `[tag]`s (else the objective.<heist>.* strings).
func _objective_tags(heist: StringName) -> Array[String]:
	var tags: Array[String] = []
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/heists/%s.md" % heist)
	if FileAccess.file_exists(doc):
		var sec: String = FileAccess.get_file_as_string(doc).get_slice("## Objectives", 1).get_slice("\n## ", 0)
		var rx: RegEx = RegEx.create_from_string("`\\[([a-z_]+)\\]`")
		for m: RegExMatch in rx.search_all(sec):
			if not tags.has(m.get_string(1)):
				tags.append(m.get_string(1))
	var prefix: String = "objective.%s." % heist
	for k: Variant in _strings:
		var tag: String = String(k).trim_prefix(prefix)
		# `<tag>_loud` / `<tag>_last_call` are texts of objective <tag> (the mission swaps them), not objectives.
		var variant: bool = false
		for suffix: String in TEXT_VARIANT_SUFFIXES:
			variant = variant or (tag.ends_with(suffix) and tags.has(tag.trim_suffix(suffix)))
		if variant:
			continue
		if String(k).begins_with(prefix) and not tags.has(tag):
			tags.append(tag)
	return tags


## Registered heists plus DRAFT_HEISTS: the heists whose radio lines are checked.
func _radio_heists() -> Dictionary:
	var out: Dictionary = HEISTS.duplicate()
	out.merge(DRAFT_HEISTS)
	return out


## Lead ruling: guard barks / crew acks get subtitles only with Options › Accessibility › subtitles_all_speakers.
func test_guard_and_crew_subtitles_behind_the_toggle() -> void:
	var s: GameSettings = GameSettings.current()
	var o: SubtitleOverlay = _overlay()
	assert_false(bool(s.get_value(GameSettings.ACCESSIBILITY, &"subtitles_all_speakers")), "default off")
	assert_false(o.show_line(&"guard", &"vo.guard.cuff_warning", {}), "guard bark hidden by default")
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitles_all_speakers", true)
	assert_true(o.show_line(&"guard", &"vo.guard.cuff_warning", {}), "shown once the toggle is on")
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitles_all_speakers", false)


## P fresh-eyes #9: subtitles sit above the bottom HUD band on a readable backing.
func test_subtitles_clear_the_bottom_band_on_a_solid_backing() -> void:
	var o: SubtitleOverlay = _overlay()
	await wait_frames(1)
	assert_true(o.tweak.bottom_margin_px >= 90.0, "lifted out of the vitals / ammo band")
	assert_true(o.tweak.panel_color.a >= 0.8, "backing alpha %.2f" % o.tweak.panel_color.a)
	assert_true(o.tweak.bottom_margin_px + o.tweak.max_height_px <= 354.0, "stays under the interaction prompt (hud_scale 1.5)")
	o.queue_free()

