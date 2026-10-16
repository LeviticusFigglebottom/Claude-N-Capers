## SL-6 shared test body (not a test file itself: no test_ prefix): launch Shadow Ledger with pinned variants
## (PreplanResult force_variants) or a duplicated variant table (rare events at chance 1), record Mercer's lines
## and heist_ended. Used by test_sl6_loud.gd and test_sl6_paths.gd. Owner: ENV A.
extends TestCase

const HEIST: StringName = &"shadow_ledger"
const SEED: int = 777
const VARIANTS_PATH: String = "res://world/heists/shadow_ledger/shadow_ledger_variants.tres"
const DONE: Enums.ObjectiveState = Enums.ObjectiveState.COMPLETED
const ACTIVE: Enums.ObjectiveState = Enums.ObjectiveState.ACTIVE
const ABORT_SL: StringName = &"vo.mercer.shadow_ledger_abort"
const ABORT_GENERIC: StringName = &"vo.mercer.abort"

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
	await _teardown()


func _teardown() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## `force`: group -> [slot ids] pinned (PreplanResult force_variants); `table`: a variant table override.
func _launch(force: Dictionary = {}, table: HeistVariantTable = null,
		difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE, run_seed: int = SEED) -> HeistMission:
	var opts: Dictionary = {"crew_ai": false, "ai_teammates": 0}
	if not force.is_empty():
		opts["preplan"] = {"force_variants": force}
	if table != null:
		opts["variant_table"] = table
	_rt = await HeistLauncher.launch(HEIST, run_seed, difficulty, self, opts)
	await wait_physics_frames(3)
	assert_true(_rt != null and _rt.mission != null, "SL launched")
	return _rt.mission if _rt != null else null


## The SL variant table with `rare_id` always firing (chance 1).
static func _table_with_rare(rare_ids: Array[StringName]) -> HeistVariantTable:
	var t: HeistVariantTable = (load(VARIANTS_PATH) as HeistVariantTable).duplicate(true) as HeistVariantTable
	var rare: Array[Dictionary] = []
	for ev: Dictionary in t.rare_events:
		var e: Dictionary = ev.duplicate(true)
		e["chance"] = 1.0 if rare_ids.has(StringName(e.get("id", &""))) else 0.0
		rare.append(e)
	t.rare_events = rare
	return t


func _count(line_id: StringName) -> int:
	return _lines.filter(func(l: Array) -> bool: return l[1] == line_id).size()


func _line_ctx(line_id: StringName) -> Dictionary:
	for l: Array in _lines:
		if l[1] == line_id:
			return l[2]
	return {}


func _data(oid: StringName) -> Dictionary:
	for o: Dictionary in _rt.mission.objectives():
		if StringName(o["id"]) == oid:
			return o.get("data", {}) as Dictionary
	return {}


func _one(tag: StringName) -> Node:
	var all: Array[Node] = _rt.find_by_tag(tag)
	return all[0] if all.size() == 1 else null


func _nid(n: Node) -> int:
	return int(n.get(&"net_id"))


func _enabled(prefab: Node) -> bool:
	var it: Node = prefab.get_node_or_null(^"Interactable")
	return it != null and bool(it.get(&"enabled"))


func _rare_on(id: StringName) -> bool:
	return (_rt.variants.get(VariantResolver.RARE_KEY, []) as Array).has(id)


func _slot(group: StringName) -> Array:
	return _rt.variants.get(group, []) as Array
