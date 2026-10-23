## QB-50a: contact portrait busts for the briefing screen (ContactDef.portrait_scene /
## portrait_texture). Run after `godot --import` and the character assembly.
## * The contact characters (tools/blender/characters/char_contacts.py) are proper rig_humanoid
##   characters: 52 bones, skinned meshes without blend shapes, <= 35k triangles, library materials,
##   and an assembled world/characters/contact_<name>/ scene.
## * Each bust scene world/characters/portraits/<name>/<name>_portrait.tscn has a Node3D root (so
##   ContactPortrait renders it in a SubViewport), a Camera3D, a WorldEnvironment, lights and the
##   character, and its PortraitBust script poses the arms down and frames the head.
## * Each still assets/characters/portraits/<name>.png is a square 1024 x 1024 texture.
## * Each crew heister (D-073) has an unmasked square 1024 x 1024 picker still at the same path.
extends TestCase

const CONTACTS: Array[String] = ["odile", "hollis", "accountant"]
const HEISTERS: Array[String] = ["rook", "sable", "dutch", "wren", "marten", "jay", "juno", "hale"]
const BONES: int = 52
const TRI_BUDGET: int = 35000
const SIZE: int = 1024
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]


func _glb(n: String) -> String:
	return "res://assets/characters/char_contact_%s/char_contact_%s.glb" % [n, n]


func _scene(n: String) -> String:
	return "res://world/characters/portraits/%s/%s_portrait.tscn" % [n, n]


func _png(n: String) -> String:
	return "res://assets/characters/portraits/%s.png" % n


func _tris(mesh: Mesh) -> int:
	var t: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		t += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func test_contact_characters_are_rig_humanoid() -> void:
	for n: String in CONTACTS:
		var packed: PackedScene = load(_glb(n)) as PackedScene
		assert_true(packed != null, "%s: glb loads" % n)
		if packed == null:
			continue
		var root: Node3D = packed.instantiate() as Node3D
		add_child(root)
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Skeleton3D" % n)
		if skel != null:
			assert_eq(skel.get_bone_count(), BONES, "%s: bone count" % n)
		var tris: int = 0
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node as MeshInstance3D
			assert_has(ALLOWED_MESHES, String(mi.name), "%s: unexpected mesh %s" % [n, mi.name])
			assert_true(mi.skin != null, "%s/%s: skinned" % [n, mi.name])
			var am: ArrayMesh = mi.mesh as ArrayMesh
			if am != null:
				assert_eq(am.get_blend_shape_count(), 0, "%s/%s: no blend shapes" % [n, mi.name])
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(s)
				assert_true(m != null and m.resource_path.begins_with("res://world/materials/"),
						"%s/%s surface %d: library material" % [n, mi.name, s])
			tris += _tris(mi.mesh)
		assert_true(tris > 0 and tris <= TRI_BUDGET, "%s: %d triangles within %d" % [n, tris, TRI_BUDGET])
		root.queue_free()


func test_portrait_scenes_have_camera_lights_and_character() -> void:
	for n: String in CONTACTS:
		var packed: PackedScene = load(_scene(n)) as PackedScene
		assert_true(packed != null, "%s: portrait scene loads" % n)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		assert_true(root is Node3D, "%s: Node3D root (rendered in a SubViewport by ContactPortrait)" % n)
		assert_true(root is PortraitBust, "%s: PortraitBust script" % n)
		var cam: Camera3D = root.get_node_or_null("Camera3D") as Camera3D
		assert_true(cam != null, "%s: Camera3D" % n)
		assert_true(root.get_node_or_null("WorldEnvironment") is WorldEnvironment, "%s: WorldEnvironment" % n)
		var lights: Node = root.get_node_or_null("Lights")
		assert_true(lights != null and lights.get_child_count() >= 3, "%s: a light rig (>= 3 lights)" % n)
		var skel: Skeleton3D = root.get_node_or_null("Character/Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Character/Skeleton3D (assembled contact scene)" % n)
		if skel == null or cam == null:
			root.free()
			continue
		var arm: int = skel.find_bone("upper_arm.L")
		var rest_dir: Vector3 = _bone_dir(skel, arm)
		add_child(root)   # _ready: pose + framing
		var posed_dir: Vector3 = _bone_dir(skel, arm)
		assert_true(posed_dir.y < rest_dir.y - 0.2, "%s: arms posed down from the A-pose (%.2f -> %.2f)" % [
			n, rest_dir.y, posed_dir.y])
		var head: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head")).origin
		var to_head: Vector3 = (head - cam.global_position).normalized()
		assert_true(to_head.dot(-cam.global_basis.z) > 0.97, "%s: camera framed on the head" % n)
		var d: float = cam.global_position.distance_to(head)
		assert_true(d > 0.8 and d < 2.5, "%s: bust distance %.2f m" % [n, d])
		root.queue_free()


func _bone_dir(skel: Skeleton3D, bone: int) -> Vector3:
	var child: int = skel.get_bone_children(bone)[0]
	var a: Vector3 = skel.get_bone_global_pose(bone).origin
	var b: Vector3 = skel.get_bone_global_pose(child).origin
	return (b - a).normalized()


func test_portrait_textures_are_square_1024() -> void:
	for n: String in CONTACTS:
		var tex: Texture2D = load(_png(n)) as Texture2D
		assert_true(tex != null, "%s: portrait texture loads" % n)
		if tex == null:
			continue
		assert_eq(tex.get_width(), SIZE, "%s: width" % n)
		assert_eq(tex.get_height(), SIZE, "%s: height" % n)


## D-073: the crew heister picker portraits (Heisters.portrait loads `<portrait_dir>/<id>.png`):
## one unmasked 1024 x 1024 still per roster heister (tools/blender/characters/_heister_portrait.py).
func test_heister_portraits_are_square_1024() -> void:
	for n: String in HEISTERS:
		assert_true(ResourceLoader.exists(_png(n)), "%s: heister portrait exists" % n)
		var tex: Texture2D = load(_png(n)) as Texture2D
		assert_true(tex != null, "%s: heister portrait loads as Texture2D" % n)
		if tex == null:
			continue
		assert_eq(tex.get_width(), SIZE, "%s: width" % n)
		assert_eq(tex.get_height(), SIZE, "%s: height" % n)
