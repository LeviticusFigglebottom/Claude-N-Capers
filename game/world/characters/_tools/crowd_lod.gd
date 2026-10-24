## D4-01: character LODs. Owner: ENV D. Used by assemble_characters.gd and game/tests/d/test_lod.gd.
##
## Three levels per character (docs/roadmap.md D4-01, A4-02):
## * LOD0 = the glb meshes as built (100 %).
## * LOD1 = Godot's automatic mesh LODs (`meshes/generate_lods=true` in every character .import): the
##   renderer swaps index buffers per surface by screen size (about 50 / 25 / 12 % steps). No node change.
## * LOD2 = `Skeleton3D/CrowdLod`: ONE skinned surface (one draw call, one shadow draw) merged from every
##   surface's automatic LOD nearest TARGET_RATIO, coloured per vertex with each material's mean albedo
##   (char_crowd_lod.tres). Shown from `switch_m` on with visibility ranges: the full meshes end at
##   switch_m, CrowdLod begins there (hysteresis MARGIN_M, no fade so nothing enters the alpha pass).
##   A crowd of 30 club patrons goes from ~12 draws each to 1.
##
## Which characters get LOD2 and from where (lod_class): crowd NPCs (civilians, heist staff, P5 casts)
## switch at CROWD_SWITCH_M; armed units (security, police, cartel, faction swat) at UNIT_SWITCH_M (the merged
## mesh keeps the silhouette and colours, so the 30 m silhouette rule holds on LOD2). No LOD2 (full meshes
## always, LOD1 only): the crew heisters (player bodies), contacts, and any character with
## gameplay-toggled meshes or a material_override (Wrecker plates/visor, Phantom goggles), so ENV A's
## node lookups and telegraphs never land on a proxy.
##
## Deterministic: sorted mesh order, integer index work, a fixed pixel grid for the albedo mean.
extends RefCounted

const NODE_NAME: String = "CrowdLod"
const MATERIAL_PATH: String = "res://world/materials/char_crowd_lod.tres"
## Per-surface LOD choice: the smallest automatic LOD with at least this share of the surface's tris.
const TARGET_RATIO: float = 0.10
## Surfaces this small (eyes, iris, lashes, teeth, badges) are dropped from LOD2: sub-pixel past 20 m.
const MIN_SURFACE_TRIS: int = 150
## D-132 (D-130 perf audit, D2): 20 -> 15 m for crowd NPCs and 35 -> 25 m for armed units (draws -27 % / -10 % in the
## bench); LOD2 holds up at those distances since the covered-layer fix (1b375cb9).
const CROWD_SWITCH_M: float = 15.0
const UNIT_SWITCH_M: float = 25.0
const MARGIN_M: float = 1.0
## D-084: every CrowdLod proxy is in this group (persistent, set by the assembler) so the switch can follow zoom.
const GROUP: StringName = &"crowd_lod"
const META_BASE: StringName = &"crowd_lod_switch_m"
## Mesh node names a character may have and still get LOD2 (anything else is gameplay-visible).
const PLAIN_MESHES: Array[String] = ["Body", "Gear", "Hair", "Headwear", "Outfit", "Slung"]
const CROWD_SCRIPTS: Array[String] = [
	"char_civilians.py", "char_dock_workers.py", "char_npc_bank.py", "char_npc_calder.py", "char_npc_penthouse.py",
	"char_p5_bank.py", "char_p5_club.py", "char_p5_convoy.py", "char_p5_gallery.py",
]
## D-080: specials (char_specials.py: TAC Heavy, Corpsman, Stinger, Longshot, Bulwark, Brandt, ...) keep LOD0/1 only,
## so their telegraphs (Corpsman cross, Bulwark shield, Longshot scope) never collapse on a proxy.
const UNIT_SCRIPTS: Array[String] = ["char_security.py", "char_police.py", "char_cartel.py"]
## Vertices closer than this (same colour and influences) are welded in LOD2.
const WELD_M: float = 0.001
## LOD2 aim as a share of the full character's tris (the roadmap's ~15 %).
const FINAL_RATIO: float = 0.15
## Albedo mean: a GRID x GRID sample of the albedo PNG.
const GRID: int = 32
## Layered garments (a shirt under a jacket): a LOD2 vertex is hidden when a segment this long along its normal
## (rest pose) hits a triangle of ANOTHER surface that faces the same way (normal dot >= COVER_DOT). A triangle with
## all three vertices hidden is dropped, so the simplified outer shell no longer lets the layer under it through.
## Covered vertices that stay (their triangle straddles the outer layer's edge) are tucked this far inward.
const COVER_M: float = 0.04
const COVER_DOT: float = 0.3
const COVER_TUCK_M: float = 0.02
## Spatial hash cell for the cover test (m).
const COVER_CELL_M: float = 0.04
## D-165: per-look LOD2 brightness gains (see gain_for)
const GAIN_PATH: String = "res://world/characters/_layers/crowd_lod_gain.json"


