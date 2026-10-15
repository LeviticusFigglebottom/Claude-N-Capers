## PO6-04 (PO playtest 2026-10-15, D-114 §1): "Stealth needs the drill -> camera alarm." On Golden Hour
## (`glasshouse`) the workshop safe must open silently without the drill (the manager's code note or keycard,
## or a slow lockpick fallback), a running drill is investigable noise for guards (not an instant alarm),
## and cameras react only to what they SEE: a running drill outside a camera's cone never alarms it.
## The interactions are driven like a real player: stand at the UsePoint, aim, hold interact through the
## InteractionSystem until the session completes, release (as test_po6_01_drill_place_once.gd).
extends TestCase

const MARGIN_S: float = 1.0
const SEED: int = 7
## (b): the guard must react to the drill within this many seconds.
const GUARD_REACT_S: float = 6.0
## (c): how long the drill runs with the camera looking away.
const CAMERA_WATCH_S: float = 5.0

var _rt: HeistRuntime = null
var _starts: Array[int] = []
var _alarms: Array[StringName] = []
var _on_start: Callable = Callable()
var _on_alarm: Callable = Callable()
var _saved_fallback: PackedFloat32Array = PackedFloat32Array()


func before_each() -> void:
	_starts.clear()
	_alarms.clear()
	_saved_fallback = Tweak.interaction().safe_lockpick_fallback_s.duplicate()
	_on_start = func(id: int, _kind: StringName, _d: float) -> void: _starts.append(id)
	_on_alarm = func(reason: StringName, _src: int) -> void: _alarms.append(reason)
	EventBus.device_started.connect(_on_start)
	EventBus.alarm_raised.connect(_on_alarm)


func after_each() -> void:
	Tweak.interaction().safe_lockpick_fallback_s = _saved_fallback
	for pair: Array in [[EventBus.device_started, _on_start], [EventBus.alarm_raised, _on_alarm]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.clear_bot_intent(0)
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(seed_value: int = SEED) -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", seed_value, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)


func _tagged(tag: StringName) -> Node:
	for n: Node in _rt.mission.find_tagged(tag):
		return n
	return null


func _stealth() -> StealthDirector:
	return _rt.service(G.SVC_STEALTH) as StealthDirector


func _safe() -> Safe:
	return _tagged(&"safe") as Safe


func _drill() -> DrillPoint:
	return _tagged(&"safe_drill") as DrillPoint


## Only the crew stays: no NPC or camera can see the masked crew in the workshop (the route is under test
## here, detection is covered by the S2/S3 tests).
func _no_observers() -> void:
	_rt.isolate_npc(null)
	for cam: Node in _rt.find_by_tag(&"security_camera"):
		cam.get_parent().remove_child(cam)
		cam.queue_free()
	await wait_physics_frames(2)


func _floor_below(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.2, p + Vector3.DOWN * 3.0)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = _rt.get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3) if not hit.is_empty() else p


## Stand at `stand`'s UsePoint (on the floor below it), aim at `comp` and hold interact until the session
## completes (or `limit_s`), then release. True when a session started and ended.
func _hold_aimed(stand: GameplayPrefab, comp: InteractableComponent, limit_s: float) -> bool:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var at: Vector3 = _floor_below(stand.use_point.global_position)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var to: Vector3 = comp.global_position - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-to.x, -to.z)
	i.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	assert_true(_rt.interaction.aimed_component(c) == comp, "aim resolves to %s" % comp.get_parent().name)
	i.interact = true
	var started: bool = await wait_until(func() -> bool: return not _rt.interaction.session(0).is_empty(), 1.0)
	var done: bool = await wait_until(func() -> bool: return _rt.interaction.session(0).is_empty(), limit_s + MARGIN_S)
	i.interact = false
	_rt.clear_bot_intent(0)
	await wait_physics_frames(3)
	return started and done


func _assert_silent_open(how: StringName) -> void:
	var safe: Safe = _safe()
	assert_true(safe.opened, "the safe is open (%s)" % how)
	assert_eq(safe.beaten_by, how, "beaten by %s" % how)
	assert_eq(_drill().runner.state, DeviceRunner.State.IDLE, "the drill was never placed")
	assert_false(_drill().interactable.enabled, "the open safe's drill spot no longer offers 'place the drill'")
	assert_eq(_starts.size(), 0, "no device started (%s)" % [_starts])
	assert_false(_stealth().alarm_raised, "no alarm")
	assert_eq(_alarms.size(), 0, "no alarm_raised (%s)" % [_alarms])
	assert_true(_stealth().camera_countdown() < 0.0, "no camera countdown")
	assert_eq(_rt.mission.objective_state(&"safe"), Enums.ObjectiveState.COMPLETED, "safe objective done")
	assert_eq(_rt.mission.objective_state(&"safe_loot"), Enums.ObjectiveState.ACTIVE, "bag the consignment next")


