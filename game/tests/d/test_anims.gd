## D1-03: the procedural "humanoid" animation library (char_anim_humanoid). Run after `godot --import`.
## Checks every P1 clip name (and the P2 clips and P3 specials delivered) is present exactly, loop modes for the
## looped clips (the glb marks them with a `-loop` suffix that Godot strips), lengths at 30 fps,
## tracks that target Skeleton3D bones, held poses keeping their constant tracks
## (remove_immutable_tracks=false) and finite values. NPC ambient set (priority 4, heist casting): present, looped,
## events/speeds/prop grips in SOURCE.txt, planted feet, and the props (posed through HandR/Socket + the documented
## `<prop>_grip`) where they belong: the mug level, the mop head on the floor, the phone at the ear, the book in front
## of the reader in bed. Police rappel (QC-41): present, looped, 1 s per hop, speed / axis / `land` in SOURCE.txt, the
## fists on the documented rope line (`rappel_rope`) and the feet world-still on the wall while the root descends.
## P5 NPC set (D3-02, priority 5): present, looped, events / speeds / bpm+beats / prop grips / placement in SOURCE.txt,
## planted feet (every heel / ball / toe-tip contact is still while it touches the floor), the props where they belong
## (rag on the bar, bottle over the glass while pouring, cash in hand, phone in front of the face) and the dances on the beat.
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
## NPC ambient clips (priority 4): civilians and staff of the heists (all looped).
const NPC: Array[String] = [
	"desk_work", "phone_seated", "sit_chair_watch", "mug_idle", "mug_carry_walk", "mop", "sit_bed_read", "idle_thug",
]
const NPC_EVENTS: Dictionary = {"mug_idle": {"sip": 105}, "sit_bed_read": {"page_turn": 221}}
const NPC_FRAMES: Dictionary = {
	"desk_work": 360, "phone_seated": 240, "sit_chair_watch": 300, "mug_idle": 240, "mug_carry_walk": 34, "mop": 120,
	"sit_bed_read": 300, "idle_thug": 105,
}
## P5 NPC ambient clips (D3-02, priority 5): all looped.
const P5: Array[String] = [
	"dance_a", "dance_b", "dance_c", "bartender_wipe", "bartender_pour", "bouncer_idle", "teller_count",
	"curator_inspect", "walk_text", "cower_seated", "cower_stand",
]
const P5_FRAMES: Dictionary = {
	"dance_a": 120, "dance_b": 120, "dance_c": 120, "bartender_wipe": 180, "bartender_pour": 150, "bouncer_idle": 300,
	"teller_count": 240, "curator_inspect": 360, "walk_text": 36, "cower_seated": 90, "cower_stand": 150,
}
const P5_EVENTS: Dictionary = {
	"bartender_pour": {"lift": 2, "pour_start": 39, "pour_end": 77, "set_down": 110},
	"bouncer_idle": {"watch": 222},
	"teller_count": {"count_start": 6, "count_end": 120, "stack_down": 144, "tap_1": 177, "tap_2": 189},
	"curator_inspect": {"step_back_r": 93, "step_back_l": 110, "step_fwd_l": 256, "step_fwd_r": 272},
	"cower_stand": {"flinch_1": 39, "flinch_2": 108},
}
## P5 prop grips (SOURCE.txt `<prop>_grip`; bottle/rag at HandR/Socket, glass/cash at HandL/Socket) and placement notes.
const P5_GRIPS: Dictionary = {"rag_grip": "HandR", "bottle_grip": "HandR", "glass_grip": "HandL", "cash_grip": "HandL"}
const P5_NOTES: Array[String] = [
	"dance_sync", "bar_placement", "teller_counter", "curator_painting", "cower_seated_seat", "cower_stand_space",
	"walk_text_speed", "bouncer_stance",
]
## Dance tempo (SOURCE.txt clip rows `bpm=120 beats=8`): a beat every 15 frames.
const DANCE_BPM: int = 120
const DANCE_BEATS: int = 8
## Furniture heights (SOURCE.txt bar_placement / teller_counter / curator_painting / npc_seat).
const BAR_Z: float = 1.05
const COUNTER_Z: float = 1.0
const PAINT_WALL: float = 0.8
const SEAT_H: float = 0.47
## Police clips (QC-41): the rappel descent loop.
const POLICE: Array[String] = ["rappel"]
## Native descent speed (m/s, SOURCE.txt clip.rappel speed_mps) and the wall-contact frames (feet world-still).
const RAPPEL_SPEED: float = 2.5
const RAPPEL_CONTACT: int = 4
## Held props (SOURCE.txt `<prop>_grip`, relative to HandR/Socket).
const GRIPS: Array[String] = ["phone_grip", "mug_grip", "mop_grip", "book_grip"]
const LOOPED: Array[String] = [
	"idle", "idle_alert", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "strafe_l", "strafe_r",
	"walk_back", "aim_rifle", "aim_pistol", "kneel_cuffed", "hands_up", "cower", "lie_down", "tied",
	"flee", "phone_call", "pager_answer", "investigate_look", "smoke", "lean_wall", "sit_chair",
	"desk_type", "browse", "downed", "tased", "climb_ladder", "carry_bag_walk", "interact_low",
	"interact_mid", "interact_high", "shield_idle", "shield_walk", "dozer_walk", "desk_work", "phone_seated",
	"sit_chair_watch", "mug_idle", "mug_carry_walk", "mop", "sit_bed_read", "idle_thug", "rappel",
]
## Clip -> frames at 30 fps (anim_humanoid.CLIPS).
const FRAMES: Dictionary = {"idle": 120, "walk": 30, "run": 21, "sprint": 18, "crouch_walk": 27,
	"fire_pistol": 9, "fire_rifle": 6, "reload_pistol": 45, "reload_rifle": 72, "death_front": 54,
	"radio_call": 60, "carry_bag_walk": 22, "flee": 20, "kick_charge": 15, "kick_hit": 21, "shield_walk": 28,
	"shield_idle": 108, "shield_bang": 24, "heal_ally": 30, "dozer_walk": 33, "rappel": 30}
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
	assert_eq(names.size(), P1.size() + P2.size() + SPECIALS.size() + NPC.size() + POLICE.size() + P5.size(),
		"no extra or misnamed clips: %s" % [names])
	for n: String in names:
		assert_false(n.ends_with("-loop") or n.ends_with("_loop"), "%s: loop suffix stripped" % n)


