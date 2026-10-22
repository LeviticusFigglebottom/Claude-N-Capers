## Network codec for heist entities (A3-07, docs/contracts/net.md). Owner: ENV A.
## Pure static helpers used by HeistNetSync:
## * spawn descriptors `{scene, script, name, net_id, xform, params}` for dynamic entities (NPCs,
##   crew, loot bags, deployables, pre-planning drops, anything under HeistRuntime.dynamic_root
##   carrying a `net_id`) and the client-side instantiation of a descriptor;
## * discrete state `{key: value}` per entity (server `state_of`, client `apply_state`). A node may
##   provide the virtual hooks `_net_state() -> Dictionary` / `_apply_net_state(state)` itself; otherwise a generic
##   property list is mirrored (door open, glass broken, camera off, device progress...);
## * continuous transforms (`xform_of` / `apply_xform`) for NPCs, crew and loose bags.
## Values are network-serializable only (no Node or Resource references: net_ids and res:// paths).
class_name NetEntityCodec
extends RefCounted

## Mirrored when present on a node without its own `net_state()` (map prefabs, deployables).
const GENERIC_PROPS: Array[StringName] = [
	&"is_open", &"locked", &"broken", &"glass_broken", &"opened", &"taken", &"used", &"pressed",
	&"active", &"destroyed", &"disabled_reason", &"cameras_off", &"staffed", &"tripped", &"remaining",
	&"stored", &"state", &"progress", &"duration", &"stage", &"timer_left", &"beaten_by", &"uses_left",
	&"ammo_left", &"ecm_state", &"jam_left", &"arrival_left", &"landing", &"destination", &"trip_t",
	&"saw_progress", &"usable", &"delivered", &"placed_kind", &"height_m", &"powered",
]
## Crew members' replicated fields (crew_state, mask, inventory, carried bag, vitals).
const CREW_HEALTH_PROPS: Array[StringName] = [
	&"health", &"max_health", &"armor", &"max_armor", &"downs_used", &"bleedout_left", &"flashed_left",
]
## NPC children that only make sense on the authority (brains, motors, gunners, nav agents).
const NPC_SERVER_ONLY: Array[String] = ["Brain", "Motor", "Gunner", "NavAgent"]
const LOADOUT_PROPS: Array[StringName] = [
	&"primary", &"secondary", &"melee", &"throwable", &"deployable", &"deployable_secondary", &"armor",
	&"mask", &"mask_descriptor", &"perk_deck", &"perk_deck_cards", &"skills", &"modifiers",
	&"concealment_total", &"detection_risk", &"heister",
]


# --- Spawn descriptors -----------------------------------------------------------------------

## Server: descriptor of a dynamic entity (the node must already carry its net_id).
static func describe(node: Node) -> Dictionary:
	var n3: Node3D = node as Node3D
	var script: Script = node.get_script() as Script
	var d: Dictionary = {
		"scene": node.scene_file_path, "script": script.resource_path if script != null else "",
		"name": String(node.name), "net_id": NetIds.of(node),
		"xform": n3.global_transform if n3 != null and n3.is_inside_tree() else Transform3D.IDENTITY,
		"params": _spawn_params(node),
	}
	return d


static func _spawn_params(node: Node) -> Dictionary:
	var p: Dictionary = {}
	var crew: CrewController = node as CrewController
	if crew != null:
		p = {"slot": crew.slot, "loadout": loadout_to_dict(crew.loadout), "masked": crew.masked}
		return p
	var npc: NpcBase = node as NpcBase
	if npc != null:
		p = {
			"role": npc.role, "difficulty": npc.difficulty, "alive": npc.alive, "alert": int(npc.alert_state),
			"enemy_def": npc.enemy_def.resource_path if npc.enemy_def != null else "",
			"tags": (npc.spawn_info.get("tags", []) as Array).duplicate(),
			"look": int(npc.spawn_info.get("look", -1)),  # D-115: the authority's look pick (NpcVisuals)
		}
		return p
	var bag: LootBag = node as LootBag
	if bag != null:
		p = {
			"loot_id": bag.loot_id, "weight": int(bag.weight), "value": bag.value, "moved": bag.moved,
			"visual": bag.visual_scene.resource_path if bag.visual_scene != null else "",
		}
		return p
	var dep: DeployablePrefab = node as DeployablePrefab
	if dep != null:
		p = {"deployable_id": dep.deployable_id, "owner_slot": dep.owner_slot, "uses": dep.uses_left}
	for k: StringName in [&"asset_id", &"kind", &"objective_tag", &"params"]:
		if k in node and not p.has(String(k)):
			p[String(k)] = node.get(k)
	return p


