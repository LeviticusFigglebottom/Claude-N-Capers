## D-116: the hit-zone flinches of the "humanoid" library (char_anim_humanoid, _anim_hitzones). Run after
## `godot --import`. Each flinch: present, one-shot, length and `impact` (SOURCE), the zone map documented
## (`hit_zones`), starts and ends on idle_alert frame 0 (1 cm per bone), the root fixed, the feet planted (the leg
## flinches: the other foot planted, the hit foot steps back and returns), and the right body part moved at `impact`
## (head tipped back, chest back, the hit shoulder back, the hips down toward the hit leg).
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, impact frame, the foot that steps ("" = none)].
const HIT_ZONES: Dictionary = {
	"hit_head": [14, 2, ""], "hit_chest": [14, 3, ""], "hit_shoulder_l": [14, 3, ""], "hit_shoulder_r": [14, 3, ""],
	"hit_leg_l": [16, 3, "L"], "hit_leg_r": [16, 3, "R"],
}

var _root: Node3D = null
var _player: AnimationPlayer = null
var _skel: Skeleton3D = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func test_hit_zone_flinches() -> void:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s with an AnimationPlayer and rig_humanoid/Skeleton3D (run godot --import first)" % GLB)
		return
	var lines: Dictionary = _source_lines()
	var zones: String = String(lines.get("hit_zones", ""))
	for clip: String in HIT_ZONES:
		assert_true(zones.contains(clip), "SOURCE hit_zones maps %s" % clip)
	assert_true(lines.has("hit_zone_checks"), "SOURCE hit_zone_checks")
	var alert0: Array[Vector3] = _snapshot("idle_alert", 0.0)
	var root: int = _skel.find_bone("root")
	for clip: String in HIT_ZONES:
		var spec: Array = HIT_ZONES[clip]
		var n: int = int(spec[0])
		var a: Animation = _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null
		assert_true(a != null, "D-116 clip %s" % clip)
		if a == null:
			continue
		assert_eq(a.loop_mode, Animation.LOOP_NONE, "%s is a one-shot" % clip)
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_true(String(lines.get("clip." + clip, "")).contains("impact@%d" % int(spec[1])), "%s impact event" % clip)
		var s0: Array[Vector3] = _snapshot(clip, 0.0)
		var sn: Array[Vector3] = _snapshot(clip, float(n) / 30.0)
		assert_true(_snap_dist(s0, alert0) < 0.01, "%s: starts on idle_alert frame 0 (%f m)" % [clip, _snap_dist(s0, alert0)])
		assert_true(_snap_dist(sn, alert0) < 0.01, "%s: ends on idle_alert frame 0 (%f m)" % [clip, _snap_dist(sn, alert0)])
		var stepper: String = String(spec[2])
		var drift: Dictionary = {"L": 0.0, "R": 0.0}
		var back: float = 0.0
		var root_move: float = 0.0
		for f: int in range(n + 1):
			var s: Array[Vector3] = _snapshot(clip, float(f) / 30.0)
			root_move = maxf(root_move, s[root].distance_to(s0[root]))
			for sfx: String in ["L", "R"]:
				for b: String in ["foot." + sfx, "toe." + sfx]:
					var i: int = _skel.find_bone(b)
					drift[sfx] = maxf(float(drift[sfx]), s[i].distance_to(s0[i]))
					if sfx == stepper:
						back = maxf(back, s[i].z - s0[i].z)
		assert_true(root_move < 0.001, "%s: the root never moves (%f m)" % [clip, root_move])
		for sfx: String in ["L", "R"]:
			if sfx == stepper:
				assert_true(back > 0.04 and float(drift[sfx]) < 0.12, "%s: the hit foot steps back %f m and returns" % [clip, back])
			else:
				assert_true(float(drift[sfx]) < 0.004, "%s: foot.%s planted (%f m)" % [clip, sfx, drift[sfx]])
		_check_flinch_direction(clip, s0, _snapshot(clip, float(spec[1]) / 30.0))


func _check_flinch_direction(clip: String, s0: Array[Vector3], si: Array[Vector3]) -> void:
	var d_head: Vector3 = si[_skel.find_bone("head")] - s0[_skel.find_bone("head")]
	var d_chest: Vector3 = si[_skel.find_bone("chest")] - s0[_skel.find_bone("chest")]
	var d_hips: Vector3 = si[_skel.find_bone("hips")] - s0[_skel.find_bone("hips")]
	match clip:
		"hit_head":
			# the head bone's axis (neck -> crown) tips back (+Z) at impact
			_player.play(&"hit_head")
			_player.seek(0.0, true)
			var tip0: Vector3 = _bone_xform("head").basis.y.normalized()
			_player.seek(float(HIT_ZONES[clip][1]) / 30.0, true)
			var tip: Vector3 = _bone_xform("head").basis.y.normalized()
			_player.stop()
			assert_true(tip.z - tip0.z > 0.15, "hit_head: the head snaps back (%s -> %s)" % [tip0, tip])
		"hit_chest":
			assert_true(d_chest.z > 0.03, "hit_chest: the chest is knocked back (%s)" % d_chest)
		"hit_shoulder_l", "hit_shoulder_r":
			var b: String = "upper_arm.L" if clip.ends_with("l") else "upper_arm.R"
			var o: String = "upper_arm.R" if clip.ends_with("l") else "upper_arm.L"
			var near: float = si[_skel.find_bone(b)].z - s0[_skel.find_bone(b)].z
			var other: float = si[_skel.find_bone(o)].z - s0[_skel.find_bone(o)].z
			assert_true(near > 0.03 and near > other + 0.03, "%s: the hit shoulder goes back (%f vs %f)" % [clip, near, other])
		"hit_leg_l", "hit_leg_r":
			var sx: float = -1.0 if clip.ends_with("l") else 1.0
			assert_true(d_hips.y < -0.05 and d_hips.x * sx > 0.01, "%s: the hips drop toward the hit leg (%s)" % [clip, d_hips])
	assert_true(d_head.length() > 0.02 or clip == "hit_head", "%s: visible at impact (%s)" % [clip, d_head])


func _source_lines() -> Dictionary:
	var lines: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var i: int = line.find(":")
		if i > 0:
			lines[line.substr(0, i)] = line.substr(i + 1)
	return lines


func _bone_xform(bone: String) -> Transform3D:
	return _skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(bone))


## Every bone's position at time `t` of `clip`.
func _snapshot(clip: String, t: float) -> Array[Vector3]:
	_player.play(StringName(clip))
	_player.seek(t, true)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


static func _snap_dist(a: Array[Vector3], b: Array[Vector3]) -> float:
	var worst: float = 0.0
	for i: int in range(a.size()):
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst
