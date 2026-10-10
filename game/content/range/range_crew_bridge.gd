## The firing range's only door into ENV A's crew runtime (B1-05, QB-25 / D-026). Owner: ENV B.
##
## Uses the documented hook `CrewController.spawn_for_range(parent, xform, loadout) -> Node` (a
## standalone, masked, locally controlled crew member with PlayerInput + Weapons + Health, no
## HeistRuntime) and `set_loadout(loadout)` for instant swaps. Everything else is duck-typed so
## content still parses (and the range falls back to RangeSpectator) when the class or the hook is
## missing:
##   * crew `net_id` (attacker id on EventBus.damage_applied), `eye_position()`, `look_yaw/look_pitch`,
##     `apply_intent(CrewIntent)` (crew_intent.md), `weapon_visual` (visual_slots.md WeaponVisual);
##   * crew `weapons` (CrewWeapons HUD duck-typed interface): `equipped_slot`, `reloading`,
##     `mag(slot)`, `reserve(slot)`, `mag_size(slot)`;
##   * the `PlayerInput` child spawn_for_range adds, paused through its public `enabled` flag while the
##     range panels are open (no documented pause API yet: question QB-38 in the B1-05 report);
##   * the first Camera3D under the crew (crew_member.tscn `Head/Camera`), made current by the range
##     (nobody else activates it outside a heist yet: question QB-39).
class_name RangeCrewBridge
extends RefCounted

const CONTROLLER_CLASS: StringName = &"CrewController"
const SPAWN_METHOD: StringName = &"spawn_for_range"
const SET_LOADOUT_METHOD: StringName = &"set_loadout"
## Name of the PlayerInput child added by CrewController.spawn_for_range.
const INPUT_NODE: String = "PlayerInput"
## First-person weapon model under the crew camera (presentation only).
const VIEWMODEL_NAME: String = "RangeViewmodel"


## True when ENV A's controller provides the range hook.
static func available() -> bool:
	var s: Script = UiNav.global_class(CONTROLLER_CLASS)
	if s == null:
		return false
	for m: Dictionary in s.get_script_method_list():
		if StringName(m["name"]) == SPAWN_METHOD:
			return true
	return false


## The crew node, or null when ENV A's controller (or the hook) is not there.
static func try_spawn(parent: Node, xform: Transform3D, loadout: Loadout) -> Node:
	if not available():
		Log.info(&"range", "CrewController.%s() not available; using the fallback range camera" % SPAWN_METHOD)
		return null
	var s: Script = UiNav.global_class(CONTROLLER_CLASS)
	return s.call(SPAWN_METHOD, parent, xform, loadout) as Node


## Instant loadout swap: re-resolve, re-arm (full ammo) and refill health (CrewController.set_loadout).
static func push_loadout(crew: Node, loadout: Loadout) -> void:
	if crew != null and is_instance_valid(crew) and crew.has_method(SET_LOADOUT_METHOD):
		crew.call(SET_LOADOUT_METHOD, loadout)


## The crew's net id (attacker id of its hits), or -1 without a crew.
static func net_id(crew: Node) -> int:
	if crew == null or not is_instance_valid(crew):
		return -1
	var v: Variant = crew.get(&"net_id")
	return int(v) if v != null else -1


## Eye position (hitscan origin) of the crew, else its origin.
static func eye_position(crew: Node) -> Vector3:
	if crew.has_method(&"eye_position"):
		return crew.call(&"eye_position") as Vector3
	return (crew as Node3D).global_position if crew is Node3D else Vector3.ZERO


static func camera(crew: Node) -> Camera3D:
	if crew == null:
		return null
	var found: Array[Node] = crew.find_children("*", "Camera3D", true, false)
	return found[0] as Camera3D if not found.is_empty() else null


## Make the crew's first-person camera the active one. Returns it (null when the crew has none).
static func activate_camera(crew: Node) -> Camera3D:
	var cam: Camera3D = camera(crew)
	if cam != null:
		cam.current = true
	return cam


static func input_node(crew: Node) -> Node:
	return crew.get_node_or_null(INPUT_NODE) if crew != null and is_instance_valid(crew) else null


## Resume (true) or pause (false) the crew's player input. Pausing also hands the crew a neutral
## intent (same look direction, no buttons) so a held trigger or move key does not stay applied.
static func set_input_enabled(crew: Node, on: bool) -> void:
	var pin: Node = input_node(crew)
	if pin != null:
		if &"enabled" in pin:
			pin.set(&"enabled", on)
		else:
			pin.set_physics_process(on)
			pin.set_process_unhandled_input(on)
	if not on and crew != null and is_instance_valid(crew) and crew.has_method(&"apply_intent"):
		var i: CrewIntent = CrewIntent.new()
		i.look_yaw = float(crew.get(&"look_yaw"))
		i.look_pitch = float(crew.get(&"look_pitch"))
		crew.call(&"apply_intent", i)


static func input_enabled(crew: Node) -> bool:
	var pin: Node = input_node(crew)
	if pin == null:
		return false
	return bool(pin.get(&"enabled")) if &"enabled" in pin else pin.is_physics_processing()


## Equipped weapon ammo: {mag, mag_size, reserve, reloading}; {} without crew weapons.
static func ammo(crew: Node) -> Dictionary:
	var w: Object = crew.get(&"weapons") as Object if crew != null and is_instance_valid(crew) else null
	if w == null:
		return {}
	var ws: int = int(w.get(&"equipped_slot"))
	return {
		"mag": int(w.call(&"mag", ws)), "mag_size": int(w.call(&"mag_size", ws)),
		"reserve": int(w.call(&"reserve", ws)), "reloading": bool(w.get(&"reloading")),
	}


## Put a WeaponVisual of `def` + `mods` in front of the crew camera and hand it to the crew as its
## `weapon_visual` (muzzle origin for tracers/noise, visual_slots.md). Replaces the previous one.
static func attach_viewmodel(crew: Node, def: WeaponDef, mod_ids: Array[StringName], offset: Vector3) -> WeaponVisual:
	var cam: Camera3D = camera(crew)
	if cam == null or def == null:
		return null
	var old: Node = cam.get_node_or_null(VIEWMODEL_NAME)
	if old != null:
		cam.remove_child(old)
		old.queue_free()
	var wv: WeaponVisual = WeaponVisual.new()
	wv.name = VIEWMODEL_NAME
	wv.position = offset
	cam.add_child(wv)
	var mods: Array[WeaponModDef] = []
	for m: WeaponModDef in LoadoutResolver.applied_mods(def, mod_ids):
		mods.append(m)
	wv.setup(def, mods)
	if &"weapon_visual" in crew:
		crew.set(&"weapon_visual", wv)
	return wv
