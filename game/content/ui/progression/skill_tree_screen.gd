## Skill tree screen (B4-03, pd2_fidelity P1/P2). Owner: ENV B. Opened from the loadout screen.
## 5 tree tabs; each shows 3 subtree columns x 4 tier rows (tier 4 on top, 1/2/2/1 skills). A skill
## button shows name, state (locked / available / basic / aced) and the next step's cost. Hover/focus
## shows details; click / A / Enter invests the next level; right-click / gamepad X / Delete refunds one
## level (SkillBuild: refunds that would break a higher tier's gate are blocked). Points available =
## SkillPoints.points_for_level(level) - spent. Respec is free (two presses). Several skill sets
## (PlayerProfile.skill_sets, count from ProgressionUiTweak). Every change is saved via SaveService.
## Tree tabs: LB/RB or PageUp/PageDown.
class_name SkillTreeScreen
extends UiScreen

## After any change to the profile's skills (buy, refund, respec, set switch).
signal skills_changed()

const TIERS: int = 4
## Logical focus grid: 2 columns per subtree (tier 1 and 4 span both).
const GRID_COLS_PER_SUBTREE: int = 2

@export var profile_slot: int = 0

var profile: PlayerProfile
var tweak: ProgressionUiTweak
var current_tree: StringName = &""
var selected_skill: StringName = &""
## tree id -> Button
var tree_tabs: Dictionary = {}
## skill id -> Button (current tree only)
var skill_buttons: Dictionary = {}
var set_buttons: Array[Button] = []
var level_label: Label
var points_label: Label
## subtree id -> Label ("Spent: n")
var subtree_spent_labels: Dictionary = {}
var detail_name: Label
var detail_meta: Label
var detail_state: Label
var detail_team: Label
var detail_basic_header: Label
var detail_basic: Label
var detail_basic_note: Label
var detail_aced_header: Label
var detail_aced: Label
var detail_aced_note: Label
var detail_unlock: Label
var detail_reason: Label
var buy_button: Button
var refund_button: Button
var respec_button: Button
var back_button: Button
var _grid: GridContainer
var _tab_box: HBoxContainer
## [row][col] -> Button, row 0 = tier 4.
var _nav: Array = []
var _respec_armed: bool = false
var _styles: Dictionary = {}


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
	_build_styles()
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root, UiTokens.S6)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S6)
	var titles: VBoxContainer = UiBuild.header(&"ui.skills.crumb", &"ui.skills.title")
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	level_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	points_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	for pair: Array in [[&"ui.skills.level_caption", level_label], [&"ui.skills.points_caption", points_label]]:
		var f: VBoxContainer = UiBuild.field(StringName(pair[0]), pair[1] as Control)
		f.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(f)
	root.add_child(top)
	var tabs_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	_tab_box = UiBuild.hbox(UiTokens.S2)
	tabs_row.add_child(_tab_box)
	for tree: StringName in SkillPoints.tree_def().trees:
		var b: Button = UiBuild.tab(_small_button(StringName("ui.skills.tree.%s" % tree)))
		b.custom_minimum_size = Vector2(170, 0)
		b.pressed.connect(show_tree.bind(tree))
		_tab_box.add_child(b)
		tree_tabs[tree] = b
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(spacer2)
	tabs_row.add_child(UiBuild.caption(&"ui.skills.sets"))
	for i: int in range(maxi(tweak.skill_set_count, 1)):
		var sb: Button = UiBuild.tab(_small_button(&"ui.skills.set", {"n": i + 1}))
		sb.custom_minimum_size = Vector2(100, 0)
		sb.pressed.connect(select_skill_set.bind(i))
		tabs_row.add_child(sb)
		set_buttons.append(sb)
	root.add_child(tabs_row)
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	_grid.add_theme_constant_override(&"v_separation", UiTokens.S2)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)
	body.add_child(_build_details())
	# PO-4 footer: Back and Reset (ghost) left, the refund / tree keys, then Refund and the invest
	# button (the screen's primary) bottom right.
	back_button = UiBuild.back(UiBuild.button(&"ui.menu.back"))
	respec_button = UiBuild.ghost(UiBuild.button(&"ui.skills.respec"))
	back_button.pressed.connect(back_requested.emit)
	respec_button.pressed.connect(_on_respec_pressed)
	respec_button.focus_exited.connect(_disarm_respec)
	for b: Button in [back_button, respec_button]:
		b.custom_minimum_size = Vector2(200, 0)
	var hint: Label = UiBuild.label(&"ui.skills.hint", UiBuild.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	for c: Control in [back_button, respec_button, hint, refund_button, UiBuild.primary(buy_button)]:
		foot.add_child(c)
	root.add_child(foot)
	profile.switch_skill_set(profile.active_skill_set)  # pads skill_sets to the active index
	show_tree(SkillPoints.tree_def().trees[0])


func _build_details() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.custom_minimum_size = Vector2(540, 0)
	detail_name = UiBuild.label(&"", UiBuild.SUBHEADER)
	detail_meta = UiBuild.caption()
	detail_state = UiBuild.label()
	detail_team = UiBuild.label(&"ui.skills.team", UiBuild.DIM)
	detail_basic_header = UiBuild.caption()
	detail_basic = _wrap_label()
	detail_basic_note = _note_label()
	detail_aced_header = UiBuild.caption()
	detail_aced = _wrap_label()
	detail_aced_note = _note_label()
	detail_unlock = _wrap_label()
	detail_reason = _wrap_label()
	detail_reason.add_theme_color_override(&"font_color", tweak.reason_color)
	for c: Control in [detail_name, detail_meta, detail_state, detail_team, detail_basic_header, detail_basic,
			detail_basic_note, detail_aced_header, detail_aced, detail_aced_note, detail_unlock]:
		v.add_child(c)
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	v.add_child(detail_reason)
	# Buy / Refund act on the selected skill; build_ui puts them in the footer (bottom right).
	buy_button = UiBuild.button(&"ui.skills.buy_basic", {"cost": 0})
	refund_button = UiBuild.button(&"ui.skills.refund")
	buy_button.pressed.connect(func() -> void: UiSfx.check(bool(buy(selected_skill)["ok"])))
	refund_button.pressed.connect(func() -> void: refund(selected_skill))
	return UiBuild.panel(v)


## Show one tree's 3 subtrees (rebuilds the grid buttons).
func show_tree(tree: StringName) -> void:
	var had_focus: bool = _grid_has_focus()
	current_tree = tree
	for t: Variant in tree_tabs:
		(tree_tabs[t] as Button).set_pressed_no_signal(t == tree)
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	skill_buttons.clear()
	subtree_spent_labels.clear()
	var t: SkillTreeDef = SkillPoints.tree_def()
	var subs: Array[StringName] = t.subtree_ids(tree)
	_grid.columns = 1 + subs.size()
	_grid.add_child(Control.new())
	for sub: StringName in subs:
		var head: VBoxContainer = UiBuild.vbox(UiTokens.S1)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(UiBuild.label(StringName("ui.skills.subtree.%s" % sub), UiBuild.SUBHEADER))
		var spent: Label = UiBuild.caption()
		head.add_child(spent)
		subtree_spent_labels[sub] = spent
		_grid.add_child(head)
	_nav.clear()
	for row: int in range(TIERS):
		var tier: int = TIERS - row
		_grid.add_child(_tier_gutter(tier))
		var nav_row: Array = []
		for sub: StringName in subs:
			var cell: HBoxContainer = UiBuild.hbox(10)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var tier_ids: Array = (t.layout.get(sub, []) as Array)[tier - 1] as Array
			var made: Array[Button] = []
			for sid: Variant in tier_ids:
				var b: Button = _skill_button(StringName(sid))
				cell.add_child(b)
				made.append(b)
			for k: int in range(GRID_COLS_PER_SUBTREE):
				nav_row.append(made[mini(k, made.size() - 1)] if not made.is_empty() else null)
			_grid.add_child(cell)
		_nav.append(nav_row)
	if selected_skill == &"" or not skill_buttons.has(selected_skill):
		selected_skill = _first_skill()
	_rebuild_focus_chain()
	refresh()
	if had_focus and skill_buttons.has(selected_skill):
		_focus_selected.call_deferred()


func _tier_gutter(tier: int) -> VBoxContainer:
	var g: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	g.custom_minimum_size = Vector2(120, 0)
	g.add_child(UiBuild.caption(&"ui.skills.tier", {"tier": tier}))
	var need: int = SkillPoints.tree_def().threshold_for_tier(tier)
	if need <= 0:
		g.add_child(UiBuild.label(&"ui.skills.tier_open", UiBuild.DIM))
	else:
		g.add_child(UiBuild.label(&"ui.skills.tier_gate", UiBuild.DIM, {"need": need}))
	return g


func _skill_button(sid: StringName) -> Button:
	var b: Button = Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.focus_mode = Control.FOCUS_ALL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_font_size_override(&"font_size", UiTokens.FONT_SMALL)
	b.pressed.connect(buy.bind(sid))
	b.focus_entered.connect(select_skill.bind(sid))
	b.mouse_entered.connect(select_skill.bind(sid))
	b.gui_input.connect(_on_skill_gui_input.bind(sid))
	skill_buttons[sid] = b
	return b


## Recompute every label and button from the profile.
func refresh() -> void:
	var skills: Dictionary = profile.loadout.skills
	var total: int = SkillBuild.total_points(profile.level)
	level_label.text = str(profile.level)
	points_label.text = UiText.t(&"ui.skills.points_left",
			{"points": total - SkillPoints.spent_total(skills), "total": total})
	for i: int in range(set_buttons.size()):
		set_buttons[i].set_pressed_no_signal(i == profile.active_skill_set)
	for sub: Variant in subtree_spent_labels:
		(subtree_spent_labels[sub] as Label).text = UiText.t(&"ui.skills.spent",
				{"points": SkillPoints.spent_in_subtree(skills, StringName(sub))})
	for sid: Variant in skill_buttons:
		_refresh_button(StringName(sid), skill_buttons[sid] as Button)
	_refresh_details()


func _refresh_button(sid: StringName, b: Button) -> void:
	var s: SkillDef = ContentDB.by_id(ContentDB.SKILLS, sid) as SkillDef
	var state: StringName = SkillBuild.state_of(profile.loadout.skills, sid, profile.level)
	var state_text: String = UiText.t(StringName("ui.skills.state.%s" % state))
	var line: String = state_text
	if state != SkillBuild.STATE_ACED and s != null:
		var cost: int = s.cost_basic if state != SkillBuild.STATE_BASIC else s.cost_aced
		line = UiText.t(&"ui.skills.button_cost", {"state": state_text, "cost": cost})
	b.text = "%s\n%s" % [UiText.t(StringName("%s.name" % sid)), line]
	# LEAD r280: skills whose effect has no runtime hook yet say so on the tree (content/docs/unhooked_skill_keys.md).
	var act: StringName = SkillBuild.activity(s) if s != null else &"active"
	if act != &"active":
		b.text += "\n%s" % UiText.t(StringName("ui.skills.button_%s" % act))
	var style: StyleBox = _styles.get(state, null) as StyleBox
	for slot: StringName in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(slot, style)
	b.add_theme_color_override(&"font_color", UiTokens.PAPER_MUTE if state == SkillBuild.STATE_LOCKED else UiTokens.PAPER)


func select_skill(sid: StringName) -> void:
	if selected_skill == sid:
		return
	selected_skill = sid
	_disarm_respec()
	_refresh_details()


func _refresh_details() -> void:
	var s: SkillDef = ContentDB.by_id(ContentDB.SKILLS, selected_skill) as SkillDef if selected_skill != &"" else null
	if s == null:
		return
	var skills: Dictionary = profile.loadout.skills
	var state: StringName = SkillBuild.state_of(skills, s.id, profile.level)
	detail_name.text = UiText.t(StringName("%s.name" % s.id))
	detail_meta.text = UiText.t(&"ui.skills.meta", {
		"tree": UiText.t(StringName("ui.skills.tree.%s" % s.tree)),
		"subtree": UiText.t(StringName("ui.skills.subtree.%s" % s.subtree)), "tier": s.tier})
	detail_state.text = UiText.t(StringName("ui.skills.state.%s" % state))
	detail_state.add_theme_color_override(&"font_color", _state_color(state))
	detail_team.visible = SkillBuild.is_team_skill(s)
	detail_basic_header.text = UiText.t(&"ui.skills.part_header", {"part": UiText.t(&"ui.skills.basic"), "cost": s.cost_basic})
	detail_aced_header.text = UiText.t(&"ui.skills.part_header", {"part": UiText.t(&"ui.skills.aced"), "cost": s.cost_aced})
	detail_basic.text = UiText.t(StringName("%s.basic" % s.id))
	detail_aced.text = UiText.t(StringName("%s.aced" % s.id))
	_set_note(detail_basic_note, s.id, "basic", s.grants_basic)
	_set_note(detail_aced_note, s.id, "aced", s.grants_aced)
	var unlock: StringName = SkillBuild.unlock_of(s.id, "aced")
	detail_unlock.visible = unlock != &""
	if unlock != &"":
		detail_unlock.text = UiText.t(&"ui.skills.unlocks", {"item": UiText.t(UiText.item_key(unlock))})
	var r: Dictionary = SkillPoints.can_unlock(skills, s.id, SkillBuild.total_points(profile.level))
	var rf: Dictionary = SkillBuild.can_refund(skills, s.id)
	var reasons: Array[String] = []
	if not bool(r["ok"]) and StringName(r["reason"]) != SkillPoints.REASON_ACED:
		reasons.append(_reason_text(StringName(r["reason"]), r))
	if int(skills.get(s.id, 0)) > 0 and not bool(rf["ok"]):
		reasons.append(_reason_text(StringName(rf["reason"]), rf))
	detail_reason.text = "\n".join(reasons)
	if state == SkillBuild.STATE_ACED:
		buy_button.text = UiText.t(&"ui.skills.state.aced")
	elif state == SkillBuild.STATE_BASIC:
		buy_button.text = UiText.t(&"ui.skills.buy_aced", {"cost": s.cost_aced})
	else:
		buy_button.text = UiText.t(&"ui.skills.buy_basic", {"cost": s.cost_basic})
	buy_button.disabled = not bool(r["ok"])
	refund_button.disabled = not bool(rf["ok"])
	refund_button.text = UiText.t(&"ui.skills.refund_points" if bool(rf["ok"]) else &"ui.skills.refund",
			{"points": int(rf["refund"])})


func _set_note(l: Label, sid: StringName, part: String, grants: Dictionary) -> void:
	var blocked: Array = SkillBuild.blocked_keys(sid, part)
	l.visible = not blocked.is_empty()
	l.text = UiText.t(&"ui.skills.blocked" if grants.is_empty() else &"ui.skills.blocked_partial")


static func _reason_text(reason: StringName, r: Dictionary) -> String:
	return UiText.t(StringName("ui.skills.reason.%s" % reason), r)


## Invest the next level of a skill (basic, then aced). Saves on success. Returns can_unlock()'s dict.
func buy(sid: StringName) -> Dictionary:
	select_skill(sid)
	var r: Dictionary = SkillBuild.buy(profile.loadout.skills, sid, profile.level)
	if bool(r["ok"]):
		_commit()
	return r


## Refund one level of a skill (blocked when a higher tier depends on it). Returns can_refund()'s dict.
func refund(sid: StringName) -> Dictionary:
	select_skill(sid)
	var r: Dictionary = SkillBuild.refund(profile.loadout.skills, sid)
	if bool(r["ok"]):
		NotorietySkills.release(profile, profile.active_skill_set)  # the player owns the build again
		_commit()
	return r


## Free respec of the active set (drops a Notoriety-held build of that set). Returns the points given back.
func respec() -> int:
	_disarm_respec()
	NotorietySkills.release(profile, profile.active_skill_set)
	var back: int = SkillBuild.respec(profile.loadout.skills)
	_commit()
	return back


func select_skill_set(index: int) -> void:
	if index != profile.active_skill_set:
		profile.switch_skill_set(index)
		_commit()
	else:
		refresh()


func available_points() -> int:
	return SkillBuild.available_points(profile.loadout.skills, profile.level)


func _commit() -> void:
	SaveService.save_profile(profile, profile_slot)
	refresh()
	skills_changed.emit()


func _on_respec_pressed() -> void:
	if _respec_armed:
		respec()
		return
	_respec_armed = true
	respec_button.text = UiText.t(&"ui.skills.respec_confirm")


func _disarm_respec() -> void:
	_respec_armed = false
	if respec_button != null:
		respec_button.text = UiText.t(&"ui.skills.respec")


func _on_skill_gui_input(event: InputEvent, sid: StringName) -> void:
	var wants_refund: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		wants_refund = mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event as InputEventJoypadButton
		wants_refund = jb.pressed and jb.button_index == JOY_BUTTON_X
	elif event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		wants_refund = k.pressed and not k.echo and (k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE)
	if wants_refund:
		accept_event()
		refund(sid)


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_visible_in_tree():
		return
	var step: int = 0
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var idx: JoyButton = (event as InputEventJoypadButton).button_index
		step = -1 if idx == JOY_BUTTON_LEFT_SHOULDER else (1 if idx == JOY_BUTTON_RIGHT_SHOULDER else 0)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: Key = (event as InputEventKey).keycode
		step = -1 if kc == KEY_PAGEUP else (1 if kc == KEY_PAGEDOWN else 0)
	if step != 0:
		get_viewport().set_input_as_handled()
		var trees: Array[StringName] = SkillPoints.tree_def().trees
		var i: int = trees.find(current_tree)
		show_tree(trees[posmod(i + step, trees.size())])
		if skill_buttons.has(selected_skill):
			_focus_selected.call_deferred()


func focus_default() -> void:
	if is_visible_in_tree() and skill_buttons.has(selected_skill):
		_focus_selected.call_deferred()
	else:
		super()


## Deferred focus on the selected skill's button (the grid may have been rebuilt in between).
func _focus_selected() -> void:
	var b: Button = skill_buttons.get(selected_skill, null) as Button
	if b != null and is_instance_valid(b) and b.is_inside_tree() and is_visible_in_tree():
		b.grab_focus()


func _rebuild_focus_chain() -> void:
	focus_chain.clear()
	for row: Array in _nav:
		for b: Variant in row:
			if b != null and not focus_chain.has(b as Control):
				focus_chain.append(b as Control)
	focus_chain.append(buy_button)
	focus_chain.append(refund_button)
	focus_chain.append(back_button)
	focus_chain.append(respec_button)
	for t: StringName in SkillPoints.tree_def().trees:
		focus_chain.append(tree_tabs[t] as Control)
	for sb: Button in set_buttons:
		focus_chain.append(sb)
	if is_inside_tree():
		UiNav.chain_vertical(focus_chain)
		_wire_focus()


## Explicit 2D neighbours: grid by logical columns; top row -> tree tabs; bottom row -> Back/Reset;
## right edge -> details (Buy/Refund); tabs and set buttons chain left/right.
func _wire_focus() -> void:
	if _nav.is_empty():
		return
	var tabs: Array[Control] = []
	for t: StringName in SkillPoints.tree_def().trees:
		tabs.append(tree_tabs[t] as Control)
	for sb: Button in set_buttons:
		tabs.append(sb)
	UiNav.chain_horizontal(tabs, false)
	var rows: int = _nav.size()
	var cols: int = (_nav[0] as Array).size()
	var wired: Dictionary = {}
	for r: int in range(rows):
		for c: int in range(cols):
			var b: Control = _nav[r][c] as Control
			if b == null or wired.has(b):
				continue  # a 1-skill tier spans 2 logical columns; wire it from its left cell
			wired[b] = true
			var left: Control = _step(r, c, 0, -1)
			var right: Control = _step(r, c, 0, 1)
			var up: Control = _step(r, c, -1, 0)
			var down: Control = _step(r, c, 1, 0)
			if up == null:
				up = tree_tabs.get(current_tree, null) as Control
			if down == null:
				down = back_button
			if right == null:
				right = buy_button
			_link(b, SIDE_LEFT, left if left != null else b)
			_link(b, SIDE_RIGHT, right)
			_link(b, SIDE_TOP, up)
			_link(b, SIDE_BOTTOM, down)
	var first: Control = _nav[0][0] as Control
	for tab: Control in tabs:
		_link(tab, SIDE_BOTTOM, first)
		_link(tab, SIDE_TOP, tab)
	var sel: Control = skill_buttons.get(selected_skill, first) as Control
	_link(refund_button, SIDE_LEFT, respec_button)
	_link(buy_button, SIDE_LEFT, refund_button)
	_link(buy_button, SIDE_RIGHT, buy_button)
	_link(refund_button, SIDE_RIGHT, buy_button)
	for d: Control in [buy_button, refund_button]:
		_link(d, SIDE_TOP, sel)
		_link(d, SIDE_BOTTOM, d)
	var bottom_left: Control = _nav[rows - 1][0] as Control
	for d: Control in [back_button, respec_button]:
		_link(d, SIDE_TOP, bottom_left)
		_link(d, SIDE_BOTTOM, d)
	_link(back_button, SIDE_RIGHT, respec_button)
	_link(back_button, SIDE_LEFT, back_button)
	_link(respec_button, SIDE_LEFT, back_button)
	_link(respec_button, SIDE_RIGHT, refund_button)


## The next different button from (r, c) in direction (dr, dc), or null at the edge.
func _step(r: int, c: int, dr: int, dc: int) -> Control:
	var here: Variant = _nav[r][c]
	var rr: int = r + dr
	var cc: int = c + dc
	while rr >= 0 and rr < _nav.size() and cc >= 0 and cc < (_nav[rr] as Array).size():
		var b: Variant = _nav[rr][cc]
		if b != null and b != here:
			return b as Control
		rr += dr
		cc += dc
	return null


static func _link(c: Control, side: Side, to: Control) -> void:
	if c != null and to != null:
		c.set_focus_neighbor(side, c.get_path_to(to))


func _grid_has_focus() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f != null and _grid.is_ancestor_of(f)


func _first_skill() -> StringName:
	var subs: Array[StringName] = SkillPoints.tree_def().subtree_ids(current_tree)
	if subs.is_empty():
		return &""
	var layout: Array = SkillPoints.tree_def().layout.get(subs[0], []) as Array
	return StringName((layout[0] as Array)[0]) if not layout.is_empty() else &""


func _state_color(state: StringName) -> Color:
	match state:
		SkillBuild.STATE_ACED:
			return tweak.skill_aced_color
		SkillBuild.STATE_BASIC:
			return tweak.skill_basic_color
		SkillBuild.STATE_AVAILABLE:
			return UiTokens.PAPER
	return tweak.note_color


func _build_styles() -> void:
	var base: StyleBoxFlat = UiBuild.theme().get_stylebox(&"normal", &"Button") as StyleBoxFlat
	var colors: Dictionary = {
		SkillBuild.STATE_LOCKED: tweak.skill_locked_color, SkillBuild.STATE_AVAILABLE: tweak.skill_available_color,
		SkillBuild.STATE_BASIC: tweak.skill_basic_color, SkillBuild.STATE_ACED: tweak.skill_aced_color,
	}
	for state: Variant in colors:
		var sb: StyleBoxFlat = base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
		var c: Color = colors[state] as Color
		sb.border_color = c
		sb.set_border_width_all(3 if state == SkillBuild.STATE_ACED or state == SkillBuild.STATE_BASIC else 2)
		sb.content_margin_left = UiTokens.S2
		sb.content_margin_right = UiTokens.S2
		if state == SkillBuild.STATE_LOCKED:
			sb.bg_color = sb.bg_color.darkened(0.35)
		elif state == SkillBuild.STATE_BASIC or state == SkillBuild.STATE_ACED:
			sb.bg_color = sb.bg_color.lerp(Color(c, 1.0), tweak.owned_tint)  # owned: tinted fill
		_styles[state] = sb


func _small_button(key: StringName, args: Dictionary = {}) -> Button:
	var b: Button = UiBuild.button(key, args)
	b.custom_minimum_size = Vector2(0, 0)
	return b


static func _wrap_label() -> Label:
	var l: Label = UiBuild.label()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	return l


func _note_label() -> Label:
	var l: Label = _wrap_label()
	l.add_theme_color_override(&"font_color", tweak.note_color)
	l.add_theme_font_size_override(&"font_size", UiTokens.FONT_SMALL)
	return l