## Client: build the node of a descriptor (not yet in the tree; HeistNetSync adds it). Null on error.
static func instantiate(d: Dictionary) -> Node:
	var node: Node = null
	var scene_path: String = String(d.get("scene", ""))
	var script_path: String = String(d.get("script", ""))
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var ps: PackedScene = load(scene_path) as PackedScene
		node = ps.instantiate() if ps != null else null
	elif script_path != "" and ResourceLoader.exists(script_path):
		var s: GDScript = load(script_path) as GDScript
		node = s.new() as Node if s != null and s.can_instantiate() else null
	if node == null:
		Log.error(&"net", "cannot instantiate replicated entity %s (scene '%s', script '%s')" % [d.get("name"), scene_path, script_path])
		return null
	node.name = String(d.get("name", node.name))
	_configure(node, d.get("params", {}) as Dictionary)
	return node


static func _configure(node: Node, p: Dictionary) -> void:
	var crew: CrewController = node as CrewController
	if crew != null:
		var slot: int = int(p.get("slot", 0))
		var info: Dictionary = Net.crew.get(slot, {"peer_id": Net.AI_PEER, "is_ai": true, "display_name": "Crew %d" % slot})
		crew.setup(slot, info, loadout_from_dict(p.get("loadout", {}) as Dictionary))
		return
	var npc: NpcBase = node as NpcBase
	if npc != null:
		var def_path: String = String(p.get("enemy_def", ""))
		if def_path != "" and ResourceLoader.exists(def_path):
			npc.enemy_def = load(def_path) as EnemyDef
		npc.role = StringName(p.get("role", npc.role))
		npc.setup_npc(int(p.get("difficulty", 0)), {"tags": p.get("tags", []), "replica": true,
			"look": int(p.get("look", -1))})
		for child_name: String in NPC_SERVER_ONLY:  # the server simulates; the client only renders
			var c: Node = npc.get_node_or_null(child_name)
			if c != null:
				npc.remove_child(c)
				c.free()
		return
	var bag: LootBag = node as LootBag
	if bag != null:
		bag.loot_id = StringName(p.get("loot_id", &""))
		bag.weight = int(p.get("weight", Enums.LootWeight.MEDIUM)) as Enums.LootWeight
		bag.value = int(p.get("value", 0))
		bag.moved = bool(p.get("moved", false))
		var vis: String = String(p.get("visual", ""))
		if vis != "" and ResourceLoader.exists(vis):
			bag.visual_scene = load(vis) as PackedScene
		bag.freeze = true  # the server simulates bag physics; clients follow the replicated transform
		return
	var dep: DeployablePrefab = node as DeployablePrefab
	if dep != null:
		var def: DeployableDef = DeployableSystem.def_for(StringName(p.get("deployable_id", &"")))
		if def != null:
			dep.setup(def, int(p.get("owner_slot", -1)), int(p.get("uses", 1)))
	for k: String in ["asset_id", "kind", "objective_tag", "params"]:
		if p.has(k) and StringName(k) in node:
			node.set(StringName(k), p[k])


## Client, after the node entered the tree: transform, net id, post-ready state.
static func finish_spawn(node: Node, d: Dictionary) -> void:
	var n3: Node3D = node as Node3D
	var p: Dictionary = d.get("params", {}) as Dictionary
	var crew: CrewController = node as CrewController
	if crew != null:
		crew.teleport(d.get("xform", Transform3D.IDENTITY) as Transform3D)
		if bool(p.get("masked", false)):
			crew.set_masked(false)
	elif n3 != null:
		n3.global_transform = d.get("xform", Transform3D.IDENTITY) as Transform3D
	NetIds.adopt(node, int(d.get("net_id", Ids.INVALID)))
	var npc: NpcBase = node as NpcBase
	if npc != null:
		npc.set_alert_state(int(p.get("alert", Enums.AlertState.CALM)) as Enums.AlertState)
		if not bool(p.get("alive", true)):
			npc.die({}, 0)
	var bag: LootBag = node as LootBag
	if bag != null:
		bag.freeze = true


