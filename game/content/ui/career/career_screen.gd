## Career / profile screen (B7-01). Owner: ENV B. Opened from the hub's profile panel
## (HubMenu.career_requested -> MenuFlow._open_career); Back returns to the hub.
## Shows the profile's lifetime career (Career, save v7): a record summary (level + Notoriety badge,
## heists played / won / failed, success rate, stealth vs loud wins, time on the job), money (earned,
## spent, XP, bags, small loot, payday card cash / XP, favourite weapon), combat (kills, specials, civilians, downs, custody, and
## shots / hits / headshots / accuracy only when the HeistResult carried them) and a per-heist table
## (played, won, failed, stealth, loud, best difficulty, fastest win). A counter that was never counted
## reads `ui.career.not_tracked`, never 0.
## The panels and the heist rows are focusable so keyboard / gamepad scroll the page (follow_focus).
## API: setup(profile) before or after entering the tree (null = load profile_slot); refresh().
class_name CareerScreen
extends UiScreen

## Totals keys shown in each panel, in order (label key = `ui.career.<key>`).
const RECORD_KEYS: Array[String] = ["played", "won", "failed", "stealth_wins", "loud_wins"]
const MONEY_KEYS: Array[String] = ["spending_earned", "stash_earned", "cash_spent", "offshore_spent", "xp_earned",
	"bags", "small_loot", "card_cash", "card_xp"]
const COMBAT_KEYS: Array[String] = ["kills", "specials_killed", "civilians_killed", "downs", "custody", "shots", "hits",
	"headshots"]
## Totals keys that are money amounts.
const MONEY_AMOUNTS: Array[String] = ["spending_earned", "stash_earned", "cash_spent", "offshore_spent", "small_loot",
	"card_cash"]
## Per-heist table columns (header key = `ui.career.col.<id>`).
const COLUMNS: Array[String] = ["heist", "played", "won", "failed", "stealth", "loud", "best", "fastest"]
const COLUMN_WIDTH: float = 160.0
## The two text columns (best difficulty, fastest win) are wider: their caption heads are longer.
const WIDE_COLUMN_WIDTH: float = 240.0
const HEIST_COLUMN_WIDTH: float = 300.0

@export var profile_slot: int = 0

var profile: PlayerProfile = null
var level_label: Label
var badge_label: Label
## Stat key (totals keys + "win_rate", "time_played", "accuracy", "favourite_weapon") -> its value Label.
var value_labels: Dictionary = {}
## Heist id -> its table row PanelContainer.
var heist_rows: Dictionary = {}
var table: VBoxContainer
var empty_label: Label
var back_button: Button
var _panels: Array[Control] = []
var _record_box: VBoxContainer
var _money_box: VBoxContainer
var _combat_box: VBoxContainer


func setup(p: PlayerProfile) -> void:
	profile = p
	if is_node_ready():
		refresh()


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root)
	var titles: VBoxContainer = UiBuild.header(&"ui.career.crumb", &"ui.career.title")
	titles.add_child(UiBuild.label(&"ui.career.subtitle", UiBuild.DIM))
	root.add_child(titles)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	root.add_child(scroll)
	var page: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	var cols: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	page.add_child(cols)
	_record_box = _panel_box(cols, &"ui.career.summary")
	level_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	badge_label = UiBuild.label(&"", UiBuild.DIM)
	_record_box.add_child(level_label)
	_record_box.add_child(badge_label)
	_money_box = _panel_box(cols, &"ui.career.money")
	_combat_box = _panel_box(cols, &"ui.career.combat")
	var heists: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	heists.add_child(UiBuild.label(&"ui.career.heists", UiBuild.SUBHEADER))
	heists.add_child(_header_row())
	table = UiBuild.vbox(UiTokens.S1)
	heists.add_child(table)
	empty_label = UiBuild.label(&"ui.career.empty", UiBuild.DIM)
	heists.add_child(empty_label)
	page.add_child(UiBuild.panel(heists))
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	root.add_child(UiBuild.footer(back_button))  # PO-4: a read-only page, so no primary
	refresh()


## Re-reads every value from the profile.
func refresh() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if table == null:
		return
	level_label.text = NotorietyScreen.level_text(profile.level, profile.notoriety)
	badge_label.text = NotorietyScreen.badge_text(profile.notoriety)
	_fill(_record_box, RECORD_KEYS + ["win_rate", "time_played"])
	_fill(_money_box, MONEY_KEYS + ["favourite_weapon"])
	_fill(_combat_box, COMBAT_KEYS + ["accuracy"])
	_fill_table()
	focus_chain.clear()
	focus_chain.append_array(_panels)
	for id: Variant in heist_rows:
		focus_chain.append(heist_rows[id] as Control)
	focus_chain.append(back_button)
	UiNav.chain_vertical(focus_chain)


