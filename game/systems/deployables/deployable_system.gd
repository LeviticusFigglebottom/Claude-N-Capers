## Deployables runtime (A2-06): per-crew inventory, the `deploy` hold and placement. Owner: ENV A.
## Service SERVICE (&"deployables"), child of HeistRuntime, server only; also a crew tick handler.
## Rows: L2.11 (doctor bag 2 uses, FAK 4 per player / 1 s deploy, ammo bag 400 %), S6.2 (body bag
## case holds 3), S8.4 (ECM: 2 s deploy), S1.1 (no deploying while casing).
##
## Inventory: Loadout.deployable (+ deployable_secondary with deploy.second_deployable), count =
## DeployableDef.count + deploy.extra (qualifier = kind) (+ stealth.ecm_extra for an ECM); uses =
## DeployableDef.uses x deploy.capacity_mult (kind). Ids without a ContentDB def use
## DeployableTweak.fallback_defs. The HUD reads crew.weapons.deployable_id / deployable_count
## (CrewWeapons.set_deployable keeps the owning peer in sync).
## Deploy (crew_intent `deploy`): the rising edge starts a hold of DeployableDef.deploy_time_s x
## deploy.deploy_speed_mult; releasing, leaving NORMAL or unmasking cancels it. At the end the
## deployable lands on the floor `place_forward_m` in front (ray down) and is spawned as a
## DeployablePrefab (systems/prefabs/deployable). An ECM aimed at a keycard reader with
## stealth.ecm_opens_doors attaches to it instead (S8.5, EcmSystem.attach_to_reader).
##
## Armor bag (QB-58, Walk-in Closet): only with `deploy.armor_bag`; the crew member starts in
## DeployableTweak.armor_bag_start_armor and the placed bag holds the loadout's armor (wear_armor on use).
##
## PUBLIC API: deployable_id(slot) / deployable_count(slot) / deploy_progress(slot) (0..1, -1 idle)
##   give(slot, id, count = -1)       -> server/test hook: set the slot's deployable (count -1 = loadout rule)
##   place(crew, id = &"") -> Node    -> server: place one now (no hold), returns the prefab or null
##   placed(kind = &"") -> Array[Node] -> placed deployables in this heist
##   static def_for(id) -> DeployableDef
##   static wear_armor(crew, armor_id)  -> server: change armor now (full armor, health kept)
class_name DeployableSystem
extends Node

signal deployed(slot: int, prefab: Node)

const SERVICE: StringName = &"deployables"
const SCENE: String = "res://systems/prefabs/deployable/deployable.tscn"
const FLOOR_MASK: int = (1 << 0) | (1 << 1)
const BLOCK_NONE: StringName = &""
const BLOCK_CASING: StringName = &"ui.blocked.casing"
const BLOCK_EMPTY: StringName = &"ui.blocked.no_deployable"
const BLOCK_PLACE: StringName = &"ui.blocked.no_space"
const BLOCK_STATE: StringName = &"ui.blocked.state"

## Fallback defs built from DeployableTweak (ids ENV B has not shipped yet).
static var _fallback_cache: Dictionary[StringName, DeployableDef] = {}

## Last refusal reason per slot (HUD).
var blocked: Dictionary[int, StringName] = {}

var _runtime: HeistRuntime = null
## slot -> [{"id": StringName, "count": int}] (primary first).
var _inv: Dictionary[int, Array] = {}
## slot -> seconds held.
var _hold: Dictionary[int, float] = {}
var _needs_release: Dictionary[int, bool] = {}
## QB-58: slot -> ArmorDef id stored in that slot's armor bag.
var _bag_armor: Dictionary[int, StringName] = {}


func _ready() -> void:
	if _runtime == null:
		_runtime = HeistRuntime.of(self)
	if _runtime != null:
		_runtime.add_crew_tick_handler(tick)
		_runtime.crew_spawned.connect(_on_crew_spawned)


func bind(rt: HeistRuntime) -> void:
	_runtime = rt


# --- Defs ----------------------------------------------------------------------------------------