func test_loop_modes() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) or P5.has(clip) else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "loop mode of %s" % clip)


func test_lengths() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS + POLICE:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		assert_true(a.length > 0.0, "%s has a length" % clip)
		assert_true(a.length <= 4.01, "%s at most 4 s" % clip)
	for clip: String in NPC:
		var a: Animation = _anim(clip)
		if a != null:
			assert_near(a.length, float(NPC_FRAMES[clip]) / 30.0, 0.002, "%s length" % clip)
			assert_true(a.length <= 12.01, "%s: ambient loop at most 12 s" % clip)
	for clip: String in FRAMES:
		var a: Animation = _anim(clip)
		if a != null:
			assert_near(a.length, float(FRAMES[clip]) / 30.0, 0.002, "%s length" % clip)
	for clip: String in P5:
		var a: Animation = _anim(clip)
		if a != null:
			assert_near(a.length, float(P5_FRAMES[clip]) / 30.0, 0.002, "%s length" % clip)
			assert_true(a.length <= 12.01, "%s: ambient loop at most 12 s" % clip)


func test_tracks_target_skeleton_bones() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5:
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
	for clip: String in LOOPED + P5:
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
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5:
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


# ---------------------------------------------------------------------------------------------
# NPC ambient set (priority 4)
# ---------------------------------------------------------------------------------------------
func _source_lines() -> Dictionary:
	var lines: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var i: int = line.find(":")
		if i > 0:
			lines[line.substr(0, i)] = line.substr(i + 1)
	return lines


## "basis x=(..) y=(..) z=(..) origin=(..)" (SOURCE.txt transform notation) -> Transform3D.
static func _parse_xform(text: String) -> Transform3D:
	var re: RegEx = RegEx.create_from_string("(x|y|z|origin)=\\(([^)]*)\\)")
	var v: Dictionary = {}
	for m: RegExMatch in re.search_all(text):
		var p: PackedStringArray = m.get_string(2).split(",")
		v[m.get_string(1)] = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if v.size() < 4:
		return Transform3D(Basis(), Vector3.INF)
	return Transform3D(Basis(v["x"], v["y"], v["z"]), v["origin"])


func _bone_xform(bone: String) -> Transform3D:
	return _skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(bone))


func _bone_pos(bone: String) -> Vector3:
	return _bone_xform(bone).origin


