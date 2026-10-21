## Ostrander Federal door clearance (OF-C2, ENV P ghost run 250: the pilot pinned on the AssistantDoor's west jamb).
## The check is _door_clearance_base.gd. Owner: ENV C.
extends "res://tests/c/_door_clearance_base.gd"


func test_crew_capsule_clears_every_open_door_frame() -> void:
	await check_heist(&"ostrander_federal", 20)
