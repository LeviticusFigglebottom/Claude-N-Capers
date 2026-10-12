## Firing-range aim look is resolution independent (like Env P's 1328183f): N mouse counts turn exactly
## N x mouse_look_deg_per_px. The event carries `relative` scaled 30x (what headless canvas_items stretch
## produces; 1.5x at 720p), so this fails if RangeSpectator ever goes back to `relative`.
extends TestCase

const TWEAK_PATH: String = "res://content/data/range/range_tweak.tres"


func _motion(counts: Vector2, stretch: float) -> InputEventMouseMotion:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.screen_relative = counts
	m.relative = counts * stretch
	return m


func test_degrees_per_mouse_count() -> void:
	var sp: RangeSpectator = RangeSpectator.new()
	sp.tweak = load(TWEAK_PATH) as RangeTweak
	add_child(sp)
	await wait_frames(1)
	sp.set_aim_active(true)
	var per: float = sp.tweak.mouse_look_deg_per_px
	assert_true(per > 0.0)
	var y0: float = sp.rotation.y
	sp._unhandled_input(_motion(Vector2(-400.0, 0.0), 30.0))
	assert_near(rad_to_deg(sp.rotation.y - y0), 400.0 * per, 1e-3, "400 counts left = %.2f deg" % (400.0 * per))
	var p0: float = sp.camera.rotation.x
	sp._unhandled_input(_motion(Vector2(0.0, -10.0), 1.5))
	assert_near(rad_to_deg(sp.camera.rotation.x - p0), 10.0 * per, 1e-3, "10 counts up")
	sp.set_aim_active(false)
	sp.queue_free()
	await wait_frames(1)
