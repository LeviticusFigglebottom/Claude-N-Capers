## D1-03: the procedural "humanoid" animation library (char_anim_humanoid). Run after `godot --import`.
## Checks every P1 clip name (and the P2 clips and P3 specials delivered) is present exactly, loop modes for the
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
## P3 special-enemy clips (Phantom kick, Bulwark shield, Corpsman heal, Wrecker walk).
const SPECIALS: Array[String] = [
	"kick_charge", "kick_hit", "shield_idle", "shield_walk", "shield_bang", "heal_ally", "dozer_walk",
]
const LOOPED: Array[String] = [
	"idle", "idle_alert", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "strafe_l", "strafe_r",
	"walk_back", "aim_rifle", "aim_pistol", "kneel_cuffed", "hands_up", "cower", "lie_down", "tied",
	"flee", "phone_call", "pager_answer", "investigate_look", "smoke", "lean_wall", "sit_chair",
	"desk_type", "browse", "downed", "tased", "climb_ladder", "carry_bag_walk", "interact_low",
	"interact_mid", "interact_high", "shield_idle", "shield_walk", "dozer_walk",
]
## Clip -> frames at 30 fps (anim_humanoid.CLIPS).
const FRAMES: Dictionary = {"idle": 120, "walk": 30, "run": 21, "sprint": 18, "crouch_walk": 27,
	"fire_pistol": 9, "fire_rifle": 6, "reload_pistol": 45, "reload_rifle": 72, "death_front": 54,
	"radio_call": 60, "carry_bag_walk": 22, "flee": 20, "kick_charge": 15, "kick_hit": 21, "shield_walk": 28,
	"shield_idle": 108, "shield_bang": 24, "heal_ally": 30, "dozer_walk": 33}
## Contract-listed event frames of the specials (SOURCE.txt `clip.<name>: ... events=`): ENV A syncs to them.
const SPECIAL_EVENTS: Dictionary = {
	"kick_hit": {"impact": 6}, "shield_bang": {"bang_1": 6, "bang_2": 12, "bang_3": 18},
	"heal_ally": {"heal": 12}, "dozer_walk": {"step_r": 0, "step_l": 16},
}
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## Native speeds (m/s at 1.78 m) of the special locomotion loops.
const SPECIAL_SPEEDS: Dictionary = {"shield_walk": 1.6, "dozer_walk": 1.6}

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
	assert_eq(names.size(), P1.size() + P2.size() + SPECIALS.size(), "no extra or misnamed clips: %s" % [names])
	for n: String in names:
		assert_false(n.ends_with("-loop") or n.ends_with("_loop"), "%s: loop suffix stripped" % n)


func test_loop_modes() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "loop mode of %s" % clip)


func test_lengths() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS:
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
	for clip: String in P1 + P2 + SPECIALS:
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
	for clip: String in P1 + P2 + SPECIALS:
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


func test_special_clips_are_present() -> void:
	if not _ready_or_fail():
		return
	for clip: String in SPECIALS:
		assert_true(_player.has_animation(StringName(clip)), "P3 special clip %s" % clip)


func test_special_events_and_speeds_in_source() -> void:
	var text: String = FileAccess.get_file_as_string(SOURCE)
	assert_true(not text.is_empty(), "read %s" % SOURCE)
	var lines: Dictionary = {}
	for line: String in text.split("\n"):
		if line.begins_with("clip."):
			lines[line.get_slice(":", 0).trim_prefix("clip.")] = line
	for clip: String in SPECIALS:
		assert_true(lines.has(clip), "SOURCE.txt lists clip.%s" % clip)
	for clip: String in SPECIAL_EVENTS:
		var want: Dictionary = SPECIAL_EVENTS[clip]
		for ev: String in want:
			var frame: int = int(want[ev])
			assert_true(String(lines.get(clip, "")).contains("%s@%d" % [ev, frame]), "%s event %s@%d" % [clip, ev, frame])
			var a: Animation = _anim(clip) if _player != null else null
			if a != null:
				assert_true(float(frame) / 30.0 <= a.length + 0.001, "%s: %s inside the clip" % [clip, ev])
	for clip: String in SPECIAL_SPEEDS:
		assert_true(String(lines.get(clip, "")).contains("speed_mps=%s" % str(SPECIAL_SPEEDS[clip])),
			"%s native speed %s m/s" % [clip, SPECIAL_SPEEDS[clip]])
	var loops: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("loops:"):
			loops = line
	for clip: String in ["shield_idle", "shield_walk", "dozer_walk"]:
		assert_true(loops.contains(clip), "SOURCE.txt loops: lists %s" % clip)