## World transform of a held prop: hand.R * HandR/Socket offset * `<prop>_grip`.
func _prop_xform(socket: Transform3D, grip: Transform3D) -> Transform3D:
	return _bone_xform("hand.R") * socket * grip


func test_npc_clips_present_looped_with_events_and_grips() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	for clip: String in NPC:
		assert_true(_player.has_animation(StringName(clip)), "NPC clip %s" % clip)
		assert_true(lines.has("clip." + clip), "SOURCE.txt lists clip.%s" % clip)
		assert_true(String(lines.get("loops", "")).contains(clip), "SOURCE.txt loops: lists %s" % clip)
	for clip: String in NPC_EVENTS:
		var want: Dictionary = NPC_EVENTS[clip]
		for ev: String in want:
			assert_true(String(lines.get("clip." + clip, "")).contains("%s@%d" % [ev, int(want[ev])]),
				"%s event %s@%d" % [clip, ev, int(want[ev])])
	assert_true(String(lines.get("clip.mug_carry_walk", "")).contains("speed_mps=1.3"), "mug_carry_walk native 1.3 m/s")
	for g: String in GRIPS:
		assert_true(lines.has(g), "SOURCE.txt documents %s" % g)
		assert_true(_parse_xform(String(lines.get(g, ""))).origin.is_finite(), "%s parses as a transform" % g)


## Seated and in-place standing clips keep both feet planted (no slide) and above the floor.
func test_npc_feet_planted() -> void:
	if not _ready_or_fail():
		return
	for clip: String in ["desk_work", "phone_seated", "sit_chair_watch", "mug_idle", "mop", "sit_bed_read", "idle_thug"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		var first: Dictionary = {}
		var drift: float = 0.0
		var lowest: float = 1.0
		for i: int in range(0, int(round(a.length * 30.0)) + 1, 3):
			_player.seek(float(i) / 30.0, true)
			for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
				var p: Vector3 = _bone_pos(b)
				if not first.has(b):
					first[b] = p
				drift = maxf(drift, p.distance_to(first[b]))
				lowest = minf(lowest, p.y)
		_player.stop()
		assert_true(drift < 0.004, "%s: feet planted (%f m)" % [clip, drift])
		assert_true(lowest > 0.0, "%s: ankles and balls above the floor / mattress (lowest %f)" % [clip, lowest])


## The held props sit where they belong (posed through HandR/Socket + `<prop>_grip`), and Kessler's bed pose.
func test_npc_props_and_bed_pose() -> void:
	if not _ready_or_fail():
		return
	_check_mug()
	_check_mop()
	_check_phone()
	_check_bed()
	_check_thug()


func _check_mug() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get("mug_grip", "")))
	var a: Animation = _anim("mug_carry_walk")
	if a == null or not grip.origin.is_finite():
		fail("mug_carry_walk / mug_grip missing")
		return
	_player.play(&"mug_carry_walk")
	var worst: float = 0.0
	var low: float = 10.0
	var high: float = 0.0
	var feet: float = 1.0
	for i: int in range(35):
		_player.seek(float(i) / 30.0, true)
		var m: Transform3D = _prop_xform(socket, grip)
		worst = maxf(worst, rad_to_deg(m.basis.y.normalized().angle_to(Vector3.UP)))
		low = minf(low, m.origin.y)
		high = maxf(high, m.origin.y)
		for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
			feet = minf(feet, _bone_pos(b).y)
	_player.stop()
	assert_true(worst < 4.0, "mug_carry_walk: the mug stays level (worst tilt %f deg)" % worst)
	assert_true(low > 0.95 and high < 1.25, "mug_carry_walk: mug base at chest height (%f..%f m)" % [low, high])
	assert_true(high - low < 0.03, "mug_carry_walk: carried steadily (%f m bob)" % [high - low])
	assert_true(feet > 0.0, "mug_carry_walk: ankles and balls above the floor (%f)" % feet)
	# mug_idle: at the sip the mug is at the mouth and tipped toward the face
	_player.play(&"mug_idle")
	_player.seek(105.0 / 30.0, true)
	var sip: Transform3D = _prop_xform(socket, grip)
	var head: Vector3 = _bone_pos("head")
	_player.stop()
	assert_true(sip.origin.distance_to(head) < 0.25, "mug_idle: mug at the mouth at sip (%f m)" % sip.origin.distance_to(head))
	var tilt: float = rad_to_deg(sip.basis.y.normalized().angle_to(Vector3.UP))
	assert_true(tilt > 20.0 and tilt < 60.0, "mug_idle: mug tipped to drink (%f deg)" % tilt)


