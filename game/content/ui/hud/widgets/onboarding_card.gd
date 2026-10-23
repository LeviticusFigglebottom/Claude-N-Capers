## PO-4 lane 11 (lead ruling): first-time onboarding cards, one per situation, shown the first time it
## arises rather than as one wall of text:
##   casing  - player_mode &"casing"            (walk in, look around, doors vs locks, hold G to mask up)
##   stealth - masked, no alarm yet             (guards / cameras / pagers, interact, carry / throw bags)
##   loud    - heist_phase LOUD or an assault   (waves, hostages, keep moving the loot)
##   escape  - heist_phase ESCAPE               (the getaway, unsecured bags, whole crew in the zone)
## A card shows SHOW_DELAY_S after its situation starts, stays DWELL_S (a thin bar drains) and closes
## early on the dismiss_tip action (D-096). Row key caps and the footer follow the current binding (D-115: also
## after a rebind while the card is open). Shown ids are stored in the profile (OnboardingTips), so each card appears
## once per profile. A new unseen situation replaces the open card (its situation is over).
## D-115: each built heist (OnboardingTips.HEISTS) also has one card for its own mechanics. It queues behind the
## situation cards: it shows once a heist situation is up and that situation's card is already seen (so on a first run
## right after the casing / loud card, on later runs at heist start). No situation replaces it; the counter slot names
## the heist instead of "n/4". Owner: ENV B.
class_name OnboardingCard
extends HudWidget

const DWELL_S: float = 14.0
const SHOW_DELAY_S: float = 1.2
## D-096 input action (H / pad D-pad right); DISMISS_KEY is the fallback before the action exists.
const DISMISS_ACTION: StringName = &"dismiss_tip"
const DISMISS_KEY: Key = KEY_H
const WIDTH: float = 600.0
## tip id -> rows [input action (&"" = bullet), strings key].
const ROWS: Dictionary = {
	&"casing": [[&"", &"ui.tip.casing.1"], [&"", &"ui.tip.casing.2"], [&"", &"ui.tip.casing.3"],
			[&"mask_up", &"ui.tip.casing.mask"]],
	&"stealth": [[&"", &"ui.tip.stealth.1"], [&"", &"ui.tip.stealth.2"], [&"interact", &"ui.tip.stealth.interact"],
			[&"drop_bag", &"ui.tip.stealth.throw"]],
	&"loud": [[&"", &"ui.tip.loud.1"], [&"shout", &"ui.tip.loud.shout"], [&"", &"ui.tip.loud.3"]],
	&"escape": [[&"", &"ui.tip.escape.1"], [&"", &"ui.tip.escape.2"], [&"", &"ui.tip.escape.3"]],
	&"heist_glasshouse": [[&"", &"ui.tip.heist_glasshouse.1"], [&"", &"ui.tip.heist_glasshouse.2"],
			[&"interact", &"ui.tip.heist_glasshouse.interact"], [&"", &"ui.tip.heist_glasshouse.drill"]],
	&"heist_night_deposit": [[&"", &"ui.tip.heist_night_deposit.1"], [&"", &"ui.tip.heist_night_deposit.2"],
			[&"", &"ui.tip.heist_night_deposit.lasers"], [&"", &"ui.tip.heist_night_deposit.ecm"]],
	&"heist_shadow_ledger": [[&"", &"ui.tip.heist_shadow_ledger.cage"], [&"", &"ui.tip.heist_shadow_ledger.saw"],
			[&"interact", &"ui.tip.heist_shadow_ledger.hack"], [&"", &"ui.tip.heist_shadow_ledger.alarm"]],
	&"heist_dockside_burn": [[&"interact", &"ui.tip.heist_dockside_burn.thermite"],
			[&"", &"ui.tip.heist_dockside_burn.shutters"], [&"", &"ui.tip.heist_dockside_burn.containers"]],
	&"heist_gallery_night": [[&"", &"ui.tip.heist_gallery_night.list"],
			[&"interact", &"ui.tip.heist_gallery_night.cut"], [&"", &"ui.tip.heist_gallery_night.gala"],
			[&"", &"ui.tip.heist_gallery_night.last_call"]],
	&"heist_rolling_thunder": [[&"", &"ui.tip.heist_rolling_thunder.signals"],
			[&"", &"ui.tip.heist_rolling_thunder.crash"], [&"interact", &"ui.tip.heist_rolling_thunder.trucks"],
			[&"", &"ui.tip.heist_rolling_thunder.bags"]],
}

