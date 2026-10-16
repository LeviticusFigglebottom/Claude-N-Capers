## X-4 follow-up: Gallery Night stealth end-to-end where the only keycard is the one the curator carries (kc_curator,
## QC-52: the `keycard` KeycardPickup with carrier_tag civ_curator). The crew shouts Sorell down, cable-ties her and
## takes the card off her (X4StealthRoutes._gn_curator_card), then plays the normal GN route (seed 11 otherwise).
## Variant forcing, no seed hunt: the preplan path pins keycard = kc_curator, centrepiece = cp_store (behind the AS
## vault reader, so the card is needed) and curator_route = curator_office (PreplanResult force_variants ->
## VariantResolver.resolve(..., forced)); the pin counts toward the group's pick but the GN table picks 2 keycards,
## so the run also gets a duplicate of the GN variant table (HeistRuntime option "variant_table") with the keycard
## pick narrowed to 1 and the curator_tipsy rare event left out (it swaps her lanyard for the bar card at last call).
## The map and gallery_night_variants.tres are untouched.
extends "res://tests/a/x4_stealth_case.gd"

const SEED: int = 11
const VARIANTS_PATH: String = "res://world/heists/gallery_night/gallery_night_variants.tres"


func _curator_only_table() -> HeistVariantTable:
	var t: HeistVariantTable = (load(VARIANTS_PATH) as HeistVariantTable).duplicate(true) as HeistVariantTable
	var rules: Array[Dictionary] = []
	for r: Dictionary in t.rules:
		var rr: Dictionary = r.duplicate(true)
		if StringName(rr.get("group", &"")) == &"keycard":
			rr["pick"] = Vector2i(1, 1)
		rules.append(rr)
	t.rules = rules
	var rare: Array[Dictionary] = []
	for ev: Dictionary in t.rare_events:
		if StringName(ev.get("id", &"")) != &"curator_tipsy":
			rare.append(ev.duplicate(true))
	t.rare_events = rare
	return t


func _options() -> Dictionary:
	return {
		"variant_table": _curator_only_table(),
		"preplan": {"force_variants": {
			"keycard": [&"kc_curator"], "centrepiece": [&"cp_store"], "curator_route": [&"curator_office"]}},
	}


func test_x4_gn_curator_keycard_completes_without_alarm() -> void:
	await run_stealth(&"gallery_night", SEED,
		[&"casing", &"keycard", &"art_store", &"centrepiece", &"canvases", &"secure"], _options())
	if flow == null or flow.rt == null:
		return
	assert_eq(flow.rt.variants.get(&"keycard"), [&"kc_curator"], "keycard forced to kc_curator only")
	assert_eq(flow.rt.variants.get(&"centrepiece"), [&"cp_store"], "centrepiece forced to cp_store")
	assert_false((flow.rt.variants.get(VariantResolver.RARE_KEY, []) as Array).has(&"curator_tipsy"), "no curator_tipsy")
	var fx: Dictionary = flow.facts
	assert_true(fx.has(&"curator_net_id"), "the route took the curator branch (%s)" % [fx])
	assert_eq(fx.get(&"curator_card_carrier", -1), fx.get(&"curator_net_id", -2), "the card was on the curator")
	assert_false(bool(fx.get(&"curator_card_released_before_shout", true)), "the card was locked on her lanyard first")
	assert_true(bool(fx.get(&"curator_tied", false)), "the curator was cable-tied")
	assert_eq(fx.get(&"curator_card_taken_by_slot", -1), 0, "the bot took the card off her")
	assert_true(bool(fx.get(&"curator_card_tied_at_take", false)), "she was tied when the card was taken")
