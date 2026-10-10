## Headless test runner. Owner: LEAD.
## godot --headless --path game res://tests/framework/runner.tscn -- [--dir=a] [--filter=substr] [--junit=path]
## Discovers res://tests/<dir>/**/test_*.gd. Exit code 0 = all passed.
extends Node

const ROOT: String = "res://tests"


func _ready() -> void:
	var args: Dictionary = _parse(OS.get_cmdline_user_args())
	var dirs: Array[String] = []
	if args.has("dir"):
		for d: String in String(args["dir"]).split(","):
			dirs.append("%s/%s" % [ROOT, d])
	else:
		for d: String in ["a", "b", "c", "d", "integration", "lead"]:
			dirs.append("%s/%s" % [ROOT, d])
	var files: Array[String] = []
	for d: String in dirs:
		_collect(d, files)
	files.sort()
	var filter: String = String(args.get("filter", ""))
	var total: int = 0
	var failed: int = 0
	var skipped: int = 0
	var lines: Array[String] = []
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null:
			lines.append("LOAD FAIL %s" % path)
			failed += 1
			continue
		var inst: Object = script.new()
		var tc: TestCase = inst as TestCase
		if tc == null:
			lines.append("SKIP %s (does not extend TestCase)" % path)
			continue
		add_child(tc)
		await tc.before_all()
		for m: Dictionary in tc.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			if filter != "" and not (path + ":" + mname).contains(filter):
				continue
			total += 1
			tc._failures.clear()
			tc._skipped = ""
			tc._current = "%s:%s" % [path.get_file(), mname]
			await tc.before_each()
			await tc.call(mname)
			await tc.after_each()
			if tc._skipped != "" and tc._failures.is_empty():
				skipped += 1
				lines.append("SKIP %s (%s)" % [tc._current, tc._skipped])
			elif tc._failures.is_empty():
				lines.append("PASS %s" % tc._current)
			else:
				failed += 1
				lines.append("FAIL %s" % tc._current)
				for f: String in tc._failures:
					lines.append("     %s" % f)
		await tc.after_all()
		tc.queue_free()
		await get_tree().process_frame
	for l: String in lines:
		print(l)
	print("== %d tests, %d failed, %d skipped ==" % [total, failed, skipped])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), out)


func _parse(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in argv:
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out
