## Perk deck screen (B4-03, pd2_fidelity P4). Owner: ENV B. Opened from the loadout screen.
## Left: the 14 decks (unlocked cards n/9, the equipped one marked). Focus/hover previews a deck;
## pressing it equips it. Right: the previewed deck's 9 cards (name, text, cost, unlocked / next /
## locked), "Unlock next card" (perk points, PerkProgress) and "Equip". Equip writes
## Loadout.perk_deck + perk_deck_cards; every change is saved via SaveService.
## D-164 Copycat (Understudy): a card with "choices" shows its picked bonus and a "mimic" card the deck it copies;
## pressing such a card (accept / click) cycles the pick (Loadout.perk_choices / perk_mimic_deck), saved at once.
class_name PerkDeckScreen
extends UiScreen

## After any change (equip, card unlock).
signal perks_changed()

const CARD_COLUMNS: int = 3

@export var profile_slot: int = 0

var profile: PlayerProfile
var tweak: ProgressionUiTweak
var preview_deck: StringName = &""
## deck id -> Button
var deck_buttons: Dictionary = {}
var points_label: Label
var deck_name_label: Label
var deck_desc_label: Label
var deck_status_label: Label
var reason_label: Label
var equip_button: Button
var unlock_button: Button
var back_button: Button
## Per card (index 0..8): PanelContainer and its labels.
var card_panels: Array[PanelContainer] = []
var card_title_labels: Array[Label] = []
var card_name_labels: Array[Label] = []
var card_desc_labels: Array[Label] = []
var card_state_labels: Array[Label] = []
## D-164: per card, the "BONUS: … / COPIES: …" line (hidden on plain cards) (tests).
var card_choice_labels: Array[Label] = []
var _decks: Array[PerkDeckDef] = []
var _card_styles: Dictionary = {}


## Optional: inject a profile before the screen enters the tree (tests, MenuFlow).
func setup(p: PlayerProfile) -> void:
	profile = p


func _ready() -> void:
	super()
	_wire_focus()


