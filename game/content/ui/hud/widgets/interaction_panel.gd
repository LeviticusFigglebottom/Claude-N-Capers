## Interaction prompt (tr(text_key) with args), hold progress bar and blocked reason (S9.1, S1.1).
class_name InteractionPanel
extends HudWidget

var prompt_label: Label
var progress_bar: ProgressBar
var blocked_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	prompt_label = UiBuild.label(&"", UiBuild.HUD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt_label)
	progress_bar = UiBuild.bar(Color.WHITE, Vector2(320, 10))
	progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(progress_bar)
	blocked_label = UiBuild.label(&"", UiBuild.HUD)
	blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blocked_label.add_theme_color_override(&"font_color", tweak.low_health_color)
	v.add_child(blocked_label)


func watched_signals() -> Array[StringName]:
	return [&"interaction_changed"]


func refresh() -> void:
	var it: Dictionary = prop(&"interaction", {}) as Dictionary
	var key: StringName = StringName(it.get("text_key", &""))
	visible = key != &""
	if not visible:
		return
	prompt_label.text = UiText.t(key, it.get("args", {}) as Dictionary)
	var p: float = float(it.get("progress", 0.0))
	progress_bar.visible = p > 0.0
	progress_bar.value = p
	var blocked: StringName = StringName(it.get("blocked_reason", &""))
	blocked_label.visible = blocked != &""
	blocked_label.text = UiText.t(blocked, it.get("args", {}) as Dictionary) if blocked != &"" else ""
