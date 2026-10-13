## Notoriety screen (B5-02, pd2_fidelity P10). Owner: ENV B. Opened from the hub's profile panel
## (HubMenu.notoriety_requested -> MenuFlow._open_notoriety); Back returns to the hub.
## Shows the current rank badge (roman numeral) and XP bonus, the next rank's requirements checklist
## (level, spending cash, or the cap), its cost and reward preview (Notoriety.rewards_for + the choice
## pool + the new XP bonus). Rank Up opens an in-screen confirm panel that warns about the level/XP
## reset; Confirm runs Notoriety.rank_up and saves. A rank with a reward choice (Notoriety
## pending_choices) lists one button per option until the player picks.
## Focus: choice buttons -> Rank Up -> Back; while confirming only Confirm / Cancel (Esc / gamepad B
## cancels the confirm instead of leaving the screen).
## API: setup(profile) before or after entering the tree (null = load profile_slot); refresh();
## request_rank_up() / confirm_rank_up() / cancel_confirm(); choose(item_id).
class_name NotorietyScreen
extends UiScreen

signal rank_changed(rank: int)

@export var profile_slot: int = 0
## Save the profile after a rank-up or a reward choice (tests turn it off).
@export var save_on_change: bool = true

var profile: PlayerProfile = null
var rank_label: Label
var bonus_label: Label
var held_label: Label
var next_label: Label
var cost_label: Label
var result_label: Label
## Requirement code (Notoriety.REQ_*) -> its row's status Label.
var check_rows: Dictionary = {}
var checklist: VBoxContainer
var reward_list: VBoxContainer
var choice_box: VBoxContainer
## Reward id -> its choice Button (the earliest pending choice rank).
var choice_buttons: Dictionary = {}
var rank_up_button: Button
var back_button: Button
var confirm_panel: PanelContainer
var confirm_title: Label
var confirm_body: Label
var confirm_button: Button
var cancel_button: Button
var _cost_field: VBoxContainer


func setup(p: PlayerProfile) -> void:
	profile = p
	if is_node_ready():
		refresh()


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root)
	var titles: VBoxContainer = UiBuild.header(&"ui.notoriety.crumb", &"ui.notoriety.title")
	var sub: Label = UiBuild.label(&"ui.notoriety.subtitle", UiBuild.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(sub)
	root.add_child(titles)
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_current())
	body.add_child(_build_next())
	confirm_panel = _build_confirm()
	root.add_child(confirm_panel)
	result_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	root.add_child(result_label)
	# PO-4 footer: Back (ghost) left, Rank Up (the screen's primary) right.
	rank_up_button = UiBuild.button(&"ui.notoriety.rank_up")
	rank_up_button.pressed.connect(request_rank_up)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	root.add_child(UiBuild.footer(back_button, rank_up_button))
	refresh()


func _build_current() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_child(UiBuild.caption(&"ui.notoriety.current"))
	rank_label = UiBuild.label(&"", UiBuild.HEADER)
	v.add_child(rank_label)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S2)
	v.add_child(gap)
	bonus_label = UiBuild.label()
	bonus_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	v.add_child(UiBuild.field(&"ui.notoriety.xp_bonus_caption", bonus_label))
	held_label = UiBuild.label(&"", UiBuild.DIM)
	held_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(held_label)
	return UiBuild.panel(v)


func _build_next() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	v.add_child(next_label)
	v.add_child(UiBuild.caption(&"ui.notoriety.requirements"))
	checklist = UiBuild.vbox(UiTokens.S1)
	v.add_child(checklist)
	cost_label = UiBuild.label(&"", UiBuild.MONEY)
	_cost_field = UiBuild.field(&"ui.notoriety.cost_caption", cost_label)
	v.add_child(_cost_field)
	v.add_child(HSeparator.new())
	reward_list = UiBuild.vbox(UiTokens.S1)
	v.add_child(reward_list)
	choice_box = UiBuild.vbox(UiTokens.S2)
	v.add_child(choice_box)
	var panel: PanelContainer = UiBuild.panel(v)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _build_confirm() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	confirm_title = UiBuild.label(&"", UiBuild.SUBHEADER)
	v.add_child(confirm_title)
	confirm_body = UiBuild.label()
	confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_body.custom_minimum_size = Vector2(640, 0)
	v.add_child(confirm_body)
	# Cancel (ghost) left, Confirm (primary) right, like the screen footer.
	confirm_button = UiBuild.button(&"ui.notoriety.confirm")
	confirm_button.pressed.connect(func() -> void: UiSfx.check(bool(confirm_rank_up()["ok"])))
	cancel_button = UiBuild.button(&"ui.notoriety.cancel")
	cancel_button.pressed.connect(cancel_confirm)
	v.add_child(UiBuild.footer(cancel_button, confirm_button))
	var panel: PanelContainer = UiBuild.panel(v, &"AlertPanel")  # the reset warning reads as loud
	panel.visible = false
	return panel


