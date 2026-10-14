## PO-11 (S1.1): while the crew is casing (unmasked), nothing it does may scare a civilian: walking up to
## every civilian on the real map, shouting at them (F with nothing aimed is a shout), pressing F,
## trying to run, opening the unlocked doors, lifting the casing keycard, with the AI bots out of the van
## following the player. No civilian may leave its calm states (CALM; never PANICKED / INTIMIDATED /
## TIED, i.e. no flee, no down, no hostage) and none may report (no alarm). Then the player masks up
## and the same shout DOES intimidate (the gate is on casing, not a broken shout).
## Every civilian alert-state change is logged with its likely cause (crew_spotted / stimulus / noise
## / shout) so a failure says what scared them.
extends TestCase

const CALM_STATES: Array[int] = [Enums.AlertState.CALM]

var _rt: HeistRuntime = null
var _log: Array[String] = []
var _cause: Dictionary[int, String] = {}
var _intimidated: int = 0
var _fled: int = 0
var _tied: int = 0
var _alarms: Array[StringName] = []
var _shouting: bool = false
var _doors_opened: int = 0
var _cards_taken: int = 0


func before_each() -> void:
	_log.clear()
	_cause.clear()
	_intimidated = 0
	_fled = 0
	_tied = 0
	_alarms.clear()
	_doors_opened = 0
	_cards_taken = 0
	EventBus.npc_alert_state_changed.connect(_on_alert)
	EventBus.civilian_intimidated.connect(_on_intimidated)
	EventBus.civilian_fled.connect(_on_fled)
	EventBus.civilian_tied.connect(_on_tied)
	EventBus.alarm_raised.connect(_on_alarm)


func after_each() -> void:
	for pair: Array in [[EventBus.npc_alert_state_changed, _on_alert], [EventBus.civilian_intimidated, _on_intimidated],
			[EventBus.civilian_fled, _on_fled], [EventBus.civilian_tied, _on_tied], [EventBus.alarm_raised, _on_alarm]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


# --- Logging -----------------------------------------------------------------------------------

func _is_civ_id(net_id: int) -> bool:
	var n: NpcBase = Ids.lookup(net_id) as NpcBase
	return n != null and n.role == &"civilian"


func _on_alert(net_id: int, old_state: int, new_state: int) -> void:
	if not _is_civ_id(net_id):
		return
	var cause: String = _cause.get(net_id, "shout" if _shouting else "no stimulus")
	_log.append("civ %d: %s -> %s (cause: %s)" % [net_id, Enums.AlertState.keys()[old_state],
		Enums.AlertState.keys()[new_state], cause])


func _on_intimidated(_npc: int, _slot: int) -> void:
	_intimidated += 1


func _on_fled(_npc: int) -> void:
	_fled += 1


func _on_tied(_npc: int, _slot: int) -> void:
	_tied += 1


func _on_alarm(reason: StringName, _src: int) -> void:
	_alarms.append(reason)


func _watch_causes() -> void:
	for n: Node in _rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		var id: int = npc.net_id
		npc.crew_spotted.connect(func(c: Node) -> void: _cause[id] = "crew_spotted %s" % c.name)
		npc.stimulus_spotted.connect(func(_s: int, kind: StringName, _p: Vector3) -> void:
			_cause[id] = "stimulus %s" % kind)
		npc.noise_heard.connect(func(_p: Vector3, kind: StringName, _src: int) -> void: _cause[id] = "noise %s" % kind)


# --- Driving -----------------------------------------------------------------------------------

func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


func _intent(yaw: float) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = yaw
	return i


## Teleport the player (and the following bots just behind) to `pos`, looking at `look_at`.
func _go(pos: Vector3, look_at: Vector3) -> float:
	var yaw: float = _yaw_to(pos, look_at)
	_rt.teleport_crew(0, Transform3D(Basis(Vector3.UP, yaw), pos))
	var back: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	for s: int in [1, 2, 3]:
		if _rt.crew_controller(s) != null:
			_rt.teleport_crew(s, Transform3D(Basis(Vector3.UP, yaw), pos + back * (0.9 * s) + Vector3(0.6 * (s - 2), 0, 0)))
	_rt.set_bot_intent(0, _intent(yaw))
	await wait_physics_frames(3)
	return yaw


func _shout(yaw: float) -> void:
	var i: CrewIntent = _intent(yaw)
	i.shout = true
	_shouting = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, _intent(yaw))
	await wait_physics_frames(2)
	_shouting = false


## "Running": sprint + move forward (casing blocks the sprint; the walk itself must scare nobody).
func _run(yaw: float, seconds: float) -> void:
	var i: CrewIntent = _intent(yaw)
	i.move = Vector2(0, 1)
	i.sprint = true
	i.crouch = false
	_rt.set_bot_intent(0, i)
	await wait_physics_seconds(seconds)
	_rt.set_bot_intent(0, _intent(yaw))


func _interact(comp: InteractableComponent, yaw: float) -> void:
	var i: CrewIntent = _intent(yaw)
	i.interact = true
	i.interact_target_net_id = comp.owner_net_id()
	_rt.set_bot_intent(0, i)
	await wait_physics_seconds(comp.duration_for(_crew()) + 0.3)
	_rt.set_bot_intent(0, _intent(yaw))
	await wait_physics_frames(2)


func wait_physics_seconds(s: float) -> void:
	await wait_physics_frames(maxi(1, int(ceil(s * Engine.physics_ticks_per_second))))


func _all_of(cls: Variant) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [_rt]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if is_instance_of(n, cls):
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _calm_report() -> Array[String]:
	var bad: Array[String] = []
	for n: Node in _rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if npc.alive and not CALM_STATES.has(npc.alert_state):
			bad.append("%s %s" % [npc.name, Enums.AlertState.keys()[npc.alert_state]])
	return bad


func _launch(heist: StringName, seed: int) -> bool:
	_rt = await HeistLauncher.launch(heist, seed, Enums.Difficulty.ROUTINE, self, {"crew_ai": true})
	if _rt == null:
		return false
	await wait_physics_frames(5)
	# Guards/cameras catching the casing player in a restricted zone would force-mask him (legit S1.2) and
	# end the casing we test here, so their casing fill is switched off for this crew.
	for s: int in [0, 1, 2, 3]:
		Modifiers.set_source(s, &"po11_test", {&"stealth.casing_detection_rate_mult": 0.0})
	_watch_causes()
	for s: int in [1, 2, 3]:  # D-014 P4: bots ordered out of the van follow the (unmasked) player
		var bot: CrewController = _rt.crew_controller(s) as CrewController
		var brain: CrewAiBrain = CrewAiBrain.of(bot)
		if brain != null:
			brain.receive_order(&"follow", 0, Vector3.ZERO, 0)
	await wait_physics_frames(3)
	return true


## Stand 1.6 m in front of `civ` (along its facing), looking at it. Returns the look yaw.
func _approach(civ: NpcBase) -> float:
	var p: Vector3 = civ.global_position
	var fwd: Vector3 = -civ.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(1, 0, 0)
	return await _go(p + fwd.normalized() * 1.6, p + Vector3(0, 1.0, 0))


## The casing tour; returns the number of civilians visited.
func _casing_tour() -> int:
	var c: CrewController = _crew()
	var civs: Array[NpcBase] = []
	for n: Node in _rt.npcs(&"civilian"):
		civs.append(n as NpcBase)
	for civ: NpcBase in civs:
		if not is_instance_valid(civ):
			continue
		var yaw: float = await _approach(civ)
		await _shout(yaw)  # aimed at the civilian, inside the all-round 6 m
		await wait_physics_seconds(0.3)
		var f: CrewIntent = _intent(yaw)  # F with nothing aimed (the PO-11 windowed report)
		f.interact = true
		_rt.set_bot_intent(0, f)
		await wait_physics_frames(2)
		_rt.set_bot_intent(0, _intent(yaw))
		await _run(yaw + PI, 0.4)
		await wait_physics_seconds(0.3)
	for d: Node in _all_of(Door):
		var door: Door = d as Door
		if door.interactable == null or door.locked or door.is_open:
			continue
		var side: Vector3 = door.global_transform.basis.z.normalized() * 1.2
		var yaw: float = await _go(door.global_position + side, door.global_position + Vector3(0, 1.0, 0))
		if door.interactable.availability(c) == InteractableComponent.BLOCK_NONE:
			await _interact(door.interactable, yaw)
			if door.is_open:
				_doors_opened += 1
	for k: Node in _all_of(KeycardPickup):
		var card: KeycardPickup = k as KeycardPickup
		if card.interactable == null or not card.interactable.enabled:
			continue
		var at: Vector3 = card.global_position
		var yaw: float = await _go(at + Vector3(0.8, 0.0, 0.0), at)
		await wait_physics_seconds(0.6)  # settle on the floor (the card lies on a desk) before the hold
		_rt.set_bot_intent(0, _intent(_yaw_to(_crew().eye_position(), at)))
		await wait_physics_frames(2)
		yaw = _yaw_to(_crew().global_position, at)
		await _interact(card.interactable, yaw)
		if not is_instance_valid(card) or card.taken:
			_cards_taken += 1
	await wait_physics_seconds(1.5)
	return civs.size()


func _assert_casing_clean(heist: String, visited: int) -> void:
	assert_true(visited > 0, "%s has civilians to visit" % heist)
	assert_false(_crew().masked, "%s: the player is still casing" % heist)
	for s: int in [1, 2, 3]:
		var bot: CrewController = _rt.crew_controller(s) as CrewController
		if bot != null:
			assert_false(bot.masked, "%s: bot %d stays unmasked while the player cases" % [heist, s])
			var brain: CrewAiBrain = CrewAiBrain.of(bot)
			assert_true(brain == null or brain.target_enemy == null, "%s: bot %d aims at nobody" % [heist, s])
	assert_eq(_calm_report(), [] as Array[String], "%s: every civilian stays calm" % heist)
	assert_eq(_log, [] as Array[String], "%s: no civilian state change" % heist)
	assert_eq(_intimidated + _fled + _tied, 0, "%s: no intimidate / flee / tie" % heist)
	assert_eq(_alarms, [] as Array[StringName], "%s: no civilian report / alarm" % heist)
	assert_false(_rt.went_loud, "%s: still stealth" % heist)


func _assert_masked_shout_works(heist: String) -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var target: NpcBase = null
	for n: Node in _rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if npc.alive and npc.alert_state == Enums.AlertState.CALM:
			target = npc
			break
	assert_true(target != null, "%s: a calm civilian to shout at" % heist)
	if target == null:
		return
	var yaw: float = await _approach(target)
	await _shout(yaw)
	assert_eq(target.alert_state, Enums.AlertState.INTIMIDATED, "%s: a masked shout intimidates" % heist)
	assert_true(_intimidated >= 1, "%s: civilian_intimidated emitted" % heist)


func test_po11_glasshouse_casing_never_scares_civilians() -> void:
	assert_true(await _launch(&"glasshouse", 1101), "launched glasshouse")
	if _rt == null:
		return
	var visited: int = await _casing_tour()
	assert_true(_doors_opened > 0, "glasshouse: the casing player opened doors (%d)" % _doors_opened)
	assert_true(_cards_taken > 0, "glasshouse: the casing keycard was lifted")
	_assert_casing_clean("glasshouse", visited)
	await _assert_masked_shout_works("glasshouse")


func test_po11_night_deposit_casing_never_scares_civilians() -> void:
	assert_true(await _launch(&"night_deposit", 1102), "launched night_deposit")
	if _rt == null:
		return
	if _rt.npcs(&"civilian").is_empty():
		return
	var visited: int = await _casing_tour()
	_assert_casing_clean("night_deposit", visited)
	await _assert_masked_shout_works("night_deposit")
