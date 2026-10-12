## Guard-domination prompt (PP-A-1, S5.8 / D-079): shown while the model's `dominate_target` is a
## non-zero guard net id, hidden at 0. Text names the first keyboard binding of SHOUT_ACTION and the
## seconds left in the guard's window (`dominate_window_s`).
class_name DominatePrompt
extends HudWidget

const SHOUT_ACTION: StringName = &"shout"

var prompt_label: Label


func build() -> void:
	prompt_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD_BIG))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_theme_color_override(&"font_color", tweak.interaction_color)
	add_child(prompt_label)


func watched_signals() -> Array[StringName]:
	return [&"dominate_prompt_changed"]


func refresh() -> void:
	var target: int = int(prop(&"dominate_target", 0))
	visible = target != 0
	if not visible:
		return
	prompt_label.text = UiText.t(&"ui.hud.dominate_prompt", {
		"key": InteractionPanel.action_key_text(SHOUT_ACTION),
		"seconds": snappedf(maxf(float(prop(&"dominate_window_s", 0.0)), 0.0), 0.1)})
