## HUD equipment glyph (lead queue d): a small line drawing in paper with a dark outline (frameless HUD,
## readable on any scene), drawn in code (no image assets). `kind` comes from kind_for(item id):
## doctor_bag, ammo_bag, armor_bag, body_bag_case, grenade, concussion, incendiary, knife, vial,
## cable_tie, body_bag, hostage, pocket_ecm (D-161), ecm, fak, sentry, trip_mine, smoke_bomb, gas_dispenser, leech_ampule
## (KINDS). Unknown kinds draw a dot; test_equipment_glyphs keeps every catalogue deployable / throwable off it.
## Owner: ENV B.
class_name EquipmentIcon
extends Control

const OUTLINE: Color = Color(0, 0, 0, 0.8)
## Every kind _glyph draws (anything else is the fallback dot).
const KINDS: Array[StringName] = [&"doctor_bag", &"ammo_bag", &"armor_bag", &"body_bag_case", &"grenade",
	&"concussion", &"incendiary", &"knife", &"vial", &"cable_tie", &"body_bag", &"hostage", &"pocket_ecm", &"ecm",
	&"fak", &"sentry", &"trip_mine", &"smoke_bomb", &"gas_dispenser",
	&"leech_ampule"]

var kind: StringName = &""
var color: Color = UiTokens.PAPER


func _init(k: StringName = &"", px: float = 32.0) -> void:
	kind = k
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Glyph kind for a deployable / throwable id ("deployable.doctor_bag" -> &"doctor_bag").
static func kind_for(item_id: StringName) -> StringName:
	var tail: String = String(item_id).get_slice(".", 1)
	match tail:
		"doctor_bag", "ammo_bag", "armor_bag", "body_bag_case", "concussion", "incendiary":
			return StringName(tail)
		"frag":
			return &"grenade"
		"throwing_knife":
			return &"knife"
		"boss_injector", "steady_flask":
			return &"vial"
	return StringName(tail)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var u: float = s * 0.5
	var w: float = maxf(1.5, s * 0.08)
	for pass_i: int in range(2):  # outline first, then the glyph
		var col: Color = OUTLINE if pass_i == 0 else color
		var lw: float = w + 2.5 if pass_i == 0 else w
		_glyph(c, u, lw, col)


