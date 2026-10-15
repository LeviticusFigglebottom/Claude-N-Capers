## PO6-17 police helicopter (PD2 heli drop / heli sniper). Owner: ENV A. Replicated dynamic entity (nose -Z,
## ENV C prop_police_helicopter: Rotor spins about Y, TailRotor about X, RopeL/RopeR rope anchors, SniperSeat).
## Server flight: APPROACH (from approach_m out, at orbit height, cue.assault_heli_arrive = rotor loop start) ->
## ORBIT (around the orbit centre, left door toward the centre, orbit_s) -> [drop] TO_DROP (to hover_height_m
## over the drop point) -> HOVER (ropes out; the runner rappels the squad down the ropes; leaves once every unit
## is down or dead) -> [sniper] SNIPER (orbit again with a Longshot at the open left door for sniper_s; the
## runner keeps him and a moving SNIPER_PERCH on the seat) -> LEAVE (flies off, cue.assault_heli_leave = rotor
## stop fact) -> freed. Speed speed_mps, heading follows the velocity with a little bank.
class_name AssaultHeli
extends AssaultEventEntity

## Server: HOVER reached (the runner starts the rappel squad); SNIPER started / ended.
signal hover_reached(heli: AssaultHeli)
signal sniper_window(heli: AssaultHeli, on: bool)

enum Stage { APPROACH, ORBIT, TO_DROP, HOVER, SNIPER, LEAVE, GONE }

const ROTOR_RPS: float = 6.0
const TAIL_RPS: float = 24.0
## ENV D PO6-17 clips for the door sniper (AnimDriver.FALLBACK_CLIPS -> aim_rifle until they land).
const CLIP_DOOR_IDLE: StringName = &"heli_door_idle"
const CLIP_DOOR_AIM: StringName = &"heli_door_aim"


var model: Node3D = null
var rotor: Node3D = null
var tail_rotor: Node3D = null
var rope_l: Node3D = null
var rope_r: Node3D = null
var seat: Node3D = null
var ropes: Array[MeshInstance3D] = []
## Server: orbit centre / radius / height, hover point, flags.
var orbit_center: Vector3 = Vector3.ZERO
var orbit_radius: float = 24.0
var hover_point: Vector3 = Vector3.INF
var drop_floor_y: float = 0.0
var do_drop: bool = false
var do_sniper: bool = false
## Server: the runner says the drop is done (every unit down or dead).
var drop_done: bool = false
## Ropes: each drawn as ONE straight vertical line (top_level, world space) from its RopeL / RopeR anchor down to
## rope_floor_y, only while rope_on[i] (the runner: a unit still has to come down it; ENV D: retract on touch).
var rope_floor_y: float = 0.0
var rope_on: Array[bool] = [false, false]
## Server: the seated sniper and his moving SNIPER_PERCH (the runner sets / clears them); pinned to the seat
## every physics frame after his motor ran (process_physics_priority).
var passenger: NpcBase = null
var passenger_perch: Node3D = null
var _angle: float = 0.0
var _leave_to: Vector3 = Vector3.ZERO
var _vel: Vector3 = Vector3.ZERO


func _build() -> void:
	model = AssaultEventEntity.prop(String(params.get("heli_scene", AssaultEventsTweak.data().heli_scene)))
	if model == null:
		model = _placeholder()
	model.name = "Prop"
	add_child(model)
	rotor = AssaultEventEntity.find_named(model, "Rotor")
	tail_rotor = AssaultEventEntity.find_named(model, "TailRotor")
	rope_l = AssaultEventEntity.find_named(model, "RopeL")
	rope_r = AssaultEventEntity.find_named(model, "RopeR")
	seat = AssaultEventEntity.find_named(model, "SniperSeat")
	for anchor: Node3D in [rope_l, rope_r]:
		if anchor == null:
			continue
		var rope: MeshInstance3D = AssaultEventEntity.cylinder("Rope%d" % ropes.size(), 0.02, 1.0, Color(0.1, 0.09, 0.08))
		rope.visible = false
		rope.top_level = true
		add_child(rope)
		ropes.append(rope)
	process_physics_priority = 10  # after NpcMotor: the seated sniper is pinned after his motor ran


