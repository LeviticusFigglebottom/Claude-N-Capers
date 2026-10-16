## characters.md v1.23 (D-116 crew_actions, ENV D 6df520b3; LEAD rulings on V1.23): third-person crew actions.
## - mask_on plays DURING the mask-up hold, its time following the replicated mask_progress (the `mask_on` event at
##   18/30 of the hold), the mask on the face from the event; the clip finishes once masked, then the weapon draws. A
##   cancelled hold blends out with no mask. A forced mask-up (no hold) plays the whole clip.
## - a remote replica (mask_progress and masked from the state diffs, or the masked RPC) plays the same.
## - standing: full body; moving: the ActionLayer upper-body layer over locomotion (the legs keep walking).
## - casing (unmasked) shows no weapon; a body spawned masked is armed at once.
## - throw_grenade from the pin, `release` on the projectile spawn (+-1 frame), the grenade (ThrowableDef.model) at
##   HandL/Socket until `release`.
## Real cast rig (rook); a case whose clip the rig lacks is skipped (print: ENV D assets not checked out).
extends TestCase

const HEISTER: StringName = &"rook"
const DT: float = 1.0 / 30.0
const DT_THROW: float = 1.0 / 60.0
const MASK_ID: StringName = &"mask.gilded_heron"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for item: Node in get_tree().get_nodes_in_group(ThrownItem.GROUP):
		item.queue_free()
	ContentDB.clear_cache()
	await wait_frames(2)


## An unmasked crew body with the rook rig. `human`: a remote human teammate (peer 7), as a client sees it.
## `masked_at_spawn`: masked before the driver's first tick (a loud-only start, a late join).
func _crew(loadout: Loadout = null, human: bool = false, masked_at_spawn: bool = false) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	var info: Dictionary = {"peer_id": 7 if human else 0, "is_ai": not human, "display_name": "Crew"}
	crew.setup(1 if human else 0, info, loadout)
	crew.heister = HEISTER
	crew.net_id = 88300 + (1 if human else 0)
	if crew.loadout != null and crew.loadout.mask == &"" and crew.loadout.mask_descriptor.is_empty():
		crew.loadout.mask = MASK_ID
	add_child(crew)
	_nodes.append(crew)
	if masked_at_spawn:
		crew.set_masked(true)
	await wait_frames(3)  # CrewView.refresh is deferred
	crew.set_physics_process(false)  # the test steps the hold / the throwables itself
	return crew


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null or d.crew_action == null:
		print("[v123] skip %s: the crew body has no animated rig" % what)
		return true
	for c: StringName in clips:
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			print("[v123] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


## The test steps the AnimationPlayer itself (manual mode), so clip time and driver time stay in lockstep.
func _manual(d: AnimDriver) -> void:
	d.set_process(false)
	d.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _step(d: AnimDriver, dt: float) -> void:
	d.tick(dt)
	d.player.advance(dt)


func _mask_of(crew: CrewController) -> Node3D:
	var socket: Node3D = AnimDriver.socket_of(crew, "Head")
	return socket.get_node_or_null(NodePath(CrewView.MASK_NAME)) as Node3D if socket != null else null


## A mask shows on the face: the hold preview or CrewView's mask, visible.
func _mask_on_face(d: AnimDriver, crew: CrewController) -> bool:
	if d.crew_action.mask_preview() != null:
		return true
	var m: Node3D = _mask_of(crew)
	return m != null and m.visible


func _weapon_hidden(d: AnimDriver) -> bool:
	return d.weapon_visual == null or not d.weapon_visual.visible


func _up_s() -> float:
	return Tweak.crew().mask_up_time_s


## Run a whole mask-up hold through `set_progress` (called per tick with the server progress), masking at 1.0 through
## `mask_up`; checks the clip follows the progress, the mask at 18/30 of the hold, the finish and the weapon draw.
func _check_hold(crew: CrewController, set_progress: Callable, mask_up: Callable, what: String) -> void:
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], what):
		return
	_manual(d)
	for _i: int in 3:
		_step(d, DT)
	assert_true(_weapon_hidden(d), "%s: casing: no weapon" % what)
	var ca: CrewActionAnim = d.crew_action
	var length: float = d.player.get_animation("humanoid/mask_on").length
	var event_frac: float = AnimTweak.data().mask_on_s() / length
	var p: float = 0.0
	var shown_p: float = -1.0
	var ticks: int = 0
	while not crew.masked and ticks < 200:
		p = minf(p + DT / _up_s(), 1.0)
		set_progress.call(p)
		if p >= 1.0:
			mask_up.call()
		d.tick(DT)
		ticks += 1
		if crew.masked:
			break
		if crew.mask_progress <= 0.0:
			d.player.advance(DT)
			continue  # a replica before its first diff
		assert_eq(d.clip, CrewActionAnim.MASK_ON, "%s: mask_on during the hold (p %.2f)" % [what, p])
		assert_near(ca.time / length, p, DT / _up_s() * 2.01, "%s: clip time follows the hold (p %.2f)" % [what, p])
		assert_near(d.player.current_animation_position, ca.time, 0.002, "%s: the player is at the driven time" % what)
		assert_true(_weapon_hidden(d), "%s: weapon holstered during the hold" % what)
		if _mask_on_face(d, crew) and shown_p < 0.0:
			shown_p = p
		elif not _mask_on_face(d, crew):
			assert_true(shown_p < 0.0, "%s: the mask stays once on" % what)
		d.player.advance(DT)
	assert_true(crew.masked, "%s: masked at the end of the hold" % what)
	assert_true(shown_p >= 0.0, "%s: the mask went on during the hold" % what)
	assert_near(shown_p, event_frac, DT / _up_s() * 1.01 + 0.067,
		"%s: the mask at 18/30 of the hold (+-1 frame and one diff) (%.3f)" % [what, shown_p])
	var finish: int = 0
	while ca.action == CrewActionAnim.MASK_ON and finish < 60:
		assert_true(_weapon_hidden(d), "%s: weapon holstered until mask_on ends" % what)
		_step(d, DT)
		finish += 1
	assert_true(finish <= 4, "%s: the clip finishes from the end of the hold (%d ticks)" % [what, finish])
	_step(d, DT)
	assert_ne(d.clip, CrewActionAnim.MASK_ON, "%s: mask_on over" % what)
	assert_true(String(d.clip).begins_with("idle_alert"), "%s: the masked hold (%s)" % [what, d.clip])
	assert_true(d.weapon_visual != null and d.weapon_visual.visible, "%s: weapon drawn after mask_on" % what)
	var m: Node3D = _mask_of(crew)
	assert_true(m != null and m.visible, "%s: CrewView's mask on" % what)
	assert_true(ca.mask_preview() == null, "%s: the preview is gone" % what)


