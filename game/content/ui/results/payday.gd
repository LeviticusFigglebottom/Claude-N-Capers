## Payday / results screen (pd2_fidelity C6, S10.4; D-020, D-022). Owner: ENV B.
##
## show_result(result) takes a HeistResult (contracts/events.md), runs PayoutCalculator.compute for
## the local crew slot with the profile's banked stealth bonus, lists the cash breakdown and the XP
## lines in C6 order with level progress (XpCurve), crew stats, then applies the payout to the
## profile (SaveService.apply_heist_payout + save_profile) once per shown result.
## With `listen_heist_ended` it shows itself on EventBus.heist_ended (in-heist use).
## Card pick (P9, B4-05; content/docs/payday_cards.md): after a successful heist that pays into the
## profile, Continue on the summary opens the card stage: 3 face-down PaydayCardViews rolled by
## PaydayCards.roll(result.seed, local slot, ...). Pick one (mouse / ui_accept), or the timer
## (PaydayCardsTable.pick_time_s, 30 s) picks `auto_pick`; all three are revealed, the picked reward
## is granted (PaydayCards.grant) and saved, and Continue is enabled again.
## Leaving with an unpicked card (QB-PC1, D-049): the screen leaving the tree, the app quitting
## (WM close request), a new result replacing this one, or MenuFlow leaving the heist auto-pick it
## with the same deterministic `auto_pick` as the timeout (finish_card_pick()); no save change.
## Career (B7-01): _apply banks the result into profile.career (Career.record, local crew slot) before the
## achievements, so career-stat achievements see this payday.
## Achievements (B4-20): _apply runs Achievements.on_payday on the profile before saving; ids unlocked by
## this payday are in `achievements_unlocked` and listed under the summary.
## Awards (B6-02; content/docs/scoreboard.md): HeistAwards.compute over result.crew -> `awards`, shown as
## their own "Crew Honours" section under the crew stats (`award_labels`: award id -> winner names Label).
## Continue emits continue_pressed; if nobody listens it returns to the main menu scene.
class_name PaydayScreen
extends UiScreen

signal continue_pressed()

const MENU_SCENE: String = "res://content/ui/menus/menu_flow.tscn"
const URGENT_COLOR: Color = Color(1.0, 0.42, 0.32)
## PQ-B-5: player picks are ignored this long after the cards appear.
const INPUT_GRACE_S: float = 0.6

@export var listen_heist_ended: bool = false
@export var apply_to_profile: bool = true
@export var profile_slot: int = 0
## Offer the payday card pick after a successful heist (only when apply_to_profile is on).
@export var cards_enabled: bool = true
## Pro job (a Board contract flagged pro, B4-07): PayoutCalculator's is_pro (pro_job_xp_mult XP
## line). MenuFlow sets it from the contract before the heist ends; HeistResult does not carry it.
@export var is_pro: bool = false

var profile: PlayerProfile
## PayoutCalculator.compute output for the shown result.
var payout: Dictionary = {}
var result: Dictionary = {}
## Line id -> value Label (ids: contract, loot, small_loot, crew_alive, civilian_penalty, total,
## stash, spending, xp.<key>, xp_total, level).
var value_labels: Dictionary = {}
var level_bar: ProgressBar
var continue_button: Button
var xp_before: int = 0
var xp_after: int = 0
## PaydayCards.roll output for the shown result ({} = no card pick).
var card_roll: Dictionary = {}
## HeistAwards.compute(result.crew) for the shown result (B6-02).
var awards: Array[Dictionary] = []
## Award id -> the Label with the winners' names (tests).
var award_labels: Dictionary = {}
## Achievement ids this payday unlocked (B4-20).
var achievements_unlocked: Array[StringName] = []
## Index of the picked card (-1 = not picked yet).
var picked_index: int = -1
## True when the timer picked the card.
var auto_picked: bool = false
## Seconds left on the card stage before the auto-pick.
var time_left: float = 0.0
var cards_stage: bool = false
var card_views: Array[PaydayCardView] = []
var timer_label: Label
var card_result_label: Label
## Urgent-window second ticks so far (PQ-B-9).
var urgent_ticks: int = 0
var _content: VBoxContainer
var _summary: ScrollContainer
var _cards_root: VBoxContainer
var _cards_row: HBoxContainer
var _cards_title: Label
var _applied: bool = false
var _input_grace: float = 0.0


