## Lead round 215 (range label clutter): only the targets nearest the crosshair plus the readout lane show their
## HP / distance / name labels.
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"

var _range: FiringRange = null


func after_each() -> void:
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	await wait_frames(2)


func test_only_targets_near_the_crosshair_show_labels() -> void:
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	_range.use_fallback_shooter = true
	add_child(_range)
	await wait_frames(3)
	var cam: Camera3D = get_viewport().get_camera_3d()
	assert_true(cam != null, "range camera")
	var aimed: RangeTarget = _range.targets[_range.layout.lane_count() - 1]
	cam.look_at(aimed.zone_position(Enums.HitZone.BODY), Vector3.UP)
	var shown: Array[int] = _range.focus_labels(cam)
	assert_has(shown, aimed.lane, "the target under the crosshair keeps its labels")
	assert_has(shown, _range.readout_lane, "the readout lane keeps its labels")
	assert_true(shown.size() <= _range.tweak.label_focus_count + 1, "at most count + readout lane (%d)" % shown.size())
	assert_true(shown.size() < _range.targets.size(), "far lanes are hidden")
	var hidden: int = 0
	for t: RangeTarget in _range.targets:
		if not shown.has(t.lane):
			assert_false(t.labels_visible(), "lane %d hidden" % t.lane)
			for n: Variant in t.get_meta(&"signs", []):
				assert_false((n as Node3D).visible, "lane %d sign hidden" % t.lane)
			hidden += 1
	assert_true(hidden > 0)
	_range.tweak.label_focus_count = 0
	assert_eq(_range.focus_labels(cam).size(), _range.targets.size(), "count 0 = every label")
	_range.tweak.label_focus_count = 3