func test_server_hold_drives_mask_on_from_mask_progress() -> void:
	var crew: CrewController = await _crew()
	var hold: CrewIntent = CrewIntent.new()
	hold.mask_up = true
	crew.intent = hold
	var set_p: Callable = func(_p: float) -> void: crew._tick_server_actions(DT)  # the real S1.2 hold
	await _check_hold(crew, set_p, func() -> void: pass, "server hold")


func test_replica_hold_from_state_diffs() -> void:
	var crew: CrewController = await _crew(null, true)
	var n: Array[int] = [0]
	var set_p: Callable = func(p: float) -> void:
		n[0] += 1
		if n[0] % 2 == 0 or p >= 1.0:  # 15 Hz diffs (HeistNetSync.SYNC_HZ) at 30 fps
			NetEntityCodec._apply_crew_state(crew, {"mp": p})
	var masked: Callable = func() -> void: NetEntityCodec._apply_crew_state(crew, {"masked": true, "mp": 1.0})
	await _check_hold(crew, set_p, masked, "replica (diffs)")


func test_cancelled_hold_blends_out_with_no_mask() -> void:
	var crew: CrewController = await _crew(null, true)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], "cancel"):
		return
	_manual(d)
	_step(d, DT)
	var p: float = 0.0
	while p < 0.8:
		p += DT / _up_s()
		crew.mask_progress = p
		_step(d, DT)
	assert_eq(d.clip, CrewActionAnim.MASK_ON, "holding")
	assert_true(d.crew_action.mask_preview() != null, "past the event: mask on the face")
	crew.mask_progress = 0.0  # released early
	_step(d, DT)
	assert_eq(d.crew_action.action, &"", "the action ends")
	assert_ne(d.clip, CrewActionAnim.MASK_ON, "mask_on out")
	assert_near(d.last_blend_s, AnimTweak.data().blend_s, 0.001, "crossfaded out")
	assert_false(_mask_on_face(d, crew), "no mask after a cancel")
	assert_true(_weapon_hidden(d), "still casing: no weapon")
	assert_false(crew.masked, "unmasked")


