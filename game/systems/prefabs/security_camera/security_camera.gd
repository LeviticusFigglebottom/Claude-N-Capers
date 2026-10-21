## Security camera observer (gameplay_prefabs.md `security_camera`). Owner: ENV A.
## Rows: S8.1 (cones, one-shot, broken-camera stimulus, Titan), S8.2 (operator), S3.5 (countdown),
## S4.4 (camera stimulus list, deaf), S2.5 (crouch ignored, in StealthDirector).
## Wall/ceiling mounted: pivot back-centre (wall) or top-centre (ceiling), view along -Z.
## Visual: `Mount` (static), `Head` (A yaws/pitches it), `Lens` (Marker3D, -Z = view direction),
## `Led` (MeshInstance3D, A toggles emission). Not interactive (shot to destroy when `destructible`).
## `Collision` is a small hitbox (layer hitboxes) so it can be shot, fitted at ready to the visual
## (GameplayPrefab collision fitting; `collision_size_override`, or the visual's own `Collision`). A2-08: its box spans local
## z in [-0.45, 0], entirely in front of the wall-mount pivot (no part behind the wall plane).
## QA-26 (D-043, visual_slots.md): mounted collision stays on the room side of the pivot (wall: -Z
## only; ceiling: -Y only). `mount_mode` (AUTO = node meta `mount` "ceiling"/"wall", the level
## convention, else WALL): a CEILING camera lowers `Collision` (and the placeholder) until its top is
## at the pivot plane (y <= 0).
##
## Observer protocol (stealth/README.md): group G.OBSERVER, `observer_kind() == CAMERA`, the cone
## comes from `detection_overrides()` (fov_deg, range_m -> preset `far`) on top of the `camera`
## preset; eye and view direction from `Lens` (follows the `Head` pan). Cameras never hear (S4.4).
## A camera that confirms a stimulus (S4.4 list: `camera: true` kinds) starts the S3.5 countdown.
##
## PUBLIC API (server unless noted):
##   can_observe() -> bool                    -> active, not destroyed, not suppressed
##   destroy(by_net_id)                        -> S8.1 break: camera_disabled(&"destroyed") [R] + `broken_camera` stimulus
##   disable(reason, by_net_id)                -> permanent off: camera_disabled(reason) [R] (operator: &"operator")
##   set_suppressed(source, on)                -> temporary blind (A2-03 ECM jam, P3 `stealth.camera_loop`)
##   is_titan() -> bool                        -> indestructible (export `titan` or difficulty >= camera_titan_min_difficulty)
##   broken_position() -> Vector3              -> where guards investigate a broken camera
##   SecurityCamera.cameras_in(rt) -> Array[SecurityCamera] (static)
## Clients mirror `active`/`destroyed` and the visuals from camera_disabled [R].
class_name SecurityCamera
extends GameplayPrefab

signal crew_spotted(crew: Node)
signal stimulus_spotted(stimulus_id: int, kind: StringName, position: Vector3)
signal disabled(reason: StringName)

## QA-26 mount of the camera (pivot back-centre on a wall, top-centre on a ceiling).
enum MountMode { AUTO, WALL, CEILING }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/security_camera/security_camera_placeholder.tscn")
## Runtime group of every security camera (station lookups; the director uses G.OBSERVER).
const GROUP: StringName = &"security_camera"
## Default objective_tag so `HeistRuntime.find_by_tag(&"security_camera")` lists untagged cameras.
const DEFAULT_TAG: StringName = &"security_camera"
const REASON_DESTROYED: StringName = &"destroyed"
const REASON_OPERATOR: StringName = &"operator"
const STIMULUS_KIND: StringName = &"broken_camera"
## Level-convention meta read by MountMode.AUTO (tools/levelcheck: &"wall" / &"ceiling").
const MOUNT_META: StringName = &"mount"

## Horizontal field of view (degrees).
@export var fov_deg: float = 60.0
@export var range_m: float = 15.0  # D-128 (LEAD): PD2 editor default; per-camera overrides stay
## Total pan arc (degrees). 0 = static.
@export var pan_deg: float = 0.0
## Seconds for a full pan cycle.
@export var pan_period_s: float = 8.0
@export var destructible: bool = true
## S8.1 Titan camera: indestructible regardless of difficulty (Lethal+ makes every camera Titan).
@export var titan: bool = false
## QA-26: wall (pivot back-centre) or ceiling (pivot top-centre). AUTO = meta `mount`, else WALL.
@export var mount_mode: MountMode = MountMode.AUTO:
	set(value):
		mount_mode = value
		apply_mount()
