## PO-4 briefing timeline: one step's node on a vertical rail (a ring, filled brass for the first
## step) with the rail running to the previous and next steps. Drawn in code. Owner: ENV B.
class_name TimelineNode
extends Control

const R: float = 7.0

var first: bool = false
var last: bool = false
## D-117 §5: the "+N more steps" row: a dashed rail and no ring (steps left out between the lead ones and the final).
var gap: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(22, 34)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = Vector2(size.x * 0.5, 17.0)
	var rail: Color = UiTokens.LINE_STRONG
	if gap:
		draw_dashed_line(Vector2(c.x, 0), Vector2(c.x, size.y), rail, 2.0, 4.0)
		return
	if not first:
		draw_line(Vector2(c.x, 0), c - Vector2(0, R), rail, 2.0)
	if not last:
		draw_line(c + Vector2(0, R), Vector2(c.x, size.y), rail, 2.0)
	if first:
		draw_circle(c, R, UiTokens.BRASS)
	else:
		draw_arc(c, R, 0.0, TAU, 20, UiTokens.PAPER_DIM, 2.0, true)
