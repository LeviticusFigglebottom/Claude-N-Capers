## C3 pre-planning: applies a PreplanResult at launch (docs/contracts/preplanning.md v1.0, D-038).
## Owner: ENV A (A2-07, A3-08). ENV B resolves the plan (`PreplanPlan.apply()`); ENV A only applies
## it and never re-resolves the asset catalog. HeistRuntime owns one instance (`rt.preplan`).
## Shapes and examples: game/systems/heist/README.md.
##
## Launch options:
##   options["preplan"]      = PreplanResult (version 1), applied as given.
##   options["preplanning"]  = dev/test shortcut: asset ids (Array, or Dictionary {id: point_id | true}).
##     They are resolved by ENV B (`PreplanPlan.resolve_ids(heist_id, ids)`, or while that is not
##     shipped, a PreplanBoard + PreplanPlan built from the ids and `apply()`), never by ENV A.
##
## Normalized result (`result`, contract keys; ENV B's pre-contract hand-off keys are accepted too:
## spawns[{asset,item,point}] -> drops, player_spawn_tag -> spawn_tag, reveal_variant_groups -> reveals,
## force_variants [{asset,group,slot}] -> {group: [slots]}):
##   { "version": 1, "modifier_sources": {asset_id: {key: value}}, "drops": [{asset, kind, point, params}],
##     "spawn_tag": StringName, "escape_tag": StringName, "force_variants": {group: [slot_ids]},
##     "reveals": [group], "cash_spent": {slot: int}, "plan": Dictionary }
## QC-63 (OF-A3): `reveal_group(group)` (server, runtime) adds a variant group to `reveals()` mid-run (an intel note:
## OF's manager planner -> `code_pc`), the same effect as an asset's `reveals`; kept apart from `result` (not a bought
## asset, `is_active()` unchanged) and mirrored to clients by HeistNetSync (service "reveals").
class_name PreplanAssets
extends RefCounted

## QC-63: a variant group was revealed at runtime (server, and on clients when the mirror adds it).
signal group_revealed(group: StringName)

const OPTION_KEY: String = "preplan"
const DEV_OPTION_KEY: String = "preplanning"
const RESULT_VERSION: int = 1
const SOURCE_PREFIX: String = "asset."
const DEPLOYABLE_PREFIX: String = "deployable."
## `<Map>/Preplan` (heist_map.md v1.2): PREPLAN_POINT Marker3Ds, node name = point id.
const POINTS_NODE: String = "Preplan"
## Fallback drop nodes join this group.
const DROP_GROUP: StringName = &"preplan_drop"
## D-068: drop kinds `loot.<id>` spawn a loot bag of that id at the point (LootManager.spawn_bag).
const LOOT_PREFIX: String = "loot."

## Drop kind -> scene path or Callable(asset_id, drop: Dictionary) -> Node3D. Unregistered kinds:
## `deployable.<x>` with a DeployableDef -> a DeployablePrefab (no owner); else
## res://systems/prefabs/<kind>/<kind>.tscn; else a PreplanDrop marker node.
static var _drop_factories: Dictionary = {}

## Normalized PreplanResult (empty = no pre-planning).
var result: Dictionary = {}
## Nodes spawned for drops: point id -> Node3D (one asset per point, PD2).
var drops: Dictionary = {}
## QC-63: variant groups revealed during the run (intel notes), in reveal order.
var runtime_reveals: Array[StringName] = []


## Register how a drop kind is spawned (scene path String or Callable(asset_id, drop) -> Node3D).
static func register_drop(kind: StringName, scene_or_factory: Variant) -> void:
	_drop_factories[kind] = scene_or_factory


static func unregister_drop(kind: StringName) -> void:
	_drop_factories.erase(kind)


## Read the launch options. `def` / `p_heist_id` / `p_difficulty` are only used for the dev ids path.
func setup(options: Dictionary, def: HeistDef, p_heist_id: StringName = &"", p_difficulty: int = 0) -> void:
	result = {}
	drops.clear()
	runtime_reveals.clear()
	var raw: Variant = options.get(OPTION_KEY, null)
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		result = normalize(raw as Dictionary)
	elif options.has(DEV_OPTION_KEY):
		var hid: StringName = p_heist_id if p_heist_id != &"" else (def.id if def != null else &"")
		var resolved: Dictionary = resolve_ids(hid, p_difficulty, options[DEV_OPTION_KEY], def)
		if not resolved.is_empty():
			result = normalize(resolved)
	if not result.is_empty():
		Log.info(&"preplan", "assets %s" % [asset_ids()])


