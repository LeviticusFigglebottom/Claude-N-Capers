## Loot service (G.SVC_LOOT, child of HeistRuntime): bags, body bagging, securing. Owner: ENV A.
## Rows: S6.2, S6.3, S10.1, S10.2 (S10.3 small loot lives on the prefabs).
##
## PUBLIC API:
##   spawn_bag(loot_id, xform, moved = true, weight_override = -1) -> LootBag   (loot_spawned [R])
##   carry(bag, crew) -> bool                 -> crew picks the bag up (loot_picked [R])
##   drop_bag(crew, thrown) -> LootBag        -> drop in front / throw (loot_dropped [R])
##   npc_carry(bag, npc) -> bool              -> QC-57: an NPC carries the bag (GN Vaultline courier)
##   npc_drop(npc) -> LootBag                 -> QC-57: the NPC puts it down in front of him
##   bags() -> Array[LootBag]                 -> bags of this heist (carried or not)
##   loot_info(loot_id) -> {weight, value, known}  (static; ContentDB, else LootTweak fallback)
##   bag_body(crew, npc) -> LootBag           -> S6.2 completion logic (body_bagged [R])
##   tool_bag_for(crew, loot_id, origin, radius_m) -> LootBag  -> QC-60: carried, else nearest loose bag (static)
##   consume_bag(bag)                         -> QC-60: a device uses the bag up (META_CONSUMED, freed; static)
## Server only. Drop/throw come from CrewIntent.drop_bag / throw_bag rising edges through a crew
## tick handler. A bag resting inside a SECURE_LOOT MapZone for LootTweak.secure_rest_s is secured
## (loot_secured [R]) and freed. Body bags inside a BODY_HIDE zone (body_container respects its
## `capacity`) are hidden from stealth (S6.3). A carrier who goes down / is cuffed / taken into
## custody drops the bag. QC-57: an NPC carrier drops it when he dies, is intimidated / dominated / tied, or
## fights (NPC_DROP_STATES). Every dead NPC gets a `BagBodyInteractable` (kind &"bag_body").
class_name LootManager
extends Node

const BAG_SCENE_PATH: String = "res://systems/loot/loot_bag.tscn"
const BAG_BODY_NODE: StringName = &"BagBodyInteractable"
## Crew states that make the carrier drop the bag.
## QC-60: meta set on a bag a device used up (burn_point / drill_point), so a respawn watch does not replace it.
const META_CONSUMED: StringName = &"consumed"
const DROP_STATES: Array[int] = [
	Enums.CrewState.DOWNED, Enums.CrewState.CLOAKER_DOWNED, Enums.CrewState.CUFFED, Enums.CrewState.CUSTODY,
]

## QC-57: NPC alert states that make an NPC carrier put the bag down (killed, intimidated / dominated / tied, or
## fighting: a courier who goes to COMBAT needs his hands, and the canvas stays where the crew can take it, B3).
const NPC_DROP_STATES: Array[int] = [
	Enums.AlertState.PANICKED, Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED,
	Enums.AlertState.DOMINATED, Enums.AlertState.CONVERTED, Enums.AlertState.COMBAT, Enums.AlertState.DEAD,
]

static var _loot_cache: Dictionary = {}

var _runtime: HeistRuntime = null
var _tw: LootTweak = null
var _bag_scene: PackedScene = null
var _drop_latch: Dictionary[int, bool] = {}
var _throw_latch: Dictionary[int, bool] = {}


func _ready() -> void:
	_tw = LootTweak.get_default()
	_runtime = HeistRuntime.of(self)
	if _runtime != null:
		_runtime.add_crew_tick_handler(_on_crew_tick)
		_runtime.crew_spawned.connect(_on_crew_spawned)
	EventBus.npc_killed.connect(_on_npc_killed)


func _exit_tree() -> void:
	if EventBus.npc_killed.is_connected(_on_npc_killed):
		EventBus.npc_killed.disconnect(_on_npc_killed)


