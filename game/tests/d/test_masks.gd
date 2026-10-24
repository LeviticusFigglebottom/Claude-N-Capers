## D1-04: crew mask models (tools/blender/masks/). The mask glb has M_char_mask_* surfaces, a
## head-sized AABB and its pivot at the face centre with the front (beak) toward -Z.
## QB-50b: the five customisable base masks (content/docs/masks.md): one colour-neutral surface
## (the mask shader is applied as material_override), front-projected UV0 (x 0 = viewer's left
## = +X, y 0 = top), pivot at the face centre, -Z forward.
## B4-15: five more bases (skull, theatre, gasmask, demon, goalie) under the same contract.
## D3-03: twelve more bases (ram, stag, cat, boar, serpent, moth, knight, doll, sunburst, geo, robot,
## jester) under the same contract.
## D-111: eight more bases (kraken, lion, shark, pierrot, welder, wicker, lucha, signal), same contract.
## D-ACH: three achievement-reward bases (vault_dial, keystone, bust), same contract.
## RT-D2: two Rolling Thunder reward bases (road_cone, ingot), same contract.
## D-165: two Afterhours reward bases (vinyl, disco), same contract.
## D-073: every mask is fitted over the crew face envelope (tools/blender/masks/_face_envelope.py);
## the envelope must have been generated from the current crew heads.
## Run after `godot --import`.
extends TestCase

const MASK_PATH: String = "res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb"
const MATERIAL_PREFIX: String = "M_char_mask_"
const LIBRARY_PREFIX: String = "res://world/materials/char_mask_"
# QB-50b customisable base masks
const BASE_NAMES: Array[String] = [
	"heron", "visage", "vulpine", "bruiser", "owl", "skull", "theatre", "gasmask", "demon", "goalie",
	"ram", "stag", "cat", "boar", "serpent", "moth", "knight", "doll", "sunburst", "geo", "robot", "jester",
	"kraken", "lion", "shark", "pierrot", "welder", "wicker", "lucha", "signal",
	"vault_dial", "keystone", "bust", "road_cone", "ingot", "vinyl", "disco",
]
const BASE_MATERIAL: String = "M_char_mask_base"
const BASE_LIBRARY: String = "res://world/materials/char_mask_base.tres"
const BASE_TRI_BUDGET: int = 8000
## Masks whose front-most point is a centred beak/snout/nose/teeth/canister below the eye line.
const CENTRED_FRONT: Array[String] = [
	"heron", "visage", "vulpine", "owl", "skull", "theatre", "gasmask", "demon",
	"ram", "stag", "cat", "moth", "doll", "sunburst", "geo", "robot", "jester", "keystone", "bust",
]
## The respirator pushes well forward of the face (its filter canister); the boar's snout disc too.
const PROTRUDING_FRONT: Dictionary[String, float] = {"gasmask": -0.09, "boar": -0.08}
## Deliberately lopsided bases (D-111 signal: dish on one temple, aerial on the other): wider centring tolerance (m).
const OFF_CENTRE: Dictionary[String, float] = {"signal": 0.03}
## D-073 mask fit: the crew face envelope the mask generator pushes every shell out of.
const ENVELOPE_REL: String = "../tools/blender/masks/_crew_face_envelope.json"
const CHARACTERS_DIR: String = "res://assets/characters"
const STALE_HINT: String = (
	"regenerate _crew_face_envelope.json (blender -b --factory-startup --python "
	+ "tools/blender/masks/_face_envelope.py) and rebuild masks (tools/blender/build.py --category masks)"
)


func _load_mask() -> Node3D:
	var packed: PackedScene = load(MASK_PATH) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % MASK_PATH)
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes:
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Front-most vertex (most negative Z) across all surfaces, in the mask root's space.
func _front_point(meshes: Array[MeshInstance3D]) -> Vector3:
	var best: Vector3 = Vector3(0.0, 0.0, INF)
	for mi: MeshInstance3D in meshes:
		for s: int in range(mi.mesh.get_surface_count()):
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var w: Vector3 = mi.global_transform * v
				if w.z < best.z:
					best = w
	return best


func test_mask_has_char_mask_surfaces() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = _meshes(root)
	assert_true(meshes.size() > 0, "mask has at least one mesh")
	var names: Array[String] = []
	for mi: MeshInstance3D in meshes:
		for s: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(s)
			assert_true(m != null, "%s surface %d has a material" % [mi.name, s])
			if m == null:
				continue
			# placeholder keeps the M_ name; a library material comes from world/materials/char_mask_*
			var ok: bool = m.resource_name.begins_with(MATERIAL_PREFIX) or m.resource_path.begins_with(LIBRARY_PREFIX)
			assert_true(ok, "%s surface %d material %s / %s" % [mi.name, s, m.resource_name, m.resource_path])
			names.append(m.resource_name if m.resource_path.is_empty() else m.resource_path.get_file())
	assert_true(names.size() >= 2, "gold + lacquer (+ inner) surfaces, got %s" % [names])
	root.queue_free()


