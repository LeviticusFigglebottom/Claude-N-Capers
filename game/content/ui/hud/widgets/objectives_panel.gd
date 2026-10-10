## Objectives list (active first, completed dimmed, hidden ones omitted). B4-07: the panel carries
## the heist's accent (UiAccent; set_accent) on its edge and header.
class_name ObjectivesPanel
extends HudWidget

var list_box: VBoxContainer
var header_label: Label
var panel: PanelContainer
## Heist accent (alpha 0 = none).
var accent: Color = Color(0, 0, 0, 0)


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	panel = UiBuild.panel(v, UiBuild.HUD_PANEL)
	add_child(panel)
	header_label = UiBuild.label(&"ui.hud.objectives", UiBuild.HUD)
	v.add_child(header_label)
	list_box = UiBuild.vbox(2)
	v.add_child(list_box)
	_apply_accent()


## Accent the panel edge and header with `color` (readable against the HUD panel).
func set_accent(color: Color) -> void:
	accent = color
	_apply_accent()


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
	var shown: int = 0
	for o: Dictionary in prop(&"objectives", []) as Array:
		var st: int = int(o.get("state", Enums.ObjectiveState.ACTIVE))
		if st == Enums.ObjectiveState.HIDDEN:
			continue
		var l: Label = UiBuild.label(&"", UiBuild.HUD)
		l.text = UiText.t(_state_key(st), {"text": UiText.t(StringName(o.get("text_key", &"")), o.get("args", {}) as Dictionary)})
		if st != Enums.ObjectiveState.ACTIVE:
			l.modulate = Color(1, 1, 1, 0.55)
		list_box.add_child(l)
		shown += 1
	visible = shown > 0


static func _state_key(st: int) -> StringName:
	match st:
		Enums.ObjectiveState.COMPLETED:
			return &"ui.hud.objective_done"
		Enums.ObjectiveState.FAILED:
			return &"ui.hud.objective_failed"
	return &"ui.hud.objective_active"
