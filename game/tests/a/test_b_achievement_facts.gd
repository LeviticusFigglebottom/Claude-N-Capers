## ENV B per-heist achievements (env/b-content 56fdc31e `requires_facts`): HeistResult.loot_available (every valued
## bag the run offered, safe contents and variants included; body / tool bags not), objective data
## safe.open_method (GH: keycard / code / lockpick / drill / left_open) and cage.open_method (SL: code / saw /
## left_open), set before the objective completes.
extends TestCase

var _rt: HeistRuntime = null
var _facts: Array[Dictionary] = []


func _on_objective(id: StringName, state: int, data: Dictionary) -> void:
	if state == Enums.ObjectiveState.COMPLETED:
		_facts.append({"id": id, "data": data.duplicate(true)})


func after_each() -> void:
	if EventBus.objective_updated.is_connected(_on_objective):
		EventBus.objective_updated.disconnect(_on_objective)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(heist: StringName, seed_v: int) -> void:
	_facts.clear()
	EventBus.objective_updated.connect(_on_objective)
	_rt = await HeistLauncher.launch(heist, seed_v, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "%s launched" % heist)
	await wait_physics_frames(5)


func _first_tagged(tag: StringName) -> Node:
	var n: Array[Node] = _rt.mission.find_tagged(tag)
	return n[0] if not n.is_empty() else null


func _completed_method(id: StringName) -> StringName:
	for f: Dictionary in _facts:
		if f["id"] == id:
			return StringName((f["data"] as Dictionary).get("open_method", &""))
	return &"-"


func _spawn_offer() -> int:
	var n: int = 0
	var stack: Array[Node] = [_rt]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		stack.append_array(x.get_children())
		var ls: LootSpawn = x as LootSpawn
		if ls != null and int(LootManager.loot_info(ls.loot_id).get("value", 0)) > 0:
			n += ls.remaining
	return n


func test_gh_safe_open_method_keycard_and_drill() -> void:
	await _launch(&"glasshouse", 5)
	var reader: Node = _first_tagged(&"safe_reader")
	assert_true(reader != null, "GH safe reader")
	_rt.mission.call(&"_on_interaction_completed", int(reader.get(&"net_id")), 0, &"swipe_card")
	assert_eq(_completed_method(&"safe"), &"keycard", "reader: open_method keycard (%s)" % [_facts])
	_rt.teardown()
	await wait_frames(2)
	EventBus.objective_updated.disconnect(_on_objective)
	await _launch(&"glasshouse", 6)
	var drill: Node = _first_tagged(&"safe_drill")
	assert_true(drill != null, "GH safe drill point")
	_rt.mission.call(&"_on_device_finished", int(drill.get(&"net_id")))
	assert_eq(_completed_method(&"safe"), &"drill", "drill: open_method drill")


## D-138.4: the SL cage lock of `cls` (the CageGate's Keypad / Padlock); on a pre-D-138 map the CageLock safe.
func _cage_lock(cls: Variant) -> Node:
	for n: Node in _rt.mission.find_tagged(&"cage"):
		if is_instance_of(n, cls):
			return n
	return _first_tagged(&"cage")  # legacy: pre-D-138 maps, remove after C b4ad9153 is on trunk


func test_sl_cage_open_method_code_and_saw() -> void:
	await _launch(&"shadow_ledger", 5)
	var kp: Node = _cage_lock(Keypad)
	assert_true(kp != null, "SL cage lock")
	if _completed_method(&"cage") == &"left_open":
		return  # rare cage_left_open rolled: nothing else to open
	if kp is Keypad:
		kp.call(&"_on_completed", _rt.crew_controller(0))  # the code entered: the keypad opens the gate
	else:
		kp.call(&"_lock_beaten", &"code")  # legacy: pre-D-138 maps (Safe._on_completed), remove after C b4ad9153
	_rt.mission.call(&"_on_interaction_completed", int(kp.get(&"net_id")), 0, &"enter_code")
	assert_eq(_completed_method(&"cage"), &"code", "keypad: open_method code (%s)" % [_facts])
	_rt.teardown()
	await wait_frames(2)
	EventBus.objective_updated.disconnect(_on_objective)
	await _launch(&"shadow_ledger", 6)
	var saw: Node = _cage_lock(Padlock)
	if saw is Padlock:
		(saw as Padlock).open_lock(true, &"saw")  # the placed saw's DeviceRunner beat the padlock
	else:
		saw.call(&"open_by_device")  # legacy: pre-D-138 maps, remove after C b4ad9153 is on trunk
	_rt.mission.call(&"_on_device_finished", int(saw.get(&"net_id")))
	if _completed_method(&"cage") != &"left_open":
		assert_eq(_completed_method(&"cage"), &"saw", "saw device: open_method saw")


func test_loot_available_counts_every_offered_bag() -> void:
	await _launch(&"glasshouse", 5)
	var offer: int = _spawn_offer()
	assert_true(offer > 0, "GH offers bags (%d)" % offer)
	var mgr: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	mgr.spawn_bag(&"loot.body_bag", Transform3D.IDENTITY)  # bodies are not loot
	var res: Dictionary = _rt.end_heist(true)
	assert_eq(int(res.get("loot_available", -1)), offer, "loot_available = every valued bag offered")


func test_loot_available_keeps_taken_bags() -> void:
	await _launch(&"glasshouse", 5)
	var offer: int = _spawn_offer()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	for ls: Node in _rt.mission.find_tagged(&"safe_loot"):
		if ls is LootSpawn and (ls as LootSpawn).remaining > 0:
			c.set_carried_bag(null)
			(ls as LootSpawn).call(&"_on_completed", c)  # take one bag: remaining - 1, a spawned bag + 1
			break
	assert_true(_spawn_offer() < offer or offer == 0, "a bag was taken")
	var res: Dictionary = _rt.end_heist(true)
	assert_eq(int(res.get("loot_available", -1)), offer, "taken bags still count as offered")