func _check_mop() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get("mop_grip", "")))
	var a: Animation = _anim("mop")
	if a == null or not grip.origin.is_finite():
		fail("mop / mop_grip missing")
		return
	_player.play(&"mop")
	var low: float = 10.0
	var high: float = -10.0
	var xs: Array[float] = []
	for i: int in range(0, 121, 2):
		_player.seek(float(i) / 30.0, true)
		var m: Transform3D = _prop_xform(socket, grip)
		low = minf(low, m.origin.y)
		high = maxf(high, m.origin.y)
		xs.append(m.origin.x)
	_player.stop()
	assert_true(low > -0.01 and high < 0.02, "mop: the head stays on the floor (%f..%f m)" % [low, high])
	assert_true(xs.max() - xs.min() > 0.4, "mop: side-to-side sweep (%f m)" % [xs.max() - xs.min()])


func _check_phone() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get("phone_grip", "")))
	for clip: String in ["phone_call", "phone_seated"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		var worst: float = 0.0
		for i: int in range(0, int(round(a.length * 30.0)) + 1, 10):
			_player.seek(float(i) / 30.0, true)
			var head: Vector3 = _bone_pos("head")
			var phone: Vector3 = _prop_xform(socket, grip).origin
			worst = maxf(worst, phone.distance_to(head))
			assert_true(phone.x > head.x + 0.05, "%s: phone at the right ear (%s vs head %s)" % [clip, phone, head])
		_player.stop()
		assert_true(worst < 0.13, "%s: phone held at the ear (%f m from the head joint)" % [clip, worst])


## Kessler in bed: the body rests on the root plane (the mattress top), legs out in front, the trunk
## reclined against the pillows and the book in front of his face.
func _check_bed() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get("book_grip", "")))
	var a: Animation = _anim("sit_bed_read")
	if a == null:
		fail("sit_bed_read missing")
		return
	_player.play(&"sit_bed_read")
	_player.seek(0.0, true)
	var hips: Vector3 = _bone_pos("hips")
	var neck: Vector3 = _bone_pos("neck")
	var head: Vector3 = _bone_pos("head")
	var book: Vector3 = _prop_xform(socket, grip).origin
	var lowest: float = 10.0
	for i: int in range(0, 301, 10):
		_player.seek(float(i) / 30.0, true)
		for b: int in range(_skel.get_bone_count()):
			lowest = minf(lowest, (_skel.global_transform * _skel.get_bone_global_pose(b)).origin.y)
	_player.seek(0.0, true)
	var ankles: Array[Vector3] = [_bone_pos("foot.L"), _bone_pos("foot.R")]
	_player.stop()
	assert_true(lowest > -0.005, "sit_bed_read: nothing below the mattress (lowest joint %f)" % lowest)
	assert_true(hips.y > 0.05 and hips.y < 0.2, "sit_bed_read: pelvis on the mattress (hips %f m)" % hips.y)
	for p: Vector3 in ankles:
		assert_true(p.z < -0.6 and p.y < 0.15, "sit_bed_read: legs out on the bed (%s)" % p)
	var recline: float = rad_to_deg(atan2(neck.z - hips.z, neck.y - hips.y))
	assert_true(recline > 20.0 and recline < 50.0, "sit_bed_read: trunk reclined (%f deg)" % recline)
	var d: float = book.distance_to(head)
	assert_true(d > 0.2 and d < 0.6 and book.z < head.z, "sit_bed_read: book in front of the face (%f m)" % d)


## idle_thug: the long gun (at HandR/Socket, muzzle = socket -Z) stays low, muzzle down ~30 deg and across the body.
func _check_thug() -> void:
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var a: Animation = _anim("idle_thug")
	if a == null:
		fail("idle_thug missing")
		return
	assert_true(a.length >= 3.0 and a.length <= 4.01, "idle_thug: 3-4 s loop (%f)" % a.length)
	_player.play(&"idle_thug")
	for i: int in range(0, 106, 15):
		_player.seek(float(i) / 30.0, true)
		var w: Transform3D = _bone_xform("hand.R") * socket
		var muzzle: Vector3 = -w.basis.z.normalized()
		var down: float = rad_to_deg(asin(-muzzle.y))
		assert_true(down > 20.0 and down < 42.0, "idle_thug f%d: muzzle down %f deg" % [i, down])
		assert_true(muzzle.x < -0.2 and muzzle.z < 0.0, "idle_thug f%d: muzzle across to the left/front (%s)" % [i, muzzle])
		assert_true(w.origin.y > 0.75 and w.origin.y < 1.1, "idle_thug f%d: gun held low (%f m)" % [i, w.origin.y])
	_player.stop()


