## The safehouse hub, 2D layer (pd2_fidelity C9, roadmap B4-07). Owner: ENV B.
## Lists the safehouse stations (HubStationList, data/ui/hub_stations.tres) as cards: The Board,
## Planning table, Armory, Mask bench, Firing range door, plus a profile summary (level, XP bar,
## spending cash, stash, skill and perk points). ENV C's 3D safehouse will host the same stations;
## its interactables call MenuFlow.open_station(id), the same path these cards use.
##
## API (MenuFlow wires it): setup(profile) before or after entering the tree; refresh_profile(p).
## B-PP-1: Career and Notoriety open only via their station cards (profile / notoriety); the duplicate
## side-panel buttons are gone. The signals stay for API compatibility.
## Signals: station_requested(id) (a card pressed); achievements_requested() (the profile panel's
## Achievements button, B4-20); options_requested() (its Options button, B5-01); notoriety_requested() (its
## Notoriety button, B5-02); career_requested() (its Career button, B7-01: CareerScreen);
## back_requested() (UiScreen, Esc / gamepad B, and the Main Menu button). The
## profile panel shows the Notoriety rank badge (roman numeral) next to the level and in its own line.
class_name HubMenu
extends UiScreen

signal station_requested(station_id: StringName)
signal achievements_requested()
## PO-19: the profile panel's Bot Crew button.
signal crew_requested()
signal options_requested()
signal notoriety_requested()
signal career_requested()
## Lead: relaunch the last job (QuickPlay) from the hub.
signal continue_requested()

## Station cards per row (B-PP-2).
## D-111 (style.md §11): a 3x3 grid of icon + title cards; the focused card's line shows in the side panel.
const CARD_COLUMNS: int = 3
const POINTS_STATION: StringName = &"armory"
const CARD_HEIGHT: float = 196.0
## PO-4: where a new player is pointed (the Board: live contracts, the PD2 Crime.net equivalent).
const START_STATION: StringName = &"board"

@export var profile_slot: int = 0

var stations: HubStationList
var profile: PlayerProfile = null
## Station id -> its card Button.
var station_buttons: Dictionary = {}
var back_button: Button
## PQ-B-8: full description of the focused / hovered station card (cards trim it with an ellipsis).
var station_detail: Label
var name_label: Label
var level_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var spending_label: Label
var stash_label: Label
var skill_points_label: Label
## Notoriety rank badge line (B5-02).
var notoriety_label: Label
## Profile panel button -> achievements_requested (B4-20).
var achievements_button: Button
## PO-19: Bot Crew (crew_requested).
var crew_button: Button
## Profile panel button -> options_requested (B5-01).
var options_button: Button
## Quick Play: "Continue · <heist> · <difficulty>", hidden without a playable last job.
var continue_button: Button
## PO-4 first-time pointer: the "START HERE" chip on the Board card while the profile has never
## played a heist (is_first_time: career totals "played" absent / 0).
var start_here: Label


func setup(p: PlayerProfile) -> void:
	profile = p
	if is_node_ready():
		refresh_profile(p)


