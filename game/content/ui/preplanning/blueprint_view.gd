## Top-down blueprint of a heist (B2-01): grid, shapes and labels drawn with Control._draw(), plus
## one focusable marker Button per pre-planning point that offers assets. Owner: ENV B.
## No art assets: everything is drawn from PreplanBlueprint data. Mouse: click a marker. Keyboard /
## gamepad: markers are Buttons, so arrows / d-pad move between them by position (Godot's spatial
## focus search) and Enter / A presses one.
class_name BlueprintView
extends Control

signal point_pressed(point_id: StringName)
signal point_focused(point_id: StringName)

## Pixels kept free around the drawn bounds.
const PAD: float = 28.0

var board: PreplanBoard
var tweak: PreplanTweak
var floor_index: int = 0
## point id -> Button (current floor)
var markers: Dictionary = {}
## point id -> Label (name under the marker)
var marker_labels: Dictionary = {}
## point id -> 1-based number shown on the marker
var marker_numbers: Dictionary = {}
var _styles: Dictionary = {}


func setup(p_board: PreplanBoard) -> void:
	board = p_board
	tweak = board.tweak
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not resized.is_connected(_layout_markers):
		resized.connect(_layout_markers)
	_build_markers()


func set_floor(index: int) -> void:
	floor_index = clampi(index, 0, board.blueprint.floor_count() - 1)
	_build_markers()
	queue_redraw()


## Marker ids of the current floor in blueprint order.
func marker_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for pid: StringName in board.blueprint.point_ids():
		if markers.has(pid):
			out.append(pid)
	return out


## Recolor markers: owned = an asset is placed there, vote = a plan option there, selected = shown in the panel.
func refresh(plan: PreplanPlan, selected_point: StringName) -> void:
	for pid: Variant in markers:
		var b: Button = markers[pid] as Button
		var i: int = plan.index_at(StringName(pid))
		var state: StringName = &"free"
		if i >= 0:
			var a: PreplanAssetDef = board.asset(StringName(plan.selections[i]["asset"]))
			state = &"vote" if a != null and a.vote_group != &"" else &"owned"
		_apply_style(b, state, StringName(pid) == selected_point)


## View position (pixels, local) of a world point (meters, x/z).
func world_to_view(p: Vector2) -> Vector2:
	var t: Dictionary = _transform()
	return Vector2(t["origin"]) + (p - board.blueprint.bounds.position) * float(t["scale"])


func _transform() -> Dictionary:
	var b: Rect2 = board.blueprint.bounds
	var avail: Vector2 = (size - Vector2(PAD, PAD) * 2.0).max(Vector2.ONE)
	var s: float = minf(avail.x / maxf(b.size.x, 0.01), avail.y / maxf(b.size.y, 0.01))
	var used: Vector2 = b.size * s
	return {"scale": s, "origin": (size - used) * 0.5}


