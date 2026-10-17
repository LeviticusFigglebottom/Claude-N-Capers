## Shared-resource drift guard for tests/b (LEAD r230, after A's tests/a/test_zz_shared_resource_drift.gd). Owner: ENV B.
## The runner loads test files in sorted order in one process; a test that writes to a cached content .tres (a
## WeaponDef, a WeaponModDef, a tweak, a HeistDef ...) without duplicate() / restore changes it for every later file
## (r230 known reds: kestrel_p9 gained a flashlight in test_gadgets_ammo). This file sorts last in tests/b: every
## content/data and heist-def .tres still in the ResourceLoader cache must equal a fresh load from disk, sub-resources
## included (a WeaponDef's `base` WeaponStats, a mod's `delta`: the r230 leak lived there, so the flat check of
## tests/a would miss it). Alone it checks nothing (nothing is cached).
extends TestCase

const ROOTS: Array[String] = ["res://content/data", "res://world/heists"]
const SKIP_PROPS: Array[String] = ["resource_path", "resource_name", "resource_local_to_scene", "script"]
const MAX_DEPTH: int = 3


func test_zz_no_cached_content_drifted() -> void:
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
		_compare(p, cached, fresh, drift, 0)
	print("[drift-b] %d cached resources checked, %d drifted" % [checked, drift.size()])
	for d: String in drift:
		print("[drift-b] " + d)
	assert_eq(drift, [] as Array[String], "no b test left a cached content resource changed (bisect with a filter)")


## Appends "<where>: <prop> = <cached> (on disk <fresh>)" for each stored property that differs; Resource values
## (and arrays of them) are compared recursively up to MAX_DEPTH, other objects are skipped.
func _compare(where: String, cached: Object, fresh: Object, drift: Array[String], depth: int) -> void:
	for prop: Dictionary in fresh.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var key: String = prop["name"]
		if SKIP_PROPS.has(key):
			continue
		_compare_value("%s: %s" % [where, key], cached.get(key), fresh.get(key), drift, depth)


func _compare_value(where: String, a: Variant, b: Variant, drift: Array[String], depth: int) -> void:
	if a is Resource and b is Resource:
		if depth < MAX_DEPTH and (a as Resource).resource_path == (b as Resource).resource_path:
			_compare(where, a as Object, b as Object, drift, depth + 1)
		return
	if a is Object or b is Object:
		return
	if a is Array and b is Array and (_has_objects(a) or _has_objects(b)):
		if (a as Array).size() != (b as Array).size():
			drift.append("%s: size %d (on disk %d)" % [where, (a as Array).size(), (b as Array).size()])
			return
		for i: int in range((a as Array).size()):
			_compare_value("%s[%d]" % [where, i], (a as Array)[i], (b as Array)[i], drift, depth)
		return
	if _has_objects(a) or _has_objects(b):
		return
	if a != b:
		drift.append("%s = %s (on disk %s)" % [where, str(a).left(80), str(b).left(80)])


func _collect(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("_") and not d.begins_with("."):
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
