## D-115 new-player flow (fresh profile): main menu -> hub (START HERE) -> first heist (Golden Hour, Routine) ->
## payday -> hub. Checks the B side of what a first-time player sees:
##   * every first-time card fires exactly once and in order (casing -> heist_glasshouse -> stealth -> loud ->
##     escape); a second run on the same profile shows none; START HERE (2D chip and 3D note) goes away once a
##     payday is banked;
##   * every key cap / prompt / hint the flow shows follows the CURRENT binding, also after a rebind
##     (interact F -> E, mask_up G -> Q, dismiss_tip H -> J) while the card is already open;
##   * no string the flow shows names a feature that is not built (FORBIDDEN, from the D-115 audit).
## Never touches the player's save or settings (per-process folders, OnboardingTips.persist = false).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const HUB_SCENE: PackedScene = preload("res://content/ui/hub/hub_menu.tscn")
const HEIST: StringName = &"glasshouse"
## The order a first Golden Hour run reaches the cards (casing card, its heist card, then the situations).
const ORDER: Array[StringName] = [&"casing", &"heist_glasshouse", &"stealth", &"loud", &"escape"]
## Rebinds of the test: action -> new key.
const REBINDS: Dictionary = {&"interact": KEY_E, &"mask_up": KEY_Q, &"dismiss_tip": KEY_J}
## D-115 audit: terms for features that do not exist (no Crime.net, no tutorial level, no shop / black market /
## infamy, no Options "show tips again" row, the unbuilt P5 heists, stub "coming soon" screens, the pager
## "operator" that is not a mechanic). Case-insensitive substrings.
const FORBIDDEN: Array[String] = ["crime.net", "crimenet", "crime net", "tutorial", "coming soon", "not in this build",
	"black market", "infamy", "steam", "dlc", "side job", "show tips again", "ostrander", "rolling thunder",
	"afterhours", "civilian mode", "operator gets suspicious"]
## strings.csv key prefixes the flow can put on screen (main menu, hub + stations' prompts, loading, briefing /
## pre-planning / objectives / loot of Golden Hour, the in-heist HUD and cards, payday).
const FLOW_PREFIXES: Array[String] = ["ui.menu.", "ui.hub.", "ui.prompt.", "ui.tip.", "ui.loading.", "ui.hud.",
	"ui.hint.", "ui.payday", "ui.blocked.", "ui.briefing.", "heist.glasshouse.", "objective.glasshouse.",
	"ui.preplan.bp.glasshouse.", "ui.key."]
## Keys under those prefixes that the flow never shows: the stub screen exists only when the launcher is missing.
const NOT_IN_FLOW: Array[String] = ["ui.menu.coming_soon"]

var _hud: Hud
var _model: MockHudModel
var _card: OnboardingCard
var _settings: GameSettings
var _log: Array[StringName] = []


func before_each() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	GameSettings.root_dir = BTestUtil.settings_root()
	_settings = GameSettings.new()
	GameSettings.set_current(_settings)
	InputBindings.apply(_settings)
	OnboardingTips.persist = false
	OnboardingTips.reset()
	InteractionPanel.pad_active = false


func after_each() -> void:
	await _teardown()
	InputBindings.apply(GameSettings.new())
	GameSettings.set_current(null)
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR
	OnboardingTips.persist = true
	OnboardingTips.reset()
	OnboardingTips._loaded = false
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _start_run() -> void:
	await _teardown()
	_log.clear()
	_model = MockHudModel.new()
	_model.casing = false
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	_hud.heist_id = HEIST
	add_child(_hud)
	await wait_frames(1)
	_hud.hint.capture_probe = func() -> bool: return true
	_card = _hud.onboarding
	_hud.bind(_model)


func _teardown() -> void:
	if _hud != null:
		_hud.queue_free()
		_hud = null
	if _model != null:
		_model.queue_free()
		_model = null
	await wait_frames(1)


