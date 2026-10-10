## Contact portrait slot (pd2_fidelity C2). Owner: ENV B.
## Shows ContactDef.portrait_scene (Control root: fills the slot; Node3D root: rendered in a
## SubViewport), else portrait_texture, else an original procedural silhouette drawn here from
## ContactDef.silhouette + accent_color. No third-party art.
class_name ContactPortrait
extends Control

const SILHOUETTES: Array[StringName] = [&"bun", &"cap", &"veiled", &"headset"]

var contact: ContactDef = null
var bg_color: Color = Color(0.08, 0.07, 0.065, 1)
var figure_color: Color = Color(0.15, 0.135, 0.125, 1)
## The art node currently filling the slot (null while the placeholder silhouette is drawn).
var art: Node = null


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_contact(c: ContactDef) -> void:
	contact = c
	if art != null:
		art.queue_free()
		art = null
	if c != null and c.portrait_scene != null:
		art = _scene_art(c.portrait_scene)
	elif c != null and c.portrait_texture != null:
		var tr_art: TextureRect = TextureRect.new()
		tr_art.texture = c.portrait_texture
		tr_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art = tr_art
	if art is Control:
		(art as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(art as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art != null:
		add_child(art)
	queue_redraw()


func uses_placeholder() -> bool:
	return art == null


func _scene_art(ps: PackedScene) -> Node:
	var n: Node = ps.instantiate()
	if n is Control or not n is Node3D:
		return n
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	holder.add_child(vp)
	vp.add_child(n)
	return holder


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, bg_color)
	if contact == null or art != null:
		return
	var accent: Color = contact.accent_color
	var w: float = size.x
	var h: float = size.y
	var u: float = minf(w, h)
	var c: Vector2 = Vector2(w * 0.5, h * 0.44)
	# Spotlight behind the head.
	for i: int in range(6):
		draw_circle(c, u * (0.46 - 0.06 * i), Color(accent, 0.035 + 0.02 * i))
	var style: StringName = contact.silhouette if SILHOUETTES.has(contact.silhouette) else &"bun"
	var shoulder_rx: float = {&"bun": 0.33, &"cap": 0.47, &"veiled": 0.40, &"headset": 0.40}[style]
	var head_r: float = u * 0.15
	# Shoulders (half ellipse) and neck.
	draw_colored_polygon(_half_ellipse(Vector2(w * 0.5, h * 1.02), Vector2(w * shoulder_rx, h * 0.30)), figure_color)
	draw_rect(Rect2(c.x - head_r * 0.42, c.y + head_r * 0.6, head_r * 0.84, h * 0.2), figure_color)
	match style:
		&"bun":
			draw_circle(c + Vector2(head_r * 0.2, -head_r * 1.0), head_r * 0.5, figure_color)
			draw_circle(c, head_r, figure_color)
			draw_circle(c + Vector2(-head_r * 0.98, head_r * 0.45), u * 0.012, accent)
		&"cap":
			draw_circle(c, head_r, figure_color)
			var cap: PackedVector2Array = _half_ellipse(c + Vector2(0, -head_r * 0.25), Vector2(head_r * 1.08, head_r * 0.95))
			draw_colored_polygon(cap, figure_color.lightened(0.08))
			draw_line(c + Vector2(-head_r * 1.7, -head_r * 0.22), c + Vector2(head_r * 0.6, -head_r * 0.22),
					figure_color.lightened(0.08), u * 0.03)
			draw_line(c + Vector2(-head_r * 1.0, -head_r * 0.42), c + Vector2(head_r * 1.0, -head_r * 0.42), accent, u * 0.008)
		&"veiled":
			var hood: PackedVector2Array = _half_ellipse(c + Vector2(0, head_r * 0.2), Vector2(head_r * 1.4, head_r * 1.5))
			hood.append_array(_half_ellipse(c + Vector2(0, head_r * 0.2), Vector2(-head_r * 1.4, -head_r * 2.4)))
			draw_colored_polygon(hood, figure_color.lightened(0.05))
			draw_circle(c + Vector2(0, head_r * 0.15), head_r * 0.92, bg_color.darkened(0.3))
			for i: int in range(3):
				var y: float = c.y - head_r * 0.2 + i * head_r * 0.38
				draw_rect(Rect2(c.x - head_r * 0.85, y, head_r * 1.7, head_r * 0.2), Color(accent, 0.75 - 0.2 * i))
		&"headset":
			draw_circle(c, head_r, figure_color)
			draw_arc(c, head_r * 1.12, PI * 1.08, PI * 1.92, 24, accent.darkened(0.2), u * 0.018)
			draw_circle(c + Vector2(-head_r * 1.05, head_r * 0.05), head_r * 0.28, figure_color.lightened(0.1))
			draw_circle(c + Vector2(head_r * 1.05, head_r * 0.05), head_r * 0.28, figure_color.lightened(0.1))
			draw_line(c + Vector2(-head_r * 1.05, head_r * 0.2), c + Vector2(-head_r * 0.35, head_r * 0.85), accent, u * 0.01)
			draw_circle(c + Vector2(-head_r * 0.32, head_r * 0.86), u * 0.014, accent)
	# Rim light and frame.
	if style != &"veiled":
		draw_arc(c, head_r + u * 0.006, -PI * 0.45, PI * 0.25, 24, Color(accent, 0.8), u * 0.008)
	draw_rect(r, Color(accent, 0.9), false, maxf(2.0, u * 0.006))


## Points of the upper half of an ellipse (a closed polygon along its flat bottom edge).
static func _half_ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 28
	for i: int in range(n + 1):
		var a: float = PI + PI * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