## True when a PreplanResult is being applied.
func is_active() -> bool:
	return not result.is_empty()


## Dev/test: resolve asset ids with ENV B's resolver. `ids`: Array of ids, or {id: point_id | true}.
static func resolve_ids(heist_id: StringName, difficulty: int, ids: Variant, def: HeistDef = null) -> Dictionary:
	var picks: Array[Dictionary] = []
	if ids is Array:
		for id: Variant in ids:
			picks.append({"asset": StringName(id), "point": &""})
	elif ids is Dictionary:
		for id: Variant in ids:
			var v: Variant = (ids as Dictionary)[id]
			var pt: StringName = StringName(v) if (v is String or v is StringName) else &""
			picks.append({"asset": StringName(id), "point": pt})
	if picks.is_empty():
		return {}
	if _plan_has_static(&"resolve_ids"):
		var id_list: Array[StringName] = []
		for p: Dictionary in picks:
			id_list.append(p["asset"])
		var out: Variant = (PreplanPlan as Script).call(&"resolve_ids", heist_id, id_list)
		return out as Dictionary if out is Dictionary else {}
	return _resolve_with_plan(heist_id, difficulty, picks, def)


## Bridge until ENV B ships PreplanPlan.resolve_ids (B4-08): ENV B's board + plan + apply().
## Located assets without a point take the first allowed point of the board's blueprint.
static func _resolve_with_plan(heist_id: StringName, difficulty: int, picks: Array[Dictionary], def: HeistDef) -> Dictionary:
	var board: PreplanBoard = PreplanBoard.build(heist_id, difficulty, def)
	var plan: PreplanPlan = PreplanPlan.new(board)
	for p: Dictionary in picks:
		var id: StringName = p["asset"]
		var a: PreplanAssetDef = board.asset(id)
		if a == null:
			Log.warn(&"preplan", "asset '%s' is not on the %s board; ignored" % [id, heist_id])
			continue
		var pt: StringName = p["point"]
		if pt == &"" and a.is_located():
			pt = _first_point(board, a)
		var r: StringName = plan.add(id, pt, 0)
		if r != PreplanPlan.OK:
			Log.warn(&"preplan", "asset '%s'@'%s' refused: %s" % [id, pt, r])
	if plan.selections.is_empty():
		return {}
	return plan.apply()


static func _first_point(board: PreplanBoard, a: PreplanAssetDef) -> StringName:
	if not a.point_ids.is_empty():
		return a.point_ids[0]
	for pid: StringName in board.blueprint.point_ids():
		if a.allows_point(pid, board.blueprint.category_of(pid)):
			return pid
	return &""


static func _plan_has_static(method: StringName) -> bool:
	for m: Dictionary in (PreplanPlan as Script).get_script_method_list():
		if StringName(m.get("name", "")) == method:
			return true
	return false


## Contract shape from a PreplanResult (also accepts ENV B's pre-contract hand-off keys).
static func normalize(raw: Dictionary) -> Dictionary:
	var version: int = int(raw.get("version", RESULT_VERSION))
	if version != RESULT_VERSION:
		Log.warn(&"preplan", "PreplanResult version %d (expected %d); applying known keys" % [version, RESULT_VERSION])
	var mods: Dictionary = {}
	var rm: Variant = raw.get("modifier_sources", {})
	if rm is Dictionary:
		for id: Variant in rm:
			if (rm as Dictionary)[id] is Dictionary:
				mods[StringName(id)] = ((rm as Dictionary)[id] as Dictionary).duplicate(true)
	var out_drops: Array[Dictionary] = []
	for d: Variant in raw.get("drops", raw.get("spawns", [])) as Array:
		if not (d is Dictionary):
			continue
		var dd: Dictionary = d
		out_drops.append({
			"asset": StringName(dd.get("asset", &"")),
			"kind": StringName(dd.get("kind", dd.get("item", &""))),
			"point": StringName(dd.get("point", &"")),
			"params": (dd.get("params", {}) as Dictionary).duplicate(true),
		})
	var reveals: Array[StringName] = []
	for g: Variant in raw.get("reveals", raw.get("reveal_variant_groups", [])) as Array:
		if not reveals.has(StringName(g)):
			reveals.append(StringName(g))
	return {
		"version": RESULT_VERSION,
		"modifier_sources": mods,
		"drops": out_drops,
		"spawn_tag": StringName(raw.get("spawn_tag", raw.get("player_spawn_tag", &""))),
		"escape_tag": StringName(raw.get("escape_tag", &"")),
		"force_variants": _normalize_forces(raw.get("force_variants", {})),
		"reveals": reveals,
		"cash_spent": (raw.get("cash_spent", {}) as Dictionary).duplicate(true),
		"plan": (raw.get("plan", {}) as Dictionary).duplicate(true),
	}


