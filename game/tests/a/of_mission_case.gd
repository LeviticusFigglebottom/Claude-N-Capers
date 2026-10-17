## OF-A6 shared test body (not a test file itself: no test_ prefix): launch Ostrander Federal with pinned variant slots
## and rare events (a duplicated variant table, the GN / SL-6 pattern), record Mercer's lines and heist_ended. Used by
## test_of_mission_*.gd. The tests run on ENV C's G1 map; without it (trunk before OF-C1 lands) every test SKIPs with
## "pending C G1". Owner: ENV A.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const VARIANTS_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal_variants.tres"
const SEED: int = 3136
const PENDING: String = "pending C G1: no ostrander_federal map on this branch (OF-C1)"
const DONE: Enums.ObjectiveState = Enums.ObjectiveState.COMPLETED
const ACTIVE: Enums.ObjectiveState = Enums.ObjectiveState.ACTIVE
const HIDDEN: Enums.ObjectiveState = Enums.ObjectiveState.HIDDEN
## Slot ids of the groups the tests pin (unlisted slots keep their VariantSlot weight, so every slot is listed).
const GROUP_SLOTS: Dictionary = {
	&"escape": [&"esc_van_dock", &"esc_van_tannery", &"esc_heli_terrace"],
	&"drill_delivery": [&"drop_terrace", &"drop_dock"],
	&"security_room_staffed": [&"sec_staffed", &"sec_empty"],
	&"code_pc": [&"pc_ao1", &"pc_ao2", &"pc_ao3", &"pc_ops", &"pc_vault_ops", &"pc_exec"],
}

var _rt: HeistRuntime = null
var _lines: Array[Array] = []
var _ended: Array[Dictionary] = []
var _line_cb: Callable
var _end_cb: Callable


func before_each() -> void:
	_lines.clear()
	_ended.clear()
	_line_cb = func(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
		_lines.append([speaker, line_id, ctx])
	_end_cb = func(result: Dictionary) -> void:
		_ended.append(result)
	EventBus.voice_line_requested.connect(_line_cb)
	EventBus.heist_ended.connect(_end_cb)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_line_cb):
		EventBus.voice_line_requested.disconnect(_line_cb)
	if EventBus.heist_ended.is_connected(_end_cb):
		EventBus.heist_ended.disconnect(_end_cb)
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## True (after skip()) when ENV C's map is not on this branch.
func _pending() -> bool:
	if ResourceLoader.exists(MAP_PATH) and ResourceLoader.exists(VARIANTS_PATH):
		return false
	skip(PENDING)
	return true


## Launch with `pins` {group: slot_id} pinned and exactly the `rares` rare events rolled (every other rare at 0).
func _launch(difficulty: int = Enums.Difficulty.ROUTINE, pins: Dictionary = {}, rares: Array = [],
		opts: Dictionary = {}) -> bool:
	var vt: HeistVariantTable = (load(VARIANTS_PATH) as HeistVariantTable).duplicate(true) as HeistVariantTable
	for i: int in range(vt.rules.size()):
		var group: StringName = StringName(vt.rules[i].get("group", &""))
		if not pins.has(group):
			continue
		var weights: Dictionary = {}
		for s: StringName in GROUP_SLOTS.get(group, [pins[group]]):
			weights[s] = 1.0 if s == pins[group] else 0.0
		var by_diff: Dictionary = {}
		for d: int in Enums.Difficulty.values():
			by_diff[d] = weights
		var r: Dictionary = vt.rules[i].duplicate(true)
		r["weights_by_difficulty"] = by_diff
		vt.rules[i] = r
	var rare_rows: Array[Dictionary] = []
	for ev: Dictionary in vt.rare_events:
		var e: Dictionary = ev.duplicate(true)
		e["chance"] = 1.0 if rares.has(StringName(e.get("id", &""))) else 0.0
		rare_rows.append(e)
	vt.rare_events = rare_rows
	var o: Dictionary = {"crew_ai": false, "ai_teammates": 0, "variant_table": vt}
	o.merge(opts, true)
	_rt = await HeistLauncher.launch(HEIST, SEED, difficulty, self, o)
	await wait_physics_frames(3)
	assert_true(_rt != null and _rt.mission != null, "Ostrander Federal launched with its mission")
	if _rt == null or _rt.mission == null:
		return false
	for g: Variant in pins:
		var v: Variant = _m().variant(StringName(g))
		assert_true(v is Array and (v as Array).has(pins[g]), "%s pinned on %s (%s)" % [g, pins[g], v])
	return true


func _m() -> HeistMission:
	return _rt.mission


func _state(id: StringName) -> int:
	return _m().objective_state(id)


func _data(id: StringName) -> Dictionary:
	for o: Dictionary in _m().objectives():
		if StringName(o["id"]) == id:
			return o.get("data", {}) as Dictionary
	return {}


func _count(line_id: StringName) -> int:
	return _lines.filter(func(l: Array) -> bool: return l[1] == line_id).size()


func _first(tag: StringName, cls: String = "") -> Node:
	for n: Node in _m().find_tagged(tag):
		if cls == "" or n.is_class(cls) or (n.get_script() != null and (n.get_script() as Script).get_global_name() == cls):
			return n
	return null


func _net_id(n: Node) -> int:
	var v: Variant = n.get(&"net_id") if n != null else null
	return int(v) if v != null else 0


## Emit the server fact `sig` with `args` as the prefab would (EventBus only; the mission listens there).
func _fact(sig: StringName, args: Array) -> void:
	EventBus.callv(&"emit_signal", [sig] + args)
	await wait_physics_frames(1)


## Secure `n` bags of `loot_id` (loot_secured facts, as LootManager emits them).
func _secure(loot_id: StringName, n: int) -> void:
	for i: int in range(n):
		EventBus.loot_secured.emit(9000 + i, loot_id, 1000)
	await wait_physics_frames(1)


func _drill_parts() -> Array[LootBag]:
	var out: Array[LootBag] = []
	for n: Node in _rt.find_children("*", "", true, false):
		if n is LootBag and (n as LootBag).loot_id == &"loot.thermal_drill_part" and not n.is_queued_for_deletion():
			out.append(n as LootBag)
	return out
