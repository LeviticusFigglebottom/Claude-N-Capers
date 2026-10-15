## PO6-01 (PO playtest 2026-10-15): on Golden Hour (`glasshouse`) the drill needed placing twice: the first hold
## played the place sound but no drill appeared, the second placed it. The WorkshopSafe (methods keycard/code/drill)
## ran its own invisible DeviceRunner when its Interactable was the aimed one, 0.3 m from the SafeDrill spot that
## shows the device. Now the safe places the SafeDrill's device. Driven like a real player: stand at a UsePoint,
## aim (no explicit target id), hold interact through the InteractionSystem until it completes, release.
extends TestCase

const MARGIN_S: float = 1.0

var _rt: HeistRuntime = null
var _starts: Array[int] = []
var _loop_cues: Array[int] = []
var _on_start: Callable = Callable()
var _on_cue: Callable = Callable()


func before_each() -> void:
	_starts.clear()
	_loop_cues.clear()
	_on_start = func(id: int, _kind: StringName, _d: float) -> void: _starts.append(id)
	_on_cue = func(cue_id: StringName, _p: Vector3, id: int) -> void:
		if cue_id == &"cue.drill_loop":
			_loop_cues.append(id)
	EventBus.device_started.connect(_on_start)
	EventBus.audio_cue_requested.connect(_on_cue)


func after_each() -> void:
	for pair: Array in [[EventBus.device_started, _on_start], [EventBus.audio_cue_requested, _on_cue]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.clear_bot_intent(0)
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)


func _tagged(tag: StringName) -> Node:
	for n: Node in _rt.mission.find_tagged(tag):
		return n
	return null


## Stand at `stand`'s UsePoint, aim at `comp` and hold interact until the session completes (or the limit), then release.
func _hold_aimed(stand: GameplayPrefab, comp: InteractableComponent) -> bool:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, stand.use_point.global_position + Vector3(0, 0.05, 0)))
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
	var done: bool = await wait_until(func() -> bool: return _rt.interaction.session(0).is_empty(),
			Tweak.interaction().drill_place_s + MARGIN_S)
	i.interact = false
	_rt.clear_bot_intent(0)
	await wait_physics_frames(3)
	return started and done


func _assert_one_drill(drill: DrillPoint, safe: Safe) -> void:
	assert_eq(drill.runner.state, DeviceRunner.State.RUNNING, "the drill runs after ONE hold")
	assert_true(safe.runner == drill.runner, "the safe shares the SafeDrill's runner (no second, invisible drill)")
	assert_true(drill.device_node != null and is_instance_valid(drill.device_node), "the drill device is shown")
	assert_true(drill.device_node != null and drill.device_node.is_visible_in_tree(), "the drill device is visible")
	assert_eq(_starts.size(), 1, "exactly one device_started (%s)" % [_starts])
	assert_eq(_starts[0] if not _starts.is_empty() else 0, drill.net_id, "started on the SafeDrill (mission tag safe_drill)")
	assert_eq(_loop_cues.size(), 1, "the drill place/loop cue fired exactly once (%s)" % [_loop_cues])


func test_po6_01_one_hold_on_the_safe_places_the_visible_drill() -> void:
	await _launch()
	var drill: DrillPoint = _tagged(&"safe_drill") as DrillPoint
	var safe: Safe = _tagged(&"safe") as Safe
	assert_true(drill != null and safe != null, "safe and drill tagged")
	assert_eq(drill.runner.state, DeviceRunner.State.IDLE, "drill idle at start")
	# PO6-04: in stealth the safe itself offers the slow silent lockpick first (Safe.lockpick_fallback); this
	# test is about the drill method of the safe's Interactable, so the fallback is switched off here.
	safe.lockpick_fallback = false
	assert_eq(safe.method_for(_rt.crew_controller(0)), &"drill", "the safe offers the drill (code unknown)")
	assert_true(await _hold_aimed(safe, safe.interactable), "one hold on the safe completed")
	_assert_one_drill(drill, safe)
	# The drill spot now refuses with the device-running reason: there is nothing left to place.
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(drill.interactable.availability(c), DrillPoint.BLOCK_RUNNING, "drill spot: device running")
	assert_eq(safe.interactable.availability(c), DrillPoint.BLOCK_RUNNING, "safe: device running (not the reasonless block)")


func test_po6_01_one_hold_on_the_drill_spot_places_the_visible_drill() -> void:
	await _launch()
	var drill: DrillPoint = _tagged(&"safe_drill") as DrillPoint
	var safe: Safe = _tagged(&"safe") as Safe
	assert_true(await _hold_aimed(drill, drill.interactable), "one hold on the drill spot completed")
	_assert_one_drill(drill, safe)
	assert_false(safe.method_for(_rt.crew_controller(0)) == &"drill", "the safe offers no second drill")
