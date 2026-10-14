## Lead queue (4): the colour-blind / high-contrast palettes reach the round-62..64 widgets (markers,
## crew badges, hostage trade line, hit markers, damage arcs, low-health vignette, downed overlay), and
## the pairs a player must tell apart stay apart under each palette's own colour-vision simulation.
extends TestCase

const MIN_DELTA_E: float = 20.0

var _set: HudPaletteSet


func before_all() -> void:
	_set = HudPaletteSet.load_default()


func test_new_widgets_follow_the_palette() -> void:
	var s: GameSettings = GameSettings.new()
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.settings = s
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	for id: StringName in _set.ids():
		s.set_value(GameSettings.ACCESSIBILITY, &"palette", String(id))
		await wait_frames(1)
		var pal: HudPalette = _set.find(id)
		for w: HudWidget in [hud.hit_feedback, hud.damage_direction, hud.low_health, hud.downed, hud.hostages,
				hud.objective_markers, hud.teammates]:
			assert_eq(w.tweak.low_health_color, pal.low_health, "%s danger role in %s" % [w.name, id])
		assert_eq(hud.objective_markers.tweak.objective_color, pal.objective, "markers in %s" % id)
		assert_eq(hud.downed.revive_bar.self_modulate, pal.ally_marker, "revive bar in %s" % id)
		model.hostages = 1
		model.crew = [{"slot": 1, "name": "Dutch", "state": Enums.CrewState.CUSTODY}]
		assert_eq(hud.hostages.trade_label.get_theme_color(&"font_color"), pal.ally_marker, "trade ready in %s" % id)
		model.crew = [{"slot": 1, "name": "Dutch", "state": Enums.CrewState.DOWNED, "bleedout_s": 10.0}]
		var badge: CrewStateBadge = hud.teammates.badges[1] as CrewStateBadge
		assert_eq(badge.danger_color, pal.low_health, "badge in %s" % id)
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)


## danger vs ally (bleedout vs revive ring, "take a hostage" vs "trade ready") and kill vs headshot
## markers stay distinguishable for the palette's own colour vision (default / high contrast: normal).
func test_new_pairs_stay_apart() -> void:
	for id: StringName in _set.ids():
		var pal: HudPalette = _set.find(id)
		var kind: StringName = id if ColorVision.KINDS.has(id) else ColorVision.NORMAL
		var pairs: Array = [[pal.low_health, pal.ally_marker, "danger / ally"],
			[pal.low_health, pal.armor, "kill / headshot marker"]]
		for p: Array in pairs:
			var d: float = ColorVision.delta_e76_as(p[0] as Color, p[1] as Color, kind) if kind != ColorVision.NORMAL \
					else ColorVision.delta_e76(p[0] as Color, p[1] as Color)
			assert_true(d >= MIN_DELTA_E, "%s: %s delta E %.1f under %s" % [id, String(p[2]), d, kind])
