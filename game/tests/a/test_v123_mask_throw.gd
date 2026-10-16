## D-116 crew_actions (ENV D 6df520b3, LEAD review of the mask-up): a crew body that masks up plays mask_on with the
## third-person weapon holstered for the whole clip (drawn again after it), and the mask appears on the face at the clip's
## `mask_on` event (+-1 frame), never before; a remote replica masked through replication (the RPC, the state snapshot)
## plays the same; a grenade throw plays throw_grenade, re-timed so its `release` lands on the projectile spawn (+-1
## frame). Real cast rig (rook); a case whose clip the rig lacks is skipped (print: ENV D assets not checked out).
extends TestCase

const HEISTER: StringName = &"rook"
const DT: float = 1.0 / 30.0
const DT_THROW: float = 1.0 / 60.0

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
func _crew(loadout: Loadout = null, human: bool = false) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	var info: Dictionary = {"peer_id": 7 if human else 0, "is_ai": not human, "display_name": "Crew"}
	crew.setup(1 if human else 0, info, loadout)
	crew.heister = HEISTER
	crew.net_id = 88300 + (1 if human else 0)
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)  # CrewView.refresh is deferred
	crew.set_physics_process(false)  # the test steps the throwables itself
	if crew.loadout != null and crew.loadout.mask == &"" and crew.loadout.mask_descriptor.is_empty():
		crew.loadout.mask = &"mask.gilded_heron"
	return crew


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null:
		print("[v123] skip %s: the crew body has no animated rig" % what)
		return true
	for c: StringName in clips:
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			print("[v123] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


## The driver steps the AnimationPlayer itself here (manual mode), so clip time and driver time stay in lockstep.
func _manual(d: AnimDriver) -> void:
	d.set_process(false)
	d.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func _step(d: AnimDriver, dt: float) -> void:
	d.tick(dt)
	d.player.advance(dt)


func _mask_of(crew: CrewController) -> Node3D:
	var socket: Node3D = AnimDriver.socket_of(crew, "Head")
	return socket.get_node_or_null(NodePath(CrewView.MASK_NAME)) as Node3D if socket != null else null


## Mask the body through `mask_up` and check the whole clip: weapon holstered, mask at the event, weapon drawn after.
func _check_mask_on(crew: CrewController, mask_up: Callable, what: String) -> void:
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [AnimDriver.MASK_ON], what):
		return
	_manual(d)
	for _i: int in 3:
		_step(d, DT)
	assert_false(crew.masked, "%s: unmasked before" % what)
	assert_ne(d.clip, AnimDriver.MASK_ON, "%s: no mask_on before the mask-up" % what)
	mask_up.call()
	assert_true(crew.masked, "%s: masked" % what)
	var mask: Node3D = _mask_of(crew)
	assert_true(mask != null, "%s: CrewView built the mask at Head/Socket" % what)
	if mask == null:
		return
	assert_false(mask.visible, "%s: the mask is not on the face at the mask-up" % what)
	var event_s: float = AnimTweak.data().mask_on_s()
	var length: float = d.player.get_animation("humanoid/mask_on").length
	var shown_at: float = -1.0
	var shown_pos: float = -1.0
	var ticks: int = 0
	var weapon_seen: bool = false
	while ticks < 120:
		var t: float = d._state_oneshot_t + DT  # the driver time this tick reaches
		d.tick(DT)
		ticks += 1
		if d.clip != AnimDriver.MASK_ON:
			break
		var pos: float = d.player.current_animation_position
		assert_eq(String(d.player.current_animation), "humanoid/mask_on", "%s: the player plays mask_on" % what)
		if d.weapon_visual != null:
			weapon_seen = true
			assert_false(d.weapon_visual.visible, "%s: weapon holstered at %.3f s" % [what, t])
		if mask.visible and shown_at < 0.0:
			shown_at = t
			shown_pos = pos
		elif not mask.visible:
			assert_true(shown_at < 0.0, "%s: the mask stays on once shown (%.3f s)" % [what, t])
			assert_true(t < event_s + DT * 1.01, "%s: mask hidden only before the event (%.3f s)" % [what, t])
		d.player.advance(DT)
	assert_true(weapon_seen, "%s: the crew body holds a third-person weapon" % what)
	assert_true(shown_at >= 0.0, "%s: the mask appeared during mask_on" % what)
	assert_near(shown_at, event_s, DT * 1.01, "%s: mask shown at mask_on@%.3f s +-1 frame (%.3f)" % [what, event_s, shown_at])
	assert_near(shown_pos, event_s, DT * 1.01, "%s: clip frame at the mask (%.3f)" % [what, shown_pos])
	assert_near(ticks * DT, length + DT, DT * 1.5, "%s: mask_on plays its whole length (%d ticks)" % [what, ticks])
	assert_ne(d.clip, AnimDriver.MASK_ON, "%s: mask_on over" % what)
	assert_true(String(d.clip).begins_with("idle_alert"), "%s: into the masked hold (%s)" % [what, d.clip])
	if d.weapon_visual != null:
		assert_true(d.weapon_visual.visible, "%s: weapon drawn after the clip" % what)
	assert_true(mask.visible, "%s: the mask stays on" % what)
	assert_false(d.mask_held(), "%s: nothing held" % what)