static func _normalize_forces(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for g: Variant in raw:
			var v: Variant = (raw as Dictionary)[g]
			for sid: Variant in (v if v is Array else [v]):
				_add_force(out, StringName(g), StringName(sid))
	elif raw is Array:
		for e: Variant in raw:
			if e is Dictionary:
				_add_force(out, StringName((e as Dictionary).get("group", &"")), StringName((e as Dictionary).get("slot", &"")))
	return out


static func _add_force(out: Dictionary, group: StringName, slot_id: StringName) -> void:
	if group == &"" or slot_id == &"":
		return
	if not out.has(group):
		out[group] = []
	if not (out[group] as Array).has(slot_id):
		(out[group] as Array).append(slot_id)


## Asset ids in the result (modifier sources, drops, plan selections); first-seen order.
func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in result.get("modifier_sources", {}):
		if not out.has(StringName(id)):
			out.append(StringName(id))
	for d: Dictionary in result.get("drops", []):
		if not out.has(StringName(d["asset"])):
			out.append(StringName(d["asset"]))
	for s: Variant in (result.get("plan", {}) as Dictionary).get("selections", []):
		if s is Dictionary and not out.has(StringName((s as Dictionary).get("asset", &""))):
			out.append(StringName((s as Dictionary).get("asset", &"")))
	return out


func has_asset(id: StringName) -> bool:
	return asset_ids().has(id)


## group -> [slot_ids] the VariantResolver must pin active.
func forced_variants() -> Dictionary:
	return (result.get("force_variants", {}) as Dictionary).duplicate(true)


## One TEAM source per asset (the source name is the asset id, `asset.<id>`). Cleared by
## Modifiers.clear_all() at teardown.
func apply_modifiers() -> void:
	var mods: Dictionary = result.get("modifier_sources", {})
	for id: StringName in mods:
		var grants: Dictionary = mods[id]
		if not grants.is_empty():
			Modifiers.set_source(Modifiers.TEAM, source_name(id), grants)


## Modifier source / objective tag for an asset: `asset.<id>` (ids already starting with `asset.` are kept).
static func source_name(id: StringName) -> StringName:
	var s: String = String(id)
	return StringName(s if s.begins_with(SOURCE_PREFIX) else SOURCE_PREFIX + s)


## Spawn choice (&"" = default spawns).
func spawn_tag() -> StringName:
	return StringName(result.get("spawn_tag", &""))


## Escape choice (&"" = mission default).
func escape_tag() -> StringName:
	return StringName(result.get("escape_tag", &""))


## Variant groups revealed to the crew (insider info): the plan's, then the runtime reveals (QC-63).
func reveals() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: Variant in result.get("reveals", []):
		out.append(StringName(g))
	for g: StringName in runtime_reveals:
		if not out.has(g):
			out.append(g)
	return out


## QC-63: reveal variant group `group` now (intel note read). True the first time (signal group_revealed).
func reveal_group(group: StringName) -> bool:
	if group == &"" or reveals().has(group):
		return false
	runtime_reveals.append(group)
	group_revealed.emit(group)
	return true


## QC-63 (HeistNetSync): the runtime reveals as Strings.
func reveals_net_state() -> Array:
	var out: Array = []
	for g: StringName in runtime_reveals:
		out.append(String(g))
	return out


## QC-63 (client): adopt the server's runtime reveals (adds only; emits group_revealed for each new one).
func apply_reveals_net_state(groups: Array) -> void:
	for g: Variant in groups:
		reveal_group(StringName(g))


## Insider info: { group: resolved value } for every revealed group.
func revealed_variants(variants: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for g: StringName in reveals():
		if variants.has(g):
			out[g] = variants[g]
	return out


## Spending cash ENV B already charged: {slot: int} (results screen / replay; ENV A never charges).
func cash_spent() -> Dictionary:
	return result.get("cash_spent", {})


## Drops: spawn each at its PREPLAN_POINT under `parent` (server).
func spawn_drops(map: HeistMap, parent: Node3D) -> void:
	for d: Dictionary in result.get("drops", []):
		var pid: StringName = d["point"]
		var point: Node3D = find_point(map, pid)
		if point == null:
			Log.error(&"preplan", "drop '%s': no PREPLAN_POINT '%s' under <Map>/%s" % [d["asset"], pid, POINTS_NODE])
			continue
		if String(d["kind"]).begins_with(LOOT_PREFIX):  # D-068: a loot bag drop (asset.thermite_drop -> loot.thermite)
			var rt: HeistRuntime = HeistRuntime.of(parent)
			var mgr: LootManager = rt.service(G.SVC_LOOT) as LootManager if rt != null else null
			var bag: LootBag = mgr.spawn_bag(StringName(d["kind"]), point.global_transform) if mgr != null else null
			if bag != null:
				drops[pid] = bag
			continue
		var node: Node3D = _make_drop(d)
		if node == null:
			continue
		parent.add_child(node, true)
		node.global_transform = point.global_transform
		if node.has_method(&"configure_preplan"):
			node.call(&"configure_preplan", d["asset"], d)
		drops[pid] = node


## PREPLAN_POINT `point_id`: the node `<Map>/Preplan/<point_id>` (contract), else any node in group
## G.PREPLAN_POINT named `point_id` or with `asset_slot` metadata/property `point_id` (legacy).
static func find_point(map: HeistMap, point_id: StringName) -> Node3D:
	if map == null or point_id == &"":
		return null
	var holder: Node = map.get_node_or_null(POINTS_NODE)
	if holder != null:
		var direct: Node3D = holder.get_node_or_null(NodePath(String(point_id))) as Node3D
		if direct != null:
			return direct
	for n: Node in map.get_slots(G.PREPLAN_POINT):
		var n3: Node3D = n as Node3D
		if n3 == null:
			continue
		if StringName(n3.name) == point_id:
			return n3
		var prop: Variant = n3.get(&"asset_slot")
		if prop != null and StringName(prop) == point_id:
			return n3
		if n3.has_meta(&"asset_slot") and StringName(n3.get_meta(&"asset_slot")) == point_id:
			return n3
	return null


func _make_drop(d: Dictionary) -> Node3D:
	var id: StringName = d["asset"]
	var kind: StringName = d["kind"]
	var src: Variant = _drop_factories.get(kind, "")
	var node: Node3D = null
	if src is Callable:
		node = (src as Callable).call(id, d) as Node3D
	elif String(src) != "":
		node = _instantiate(String(src), id)
	else:
		node = _deployable_drop(kind)
		if node == null:
			var bare: String = String(kind).trim_prefix(DEPLOYABLE_PREFIX)
			var probe: String = "res://systems/prefabs/%s/%s.tscn" % [bare, bare]
			if bare != "" and ResourceLoader.exists(probe):
				node = _instantiate(probe, id)
	if node == null:
		var marker: PreplanDrop = PreplanDrop.new()
		marker.kind = kind
		marker.params = d["params"]
		node = marker
	node.name = "Asset_%s_%s" % [id, d["point"]]
	if &"asset_id" in node:
		node.set(&"asset_id", id)
	if &"objective_tag" in node and StringName(node.get(&"objective_tag")) == &"":
		node.set(&"objective_tag", source_name(id))
	return node


## `deployable.<x>` with a DeployableDef -> an unowned DeployablePrefab (PD2 pre-planned bags).
static func _deployable_drop(kind: StringName) -> Node3D:
	if not String(kind).begins_with(DEPLOYABLE_PREFIX):
		return null
	var def: DeployableDef = DeployableSystem.def_for(kind)
	if def == null:
		return null
	var p: DeployablePrefab = (load(DeployableSystem.SCENE) as PackedScene).instantiate() as DeployablePrefab
	p.setup(def, -1, maxi(def.uses, 1))
	return p


static func _instantiate(path: String, id: StringName) -> Node3D:
	var ps: PackedScene = load(path) as PackedScene
	var node: Node3D = ps.instantiate() as Node3D if ps != null else null
	if node == null:
		Log.error(&"preplan", "asset '%s': '%s' is not a Node3D scene" % [id, path])
	return node
