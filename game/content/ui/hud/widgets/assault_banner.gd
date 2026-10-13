## Assault banner (L1.7): phase name and wave while the assault director is active. Lead queue (c):
## a thin phase strip under the text (PD2 endurance read): anticipation | build | sustain | fade, the
## passed ones filled dim, the current one lit, the rest hollow. Between assaults (CONTROL) the strip
## hides and the banner dims, so "regrouping" never reads like an assault.
class_name AssaultBanner
extends HudWidget

## The strip's phases, in order.
const STRIP: Array[int] = [Enums.AssaultPhase.ANTICIPATION, Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN,
		Enums.AssaultPhase.FADE]

var phase_label: Label
var wave_label: Label
var strip: PhaseStrip
var panel: PanelContainer


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var h: HBoxContainer = UiBuild.hbox(24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	panel = UiBuild.panel(v, UiBuild.BANNER_PANEL)
	add_child(panel)
	phase_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(phase_label)
	wave_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(wave_label)
	strip = PhaseStrip.new()
	v.add_child(strip)


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
	strip.current = STRIP.find(phase)
	strip.visible = strip.current >= 0
	strip.queue_redraw()
	panel.modulate.a = 0.7 if phase == Enums.AssaultPhase.CONTROL else 1.0


static func phase_key(phase: int) -> StringName:
	var keys: Array = Enums.AssaultPhase.keys()
	return StringName("ui.hud.assault_phase.%s" % String(keys[clampi(phase, 0, keys.size() - 1)]).to_lower())


## The 4-segment phase strip (drawn; `current` = index into STRIP, -1 = none).
class PhaseStrip:
	extends Control

	var current: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 6)

	func _draw() -> void:
		var n: int = AssaultBanner.STRIP.size()
		var gap: float = 4.0
		var w: float = (size.x - gap * (n - 1)) / n
		for i: int in range(n):
			var r: Rect2 = Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
			if i < current:
				draw_rect(r, Color(UiTokens.PAPER, 0.45))
			elif i == current:
				draw_rect(r, UiTokens.PAPER)
			else:
				draw_rect(r, Color(UiTokens.PAPER, 0.45), false, 1.0)