static func loadout_to_dict(l: Loadout) -> Dictionary:
	var out: Dictionary = {}
	if l == null:
		return out
	for k: StringName in LOADOUT_PROPS:
		out[String(k)] = l.get(k)
	out["primary_mods"] = Array(l.primary_mods)
	out["secondary_mods"] = Array(l.secondary_mods)
	return out


## Null for an empty dictionary (CrewWeapons.build_loadout then uses the default kit).
static func loadout_from_dict(d: Dictionary) -> Loadout:
	if d.is_empty():
		return null
	var l: Loadout = Loadout.new()
	for k: StringName in LOADOUT_PROPS:
		if d.has(String(k)):
			l.set(k, d[String(k)])
	l.primary_mods.assign(d.get("primary_mods", []) as Array)
	l.secondary_mods.assign(d.get("secondary_mods", []) as Array)
	return l


# --- Discrete state ----------------------------------------------------------------------------

## Server: replicated discrete state of `node` ({} = nothing to mirror).
static func state_of(node: Node) -> Dictionary:
	var out: Dictionary = _state_of(node)
	var gp: GameplayPrefab = node as GameplayPrefab
	if gp != null:
		out["pe"] = gp.prefab_enabled  # OF-A2 (QC-61): runtime enable of every map prefab
	return out


static func _state_of(node: Node) -> Dictionary:
	if node.has_method(&"_net_state"):
		return node.call(&"_net_state") as Dictionary
	var crew: CrewController = node as CrewController
	if crew != null:
		return _crew_state(crew)
	var npc: NpcBase = node as NpcBase
	if npc != null:
		var st: Dictionary = {"alive": npc.alive, "alert": int(npc.alert_state), "hp": npc.health, "stun": npc.stun_left > 0.0}
		if not npc.visible:
			st["hid"] = true  # QC-83: a unit seated in an armoured cab
		var gb: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain
		if gb != null:
			st["dom"] = gb.dominate_window_left > 0.0  # PP-A-1: the S5.8 window, for the client HUD cue
		var brain: Node = npc.get_node_or_null(^"Brain")
		var hint: Variant = brain.get(&"anim_hint") if brain != null else null
		if hint is StringName:
			st["ah"] = hint if AnimDriver.NET_HINTS.has(hint) else &""  # D-116: the cuff (interact_low) on clients
		var ca: Array = CorpseAnchor.net_value(npc)
		if not ca.is_empty():
			st["ca"] = ca  # D-121: the corpse's gameplay anchor + push direction (root, bag interaction, hitbox)
		var rd: NpcRagdoll = NpcRagdoll.of(npc)
		if rd != null:
			rd.net_state(st)  # PO6-19: "rs" start / push, "rp" frozen pose
		return st
	var bag: LootBag = node as LootBag
	if bag != null:
		var crew_carried: bool = bag.is_carried() and not bag.is_npc_carried()
		return {"carrier": NetIds.of(bag.carrier) if crew_carried else 0, "secured": bag.secured,
			"npc": NetIds.of(bag.npc_carrier) if bag.is_npc_carried() else 0, "tag": bag.objective_tag,
			"hidden": bag.hidden_from_stealth, "moved": bag.moved}
	var out: Dictionary = {}
	for k: StringName in GENERIC_PROPS:
		if k in node:
			var v: Variant = node.get(k)
			if v is bool or v is int or v is float or v is StringName or v is String:
				out[String(k)] = v
	var runner: Variant = node.get(&"runner")
	if runner is DeviceRunner:
		var r: DeviceRunner = runner as DeviceRunner
		out["runner"] = [int(r.state), r.progress, r.duration, r.slot, r.restart_left]
	var comp: Variant = node.get(&"interactable")
	if comp is InteractableComponent and is_instance_valid(comp):
		out["ie"] = (comp as InteractableComponent).enabled
	var sentry: SentryGun = SentryGun.of(node)
	if sentry != null:
		out["sentry"] = sentry.net_state()  # D-157: aim, ammo, mode, health, shield
	return out


