## Achievement unlock toast (D-115 achievements in play). Owner: ENV B.
## A PD2-style small banner in the top-right corner: "ACHIEVEMENT UNLOCKED" caption, the achievement's name and
## its reward (AchievementsScreen.reward_name; the line hides when it grants nothing). Several unlocks queue and
## show one after the other, SHOW_S each.
## Where it lives: achievements are only evaluated at payday (Achievements.on_payday from PaydayScreen._apply;
## Achievements.sync also runs on Notoriety rank-up, which is a hub action, so there is no mid-heist unlock
## path). The in-heist PaydayScreen owns one (`PaydayScreen.toast`) and pushes the ids on_payday returned, so it
## draws over the payday summary and the card stage (z_index 1) while the HUD itself is hidden.
## Toast rules (as the HUD's toasts): never over the pause menu (MouseCapture &"pause" released) nor over a
## `blockers` control that is visible (the HUD's Tab sheet when one is set); a blocked toast is hidden and its
## timer holds, so nothing in the queue is lost. Only ticks while visible in the tree.
## API: push(ids), clear(), tick(delta); `current` (shown id, &"" = none), `queue` (waiting ids), `shown_ids`
## (every id shown so far, in order; tests).
class_name AchievementToast
extends Control

## Seconds each toast stays up (unblocked time).
const SHOW_S: float = 3.5
## Banner width and the gap to the screen's top-right corner.
const WIDTH: float = 420.0
const EDGE: float = 64.0  # the screen margin (UiBuild.screen_margin): inside the corner brackets

## Controls that hide the toast while visible (e.g. a HUD's Tab sheet).
var blockers: Array[Control] = []
var queue: Array[StringName] = []
var current: StringName = &""
var shown_ids: Array[StringName] = []
var panel: PanelContainer
var caption_label: Label
var name_label: Label
var reward_label: Label
var _t: float = 0.0


func _init() -> void:
	name = "AchievementToast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	caption_label = UiBuild.caption(&"ui.results.achievement_toast")
	caption_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(caption_label)
	name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_label)
	reward_label = UiBuild.label(&"", UiBuild.DIM)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reward_label)
	panel = UiBuild.panel(v)
	panel.add_theme_stylebox_override(&"panel", _style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -WIDTH - EDGE
	panel.offset_right = -EDGE
	panel.offset_top = EDGE
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.visible = false
	add_child(panel)


## Raised ink card with a brass edge on the left (the achievement colour on the payday).
static func _style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.INK_2, 0.97)
	sb.border_color = UiTokens.BRASS
	sb.border_width_left = 6
	sb.set_content_margin_all(UiTokens.S3)
	sb.content_margin_left = UiTokens.S4
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


## Queue newly unlocked achievement ids (unknown ids are skipped); starts the first at once.
func push(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) is AchievementDef and not queue.has(id) and id != current:
			queue.append(id)
	if current == &"":
		_next()


## Drops the shown toast and the queue (a new result replaced this one).
func clear() -> void:
	queue.clear()
	current = &""
	_t = 0.0
	panel.visible = false


## True while a pause menu or a visible blocker would sit under / over the toast.
func blocked() -> bool:
	if MouseCapture.is_released(&"pause"):
		return true
	for b: Control in blockers:
		if b != null and is_instance_valid(b) and b.is_visible_in_tree():
			return true
	return false


func tick(delta: float) -> void:
	if current == &"":
		return
	var hold: bool = blocked()
	panel.visible = not hold
	if hold:
		return
	_t -= delta
	if _t <= 0.0:
		_next()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		tick(delta)


func _next() -> void:
	current = &""
	if not queue.is_empty():
		current = queue.pop_front()
	if current == &"":
		panel.visible = false
		return
	var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, current) as AchievementDef
	name_label.text = UiText.t(a.name_key)
	var reward: String = AchievementsScreen.reward_name(a)
	reward_label.text = UiText.t(&"ui.results.achievement_toast_reward", {"name": reward})
	reward_label.visible = reward != ""
	_t = SHOW_S
	shown_ids.append(current)
	panel.visible = not blocked()
	UiSfx.play(UiSfx.OBJECTIVE_DONE)
	if UiTokens.motion_ok() and is_inside_tree() and DisplayServer.get_name() != "headless":
		panel.modulate.a = 0.0
		create_tween().tween_property(panel, ^"modulate:a", 1.0, UiTokens.T_BASE)
