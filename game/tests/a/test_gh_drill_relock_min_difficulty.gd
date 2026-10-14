## Glasshouse rare event `drill_relock` (B data finding): min_difficulty is an event field (the resolver
## reads it there), not an `effects` key; the event never fires below Brutal and can fire at Brutal.
extends TestCase

const VARIANTS: String = "res://world/heists/glasshouse/glasshouse_variants.tres"


func _drill_relock(t: HeistVariantTable) -> Dictionary:
	for ev: Dictionary in t.rare_events:
		if StringName(ev.get("id", &"")) == &"drill_relock":
			return ev
	return {}


func test_drill_relock_min_difficulty_is_an_event_field() -> void:
	var t: HeistVariantTable = load(VARIANTS) as HeistVariantTable
	var ev: Dictionary = _drill_relock(t)
	assert_false(ev.is_empty(), "glasshouse has drill_relock")
	assert_eq(int(ev.get("min_difficulty", -1)), Enums.Difficulty.BRUTAL, "event-level min_difficulty (Brutal)")
	assert_false((ev.get("effects", {}) as Dictionary).has("min_difficulty"), "not hidden inside effects")


func test_drill_relock_never_below_brutal() -> void:
	var src: HeistVariantTable = load(VARIANTS) as HeistVariantTable
	var t: HeistVariantTable = HeistVariantTable.new()  # rare events only: no slots needed
	t.rare_events = src.rare_events
	var fired_brutal: bool = false
	for s: int in range(200):
		for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.TENSE, Enums.Difficulty.HAZARDOUS]:
			GameRng.begin_run(9000 + s)
			var r: Dictionary = VariantResolver.resolve(t, {}, d)
			assert_false((r.get("rare", []) as Array).has(&"drill_relock"), "no drill_relock at difficulty %d" % d)
		GameRng.begin_run(9000 + s)
		fired_brutal = fired_brutal or (VariantResolver.resolve(t, {}, Enums.Difficulty.BRUTAL).get("rare", []) as Array).has(&"drill_relock")
	assert_true(fired_brutal, "fires at Brutal for some seed (chance 0.10 over 200 seeds)")
