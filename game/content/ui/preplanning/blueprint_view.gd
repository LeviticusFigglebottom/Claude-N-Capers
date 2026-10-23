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

## Zone name size (canvas units) in _draw(); _zone_label_rects() measures with it.
const ZONE_FONT: int = 16
## LEAD r304: a name too big for its zone at ZONE_FONT tries this size inside the zone before going beside it.
const ZONE_FONT_SMALL: int = 12
## LEAD r304: point labels also try spots this many pixels further out from their marker (crowded plans).
const LABEL_FAR: float = 16.0
## Clear pixels kept between two markers (_separate_markers).
const MARKER_GAP: float = 4.0
## Length of the scale bar in meters (_draw_scale_bar, _furniture_rects).
const SCALE_BAR_M: float = 10.0
## _zone_labels: the cost of a beside-name crossing the map's outer frame (below a hard clash, 1e6).
const FRAME_STRADDLE_COST: float = 1e5
## Pixels between a narrow zone and its name placed beside it (_zone_labels).
const BESIDE_GAP: float = 6.0

var board: PreplanBoard
var tweak: PreplanTweak
var floor_index: int = 0
## point id -> Button (current floor)
var markers: Dictionary = {}
## point id -> Label (name under the marker)
var marker_labels: Dictionary = {}
## point id -> 1-based number shown on the marker
var marker_numbers: Dictionary = {}
## Zone-name rects a shown point label had to cover (no clear spot, e.g. the small briefing view): _draw() leaves
## those names out instead of printing two texts over each other (lead r242, DB "Pontoon" over "LANDING STAGE").
var yielded_zones: Array[Rect2] = []
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
		b.focus_entered.connect(_peek_label.bind(pid, true))
		b.focus_exited.connect(_peek_label.bind(pid, false))
		b.mouse_entered.connect(_peek_label.bind(pid, true))
		b.mouse_exited.connect(_peek_label.bind(pid, false))
		_apply_style(b, &"free", false)
		add_child(b)
		markers[pid] = b
		marker_numbers[pid] = n
		var l: Label = UiBuild.label(StringName(p.get("label", &"")))
		l.add_theme_font_size_override(&"font_size", 21)
		l.add_theme_color_override(&"font_color", tweak.label_color)
		l.add_theme_color_override(&"font_outline_color", tweak.paper_color)
		l.add_theme_constant_override(&"outline_size", 6)
		# Lead r222: a thin translucent plate in the paper colour, so a line under a label never cuts its text.
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = Color(tweak.paper_color, tweak.label_plate_alpha)
		plate.set_content_margin_all(2.0)
		plate.set_corner_radius_all(2)
		l.add_theme_stylebox_override(&"normal", plate)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		marker_labels[pid] = l
	_layout_markers()


