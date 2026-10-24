## Health and armor bars, downs left, downed/custody state with bleedout timer.
class_name VitalsPanel
extends HudWidget

var health_bar: ProgressBar
var armor_bar: ProgressBar
var health_label: Label
var armor_label: Label
var downs_label: Label
var state_label: Label
## ui_hud v1.22 (D-164): while a leech ampule runs, tick marks split the health bar into its slices (tests).
var segment_ticks: Control
## {count, size} of the running ampule; {} = none.
var _segments: Dictionary = {}


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.HUD_PANEL)
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)  # PO-4: sits on the bottom margin
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	state_label = UiBuild.label(&"", UiBuild.HUD)
	state_label.add_theme_color_override(&"font_color", tweak.low_health_color)
	v.add_child(state_label)
	armor_label = _row(v, &"ui.hud.armor")
	armor_bar = UiBuild.hud_bar(tweak.armor_color, Vector2(300, 4))
	v.add_child(armor_bar)
	health_label = _row(v, &"ui.hud.health")
	health_bar = UiBuild.hud_bar(tweak.health_color, Vector2(300, 6))
	v.add_child(health_bar)
	segment_ticks = Control.new()
	segment_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	segment_ticks.visible = false
	segment_ticks.draw.connect(_draw_segments)
	health_bar.add_child(segment_ticks)
	downs_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.DIM))
	v.add_child(downs_label)


func _row(parent: Container, key: StringName) -> Label:
	var h: HBoxContainer = UiBuild.hbox(8)
	# PO-4: label as caption, value as text. r266 B top-3 #1: the caption sits on the label scrim (HEALTH measured
	# 2.94:1 fill on a bright scene); a spacer keeps the value on the right edge.
	var cap: Label = UiBuild.scrim_label(UiBuild.float_text(UiBuild.caption(key)), UiBuild.LABEL_SCRIM_STRONG_ALPHA)
	h.add_child(cap)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)
	var val: Label = UiBuild.label(&"", UiBuild.HUD)
	h.add_child(val)
	parent.add_child(h)
	return val


func watched_signals() -> Array[StringName]:
	return [&"vitals_changed", &"perk_item_changed"]


func refresh() -> void:
	var hp: float = float(prop(&"health", 0.0))
	var hp_max: float = maxf(float(prop(&"max_health", 1.0)), 0.001)
	var ar: float = float(prop(&"armor", 0.0))
	var ar_max: float = float(prop(&"max_armor", 0.0))
	health_bar.value = clampf(hp / hp_max, 0.0, 1.0)
	health_bar.self_modulate = tweak.low_health_color if hp / hp_max <= tweak.low_health_frac else tweak.health_color
	health_label.text = str(roundi(hp))
	armor_bar.value = clampf(ar / ar_max, 0.0, 1.0) if ar_max > 0.0 else 0.0
	armor_label.text = str(roundi(ar))
	downs_label.text = UiText.t(&"ui.hud.downs_left", {"count": int(prop(&"downs_left", 0))})
	var st: int = int(prop(&"crew_state", Enums.CrewState.NORMAL))
	var bleed: float = float(prop(&"bleedout_s", -1.0))
	state_label.text = ""
	if st == Enums.CrewState.CUSTODY:
		state_label.text = UiText.t(&"ui.hud.custody")
	elif st != Enums.CrewState.NORMAL and bleed >= 0.0 and not DownedOverlay.is_helpless(st):  # downed: the big timer
		state_label.text = UiText.t(&"ui.hud.bleedout", {"seconds": ceili(bleed)})
	state_label.visible = state_label.text != ""
	var seg: Dictionary = (prop(&"perk_item", {}) as Dictionary).get("segments", {}) as Dictionary
	if seg != _segments:
		_segments = seg.duplicate()
		segment_ticks.visible = int(seg.get("size", 0)) > 1
		segment_ticks.queue_redraw()


## One dark notch between slices (size - 1 lines), so a hit visibly takes a whole slice.
func _draw_segments() -> void:
	var n: int = int(_segments.get("size", 0))
	var w: float = segment_ticks.size.x
	var h: float = segment_ticks.size.y
	for i: int in range(1, n):
		var x: float = roundf(w * float(i) / float(n))
		segment_ticks.draw_line(Vector2(x, -1.0), Vector2(x, h + 1.0), UiTokens.INK_0, 2.0)
