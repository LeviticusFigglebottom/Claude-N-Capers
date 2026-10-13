## PO-4 lane 11 (lead ruling): first-time onboarding cards, one per situation, shown the first time it
## arises rather than as one wall of text:
##   casing  - player_mode &"casing"            (walk in, look around, doors vs locks, hold G to mask up)
##   stealth - masked, no alarm yet             (guards / cameras / pagers, interact, carry / throw bags)
##   loud    - heist_phase LOUD or an assault   (waves, hostages, keep moving the loot)
##   escape  - heist_phase ESCAPE               (the getaway, unsecured bags, whole crew in the zone)
## A card shows SHOW_DELAY_S after its situation starts, stays DWELL_S (a thin bar drains) and closes
## early on DISMISS_KEY. Shown ids are stored in the profile (OnboardingTips), so each card appears
## once per profile. A later situation replaces an earlier card. Owner: ENV B.
class_name OnboardingCard
extends HudWidget

const DWELL_S: float = 14.0
const SHOW_DELAY_S: float = 1.2
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
}

## Tip on screen (&"" = none) and the situation the model is in now (tests).
var shown: StringName = &""
var situation: StringName = &""
var show_delay_s: float = SHOW_DELAY_S
var panel: PanelContainer
var title: Label
var step_label: Label
var rows_box: VBoxContainer
var footer: KeyPrompt
var dwell_bar: ProgressBar
var _left: float = 0.0
var _pending: StringName = &""
var _pending_t: float = 0.0


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
	situation = current_situation()
	if shown != &"" or situation == &"" or OnboardingTips.is_seen(situation):
		return  # an open card stays until it times out or is dismissed; dismiss() looks again
	if _pending != situation:
		_pending = situation
		_pending_t = show_delay_s
	set_process(true)
	if _pending_t <= 0.0:
		_show(_pending)


func _process(delta: float) -> void:
	if _pending != &"":
		_pending_t -= delta
		if _pending_t <= 0.0:
			if _pending == current_situation():
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
	var k: InputEventKey = event as InputEventKey
	if shown != &"" and k != null and k.pressed and not k.echo \
			and (k.physical_keycode == DISMISS_KEY or k.keycode == DISMISS_KEY):
		dismiss()
		get_viewport().set_input_as_handled()


func _show(id: StringName) -> void:
	_pending = &""
	shown = id
	OnboardingTips.mark_seen(id)
	title.text = UiText.t(StringName("ui.tip.%s.title" % id))
	step_label.text = UiText.t(&"ui.tip.step", {"n": OnboardingTips.ALL.find(id) + 1,
			"total": OnboardingTips.ALL.size()})
	for c: Node in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	for r: Array in ROWS[id] as Array:
		rows_box.add_child(_row(StringName(r[0]), StringName(r[1])))
	if InteractionPanel.pad_active:
		footer.set_line(UiText.t(&"ui.tip.auto_close"), "")
	else:
		footer.set_prompt(&"ui.tip.dismiss", {}, OS.get_keycode_string(DISMISS_KEY))
	_left = DWELL_S
	dwell_bar.value = 1.0
	visible = true
	set_process(true)
	UiSfx.play(UiSfx.HINT)  # D-090
	if is_inside_tree() and UiTokens.motion_ok():
		modulate.a = 0.0
		position.x += UiTokens.S5
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(self, ^"modulate:a", 1.0, UiTokens.T_SLOW).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, ^"position:x", position.x - UiTokens.S5, UiTokens.T_SLOW) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Closes the card; a situation that started meanwhile (and is unseen) shows next.
func dismiss() -> void:
	shown = &""
	visible = false
	modulate.a = 1.0
	refresh()


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
	l.custom_minimum_size = Vector2(WIDTH - 120, 0)
	h.add_child(l)
	return h
