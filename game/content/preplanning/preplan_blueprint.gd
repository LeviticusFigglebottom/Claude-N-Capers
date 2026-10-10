## Top-down schematic of a heist for the pre-planning board (B2-01). Owner: ENV B.
## Data: res://content/data/preplanning/blueprints/<heist id>.tres, else
## res://content/data/preplanning/placeholder_blueprint.tres (`placeholder = true`, shown with a banner).
## Coordinates are world meters on the ground plane: Vector2(x, z) (+x east, +z south, as in the
## heist design docs), so a point's `pos` equals its PREPLAN_POINT marker's global (x, z).
class_name PreplanBlueprint
extends Resource

## Heist this blueprint draws (&"" for the generic placeholder).
@export var heist_id: StringName = &""
## True = not the real map: the UI shows a "placeholder blueprint" banner.
@export var placeholder: bool = false
## World rect shown (meters, x/z).
@export var bounds: Rect2 = Rect2(-20, -20, 40, 40)
## Grid line spacing (meters); every 5th line is drawn stronger.
@export var grid_step_m: float = 2.0
## Floor index -> strings key (`ui.preplan.floor.ground`); one entry = no floor switcher.
@export var floor_names: Array[StringName] = [&"ui.preplan.floor.ground"]
## Shapes: { "kind": StringName (PreplanTweak.shape_fill key), "rect": Rect2 (meters),
##   "floor": int (-1 = every floor, default), "label": StringName strings key or &"" }
@export var shapes: Array[Dictionary] = []
## Pre-planning points: { "id": StringName, "category": StringName, "pos": Vector2 (meters),
##   "floor": int, "label": StringName strings key, "params": Dictionary }
## params: {"spawn_tag": &"preplan_spawn_alley"} (PLAYER_SPAWN), {"variant_group", "variant_slot"} (FORCE_VARIANT).
@export var points: Array[Dictionary] = []


func point(point_id: StringName) -> Dictionary:
	for p: Dictionary in points:
		if StringName(p.get("id", &"")) == point_id:
			return p
	return {}


func point_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in points:
		out.append(StringName(p.get("id", &"")))
	return out


func category_of(point_id: StringName) -> StringName:
	return StringName(point(point_id).get("category", &""))


func floor_count() -> int:
	return maxi(floor_names.size(), 1)


## A blueprint whose points come from a heist map's PREPLAN_POINT nodes (group G.PREPLAN_POINT).
## Each node is a Node3D with metadata `preplan_category` (StringName), optional `preplan_label`,
## `preplan_floor` and `preplan_params`; the point id is the node name. Shapes/bounds come from
## `base` (the drawn schematic). Proposed for ENV C (see content/docs/preplanning.md, question QB-PP1).
static func from_nodes(nodes: Array[Node], base: PreplanBlueprint) -> PreplanBlueprint:
	var bp: PreplanBlueprint = base.duplicate(true) as PreplanBlueprint if base != null else PreplanBlueprint.new()
	bp.points = []
	for n: Node in nodes:
		var n3: Node3D = n as Node3D
		if n3 == null:
			continue
		var pos: Vector3 = n3.global_position if n3.is_inside_tree() else n3.position
		bp.points.append({
			"id": StringName(n3.name),
			"category": StringName(String(n3.get_meta(&"preplan_category", ""))),
			"pos": Vector2(pos.x, pos.z),
			"floor": int(n3.get_meta(&"preplan_floor", 0)),
			"label": StringName(String(n3.get_meta(&"preplan_label", ""))),
			"params": n3.get_meta(&"preplan_params", {}) as Dictionary,
		})
	return bp
