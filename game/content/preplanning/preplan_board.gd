## The pre-planning board of one heist at one difficulty (B2-01, C3; contract preplanning.md v1.0):
## merged asset set, favors budget, blueprint and scaled costs. Owner: ENV B. Pure data, no nodes.
##
##   var board: PreplanBoard = PreplanBoard.build(&"glasshouse", Enums.Difficulty.BRUTAL)
##   board.cost_of(&"asset.ammo_bag_drop")   # spending cash at Brutal
##   board.assets_for_point(&"pp_alley_dumpsters")
##
## Merge (PreplanBoard.merge): the generic library (data/preplanning/assets/) + HeistDef.preplanning:
##   { "favors": int,                         # favors budget (default PreplanTweak.default_favors)
##     "disable": [asset ids],                # library assets this heist does not offer
##     "assets": { asset_id: {overrides} } }  # AssetDef field overrides; a new id adds a heist-only asset
## Points: the map's `<Map>/Preplan` Marker3Ds (PreplanBlueprint.from_map_scene), else the drawn
## blueprint's points (blueprints/<id>.tres, else the placeholder).
class_name PreplanBoard
extends RefCounted

const ASSET_DIR: String = "res://content/data/preplanning/assets"
const BLUEPRINT_DIR: String = "res://content/data/preplanning/blueprints"
const PLACEHOLDER_BLUEPRINT_PATH: String = "res://content/data/preplanning/placeholder_blueprint.tres"

## Top-level keys of HeistDef.preplanning (contract v1.0).
const PREPLANNING_KEYS: Array[String] = ["favors", "disable", "assets"]

static var _generic_cache: Dictionary = {}
## heist id -> PreplanBlueprint read from the map (or null = no points); maps are big, read once.
static var _map_cache: Dictionary = {}

var heist_id: StringName = &""
var difficulty: int = 0
var favors_budget: int = 10
## asset id -> PreplanAssetDef (merged)
var assets: Dictionary = {}
var blueprint: PreplanBlueprint
var tweak: PreplanTweak
## Data problems found while merging (logged once by build()).
var errors: Array[String] = []


static func build(p_heist_id: StringName, p_difficulty: int, def: HeistDef = null,
		p_tweak: PreplanTweak = null, p_blueprint: PreplanBlueprint = null) -> PreplanBoard:
	var b: PreplanBoard = PreplanBoard.new()
	b.heist_id = p_heist_id
	b.difficulty = p_difficulty
	b.tweak = p_tweak if p_tweak != null else PreplanTweak.load_default()
	if def == null and p_heist_id != &"":
		def = HeistRegistry.get_def(p_heist_id)
	b.blueprint = p_blueprint if p_blueprint != null else blueprint_for(p_heist_id, def)
	var pre: Dictionary = def.preplanning if def != null else {}
	if is_legacy_format(pre):
		Log.warn(&"preplan", "%s: HeistDef.preplanning is not in the contract v1.0 format {favors, disable, assets}; ignored" % p_heist_id)
		pre = {}
	var merged: Dictionary = merge(generic_assets(), pre, b.errors)
	b.assets = merged["assets"]
	b.favors_budget = int(merged.get("favors", b.tweak.default_favors))
	for id: StringName in b.asset_ids():
		b.errors.append_array((b.assets[id] as PreplanAssetDef).validate())
	for e: String in b.errors:
		Log.error(&"preplan", e)
	return b


## Generic asset set: id -> PreplanAssetDef (cached; tests may clear_cache()).
static func generic_assets() -> Dictionary:
	if _generic_cache.is_empty():
		for f: String in ResourceLoader.list_directory(ASSET_DIR):
			if not f.ends_with(".tres"):
				continue
			var a: PreplanAssetDef = load(ASSET_DIR.path_join(f)) as PreplanAssetDef
			if a != null and a.id != &"":
				_generic_cache[a.id] = a
	return _generic_cache


static func clear_cache() -> void:
	_generic_cache.clear()
	_map_cache.clear()


## The blueprint a heist's board uses: the drawn schematic (blueprints/<id>.tres, else the
## placeholder) with its points replaced by the map's PREPLAN_POINTs when the map has any.
static func blueprint_for(p_heist_id: StringName, def: HeistDef = null) -> PreplanBlueprint:
	var base: PreplanBlueprint = drawn_blueprint(p_heist_id)
	if p_heist_id == &"":
		return base
	var from_map: PreplanBlueprint = map_blueprint(p_heist_id, base, def)
	return from_map if from_map != null else base