## LOD2 switch distance for an asset (0.0 = no LOD2). `source` = CharacterSpec.read_source(SOURCE.txt).
static func switch_m(source: Dictionary, mesh_names: Array[String]) -> float:
	if source.has("material_override"):
		return 0.0
	for n: String in mesh_names:
		if not PLAIN_MESHES.has(n):
			return 0.0
	var script: String = String(source.get("script", "")).get_file()
	if CROWD_SCRIPTS.has(script):
		return CROWD_SWITCH_M
	if UNIT_SCRIPTS.has(script):
		return UNIT_SWITCH_M
	return 0.0


## The top-level meshes of a character skeleton, sorted by name (CrowdLod excluded).
static func source_meshes(skel: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in skel.get_children():
		if c is MeshInstance3D and String(c.name) != NODE_NAME and (c as MeshInstance3D).mesh is ArrayMesh:
			out.append(c as MeshInstance3D)
	out.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return String(a.name) < String(b.name))
	return out


## D-084: the camera zoom (ADS / scope) as a factor >= 1.0, read defensively: CrewView (ENV P) publishes
## `zoom_factor`; anything without it (or null) is 1.0.
static func zoom_factor_of(view: Object) -> float:
	if view == null or not is_instance_valid(view):
		return 1.0
	var z: Variant = view.get(&"zoom_factor")
	if typeof(z) != TYPE_FLOAT and typeof(z) != TYPE_INT:
		return 1.0
	return maxf(1.0, float(z))


## D-084: scale one character's LOD switch by `zoom` (switch = base * zoom; base is the assembled distance).
## Returns false when the character has no CrowdLod (specials, heisters: nothing to scale).
static func apply_zoom(proxy_or_character: Node, zoom: float) -> bool:
	var proxy: MeshInstance3D = proxy_or_character as MeshInstance3D
	if proxy == null or String(proxy.name) != NODE_NAME:
		proxy = proxy_or_character.get_node_or_null(NodePath("Skeleton3D/" + NODE_NAME)) as MeshInstance3D
	if proxy == null:
		return false
	if not proxy.has_meta(META_BASE):
		proxy.set_meta(META_BASE, proxy.visibility_range_begin)
	var base: float = float(proxy.get_meta(META_BASE))
	if base <= 0.0:
		return false
	var d: float = base * maxf(1.0, zoom)
	proxy.visibility_range_begin = d
	var skel: Node = proxy.get_parent()
	if skel != null:
		for mi: MeshInstance3D in source_meshes(skel):
			mi.visibility_range_end = d
	return true


## D-084: call once per frame (or when zoom changes) from the local camera owner, e.g. in CrewView:
##   CrowdLod.apply_zoom_all(get_tree(), CrowdLod.zoom_factor_of(self))
## Returns the number of proxies updated.
static func apply_zoom_all(tree: SceneTree, zoom: float) -> int:
	var n: int = 0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if apply_zoom(node, zoom):
			n += 1
	return n


## Review renders: show one level regardless of camera distance (lod2 = false: the glb meshes only).
## Returns false when the character has no LOD2 and lod2 was asked for.
static func force_level(character: Node, lod2: bool) -> bool:
	var skel: Node = character.get_node_or_null(^"Skeleton3D")
	if skel == null:
		return false
	var proxy: MeshInstance3D = skel.get_node_or_null(NodePath(NODE_NAME)) as MeshInstance3D
	if proxy == null and lod2:
		return false
	for mi: MeshInstance3D in source_meshes(skel):
		mi.visibility_range_end = 0.0
		mi.visible = not lod2
	if proxy != null:
		proxy.visibility_range_begin = 0.0
		proxy.visible = lod2
	return true