## Tip on screen (&"" = none) and the situation the model is in now (tests).
var shown: StringName = &""
var situation: StringName = &""
## Heist being played (Hud sets it from Hud.heist_id); picks the heist card (OnboardingTips.heist_tip).
var heist_id: StringName = &""
var show_delay_s: float = SHOW_DELAY_S
## r228: the card's width; the HUD narrows it to fit the black margin beside a scope ring (fit_width).
var width: float = WIDTH
var panel: PanelContainer
var title: Label
var step_label: Label
var rows_box: VBoxContainer
var footer: KeyPrompt
var dwell_bar: ProgressBar
var _left: float = 0.0
var _pending: StringName = &""
var _pending_t: float = 0.0
var _slide: Tween = null
## Key cap text of each row of the open card ("" = bullet row), to redraw them when a binding changes.
var _row_glyphs: Array[String] = []


func build() -> void:
	visible = false
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	panel = UiBuild.panel(v, UiBuild.CARD)
	var sb: StyleBoxFlat = (UiBuild.theme().get_stylebox(&"panel", UiBuild.CARD) as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.bg_color = Color(UiTokens.INK_1, 0.95)
	sb.border_color = UiTokens.BRASS
	sb.border_width_left = 3
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(panel)
	var head: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	var cap: Label = UiBuild.caption(&"ui.tip.caption")
	cap.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	step_label = UiBuild.caption()
	step_label.add_theme_color_override(&"font_color", UiTokens.PAPER_DIM)
	head.add_child(step_label)
	v.add_child(head)
	title = UiBuild.label()  # plain text: the card is opaque, no HUD outline / shadow
	title.add_theme_font_size_override(&"font_size", UiTokens.FONT_H2)
	title.add_theme_font_override(&"font", UiTokens.font_heading())
	title.add_theme_color_override(&"font_color", UiTokens.PAPER)
	v.add_child(title)
	rows_box = UiBuild.vbox(UiTokens.S2)
	v.add_child(rows_box)
	dwell_bar = UiBuild.bar(UiTokens.BRASS, Vector2(WIDTH - 2 * UiTokens.S3, 3))
	v.add_child(dwell_bar)
	footer = KeyPrompt.new(UiTokens.FONT_SMALL)
	footer.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(footer)


func watched_signals() -> Array[StringName]:
	return [&"player_mode_changed", &"masked_changed", &"assault_changed", &"changed"]


## Which tip the model's state calls for (&"" = none yet).
func current_situation() -> StringName:
	var phase: int = int(prop(&"heist_phase", -1))
	if phase == Enums.HeistPhase.ESCAPE:
		return &"escape"
	if phase == Enums.HeistPhase.LOUD or int(prop(&"assault_phase", Enums.AssaultPhase.NONE)) != Enums.AssaultPhase.NONE:
		return &"loud"
	match player_mode():
		&"casing":
			return &"casing"
		&"masked":
			return &"stealth"
	return &""


func refresh() -> void:
	if panel == null or model == null:
		return
	if shown != &"":
		_update_footer()  # Hud refreshes every widget on a device switch and after a rebind
		_update_row_keys()
	situation = current_situation()
	if shown != &"" and OnboardingTips.ALL.has(shown) and situation != shown and situation != &"" \
			and not OnboardingTips.is_seen(situation):
		_close()  # h02 capture: the casing card outlived the mask-up; a card whose situation ended yields
	var want: StringName = wanted_tip()
	if shown != &"" or want == &"":
		return  # an open card stays until it times out or is dismissed; dismiss() looks again
	if _pending != want:
		_pending = want
		_pending_t = show_delay_s
	set_process(true)
	if _pending_t <= 0.0:
		_show(_pending)


## The card to show next (&"" = none): the situation's card while unseen, else the heist's card while unseen.
func wanted_tip() -> StringName:
	var sit: StringName = current_situation()
	if sit == &"":
		return &""  # the heist card waits for the heist to be under way too
	if not OnboardingTips.is_seen(sit):
		return sit
	var heist_tip: StringName = OnboardingTips.heist_tip(heist_id)
	if heist_tip != &"" and not OnboardingTips.is_seen(heist_tip):
		return heist_tip
	return &""


func _process(delta: float) -> void:
	if _pending != &"":
		_pending_t -= delta
		if _pending_t <= 0.0:
			if _pending == wanted_tip():
				_show(_pending)
			else:
				_pending = &""
	if shown != &"":
		_left -= delta
		dwell_bar.value = clampf(_left / DWELL_S, 0.0, 1.0)
		if _left <= 0.0:
			dismiss()
	if _pending == &"" and shown == &"":
		set_process(false)


func _input(event: InputEvent) -> void:
	if shown != &"" and is_dismiss(event):
		dismiss()
		get_viewport().set_input_as_handled()


## True for a press of the dismiss_tip action (or of H while the action is not in the InputMap).
static func is_dismiss(event: InputEvent) -> bool:
	if InputMap.has_action(DISMISS_ACTION):
		return event.is_action_pressed(DISMISS_ACTION, false, true)
	var k: InputEventKey = event as InputEventKey
	return k != null and k.pressed and not k.echo and (k.physical_keycode == DISMISS_KEY or k.keycode == DISMISS_KEY)


func _show(id: StringName) -> void:
	_pending = &""
	shown = id
	OnboardingTips.mark_seen(id)
	title.text = UiText.t(StringName("ui.tip.%s.title" % id))
	if OnboardingTips.ALL.has(id):
		step_label.text = UiText.t(&"ui.tip.step", {"n": OnboardingTips.ALL.find(id) + 1,
				"total": OnboardingTips.ALL.size()})
	else:
		step_label.text = UiText.t(StringName("heist.%s.name" % heist_id))
	_build_rows()
	_update_footer()
	_left = DWELL_S
	dwell_bar.value = 1.0
	visible = true
	set_process(true)
	UiSfx.play(UiSfx.HINT)  # D-090
	if is_inside_tree() and UiTokens.motion_ok():
		modulate.a = 0.0
		position.x += UiTokens.S5
		var tw: Tween = create_tween().set_parallel(true)
		_slide = tw
		tw.tween_property(self, ^"modulate:a", 1.0, UiTokens.T_SLOW).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, ^"position:x", position.x - UiTokens.S5, UiTokens.T_SLOW) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _build_rows() -> void:
	for c: Node in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	_row_glyphs = row_glyphs(shown)
	for r: Array in rows_for(shown):
		rows_box.add_child(_row(StringName(r[0]), StringName(r[1])))