## ContentDB def, else DeployableTweak.fallback_defs, else null.
static func def_for(id: StringName) -> DeployableDef:
	if id == &"":
		return null
	if _fallback_cache.has(id):
		return _fallback_cache[id]
	var d: DeployableDef = null
	for r: Variant in ContentDB.all_deployables():  # quiet lookup (ContentDB.deployable logs misses)
		var def: DeployableDef = r as DeployableDef
		if def != null and def.id == id:
			d = def
	if d != null:
		return d
	var row: Variant = DeployableTweak.data().fallback_defs.get(id)
	if not (row is Dictionary):
		return null
	var r: Dictionary = row
	d = DeployableDef.new()
	d.id = id
	d.kind = StringName(r.get("kind", &""))
	d.count = int(r.get("count", 1))
	d.uses = int(r.get("uses", 1))
	d.deploy_time_s = float(r.get("deploy_time_s", DeployableTweak.data().default_deploy_time_s))
	d.params = (r.get("params", {}) as Dictionary).duplicate()
	_fallback_cache[id] = d
	return d


static func count_for(slot: int, def: DeployableDef) -> int:
	var n: int = def.count + int(Modifiers.add(slot, &"deploy.extra", def.kind))
	if def.kind == &"ecm":
		n += int(Modifiers.add(slot, &"stealth.ecm_extra"))  # S8.4 / Jammer Jockey
	return maxi(n, 0)


static func uses_for(slot: int, def: DeployableDef) -> int:
	return maxi(int(round(float(def.uses) * Modifiers.mult(slot, &"deploy.capacity_mult", def.kind))), 1)


static func deploy_time_for(slot: int, def: DeployableDef) -> float:
	var t: float = def.deploy_time_s if def.deploy_time_s > 0.0 else DeployableTweak.data().default_deploy_time_s
	return t * Modifiers.mult(slot, &"deploy.deploy_speed_mult")


# --- Inventory -------------------------------------------------------------------------------------

