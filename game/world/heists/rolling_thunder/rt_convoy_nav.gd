## Rolling Thunder convoy nav guard (RT-C2, D-149.1). Owner: ENV C. Stopgap until ConvoyLayouts does it (ask: ENV A).
## The map holds one whole-map NavigationRegion3D per convoy layout (`NavConvoy`, authored disabled) beside the open
## road (`Navigation`, meta `convoy_open_nav`); ConvoyLayouts swaps them with `enabled`. Godot 4.7 still feeds a
## disabled region's edges to the map's edge merge, so the copies' identical edges collide ("More than 2 edges tried
## to occupy the same map rasterization space") and the enabled region loses connections (RT: 448 -> 408 of 576
## spawn-pair paths). This node keeps every disabled convoy region off the navigation map (region_set_map to an
## empty RID) and puts it back when enabled, checked each physics frame (a handful of regions), on every peer.
extends Node3D

var _regions: Array[NavigationRegion3D] = []
var _on: Dictionary = {}


func _ready() -> void:
	var map: Node = owner if owner != null else get_parent()
	for n: Node in map.find_children("*", "NavigationRegion3D", true, false):
		if n.has_meta(&"convoy_open_nav") or _in_layout(n):
			_regions.append(n as NavigationRegion3D)
	_sync()


func _physics_process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	for r: NavigationRegion3D in _regions:
		if not is_instance_valid(r) or not r.is_inside_tree():
			continue
		var on: bool = r.enabled
		if _on.get(r.get_instance_id(), not on) == on:
			continue
		_on[r.get_instance_id()] = on
		var nav_map: RID = r.get_navigation_map()
		if not nav_map.is_valid():
			nav_map = r.get_world_3d().navigation_map
		NavigationServer3D.region_set_map(r.get_rid(), nav_map if on else RID())


static func _in_layout(n: Node) -> bool:
	var cur: Node = n.get_parent()
	while cur != null:
		if cur.has_meta(&"convoy_layout"):
			return true
		cur = cur.get_parent()
	return false
