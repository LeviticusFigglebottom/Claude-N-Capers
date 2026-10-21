## Door clearance check shared by test_of_door_clearance / test_door_clearance_maps (OF-C2, ENV P ghost run 250: the
## pilot pinned on Ostrander's AssistantDoor west jamb). On a built map in a real HeistRuntime, with every door snapped
## open, the navmesh path from 1.2 m in front of each
## door to 1.2 m behind it (straight and angled) keeps a crew-size capsule (crew_member.tscn: radius 0.35, height 1.8)
## clear of that door's own frame (layer 1) everywhere inside the doorway (CLEAR_M; touching only on the 0.9 m
## singles). The nav agent is 0.3 m; of_gameplay._jamb_clearance bakes a straight throat centred on the frame. Doors
## without navmesh on both sides are skipped. Owner: ENV C.
extends TestCase

const SEED: int = 1002
const CREW_R: float = 0.35
const CREW_H: float = 1.8
## Required clearance to the frame inside the doorway: doors 1.0 m and wider keep CLEAR_M (the old bake put the
## AssistantDoor capsule exactly on the jamb, 0 m, and ENV P's pilot stalled there). The 0.9 m singles leave a 0.35 m
## capsule +-0.10 m of play, the narrowest throat the 0.1 m bake cells allow is +-0.10 m, so there it may touch
## (TOUCH_M) but not dig in.
const CLEAR_M: float = 0.04
const TOUCH_M: float = -0.005
const WIDE_M: float = 1.0
## The capsule rides this far above the floor (the controller walks up lips; the frame has no threshold).
const LIFT_M: float = 0.06
## A side point counts as on the navmesh within this distance.
const ON_NAV_M: float = 0.3
## Path ends this far in front of / behind the door, at these lateral offsets (in, out): straight and angled
## approaches, so paths hug both throat edges (ENV P's pilot came out of the office at an angle).
const APPROACH_M: float = 1.2
## The doorway band checked on each path (door-local |z|, the wall and the frame casing) and the sample step.
const BAND_M: float = 0.1
const STEP_M: float = 0.05
const LATERALS: Array = [[0.0, 0.0], [-1.0, -1.0], [1.0, 1.0], [-1.0, 1.0], [1.0, -1.0], [-1.6, 0.0], [1.6, 0.0],
	[0.0, -1.6], [0.0, 1.6]]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Runs the check on `heist`; at least `min_checked` doors must have navmesh on both sides.
func check_heist(heist: StringName, min_checked: int) -> void:
	_rt = await HeistLauncher.launch(heist, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % heist)
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.0, -50.0, 0.0)))
	var doors: Array[Door] = []
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if d.is_visible_in_tree() and not d.locked:
			d.set_open(true, true)
			d.finish_swing()
			doors.append(d)
	await wait_physics_frames(3)
	var nav: RID = c.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = c.get_world_3d().direct_space_state
	var checked: int = 0
	for d: Door in doors:
		var frames: Array[RID] = []
		for b: Node in d.find_children("*", "StaticBody3D", true, false):
			frames.append((b as StaticBody3D).get_rid())
		if frames.is_empty():
			continue
		var xf: Transform3D = d.global_transform
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = CREW_R + (CLEAR_M if d.effective_width() >= WIDE_M else TOUCH_M)
		cap.height = CREW_H + 2.0 * (cap.radius - CREW_R)
		var any: bool = false
		for lat: Array in LATERALS:
			var ends: Array[Vector3] = []
			for k: int in 2:
				var want: Vector3 = xf * Vector3(float(lat[k]), 0.0, -APPROACH_M if k == 0 else APPROACH_M)
				var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
				if Vector2(p.x - want.x, p.z - want.z).length() <= ON_NAV_M and absf(p.y - want.y) < 0.5:
					ends.append(p)
			if ends.size() < 2:
				continue
			var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, ends[0], ends[1], true)
			if path.size() < 2 or path[path.size() - 1].distance_to(ends[1]) > 0.5:
				continue
			any = true
			var hit: String = _frame_hit(space, cap, path, frames, xf)
			if hit != "":
				fail("%s %s (approach %s): %s" % [heist, d.name, lat, hit])
				break
		if any:
			checked += 1
	print("  door clearance %s: %d / %d open doors with navmesh on both sides checked" % [heist, checked, doors.size()])
	assert_true(checked >= min_checked, "%s: most doors checked (%d)" % [heist, checked])


## A crew capsule standing on `path` inside the doorway (within BAND_M of the door plane, sampled every STEP_M)
## that overlaps one of `frames`, as text ("" when clear). Grazes at the throat mouth on a diagonal approach slide off
## (move_and_slide); a capsule wedged in the throat is ENV P's stall.
func _frame_hit(space: PhysicsDirectSpaceState3D, cap: CapsuleShape3D, path: PackedVector3Array,
		frames: Array[RID], xf: Transform3D) -> String:
	var inv: Transform3D = xf.affine_inverse()
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	for i: int in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var steps: int = maxi(1, ceili(a.distance_to(b) / STEP_M))
		for k: int in steps + 1:
			var p: Vector3 = a.lerp(b, float(k) / float(steps))
			if absf((inv * p).z) > BAND_M:
				continue
			# the navmesh rides ~0.2 m over the floor
			q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, p.y - 0.2 + LIFT_M + CREW_H * 0.5, p.z))
			for h: Dictionary in space.intersect_shape(q, 16):
				if frames.has(h["rid"] as RID):
					return "a %.3f m capsule at %s (door-local %s) overlaps the frame (path %s)" % [cap.radius, p, inv * p,
						path]
	return ""
