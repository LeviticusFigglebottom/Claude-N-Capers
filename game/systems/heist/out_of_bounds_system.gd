## OUT_OF_BOUNDS zones (QC-14, D-040; MapZone.Kind.OUT_OF_BOUNDS, group `out_of_bounds_zone`).
## Owner: ENV A. Child service of HeistRuntime (SERVICE). Server only. Never an alarm, never noise.
## * Crew: a crew member (not in custody) whose body centre (origin + 0.5 m) is inside an OOB zone is
##   teleported to the nearest PLAYER SpawnPoint tagged RESPAWN_TAG (`oob_respawn`); with none, to
##   the nearest PLAYER SpawnPoint. A carried bag is dropped first and returns like any loose bag
##   (below), so jumping into the water never moves loot. A running interaction ends
##   (CrewController.teleport cancels it).
## * Bags: every loose bag (not carried, not secured, not frozen on a zipline / lift) remembers its
##   last valid position: in bounds and at rest (LootTweak.rest_speed_mps); while carried, the
##   carrier's last in-bounds standing position (on the floor / ground probe). A loose bag whose probe point (origin +
##   LootTweak.zone_probe_up_m) is inside an OOB zone is put back there at rest. A bag that never had
##   a valid position stays where it is (warning, once).
## Signals: `crew_respawned(slot, spawn)` and `bag_returned(bag)` (local; tests / HUD).
class_name OutOfBoundsSystem
extends Node

signal crew_respawned(slot: int, spawn: Node3D)
signal bag_returned(bag: LootBag)

const SERVICE: StringName = &"out_of_bounds"
const ZONE_GROUP: StringName = &"out_of_bounds_zone"
## PLAYER SpawnPoint tag for OOB respawns (D-040). These points are not used as start spawns.
const RESPAWN_TAG: StringName = &"oob_respawn"
## Crew probe height above the origin (m), as for escape zones.
const CREW_PROBE_UP_M: float = 0.5
## Height above the carrier's feet a carried bag returns to (m).
const CARRIER_RETURN_UP_M: float = 0.3
## A carrier counts as standing when world geometry is within this distance below the feet (m).
const GROUND_PROBE_M: float = 0.25

var _runtime: HeistRuntime = null
## Bag instance id -> last valid position.
var _last_valid: Dictionary[int, Vector3] = {}
var _warned: Dictionary[int, bool] = {}


func _ready() -> void:
	_runtime = HeistRuntime.of(self)


## OUT_OF_BOUNDS zones of this heist.
func zones() -> Array[Area3D]:
	var out: Array[Area3D] = []
	for n: Node in get_tree().get_nodes_in_group(ZONE_GROUP):
		var a: Area3D = n as Area3D
		if a != null and a.is_inside_tree() and (_runtime == null or _runtime.is_ancestor_of(a)):
			out.append(a)
	return out


## True when `pos` is inside any OUT_OF_BOUNDS zone of this heist.
func is_out_of_bounds(pos: Vector3, zone_list: Array[Area3D] = []) -> bool:
	var list: Array[Area3D] = zone_list if not zone_list.is_empty() else zones()
	for a: Area3D in list:
		if ZoneUtil.contains(a, pos):
			return true
	return false


## Last valid (in bounds, at rest) position remembered for `bag` (Vector3.INF = none).
func last_valid_position(bag: LootBag) -> Vector3:
	return _last_valid.get(bag.get_instance_id(), Vector3.INF) if bag != null else Vector3.INF


## Respawn point for a crew member at `from`: nearest `oob_respawn` PLAYER spawn, else nearest PLAYER spawn.
func respawn_point(from: Vector3) -> Node3D:
	if _runtime == null or _runtime.map == null:
		return null
	var tagged: Array[Node3D] = []
	var any: Array[Node3D] = []
	for n: Node in _runtime.map.get_slots(G.PLAYER_SPAWN):
		var sp: SpawnPoint = n as SpawnPoint
		if sp == null:
			continue
		any.append(sp)
		if sp.tags.has(RESPAWN_TAG):
			tagged.append(sp)
	return _nearest(tagged if not tagged.is_empty() else any, from)


func _physics_process(_delta: float) -> void:
	if not Net.is_authority() or _runtime == null or _runtime.phase == Enums.HeistPhase.ENDED:
		return
	var list: Array[Area3D] = zones()
	if list.is_empty():
		return
	var loot: LootManager = _runtime.service(G.SVC_LOOT) as LootManager
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY or not c.is_inside_tree():
			continue
		var oob: bool = is_out_of_bounds(c.global_position + Vector3.UP * CREW_PROBE_UP_M, list)
		if oob:
			_respawn(c, loot)
		elif c.is_carrying_bag() and _grounded(c):
			var cb: LootBag = c.carried_bag as LootBag
			if cb != null:
				_last_valid[cb.get_instance_id()] = c.global_position + Vector3.UP * CARRIER_RETURN_UP_M
	if loot == null:
		return
	var probe_up: float = LootTweak.get_default().zone_probe_up_m
	var rest: float = LootTweak.get_default().rest_speed_mps
	for bag: LootBag in loot.bags():
		if bag.secured or bag.is_carried() or bag.freeze or not bag.is_inside_tree():
			continue
		var id: int = bag.get_instance_id()
		if is_out_of_bounds(bag.global_position + Vector3.UP * probe_up, list):
			_return_bag(bag, id)
		elif bag.linear_velocity.length() <= rest and not bag.in_flight:
			_last_valid[id] = bag.global_position


func _respawn(c: CrewController, loot: LootManager) -> void:
	if c.is_carrying_bag() and loot != null:
		var bag: LootBag = loot.drop_bag(c, false)
		if bag != null:
			_return_bag(bag, bag.get_instance_id())
	var sp: Node3D = respawn_point(c.global_position)
	if sp == null:
		Log.error(&"heist", "OUT_OF_BOUNDS: no PLAYER SpawnPoint to respawn slot %d" % c.slot)
		return
	c.teleport(sp.global_transform)
	Log.info(&"heist", "OUT_OF_BOUNDS: slot %d respawned at %s" % [c.slot, sp.name])
	crew_respawned.emit(c.slot, sp)


func _return_bag(bag: LootBag, id: int) -> void:
	var pos: Vector3 = _last_valid.get(id, Vector3.INF)
	if pos == Vector3.INF:
		if not _warned.get(id, false):
			_warned[id] = true
			Log.warn(&"loot", "OUT_OF_BOUNDS: bag %s has no valid position to return to" % bag.name)
		return
	bag.release(pos, Vector3.ZERO, false)
	bag_returned.emit(bag)


## On the floor (CharacterBody3D) or world_static / world_dynamic just below the feet.
func _grounded(c: CrewController) -> bool:
	if c.is_on_floor():
		return true
	var from: Vector3 = c.global_position + Vector3.UP * 0.1
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (GROUND_PROBE_M + 0.1),
		GameplayPrefab.LAYER_WORLD_STATIC | GameplayPrefab.LAYER_WORLD_DYNAMIC, [c.get_rid()])
	return not c.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


static func _nearest(points: Array[Node3D], from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for p: Node3D in points:
		var d: float = p.global_position.distance_squared_to(from)
		if d < best_d:
			best = p
			best_d = d
	return best
