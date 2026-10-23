# gdlint:disable=max-public-methods
## D-116 police combat movement (ENV D SOURCE police_combat + locomotion_holds) and DB-4 in AnimDriver / CombatClips:
## aim_<fam>_<gait> layered while aiming on the move (frame-locked), class reloads scaled so `done` lands on
## completion (moving: on the upper-body layer), cover_low / cover_peek_l / _r on a brain's cover post (LOS probes),
## stagger_<fam> for stagger-strength hits, sit_chair_armed for armed seated NPCs. Every clip falls back to today's
## behaviour when the rig lacks it. Uses a rig built in code (the clips are empty Animations with the contract names).
extends TestCase

const BASE: Array[StringName] = [
	&"idle", &"idle_alert", &"walk", &"run", &"crouch_walk", &"strafe_l", &"strafe_r", &"walk_back", &"aim_rifle",
	&"aim_pistol", &"sit_chair", &"hit_react", &"hit_react_back", &"hit_react_left", &"hit_react_right", &"fire_rifle",
	&"fire_pistol", &"reload_rifle", &"reload_pistol", &"turn_l", &"turn_r",
]
## The D-116 clips: name -> frames at 30 fps (loops first).
const D116_LOOPS: Dictionary = {
	&"aim_rifle_walk": 30, &"aim_rifle_run": 21, &"aim_rifle_crouch": 27, &"aim_pistol_walk": 30,
	&"aim_pistol_run": 21, &"aim_pistol_crouch": 27, &"cover_low_rifle": 150, &"cover_low_pistol": 150,
	&"cover_peek_l_rifle": 150, &"cover_peek_r_rifle": 150, &"cover_peek_l_pistol": 150, &"cover_peek_r_pistol": 150,
	&"sit_chair_armed": 140,
}
const D116_ONCE: Dictionary = {
	&"reload_smg": 54, &"reload_shotgun": 84, &"reload_lmg": 120, &"reload_sniper": 78, &"stagger_rifle": 36,
	&"stagger_pistol": 36,
}
## `done` frames (SOURCE police_combat).
const DONE_F: Dictionary = {&"reload_smg": 44, &"reload_shotgun": 74, &"reload_lmg": 106, &"reload_sniper": 66}
const BRAIN_SCRIPT: String = """extends Node
var anim_hint: StringName = &"idle"
var cover_point: Node3D = null
var staggered: bool = false
func is_staggered() -> bool:
	return staggered
"""

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


