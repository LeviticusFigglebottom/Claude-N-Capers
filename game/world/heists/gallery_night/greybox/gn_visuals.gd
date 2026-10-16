## Gallery Night generated prefab visuals (GN-C2, ENV C): the laser grids' beams (visual_slots: `Beam<i>` nodes that the
## LaserGrid prefab moves on its beam line), one scene per grid shape, written to res://world/heists/gallery_night/art/
## with library / emissive materials (gn_art.local_box_mesh) so the final-stage `materials` check passes. The Treasury's
## emitter columns are map-built (gn_content._emitters); the landing curtain gets two slim bronze posts.
## Same approach as Night Deposit's make_visuals (nd_dress.gd): deterministic, uid kept across regens.
extends RefCounted

const ART_DIR: String = "res://world/heists/gallery_night/art/"
## [file, beams, size (w, h), sweeping, z offset of the bars (the three TR variants share a spot), posts].
const LASERS: Dictionary = {
	"lz_static": ["gn_laser_static.tscn", 3, Vector2(7.3, 1.8), false, 0.0, false],
	"lz_sweep": ["gn_laser_sweep.tscn", 3, Vector2(7.3, 2.6), true, 0.02, false],
	"lz_timed": ["gn_laser_timed.tscn", 4, Vector2(7.3, 2.6), false, 0.04, false],
	"curtain": ["gn_laser_curtain.tscn", 5, Vector2(11.2, 2.4), false, 0.0, true],
}
const BAR_T: float = 0.012


static func path(id: String) -> String:
	return ART_DIR + String((LASERS[id] as Array)[0])


## Writes every visual scene; returns an error message or "". `res` supplies read_uid / normalize_scene.
static func make(art: RefCounted, res: GDScript) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_DIR))
	var ids: Array = LASERS.keys()
	ids.sort()
	for id: Variant in ids:
		var r: Array = LASERS[id]
		var n: int = int(r[1])
		var size: Vector2 = r[2]
		var sweeping: bool = bool(r[3])
		var dz: float = float(r[4])
		var root: Node3D = Node3D.new()
		root.name = "GnLaser" + String(id).capitalize().replace(" ", "")
		for i: int in range(n):
			var beam: Node3D = Node3D.new()
			beam.name = "Beam%d" % i
			beam.position = Vector3(size.x * (float(i) + 1.0) / float(n + 1) - size.x * 0.5, size.y * 0.5, 0.0) if sweeping \
				else Vector3(0.0, size.y * (float(i) + 0.5) / float(n), 0.0)
			root.add_child(beam)
			beam.owner = root
			var bar: MeshInstance3D = MeshInstance3D.new()
			bar.name = "Bar"
			bar.position = Vector3(0.0, 0.0, dz)
			var bs: Vector3 = Vector3(BAR_T, size.y - 0.1, BAR_T) if sweeping else Vector3(size.x - 0.1, BAR_T, BAR_T)
			bar.mesh = art.call(&"local_box_mesh", [[bs, Vector3.ZERO, "laser_red"]])
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.add_child(bar)
			bar.owner = root
		if bool(r[5]):
			for sx: float in [-1.0, 1.0]:
				var post: MeshInstance3D = MeshInstance3D.new()
				post.name = "PostL" if sx < 0.0 else "PostR"
				post.position = Vector3(sx * (size.x * 0.5 - 0.03), size.y * 0.5, 0.0)
				post.mesh = art.call(&"local_box_mesh", [[Vector3(0.05, size.y, 0.05), Vector3.ZERO, "bronze_brass"],
					[Vector3(0.09, 0.03, 0.09), Vector3(0.0, -size.y * 0.5 + 0.015, 0.0), "bronze_brass"]])
				root.add_child(post)
				post.owner = root
		var ps: PackedScene = PackedScene.new()
		var err: int = ps.pack(root)
		root.free()
		var out: String = path(String(id))
		var old_uid: String = res.read_uid(out)
		if err == OK:
			err = ResourceSaver.save(ps, out)
		if err != OK:
			return "cannot save %s (%d)" % [out, err]
		res.normalize_scene(out, old_uid)
	return ""
