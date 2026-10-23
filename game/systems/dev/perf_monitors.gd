## A4-02 performance monitors: CAPERWORKS counters in Godot's Performance custom monitors (the editor debugger's
## Monitors tab, Performance.get_custom_monitor in harnesses). Owner: ENV A. HeistRuntime calls `attach(self)`;
## the monitors read the live runtime and cost nothing until something queries them.
##   caperworks/npcs            every NPC under the runtime
##   caperworks/enemies_alive   alive enemy NPCs (G.ENEMY)
##   caperworks/civilians       alive civilians
##   caperworks/crew_standing   crew members NORMAL / SWAN_SONG
##   caperworks/dynamic_nodes   nodes under HeistRuntime.dynamic_root (bags, deployables, corpses, effects)
##   caperworks/frame_prof_ms   FrameProf time this frame (only while FrameProf.enabled)
class_name PerfMonitors
extends RefCounted

const PREFIX: String = "caperworks/"

static var _rt: WeakRef = null


## Point the monitors at `rt` (registered once per process; later runtimes replace the target).
static func attach(rt: HeistRuntime) -> void:
	_rt = weakref(rt)
	_add(&"npcs", _npcs)
	_add(&"enemies_alive", _enemies)
	_add(&"civilians", _civilians)
	_add(&"crew_standing", _standing)
	_add(&"dynamic_nodes", _dynamic)
	_add(&"frame_prof_ms", _frame_prof)


static func _add(n: StringName, f: Callable) -> void:
	var id: StringName = StringName(PREFIX + String(n))
	if not Performance.has_custom_monitor(id):
		Performance.add_custom_monitor(id, f)


static func _runtime() -> HeistRuntime:
	var rt: HeistRuntime = _rt.get_ref() as HeistRuntime if _rt != null else null
	return rt if rt != null and is_instance_valid(rt) and rt.is_inside_tree() else null


static func _npcs() -> int:
	var rt: HeistRuntime = _runtime()
	return rt.npcs().size() if rt != null else 0


static func _enemies() -> int:
	var rt: HeistRuntime = _runtime()
	if rt == null:
		return 0
	var n: int = 0
	for node: Node in rt.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = node as NpcBase
		if npc != null and npc.alive and rt.is_ancestor_of(npc):
			n += 1
	return n


static func _civilians() -> int:
	var rt: HeistRuntime = _runtime()
	if rt == null:
		return 0
	var n: int = 0
	for node: Node in rt.npcs(&"civilian"):
		if (node as NpcBase) != null and (node as NpcBase).alive:
			n += 1
	return n


static func _standing() -> int:
	var rt: HeistRuntime = _runtime()
	if rt == null:
		return 0
	var n: int = 0
	for c: CrewController in rt.crew_members():
		if c.crew_state == Enums.CrewState.NORMAL or c.crew_state == Enums.CrewState.SWAN_SONG:
			n += 1
	return n


static func _dynamic() -> int:
	var rt: HeistRuntime = _runtime()
	return rt.dynamic_root.get_child_count() if rt != null and rt.dynamic_root != null else 0


static func _frame_prof() -> float:
	var us: int = 0
	for k: Variant in FrameProf.frame:
		us += int(FrameProf.frame[k])
	return float(us) / 1000.0
