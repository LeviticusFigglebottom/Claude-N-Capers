## Radial hold progress (lead round 64, PD2's circular interaction timer): a ProgressBar that draws a
## ring around its rect instead of a bar. It sits inside the key cap of the interaction prompt, so the
## ring circles the key. A dim full track, then the clockwise fill from 12 o'clock; the colour is the
## node's self_modulate (palette tint, UiBuild.bar convention). value 0..1. Owner: ENV B.
class_name ProgressRing
extends ProgressBar

const WIDTH: float = 4.0
const PAD: float = 7.0


func _init() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sb: StringName in [&"background", &"fill"]:
		add_theme_stylebox_override(sb, StyleBoxEmpty.new())
	value_changed.connect(func(_v: float) -> void: queue_redraw())
	resized.connect(queue_redraw)


func _draw() -> void:
	# Centre on the key cap (the parent), whatever rect the container gave this node.
	var host: Control = get_parent() as Control
	var box: Vector2 = host.size if host != null else size
	var c: Vector2 = box * 0.5 - position
	var r: float = maxf(box.x, box.y) * 0.5 + PAD
	draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.55), WIDTH + 3.0, true)  # outline for bright scenes
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.22), WIDTH, true)
	var f: float = clampf(value, 0.0, 1.0)
	if f > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, maxi(4, int(48 * f)), Color.WHITE, WIDTH, true)
