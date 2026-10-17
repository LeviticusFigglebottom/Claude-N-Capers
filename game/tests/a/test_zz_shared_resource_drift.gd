## Shared-resource drift guard (LEAD follow-up to the round-229 DifficultyDef leak). Owner: ENV A.
## The runner loads test files in sorted order in one process, and a test that writes to a cached .tres (Tweak.*(),
## *Tweak.data(), a DifficultyDef, an EnemyDef) without duplicate() / restore changes it for every later file:
## test_s2_detection_meter's detection_speed_mult = 2.0 halved test_s3_8_cameras' crouch delay in the gate.
## This file sorts last in tests/a: every systems / difficulty .tres still in the ResourceLoader cache must equal a
## fresh load from disk (scalar and array properties; sub-resources are skipped). A drift names the resource and the
## property, so the leaking test can be found with a filter bisect. Running it alone checks nothing (nothing cached).
extends TestCase

const ROOTS: Array[String] = ["res://systems", "res://content/data/difficulty"]


func test_zz_no_cached_tweak_or_def_drifted() -> void:
	var paths: Array[String] = []
	for r: String in ROOTS:
		_collect(r, paths)
	var checked: int = 0
	var drift: Array[String] = []
	for p: String in paths:
		if not ResourceLoader.has_cached(p):
			continue
		var cached: Resource = load(p)
		var fresh: Resource = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cached == null or fresh == null:
			continue
		checked += 1
		for prop: Dictionary in fresh.get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_STORAGE == 0:
				continue
			var key: String = prop["name"]
			if key in ["resource_path", "resource_name", "resource_local_to_scene", "script"]:
				continue
			var a: Variant = cached.get(key)
			var b: Variant = fresh.get(key)
			if a is Object or b is Object or _has_objects(a) or _has_objects(b):
				continue
			if a != b:
				drift.append("%s: %s = %s (on disk %s)" % [p, key, str(a).left(80), str(b).left(80)])
	print("[drift] %d cached resources checked, %d drifted" % [checked, drift.size()])
	for d: String in drift:
		print("[drift] " + d)
	assert_eq(drift, [] as Array[String], "no test left a cached tweak / def changed (bisect with a filter)")


func _collect(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


## Arrays / dictionaries holding resources compare by instance: skip them.
func _has_objects(v: Variant) -> bool:
	if v is Array:
		for e: Variant in v:
			if e is Object:
				return true
	elif v is Dictionary:
		for k: Variant in v:
			if k is Object or v[k] is Object:
				return true
	return false
