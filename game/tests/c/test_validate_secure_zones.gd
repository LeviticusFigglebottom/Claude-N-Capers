## validate_level `secure_zones` check (D-066): every SECURE_LOOT zone must hold a resting bag's
## probe point (ground + 0.05 m).
extends LcTestBase


func test_zone_on_floor_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", Callable(), false, ["secure_zones"])
	_expect_only(res, [])


func test_zone_floor_above_ground_fails() -> void:
	# The Glasshouse VanSecureE1 case: zone floor 0.15 m above the ground under it.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		(m.get_node("Zones/SecureZone") as Node3D).position.y += 0.15, false, ["secure_zones"])
	_expect_fail(res, "secure_zones", "ground is 0.15 m below")