func _objective(id: StringName) -> Dictionary:
	for o: Dictionary in _rt.mission.objectives():
		if StringName(o["id"]) == id:
			return o
	return {}


# --- (a) the silent stealth routes -----------------------------------------------------------------

func test_po6_04_route_is_discoverable() -> void:
	await _launch()
	var note: Node = _tagged(&"code_note")
	assert_true(note is CodeNote, "the surviving code note carries the code_note objective tag")
	var code: Dictionary = _objective(&"code")
	assert_eq(int(code.get("state", -1)), Enums.ObjectiveState.ACTIVE, "find-the-code objective active")
	assert_has((code.get("data", {}) as Dictionary).get("marker_tags", []), &"code_note", "code objective marks the note")
	var kc: Dictionary = _objective(&"keycard")
	assert_eq(int(kc.get("state", -1)), Enums.ObjectiveState.ACTIVE, "keycard objective active")
	var safe_data: Dictionary = _objective(&"safe").get("data", {})
	assert_has(safe_data.get("marker_tags", []), &"safe_reader", "safe objective marks the keycard reader")
	for m: StringName in [&"keycard", &"code", &"lockpick", &"drill"]:
		assert_has(safe_data.get("methods", []), m, "safe objective lists %s" % m)
	assert_true(_safe().lockpick_fallback, "the safe takes the slow lockpick fallback")


func test_po6_04_code_note_opens_the_safe_without_drill_or_alarm() -> void:
	await _launch()
	await _no_observers()
	var note: CodeNote = _tagged(&"code_note") as CodeNote
	var safe: Safe = _safe()
	assert_true(note != null and safe != null, "code note and safe")
	assert_true(await _hold_aimed(note, note.interactable, Tweak.interaction().read_note_s), "read the code note")
	assert_true(CodeRegistry.of(_rt).is_known(&"glasshouse_safe"), "the crew knows the safe code")
	assert_eq(_rt.mission.objective_state(&"code"), Enums.ObjectiveState.COMPLETED, "code objective done")
	assert_eq(_rt.mission.objective_state(&"keycard"), Enums.ObjectiveState.COMPLETED, "keycard objective skipped")
	assert_eq(safe.method_for(_rt.crew_controller(0)), &"code", "the safe now offers the keypad")
	assert_true(await _hold_aimed(safe, safe.interactable, Tweak.interaction().keypad_s), "entered the code")
	_assert_silent_open(&"code")


func test_po6_04_keycard_opens_the_safe_without_drill_or_alarm() -> void:
	await _launch()
	await _no_observers()
	var card: KeycardPickup = _tagged(&"keycard") as KeycardPickup
	var reader: KeycardReader = _tagged(&"safe_reader") as KeycardReader
	assert_true(card != null and reader != null, "keycard and reader")
	assert_true(await _hold_aimed(card, card.interactable, Tweak.interaction().item_pickup_s), "took the keycard")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(c.item_count(&"item.keycard"), 1, "the crew carries the keycard")
	assert_eq(_rt.mission.objective_state(&"keycard"), Enums.ObjectiveState.COMPLETED, "keycard objective done")
	assert_true(await _hold_aimed(reader, reader.interactable, Tweak.interaction().keycard_s), "swiped the reader")
	assert_true(reader.used, "the reader took the card")
	_assert_silent_open(&"keycard")


func test_po6_04_lockpick_fallback_in_stealth_only() -> void:
	await _launch()
	await _no_observers()
	var safe: Safe = _safe()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_false(Modifiers.flag(c.slot, &"interaction.can_lockpick_safes"), "no lockpick skill")
	assert_eq(safe.method_for(c), &"lockpick", "code unknown: the safe offers the slow lockpick, not the drill")
	var slow: float = safe.interactable.duration_override.call(c, 0.0)
	assert_eq(slow, Tweak.interaction().safe_lockpick_fallback_s[Safe.Size.LARGE], "the large-safe fallback time")
	assert_true(slow > Tweak.interaction().safe_lockpick_s, "slower than the skilled lockpick")
	# Shorten the hold for the test only; the hold itself is the real InteractionSystem path.
	Tweak.interaction().safe_lockpick_fallback_s = PackedFloat32Array([1.0, 1.0, 1.5])
	assert_true(await _hold_aimed(safe, safe.interactable, 1.5), "picked the lock")
	_assert_silent_open(&"lockpick")


func test_po6_04_no_lockpick_fallback_when_loud() -> void:
	await _launch()
	var safe: Safe = _safe()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_stealth().raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_eq(safe.method_for(c), &"drill", "loud: the drill is the way")


# --- (b) drill noise is investigated, not an alarm --------------------------------------------------