## Collision box size (m), placed on the pivot; ZERO = fit to the visual (or use the visual's own
## `Collision`), see GameplayPrefab "Collision fitting".
@export var collision_size_override: Vector3 = Vector3.ZERO

## False once permanently disabled (destroyed, operator neutralised).
var active: bool = true
var destroyed: bool = false
## Why the camera went off (&"destroyed", &"operator", ...), &"" while active.
var disabled_reason: StringName = &""
## StealthTweak.observer_presets key (S2.2).
var detection_preset: StringName = &"camera"
## Current pan yaw offset from the rest pose (degrees).
var pan_offset_deg: float = 0.0
## Stimulus id of the broken camera (S8.1), 0 if none.
var broken_stimulus_id: int = 0
## True once this camera fully detected something (S3.5).
var alerted: bool = false

var _suppressed: Dictionary[StringName, bool] = {}
var _head: Node3D = null
var _lens: Node3D = null
var _led: MeshInstance3D = null
var _head_rest: Basis = Basis.IDENTITY
var _pan_time: float = 0.0
var _led_off: StandardMaterial3D = null
var _collision_rest: Transform3D = Transform3D.IDENTITY
var _collision_rest_set: bool = false
var _placeholder_rest: Vector3 = Vector3.ZERO
var _placeholder_rest_set: bool = false


func _init() -> void:
	objective_tag = DEFAULT_TAG


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Mount", "Head", "Lens", "Led"])


## Fitted hitbox: wall art (and the wall-authored placeholder, which `apply_mount` lowers together
## with `Collision`) stays at z <= 0; ceiling art at y <= 0.
func _collision_pivot() -> CollisionPivot:
	if resolved_mount() == MountMode.CEILING and not using_placeholder:
		return CollisionPivot.CEILING
	return CollisionPivot.WALL


func _prefab_ready() -> void:
	add_to_group(G.OBSERVER)
	add_to_group(GROUP)
	_head = visual_node("Head") as Node3D
	_lens = visual_node("Lens") as Node3D
	_led = visual_node("Led") as MeshInstance3D
	if _head != null:
		_head_rest = _head.transform.basis
	apply_mount()
	_route_hits(get_node_or_null(^"Collision"))
	EventBus.camera_disabled.connect(_on_camera_disabled_event)
	_apply_visuals()


func _exit_tree() -> void:
	if EventBus.camera_disabled.is_connected(_on_camera_disabled_event):
		EventBus.camera_disabled.disconnect(_on_camera_disabled_event)
	var st: StealthDirector = _stealth()
	if st != null and broken_stimulus_id != 0:
		st.unregister_stimulus(broken_stimulus_id)
	broken_stimulus_id = 0


## Every SecurityCamera inside `rt` (tree order).
static func cameras_in(rt: Node) -> Array[SecurityCamera]:
	var out: Array[SecurityCamera] = []
	if rt == null or not rt.is_inside_tree():
		return out
	for n: Node in rt.get_tree().get_nodes_in_group(GROUP):
		var cam: SecurityCamera = n as SecurityCamera
		if cam != null and rt.is_ancestor_of(cam):
			out.append(cam)
	return out


# --- Mount (QA-26) ---------------------------------------------------------------------

## WALL or CEILING after resolving AUTO (meta `mount` == "ceiling" -> CEILING, else WALL).
func resolved_mount() -> MountMode:
	if mount_mode != MountMode.AUTO:
		return mount_mode
	if has_meta(MOUNT_META) and String(get_meta(MOUNT_META)) == "ceiling":
		return MountMode.CEILING
	return MountMode.WALL


## Re-apply the mount offsets (idempotent; works before entering the tree). CEILING: `Collision`
## and the placeholder visual move down so nothing reaches above the pivot plane.
func apply_mount() -> void:
	var ceiling: bool = resolved_mount() == MountMode.CEILING
	var body: Node3D = get_node_or_null(^"Collision") as Node3D
	if body != null:
		if not _collision_rest_set:
			_collision_rest = body.transform
			_collision_rest_set = true
		body.transform = _collision_rest
		if ceiling:
			body.position.y -= maxf(collision_aabb().end.y, 0.0)
	if using_placeholder and visual_instance != null and is_instance_valid(visual_instance):
		if not _placeholder_rest_set:
			_placeholder_rest = visual_instance.position
			_placeholder_rest_set = true
		visual_instance.position = _placeholder_rest
		if ceiling:
			visual_instance.position.y -= maxf(_mesh_top_y(visual_instance), 0.0)


