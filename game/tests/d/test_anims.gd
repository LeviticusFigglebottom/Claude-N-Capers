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
## D3-04 polish (priority 6): 8-way walk / run sets phase-locked to walk / run (left foot down at the same normalised
## time +-1 frame, speeds / directions in SOURCE.txt and matching the planted feet), start / stop transitions (hand-off
## frames equal the cycle / idle pose, planted feet still at the documented root curve), directional hit reacts, death
## variants ending on the floor, the downed crawl (palms planted at 0.3 m/s) and the heavy Wrecker stomp.
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
	"idle_alert", "sprint", "strafe_l", "strafe_r", "walk_back", "turn_l", "turn_r", "turn_l_45", "turn_r_45", "surrender",
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
const GRIPS: Array[String] = ["phone_grip", "mug_grip", "mop_grip", "book_grip", "cigarette_grip"]
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
## D3-04 polish set (priority 6).
const D304_DIRS: Dictionary = {"fl": -45.0, "fr": 45.0, "l": -90.0, "r": 90.0, "bl": -135.0, "br": 135.0, "b": 180.0}
const D304_GAITS: Dictionary = {"walk": [30, 1.6], "run": [21, 3.5]}
const D304_ONESHOTS: Dictionary = {
	"walk_start": 18, "walk_stop": 18, "run_start": 18, "run_stop": 20, "hit_react_back": 15, "hit_react_left": 15,
	"hit_react_right": 15, "death_front_b": 60, "death_back_b": 60, "death_side": 60,
	"death_seated_slump": 48, "death_seated_fall": 60, "death_crouch": 45, "death_kneel_cuffed": 45, "death_kneel": 45,
	"death_prone": 30, "death_downed": 36,
}
const D304_LOOPS: Dictionary = {"downed_crawl": 60, "dozer_walk_heavy": 33}
const D304_EVENTS: Dictionary = {
	"walk_start": {"step_r": 15}, "walk_stop": {"step_l": 14}, "run_start": {"step_r": 14},
	"run_stop": {"step_l": 6, "step_r": 17}, "death_front_b": {"knees": 16, "impact": 38},
	"death_back_b": {"step_r": 12, "step_l": 21, "impact": 44}, "death_side": {"impact": 36},
	"death_seated_slump": {"impact": 22}, "death_seated_fall": {"impact": 34},
	"death_crouch": {"impact": 26}, "death_kneel_cuffed": {"impact": 24}, "death_kneel": {"impact": 24},
	"death_prone": {"impact": 3}, "death_downed": {"impact": 20},
	"dozer_walk_heavy": {"step_r": 0, "step_l": 16},
}
## PO6-18 pose-aware deaths: clip -> [source clip, source time (s)] its frame 0 equals (surrender: its last frame).
const POSE_DEATHS: Dictionary = {
	"death_crouch": ["crouch_idle", 0.0], "death_kneel_cuffed": ["kneel_cuffed", 0.0], "death_kneel": ["surrender", 1.6],
	"death_prone": ["lie_down", 0.0], "death_downed": ["downed", 0.0],
}
## PO6-17 assault-event clips (_anim_assault): clip -> [frames, looped, events, [clip, time] frame 0 equals, clip whose
## frame 0 the last frame equals].
const ASSAULT: Dictionary = {
	"rappel_hang": [40, true, {}, [], ""], "rappel_descend": [20, true, {}, [], ""],
	"rappel_land": [30, false, {"touch": 6}, ["rappel_descend", 0.0], "idle_alert"],
	"heli_door_idle": [90, true, {}, [], ""], "heli_door_aim": [90, true, {}, [], ""],
	"heli_door_fire": [6, false, {"shot": 0}, [], ""],
	"van_exit": [36, false, {"step_r": 16, "step_l": 28}, [], "idle_alert"],
	"breach_place": [45, false, {"place": 28}, ["idle_alert", 0.0], "idle_alert"],
	"breach_standback": [30, false, {}, ["breach_place", 1.5], "crouch_idle"],
}
## Start / stop: the cycle frame each one hands over to / from (SOURCE.txt handoff_frame).
const D304_HANDOFF: Dictionary = {"walk_start": 3, "walk_stop": 0, "run_start": 4, "run_stop": 0}
const CRAWL_SPEED: float = 0.3
const HEAVY_SPEED: float = 1.7

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
	assert_eq(names.size(), P1.size() + P2.size() + SPECIALS.size() + NPC.size() + POLICE.size() + P5.size() + _d304().size()
		+ _assault().size() + 22 + preload("res://tests/d/test_surrender_variants.gd").VARIANTS.size() + 15 + 48 + 23
		+ preload("res://tests/d/test_civ_panic.gd").VARIANTS.size() + 26, "no extra or misnamed clips: %s" % [names])  # OF5RT7id4rv8p1AH1
	for n: String in names:
		assert_false(n.ends_with("-loop") or n.ends_with("_loop"), "%s: loop suffix stripped" % n)