static func _rig(with_d116: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TestRig"
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	for b: String in ["root", "spine", "hand.R", "hand.L"]:
		skel.add_bone(b)
	root.add_child(skel)
	for side: String in ["R", "L"]:
		var hand: BoneAttachment3D = BoneAttachment3D.new()
		hand.name = "Hand" + side
		hand.bone_name = "hand." + side
		skel.add_child(hand)
		var socket: Marker3D = Marker3D.new()
		socket.name = "Socket"
		hand.add_child(socket)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	var clips: Dictionary = {}
	for c: StringName in BASE:
		clips[c] = 30 if c in [&"walk", &"walk_back", &"run"] else (18 if String(c).begins_with("strafe_") else 60)
	clips[&"run"] = 21
	if with_d116:
		clips.merge(D116_LOOPS)
		clips.merge(D116_ONCE)
	for c: StringName in clips:
		var a: Animation = Animation.new()
		a.length = float(clips[c]) / 30.0
		var once: bool = D116_ONCE.has(c) or String(c).begins_with("reload_") or String(c).begins_with("fire_") \
			or String(c).begins_with("hit_") or String(c).begins_with("turn_")
		a.loop_mode = Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
		var t: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:spine"))
		a.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
		lib.add_animation(c, a)
	ap.add_animation_library(AnimDriver.LIBRARY, lib)
	root.add_child(ap)
	return root


func _npc(role: StringName, with_d116: bool, net_id: int) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.net_id = net_id
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.add_child(_rig(with_d116))
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = BRAIN_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	return npc


func _brain(npc: NpcBase) -> Node:
	return npc.get_node(^"Brain")


# --- Pure selection --------------------------------------------------------------------------

func test_aim_gait_and_cover_classification() -> void:
	for pair: Array in [[&"walk", &"walk"], [&"walk_fl", &"walk"], [&"walk_back", &"walk"], [&"strafe_l", &"walk"],
			[&"strafe_r", &"walk"], [&"run", &"run"], [&"run_bl", &"run"], [&"crouch_walk", &"crouch"],
			[&"sprint", &""], [&"walk_start", &""], [&"run_stop", &""], [&"walk_text", &""], [&"idle", &""]]:
		assert_eq(CombatClips.aim_gait_of(pair[0]), pair[1], "aim gait of %s" % pair[0])
	assert_near(CombatClips.locked_time(0.4, 1.0, 1.0), 0.4, 0.0001, "same length: the base position")
	assert_near(CombatClips.locked_time(0.3, 0.6, 1.0), 0.5, 0.0001, "18 f strafe under a 30 f layer: same phase")
	# (front_low, front_high, left wall, right wall)
	assert_eq(CombatClips.classify_cover(true, false, false, false), CombatClips.COVER_LOW, "low cover")
	assert_eq(CombatClips.classify_cover(true, false, true, false), CombatClips.COVER_LOW, "low wins over a corner")
	assert_eq(CombatClips.classify_cover(false, false, false, true), CombatClips.COVER_PEEK_L, "wall right: peek left")
	assert_eq(CombatClips.classify_cover(false, false, true, false), CombatClips.COVER_PEEK_R, "wall left: peek right")
	assert_eq(CombatClips.classify_cover(false, false, false, false), CombatClips.COVER_NONE, "open: plain aim")
	assert_eq(CombatClips.classify_cover(false, false, true, true), CombatClips.COVER_NONE, "walls both sides: aim")
	assert_eq(CombatClips.classify_cover(true, true, false, false), CombatClips.COVER_NONE, "full wall ahead: aim")


# --- 1) aim on the move ----------------------------------------------------------------------

func test_police_aims_on_the_move_frame_locked() -> void:
	var npc: NpcBase = _npc(&"police", true, 71601)
	var d: AnimDriver = AnimDriver.of(npc)
	assert_true(d.hold_layer != null, "NPCs carry the upper-body layer")
	assert_eq(d.aim_family(), &"rifle", "police aim as rifles")
	_brain(npc).anim_hint = &"aim"
	npc.velocity = Vector3(0, 0, -1.6)
	for _i: int in 20:
		d.tick(0.033)
	assert_eq(d.clip, &"walk", "walking")
	assert_eq(d.hold_layer.clip, &"aim_rifle_walk", "aim_rifle_walk over the walk")
	assert_near(d.hold_layer.influence, 1.0, 0.001, "weight 1")
	for _i: int in 5:
		d.tick(0.033)
		assert_near(d.hold_layer.time, d.player.current_animation_position, 0.0001, "frame-locked to the walk")
	npc.velocity = Vector3(0, 0, -3.5)
	d.tick(0.033)
	assert_eq([d.clip, d.hold_layer.clip], [&"run", &"aim_rifle_run"], "run: aim_rifle_run")
	npc.velocity = Vector3(1.2, 0, 0)
	for _i: int in 3:
		d.tick(0.033)
	assert_eq([d.clip, d.hold_layer.clip], [&"strafe_r", &"aim_rifle_walk"], "strafe: aim_rifle_walk")
	var phase: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	assert_near(d.hold_layer.time, phase * 1.0, 0.0001, "18 f strafe: phase-locked")
	d.weapon_kind = &"pistol"
	d.tick(0.033)
	assert_eq(d.hold_layer.clip, &"aim_pistol_walk", "pistol family: aim_pistol_walk")
	npc.velocity = Vector3.ZERO
	for _i: int in 10:
		d.tick(0.033)
	assert_eq(d.clip, &"aim_pistol", "standing: the plain aim clip as today")
	assert_near(d.hold_layer.influence, 0.0, 0.001, "standing: layer off")
	_brain(npc).anim_hint = &"idle"
	npc.velocity = Vector3(0, 0, -1.6)
	for _i: int in 10:
		d.tick(0.033)
	assert_near(d.hold_layer.influence, 0.0, 0.001, "moving without aiming: no NPC layer")


func test_aim_on_the_move_falls_back_without_the_clips() -> void:
	var npc: NpcBase = _npc(&"police", false, 71602)
	var d: AnimDriver = AnimDriver.of(npc)
	_brain(npc).anim_hint = &"aim"
	npc.velocity = Vector3(0, 0, -1.6)
	for _i: int in 10:
		d.tick(0.033)
	assert_eq(d.clip, &"walk", "walking")
	assert_near(d.hold_layer.influence, 0.0, 0.001, "trunk rig: no NPC aim layer (today)")
	assert_eq(d.combat.aim_move_clip(&"walk"), &"", "no aim_rifle_walk")


# --- 2) class reloads ------------------------------------------------------------------------

func test_npc_class_reload_clip_and_done_scaling() -> void:
	var npc: NpcBase = _npc(&"police", true, 71603)
	var d: AnimDriver = AnimDriver.of(npc)
	var cases: Array = [
		[Enums.WeaponClass.SMG, &"reload_smg"], [Enums.WeaponClass.SPECIAL, &"reload_smg"],
		[Enums.WeaponClass.SHOTGUN, &"reload_shotgun"], [Enums.WeaponClass.LMG, &"reload_lmg"],
		[Enums.WeaponClass.SNIPER, &"reload_sniper"], [Enums.WeaponClass.ASSAULT_RIFLE, &"reload_rifle"],
		[-1, &"reload_rifle"],
	]
	var g_dur: float = CombatTweak.data().npc_reload_s
	for c: Array in cases:
		d.weapon_class = int(c[0])
		d._oneshot_left = 0.0
		EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, npc.net_id)
		d.tick(0.016)
		assert_eq(d.clip, c[1], "class %d reloads with %s" % [c[0], c[1]])
		var want_done: float = float(DONE_F.get(c[1], 58)) / 30.0
		assert_near(d._oneshot_speed * d._oneshot_dur, want_done, 0.002,
			"%s: `done` (%.3f s of clip) lands on reload completion" % [c[1], want_done])
		assert_near(d._oneshot_dur, g_dur, 0.001, "%s lasts the gameplay reload" % c[1])
	d.weapon_class = Enums.WeaponClass.SHOTGUN
	d._oneshot_left = 0.0
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_PISTOL, Vector3.ZERO, npc.net_id)
	d.tick(0.016)
	assert_eq(d.clip, &"reload_pistol", "the pistol cue keeps reload_pistol")