## PO-4 (audit: point labels overlapped, "Alley … Van: alley west"); lead r222 (blueprints): each label scores 8 spots
## around its marker (below, above, right, left and the diagonals) by overlap with markers and placed labels (heavy)
## and with the drawn shape edges (light, so a label does not straddle a street edge) and takes the cheapest. A label
## whose every spot covers a marker is hidden and shows while its marker is focused or hovered.
func _layout_markers() -> void:
	# Zone names are soft (a label may cover one when nothing else is free); the scale bar, the north arrow and
	# labels already placed are hard: a label with no spot clear of them hides (crowded, shown on hover).
	for pid: Variant in markers:
		var p: Dictionary = board.blueprint.point(StringName(pid))
		var b: Button = markers[pid] as Button
		b.position = world_to_view(p.get("pos", Vector2.ZERO) as Vector2) - b.size * 0.5
	_separate_markers()
	var taken: Array[Rect2] = _zone_label_rects()  # after the markers move: zone names keep off them
	yielded_zones.clear()
	var hard: Array[Rect2] = _furniture_rects()
	var marker_rects: Array[Rect2] = []
	for pid: Variant in markers:
		marker_rects.append((markers[pid] as Button).get_rect().grow(5.0))  # LEAD r304: clear of the focus ring too
	var edges: Array[Rect2] = _shape_edge_rects()
	for pid: Variant in markers:
		var b: Button = markers[pid] as Button
		var l: Label = marker_labels[pid] as Label
		l.reset_size()
		var c: Vector2 = b.position + b.size * 0.5
		var h: Vector2 = b.size * 0.5
		var w: Vector2 = l.size
		var spots: Array[Vector2] = []
		for far: float in [0.0, LABEL_FAR]:  # LEAD r304: a second, wider ring for crowded plans
			spots.append_array([
				Vector2(c.x - w.x * 0.5, c.y + h.y + 2.0 + far), Vector2(c.x - w.x * 0.5, c.y - h.y - 2.0 - w.y - far),
				Vector2(c.x + h.x + 4.0 + far, c.y - w.y * 0.5), Vector2(c.x - h.x - 4.0 - w.x - far, c.y - w.y * 0.5),
				Vector2(c.x + h.x + 2.0 + far, c.y + h.y), Vector2(c.x - h.x - 2.0 - w.x - far, c.y + h.y),
				Vector2(c.x + h.x + 2.0 + far, c.y - h.y - w.y), Vector2(c.x - h.x - 2.0 - w.x - far, c.y - h.y - w.y)])
		# LEAD r304 (AH: "Gear: patrons' restroom duct" hung in the margin): a label stays inside the drawn plan.
		var frame: Rect2 = Rect2(world_to_view(board.blueprint.bounds.position),
				board.blueprint.bounds.size * float(_transform()["scale"]))
		var best: Vector2 = spots[0]
		var best_cost: float = INF
		var best_blocked: bool = true
		for si: int in range(spots.size()):
			var spot: Vector2 = spots[si]
			var r: Rect2 = Rect2(spot, w)
			if size != Vector2.ZERO and not (Rect2(Vector2.ZERO, size).encloses(r) and frame.encloses(r)):
				continue
			var blocked: bool = false
			var cost: float = 0.5 if si >= 8 else 0.0  # the near ring wins a tie
			for m: Rect2 in marker_rects:
				if m.intersects(r):
					blocked = true
					cost += 1e6
			for t: Rect2 in taken:
				if t.intersects(r):
					cost += 1000.0 + t.intersection(r).get_area()
			for hr: Rect2 in hard:
				if hr.intersects(r):
					blocked = true
					cost += 1e5
			for e: Rect2 in edges:
				if e.intersects(r):
					cost += 1.0 + e.intersection(r).get_area() * 0.1
			if cost < best_cost:
				best_cost = cost
				best = spot
				best_blocked = blocked
		l.position = best
		if not best_blocked:
			hard.append(Rect2(best, w))
			for t: Rect2 in taken:
				if t.intersects(Rect2(best, w)) and t.intersection(Rect2(best, w)).get_area() > 4.0:
					yielded_zones.append(t)
		l.set_meta(&"crowded", best_blocked)
		l.visible = not best_blocked
	queue_redraw()


## Thin rects (view px) along the edges of the shapes drawn on this floor: label placement avoids sitting on lines.
func _shape_edge_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if board == null or size == Vector2.ZERO:
		return out
	var s: float = float(_transform()["scale"])
	for sh: Dictionary in board.blueprint.shapes:
		var fl: int = int(sh.get("floor", -1))
		if fl >= 0 and fl != floor_index:
			continue
		var r: Rect2 = sh.get("rect", Rect2()) as Rect2
		var vr: Rect2 = Rect2(world_to_view(r.position), r.size * s)
		out.append(Rect2(vr.position - Vector2(1, 1), Vector2(vr.size.x + 2, 2)))
		out.append(Rect2(Vector2(vr.position.x - 1, vr.end.y - 1), Vector2(vr.size.x + 2, 2)))
		out.append(Rect2(vr.position - Vector2(1, 1), Vector2(2, vr.size.y + 2)))
		out.append(Rect2(Vector2(vr.end.x - 1, vr.position.y - 1), Vector2(2, vr.size.y + 2)))
	return out


## GN-B1 capture: two points a couple of meters apart (Gallery Night's portico entry and limo escape) drew
## one marker over the other. A later marker that overlaps an earlier one moves straight away from it (down
## when they coincide) until MARKER_GAP px clear, inside the view.
func _separate_markers() -> void:
	var placed: Array[Button] = []
	for pid: Variant in markers:
		var b: Button = markers[pid] as Button
		for _pass: int in range(4):
			var moved: bool = false
			for o: Button in placed:
				var d: Vector2 = (b.position + b.size * 0.5) - (o.position + o.size * 0.5)
				var need: float = (b.size.x + o.size.x) * 0.5 + MARKER_GAP
				if d.length() >= need:
					continue
				var dir: Vector2 = d.normalized() if d.length() > 0.5 else Vector2.DOWN
				b.position += dir * (need - d.length())
				moved = true
			if size != Vector2.ZERO:
				b.position = b.position.clamp(Vector2.ZERO, (size - b.size).max(Vector2.ZERO))
			if not moved:
				break
		placed.append(b)


