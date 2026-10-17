extends SceneTree


func _initialize() -> void:
	for id: String in ["gallery_waiter", "security_officer"]:
		var ch: Node = (load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene).instantiate()
		var skel: Node = ch.get_node("Skeleton3D")
		for c: Node in skel.get_children():
			if not c is MeshInstance3D:
				continue
			var mi: MeshInstance3D = c
			var mesh: ArrayMesh = mi.mesh as ArrayMesh
			print("%s/%s surfaces=%d blend=%d shadow=%s layers=%d skin=%s" % [id, mi.name, mesh.get_surface_count(),
				mesh.get_blend_shape_count(), mesh.shadow_mesh.get_surface_count() if mesh.shadow_mesh else -1, mi.layers,
				mi.skin.resource_path if mi.skin else "-"])
			var surfs: Array = mesh.get("_surfaces")
			for si: int in mesh.get_surface_count():
				var s: Dictionary = surfs[si]
				var lods: Array = s.get("lods", [])
				var th: Array = []
				for k: int in range(0, lods.size(), 2):
					th.append(snappedf(float(lods[k]), 0.0001))
				var m: Material = mesh.surface_get_material(si)
				print("   %d %s fmt=%x verts=%d idx=%d lods=%s keys=%s ovr=%s" % [si, m.resource_path if m else "-",
					mesh.surface_get_format(si), mesh.surface_get_array_len(si), mesh.surface_get_array_index_len(si), th,
					s.keys(), mi.get_surface_override_material(si)])
		ch.free()
	quit()