func test_class_reload_falls_back_to_reload_rifle() -> void:
	var npc: NpcBase = _npc(&"police", false, 71604)
	var d: AnimDriver = AnimDriver.of(npc)
	for cls: int in [Enums.WeaponClass.SMG, Enums.WeaponClass.SHOTGUN, Enums.WeaponClass.LMG, Enums.WeaponClass.SNIPER]:
		d.weapon_class = cls
		d._oneshot_left = 0.0
		EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, npc.net_id)
		d.tick(0.016)
		assert_eq(d.clip, &"reload_rifle", "class %d without its clip: reload_rifle" % cls)
		assert_near(d._oneshot_speed * d._oneshot_dur, AnimTweak.data().reload_done(&"rifle"), 0.002, "rifle done")


func test_moving_reload_rides_the_upper_body_layer() -> void:
	var npc: NpcBase = _npc(&"police", true, 71605)
	var d: AnimDriver = AnimDriver.of(npc)
	d.weapon_class = Enums.WeaponClass.LMG
	npc.velocity = Vector3(0, 0, -1.6)
	d.tick(0.033)
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_RELOAD_RIFLE, Vector3.ZERO, npc.net_id)
	for _i: int in 10:
		d.tick(0.033)
	assert_eq(d.clip, &"walk", "the legs keep walking")
	assert_eq(d.hold_layer.clip, &"reload_lmg", "reload_lmg on the upper body")
	var elapsed: float = d._oneshot_dur - d._oneshot_left
	assert_near(d.hold_layer.time, elapsed * d._oneshot_speed, 0.0001, "the layer runs at the reload's time")
	assert_near(d.hold_layer.influence, 1.0, 0.001, "weight 1")
	npc.velocity = Vector3.ZERO
	d.tick(0.033)
	assert_eq(d.clip, &"reload_lmg", "stopping: the full-body reload")


