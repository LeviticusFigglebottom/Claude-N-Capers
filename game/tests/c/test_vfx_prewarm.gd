## VfxDirector.prewarm (ENV A's HITCH root cause, PO-7): every pool is built to its cap at heist load, so shots during
## a fight create no nodes (a new GPU resource mid-fight stalled llvmpipe for seconds). Idempotent. Headless.
extends TestCase

var _vfx: VfxDirector


func before_each() -> void:
	VfxSettings.reset()
	GameRng.begin_run(7)
	_vfx = (load("res://world/vfx/vfx_director.tscn") as PackedScene).instantiate() as VfxDirector
	_vfx.auto_advance = false
	add_child(_vfx)


func after_each() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()
	VfxSettings.reset()


func _nodes(n: Node) -> int:
	return n.get_child_count(true) + n.find_children("*", "", true, false).size()


func test_prewarm_fills_caps_and_is_idempotent() -> void:
	_vfx.prewarm()
	assert_eq(_vfx.muzzles.set_count(), _vfx.muzzles.cap(), "muzzle sets at cap")
	var n: int = _nodes(_vfx)
	_vfx.prewarm()
	assert_eq(_nodes(_vfx), n, "a second prewarm builds nothing")


func test_shots_after_prewarm_add_no_nodes() -> void:
	_vfx.prewarm()
	var n: int = _nodes(_vfx)
	for i: int in range(60):
		var o: Vector3 = Vector3(float(i % 6), 1.4, -float(i / 6))
		_vfx.on_shot_fx(o, o + Vector3(0, 0, -10), Vector3.BACK, &"concrete", [&"rifle", &"pistol", &"shotgun"][i % 3], 100 + i % 5, 0)
		_vfx.advance(0.016)
	assert_eq(_nodes(_vfx), n, "60 NPC shots after prewarm: no new nodes")
