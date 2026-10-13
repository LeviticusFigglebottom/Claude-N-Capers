## Guard-domination prompt (PP-A-1, S5.8 / D-079): shown while the model's `dominate_target` is a
## non-zero guard net id, hidden at 0. Text names the first keyboard binding of SHOUT_ACTION and the
## seconds left in the guard's window (`dominate_window_s`).
class_name DominatePrompt
extends HudWidget

const SHOUT_ACTION: StringName = &"shout"

var prompt: KeyPrompt


func build() -> void:
	prompt = KeyPrompt.new(UiTokens.FONT_H2)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt.set_color(tweak.interaction_color)
	add_child(prompt)


func watched_signals() -> Array[StringName]:
	return [&"dominate_prompt_changed"]


func refresh() -> void:
	var target: int = int(prop(&"dominate_target", 0))
	visible = target != 0
	if not visible:
		return
	prompt.set_prompt(&"ui.hud.dominate_prompt", {
		"key": InteractionPanel.action_key_text(SHOUT_ACTION),
		"seconds": snappedf(maxf(float(prop(&"dominate_window_s", 0.0)), 0.0), 0.1)})
