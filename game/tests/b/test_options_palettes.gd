## B5-01: colour-blind-safe HUD palettes. Contrast reuses the WCAG helper (UiAccent.contrast_ratio, as
## test_ui_accent.gd); distinguishability uses the Machado 2009 simulation + CIE76 distance
## (ColorVision). The HUD widgets follow the active palette and HUD scale live.
extends TestCase

## WCAG 1.4.11 non-text contrast (bars, chevrons, markers) and 1.4.3 body text (low_health is text).
const NON_TEXT: float = 3.0
const BODY_TEXT: float = 4.5
## Minimum CIE76 distance between paired states (about 10x a just-noticeable difference).
const MIN_DELTA_E: float = 20.0
## States that must never be confused.
const PAIRS: Array = [
	[&"detection_suspicious", &"detection_alert"], [&"detection_alert", &"detection_detected"],
	[&"detection_suspicious", &"detection_detected"], [&"health", &"armor"], [&"health", &"low_health"],
	[&"ally_marker", &"enemy_marker"], [&"objective", &"loot_highlight"], [&"loot_highlight", &"interaction_highlight"],
]
## Palette id -> the simulations it must survive (default: normal vision only).
const TARGETS: Dictionary = {
	&"default": [],
	&"deuteranopia": [&"deuteranopia"],
	&"protanopia": [&"protanopia"],
	&"tritanopia": [&"tritanopia"],
	&"high_contrast": [&"protanopia", &"deuteranopia", &"tritanopia"],
}

var _set: HudPaletteSet


func before_all() -> void:
	_set = HudPaletteSet.load_default()


## PO-4 frameless HUD: no panel behind the widgets; coloured HUD text reads against its own outline
## (HudLabel outline, plus a soft shadow). The pixel-level check over real backdrops is the windowed
## tests/b/render/hud_contrast_capture.gd.
func _hud_bg() -> Color:
	return UiBuild.theme().get_color(&"font_outline_color", &"HudLabel")


func test_one_palette_per_setting_option() -> void:
	var opts: Array = SettingsDefaults.load_default().spec(GameSettings.ACCESSIBILITY, &"palette")["options"]
	assert_eq(opts.size(), 5)
	var table: Dictionary = StringTable.parse_csv()
	for o: Variant in opts:
		assert_has(_set.ids(), StringName(o), "palette entry for %s" % o)
	for p: HudPalette in _set.palettes:
		assert_has(opts, String(p.id))
		assert_has(table, String(p.name_key))
	assert_eq(_set.find(&"no_such").id, &"default", "unknown -> default")


func test_default_palette_keeps_the_pd2_hud_colours() -> void:
	var tw: HudTweak = HudTweak.load_default()
	var p: HudPalette = _set.find(&"default")
	assert_eq(p.detection_suspicious, tw.detection_blue)
	assert_eq(p.detection_alert, tw.detection_orange)
	assert_eq(p.detection_detected, tw.detection_red)
	assert_eq(p.health, tw.health_color)
	assert_eq(p.armor, tw.armor_color)
	assert_eq(p.enemy_marker, tw.mark_color)
	var applied: HudTweak = p.apply_to(tw)
	assert_ne(applied, tw, "apply_to copies")
	assert_eq(applied.chevron_radius_px, tw.chevron_radius_px, "non-colour tuning kept")


func test_contrast_against_the_hud() -> void:
	var bg: Color = _hud_bg()
	for p: HudPalette in _set.palettes:
		for f: StringName in HudPalette.FIELDS:
			var minimum: float = BODY_TEXT if f == &"low_health" else NON_TEXT
			var r: float = UiAccent.contrast_ratio(p.color(f), bg)
			assert_true(r >= minimum, "%s.%s contrast %.2f < %.1f" % [p.id, f, r, minimum])


