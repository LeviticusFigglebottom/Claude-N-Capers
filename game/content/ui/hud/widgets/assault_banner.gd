## Assault banner (L1.7): phase name and wave while the assault director is active. Lead queue (c):
## a thin phase strip under the text (PD2 endurance read): anticipation | build | sustain | fade, the
## passed ones filled dim, the current one lit, the rest hollow. Between assaults (CONTROL) the strip
## hides and the banner dims, so "regrouping" never reads like an assault.
## L1.7 difficulty skulls (PD2): one skull per tier above Routine (Tense 1 ... Cataclysm 5) before the phase name, and a
## LAST BREATH tag (C4 One Down). The Hud passes `difficulty` / `last_breath` (MenuFlow sets them at launch).
class_name AssaultBanner
extends HudWidget

## The strip's phases, in order.
const STRIP: Array[int] = [Enums.AssaultPhase.ANTICIPATION, Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN,
		Enums.AssaultPhase.FADE]

var phase_label: Label
## Enums.Difficulty of the running heist (-1 = unknown: no skulls) and the Last Breath flag.
var difficulty: int = -1
var last_breath: bool = false
var skulls: SkullRow
var last_breath_label: Label
var wave_label: Label
var strip: PhaseStrip
var panel: PanelContainer
## PO6-17: the live RNG assault events ("TURRET VAN · BREACH") in red under the phase (Hud feeds set_events).
var events_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var h: HBoxContainer = UiBuild.hbox(24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	panel = UiBuild.panel(v, UiBuild.BANNER_PANEL)
	add_child(panel)
	skulls = SkullRow.new()
	skulls.name = "DifficultySkulls"
	skulls.color = tweak.assault_color
	h.add_child(skulls)
	phase_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(phase_label)
	wave_label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(wave_label)
	last_breath_label = UiBuild.label(&"ui.hud.last_breath", UiBuild.HUD)
	last_breath_label.name = "LastBreath"
	last_breath_label.add_theme_color_override(&"font_color", tweak.assault_color)
	h.add_child(last_breath_label)
	strip = PhaseStrip.new()
	v.add_child(strip)
	events_label = UiBuild.label(&"", UiBuild.HUD)
	events_label.name = "AssaultEvents"
	events_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	events_label.add_theme_color_override(&"font_color", tweak.assault_color)
	events_label.visible = false
	v.add_child(events_label)


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
	skulls.count = maxi(difficulty, 0)
	skulls.visible = skulls.count > 0
	skulls.queue_redraw()
	last_breath_label.visible = last_breath
	strip.current = STRIP.find(phase)
	strip.visible = strip.current >= 0
	strip.queue_redraw()
	panel.modulate.a = 0.7 if phase == Enums.AssaultPhase.CONTROL else 1.0


## PO6-17 (AssaultEventMarkers.events_changed): the live event names; empty hides the line.
func set_events(kinds: Array[StringName]) -> void:
	if events_label == null:
		return
	var names: PackedStringArray = PackedStringArray()
	for k: StringName in kinds:
		var t: String = AssaultEventMarkers.kind_text(k)
		if not names.has(t):
			names.append(t)
	events_label.text = " · ".join(names)
	events_label.visible = not names.is_empty()


static func phase_key(phase: int) -> StringName:
	var keys: Array = Enums.AssaultPhase.keys()
	return StringName("ui.hud.assault_phase.%s" % String(keys[clampi(phase, 0, keys.size() - 1)]).to_lower())


## `count` small skull pictograms in a row (drawn: cranium, jaw, two eye sockets), PD2's difficulty marks.
class SkullRow:
	extends Control

	const SIZE: float = 16.0
	const GAP: float = 4.0
	var count: int = 0:
		set(v):
			count = v
			custom_minimum_size = Vector2(maxf(count * (SIZE + GAP) - GAP, 0.0), SIZE)
	var color: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var y0: float = (size.y - SIZE) * 0.5
		for i: int in range(count):
			var x: float = i * (SIZE + GAP)
			var c: Vector2 = Vector2(x + SIZE * 0.5, y0 + SIZE * 0.42)
			draw_circle(c, SIZE * 0.42, color)
			draw_rect(Rect2(Vector2(x + SIZE * 0.26, y0 + SIZE * 0.6), Vector2(SIZE * 0.48, SIZE * 0.36)), color)
			for e: float in [-1.0, 1.0]:
				draw_circle(c + Vector2(e * SIZE * 0.17, SIZE * 0.02), SIZE * 0.11, UiTokens.INK_0)


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
