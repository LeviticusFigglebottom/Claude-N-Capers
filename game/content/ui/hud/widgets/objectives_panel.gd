## Objectives list (active first, completed dimmed, hidden ones omitted).
class_name ObjectivesPanel
extends HudWidget

var list_box: VBoxContainer


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	add_child(UiBuild.panel(v, UiBuild.HUD_PANEL))
	v.add_child(UiBuild.label(&"ui.hud.objectives", UiBuild.HUD))
	list_box = UiBuild.vbox(2)
	v.add_child(list_box)


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
