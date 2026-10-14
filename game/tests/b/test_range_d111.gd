## D-111 range polish ("the firing range still feels experimental"): aim mode keeps a small target card
## (RangeOverlay.AIM_ROWS), panel mode shows the full readout; the physical stats fold behind a toggle;
## per-target 3D labels fade with distance.
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"

var _range: FiringRange = null


func after_each() -> void:
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	await wait_frames(2)


func _spawn() -> FiringRange:
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	_range.use_fallback_shooter = true
	add_child(_range)
	await wait_frames(2)
	return _range


func _row_shown(o: RangeOverlay, id: String) -> bool:
	var v: Label = o.get(&"_values")[id] as Label
	return v.visible and (v.get_meta(&"name_label") as Label).visible


func test_aim_mode_shows_the_target_card_only() -> void:
	var r: FiringRange = await _spawn()
	var o: RangeOverlay = r.overlay
	o.set_interactive(false)
	for row: Array in RangeOverlay.READOUT_ROWS + RangeOverlay.LAST_SHOT_ROWS:
		var id: String = String(row[0])
		assert_eq(_row_shown(o, id), RangeOverlay.AIM_ROWS.has(id), "aim: %s" % id)
	o.set_interactive(true)
	for row: Array in RangeOverlay.READOUT_ROWS + RangeOverlay.LAST_SHOT_ROWS:
		assert_true(_row_shown(o, String(row[0])), "panel: %s" % row[0])


func test_physical_stats_fold_behind_details() -> void:
	var r: FiringRange = await _spawn()
	var o: RangeOverlay = r.overlay
	o.set_interactive(true)
	assert_false(o.value_text("phys_rpm") == "" , "values still filled while folded")
	assert_false((o.get(&"_values")["phys_rpm"] as Label).is_visible_in_tree(), "folded by default")
	assert_true(o.focus_chain.has(o.details_toggle))
	o.set_details_open(true)
	assert_true((o.get(&"_values")["phys_rpm"] as Label).is_visible_in_tree())
	assert_eq(o.details_toggle.text, UiText.t(&"ui.range.details_hide"))


func test_target_labels_fade_with_distance() -> void:
	var r: FiringRange = await _spawn()
	var faded: int = 0
	for n: Node in r.find_children("*", "Label3D", true, false):
		var l: Label3D = n as Label3D
		if l.visibility_range_end > 0.0:
			faded += 1
			assert_near(l.visibility_range_end, RangeBuilder.LABEL_FADE_M + 5.0, 0.001)
	assert_true(faded >= r.targets.size(), "every target's HP label fades (%d)" % faded)
