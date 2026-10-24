## Laser grid that trips the alarm on touch, even while casing / in civilian mode; ECM doesn't
## affect it (S9.10, P2). Owner: ENV A. Floor object: pivot bottom-centre, the grid spans `size_m`
## (x = width, y = height, z = depth) centred on the origin footprint.
## `Trigger` (Area3D, triggers layer, monitors players) is the whole grid volume. Detection is done
## by one runtime Area3D per beam, `BeamArea<i>` (triggers layer, mask players): any CrewController
## overlapping an active beam trips the grid once: laser_tripped(grid net_id) [R], cue.laser_trip and
## raise_alarm(&"laser"). No trips once the heist went loud.
## Patterns (`pattern`), time base = seconds since the grid started (+ `phase_s`):
##   &"static"     `beam_count` horizontal beams evenly spread over the height, always on.
##   &"timed_off"  the same beams, all off for the last `off_s` of every `period_s` cycle.
##   &"sweeping"   `sweep_beams` vertical beams sweeping across the width and back (ping-pong) once
##                 per `period_s`, evenly phase-shifted.
## Visual (visual_slots.md, optional): `Beam<i>` nodes (Beam0, Beam1, ...). A drives their
## `visible` (beam on) and position (horizontal beams: y; sweeping: x); author horizontal beams
## for static/timed_off and vertical beams for sweeping. The placeholder is laid out by A.
## D-103 §6 / QC-53: `set_enabled(bool)` (server, replicated as `active`) turns the whole grid on / off for the
## mission (Gallery Night: the landing curtain switches on at last call); `enabled_at_start` false = starts off.
## OF-A2: both override GameplayPrefab's runtime enable: the grid itself (frame, art) stays visible and never
## takes the generic hidden / no-collision state (`_start_enabled` is always true; `enabled_at_start`, the base
## export, seeds `active` instead).
class_name LaserGrid
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/laser_grid/laser_grid_placeholder.tscn")
const PATTERN_STATIC: StringName = &"static"
const PATTERN_SWEEPING: StringName = &"sweeping"
const PATTERN_TIMED_OFF: StringName = &"timed_off"
const PATTERNS: Array[StringName] = [PATTERN_STATIC, PATTERN_SWEEPING, PATTERN_TIMED_OFF]

## &"static", &"sweeping" or &"timed_off" (S9.10).
@export var pattern: StringName = &"static"
@export var size_m: Vector3 = Vector3(2.0, 2.0, 0.1)
## A2-04: horizontal beams (static / timed_off).
@export var beam_count: int = 4
## A2-04: cycle length (s) of timed_off and sweeping.
@export var period_s: float = 4.0
## A2-04: timed_off: seconds per cycle the beams are off (at the end of the cycle).
@export var off_s: float = 1.5
## A2-04: time offset (s) into the cycle at start.
@export var phase_s: float = 0.0
## A2-04: vertical beams of the sweeping pattern.
@export var sweep_beams: int = 1

var tripped: bool = false
## Switched on (set_enabled; generic replicated prop `active`).
var active: bool = true
## Seconds since the grid started (+ phase_s).
var time_s: float = 0.0
var beam_areas: Array[Area3D] = []

## Visual `Beam<i>` per beam area (null = none in the visual).
var _beam_visuals: Array[Node3D] = []

@onready var trigger: Area3D = $Trigger as Area3D


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


## OF-A2: `enabled_at_start` drives `active` (beams), not the generic hidden state.
func _start_enabled() -> bool:
	return true


func _prefab_ready() -> void:
	if not PATTERNS.has(pattern):
		# LEAD r314 (C 10f91e29: AH wrote "sweep" / "timed", which silently ran as a static grid): loud, not a fallback.
		Log.error(LOG_CHANNEL, "%s: unknown laser pattern '%s' (one of %s); running static" % [get_path(), pattern, PATTERNS])
	ZoneUtil.size_box_zone(trigger, size_m)
	trigger.collision_layer = LAYER_TRIGGERS
	trigger.collision_mask = LAYER_PLAYERS
	time_s = phase_s
	active = enabled_at_start
	_build_beams()
	_update_beams()


## Number of beams of the current pattern.
func beam_total() -> int:
	return maxi(sweep_beams, 0) if pattern == PATTERN_SWEEPING else maxi(beam_count, 0)