## True when a shown point label covers this zone name's rect (the name is not drawn; see yielded_zones).
func is_zone_yielded(r: Rect2) -> bool:
	for y: Rect2 in yielded_zones:
		if y.is_equal_approx(r):
			return true
	return false


## Rects of the zone names _draw() prints (see _zone_labels).
func _zone_label_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for z: Array in _zone_labels():
		out.append(z[2] as Rect2)
	return out


## The zone names this floor shows: [text, baseline pos, rect, leader, font size] (leader: [from, to] or null).
## 1. Inside: at the zone's top-left when the name fits the zone (width AND height) and clears a name already
##    placed (ND audit: "WAREHOUSE YARD" on a 1 m strip ran into "STAFF LOT").
## 2. Beside (LEAD r226, DB containers / west lane): a name that fits none of its zones goes just outside the union
##    of its zones on this floor (right, left, above, below), on a paper plate with a short leader line, at the spot
##    the collision scoring likes best (names already placed and the scale bar / north arrow are hard, shape edges
##    cost a little); with no clear spot it is left out. A name shows once per floor.
func _zone_labels() -> Array[Array]:
	var out: Array[Array] = []
	if board == null or size == Vector2.ZERO:
		return out
	var s: float = float(_transform()["scale"])
	var font: Font = get_theme_default_font()
	var placed: Array[Rect2] = []
	var shown: Dictionary = {}
	var narrow: Dictionary = {}  # text -> union view rect of its zones that are too small for it
	# LEAD r229 real-input run: "STAIRS" sat under marker 2. A name inside its zone that a marker covers goes beside
	# the zone instead (markers are hard for the beside spots too).
	var marker_rects: Array[Rect2] = []
	for pid: Variant in markers:
		var mb: Button = markers[pid] as Button
		if mb.visible:
			marker_rects.append(mb.get_rect().grow(2.0))
	for sh: Dictionary in board.blueprint.shapes:
		var key: StringName = StringName(sh.get("label", &""))
		var fl: int = int(sh.get("floor", -1))
		if key == &"" or (fl >= 0 and fl != floor_index):
			continue
		var r: Rect2 = sh.get("rect", Rect2()) as Rect2
		var vr: Rect2 = Rect2(world_to_view(r.position), r.size * s)
		var text: String = UiText.t(key).to_upper()
		var fs: int = ZONE_FONT
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		if ts.x > vr.size.x - 8.0 or ts.y > vr.size.y - 4.0:
			fs = ZONE_FONT_SMALL
			ts = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rect: Rect2 = Rect2(vr.position + Vector2(6, 4), ts)
		var under_marker: bool = false
		for m: Rect2 in marker_rects:
			under_marker = under_marker or m.intersects(rect)
		if ts.x > vr.size.x - 8.0 or ts.y > vr.size.y - 4.0 or under_marker:
			narrow[text] = (narrow[text] as Rect2).merge(vr) if narrow.has(text) else vr
			continue
		var clash: bool = shown.has(text)
		for p: Rect2 in placed:
			clash = clash or p.intersects(rect)
		if clash:
			continue
		placed.append(rect)
		shown[text] = true
		out.append([text, vr.position + Vector2(6, 4.0 + float(fs) * 0.875), rect, null, fs])
	var hard: Array[Rect2] = _furniture_rects()
	hard.append_array(marker_rects)
	var edges: Array[Rect2] = _shape_edge_rects()
	var view: Rect2 = Rect2(Vector2.ZERO, size)
	# RT-B1 720p / 4K pass: a name beside a zone on the map's edge straddled the outer frame line ("SITE WELFARE CABIN",
	# "FRAME, GROUND LEVEL"); a spot half in, half out of the drawn bounds costs far more than any other edge.
	var sc: float = float(_transform()["scale"])
	var frame: Rect2 = Rect2(world_to_view(board.blueprint.bounds.position), board.blueprint.bounds.size * sc)
	for text: String in narrow:
		if shown.has(text):
			continue
		var z: Rect2 = narrow[text] as Rect2
		var ts2: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ZONE_FONT) + Vector2(6, 2)
		var gap: float = BESIDE_GAP
		var spots: Array[Vector2] = [
			Vector2(z.end.x + gap, z.get_center().y - ts2.y * 0.5), Vector2(z.position.x - gap - ts2.x, z.get_center().y - ts2.y * 0.5),
			Vector2(z.get_center().x - ts2.x * 0.5, z.position.y - gap - ts2.y), Vector2(z.get_center().x - ts2.x * 0.5, z.end.y + gap)]
		# LEAD r304: names stay inside the drawn plan. A spot that leaves it is tried shifted wholly inside instead
		# (the margin is no longer used); a name with no clear spot inside is left out.
		var lim: Vector2 = (frame.end - ts2).max(frame.position)
		for k: int in range(spots.size()):
			if not frame.encloses(Rect2(spots[k], ts2)):
				spots[k] = spots[k].clamp(frame.position, lim)
		var best: Rect2 = Rect2()
		var best_cost: float = INF
		for sp: Vector2 in spots:
			var rr: Rect2 = Rect2(sp, ts2)
			if not view.encloses(rr) or not frame.encloses(rr):
				continue
			var cost: float = 0.0
			for p2: Rect2 in placed + hard:
				if p2.intersects(rr):
					cost += 1e6
			if frame.intersects(rr) and not frame.encloses(rr):
				cost += FRAME_STRADDLE_COST
			for e: Rect2 in edges:
				if e.intersects(rr):
					cost += 1.0 + e.intersection(rr).get_area() * 0.05
			if cost < best_cost:
				best_cost = cost
				best = rr
		if best_cost >= 1e6:
			continue
		placed.append(best)
		shown[text] = true
		var to: Vector2 = Vector2(clampf(best.get_center().x, z.position.x, z.end.x), clampf(best.get_center().y, z.position.y, z.end.y))
		var from: Vector2 = Vector2(clampf(to.x, best.position.x, best.end.x), clampf(to.y, best.position.y, best.end.y))
		out.append([text, best.position + Vector2(3, 15), best, [from, to], ZONE_FONT])
	return out


