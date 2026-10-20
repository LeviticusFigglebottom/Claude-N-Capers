## MultimeshTiles (world/props/multimesh_tiles.gd, OF-C2): filling never touches transform_format while instances
## exist ("Instance count must be 0 to change the transform format", logged 6x per OF load before the fix), and a
## re-fill (re-entering the tree, a scene-saved count) keeps the instances. The headless dummy renderer keeps no
## buffer, so the instance transforms are not read back here. Owner: ENV C.
extends TestCase

const TILES: GDScript = preload("res://world/props/multimesh_tiles.gd")


## Collects engine errors (OS.add_logger) so the test fails on the engine's own "transform format" error.
class ErrorTap:
	extends Logger
	var errors: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		errors.append("%s %s" % [code, rationale])


func _tiles(count_before: int, fmt: MultiMesh.TransformFormat) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = TILES.new() as MultiMeshInstance3D
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = fmt
	mm.mesh = BoxMesh.new()
	mm.instance_count = count_before
	mmi.multimesh = mm
	mmi.set(&"instances", PackedFloat32Array([1.0, 0.0, 2.0, 0.0, -1.0, 0.5, 3.0, PI * 0.5]))
	return mmi


func test_fill_keeps_instances_and_format() -> void:
	var tap: ErrorTap = ErrorTap.new()
	OS.add_logger(tap)
	for pre: Array in [[0, MultiMesh.TRANSFORM_2D], [2, MultiMesh.TRANSFORM_3D], [5, MultiMesh.TRANSFORM_2D]]:
		var mmi: MultiMeshInstance3D = _tiles(int(pre[0]), pre[1] as MultiMesh.TransformFormat)
		mmi.call(&"fill")
		mmi.call(&"fill")   # a second fill (re-entering the tree) with instances present
		assert_eq(mmi.multimesh.transform_format, MultiMesh.TRANSFORM_3D, "format after fill %s" % [pre])
		assert_eq(mmi.multimesh.instance_count, 2, "instance count after fill %s" % [pre])
		mmi.free()
	OS.remove_logger(tap)
	for e: String in tap.errors:
		assert_false(e.contains("transform format"), "engine error during fill: %s" % e)