## QC-41: the police rappel loop. The fists ride the rope line documented in `rappel_rope` (the guide hand on it, the
## brake hand at the right hip just off it) and the feet stay world-still on the wall for the contact frames while
## ENV A moves the root down at speed_mps.
func test_rappel() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var a: Animation = _anim("rappel")
	if a == null:
		fail("rappel clip missing")
		return
	assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "rappel loops")
	var row: String = String(lines.get("clip.rappel", ""))
	assert_true(row.contains("speed_mps=%s" % RAPPEL_SPEED), "clip.rappel speed_mps=%s (%s)" % [RAPPEL_SPEED, row])
	assert_true(row.contains("travel_axis=down") and row.contains("land@0"), "clip.rappel: travel_axis=down, land@0")
	var rope_doc: String = String(lines.get("rappel_rope", ""))
	var m: RegExMatch = RegEx.create_from_string("line at Godot x=(-?[0-9.]+) z=(-?[0-9.]+)").search(rope_doc)
	if m == null:
		fail("SOURCE.txt rappel_rope gives the rope line (%s)" % rope_doc)
		return
	var rope: Vector2 = Vector2(m.get_string(1).to_float(), m.get_string(2).to_float())
	assert_true(rope.y < -0.1, "the rope is in front of the character (z %f)" % rope.y)
	var sock_r: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var sock_l: Transform3D = _parse_xform(String(lines.get("handl_shield_offset_godot", "")))
	_player.play(&"rappel")
	var worst_l: float = 0.0
	var worst_r: float = 0.0
	var feet0: Dictionary = {}
	var slide: float = 0.0
	for f: int in range(0, 31):
		_player.seek(float(f) / 30.0, true)
		var gl: Vector3 = (_bone_xform("hand.L") * sock_l).origin
		var gr: Vector3 = (_bone_xform("hand.R") * sock_r).origin
		worst_l = maxf(worst_l, Vector2(gl.x, gl.z).distance_to(rope))
		worst_r = maxf(worst_r, Vector2(gr.x, gr.z).distance_to(rope))
		assert_true(gl.y > gr.y + 0.5, "rappel f%d: guide hand high, brake hand low" % f)
		if f <= RAPPEL_CONTACT:
			for b: String in ["toe.L", "toe.R"]:
				# world = root space - the root's descent: constant while the feet are on the wall
				var w: Vector3 = _bone_pos(b) - Vector3(0.0, RAPPEL_SPEED * float(f) / 30.0, 0.0)
				if not feet0.has(b):
					feet0[b] = w
				slide = maxf(slide, w.distance_to(feet0[b]))
	_player.stop()
	assert_true(worst_l < 0.02, "rappel: the guide fist on the rope line (%f m)" % worst_l)
	assert_true(worst_r < 0.16, "rappel: the brake fist by the rope line at the hip (%f m)" % worst_r)
	assert_true(slide < 0.005, "rappel: the feet world-still on the wall during contact (%f m)" % slide)


# ---------------------------------------------------------------------------------------------
# P5 NPC set (D3-02)
# ---------------------------------------------------------------------------------------------
func test_p5_npc_set() -> void:
	if not _ready_or_fail():
		return
	_check_p5_source()
	_check_p5_feet_planted()
	_check_p5_steps_return()
	_check_p5_props_and_placement()
	_check_p5_dances_on_the_beat()


