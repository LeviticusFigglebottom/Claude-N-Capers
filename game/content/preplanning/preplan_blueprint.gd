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


## A blueprint whose points come from PREPLAN_POINT nodes (contract preplanning.md / heist_map.md
## v1.2): Marker3Ds under `<Map>/Preplan`; the node name is the point id; metadata `category`
## (StringName), `label` (strings key), `floor` (int), `params` (Dictionary). Shapes come from `base`
## (the drawn schematic); its bounds grow to include every point. Works on nodes outside the tree
## (positions are taken relative to the topmost ancestor).
static func from_nodes(nodes: Array[Node], base: PreplanBlueprint) -> PreplanBlueprint:
	var bp: PreplanBlueprint = base.duplicate(true) as PreplanBlueprint if base != null else PreplanBlueprint.new()
	bp.points = []
	for n: Node in nodes:
		var n3: Node3D = n as Node3D
		if n3 == null:
			continue
		var pos: Vector3 = n3.global_position if n3.is_inside_tree() else _root_relative(n3)
		var p2: Vector2 = Vector2(pos.x, pos.z)
		bp.points.append({
			"id": StringName(n3.name),
			"category": StringName(String(n3.get_meta(&"category", ""))),
			"pos": p2,
			"floor": int(n3.get_meta(&"floor", 0)),
			"label": StringName(String(n3.get_meta(&"label", ""))),
			"params": (n3.get_meta(&"params", {}) as Dictionary).duplicate(true),
		})
		var margin: float = bp.grid_step_m
		bp.bounds = bp.bounds.expand(p2 - Vector2(margin, margin)).expand(p2 + Vector2(margin, margin))
	return bp


## PREPLAN_POINT nodes of an instanced (not necessarily in-tree) map: the Marker3D children of its
## `Preplan` node, in child order.
static func map_points(map_root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var holder: Node = map_root.get_node_or_null(^"Preplan") if map_root != null else null
	if holder == null:
		return out
	for c: Node in holder.get_children():
		if c is Marker3D:
			out.append(c)
	return out


## Points read from a map scene: instanced WITHOUT adding it to the tree, then freed. Returns null
## when the scene is missing or has no `Preplan` points (callers fall back to the placeholder).
static func from_map_scene(scene_path: String, base: PreplanBlueprint) -> PreplanBlueprint:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return null
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return null
	var root: Node = ps.instantiate()
	if root == null:
		return null
	var nodes: Array[Node] = map_points(root)
	var bp: PreplanBlueprint = from_nodes(nodes, base) if not nodes.is_empty() else null
	root.free()
	return bp


static func _root_relative(n: Node3D) -> Vector3:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t.origin
