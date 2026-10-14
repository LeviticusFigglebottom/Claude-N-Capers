## Shared helpers for the validate_level tests (not a test file itself). Owner: ENV C.
class_name LcTestBase
extends TestCase

const GOOD: String = "res://tests/c/fixtures/lc_fixture_good.tscn"
const BAD: String = "res://tests/c/fixtures/lc_fixture_bad.tscn"
const KITS: String = "res://tests/c/fixtures/kits"
## Bad fixture: check -> node names that must appear in that check's failures.
const BAD_EXPECT: Dictionary = {
	"floating": ["FloatBox"],
	"clipping": ["WallClipBox"],
	"lights": ["BareLight"],
	# PO-8: an untagged interior key light fails `viewmodel_lit` (no layer 21)
	"viewmodel_lit": ["BareLight"],
	"materials": ["NullMatMesh"],
	"reachability": ["PlayerSpawn5"],
	"walkthrough": ["PlayerSpawn5"],
	"patrols": ["LonelyPoint"],
	# WallClipBox's base is coplanar with the wall it penetrates: a true z-fight.
	"zfight": ["WallClipBox"],
}


## Loads a fixture, lets `mutate` edit it before it enters the tree, runs the checks.
func _validate(path: String, stage: String, mutate: Callable = Callable(), variants_all: bool = false,
		only: PackedStringArray = PackedStringArray()) -> Dictionary:
	var map: HeistMap = (load(path) as PackedScene).instantiate() as HeistMap
	if mutate.is_valid():
		mutate.call(map)
	var ctx: LcContext = await LcRunner.prepare(map, self)
	ctx.stage = stage
	ctx.variants_all = variants_all
	ctx.kit_dirs.append(KITS)
	var checks: Array[LcCheck] = await LcRunner.run(ctx, only)
	var out: Dictionary = {}
	for c: LcCheck in checks:
		if c.skipped_reason == "":
			var lines: PackedStringArray = PackedStringArray()
			for i: Dictionary in c.sorted_issues():
				if i["severity"] == LcCheck.SEV_FAIL:
					lines.append(LcCheck.issue_line(i))
			out[String(c.id)] = lines
	remove_child(map)
	map.free()
	await wait_physics_frames(2)
	return out


static func _failed(res: Dictionary) -> PackedStringArray:
	var f: PackedStringArray = PackedStringArray()
	for k: String in res.keys():
		if not (res[k] as PackedStringArray).is_empty():
			f.append(k)
	f.sort()
	return f


func _expect_fail(res: Dictionary, check: String, needle: String) -> void:
	var lines: PackedStringArray = res.get(check, PackedStringArray())
	for l: String in lines:
		if l.contains(needle):
			return
	fail("expected %s to fail mentioning `%s`; got %s" % [check, needle, lines])


func _expect_only(res: Dictionary, checks: Array) -> void:
	var want: PackedStringArray = PackedStringArray(checks)
	want.sort()
	assert_eq(_failed(res), want, "failed checks; details: %s" % [res])
