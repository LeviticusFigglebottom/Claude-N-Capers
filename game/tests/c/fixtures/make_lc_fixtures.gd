## Regenerates lc_fixture_good.tscn / lc_fixture_bad.tscn (navmesh baked in).
## /opt/godot/godot --headless --path game --script res://tests/c/fixtures/make_lc_fixtures.gd
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for bad: bool in [false, true]:
		var map: HeistMap = LcFixtureBuilder.build(bad)
		root.add_child(map)
		await physics_frame
		LcFixtureBuilder.bake(map)
		print("%s: %d nav polygons" % [map.name, map.get_node("Navigation").navigation_mesh.get_polygon_count()])
		var ps: PackedScene = PackedScene.new()
		var err: int = ps.pack(map)
		var path: String = "res://tests/c/fixtures/lc_fixture_%s.tscn" % ("bad" if bad else "good")
		if err == OK:
			err = ResourceSaver.save(ps, path)
		print("%s -> %s (%s)" % [map.name, path, error_string(err)])
		root.remove_child(map)
		map.free()
	quit()
