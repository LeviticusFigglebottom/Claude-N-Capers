## Assault banner (L1.7): phase name and wave while the assault director is active.
class_name AssaultBanner
extends HudWidget

var phase_label: Label
var wave_label: Label


func build() -> void:
	var h: HBoxContainer = UiBuild.hbox(24)
	var p: PanelContainer = UiBuild.panel(h, UiBuild.BANNER_PANEL)
	add_child(p)
	phase_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(phase_label)
	wave_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(wave_label)


func watched_signals() -> Array[StringName]:
	return [&"assault_changed"]


func refresh() -> void:
	var phase: int = int(prop(&"assault_phase", Enums.AssaultPhase.NONE))
	visible = phase != Enums.AssaultPhase.NONE
	if not visible:
		return
	phase_label.text = UiText.t(phase_key(phase))
	var wave: int = int(prop(&"assault_wave", 0))
	wave_label.visible = wave > 0
	wave_label.text = UiText.t(&"ui.hud.assault_wave", {"wave": wave})


static func phase_key(phase: int) -> StringName:
	var keys: Array = Enums.AssaultPhase.keys()
	return StringName("ui.hud.assault_phase.%s" % String(keys[clampi(phase, 0, keys.size() - 1)]).to_lower())
