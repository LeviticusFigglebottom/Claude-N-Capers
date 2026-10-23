## D-084: one watcher per SceneTree that subscribes the CrowdLod switch to the local player's zoom. Owner: ENV D.
## Every CrowdLod proxy (crowd_lod_proxy.gd) calls `ensure(tree)` on entering the tree; the watcher looks up
## `CrewView.local_view()` (ENV P) and connects `zoom_factor_changed(f)` -> `CrowdLod.apply_zoom_all(tree, f)`.
## Re-checked whenever a CrewView enters the tree (local player spawn) and after the connected view leaves.
## Defensive: no CrewView class, no `local_view` method or no `zoom_factor_changed` signal = no-op (zoom 1.0).
extends Node

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const NODE_NAME: String = "CrowdLodZoom"
const VIEW_CLASS: StringName = &"CrewView"
## Root meta holding the watcher while its deferred add is pending (proxies entering in the same frame share it).
const PENDING_META: StringName = &"_crowd_lod_zoom_pending"

var _view: Object = null
var _view_script: Script = null
var _zoom: float = 1.0


## The watcher for `tree`, created on first use (deferred add to the root).
static func ensure(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	var w: Node = tree.root.get_node_or_null(NodePath(NODE_NAME))
	if w != null:
		return w
	if tree.root.has_meta(PENDING_META):
		var pending: Object = tree.root.get_meta(PENDING_META)
		if is_instance_valid(pending):
			return pending as Node
	var script: GDScript = load("res://world/characters/_tools/crowd_lod_zoom.gd") as GDScript
	w = script.new() as Node
	w.name = NODE_NAME
	tree.root.set_meta(PENDING_META, w)
	tree.root.add_child.call_deferred(w)
	return w


## The CrewView script, or null when the class is not in the project (yet).
static func view_script() -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(c.get("class", "")) == VIEW_CLASS:
			return load(String(c.get("path", ""))) as Script
	return null


func _ready() -> void:
	if get_tree().root.has_meta(PENDING_META):
		get_tree().root.remove_meta(PENDING_META)
	_view_script = view_script()
	get_tree().node_added.connect(_on_node_added)
	recheck()


func current_zoom() -> float:
	return _zoom


func is_subscribed() -> bool:
	return _view != null and is_instance_valid(_view)


## Look up the local view and subscribe; safe to call any time.
func recheck() -> void:
	if is_subscribed() or _view_script == null:
		return
	if not (_view_script as Object).has_method(&"local_view"):
		var found: bool = false
		for m: Dictionary in _view_script.get_script_method_list():
			if StringName(m.get("name", "")) == &"local_view":
				found = true
		if not found:
			return
	var v: Object = (_view_script as Object).call(&"local_view")
	if v == null or not is_instance_valid(v) or not v.has_signal(&"zoom_factor_changed"):
		return
	subscribe(v)


## Connect to `view` (also used by tests with a stand-in view).
func subscribe(view: Object) -> void:
	_view = view
	view.connect(&"zoom_factor_changed", _on_zoom)
	if view is Node:
		(view as Node).tree_exiting.connect(_on_view_gone, CONNECT_ONE_SHOT)
	_on_zoom(CrowdLod.zoom_factor_of(view))


func _on_zoom(f: float) -> void:
	_zoom = maxf(1.0, f)
	CrowdLod.apply_zoom_all(get_tree(), _zoom)


func _on_view_gone() -> void:
	_view = null
	_on_zoom(1.0)
	recheck.call_deferred()


func _on_node_added(n: Node) -> void:
	if is_subscribed():
		if n.is_in_group(CrowdLod.GROUP) and n is MeshInstance3D:
			CrowdLod.apply_zoom(n, _zoom)
		return
	if _view_script != null and n.get_script() == _view_script:
		recheck.call_deferred()