func _sync_cursor() -> void:
	if is_visible_in_tree():
		MouseCapture.push_release(&"payday")
	else:
		MouseCapture.pop_release(&"payday")


func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	var backdrop: ColorRect = CaseBackdrop.new()  # opaque over the map when shown in-heist
	backdrop.color = Color(UiAccent.app_bg(), 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var root: VBoxContainer = UiBuild.vbox(16)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.results.title", UiBuild.HEADER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_summary = scroll
	_build_cards_stage(root)
	_content = UiBuild.vbox(20)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	continue_button = UiBuild.primary(UiBuild.button(&"ui.results.continue"))
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(_on_continue)
	root.add_child(continue_button)
	focus_chain.append(continue_button)
	back_requested.connect(_on_continue)
	# input_focus.md 1.1: the payday screen holds the cursor while shown (MouseCapture &"payday"), so the
	# heist's still-live PlayerInput neither captures it nor eats the first click as a capture click.
	visibility_changed.connect(_sync_cursor)
	tree_exiting.connect(MouseCapture.pop_release.bind(&"payday"))
	_sync_cursor()
	if listen_heist_ended and not EventBus.heist_ended.is_connected(_on_heist_ended):
		EventBus.heist_ended.connect(_on_heist_ended)
	if not result.is_empty():
		_render()


## Show a HeistResult. Computes the payout and (unless apply_to_profile is false) banks it.
func show_result(heist_result: Dictionary) -> void:
	finish_card_pick()
	result = heist_result
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	payout = compute_payout(result, profile, Net.local_slot(), is_pro)
	xp_before = profile.xp
	xp_after = xp_before + int(payout.get("xp_total", 0))
	_applied = false
	awards = HeistAwards.compute(result.get("crew", []) as Array)
	achievements_unlocked = []
	if apply_to_profile:
		_apply()
	card_roll = {}
	picked_index = -1
	auto_picked = false
	cards_stage = false
	if apply_to_profile and cards_enabled and bool(payout.get("success", false)):
		card_roll = PaydayCards.roll(int(result.get("seed", 0)), Net.local_slot(), int(result.get("difficulty", 0)),
				profile, PaydayCards.quality_add_for(profile))
		time_left = PaydayCards.table().pick_time_s
		urgent_ticks = 0
	if _content != null:
		_render()
		_set_stage(false)


## True while a card pick is offered and not done yet.
func has_card_pick() -> bool:
	return not card_roll.is_empty() and picked_index < 0


## Switch to the card stage: face-down cards, timer running, Continue disabled until a pick.
func show_cards() -> void:
	if card_roll.is_empty() or _cards_root == null:
		return
	_set_stage(true)
	for v: PaydayCardView in card_views:
		_cards_row.remove_child(v)
		v.queue_free()
	card_views.clear()
	var cards: Array = card_roll.get("cards", []) as Array
	for i: int in range(cards.size()):
		var v: PaydayCardView = PaydayCardView.new()
		v.setup(i, PaydayCards.table())
		v.pressed.connect(_on_card_pressed.bind(i))
		_cards_row.add_child(v)
		card_views.append(v)
	var chain: Array[Control] = []
	for v: PaydayCardView in card_views:
		chain.append(v)
	UiNav.chain_horizontal(chain)
	for v: PaydayCardView in card_views:
		v.set_focus_neighbor(SIDE_BOTTOM, v.get_path_to(continue_button))
	continue_button.disabled = picked_index < 0
	if picked_index >= 0:
		_reveal()
	_update_timer_label()
	focus_chain = chain
	focus_chain.append(continue_button)
	focus_default()
	_input_grace = INPUT_GRACE_S


## PQ-B-5: player picks are ignored for INPUT_GRACE_S after the cards appear, so an accept held or
## mashed through the summary cannot pick the default-focused card blind. The timer is unaffected.
## True while player card picks are still being ignored.
func in_input_grace() -> bool:
	return _input_grace > 0.0


func _on_card_pressed(index: int) -> void:
	if in_input_grace():
		return
	pick(index)


## PQ-B-4: number keys 1..3 pick a card directly (after the grace).
func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not cards_stage or picked_index >= 0 or in_input_grace():
		return
	var idx: int = int(k.physical_keycode) - int(KEY_1)
	if idx >= 0 and idx < card_views.size():
		get_viewport().set_input_as_handled()
		pick(idx)


## Pick card `index` (player or timer): reveals all cards, grants the reward and saves the profile.
func pick(index: int) -> void:
	var cards: Array = card_roll.get("cards", []) as Array
	if picked_index >= 0 or index < 0 or index >= cards.size():
		return
	picked_index = index
	if PaydayCards.grant(profile, cards[index] as Dictionary) and apply_to_profile:
		SaveService.save_profile(profile, profile_slot)
	_reveal()
	if continue_button != null:
		continue_button.disabled = false
		if is_visible_in_tree():
			continue_button.grab_focus.call_deferred()


## Auto-pick an offered, unpicked card exactly like the timeout does (auto_pick of the roll), for
## every way of leaving the screen (QB-PC1). No-op when there is no pending pick. Returns whether it picked.
func finish_card_pick() -> bool:
	if not has_card_pick():
		return false
	auto_picked = true
	pick(int(card_roll.get("auto_pick", 0)))
	_update_timer_label()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish_card_pick()


func _exit_tree() -> void:
	finish_card_pick()


## Advance the pick timer (called from _process; tests call it directly).
func tick(delta: float) -> void:
	if not cards_stage or picked_index >= 0:
		return
	_input_grace = maxf(_input_grace - delta, 0.0)
	var before: int = ceili(time_left)
	time_left = maxf(time_left - delta, 0.0)
	if timer_is_urgent() and ceili(time_left) < before and time_left > 0.0:
		_urgent_tick()
	if time_left <= 0.0:
		finish_card_pick()
	_update_timer_label()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		tick(delta)


func _build_cards_stage(root: VBoxContainer) -> void:
	_cards_root = UiBuild.vbox(24)
	_cards_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_root.visible = false
	root.add_child(_cards_root)
	_cards_title = UiBuild.label(&"ui.payday_cards.title", UiBuild.SUBHEADER)
	_cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_root.add_child(_cards_title)
	var hint: Label = UiBuild.label(&"ui.payday_cards.hint", UiBuild.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_root.add_child(hint)
	_cards_row = UiBuild.hbox(48)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_root.add_child(_cards_row)
	timer_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_root.add_child(timer_label)
	card_result_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	card_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_root.add_child(card_result_label)


func _set_stage(cards: bool) -> void:
	cards_stage = cards
	_summary.visible = not cards
	_cards_root.visible = cards
	if not cards:
		continue_button.disabled = false
		focus_chain.clear()
		focus_chain.append(continue_button)
		card_result_label.text = ""


func _reveal() -> void:
	var cards: Array = card_roll.get("cards", []) as Array
	for i: int in range(mini(card_views.size(), cards.size())):
		card_views[i].reveal(cards[i] as Dictionary, i == picked_index)
	if picked_index >= 0 and picked_index < cards.size():
		card_result_label.text = UiText.t(&"ui.payday_cards.you_got",
				{"reward": PaydayCardView.reward_text(cards[picked_index] as Dictionary)})
	_update_timer_label()


## True while the card stage is waiting for a pick and PaydayCardsTable.urgent_time_s or less remain.
## PQ-B-9: one cue request per whole second in the urgent window (PaydayCardsTable.urgent_tick_cue).
func _urgent_tick() -> void:
	urgent_ticks += 1
	var cue: StringName = PaydayCards.table().urgent_tick_cue
	if cue_registered(cue):
		EventBus.audio_cue_requested.emit(cue, Vector3.ZERO, -1)


## True when ENV C's cue registry has `cue_id` (no hard dependency on world/audio; false when absent).
static func cue_registered(cue_id: StringName) -> bool:
	if cue_id == &"":
		return false
	var reg_script: Script = UiNav.global_class(&"AudioCueRegistry")
	if reg_script == null:
		return false
	var reg: Object = reg_script.call(&"load_default") as Object
	return reg != null and bool(reg.call(&"has_cue", cue_id))


## Gamepad LB / RB (ui_payday_prev / ui_payday_next, once the lead adds them): move along the cards.
## LB / RB are shared with throw / melee, so this runs in _input (before gameplay's unhandled input),
## only while focus is inside this screen, and consumes the event.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not cards_stage or picked_index >= 0 or card_views.is_empty():
		return
	var owner_ctl: Control = get_viewport().gui_get_focus_owner()
	if owner_ctl == null or not is_ancestor_of(owner_ctl):
		return
	var step: int = 0
	if InputMap.has_action(&"ui_payday_prev") and event.is_action_pressed(&"ui_payday_prev"):
		step = -1
	elif InputMap.has_action(&"ui_payday_next") and event.is_action_pressed(&"ui_payday_next"):
		step = 1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var cur: int = card_views.find(owner_ctl as PaydayCardView)
	var n: int = card_views.size()
	var nxt: int = (maxi(cur, 0) + step + n) % n if cur >= 0 else (0 if step > 0 else n - 1)
	card_views[nxt].grab_focus()


func timer_is_urgent() -> bool:
	return cards_stage and picked_index < 0 and time_left <= PaydayCards.table().urgent_time_s


func _update_timer_label() -> void:
	if timer_label == null:
		return
	if picked_index >= 0:
		timer_label.text = UiText.t(&"ui.payday_cards.auto_picked") if auto_picked else ""
	else:
		timer_label.text = UiText.t(&"ui.payday_cards.timer", {"seconds": ceili(time_left)})
	# B-PP-3: the PD2 30 s auto-pick stays (pd2_fidelity P9), but the last seconds are flagged so the
	# timeout never silently picks for a player who is still deciding.
	if timer_is_urgent():
		timer_label.add_theme_color_override(&"font_color", URGENT_COLOR)
	else:
		timer_label.remove_theme_color_override(&"font_color")
	timer_label.visible = timer_label.text != ""


## PayoutCalculator.compute for `crew_slot` with the profile's banked stealth multiplier (D-022);
## `pro` = a pro job contract. The profile's Notoriety rank adds its XP bonus line (Notoriety.xp_bonus).
static func compute_payout(heist_result: Dictionary, p: PlayerProfile, crew_slot: int, pro: bool = false) -> Dictionary:
	var banked: float = p.banked_stealth_mult if p != null else 1.0
	var xp_mult: float = 1.0
	var notoriety: float = 0.0
	if p != null:
		var mods: Dictionary = LoadoutResolver.resolve(p.loadout).modifiers
		xp_mult = float(mods.get(&"progression.xp_mult", 1.0))
		notoriety = Notoriety.xp_bonus(p.notoriety)
	return PayoutCalculator.compute(heist_result, null, null, pro, crew_slot, banked, xp_mult, notoriety)


func _apply() -> void:
	if _applied:
		return
	_applied = true
	SaveService.apply_heist_payout(profile, payout, XpCurve.level_for_xp)
	profile.add_stat("heists_completed" if bool(payout.get("success", false)) else "heists_failed")
	Career.record(profile, result, payout, Net.local_slot())
	achievements_unlocked = Achievements.on_payday(profile, result, payout, is_pro)
	SaveService.save_profile(profile, profile_slot)


func _render() -> void:
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	value_labels.clear()
	var success: bool = bool(payout.get("success", false))
	_content.add_child(_build_hero(success))
	var summary: Array[String] = [
		UiText.t(&"ui.results.stealth" if bool(result.get("stealth", false)) else &"ui.results.loud"),
		UiText.t(&"ui.results.time", {"time": UiText.clock(float(result.get("time_s", 0.0)))}),
		UiText.t(&"ui.results.pagers_answered", {"count": int(result.get("pagers_answered", 0))}),
		UiText.t(UiText.difficulty_key(int(result.get("difficulty", 0)))),
	]
	var chips: Label = UiBuild.caption()
	chips.text = "   ·   ".join(summary)
	_content.add_child(chips)
	var cols: HBoxContainer = UiBuild.hbox(40)
	_content.add_child(cols)
	cols.add_child(UiBuild.panel(_build_cash()))
	cols.add_child(UiBuild.panel(_build_xp()))
	_content.add_child(UiBuild.panel(_build_stats()))
	_content.add_child(UiBuild.panel(_build_awards()))
	for id: StringName in achievements_unlocked:
		var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef
		if a != null:
			_content.add_child(UiBuild.label(&"ui.results.achievement_unlocked", UiBuild.SUBHEADER, {"name": UiText.t(a.name_key)}))
	focus_default()


## PO-4 hero row (style.md §8 payday): the outcome as a caption, the take-home total as the display
## number in brass, where it went (stash / spending) under it; XP total and the level bar on the right.
func _build_hero(success: bool) -> HBoxContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S7)
	var left: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var outcome: Label = UiBuild.caption(&"ui.results.success" if success else &"ui.results.failure")
	outcome.add_theme_color_override(&"font_color", UiTokens.OK if success else UiTokens.ALERT)
	left.add_child(outcome)
	var total: Label = UiBuild.label(&"", UiBuild.DISPLAY)
	total.text = UiText.money(int(payout.get("total", 0)))
	total.add_theme_color_override(&"font_color", UiTokens.BRASS_HI if success else UiTokens.PAPER_MUTE)
	left.add_child(total)
	value_labels[&"hero_total"] = total
	var split: Label = UiBuild.label(&"", UiBuild.DIM)
	split.text = "%s   ·   %s" % [
		UiText.t(&"ui.results.stash_line", {"amount": UiText.money(int(payout.get("stash", 0)))}),
		UiText.t(&"ui.results.spending_line", {"amount": UiText.money(int(payout.get("spending", 0)))})]
	left.add_child(split)
	var right: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	right.custom_minimum_size = Vector2(520, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	right.add_child(UiBuild.caption(&"ui.results.xp_header"))
	var xp: Label = UiBuild.label(&"", UiBuild.HEADER)
	xp.text = "+" + UiText.group_digits(int(payout.get("xp_total", 0)))
	right.add_child(xp)
	return row


func _build_cash() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.custom_minimum_size = Vector2(560, 0)
	v.add_child(UiBuild.label(&"ui.results.cash_header", UiBuild.SUBHEADER))
	var grid: GridContainer = _grid(v)
	_line(grid, &"contract", UiText.t(&"ui.results.contract"), UiText.money(int(payout.get("contract", 0))))
	for line: Dictionary in _grouped_loot():
		var loot_name: String = UiText.t(UiText.item_key(StringName(line["loot_id"])))
		_line(grid, StringName("loot." + String(line["loot_id"])),
				UiText.t(&"ui.results.loot_line", {"loot": loot_name, "count": line["count"]}), UiText.money(int(line["value"])))
	_line(grid, &"small_loot", UiText.t(&"ui.results.small_loot"), UiText.money(int(payout.get("small_loot", 0))))
	var mult: float = float(payout.get("crew_alive_mult", 1.0))
	var bonus: int = int(payout.get("gross", 0)) - int(payout.get("subtotal", 0))
	_line(grid, &"crew_alive", UiText.t(&"ui.results.crew_alive", {"mult": "%.2f" % mult}), UiText.money(bonus))
	_line(grid, &"civilian_penalty", UiText.t(&"ui.results.civilian_penalty"),
			UiText.money(-int(payout.get("civilian_penalty", 0))))
	_line(grid, &"total", UiText.t(&"ui.results.total"), UiText.money(int(payout.get("total", 0))))
	_line(grid, &"stash", UiText.t(&"ui.results.stash"), UiText.money(int(payout.get("stash", 0))))
	_line(grid, &"spending", UiText.t(&"ui.results.spending"), UiText.money(int(payout.get("spending", 0))))
	return v


func _build_xp() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.custom_minimum_size = Vector2(560, 0)
	v.add_child(UiBuild.label(&"ui.results.xp_header", UiBuild.SUBHEADER))
	var grid: GridContainer = _grid(v)
	for line: Dictionary in payout.get("xp_lines", []) as Array:
		var key: StringName = StringName(line["key"])
		_line(grid, StringName("xp." + String(key)), UiText.t(key), UiText.group_digits(int(line["amount"])))
	_line(grid, &"xp_total", UiText.t(&"ui.results.xp_total"), UiText.group_digits(int(payout.get("xp_total", 0))))
	var banked: float = float(payout.get("stealth_bonus_banked", 0.0))
	if banked > 1.0:
		v.add_child(UiBuild.label(&"ui.results.stealth_bonus_banked", UiBuild.DIM,
				{"pct": roundi((banked - 1.0) * 100.0)}))
	var level_before: int = XpCurve.level_for_xp(xp_before)
	var level_after: int = XpCurve.level_for_xp(xp_after)
	var lvl: Label = UiBuild.label(&"ui.menu.level", &"", {"level": level_after})
	value_labels[&"level"] = lvl
	v.add_child(lvl)
	level_bar = UiBuild.bar(UiAccent.table().fallback.lightened(0.15), Vector2(480, 16))
	level_bar.value = _level_progress(xp_after)
	v.add_child(level_bar)
	if level_after > level_before:
		v.add_child(UiBuild.label(&"ui.results.level_up", UiBuild.SUBHEADER, {"level": level_after}))
	return v


func _build_stats() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 36)
	v.add_child(grid)
	for key: StringName in [&"ui.results.crew", &"ui.results.kills", &"ui.results.specials_killed",
			&"ui.results.downs", &"ui.results.civilians_killed"]:
		grid.add_child(UiBuild.label(key, UiBuild.DIM))
	for member: Dictionary in result.get("crew", []) as Array:
		var slot: int = int(member.get("slot", 0))
		grid.add_child(UiBuild.label(StringName(_crew_name(slot, bool(member.get("is_ai", false))))))
		for k: String in ["kills", "specials_killed", "downs", "civilians_killed"]:
			grid.add_child(UiBuild.label(StringName(str(int(member.get(k, 0))))))
	return v


## B6-02 "Crew Honours": award name | winners | what it was for.
func _build_awards() -> VBoxContainer:
	award_labels.clear()
	var v: VBoxContainer = UiBuild.vbox(6)
	v.add_child(UiBuild.label(&"ui.awards.title", UiBuild.SUBHEADER))
	if awards.is_empty():
		v.add_child(UiBuild.label(&"ui.awards.none", UiBuild.DIM))
		return v
	var by_slot: Dictionary = {}
	for member: Dictionary in result.get("crew", []) as Array:
		by_slot[int(member.get("slot", -1))] = member
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 36)
	v.add_child(grid)
	for a: Dictionary in awards:
		grid.add_child(UiBuild.label(StringName(a["name_key"])))
		var names: Array[String] = []
		for slot: int in a["slots"] as Array:
			var member: Dictionary = by_slot.get(slot, {}) as Dictionary
			var n: String = String(member.get("name", ""))
			names.append(n if n != "" else _crew_name(slot, bool(member.get("is_ai", false))))
		var who: Label = UiBuild.label()
		who.text = ", ".join(names)
		grid.add_child(who)
		award_labels[StringName(a["id"])] = who
		grid.add_child(UiBuild.label(StringName(a["desc_key"]), UiBuild.DIM, {"value": roundi(float(a["value"]))}))
	return v


