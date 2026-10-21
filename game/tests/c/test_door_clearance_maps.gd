## Door clearance on the other heists (LEAD round 252: the Ostrander jamb snag, ENV P ghost run 250, checked map-wide).
## The check is _door_clearance_base.gd. Owner: ENV C.
extends "res://tests/c/_door_clearance_base.gd"


func test_glasshouse() -> void:
	await check_heist(&"glasshouse", 5)


func test_night_deposit() -> void:
	await check_heist(&"night_deposit", 5)


func test_gallery_night() -> void:
	await check_heist(&"gallery_night", 5)


func test_dockside_burn() -> void:
	await check_heist(&"dockside_burn", 5)


func test_shadow_ledger() -> void:
	await check_heist(&"shadow_ledger", 5)
