## C3 pre-planning asset hooks: turns the chosen assets into gameplay at launch. Owner: ENV A (A2-07).
## Shapes and examples: game/systems/heist/README.md. HeistRuntime owns one instance (`rt.preplan`).
##
## Asset definition (HeistDef.preplanning[id], optionally overridden per launch):
##   { "cost": int, "favors": int, "type": StringName (informational: &"modifier", &"drop", &"spawn",
##     &"escape", &"variant", &"insider"),
##     "grants": {modifier_key: value}          -> Modifiers.set_source(TEAM, &"asset.<id>", grants)
##     "slot": StringName + "drop": StringName  -> spawn the drop at the PREPLAN_POINT named `slot`
##       (optional "scene": String path, "params": Dictionary)
##     "spawn_tag": StringName                  -> crew spawns at PLAYER SpawnPoints carrying that tag
##     "escape_tag": StringName                 -> HeistMission.activate_escape() defaults to that tag
##     "force_variants": {group: [slot_ids]}    -> pinned active by the VariantResolver
##     "reveals": [groups]                      -> revealed_variants() exposes those resolved groups }
## Effects are applied independently, so one asset may combine several keys.
## Launch option `options["preplanning"]`: Array of asset ids (looked up in HeistDef.preplanning) or
## a Dictionary { id: true | Dictionary } (a Dictionary value is merged over the catalog entry, or is
## the whole definition when the heist has no entry for it).
class_name PreplanAssets
extends RefCounted

const OPTION_KEY: String = "preplanning"
const SOURCE_PREFIX: String = "asset."
## Fallback drop nodes join this group.
const DROP_GROUP: StringName = &"preplan_drop"

## Drop kind -> scene path or Callable(asset_id, def) -> Node3D. Systems that own a drop prefab
## (e.g. the deployables) register here; unregistered kinds probe res://systems/prefabs/<kind>/<kind>.tscn
## and fall back to a PreplanDrop marker node.
static var _drop_factories: Dictionary = {}

## Chosen assets: id (StringName) -> definition Dictionary. Ids in String order.
var chosen: Dictionary = {}
## Nodes spawned for drop assets: id -> Node3D.
var drops: Dictionary = {}


## Register how a drop kind is spawned (scene path String or Callable(asset_id, def) -> Node3D).
static func register_drop(kind: StringName, scene_or_factory: Variant) -> void:
	_drop_factories[kind] = scene_or_factory


static func unregister_drop(kind: StringName) -> void:
	_drop_factories.erase(kind)


## Resolve the launch option against the heist's catalog.
func setup(options: Dictionary, def: HeistDef) -> void:
	chosen.clear()
	var catalog: Dictionary = def.preplanning if def != null else {}
	var raw: Variant = options.get(OPTION_KEY, [])
	var picks: Dictionary = {}
	if raw is Array:
		for id: Variant in raw:
			picks[StringName(id)] = true
	elif raw is Dictionary:
		for id: Variant in raw:
			picks[StringName(id)] = (raw as Dictionary)[id]
	var ids: Array = picks.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var entry: Dictionary = _catalog_entry(catalog, id)
		var over: Variant = picks[id]
		if over is Dictionary:
			entry.merge(over as Dictionary, true)
		elif entry.is_empty():
			Log.warn(&"preplan", "asset '%s' is not in the heist's preplanning catalog; ignored" % id)
			continue
		chosen[id] = entry
	if not chosen.is_empty():
		Log.info(&"preplan", "assets %s" % [chosen.keys()])


func has_asset(id: StringName) -> bool:
	return chosen.has(id)


## group -> [slot_ids] the VariantResolver must pin active.
func forced_variants() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in chosen:
		var fv: Dictionary = (chosen[id] as Dictionary).get("force_variants", {})
		for g: Variant in fv:
			var group: StringName = StringName(g)
			if not out.has(group):
				out[group] = []
			var v: Variant = fv[g]
			for sid: Variant in (v if v is Array else [v]):
				(out[group] as Array).append(StringName(sid))
	return out


## Modifier assets: one TEAM source per asset (`asset.<id>`). Cleared by Modifiers.clear_all() at teardown.
func apply_modifiers() -> void:
	for id: StringName in chosen:
		var grants: Dictionary = (chosen[id] as Dictionary).get("grants", {})
		if not grants.is_empty():
			Modifiers.set_source(Modifiers.TEAM, source_name(id), grants)


