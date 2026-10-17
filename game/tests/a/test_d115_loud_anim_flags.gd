## D-115 follow-up: ENV D's 3P loud coverage harness flags (loud_anim_coverage, P's AnimCoverage) reproduced on the
## driver. (1) PLAYER_MISMATCH `melee`: PoliceBrain's cuff hold set anim_hint `melee`, a ONESHOT_HINT that was then
## held as the hint idle after its one-shot ended, so the driver kept `melee` while the AnimationPlayer had stopped at
## the end of the non-looping clip. (3) NO_CLIP revive: a turn-in-place / hit flinch one-shot beat the crew bot's
## interact clip. FROZEN: see test_frozen_* below.
extends TestCase

const ANIM_TEST: GDScript = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"\"\n"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _npc(role: StringName = &"police") -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.net_id = 71500 + _nodes.size()
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.add_child(ANIM_TEST._test_rig())
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	AnimDriver.of(npc).set_process(false)
	return npc


func _bot() -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(1, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	crew.heister = &"rook"
	crew.net_id = 88315
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)
	crew.masked = true
	crew.set_physics_process(false)  # no floor: keep the body where the test puts it
	return crew


## The coverage tool's PLAYER_MISMATCH test: the player plays the driver's clip at a non-zero speed.
static func _agrees(d: AnimDriver) -> bool:
	return d.player.is_playing() and d.player.speed_scale != 0.0 \
		and String(d.player.current_animation).ends_with(String(d.clip))


## (1) A melee hint that lingers (any brain) plays the swing once, then the body goes back to its idle / aim: never
## `melee` held on a stopped player.
func test_lingering_melee_hint_never_holds_a_stopped_player() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.COMBAT
	d.tick(0.016)
	npc.get_node("Brain").set(&"anim_hint", &"melee")
	d.tick(0.016)
	assert_eq(d.clip, &"melee", "the melee hint swings once")
	for _i: int in 120:  # 2 s, the clip is 0.5 s
		d.tick(0.016)
		if not _agrees(d):
			break
	assert_true(_agrees(d), "driver '%s' vs player '%s' playing=%s" % [d.clip, d.player.current_animation,
		d.player.is_playing()])
	assert_ne(d.clip, &"melee", "the finished swing is not held (%s)" % d.clip)


## (1) A cop cuffing a downed heister holds the `cuff` hint (interact_low, a loop), as GuardBrain does.
func test_police_cuff_hold_plays_a_loop() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.COMBAT
	npc.get_node("Brain").set(&"anim_hint", &"cuff")
	for _i: int in 180:  # 3 s: police_cuff_time_s
		d.tick(0.016)
	assert_eq(d.clip, &"interact_low", "kneels and cuffs")
	assert_true(_agrees(d), "the player plays it (%s)" % d.player.current_animation)
	var src: String = (load("res://systems/ai/police/police_brain.gd") as GDScript).source_code
	var at: int = src.find("mode = &\"cuff\"")
	assert_true(at > 0 and src.substr(at, 120).contains("anim_hint = &\"cuff\""),
		"PoliceBrain._tick_cuff sets the cuff hint (not melee)")


## (1) The A3-13 windup one-shot (cue.npc_melee_swing) still plays melee and ends with the player.
func test_npc_melee_windup_plays_and_ends_cleanly() -> void:
	var npc: NpcBase = _npc()
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.COMBAT
	d.tick(0.016)
	EventBus.audio_cue_requested.emit(NpcGunner.CUE_MELEE_SWING, Vector3.ZERO, npc.net_id)
	d.tick(0.016)
	assert_eq(d.clip, &"melee", "windup")
	for _i: int in 90:
		d.tick(0.016)
		if d.clip == &"melee" and not _agrees(d):
			break
	assert_true(_agrees(d), "after the windup: driver '%s', player '%s'" % [d.clip, d.player.current_animation])