func build_ui() -> void:
	tweak = ProgressionUiTweak.load_default()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	PerkProgress.sync(profile, tweak)
	_decks = PerkProgress.decks(tweak)
	_build_card_styles()
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	UiBuild.screen_margin(self, root, UiTokens.S6)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S5)
	var titles: VBoxContainer = UiBuild.header(&"ui.perks.crumb", &"ui.perks.title")
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	points_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	var pts: VBoxContainer = UiBuild.field(&"ui.perks.points_caption", points_label)
	pts.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(pts)
	root.add_child(top)
	if tweak.dev_unlock_all_perks:
		root.add_child(UiBuild.label(&"ui.perks.dev_unlocked", UiBuild.DIM))
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(420, 0)
	body.add_child(scroll)
	var list: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(UiBuild.caption(&"ui.perks.decks"))
	for d: PerkDeckDef in _decks:
		var b: Button = UiBuild.button(&"ui.perks.title")
		b.custom_minimum_size = Vector2(400, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true  # PO-4: the previewed deck shows the pressed style (ink + cyan edge)
		b.pressed.connect(equip.bind(d.id))
		b.focus_entered.connect(preview.bind(d.id))
		b.mouse_entered.connect(preview.bind(d.id))
		list.add_child(b)
		deck_buttons[d.id] = b
	body.add_child(_build_deck_view())
	# PO-4 footer: Back (ghost) left, a one-line rule, Equip Deck (the screen's primary) right.
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	var hint: Label = UiBuild.label(&"ui.perks.hint", UiBuild.DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(UiBuild.footer(back_button, equip_button, [hint] as Array[Control]))
	for d: PerkDeckDef in _decks:
		focus_chain.append(deck_buttons[d.id] as Control)
	focus_chain.append(equip_button)
	focus_chain.append(unlock_button)
	focus_chain.append(back_button)
	var start: StringName = profile.loadout.perk_deck
	preview(start if deck_buttons.has(start) else (_decks[0].id if not _decks.is_empty() else &""))


func _build_deck_view() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	deck_name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	deck_status_label = UiBuild.caption()
	deck_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(deck_name_label)
	head.add_child(deck_status_label)
	head.add_child(UiBuild.spacer())
	v.add_child(head)
	deck_desc_label = UiBuild.label()
	deck_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(deck_desc_label)
	# The card grid scrolls so the footer stays on screen at 720p (long completion texts).
	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.follow_focus = true  # pad focus on a card scrolls it into view
	v.add_child(grid_scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override(&"h_separation", UiTokens.S2)
	grid.add_theme_constant_override(&"v_separation", UiTokens.S2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid)
	for i: int in range(_max_cards()):
		var cv: VBoxContainer = UiBuild.vbox(UiTokens.S1)
		var title: Label = UiBuild.caption()
		var nm: Label = UiBuild.label()
		nm.add_theme_font_override(&"font", UiTokens.font_heading())
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc: Label = UiBuild.label()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override(&"font_size", UiTokens.FONT_SMALL)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var st: Label = UiBuild.caption()
		var choice: Label = UiBuild.label()
		choice.add_theme_color_override(&"font_color", UiTokens.CYAN)
		choice.add_theme_font_size_override(&"font_size", UiTokens.FONT_SMALL)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.visible = false
		# Caption row: "CARD 1 · 200 PTS" left, the state right (keeps 3 rows of cards on a 720p screen).
		var head_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_row.add_child(title)
		head_row.add_child(st)
		for c: Control in [head_row, nm, choice, desc]:  # D-164: the pick sits under the name, never clipped
			cv.add_child(c)
		var p: PanelContainer = UiBuild.panel(cv)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(UiBuild.focus_panel(p))  # readable with the pad (scrolls the grid)
		p.gui_input.connect(_on_card_input.bind(i))
		card_panels.append(p)
		card_choice_labels.append(choice)
		card_title_labels.append(title)
		card_name_labels.append(nm)
		card_desc_labels.append(desc)
		card_state_labels.append(st)
	# Unlock (and why it is blocked) sit on the deck's title row, so three card rows fit at 720p.
	reason_label = UiBuild.label()
	reason_label.add_theme_color_override(&"font_color", tweak.reason_color)
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_button = UiBuild.button(&"ui.perks.equip")  # placed in the footer by build_ui
	unlock_button = UiBuild.button(&"ui.perks.all_unlocked")
	unlock_button.custom_minimum_size = Vector2(360, 0)
	equip_button.pressed.connect(func() -> void: equip(preview_deck))
	unlock_button.pressed.connect(func() -> void: unlock_next(preview_deck))
	head.add_child(reason_label)
	head.add_child(unlock_button)
	return v


## Show a deck's cards on the right (no profile change).
func preview(deck_id: StringName) -> void:
	preview_deck = deck_id
	refresh()


## Equip a deck: Loadout.perk_deck and perk_deck_cards (its unlocked count). Saves. False if unknown.
func equip(deck_id: StringName) -> bool:
	if not PerkProgress.equip(profile, deck_id, tweak):
		return false
	preview_deck = deck_id
	_commit()
	return true


## D-164: whether card `index` of the previewed deck has a pick (Copycat "choices" or the "mimic" card).
func card_choosable(index: int) -> bool:
	var deck: PerkDeckDef = PerkProgress.deck(preview_deck)
	if deck == null or index < 0 or index >= deck.cards.size():
		return false
	var card: Dictionary = deck.cards[index]
	return not (card.get("choices", []) as Array).is_empty() or bool(card.get("mimic", false))


## D-164: the next pick on card `index`: the next of its choices, or the next mimicable deck (wrapping). Saves.
func cycle_choice(index: int) -> void:
	if not card_choosable(index):
		return
	var deck: PerkDeckDef = PerkProgress.deck(preview_deck)
	var card: Dictionary = deck.cards[index]
	var choices: Array = card.get("choices", []) as Array
	if not choices.is_empty():
		var picks: Dictionary = profile.loadout.perk_choices.duplicate()
		picks[index] = (LoadoutResolver.chosen_option(profile.loadout, deck, index) + 1) % choices.size()
		profile.loadout.perk_choices = picks
	else:
		var ids: Array[StringName] = mimic_options(deck.id)
		if ids.is_empty():
			return
		profile.loadout.perk_mimic_deck = ids[(ids.find(profile.loadout.perk_mimic_deck) + 1) % ids.size()]
	_commit()


## D-164: the decks a mimic card can copy, in deck-list order (mimicable, not `deck_id` itself).
func mimic_options(deck_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: PerkDeckDef in _decks:
		if d.mimicable and d.id != deck_id:
			out.append(d.id)
	return out


func _on_card_input(event: InputEvent, index: int) -> void:
	var click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if (click or event.is_action_pressed(&"ui_accept")) and card_choosable(index):
		cycle_choice(index)
		card_panels[index].accept_event()


## Unlock the next card of a deck with perk points. Saves on success. Returns PerkProgress' dict.
func unlock_next(deck_id: StringName) -> Dictionary:
	var r: Dictionary = PerkProgress.unlock_next(profile, deck_id, tweak)
	if bool(r["ok"]):
		_commit()
	else:
		refresh()
	return r


func refresh() -> void:
	points_label.text = UiText.group_digits(PerkProgress.available(profile, tweak))
	for d: PerkDeckDef in _decks:
		var n: int = PerkProgress.cards_unlocked(profile, d.id, tweak)
		var key: StringName = &"ui.perks.deck_entry_active" if d.id == profile.loadout.perk_deck else &"ui.perks.deck_entry"
		(deck_buttons[d.id] as Button).text = UiText.t(key, {"name": UiText.t(StringName("%s.name" % d.id)),
				"cards": n, "total": d.cards.size()})
		(deck_buttons[d.id] as Button).set_pressed_no_signal(d.id == preview_deck)
	var deck: PerkDeckDef = PerkProgress.deck(preview_deck)
	if deck == null:
		return
	var unlocked: int = PerkProgress.cards_unlocked(profile, deck.id, tweak)
	var equipped: bool = deck.id == profile.loadout.perk_deck
	deck_name_label.text = UiText.t(StringName("%s.name" % deck.id))
	deck_status_label.text = UiText.t(&"ui.perks.equipped" if equipped else &"ui.perks.not_equipped")
	deck_desc_label.text = UiText.t(StringName(deck.description)) if deck.description != "" else ""
	for i: int in range(card_panels.size()):
		_refresh_card(i, deck, unlocked)
	equip_button.disabled = equipped
	equip_button.text = UiText.t(&"ui.perks.equipped" if equipped else &"ui.perks.equip")
	var r: Dictionary = PerkProgress.can_unlock_next(profile, deck.id, tweak)
	unlock_button.disabled = not bool(r["ok"])
	if StringName(r["reason"]) == PerkProgress.REASON_ALL:
		unlock_button.text = UiText.t(&"ui.perks.all_unlocked")
	else:
		unlock_button.text = UiText.t(&"ui.perks.unlock_next", {"n": int(r["index"]), "cost": UiText.group_digits(int(r["cost"]))})
	reason_label.text = ""
	if StringName(r["reason"]) == PerkProgress.REASON_POINTS:
		reason_label.text = UiText.t(&"ui.perks.reason.not_enough_points",
				{"cost": UiText.group_digits(int(r["cost"])), "have": UiText.group_digits(int(r["have"]))})


func _refresh_card(i: int, deck: PerkDeckDef, unlocked: int) -> void:
	var p: PanelContainer = card_panels[i]
	p.visible = i < deck.cards.size()
	if not p.visible:
		return
	var card: Dictionary = deck.cards[i]
	card_title_labels[i].text = UiText.t(&"ui.perks.card_header",
			{"n": i + 1, "cost": UiText.group_digits(int(card.get("cost", 0)))})
	card_name_labels[i].text = UiText.t(StringName(String(card.get("name", ""))))
	var desc: String = UiText.t(StringName(String(card.get("desc", ""))))
	if i == deck.cards.size() - 1:
		desc += "\n" + UiText.t(&"perk.shared.completion.desc")
	card_desc_labels[i].text = desc
	_refresh_choice(i, deck, card)
	var state: StringName = &"unlocked" if i < unlocked else (&"next" if i == unlocked else &"locked")
	card_state_labels[i].text = UiText.t(StringName("ui.perks.state.%s" % state))
	p.add_theme_stylebox_override(&"panel", _card_styles[state] as StyleBox)
	p.modulate = Color.WHITE if state != &"locked" else Color.WHITE.darkened(0.3)


## D-164: the picked bonus / copied deck under a Copycat card, with what it does.
func _refresh_choice(i: int, deck: PerkDeckDef, card: Dictionary) -> void:
	var l: Label = card_choice_labels[i]
	var choices: Array = card.get("choices", []) as Array
	l.visible = true
	if not choices.is_empty():
		var c: Dictionary = choices[LoadoutResolver.chosen_option(profile.loadout, deck, i)] as Dictionary
		l.text = UiText.t(&"ui.perks.choice", {"name": UiText.t(StringName(String(c.get("name", "")))),
				"desc": UiText.t(StringName(String(c.get("desc", ""))))})
	elif bool(card.get("mimic", false)):
		var m: PerkDeckDef = LoadoutResolver.mimic_deck(profile.loadout)
		l.text = UiText.t(&"ui.perks.mimic_none") if m == null else UiText.t(&"ui.perks.mimic",
				{"name": UiText.t(StringName("%s.name" % m.id)), "desc": UiText.t(StringName("%s.mimic.desc" % m.id))})
	else:
		l.visible = false


func _commit() -> void:
	SaveService.save_profile(profile, profile_slot)
	refresh()
	perks_changed.emit()


func _max_cards() -> int:
	var n: int = 0
	for d: PerkDeckDef in _decks:
		n = maxi(n, d.cards.size())
	return n


func _build_card_styles() -> void:
	var base: StyleBoxFlat = UiBuild.theme().get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	var colors: Dictionary = {
		&"unlocked": tweak.card_unlocked_color, &"next": tweak.card_next_color, &"locked": tweak.card_locked_color,
	}
	for state: Variant in colors:
		var sb: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
		sb.border_color = colors[state] as Color
		sb.content_margin_left = UiTokens.S3
		sb.content_margin_right = UiTokens.S3
		sb.content_margin_top = UiTokens.S1
		sb.content_margin_bottom = UiTokens.S1
		_card_styles[state] = sb


## Deck list is a vertical chain; right from any deck -> Equip (footer, bottom right); Unlock sits
## above Equip; Back <-> Equip along the footer.
func _wire_focus() -> void:
	for d: PerkDeckDef in _decks:
		var b: Button = deck_buttons[d.id] as Button
		b.focus_neighbor_right = b.get_path_to(equip_button)
		b.focus_neighbor_left = b.get_path_to(b)
	UiNav.chain_horizontal([back_button, equip_button] as Array[Control], false)
	_link_cards()
	var first: Button = deck_buttons[_decks[0].id] as Button if not _decks.is_empty() else null
	unlock_button.focus_neighbor_bottom = unlock_button.get_path_to(equip_button)
	unlock_button.focus_neighbor_top = unlock_button.get_path_to(unlock_button)
	unlock_button.focus_neighbor_right = unlock_button.get_path_to(equip_button)
	equip_button.focus_neighbor_top = equip_button.get_path_to(unlock_button)
	equip_button.focus_neighbor_bottom = equip_button.get_path_to(equip_button)
	if first != null:
		unlock_button.focus_neighbor_left = unlock_button.get_path_to(first)
		back_button.focus_neighbor_left = back_button.get_path_to(first)
		back_button.focus_neighbor_top = back_button.get_path_to(first)


func _focus_preview() -> void:
	var b: Button = deck_buttons.get(preview_deck, null) as Button
	if b != null and b.is_inside_tree() and is_visible_in_tree():
		b.grab_focus()


func focus_default() -> void:
	if is_visible_in_tree() and deck_buttons.has(preview_deck):
		_focus_preview.call_deferred()
	else:
		super()


## Pad / arrows: right from any deck enters the card grid; the grid moves by rows and columns; left
## from the first column returns to the decks.
func _link_cards() -> void:
	if card_panels.is_empty():
		return
	var first_deck: Control = null
	for id: Variant in deck_buttons:
		var b: Control = deck_buttons[id] as Control
		b.focus_neighbor_right = b.get_path_to(card_panels[0])
		if first_deck == null:
			first_deck = b
	for i: int in range(card_panels.size()):
		var c: PanelContainer = card_panels[i]
		var col: int = i % CARD_COLUMNS
		if col > 0:
			c.focus_neighbor_left = c.get_path_to(card_panels[i - 1])
		elif first_deck != null:
			c.focus_neighbor_left = c.get_path_to(first_deck)
		if col < CARD_COLUMNS - 1 and i + 1 < card_panels.size():
			c.focus_neighbor_right = c.get_path_to(card_panels[i + 1])
		if i >= CARD_COLUMNS:
			c.focus_neighbor_top = c.get_path_to(card_panels[i - CARD_COLUMNS])
		if i + CARD_COLUMNS < card_panels.size():
			c.focus_neighbor_bottom = c.get_path_to(card_panels[i + CARD_COLUMNS])
		else:
			c.focus_neighbor_bottom = c.get_path_to(equip_button)
