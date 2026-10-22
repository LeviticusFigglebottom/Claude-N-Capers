## OF-D1 cast clip audit (LEAD 2026-10-21): every Ostrander Federal spawn's idle activity (the built map's SpawnPoints,
## variant slots included) resolves to an ambient clip that exists in char_anim_humanoid (or as its variant group), loops
## and moves (no frozen pose: some bone track differs between two times in the loop), and fits its prop: a seated clip
## has a map `Seat` marker within StealthTweak.civilian_seat_radius_m on its floor (CivilianTargets.seat_near), a
## teller_count row stands behind a teller_worktop (top 1.00 m, near edge 0.20-0.40 m ahead, the clip's 0.28 m).
## A's test_anim_driver already pins HINT_CLIPS / KNOWN_ACTIVITIES keys; C's test_ostrander_federal_map the queue marks.
## Owner: ENV D.
extends TestCase

const SCENE: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
## clips that sit the root on a seat (the chair's Seat marker is where the seated clips put the root)
const SEATED_CLIPS: Array[StringName] = [&"sit_chair", &"desk_work", &"phone_seated", &"sit_chair_read",
	&"sit_chair_watch", &"sit_chair_armed", &"sit_eat"]
## teller_count authoring (_anim_p5.py COUNTER_Z / COUNTER_EDGE): worktop top and its near edge ahead of the root
const WORKTOP_TOP: float = 1.00
const EDGE_MIN: float = 0.20
const EDGE_MAX: float = 0.40
## a bone this far (m / rad) between two loop times counts as moving
const MOVE_EPS: float = 0.002

var _map: HeistMap = null
var _anims: Node3D = null
var _player: AnimationPlayer = null


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps != null:
		_map = ps.instantiate() as HeistMap
	var glb: PackedScene = load(GLB) as PackedScene
	if glb != null:
		_anims = glb.instantiate() as Node3D
		add_child(_anims)
		var found: Array[Node] = _anims.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _map != null:
		_map.free()
	if _anims != null:
		_anims.queue_free()


func test_every_of_spawn_clip_exists_loops_and_moves() -> void:
	if _map == null or _player == null:
		fail("map or animation library missing")
		return
	var checked: Dictionary = {}
	for sp: SpawnPoint in _spawns():
		var clip: StringName = _clip_of(sp)
		if clip == &"" or checked.has(clip):
			continue
		checked[clip] = true
		var names: Array = AnimDriver.VARIANT_GROUPS.get(clip, [clip])
		for v: Variant in names:
			var a: Animation = _anim(StringName(v))
			assert_true(a != null, "%s (%s): clip %s in char_anim_humanoid" % [sp.name, sp.idle_activity, v])
			if a == null:
				continue
			assert_true(a.loop_mode != Animation.LOOP_NONE, "clip %s loops (ambient idle)" % v)
			assert_true(_moves(a), "clip %s moves (not a frozen pose)" % v)
	assert_true(checked.size() >= 6, "OF uses several ambient clips (%s)" % [checked.keys()])


func test_seated_spawns_have_a_seat() -> void:
	if _map == null:
		fail("map missing")
		return
	var seats: Array[Vector3] = []
	for n: Node in _map.find_children(String(CivilianTargets.SEAT_NODE), "Node3D", true, false):
		seats.append(_xform(n as Node3D).origin)
	var tw: StealthTweak = Tweak.stealth()
	var seated: int = 0
	for sp: SpawnPoint in _spawns():
		if not SEATED_CLIPS.has(_clip_of(sp)):
			continue
		seated += 1
		var p: Vector3 = _xform(sp).origin
		var best: float = INF
		for s: Vector3 in seats:
			if absf(s.y - p.y) <= tw.civilian_wander_floor_dy_m:
				best = minf(best, Vector2(s.x - p.x, s.z - p.z).length())
		assert_true(best <= tw.civilian_seat_radius_m, "%s (%s, %s): Seat %.2f m away (<= %.2f)" % [
			sp.name, sp.idle_activity, _clip_of(sp), best, tw.civilian_seat_radius_m])
	assert_true(seated > 0, "OF has seated spawns")


