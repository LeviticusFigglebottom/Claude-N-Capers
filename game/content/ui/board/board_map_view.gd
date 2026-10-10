## The Board's city map (pd2_fidelity C1). Owner: ENV B. Original vector art drawn from BoardCityMap
## data (districts, water, rivers, avenues, streets, district names), letterboxed at the map's
## aspect, with one BoardPin per contract. Pins navigate spatially (ui_left/right/up/down pick the
## nearest pin in that direction); `exit_right` (the screen's Take button) is the right-hand exit.
class_name BoardMapView
extends Control

signal pin_focused(slot: int)
signal pin_pressed(slot: int)

var city: BoardCityMap = null
## slot -> BoardPin, in slot order.
var pins: Array[BoardPin] = []
var exit_right: Control = null
## Pin disc centres in px after spreading (slot order).
var pin_centers: Array[Vector2] = []
var _contracts: Array[Dictionary] = []


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_pins)


## Fitted map area inside this control (keeps BoardCityMap.aspect; centred horizontally, top-aligned).
func map_rect() -> Rect2:
	var aspect: float = city.aspect if city != null else 1.6
	var w: float = size.x
	var h: float = w / aspect
	if h > size.y:
		h = size.y
		w = h * aspect
	return Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, h))


func to_px(p: Vector2) -> Vector2:
	var r: Rect2 = map_rect()
	return r.position + p * r.size


## Show `contracts` (BoardContracts.generate() order). Pins are reused per slot, so focus survives
## a rotation.
func set_contracts(contracts: Array[Dictionary]) -> void:
	_contracts = contracts
	while pins.size() > contracts.size():
		var old: BoardPin = pins.pop_back()
		old.queue_free()
	while pins.size() < contracts.size():
		var pin: BoardPin = BoardPin.new()
		var slot: int = pins.size()
		pin.name = "Pin%d" % slot
		pin.focus_entered.connect(func() -> void: pin_focused.emit(slot))
		pin.pressed.connect(func() -> void: pin_pressed.emit(slot))
		add_child(pin)
		pins.append(pin)
	for i: int in range(contracts.size()):
		var c: Dictionary = contracts[i]
		var pin: BoardPin = pins[i]
		pin.contract = c
		var contact: ContactDef = ContactDef.find(StringName(c["contact_id"])) if StringName(c["contact_id"]) != &"" else null
		pin.accent = contact.accent_color if contact != null else Color(0.8, 0.8, 0.8, 1)
		if city != null:
			pin.highlight = city.highlight_color
			pin.pro_color = city.pro_color
		pin.tooltip_text = UiText.t(&"ui.board.pin_tooltip", {
			"heist": UiText.t(StringName("heist.%s.name" % c["heist_id"])),
			"difficulty": UiText.t(UiText.difficulty_key(int(c["difficulty"]))),
		})
		pin.queue_redraw()
	_layout_pins()


func set_selected(slot: int) -> void:
	for i: int in range(pins.size()):
		pins[i].selected = i == slot
		pins[i].queue_redraw()


## Refresh the expiry rings at Unix time `now`.
func update_times(now: float) -> void:
	for i: int in range(mini(pins.size(), _contracts.size())):
		var c: Dictionary = _contracts[i]
		var span: float = maxf(float(c["expires_at"]) - float(c["starts_at"]), 1.0)
		pins[i].time_fraction = BoardContracts.time_left(c, now) / span
		pins[i].queue_redraw()


func _layout_pins() -> void:
	var disc: float = city.pin_px if city != null else 44.0
	var r: Rect2 = map_rect()
	var n: int = mini(pins.size(), _contracts.size())
	pin_centers = []
	for i: int in range(n):
		pin_centers.append(r.position + (_contracts[i]["map_pos"] as Vector2) * r.size)
	pin_centers = spread(pin_centers, BoardPin.size_for(disc).x * 1.05, r.grow(-disc * 0.6))
	for i: int in range(n):
		var pin: BoardPin = pins[i]
		pin.size = BoardPin.size_for(disc)
		pin.custom_minimum_size = pin.size
		pin.position = pin_centers[i] - pin.disc_center()
	link_focus()
	queue_redraw()


