## A heist map's render-budget policy (D-146, architecture §10: main pass <= 2,500 and <= 4,000 draws per view with
## the shadow passes). Owner: ENV C. Applied once when the map enters the tree (deferred, so procedural props exist),
## to the GeometryInstance3D nodes under `roots` (and, when smaller than `small_max` m, under `small_roots`) whose AABB
## centre lies in an interior RoomVolume (purpose not in `open_purposes`):
## - outside `cast_keep_rooms` they cast no shadows. Indoors only the sun (through the glazing) and the kept rooms'
##   shadowed lights would draw them; the shell, exterior doors and finishes keep casting: no light leaks in;
## - a door under `door_roots` (its direct children) with an interior room on both sides (probes 0.6 m along its local
##   z, 1.2 m up) casts no shadow when neither room is in `cast_keep_rooms` (an exterior door keeps casting: the sun);
## - outside `range_keep_rooms` a visibility range above `range_cap` m is cut to it (margin 10 %): dressing seen from
##   another room is behind its walls (levelcheck counts it: no occlusion).
## Deterministic (tree order, no RNG); off in the editor. levelcheck `perf` sees the result (it runs after this).
class_name RenderBudgetPolicy
extends Node

@export var roots: PackedStringArray = PackedStringArray()
@export var small_roots: PackedStringArray = PackedStringArray()
@export var small_max: float = 1.5
@export var door_roots: PackedStringArray = PackedStringArray()
@export var cast_keep_rooms: PackedStringArray = PackedStringArray()
@export var range_keep_rooms: PackedStringArray = PackedStringArray()
@export var range_cap: float = 0.0
@export var open_purposes: PackedStringArray = PackedStringArray(["exterior"])

var applied_cast: int = 0
var applied_range: int = 0
var applied_doors: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	apply.call_deferred()


## [[room_id, world AABB]] of the interior rooms.
func _rooms(map: Node) -> Array:
	var out: Array = []
	var holder: Node = map.get_node_or_null("Rooms")
	if holder == null:
		return out
	for n: Node in holder.get_children():
		var rv: RoomVolume = n as RoomVolume
		if rv == null or String(rv.purpose) in open_purposes:
			continue
		var cs: CollisionShape3D = rv.get_node_or_null("Shape") as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		out.append([String(rv.room_id), cs.global_transform * AABB(-sz * 0.5, sz)])
	return out


func apply() -> void:
	var map: Node = owner if owner != null else get_parent()
	if map == null:
		return
	var rooms: Array = _rooms(map)
	_doors(map, rooms)
	for pass_i: int in range(2):
		var list: PackedStringArray = roots if pass_i == 0 else small_roots
		for p: String in list:
			var root: Node = map.get_node_or_null(p)
			if root == null:
				continue
			for g: Node in root.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = g
				var box: AABB = gi.global_transform * gi.get_aabb()
				if pass_i == 1 and box.get_longest_axis_size() >= small_max:
					continue
				var rid: String = _room_of(rooms, box.get_center())
				if rid == "":
					continue
				if not (rid in cast_keep_rooms) and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					applied_cast += 1
				if range_cap > 0.0 and not (rid in range_keep_rooms) and gi.visibility_range_end > range_cap:
					gi.visibility_range_end = range_cap
					gi.visibility_range_end_margin = minf(gi.visibility_range_end_margin, range_cap * 0.1)
					applied_range += 1


func _doors(map: Node, rooms: Array) -> void:
	for p: String in door_roots:
		var root: Node = map.get_node_or_null(p)
		if root == null:
			continue
		for d: Node in root.get_children():
			var door: Node3D = d as Node3D
			if door == null:
				continue
			var xf: Transform3D = door.global_transform
			var up: Vector3 = Vector3.UP * 1.2
			var a: String = _room_of(rooms, xf.origin + up + xf.basis.z.normalized() * 0.6)
			var b: String = _room_of(rooms, xf.origin + up - xf.basis.z.normalized() * 0.6)
			if a == "" or b == "" or a in cast_keep_rooms or b in cast_keep_rooms:
				continue
			for g: Node in door.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = g
				if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					applied_doors += 1


static func _room_of(rooms: Array, p: Vector3) -> String:
	for r: Array in rooms:
		if (r[1] as AABB).has_point(p):
			return r[0]
	return ""