static func _crew_state(crew: CrewController) -> Dictionary:
	var out: Dictionary = {
		"cs": int(crew.crew_state), "masked": crew.masked, "mp": crew.mask_progress, "bb": crew.body_bags,
		"ct": crew.cable_ties, "items": crew.items.duplicate(), "bag": NetIds.of(crew.carried_bag) if crew.is_carrying_bag() else 0,
		"hidden": crew.stealth_hidden, "civ": crew.civilian,
		"pid": crew.peer_id, "ai": crew.is_ai, "nm": crew.display_name,  # QB-B6-DROPIN: drop-in / drop-out owner
		# QB-60 stamina for the HUD (ui_hud v1.4); 0.01 steps keep the diff small. A remote human's own
		# peer simulates its stamina and ignores this (the server does not simulate it).
		"st": snappedf(crew.stamina.fraction(), 0.01), "sx": crew.stamina.exhausted,
	}
	if crew.health != null:
		for k: StringName in CREW_HEALTH_PROPS:
			out["h_" + String(k)] = crew.health.get(k)
	if crew.weapons != null:
		out["gd"] = crew.weapons.gadget_bits()  # D-118 laser / flashlight per slot
	return out


## Client: apply a (partial) state dictionary from the server.
static func apply_state(node: Node, d: Dictionary) -> void:
	var gp: GameplayPrefab = node as GameplayPrefab
	if gp != null and d.has("pe"):
		gp.prefab_enabled = bool(d["pe"])  # OF-A2: before the prefab's own state
		d = d.duplicate()
		d.erase("pe")
	if node.has_method(&"_apply_net_state"):
		node.call(&"_apply_net_state", d)
		return
	var crew: CrewController = node as CrewController
	if crew != null:
		_apply_crew_state(crew, d)
		return
	var npc: NpcBase = node as NpcBase
	if npc != null:
		_apply_npc_state(npc, d)
		return
	var bag: LootBag = node as LootBag
	if bag != null:
		_apply_bag_state(bag, d)
		return
	var safe: Safe = node as Safe
	if safe != null and bool(d.get("opened", false)) and not safe.opened:
		safe.swing_open()  # visuals + inner loot (not authority-guarded)
	for k: Variant in d:
		var key: String = String(k)
		if key == "ie":
			var comp: InteractableComponent = node.get(&"interactable") as InteractableComponent
			if comp != null:
				comp.enabled = bool(d[k])
		elif key == "runner":
			_apply_runner(node, d[k] as Array)
		elif key == "sentry":
			if SentryGun.of(node) != null:
				SentryGun.of(node).apply_net_state(d[k] as Dictionary)
		elif StringName(key) in node:
			node.set(StringName(key), d[k])


static func _apply_runner(node: Node, a: Array) -> void:
	var r: DeviceRunner = node.get(&"runner") as DeviceRunner
	if r == null:
		return  # the prefab creates its runner in _prefab_ready on every peer
	var changed: bool = int(r.state) != int(a[0])
	r.state = int(a[0]) as DeviceRunner.State
	r.progress = float(a[1])
	r.duration = float(a[2])
	r.slot = int(a[3])
	r.restart_left = float(a[4])
	if changed:
		r.state_changed.emit(int(r.state))


static func _apply_crew_state(crew: CrewController, d: Dictionary) -> void:
	if d.has("masked") and bool(d["masked"]) and not crew.masked:
		crew.set_masked(false)
	if d.has("mp"):
		crew.mask_progress = float(d["mp"])
	if d.has("cs"):
		crew.set_crew_state(int(d["cs"]) as Enums.CrewState)
	if d.has("bb"):
		crew.body_bags = int(d["bb"])
	if d.has("ct"):
		crew.cable_ties = int(d["ct"])
	if d.has("hidden"):
		crew.stealth_hidden = bool(d["hidden"])
	if d.has("gd") and crew.weapons != null:
		crew.weapons.apply_gadget_bits(int(d["gd"]))
	if d.has("civ"):
		crew.civilian = bool(d["civ"])
	if d.has("pid"):
		crew.peer_id = int(d["pid"])
	if d.has("ai"):
		crew.is_ai = bool(d["ai"])
	if d.has("nm"):
		crew.display_name = String(d["nm"])
	if (d.has("st") or d.has("sx")) and not crew.is_local():
		crew.stamina.apply_replicated(float(d.get("st", crew.stamina.fraction())), bool(d.get("sx", crew.stamina.exhausted)))
	if d.has("items"):
		crew.items.assign(d["items"] as Dictionary)
		crew.inventory_changed.emit()
	if d.has("bag"):
		var bag: Node = Ids.lookup(int(d["bag"]))
		if bag != crew.carried_bag:
			crew.set_carried_bag(bag)
	if crew.health != null:
		for k: StringName in CREW_HEALTH_PROPS:
			if d.has("h_" + String(k)):
				crew.health.set(k, d["h_" + String(k)])