func build_ui() -> void:
	stations = HubStationList.load_default()
	var root: VBoxContainer = UiBuild.vbox(28)
	UiBuild.screen_margin(self, root)
	root.add_child(_build_header())
	var body: HBoxContainer = UiBuild.hbox(48)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# B-PP-2: nine stations in one column overflowed the 1080-unit canvas (= 1280x720 under canvas_items
	# stretch). Two columns of compact cards fit every card on screen; the scroll stays as a safety net.
	var list: GridContainer = GridContainer.new()
	list.name = "StationGrid"
	list.columns = CARD_COLUMNS
	list.add_theme_constant_override("h_separation", 14)
	list.add_theme_constant_override("v_separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.name = "StationScroll"
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	list_scroll.add_child(list)
	body.add_child(list_scroll)
	for s: HubStation in stations.stations:
		var b: Button = _station_card(s)
		list.add_child(b)
		station_buttons[s.id] = b
		focus_chain.append(b)
	var side: VBoxContainer = UiBuild.vbox(14)
	side.custom_minimum_size = Vector2(440, 0)
	body.add_child(side)
	station_detail = UiBuild.label(&"")
	station_detail.name = "StationDetail"
	station_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	station_detail.custom_minimum_size = Vector2(0, 72)
	side.add_child(station_detail)
	side.add_child(_build_profile_panel())
	achievements_button = UiBuild.button(&"ui.hub.achievements")
	achievements_button.pressed.connect(achievements_requested.emit)
	side.add_child(achievements_button)
	focus_chain.append(achievements_button)
	crew_button = UiBuild.button(&"ui.hub.crew")
	crew_button.pressed.connect(crew_requested.emit)
	side.add_child(crew_button)
	focus_chain.append(crew_button)
	options_button = UiBuild.button(&"ui.menu.options")
	options_button.pressed.connect(options_requested.emit)
	side.add_child(options_button)
	focus_chain.append(options_button)
	var footer: HBoxContainer = UiBuild.hbox(16)
	root.add_child(footer)
	back_button = UiBuild.back(UiBuild.button(&"ui.hub.main_menu"))
	back_button.pressed.connect(back_requested.emit)
	footer.add_child(back_button)
	focus_chain.append(back_button)
	var push: Control = Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(push)
	# Quick Play bottom right, like the forward action on the other screens.
	continue_button = UiBuild.primary(UiBuild.button(&"ui.menu.continue"))
	continue_button.pressed.connect(continue_requested.emit)
	footer.add_child(continue_button)
	focus_chain.append(continue_button)
	refresh_profile(profile)


func _ready() -> void:
	super()
	chain_grid()


## PQ-B-3: arrow / d-pad neighbours that match the 2-column card grid (UiScreen's vertical chain
## would send "down" to the card on the right). Right of the right column goes to the profile panel,
## below the last row to Main Menu. Tab order (focus_next) keeps the vertical chain.
func chain_grid() -> void:
	var cards: Array[Button] = []
	for s: HubStation in stations.stations:
		cards.append(station_buttons[s.id] as Button)
	var n: int = cards.size()
	if n == 0:
		return
	var side_first: Control = achievements_button
	for i: int in range(n):
		var b: Button = cards[i]
		var col: int = i % CARD_COLUMNS
		b.set_focus_neighbor(SIDE_LEFT, b.get_path_to(cards[i - 1]) if col > 0 else NodePath(""))
		var right: Control = cards[i + 1] if col < CARD_COLUMNS - 1 and i + 1 < n else side_first
		b.set_focus_neighbor(SIDE_RIGHT, b.get_path_to(right))
		var up: Control = cards[i - CARD_COLUMNS] if i >= CARD_COLUMNS else back_button
		b.set_focus_neighbor(SIDE_TOP, b.get_path_to(up))
		var down: Control = cards[i + CARD_COLUMNS] if i + CARD_COLUMNS < n else back_button
		b.set_focus_neighbor(SIDE_BOTTOM, b.get_path_to(down))
	for c: Control in [achievements_button, crew_button, options_button]:
		c.set_focus_neighbor(SIDE_LEFT, c.get_path_to(cards[0]))
	back_button.set_focus_neighbor(SIDE_TOP, back_button.get_path_to(cards[n - 1]))
	back_button.set_focus_neighbor(SIDE_BOTTOM, back_button.get_path_to(cards[0]))
	_wire_continue()


## Quick Play sits bottom right: Main Menu <-> Continue, Options above it. Linked only while Continue shows:
## a hidden explicit neighbour traps the d-pad (gate82 class, test_menu_reach).
func _wire_continue() -> void:
	var on: bool = continue_button.visible
	back_button.set_focus_neighbor(SIDE_RIGHT, back_button.get_path_to(continue_button) if on else NodePath())
	continue_button.set_focus_neighbor(SIDE_LEFT, continue_button.get_path_to(back_button))
	continue_button.set_focus_neighbor(SIDE_TOP, continue_button.get_path_to(options_button))
	options_button.set_focus_neighbor(SIDE_BOTTOM, options_button.get_path_to(continue_button) if on else NodePath())


## D-115 new-player flow: true while `p` has never finished a heist (no payday banked: career totals "played"
## absent or 0). The 2D hub's START HERE chip and the 3D safehouse's first-time note follow it. (The chip used to
## read p.career["played"], which Career never writes: it never went away.)
static func is_first_time(p: PlayerProfile) -> bool:
	return p == null or Career.total(p, Career.PLAYED) <= 0


func _refresh_continue(p: PlayerProfile) -> void:
	if continue_button == null:
		return
	var job: Dictionary = QuickPlay.last(p)
	continue_button.visible = not job.is_empty()
	if not job.is_empty():
		continue_button.text = QuickPlay.label(job)
	if back_button != null and options_button != null:
		_wire_continue()


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = UiBuild.hbox(20)
	header.add_child(UiAccent.strip(UiAccent.table().fallback, 6.0))
	var titles: VBoxContainer = UiBuild.vbox(2)
	titles.add_child(UiBuild.caption(&"ui.menu.title"))
	titles.add_child(UiBuild.label(&"ui.hub.title", UiBuild.HEADER))
	titles.add_child(UiBuild.label(&"ui.hub.subtitle", UiBuild.DIM))
	header.add_child(titles)
	return header


func _station_card(s: HubStation) -> Button:
	var b: Button = Button.new()
	b.theme_type_variation = &"StationButton"
	b.focus_mode = Control.FOCUS_ALL
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = UiText.t(s.desc_key)
	b.pressed.connect(station_requested.emit.bind(s.id))
	b.focus_entered.connect(show_station_detail.bind(s.id))
	b.mouse_entered.connect(show_station_detail.bind(s.id))
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, UiTokens.S3)
	for side: String in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	b.add_child(m)
	# D-111: a tile (icon top, title and state word at the bottom) so the 3x3 grid fills the body.
	var row: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	var icon: HubStationIcon = HubStationIcon.new()
	icon.kind = s.icon_kind
	icon.color = UiBuild.theme().get_color(&"font_color", &"HeaderLabel")
	icon.tile_color = UiAccent.app_bg()
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var text: VBoxContainer = UiBuild.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title: Label = UiBuild.label(s.title_key, UiBuild.SUBHEADER)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	# D-111: no description on the card (it shows in the side panel on focus); at most one state word.
	if s.id == POINTS_STATION:
		skill_points_label = UiBuild.caption(&"")
		skill_points_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
		skill_points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(skill_points_label)
	if s.id == START_STATION:
		start_here = UiBuild.caption(&"ui.hub.start_here")
		start_here.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
		start_here.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		start_here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_here.visible = false
		start_here.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Under the title, like the Armory's points word (one state word per card).
		var head: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(head)
		head.add_child(start_here)
	# A Button does not grow with its children: follow the content so a two-line description stays
	# inside the card (lane 13 16:10 capture: the second line spilled under the next card).
	m.minimum_size_changed.connect(func() -> void:
		b.custom_minimum_size.y = maxf(CARD_HEIGHT, m.get_combined_minimum_size().y))
	return b