## Weight/value of a loot id: ContentDB LootDef, else LootTweak.fallback_loot, else unknown_*.
## Body bags always use LootTweak.body_bag_weight (S6.3).
static func loot_info(loot_id: StringName) -> Dictionary:
	var tw: LootTweak = LootTweak.get_default()
	if _loot_cache.is_empty():
		for r: Variant in ContentDB.all_loots():
			var d: LootDef = r as LootDef
			if d != null:
				_loot_cache[d.id] = {"weight": int(d.weight), "value": d.value, "known": true, "def": d}
	var out: Dictionary = {}
	if _loot_cache.has(loot_id):
		out = (_loot_cache[loot_id] as Dictionary).duplicate()
	elif tw.fallback_loot.has(loot_id):
		var f: Dictionary = tw.fallback_loot[loot_id]
		out = {"weight": int(f.get("weight", tw.unknown_weight)), "value": int(f.get("value", tw.unknown_value)), "known": true}
	else:
		out = {"weight": int(tw.unknown_weight), "value": tw.unknown_value, "known": false}
	if loot_id == tw.body_bag_loot_id:
		out["weight"] = int(tw.body_bag_weight)
	return out


## D-068: a tool bag (LootDef.is_tool, e.g. loot.thermite) is never secured: no value, no XP, not [secure].
static func is_tool_loot(loot_id: StringName) -> bool:
	var d: LootDef = loot_info(loot_id).get("def") as LootDef
	return d != null and d.is_tool


## QC-60 / D-068: the `loot_id` bag `crew` would deliver at `origin`: the one it carries, else the nearest loose one
## (not carried, not secured) within `radius_m`. Null when none.
static func tool_bag_for(crew: Node, loot_id: StringName, origin: Vector3, radius_m: float) -> LootBag:
	if loot_id == &"" or crew == null or not crew.is_inside_tree():
		return null
	var carried: LootBag = crew.get(&"carried_bag") as LootBag
	if carried != null and is_instance_valid(carried) and carried.loot_id == loot_id:
		return carried
	var best: LootBag = null
	var best_d: float = radius_m
	for n: Node in crew.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.loot_id != loot_id or b.is_carried() or b.secured or b.is_queued_for_deletion():
			continue
		var d: float = b.global_position.distance_to(origin)
		if d <= best_d:
			best = b
			best_d = d
	return best


## Server (QC-60): a device used `bag` up (thermite, drill parts): off its carrier, marked META_CONSUMED, freed.
static func consume_bag(bag: LootBag) -> void:
	if bag == null or not is_instance_valid(bag):
		return
	var c: CrewController = bag.carrier
	if c != null and is_instance_valid(c) and c.carried_bag == bag:
		c.set_carried_bag(null)
	bag.set_meta(META_CONSUMED, true)
	if bag.get_parent() != null:
		bag.get_parent().remove_child(bag)
	bag.queue_free()


# --- Bags ---------------------------------------------------------------------------------------

## Server: spawn a bag. `moved` false = pre-placed style (ignored by NPCs until picked up).
func spawn_bag(loot_id: StringName, xform: Transform3D, moved: bool = true, weight_override: int = -1) -> LootBag:
	if not Net.is_authority():
		return null
	if _bag_scene == null:
		_bag_scene = load(BAG_SCENE_PATH) as PackedScene
	var info: Dictionary = loot_info(loot_id)
	var bag: LootBag = _bag_scene.instantiate() as LootBag
	bag.loot_id = loot_id
	bag.weight = (weight_override if weight_override >= 0 else int(info["weight"])) as Enums.LootWeight
	bag.value = int(info["value"])
	bag.moved = moved
	var def: LootDef = info.get("def") as LootDef
	if def != null and def.bag_model != null:
		bag.visual_scene = def.bag_model
	var parent: Node = _runtime.dynamic_root if _runtime != null and _runtime.dynamic_root != null else self
	bag.name = "Bag_%s" % String(loot_id).get_slice(".", 1)
	parent.add_child(bag, true)
	bag.global_transform = xform
	_emit(&"loot_spawned", [bag.net_id, loot_id])
	return bag