## Key cap text of each row of card `id` for the current bindings and device ("" = a bullet row).
static func row_glyphs(id: StringName) -> Array[String]:
	var out: Array[String] = []
	for r: Array in rows_for(id):
		out.append(InteractionPanel.action_key_text(StringName(r[0])) if StringName(r[0]) != &"" else "")
	return out


## Rows of card `id` (ROWS), plus the D-142 glass row on the stealth card when HudTweak.d142_glass_tips is on.
static func rows_for(id: StringName) -> Array:
	var out: Array = (ROWS.get(id, []) as Array).duplicate()
	if id == &"stealth" and HudTweak.load_default().d142_glass_tips:
		out.insert(1, [&"", &"ui.tip.stealth.glass"])
	return out


## D-115: an open card's key caps follow a rebind / device switch (rows rebuilt only when a glyph changed).
func _update_row_keys() -> void:
	if ROWS.has(shown) and row_glyphs(shown) != _row_glyphs:
		_build_rows()


## "Press [H] to close" in the last device's glyph; "Closes by itself" when the action has no glyph.
func _update_footer() -> void:
	var glyph: String = InteractionPanel.action_key_text(DISMISS_ACTION) if InputMap.has_action(DISMISS_ACTION) \
			else ("" if InteractionPanel.pad_active else OS.get_keycode_string(DISMISS_KEY))
	if glyph == "":
		footer.set_line(UiText.t(&"ui.tip.auto_close"), "")
	else:
		footer.set_prompt(&"ui.tip.dismiss", {}, glyph)


## r228: ends the slide-in at once (the HUD is about to move the card into the scope margin).
func settle() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
	modulate.a = 1.0


## r228: re-wraps the card to `w` HUD units wide (the rows reflow; the card grows taller).
func fit_width(w: float) -> void:
	if is_equal_approx(w, width) or panel == null:
		return
	width = w
	panel.custom_minimum_size = Vector2(w, 0)
	dwell_bar.custom_minimum_size.x = w - 2 * UiTokens.S3
	for r: Node in rows_box.get_children():
		var l: Label = r.get_child(r.get_child_count() - 1) as Label
		if l != null:
			l.custom_minimum_size.x = w - 120
	panel.reset_size()


## Closes the card; a situation that started meanwhile (and is unseen) shows next.
func dismiss() -> void:
	_close()
	refresh()


func _close() -> void:
	shown = &""
	visible = false
	modulate.a = 1.0


## One card row: a key cap for `action` (or a brass bullet) and the wrapped text.
func _row(action: StringName, key: StringName) -> HBoxContainer:
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	var glyph: String = InteractionPanel.action_key_text(action) if action != &"" else ""
	if glyph != "":
		var cap: PanelContainer = UiBuild.keycap(glyph, UiTokens.FONT_SMALL)
		cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(cap)
	else:
		var dot: Label = UiBuild.label()
		dot.text = "\u2014"
		dot.add_theme_color_override(&"font_color", UiTokens.BRASS)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.custom_minimum_size = Vector2(UiTokens.FONT_SMALL * 1.8, 0)  # the text lines up with the key caps
		dot.add_theme_font_size_override(&"font_size", UiTokens.FONT_BODY)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(dot)
	var l: Label = UiBuild.label(key)
	l.add_theme_font_size_override(&"font_size", UiTokens.FONT_BODY)
	l.add_theme_color_override(&"font_color", UiTokens.PAPER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(width - 120, 0)
	h.add_child(l)
	return h