## Same node names / frame as C's prop_police_helicopter (nose -Z).
static func _placeholder() -> Node3D:
	var root: Node3D = Node3D.new()
	var m: Node3D = Node3D.new()
	m.name = "Model"
	root.add_child(m)
	var b: Node3D = AssaultEventEntity.marker("Body", Vector3.ZERO)
	m.add_child(b)
	var navy: Color = Color(0.12, 0.16, 0.27)
	b.add_child(AssaultEventEntity.box("Cabin", Vector3(1.9, 1.7, 3.6), navy, Vector3(0, 1.25, -0.3)))
	b.add_child(AssaultEventEntity.box("Nose", Vector3(1.6, 1.1, 1.2), Color(0.84, 0.89, 0.29), Vector3(0, 1.05, -2.6)))
	b.add_child(AssaultEventEntity.box("Boom", Vector3(0.35, 0.4, 5.0), navy, Vector3(0, 1.7, 3.8)))
	b.add_child(AssaultEventEntity.box("Fin", Vector3(0.1, 1.2, 0.8), navy, Vector3(0, 2.2, 6.2)))
	for x: float in [-0.8, 0.8]:
		b.add_child(AssaultEventEntity.box("Skid", Vector3(0.1, 0.1, 3.4), Color(0.1, 0.1, 0.1), Vector3(x, 0.05, -0.3)))
	var r: Node3D = AssaultEventEntity.marker("Rotor", Vector3(0, 2.65, -0.3))
	m.add_child(r)
	for i: int in range(2):
		var blade: MeshInstance3D = AssaultEventEntity.box("RotorBlades", Vector3(9.0, 0.04, 0.3), Color(0.08, 0.08, 0.08))
		blade.rotation.y = PI * 0.5 * i
		r.add_child(blade)
	var tr: Node3D = AssaultEventEntity.marker("TailRotor", Vector3(0.11, 2.25, 6.45))
	m.add_child(tr)
	tr.add_child(AssaultEventEntity.box("TailRotorBlades", Vector3(0.04, 1.4, 0.12), Color(0.08, 0.08, 0.08)))
	m.add_child(AssaultEventEntity.marker("RopeL", Vector3(-1.1, 1.93, -0.3)))
	m.add_child(AssaultEventEntity.marker("RopeR", Vector3(1.1, 1.93, -0.3)))
	var s: Node3D = AssaultEventEntity.marker("SniperSeat", Vector3(-0.53, 1.08, 0.12))
	s.rotation.y = PI * 0.5
	m.add_child(s)
	var sl: Node3D = AssaultEventEntity.marker("Spotlight", Vector3(0, 0.36, -2.49))
	m.add_child(sl)
	var light: SpotLight3D = SpotLight3D.new()
	light.spot_range = 45.0
	light.spot_angle = 14.0
	light.light_energy = 6.0
	light.rotation.x = deg_to_rad(-30.0)
	sl.add_child(light)
	return root


## Rope anchors (world), left first.
func rope_anchors() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a: Node3D in [rope_l, rope_r]:
		if a != null and a.is_inside_tree():
			out.append(a.global_position)
	if out.is_empty():
		out.append(global_position + Vector3(0, 1.9, 0))
	return out


func seat_transform() -> Transform3D:
	if seat != null and seat.is_inside_tree():
		return seat.global_transform
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.53, 1.08, 0.12))


func _process(delta: float) -> void:
	_update_ropes()
	if rotor != null:
		rotor.rotate_y(TAU * ROTOR_RPS * delta)
	if tail_rotor != null:
		tail_rotor.rotate_x(TAU * TAIL_RPS * delta)


func _apply_stage(s: int) -> void:
	if s != Stage.HOVER:
		rope_on = [false, false] as Array[bool]
	_update_ropes()


## Server (runner): show / retract rope `i` (0 = RopeL, 1 = RopeR).
func set_rope_shown(i: int, on: bool) -> void:
	if i >= 0 and i < rope_on.size():
		rope_on[i] = on
	_update_ropes()


func _update_ropes() -> void:
	var anchors: Array[Node3D] = []
	for a: Node3D in [rope_l, rope_r]:
		if a != null:
			anchors.append(a)
	for i: int in range(ropes.size()):
		var rope: MeshInstance3D = ropes[i]
		var on: bool = stage == Stage.HOVER and i < rope_on.size() and rope_on[i] and i < anchors.size() \
			and anchors[i].is_inside_tree()
		var top: Vector3 = anchors[i].global_position if on else Vector3.ZERO
		var length: float = top.y - rope_floor_y
		rope.visible = on and length > 0.2
		if rope.visible:
			(rope.mesh as CylinderMesh).height = length
			rope.transform = Transform3D(Basis.IDENTITY, Vector3(top.x, (top.y + rope_floor_y) * 0.5, top.z))


# --- Server -------------------------------------------------------------------------------------

func start(center: Vector3, radius: float, p_hover: Vector3, floor_y: float, drop: bool, sniper: bool) -> void:
	orbit_center = center
	orbit_radius = maxf(radius, 6.0)
	hover_point = p_hover
	drop_floor_y = floor_y
	do_drop = drop and p_hover != Vector3.INF
	do_sniper = sniper
	var rng: RandomNumberGenerator = GameRng.stream(&"assault_events")
	var a: float = rng.randf() * TAU
	var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
	global_position = center + dir * p_float("approach_m", 110.0)
	_leave_to = center - dir * p_float("approach_m", 110.0)
	_angle = a  # rotor loop / cue.assault_heli_arrive / _leave: C's CuePlayer on assault_event_started / _ended