func _build_markers() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	markers.clear()
	marker_labels.clear()
	marker_numbers.clear()
	var n: int = 0
	for pid: StringName in board.active_point_ids():
		var p: Dictionary = board.blueprint.point(pid)
		if int(p.get("floor", 0)) != floor_index:
			continue
		n += 1
		var b: Button = Button.new()
		b.name = "Marker_%s" % pid
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.text = str(n)
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(tweak.marker_size, tweak.marker_size)
		b.size = b.custom_minimum_size
		b.tooltip_text = UiText.t(StringName(p.get("label", &"")))
		b.pressed.connect(point_pressed.emit.bind(pid))
		b.focus_entered.connect(point_focused.emit.bind(pid))
		_apply_style(b, &"free", false)
		add_child(b)
		markers[pid] = b
		marker_numbers[pid] = n
		var l: Label = UiBuild.label(StringName(p.get("label", &"")))
		l.add_theme_font_size_override(&"font_size", 21)
		l.add_theme_color_override(&"font_color", tweak.label_color)
		l.add_theme_color_override(&"font_outline_color", tweak.paper_color)
		l.add_theme_constant_override(&"outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		marker_labels[pid] = l
	_layout_markers()


func _layout_markers() -> void:
	for pid: Variant in markers:
		var p: Dictionary = board.blueprint.point(StringName(pid))
		var c: Vector2 = world_to_view(p.get("pos", Vector2.ZERO) as Vector2)
		var b: Button = markers[pid] as Button
		b.position = c - b.size * 0.5
		var l: Label = marker_labels[pid] as Label
		l.reset_size()
		l.position = Vector2(c.x - l.size.x * 0.5, c.y + b.size.y * 0.5 + 2.0)
	queue_redraw()


func _apply_style(b: Button, state: StringName, selected: bool) -> void:
	var fill: Color = tweak.paper_color.lerp(tweak.point_color, 0.25)
	var border: Color = tweak.point_color
	if state == &"owned":
		fill = tweak.point_owned_color.darkened(0.35)
		border = tweak.point_owned_color
	elif state == &"vote":
		fill = tweak.point_vote_color.darkened(0.4)
		border = tweak.point_vote_color
	var key: String = "%s_%s" % [state, selected]
	if not _styles.has(key):
		var r: int = int(tweak.marker_size * 0.5)
		var normal: StyleBoxFlat = _circle(fill, border, 4 if selected else 2, r)
		var hover: StyleBoxFlat = _circle(fill.lightened(0.2), border, 4 if selected else 3, r)
		var focus: StyleBoxFlat = _circle(Color(0, 0, 0, 0), Color(1, 1, 1), 4, r)
		focus.expand_margin_left = 4
		focus.expand_margin_right = 4
		focus.expand_margin_top = 4
		focus.expand_margin_bottom = 4
		_styles[key] = [normal, hover, focus]
	var st: Array = _styles[key]
	b.add_theme_stylebox_override(&"normal", st[0])
	b.add_theme_stylebox_override(&"hover", st[1])
	b.add_theme_stylebox_override(&"pressed", st[1])
	b.add_theme_stylebox_override(&"hover_pressed", st[1])
	b.add_theme_stylebox_override(&"focus", st[2])
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color",
			&"font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(1, 1, 1))


static func _circle(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


func _draw() -> void:
	if board == null:
		return
	var bp: PreplanBlueprint = board.blueprint
	draw_rect(Rect2(Vector2.ZERO, size), tweak.paper_color)
	var t: Dictionary = _transform()
	var s: float = float(t["scale"])
	var area: Rect2 = Rect2(world_to_view(bp.bounds.position), bp.bounds.size * s)
	_draw_grid(area)
	var font: Font = get_theme_default_font()
	for sh: Dictionary in bp.shapes:
		var fl: int = int(sh.get("floor", -1))
		if fl >= 0 and fl != floor_index:
			continue
		var r: Rect2 = sh.get("rect", Rect2()) as Rect2
		var vr: Rect2 = Rect2(world_to_view(r.position), r.size * s)
		var fill: Color = tweak.shape_fill.get(StringName(sh.get("kind", &"")), tweak.grid_color) as Color
		draw_rect(vr, fill)
		draw_rect(vr, tweak.line_color, false, 2.0 if StringName(sh.get("kind", &"")) == &"building" else 1.0)
	for sh: Dictionary in bp.shapes:
		var key: StringName = StringName(sh.get("label", &""))
		var fl2: int = int(sh.get("floor", -1))
		if key == &"" or (fl2 >= 0 and fl2 != floor_index):
			continue
		var r2: Rect2 = sh.get("rect", Rect2()) as Rect2
		var vr2: Rect2 = Rect2(world_to_view(r2.position), r2.size * s)
		var text: String = UiText.t(key).to_upper()
		var fs: int = 16
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > vr2.size.x - 8.0:
			continue
		draw_string(font, vr2.position + Vector2(6, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tweak.label_color)
	draw_rect(area, tweak.line_color, false, 2.0)
	_draw_scale_bar(area, s, font)


func _draw_grid(area: Rect2) -> void:
	var step: float = maxf(board.blueprint.grid_step_m, 0.5)
	var b: Rect2 = board.blueprint.bounds
	var x: float = ceilf(b.position.x / step) * step
	while x <= b.end.x + 0.001:
		var vx: float = world_to_view(Vector2(x, b.position.y)).x
		var major: bool = is_zero_approx(fmod(absf(x), step * 5.0))
		draw_line(Vector2(vx, area.position.y), Vector2(vx, area.end.y), tweak.grid_major_color if major else tweak.grid_color, 1.0)
		x += step
	var z: float = ceilf(b.position.y / step) * step
	while z <= b.end.y + 0.001:
		var vy: float = world_to_view(Vector2(b.position.x, z)).y
		var major_z: bool = is_zero_approx(fmod(absf(z), step * 5.0))
		draw_line(Vector2(area.position.x, vy), Vector2(area.end.x, vy), tweak.grid_major_color if major_z else tweak.grid_color, 1.0)
		z += step


func _draw_scale_bar(area: Rect2, s: float, font: Font) -> void:
	var meters: float = 10.0
	var o: Vector2 = Vector2(area.end.x - meters * s - 12.0, area.end.y - 14.0)
	draw_line(o, o + Vector2(meters * s, 0), tweak.line_color, 3.0)
	draw_line(o + Vector2(0, -6), o + Vector2(0, 0), tweak.line_color, 2.0)
	draw_line(o + Vector2(meters * s, -6), o + Vector2(meters * s, 0), tweak.line_color, 2.0)
	draw_string(font, o + Vector2(0, -10), UiText.t(&"ui.preplan.scale", {"m": int(meters)}),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tweak.label_color)
	var n: Vector2 = Vector2(maxf(area.position.x - 30.0, 16.0), area.position.y + 30.0)
	draw_line(n + Vector2(0, 14), n + Vector2(0, -14), tweak.line_color, 2.0)
	draw_line(n + Vector2(0, -14), n + Vector2(-6, -4), tweak.line_color, 2.0)
	draw_line(n + Vector2(0, -14), n + Vector2(6, -4), tweak.line_color, 2.0)
	draw_string(font, n + Vector2(-6, 34), UiText.t(&"ui.preplan.north"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tweak.label_color)
