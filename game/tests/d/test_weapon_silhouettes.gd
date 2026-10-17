## LEAD (k): far weapon silhouettes (world/characters/_tools/make_weapon_silhouettes.gd). Every NPC weapon id in ENV B's
## npc_weapon_models.tres has a silhouette scene in weapon_silhouettes.json; each is one MeshInstance3D with one
## surface, a small triangle count, no shadow, visible only from the CrowdLod unit switch on, and spans its armory
## model's length (Z) and height (Y) within 2 cm (the same weapon frame, so it sits in the hand like the model).
extends TestCase

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const MAP: String = "res://content/data/npc/npc_weapon_models.tres"
const INDEX: String = "res://world/characters/_props/weapon_silhouettes/weapon_silhouettes.json"
const MAX_TRIS: int = 300
const TOL: float = 0.02

var _index: Dictionary = {}


func before_all() -> void:
	_index = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) as Dictionary


func test_every_npc_weapon_has_a_silhouette() -> void:
	var models: Dictionary = load(MAP).get("models") as Dictionary
	var sil: Dictionary = _index.get("silhouettes", {}) as Dictionary
	assert_eq(float(_index.get("switch_m", 0.0)), CrowdLod.UNIT_SWITCH_M, "switch_m = CrowdLod.UNIT_SWITCH_M")
	for id: Variant in models:
		assert_true(sil.has(String(id)), "%s: has a silhouette" % id)
		assert_true(ResourceLoader.exists(String(sil.get(String(id), ""))), "%s: silhouette scene exists" % id)


func test_silhouettes_are_cheap_and_far_only() -> void:
	for id: String in (_index.get("silhouettes", {}) as Dictionary):
		var mi: MeshInstance3D = (load(String(_index["silhouettes"][id])) as PackedScene).instantiate() as MeshInstance3D
		assert_true(mi != null and mi.mesh != null, "%s: one MeshInstance3D with a mesh" % id)
		if mi == null or mi.mesh == null:
			continue
		assert_eq(mi.get_child_count(), 0, "%s: a single node" % id)
		assert_eq(mi.mesh.get_surface_count(), 1, "%s: one surface (one draw)" % id)
		var tris: int = (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		assert_true(tris > 0 and tris <= MAX_TRIS, "%s: %d tris (<= %d)" % [id, tris, MAX_TRIS])
		assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: no shadow" % id)
		assert_eq(mi.visibility_range_begin, CrowdLod.UNIT_SWITCH_M, "%s: from the unit switch on" % id)
		mi.free()


func test_silhouettes_span_their_model() -> void:
	var models: Dictionary = load(MAP).get("models") as Dictionary
	for id: Variant in models:
		var model_id: String = String(models[id]).trim_prefix("weapon.")
		var def: Resource = load("res://content/data/weapons/%s.tres" % model_id)
		var path: String = String((_index.get("silhouettes", {}) as Dictionary).get(String(id), ""))
		if def == null or def.get("model") == null or not ResourceLoader.exists(path):
			continue
		var full: Node3D = (def.get("model") as PackedScene).instantiate() as Node3D
		var ab: AABB = _bounds(full, full)
		full.free()
		var mi: MeshInstance3D = (load(path) as PackedScene).instantiate() as MeshInstance3D
		var sb: AABB = mi.mesh.get_aabb()
		mi.free()
		for axis: int in [1, 2]:
			assert_true(absf(sb.position[axis] - ab.position[axis]) <= TOL and absf(sb.end[axis] - ab.end[axis]) <= TOL,
					"%s: silhouette spans the model on axis %d (%s vs %s)" % [id, axis, sb, ab])


func _bounds(n: Node, top: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != top:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