## The drawn schematic: blueprints/<id>.tres, else the placeholder.
static func drawn_blueprint(p_heist_id: StringName) -> PreplanBlueprint:
	var p: String = "%s/%s.tres" % [BLUEPRINT_DIR, p_heist_id]
	if p_heist_id != &"" and ResourceLoader.exists(p):
		var bp: PreplanBlueprint = load(p) as PreplanBlueprint
		if bp != null:
			return bp
	var ph: PreplanBlueprint = load(PLACEHOLDER_BLUEPRINT_PATH) as PreplanBlueprint
	return ph if ph != null else PreplanBlueprint.new()


## Points from the heist map (`HeistRegistry.map_scene_path`, or `def.map_scene`), cached per heist;
## null when the map is missing or has no `Preplan` points.
static func map_blueprint(p_heist_id: StringName, base: PreplanBlueprint, def: HeistDef = null) -> PreplanBlueprint:
	if not _map_cache.has(p_heist_id):
		var path: String = def.map_scene if def != null and def.map_scene != "" else HeistRegistry.map_scene_path(p_heist_id)
		_map_cache[p_heist_id] = PreplanBlueprint.from_map_scene(path, base)
	return _map_cache[p_heist_id] as PreplanBlueprint


## True for a non-empty HeistDef.preplanning that has none of the contract's top-level keys
## (the pre-D-038 `{asset_id: {...}}` shape).
static func is_legacy_format(preplanning: Dictionary) -> bool:
	if preplanning.is_empty():
		return false
	for k: Variant in preplanning:
		if PREPLANNING_KEYS.has(String(k)):
			return false
	return true


## Pure merge: returns {"assets": {id: PreplanAssetDef}, "favors": int (only when the heist sets it)}.
static func merge(generic: Dictionary, preplanning: Dictionary, errors: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in generic:
		out[StringName(id)] = generic[id]
	var res: Dictionary = {"assets": out}
	for k: Variant in preplanning:
		var key: String = String(k)
		var v: Variant = preplanning[k]
		if key == "favors":
			res["favors"] = int(v)
		elif key == "disable":
			for d: Variant in v as Array if v is Array else []:
				out.erase(StringName(String(d)))
		elif key == "assets":
			if not v is Dictionary:
				errors.append("preplanning.assets must be a Dictionary")
				continue
			for ak: Variant in v as Dictionary:
				var id: StringName = StringName(String(ak))
				var entry: Variant = (v as Dictionary)[ak]
				if not String(id).begins_with("asset."):
					errors.append("preplanning.assets: id '%s' must start with 'asset.'" % id)
				elif not entry is Dictionary:
					errors.append("%s: preplanning entry must be a Dictionary" % id)
				else:
					var base: PreplanAssetDef = out.get(id) as PreplanAssetDef
					if base == null:
						base = PreplanAssetDef.new()
						base.id = id
					out[id] = base.with_overrides(entry as Dictionary, errors)
		else:
			errors.append("preplanning: unknown key '%s' (contract: favors, disable, assets)" % key)
	return res


## Asset ids sorted by category (PreplanTweak.category_order), then id text.
func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in assets:
		out.append(StringName(id))
	ContentDB.sort_ids(out)
	var order: Array[StringName] = tweak.category_order if tweak != null else ([] as Array[StringName])
	var rank: Callable = func(id: StringName) -> int:
		var c: int = order.find((assets[id] as PreplanAssetDef).category)
		return c if c >= 0 else order.size()
	var sorted: Array[StringName] = []
	for r: int in range(order.size() + 1):
		for id: StringName in out:
			if rank.call(id) == r:
				sorted.append(id)
	return sorted


func asset(id: StringName) -> PreplanAssetDef:
	return assets.get(id) as PreplanAssetDef


## Spending cash for one copy at this board's difficulty.
func cost_of(id: StringName) -> int:
	var a: PreplanAssetDef = asset(id)
	return tweak.scaled_cost(a.cost, difficulty) if a != null else 0


func favors_of(id: StringName) -> int:
	var a: PreplanAssetDef = asset(id)
	return a.favors if a != null else 0


## Assets that may be placed on a point (sorted like asset_ids()).
func assets_for_point(point_id: StringName) -> Array[StringName]:
	var cat: StringName = blueprint.category_of(point_id)
	var out: Array[StringName] = []
	for id: StringName in asset_ids():
		var a: PreplanAssetDef = asset(id)
		if a.is_located() and a.allows_point(point_id, cat):
			out.append(id)
	return out


## Assets with no map location (bought for the crew).
func crew_assets() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in asset_ids():
		if not asset(id).is_located():
			out.append(id)
	return out


## Points that offer at least one asset.
func active_point_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for pid: StringName in blueprint.point_ids():
		if not assets_for_point(pid).is_empty():
			out.append(pid)
	return out
