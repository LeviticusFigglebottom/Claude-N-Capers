## Pager timers (S5.2-S5.4), pagers left, ECM jammer and camera alarm countdowns (S3.5).
class_name PagerPanel
extends HudWidget

var rows_box: VBoxContainer
var pagers_left_label: Label
var timers_label: Label
## Label per active pager, in model order (tests).
var pager_labels: Array[Label] = []


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	add_child(v)
	rows_box = UiBuild.vbox(4)
	v.add_child(rows_box)
	pagers_left_label = UiBuild.label(&"", UiBuild.HUD)
	pagers_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pagers_left_label)
	timers_label = UiBuild.label(&"", UiBuild.HUD)
	timers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(timers_label)


func watched_signals() -> Array[StringName]:
	return [&"pagers_changed", &"timers_changed"]


func refresh() -> void:
	var pagers: Array = prop(&"pagers", []) as Array
	while pager_labels.size() < pagers.size():
		var row: VBoxContainer = UiBuild.vbox(2)
		var l: Label = UiBuild.label(&"", UiBuild.HUD_BIG)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override(&"font_color", tweak.pager_color)
		row.add_child(l)
		var b: ProgressBar = UiBuild.bar(tweak.pager_color, Vector2(260, 8))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		rows_box.add_child(row)
		pager_labels.append(l)
	for i: int in range(pager_labels.size()):
		var row: Control = pager_labels[i].get_parent() as Control
		row.visible = i < pagers.size()
		if not row.visible:
			continue
		var p: Dictionary = pagers[i] as Dictionary
		pager_labels[i].text = UiText.t(&"ui.hud.pager", {"seconds": UiText.clock(float(p.get("time_left_s", 0.0)))})
		var bar: ProgressBar = row.get_child(1) as ProgressBar
		bar.visible = bool(p.get("answering", false))
		bar.value = float(p.get("progress", 0.0))
	var answered: int = int(prop(&"pagers_answered", 0))
	var max_answers: int = int(prop(&"pagers_max", 0))
	pagers_left_label.visible = answered > 0 or not pagers.is_empty()
	pagers_left_label.text = UiText.t(&"ui.hud.pagers_left", {"count": maxi(max_answers - answered, 0)})
	var timers: Array[String] = []
	var ecm: float = float(prop(&"ecm_time_left_s", -1.0))
	if ecm >= 0.0:
		timers.append(UiText.t(&"ui.hud.ecm", {"seconds": UiText.clock(ecm)}))
	var cam: float = float(prop(&"camera_alarm_s", -1.0))
	if cam >= 0.0:
		timers.append(UiText.t(&"ui.hud.camera_alarm", {"seconds": UiText.clock(cam)}))
	timers_label.text = "\n".join(timers)
	timers_label.visible = not timers.is_empty()