## Display text of one stat (see value_labels for the keys); `ui.career.not_tracked` when never counted.
static func value_text(p: PlayerProfile, key: String) -> String:
	var none: String = UiText.t(&"ui.career.not_tracked")
	match key:
		"win_rate":
			var played: int = Career.total(p, Career.PLAYED)
			return _percent(float(maxi(Career.total(p, Career.WON), 0)) / float(played)) if played > 0 else none
		"time_played":
			var s: int = Career.total(p, Career.TIME_PLAYED_S)
			return UiText.t(&"ui.career.time_format", {"hours": s / 3600, "minutes": (s % 3600) / 60}) if s >= 0 else none
		"accuracy":
			var acc: float = Career.accuracy(p)
			return _percent(acc) if acc >= 0.0 else none
		"favourite_weapon":
			var w: StringName = Career.favourite_weapon(p)
			return UiText.t(UiText.item_key(w)) if w != &"" else UiText.t(&"ui.career.none")
	var n: int = Career.total(p, key)
	if n < 0:
		return none
	return UiText.money(n) if MONEY_AMOUNTS.has(key) else UiText.group_digits(n)


## Heist ids for the table: every offered heist (HeistCatalog) plus any other heist on the record, by id.
static func table_heists(p: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = HeistCatalog.ids()
	for id: Variant in Career.section(p, "heists"):
		if not out.has(StringName(String(id))):
			out.append(StringName(String(id)))
	ContentDB.sort_ids(out)
	return out


## Cell texts of one heist row, in COLUMNS order.
static func heist_cells(p: PlayerProfile, heist_id: StringName) -> Array[String]:
	var h: Dictionary = Career.heist(p, heist_id)
	var out: Array[String] = [UiText.t(StringName("heist.%s.name" % heist_id))]
	for k: String in [Career.PLAYED, Career.WON, Career.FAILED, Career.STEALTH_WINS, Career.LOUD_WINS]:
		out.append(UiText.group_digits(int(h.get(k, 0))))
	var best: int = Career.best_difficulty(p, heist_id)
	out.append(UiText.t(UiText.difficulty_key(best)) if best >= 0 else UiText.t(&"ui.career.not_tracked"))
	var fastest: float = Career.fastest_win_s(p, heist_id)
	out.append(UiText.clock(fastest) if fastest > 0.0 else UiText.t(&"ui.career.not_tracked"))
	return out


static func _percent(v: float) -> String:
	return UiText.t(&"ui.career.percent", {"value": "%.1f" % (v * 100.0)})


func _panel_box(parent: Control, title: StringName) -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_child(UiBuild.label(title, UiBuild.SUBHEADER))
	var panel: PanelContainer = UiBuild.panel(v)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiBuild.focus_panel(panel)
	parent.add_child(panel)
	_panels.append(panel)
	return v


func _fill(box: VBoxContainer, keys: Array) -> void:
	for k: Variant in keys:
		var key: String = String(k)
		var l: Label = value_labels.get(key, null) as Label
		if l == null:
			var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
			var name_label: Label = UiBuild.caption(StringName("ui.career.%s" % key))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(name_label)
			l = UiBuild.label()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
			box.add_child(row)
			value_labels[key] = l
		l.text = value_text(profile, key)
	var acc_row: Node = (value_labels.get("accuracy", null) as Label).get_parent() if value_labels.has("accuracy") else null
	if acc_row != null:
		(acc_row as Control).visible = Career.accuracy(profile) >= 0.0


func _header_row() -> MarginContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	var pad: MarginContainer = MarginContainer.new()  # lines the column heads up with the row panels' padding
	pad.add_theme_constant_override(&"margin_left", UiTokens.S4)
	pad.add_child(row)
	for c: String in COLUMNS:
		var l: Label = UiBuild.caption(StringName("ui.career.col.%s" % c))
		l.custom_minimum_size = Vector2(column_width(COLUMNS.find(c)), 0)
		row.add_child(l)
	return pad


func _fill_table() -> void:
	for c: Node in table.get_children():
		table.remove_child(c)
		c.queue_free()
	heist_rows.clear()
	var any: bool = false
	for id: StringName in table_heists(profile):
		var row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
		var cells: Array[String] = heist_cells(profile, id)
		for i: int in range(cells.size()):
			var l: Label = UiBuild.label()
			l.text = cells[i]
			l.custom_minimum_size = Vector2(column_width(i), 0)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(l)
		var panel: PanelContainer = UiBuild.panel(row)
		UiBuild.focus_panel(panel)
		panel.name = "Heist_%s" % id
		table.add_child(panel)
		heist_rows[id] = panel
		any = any or not Career.heist(profile, id).is_empty()
	empty_label.visible = not any


## Width of table column `i` (COLUMNS order).
static func column_width(i: int) -> float:
	if i == 0:
		return HEIST_COLUMN_WIDTH
	return WIDE_COLUMN_WIDTH if i >= COLUMNS.size() - 2 else COLUMN_WIDTH