## Modifier source / objective tag for an asset: `asset.<id>` (ids already starting with `asset.` are kept).
static func source_name(id: StringName) -> StringName:
	var s: String = String(id)
	return StringName(s if s.begins_with(SOURCE_PREFIX) else SOURCE_PREFIX + s)


## Spawn-location choice: the first chosen asset's `spawn_tag` (&"" = defaults).
func spawn_tag() -> StringName:
	return _first_key("spawn_tag")


## Escape choice: the first chosen asset's `escape_tag` (&"" = mission default).
func escape_tag() -> StringName:
	return _first_key("escape_tag")


## Insider info: { group: resolved value } for every group named by a chosen asset's `reveals`.
func revealed_variants(variants: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in chosen:
		for g: Variant in (chosen[id] as Dictionary).get("reveals", []):
			if variants.has(StringName(g)):
				out[StringName(g)] = variants[StringName(g)]
	return out


## Drop assets: spawn each at its PREPLAN_POINT under `parent`.
func spawn_drops(map: HeistMap, parent: Node3D) -> void:
	for id: StringName in chosen:
		var def: Dictionary = chosen[id]
		var slot: StringName = StringName(def.get("slot", &""))
		if slot == &"" or not (def.has("drop") or def.has("scene")):
			continue
		var point: Node3D = find_point(map, slot)
		if point == null:
			Log.error(&"preplan", "asset '%s': no PREPLAN_POINT matches slot '%s'" % [id, slot])
			continue
		var node: Node3D = _make_drop(id, def)
		if node == null:
			continue
		parent.add_child(node, true)
		node.global_transform = point.global_transform
		if node.has_method(&"configure_preplan"):
			node.call(&"configure_preplan", id, def)
		drops[id] = node


## PREPLAN_POINT in `map` whose `asset_slot` property, `asset_slot` metadata or node name equals `slot`.
static func find_point(map: HeistMap, slot: StringName) -> Node3D:
	if map == null:
		return null
	for n: Node in map.get_slots(G.PREPLAN_POINT):
		var n3: Node3D = n as Node3D
		if n3 == null:
			continue
		var prop: Variant = n3.get(&"asset_slot")
		if prop != null and StringName(prop) == slot:
			return n3
		if n3.has_meta(&"asset_slot") and StringName(n3.get_meta(&"asset_slot")) == slot:
			return n3
		if StringName(n3.name) == slot:
			return n3
	return null


func _make_drop(id: StringName, def: Dictionary) -> Node3D:
	var kind: StringName = StringName(def.get("drop", &""))
	var src: Variant = def.get("scene", _drop_factories.get(kind, ""))
	var node: Node3D = null
	if src is Callable:
		node = (src as Callable).call(id, def) as Node3D
	else:
		var path: String = String(src)
		if path == "" and kind != &"":
			var probe: String = "res://systems/prefabs/%s/%s.tscn" % [kind, kind]
			if ResourceLoader.exists(probe):
				path = probe
		if path != "":
			var ps: PackedScene = load(path) as PackedScene
			node = ps.instantiate() as Node3D if ps != null else null
			if node == null:
				Log.error(&"preplan", "asset '%s': '%s' is not a Node3D scene" % [id, path])
				return null
	if node == null:
		var marker: PreplanDrop = PreplanDrop.new()
		marker.kind = kind
		marker.params = def.get("params", {})
		node = marker
	node.name = "Asset_%s" % id
	if &"asset_id" in node:
		node.set(&"asset_id", id)
	if &"objective_tag" in node and StringName(node.get(&"objective_tag")) == &"":
		node.set(&"objective_tag", source_name(id))
	return node


func _first_key(key: String) -> StringName:
	for id: StringName in chosen:
		var v: StringName = StringName((chosen[id] as Dictionary).get(key, &""))
		if v != &"":
			return v
	return &""


func _catalog_entry(catalog: Dictionary, id: StringName) -> Dictionary:
	for k: Variant in [id, String(id)]:
		if catalog.has(k) and catalog[k] is Dictionary:
			return (catalog[k] as Dictionary).duplicate(true)
	return {}