## Server: `crew` picks up `bag` (one at a time, S10.1). Returns false if not possible.
func carry(bag: LootBag, crew: CrewController) -> bool:
	if not Net.is_authority() or bag == null or crew == null or bag.secured or bag.is_carried():
		return false
	if crew.is_carrying_bag():
		return false
	bag.attach(crew)
	crew.set_carried_bag(bag)
	_emit(&"loot_picked", [bag.net_id, crew.slot])
	_cue(&"cue.bag_pickup", bag.global_position, bag.net_id)
	return true


## Server: drop (in front) or throw (S10.1 distance by weight × loot.throw_distance_mult).
func drop_bag(crew: CrewController, thrown: bool) -> LootBag:
	if not Net.is_authority() or crew == null or not crew.is_carrying_bag():
		return null
	var bag: LootBag = crew.carried_bag as LootBag
	crew.set_carried_bag(null)
	if bag == null:
		return null
	var fwd: Vector3 = crew.aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else -crew.global_transform.basis.z
	var pos: Vector3 = crew.global_position + fwd * _tw.drop_forward_m
	var vel: Vector3 = Vector3.ZERO
	var down_states: bool = DROP_STATES.has(int(crew.crew_state))
	if thrown and not down_states:
		pos.y += _tw.throw_release_height_m
		vel = _throw_velocity(crew, int(bag.weight), fwd)
	else:
		thrown = false
		pos.y += _tw.drop_height_m
	bag.release(pos, vel, thrown)
	bag.thrown_by_slot = crew.slot if thrown else -1
	_emit(&"loot_dropped", [bag.net_id, crew.slot, thrown])
	if thrown:
		_cue(&"cue.bag_throw", pos, bag.net_id)
	return bag


## Server (QC-57): `npc` picks up `bag` (one at a time). He drops it on NPC_DROP_STATES or death (npc_drop).
func npc_carry(bag: LootBag, npc: NpcBase) -> bool:
	if not Net.is_authority() or bag == null or npc == null or not npc.alive or bag.secured or bag.is_carried():
		return false
	if npc_bag(npc) != null or NPC_DROP_STATES.has(int(npc.alert_state)):
		return false
	bag.attach_npc(npc)
	if not npc.alert_state_changed.is_connected(_on_npc_state_changed):
		npc.alert_state_changed.connect(_on_npc_state_changed.bind(npc))
	if not npc.died.is_connected(_on_npc_carrier_died):
		npc.died.connect(_on_npc_carrier_died.bind(npc))
	_cue(&"cue.bag_pickup", bag.global_position, bag.net_id)
	return true


## Server (QC-57): `npc` puts his bag down in front of him (on the floor where he stands). Returns the bag or null.
func npc_drop(npc: NpcBase) -> LootBag:
	var bag: LootBag = npc_bag(npc)
	if not Net.is_authority() or bag == null:
		return null
	var fwd: Vector3 = npc.look_forward()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else -npc.global_transform.basis.z
	bag.release(npc.global_position + fwd * _tw.drop_forward_m + Vector3.UP * _tw.drop_height_m, Vector3.ZERO, false)
	return bag


## QC-57: the bag `npc` carries, or null.
func npc_bag(npc: NpcBase) -> LootBag:
	if npc == null:
		return null
	for b: LootBag in bags():
		if b.npc_carrier == npc:
			return b
	return null


func _on_npc_state_changed(_old_state: int, new_state: int, npc: NpcBase) -> void:
	if NPC_DROP_STATES.has(new_state):
		npc_drop(npc)


func _on_npc_carrier_died(_info: Dictionary, _killer_net_id: int, npc: NpcBase) -> void:
	npc_drop(npc)


