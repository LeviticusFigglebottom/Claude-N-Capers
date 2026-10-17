## D-142 (clear glass is see-through for detection): the stealth onboarding card's glass row and the briefing's
## "Clear glass" line on heists marked "glazing" (GH, SL) stay off until HudTweak.d142_glass_tips is switched on.
extends TestCase


## Held while a test switches the flag on (the cached resource lives only while referenced).
var _tw: HudTweak = null


func after_each() -> void:
	if _tw != null:
		_tw.d142_glass_tips = false  # the shipped value
	_tw = null


func _intel_ids(heist: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for l: Dictionary in BriefingIntel.lines(heist, Enums.Difficulty.ROUTINE, int(HeistRegistry.get_def(heist).mode)):
		ids.append(StringName(l["id"]))
	return ids


func test_off_until_d142() -> void:
	assert_false(HudTweak.load_default().d142_glass_tips, "hidden until D-142 is on trunk")
	for r: Array in OnboardingCard.rows_for(&"stealth"):
		assert_ne(StringName(r[1]), &"ui.tip.stealth.glass")
	assert_false(_intel_ids(&"glasshouse").has(&"glass"))


func test_on_shows_the_tip_and_the_glazing_line() -> void:
	_tw = HudTweak.load_default()
	_tw.d142_glass_tips = true
	var keys: Array[StringName] = []
	for r: Array in OnboardingCard.rows_for(&"stealth"):
		keys.append(StringName(r[1]))
	assert_has(keys, &"ui.tip.stealth.glass")
	assert_eq(OnboardingCard.row_glyphs(&"stealth").size(), keys.size(), "glyphs follow the rows")
	assert_eq(UiText.t(&"ui.tip.stealth.glass"), "Guards and cameras can see you through clear glass.")
	assert_true(HeistCatalog.heist_list().has_glazing(&"glasshouse"))
	assert_true(HeistCatalog.heist_list().has_glazing(&"shadow_ledger"))
	assert_false(HeistCatalog.heist_list().has_glazing(&"night_deposit"))
	assert_has(_intel_ids(&"glasshouse"), &"glass")
	assert_has(_intel_ids(&"shadow_ledger"), &"glass")
	assert_false(_intel_ids(&"night_deposit").has(&"glass"), "no glazing flag: no line")
	assert_false(_intel_ids(&"dockside_burn").has(&"glass"), "loud-only: no line")