func test_paired_states_stay_distinguishable() -> void:
	for p: HudPalette in _set.palettes:
		assert_true(TARGETS.has(p.id), "target list for %s" % p.id)
		var kinds: Array = [ColorVision.NORMAL] + (TARGETS.get(p.id, []) as Array)
		for kind: Variant in kinds:
			for pair: Array in PAIRS:
				var d: float = ColorVision.delta_e76_as(p.color(pair[0]), p.color(pair[1]), StringName(kind))
				assert_true(d >= MIN_DELTA_E, "%s under %s: %s vs %s dE76 %.1f < %.0f" % [p.id, kind, pair[0], pair[1], d, MIN_DELTA_E])


func test_simulation_math() -> void:
	assert_near(ColorVision.delta_e76(Color.WHITE, Color.BLACK), 100.0, 0.05, "L* 0..100")
	assert_near(ColorVision.to_lab(Color.WHITE).x, 100.0, 0.05)
	assert_eq(ColorVision.simulate(Color(0.3, 0.6, 0.9), ColorVision.NORMAL), Color(0.3, 0.6, 0.9))
	var red: Color = Color(0.85, 0.15, 0.1)
	var green: Color = Color(0.25, 0.6, 0.1)
	var normal: float = ColorVision.delta_e76(red, green)
	for kind: StringName in [ColorVision.PROTANOPIA, ColorVision.DEUTERANOPIA]:
		var sim: float = ColorVision.delta_e76_as(red, green, kind)
		assert_true(sim < normal * 0.5, "red/green collapse under %s: %.1f vs %.1f" % [kind, sim, normal])
	var blue: Color = Color(0.2, 0.3, 0.9)
	var teal: Color = Color(0.2, 0.75, 0.6)
	assert_true(ColorVision.delta_e76_as(blue, teal, ColorVision.TRITANOPIA) < ColorVision.delta_e76(blue, teal),
			"blue/teal closer under tritanopia")
	for kind: StringName in ColorVision.KINDS:
		var w: Color = ColorVision.simulate(Color.WHITE, kind)
		assert_true(ColorVision.delta_e76(w, Color.WHITE) < 3.0, "white stays white under %s" % kind)


func test_hud_follows_the_palette_and_scale() -> void:
	var s: GameSettings = GameSettings.new()
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.settings = s
	add_child(hud)
	await wait_frames(1)
	var def: HudPalette = _set.find(&"default")
	assert_eq(hud.chevrons.color_for(1.0), def.detection_detected)
	var hc: HudPalette = _set.find(&"high_contrast")
	s.set_value(GameSettings.ACCESSIBILITY, &"palette", "high_contrast")
	await wait_frames(1)
	for w: HudWidget in hud.widgets():
		assert_eq(w.tweak, hud.tweak, "%s reads the HUD's palette tweak" % w.name)
	assert_eq(hud.chevrons.color_for(0.1), hc.detection_suspicious)
	assert_eq(hud.chevrons.color_for(0.6), hc.detection_alert)
	assert_eq(hud.chevrons.color_for(1.0), hc.detection_detected)
	assert_eq(hud.vitals.armor_bar.self_modulate, hc.armor)
	assert_eq(hud.vitals.health_bar.self_modulate, hc.low_health, "empty health shows the low colour")
	assert_eq(hud.interaction.progress_bar.self_modulate, hc.interaction_highlight)
	assert_eq(hud.status.bag_label.get_theme_color(&"font_color"), hc.loot_highlight)
	assert_eq(hud.tweak.mark_color, hc.enemy_marker)
	assert_eq(hud.tweak.ally_color, hc.ally_marker)
	s.set_value(GameSettings.ACCESSIBILITY, &"hud_scale", 1.25)
	assert_eq(hud.vitals.scale, Vector2(1.25, 1.25))
	assert_near(hud.vitals.pivot_offset.y, hud.vitals.size.y, 0.5, "bottom-left widget scales from its corner")
	assert_eq(hud.chevrons.scale, Vector2.ONE, "full-screen overlays not scaled")
	hud.queue_free()
	await wait_frames(1)
	s.set_value(GameSettings.ACCESSIBILITY, &"palette", "default")  # no callback into a freed HUD