func test_forced_mask_plays_the_whole_clip() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], "forced"):
		return
	_manual(d)
	for _i: int in 3:
		_step(d, DT)
	crew.set_masked(true)  # detection / alarm: no hold
	var mask: Node3D = _mask_of(crew)
	assert_true(mask != null and not mask.visible, "the mask is not on the face at the mask-up")
	var event_s: float = AnimTweak.data().mask_on_s()
	var shown_t: float = -1.0
	var ticks: int = 0
	while ticks < 90:
		d.tick(DT)
		ticks += 1
		if d.crew_action.action != CrewActionAnim.MASK_ON:
			break
		assert_eq(d.clip, CrewActionAnim.MASK_ON, "full-body mask_on")
		assert_true(_weapon_hidden(d), "weapon holstered")
		if mask.visible and shown_t < 0.0:
			shown_t = d.crew_action.time
		d.player.advance(DT)
	assert_near(shown_t, event_s, DT * 1.01, "mask at mask_on@ (%.3f)" % shown_t)
	assert_near(ticks * DT, d.player.get_animation("humanoid/mask_on").length + DT, DT * 1.5, "the whole clip")
	_step(d, DT)
	assert_true(d.weapon_visual != null and d.weapon_visual.visible, "weapon drawn after")


func test_replica_masked_by_rpc_plays_mask_on() -> void:
	var crew: CrewController = await _crew(null, true)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], "rpc"):
		return
	_manual(d)
	_step(d, DT)
	crew._rpc_masked(false)
	_step(d, DT)
	assert_eq(d.clip, CrewActionAnim.MASK_ON, "the RPC replica plays mask_on")
	assert_true(_weapon_hidden(d), "holstered")


func test_downed_mid_mask_on_shows_the_mask() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], "cut short"):
		return
	_manual(d)
	_step(d, DT)
	crew.set_masked(true)
	_step(d, DT)
	var mask: Node3D = _mask_of(crew)
	assert_true(mask != null and not mask.visible, "held during mask_on")
	crew.set_crew_state(Enums.CrewState.DOWNED)
	_step(d, DT)
	assert_ne(d.clip, CrewActionAnim.MASK_ON, "downed cuts mask_on")
	assert_true(mask != null and mask.visible, "the mask shows when the clip is cut short")


func test_casing_no_weapon_spawned_masked_armed_at_once() -> void:
	var casing: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(casing)
	if _missing(d, [], "casing"):
		return
	assert_true(d.weapon_visual != null, "the body has a third-person weapon")
	assert_true(_weapon_hidden(d), "casing (unmasked): no weapon (PD2)")
	var armed: CrewController = await _crew(null, true, true)
	var d2: AnimDriver = AnimDriver.of(armed)
	assert_true(armed.masked, "spawned masked")
	assert_eq(d2.crew_action.action, &"", "no mask_on for a body spawned masked")
	assert_true(d2.weapon_visual != null and d2.weapon_visual.visible, "armed at once")
	var m: Node3D = _mask_of(armed)
	assert_true(m != null and m.visible, "masked at once")


## Walk the body along -Z at `speed` m/s for `n` ticks (the driver reads velocity from position deltas).
func _walk(d: AnimDriver, crew: CrewController, speed: float, n: int, each: Callable = Callable()) -> void:
	for _i: int in n:
		crew.position += Vector3(0.0, 0.0, -speed * DT)
		crew.velocity = Vector3(0.0, 0.0, -speed)  # the server reads CharacterBody3D.velocity
		if each.is_valid():
			each.call()
		_step(d, DT)


func test_moving_plays_the_action_as_an_upper_body_layer() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.MASK_ON], "layer"):
		return
	_manual(d)
	var p: Array[float] = [0.0]
	var hold: Callable = func() -> void:
		p[0] = minf(p[0] + DT / _up_s(), 0.95)
		crew.mask_progress = p[0]
	_walk(d, crew, 1.6, 6)
	_walk(d, crew, 1.6, 10, hold)
	var ca: CrewActionAnim = d.crew_action
	assert_eq(ca.action, CrewActionAnim.MASK_ON, "masking while walking")
	assert_ne(d.clip, CrewActionAnim.MASK_ON, "the legs keep locomotion (%s)" % d.clip)
	assert_true(String(d.clip).begins_with("walk") or String(d.clip).begins_with("run"), "locomotion (%s)" % d.clip)
	assert_true(ca.layered(), "layered")
	assert_true(ca.layer != null and ca.layer.active and ca.layer.clip == CrewActionAnim.MASK_ON, "ActionLayer carries mask_on")
	assert_near(ca.layer.time, ca.time, 0.0001, "the layer at the driven time")
	assert_true(ca.layer.influence > 0.99, "full weight on the upper body")
	assert_true(ca.layer.bone_count() > 10 and not UpperBodyLayer.filtered("thigh.L"), "upper body only")
	# Stop: full body.
	crew.velocity = Vector3.ZERO
	for _i: int in 6:
		hold.call()
		_step(d, DT)
	assert_eq(d.clip, CrewActionAnim.MASK_ON, "standing: full-body mask_on")
	assert_false(ca.layered(), "not layered standing")
	assert_true(ca.layer.influence < 1.0, "the layer blends out")