func _check_p5_source() -> void:
	var lines: Dictionary = _source_lines()
	for clip: String in P5:
		assert_true(_player.has_animation(StringName(clip)), "P5 clip %s" % clip)
		assert_true(lines.has("clip." + clip), "SOURCE.txt lists clip.%s" % clip)
		assert_true(String(lines.get("loops", "")).split(",").has(clip), "SOURCE.txt loops: lists %s" % clip)
	for clip: String in P5_EVENTS:
		var want: Dictionary = P5_EVENTS[clip]
		for ev: String in want:
			assert_true(String(lines.get("clip." + clip, "")).contains("%s@%d" % [ev, int(want[ev])]),
				"%s event %s@%d" % [clip, ev, int(want[ev])])
			assert_true(int(want[ev]) < int(P5_FRAMES[clip]), "%s: %s inside the clip" % [clip, ev])
	for clip: String in ["dance_a", "dance_b", "dance_c"]:
		var row: String = String(lines.get("clip." + clip, ""))
		assert_true(row.contains("bpm=%d beats=%d" % [DANCE_BPM, DANCE_BEATS]), "%s: bpm/beats in SOURCE (%s)" % [clip, row])
		# the loop is a whole number of beats at that tempo
		assert_eq(int(P5_FRAMES[clip]) * DANCE_BPM, DANCE_BEATS * 60 * 30, "%s: %d beats at %d BPM" % [clip, DANCE_BEATS, DANCE_BPM])
	assert_true(String(lines.get("clip.walk_text", "")).contains("speed_mps=1.2"), "walk_text native 1.2 m/s")
	for g: String in P5_GRIPS:
		assert_true(_parse_xform(String(lines.get(g, ""))).origin.is_finite(), "%s parses as a transform" % g)
		assert_true(String(lines.get(g, "")).contains("relative to %s/Socket" % P5_GRIPS[g]), "%s on %s" % [g, P5_GRIPS[g]])
	for n: String in P5_NOTES:
		assert_true(lines.has(n), "SOURCE.txt documents %s" % n)


## Ground points (skeleton space, metres) carried by the foot (heel) and the toes (ball, tip): local offsets from the rest.
func _ground_locals() -> Dictionary:
	var out: Dictionary = {}
	for sfx: String in ["L", "R"]:
		var fi: int = _skel.find_bone("foot." + sfx)
		var ti: int = _skel.find_bone("toe." + sfx)
		var fr: Transform3D = _skel.get_bone_global_rest(fi)
		var tr: Transform3D = _skel.get_bone_global_rest(ti)
		var heel: Vector3 = Vector3(fr.origin.x, 0.0, fr.origin.z + 0.05)
		var ball: Vector3 = Vector3(tr.origin.x, 0.0, tr.origin.z)
		var tip: Vector3 = Vector3(tr.origin.x, 0.0, tr.origin.z - 0.068)
		out["heel." + sfx] = [fi, fr.affine_inverse() * heel]
		out["ball." + sfx] = [ti, tr.affine_inverse() * ball]
		out["tip." + sfx] = [ti, tr.affine_inverse() * tip]
	return out


## Every P5 standing / seated clip: a heel, ball or toe tip that touches the floor (y < 4 mm) in two consecutive
## frames does not move: exact in the source (SOURCE.txt check row `contact_slide` < 0.1 mm/frame), and < 4 mm per
## frame after Godot's import keyframe optimizer (it leaves single-frame wobbles of a few mm down the leg chain).
## Nothing goes through the floor, and the clips without steps keep both balls where they are. Dances never leave
## the floor (a ball is always down).
func _check_p5_feet_planted() -> void:
	var checks: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var m: RegExMatch = RegEx.create_from_string("^check\\.\\d+: (\\w+): .*contact_slide=([0-9.]+)mm/f").search(line)
		if m != null:
			checks[m.get_string(1)] = m.get_string(2).to_float()
	var pts: Dictionary = _ground_locals()
	for clip: String in P5:
		if clip == "walk_text":
			continue
		assert_true(checks.has(clip) and float(checks[clip]) < 0.1, "%s: source contact_slide %s mm/frame" % [clip, checks.get(clip)])
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		var prev: Dictionary = {}
		var first: Dictionary = {}
		var slide: float = 0.0
		var drift: float = 0.0
		var lowest: float = 1.0
		var airborne: int = 0
		for f: int in range(int(P5_FRAMES[clip]) + 1):
			_player.seek(float(f) / 30.0, true)
			var lowest_ball: float = 1.0
			for key: String in pts:
				var spec: Array = pts[key]
				var p: Vector3 = _skel.global_transform * _skel.get_bone_global_pose(int(spec[0])) * Vector3(spec[1])
				lowest = minf(lowest, p.y)
				if key.begins_with("ball"):
					lowest_ball = minf(lowest_ball, p.y)
					if not first.has(key):
						first[key] = p
					drift = maxf(drift, p.distance_to(first[key]))
				if prev.has(key) and p.y < 0.004 and Vector3(prev[key]).y < 0.004:
					slide = maxf(slide, Vector2(p.x - Vector3(prev[key]).x, p.z - Vector3(prev[key]).z).length())
				prev[key] = p
			if lowest_ball > 0.01:
				airborne += 1
		_player.stop()
		assert_true(slide < 0.004, "%s: planted contacts do not slide (%f m/frame)" % [clip, slide])
		assert_true(lowest > -0.003, "%s: heels / balls / toes above the floor (%f)" % [clip, lowest])
		assert_eq(airborne, 0, "%s: always a foot on the floor" % clip)
		if not clip in ["dance_a", "curator_inspect"]:
			assert_true(drift < 0.004, "%s: both balls stay put (%f m)" % [clip, drift])


