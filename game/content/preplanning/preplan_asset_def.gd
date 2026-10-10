## One pre-planning asset (B2-01, pd2_fidelity C3). Owner: ENV B.
## Generic set: res://content/data/preplanning/assets/<name>.tres (id `asset.<name>`). A heist's
## HeistDef.preplanning entry with the same id overrides fields, a new id adds a heist-only asset
## (PreplanCatalog.merge). Design + hand-off: content/docs/preplanning.md.
##
## Exactly one effect per asset:
##   MODIFIERS      `grants` (registry keys only) -> Modifiers.set_source(Modifiers.TEAM, &"asset.<id>", grants)
##   SPAWN          `spawn_item` (a deployable id) is placed at the chosen PREPLAN_POINT
##   REVEAL         `reveal_variant_group`: the crew learns which slots of that group rolled (insider info)
##   FORCE_VARIANT  forces a VariantSlot: `force_variant_group` + `force_variant_slot`, or the chosen
##                  point's params {"variant_group", "variant_slot"} (escape position, propped door)
##   PLAYER_SPAWN   the crew starts at the chosen point's params["spawn_tag"] SpawnPoints
class_name PreplanAssetDef
extends Resource

enum Effect { MODIFIERS, SPAWN, REVEAL, FORCE_VARIANT, PLAYER_SPAWN }

@export var id: StringName = &""
@export var effect: Effect = Effect.MODIFIERS
## UI grouping only: &"supply", &"intel", &"gear", &"entry", &"escape", &"access".
@export var category: StringName = &"supply"
## Spending cash at Routine; scaled by PreplanTweak.cost_mult[difficulty] (PD2: prices scale with difficulty).
@export var base_cost: int = 0
## Favors (team budget per heist day; does not scale with difficulty).
@export var favors: int = 0
## Location-limited: PREPLAN_POINT categories this asset may be placed on. Empty (and no
## point_ids) = crew asset with no map location.
@export var point_categories: Array[StringName] = []
## Restrict to these exact point ids (HeistDef.preplanning "slot"); overrides point_categories.
@export var point_ids: Array[StringName] = []
## Copies of this asset one plan may hold (on different points).
@export var max_count: int = 1
## At most one asset of an exclusive group per plan (e.g. &"player_spawn").
@export var exclusive_group: StringName = &""
## Plans (PD2 "plans": vault method, escape): the crew votes, the host breaks ties (PlanVote).
## A vote group is also exclusive.
@export var vote_group: StringName = &""
## MODIFIERS: { registry key: value }.
@export var grants: Dictionary = {}
## SPAWN: deployable id placed at the point (&"deployable.ammo_bag").
@export var spawn_item: StringName = &""
## REVEAL: VariantSlot group whose rolled slots are revealed.
@export var reveal_variant_group: StringName = &""
## FORCE_VARIANT: fixed group/slot; empty = taken from the chosen point's params.
@export var force_variant_group: StringName = &""
@export var force_variant_slot: StringName = &""
## &"stealth" / &"loud": which play style the asset helps (UI hint only).
@export var tags: Array[StringName] = []


func is_located() -> bool:
	return not point_categories.is_empty() or not point_ids.is_empty()


func allows_point(point_id: StringName, point_category: StringName) -> bool:
	if not point_ids.is_empty():
		return point_ids.has(point_id)
	return point_categories.has(point_category)


func effect_name() -> StringName:
	return StringName(String(Effect.keys()[effect]).to_lower())


static func effect_from_name(n: String) -> int:
	return Effect.keys().find(n.to_upper())


## Copy with the fields of a HeistDef.preplanning entry applied. Keys (all optional):
## cost, favors, slot (point id, or point category), point_categories, max_count, exclusive_group,
## vote_group, grants, spawn ("ammo_bag" or "deployable.ammo_bag"), reveal_variant_group,
## force_variant ({"group", "slot"}), effect ("modifiers"/"spawn"/...), category, tags.
## `point_ids_known` tells "slot" ids apart from categories. Unknown keys go to `errors`.
func with_overrides(entry: Dictionary, point_ids_known: Array[StringName], errors: Array[String]) -> PreplanAssetDef:
	var a: PreplanAssetDef = duplicate(true) as PreplanAssetDef
	for k: Variant in entry:
		var v: Variant = entry[k]
		match String(k):
			"cost":
				a.base_cost = int(v)
			"favors":
				a.favors = int(v)
			"slot":
				var s: StringName = StringName(String(v))
				if point_ids_known.has(s):
					a.point_ids = _names([s])
				else:
					a.point_ids = _names([])
					a.point_categories = _names([s])
			"point_categories":
				a.point_categories = _names(v)
			"max_count":
				a.max_count = int(v)
			"exclusive_group":
				a.exclusive_group = StringName(String(v))
			"vote_group":
				a.vote_group = StringName(String(v))
			"grants":
				a.grants = (v as Dictionary).duplicate(true)
				a.effect = Effect.MODIFIERS
			"spawn":
				var item: String = String(v)
				a.spawn_item = StringName(item if item.contains(".") else "deployable." + item)
				a.effect = Effect.SPAWN
			"reveal_variant_group":
				a.reveal_variant_group = StringName(String(v))
				a.effect = Effect.REVEAL
			"force_variant":
				var fv: Dictionary = v as Dictionary
				a.force_variant_group = StringName(String(fv.get("group", "")))
				a.force_variant_slot = StringName(String(fv.get("slot", "")))
				a.effect = Effect.FORCE_VARIANT
			"effect":
				var e: int = effect_from_name(String(v))
				if e < 0:
					errors.append("%s: unknown effect '%s'" % [id, v])
				else:
					a.effect = e as Effect
			"category":
				a.category = StringName(String(v))
			"tags":
				a.tags = _names(v)
			_:
				errors.append("%s: unknown preplanning field '%s'" % [id, k])
	return a


## Data problems (empty = valid): effect payload present, grants registry-known, sane numbers.
func validate() -> Array[String]:
	var out: Array[String] = []
	if not String(id).begins_with("asset."):
		out.append("%s: id must start with 'asset.'" % id)
	if base_cost < 0 or favors < 0 or max_count < 1:
		out.append("%s: negative cost/favors or max_count < 1" % id)
	match effect:
		Effect.MODIFIERS:
			if grants.is_empty():
				out.append("%s: MODIFIERS asset without grants" % id)
			for k: Variant in grants:
				if not ModifierKeys.is_known(StringName(String(k))):
					out.append("%s: unknown modifier key %s" % [id, k])
		Effect.SPAWN:
			if spawn_item == &"":
				out.append("%s: SPAWN asset without spawn_item" % id)
			if not is_located():
				out.append("%s: SPAWN asset needs a point" % id)
		Effect.REVEAL:
			if reveal_variant_group == &"":
				out.append("%s: REVEAL asset without reveal_variant_group" % id)
		Effect.FORCE_VARIANT:
			if force_variant_slot == &"" and not is_located():
				out.append("%s: FORCE_VARIANT needs force_variant_slot or a point" % id)
		Effect.PLAYER_SPAWN:
			if not is_located():
				out.append("%s: PLAYER_SPAWN asset needs a point" % id)
	return out


static func _names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for x: Variant in v as Array:
			out.append(StringName(String(x)))
	elif v != null:
		out.append(StringName(String(v)))
	return out
