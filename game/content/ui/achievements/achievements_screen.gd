## Achievements screen (B4-20 stub). Owner: ENV B. Opened from the hub's profile panel
## (HubMenu.achievements_requested -> MenuFlow._open_achievements); Back returns to the hub.
## One row per AchievementDef (Achievements.all() order): name, description, progress bar
## "progress / target", Unlocked / In progress, and the mask reward of its unlock (if any).
## Rows are focusable so keyboard/gamepad scroll the list (ScrollContainer.follow_focus).
## API: setup(profile) before or after entering the tree (null = load profile_slot); refresh().
class_name AchievementsScreen
extends UiScreen

@export var profile_slot: int = 0

var profile: PlayerProfile = null
var count_label: Label
var list: VBoxContainer
var back_button: Button
## Achievement id -> its row PanelContainer.
var rows: Dictionary = {}


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
	focus_chain.clear()
	var defs: Array[AchievementDef] = Achievements.all()
	var unlocked: int = 0
	for a: AchievementDef in defs:
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
	bar.value = clampf(float(Achievements.progress(profile, a.id)) / float(a.target()), 0.0, 1.0)
	bar_row.add_child(bar)
	bar_row.add_child(UiBuild.label(&"ui.achievements.progress", UiBuild.DIM,
			{"progress": UiText.group_digits(Achievements.progress(profile, a.id)), "target": UiText.group_digits(a.target())}))
	v.add_child(bar_row)
	var reward: String = reward_name(a)
	if reward != "":
		v.add_child(UiBuild.label(&"ui.achievements.reward", UiBuild.DIM, {"name": reward}))
	var panel: PanelContainer = UiBuild.panel(v)
	panel.focus_mode = Control.FOCUS_ALL
	panel.modulate = Color.WHITE if done else Color(1, 1, 1, 0.8)
	return panel


## Display name of the preset mask behind `a.unlock` ("" when it unlocks no mask).
static func reward_name(a: AchievementDef) -> String:
	if a.unlock == &"":
		return ""
	for md: MaskDef in MaskCatalog.presets():
		if md.unlock == a.unlock:
			return MaskCatalog.display_name(md.id)
	return ""