## The stepping clips really step and come back (in place): dance_a (side step-touch) and curator_inspect (back
## and forward again).
func _check_p5_steps_return() -> void:
	for clip: String in ["dance_a", "curator_inspect"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		_player.seek(0.0, true)
		var start: Vector3 = _bone_pos("foot.R")
		var far: float = 0.0
		for f: int in range(0, int(P5_FRAMES[clip]) + 1, 3):
			_player.seek(float(f) / 30.0, true)
			far = maxf(far, _bone_pos("foot.R").distance_to(start))
		_player.seek(a.length, true)
		var back: float = _bone_pos("foot.R").distance_to(start)
		_player.stop()
		assert_true(far > 0.12, "%s: the right foot steps (%f m)" % [clip, far])
		assert_true(back < 0.004, "%s: and returns to its frame-0 plant (%f m)" % [clip, back])


func _hand_prop(lines: Dictionary, prop: String) -> Transform3D:
	var left: bool = P5_GRIPS.get(prop + "_grip", "HandR") == "HandL"
	var socket: Transform3D = _parse_xform(String(lines.get("handl_shield_offset_godot" if left else "handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get(prop + "_grip", "")))
	return _bone_xform("hand.L" if left else "hand.R") * socket * grip


func _check_p5_props_and_placement() -> void:
	var lines: Dictionary = _source_lines()
	# bartender_wipe: the rag lies flat on the bar top, in front, moving in circles
	if _anim("bartender_wipe") != null:
		_player.play(&"bartender_wipe")
		var xs: Array[float] = []
		for f: int in range(0, 181, 5):
			_player.seek(float(f) / 30.0, true)
			var rag: Transform3D = _hand_prop(lines, "rag")
			assert_near(rag.origin.y, BAR_Z, 0.006, "bartender_wipe f%d: rag on the bar top" % f)
			assert_true(rag.basis.y.normalized().dot(Vector3.UP) > 0.99, "bartender_wipe f%d: rag flat" % f)
			assert_true(rag.origin.z < -0.33, "bartender_wipe f%d: rag beyond the bar edge (%f)" % [f, rag.origin.z])
			xs.append(rag.origin.x)
		_player.stop()
		assert_true(xs.max() - xs.min() > 0.15, "bartender_wipe: wiping across (%f m)" % [xs.max() - xs.min()])
	# bartender_pour: bottle upright on the bar at 0 and set_down, mouth over the glass while pouring; glass still
	if _anim("bartender_pour") != null:
		_player.play(&"bartender_pour")
		_player.seek(0.0, true)
		var b0: Transform3D = _hand_prop(lines, "bottle")
		var g0: Transform3D = _hand_prop(lines, "glass")
		assert_near(b0.origin.y, BAR_Z, 0.004, "bartender_pour: bottle on the bar at frame 0")
		assert_near(g0.origin.y, BAR_Z, 0.004, "bartender_pour: glass on the bar")
		assert_true(b0.basis.y.normalized().dot(Vector3.UP) > 0.995, "bartender_pour: bottle upright at frame 0")
		for f: int in range(0, 151, 3):
			_player.seek(float(f) / 30.0, true)
			var b: Transform3D = _hand_prop(lines, "bottle")
			var g: Transform3D = _hand_prop(lines, "glass")
			assert_true(g.origin.distance_to(g0.origin) < 0.004, "bartender_pour f%d: the glass stays put" % f)
			if f >= 39 and f <= 77:
				var mouth: Vector3 = b * Vector3(0.0, 0.30, 0.0)
				var rim: Vector3 = g0.origin + Vector3(0.0, 0.10, 0.0)
				assert_true(mouth.y > rim.y + 0.02 and mouth.y < rim.y + 0.1, "bartender_pour f%d: mouth above the rim" % f)
				assert_true(Vector2(mouth.x - rim.x, mouth.z - rim.z).length() < 0.04, "bartender_pour f%d: mouth over the glass" % f)
				assert_true(rad_to_deg(b.basis.y.normalized().angle_to(Vector3.UP)) > 99.0, "bartender_pour f%d: tipped to pour" % f)
		_player.seek(110.0 / 30.0, true)
		var b1: Transform3D = _hand_prop(lines, "bottle")
		_player.stop()
		assert_true(b1.origin.distance_to(b0.origin) < 0.004, "bartender_pour: set back down where it stood")
	# teller_count: the stack in the left hand above the counter, in front
	if _anim("teller_count") != null:
		_player.play(&"teller_count")
		for f: int in range(0, 241, 6):
			_player.seek(float(f) / 30.0, true)
			var cash: Transform3D = _hand_prop(lines, "cash")
			assert_true(cash.origin.y > COUNTER_Z + 0.03 and cash.origin.y < 1.3, "teller_count f%d: stack above the counter" % f)
			assert_true(cash.origin.z < -0.25, "teller_count f%d: stack in front (%f)" % [f, cash.origin.z])
		_player.stop()
	# walk_text: the phone in front of the chest, screen toward the (lowered) face
	if _anim("walk_text") != null:
		_player.play(&"walk_text")
		for f: int in range(0, 37, 4):
			_player.seek(float(f) / 30.0, true)
			var ph: Transform3D = _hand_prop(lines, "phone")
			var head: Vector3 = _bone_pos("head")
			assert_true(ph.origin.y > 1.0 and ph.origin.y < 1.3 and ph.origin.z < -0.15, "walk_text f%d: phone at the chest (%s)" % [f, ph.origin])
			assert_true(ph.basis.z.normalized().dot((head - ph.origin).normalized()) > 0.7, "walk_text f%d: screen toward the face" % f)
		_player.stop()
	# cower_seated: the pelvis on the seat; curator_inspect: never into the wall
	if _anim("cower_seated") != null:
		_player.play(&"cower_seated")
		_player.seek(0.0, true)
		var hips: Vector3 = _bone_pos("hips")
		var head: Vector3 = _bone_pos("head")
		_player.stop()
		assert_true(hips.y > SEAT_H + 0.03 and hips.y < SEAT_H + 0.12, "cower_seated: on the seat (hips %f)" % hips.y)
		assert_true(head.y < 1.05, "cower_seated: curled forward (head %f)" % head.y)
	if _anim("curator_inspect") != null:
		_player.play(&"curator_inspect")
		var nearest: float = 10.0
		for f: int in range(0, 361, 6):
			_player.seek(float(f) / 30.0, true)
			nearest = minf(nearest, _bone_pos("head").z + PAINT_WALL)
		_player.stop()
		assert_true(nearest > 0.3 and nearest < 0.75, "curator_inspect: leans in close to the painting (%f m)" % nearest)
	# dance_c: both hands above the head at every frame
	if _anim("dance_c") != null:
		_player.play(&"dance_c")
		for f: int in range(0, 121, 5):
			_player.seek(float(f) / 30.0, true)
			var top: float = _bone_pos("head").y
			assert_true(_bone_pos("hand.L").y > top and _bone_pos("hand.R").y > top, "dance_c f%d: arms up" % f)
		_player.stop()


## Dances are beat-synced: the hips are lowest within 4 frames after each beat (every 15 f), every beat.
func _check_p5_dances_on_the_beat() -> void:
	for clip: String in ["dance_a", "dance_b", "dance_c"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		_player.play(StringName(clip))
		var ys: Array[float] = []
		for f: int in range(121):
			_player.seek(float(f) / 30.0, true)
			ys.append(_bone_pos("hips").y)
		_player.stop()
		for beat: int in range(DANCE_BEATS):
			var lo: int = beat * 15 - 5
			var best: int = lo
			for f: int in range(lo, lo + 15):
				if ys[posmod(f, 120)] < ys[posmod(best, 120)]:
					best = f
			var off: int = best - beat * 15
			assert_true(off >= -1 and off <= 4, "%s beat %d: hips lowest %d f after the beat" % [clip, beat + 1, off])