## Rects of the scale bar (with its "10 m") and the north arrow _draw_scale_bar() prints: labels keep off them
## (DB quay capture: "Pontoon: by launch" sat on the scale text).
func _furniture_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if board == null or size == Vector2.ZERO:
		return out
	var s: float = float(_transform()["scale"])
	var area: Rect2 = Rect2(world_to_view(board.blueprint.bounds.position), board.blueprint.bounds.size * s)
	var font: Font = get_theme_default_font()
	var bar: float = SCALE_BAR_M * s
	var o: Vector2 = Vector2(area.end.x - bar - 12.0, area.end.y - 14.0)
	var tw: float = font.get_string_size(UiText.t(&"ui.preplan.scale", {"m": int(SCALE_BAR_M)}),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	out.append(Rect2(o + Vector2(-2, -28), Vector2(maxf(bar, tw) + 4.0, 32)))
	var n: Vector2 = Vector2(maxf(area.position.x - 30.0, 16.0), area.position.y + 30.0)
	out.append(Rect2(n + Vector2(-10, -16), Vector2(24, 54)))
	return out


func _peek_label(pid: StringName, on: bool) -> void:
	var l: Label = marker_labels.get(pid) as Label
	if l == null or not bool(l.get_meta(&"crowded", false)):
		return
	l.visible = on
	if on:
		move_child(l, -1)


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
	for z: Array in _zone_labels():
		if is_zone_yielded(z[2] as Rect2):
			continue
		if z[3] != null:  # beside a narrow zone: plate + leader
			var lead: Array = z[3] as Array
			draw_line(lead[0] as Vector2, lead[1] as Vector2, tweak.label_color, 1.0, true)
			draw_rect(z[2] as Rect2, Color(tweak.paper_color, tweak.label_plate_alpha))
		draw_string(font, z[1] as Vector2, String(z[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(z[4]), tweak.label_color)
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
	var meters: float = SCALE_BAR_M
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