## Rebuilds every label, the checklist, the rewards and the choice buttons from the profile.
func refresh() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if rank_label == null:
		return
	var rank: int = profile.notoriety
	var cap: int = Notoriety.max_rank()
	rank_label.text = badge_text(rank)
	var pct: int = roundi(Notoriety.xp_bonus(rank) * 100.0)
	var maxed: bool = Notoriety.xp_bonus(rank) >= Notoriety.tweak().xp_bonus_cap
	bonus_label.text = UiText.t(&"ui.notoriety.xp_bonus_max" if maxed else &"ui.notoriety.xp_bonus", {"pct": pct})
	var held: int = NotorietySkills.held_points(profile, profile.active_skill_set)
	held_label.text = UiText.t(&"ui.notoriety.held_skills", {"points": held}) if held > 0 else ""
	held_label.visible = held > 0
	next_label.text = UiText.t(&"ui.notoriety.max_reached") if rank >= cap else \
			UiText.t(&"ui.notoriety.next", {"rank": Notoriety.roman(rank + 1)})
	_fill_checklist()
	cost_label.visible = rank < cap
	_cost_field.visible = rank < cap
	cost_label.text = UiText.t(&"ui.notoriety.cost", {"amount": UiText.money(Notoriety.cost_for(rank + 1))})
	_fill_rewards(rank + 1 if rank < cap else 0)
	_fill_choices()
	rank_up_button.disabled = not Notoriety.can_rank_up(profile) or is_confirming()
	_rebuild_focus()


func _fill_checklist() -> void:
	_clear(checklist)
	check_rows.clear()
	for r: Dictionary in Notoriety.requirements(profile):
		var code: StringName = r["code"] as StringName
		var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		var have: String = UiText.money(int(r["have"])) if code == Notoriety.REQ_CASH else str(int(r["have"]))
		var need: String = UiText.money(int(r["need"])) if code == Notoriety.REQ_CASH else str(int(r["need"]))
		var text: Label = UiBuild.label(StringName("ui.notoriety.check.%s" % code), &"", {"have": have, "need": need})
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var met: bool = bool(r["met"])
		var status: Label = UiBuild.caption(&"ui.notoriety.check.met" if met else &"ui.notoriety.check.unmet")
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if met:
			status.add_theme_color_override(&"font_color", UiTokens.OK)
		row.add_child(status)
		checklist.add_child(row)
		check_rows[code] = status


## Reward preview of `rank` (0 = none: at the cap).
func _fill_rewards(rank: int) -> void:
	_clear(reward_list)
	if rank <= 0:
		return
	reward_list.add_child(UiBuild.caption(&"ui.notoriety.rewards", {"rank": Notoriety.roman(rank)}))
	var ids: Array[StringName] = Notoriety.rewards_for(rank)
	for id: StringName in ids:
		reward_list.add_child(UiBuild.label(&"ui.notoriety.reward_line", &"", {"name": Notoriety.reward_name(id)}))
	var d: NotorietyDef = Notoriety.def_for(rank)
	if d != null and not d.choices.is_empty():
		var names: PackedStringArray = []
		for id: StringName in d.choices:
			if not MaskLocker.is_drop_owned(profile, id):
				names.append(Notoriety.reward_name(id))
		if not names.is_empty():
			reward_list.add_child(UiBuild.label(&"ui.notoriety.reward_choice", &"", {"names": ", ".join(names)}))
	if Notoriety.xp_bonus(rank) > Notoriety.xp_bonus(rank - 1):
		reward_list.add_child(UiBuild.label(&"ui.notoriety.reward_xp", &"",
				{"pct": roundi(Notoriety.xp_bonus(rank) * 100.0)}))
	elif ids.is_empty():
		reward_list.add_child(UiBuild.label(&"ui.notoriety.reward_none", UiBuild.DIM))


