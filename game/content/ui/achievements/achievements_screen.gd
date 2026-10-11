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

@export var profile_slot: int = 0

var profile: PlayerProfile = null
var count_label: Label
var list: VBoxContainer
var back_button: Button
## Achievement id -> its row PanelContainer.
var rows: Dictionary = {}
## Category id -> its header Label.
var category_labels: Dictionary = {}


func setup(p: PlayerProfile) -> void:
	profile = p
	if is_node_ready():
		refresh()


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(18)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.achievements.title", UiBuild.HEADER))
	root.add_child(UiBuild.label(&"ui.achievements.subtitle", UiBuild.DIM))
	count_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	root.add_child(count_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)
	list = UiBuild.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	root.add_child(back_button)
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
	var defs: Array[AchievementDef] = Achievements.all()
	var unlocked: int = 0
	for cat: StringName in _categories(defs):
		var header: Label = UiBuild.label(StringName("ui.achievements.category.%s" % cat), UiBuild.SUBHEADER)
		list.add_child(header)
		category_labels[cat] = header
		for a: AchievementDef in defs:
			if a.category != cat:
				continue
			if Achievements.is_unlocked(profile, a.id):
				unlocked += 1
			var row: PanelContainer = _row(a)
			list.add_child(row)
			rows[a.id] = row
			focus_chain.append(row)
	focus_chain.append(back_button)
	UiNav.chain_vertical(focus_chain)
	count_label.text = UiText.t(&"ui.achievements.count", {"unlocked": unlocked, "total": defs.size()})


func _row(a: AchievementDef) -> PanelContainer:
	var done: bool = Achievements.is_unlocked(profile, a.id)
	var v: VBoxContainer = UiBuild.vbox(4)
	var head: HBoxContainer = UiBuild.hbox(16)
	var title: Label = UiBuild.label(a.name_key, UiBuild.SUBHEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var status: Label = UiBuild.label(&"ui.achievements.unlocked" if done else &"ui.achievements.locked",
			&"" if done else UiBuild.DIM)
	status.name = "Status"
	head.add_child(status)
	v.add_child(head)
	var desc: Label = UiBuild.label(a.desc_key, UiBuild.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var bar_row: HBoxContainer = UiBuild.hbox(12)
	var bar: ProgressBar = UiBuild.bar(UiAccent.table().fallback if done else Color(1, 1, 1, 1), Vector2(320, 10))
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
		v.add_child(UiBuild.label(&"ui.achievements.reward", UiBuild.DIM, {"name": reward}))
	var panel: PanelContainer = UiBuild.panel(v)
	panel.focus_mode = Control.FOCUS_ALL
	panel.modulate = Color.WHITE if done else Color(1, 1, 1, 0.8)
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
