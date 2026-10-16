## LEAD r229 (crowding pass): the objectives caption takes the heist accent, and the frameless HUD panel is mostly
## see-through, so every heist's caption must read over a mid-grey scene (ObjectivesPanel.WORLD_BG), not only over the
## panel's own tint. Night Deposit's dark red failed this in the loud shots. Also: an assault event the banner already
## lists is not toasted on top.
extends TestCase

const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
		&"gallery_night"]


func test_every_heist_caption_reads_over_the_scene() -> void:
	var need: float = UiAccent.table().min_text_contrast
	var lifted: Array[StringName] = []
	for h: StringName in HEISTS:
		var a: Color = UiAccent.for_heist(h)
		var c: Color = ObjectivesPanel.caption_color(a)
		var r: float = UiAccent.contrast_ratio(c, ObjectivesPanel.WORLD_BG)
		print("%s accent %s -> caption %s, %.2f:1 (was %.2f:1)" % [h, a.to_html(false), c.to_html(false), r,
				UiAccent.contrast_ratio(a, ObjectivesPanel.WORLD_BG)])
		assert_true(r >= need - 0.01, "%s caption %.2f:1 over the scene (need %.1f)" % [h, r, need])
		if not c.is_equal_approx(a):
			lifted.append(h)
	assert_has(lifted, &"night_deposit", "ND's dark red is lifted")


func test_banner_listed_event_is_not_toasted() -> void:
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await wait_frames(1)
	var kinds: Array[StringName] = [&"turret_van"]
	hud.assault.set_events(kinds)
	hud.toast(&"ui.hud.assault_event.turret_van")
	assert_false(hud.toast_label.visible, "the banner already names it")
	hud.toast(&"ui.hud.assault_event.heli")
	assert_true(hud.toast_label.visible, "an event the banner doesn't list still toasts")
	hud.toast_label.visible = false
	hud.toast(&"ui.hud.alarm")
	assert_true(hud.toast_label.visible, "other toasts are untouched")
	hud.queue_free()
	await wait_frames(1)
