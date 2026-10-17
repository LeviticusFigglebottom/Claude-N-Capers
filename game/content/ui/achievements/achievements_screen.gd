## Achievements screen (B4-20, categories in B7-02). Owner: ENV B. Opened from the hub's profile panel
## (HubMenu.achievements_requested -> MenuFlow._open_achievements); Back returns to the hub.
## Rows are grouped under category headers (Achievements.CATEGORIES order, `ui.achievements.category.<id>`),
## one row per AchievementDef (Achievements.all() order): name, description, progress bar
## "progress / target" (Achievements.display_progress: career-stat achievements show the live career value,
## e.g. 37 / 100), Unlocked / In progress, and the rewards (reward_name: mask preset or part behind the
## unlock, reward parts, weapon finishes; a part still waiting for its ENV D model says so).
## Rows are focusable so keyboard/gamepad scroll the list (ScrollContainer.follow_focus).
## API: setup(profile) before or after entering the tree (null = load profile_slot); refresh().
class_name AchievementsScreen
extends UiScreen

const FINISH_PREFIX: String = "unlock.finish."
## Cards per line in each category grid.
const COLUMNS: int = 2

@export var profile_slot: int = 0

var profile: PlayerProfile = null
var count_label: Label
var list: VBoxContainer
var back_button: Button
## Achievement id -> its row PanelContainer.
var rows: Dictionary = {}
## Category id -> its header Label.
var category_labels: Dictionary = {}
## Each category's cards in grid order (Array[Control] per category), for the d-pad wiring.
var grids: Array = []
var _scroll: ScrollContainer


func setup(p: PlayerProfile) -> void:
	profile = p
	if is_node_ready():
		refresh()