func _grid(parent: Container) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", 32)
	parent.add_child(g)
	return g


func _line(grid: GridContainer, id: StringName, caption: String, value: String) -> void:
	var c: Label = UiBuild.label()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: Label = UiBuild.label()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(c)
	grid.add_child(v)
	value_labels[id] = v
	# PO-4: a line worth nothing is noise (pro bonus 0, custody 0, ...); totals always show.
	var zero: bool = RegEx.create_from_string("[1-9]").search(value) == null
	if zero and not id in [&"contract", &"total", &"stash", &"spending", &"xp_total"]:
		c.visible = false
		v.visible = false


## payout.loot_lines grouped by loot id in first-seen order: [{loot_id, count, value}].
func _grouped_loot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: Dictionary = {}
	for line: Dictionary in payout.get("loot_lines", []) as Array:
		var id: StringName = StringName(line["loot_id"])
		if not index.has(id):
			index[id] = out.size()
			out.append({"loot_id": id, "count": 0, "value": 0})
		var g: Dictionary = out[int(index[id])]
		g["count"] = int(g["count"]) + 1
		g["value"] = int(g["value"]) + int(line["value"])
	return out


func _crew_name(slot: int, is_ai: bool) -> String:
	if Net.crew.has(slot):
		return String(Net.crew[slot].get("display_name", ""))
	return UiText.t(&"ui.results.crew_ai" if is_ai else &"ui.results.crew_slot", {"slot": slot + 1})


static func _level_progress(xp: int) -> float:
	var level: int = XpCurve.level_for_xp(xp)
	if level >= XpCurve.max_level():
		return 1.0
	var step: int = XpCurve.step_xp(level + 1)
	return clampf(float(xp - XpCurve.xp_for_level(level)) / float(maxi(step, 1)), 0.0, 1.0)


func _on_heist_ended(heist_result: Dictionary) -> void:
	show_result(heist_result)
	show()


func _on_continue() -> void:
	if not cards_stage and has_card_pick():
		show_cards()
		return
	if cards_stage and picked_index < 0:
		return
	if continue_pressed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	continue_pressed.emit()
