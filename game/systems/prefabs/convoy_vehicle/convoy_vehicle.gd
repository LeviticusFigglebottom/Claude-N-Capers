## A5-02 convoy vehicle mover (Rolling Thunder QC-82; D-149.1 / D-149.8). Owner: ENV A.
## A vehicle that drives along a `Path3D` to a stop marker with braking, then stays static for good. The server
## simulates; clients follow the replicated transform (`_net_xform`, the PO6-17 assault-van path). The mission
## calls `drive(path, stop)`: the vehicle starts at the curve's start, follows it to the curve point nearest the stop
## marker, then a straight leg onto the marker (its rotation turning onto the marker's), accelerating and braking at
## `accel_mps2` / `brake_mps2` up to `speed_mps`, and ends exactly on the marker: `vehicle_stopped(net_id)` (and
## `stage` STOPPED). `park(stop)` puts it there at once (pop-in, D-149.8). Navigation round the stopped vehicle is the
## layout's pre-baked nav region (ConvoyLayouts, D-149.1): no carve, no rebake.
## Forward is +Z (the cab end; ArmoredTruck's rear doors face -Z). Children move with it: an `armored_truck` prefab
## parented to the mover is carried (QC-82: "the trucks, carrying their armored_truck").
## Visual: `Body` (the collision is fitted to it), optional `Seat0..n` markers (QC-83 seated occupants).
class_name ConvoyVehicle
extends GameplayPrefab

## Server, every peer through `stage` replication: the vehicle started driving (C: the mixer's move opens the
## Tannery gates) / reached its stop marker.
signal drive_started(id: int)
signal vehicle_stopped(id: int)

enum Stage { PARKED, DRIVING, STOPPED }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/convoy_vehicle/convoy_vehicle_placeholder.tscn")
const GROUP: StringName = &"convoy_vehicle"
## The most seat markers looked up (Seat0..Seat7).
const MAX_SEATS: int = 8

## Informational: &"car", &"truck", &"mixer", &"van" (the mission picks seats / cover by it).
@export var vehicle_kind: StringName = &"car"
@export var speed_mps: float = 9.0
@export var accel_mps2: float = 3.0
@export var brake_mps2: float = 4.0
## Collision box size (m); ZERO = fit to `Body` (GameplayPrefab "Collision fitting").
@export var collision_size_override: Vector3 = Vector3.ZERO

var stage: Stage = Stage.PARKED
## Distance driven along the route (m) and its total length (server).
var travelled_m: float = 0.0
var route_m: float = 0.0
var speed: float = 0.0

var _path: Path3D = null
var _stop: Node3D = null
var _curve_end_m: float = 0.0
var _curve_end_xf: Transform3D = Transform3D.IDENTITY


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body"])


func _collision_source_node() -> String:
	return "Body"


func _prefab_ready() -> void:
	add_to_group(GROUP)
	set_physics_process(false)


## Server: drive `path` from its start onto `stop` (a Marker3D / Node3D: the layout's spot for this vehicle).
func drive(path: Path3D, stop: Node3D) -> void:
	if not Net.is_authority() or stage == Stage.STOPPED or path == null or path.curve == null or stop == null:
		return
	_path = path
	_stop = stop
	var c: Curve3D = path.curve
	_curve_end_m = c.get_closest_offset(path.to_local(stop.global_position))
	_curve_end_xf = _curve_xform(_curve_end_m)
	route_m = _curve_end_m + _curve_end_xf.origin.distance_to(stop.global_position)
	travelled_m = 0.0
	speed = 0.0
	stage = Stage.DRIVING
	global_transform = _curve_xform(0.0)
	set_physics_process(true)
	drive_started.emit(net_id)


## Server: stand on `stop` at once and stay (pop-in, or the end of a drive).
func park(stop: Node3D) -> void:
	if not Net.is_authority() or stage == Stage.STOPPED or stop == null:
		return
	global_transform = Transform3D(stop.global_basis.orthonormalized(), stop.global_position)
	speed = 0.0
	stage = Stage.STOPPED
	set_physics_process(false)
	vehicle_stopped.emit(net_id)


func is_stopped() -> bool:
	return stage == Stage.STOPPED


## QC-83: the seat nodes (`Seat0..n` in the visual), in order. D (RT convoy fit): a glb exports them as plain Node3D
## empties, so any Node3D counts (the placeholder's Marker3Ds too).
func seats() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i: int in MAX_SEATS:
		var m: Node3D = visual_node("Seat%d" % i) as Node3D
		if m == null:
			break
		out.append(m)
	return out


func _physics_process(delta: float) -> void:
	if stage != Stage.DRIVING or not Net.is_authority():
		return
	var left: float = route_m - travelled_m
	# brake so the speed reaches 0 at the marker (v^2 = 2 a s), else accelerate up to speed_mps
	var v_max: float = sqrt(2.0 * maxf(brake_mps2, 0.01) * maxf(left, 0.0))
	speed = minf(minf(speed + accel_mps2 * delta, speed_mps), maxf(v_max, 0.3))
	travelled_m = minf(travelled_m + speed * delta, route_m)
	if route_m - travelled_m <= 0.01:
		park(_stop)
		return
	global_transform = _route_xform(travelled_m)


## The vehicle transform `d` metres along the route (curve, then the straight leg onto the stop marker).
func _route_xform(d: float) -> Transform3D:
	if d <= _curve_end_m:
		return _curve_xform(d)
	var leg: float = maxf(route_m - _curve_end_m, 0.001)
	var t: float = clampf((d - _curve_end_m) / leg, 0.0, 1.0)
	var end_basis: Basis = _stop.global_basis.orthonormalized()
	var q: Quaternion = _curve_end_xf.basis.get_rotation_quaternion().slerp(end_basis.get_rotation_quaternion(), t)
	return Transform3D(Basis(q), _curve_end_xf.origin.lerp(_stop.global_position, t))


## The curve's frame at offset `d` as a vehicle transform: forward +Z along the curve tangent, pitched with it (C: on
## the ~9 deg east ramp an upright 9 m truck clipped the road by up to 0.7 m), no roll.
func _curve_xform(d: float) -> Transform3D:
	var c: Curve3D = _path.curve
	var p: Vector3 = _path.to_global(c.sample_baked(d, true))
	var ahead: Vector3 = _path.to_global(c.sample_baked(minf(d + 0.5, c.get_baked_length()), true))
	var fwd: Vector3 = ahead - p
	if d + 0.5 > c.get_baked_length():
		fwd = p - _path.to_global(c.sample_baked(maxf(d - 0.5, 0.0), true))
	if Vector2(fwd.x, fwd.z).length() < 0.001:
		return Transform3D(global_basis, p)
	var z: Vector3 = fwd.normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x).normalized(), z), p)


func _net_xform() -> Variant:
	return global_transform


func _net_state() -> Dictionary:
	return {"stage": int(stage)}


func _apply_net_state(d: Dictionary) -> void:
	if not d.has("stage"):
		return
	var was: Stage = stage
	stage = int(d["stage"]) as Stage
	if stage == Stage.DRIVING and was == Stage.PARKED:
		drive_started.emit(net_id)
	if stage == Stage.STOPPED and was != Stage.STOPPED:
		vehicle_stopped.emit(net_id)
