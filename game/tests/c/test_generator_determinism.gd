## The map generators are the source of the heist scenes (level_standards §6b): every one must be
## byte-stable. Each generator runs twice in its own headless Godot process (`-- --out=<scratch>`), the
## two scenes must be byte-identical, and they must equal the committed scene (no hand edits, no stale
## regen). PO-9: KitPlacer sorted StringName keys with Array.sort(), which orders StringNames by interned
## pointer, so dressing drifted between regens. Owner: ENV C. Slow (10 generator runs, about two minutes).
## Gallery Night joined at G1 step 2 (GN-C1; this replaces tools/levelcheck/gn_regen_twice.sh).
extends TestCase

const HEISTS: Array[String] = ["glasshouse", "night_deposit", "dockside_burn", "shadow_ledger", "gallery_night"]
const SCRATCH: String = "user://gen_determinism"


func test_generators_are_byte_stable() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	for h: String in HEISTS:
		var gen: String = "res://world/heists/%s/greybox/build_greybox.gd" % h
		if not ResourceLoader.exists(gen):
			fail("%s: generator missing" % h)
			continue
		var outs: Array[PackedByteArray] = []
		for run: String in ["a", "b"]:
			var path: String = ProjectSettings.globalize_path("%s/%s_%s.tscn" % [SCRATCH, h, run])
			DirAccess.remove_absolute(path)
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
				ProjectSettings.globalize_path("res://"), "--script", gen, "--", "--out=" + path], output, true)
			if code != 0 or not FileAccess.file_exists(path):
				fail("%s run %s: generator exit %d\n%s" % [h, run, code, "\n".join(output).right(2000)])
				break
			outs.append(FileAccess.get_file_as_bytes(path))
		if outs.size() != 2:
			continue
		assert_true(outs[0] == outs[1], "%s: two regens differ (non-deterministic generator)" % h)
		var committed: PackedByteArray = FileAccess.get_file_as_bytes("res://world/heists/%s/%s.tscn" % [h, h])
		assert_true(outs[0] == committed,
			"%s: committed scene differs from its generator output (regenerate, never hand-edit)" % h)
