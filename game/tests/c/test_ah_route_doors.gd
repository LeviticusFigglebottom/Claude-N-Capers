## Afterhours door flags vs the doc's stealth routes (docs/design/heists/afterhours.md "Stealth routes", P's casing pass
## seed 6501): every guest door (D-075) lets civilians through and every door a route crosses unmasked lets a casing
## player through; the keycard / lockpick doors stay masked-only. civilian_allowed is asserted once ENV A's Door has the
## export (until then the generator skips it). Every gear_drop slot's bag is taken by a civilian from a guest / public
## room: its UsePoint stands in one, within REACH_M of the bag, with a clear line of sight to it (P r305: the cloakroom
## hatch). Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/afterhours/afterhours.tscn"
## D-075 guest doors: civilian_allowed and casing_allowed.
const GUEST: Array[String] = ["MainDoorsW", "MainDoorsE", "HallDoorsW", "HallDoorsE", "WCDoorG3a", "WCDoorG3b",
	"WCDoorU4a", "WCDoorU4b", "HallFireExitN", "HallFireExitS", "RopeGate"]
## Crossed unmasked by routes 1-3 (casing_allowed, not civilian_allowed).
const CASING: Array[String] = ["EastBarServiceDoor", "BarStoreDoor", "StaffRoomDoor", "DoorTeamRoomDoor",
	"StaffEntranceDoor", "StaffStairDoorG", "StaffStairDoorU", "BackstageDoor", "GreenRoomDoor", "LoadingDoor",
	"EventStoreDoor", "RearDoor"]
## Guest / public rooms a civilian walks (D-075 front of house + the streets).
const GUEST_ROOMS: Array[StringName] = [&"G1", &"G3a", &"G3b", &"G6", &"G7", &"U1", &"U2", &"U4a", &"U4b", &"X1", &"X2"]
const REACH_M: float = 2.0
const EYE_M: float = 1.4
## Masked-only: neither flag.
const MASKED: Array[String] = ["OfficeDoor", "CountRoomDoor", "VIPStaffDoor", "StockRoomDoor", "ElectricalDoor",
	"DoorOfficeDoorN", "DoorOfficeDoorW", "SecurityRoomDoor", "StaffStreetDoor"]


func test_route_door_flags() -> void:
	var map: Node = (load(SCENE) as PackedScene).instantiate()
	var has_civ: bool = false
	for name: String in GUEST + CASING + MASKED:
		var doors: Array[Node] = map.find_children(name, "Door", true, false)
		assert_true(not doors.is_empty(), "door %s exists" % name)
		for d: Node in doors:
			has_civ = has_civ or (&"civilian_allowed" in d)
			var casing: bool = bool(d.get(&"casing_allowed"))
			var civ: bool = bool(d.get(&"civilian_allowed")) if &"civilian_allowed" in d else false
			if name in MASKED:
				assert_false(casing, "%s is masked-only (casing_allowed false)" % map.get_path_to(d))
				assert_false(civ, "%s is masked-only (civilian_allowed false)" % map.get_path_to(d))
			else:
				assert_true(casing, "%s: a stealth route crosses it unmasked (casing_allowed)" % map.get_path_to(d))
			if name in CASING:
				assert_false(civ, "%s is a staff door (civilian_allowed false)" % map.get_path_to(d))
			if name in GUEST and &"civilian_allowed" in d:
				assert_true(civ, "%s is a D-075 guest door (civilian_allowed)" % map.get_path_to(d))
	if not has_civ:
		print("  (Door has no civilian_allowed export yet: the guest-door civilian check waits on ENV A)")
	map.free()


func test_gear_slots_reachable_by_civilians() -> void:
	var map: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	add_child(map)
	await wait_physics_frames(3)
	var bags: Array[Node] = map.find_children("GearBag", "", true, false)
	assert_eq(bags.size(), 4, "a GearBag in each of the 4 gear_drop slots")
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	for b: Node in bags:
		var bag: Node3D = b as Node3D
		var up: Node3D = bag.get_node_or_null("UsePoint") as Node3D
		assert_true(up != null, "%s has a UsePoint" % map.get_path_to(bag))
		if up == null:
			continue
		var stand: Vector3 = up.global_position
		var room: StringName = _room_at(map, stand + Vector3(0.0, 0.5, 0.0))
		assert_true(room in GUEST_ROOMS, "%s is taken from %s (a guest / public room)" % [map.get_path_to(bag), room])
		var flat: Vector2 = Vector2(bag.global_position.x - stand.x, bag.global_position.z - stand.z)
		assert_true(flat.length() <= REACH_M, "%s within %.1f m of its UsePoint (%.2f)" % [bag.name, REACH_M, flat.length()])
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(stand + Vector3(0.0, EYE_M, 0.0),
			bag.global_position + Vector3(0.0, 0.1, 0.0), 1)
		var hit: Dictionary = space.intersect_ray(q)
		var blocked: bool = not hit.is_empty() and not bag.is_ancestor_of(hit["collider"]) and hit["collider"] != bag
		assert_false(blocked, "%s: line of sight from its UsePoint is blocked by %s" % [map.get_path_to(bag),
			map.get_path_to(hit["collider"]) if blocked else ""])
	map.queue_free()


static func _room_at(map: Node, p: Vector3) -> StringName:
	for r: Node in map.get_node("Rooms").get_children():
		var sh: CollisionShape3D = r.get_node_or_null("Shape") as CollisionShape3D
		if sh == null or not (sh.shape is BoxShape3D):
			continue
		var local: Vector3 = sh.global_transform.affine_inverse() * p
		var half: Vector3 = (sh.shape as BoxShape3D).size * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return StringName(r.get(&"room_id"))
	return &""