func test_crew_class_reload_and_aim_on_the_move() -> void:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	crew.heister = &"rook"
	crew.net_id = 71606
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)
	crew.masked = true
	crew.set_physics_process(false)
	var d: AnimDriver = AnimDriver.of(crew)
	if d == null or d.player == null or d.hold_layer == null or d._held_weapon_clip(&"hold_") == &"":
		skip("no animated crew rig with weapon holds")
		return
	d.set_process(false)
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for c: StringName in [&"reload_shotgun", &"aim_rifle_walk"]:
		if not lib.has_animation(c):  # stand-ins until D's library lands on trunk
			var src: Animation = lib.get_animation(&"reload_rifle" if c == &"reload_shotgun" else &"walk")
			lib.add_animation(c, src.duplicate() as Animation)
	d.weapon_kind = &"rifle"
	d.weapon_class = Enums.WeaponClass.SHOTGUN
	d._on_reload_started(Enums.WeaponSlot.PRIMARY, 2.0)
	d.tick(0.016)
	assert_eq(d.clip, &"reload_shotgun", "a crew shotgun reloads with reload_shotgun")
	var done_s: float = AnimTweak.data().reload_done(&"shotgun")
	assert_near(d._oneshot_speed, done_s / 2.0, 0.0005, "scaled so `done` lands at 2.0 s")
	d._oneshot_left = 0.0
	d.weapon_class = Enums.WeaponClass.ASSAULT_RIFLE
	d._on_reload_started(Enums.WeaponSlot.PRIMARY, 2.0)
	d.tick(0.016)
	assert_eq(d.clip, &"reload_rifle", "an assault rifle keeps reload_rifle")
	d._oneshot_left = 0.0
	d._aim_hold_left = 10.0
	crew.velocity = Vector3(0, 0, -1.6)
	for _i: int in 25:
		d.tick(0.05)
	if d.clip != &"walk":
		return  # a start / directional variant; selection is covered by the NPC tests
	assert_eq(d.hold_layer.clip, &"aim_rifle_walk", "crew aiming on the move: aim_rifle_walk")
	assert_near(d.hold_layer.time, d.player.current_animation_position, 0.0001, "frame-locked to the walk")


# --- 3) cover --------------------------------------------------------------------------------

func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	add_child(b)
	_nodes.append(b)
	b.global_position = pos
	return b


func _cover_case(net_id: int, boxes: Array, with_d116: bool = true) -> AnimDriver:
	var npc: NpcBase = _npc(&"police", with_d116, net_id)
	npc.global_position = Vector3(net_id % 100 * 20.0, 0.0, 200.0)  # far from the other cases
	var post: Marker3D = Marker3D.new()
	add_child(post)
	_nodes.append(post)
	post.global_position = npc.global_position + Vector3(0.3, 0.0, 0.0)
	for b: Array in boxes:
		_box(npc.global_position + (b[0] as Vector3), b[1])
	_brain(npc).cover_point = post
	_brain(npc).anim_hint = &"aim"
	return AnimDriver.of(npc)


func test_cover_poses_on_the_post() -> void:
	# The NPC faces -Z. Low: a counter 0.9 m tall 0.7 m ahead. Corner: a wall close on the right (+X).
	var low: AnimDriver = _cover_case(71610, [[Vector3(0, 0.45, -0.7), Vector3(2.0, 0.9, 0.2)]])
	var right_wall: AnimDriver = _cover_case(71611, [[Vector3(0.5, 1.0, -0.3), Vector3(0.2, 2.0, 1.4)]])
	var left_wall: AnimDriver = _cover_case(71612, [[Vector3(-0.5, 1.0, -0.3), Vector3(0.2, 2.0, 1.4)]])
	var open: AnimDriver = _cover_case(71613, [])
	await wait_physics_frames(2)
	for d: AnimDriver in [low, right_wall, left_wall, open]:
		d.tick(0.033)
	assert_eq(low.clip, &"cover_low_rifle", "behind low cover: cover_low_rifle")
	assert_eq(right_wall.clip, &"cover_peek_l_rifle", "wall on the right: lean out left")
	assert_eq(left_wall.clip, &"cover_peek_r_rifle", "wall on the left: lean out right")
	assert_eq(open.clip, &"aim_rifle", "no cover geometry: plain aim")
	low.weapon_kind = &"pistol"
	low.combat._cover_next_ms = 0
	low.tick(0.033)
	assert_eq(low.clip, &"cover_low_pistol", "pistol family: cover_low_pistol")
	# A shot on the post keeps the cover loop playing (fire would restart it); off the post: aim again.
	EventBus.weapon_fired.emit(low._net_id(), &"", false, Vector3.ZERO)
	low.tick(0.033)
	assert_eq(low.clip, &"cover_low_pistol", "firing from cover keeps the cover loop")
	(low.get_parent().get_node(^"Brain")).cover_point = null
	low.tick(0.033)
	assert_ne(low.clip, &"cover_low_pistol", "off the post: no cover loop")


func test_cover_falls_back_to_aim_without_the_clips() -> void:
	var d: AnimDriver = _cover_case(71614, [[Vector3(0, 0.45, -0.7), Vector3(2.0, 0.9, 0.2)]], false)
	await wait_physics_frames(2)
	d.tick(0.033)
	assert_eq(d.clip, &"aim_rifle", "trunk rig: aim_rifle on the cover post (today)")


# --- 4) stagger ------------------------------------------------------------------------------

