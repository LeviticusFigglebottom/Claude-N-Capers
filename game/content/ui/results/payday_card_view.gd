## One PAYDAY card (pd2_fidelity P9), drawn in code (no art assets). Owner: ENV B.
## A Button so mouse, keyboard and gamepad (ui_accept) pick it. Face down until reveal(card, picked):
## then the face shows the type band, a drawn type icon, the reward text and the quality tier.
class_name PaydayCardView
extends Button

const CARD_SIZE: Vector2 = Vector2(300, 460)
const CORNER: float = 14.0
const BACK_COLOR: Color = Color(0.125, 0.11, 0.096, 1)
const BACK_LINE: Color = Color(0.788, 0.635, 0.153, 1)
const FACE_COLOR: Color = Color(0.89, 0.86, 0.8, 1)
const INK: Color = Color(0.11, 0.094, 0.078, 1)
const FOCUS_COLOR: Color = Color(0.31, 0.82, 0.91, 1)
const BAND_H: float = 64.0
## Height kept free under the type label for the drawn icon (centre ICON_Y from the card top).
const ICON_ZONE_H: float = 170.0
const ICON_Y: float = 142.0
const ICON_SCALE: float = 0.82

var index: int = 0
var card: Dictionary = {}
var face_up: bool = false
var picked: bool = false
var type_label: Label
var reward_label: Label
var detail_label: Label
var tier_label: Label
var _table: PaydayCardsTable


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	flat = true
	for s: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 14
	box.offset_bottom = -16
	add_child(box)
	type_label = _label(box, &"SubheaderLabel", Color(0.97, 0.96, 0.92))
	box.add_child(_gap(ICON_ZONE_H))  # the drawn icon sits here
	reward_label = _label(box, &"SubheaderLabel", INK)
	detail_label = _label(box, &"", Color(0.25, 0.26, 0.3))
	tier_label = _label(box, &"", INK)
	var filler: Control = _gap(0)
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	box.add_child(_gap(36))  # keeps text above the tier stripe
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_set_texts_visible(false)


func setup(card_index: int, t: PaydayCardsTable) -> void:
	index = card_index
	_table = t
	queue_redraw()


## Turn the card face up showing `c` (PaydayCards card dict). `is_picked` marks the player's card.
func reveal(c: Dictionary, is_picked: bool) -> void:
	card = c
	face_up = true
	picked = is_picked
	type_label.text = UiText.t(StringName("ui.payday_cards.type.%s" % String(c.get("type", ""))))
	reward_label.text = reward_text(c)
	detail_label.text = detail_text(c)
	tier_label.text = UiText.t(StringName("ui.payday_cards.tier.%d" % int(c.get("tier", 0))))
	_set_texts_visible(true)
	modulate = Color(1, 1, 1, 1) if is_picked else Color(0.72, 0.72, 0.74, 1)
	queue_redraw()


## Main reward line: an amount for cash/XP, the item name for items.
static func reward_text(c: Dictionary) -> String:
	var type: StringName = StringName(c.get("type", &""))
	if type == PaydayCards.CASH:
		return UiText.money(int(c.get("amount", 0)))
	if type == PaydayCards.XP:
		return UiText.t(&"ui.payday_cards.xp_amount", {"amount": UiText.group_digits(int(c.get("amount", 0)))})
	return UiText.t(UiText.item_key(StringName(c.get("item_id", &""))))


## Secondary line: which weapon a mod fits, which part of a mask a part is.
static func detail_text(c: Dictionary) -> String:
	var type: StringName = StringName(c.get("type", &""))
	var item: StringName = StringName(c.get("item_id", &""))
	if type == PaydayCards.WEAPON_MOD:
		var w: StringName = PaydayCards.weapon_for_mod(item)
		return UiText.t(&"ui.payday_cards.mod_for", {"weapon": UiText.t(UiText.item_key(w))}) if w != &"" else ""
	if type == PaydayCards.MASK_PART:
		var kind: String = "preset" if MaskCatalog.is_preset_id(item) else MaskCatalog.kind_of(item)
		return UiText.t(StringName("ui.payday_cards.mask_kind.%s" % kind))
	if type == PaydayCards.CASH:
		return UiText.t(&"ui.payday_cards.cash_detail")
	return UiText.t(&"ui.payday_cards.xp_detail")


func _draw() -> void:
	var lift: float = -8.0 if (has_focus() or is_hovered()) and not face_up else 0.0
	var r: Rect2 = Rect2(Vector2(0, lift), size)
	_draw_shadow(r)
	if face_up:
		_draw_face(r)
	else:
		_draw_back(r)
	if has_focus() or picked:
		_rounded(r.grow(4.0), FOCUS_COLOR, false, 4.0 if picked else 3.0)


func _draw_shadow(r: Rect2) -> void:
	_rounded(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.45), true)


func _draw_back(r: Rect2) -> void:
	_rounded(r, BACK_COLOR, true)
	var inner: Rect2 = r.grow(-14.0)
	_rounded(inner, BACK_LINE.darkened(0.55), false, 2.0)
	# Diagonal guilloche lattice inside the inner frame.
	var step: float = 22.0
	var lattice: Color = Color(BACK_LINE.r, BACK_LINE.g, BACK_LINE.b, 0.12)
	var d: float = -inner.size.y
	while d < inner.size.x:
		_clipped_line(inner, inner.position + Vector2(d, 0), Vector2(1, 1), lattice)
		_clipped_line(inner, inner.position + Vector2(d + inner.size.y, 0), Vector2(-1, 1), lattice)
		d += step
	# Emblem: nested diamonds around a ring.
	var c: Vector2 = r.get_center()
	for k: int in range(3):
		var s: float = 74.0 - k * 20.0
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(s, 0),
				c + Vector2(0, s * 1.3), c + Vector2(-s, 0), c + Vector2(0, -s * 1.3)])
		draw_polyline(pts, BACK_LINE if k != 1 else BACK_LINE.darkened(0.3), 3.0 - k * 0.5, true)
	draw_arc(c, 14.0, 0.0, TAU, 32, BACK_LINE, 3.0, true)
	draw_circle(c, 5.0, BACK_LINE)
	_rounded(inner.grow(-6.0), BACK_LINE.darkened(0.7), false, 1.0)


