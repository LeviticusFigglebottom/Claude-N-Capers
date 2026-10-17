## A small drawn up / down triangle (no font glyph: the UI font has no arrows) so a bonus / penalty reads without
## colour (colour-blind safety, lead r242). direction 1 = up (bonus), -1 = down (penalty), 0 = nothing drawn.
## Owner: ENV B.
class_name TrendMark
extends Control

var direction: int = 0:
	set(v):
		direction = v
		queue_redraw()
var color: Color = UiTokens.PAPER:
	set(v):
		color = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if direction == 0:
		return
	var w: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(w, w)) * 0.5
	var pts: PackedVector2Array
	if direction > 0:
		pts = PackedVector2Array([o + Vector2(w * 0.5, w * 0.15), o + Vector2(w * 0.95, w * 0.85), o + Vector2(w * 0.05, w * 0.85)])
	else:
		pts = PackedVector2Array([o + Vector2(w * 0.05, w * 0.15), o + Vector2(w * 0.95, w * 0.15), o + Vector2(w * 0.5, w * 0.85)])
	draw_colored_polygon(pts, color)
