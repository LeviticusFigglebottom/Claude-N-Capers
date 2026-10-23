## Afterhours door flags vs the doc's stealth routes (docs/design/heists/afterhours.md "Stealth routes", P's casing pass
## seed 6501): every guest door (D-075) lets civilians through and every door a route crosses unmasked lets a casing
## player through; the keycard / lockpick doors stay masked-only. civilian_allowed is asserted once ENV A's Door has the
## export (until then the generator skips it). Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/afterhours/afterhours.tscn"
## D-075 guest doors: civilian_allowed and casing_allowed.
const GUEST: Array[String] = ["MainDoorsW", "MainDoorsE", "HallDoorsW", "HallDoorsE", "WCDoorG3a", "WCDoorG3b",
	"WCDoorU4a", "WCDoorU4b", "HallFireExitN", "HallFireExitS", "RopeGate"]
## Crossed unmasked by routes 1-3 (casing_allowed, not civilian_allowed).
const CASING: Array[String] = ["EastBarServiceDoor", "BarStoreDoor", "StaffRoomDoor", "DoorTeamRoomDoor",
	"StaffEntranceDoor", "StaffStairDoorG", "StaffStairDoorU", "BackstageDoor", "GreenRoomDoor", "LoadingDoor",
	"EventStoreDoor", "RearDoor"]
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
