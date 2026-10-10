## One pre-planning asset (B2-01, pd2_fidelity C3; contract docs/contracts/preplanning.md v1.0, D-038).
## Owner: ENV B. Generic library: res://content/data/preplanning/assets/<name>.tres (id `asset.<name>`).
## A heist's `HeistDef.preplanning.assets[id]` entry overrides fields of the library entry, or adds a
## heist-only asset (PreplanBoard.merge). Resolution into a PreplanResult: PreplanPlan.apply().
##
## Fields follow the contract's AssetDef table. An asset may combine effects:
##   grants         {registry key: value} -> Modifiers.set_source(TEAM, &"asset.<id>", grants)
##   drop (+params) spawn kind placed at the chosen PREPLAN_POINT (&"deployable.ammo_bag")
##   spawn_tag      the crew spawns at PLAYER SpawnPoints with this tag
##   escape_tag     escape activation restricted to escapes with this objective_tag
##   force_variants {group: [slot ids]} forced active by the VariantResolver
##   reveals        variant groups shown on the HUD/blueprint (insider info)
## A located asset also takes the chosen point's params `spawn_tag`, `escape_tag` and
## `variant_group`+`variant_slot` (a forced variant) for each of those fields it leaves empty.
class_name PreplanAssetDef
extends Resource

## Keys an asset must never grant (D-038 QA-16: ECM feedback is built into every ECM).
const DEPRECATED_KEYS: Array[StringName] = [&"stealth.ecm_feedback"]

@export var id: StringName = &""
## UI grouping only: &"supply", &"intel", &"gear", &"entry", &"escape", &"access" (ours, not in the contract).
@export var category: StringName = &"supply"
## Spending cash at Routine; scaled by PreplanTweak.cost_mult[difficulty] (PD2: prices scale with difficulty).
@export var cost: int = 0
## Favors (team budget per heist day; does not scale with difficulty).
@export var favors: int = 0
## Copies of this asset one plan may hold (on different points; crew assets: 1).
@export var max_count: int = 1
## Location-limited: PREPLAN_POINT categories this asset may be placed on. Empty (and no
## point_ids) = crew asset with no map location.
@export var point_categories: Array[StringName] = []
## Restrict to these exact point ids; overrides point_categories.
@export var point_ids: Array[StringName] = []
## At most one asset of an exclusive group per plan (e.g. &"spawn"; ours, not in the contract).
@export var exclusive_group: StringName = &""
## Plans (PD2 "plans": vault method, escape): the crew votes, the host breaks ties (PlanVote).
## A vote group is also exclusive. Its cost is split among the human crew.
@export var vote_group: StringName = &""
## { registry key: value } (ModifierKeys only).
@export var grants: Dictionary = {}
## Spawn kind placed at the chosen point (&"deployable.ammo_bag").
@export var drop: StringName = &""
## Extra data for the dropped node (contract drops[].params).
@export var drop_params: Dictionary = {}
@export var spawn_tag: StringName = &""
@export var escape_tag: StringName = &""
## { variant group: [slot ids] }; empty = the chosen point's params variant_group/variant_slot.
@export var force_variants: Dictionary = {}
## Variant groups whose rolled slots the crew learns.
@export var reveals: Array[StringName] = []
## &"stealth" / &"loud": which play style the asset helps (UI hint only).
@export var tags: Array[StringName] = []


func is_located() -> bool:
	return not point_categories.is_empty() or not point_ids.is_empty()


func allows_point(point_id: StringName, point_category: StringName) -> bool:
	if not point_ids.is_empty():
		return point_ids.has(point_id)
	return point_categories.has(point_category)


## Does the asset do anything by itself (a located asset may get its effect from the point's params)?
func has_own_effect() -> bool:
	return not grants.is_empty() or drop != &"" or spawn_tag != &"" or escape_tag != &"" \
			or not force_variants.is_empty() or not reveals.is_empty()


## Copy with the fields of a `HeistDef.preplanning.assets[id]` entry applied. Keys are the AssetDef
## field names of the contract: cost, favors, max_count, point_categories, point_ids, vote_group,
## grants, drop (a spawn kind, or a bare deployable name), params (drop params), spawn_tag,
## escape_tag, force_variants ({group: [slots]} or {group: slot}), reveals; plus our UI fields
## category, tags, exclusive_group. Unknown keys go to `errors`.
func with_overrides(entry: Dictionary, errors: Array[String]) -> PreplanAssetDef:
	var a: PreplanAssetDef = duplicate(true) as PreplanAssetDef
	for k: Variant in entry:
		var v: Variant = entry[k]
		match String(k):
			"cost":
				a.cost = int(v)
			"favors":
				a.favors = int(v)
			"max_count":
				a.max_count = int(v)
			"point_categories":
				a.point_categories = _names(v)
			"point_ids":
				a.point_ids = _names(v)
			"exclusive_group":
				a.exclusive_group = StringName(String(v))
			"vote_group":
				a.vote_group = StringName(String(v))
			"grants":
				a.grants = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"drop":
				var item: String = String(v)
				a.drop = StringName(item if item.contains(".") or item == "" else "deployable." + item)
			"params":
				a.drop_params = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"spawn_tag":
				a.spawn_tag = StringName(String(v))
			"escape_tag":
				a.escape_tag = StringName(String(v))
			"force_variants":
				a.force_variants = _variant_map(v)
			"reveals":
				a.reveals = _names(v)
			"category":
				a.category = StringName(String(v))
			"tags":
				a.tags = _names(v)
			_:
				errors.append("%s: unknown preplanning field '%s'" % [id, k])
	return a


## Data problems (empty = valid): an effect present, grants registry-known, sane numbers.
func validate() -> Array[String]:
	var out: Array[String] = []
	if not String(id).begins_with("asset."):
		out.append("%s: id must start with 'asset.'" % id)
	if cost < 0 or favors < 0 or max_count < 1:
		out.append("%s: negative cost/favors or max_count < 1" % id)
	if not has_own_effect() and not is_located():
		out.append("%s: no effect (grants, drop, spawn_tag, escape_tag, force_variants, reveals) and no point" % id)
	for k: Variant in grants:
		var key: StringName = StringName(String(k))
		if not ModifierKeys.is_known(key):
			out.append("%s: unknown modifier key %s" % [id, k])
		elif DEPRECATED_KEYS.has(key):
			out.append("%s: grants deprecated key %s" % [id, k])
	if drop != &"" and not is_located():
		out.append("%s: a drop needs a point" % id)
	for g: Variant in force_variants:
		var slots: Variant = force_variants[g]
		if String(g) == "" or not slots is Array or (slots as Array).is_empty():
			out.append("%s: force_variants needs {group: [slot ids]}" % id)
	for g: StringName in reveals:
		if g == &"":
			out.append("%s: empty reveal group" % id)
	return out


static func _names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for x: Variant in v as Array:
			out.append(StringName(String(x)))
	elif v != null and String(v) != "":
		out.append(StringName(String(v)))
	return out


## {group: slot} or {group: [slots]} -> {StringName group: Array[StringName] slots}.
static func _variant_map(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for g: Variant in v as Dictionary:
			var slots: Array[StringName] = _names((v as Dictionary)[g])
			out[StringName(String(g))] = slots
	return out
