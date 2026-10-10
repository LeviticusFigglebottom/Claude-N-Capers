## lights (final): every Light3D has a visible fixture (parented to / within 0.3 m of geometry
## in group `fixture` or meta fixture=true), except DirectionalLight3D (sun/moon, max 1) and
## fill lights (meta fill=true: energy <= 0.3, no shadows, <= 2 per room);
## <= 8 shadow-casting lights per room (level_standards §3.7, §5).
class_name LcCheckLights
extends LcCheck

const FIXTURE_DIST: float = 0.3
const MAX_SHADOW_PER_ROOM: int = 8
const MAX_FILL_PER_ROOM: int = 2
const MAX_FILL_ENERGY: float = 0.3


func _init() -> void:
	id = &"lights"
	title = "Lighting is deliberate"
	stages = PackedStringArray(["final"])


static func is_fixture(n: Node) -> bool:
	return n.is_in_group(&"fixture") or LcUtil.meta_b(n, &"fixture")


func run(ctx: LcContext) -> void:
	var fixtures: Array[Dictionary] = []
	for n: Node in ctx.map.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		if not gi.is_visible_in_tree() or not ctx.is_active(gi):
			continue
		var cur: Node = gi
		var fx: bool = false
		while cur != null and cur != ctx.map:
			if is_fixture(cur):
				fx = true
				break
			cur = cur.get_parent()
		if fx:
			fixtures.append({"node": gi, "aabb": gi.global_transform * gi.get_aabb()})
	var suns: int = 0
	var shadow_count: Dictionary = {}
	var fill_count: Dictionary = {}
	var lights: int = 0
	for n2: Node in ctx.map.find_children("*", "Light3D", true, false):
		var l: Light3D = n2
		if not l.is_visible_in_tree() or not ctx.is_active(l):
			continue
		lights += 1
		if l is DirectionalLight3D:
			suns += 1
			continue
		var room: RoomVolume = ctx.room_at(l.global_position)
		var rk: Node = room if room != null else ctx.map
		if LcUtil.meta_b(l, &"fill"):
			fill_count[rk] = int(fill_count.get(rk, 0)) + 1
			if l.light_energy > MAX_FILL_ENERGY:
				fail(ctx, l, null, "fill light energy %.2f > %.1f" % [l.light_energy, MAX_FILL_ENERGY])
			if l.shadow_enabled:
				fail(ctx, l, null, "fill light casts shadows (must be off)")
			continue
		if l.shadow_enabled:
			shadow_count[rk] = int(shadow_count.get(rk, 0)) + 1
		if not _has_fixture(ctx, l, fixtures):
			fail(ctx, l, null, "light has no fixture (parent it to, or place within %.1f m of, a mesh in group `fixture`)"
				% FIXTURE_DIST)
	if suns > 1:
		fail(ctx, ctx.map, null, "%d DirectionalLight3D nodes; one time of day per heist (max 1)" % suns)
	for rk2: Node in shadow_count.keys():
		if int(shadow_count[rk2]) > MAX_SHADOW_PER_ROOM:
			fail(ctx, rk2, null, "%d shadow-casting lights in room (max %d)" % [shadow_count[rk2], MAX_SHADOW_PER_ROOM])
	for rk3: Node in fill_count.keys():
		if int(fill_count[rk3]) > MAX_FILL_PER_ROOM and rk3 != ctx.map:
			fail(ctx, rk3, null, "%d fill lights in room (max %d)" % [fill_count[rk3], MAX_FILL_PER_ROOM])
	note("%d lights, %d fixture meshes" % [lights, fixtures.size()])


func _has_fixture(ctx: LcContext, l: Light3D, fixtures: Array[Dictionary]) -> bool:
	var cur: Node = l.get_parent()
	while cur != null and cur != ctx.map:
		if is_fixture(cur) and (cur is GeometryInstance3D or not cur.find_children("*", "GeometryInstance3D", true, false).is_empty()):
			return true
		cur = cur.get_parent()
	var p: Vector3 = l.global_position
	for f: Dictionary in fixtures:
		var box: AABB = f["aabb"]
		if LcGeom.aabb_gap(box, AABB(p, Vector3.ZERO)) <= FIXTURE_DIST:
			return true
	return false