## Bags in this heist.
func bags() -> Array[LootBag]:
	var out: Array[LootBag] = []
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b != null and not b.is_queued_for_deletion() and (_runtime == null or _runtime.is_ancestor_of(b)):
			out.append(b)
	return out


## Launch velocity that lands `weight`'s throw distance away from the release height.
func _throw_velocity(crew: CrewController, w: int, fwd: Vector3) -> Vector3:
	var dists: PackedFloat32Array = Tweak.crew().bag_throw_distance_m
	var dist: float = dists[clampi(w, 0, dists.size() - 1)] * Modifiers.mult(crew.slot, &"loot.throw_distance_mult")
	var theta: float = deg_to_rad(_tw.throw_elevation_deg)
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var h: float = _tw.throw_release_height_m
	var t: float = sqrt(maxf(2.0 * (h + dist * tan(theta)) / g, 0.0001))
	var v: float = dist / (cos(theta) * t)
	# PO-5 (PD2): aim the throw with the camera; the flat-ground speed above keeps the distance tuning.
	var elev: float = clampf(crew.look_pitch + deg_to_rad(_tw.throw_pitch_bias_deg),
		deg_to_rad(_tw.throw_min_elev_deg), deg_to_rad(_tw.throw_max_elev_deg))
	return fwd * v * cos(elev) + Vector3.UP * v * sin(elev)


func _on_crew_tick(crew: CrewController, intent: CrewIntent, _delta: float) -> void:
	if intent == null:
		return
	var slot: int = crew.slot
	if intent.throw_bag and not _throw_latch.get(slot, false):
		drop_bag(crew, true)
	elif intent.drop_bag and not _drop_latch.get(slot, false):
		drop_bag(crew, false)
	_throw_latch[slot] = intent.throw_bag
	_drop_latch[slot] = intent.drop_bag