## Beams on right now (timed_off: false during the off window).
func beams_on() -> bool:
	if tripped or not active:
		return false
	if pattern != PATTERN_TIMED_OFF or period_s <= 0.0:
		return true
	return fposmod(time_s, period_s) < period_s - clampf(off_s, 0.0, period_s)


## Local offset of beam `i`: y (height) for horizontal beams, x for sweeping beams.
func beam_offset(i: int) -> float:
	var n: int = beam_total()
	if pattern != PATTERN_SWEEPING:
		return size_m.y * (float(i) + 0.5) / float(maxi(n, 1))
	var p: float = maxf(period_s, 0.01)
	var u: float = fposmod(time_s / p + float(i) / float(maxi(n, 1)), 1.0)
	var tri: float = 1.0 - absf(2.0 * u - 1.0)  # 0 -> 1 -> 0 over a cycle
	return (tri - 0.5) * size_m.x


func _physics_process(delta: float) -> void:
	time_s += delta
	_update_beams()
	if tripped or not Net.is_authority() or not beams_on():
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null and rt.went_loud:
		return
	for a: Area3D in beam_areas:
		for b: Node3D in a.get_overlapping_bodies():
			var c: CrewController = b as CrewController
			if c != null:
				_trip(c)
				return


## Server (mission): switch the grid on / off. Off = no beams, no trips; on again resumes its pattern.
func set_enabled(on: bool) -> void:
	if not Net.is_authority():
		return
	active = on
	_update_beams()


func _trip(by: CrewController) -> void:
	tripped = true
	Log.info(LOG_CHANNEL, "%s tripped by slot %d" % [name, by.slot])
	_emit_fact(&"laser_tripped", [net_id])
	_cue(&"cue.laser_trip", by.global_position)
	_raise_alarm(&"laser", net_id)
	_update_beams()


func _build_beams() -> void:
	var t: float = Tweak.interaction().laser_beam_thickness_m
	var sweeping: bool = pattern == PATTERN_SWEEPING
	for i: int in range(beam_total()):
		var a: Area3D = Area3D.new()
		a.name = "BeamArea%d" % i
		a.collision_layer = LAYER_TRIGGERS
		a.collision_mask = LAYER_PLAYERS
		a.monitorable = false
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(t, size_m.y, maxf(size_m.z, t)) if sweeping else Vector3(size_m.x, t, maxf(size_m.z, t))
		cs.shape = box
		a.add_child(cs)
		add_child(a)
		beam_areas.append(a)
		_beam_visuals.append(visual_node("Beam%d" % i) as Node3D)
	if not using_placeholder:
		return
	# Placeholder posts sit just inside the passage edges (the whole grid stays within size_m) and span
	# size_m.y (QC Night Deposit; LEAD: inset by the post's half width so posts never clip the walls).
	for post: String in ["PostL", "PostR"]:
		var pm: Node3D = visual_node(post) as Node3D
		if pm != null:
			var side: float = -1.0 if post == "PostL" else 1.0
			var half_w: float = 0.0
			if pm is MeshInstance3D and (pm as MeshInstance3D).mesh != null:
				half_w = (pm as MeshInstance3D).mesh.get_aabb().size.x * 0.5
			pm.position = Vector3(side * (size_m.x * 0.5 - half_w), size_m.y * 0.5, 0.0)
			pm.scale = Vector3(1.0, size_m.y / 2.0, 1.0)
	# Placeholder: Beam0..3 are 2 m horizontal bars; fit them to the pattern and size.
	for i: int in range(4):
		var m: Node3D = visual_node("Beam%d" % i) as Node3D
		if m == null:
			continue
		if i >= beam_total():
			m.visible = false
		elif sweeping:
			m.basis = Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(size_m.y / 2.0, 1.0, 1.0))
		else:
			m.scale = Vector3(size_m.x / 2.0, 1.0, 1.0)


func _update_beams() -> void:
	var on: bool = beams_on()
	var sweeping: bool = pattern == PATTERN_SWEEPING
	for i: int in range(beam_areas.size()):
		var off: float = beam_offset(i)
		var pos: Vector3 = Vector3(off, size_m.y * 0.5, 0.0) if sweeping else Vector3(0.0, off, 0.0)
		beam_areas[i].position = pos
		var m: Node3D = _beam_visuals[i] if i < _beam_visuals.size() else null
		if m != null:
			m.position = pos
			m.visible = on
