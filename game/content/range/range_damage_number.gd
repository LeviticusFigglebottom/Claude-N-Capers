## Floating damage number for the firing range (B1-05). Owner: ENV B.
## A billboard Label3D that rises and fades, then frees itself. Headshots are larger and gold,
## killing hits red (colors and sizes in RangeTweak).
class_name RangeDamageNumber
extends Label3D

var _life: float = 0.0
var _lifetime: float = 1.0
var _rise: float = 0.5
var _start: Vector3 = Vector3.ZERO


## Configure before adding to the tree; `world_pos` is the hit position.
func setup(amount: float, zone: int, killed: bool, world_pos: Vector3, tweak: RangeTweak) -> void:
	var head: bool = zone == Enums.HitZone.HEAD or zone == Enums.HitZone.WEAKPOINT
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var key: StringName = &"ui.range.damage_head" if head else &"ui.range.damage_body"
	text = UiText.t(key, {"value": format_amount(amount)})
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = tweak.number_pixel_size
	font_size = tweak.number_head_font_size if head else tweak.number_font_size
	outline_size = 12
	if killed:
		modulate = tweak.number_kill_color
	elif head:
		modulate = tweak.number_head_color
	else:
		modulate = tweak.number_body_color
	_lifetime = maxf(tweak.number_lifetime_s, 0.05)
	_rise = tweak.number_rise_m
	_start = world_pos
	position = world_pos


func _process(delta: float) -> void:
	_life += delta
	var t: float = clampf(_life / _lifetime, 0.0, 1.0)
	position = _start + Vector3.UP * _rise * t
	modulate.a = 1.0 - t * t
	outline_modulate.a = modulate.a
	if _life >= _lifetime:
		queue_free()


## 35.0 -> "35", 17.5 -> "17.5".
static func format_amount(amount: float) -> String:
	var r: float = snappedf(amount, 0.1)
	if is_equal_approx(r, roundf(r)):
		return str(roundi(r))
	return "%.1f" % r
