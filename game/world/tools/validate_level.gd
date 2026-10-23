## validate_level: the automated level gate (level_standards §7). Owner: ENV C.
## godot --headless --path game res://world/tools/validate_level.tscn -- --heist=<id>
##   --stage=<greybox|final> [--variants=all] [--report=<path>] [--scene=<res path>]
##   [--only=check1,check2] [--walkthrough-report=<path>] [--kits=<res dir>,...] [--timeout=<s>] [--profile=hub]
## --profile=hub: the safehouse hub (hub_map.md; a data-only HeistMap): the hub contract nodes, no heist-only checks.
## Exit code 0 = pass, 1 = fail, 2 = usage/load error, 3 = timeout/crash (watchdog).
## See tools/levelcheck/README.md.
extends Node


func _ready() -> void:
	_main.call_deferred()


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()


func _main() -> void:
	var t0: int = Time.get_ticks_msec()
	var args: Dictionary = parse_args(OS.get_cmdline_user_args())
	# Watchdog: a script error inside a coroutine would otherwise hang CI forever.
	var dog: Timer = Timer.new()
	dog.one_shot = true
	dog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dog)
	dog.timeout.connect(func() -> void: _quit(3, "validate_level: TIMEOUT/CRASH (watchdog %s s)" % dog.wait_time))
	dog.start(float(args.get("timeout", "600")))
	var heist: String = String(args.get("heist", ""))
	var stage: String = String(args.get("stage", "greybox"))
	var scene_path: String = String(args.get("scene", ""))
	if stage != "greybox" and stage != "final":
		_quit(2, "usage: --stage must be greybox or final")
		return
	if scene_path == "":
		if heist == "":
			_quit(2, "usage: --heist=<id> or --scene=<res path> required")
			return
		scene_path = "res://world/heists/%s/%s.tscn" % [heist, heist]
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		_quit(2, "cannot load %s" % scene_path)
		return
	var map: HeistMap = ps.instantiate() as HeistMap
	if map == null:
		_quit(1, "FAIL contract_nodes: root of %s is not a HeistMap" % scene_path)
		return
	var ctx: LcContext = await LcRunner.prepare(map, self)
	ctx.heist_id = heist
	ctx.stage = stage
	ctx.variants_all = String(args.get("variants", "")) == "all"
	ctx.profile = String(args.get("profile", ""))
	if args.has("kits"):
		for d: String in String(args["kits"]).split(",", false):
			ctx.kit_dirs.append(d)
	var root: String = repo_root()
	var report: String = String(args.get("report", ""))
	var wt: String = String(args.get("walkthrough-report", ""))
	if heist != "" and not args.has("scene"):
		# A partial run (--only) never overwrites the full validation report unless asked to.
		if report == "" and not args.has("only"):
			report = root.path_join("docs/levels/%s/validation.md" % heist)
		if wt == "":
			wt = root.path_join("docs/levels/%s/walkthrough.md" % heist)
		var wl: String = "res://world/heists/%s/walkthrough_whitelist.txt" % heist
		if FileAccess.file_exists(wl):
			ctx.walkthrough_whitelist = FileAccess.get_file_as_string(wl).split("\n", false)
	ctx.walkthrough_report = wt
	var only: PackedStringArray = PackedStringArray()
	if args.has("only"):
		only = String(args["only"]).split(",", false)
	var checks: Array[LcCheck] = await LcRunner.run(ctx, only)
	var failed: PackedStringArray = LcRunner.failed_checks(checks)
	for c: LcCheck in checks:
		if c.skipped_reason != "":
			print("  %-14s skipped (%s)" % [c.id, c.skipped_reason])
			continue
		print("  %-14s %s  fails=%d warns=%d  %d ms" % [c.id, "PASS" if c.passed() else "FAIL", c.fail_count(),
			c.warn_count(), c.elapsed_ms])
		for i: Dictionary in c.sorted_issues():
			print("      " + LcCheck.issue_line(i))
	if report != "":
		if not report.is_absolute_path():
			report = root.path_join(report)
		DirAccess.make_dir_recursive_absolute(report.get_base_dir())
		var f: FileAccess = FileAccess.open(report, FileAccess.WRITE)
		if f != null:
			f.store_string(LcRunner.report_markdown(ctx, checks))
			f.close()
			print("report: %s" % report)
	var label: String = heist if heist != "" else scene_path
	var verdict: String = "PASS" if failed.is_empty() else "FAIL (%s)" % ", ".join(failed)
	_quit(0 if failed.is_empty() else 1, "validate_level %s [%s]: %s in %.1f s" % [label, stage, verdict,
		float(Time.get_ticks_msec() - t0) / 1000.0])


func _quit(code: int, msg: String) -> void:
	if code == 2:
		push_error(msg)
	print(msg)
	get_tree().quit(code)