func test_mask_is_head_sized() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var box: AABB = _bounds(_meshes(root))
	assert_true(box.size.x >= 0.14 and box.size.x <= 0.30, "width %.3f m in 0.14..0.30" % box.size.x)
	assert_true(box.size.y >= 0.18 and box.size.y <= 0.32, "height %.3f m in 0.18..0.32" % box.size.y)
	assert_true(box.size.z <= 0.30, "depth %.3f m" % box.size.z)
	assert_near(box.get_center().x, 0.0, 0.002, "mask is symmetric about x = 0")
	root.queue_free()


func test_pivot_is_face_centre_and_front_is_minus_z() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = _meshes(root)
	var box: AABB = _bounds(meshes)
	assert_true(box.position.x < 0.0 and box.end.x > 0.0, "origin inside the mask in X")
	assert_true(box.position.y < -0.05 and box.end.y > 0.05, "origin near the eye line, between brow and chin")
	assert_true(box.position.z < 0.0 and box.end.z > 0.0, "origin at eye depth, inside the shell's depth range")
	assert_true(-box.position.z > box.end.z, "the mask extends further to -Z (front) than to +Z")
	var tip: Vector3 = _front_point(meshes)
	assert_true(tip.z < -0.10, "beak tip well in front of the face (z = %.3f)" % tip.z)
	assert_near(tip.x, 0.0, 0.002, "beak tip on the centreline")
	assert_true(tip.y < 0.0, "beak points forward and down (y = %.3f)" % tip.y)
	root.queue_free()


# --- QB-50b customisable base masks ------------------------------------------------------------


func _base_path(base_name: String) -> String:
	return "res://assets/masks/mask_base_%s/mask_base_%s.glb" % [base_name, base_name]


func _load_base(base_name: String) -> Node3D:
	var packed: PackedScene = load(_base_path(base_name)) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % _base_path(base_name))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func test_base_masks_have_one_neutral_surface() -> void:
	for base_name: String in BASE_NAMES:
		var root: Node3D = _load_base(base_name)
		if root == null:
			continue
		var surfaces: int = 0
		var tris: int = 0
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				surfaces += 1
				var m: Material = mi.mesh.surface_get_material(s)
				var mat_name: String = "" if m == null else m.resource_name
				# placeholder M_char_mask_base, or the library world/materials/char_mask_base.tres once it exists
				var ok: bool = mat_name == BASE_MATERIAL or (m != null and m.resource_path == BASE_LIBRARY)
				assert_true(ok, "%s surface %d material %s (want %s)" % [base_name, s, mat_name, BASE_MATERIAL])
				var idx: PackedInt32Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3
		assert_eq(surfaces, 1, "%s has exactly one surface (masks.md)" % base_name)
		assert_true(tris > 1000 and tris <= BASE_TRI_BUDGET, "%s tris %d in 1000..%d" % [base_name, tris, BASE_TRI_BUDGET])
		root.queue_free()


func test_base_masks_are_head_sized_and_symmetric() -> void:
	for base_name: String in BASE_NAMES:
		var root: Node3D = _load_base(base_name)
		if root == null:
			continue
		var box: AABB = _bounds(_meshes(root))
		assert_true(box.size.x >= 0.14 and box.size.x <= 0.30, "%s width %.3f m in 0.14..0.30" % [base_name, box.size.x])
		assert_true(box.size.y >= 0.18 and box.size.y <= 0.32, "%s height %.3f m in 0.18..0.32" % [base_name, box.size.y])
		assert_true(box.size.z >= 0.04 and box.size.z <= 0.30, "%s depth %.3f m in 0.04..0.30" % [base_name, box.size.z])
		var tol: float = OFF_CENTRE.get(base_name, 0.002)
		assert_near(box.get_center().x, 0.0, tol, "%s is centred about x = 0 (tolerance %.3f)" % [base_name, tol])
		root.queue_free()


