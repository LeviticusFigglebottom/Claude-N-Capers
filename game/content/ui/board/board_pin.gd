## One contract pin on the Board's city map. Owner: ENV B. A focusable Button (mouse, keyboard,
## gamepad) drawn in code: contact-coloured disc, a ring that empties as the contract expires,
## difficulty pips, a pro badge, and the interactable-accent ring while focused or selected.
class_name BoardPin
extends Button

var contract: Dictionary = {}
var accent: Color = Color(0.8, 0.8, 0.8, 1)
var highlight: Color = Color(0.31, 0.82, 0.91, 1)
var pro_color: Color = Color(0.62, 0.17, 0.15, 1)
## 1 = fresh contract, 0 = expiring now.
var time_fraction: float = 1.0
var selected: bool = false


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for s: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		add_theme_stylebox_override(s, empty)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## Pin size for a disc of `disc_px`: the disc on top, the difficulty pips under it.
static func size_for(disc_px: float) -> Vector2:
	return Vector2(disc_px * 1.5, disc_px * 1.5)


## Where the disc centre sits inside the pin (the map anchors this point on the contract's spot).
func disc_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.4)


func _draw() -> void:
	var c: Vector2 = disc_center()
	var r: float = minf(size.x, size.y) * 0.3
	var lit: bool = has_focus() or selected or is_hovered()
	draw_circle(c + Vector2(0, r * 0.18), r * 1.12, Color(0, 0, 0, 0.45))
	if lit:
		draw_arc(c, r * 1.38, 0.0, TAU, 40, highlight, maxf(2.0, r * 0.14), true)
	draw_circle(c, r * 1.08, Color(0.07, 0.08, 0.1, 1))
	draw_arc(c, r * 1.0, 0.0, TAU, 40, Color(accent, 0.25), r * 0.16, true)
	if time_fraction > 0.0:
		draw_arc(c, r * 1.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(time_fraction, 0.0, 1.0), 40, accent, r * 0.16, true)
	draw_circle(c, r * 0.62, accent.darkened(0.15))
	draw_circle(c, r * 0.26, Color(0.07, 0.08, 0.1, 1))
	if bool(contract.get("is_pro", false)):
		var b: Vector2 = c + Vector2(r * 0.95, -r * 0.95)
		var s: float = r * 0.42
		var diamond: PackedVector2Array = PackedVector2Array([b + Vector2(0, -s), b + Vector2(s, 0), b + Vector2(0, s), b + Vector2(-s, 0)])
		draw_colored_polygon(diamond, pro_color)
		diamond.append(diamond[0])
		draw_polyline(diamond, Color(1, 0.86, 0.8, 0.9), maxf(1.0, r * 0.07), true)
	var pips: int = int(contract.get("difficulty", 0)) + 1
	var pip: float = r * 0.3
	var gap: float = pip * 0.5
	var row_w: float = pips * pip + (pips - 1) * gap
	var y: float = c.y + r * 1.42
	for i: int in range(pips):
		var x: float = c.x - row_w * 0.5 + i * (pip + gap)
		draw_rect(Rect2(x, y, pip, pip), Color(0.9, 0.91, 0.93, 0.9) if i < 4 else pro_color.lightened(0.25))