func _on_crew_spawned(slot: int, crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if c == null:
		return
	var rows: Array = []
	var l: Loadout = c.loadout
	if l != null:
		for id: StringName in [l.deployable, l.deployable_secondary]:
			if id == &"" or (id == l.deployable_secondary and not rows.is_empty()
					and not Modifiers.flag(slot, &"deploy.second_deployable")):
				continue
			var def: DeployableDef = def_for(id)
			if def == null:
				Log.warn(&"deployables", "slot %d: unknown deployable %s" % [slot, id])
				continue
			if not _gate_ok(slot, id):
				continue
			if def.kind == &"armor_bag" and not _setup_armor_bag(c):
				continue
			rows.append({"id": id, "count": count_for(slot, def)})
	_inv[slot] = rows
	_sync(slot)


## A gated deployable (DeployableGate) without its FLAG gives no unit, so a stale save cannot carry one.
static func _gate_ok(slot: int, id: StringName) -> bool:
	var flag: StringName = DeployableGate.required_flag(id)
	if flag == &"" or Modifiers.flag(slot, flag):
		return true
	Log.warn(&"deployables", "slot %d: %s needs %s" % [slot, id, flag])
	return false


## QB-58: an armor bag needs deploy.armor_bag; the bag keeps the loadout armor, the crew member
## starts in DeployableTweak.armor_bag_start_armor. False = not allowed (no bag).
func _setup_armor_bag(c: CrewController) -> bool:
	if not Modifiers.flag(c.slot, &"deploy.armor_bag"):
		Log.warn(&"deployables", "slot %d: armor bag needs deploy.armor_bag (Walk-in Closet)" % c.slot)
		return false
	var start: StringName = DeployableTweak.data().armor_bag_start_armor
	_bag_armor[c.slot] = c.loadout.armor if c.loadout.armor != &"" else start
	if c.loadout.armor != start:
		wear_armor(c, start)
	return true


## Server: `crew` changes into ArmorDef `armor_id` now (armor bag): max armor recomputed and filled,
## health kept. The crew member's loadout is copied first (the caller's Loadout is not changed).
static func wear_armor(crew: CrewController, armor_id: StringName) -> void:
	if crew == null or crew.loadout == null:
		return
	var l: Loadout = crew.loadout.duplicate() as Loadout
	l.armor = armor_id
	crew.loadout = l
	if crew.health != null:
		crew.health.max_armor = crew.health.compute_max_armor()
		crew.health.armor = crew.health.max_armor
		crew.health.regen_delay_left = 0.0


## Server/test hook: give `slot` deployable `id` (replaces the inventory). count -1 = loadout rule.
func give(slot: int, id: StringName, count: int = -1) -> void:
	var def: DeployableDef = def_for(id)
	if def == null:
		Log.warn(&"deployables", "give: unknown deployable %s" % id)
		return
	_inv[slot] = [{"id": id, "count": count_for(slot, def) if count < 0 else count}]
	_sync(slot)


## Server, D-157: one `id` back into `slot`'s inventory (a picked-up sentry).
func restock(slot: int, id: StringName) -> void:
	for r: Dictionary in _inv.get(slot, []):
		if StringName(r["id"]) == id:
			r["count"] = int(r["count"]) + 1
			_sync(slot)
			return
	if not _inv.has(slot):
		_inv[slot] = []
	(_inv[slot] as Array).append({"id": id, "count": 1})
	_sync(slot)


func _current_row(slot: int) -> Dictionary:
	var rows: Array = _inv.get(slot, [])
	for r: Dictionary in rows:
		if int(r["count"]) > 0:
			return r
	return rows[0] if not rows.is_empty() else {}


func deployable_id(slot: int) -> StringName:
	var r: Dictionary = _current_row(slot)
	return StringName(r.get("id", &""))


## S9.5: total carried count of deployables of `kind` for `slot` (all rows).
func count_of_kind(slot: int, kind: StringName) -> int:
	var n: int = 0
	for r: Dictionary in _inv.get(slot, []):
		var def: DeployableDef = def_for(StringName(r["id"]))
		if def != null and def.kind == kind:
			n += int(r["count"])
	return n


## S9.5: server, take `n` deployables of `kind` from `slot` (all or nothing).
func consume_kind(slot: int, kind: StringName, n: int) -> bool:
	if n <= 0 or count_of_kind(slot, kind) < n:
		return false
	var left: int = n
	for r: Dictionary in _inv.get(slot, []):
		var def: DeployableDef = def_for(StringName(r["id"]))
		if left > 0 and def != null and def.kind == kind:
			var take: int = mini(int(r["count"]), left)
			r["count"] = int(r["count"]) - take
			left -= take
	_sync(slot)
	return true


func deployable_count(slot: int) -> int:
	return int(_current_row(slot).get("count", 0))


## Hold progress 0..1 (-1 when not deploying).
func deploy_progress(slot: int) -> float:
	if not _hold.has(slot):
		return -1.0
	var def: DeployableDef = def_for(deployable_id(slot))
	if def == null:
		return -1.0
	return clampf(_hold[slot] / maxf(deploy_time_for(slot, def), 0.001), 0.0, 1.0)


func _sync(slot: int) -> void:
	var c: CrewController = _runtime.crew_controller(slot) as CrewController if _runtime != null else null
	if c != null and c.weapons != null:
		c.weapons.set_deployable(deployable_id(slot), deployable_count(slot))


# --- Deploy hold -------------------------------------------------------------------------------------

## Crew tick handler (HeistRuntime.crew_actions_tick, server).
func tick(crew: CrewController, intent: CrewIntent, delta: float) -> void:
	if not Net.is_authority() or crew == null:
		return
	var slot: int = crew.slot
	if intent == null or not intent.deploy:
		_hold.erase(slot)
		_needs_release.erase(slot)
		return
	if _needs_release.get(slot, false):
		return
	var reason: StringName = can_deploy(crew)
	if reason != BLOCK_NONE:
		blocked[slot] = reason
		_hold.erase(slot)
		_needs_release[slot] = true
		return
	blocked.erase(slot)
	var def: DeployableDef = def_for(deployable_id(slot))
	_hold[slot] = float(_hold.get(slot, 0.0)) + delta
	if _hold[slot] + 0.0001 < deploy_time_for(slot, def):
		return
	_hold.erase(slot)
	_needs_release[slot] = true
	place(crew)


## Why `crew` cannot deploy now (&"" = allowed).
func can_deploy(crew: CrewController) -> StringName:
	if crew.is_casing():
		return BLOCK_CASING  # S1.1
	if crew.crew_state != Enums.CrewState.NORMAL:
		return BLOCK_STATE
	if deployable_count(crew.slot) <= 0 or def_for(deployable_id(crew.slot)) == null:
		return BLOCK_EMPTY
	if placement_for(crew).is_empty():
		return BLOCK_PLACE
	return BLOCK_NONE


## {"transform": Transform3D, "reader": Node or null} or {} when there is no floor in front.
func placement_for(crew: CrewController) -> Dictionary:
	var tw: DeployableTweak = DeployableTweak.data()
	var fwd: Vector3 = crew.aim_direction()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	var reader: Node = _aimed_reader(crew)
	var probe: Vector3 = crew.global_position + fwd * tw.place_forward_m
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		probe + Vector3.UP * tw.place_probe_up_m, probe + Vector3.DOWN * tw.place_probe_down_m, FLOOR_MASK)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	# Front (-Z) faces the crew member.
	var basis: Basis = Basis.looking_at(-fwd, Vector3.UP)
	return {"transform": Transform3D(basis, hit["position"]), "reader": reader}