## Triangle count of every surface of `meshes` at full detail.
static func full_tris(meshes: Array[MeshInstance3D]) -> int:
	var n: int = 0
	for mi: MeshInstance3D in meshes:
		var surfs: Array = (mi.mesh as ArrayMesh).get("_surfaces")
		for s: Variant in surfs:
			n += int((s as Dictionary).get("index_count", 0)) / 3
	return n


## Index buffer (vertex ids) of the automatic LOD chosen for one surface.
static func surface_lod_indices(surface: Dictionary) -> PackedInt32Array:
	var base_count: int = int(surface.get("index_count", 0))
	var raw: PackedByteArray = surface.get("index_data", PackedByteArray())
	var width: int = raw.size() / maxi(base_count, 1)
	var chosen: PackedByteArray = raw
	var lods: Array = surface.get("lods", [])
	for i: int in range(1, lods.size(), 2):
		var lod: PackedByteArray = lods[i]
		if float(lod.size() / width) >= TARGET_RATIO * float(base_count):
			chosen = lod
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(chosen.size() / width)
	for k: int in range(out.size()):
		out[k] = chosen.decode_u16(k * 2) if width == 2 else int(chosen.decode_u32(k * 4))
	return out


## Mean albedo (sRGB) of a surface material: albedo_color x the mean of the albedo PNG.
static func material_color(mat: Material, cache: Dictionary) -> Color:
	var bm: BaseMaterial3D = mat as BaseMaterial3D
	if bm == null:
		return Color(0.5, 0.5, 0.5)
	var key: String = bm.resource_path if not bm.resource_path.is_empty() else bm.resource_name
	if cache.has(key):
		return cache[key]
	var c: Color = bm.albedo_color
	if bm.albedo_texture != null and not bm.albedo_texture.resource_path.is_empty():
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(bm.albedo_texture.resource_path))
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var sum: Vector3 = Vector3.ZERO
			for y: int in range(GRID):
				for x: int in range(GRID):
					var p: Color = img.get_pixel((x * img.get_width() + img.get_width() / 2) / GRID,
						(y * img.get_height() + img.get_height() / 2) / GRID)
					sum += Vector3(p.r, p.g, p.b)
			sum /= float(GRID * GRID)
			c = Color(c.r * sum.x, c.g * sum.y, c.b * sum.z)
	c = Color(snappedf(c.r, 1.0 / 255.0), snappedf(c.g, 1.0 / 255.0), snappedf(c.b, 1.0 / 255.0))
	cache[key] = c
	return c


## D-165: per-look LOD2 brightness gain (crowd_lod_gain.json, written by render_lod2_pop.gd --calibrate): the
## club_* looks are only ever seen under the Velvet's light, where the flat proxy read up to 35 % darker than the full
## meshes (normal-mapped satin / shirt highlights a merged rough surface cannot show). 1.0 for every other look.


static func gain_for(char_id: String) -> float:
	if not FileAccess.file_exists(GAIN_PATH):
		return 1.0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GAIN_PATH))
	if not (data is Dictionary):
		return 1.0
	return float((data as Dictionary).get("gain", {}).get(char_id, 1.0))


## `c` (sRGB) scaled by `gain` in linear light, clamped, snapped to 8 bits like material_color.
static func _gained(c: Color, gain: float) -> Color:
	if is_equal_approx(gain, 1.0):
		return c
	var l: Color = c.srgb_to_linear()
	var o: Color = Color(minf(l.r * gain, 1.0), minf(l.g * gain, 1.0), minf(l.b * gain, 1.0)).linear_to_srgb()
	return Color(snappedf(o.r, 1.0 / 255.0), snappedf(o.g, 1.0 / 255.0), snappedf(o.b, 1.0 / 255.0))


