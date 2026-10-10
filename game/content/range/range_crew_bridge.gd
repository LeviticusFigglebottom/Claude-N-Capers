## Spawns ENV A's crew controller into the firing range when it exists (B1-05). Owner: ENV B.
## Resolved dynamically (like the P1 gate test) so content parses before ENV A delivers.
##
## PROPOSED HOOK (needs a contract from the lead, see the B1-05 report): the global class
## `CrewController` exposes
##     static func spawn_for_range(parent: Node, xform: Transform3D, loadout: Loadout) -> Node
## (a local, human-driven crew member outside a heist, slot 0, no HeistRuntime) and the returned
## node accepts `set_loadout(loadout: Loadout)` for instant loadout swaps. Until that exists, this
## returns null and FiringRange falls back to the temporary RangeSpectator.
class_name RangeCrewBridge
extends RefCounted

const CONTROLLER_CLASS: StringName = &"CrewController"
const SPAWN_METHOD: StringName = &"spawn_for_range"
const SET_LOADOUT_METHOD: StringName = &"set_loadout"


## The crew node, or null when ENV A's controller (or the hook) is not there yet.
static func try_spawn(parent: Node, xform: Transform3D, loadout: Loadout) -> Node:
	var s: Script = UiNav.global_class(CONTROLLER_CLASS)
	if s == null:
		return null
	for m: Dictionary in s.get_script_method_list():
		if StringName(m["name"]) == SPAWN_METHOD:
			return s.call(SPAWN_METHOD, parent, xform, loadout) as Node
	Log.info(&"range", "CrewController has no %s(); using the range camera" % SPAWN_METHOD)
	return null


static func push_loadout(crew: Node, loadout: Loadout) -> void:
	if crew != null and crew.has_method(SET_LOADOUT_METHOD):
		crew.call(SET_LOADOUT_METHOD, loadout)