func _fill_choices() -> void:
	_clear(choice_box)
	choice_buttons.clear()
	var pending: Array[int] = Notoriety.pending_choices(profile)
	if pending.is_empty():
		return
	var rank: int = pending[0]
	choice_box.add_child(UiBuild.label(&"ui.notoriety.choice_title", UiBuild.SUBHEADER, {"rank": Notoriety.roman(rank)}))
	for id: StringName in Notoriety.choice_options(profile, rank):
		var b: Button = UiBuild.button(&"ui.notoriety.reward_line", {"name": Notoriety.reward_name(id)})
		b.pressed.connect(choose.bind(id))
		choice_box.add_child(b)
		choice_buttons[id] = b


func is_confirming() -> bool:
	return confirm_panel != null and confirm_panel.visible


## Opens the confirm panel when the next rank's requirements are met. Returns whether it opened.
func request_rank_up() -> bool:
	if not Notoriety.can_rank_up(profile):
		return false
	var next: int = profile.notoriety + 1
	confirm_title.text = UiText.t(&"ui.notoriety.confirm_title", {"rank": Notoriety.roman(next)})
	confirm_body.text = UiText.t(&"ui.notoriety.confirm_body", {"amount": UiText.money(Notoriety.cost_for(next))})
	confirm_panel.visible = true
	refresh()
	_focus_confirm.call_deferred()
	return true


func _focus_confirm() -> void:
	if is_confirming() and confirm_button.is_visible_in_tree():
		confirm_button.grab_focus()


## Confirm: runs Notoriety.rank_up, saves, refreshes. Returns rank_up()'s dict ({ok: false} when the
## confirm panel was not open).
func confirm_rank_up() -> Dictionary:
	if not is_confirming():
		return {"ok": false}
	confirm_panel.visible = false
	var r: Dictionary = Notoriety.rank_up(profile)
	if bool(r["ok"]):
		_save()
		result_label.text = UiText.t(&"ui.notoriety.done", {"rank": Notoriety.roman(int(r["rank"]))})
		rank_changed.emit(int(r["rank"]))
	refresh()
	focus_default()
	return r


func cancel_confirm() -> void:
	if confirm_panel != null:
		confirm_panel.visible = false
	refresh()
	focus_default()


## Picks a reward of the earliest pending choice rank. Saves on success.
func choose(item_id: StringName) -> bool:
	var pending: Array[int] = Notoriety.pending_choices(profile)
	if pending.is_empty() or not Notoriety.choose(profile, pending[0], item_id):
		return false
	_save()
	refresh()
	focus_default()
	return true


## "Level 73" or, with a rank, "XII · Level 73" (hub profile panel, lobby slots).
static func level_text(level: int, rank: int) -> String:
	if rank <= 0:
		return UiText.t(&"ui.menu.level", {"level": level})
	return UiText.t(&"ui.notoriety.level_badge", {"rank": Notoriety.roman(rank), "level": level})


## The rank badge line: "Notoriety XII", or the no-rank text.
static func badge_text(rank: int) -> String:
	if rank <= 0:
		return UiText.t(&"ui.notoriety.badge_none")
	return UiText.t(&"ui.notoriety.badge", {"rank": Notoriety.roman(rank)})


func _unhandled_input(event: InputEvent) -> void:
	if is_confirming() and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_confirm()
		return
	super(event)


func _rebuild_focus() -> void:
	focus_chain.clear()
	if is_confirming():
		focus_chain.append(confirm_button)
		focus_chain.append(cancel_button)
	else:
		for id: Variant in choice_buttons:
			focus_chain.append(choice_buttons[id] as Button)
		focus_chain.append(rank_up_button)
		focus_chain.append(back_button)
	UiNav.chain_vertical(focus_chain)


func _save() -> void:
	if save_on_change:
		SaveService.save_profile(profile, profile_slot)


static func _clear(box: Container) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()