## Merged AABB of the `Collision` shapes in this node's local space (tests, levelcheck).
func collision_aabb() -> AABB:
	var body: Node3D = collision_body() as Node3D
	var out: AABB = AABB()
	var first: bool = true
	if body == null:
		return out
	for n: Node in body.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var local: AABB = cs.shape.get_debug_mesh().get_aabb()
		var xf: Transform3D = _relative_xform(self, cs)
		var box: AABB = xf * local
		out = box if first else out.merge(box)
		first = false
	return out


## Highest y of the visual meshes under `root`, in this node's local space.
func _mesh_top_y(root: Node3D) -> float:
	var top: float = -INF
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var box: AABB = _relative_xform(self, mi) * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > -INF else 0.0


## Transform of `n` relative to its ancestor `ancestor` (no tree needed).
static func _relative_xform(ancestor: Node, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


# --- Observer protocol (StealthDirector) ---------------------------------------------

func observer_kind() -> int:
	return Enums.ObserverKind.CAMERA


## P (OF G2 throws, CameraC9): a camera switched off with GameplayPrefab.set_enabled(false) / enabled_at_start false
## (OF-A2, QC-61: hidden, processing off) sees nothing.
func can_observe() -> bool:
	return active and prefab_enabled and not destroyed and _suppressed.is_empty() and is_inside_tree()


## Per-camera cone on top of the `camera` preset (S8.1): fov_deg, range_m.
func detection_overrides() -> Dictionary:
	return {"fov_deg": fov_deg, "far": range_m}


func eye_position() -> Vector3:
	return _lens.global_position if _lens != null else global_position


## 3D view direction (-Z of `Lens`, which follows the Head pan).
func look_forward() -> Vector3:
	var n: Node3D = _lens if _lens != null else self
	var f: Vector3 = -n.global_basis.z
	return f.normalized() if f.length_squared() > 0.000001 else Vector3.FORWARD


func notify_crew_spotted(crew: Node) -> void:
	alerted = true  # StealthDirector starts the S3.5 countdown itself.
	crew_spotted.emit(crew)


## S4.4: a confirmed camera stimulus alerts the camera (S3.5 countdown) unless the stimulus preset
## sets `camera_alarm: false`.
func notify_stimulus(stimulus_id: int, kind: StringName, position: Vector3) -> void:
	stimulus_spotted.emit(stimulus_id, kind, position)
	var preset: Dictionary = Tweak.stealth().stimuli.get(kind, {})
	if not bool(preset.get("camera_alarm", true)):
		return
	var st: StealthDirector = _stealth()
	if st != null and Net.is_authority():
		alerted = true
		st.start_camera_alarm(net_id)


## S4.4: cameras do not hear (the director never calls this for cameras either).
func notify_noise(_position: Vector3, _kind: StringName, _source_net_id: int) -> void:
	pass


# --- Damage (damage.md) ----------------------------------------------------------------

## S8.1: one hit of any amount breaks a destructible, non-Titan camera.
func is_titan() -> bool:
	if titan:
		return true
	var rt: HeistRuntime = HeistRuntime.of(self)
	return rt != null and rt.difficulty >= titan_min_difficulty(rt)


## D-130: the Enums.Difficulty from which a run's cameras are Titan: the heist's HeistDef.camera_titan_min_difficulty
## when >= 0 (Golden Hour: HAZARDOUS), else StealthTweak.camera_titan_min_difficulty (LETHAL).
static func titan_min_difficulty(rt: HeistRuntime) -> int:
	var def: HeistDef = rt.map.heist_def if rt != null and rt.map != null else null
	if def != null and def.camera_titan_min_difficulty >= 0:
		return def.camera_titan_min_difficulty
	return Tweak.stealth().camera_titan_min_difficulty


func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = info.duplicate()
	out["killed"] = false
	if not Net.is_authority():
		out["amount"] = 0.0
		return out
	var breaks: bool = not destroyed and destructible and not is_titan()
	if breaks:
		out["killed"] = true
	else:
		out["amount"] = 0.0
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [net_id, attacker_net_id, out])
	if breaks:
		destroy(attacker_net_id)
	return out