func _glyph(c: Vector2, u: float, w: float, col: Color) -> void:
	match kind:
		&"doctor_bag", &"ammo_bag", &"armor_bag", &"body_bag_case":
			var r: Rect2 = Rect2(c + Vector2(-0.8, -0.45) * u, Vector2(1.6, 1.15) * u)
			draw_rect(r, col, false, w)
			draw_arc(c + Vector2(0, -0.45) * u, 0.3 * u, PI, TAU, 8, col, w)  # handle
			match kind:
				&"doctor_bag":
					draw_line(c + Vector2(-0.3, 0.12) * u, c + Vector2(0.3, 0.12) * u, col, w)
					draw_line(c + Vector2(0, -0.18) * u, c + Vector2(0, 0.42) * u, col, w)
				&"ammo_bag":
					for x: float in [-0.35, 0.0, 0.35]:
						draw_line(c + Vector2(x, -0.12) * u, c + Vector2(x, 0.45) * u, col, w)
				&"armor_bag":
					draw_polyline(PackedVector2Array([c + Vector2(-0.35, -0.12) * u, c + Vector2(0.35, -0.12) * u,
							c + Vector2(0.3, 0.25) * u, c + Vector2(0, 0.45) * u, c + Vector2(-0.3, 0.25) * u,
							c + Vector2(-0.35, -0.12) * u]), col, w)
				&"body_bag_case":
					draw_line(c + Vector2(-0.45, 0.15) * u, c + Vector2(0.45, 0.15) * u, col, w)
		&"grenade", &"concussion", &"incendiary":
			draw_arc(c + Vector2(0, 0.15) * u, 0.55 * u, 0.0, TAU, 20, col, w)
			draw_line(c + Vector2(-0.2, -0.45) * u, c + Vector2(0.25, -0.45) * u, col, w)  # fuse cap
			draw_arc(c + Vector2(0.35, -0.55) * u, 0.18 * u, -PI * 0.5, PI * 0.5, 6, col, w)  # pin ring
			if kind == &"concussion":
				draw_arc(c + Vector2(0, 0.15) * u, 0.25 * u, 0.0, TAU, 14, col, w)
			elif kind == &"incendiary":
				draw_polyline(PackedVector2Array([c + Vector2(-0.15, 0.4) * u, c + Vector2(0, 0.0) * u,
						c + Vector2(0.15, 0.4) * u]), col, w)
		&"knife":
			draw_line(c + Vector2(-0.75, 0.75) * u, c + Vector2(-0.25, 0.25) * u, col, w * 1.6)  # grip
			draw_polyline(PackedVector2Array([c + Vector2(-0.3, 0.2) * u, c + Vector2(0.75, -0.75) * u,
					c + Vector2(-0.1, 0.35) * u]), col, w)
		&"vial":
			draw_rect(Rect2(c + Vector2(-0.28, -0.35) * u, Vector2(0.56, 1.1) * u), col, false, w)
			draw_line(c + Vector2(-0.4, -0.55) * u, c + Vector2(0.4, -0.55) * u, col, w)
			draw_line(c + Vector2(-0.28, 0.2) * u, c + Vector2(0.28, 0.2) * u, col, w)
		&"cable_tie":
			draw_arc(c + Vector2(0, -0.1) * u, 0.5 * u, PI * 0.6, PI * 2.4, 18, col, w)
			draw_rect(Rect2(c + Vector2(-0.2, 0.3) * u, Vector2(0.4, 0.3) * u), col, false, w)  # lock head
			draw_line(c + Vector2(0, 0.6) * u, c + Vector2(0, 0.85) * u, col, w)  # tail
		&"hostage":  # a kneeling figure with tied wrists
			draw_arc(c + Vector2(0, -0.55) * u, 0.22 * u, 0.0, TAU, 14, col, w)
			draw_polyline(PackedVector2Array([c + Vector2(-0.35, 0.75) * u, c + Vector2(-0.3, -0.2) * u,
					c + Vector2(0.3, -0.2) * u, c + Vector2(0.35, 0.75) * u]), col, w)
			draw_line(c + Vector2(-0.2, 0.15) * u, c + Vector2(0.2, 0.45) * u, col, w)
			draw_line(c + Vector2(0.2, 0.15) * u, c + Vector2(-0.2, 0.45) * u, col, w)
		&"pocket_ecm":  # a hand-held jammer: a case with a light bar and two stub antennae
			draw_rect(Rect2(c + Vector2(-0.4, -0.35) * u, Vector2(0.8, 1.15) * u), col, false, w)
			draw_line(c + Vector2(-0.22, 0.0) * u, c + Vector2(0.22, 0.0) * u, col, w)
			draw_line(c + Vector2(-0.22, -0.35) * u, c + Vector2(-0.3, -0.8) * u, col, w)
			draw_line(c + Vector2(0.22, -0.35) * u, c + Vector2(0.3, -0.8) * u, col, w)
		&"ecm":  # the placed jammer: a wide box, a mast and two signal arcs
			draw_rect(Rect2(c + Vector2(-0.75, 0.0) * u, Vector2(1.5, 0.7) * u), col, false, w)
			draw_line(c + Vector2(0, 0.0) * u, c + Vector2(0, -0.45) * u, col, w)
			draw_arc(c + Vector2(0, -0.45) * u, 0.3 * u, PI * 1.15, PI * 1.85, 8, col, w)
			draw_arc(c + Vector2(0, -0.45) * u, 0.6 * u, PI * 1.15, PI * 1.85, 10, col, w)
		&"fak":  # a small first aid case: a square with a cross, no handle
			draw_rect(Rect2(c + Vector2(-0.6, -0.6) * u, Vector2(1.2, 1.2) * u), col, false, w)
			draw_line(c + Vector2(-0.3, 0) * u, c + Vector2(0.3, 0) * u, col, w * 1.3)
			draw_line(c + Vector2(0, -0.3) * u, c + Vector2(0, 0.3) * u, col, w * 1.3)
		&"sentry":  # a gun body with a barrel on a tripod
			draw_rect(Rect2(c + Vector2(-0.45, -0.55) * u, Vector2(0.8, 0.45) * u), col, false, w)
			draw_line(c + Vector2(0.35, -0.35) * u, c + Vector2(0.85, -0.35) * u, col, w)
			draw_line(c + Vector2(0, -0.1) * u, c + Vector2(0, 0.3) * u, col, w)
			for x: float in [-0.6, 0.0, 0.6]:
				draw_line(c + Vector2(0, 0.3) * u, c + Vector2(x, 0.8) * u, col, w)
		&"trip_mine":  # a small charge with its laser line
			draw_rect(Rect2(c + Vector2(-0.8, -0.3) * u, Vector2(0.6, 0.6) * u), col, false, w)
			for i: int in range(3):
				var x0: float = -0.05 + 0.3 * i
				draw_line(c + Vector2(x0, 0) * u, c + Vector2(x0 + 0.18, 0) * u, col, w)
		&"smoke_bomb":  # a canister with a pin ring and two smoke puffs
			draw_rect(Rect2(c + Vector2(-0.3, -0.2) * u, Vector2(0.6, 1.0) * u), col, false, w)
			draw_arc(c + Vector2(0.2, -0.35) * u, 0.15 * u, 0.0, TAU, 10, col, w)
			draw_arc(c + Vector2(-0.35, -0.55) * u, 0.25 * u, PI * 0.9, PI * 2.1, 10, col, w)
			draw_arc(c + Vector2(0.45, -0.7) * u, 0.2 * u, PI * 0.9, PI * 2.1, 10, col, w)
		&"gas_dispenser":  # an inhaler: an L-shaped body with a mouthpiece and a cartridge
			draw_rect(Rect2(c + Vector2(-0.2, -0.8) * u, Vector2(0.4, 1.0) * u), col, false, w)
			draw_rect(Rect2(c + Vector2(-0.2, 0.2) * u, Vector2(0.85, 0.45) * u), col, false, w)
			draw_line(c + Vector2(0.65, 0.3) * u, c + Vector2(0.85, 0.3) * u, col, w)
			draw_line(c + Vector2(0.65, 0.55) * u, c + Vector2(0.85, 0.55) * u, col, w)
		&"leech_ampule":  # an auto-injector: a slim tube, a cap and a needle
			draw_rect(Rect2(c + Vector2(-0.18, -0.55) * u, Vector2(0.36, 0.9) * u), col, false, w)
			draw_rect(Rect2(c + Vector2(-0.25, -0.8) * u, Vector2(0.5, 0.25) * u), col, false, w)
			draw_line(c + Vector2(0, 0.35) * u, c + Vector2(0, 0.85) * u, col, w * 0.7)
			draw_line(c + Vector2(-0.18, -0.1) * u, c + Vector2(0.18, -0.1) * u, col, w)
		&"body_bag":
			draw_rect(Rect2(c + Vector2(-0.4, -0.8) * u, Vector2(0.8, 1.6) * u), col, false, w)
			draw_line(c + Vector2(0, -0.7) * u, c + Vector2(0, 0.7) * u, col, w * 0.7)  # zip
		_:
			draw_circle(c, u * 0.18, col)
