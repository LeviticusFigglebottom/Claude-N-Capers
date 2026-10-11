## B4-12: the Marshal revolver's `Speedloader` (visual_slots.md "weapons, revolver", D-053) and the import
## sidecars of every weapon/mod model (each .glb must import through the material-library post-import script).
extends TestCase

const WEAPONS_DIR: String = "res://assets/weapons"
const POST_IMPORT_LINE: String = "import_script/path=\"res://world/tools/import/glb_post_import.gd\""
## Rounds must sit on the chamber centres within this distance (metres).
const CHAMBER_TOL: float = 0.0005


func before_all() -> void:
	ContentDB.clear_cache()


func _marshal() -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(&"weapon.marshal_357", [] as Array[StringName])
	return v


## The speedloader hangs off the model root (it rides the FP `magazine` bone, not the crane), its frame is the
## closed cylinder's `Magwell` (rear face on the axis, insertion axis forward), and its six rounds sit on the
## chamber pattern: the top chamber in line with the bore, the others every 60 degrees about the cylinder axis.
func test_marshal_speedloader_seated_on_the_chambers() -> void:
	var v: WeaponVisual = _marshal()
	var loader: Node3D = v.model.find_child("Speedloader", true, false) as Node3D
	var cyl: Node3D = v.model.find_child("Cylinder", true, false) as Node3D
	assert_true(loader != null and cyl != null, "Speedloader and Cylinder nodes")
	if loader == null or cyl == null:
		v.queue_free()
		return
	assert_true(loader.get_parent() == v.model, "Speedloader at the model root")
	var magwell: Node3D = v.get_base_marker(&"Magwell")
	assert_true(loader.global_position.distance_to(magwell.global_position) < 0.0001, "origin = the closed Magwell")
	assert_true(loader.global_basis.is_equal_approx(magwell.global_basis), "frame = the closed Magwell frame")
	var rounds: MeshInstance3D = loader.find_child("SpeedloaderRounds", true, false) as MeshInstance3D
	assert_true(rounds != null and rounds.mesh != null, "SpeedloaderRounds mesh")
	if rounds == null or rounds.mesh == null:
		v.queue_free()
		return
	var inv: Transform3D = cyl.global_transform.affine_inverse()
	var bore: Vector3 = inv * v.get_base_marker(&"Muzzle").global_position
	var top: Vector2 = Vector2(bore.x, bore.y)
	assert_true(top.length() > 0.008, "the bore is off the cylinder axis (%s)" % top)
	var sums: Array[Vector2] = []
	var counts: Array[int] = []
	for i: int in 6:
		sums.append(Vector2.ZERO)
		counts.append(0)
	var to_cyl: Transform3D = inv * rounds.global_transform
	for p: Vector3 in rounds.mesh.get_faces():
		var q: Vector3 = to_cyl * p
		var xy: Vector2 = Vector2(q.x, q.y)
		var best: int = 0
		for i: int in 6:
			if xy.distance_to(top.rotated(TAU * i / 6.0)) < xy.distance_to(top.rotated(TAU * best / 6.0)):
				best = i
		sums[best] += xy
		counts[best] += 1
	for i: int in 6:
		assert_true(counts[i] > 0, "a round in chamber %d" % i)
		if counts[i] > 0:
			var c: Vector2 = sums[i] / float(counts[i])
			assert_true(c.distance_to(top.rotated(TAU * i / 6.0)) < CHAMBER_TOL,
				"round %d on its chamber (%s vs %s)" % [i, c, top.rotated(TAU * i / 6.0)])
	v.queue_free()


## D-053: the speedloader is hidden until a reload shows it (WeaponVisual hides HIDDEN_AT_REST parts on setup;
## glTF carries no visibility flag).
func test_marshal_speedloader_hidden_by_default() -> void:
	var v: WeaponVisual = _marshal()
	var loader: Node3D = v.model.find_child("Speedloader", true, false) as Node3D
	assert_true(loader != null, "Speedloader node")
	if loader != null:
		assert_false(loader.visible, "hidden at rest")
	v.queue_free()


## Every weapon/mod .glb.import runs the material-library post-import script (batch-2 mods once had it empty).
func test_every_weapon_glb_import_uses_the_post_import_script() -> void:
	var files: Array[String] = []
	_collect_imports(WEAPONS_DIR, files)
	assert_true(files.size() > 100, "found the weapon .glb.import files (%d)" % files.size())
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(text.split("\n").has(POST_IMPORT_LINE), "%s imports through glb_post_import.gd" % path)


func _collect_imports(dir_path: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".glb.import"):
			out.append(dir_path.path_join(f))
	for d: String in DirAccess.get_directories_at(dir_path):
		_collect_imports(dir_path.path_join(d), out)
