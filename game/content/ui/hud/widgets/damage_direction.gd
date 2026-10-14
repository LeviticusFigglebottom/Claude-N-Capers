## Damage direction (lead round 62, PD2): when the LOCAL player takes damage (EventBus.damage_applied,
## victim = local_net_id()), an arc on a ring around the crosshair points to where it came from and fades
## over FADE_S. The arc keeps its WORLD direction while you turn (re-projected through the camera every
## frame). Armor-only hits are paper white, health hits red (PD2 reads the same way). The source is
## -info.direction (the shot's travel direction); without one, nothing shows. Owner: ENV B.
class_name DamageDirection
extends HudWidget

const FADE_S: float = 1.4
const RADIUS: float = 170.0
const SPAN_DEG: float = 46.0
const WIDTH: float = 7.0
const MAX_ARCS: int = 6

## Live arcs: [{dir: Vector3 (world, toward the source), left: float, health: bool}] (tests).
var arcs: Array[Dictionary] = []


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func _enter_tree() -> void:
	if not EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.connect(_on_damage)


func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.disconnect(_on_damage)


func _on_damage(victim_net_id: int, _attacker_net_id: int, info: Dictionary) -> void:
	var me: int = local_net_id()
	if me == 0 or victim_net_id != me or float(info.get("amount", 0.0)) <= 0.0:
		return
	var travel: Vector3 = info.get("direction", Vector3.ZERO) as Vector3
	if travel.length_squared() < 0.0001:
		return
	add_arc(-travel.normalized(), float(info.get("health_damage", info.get("amount", 0.0))) > 0.0)


func add_arc(world_dir: Vector3, health: bool) -> void:
	arcs.append({"dir": world_dir, "left": FADE_S, "health": health})
	if arcs.size() > MAX_ARCS:
		arcs.pop_front()
	set_process(true)
	queue_redraw()


## Screen angle (radians, 0 = up / in front, clockwise) of world direction `dir` for camera `cam`.
static func screen_angle(cam_basis: Basis, dir: Vector3) -> float:
	var local: Vector3 = cam_basis.inverse() * dir
	return atan2(local.x, -local.z)


func _process(delta: float) -> void:
	for a: Dictionary in arcs:
		a["left"] = float(a["left"]) - delta
	arcs = arcs.filter(func(a: Dictionary) -> bool: return float(a["left"]) > 0.0)
	if arcs.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var c: Vector2 = size * 0.5
	var half: float = deg_to_rad(SPAN_DEG) * 0.5
	for a: Dictionary in arcs:
		var ang: float = screen_angle(cam.global_transform.basis, a["dir"] as Vector3) - PI * 0.5
		var col: Color = tweak.low_health_color if bool(a["health"]) else tweak.armor_color  # palette roles
		col.a = clampf(float(a["left"]) / FADE_S, 0.0, 1.0) * 0.9
		draw_arc(c, RADIUS, ang - half, ang + half, 24, Color(0, 0, 0, col.a * 0.6), WIDTH + 3.0, true)
		draw_arc(c, RADIUS, ang - half, ang + half, 24, col, WIDTH, true)
