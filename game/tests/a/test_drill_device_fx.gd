## ENV C thermal-drill FX: DrillPoint drives the device's `Sparks` (emitting) and `Glow` (visible) on while RUNNING,
## off otherwise; a device without them is untouched.
extends TestCase


func test_sparks_and_glow_follow_running() -> void:
	var dev: Node3D = Node3D.new()
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.emitting = false
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "Glow"
	glow.visible = false
	dev.add_child(sparks)
	dev.add_child(glow)
	add_child(dev)
	DrillPoint.set_device_fx(dev, true)
	assert_true(sparks.emitting and glow.visible, "running: sparks + glow")
	DrillPoint.set_device_fx(dev, false)
	assert_false(sparks.emitting or glow.visible, "jammed / done: off")
	var bare: Node3D = Node3D.new()
	add_child(bare)
	DrillPoint.set_device_fx(bare, true)  # no FX nodes: no error
	assert_eq(bare.get_child_count(), 0, "a device without FX is untouched")
	dev.queue_free()
	bare.queue_free()