func _throw_def() -> ThrowableDef:
	var def: ThrowableDef = ThrowableDef.new()
	def.id = &"throwable.test_v123_frag"
	def.kind = ThrownItem.KIND_FRAG
	def.count = 3
	def.damage = 0.0
	def.radius_m = 1.0
	def.fuse_s = 30.0
	def.model = load("res://world/props/throwable/prop_throwable_frag.tscn") as PackedScene
	ContentDB.inject(ContentDB.THROWABLES, def.id, def)
	return def


func _thrower() -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = _throw_def().id
	var crew: CrewController = await _crew(l, false, true)
	CrewThrowables.set_count(crew, 2)
	return crew


func test_throw_release_on_the_spawn_with_the_grenade_in_hand() -> void:
	var crew: CrewController = await _thrower()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.THROW_GRENADE], "throw"):
		return
	var thr: CrewThrowables = crew.throwables
	assert_true(thr != null and thr.can_throw(), "the crew body can throw")
	if thr == null or not thr.can_throw():
		return
	_manual(d)
	for _i: int in 3:
		_step(d, DT_THROW)
	var ca: CrewActionAnim = d.crew_action
	var release_s: float = AnimTweak.data().throw_release_s()
	var windup: float = CombatTweak.data().throw_windup_s
	var hold: CrewIntent = CrewIntent.new()
	hold.throw_item = true
	var at_release: Array[float] = []
	var on_release: Callable = func() -> void:
		at_release.append(d.player.current_animation_position if d.clip == CrewActionAnim.THROW_GRENADE else -1.0)
	thr.released.connect(on_release)
	var hand_l: Node3D = AnimDriver.socket_of(crew, "HandL")
	var spawned_step: int = -1
	var item_gone_step: int = -1
	var steps: int = 0
	while steps < 90 and spawned_step < 0:
		thr.tick(hold, DT_THROW)
		if get_tree().get_nodes_in_group(ThrownItem.GROUP).size() > 0:
			spawned_step = steps
		d.tick(DT_THROW)
		if steps == 0:
			assert_eq(d.clip, CrewActionAnim.THROW_GRENADE, "throw_grenade starts at the pin pull")
			assert_near(d.player.speed_scale, release_s / windup, 0.001, "re-timed: release@ lands on the windup end")
			assert_true(ca.held_item() != null and ca.held_item().get_parent() == hand_l, "the grenade at HandL/Socket")
		elif spawned_step < 0:
			assert_eq(d.clip, CrewActionAnim.THROW_GRENADE, "throw_grenade through the windup")
		if ca.held_item() == null and item_gone_step < 0:
			item_gone_step = steps
		d.player.advance(DT_THROW)
		steps += 1
	thr.released.disconnect(on_release)
	assert_true(spawned_step > 0, "the grenade spawned")
	assert_true(absi(item_gone_step - spawned_step) <= 1,
		"the held grenade goes at `release`, with the spawn +-1 frame (%d / %d)" % [item_gone_step, spawned_step])
	assert_eq(at_release.size(), 1, "one release")
	if at_release.size() == 1:
		assert_near(at_release[0], release_s, DT_THROW * 1.01,
			"clip at `release` (%.3f s) when the projectile spawns (%.3f s)" % [release_s, at_release[0]])
	assert_near(spawned_step * DT_THROW, windup, DT_THROW * 1.01, "gameplay release still throw_windup_s after the pin")
	assert_true(d.weapon_visual != null and d.weapon_visual.visible, "the weapon stays in the right hand (D's clip)")


func test_throw_while_moving_is_layered() -> void:
	var crew: CrewController = await _thrower()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [CrewActionAnim.THROW_GRENADE], "throw moving"):
		return
	_manual(d)
	var hold: CrewIntent = CrewIntent.new()
	hold.throw_item = true
	_walk(d, crew, 3.0, 6)
	_walk(d, crew, 3.0, 6, func() -> void: crew.throwables.tick(hold, DT))
	var ca: CrewActionAnim = d.crew_action
	assert_eq(ca.action, CrewActionAnim.THROW_GRENADE, "throwing on the run")
	assert_ne(d.clip, CrewActionAnim.THROW_GRENADE, "the legs keep running (%s)" % d.clip)
	assert_true(ca.layer.active and ca.layer.clip == CrewActionAnim.THROW_GRENADE, "ActionLayer carries the throw")
	assert_true(d.left_hand_ik == null or d.left_hand_ik.influence < 1.0, "the left hand leaves the weapon to throw")