func _ready() -> void:
	super()
	_wire_grid_focus()  # UiScreen._ready chains focus_chain as one column; the cards sit in a grid


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root)
	var header: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	var titles: VBoxContainer = UiBuild.header(&"ui.achievements.crumb", &"ui.achievements.title")
	titles.add_child(UiBuild.label(&"ui.achievements.subtitle", UiBuild.DIM))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	count_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	var count: VBoxContainer = UiBuild.field(&"ui.achievements.count_caption", count_label)
	count.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(count)
	root.add_child(header)
	var scroll: ScrollContainer = ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)
	list = UiBuild.vbox(UiTokens.S2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	root.add_child(UiBuild.footer(back_button))  # PO-4: a read-only page, so no primary
	refresh()


## Rebuilds every row from the profile.
func refresh() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if list == null:
		return
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	rows.clear()
	category_labels.clear()
	focus_chain.clear()
	grids.clear()
	var defs: Array[AchievementDef] = Achievements.shown()  # a staged (hidden) heist's set stays off the screen
	var unlocked: int = 0
	for cat: StringName in _categories(defs):
		# Category head: a caption over a hairline (style.md §1, labels are captions).
		var header: Label = UiBuild.caption(StringName("ui.achievements.category.%s" % cat))
		var head_box: VBoxContainer = UiBuild.vbox(UiTokens.S1)
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(0, UiTokens.S2)
		head_box.add_child(gap)
		head_box.add_child(header)
		head_box.add_child(HSeparator.new())
		list.add_child(head_box)
		category_labels[cat] = header
		# Lane 2 audit: one card per line showed 4 of 41 at a time; two columns show twice as many.
		var grid: GridContainer = GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
		grid.add_theme_constant_override(&"v_separation", UiTokens.S2)
		list.add_child(grid)
		var cat_rows: Array[Control] = []
		for a: AchievementDef in defs:
			if a.category != cat:
				continue
			if Achievements.is_unlocked(profile, a.id):
				unlocked += 1
			var row: PanelContainer = _row(a)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(row)
			rows[a.id] = row
			if focus_chain.is_empty():
				# The first row's focus shows the list from the top (its category head stays in view).
				row.focus_entered.connect(func() -> void: _scroll.set_deferred(&"scroll_vertical", 0))
			focus_chain.append(row)
			cat_rows.append(row)
		grids.append(cat_rows)
	focus_chain.append(back_button)
	_wire_grid_focus()
	count_label.text = UiText.t(&"ui.achievements.count", {"unlocked": unlocked, "total": defs.size()})


## D-pad over the category grids: left / right within a line, up / down within a column (across a category
## break to the same column of the next / previous category, else its last / first card), Back below all.
func _wire_grid_focus() -> void:
	var cells: Array[Control] = []
	var col_of: Dictionary = {}
	var cat_of: Dictionary = {}
	for ci: int in range(grids.size()):
		var g: Array[Control] = grids[ci]
		for i: int in range(g.size()):
			cells.append(g[i])
			col_of[g[i]] = i % COLUMNS
			cat_of[g[i]] = ci
	for c: Control in cells:
		var g: Array[Control] = grids[int(cat_of[c])]
		var i: int = g.find(c)
		var line: int = i - i % COLUMNS
		c.focus_neighbor_left = c.get_path_to(g[i - 1]) if i > line else NodePath()
		c.focus_neighbor_right = c.get_path_to(g[i + 1]) if i + 1 < mini(line + COLUMNS, g.size()) else NodePath()
		c.focus_neighbor_bottom = c.get_path_to(_vertical(int(cat_of[c]), i, 1))
		var up: Control = _vertical(int(cat_of[c]), i, -1)
		c.focus_neighbor_top = c.get_path_to(up) if up != null else NodePath()
		c.focus_next = c.focus_neighbor_bottom
		c.focus_previous = c.focus_neighbor_top
	if not cells.is_empty():
		back_button.focus_neighbor_top = back_button.get_path_to(cells[cells.size() - 1])
		back_button.focus_previous = back_button.focus_neighbor_top


## The card `step` lines below (+1) / above (-1) card `i` of category `ci` in its column; Back below the
## last line, null above the first.
func _vertical(ci: int, i: int, step: int) -> Control:
	var g: Array[Control] = grids[ci]
	var j: int = i + step * COLUMNS
	if j >= 0 and j < g.size():
		return g[j]
	if step > 0 and i < (g.size() - 1) - (g.size() - 1) % COLUMNS:
		return g[g.size() - 1]  # nothing under it in the short last line: that line's card
	var nci: int = ci + step
	while nci >= 0 and nci < grids.size() and (grids[nci] as Array).is_empty():
		nci += step
	if nci < 0:
		return null
	if nci >= grids.size():
		return back_button
	var n: Array[Control] = grids[nci]
	var col: int = i % COLUMNS
	if step > 0:
		return n[mini(col, n.size() - 1)]
	var last_line: int = (n.size() - 1) - (n.size() - 1) % COLUMNS
	return n[mini(last_line + col, n.size() - 1)]


func _row(a: AchievementDef) -> PanelContainer:
	var done: bool = Achievements.is_unlocked(profile, a.id)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var head: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	var title: Label = UiBuild.label(a.name_key, UiBuild.SUBHEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var status: Label = UiBuild.caption(&"ui.achievements.unlocked" if done else &"ui.achievements.locked")
	status.name = "Status"
	if done:
		status.add_theme_color_override(&"font_color", UiTokens.OK)
	head.add_child(status)
	v.add_child(head)
	var desc: Label = UiBuild.label(a.desc_key, UiBuild.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var bar_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	var bar: ProgressBar = UiBuild.bar(UiTokens.OK if done else UiTokens.PAPER_DIM, Vector2(320, UiTokens.S2))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.name = "Progress"
	var shown: int = Achievements.display_progress(profile, a)
	var target: int = Achievements.target_of(a)
	bar.value = clampf(float(shown) / float(target), 0.0, 1.0)
	bar_row.add_child(bar)
	bar_row.add_child(UiBuild.label(&"ui.achievements.progress", UiBuild.DIM,
			{"progress": UiText.group_digits(shown), "target": UiText.group_digits(target)}))
	v.add_child(bar_row)
	var reward: String = reward_name(a)
	if reward != "":
		var rrow: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		var cap: Label = UiBuild.caption(&"ui.achievements.reward_caption")
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rrow.add_child(cap)
		rrow.add_child(UiBuild.label(&"ui.achievements.reward", &"", {"name": reward}))
		v.add_child(rrow)
	var panel: PanelContainer = UiBuild.panel(v)
	UiBuild.focus_panel(panel)
	panel.modulate.a = 1.0 if done else 0.8
	return panel


## Display names of everything `a` grants, comma-separated ("" when nothing): the preset masks and mask
## parts behind `a.unlock` (a part waiting for its ENV D model: `ui.achievements.reward_pending`), the
## reward parts and the weapon finishes (B7-04: `unlock.finish.<id>` -> `item.finish.<id>.name`).
static func reward_name(a: AchievementDef) -> String:
	var names: Array[String] = []
	if a.unlock != &"":
		for md: MaskDef in MaskCatalog.presets():
			if md.unlock == a.unlock:
				names.append(MaskCatalog.display_name(md.id))
		for kind: String in MaskCatalog.KINDS:
			for part: MaskPartDef in MaskCatalog.all_parts(kind):
				if part.unlock == a.unlock:
					names.append(_part_text(part))
		for hid: StringName in Heisters.ids():  # D-111: earned heisters (Marten)
			if Heisters.unlock_of(hid) == a.unlock:
				names.append(UiText.t(&"ui.achievements.reward_heister", {"name": Heisters.display_name(hid)}))
	for id: StringName in a.rewards:
		names.append(MaskCatalog.part_name(id))
	for id: StringName in [a.unlock] + a.unlocks:
		if String(id).begins_with(FINISH_PREFIX):
			names.append(UiText.t(&"ui.achievements.reward_finish", {"name": finish_name(id)}))
	return ", ".join(names)


## Display name of a weapon finish unlock id (`unlock.finish.<id>`): B7-04's `item.finish.<id>.name`, else
## the id in title case.
static func finish_name(unlock_id: StringName) -> String:
	var fid: String = String(unlock_id).trim_prefix(FINISH_PREFIX)
	var key: StringName = UiText.item_key(StringName("finish." + fid))
	var text: String = UiText.t(key)
	return fid.capitalize() if text == String(key) else text


static func _part_text(part: MaskPartDef) -> String:
	var n: String = UiText.t(UiText.item_key(part.id))
	return n if MaskCatalog.is_available(part.id) else UiText.t(&"ui.achievements.reward_pending", {"name": n})


## Categories that have achievements, Achievements.CATEGORIES order first, then any other in data order.
static func _categories(defs: Array[AchievementDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: StringName in Achievements.CATEGORIES:
		for a: AchievementDef in defs:
			if a.category == c:
				out.append(c)
				break
	for a: AchievementDef in defs:
		if not out.has(a.category):
			out.append(a.category)
	return out