func test_po6_04_guard_investigates_a_running_drill() -> void:
	await _launch()
	var guards: Array[Node] = _rt.npcs(&"guard")
	assert_true(not guards.is_empty(), "a guard")
	var guard: NpcBase = guards[0] as NpcBase
	_rt.isolate_npc(guard)
	for cam: Node in _rt.find_by_tag(&"security_camera"):
		cam.get_parent().remove_child(cam)
		cam.queue_free()
	var drill: DrillPoint = _drill()
	# Workshop door corridor side, ~9 m from the drill, looking away from it (out of sight).
	var spot: Vector3 = _floor_below(Vector3(7.5, 0.5, 9.0))
	guard.global_position = spot
	await wait_physics_frames(10)
	assert_eq(guard.alert_state, Enums.AlertState.CALM, "guard calm before the drill")
	var d0: float = guard.global_position.distance_to(drill.global_position)
	assert_true(d0 < Tweak.stealth().drill_radius_m, "guard within drill earshot (%.1f m)" % d0)
	drill.runner.place(0, drill.effective_duration())
	var reacted: bool = await wait_until(func() -> bool:
		return guard.alert_state == Enums.AlertState.CURIOUS or guard.alert_state == Enums.AlertState.INVESTIGATING,
		GUARD_REACT_S)
	assert_true(reacted, "the guard heard the drill and went to investigate")
	assert_false(_stealth().alarm_raised, "hearing the drill is not an alarm")
	var focus: Variant = guard.get_node(^"Brain").get(&"focus_position")
	assert_true(focus is Vector3 and (focus as Vector3).distance_to(drill.global_position) < 0.5, "investigating the drill")
	var investigating: bool = await wait_until(func() -> bool:
		return guard.alert_state == Enums.AlertState.INVESTIGATING, GUARD_REACT_S)
	assert_true(investigating, "the '?' beat ends in INVESTIGATING")
	# The workshop door is shut, so his path goes round; within the investigate budget he gets closer.
	var walked: bool = await wait_until(func() -> bool:
		return guard.global_position.distance_to(drill.global_position) < d0 - 1.5, Tweak.stealth().investigate_budget_s)
	assert_true(walked, "the guard walks to the drill")
	assert_false(guard.alert_state == Enums.AlertState.ALARMED or guard.alert_state == Enums.AlertState.COMBAT,
		"no alarm while investigating the drill (state %d)" % guard.alert_state)
	assert_false(_stealth().alarm_raised, "still no alarm")
	assert_eq(_alarms.size(), 0, "no alarm_raised (%s)" % [_alarms])


# --- (c) cameras react only to what they see --------------------------------------------------------

func _aim_camera(cam: SecurityCamera, pos: Vector3, at: Vector3) -> void:
	cam.pan_deg = 0.0
	cam.global_transform = Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)
	await wait_physics_frames(3)


func test_po6_04_camera_ignores_a_drill_out_of_view() -> void:
	await _launch()
	_rt.isolate_npc(null)
	var cams: Array[Node] = _rt.find_by_tag(&"security_camera")
	assert_true(not cams.is_empty(), "a live camera")
	var cam: SecurityCamera = cams[0] as SecurityCamera
	for other: Node in cams:
		if other != cam:
			other.get_parent().remove_child(other)
			other.queue_free()
	var drill: DrillPoint = _drill()
	var target: Vector3 = drill.global_position
	# In the workshop, 3 m in front of the safe and 2.4 m up, looking AWAY from the drill (+Z, to the door).
	var cam_pos: Vector3 = target + Vector3(0.0, 1.4, 2.6)
	await _aim_camera(cam, cam_pos, cam_pos + Vector3(0.0, -0.3, 1.0))
	var to: Vector3 = target - cam.eye_position()
	assert_true(rad_to_deg(cam.look_forward().angle_to(to)) > cam.fov_deg, "the drill is outside the cone")
	assert_true(to.length() < float(Tweak.stealth().stimuli[&"drill"]["range"]), "but within drill stimulus range")
	drill.runner.place(0, drill.effective_duration())
	await wait_seconds(CAMERA_WATCH_S)
	assert_eq(drill.runner.state, DeviceRunner.State.RUNNING, "the drill ran the whole time")
	assert_false(cam.alerted, "the camera never alerted on the unseen drill")
	assert_true(_stealth().camera_countdown() < 0.0, "no camera countdown")
	assert_false(_stealth().alarm_raised, "no alarm")
	# Control: the same camera turned to face the drill sees it (S4.4: cameras detect drills they see).
	await _aim_camera(cam, cam_pos, target)
	var seen: bool = await wait_until(func() -> bool: return cam.alerted, 3.0)
	assert_true(seen, "the camera alerts once the drill is inside its cone")
	assert_true(_stealth().camera_countdown() >= 0.0 or _stealth().alarm_raised, "S3.5 countdown started")
