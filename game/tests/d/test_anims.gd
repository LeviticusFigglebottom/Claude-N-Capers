## D1-03: the procedural "humanoid" animation library (char_anim_humanoid). Run after `godot --import`.
## Checks every P1 clip name (and the P2 clips delivered) is present exactly, loop modes for the
## looped clips (the glb marks them with a `-loop` suffix that Godot strips), lengths at 30 fps,
## tracks that target Skeleton3D bones, held poses keeping their constant tracks
## (remove_immutable_tracks=false) and finite values.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
## Priority 1 subset (roadmap C1-05 / D1-03).
const P1: Array[String] = [
	"idle", "walk", "run", "crouch_idle", "crouch_walk", "aim_pistol", "aim_rifle", "fire_pistol",
	"fire_rifle", "reload_pistol", "reload_rifle", "death_front", "death_back", "hit_react", "cower",
	"hands_up", "lie_down", "tied", "flee", "phone_call", "radio_call", "pager_answer", "downed",
	"carry_bag_walk", "throw_bag", "interact_low", "interact_mid", "interact_high",
]
## Priority 2 clips delivered by D1-03.
const P2: Array[String] = [
	"idle_alert", "sprint", "strafe_l", "strafe_r", "walk_back", "turn_l", "turn_r", "surrender",
	"kneel_cuffed", "melee", "investigate_look", "smoke", "lean_wall", "sit_chair", "desk_type",
	"browse", "drill_place", "climb_ladder", "tased",
]
const LOOPED: Array[String] = [
	"idle", "idle_alert", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "strafe_l", "strafe_r",
	"walk_back", "aim_rifle", "aim_pistol", "kneel_cuffed", "hands_up", "cower", "lie_down", "tied",
	"flee", "phone_call", "pager_answer", "investigate_look", "smoke", "lean_wall", "sit_chair",
	"desk_type", "browse", "downed", "tased", "climb_ladder", "carry_bag_walk", "interact_low",
	"interact_mid", "interact_high",
]
## Clip -> frames at 30 fps (anim_humanoid.CLIPS).
const FRAMES: Dictionary = {"idle": 120, "walk": 30, "run": 21, "sprint": 18, "crouch_walk": 27,
	"fire_pistol": 9, "fire_rifle": 6, "reload_pistol": 45, "reload_rifle": 72, "death_front": 54,
	"radio_call": 60, "carry_bag_walk": 22, "flee": 20}

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


func _ready_or_fail() -> bool:
	if _root == null:
		fail("could not load %s (run godot --import first)" % GLB)
		return false
	if _player == null or _skel == null:
		fail("no AnimationPlayer / rig_humanoid/Skeleton3D in %s" % GLB)
		return false
	return true


func _anim(clip: String) -> Animation:
	return _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null


func test_every_p1_clip_is_present() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1:
		assert_true(_player.has_animation(StringName(clip)), "P1 clip %s" % clip)


func test_delivered_p2_clips_are_present() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P2:
		assert_true(_player.has_animation(StringName(clip)), "P2 clip %s" % clip)
	var names: PackedStringArray = _player.get_animation_list()
	assert_eq(names.size(), P1.size() + P2.size(), "no extra or misnamed clips: %s" % [names])
	for n: String in names:
		assert_false(n.ends_with("-loop") or n.ends_with("_loop"), "%s: loop suffix stripped" % n)


func test_loop_modes() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "loop mode of %s" % clip)


func test_lengths() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		assert_true(a.length > 0.0, "%s has a length" % clip)
		assert_true(a.length <= 4.01, "%s at most 4 s" % clip)
	for clip: String in FRAMES:
		var a: Animation = _anim(clip)
		if a != null:
			assert_near(a.length, float(FRAMES[clip]) / 30.0, 0.002, "%s length" % clip)


func test_tracks_target_skeleton_bones() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var rot_tracks: int = 0
		for t: int in range(a.get_track_count()):
			var path: NodePath = a.track_get_path(t)
			var node: Node = _player.get_node(_player.root_node).get_node_or_null(NodePath(String(path.get_concatenated_names())))
			assert_true(node is Skeleton3D, "%s: track %s targets a Skeleton3D" % [clip, path])
			var bone: String = String(path.get_concatenated_subnames())
			assert_true(_skel.find_bone(bone) >= 0, "%s: bone %s exists" % [clip, bone])
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot_tracks += 1
		# held poses keep constant tracks (remove_immutable_tracks=false): every bone but root rotates
		assert_true(rot_tracks >= 51, "%s: %d rotation tracks" % [clip, rot_tracks])


func test_loops_end_on_their_first_pose() -> void:
	if not _ready_or_fail():
		return
	for clip: String in LOOPED:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		for t: int in range(a.get_track_count()):
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(t) < 2:
				continue
			var q0: Quaternion = a.track_get_key_value(t, 0)
			var q1: Quaternion = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
			assert_true(absf(q0.dot(q1)) > 0.9999, "%s: %s first == last" % [clip, a.track_get_path(t)])


func test_values_are_finite_without_flips() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		for t: int in range(a.get_track_count()):
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var prev: Quaternion = Quaternion.IDENTITY
			for k: int in range(a.track_get_key_count(t)):
				var q: Quaternion = a.track_get_key_value(t, k)
				if not q.is_finite():
					fail("%s: non-finite key in %s" % [clip, a.track_get_path(t)])
					break
				# the glTF exporter may negate whole quaternions (same rotation; Godot slerps the short way),
				# so a joint flip is a big rotation between consecutive frames, not a sign change
				if k > 0 and rad_to_deg(2.0 * acos(minf(1.0, absf(q.dot(prev))))) > 60.0:
					fail("%s: joint flip in %s at key %d" % [clip, a.track_get_path(t), k])
					break
				prev = q


func test_walk_feet_stay_above_floor() -> void:
	if not _ready_or_fail():
		return
	var a: Animation = _anim("walk")
	if a == null:
		return
	_player.play(&"walk")
	var lowest: float = 1.0
	for i: int in range(31):
		_player.seek(float(i) / 30.0, true)
		for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
			var y: float = (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin.y
			lowest = minf(lowest, y)
	_player.stop()
	assert_true(lowest > 0.0, "walk: ankles and balls stay above the floor (lowest %f)" % lowest)