func test_base_masks_pivot_is_face_centre_and_front_is_minus_z() -> void:
	for base_name: String in BASE_NAMES:
		var root: Node3D = _load_base(base_name)
		if root == null:
			continue
		var meshes: Array[MeshInstance3D] = _meshes(root)
		var box: AABB = _bounds(meshes)
		assert_true(box.position.x < -0.05 and box.end.x > 0.05, "%s: origin inside the mask in X" % base_name)
		assert_true(box.position.y < -0.07 and box.end.y > 0.07, "%s: origin on the eye line, between brow and chin" % base_name)
		assert_true(box.position.z < 0.0 and box.end.z > 0.0, "%s: origin at eye depth, inside the depth range" % base_name)
		assert_true(-box.position.z > box.end.z, "%s extends further to -Z (front) than to +Z" % base_name)
		var tip: Vector3 = _front_point(meshes)
		assert_true(tip.z < -0.025, "%s front point in front of the face (z = %.3f)" % [base_name, tip.z])
		if PROTRUDING_FRONT.has(base_name):
			var want: float = PROTRUDING_FRONT[base_name]
			assert_true(tip.z < want, "%s protrudes forward (front z = %.3f < %.3f)" % [base_name, tip.z, want])
		if base_name in CENTRED_FRONT:
			assert_near(tip.x, 0.0, 0.003, "%s front point on the centreline" % base_name)
			assert_true(tip.y < 0.0, "%s beak/snout/nose below the eye line (y = %.3f)" % [base_name, tip.y])
		root.queue_free()


## UV0 per masks.md: front planar, x 0 = viewer's left (+X) .. 1, y 0 = top .. 1 = bottom, 0..1.
func test_base_masks_uv0_is_front_projected() -> void:
	for base_name: String in BASE_NAMES:
		var root: Node3D = _load_base(base_name)
		if root == null:
			continue
		var box: AABB = _bounds(_meshes(root))
		var uv_min: Vector2 = Vector2(INF, INF)
		var uv_max: Vector2 = Vector2(-INF, -INF)
		var worst: float = 0.0
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				assert_eq(uvs.size(), verts.size(), "%s has UV0" % base_name)
				if uvs.size() != verts.size():
					continue
				for i: int in range(verts.size()):
					var w: Vector3 = mi.global_transform * verts[i]
					var uv: Vector2 = uvs[i]
					uv_min = Vector2(minf(uv_min.x, uv.x), minf(uv_min.y, uv.y))
					uv_max = Vector2(maxf(uv_max.x, uv.x), maxf(uv_max.y, uv.y))
					# expected planar projection along Z, normalised to the bounds
					var ex: float = 0.5 - 0.5 * w.x / maxf(absf(box.position.x), absf(box.end.x))
					var ey: float = (box.end.y - w.y) / box.size.y
					worst = maxf(worst, maxf(absf(uv.x - ex), absf(uv.y - ey)))
		assert_true(uv_min.x > -0.001 and uv_min.y > -0.001, "%s UV0 min %s >= 0" % [base_name, uv_min])
		assert_true(uv_max.x < 1.001 and uv_max.y < 1.001, "%s UV0 max %s <= 1" % [base_name, uv_max])
		# x = 0 maps to u 0.5 exactly (patterns stay centred on the face), so a lopsided base reaches only
		# one end of the U range
		var u_span: bool = (uv_min.x < 0.01 or uv_max.x > 0.99) if OFF_CENTRE.has(base_name) \
			else (uv_min.x < 0.01 and uv_max.x > 0.99)
		assert_true(u_span and uv_min.y < 0.01 and uv_max.y > 0.99,
			"%s UV0 spans 0..1 (%s..%s)" % [base_name, uv_min, uv_max])
		assert_true(worst < 0.005, "%s UV0 = front projection (x 0 at +X, y 0 at top); max error %.4f" % [base_name, worst])
		root.queue_free()


## D-073: the mask fit is only valid for the crew heads it was measured on. The envelope stores the
## sha256 of every crew glb; any crew head change must regenerate it and rebuild the masks.
func test_crew_face_envelope_matches_current_crew() -> void:
	var path: String = ProjectSettings.globalize_path("res://").path_join(ENVELOPE_REL)
	if not FileAccess.file_exists(path):
		fail("missing %s: %s" % [path, STALE_HINT])
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not ((data as Dictionary).get("crew_sha256") is Dictionary):
		fail("%s has no crew_sha256: %s" % [path, STALE_HINT])
		return
	var stored: Dictionary = (data as Dictionary)["crew_sha256"]
	var crew: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(CHARACTERS_DIR):
		if dir_name.begins_with("char_crew_"):
			crew.append(dir_name)
	assert_true(crew.size() >= 6, "found the crew glbs (%d)" % crew.size())
	for cid: String in crew:
		var glb: String = "%s/%s/%s.glb" % [CHARACTERS_DIR, cid, cid]
		assert_true(stored.has(cid), "envelope covers %s: %s" % [cid, STALE_HINT])
		assert_eq(FileAccess.get_sha256(glb), String(stored.get(cid, "")),
			"%s sha256 matches the envelope: %s" % [cid, STALE_HINT])