func test_kick_hit_is_airborne_at_impact() -> void:
	if not _ready_or_fail():
		return
	var a: Animation = _anim("kick_hit")
	if a == null:
		return
	_player.play(&"kick_hit")
	var low: float = 10.0
	for i: int in range(22):
		_player.seek(float(i) / 30.0, true)
		if i == 6:
			for b: String in ["foot.L", "foot.R"]:
				var y: float = (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin.y
				assert_true(y > 0.2, "kick_hit: %s off the floor at the impact (%f)" % [b, y])
			var kick: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone("foot.R"))).origin
			assert_true(kick.z < -0.7 and kick.y > 0.8, "kick_hit: right foot out in front at hip height (%s)" % kick)
		for b: String in ["toe.L", "toe.R"]:
			low = minf(low, (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin.y)
	_player.stop()
	assert_true(low > 0.0, "kick_hit: toes stay above the floor (lowest %f)" % low)


func test_special_walks_keep_feet_above_floor() -> void:
	if not _ready_or_fail():
		return
	for clip: String in ["shield_walk", "dozer_walk"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		var lowest: float = 1.0
		var n: int = int(round(a.length * 30.0))
		for i: int in range(n + 1):
			_player.seek(float(i) / 30.0, true)
			for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
				lowest = minf(lowest, (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin.y)
		_player.stop()
		assert_true(lowest > 0.0, "%s: ankles and balls stay above the floor (lowest %f)" % [clip, lowest])


## shield_idle (the Bulwark's braced stand): both feet stay planted on the floor (no slide) and the
## left fist on the shield handle and the pistol hand barely move, at shield_walk's upper-body pose.
func test_shield_idle_is_planted_and_matches_shield_walk() -> void:
	if not _ready_or_fail():
		return
	var a: Animation = _anim("shield_idle")
	if a == null:
		fail("shield_idle missing")
		return
	assert_true(a.length >= 3.0 and a.length <= 4.01, "shield_idle: 3-4 s (%f)" % a.length)
	var bones: Array[String] = ["foot.L", "foot.R", "toe.L", "toe.R", "hand.L", "hand.R"]
	var first: Dictionary = {}
	var drift: Dictionary = {}
	var lowest: float = 1.0
	var highest_toe: float = 0.0
	_player.play(&"shield_idle")
	var n: int = int(round(a.length * 30.0))
	for i: int in range(n + 1):
		_player.seek(float(i) / 30.0, true)
		for b: String in bones:
			var p: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin
			if i == 0:
				first[b] = p
				drift[b] = 0.0
			drift[b] = maxf(float(drift[b]), p.distance_to(first[b]))
			if b.begins_with("foot") or b.begins_with("toe"):
				lowest = minf(lowest, p.y)
			if b.begins_with("toe"):
				highest_toe = maxf(highest_toe, p.y)
	_player.stop()
	assert_true(lowest > 0.0, "shield_idle: ankles and balls above the floor (lowest %f)" % lowest)
	assert_true(highest_toe < 0.05, "shield_idle: balls of the feet on the floor (highest %f)" % highest_toe)
	# exact in the source (0 mm); Godot's import keyframe optimizer leaves up to ~2 mm of jitter
	for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
		assert_true(float(drift[b]) < 0.003, "shield_idle: %s planted, no slide (%f m)" % [b, drift[b]])
	for b: String in ["hand.L", "hand.R"]:
		assert_true(float(drift[b]) < 0.03, "shield_idle: %s steady (%f m)" % [b, drift[b]])
	var stance: float = absf(Vector3(first["foot.L"]).x - Vector3(first["foot.R"]).x)
	assert_true(stance > 0.3, "shield_idle: wide braced stance (%f m between the ankles)" % stance)
	# the hands sit where shield_walk holds the shield and the pistol (so A can blend the two)
	var walk: Animation = _anim("shield_walk")
	if walk == null:
		return
	_player.play(&"shield_walk")
	_player.seek(0.0, true)
	for b: String in ["hand.L", "hand.R"]:
		var p: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(b))).origin
		assert_true(p.distance_to(first[b]) < 0.03, "shield_idle: %s at shield_walk's grip (%f m)" % [b, p.distance_to(first[b])])
	_player.stop()