## Advances the card's clock by `seconds` (small steps) and logs every card that opens.
func _play(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_card._process(0.25)
		t += 0.25
		if _card.shown != &"" and (_log.is_empty() or _log[-1] != _card.shown):
			_log.append(_card.shown)


func _row_caps() -> Array[String]:
	var out: Array[String] = []
	for row: Node in _card.rows_box.get_children():
		if row.is_queued_for_deletion():
			continue
		var first: Node = row.get_child(0)
		out.append(((first as PanelContainer).get_child(0) as Label).text if first is PanelContainer else "")
	return out


func _rebind_all() -> void:
	for a: StringName in REBINDS:
		var k: InputEventKey = InputEventKey.new()
		k.physical_keycode = REBINDS[a] as Key
		InputBindings.rebind(_settings, a, InputEventCodec.to_dict(k), false)
	InputBindings.apply(_settings)  # Options: copy_from (changed) then apply
	await wait_frames(2)  # the HUD redraws its key caps deferred


func test_cards_fire_once_and_in_order_across_the_first_heist() -> void:
	await _start_run()
	# Casing (walk in unmasked): the casing card, then (it times out) the Golden Hour card.
	_model.player_mode = &"casing"
	_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_card.step_label.text, UiText.t(&"ui.tip.step", {"n": 1, "total": 4}))
	_play(OnboardingCard.DWELL_S + OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_card.shown, &"heist_glasshouse", "the heist card follows the casing card")
	# Masking up while the heist card is open does not cut it short; the stealth card follows it.
	_model.masked = true
	_model.player_mode = &"masked"
	assert_eq(_card.shown, &"heist_glasshouse", "no situation replaces the heist card")
	_play(OnboardingCard.DWELL_S + OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_card.shown, &"stealth")
	# The alarm while the stealth card is still up: that card yields to the loud one.
	_model.heist_phase = Enums.HeistPhase.LOUD
	_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_card.shown, &"loud")
	assert_eq(_card.step_label.text, UiText.t(&"ui.tip.step", {"n": 3, "total": 4}))
	_model.heist_phase = Enums.HeistPhase.ESCAPE
	_play(OnboardingCard.DWELL_S + OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_log, ORDER, "each card once, in flow order")
	_play(OnboardingCard.DWELL_S * 2.0)
	assert_false(_card.visible, "nothing left to show")
	assert_eq(OnboardingTips.seen_ids(), ["casing", "stealth", "loud", "escape", "heist_glasshouse"])
	# Second run on the same profile: the same situations show no card at all.
	await _start_run()
	for mode: StringName in [&"casing", &"masked"]:
		_model.player_mode = mode
		_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	_model.heist_phase = Enums.HeistPhase.LOUD
	_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	_model.heist_phase = Enums.HeistPhase.ESCAPE
	_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_log, [] as Array[StringName], "second run: no first-time card")


func test_start_here_until_the_first_payday() -> void:
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_true(HubMenu.is_first_time(p), "fresh profile")
	var hub: HubMenu = HUB_SCENE.instantiate() as HubMenu
	add_child(hub)
	await wait_frames(1)
	hub.refresh_profile(p)
	assert_true(hub.start_here != null and hub.start_here.visible, "2D hub: START HERE on the Board card")
	var hud: SafehouseHud = SafehouseHud.new()
	add_child(hud)
	await wait_frames(1)
	hud.set_profile(p)
	assert_true(hud.start_here.visible, "3D safehouse: the START HERE note")
	assert_eq(hud.start_here_prompt.text, UiText.t(&"ui.hub.start_here_walk", {"key": "F"}))
	# A failed first run still counts as played (Career.record at payday).
	Career.record(p, {"heist_id": String(HEIST), "success": false, "difficulty": Enums.Difficulty.ROUTINE},
			{"success": false}, -1)
	SaveService.save_profile(p, 0)
	var back: PlayerProfile = SaveService.load_profile(0)
	assert_false(HubMenu.is_first_time(back), "one payday on the record")
	hub.refresh_profile(back)
	assert_false(hub.start_here.visible, "2D hub: START HERE gone after the first payday")
	hud.set_profile(back)
	assert_false(hud.start_here.visible, "3D safehouse: note gone after the first payday")
	hub.queue_free()
	hud.queue_free()
	await wait_frames(1)