## S8.5: a keycard reader in front of the crew eye (only for an ECM with stealth.ecm_opens_doors).
func _aimed_reader(crew: CrewController) -> Node:
	var def: DeployableDef = def_for(deployable_id(crew.slot))
	if def == null or def.kind != &"ecm" or not Modifiers.flag(crew.slot, &"stealth.ecm_opens_doors"):
		return null
	var tw: DeployableTweak = DeployableTweak.data()
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var best: Node = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp == null:
			continue
		var reader: KeycardReader = comp.owner_node() as KeycardReader
		if reader == null or reader.used or not reader.is_inside_tree():
			continue
		var to: Vector3 = reader.global_position - eye
		var d: float = to.length()
		if d > tw.ecm_reader_reach_m or d < 0.001 or rad_to_deg(aim.angle_to(to)) > tw.ecm_reader_cone_deg:
			continue
		if d < best_d:
			best = reader
			best_d = d
	return best


## Server: place one deployable for `crew` now (no hold). `id` = &"" -> the current one.
## Decrements the count. Returns the DeployablePrefab or null.
func place(crew: CrewController, id: StringName = &"") -> Node:
	if not Net.is_authority() or crew == null or _runtime == null:
		return null
	var slot: int = crew.slot
	var row: Dictionary = _current_row(slot)
	if id != &"":
		for r: Dictionary in _inv.get(slot, []):
			if StringName(r["id"]) == id:
				row = r
	if row.is_empty() or int(row["count"]) <= 0:
		return null
	var def: DeployableDef = def_for(StringName(row["id"]))
	var spot: Dictionary = placement_for(crew)
	if def == null or spot.is_empty():
		return null
	row["count"] = int(row["count"]) - 1
	var p: DeployablePrefab = (load(SCENE) as PackedScene).instantiate() as DeployablePrefab
	p.setup(def, slot, uses_for(slot, def))
	if def.kind == &"armor_bag":
		p.bag_armor = _bag_armor.get(slot, &"")
	p.name = "Deployable_%s_%d" % [def.kind, _runtime.dynamic_root.get_child_count()]
	var reader: Node = spot.get("reader") as Node
	if reader != null:
		p.transform = Transform3D(reader.global_transform.basis, reader.global_position)
	else:
		p.transform = spot["transform"]
	_runtime.dynamic_root.add_child(p, true)
	if def.kind == &"sentry" and SentryGun.of(p) != null:
		SentryGun.of(p).pay_deploy_cost(crew)  # D-157: the owner's ammo
	_sync(slot)
	if def.kind == &"ecm":
		var ecm: EcmSystem = _runtime.service(EcmSystem.SERVICE) as EcmSystem
		if ecm != null:
			if reader != null:
				ecm.attach_to_reader(p, reader)
			else:
				ecm.add_jammer(p)
	Log.info(&"deployables", "slot %d placed %s (%d left)" % [slot, def.id, int(row["count"])])
	deployed.emit(slot, p)
	return p


## Placed deployables in this heist (optionally one kind).
func placed(kind: StringName = &"") -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(G.DEPLOYABLE):
		var p: DeployablePrefab = n as DeployablePrefab
		if p == null or p.is_queued_for_deletion() or (_runtime != null and not _runtime.is_ancestor_of(p)):
			continue
		if kind == &"" or p.kind == kind:
			out.append(p)
	return out