## The merged LOD2 mesh of `meshes` (null when nothing qualifies). Bone ids/weights are kept as the glb
## skin's (every character mesh shares one Skin), reduced to 4 influences per vertex.
static func build_mesh(meshes: Array[MeshInstance3D], gain: float = 1.0) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var cache: Dictionary = {}
	var weld: Dictionary = {}
	var cover: Dictionary = _cover_grid(meshes)
	var surf_id: int = -1
	for mi: MeshInstance3D in meshes:
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		var surfs: Array = mesh.get("_surfaces")
		for si: int in range(mesh.get_surface_count()):
			surf_id += 1
			var surface: Dictionary = surfs[si]
			if int(surface.get("index_count", 0)) / 3 < MIN_SURFACE_TRIS:
				continue
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(si)
			if mat == null:
				mat = mesh.surface_get_material(si)
			var col: Color = _gained(material_color(mat, cache), gain)
			var arr: Array = mesh.surface_get_arrays(si)
			var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var sb: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var sw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var per: int = sb.size() / maxi(sv.size(), 1)
			var remap: Dictionary = {}
			var tri: PackedInt32Array = PackedInt32Array([0, 0, 0])
			var hidden: Dictionary = {}
			var lod_idx: PackedInt32Array = _drop_covered(surface_lod_indices(surface), sv, sn, surf_id, cover, hidden)
			for k: int in range(lod_idx.size()):
				var vi: int = lod_idx[k]
				if not remap.has(vi):
					# Weld UV / normal splits: same point, colour and influences = one vertex (normals summed).
					var nb: PackedInt32Array = PackedInt32Array()
					var nw: PackedFloat32Array = PackedFloat32Array()
					_append_influences(nb, nw, sb, sw, vi, per)
					var p: Vector3 = sv[vi].snappedf(WELD_M)
					var key: String = "%s|%s|%s|%s" % [p, col.to_html(false), nb, nw]
					if weld.has(key):
						remap[vi] = weld[key]
					else:
						remap[vi] = verts.size()
						weld[key] = verts.size()
						var tuck: Vector3 = sn[vi].normalized() * COVER_TUCK_M if hidden.get(vi, false) else Vector3.ZERO
						verts.append(sv[vi] - tuck)
						normals.append(Vector3.ZERO)
						colors.append(col)
						bones.append_array(nb)
						weights.append_array(nw)
					var ni: int = remap[vi]
					normals[ni] += sn[vi] if vi < sn.size() else Vector3.UP
				tri[k % 3] = remap[vi]
				if k % 3 == 2 and tri[0] != tri[1] and tri[1] != tri[2] and tri[0] != tri[2]:
					indices.append_array(tri)
	if indices.is_empty():
		return null
	for i: int in range(normals.size()):
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 1e-12 else Vector3.UP
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	# Second pass on the welded whole: simplify toward FINAL_RATIO of the full character when the
	# per-surface pick overshoots (small surfaces only have a 50 % level).
	var target: int = int(FINAL_RATIO * float(full_tris(meshes)))
	if indices.size() / 3 > target * 5 / 4:
		var im: ImporterMesh = ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(25.0, 60.0, [])
		var best: PackedInt32Array = indices
		for li: int in range(im.get_surface_lod_count(0)):
			var cand: PackedInt32Array = im.get_surface_lod_indices(0, li)
			if absi(cand.size() / 3 - target) < absi(best.size() / 3 - target):
				best = cand
		arrays = _compact(arrays, best)
	return _finish(arrays)


## Rest-pose triangles of every surface of `meshes`, hashed by COVER_CELL_M cell:
## {"tris": PackedVector3Array (3 per tri), "normal": PackedVector3Array, "surf": PackedInt32Array, "cells": {Vector3i: PackedInt32Array}}.
## Surface ids count every surface of every mesh in order (as build_mesh does).
static func _cover_grid(meshes: Array[MeshInstance3D]) -> Dictionary:
	var tris: PackedVector3Array = PackedVector3Array()
	var tri_n: PackedVector3Array = PackedVector3Array()
	var tri_s: PackedInt32Array = PackedInt32Array()
	var cells: Dictionary = {}
	var surf_id: int = -1
	for mi: MeshInstance3D in meshes:
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		for si: int in range(mesh.get_surface_count()):
			surf_id += 1
			if int((mesh.get("_surfaces")[si] as Dictionary).get("index_count", 0)) / 3 < MIN_SURFACE_TRIS:
				continue   # not in LOD2 itself (eyes, badges, glasses), so it covers nothing there
			var arr: Array = mesh.surface_get_arrays(si)
			var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for k: int in range(0, idx.size() - 2, 3):
				var a: Vector3 = sv[idx[k]]
				var b: Vector3 = sv[idx[k + 1]]
				var c: Vector3 = sv[idx[k + 2]]
				var n: Vector3 = (c - a).cross(b - a)   # Godot front faces wind clockwise: the outward normal
				if n.length_squared() < 1e-14:
					continue
				var t: int = tri_s.size()
				tris.append_array([a, b, c])
				tri_n.append(n.normalized())
				tri_s.append(surf_id)
				var lo: Vector3i = _cell(Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z))))
				var hi: Vector3i = _cell(Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z))))
				for x: int in range(lo.x, hi.x + 1):
					for y: int in range(lo.y, hi.y + 1):
						for z: int in range(lo.z, hi.z + 1):
							var key: Vector3i = Vector3i(x, y, z)
							var list: PackedInt32Array = cells.get(key, PackedInt32Array())
							list.append(t)
							cells[key] = list   # packed arrays are values: write the grown copy back
	return {"tris": tris, "normal": tri_n, "surf": tri_s, "cells": cells}


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / COVER_CELL_M), floori(p.y / COVER_CELL_M), floori(p.z / COVER_CELL_M))


