## LEAD (k) review: each NPC weapon's full armory model (top row) above its far silhouette (make_weapon_silhouettes.gd,
## bottom row), side view (+X) at the same scale, lit; then the same pair seen from 3/4 front. Writes
## res://assets/characters/_review/weapon_silhouettes/weapon_silhouettes_side.png and _quarter.png. Owner: ENV D.
## Models come through B's NpcWeaponModels API (needs the autoloads, so it runs as a scene).
##   xvfb-run -a -s "-screen 0 1800x400x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --resolution 1800x400 --path game res://world/characters/_tools/render_weapon_silhouettes_review.tscn
extends Node

const DIR: String = "res://world/characters/_props/weapon_silhouettes/"
const OUT: String = "res://assets/characters/_review/weapon_silhouettes/"
const GAP: float = 1.5


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "weapon_silhouettes.json")) as Dictionary
	var models: Array[String] = []
	var full_scenes: Dictionary = {}
	for k: String in idx["silhouettes"]:
		var m: String = String(idx["silhouettes"][k]).get_file().trim_prefix("weapon_silhouette_").trim_suffix(".tscn")
		if not models.has(m):
			models.append(m)
			full_scenes[m] = NpcWeaponModels.weapon_def(StringName(k)).model
	models.sort()
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.64, 0.68)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	world.add_child(sun)
	for i: int in models.size():
		var z: float = i * GAP
		var full: Node3D = (full_scenes[models[i]] as PackedScene).instantiate()
		world.add_child(full)
		full.position = Vector3(0, 0.3, z)
		var sil: Node3D = (load(DIR + "weapon_silhouette_%s.tscn" % models[i]) as PackedScene).instantiate()
		(sil as GeometryInstance3D).visibility_range_begin = 0.0
		world.add_child(sil)
		sil.position = Vector3(0, -0.3, z)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	cam.current = true
	var mid: float = (models.size() - 1) * GAP * 0.5
	# side: the barrels run along Z (muzzle -Z), so a view from +X shows every profile left to right
	for shot: Array in [["side", 0.0], ["quarter", 35.0]]:
		for c: Node in world.get_children():
			if c is MeshInstance3D or (c is Node3D and c.get_child_count() > 0 and not (c is Camera3D)):
				(c as Node3D).rotation_degrees = Vector3(0, float(shot[1]), 0)
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = models.size() * GAP
		cam.look_at_from_position(Vector3(6.0, 0.6 if shot[1] > 0.0 else 0.0, mid), Vector3(0, 0, mid))
		for _f: int in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "weapon_silhouettes_%s.png" % shot[0]))
	print("render_weapon_silhouettes_review: %d models" % models.size())
	get_tree().quit()
