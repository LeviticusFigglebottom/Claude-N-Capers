## Current objective (PO-4, docs/design/ui/style.md §8): a caption "OBJECTIVE" over ONE line, the
## first ACTIVE objective (PD2 shows the current step, not the whole plan; the full list is on the
## scoreboard). Hidden when nothing is active. B4-07: the heist's accent (UiAccent; set_accent) edges
## the panel and tints the caption.
class_name ObjectivesPanel
extends HudWidget

var list_box: VBoxContainer
var header_label: Label
var panel: PanelContainer
## Heist accent (alpha 0 = none).
var accent: Color = Color(0, 0, 0, 0)
## Bags secured this run (EventBus.loot_secured), the {count} of "Secure the bags ({count}/{total})".
var secured_count: int = 0


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	panel = UiBuild.panel(v, UiBuild.HUD_PANEL)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(panel)
	header_label = UiBuild.caption(&"ui.hud.objectives")
	header_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(header_label)
	list_box = UiBuild.vbox(UiTokens.S1)
	v.add_child(list_box)
	_apply_accent()


## Accent the panel edge and header with `color` (readable against the HUD panel).
func set_accent(color: Color) -> void:
	accent = color
	_apply_accent()


## Display text of objective `o` with its placeholders filled (lead bug: the HUD showed a raw
## "Secure the bags ({count}/{total})"). Missions pass {"bags": N} (no count / total), so total falls back
## to bags / required and count to secured / `secured`. A placeholder still unfilled is dropped together
## with its "( ... )" group, so raw braces never reach the screen.
static func objective_text(o: Dictionary, secured: int = 0) -> String:
	var args: Dictionary = (o.get("args", {}) as Dictionary).duplicate()
	if not args.has("total"):
		for k: String in ["bags", "required", "min_bags"]:
			if args.has(k):
				args["total"] = args[k]
				break
	if not args.has("count"):
		args["count"] = args.get("secured", args.get("bags_secured", secured))
	var text: String = UiText.t(StringName(o.get("text_key", &"")), args)
	if text.contains("{"):
		var group: RegEx = RegEx.create_from_string("\\s*\\([^()]*\\{[A-Za-z_]+\\}[^()]*\\)")
		text = group.sub(text, "", true)
		text = RegEx.create_from_string("\\{[A-Za-z_]+\\}").sub(text, "", true).strip_edges()
	return text


func _on_loot_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	secured_count += 1
	if is_inside_tree():
		refresh()


func _enter_tree() -> void:
	if not EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.connect(_on_loot_secured)


func _exit_tree() -> void:
	if EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.disconnect(_on_loot_secured)


func _apply_accent() -> void:
	if panel == null or accent.a <= 0.0:
		return
	UiAccent.accent_panel(panel, accent, 4)
	var sb: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	var back: Color = UiAccent.over(sb.bg_color, UiAccent.app_bg()) if sb != null else UiAccent.app_bg()
	header_label.add_theme_color_override(&"font_color", UiAccent.readable(accent, back, UiAccent.table().min_text_contrast))


func watched_signals() -> Array[StringName]:
	return [&"objectives_changed"]


func refresh() -> void:
	for c: Node in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	for o: Dictionary in prop(&"objectives", []) as Array:
		if int(o.get("state", Enums.ObjectiveState.ACTIVE)) != Enums.ObjectiveState.ACTIVE:
			continue
		var l: Label = UiBuild.label(&"", UiBuild.HUD)
		l.text = UiText.t(&"ui.hud.objective_active", {"text": objective_text(o, secured_count)})
		l.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
		l.add_theme_constant_override(&"outline_size", 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(380, 0)
		list_box.add_child(l)
		break
	visible = list_box.get_child_count() > 0


static func _state_key(st: int) -> StringName:
	match st:
		Enums.ObjectiveState.COMPLETED:
			return &"ui.hud.objective_done"
		Enums.ObjectiveState.FAILED:
			return &"ui.hud.objective_failed"
	return &"ui.hud.objective_active"