func test_loop_modes() -> void:
	if not _ready_or_fail():
		return
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5 + _d304() + _assault():
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) or P5.has(clip) or _d304_loops().has(clip) \
			or _assault(true).has(clip) else Animation.LOOP_NONE
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
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5 + _d304() + _assault():
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
	for clip: String in LOOPED + P5 + _d304_loops() + _assault(true):
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
	for clip: String in P1 + P2 + SPECIALS + NPC + POLICE + P5 + _d304() + _assault():
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


func _check_special_clips_present() -> void:
	if not _ready_or_fail():
		return
	for clip: String in SPECIALS:
		assert_true(_player.has_animation(StringName(clip)), "P3 special clip %s" % clip)


func test_special_events_and_speeds_in_source() -> void:
	_check_special_clips_present()
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


# ---------------------------------------------------------------------------------------------
# D3-04 polish set
# ---------------------------------------------------------------------------------------------
## The D3-04 set: presence and SOURCE facts, 8-way phase lock / speed / direction, start / stop hand-offs, hit reacts,
## deaths, the downed crawl and the heavy Wrecker gait (one public test: the checks are the private _check_d304_* below).
func test_d304_polish_set() -> void:
	if not _ready_or_fail():
		return
	_check_d304_present_with_source_facts()
	_check_d304_8way_phase_locked()
	_check_d304_8way_speed_and_direction()
	_check_d304_start_stop()
	_check_d304_hit_reacts()
	_check_d304_deaths_end_on_the_floor()
	_check_seated_deaths()
	_check_pose_deaths()
	_check_d304_crawl_and_heavy_gait()
	_check_assault_clips()


func _d304_8way() -> Array[String]:
	var out: Array[String] = []
	for g: String in D304_GAITS:
		for s: String in D304_DIRS:
			out.append("%s_%s" % [g, s])
	return out


func _d304_loops() -> Array[String]:
	var out: Array[String] = _d304_8way()
	for c: String in D304_LOOPS:
		out.append(c)
	return out


func _d304() -> Array[String]:
	var out: Array[String] = _d304_loops()
	for c: String in D304_ONESHOTS:
		out.append(c)
	return out


func _d304_frames(clip: String) -> int:
	if D304_ONESHOTS.has(clip):
		return int(D304_ONESHOTS[clip])
	if D304_LOOPS.has(clip):
		return int(D304_LOOPS[clip])
	return int(D304_GAITS[clip.get_slice("_", 0)][0])


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


