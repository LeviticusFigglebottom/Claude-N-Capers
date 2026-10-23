## metal_reflection (final): every metallic surface has something to reflect. A metal (effective metallic
## >= METAL) has no diffuse term, so it shows only what its reflections give it: with the environment's
## `reflected_light_source` DISABLED and no ReflectionProbe or baked VoxelGI over it, it renders black
## whatever the lights (black-faces root cause, 2026-10-23). Effective metallic = `metallic` x the mean
## of the metallic texture channel (ORMMaterial3D: ORM.b), read from the texture's source image.
## FAIL: a metal surface with no reflection source. Notes: metals covered only by UPDATE_ONCE probes
## (they read black until the probe first renders, ~14-20 frames; review_shots warms them first).
class_name LcCheckMetalReflection
extends LcCheck

const METAL: float = 0.5
## Downsampled size used for the mean of a metallic texture channel.
const SAMPLE_PX: int = 16


func _init() -> void:
	id = &"metal_reflection"
	title = "Metal surfaces have a reflection source"
	stages = PackedStringArray(["final"])


func run(ctx: LcContext) -> void:
	var env_reflects: bool = _env_reflects(ctx)
	var probes: Array[AABB] = []
	var once: Array[bool] = []
	for n: Node in ctx.map.find_children("*", "ReflectionProbe", true, false):
		var rp: ReflectionProbe = n
		if not rp.is_visible_in_tree() or not ctx.is_active(rp):
			continue
		probes.append(rp.global_transform * AABB(-rp.size * 0.5, rp.size))
		once.append(rp.update_mode == ReflectionProbe.UPDATE_ONCE)
	var gis: Array[AABB] = []
	for n2: Node in ctx.map.find_children("*", "VoxelGI", true, false):
		var vg: VoxelGI = n2
		if vg.is_visible_in_tree() and vg.data != null:
			gis.append(vg.global_transform * AABB(-vg.size * 0.5, vg.size))
	var metals: int = 0
	var bare: Dictionary = {}  # "room|material" -> {node, count}
	var once_only: int = 0
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var node: GeometryInstance3D = piece["node"]
		var mesh: Mesh = piece["mesh"]
		var mats: Array = piece["materials"]
		var box: AABB = (piece["xf"] as Transform3D) * mesh.get_aabb()
		for s: int in range(mesh.get_surface_count()):
			var bm: BaseMaterial3D = (mats[s] if s < mats.size() else null) as BaseMaterial3D
			if bm == null or effective_metallic(ctx, bm) < METAL:
				continue
			metals += 1
			var any_probe: bool = false
			var live_probe: bool = false
			for i: int in range(probes.size()):
				if probes[i].intersects(box):
					any_probe = true
					live_probe = live_probe or not once[i]
			# Inside a probe the probe replaces the environment / GI reflections, so an unrendered one is black.
			if any_probe:
				if not live_probe:
					once_only += 1
				continue
			if env_reflects or _hits(box, gis):
				continue
			var room: RoomVolume = ctx.room_at(box.get_center())
			var key: String = "%s|%s" % [room.room_id if room != null else "-", LcCheckMaterials._mat_name(bm)]
			if not bare.has(key):
				bare[key] = {"node": node, "count": 0, "pos": box.get_center()}
			bare[key]["count"] = int(bare[key]["count"]) + 1
	var keys: Array = bare.keys()
	keys.sort()
	for k: String in keys:
		var parts: PackedStringArray = k.split("|")
		fail(ctx, bare[k]["node"], bare[k]["pos"],
			("%d metal surface(s) of `%s` in room `%s` have no reflection source (environment reflections disabled, "
			+ "no ReflectionProbe or baked VoxelGI): they render black")
			% [bare[k]["count"], parts[1], parts[0]])
	note("environment reflections: %s; %d probe(s), %d baked VoxelGI" % ["on" if env_reflects else "DISABLED",
		probes.size(), gis.size()])
	note("%d metal surface(s); %d covered only by UPDATE_ONCE probes (black until the probe first renders)"
		% [metals, once_only])


static func _hits(box: AABB, boxes: Array[AABB]) -> bool:
	for b: AABB in boxes:
		if b.intersects(box):
			return true
	return false


static func _env_reflects(ctx: LcContext) -> bool:
	for n: Node in ctx.map.find_children("*", "WorldEnvironment", true, false):
		var we: WorldEnvironment = n
		if we.environment != null and ctx.is_active(we):
			return we.environment.reflected_light_source != Environment.REFLECTION_SOURCE_DISABLED
	return true  # no environment: the project default (a clear-colour background) still reflects


## metallic x the mean of the metallic channel, from the texture's source image (works headless).
static func effective_metallic(ctx: LcContext, bm: BaseMaterial3D) -> float:
	var tex: Texture2D = bm.metallic_texture
	var channel: int = bm.metallic_texture_channel
	if bm is ORMMaterial3D:
		tex = (bm as ORMMaterial3D).orm_texture
		channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	if tex == null:
		return bm.metallic
	var key: String = "metal:%d:%d" % [tex.get_instance_id(), channel]
	if not ctx.cache.has(key):
		ctx.cache[key] = channel_mean(tex, channel)
	return bm.metallic * float(ctx.cache[key])


static func channel_mean(tex: Texture2D, channel: int) -> float:
	var img: Image = null
	if tex.resource_path != "" and FileAccess.file_exists(tex.resource_path):
		img = Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
	if img == null or img.is_empty():
		img = tex.get_image()
	if img == null or img.is_empty():
		return 1.0
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SAMPLE_PX, SAMPLE_PX, Image.INTERPOLATE_BILINEAR)
	var sum: float = 0.0
	for y: int in range(SAMPLE_PX):
		for x: int in range(SAMPLE_PX):
			var c: Color = img.get_pixel(x, y)
			sum += [c.r, c.g, c.b, c.a][channel] if channel <= 3 else c.r
	return sum / float(SAMPLE_PX * SAMPLE_PX)