## Deprecated alias of take_hit (pre-D-026 callers).
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	return take_hit(info, attacker_net_id)


## Server: break the camera (S8.1): camera_disabled(&"destroyed") [R], `broken_camera` stimulus.
func destroy(_by_net_id: int = 0) -> void:
	if not Net.is_authority() or destroyed:
		return
	destroyed = true
	active = false
	disabled_reason = REASON_DESTROYED
	_emit_fact(&"camera_disabled", [net_id, REASON_DESTROYED])
	var st: StealthDirector = _stealth()
	if st != null:
		broken_stimulus_id = st.register_stimulus(null, STIMULUS_KIND,
			{"position": broken_position(), "camera_net_id": net_id})
	_apply_visuals()
	disabled.emit(REASON_DESTROYED)


## Server: switch the camera off for good (e.g. &"operator", S8.2). No-op when already off.
func disable(reason: StringName, _by_net_id: int = 0) -> void:
	if not Net.is_authority() or not active:
		return
	active = false
	disabled_reason = reason
	_emit_fact(&"camera_disabled", [net_id, reason])
	_apply_visuals()
	disabled.emit(reason)


## Server: temporary blindness by `source` (A2-03 ECM jam, P3 camera loop). Meters clear while blind.
func set_suppressed(source: StringName, on: bool) -> void:
	if on:
		_suppressed[source] = true
	else:
		_suppressed.erase(source)
	_apply_visuals()


func is_suppressed() -> bool:
	return not _suppressed.is_empty()


## Point guards walk to / look at for a broken camera: just below the lens, off the wall.
func broken_position() -> Vector3:
	var p: Vector3 = eye_position()
	return p - Vector3.UP * Tweak.stealth().stimulus_los_height_m


# --- Pan + visuals --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if pan_deg <= 0.0 or _head == null or not active:
		return
	_pan_time += delta
	pan_offset_deg = pan_deg * 0.5 * sin(TAU * _pan_time / maxf(pan_period_s, 0.01))
	_head.transform.basis = Basis(_pan_axis(), deg_to_rad(pan_offset_deg)) * _head_rest


## World up expressed in the Head's parent space (pan stays horizontal on tilted mounts).
func _pan_axis() -> Vector3:
	var parent: Node3D = _head.get_parent() as Node3D
	if parent == null:
		return Vector3.UP
	var axis: Vector3 = parent.global_basis.orthonormalized().inverse() * Vector3.UP
	return axis.normalized() if axis.length_squared() > 0.000001 else Vector3.UP


func _apply_visuals() -> void:
	if _led != null:
		if active and _suppressed.is_empty():
			_led.material_override = null
		else:
			if _led_off == null:
				_led_off = StandardMaterial3D.new()
				_led_off.albedo_color = Color(0.15, 0.03, 0.03, 1.0)
				_led_off.emission_enabled = false
			_led.material_override = _led_off
	if destroyed:
		if _head != null:
			_head.transform.basis = Basis(Vector3.RIGHT, -deg_to_rad(Tweak.stealth().camera_broken_droop_deg)) * _head.transform.basis
		var body: CollisionObject3D = collision_body()
		if body != null:
			body.collision_layer = 0


## Client (A3-07, HeistNetSync): mirror `active` / `destroyed` when the camera_disabled event was missed.
func _apply_net_state(state: Dictionary) -> void:
	if state.has("pan_offset_deg"):
		pan_offset_deg = float(state["pan_offset_deg"])
	var off: bool = state.has("active") and not bool(state["active"])
	if bool(state.get("destroyed", false)) and not destroyed:
		_on_camera_disabled_event(net_id, REASON_DESTROYED)
	elif off and active:
		_on_camera_disabled_event(net_id, StringName(state.get("disabled_reason", disabled_reason)))


func _on_camera_disabled_event(camera_net_id: int, reason: StringName) -> void:
	if Net.is_authority() or camera_net_id != net_id or (reason != REASON_DESTROYED and not active):
		return
	var was_destroyed: bool = destroyed
	active = false
	disabled_reason = reason
	destroyed = destroyed or reason == REASON_DESTROYED
	if destroyed and was_destroyed:
		return
	_apply_visuals()
	disabled.emit(reason)