func _build_profile_panel() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_label)
	level_label = UiBuild.label(&"", UiBuild.HEADER)
	v.add_child(level_label)
	notoriety_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	v.add_child(notoriety_label)
	xp_bar = UiBuild.bar(Color(1, 1, 1, 1), Vector2(0, 14))
	xp_bar.self_modulate = UiAccent.table().fallback.lightened(0.15)
	v.add_child(xp_bar)
	xp_label = UiBuild.label(&"", UiBuild.DIM)
	v.add_child(xp_label)
	var money: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	v.add_child(money)
	spending_label = UiBuild.label()
	stash_label = UiBuild.label()
	for l: Label in [spending_label, stash_label]:
		money.add_child(l)
	return UiBuild.panel(v)


## Re-reads the summary from `p` (default: the setup profile, else profile_slot from disk).
func refresh_profile(p: PlayerProfile = null) -> void:
	_refresh_continue(p if p != null else SaveService.load_profile(profile_slot))
	if p != null:
		profile = p
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if level_label == null:
		return
	if start_here != null:
		start_here.visible = is_first_time(profile)
	name_label.text = profile.profile_name
	name_label.visible = profile.profile_name != ""
	level_label.text = NotorietyScreen.level_text(profile.level, profile.notoriety)
	notoriety_label.text = NotorietyScreen.badge_text(profile.notoriety)
	notoriety_label.visible = profile.notoriety > 0  # D-111: "No notoriety yet" was noise
	var lvl: int = XpCurve.level_for_xp(profile.xp)
	if lvl >= XpCurve.max_level():
		xp_bar.value = 1.0
		xp_label.text = UiText.t(&"ui.hub.profile.xp_max")
	else:
		var into: int = profile.xp - XpCurve.xp_for_level(lvl)
		var step: int = maxi(XpCurve.step_xp(lvl + 1), 1)
		xp_bar.value = clampf(float(into) / float(step), 0.0, 1.0)
		xp_label.text = UiText.t(&"ui.hub.profile.xp", {"xp": UiText.group_digits(into), "next": UiText.group_digits(step)})
	spending_label.text = UiText.t(&"ui.menu.spending", {"amount": UiText.money(profile.cash)})
	stash_label.text = UiText.t(&"ui.menu.stash", {"amount": UiText.money(profile.stash)})
	_refresh_points()


## D-111: free skill / perk points are the Armory card's one state word ("3 SKILL POINTS"), hidden at 0.
func _refresh_points() -> void:
	if skill_points_label == null:
		return
	var skills: int = SkillPoints.points_for_level(profile.level) - SkillPoints.spent_total(profile.loadout.skills)
	var perks: int = PerkProgress.available(profile, ProgressionUiTweak.load_default())
	var parts: PackedStringArray = PackedStringArray()
	if skills > 0:
		parts.append(UiText.t(&"ui.hub.points.skills_one" if skills == 1 else &"ui.hub.points.skills", {"points": skills}))
	if perks > 0:
		parts.append(UiText.t(&"ui.hub.points.perks_one" if perks == 1 else &"ui.hub.points.perks", {"points": perks}))
	# r262 OF payday + hub still: "20 SKILL POINTS · 58 PERK POINTS" ran past the card at 1080p; one count per line
	# (the card grows with its content).
	skill_points_label.text = "\n".join(parts)
	skill_points_label.visible = not parts.is_empty()


## Shows station `id`'s full description in the side panel (focus or hover, PQ-B-8).
func show_station_detail(station_id: StringName) -> void:
	var st: HubStation = stations.find(station_id) if stations != null else null
	if station_detail != null and st != null:
		station_detail.text = UiText.t(st.desc_key)


## The card for station `id` (null when unknown).
func station_button(station_id: StringName) -> Button:
	return station_buttons.get(station_id, null) as Button
