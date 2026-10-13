## Perk deck screen (B4-03, pd2_fidelity P4). Owner: ENV B. Opened from the loadout screen.
## Left: the 14 decks (unlocked cards n/9, the equipped one marked). Focus/hover previews a deck;
## pressing it equips it. Right: the previewed deck's 9 cards (name, text, cost, unlocked / next /
## locked), "Unlock next card" (perk points, PerkProgress) and "Equip". Equip writes
## Loadout.perk_deck + perk_deck_cards; every change is saved via SaveService.
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
	var root: VBoxContainer = UiBuild.vbox(14)
	UiBuild.screen_margin(self, root, 48)
	var top: HBoxContainer = UiBuild.hbox(32)
	top.add_child(UiBuild.label(&"ui.perks.title", UiBuild.HEADER))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	points_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	top.add_child(points_label)
	root.add_child(top)
	if tweak.dev_unlock_all_perks:
		root.add_child(UiBuild.label(&"ui.perks.dev_unlocked", UiBuild.DIM))
	var body: HBoxContainer = UiBuild.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(420, 0)
	body.add_child(scroll)
	var list: VBoxContainer = UiBuild.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for d: PerkDeckDef in _decks:
		var b: Button = UiBuild.button(&"ui.perks.title")
		b.custom_minimum_size = Vector2(400, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override(&"font_size", 22)
		b.pressed.connect(equip.bind(d.id))
		b.focus_entered.connect(preview.bind(d.id))
		b.mouse_entered.connect(preview.bind(d.id))
		list.add_child(b)
		deck_buttons[d.id] = b
	body.add_child(_build_deck_view())
	var bottom: HBoxContainer = UiBuild.hbox(16)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	bottom.add_child(back_button)
	var hint: Label = UiBuild.label(&"ui.perks.hint", UiBuild.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	root.add_child(bottom)
	for d: PerkDeckDef in _decks:
		focus_chain.append(deck_buttons[d.id] as Control)
	focus_chain.append(equip_button)
	focus_chain.append(unlock_button)
	focus_chain.append(back_button)
	var start: StringName = profile.loadout.perk_deck
	preview(start if deck_buttons.has(start) else (_decks[0].id if not _decks.is_empty() else &""))


func _build_deck_view() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = UiBuild.hbox(20)
	deck_name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	deck_status_label = UiBuild.label(&"", UiBuild.DIM)
	deck_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(deck_name_label)
	head.add_child(deck_status_label)
	v.add_child(head)
	deck_desc_label = UiBuild.label()
	deck_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(deck_desc_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for i: int in range(_max_cards()):
		var cv: VBoxContainer = UiBuild.vbox(4)
		var title: Label = UiBuild.label(&"", UiBuild.DIM)
		var nm: Label = UiBuild.label()
		nm.add_theme_font_size_override(&"font_size", 22)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc: Label = UiBuild.label()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override(&"font_size", 21)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var st: Label = UiBuild.label(&"", UiBuild.DIM)
		for c: Control in [title, nm, desc, st]:
			cv.add_child(c)
		var p: PanelContainer = UiBuild.panel(cv)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(p)
		card_panels.append(p)
		card_title_labels.append(title)
		card_name_labels.append(nm)
		card_desc_labels.append(desc)
		card_state_labels.append(st)
	reason_label = UiBuild.label()
	reason_label.add_theme_color_override(&"font_color", tweak.reason_color)
	v.add_child(reason_label)
	var h: HBoxContainer = UiBuild.hbox(16)
	equip_button = UiBuild.button(&"ui.perks.equip")
	unlock_button = UiBuild.button(&"ui.perks.all_unlocked")
	unlock_button.custom_minimum_size = Vector2(420, 0)
	equip_button.pressed.connect(func() -> void: equip(preview_deck))
	unlock_button.pressed.connect(func() -> void: unlock_next(preview_deck))
	h.add_child(equip_button)
	h.add_child(unlock_button)
	v.add_child(h)
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


## Unlock the next card of a deck with perk points. Saves on success. Returns PerkProgress' dict.
func unlock_next(deck_id: StringName) -> Dictionary:
	var r: Dictionary = PerkProgress.unlock_next(profile, deck_id, tweak)
	if bool(r["ok"]):
		_commit()
	else:
		refresh()
	return r


func refresh() -> void:
	points_label.text = UiText.t(&"ui.perks.points", {"points": UiText.group_digits(PerkProgress.available(profile, tweak))})
	for d: PerkDeckDef in _decks:
		var n: int = PerkProgress.cards_unlocked(profile, d.id, tweak)
		var key: StringName = &"ui.perks.deck_entry_active" if d.id == profile.loadout.perk_deck else &"ui.perks.deck_entry"
		(deck_buttons[d.id] as Button).text = UiText.t(key, {"name": UiText.t(StringName("%s.name" % d.id)),
				"cards": n, "total": d.cards.size()})
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
	var state: StringName = &"unlocked" if i < unlocked else (&"next" if i == unlocked else &"locked")
	card_state_labels[i].text = UiText.t(StringName("ui.perks.state.%s" % state))
	p.add_theme_stylebox_override(&"panel", _card_styles[state] as StyleBox)
	var dim: float = 1.0 if state != &"locked" else 0.7
	p.modulate = Color(dim, dim, dim)


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
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 10.0
		_card_styles[state] = sb


## Deck list is a vertical chain; right from any deck -> Equip; Equip <-> Unlock; down -> Back.
func _wire_focus() -> void:
	for d: PerkDeckDef in _decks:
		var b: Button = deck_buttons[d.id] as Button
		b.focus_neighbor_right = b.get_path_to(equip_button)
		b.focus_neighbor_left = b.get_path_to(b)
	UiNav.chain_horizontal([equip_button, unlock_button] as Array[Control], false)
	var first: Button = deck_buttons[_decks[0].id] as Button if not _decks.is_empty() else null
	for c: Control in [equip_button, unlock_button]:
		c.focus_neighbor_bottom = c.get_path_to(back_button)
		c.focus_neighbor_top = c.get_path_to(c)
	if first != null:
		equip_button.focus_neighbor_left = equip_button.get_path_to(first)
		back_button.focus_neighbor_left = back_button.get_path_to(first)
	back_button.focus_neighbor_top = back_button.get_path_to(equip_button)
	back_button.focus_neighbor_right = back_button.get_path_to(equip_button)


func _focus_preview() -> void:
	var b: Button = deck_buttons.get(preview_deck, null) as Button
	if b != null and b.is_inside_tree() and is_visible_in_tree():
		b.grab_focus()


func focus_default() -> void:
	if is_visible_in_tree() and deck_buttons.has(preview_deck):
		_focus_preview.call_deferred()
	else:
		super()