func test_explosion_and_brain_stagger() -> void:
	var npc: NpcBase = _npc(&"police", true, 71620)
	var d: AnimDriver = AnimDriver.of(npc)
	var boom: Dictionary = {"direction": Vector3(0, 0, 1), "amount": 30.0, "killed": false,
		"type": Enums.DamageType.EXPLOSION}
	EventBus.damage_applied.emit(npc.net_id, 0, boom)
	d.tick(0.016)
	assert_eq(d.clip, &"stagger_rifle", "an explosion staggers a police unit")
	d._oneshot_left = 0.0
	d._last_hit_react_t = -100.0
	EventBus.damage_applied.emit(npc.net_id, 0, {"direction": Vector3(0, 0, 1), "amount": 30.0, "killed": false})
	d.tick(0.016)
	assert_eq(d.clip, &"hit_react", "a bullet keeps the flinch")
	d._oneshot_left = 0.0
	d._last_hit_react_t = -100.0
	npc.set_meta(AegisCaptain.META_NO_FLINCH, true)
	EventBus.damage_applied.emit(npc.net_id, 0, boom)
	d.tick(0.016)
	assert_ne(d.clip, &"stagger_rifle", "no_flinch: no stagger")
	npc.remove_meta(AegisCaptain.META_NO_FLINCH)
	d._oneshot_left = 0.0
	d.weapon_kind = &"pistol"
	_brain(npc).staggered = true
	_brain(npc).anim_hint = &"hit_react"
	d.tick(0.016)
	assert_eq(d.clip, &"stagger_pistol", "the brain's L4.5 stagger (hit_react hint): stagger_pistol")
	var left: float = d._oneshot_left
	d.tick(0.016)
	assert_true(d._oneshot_left < left, "plays on (not restarted every tick)")


func test_stagger_falls_back_to_the_flinches() -> void:
	var npc: NpcBase = _npc(&"police", false, 71621)
	var d: AnimDriver = AnimDriver.of(npc)
	EventBus.damage_applied.emit(npc.net_id, 0, {"direction": Vector3(0, 0, -1), "amount": 30.0, "killed": false,
		"type": Enums.DamageType.EXPLOSION})
	d.tick(0.016)
	assert_eq(d.clip, &"hit_react_back", "trunk rig: the directional flinch (today)")
	d._oneshot_left = 0.0
	_brain(npc).staggered = true
	_brain(npc).anim_hint = &"hit_react"
	d.tick(0.016)
	assert_eq(d.clip, &"hit_react", "trunk rig: the hit_react hint plays hit_react (today)")


# --- 5) DB-4 armed seated idle ---------------------------------------------------------------

func test_db4_armed_seated_idle() -> void:
	var cartel: NpcBase = _npc(CartelBrain.ROLE, true, 71630)
	var guard: NpcBase = _npc(&"guard", true, 71631)
	var unarmed: NpcBase = _npc(&"guard", true, 71632)
	var civ: NpcBase = _npc(&"civilian", true, 71633)
	var trunk: NpcBase = _npc(CartelBrain.ROLE, false, 71634)
	var gun: Node3D = Node3D.new()
	_nodes.append(gun)
	AnimDriver.of(guard).weapon_visual = gun  # a modelled long gun
	AnimDriver.of(guard).weapon_kind = &"rifle"
	var pistol: NpcBase = _npc(&"guard", true, 71635)
	AnimDriver.of(pistol).weapon_visual = gun
	AnimDriver.of(pistol).weapon_kind = &"pistol"
	for n: NpcBase in [cartel, guard, unarmed, civ, trunk, pistol]:
		_brain(n).anim_hint = &"sit"
	assert_eq(AnimDriver.of(cartel).choose_clip(), &"sit_chair_armed", "cartel `sit`: sit_chair_armed")
	assert_eq(AnimDriver.of(guard).choose_clip(), &"sit_chair_armed", "armed guard on a seat: sit_chair_armed")
	assert_eq(AnimDriver.of(unarmed).choose_clip(), &"sit_chair", "guard without a weapon model: sit_chair")
	assert_eq(AnimDriver.of(pistol).choose_clip(), &"sit_chair", "pistol guard: sit_chair (the clip holds a long gun)")
	assert_eq(AnimDriver.of(civ).choose_clip(), &"sit_chair", "civilian: sit_chair")
	assert_eq(AnimDriver.of(trunk).choose_clip(), &"sit_chair", "rig without sit_chair_armed: sit_chair (today)")
	AnimDriver.of(cartel).tick(0.016)
	assert_eq(String(AnimDriver.of(cartel).player.current_animation), "humanoid/sit_chair_armed", "played")