func _draw_face(r: Rect2) -> void:
	var type: StringName = StringName(card.get("type", &""))
	var band_color: Color = Color(0.3, 0.32, 0.36)
	if _table != null and _table.type_colors.has(type):
		band_color = _table.type_colors[type] as Color
	var tier: int = int(card.get("tier", 0))
	var tier_color: Color = Color(0.62, 0.66, 0.7)
	if _table != null and tier < _table.tier_colors.size():
		tier_color = _table.tier_colors[tier]
	_rounded(r, FACE_COLOR, true)
	var band: Rect2 = Rect2(r.position, Vector2(r.size.x, BAND_H))
	_rounded(band, band_color, true)
	draw_rect(Rect2(band.position + Vector2(0, band.size.y - CORNER), Vector2(band.size.x, CORNER)), band_color)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 40), Vector2(r.size.x, 6)), tier_color)
	for i: int in range(tier + 1):
		draw_circle(r.position + Vector2(r.size.x - 26 - i * 18, r.size.y - 18), 6.0, tier_color)
	_rounded(r, tier_color.darkened(0.2), false, 3.0)
	draw_set_transform(r.position + Vector2(r.size.x * 0.5, ICON_Y), 0.0, Vector2.ONE * ICON_SCALE)
	_draw_icon(type, Vector2.ZERO, band_color)
	draw_set_transform(Vector2.ZERO)


func _draw_icon(type: StringName, c: Vector2, col: Color) -> void:
	match type:
		PaydayCards.CASH:
			for k: int in range(3):
				var o: Vector2 = Vector2(-8 + k * 8, -8 + k * 8)
				var bill: Rect2 = Rect2(c + o - Vector2(66, 34), Vector2(132, 68))
				draw_rect(bill, col.lightened(0.1 * k))
				draw_rect(bill, INK, false, 2.0)
			draw_circle(c + Vector2(8, 8), 20.0, FACE_COLOR)
			draw_arc(c + Vector2(8, 8), 20.0, 0.0, TAU, 32, INK, 2.0, true)
		PaydayCards.XP:
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in range(11):
				var a: float = -PI * 0.5 + k * PI / 5.0
				var rad: float = 70.0 if k % 2 == 0 else 30.0
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, col)
			draw_polyline(pts, INK, 2.0, true)
		PaydayCards.WEAPON_MOD:
			var gear: PackedVector2Array = PackedVector2Array()
			var teeth: int = 8
			for k: int in range(teeth * 4 + 1):
				var a: float = TAU * float(k) / float(teeth * 4)
				var rad: float = 64.0 if (k % 4) in [1, 2] else 50.0
				gear.append(c + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(gear, col)
			draw_polyline(gear, INK, 2.0, true)
			draw_circle(c, 20.0, FACE_COLOR)
			draw_arc(c, 20.0, 0.0, TAU, 32, INK, 2.0, true)
		PaydayCards.MASK_PART:
			var mask: PackedVector2Array = PackedVector2Array()
			for k: int in range(41):
				var a: float = TAU * float(k) / 40.0
				var rx: float = 56.0
				var ry: float = 72.0 if sin(a) > 0.0 else 64.0
				mask.append(c + Vector2(cos(a) * rx, sin(a) * ry))
			draw_colored_polygon(mask, col)
			draw_polyline(mask, INK, 2.0, true)
			for sx: float in [-1.0, 1.0]:
				var eye: PackedVector2Array = PackedVector2Array()
				for k: int in range(17):
					var a: float = TAU * float(k) / 16.0
					eye.append(c + Vector2(sx * 22.0, -10.0) + Vector2(cos(a) * 15.0, sin(a) * 9.0))
				draw_colored_polygon(eye, FACE_COLOR)


func _rounded(r: Rect2, color: Color, filled: bool, width: float = 2.0) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(int(CORNER))
	sb.anti_aliasing = true
	if filled:
		sb.bg_color = color
	else:
		sb.draw_center = false
		sb.border_color = color
		sb.set_border_width_all(maxi(int(width), 1))
	draw_style_box(sb, r)


## Line from `origin` along `dir` clipped to rect `r`.
func _clipped_line(r: Rect2, origin: Vector2, dir: Vector2, color: Color) -> void:
	var t0: float = 0.0
	var t1: float = r.size.x + r.size.y
	for axis: int in range(2):
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(d) < 0.0001:
			if o < lo or o > hi:
				return
			continue
		var a: float = (lo - o) / d
		var b: float = (hi - o) / d
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	if t1 > t0:
		draw_line(origin + dir * t0, origin + dir * t1, color, 1.5, true)


func _set_texts_visible(v: bool) -> void:
	for l: Label in [type_label, reward_label, detail_label, tier_label]:
		l.visible = v


func _label(parent: Control, variation: StringName, color: Color) -> Label:
	var l: Label = UiBuild.label(&"", variation)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


func _gap(h: float) -> Control:
	var g: Control = Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = Vector2(0, h)
	return g