func test_rebinding_changes_every_key_the_flow_shows() -> void:
	await _start_run()
	_model.player_mode = &"casing"
	_play(OnboardingCard.SHOW_DELAY_S + 1.0)
	assert_eq(_card.shown, &"casing")
	assert_eq(_row_caps(), ["", "", "", "G"] as Array[String], "default: hold G to mask up")
	assert_eq(_hud.hint.prompt.cap_label.text, "G")
	assert_eq(_card.footer.cap_label.text, "H")
	_model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {}, "progress": 0.0, "blocked_reason": &""}
	assert_eq(_hud.interaction.prompt.cap_label.text, "F")
	await _rebind_all()
	# The open card, the hint strip and the prompt follow the rebind without any model change.
	assert_eq(_row_caps(), ["", "", "", "Q"] as Array[String], "open card: the mask row reads Q")
	assert_eq(_card.footer.cap_label.text, "J", "open card: Press J to close")
	assert_eq(_hud.hint.prompt.cap_label.text, "Q", "hint strip: Hold Q to mask up")
	assert_eq(_hud.interaction.prompt.text, UiText.t(&"ui.prompt.pick_lock", {"key": "E"}))
	# A mask-up prompt names the mask key, not interact.
	_model.interaction = {"text_key": &"ui.prompt.mask_up", "args": {}, "progress": 0.0, "blocked_reason": &""}
	assert_eq(_hud.interaction.prompt.text, UiText.t(&"ui.prompt.mask_up", {"key": "Q"}))
	_model.interaction = {"text_key": &"ui.prompt.use_keycard", "args": {}, "progress": 0.0,
			"blocked_reason": &"ui.blocked.casing"}
	assert_eq(_hud.interaction.blocked_label.text, UiText.t(&"ui.blocked.casing", {"mask_key": "Q"}),
			"blocked reason: Mask up first (hold Q)")
	# Casing toast ("Mask up to sprint ({key})").
	_hud._on_casing_blocked(&"sprint")
	assert_eq(_hud.toast_label.text, UiText.t(&"ui.hud.casing_blocked.sprint", {"key": "Q"}))
	# The cards still to come use the new keys too.
	_card.dismiss()
	_play(OnboardingCard.SHOW_DELAY_S + 0.5)
	assert_eq(_card.shown, &"heist_glasshouse")
	assert_true(_row_caps().has("E") and not _row_caps().has("F"), "heist card: interact row reads E")
	_card.dismiss()
	_model.masked = true
	_model.player_mode = &"masked"
	_play(OnboardingCard.SHOW_DELAY_S + 0.5)
	assert_eq(_card.shown, &"stealth")
	assert_true(_row_caps().has("E") and not _row_caps().has("F"), "stealth card: interact row reads E")
	_model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	assert_eq(_hud.hint.hint, &"throw_bag")
	assert_eq(_hud.hint.prompt.cap_label.text, InteractionPanel.action_key_text(&"drop_bag"))
	# The walked hub: the START HERE note and a station prompt read E.
	var sh: SafehouseHud = SafehouseHud.new()
	add_child(sh)
	await wait_frames(1)
	sh.set_profile(SaveService.load_profile(0))
	assert_eq(sh.start_here_prompt.cap_label.text, "E")
	var stand_in: MockHudModel = MockHudModel.new()
	add_child(stand_in)
	sh.bind_model(stand_in)
	stand_in.interaction = {"text_key": &"ui.prompt.station.board", "args": {}, "progress": 0.0, "blocked_reason": &""}
	assert_eq(sh.prompt_text(), UiText.t(&"ui.prompt.station.board", {"key": "E"}))
	# Rebinding back while the hub is shown redraws it.
	InputBindings.reset_all(_settings)
	InputBindings.apply(_settings)
	await wait_frames(2)
	assert_eq(sh.start_here_prompt.cap_label.text, "F", "reset: the note reads F again")
	assert_eq(_row_caps().has("F"), true, "reset: the open stealth card reads F again")
	sh.queue_free()
	stand_in.queue_free()
	await wait_frames(1)


func test_no_hard_coded_game_keys_in_flow_strings() -> void:
	# A rebindable action's key must come from {key} (InputMap), never from the text itself.
	var rx: RegEx = RegEx.create_from_string("\\b([Pp]ress|[Hh]old|[Tt]ap)\\s+\\[?[A-Z0-9]\\]?(?!\\w)")
	var keys_rx: RegEx = RegEx.create_from_string("\\[[A-Z]\\]")
	for k: String in _flow_keys():
		var text: String = UiText.t(StringName(k))
		assert_true(rx.search(text) == null and keys_rx.search(text) == null, "%s spells a key: %s" % [k, text])


func test_no_flow_string_names_an_unbuilt_feature() -> void:
	var keys: Array[String] = _flow_keys()
	assert_true(keys.size() > 150, "flow strings found (%d)" % keys.size())
	for k: String in keys:
		var low: String = UiText.t(StringName(k)).to_lower()
		for term: String in FORBIDDEN:
			assert_false(low.contains(term), "%s mentions '%s': %s" % [k, term, low])
	# Every heist the menus offer is built (map + def): the Board / Planning Table never list a P5 stub.
	for e: Dictionary in HeistCatalog.entries():
		assert_true(HeistCatalog.has_map(StringName(e["id"])), "%s offered with a map" % e["id"])


func _flow_keys() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in StringTable.parse_csv(StringTable.CSV_PATH):
		var key: String = String(k)
		if NOT_IN_FLOW.has(key):
			continue
		for pre: String in FLOW_PREFIXES:
			if key.begins_with(pre):
				out.append(key)
				break
	return out


## The first real Golden Hour run (D-115 capture): ENV A's LocalHudModel has no v1.16 `scoped_ads` yet, and
## bool(null) threw in Hud._process every frame (toasts and the card's visibility rules never ran).
func test_hud_process_survives_a_model_without_scope_fields() -> void:
	await _start_run()
	var bare: Node = Node.new()
	add_child(bare)
	_hud.model = bare
	_hud._avoid_scope()
	_hud._process(0.1)
	assert_eq(_hud.device_timers.avoid, Rect2(), "no scope ring: nothing avoided")
	_hud.model = _model
	bare.queue_free()