## characters.md v1.26 (a): an alert, armed NPC on the move (not aiming) holds its weapon like the crew:
## hold_<kind>_<gait> frame-locked to the gait, hold_<kind> when D has no gait clip; calm or unarmed: no layer.
func test_v126a_npc_hold_layer_on_the_move() -> void:
	var npc: NpcBase = _npc(&"police", true, 71690)
	var d: AnimDriver = AnimDriver.of(npc)
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for c: StringName in [&"hold_rifle", &"hold_rifle_walk"]:
		if not lib.has_animation(c):
			var a: Animation = Animation.new()
			a.length = 1.0
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(c, a)
	d.weapon_kind = &"rifle"
	var gun: Node3D = Node3D.new()
	npc.add_child(gun)
	d.weapon_visual = gun
	_brain(npc).anim_hint = &"idle"
	npc.alert_state = Enums.AlertState.COMBAT
	npc.velocity = Vector3(0, 0, -1.6)
	for _i: int in 20:
		d.tick(0.033)
	assert_eq([d.clip, d.hold_layer.clip], [&"walk", &"hold_rifle_walk"], "alert + armed + walking: hold_rifle_walk")
	assert_near(d.hold_layer.influence, 1.0, 0.001, "weight 1")
	assert_near(d.hold_layer.time, d.player.current_animation_position, 0.0001, "frame-locked to the walk")
	npc.velocity = Vector3(0, 0, -3.5)
	d.tick(0.033)
	assert_eq([d.clip, d.hold_layer.clip], [&"run", &"hold_rifle"], "no hold_rifle_run: plain hold_rifle")
	npc.alert_state = Enums.AlertState.CALM
	npc.velocity = Vector3(0, 0, -1.6)
	for _i: int in 20:
		d.tick(0.033)
	assert_near(d.hold_layer.influence, 0.0, 0.001, "calm: no hold layer")
	npc.alert_state = Enums.AlertState.COMBAT
	d.weapon_visual = null
	for _i: int in 20:
		d.tick(0.033)
	assert_near(d.hold_layer.influence, 0.0, 0.001, "unarmed: no hold layer")


## characters.md v1.39 (D d2a2e3fd, LEAD: TAC port arms): a running police rifle NPC (not aiming) holds
## hold_rifle_port_run, gait-locked like hold_rifle_run; any other NPC (and the crew, whose branch is separate) keeps
## hold_rifle_run.
func test_v139_police_run_at_port_arms() -> void:
	for role: StringName in [&"police", &"guard"]:
		var npc: NpcBase = _npc(role, true, 71700 if role == &"police" else 71701)
		var d: AnimDriver = AnimDriver.of(npc)
		var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
		for c: StringName in [&"hold_rifle", &"hold_rifle_run", &"hold_rifle_port_run"]:
			if not lib.has_animation(c):
				var a: Animation = Animation.new()
				a.length = 1.0
				a.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(c, a)
		d.weapon_kind = &"rifle"
		var gun: Node3D = Node3D.new()
		npc.add_child(gun)
		d.weapon_visual = gun
		_brain(npc).anim_hint = &"idle"
		npc.alert_state = Enums.AlertState.COMBAT
		npc.velocity = Vector3(0, 0, -3.5)
		for _i: int in 20:
			d.tick(0.033)
		var want: StringName = &"hold_rifle_port_run" if role == &"police" else &"hold_rifle_run"
		assert_eq([d.clip, d.hold_layer.clip], [&"run", want], "%s running with a rifle: %s" % [role, want])
		if role == &"police":
			assert_near(d.hold_layer.time, d.player.current_animation_position, 0.0001, "gait-locked to the run")


func _add_loops(d: AnimDriver, names: Array, frames: int) -> void:
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for c: StringName in names:
		if not lib.has_animation(c):
			var a: Animation = Animation.new()
			a.length = float(frames) / 30.0
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(c, a)


static func _vel_at(deg: float, speed: float) -> Vector3:
	return Vector3(sin(deg_to_rad(deg)), 0.0, -cos(deg_to_rad(deg))) * speed  # the body faces -Z, +X is its right