func test_mask_on_holsters_the_weapon_and_shows_the_mask_at_the_event() -> void:
	var crew: CrewController = await _crew()
	await _check_mask_on(crew, func() -> void: crew.set_masked(), "server mask-up")


func test_remote_replica_masked_by_rpc_plays_the_same() -> void:
	var crew: CrewController = await _crew(null, true)
	await _check_mask_on(crew, func() -> void: crew._rpc_masked(false), "replica (RPC)")


func test_remote_replica_masked_by_snapshot_plays_the_same() -> void:
	var crew: CrewController = await _crew(null, true)
	await _check_mask_on(crew, func() -> void: NetEntityCodec._apply_crew_state(crew, {"masked": true}), "replica (snapshot)")


func test_downed_mid_mask_on_shows_the_mask() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [AnimDriver.MASK_ON], "cut short"):
		return
	_manual(d)
	_step(d, DT)
	crew.set_masked()
	_step(d, DT)
	var mask: Node3D = _mask_of(crew)
	assert_true(mask != null and not mask.visible, "held during mask_on")
	crew.set_crew_state(Enums.CrewState.DOWNED)
	_step(d, DT)
	assert_ne(d.clip, AnimDriver.MASK_ON, "downed cuts mask_on")
	assert_true(mask != null and mask.visible, "the mask shows when the clip is cut short")


func test_already_masked_body_plays_no_mask_on() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [AnimDriver.MASK_ON], "already masked"):
		return
	_manual(d)
	crew.masked = true  # a body that arrives masked (no masked_changed)
	for _i: int in 4:
		_step(d, DT)
	assert_ne(d.clip, AnimDriver.MASK_ON, "no mask_on without a mask-up")


func _throw_def() -> ThrowableDef:
	var def: ThrowableDef = ThrowableDef.new()
	def.id = &"throwable.test_v123_frag"
	def.kind = ThrownItem.KIND_FRAG
	def.count = 3
	def.damage = 0.0
	def.radius_m = 1.0
	def.fuse_s = 30.0
	ContentDB.inject(ContentDB.THROWABLES, def.id, def)
	return def


func test_throw_plays_throw_grenade_with_release_on_the_spawn() -> void:
	var def: ThrowableDef = _throw_def()
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = def.id
	var crew: CrewController = await _crew(l)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [AnimDriver.THROW_GRENADE], "throw"):
		return
	crew.masked = true  # already masked: no mask_on
	CrewThrowables.set_count(crew, 2)
	var thr: CrewThrowables = crew.throwables
	assert_true(thr != null and thr.can_throw(), "the crew body can throw")
	if thr == null or not thr.can_throw():
		return
	_manual(d)
	for _i: int in 3:
		_step(d, DT_THROW)
	var release_s: float = AnimTweak.data().throw_release_s()
	var windup: float = CombatTweak.data().throw_windup_s
	var hold: CrewIntent = CrewIntent.new()
	hold.throw_item = true
	var at_release: Array[float] = []
	var on_release: Callable = func() -> void:
		at_release.append(d.player.current_animation_position if d.clip == AnimDriver.THROW_GRENADE else -1.0)
	thr.released.connect(on_release)
	var spawned_step: int = -1
	var released_step: int = -1
	var steps: int = 0
	while steps < 90 and spawned_step < 0:
		thr.tick(hold, DT_THROW)
		if get_tree().get_nodes_in_group(ThrownItem.GROUP).size() > 0:
			spawned_step = steps
		if at_release.size() > 0 and released_step < 0:
			released_step = steps
		if steps == 0:
			assert_true(thr.busy(), "pin pulled")
		d.tick(DT_THROW)
		if steps == 0:
			assert_eq(d.clip, AnimDriver.THROW_GRENADE, "throw_grenade starts at the pin pull")
			assert_near(d.player.speed_scale, release_s / windup, 0.001, "re-timed: release@ lands on the windup end")
		elif spawned_step < 0:
			assert_eq(d.clip, AnimDriver.THROW_GRENADE, "throw_grenade plays through the windup")
		d.player.advance(DT_THROW)
		steps += 1
	thr.released.disconnect(on_release)
	assert_true(spawned_step > 0, "the grenade spawned")
	assert_eq(released_step, spawned_step, "released and spawned on the same step")
	assert_eq(at_release.size(), 1, "one release")
	if at_release.size() == 1:
		assert_near(at_release[0], release_s, DT_THROW * 1.01,
			"clip at `release` (%.3f s) when the projectile spawns (%.3f s)" % [release_s, at_release[0]])
	assert_near(spawned_step * DT_THROW, windup, DT_THROW * 1.01, "gameplay release still throw_windup_s after the pin")
	assert_true(d.weapon_visual == null or d.weapon_visual.visible, "the weapon stays in the right hand (D's clip)")