func _on_crew_spawned(_slot: int, crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if c != null:
		c.crew_state_changed.connect(_on_crew_state_changed.bind(c))


func _on_crew_state_changed(_old_state: int, new_state: int, crew: CrewController) -> void:
	if DROP_STATES.has(new_state) and crew.is_carrying_bag():
		drop_bag(crew, false)


# --- Securing / hiding (S10.2, S6.3) ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	for bag: LootBag in bags():
		if bag.secured or bag.is_carried() or not bag.is_inside_tree():
			continue
		var probe: Vector3 = bag.global_position + Vector3.UP * _tw.zone_probe_up_m
		if bag.is_body_bag():
			_update_hidden(bag, probe)
		var resting: bool = bag.linear_velocity.length() <= _tw.rest_speed_mps
		if resting and not is_tool_loot(bag.loot_id) and _zone_at(probe, G.LOOT_SECURE_ZONE) != null:
			bag.rest_time += delta
			if bag.rest_time >= _tw.secure_rest_s:
				_secure(bag)
		else:
			bag.rest_time = 0.0


func _update_hidden(bag: LootBag, probe: Vector3) -> void:
	var zone: Area3D = _zone_at(probe, G.BODY_HIDE_ZONE)
	if zone == null:
		if bag.hidden_from_stealth:
			bag.set_hidden(false, null)
		return
	var holder: Node = zone.get_parent()
	if holder == null or not holder.has_method(&"store_bag"):
		if not bag.hidden_from_stealth:
			bag.set_hidden(true, null)
		return
	if bag.container == holder:
		return
	if bool(holder.call(&"store_bag", bag)):
		bag.set_hidden(true, holder)
	elif bag.hidden_from_stealth:
		bag.set_hidden(false, null)


func _secure(bag: LootBag) -> void:
	var id: int = bag.net_id
	var pos: Vector3 = bag.global_position
	bag.mark_secured()
	_emit(&"loot_secured", [id, bag.loot_id, bag.value])
	_cue(&"cue.bag_secure", pos, id)
	bag.queue_free()


## First MapZone of `group` (inside this heist) containing `pos`, or null.
func _zone_at(pos: Vector3, group: StringName) -> Area3D:
	for n: Node in get_tree().get_nodes_in_group(group):
		var a: Area3D = n as Area3D
		if a == null or not a.is_inside_tree() or (_runtime != null and not _runtime.is_ancestor_of(a)):
			continue
		if ZoneUtil.contains(a, pos):
			return a
	return null


# --- Body bagging (S6.2, S6.3) ------------------------------------------------------------------

func _on_npc_killed(npc_id: int, _killer_id: int, _info: Dictionary) -> void:
	if not Net.is_authority():
		return
	var npc: NpcBase = Ids.lookup(npc_id) as NpcBase
	if npc == null or (_runtime != null and not _runtime.is_ancestor_of(npc)):
		return
	add_body_interactable(npc)


## Server: give a corpse its "bag body" interaction (idempotent).
func add_body_interactable(npc: NpcBase) -> InteractableComponent:
	var existing: InteractableComponent = npc.get_node_or_null(NodePath(String(BAG_BODY_NODE))) as InteractableComponent
	if existing != null:
		return existing
	var tw: InteractionTweak = Tweak.interaction()
	var comp: InteractableComponent = InteractableComponent.new()
	comp.name = String(BAG_BODY_NODE)
	comp.kind = &"bag_body"
	comp.interaction_time_s = tw.body_bag_s
	comp.speed_modifier_key = &"stealth.body_bag_speed_mult"
	comp.casing_allowed = false
	comp.prompt_key = &"ui.prompt.bag_body"
	comp.priority = 5
	comp.extra_check = _bag_body_check.bind(npc)
	comp.position = Vector3(0.0, 0.4, 0.0)
	npc.add_child(comp)
	comp.completed.connect(_on_bag_body_completed.bind(npc))
	return comp


func _bag_body_check(crew: Node, npc: NpcBase) -> StringName:
	if not is_instance_valid(npc) or npc.alive or npc.has_meta(&"bagged"):
		return InteractableComponent.BLOCK_DISABLED
	var pagers: PagerSystem = HeistRuntime.get_service(G.SVC_PAGERS) as PagerSystem
	if pagers != null and pagers.blocks_body(npc):
		return InteractableComponent.BLOCK_STATE
	var c: CrewController = crew as CrewController
	if c != null and c.body_bags <= 0:
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _on_bag_body_completed(crew: Node, npc: NpcBase) -> void:
	var c: CrewController = crew as CrewController
	if c != null:
		bag_body(c, npc)


## Server: consume a body bag, turn the corpse into a HEAVY `loot.body_bag` bag at the body.
func bag_body(crew: CrewController, npc: NpcBase) -> LootBag:
	if not Net.is_authority() or crew == null or not is_instance_valid(npc) or npc.has_meta(&"bagged"):
		return null
	if not crew.use_body_bag():
		return null
	var pos: Vector3 = npc.global_position + Vector3.UP * 0.05
	var yaw: float = npc.global_rotation.y
	npc.set_meta(&"bagged", true)
	BloodFx.bleed(npc.net_id, false, pos, 0.0)  # D-113: bagged, the pool stops growing
	npc.clear_corpse()
	var comp: Node = npc.get_node_or_null(NodePath(String(BAG_BODY_NODE)))
	if comp != null:
		comp.queue_free()
	# Keep the node (and its net_id) alive for lookups; it just stops existing in the world.
	npc.visible = false
	npc.collision_layer = 0
	npc.collision_mask = 0
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	var bag: LootBag = spawn_bag(_tw.body_bag_loot_id, Transform3D(Basis(Vector3.UP, yaw), pos), true)
	_emit(&"body_bagged", [npc.net_id, bag.net_id if bag != null else 0, crew.slot])
	return bag


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)


func _cue(cue_id: StringName, pos: Vector3, source_net_id: int) -> void:
	_emit(&"audio_cue_requested", [cue_id, pos, source_net_id])
