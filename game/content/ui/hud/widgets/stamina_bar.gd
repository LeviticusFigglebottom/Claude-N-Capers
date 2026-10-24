## Sprint stamina bar (ui_hud.md v1.4, B4-19). Owner: ENV B. Reads `stamina` (0..1, 1 = full) and
## `exhausted` (bool) on `stamina_changed`. Shown only while stamina < 1 or exhausted; the bar and label
## take HudTweak.stamina_exhausted_color while exhausted. Binds by signal name, so it stays hidden until
## ENV A's LocalHudModel has the fields (the mock has them for the demo/tests).
class_name StaminaBar
extends HudWidget

## Below this the bar counts as full (float noise from the model).
const FULL_EPS: float = 0.001

var bar: ProgressBar
var label: Label


func build() -> void:
	var h: HBoxContainer = UiBuild.hbox(10)
	add_child(UiBuild.panel(h, UiBuild.HUD_PANEL))
	label = UiBuild.label(&"ui.hud.stamina", UiBuild.HUD)
	h.add_child(label)
	bar = UiBuild.hud_bar(tweak.stamina_color, Vector2(220, 8))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)


func watched_signals() -> Array[StringName]:
	return [&"stamina_changed"]


func refresh() -> void:
	var raw: Variant = prop(&"stamina", null)
	var exhausted: bool = bool(prop(&"exhausted", false))
	var s: float = clampf(float(raw), 0.0, 1.0) if raw != null else 1.0
	visible = raw != null and (s < 1.0 - FULL_EPS or exhausted)
	bar.value = s
	var c: Color = tweak.stamina_exhausted_color if exhausted else tweak.stamina_color
	bar.self_modulate = c
	label.text = UiText.t(&"ui.hud.stamina_exhausted" if exhausted else &"ui.hud.stamina")
	if exhausted:
		label.add_theme_color_override(&"font_color", c)
	else:
		label.remove_theme_color_override(&"font_color")