func test_tellers_stand_behind_a_worktop() -> void:
	if _map == null:
		fail("map missing")
		return
	var tops: Array[AABB] = []
	for n: Node in _map.find_children("*", "Node3D", true, false):
		if String(n.name).begins_with("TellerWorktop"):
			tops.append(_box(n as Node3D))
	assert_true(tops.size() >= 4, "teller worktops in the map (%d)" % tops.size())
	var tellers: int = 0
	for sp: SpawnPoint in _spawns():
		if _clip_of(sp) != &"teller_count":
			continue
		tellers += 1
		var xf: Transform3D = _xform(sp)
		var fwd: Vector3 = -xf.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var ok: bool = false
		for b: AABB in tops:
			# step forward from the root until inside the worktop's footprint: that distance is its near edge
			for i: int in range(0, 61):
				var q: Vector3 = xf.origin + fwd * (i * 0.01)
				if q.x >= b.position.x and q.x <= b.end.x and q.z >= b.position.z and q.z <= b.end.z:
					var edge: float = i * 0.01
					ok = ok or (edge >= EDGE_MIN and edge <= EDGE_MAX and absf(b.end.y - xf.origin.y - WORKTOP_TOP) < 0.05)
					break
		assert_true(ok, "%s: a teller_worktop (top %.2f m) with its near edge %.2f-%.2f m ahead" % [sp.name, WORKTOP_TOP,
			EDGE_MIN, EDGE_MAX])
	assert_true(tellers >= 4, "OF teller spawns (%d)" % tellers)


## The clip a spawn plays when calm: its activity through CivilianBrain (civilians: unknown -> idle) and HINT_CLIPS.
func _clip_of(sp: SpawnPoint) -> StringName:
	var act: StringName = sp.idle_activity
	if act == &"":
		return &""
	if sp.kind == SpawnPoint.Kind.CIVILIAN and not CivilianBrain.KNOWN_ACTIVITIES.has(act):
		return &"idle"
	return AnimDriver.HINT_CLIPS.get(act, &"")


func _spawns() -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	for n: Node in _map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		if sp.kind in [SpawnPoint.Kind.CIVILIAN, SpawnPoint.Kind.GUARD]:
			out.append(sp)
	return out


func _anim(clip: StringName) -> Animation:
	for lib: StringName in _player.get_animation_library_list():
		var al: AnimationLibrary = _player.get_animation_library(lib)
		if al.has_animation(clip):
			return al.get_animation(clip)
	return null


## True when some position / rotation track differs between a quarter and three quarters of the loop.
func _moves(a: Animation) -> bool:
	for t: int in a.get_track_count():
		var kind: Animation.TrackType = a.track_get_type(t)
		if kind == Animation.TYPE_ROTATION_3D:
			var q0: Quaternion = a.rotation_track_interpolate(t, a.length * 0.25)
			var q1: Quaternion = a.rotation_track_interpolate(t, a.length * 0.75)
			if q0.angle_to(q1) > MOVE_EPS:
				return true
		elif kind == Animation.TYPE_POSITION_3D:
			if a.position_track_interpolate(t, a.length * 0.25).distance_to(
					a.position_track_interpolate(t, a.length * 0.75)) > MOVE_EPS:
				return true
	return false


func _xform(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != _map:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Map-space AABB of a worktop node: its first box collider or mesh.
func _box(n: Node3D) -> AABB:
	for c: Node in n.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs.shape is BoxShape3D:
			var size: Vector3 = (cs.shape as BoxShape3D).size
			var xf: Transform3D = _xform(cs)
			return AABB(xf.origin - size * 0.5, size)
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		return _xform(mi) * mi.get_aabb()
	return AABB(_xform(n).origin, Vector3.ZERO)
