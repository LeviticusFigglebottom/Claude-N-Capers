## Blueprint panel placeholder on the briefing screen (pd2_fidelity C2 "blueprint"). Owner: ENV B.
## Draws a blueprint grid and a generic floor outline with a "plans pending" note until ENV C
## provides a per-heist blueprint render (then this slot shows that instead; see B2-01 map).
class_name BlueprintPlaceholder
extends Control

var bg_color: Color = Color(0.05, 0.12, 0.22, 1)
var grid_color: Color = Color(0.25, 0.45, 0.7, 0.35)
var line_color: Color = Color(0.6, 0.8, 1.0, 0.85)
var note: Label = null


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	note = UiBuild.label(&"ui.briefing.blueprint_pending", UiBuild.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(note)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	var step: float = maxf(minf(w, h) / 12.0, 8.0)
	var x: float = 0.0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), grid_color, 1.0)
		x += step
	var y: float = 0.0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), grid_color, 1.0)
		y += step
	# Generic two-room outline with a door gap and a dashed route: clearly a placeholder plan.
	var o: Vector2 = Vector2(w * 0.14, h * 0.14)
	var s: Vector2 = Vector2(w * 0.72, h * 0.56)
	var lw: float = maxf(2.0, minf(w, h) * 0.01)
	draw_rect(Rect2(o, s), line_color, false, lw)
	var wall_x: float = o.x + s.x * 0.62
	draw_line(Vector2(wall_x, o.y), Vector2(wall_x, o.y + s.y * 0.4), line_color, lw)
	draw_line(Vector2(wall_x, o.y + s.y * 0.6), Vector2(wall_x, o.y + s.y), line_color, lw)
	draw_dashed_line(Vector2(o.x + s.x * 0.1, o.y + s.y * 0.85), Vector2(o.x + s.x * 0.85, o.y + s.y * 0.3),
			Color(line_color, 0.6), lw * 0.6, lw * 3.0)
	draw_circle(Vector2(o.x + s.x * 0.85, o.y + s.y * 0.3), lw * 2.0, line_color)