## Push points apart until no two are closer than `min_dist` (contracts for the same heist share an
## anchor), keeping them inside `bounds`. Deterministic: fixed iteration count, slot order, and an
## index-based direction for exact overlaps.
static func spread(points: Array[Vector2], min_dist: float, bounds: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = points.duplicate()
	for _iter: int in range(48):
		var moved: bool = false
		for i: int in range(out.size()):
			for j: int in range(i + 1, out.size()):
				var delta: Vector2 = out[j] - out[i]
				var d: float = delta.length()
				if d >= min_dist:
					continue
				var dir: Vector2 = delta / d if d > 0.001 else Vector2.RIGHT.rotated(TAU * float(j) / 7.0)
				var push: Vector2 = dir * (min_dist - d) * 0.5
				out[i] -= push
				out[j] += push
				moved = true
		for i: int in range(out.size()):
			out[i] = out[i].clamp(bounds.position, bounds.end)
		if not moved:
			break
	return out


## Spatial focus neighbours between pins (nearest pin within ±60° of each direction; distance plus a
## penalty for sideways offset). Right with no pin goes to `exit_right`; other dead ends stay put.
## Tab order follows slots.
func link_focus() -> void:
	var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
	var sides: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	var n: int = pins.size()
	for i: int in range(n):
		var pin: BoardPin = pins[i]
		var from: Vector2 = pin.position + pin.disc_center()
		for k: int in range(4):
			var best: BoardPin = null
			var best_score: float = INF
			for j: int in range(n):
				if j == i:
					continue
				var delta: Vector2 = pins[j].position + pins[j].disc_center() - from
				var along: float = delta.dot(dirs[k])
				if along <= 0.5 or absf(delta.angle_to(dirs[k])) > PI / 3.0:
					continue
				var score: float = along + 2.0 * absf(delta.cross(dirs[k]))
				if score < best_score:
					best_score = score
					best = pins[j]
			var target: Control = best
			if target == null and sides[k] == SIDE_RIGHT and exit_right != null:
				target = exit_right
			pin.set_focus_neighbor(sides[k], pin.get_path_to(target if target != null else pin))
		pin.focus_next = pin.get_path_to(pins[(i + 1) % n])
		pin.focus_previous = pin.get_path_to(pins[(i - 1 + n) % n])


func _draw() -> void:
	if city == null:
		return
	var r: Rect2 = map_rect()
	var s: float = r.size.x
	draw_rect(r, city.land_color)
	for id: StringName in city.district_ids():
		var d: Dictionary = city.districts[id] as Dictionary
		var poly: PackedVector2Array = _px(d.get("polygon", PackedVector2Array()) as PackedVector2Array)
		if poly.size() < 3:
			continue
		draw_colored_polygon(poly, d.get("color", Color(0.2, 0.2, 0.2, 1)) as Color)
		poly.append(poly[0])
		draw_polyline(poly, city.district_border, 2.0, true)
	for w: PackedVector2Array in city.water:
		draw_colored_polygon(_px(w), city.water_color)
	for river: PackedVector2Array in city.rivers:
		var pts: PackedVector2Array = _px(river)
		draw_polyline(pts, city.water_color, city.river_width * s, true)
		for p: Vector2 in pts:
			draw_circle(p, city.river_width * s * 0.5, city.water_color)
	for st: PackedVector2Array in city.streets:
		draw_polyline(_px(st), city.street_color, city.street_px, true)
	for av: PackedVector2Array in city.avenues:
		draw_polyline(_px(av), city.avenue_color, city.avenue_px, true)
	var font: Font = get_theme_default_font()
	for id: StringName in city.district_ids():
		var text: String = UiText.t(StringName("ui.board.district.%s" % id)).to_upper()
		var at: Vector2 = to_px(city.district_center(id))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, city.label_font_px).x
		draw_string(font, at - Vector2(w * 0.5, -city.label_font_px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				city.label_font_px, city.label_color)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)


func _px(poly: PackedVector2Array) -> PackedVector2Array:
	var r: Rect2 = map_rect()
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in poly:
		out.append(r.position + p * r.size)
	return out
