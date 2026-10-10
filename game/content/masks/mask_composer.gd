## Composition -> MaskDef -> visual (pd2_fidelity P8). Owner: ENV B. Static. Design: content/docs/masks.md.
##
## compose({"base", "material", "colors", "pattern"}, id) -> MaskDef:
##   model       = the base's ENV D glb when it exists (else null; instantiate() builds a placeholder)
##   material_id = the material part's library id (e.g. &"brass")
##   color_a/b   = the colour pair, pattern_id = the pattern part id (`mask_pattern.<name>`)
##   meta "composition" = the normalized composition (presets may carry meta "mask_base" instead).
## instantiate(def) -> Node3D (pivot at the face centre, -Z forward) with build_material(def) applied.
class_name MaskComposer
extends RefCounted

const SHADER_PATH: String = "res://content/masks/mask_surface.gdshader"
const META_COMPOSITION: StringName = &"composition"
## Optional meta on preset MaskDef files: the base part id used for the placeholder shape.
const META_BASE: StringName = &"mask_base"

## base id -> ArrayMesh
static var _meshes: Dictionary = {}


## Problems with a composition's shape and part ids (ownership is MaskLocker's job). Empty = ok.
static func validate(comp: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for k: String in MaskCatalog.KINDS:
		var id: StringName = StringName(String(comp.get(k, "")))
		if id == &"":
			errors.append("missing %s" % k)
		elif MaskCatalog.kind_of(id) != k or not MaskCatalog.has_part(id):
			errors.append("unknown %s '%s'" % [k, id])
	return errors


## The four kind keys as Strings (other keys dropped). Missing kinds become "".
static func normalized(comp: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in MaskCatalog.KINDS:
		out[k] = String(comp.get(k, ""))
	return out


## Runtime MaskDef for a composition; null + Log.error when it is invalid.
static func compose(comp: Dictionary, mask_id: StringName = &"mask.custom.0") -> MaskDef:
	var errors: Array[String] = validate(comp)
	if not errors.is_empty():
		Log.error(MaskCatalog.LOG_CHANNEL, "cannot compose mask '%s': %s" % [mask_id, ", ".join(errors)])
		return null
	var n: Dictionary = normalized(comp)
	var base: MaskBaseDef = MaskCatalog.part(StringName(n[MaskCatalog.BASE])) as MaskBaseDef
	var mat: MaskMaterialDef = MaskCatalog.part(StringName(n[MaskCatalog.MATERIAL])) as MaskMaterialDef
	var colors: MaskColorDef = MaskCatalog.part(StringName(n[MaskCatalog.COLORS])) as MaskColorDef
	var def: MaskDef = MaskDef.new()
	def.id = mask_id
	def.display_name = String(mask_id)
	def.model = _load_model(base.model_path)
	def.material_id = mat.material_id
	def.color_a = colors.color_a
	def.color_b = colors.color_b
	def.pattern_id = StringName(n[MaskCatalog.PATTERN])
	def.unlock = &""
	def.set_meta(META_COMPOSITION, n)
	return def


## Best-effort composition of any MaskDef (custom: exact; preset: base from meta "mask_base", material
## by library id, colours by an exact pair match, pattern id). Unknown parts are "".
static func composition_of(def: MaskDef) -> Dictionary:
	if def == null:
		return normalized({})
	if def.has_meta(META_COMPOSITION):
		return normalized(def.get_meta(META_COMPOSITION) as Dictionary)
	var out: Dictionary = normalized({})
	var base: StringName = StringName(String(def.get_meta(META_BASE, "")))
	if MaskCatalog.kind_of(base) == MaskCatalog.BASE and MaskCatalog.has_part(base):
		out[MaskCatalog.BASE] = String(base)
	var mat: MaskMaterialDef = MaskCatalog.material_for(def.material_id)
	if mat != null:
		out[MaskCatalog.MATERIAL] = String(mat.id)
	for p: MaskPartDef in MaskCatalog.parts(MaskCatalog.COLORS):
		var c: MaskColorDef = p as MaskColorDef
		if c.color_a.is_equal_approx(def.color_a) and c.color_b.is_equal_approx(def.color_b):
			out[MaskCatalog.COLORS] = String(c.id)
			break
	if MaskCatalog.kind_of(def.pattern_id) == MaskCatalog.PATTERN and MaskCatalog.has_part(def.pattern_id):
		out[MaskCatalog.PATTERN] = String(def.pattern_id)
	return out


## The mask surface material for a MaskDef (colours, pattern, library grain). Never null.
static func build_material(def: MaskDef) -> ShaderMaterial:
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(SHADER_PATH) as Shader
	if def == null:
		return sm
	sm.set_shader_parameter(&"color_a", def.color_a)
	sm.set_shader_parameter(&"color_b", def.color_b)
	var mat: MaskMaterialDef = MaskCatalog.material_for(def.material_id)
	if mat != null:
		sm.set_shader_parameter(&"metallic_value", mat.metallic)
		sm.set_shader_parameter(&"roughness_value", mat.roughness)
		sm.set_shader_parameter(&"detail_strength", mat.detail_strength)
		sm.set_shader_parameter(&"detail_mean", mat.detail_mean)
		sm.set_shader_parameter(&"uv_tile", mat.uv_tile)
		var lib: BaseMaterial3D = mat.library_material as BaseMaterial3D
		if lib != null:
			if lib.albedo_texture != null:
				sm.set_shader_parameter(&"detail_albedo", lib.albedo_texture)
			if lib is ORMMaterial3D and lib.orm_texture != null:
				sm.set_shader_parameter(&"detail_orm", lib.orm_texture)
			if lib.normal_enabled and lib.normal_texture != null:
				sm.set_shader_parameter(&"detail_normal", lib.normal_texture)
				sm.set_shader_parameter(&"has_normal", true)
	if MaskCatalog.kind_of(def.pattern_id) == MaskCatalog.PATTERN and MaskCatalog.has_part(def.pattern_id):
		var pat: MaskPatternDef = MaskCatalog.part(def.pattern_id) as MaskPatternDef
		sm.set_shader_parameter(&"pattern", int(pat.procedural))
		sm.set_shader_parameter(&"pattern_scale", pat.scale)
		if pat.texture_path != "" and ResourceLoader.exists(pat.texture_path):
			sm.set_shader_parameter(&"pattern_tex", load(pat.texture_path) as Texture2D)
			sm.set_shader_parameter(&"use_pattern_tex", true)
	return sm


## Visual for a MaskDef: its model (every mesh gets the mask material as material_override) or the
## procedural placeholder of its base. Root is a Node3D named "Mask"; caller owns it.
static func instantiate(def: MaskDef) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Mask"
	if def == null:
		return root
	var mat: ShaderMaterial = build_material(def)
	if def.model != null:
		var inst: Node = def.model.instantiate()
		root.add_child(inst)
		_apply_material(inst, mat)
		return root
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Placeholder"
	mi.mesh = placeholder_for(def)
	mi.material_override = mat
	root.add_child(mi)
	return root


## Placeholder mesh for a MaskDef's base (composition, meta "mask_base", else the tweak default).
static func placeholder_for(def: MaskDef) -> ArrayMesh:
	var base_id: StringName = StringName(String(composition_of(def)[MaskCatalog.BASE]))
	if base_id == &"":
		base_id = StringName(String(MaskCatalog.tweak().default_composition.get(MaskCatalog.BASE, "")))
	var base: MaskBaseDef = MaskCatalog.part(base_id) as MaskBaseDef if MaskCatalog.has_part(base_id) else null
	if base == null:
		base = MaskBaseDef.new()
	if not _meshes.has(base.id) or base.id == &"":
		_meshes[base.id] = placeholder_mesh(base, MaskCatalog.tweak().placeholder_grid)
	return _meshes[base.id]


## Original procedural face plate: a curved superellipse shell with eye holes, snout, brow and
## optional ears. A grid in (u, v) whose corners outside the outline or inside an eye are snapped
## onto the edge, so outlines stay smooth. Pivot at the face centre, -Z forward; UV0 as described
## in mask_surface.gdshader.
static func placeholder_mesh(b: MaskBaseDef, grid: int = 40) -> ArrayMesh:
	var n: int = maxi(grid, 8)
	var v_top: float = 1.0 + maxf(b.ear_h, 0.0)
	var rows: int = ceili(n * (v_top + 1.0) * 0.5)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var du: float = 2.0 / n
	var dv: float = (v_top + 1.0) / rows
	for j: int in range(rows):
		for i: int in range(n):
			var u0: float = -1.0 + i * du
			var v0: float = -1.0 + j * dv
			var quad: Array[Vector2] = [
				Vector2(u0, v0), Vector2(u0, v0 + dv), Vector2(u0 + du, v0 + dv), Vector2(u0 + du, v0)]
			var good: int = 0
			for q: Vector2 in quad:
				good += 1 if _solid(b, q) else 0
			if good == 0:
				continue
			for k: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = _snap(b, quad[k])
				st.set_uv(Vector2((1.0 - p.x) * 0.5, (1.0 - p.y) * 0.5))  # u=0 at +X (viewer's left), v=0 top (masks.md)
				st.add_vertex(_point(b, p.x, p.y))
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Drop the placeholder mesh cache (tests, hot reload).
static func clear_cache() -> void:
	_meshes.clear()


static func _solid(b: MaskBaseDef, p: Vector2) -> bool:
	return _in_outline(b, p) and _eye_value(b, p).x >= 1.0


static func _in_outline(b: MaskBaseDef, p: Vector2) -> bool:
	if b.ear_h > 0.0 and p.y > 0.55:
		var t: float = (p.y - 0.55) / (1.0 + b.ear_h - 0.55)
		if t <= 1.0 and absf(absf(p.x) - b.ear_x) < b.ear_w * (1.0 - t):
			return true
	if p.y > 1.0:
		return false
	var taper: float = 1.0 - clampf(b.chin_taper, 0.0, 0.9) * maxf(-p.y, 0.0)
	var uu: float = absf(p.x) / maxf(taper, 0.05)
	return pow(uu, b.roundness) + pow(absf(p.y), b.roundness) <= 1.0


## x = normalized ellipse distance² to the nearer eye (< 1 = inside), y = that eye's u centre.
static func _eye_value(b: MaskBaseDef, p: Vector2) -> Vector2:
	var cx: float = b.eye_x if p.x >= 0.0 else -b.eye_x
	var d: Vector2 = Vector2((p.x - cx) / maxf(b.eye_w, 0.01), (p.y - b.eye_y) / maxf(b.eye_h, 0.01))
	return Vector2(d.length_squared(), cx)


## Moves a point inside an eye onto the eye edge, and a point outside the outline onto the outline.
static func _snap(b: MaskBaseDef, p: Vector2) -> Vector2:
	var q: Vector2 = p
	var e: Vector2 = _eye_value(b, q)
	if e.x < 1.0:
		var c: Vector2 = Vector2(e.y, b.eye_y)
		if q.is_equal_approx(c):
			q = c + Vector2(0.0, b.eye_h)
		else:
			q = c + (q - c) / sqrt(maxf(e.x, 0.0001))
	if _in_outline(b, q):
		return q
	var lo: float = 0.0
	var hi: float = 1.0
	for _i: int in range(16):
		var mid: float = (lo + hi) * 0.5
		if _in_outline(b, q * mid):
			lo = mid
		else:
			hi = mid
	return q * lo


static func _point(b: MaskBaseDef, u: float, v: float) -> Vector3:
	var x: float = u * b.width_m * 0.5
	var y: float = v * b.height_m * 0.5
	var bulge: float = b.depth_m * maxf(1.0 - 0.7 * u * u - 0.3 * v * v, 0.0)
	var snout: float = b.snout_m * exp(-pow(u / maxf(b.snout_w, 0.01), 2.0) - pow((v - b.snout_y) / maxf(b.snout_h, 0.01), 2.0))
	var brow_v: float = b.eye_y + b.eye_h * 1.6
	var brow: float = b.brow_m * exp(-pow((v - brow_v) / 0.08, 2.0)) * maxf(1.0 - u * u, 0.0)
	return Vector3(x, y, -(bulge + snout + brow))


static func _apply_material(node: Node, mat: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = mat
	for c: Node in node.get_children():
		_apply_material(c, mat)


static func _load_model(path: String) -> PackedScene:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene
