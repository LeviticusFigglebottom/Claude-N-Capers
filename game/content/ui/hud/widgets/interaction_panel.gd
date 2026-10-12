## Interaction prompt (tr(text_key) with args), hold progress bar and blocked reason (S9.1, S1.1).
## The input key name is presentation (hud_model README): when the model's args carry no `key`,
## the first keyboard binding of INTERACT_ACTION is filled in for the `{key}` placeholder.
class_name InteractionPanel
extends HudWidget

const INTERACT_ACTION: StringName = &"interact"

var prompt_label: Label
var progress_bar: ProgressBar
var blocked_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	prompt_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt_label)
	progress_bar = UiBuild.bar(tweak.interaction_color, Vector2(320, 10))
	progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(progress_bar)
	blocked_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))
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
	var args: Dictionary = (it.get("args", {}) as Dictionary).duplicate()
	if not args.has("key"):
		args["key"] = action_key_text(INTERACT_ACTION)
	prompt_label.text = UiText.t(key, args)
	var p: float = float(it.get("progress", 0.0))
	progress_bar.visible = p > 0.0
	progress_bar.value = p
	var blocked: StringName = StringName(it.get("blocked_reason", &""))
	blocked_label.visible = blocked != &""
	blocked_label.text = UiText.t(blocked, args) if blocked != &"" else ""


## Display text of the first keyboard binding of an InputMap action ("F"), or "" when unbound.
static func action_key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = ev as InputEventKey
		if k != null:
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return ""