## D (motion strips, PO "inorganic"): the 8-way sector holds through jitter around a boundary (hysteresis, min hold),
## and a switch inside the walk family carries the stride's phase instead of restarting at 0.
func test_8way_sector_hysteresis_and_phase_carry() -> void:
	var npc: NpcBase = _npc(&"police", false, 71691)
	var d: AnimDriver = AnimDriver.of(npc)
	_add_loops(d, [&"walk_fr", &"walk_fl", &"walk_br", &"walk_bl"], 30)
	_brain(npc).anim_hint = &"idle"
	npc.velocity = _vel_at(45.0, 1.2)
	for _i: int in 20:
		d.tick(0.033)
	assert_eq(d.clip, &"walk_fr", "45 deg: walk_fr")
	for deg: float in [68.0, 30.0, 70.0, 25.0, 66.0]:  # jitter across the 67.5 / 22.5 deg boundaries
		npc.velocity = _vel_at(deg, 1.2)
		for _i: int in 5:
			d.tick(0.033)
		assert_eq(d.clip, &"walk_fr", "%.0f deg: still walk_fr (within 30 deg of its centre)" % deg)
	var phase: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	npc.velocity = _vel_at(-45.0, 1.2)
	d.tick(0.033)
	assert_eq(d.clip, &"walk_fl", "a real turn to -45 deg: walk_fl")
	var now: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	assert_near(now, fposmod(phase + 0.033 / 1.0, 1.0), 0.06, "walk_fl picks up walk_fr's phase (not 0)")


## D (motion strips): a stagger is not cut short by the shots / turns that follow it (the cover loop took over).
func test_stagger_plays_out() -> void:
	var npc: NpcBase = _npc(&"police", true, 71692)
	var d: AnimDriver = AnimDriver.of(npc)
	d.play_oneshot(&"stagger_pistol", -1.0, true)
	d.tick(0.1)
	d.play_oneshot(&"fire_pistol")
	d.play_oneshot(&"turn_l")
	d.tick(0.1)
	assert_eq(d._oneshot, &"stagger_pistol", "the stagger keeps playing")
	assert_eq(d.clip, &"stagger_pistol", "and is the clip")
	for _i: int in 12:
		d.tick(0.1)
	d.play_oneshot(&"fire_pistol")
	assert_eq(d._oneshot, &"fire_pistol", "after it ends, shots play again")


## D (test_loco_phase): forward -> backward carries the phase + back_phase_offset (backward -> forward subtracts it).
func test_8way_phase_carry_back_offset() -> void:
	var npc: NpcBase = _npc(&"police", false, 71693)
	var d: AnimDriver = AnimDriver.of(npc)
	_add_loops(d, [&"walk_fr", &"walk_fl", &"walk_br", &"walk_bl"], 30)
	_brain(npc).anim_hint = &"idle"
	npc.velocity = _vel_at(45.0, 1.2)
	for _i: int in 20:
		d.tick(0.033)
	var u: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	npc.velocity = _vel_at(135.0, 1.2)  # a 90 deg turn: walk_br at once
	d.tick(0.033)
	assert_eq(d.clip, &"walk_br")
	var now: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	var want: float = fposmod(u + AnimTweak.data().locomotion_back_phase_offset + 0.033, 1.0)
	assert_near(now, want, 0.06, "walk_fr -> walk_br: + the back group's offset")


## D (motion strips): a 180 deg reversal (run <-> run_b) crossfades in locomotion_reversal_blend_s, not the full blend.
func test_8way_reversal_short_crossfade() -> void:
	var npc: NpcBase = _npc(&"police", false, 71694)
	var d: AnimDriver = AnimDriver.of(npc)
	_add_loops(d, [&"run_b", &"run_fr"], 21)
	_brain(npc).anim_hint = &"idle"
	npc.velocity = _vel_at(0.0, 3.5)
	for _i: int in 20:
		d.tick(0.033)
	assert_eq(d.clip, &"run")
	npc.velocity = _vel_at(180.0, 3.5)
	d.tick(0.033)
	assert_eq(d.clip, &"run_b", "reversed")
	assert_near(d.last_blend_s, AnimTweak.data().locomotion_reversal_blend_s, 0.0001, "a short crossfade")
	assert_true(AnimDriver._reversal(&"run_bl", &"run_r") and not AnimDriver._reversal(&"run", &"run_r"),
		"135 deg is a reversal, 90 deg is not")


## D (motion strips): a bot's stop-start (a moment under the move threshold) resumes the stride's phase within the
## resume window instead of restarting it at 0.
func test_8way_resume_carry_after_a_short_stop() -> void:
	var npc: NpcBase = _npc(&"police", false, 71695)
	var d: AnimDriver = AnimDriver.of(npc)
	_add_loops(d, [&"walk_fr", &"walk_fl", &"walk_br", &"walk_bl"], 30)
	_brain(npc).anim_hint = &"idle"
	npc.velocity = _vel_at(45.0, 1.3)
	for _i: int in 20:
		d.tick(0.033)
	assert_eq(d.clip, &"walk_fr")
	d.player.seek(0.4, true)
	npc.velocity = Vector3.ZERO
	d.tick(0.033)
	assert_false(String(d.clip).begins_with("walk_f"), "stopped (%s)" % d.clip)
	npc.velocity = _vel_at(-45.0, 1.3)
	d.tick(0.033)
	assert_eq(d.clip, &"walk_fl")
	var u: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	assert_near(u, 0.4 + 0.033, 0.05, "walk_fl resumes walk_fr's stride (not 0)")