## (3) A reviving bot shows its interact clip at once even mid turn-in-place, and a hit while reviving is an upper-body
## flinch only (the coverage tool saw turn_r / hit_chest for 0.6 s).
func test_revive_beats_turn_and_hit() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if d == null or d.player == null or not d._has_clip(&"interact_low") or not d._has_clip(&"hit_chest"):
		print("[d115 flags] skip: no animated rig with interact_low / hit_chest")
		return
	d.set_process(false)
	for _i: int in 5:
		d.tick(0.016)
	crew.rotation.y = deg_to_rad(-100.0)  # the bot faces the downed teammate
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("turn_r"), "turning first (%s)" % d.clip)
	EventBus.interaction_started.emit(0, crew.slot, &"revive")
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("interact_"), "revive beats the turn (%s)" % d.clip)
	d._last_hit_react_t = -100.0
	EventBus.damage_applied.emit(crew.net_id, 0, Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"",
		Vector3(0, 1.2, 0), Vector3(0, 0, 1)))
	d.tick(0.016)
	assert_true(String(d.clip).begins_with("interact_"), "a hit does not cut the revive (%s)" % d.clip)
	assert_true(d.flinch_layer != null and d.flinch_layer.active, "the hit is an upper-body flinch")
	EventBus.interaction_cancelled.emit(0, crew.slot)
	crew.crew_state = Enums.CrewState.DOWNED
	d.tick(0.016)
	assert_eq(d.clip, &"downed", "a reviver downed mid-revive shows downed (the harness's `revive|downed`)")


## FROZEN (aim_rifle / aim_pistol / idle_alert_rifle on gunners): every shot's fire one-shot restarted the aim loop on
## frame 0 (idle_alert_<kind>: on the body's fixed loop offset), so on a steady fire cadence the harness's 1 s pose
## samples matched bit for bit. The loop now resumes at its running phase after the one-shot.
func test_frozen_aim_loop_resumes_after_a_shot() -> void:
	var npc: NpcBase = _npc(&"guard")
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.COMBAT
	npc.get_node("Brain").set(&"anim_hint", &"aim")
	d.tick(0.016)
	assert_eq(d.clip, &"aim_pistol", "aiming")
	d.player.seek(0.3, true)  # the loop has been running a while
	var positions: Array[float] = []
	for shot: int in 3:
		var cut_pos: float = d.player.current_animation_position
		var cut_clock: float = d.loop_resume.clock
		EventBus.weapon_fired.emit(npc.net_id, &"", false, Vector3.ZERO)
		d.tick(0.016)
		assert_eq(d.clip, &"fire_pistol", "shot %d fires" % shot)
		while d.clip == &"fire_pistol":
			d.tick(0.016)
		assert_eq(d.clip, &"aim_pistol", "back to the aim loop")
		var want: float = fposmod(cut_pos + d.loop_resume.clock - cut_clock, 1.0)
		assert_near(d.player.current_animation_position, want, 0.02, "shot %d: the aim loop kept its phase" % shot)
		positions.append(d.player.current_animation_position)
	assert_true(absf(positions[0] - positions[1]) > 0.05 and absf(positions[1] - positions[2]) > 0.05,
		"never the same restart frame after every shot (%s)" % [positions])


## FROZEN: idle_alert_<kind> (armed low ready) re-entered after a one-shot resumes too (it used to re-seek the fixed
## per-body weapon_hold offset every time).
func test_frozen_idle_alert_resumes_not_reoffset() -> void:
	var npc: NpcBase = _npc(&"guard")
	var d: AnimDriver = AnimDriver.of(npc)
	npc.alert_state = Enums.AlertState.COMBAT
	d.tick(0.016)
	assert_eq(d.clip, &"idle_alert", "alert idle (the test rig has no idle_alert_<kind>)")
	d.player.seek(0.6, true)
	var cut_clock: float = d.loop_resume.clock
	d.play_oneshot(&"fire_pistol")
	d.tick(0.016)
	while d.clip == &"fire_pistol":
		d.tick(0.016)
	assert_eq(d.clip, &"idle_alert")
	assert_near(d.player.current_animation_position, fposmod(0.6 + d.loop_resume.clock - cut_clock, 1.0), 0.02,
		"resumed at its phase")
