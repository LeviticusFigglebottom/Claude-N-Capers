## density (final): per RoomVolume with a dressing kit: required kinds present, prop count per m²
## within [min_density, max_density], >= min_props, and no lone prop (no other prop within 2 m)
## in rooms > 12 m² (level_standards §3.4/§3.5; floor props only, footprint distance). Rooms need a kit unless the purpose is exempt.
class_name LcCheckDensity
extends LcCheck

const LONE_RADIUS: float = 2.0
const LONE_ROOM_AREA: float = 12.0
const KIT_EXEMPT: Array[StringName] = [&"corridor", &"stair", &"exterior", &"shaft", &"elevator", &"roof",
	&"plenum", &"vault"]


func _init() -> void:
	id = &"density"
	title = "Dressing density"
	stages = PackedStringArray(["final"])


## Props whose OBB centre lies in the room (active only).
static func props_in_room(ctx: LcContext, r: RoomVolume) -> Array[LcProp]:
	if not ctx.cache.has(&"props_by_room"):
		var by_room: Dictionary = {}
		for p: LcProp in ctx.props:
			if p.has_geometry and ctx.is_active(p.node) and not p.is_door:
				var room: RoomVolume = ctx.room_at(p.center())
				if room != null:
					if not by_room.has(room):
						by_room[room] = [] as Array[LcProp]
					(by_room[room] as Array[LcProp]).append(p)
		ctx.cache[&"props_by_room"] = by_room
	var d: Dictionary = ctx.cache[&"props_by_room"]
	if d.has(r):
		return d[r]
	return [] as Array[LcProp]


func run(ctx: LcContext) -> void:
	for p: LcProp in ctx.props:
		if ctx.is_active(p.node) and p.kind == &"" and p.has_geometry:
			fail(ctx, p.node, null, "prop has no `kind` meta (needed for kits/scale checks)")
	note("| room | kit | props | m² | per m² |")
	note("|---|---|---|---|---|")
	for r: RoomVolume in ctx.rooms:
		if r.dressing_kit == &"":
			if not (r.purpose in KIT_EXEMPT):
				fail(ctx, r, null, "room (purpose `%s`) has no dressing_kit" % r.purpose)
			continue
		var kit: DressingKit = ctx.load_kit(r.dressing_kit)
		if kit == null:
			fail(ctx, r, null, "dressing kit `%s` not found in %s" % [r.dressing_kit, ctx.kit_dirs])
			continue
		if kit.purpose != &"" and kit.purpose != r.purpose:
			fail(ctx, r, null, "kit `%s` is for purpose `%s`, room purpose is `%s`" % [kit.id, kit.purpose, r.purpose])
		var inside: Array[LcProp] = props_in_room(ctx, r)
		var area: float = LcAreas.footprint(r)
		var per: float = float(inside.size()) / maxf(area, 0.01)
		note("| `%s` | %s | %d | %.1f | %.2f |" % [ctx.node_path(r), kit.id, inside.size(), area, per])
		var kinds: Dictionary = {}
		for p2: LcProp in inside:
			kinds[p2.kind] = true
		for req: StringName in kit.required_items:
			if not kinds.has(req):
				fail(ctx, r, null, "kit `%s` requires a `%s`; none in the room" % [kit.id, req])
		if inside.size() < kit.min_props:
			fail(ctx, r, null, "%d props < kit minimum %d" % [inside.size(), kit.min_props])
		if per < kit.min_density - 1e-4:
			fail(ctx, r, null, "density %.3f props/m² < kit min %.3f" % [per, kit.min_density])
		if per > kit.max_density + 1e-4:
			fail(ctx, r, null, "density %.3f props/m² > kit max %.3f" % [per, kit.max_density])
		if area > LONE_ROOM_AREA:
			for p3: LcProp in inside:
				if p3.kind in kit.lone_ok_kinds or p3.mount != &"":
					continue
				var lone: bool = true
				for o: LcProp in inside:
					if o != p3 and LcGeom.aabb_gap(_flat(o.global_aabb), _flat(p3.global_aabb)) <= LONE_RADIUS:
						lone = false
						break
				if lone:
					fail(ctx, p3.node, null, "lone prop: no other prop within %.0f m in a %.0f m² room" % [LONE_RADIUS, area])


## AABB flattened to y = 0 (footprint distance for the lone-prop rule).
static func _flat(b: AABB) -> AABB:
	return AABB(Vector3(b.position.x, 0.0, b.position.z), Vector3(b.size.x, 0.0, b.size.z))