## `idx` without the triangles whose three vertices are all covered by another surface (see COVER_M); `hidden`
## gets vertex id -> covered for every vertex looked at.
static func _drop_covered(idx: PackedInt32Array, sv: PackedVector3Array, sn: PackedVector3Array, surf_id: int,
		cover: Dictionary, hidden: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in range(0, idx.size() - 2, 3):
		var all_hidden: bool = true
		for j: int in range(3):
			var vi: int = idx[k + j]
			if not hidden.has(vi):
				hidden[vi] = vi < sn.size() and _covered(sv[vi], sn[vi], surf_id, cover)
			if not hidden[vi]:
				all_hidden = false
		if not all_hidden:
			out.append_array([idx[k], idx[k + 1], idx[k + 2]])
	return out


static func _covered(p: Vector3, n: Vector3, surf_id: int, cover: Dictionary) -> bool:
	if n.length_squared() < 1e-12:
		return false
	n = n.normalized()
	var from: Vector3 = p + n * 0.0005
	var to: Vector3 = p + n * COVER_M
	var lo: Vector3i = _cell(from.min(to))
	var hi: Vector3i = _cell(from.max(to))
	var tris: PackedVector3Array = cover["tris"]
	var tri_n: PackedVector3Array = cover["normal"]
	var tri_s: PackedInt32Array = cover["surf"]
	var cells: Dictionary = cover["cells"]
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				var key: Vector3i = Vector3i(x, y, z)
				if not cells.has(key):
					continue
				for t: int in cells[key]:
					if tri_s[t] == surf_id or tri_n[t].dot(n) < COVER_DOT:
						continue
					if Geometry3D.segment_intersects_triangle(from, to, tris[t * 3], tris[t * 3 + 1], tris[t * 3 + 2]) != null:
						return true
	return false


## Arrays with only the vertices `idx` references (first-use order), re-indexed.
static func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var sv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sc: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var sb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var remap: Dictionary = {}
	for vi: int in idx:
		if not remap.has(vi):
			remap[vi] = verts.size()
			verts.append(sv[vi])
			normals.append(sn[vi])
			colors.append(sc[vi])
			bones.append_array(sb.slice(vi * 4, vi * 4 + 4))
			weights.append_array(sw.slice(vi * 4, vi * 4 + 4))
		indices.append(remap[vi])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = indices
	return out


static func _finish(arrays: Array) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	# No ARRAY_FLAG_COMPRESS_ATTRIBUTES: with it the skinned LOD2 renders exploded (seen in lod_review.png).
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	var lod_mat: Material = load(MATERIAL_PATH) as Material
	if lod_mat != null:
		out.surface_set_material(0, lod_mat)
	out.resource_name = NODE_NAME
	return out


## The 4 strongest influences of vertex `vi` (renormalised), appended to bones/weights.
static func _append_influences(bones: PackedInt32Array, weights: PackedFloat32Array, sb: PackedInt32Array,
		sw: PackedFloat32Array, vi: int, per: int) -> void:
	var pairs: Array[Vector2] = []
	for k: int in range(per):
		pairs.append(Vector2(sw[vi * per + k], sb[vi * per + k]))
	pairs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	var total: float = 0.0
	for k: int in range(mini(4, pairs.size())):
		total += pairs[k].x
	for k: int in range(4):
		if k < pairs.size() and total > 0.0:
			bones.append(int(pairs[k].y))
			weights.append(pairs[k].x / total)
		else:
			bones.append(0)
			weights.append(1.0 if (k == 0 and total <= 0.0) else 0.0)
