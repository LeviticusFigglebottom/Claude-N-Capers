## X-4: Gallery Night (gallery_night) stealth end-to-end, seed 11 (ROUTINE): the Lantern Bearer in the art store
## (cp_store, behind the AS vault reader), sensors_treasury (ground / upper frame sensors off), the Widow in Blue in
## Founders (widow_founders), mews escape. Route and harness shortcuts: game/tests/a/e2e/x4_stealth_flow.gd
## (route_gallery_night).
extends "res://tests/a/x4_stealth_case.gd"

const SEED: int = 11


func test_x4_gn_stealth_completes_without_alarm() -> void:
	await run_stealth(&"gallery_night", SEED, [&"casing", &"keycard", &"art_store", &"centrepiece", &"canvases", &"secure"])
