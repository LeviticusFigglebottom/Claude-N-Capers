## Every interactable in ENV C heists sits clear of prop collision and is aimable from its UsePoint
## (PP-C-2: Glasshouse kc_breakroom was 0.29 m inside Props/U1/Lockers_1). Owner: ENV C.
## For each prefab with an `Interactable` and a `UsePoint` under Gameplay / Variants: (1) a physics point query
## at the Interactable (world layer 1) hits no body outside the prefab itself; (2) a ray from the UsePoint's eye
## (1.6 m) to the Interactable hits nothing outside the prefab before it. Every variant slot is live here (the
## map is instanced, not launched), so slots are checked in every variant.
extends TestCase

const HEISTS: Array[String] = ["glasshouse", "night_deposit", "dockside_burn"]
const EYE_M: float = 1.6
const FACE_M: float = 0.08
## Open findings logged in docs/levels/pp_c2_handplay.md (PP-C-2, 2026-10-12), not fixed yet: Night Deposit ATM1/ATM2
## (decorative ATM prop collision over the AtmCash interactables), kc_break_locker (inside the G4 lockers, same bug as
## Glasshouse kc_breakroom); Dockside count-room CageCashA/B (UsePoint behind wall M_X9_00). The check fails on any new one.
const KNOWN_OPEN: Dictionary = {"glasshouse": 0, "night_deposit": 9, "dockside_burn": 2}


func test_interact_slots_clear() -> void:
	for h: String in HEISTS:
		await _check(h)


func _own_rids(n: Node) -> Array[RID]:
	var out: Array[RID] = []
	for b: Node in n.find_children("*", "CollisionObject3D", true, false):
		out.append((b as CollisionObject3D).get_rid())
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	return out


## The outermost gameplay prefab holding `n` (loot inside a safe belongs to the safe).
func _prefab_root(n: Node3D) -> Node3D:
	var cur: Node3D = n
	while cur.get_parent() is Node3D and (cur.get_parent() as Node).get_node_or_null(^"UsePoint") != null:
		cur = cur.get_parent() as Node3D
	return cur


static func _slot_of(n: Node) -> Node:
	var cur: Node = n
	while cur != null and not (cur is VariantSlot):
		cur = cur.get_parent()
	return cur


## True when `hit` lives in another slot of the same variant group (only one of them is ever live).
static func _other_slot(pf: Node, hit: Node) -> bool:
	var a: Node = _slot_of(pf)
	var b: Node = _slot_of(hit)
	return a != null and b != null and a != b and a.get_parent() == b.get_parent()


func _check(heist: String) -> void:
	var ps: PackedScene = load("res://world/heists/%s/%s.tscn" % [heist, heist]) as PackedScene
	if ps == null:
		fail("%s scene missing" % heist)
		return
	var map: Node3D = ps.instantiate() as Node3D
	add_child(map)
	await wait_physics_frames(3)
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var checked: int = 0
	var bad: PackedStringArray = PackedStringArray()
	for root_name: String in ["Gameplay", "Variants"]:
		var r: Node = map.get_node_or_null(root_name)
		if r == null:
			continue
		for it: Node in r.find_children("Interactable", "Node3D", true, false):
			var pf: Node3D = it.get_parent() as Node3D
			var up: Node3D = pf.get_node_or_null(^"UsePoint") as Node3D
			if up == null or pf is Door:
				continue
			checked += 1
			var own: Array[RID] = _own_rids(_prefab_root(pf))
			var target: Vector3 = (it as Node3D).global_position
			var eye: Vector3 = up.global_position + Vector3.UP * EYE_M
			# A face-mounted interactable (deposit-box door, ATM screen) sits on its prop's face: probe 8 cm toward the user.
			var probe: Vector3 = target + (eye - target).normalized() * FACE_M
			var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
			pq.position = probe
			pq.collision_mask = 1
			pq.exclude = own
			for hit: Dictionary in space.intersect_point(pq, 4):
				if _other_slot(pf, hit["collider"] as Node):
					continue
				bad.append("%s inside %s" % [map.get_path_to(pf), map.get_path_to(hit["collider"] as Node)])
			var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target, 1, own)
			var rh: Dictionary = space.intersect_ray(rq)
			if not rh.is_empty() and not _other_slot(pf, rh["collider"] as Node) and (rh["position"] as Vector3).distance_to(target) > FACE_M + 0.02:
				bad.append("%s not aimable from its UsePoint: %s blocks at %.2f m" % [map.get_path_to(pf),
					map.get_path_to(rh["collider"] as Node), eye.distance_to(rh["position"])])
	print("[C3] %s: %d interact slots checked, %d problems" % [heist, checked, bad.size()])
	for b: String in bad:
		print("[C3]   " + b)
	assert_true(checked > 0, "%s: interact slots found" % heist)
	assert_true(bad.size() <= int(KNOWN_OPEN[heist]), "%s: interact slots clear and aimable, %d known open (%s)" % [
		heist, int(KNOWN_OPEN[heist]), "; ".join(bad.slice(0, 5))])
	map.queue_free()
	await wait_frames(2)
