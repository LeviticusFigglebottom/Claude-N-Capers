## Captain widget (ui_hud.md v1.3, D-049; pd2_fidelity L4.9): while Commander Brandt is on the map
## (`captain_present`), his name and the Aegis damage resistance (`captain_resistance` 0..1) as a bar and
## a percentage. Binds `captain_changed` by name, so it lights up once ENV A's LocalHudModel has the
## fields; hidden while they are missing.
class_name CaptainPanel
extends HudWidget

var title_label: Label
var resistance_label: Label
var resistance_bar: ProgressBar


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.BANNER_PANEL)
	add_child(p)
	title_label = UiBuild.label(&"ui.hud.captain", UiBuild.HUD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override(&"font_color", tweak.captain_color)
	v.add_child(title_label)
	resistance_bar = UiBuild.bar(tweak.captain_color, Vector2(480, 10))
	v.add_child(resistance_bar)
	resistance_label = UiBuild.label(&"", UiBuild.HUD)
	resistance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(resistance_label)


func watched_signals() -> Array[StringName]:
	return [&"captain_changed"]


func refresh() -> void:
	visible = bool(prop(&"captain_present", false))
	var r: float = clampf(float(prop(&"captain_resistance", 0.0)), 0.0, 1.0)
	resistance_bar.value = r
	resistance_label.text = UiText.t(&"ui.hud.captain_resistance", {"pct": roundi(r * 100.0)})