## characters v1.27 (D's loco_reverse): run -> run_b holds run until the next brake-foot touch-down, plays the
## reversal clip with no crossfade, then enters run_b at the clip's u_out with no crossfade.
func test_v127_reversal_clip_at_the_touch_down() -> void:
	var npc: NpcBase = _npc(&"police", false, 71696)
	var d: AnimDriver = AnimDriver.of(npc)
	_add_loops(d, [&"run_b"], 21)
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	for c: StringName in [&"run_reverse_l", &"run_reverse_r"]:
		var a: Animation = Animation.new()
		a.length = 18.0 / 30.0
		lib.add_animation(c, a)
	AnimTweak.reversals_override = {&"run>run_b": [
		{"clip": &"run_reverse_l", "frames": 18, "u_in": 0.5238, "u_out": 0.2381},
		{"clip": &"run_reverse_r", "frames": 18, "u_in": 0.0, "u_out": 0.7619}]}
	_brain(npc).anim_hint = &"idle"
	npc.velocity = _vel_at(0.0, 3.5)
	for _i: int in 10:
		d.player.advance(0.033)
		d.tick(0.033)
	assert_eq(d.clip, &"run")
	d.player.seek(0.2 * d.player.get_animation(d.player.current_animation).length, true)  # u 0.2: the L foot (0.52) is next
	npc.velocity = _vel_at(180.0, 3.5)
	d.tick(0.033)
	assert_eq(d.clip, &"run", "held on run until the brake foot lands")
	var seen: StringName = &""
	for _i: int in 30:
		d.player.advance(0.033)
		d.tick(0.033)
		if String(d.clip).contains("_reverse_"):
			seen = d.clip
			assert_near(d.last_blend_s, 0.0, 0.0001, "no crossfade into the reversal")
			break
	assert_eq(seen, &"run_reverse_l", "the left foot was next (u 0.52)")
	for _i: int in 30:
		d.player.advance(0.033)
		d.tick(0.033)
		if d.clip == &"run_b":
			break
	assert_eq(d.clip, &"run_b", "then the target loop")
	assert_near(d.last_blend_s, 0.0, 0.0001, "no crossfade out")
	var u: float = d.player.current_animation_position / d.player.get_animation(d.player.current_animation).length
	assert_near(u, 0.2381, 0.06, "entered at run_reverse_l's u_out")
	AnimTweak.reversals_override = {}


## v1.27: D's loco_reverse SOURCE line parses into the reversal table (its exact entry format, two entries here).
func test_v127_loco_reverse_parse() -> void:
	var line: String = "loco_reverse: characters v1.27 locomotion reversals (fixed facing ...): ... run_reverse_l: " \
		+ "run->run_b brake=L frames=18 u_in=0.5238 (run frame 11) u_out=0.2381 (run_b frame 5) events=foot_plant@0," \
		+ "push@6,done@18 other_lands@13.0 brake_lifts@10.1 root_total_m=-0.642 max_hip_drop_mm=6.9 | walk_reverse_back_r:" \
		+ " walk_back->walk brake=R frames=24 u_in=0.0000 (walk_back frame 0) u_out=0.7333 (walk frame 22) events=" \
		+ "foot_plant@0,push@11,done@24 other_lands@17.0 brake_lifts@20.0 root_total_m=+0.309 max_hip_drop_mm=0.0"
	var t: Dictionary = AnimTweak.parse_reversals("clip.walk: 30f\n" + line + "\n")
	assert_eq(t.keys().size(), 2, "two pairs (%s)" % [t.keys()])
	var r: Dictionary = (t.get(&"run>run_b", [{}]) as Array)[0]
	assert_eq(r.get("clip"), &"run_reverse_l")
	assert_near(float(r.get("u_in", 0.0)), 0.5238, 0.0001)
	assert_near(float(r.get("u_out", 0.0)), 0.2381, 0.0001)
	var w: Dictionary = (t.get(&"walk_back>walk", [{}]) as Array)[0]
	assert_eq([w.get("clip"), w.get("frames")], [&"walk_reverse_back_r", 24])
	assert_near(float(w.get("u_out", 0.0)), 0.7333, 0.0001)
