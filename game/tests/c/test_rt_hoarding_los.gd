## Rolling Thunder site hoarding (D-158, the LEAD's check of P's clean_haz run: site guards hit the crew at Pier-40's
## south face). The doc (rolling_thunder.md "The site"): the 2.4 m solid hoarding blocks every street view at eye
## height; only the frame slab (+3.5, holdout H3) and the crane see out; the man-gate's mesh panel is the one window.
## On the generated map:
## * every hoarding box stands >= 2.4 m on the world layer, and none but ManGatePanel is see-through;
## * the hoarding lines have no gap: a ray across each line every 0.5 m from 0.3 to 2.35 m meets a solid collider (a
##   hoarding box or a closed gate leaf), but for PENDING_SLOTS (none);
## * no ground-level site guard post or patrol point has a line of sight (eye 1.6 m) to the crew at the pier's south
##   face (bullets and vision both stop at the hoarding);
## * the frame slab's east edge does see the pier: the doc's designed H3 / post_site_frame sightline (pinned so a change
##   to it is a decision, not an accident). Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const HOARD_H: float = 2.4
## The site's hoarding rectangle (rolling_thunder_layout.gd SITE_BOXES "Hoarding": x -60 .. -14, z -56 .. -11).
const X0: float = -60.0
const X1: float = -14.0
const Z0: float = -56.0
const Z1: float = -11.0
## The crew in cover at Pier-40's south face (P's clean_haz run), chest and head height.
const PIER_CREW: Array[Vector3] = [Vector3(-0.2, 1.2, -37.2), Vector3(-0.2, 1.6, -37.2)]
const EYE: float = 1.6
const MASK: int = 0xFFFFFFFF & ~(1 << 9)
## Slots a door's leaf collision leaves open, [axis, fixed, from, to, from height]. D-158: empty since the
## SiteTanneryGate leaves take Door.height_m 2.4 (A's export, round 286): its leaves were 2.1 m under 2.4 m visuals.
const PENDING_SLOTS: Array = []
## The man-gate stack (sill, mesh panel, head) reaches the hoarding's height together.
const MAN_GATE_PREFIX: String = "ManGatePanel"

var _map: Node3D = null


func before_each() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	var mission: Node = _map.get_node_or_null("Mission")
	if mission != null:
		mission.set_script(null)
	add_child(_map)
	await wait_physics_frames(3)


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_hoarding_boxes_are_solid_and_tall_enough() -> void:
	var g: Node = _map.find_child("Hoarding", true, false)
	assert_true(g != null, "Geometry/Site/Hoarding")
	if g == null:
		return
	var n: int = 0
	for c: Node in g.get_children():
		var body: StaticBody3D = c as StaticBody3D
		if body == null:
			continue
		assert_true(body.collision_layer & 1 != 0, "%s on the world layer" % body.name)
		var see: bool = body.is_in_group(&"see_through") or bool(body.get_meta(&"see_through", false))
		assert_eq(see, String(body.name) == "ManGatePanel", "%s see-through only if it is the man-gate panel" % body.name)
		var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D and not String(body.name).begins_with(MAN_GATE_PREFIX) \
				or String(body.name) == MAN_GATE_PREFIX + "Head":
			var top: float = body.global_position.y + (cs.shape as BoxShape3D).size.y * 0.5
			assert_true(top >= HOARD_H - 0.01, "%s top %.2f m >= %.1f m" % [body.name, top, HOARD_H])
		n += 1
	assert_true(n >= 10, "%d hoarding bodies" % n)


func test_hoarding_lines_have_no_gap() -> void:
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var holes: PackedStringArray = []
	# [axis, fixed, from, to]: "x" = a line along x at z = fixed; "z" = along z at x = fixed
	for line: Array in [["x", Z0, X0, X1], ["x", Z1, X0, X1], ["z", X0, Z0, Z1], ["z", X1, Z0, Z1]]:
		var a: float = float(line[2]) + 0.25
		while a < float(line[3]) - 0.2:
			for h: float in [0.3, 1.0, 1.6, 2.05, 2.15, 2.25, 2.35]:
				var f: float = float(line[1])
				var p: Vector3 = Vector3(a, h, f - 0.5) if line[0] == "x" else Vector3(f - 0.5, h, a)
				var q: Vector3 = Vector3(a, h, f + 0.5) if line[0] == "x" else Vector3(f + 0.5, h, a)
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(p, q, MASK)).is_empty() \
						and not _pending(String(line[0]), f, a, h):
					holes.append("%s %.1f @ %.2f, h %.2f" % [line[0], f, a, h])
			a += 0.5
	assert_true(holes.is_empty(), "the hoarding lines are closed: %s" % ", ".join(holes))


static func _pending(axis: String, fixed: float, a: float, h: float) -> bool:
	for s: Array in PENDING_SLOTS:
		if String(s[0]) == axis and is_equal_approx(float(s[1]), fixed) and a > float(s[2]) and a < float(s[3]) \
				and h > float(s[4]):
			return true
	return false


func test_ground_guard_posts_cannot_see_the_pier() -> void:
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var n: int = 0
	for node: Node in _map.find_children("*", "", true, false):
		var p3: Node3D = node as Node3D
		var guard: bool = (node is SpawnPoint and (node as SpawnPoint).kind == SpawnPoint.Kind.GUARD) or node is PatrolPoint
		if p3 == null or not guard:
			continue
		var p: Vector3 = p3.global_position
		if p.x < X0 or p.x > X1 or p.z < Z0 or p.z > Z1 or p.y > 1.0:
			continue
		n += 1
		for t: Vector3 in PIER_CREW:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * EYE, t, MASK))
			assert_false(hit.is_empty(), "%s (%s) sees the crew at the pier %s" % [_map.get_path_to(node), p, t])
	assert_true(n >= 5, "%d ground-level site guard points" % n)


## The doc's H3 sightline: a guard at the frame slab's east edge sees the pier (rolling_thunder.md: "Only the frame
## slab (+3.5) and the crane see out", post_site_frame's "F1 slab edge (pause look over Orchard)").
func test_frame_slab_edge_sees_out_by_design() -> void:
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var eye: Vector3 = Vector3(-26.5, 3.5 + EYE, -38.0)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, PIER_CREW[0], MASK))
	assert_true(hit.is_empty(), "the F1 slab edge sees over the hoarding to the pier (H3)")