## Heel / ball / toe-tip points of both feet at the current pose: key -> position.
func _contacts(pts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in pts:
		var spec: Array = pts[key]
		out[key] = _skel.global_transform * _skel.get_bone_global_pose(int(spec[0])) * Vector3(spec[1])
	return out


## SOURCE.txt `check.NN: <clip>: ...` rows by clip.
func _check_rows() -> Dictionary:
	var out: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var m: RegExMatch = RegEx.create_from_string("^check\\.\\d+: (\\w+): (.*)$").search(line)
		if m != null:
			out[m.get_string(1)] = m.get_string(2)
	return out


static func _num(row: String, key: String) -> float:
	var m: RegExMatch = RegEx.create_from_string(key + "=(-?[0-9.]+)").search(row)
	return m.get_string(1).to_float() if m != null else INF


func _check_d304_present_with_source_facts() -> void:
	var lines: Dictionary = _source_lines()
	var checks: Dictionary = _check_rows()
	var loops: PackedStringArray = String(lines.get("loops", "")).split(",")
	for clip: String in _d304():
		assert_true(_player.has_animation(StringName(clip)), "D3-04 clip %s" % clip)
		var row: String = String(lines.get("clip." + clip, ""))
		assert_true(not row.is_empty(), "SOURCE.txt lists clip.%s" % clip)
		assert_eq(loops.has(clip), _d304_loops().has(clip), "%s: in SOURCE loops iff looped" % clip)
		var a: Animation = _anim(clip)
		if a != null:
			assert_near(a.length, float(_d304_frames(clip)) / 30.0, 0.002, "%s length" % clip)
	for g: String in D304_GAITS:
		for s: String in D304_DIRS:
			var clip: String = "%s_%s" % [g, s]
			var row: String = String(lines.get("clip." + clip, ""))
			assert_true(row.contains("speed_mps=%s" % str(D304_GAITS[g][1])), "%s speed %s (%s)" % [clip, D304_GAITS[g][1], row])
			assert_eq(_num(row, "dir_deg"), float(D304_DIRS[s]), "%s dir_deg" % clip)
			assert_true(row.contains("foot_down=R@0.00,L@0.50"), "%s: foot_down documented" % clip)
			assert_true(_num(String(checks.get(clip, "")), "slide") < 0.1, "%s: source slide %s" % [clip, checks.get(clip)])
	for clip: String in D304_EVENTS:
		var want: Dictionary = D304_EVENTS[clip]
		for ev: String in want:
			assert_true(String(lines.get("clip." + clip, "")).contains("%s@%d" % [ev, int(want[ev])]),
				"%s event %s@%d" % [clip, ev, int(want[ev])])
			assert_true(int(want[ev]) <= _d304_frames(clip), "%s: %s inside the clip" % [clip, ev])
	for clip: String in D304_HANDOFF:
		assert_eq(int(_num(String(lines.get("clip." + clip, "")), "handoff_frame")), int(D304_HANDOFF[clip]),
			"%s handoff frame" % clip)
		var row: String = String(checks.get(clip, ""))
		assert_true(_num(row, "slide") < 0.1, "%s: planted feet in the source (%s)" % [clip, row])
		assert_true(_num(row, "handoff_err") < 0.1 and _num(row, "idle0_err") < 0.1, "%s: exact hand-off in the source" % clip)
	assert_true(String(lines.get("clip.downed_crawl", "")).contains("speed_mps=%s" % CRAWL_SPEED), "downed_crawl speed")
	assert_true(_num(String(checks.get("downed_crawl", "")), "palm_slide") < 0.1, "downed_crawl: palms planted in the source")
	assert_true(String(lines.get("clip.dozer_walk_heavy", "")).contains("speed_mps=%s" % HEAVY_SPEED), "dozer_walk_heavy speed")
	assert_true(_num(String(checks.get("dozer_walk_heavy", "")), "slide") < 0.1, "dozer_walk_heavy: planted feet")
	for n: String in ["locomotion_blend", "locomotion_transitions", "hit_react_dirs", "death_variants", "death_end_poses",
			"downed_crawl_pose", "dozer_walk_heavy_speed", "pose_deaths", "pose_death_checks"]:
		assert_true(lines.has(n), "SOURCE.txt documents %s" % n)


## Per frame: the height of each foot's lowest contact (heel / ball / toe tip) and the lowest of all.
func _foot_heights(clip: String, frames: int) -> Dictionary:
	var pts: Dictionary = _ground_locals()
	var hl: Array[float] = []
	var hr: Array[float] = []
	var low: float = 1.0
	_player.play(StringName(clip))
	for f: int in range(frames + 1):
		_player.seek(float(f) / 30.0, true)
		var c: Dictionary = _contacts(pts)
		var l: float = minf(Vector3(c["heel.L"]).y, minf(Vector3(c["ball.L"]).y, Vector3(c["tip.L"]).y))
		var r: float = minf(Vector3(c["heel.R"]).y, minf(Vector3(c["ball.R"]).y, Vector3(c["tip.R"]).y))
		hl.append(l)
		hr.append(r)
		low = minf(low, minf(l, r))
	_player.stop()
	return {"L": hl, "R": hr, "low": low}


## Touch-down frames of a loop: on the floor (< 3 mm) after a frame in the air.
static func _touchdowns(h: Array[float], frames: int) -> Array[int]:
	var out: Array[int] = []
	for f: int in range(frames):
		if h[f] < 0.003 and h[posmod(f - 1, frames)] >= 0.003:
			out.append(f)
	return out


## The 8-way cycles are phase-locked to walk / run: one touch-down per foot per loop, the right foot at normalised
## time 0 and the left at 0.5 (+-1 frame) in every direction, like the forward clip; nothing below the floor.
func _check_d304_8way_phase_locked() -> void:
	for g: String in D304_GAITS:
		var n: int = int(D304_GAITS[g][0])
		var clips: Array[String] = [g]
		for s: String in D304_DIRS:
			clips.append("%s_%s" % [g, s])
		for clip: String in clips:
			if _anim(clip) == null:
				continue
			var hs: Dictionary = _foot_heights(clip, n)
			var r: Array[int] = _touchdowns(hs["R"], n)
			var l: Array[int] = _touchdowns(hs["L"], n)
			assert_eq(r.size(), 1, "%s: one right touch-down per loop %s" % [clip, r])
			assert_eq(l.size(), 1, "%s: one left touch-down per loop %s" % [clip, l])
			if r.size() == 1:
				var dr: int = mini(r[0], n - r[0])
				assert_true(dr <= 1, "%s: right foot down at normalised 0 (frame %d of %d)" % [clip, r[0], n])
			if l.size() == 1:
				assert_true(absf(float(l[0]) - 0.5 * float(n)) <= 1.0, "%s: left foot down at normalised 0.5 (frame %d of %d)" % [clip, l[0], n])
			if clip != g:
				# 0 mm in the source; Godot's import keyframe optimizer leaves a few mm on the fast foot roll
				assert_true(float(hs["low"]) > -0.006, "%s: heels / balls / toes above the floor (%f)" % [clip, hs["low"]])


## The planted foot moves at -speed along the documented direction (root space): what SOURCE.txt says is the speed and
## direction of the clip (+-4 %, +-3 deg), measured on the contact point that stays on the floor between frames.
func _check_d304_8way_speed_and_direction() -> void:
	var pts: Dictionary = _ground_locals()
	for g: String in D304_GAITS:
		var n: int = int(D304_GAITS[g][0])
		var v: float = float(D304_GAITS[g][1])
		for s: String in D304_DIRS:
			var clip: String = "%s_%s" % [g, s]
			if _anim(clip) == null:
				continue
			var a: float = deg_to_rad(float(D304_DIRS[s]))
			var want: Vector3 = -Vector3(sin(a), 0.0, -cos(a)) * v / 30.0
			var prev: Dictionary = {}
			var sum: Vector3 = Vector3.ZERO
			var count: int = 0
			_player.play(StringName(clip))
			for f: int in range(n + 1):
				_player.seek(float(f) / 30.0, true)
				var c: Dictionary = _contacts(pts)
				for key: String in ["heel.R", "ball.R"]:
					var p: Vector3 = c[key]
					if prev.has(key) and p.y < 0.002 and Vector3(prev[key]).y < 0.002:
						var d: Vector3 = p - Vector3(prev[key])
						sum += Vector3(d.x, 0.0, d.z)
						count += 1
					prev[key] = p
			_player.stop()
			assert_true(count >= 4, "%s: the right foot is planted for a while (%d samples)" % [clip, count])
			if count == 0:
				continue
			var mean: Vector3 = sum / float(count)
			assert_near(mean.length(), want.length(), want.length() * 0.04, "%s: planted foot speed %f m/s" % [clip, mean.length() * 30.0])
			assert_true(rad_to_deg(mean.angle_to(want)) < 3.0, "%s: travel direction (%s vs %s)" % [clip, mean, want])


## Start / stop: frame 0 / the last frame equal idle frame 0 and the documented cycle frame; the documented root curve
## starts / ends at the cycle speed and rest; with the root moved along it, planted contacts stay put.
func _check_d304_start_stop() -> void:
	var lines: Dictionary = _source_lines()
	var pts: Dictionary = _ground_locals()
	var idle0: Array[Vector3] = _snapshot("idle", 0.0)
	for clip: String in D304_HANDOFF:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var n: int = _d304_frames(clip)
		var gait: String = clip.get_slice("_", 0)
		var v: float = float(D304_GAITS[gait][1])
		var cyc: Array[Vector3] = _snapshot(gait, float(D304_HANDOFF[clip]) / 30.0)
		var first: Array[Vector3] = _snapshot(clip, 0.0)
		var last: Array[Vector3] = _snapshot(clip, float(n) / 30.0)
		var starting: bool = clip.ends_with("start")
		var e0: float = _snap_dist(first, idle0 if starting else cyc)
		var e1: float = _snap_dist(last, cyc if starting else idle0)
		var cyc_name: String = "%s frame %d" % [gait, D304_HANDOFF[clip]]
		assert_true(e0 < 0.01, "%s: frame 0 == %s (%f m)" % [clip, "idle frame 0" if starting else cyc_name, e0])
		assert_true(e1 < 0.01, "%s: last frame == %s (%f m)" % [clip, cyc_name if starting else "idle frame 0", e1])
		var m: RegExMatch = RegEx.create_from_string("root_m=([-0-9.,]+)").search(String(lines.get("curve." + clip, "")))
		if m == null:
			fail("SOURCE.txt curve.%s" % clip)
			continue
		var curve: PackedFloat64Array = PackedFloat64Array()
		for x: String in m.get_string(1).split(","):
			curve.append(x.to_float())
		assert_eq(curve.size(), n + 1, "curve.%s: a value per frame" % clip)
		if curve.size() != n + 1:
			continue
		for f: int in range(1, n + 1):
			assert_true(curve[f] >= curve[f - 1] - 1e-6, "curve.%s: never backwards (frame %d)" % [clip, f])
		var step: float = v / 30.0
		if starting:
			assert_near(curve[n] - curve[n - 1], step, step * 0.03, "curve.%s: at the cycle speed at the hand-off" % clip)
			assert_true(curve[1] - curve[0] < step * 0.1, "curve.%s: starts from rest" % clip)
		else:
			assert_near(curve[1] - curve[0], step, step * 0.12, "curve.%s: leaves the cycle at its speed" % clip)
			assert_near(curve[n] - curve[n - 1], 0.0, 1e-4, "curve.%s: at rest at the end" % clip)
		# planted contacts (on the floor for 3 frames running) are world-still: root space + the root's travel along -Z
		var prev: Dictionary = {}
		var prev2: Dictionary = {}
		var slide: float = 0.0
		var low: float = 1.0
		_player.play(StringName(clip))
		for f: int in range(n + 1):
			_player.seek(float(f) / 30.0, true)
			var c: Dictionary = _contacts(pts)
			for key: String in c:
				var p: Vector3 = Vector3(c[key]) + Vector3(0.0, 0.0, -curve[f])
				low = minf(low, p.y)
				if prev2.has(key) and p.y < 0.003 and Vector3(prev[key]).y < 0.003 and Vector3(prev2[key]).y < 0.003:
					slide = maxf(slide, Vector2(p.x - Vector3(prev[key]).x, p.z - Vector3(prev[key]).z).length())
				if prev.has(key):
					prev2[key] = prev[key]
				prev[key] = p
		_player.stop()
		assert_true(slide < 0.004, "%s: planted contacts do not slide at the documented root motion (%f m/frame)" % [clip, slide])
		assert_true(low > -0.006, "%s: heels / balls / toes above the floor (%f)" % [clip, low])


## Directional hit reacts: start and end on idle frame 0, feet planted, the chest knocked the right way at the hit.
func _check_d304_hit_reacts() -> void:
	var idle0: Array[Vector3] = _snapshot("idle", 0.0)
	var chest: int = _skel.find_bone("chest")
	var push: Dictionary = {"hit_react_back": Vector3(0.0, 0.0, -1.0), "hit_react_left": Vector3(1.0, 0.0, 0.0),
		"hit_react_right": Vector3(-1.0, 0.0, 0.0), "hit_react": Vector3(0.0, 0.0, 1.0)}
	for clip: String in push:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var n: int = int(round(a.length * 30.0))
		var s0: Array[Vector3] = _snapshot(clip, 0.0)
		var s3: Array[Vector3] = _snapshot(clip, 3.0 / 30.0)
		var sn: Array[Vector3] = _snapshot(clip, float(n) / 30.0)
		if clip != "hit_react":
			assert_true(_snap_dist(s0, idle0) < 0.01 and _snap_dist(sn, idle0) < 0.01, "%s: from and back to idle frame 0" % clip)
		var moved: Vector3 = s3[chest] - s0[chest]
		assert_true(moved.dot(push[clip]) > 0.025, "%s: the chest is knocked %s (%s)" % [clip, push[clip], moved])
		var drift: float = 0.0
		for f: int in range(n + 1):
			var s: Array[Vector3] = _snapshot(clip, float(f) / 30.0)
			for b: String in ["foot.L", "foot.R", "toe.L", "toe.R"]:
				drift = maxf(drift, s[_skel.find_bone(b)].distance_to(s0[_skel.find_bone(b)]))
		assert_true(drift < 0.004, "%s: feet planted (%f m)" % [clip, drift])


## Death variants start standing, reach the floor at `impact` and end lying on it: nothing below it at any frame,
## the hips and every joint low at the end.
func _check_d304_deaths_end_on_the_floor() -> void:
	var idle0: Array[Vector3] = _snapshot("idle", 0.0)
	var hips: int = _skel.find_bone("hips")
	for clip: String in ["death_front_b", "death_back_b", "death_side"]:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var n: int = _d304_frames(clip)
		assert_true(_snap_dist(_snapshot(clip, 0.0), idle0) < 0.01, "%s: starts from idle frame 0" % clip)
		var lowest: float = 1.0
		for f: int in range(0, n + 1, 2):
			for p: Vector3 in _snapshot(clip, float(f) / 30.0):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
		var impact: int = int(D304_EVENTS[clip]["impact"])
		var at: Array[Vector3] = _snapshot(clip, float(impact) / 30.0)
		assert_true(at[hips].y < 0.4, "%s: down at the impact (hips %f m)" % [clip, at[hips].y])
		var end: Array[Vector3] = _snapshot(clip, float(n) / 30.0)
		var top: float = 0.0
		var bottom: float = 1.0
		for p: Vector3 in end:
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
		assert_true(end[hips].y < 0.3, "%s: ends lying down (hips %f m)" % [clip, end[hips].y])
		assert_true(top < 0.6, "%s: every joint low at the end (highest %f m)" % [clip, top])
		assert_true(bottom < 0.1, "%s: resting on the floor (lowest joint %f m)" % [clip, bottom])


## downed_crawl: prone every frame, the palms planted (world-still while the root moves forward at 0.3 m/s; right hand
## down from normalised 0, left from 0.5, 60 % stance each) and the heavy Wrecker stomp on its feet, lower than dozer_walk.
func _check_d304_crawl_and_heavy_gait() -> void:
	var a: Animation = _anim("downed_crawl")
	if a != null:
		var n: int = int(D304_LOOPS["downed_crawl"])
		var hips: int = _skel.find_bone("hips")
		var prev: Dictionary = {}
		var slide: float = 0.0
		var lowest: float = 1.0
		var highest_hips: float = 0.0
		for f: int in range(n + 1):
			var s: Array[Vector3] = _snapshot("downed_crawl", float(f) / 30.0)
			highest_hips = maxf(highest_hips, s[hips].y)
			for p: Vector3 in s:
				lowest = minf(lowest, p.y)
			for sfx: String in ["R", "L"]:
				var down: float = 0.0 if sfx == "R" else 0.5 * float(n)
				var u: float = fposmod(float(f) - down, float(n))
				var p: Vector3 = s[_skel.find_bone("hand." + sfx)] + Vector3(0.0, 0.0, -CRAWL_SPEED * float(f) / 30.0)
				if u >= 1.0 and u <= 0.6 * float(n) - 1.0 and prev.has(sfx):
					slide = maxf(slide, p.distance_to(prev[sfx]))
					assert_true(p.y < 0.12, "downed_crawl f%d: %s hand on the floor (%f)" % [f, sfx, p.y])
				prev[sfx] = p
		assert_true(highest_hips < 0.3, "downed_crawl: prone (hips at most %f m)" % highest_hips)
		assert_true(lowest > -0.01, "downed_crawl: nothing below the floor (%f)" % lowest)
		assert_true(slide < 0.004, "downed_crawl: planted hands world-still (%f m/frame)" % slide)
	var heavy: Animation = _anim("dozer_walk_heavy")
	var walk: Animation = _anim("dozer_walk")
	if heavy == null or walk == null:
		fail("dozer_walk_heavy / dozer_walk missing")
		return
	var hs: Dictionary = _foot_heights("dozer_walk_heavy", 33)
	assert_true(float(hs["low"]) > -0.003, "dozer_walk_heavy: feet above the floor (%f)" % hs["low"])
	var r: Array[int] = _touchdowns(hs["R"], 33)
	var l: Array[int] = _touchdowns(hs["L"], 33)
	assert_true(r.size() == 1 and (r[0] <= 1 or r[0] >= 32), "dozer_walk_heavy: right heel strike at step_r@0 %s" % [r])
	assert_true(l.size() == 1 and absi(l[0] - 16) <= 1, "dozer_walk_heavy: left heel strike at step_l@16 %s" % [l])
	var mean_h: float = 0.0
	var mean_w: float = 0.0
	var hip: int = _skel.find_bone("hips")
	for f: int in range(33):
		mean_h += _snapshot("dozer_walk_heavy", float(f) / 30.0)[hip].y / 33.0
		mean_w += _snapshot("dozer_walk", float(f) / 30.0)[hip].y / 33.0
	assert_true(mean_h < mean_w - 0.01, "dozer_walk_heavy: lower, heavier stance than dozer_walk (%f vs %f m)" % [mean_h, mean_w])


## D-110 seated deaths (an NPC killed in its chair must not fall through the desk): both start from desk_work frame 0
## and the root never moves. slump: the hips stay on the seat and the head ends low over the desk top (0.74 m) ahead of
## the desk's near edge (0.22 m); fall: down on the floor at `impact`, nothing below it, ending to the left (−X) clear
## of the chair, the head ~1 m out.
func _check_seated_deaths() -> void:
	var seat0: Array[Vector3] = _snapshot("desk_work", 0.0)
	var hips: int = _skel.find_bone("hips")
	var head: int = _skel.find_bone("head")
	for clip: String in ["death_seated_slump", "death_seated_fall"]:
		assert_true(_player.has_animation(StringName(clip)), "%s present" % clip)
		if _anim(clip) == null:
			continue
		assert_true(_snap_dist(_snapshot(clip, 0.0), seat0) < 0.01, "%s: starts from desk_work frame 0" % clip)
		var lowest: float = 1.0
		for f: int in range(0, _d304_frames(clip) + 1, 2):
			for p: Vector3 in _snapshot(clip, float(f) / 30.0):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
	var s_end: Array[Vector3] = _snapshot("death_seated_slump", 48.0 / 30.0)
	assert_true(absf(s_end[hips].y - seat0[hips].y) < 0.04, "slump: hips stay on the seat (%f)" % s_end[hips].y)
	assert_true(s_end[head].y > 0.74 and s_end[head].y < 0.92, "slump: head low over the desk top (%f)" % s_end[head].y)
	assert_true(-s_end[head].z > 0.22, "slump: head over the desk, past its near edge (%f)" % -s_end[head].z)
	var f_hit: Array[Vector3] = _snapshot("death_seated_fall", 34.0 / 30.0)
	assert_true(f_hit[hips].y < 0.3, "fall: on the floor at the impact (hips %f)" % f_hit[hips].y)
	var f_end: Array[Vector3] = _snapshot("death_seated_fall", 2.0)
	assert_true(f_end[hips].x < -0.35, "fall: hips beside the chair, to the left (%f)" % f_end[hips].x)
	assert_true(f_end[head].x < -0.8, "fall: head ~1 m to the left (%f)" % f_end[head].x)


## PO6-18 pose-aware deaths (a cuffed / kneeling / prone / downed NPC dies in place, never stands up first): each starts
## on its source pose's frame (A switches without a crossfade), the root never moves, the hips and head never rise more
## than 5 cm above their start height, no joint goes below the floor and the body ends lying on it; the cuffed wrists
## stay together behind the hips the whole clip.
func _check_pose_deaths() -> void:
	var hips: int = _skel.find_bone("hips")
	var head: int = _skel.find_bone("head")
	var root: int = _skel.find_bone("root")
	for clip: String in POSE_DEATHS:
		assert_true(_player.has_animation(StringName(clip)), "%s present" % clip)
		if _anim(clip) == null:
			continue
		var src: Array = POSE_DEATHS[clip]
		var s0: Array[Vector3] = _snapshot(clip, 0.0)
		var d0: float = _snap_dist(s0, _snapshot(String(src[0]), float(src[1])))
		assert_true(d0 < 0.01, "%s: starts on %s @%.2fs (%f m)" % [clip, src[0], src[1], d0])
		var lowest: float = 1.0
		var rise: float = -1.0
		var root_move: float = 0.0
		var n: int = _d304_frames(clip)
		for f: int in range(0, n + 1):
			var s: Array[Vector3] = _snapshot(clip, float(f) / 30.0)
			rise = maxf(rise, maxf(s[hips].y - s0[hips].y, s[head].y - s0[head].y))
			if root >= 0:
				root_move = maxf(root_move, s[root].distance_to(s0[root]))
			for p: Vector3 in s:
				lowest = minf(lowest, p.y)
			if clip == "death_kneel_cuffed":
				var l: Vector3 = s[_skel.find_bone("hand.L")]
				var r: Vector3 = s[_skel.find_bone("hand.R")]
				assert_true(l.distance_to(r) < 0.13, "%s f%d: cuffed wrists together (%f)" % [clip, f, l.distance_to(r)])
				assert_true((l + r).distance_to(s[hips] * 2.0) < 0.6, "%s f%d: hands stay behind the hips" % [clip, f])
		assert_true(rise < 0.05, "%s: hips / head never rise above the start (+%f m)" % [clip, rise])
		assert_true(root_move < 0.001, "%s: the root never moves (%f m)" % [clip, root_move])
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
		var e: Array[Vector3] = _snapshot(clip, float(n) / 30.0)
		assert_true(e[hips].y < 0.32 and e[head].y < 0.45, "%s: ends lying on the floor (hips %f, head %f)" % [
			clip, e[hips].y, e[head].y])


# --------------------------------------------------- PO6-17 assault events (_anim_assault) ---------------------------
func _assault(loops_only: bool = false) -> Array[String]:
	var out: Array[String] = []
	for c: String in ASSAULT:
		if bool(ASSAULT[c][1]) or not loops_only:
			out.append(c)
	return out


## Every PO6-17 clip: length and events (SOURCE), root fixed, no joint below the floor, the source's lowest skin vertex
## >= -1 cm, exact (1 cm per bone) start / end joins; the heli kneel: right knee on the sill, muzzle along -Z when aimed.
func _check_assault_clips() -> void:
	var lines: Dictionary = _source_lines()
	var checks: Dictionary = _check_rows()
	var root: int = _skel.find_bone("root")
	for n: String in ["rappel_assault", "heli_door_sill", "van_exit_step", "breach_charge", "curve.van_exit",
			"curve.breach_standback", "assault_checks"]:
		assert_true(lines.has(n), "SOURCE.txt documents %s" % n)
	assert_true(String(lines.get("clip.rappel_descend", "")).contains("speed_mps=2.5 travel_axis=down"), "descend 2.5 m/s down")
	for clip: String in ASSAULT:
		var spec: Array = ASSAULT[clip]
		var n: int = int(spec[0])
		var a: Animation = _anim(clip)
		assert_true(a != null, "PO6-17 clip %s" % clip)
		if a == null:
			continue
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		for ev: String in spec[2]:
			assert_true(String(lines.get("clip." + clip, "")).contains("%s@%d" % [ev, int(spec[2][ev])]), "%s %s" % [clip, ev])
		var low_skin: float = _num(String(checks.get(clip, "")), "lowest_skin")
		assert_true(low_skin > -10.0 and low_skin < INF, "%s: lowest skin vertex %f mm (source)" % [clip, low_skin])
		var s0: Array[Vector3] = _snapshot(clip, 0.0)
		var lowest: float = 1.0
		var root_move: float = 0.0
		for f: int in range(0, n + 1):
			var s: Array[Vector3] = _snapshot(clip, float(f) / 30.0)
			root_move = maxf(root_move, s[root].distance_to(s0[root]))
			for p: Vector3 in s:
				lowest = minf(lowest, p.y)
		assert_true(root_move < 0.001, "%s: the root never moves (%f m)" % [clip, root_move])
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
		if not spec[3].is_empty():
			var d0: float = _snap_dist(s0, _snapshot(String(spec[3][0]), float(spec[3][1])))
			assert_true(d0 < 0.01, "%s: starts on %s @%.2fs (%f m)" % [clip, spec[3][0], spec[3][1], d0])
		if not String(spec[4]).is_empty():
			var d1: float = _snap_dist(_snapshot(clip, float(n) / 30.0), _snapshot(String(spec[4]), 0.0))
			assert_true(d1 < 0.01, "%s: ends on %s frame 0 (%f m)" % [clip, spec[4], d1])
	var sock_r: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	for clip: String in ["heli_door_idle", "heli_door_aim"]:
		_player.play(StringName(clip))
		_player.seek(0.0, true)
		assert_true(_bone_pos("shin.R").y < 0.12 and _bone_pos("foot.L").z < -0.15, "%s: right knee down, left foot ahead" % clip)
		var muzzle: Vector3 = -(_bone_xform("hand.R") * sock_r).basis.z.normalized()
		var ok: bool = muzzle.dot(Vector3.FORWARD) > 0.97 if clip == "heli_door_aim" else muzzle.y < -0.3
		assert_true(ok, "%s: muzzle aimed along -Z / at the low ready (%s)" % [clip, muzzle])
	# rappel_hang / rappel_descend: both fists (Socket origins) on the documented rope line (3 cm) on every frame (hang:
	# right fist overhead, left low; descend: guide fist high, brake fist low); the feet clear of the root plane
	var m: RegExMatch = RegEx.create_from_string("vertical line at Godot x=(-?[0-9.]+) z=(-?[0-9.]+)").search(
		String(lines.get("rappel_assault", "")))
	var rope: Vector2 = Vector2(m.get_string(1).to_float(), m.get_string(2).to_float()) if m != null else Vector2.INF
	assert_true(rope.y < -0.15 and rope.y > -0.35, "SOURCE rappel_assault: the rope line in front of the chest (%s)" % rope)
	var sock_l: Transform3D = _parse_xform(String(lines.get("handl_shield_offset_godot", "")))
	for clip: String in ["rappel_hang", "rappel_descend"]:
		_player.play(StringName(clip))
		var worst: float = 0.0
		var feet: float = 9.0
		for f: int in range(0, int(ASSAULT[clip][0]) + 1):
			_player.seek(float(f) / 30.0, true)
			var gl: Vector3 = (_bone_xform("hand.L") * sock_l).origin
			var gr: Vector3 = (_bone_xform("hand.R") * sock_r).origin
			worst = maxf(worst, maxf(Vector2(gl.x, gl.z).distance_to(rope), Vector2(gr.x, gr.z).distance_to(rope)))
			var order: bool = gr.y > _bone_pos("head").y and gl.y < gr.y - 0.4 if clip == "rappel_hang" else gl.y > gr.y + 0.4
			assert_true(order, "%s f%d: fist heights" % [clip, f])
			for b: String in ["toe.L", "toe.R", "foot.L", "foot.R"]:
				feet = minf(feet, _bone_pos(b).y)
		_player.stop()
		assert_true(worst < 0.03, "%s: both fists on the rope line (%f m)" % [clip, worst])
		assert_true(feet > 0.25, "%s: the feet clear of the root plane (%f m)" % [clip, feet])