static func _apply_npc_state(npc: NpcBase, d: Dictionary) -> void:
	if not Net.is_authority():
		npc.visible = not bool(d.get("hid", false))
	if d.has("hp"):
		npc.health = float(d["hp"])
	if d.has("alert") and npc.alive:
		npc.set_alert_state(int(d["alert"]) as Enums.AlertState)
	if d.has("alive") and not bool(d["alive"]) and npc.alive:
		npc.die({}, 0)
	if d.has("ca") and not Net.is_authority():
		var ca: Array = d["ca"] as Array
		if ca.size() >= 2 and (npc.corpse_anchor != (ca[0] as Vector3) or npc.corpse_dir != (ca[1] as Vector3)):
			CorpseAnchor.apply(npc, ca[0] as Vector3, ca[1] as Vector3)
	if d.has("rs") or d.has("rp"):
		var rd: NpcRagdoll = NpcRagdoll.of(npc)
		if rd != null:
			rd.apply_net_state(d)
	if d.has("ah") and not Net.is_authority():
		npc.set_meta(AnimDriver.META_NET_HINT, StringName(d["ah"]))
	if d.has("dom"):
		var gb: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain
		if gb != null and not Net.is_authority():
			var on: bool = bool(d["dom"])
			if on and gb.dominate_window_left <= 0.0:
				gb.dominate_window_left = Tweak.stealth().guard_dominate_window_s
			elif not on:
				gb.dominate_window_left = 0.0


static func _apply_bag_state(bag: LootBag, d: Dictionary) -> void:
	if d.has("moved"):
		bag.moved = bool(d["moved"])
	if d.has("hidden"):
		bag.hidden_from_stealth = bool(d["hidden"])
	if d.has("secured") and bool(d["secured"]) and not bag.secured:
		bag.secured = true
		if bag.interactable != null:
			bag.interactable.enabled = false
	if d.has("tag"):
		bag.objective_tag = StringName(d["tag"])
	if d.has("carrier"):
		var c: CrewController = Ids.lookup(int(d["carrier"])) as CrewController
		var npc: NpcBase = Ids.lookup(int(d.get("npc", 0))) as NpcBase  # QC-57: a courier's bag
		bag.carrier = c
		bag.npc_carrier = npc
		if bag.interactable != null:
			bag.interactable.enabled = c == null and npc == null and not bag.secured
		bag.collision_layer = 0 if c != null or npc != null else LootBag.LAYER_LOOT


# --- Continuous transforms ---------------------------------------------------------------------

## Server: compact transform of a moving entity, or null when it is not continuously synced.
static func xform_of(node: Node) -> Variant:
	var crew: CrewController = node as CrewController
	if crew != null:
		return [crew.global_position, crew.look_yaw, crew.look_pitch, crew.crouched]
	if node is NpcBase:
		return (node as Node3D).global_transform
	var bag: LootBag = node as LootBag
	if bag != null and not bag.is_carried():
		return bag.global_transform
	if node.has_method(&"_net_xform"):
		return node.call(&"_net_xform")  # PO6-17: moving dynamic entities (assault van / heli)
	return null


## Client: apply a transform from `xform_of` (the owner's own crew member is client-predicted).
static func apply_xform(node: Node, x: Variant) -> void:
	var crew: CrewController = node as CrewController
	if crew != null:
		if crew.is_local():
			return
		var a: Array = x as Array
		crew.global_position = a[0] as Vector3
		crew.look_yaw = float(a[1])
		crew.look_pitch = float(a[2])
		crew.rotation = Vector3(0.0, crew.look_yaw, 0.0)
		crew.crouched = bool(a[3])
		return
	var n3: Node3D = node as Node3D
	if NpcRagdoll.owns_pose(node):
		return  # PO6-19: a ragdolled corpse's root comes with its frozen pose ("rp")
	var dead: NpcBase = node as NpcBase
	if dead != null and not dead.alive:
		if x is Transform3D and dead.corpse_anchor == Vector3.INF:
			CorpseAnchor.move_root(dead, (x as Transform3D).origin)  # D-121: the root jumps to the anchor, not the visual
		return  # the anchor ("ca") owns a corpse's root
	if n3 != null and x is Transform3D:
		var bag: LootBag = node as LootBag
		if bag != null and bag.is_carried():
			return
		n3.global_transform = x as Transform3D