func _physics_process(delta: float) -> void:
	if not is_server() or not is_inside_tree():
		return
	stage_time += delta
	_step(delta)
	_pin_passenger()


func _pin_passenger() -> void:
	if not is_inside_tree():
		return
	var xf: Transform3D = seat_transform()
	if passenger_perch != null and is_instance_valid(passenger_perch):
		passenger_perch.global_position = xf.origin
	if passenger != null and is_instance_valid(passenger) and passenger.alive:
		# ENV D heli_door_sill: kneel root = SniperSeat x heli_kneel_offset (seat basis), facing out of the door.
		passenger.global_transform = Transform3D(xf.basis.orthonormalized(), xf * AssaultEventsTweak.data().heli_kneel_offset)
		passenger.velocity = Vector3.ZERO
		var lb: LongshotBrain = passenger.get_node_or_null(^"Brain") as LongshotBrain
		var clip: StringName = CLIP_DOOR_AIM if lb != null and lb.laser_active else CLIP_DOOR_IDLE
		if passenger.get_meta(AnimDriver.META_ANIM_OVERRIDE, &"") != clip:
			passenger.set_meta(AnimDriver.META_ANIM_OVERRIDE, clip)


func _step(delta: float) -> void:
	var speed: float = p_float("speed_mps", 20.0)
	match stage:
		Stage.APPROACH:
			if _fly_to(_orbit_point(_angle), speed, delta):
				set_stage(Stage.ORBIT)
		Stage.ORBIT:
			_orbit(speed, delta)
			if stage_time >= p_float("orbit_s", 10.0):
				set_stage(Stage.TO_DROP if do_drop else (Stage.SNIPER if do_sniper else Stage.LEAVE))
				if stage == Stage.SNIPER:
					sniper_window.emit(self, true)
		Stage.TO_DROP:
			if _fly_to(hover_point, speed * 0.6, delta):
				rope_floor_y = drop_floor_y
				set_stage(Stage.HOVER)
				hover_reached.emit(self)
		Stage.HOVER:
			_hold(hover_point, delta)
			if drop_done or stage_time > 60.0:
				set_stage(Stage.SNIPER if do_sniper else Stage.LEAVE)
				if stage == Stage.SNIPER:
					_angle = atan2(global_position.z - orbit_center.z, global_position.x - orbit_center.x)
					sniper_window.emit(self, true)
		Stage.SNIPER:
			_orbit(speed * 0.5, delta)
			if stage_time >= p_float("sniper_s", 35.0):
				sniper_window.emit(self, false)
				set_stage(Stage.LEAVE)
		Stage.LEAVE:
			if _fly_to(_leave_to + Vector3(0, 15.0, 0), speed * 1.2, delta):
				set_stage(Stage.GONE)
				end_event()
				queue_free()


## Fly toward `p`; true when there.
func _fly_to(p: Vector3, speed: float, delta: float) -> bool:
	var d: Vector3 = p - global_position
	if d.length() <= maxf(speed * delta, 0.3):
		global_position = p
		return true
	var want: Vector3 = d.normalized() * speed
	_vel = _vel.lerp(want, clampf(delta * 1.5, 0.0, 1.0))
	if _vel.length() < 1.0:
		_vel = want * 0.3
	global_position += _vel * delta
	_face(_vel, delta)
	return false


func _hold(p: Vector3, delta: float) -> void:
	global_position = global_position.lerp(p, clampf(delta * 2.0, 0.0, 1.0))
	_vel = Vector3.ZERO


## Orbit with the left door (-X) toward the centre: angle decreases (see the class doc).
func _orbit(speed: float, delta: float) -> void:
	_angle -= speed / orbit_radius * delta
	var target: Vector3 = _orbit_point(_angle)
	var tangent: Vector3 = Vector3(sin(_angle), 0.0, -cos(_angle))
	global_position = global_position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
	_face(tangent, delta, 0.18)


func _orbit_point(a: float) -> Vector3:
	return orbit_center + Vector3(cos(a), 0.0, sin(a)) * orbit_radius


func _face(dir: Vector3, delta: float, bank: float = 0.0) -> void:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	var b: Basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	b = b * Basis(Vector3.BACK, bank) * Basis(Vector3.RIGHT, -0.08)
	global_basis = global_basis.slerp(b.orthonormalized(), clampf(delta * 2.5, 0.0, 1.0)).orthonormalized()


func _net_state() -> Dictionary:
	return {"stage": stage, "fy": snappedf(rope_floor_y, 0.01), "ro": (1 if rope_on[0] else 0) | (2 if rope_on[1] else 0)}


func _apply_net_state(d: Dictionary) -> void:
	if d.has("fy"):
		rope_floor_y = float(d["fy"])
	if d.has("ro"):
		rope_on = [(int(d["ro"]) & 1) != 0, (int(d["ro"]) & 2) != 0] as Array[bool]
	super._apply_net_state(d)
	_update_ropes()
