## D-118 first-person weapon gadgets of the local human (visual_slots.md v1.3, crew_intent.md v1.1). Owner: ENV P.
## A child of FpViewmodel. While the equipped weapon's gadget is on (CrewWeapons.gadget_on(slot), ENV A, replicated;
## until that exists a local toggle on the intent's `gadget` edge), for each entry in WeaponStats.gadgets:
## - &"laser": a thin beam from the APPARENT `LaserOrigin` (projected out of the viewmodel camera like the tracer's
##   muzzle, FpViewmodel.marker_world_apparent) along the gun's apparent forward axis, cut at the first world hit
##   (gadget_laser_range_m), plus a small unshaded dot on that surface. World layer: the world camera draws it.
## - &"flashlight": a real SpotLight3D (no shadows) at the apparent `LightOrigin` along the same axis, range / angle /
##   energy from the resolved params, on the world layer + CrewView.VIEWMODEL_LIT_LAYER (it also lights the gun).
## Origins fall back to FpViewmodelTweak.gadget_fallback_marker (Muzzle) when the gun has no gadget marker; tuning
## from the merged WeaponDef/mod params (SpecialWeapons.params_of) with FpViewmodelTweak defaults. Presentation only.
class_name FpViewmodelGadgets
extends Node3D

const LASER: StringName = &"laser"
const FLASHLIGHT: StringName = &"flashlight"

## Local fallback state (slot -> on) while CrewWeapons has no gadget_on().
var local_on: Dictionary = {}
## Read only (tests): whether the beam / light showed on the last tick, and the beam's world end point.
var laser_visible: bool = false
var light_visible: bool = false
var laser_end: Vector3 = Vector3.ZERO

var _vm: FpViewmodel = null
var _beam: MeshInstance3D = null
var _dot: MeshInstance3D = null
var _light: SpotLight3D = null
var _seen_intent: CrewIntent = null


## World-space effects: parented OUTSIDE the camera (CrewView puts every mesh under the camera on the viewmodel
## layer, which draws at the viewmodel FOV), next to the crew; FpViewmodel frees it with itself.
func setup(vm: FpViewmodel) -> void:
	_vm = vm
	name = "FpGadgets"


func _process(_delta: float) -> void:
	tick()


## Fallback until ENV A's replicated toggle lands: the intent's gadget edge (built by PlayerInput in physics, one
## intent per tick) flips the equipped slot's local state.
func _physics_process(_delta: float) -> void:
	var c: CrewController = _vm.crew() if _vm != null and is_instance_valid(_vm) else null
	if c == null or not is_instance_valid(c) or c.weapons == null or c.weapons.has_method(&"gadget_on"):
		return
	if c.intent != null and c.intent != _seen_intent and c.intent.gadget:
		var ws: int = c.weapons.equipped_slot
		local_on[ws] = not bool(local_on.get(ws, false))
	_seen_intent = c.intent


## Whether `ws`'s gadget is on: ENV A's replicated state when available, else the local toggle.
func gadget_on(ws: int) -> bool:
	var c: CrewController = _vm.crew() if _vm != null else null
	if c != null and c.weapons != null and c.weapons.has_method(&"gadget_on"):
		return bool(c.weapons.call(&"gadget_on", ws))
	return bool(local_on.get(ws, false))


## Advance one frame (tests call it directly).
func tick() -> void:
	var c: CrewController = _vm.crew() if _vm != null and is_instance_valid(_vm) else null
	if c == null or not is_instance_valid(c) or c.weapons == null or not _vm.is_inside_tree():
		_hide_all()
		return
	var ws: int = c.weapons.equipped_slot
	var st: WeaponStats = c.weapons.stats(ws)
	var kinds: Array[StringName] = st.gadgets if st != null else [] as Array[StringName]
	var on: bool = gadget_on(ws) and not kinds.is_empty() and c.masked and _vm.weapon_visual != null \
		and is_instance_valid(_vm.weapon_visual) and _vm.action != FpViewmodel.Action.SWAP \
		and _vm.action != FpViewmodel.Action.INTERACT
	var params: Dictionary = _params(c, ws)
	_update_laser(on and kinds.has(LASER), params)
	_update_light(on and kinds.has(FLASHLIGHT), params)


func _params(c: CrewController, ws: int) -> Dictionary:
	var id: StringName = c.weapons.weapon_id(ws)
	var mods: Array[StringName] = []
	if c.loadout != null:
		var m: Variant = c.loadout.primary_mods if ws == Enums.WeaponSlot.PRIMARY else c.loadout.secondary_mods
		if m is Array:
			mods.assign(m)
	return SpecialWeapons.params_of(ContentDB.weapon(id), mods) if id != &"" else {}


## Apparent world origin and forward axis of a gadget marker (fallback marker when the gun has none).
func _origin(marker_name: StringName) -> Array:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var wv: WeaponVisual = _vm.weapon_visual
	var m: Node3D = wv.get_marker(marker_name)
	if m == null:
		m = wv.get_marker(tw.gadget_fallback_marker)
	if m == null or not m.is_inside_tree():
		return []
	# The viewmodel camera shares the world camera's orientation: the marker's -Z is the apparent axis.
	return [_vm.marker_world_apparent(m), (-m.global_basis.z).normalized()]


func _update_laser(show: bool, params: Dictionary) -> void:
	laser_visible = false
	if not show:
		_set_vis(_beam, false)
		_set_vis(_dot, false)
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var o: Array = _origin(&"LaserOrigin")
	if o.is_empty():
		_set_vis(_beam, false)
		_set_vis(_dot, false)
		return
	var from: Vector3 = o[0]
	var dir: Vector3 = o[1]
	var color: Color = params.get(&"gadget_laser_color", params.get("gadget_laser_color", tw.gadget_laser_color))
	var rng: float = float(params.get(&"gadget_laser_range_m", params.get("gadget_laser_range_m", tw.gadget_laser_range_m)))
	var to: Vector3 = from + dir * rng
	var hit: Dictionary = _ray(from, to)
	if not hit.is_empty():
		to = hit["position"]
	laser_end = to
	if _beam == null:
		_beam = _quad_mesh("LaserBeam")
		_dot = _quad_mesh("LaserDot")
	var len_m: float = from.distance_to(to)
	(_beam.material_override as StandardMaterial3D).albedo_color = Color(color, tw.gadget_laser_beam_alpha)
	_beam.global_transform = _beam_xform(from, to, tw.gadget_laser_width_m)
	_beam.visible = len_m > 0.01
	(_dot.material_override as StandardMaterial3D).albedo_color = color
	_dot.visible = not hit.is_empty()
	if _dot.visible:
		var n: Vector3 = hit["normal"]
		var cam: Camera3D = _vm.get_parent() as Camera3D
		var d: float = cam.global_position.distance_to(to) if cam != null else 5.0
		var size: float = tw.gadget_laser_dot_m * maxf(1.0, d / maxf(tw.gadget_laser_dot_ref_m, 0.1))
		var b: Basis = Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD)
		_dot.global_transform = Transform3D(b.scaled(Vector3(size, size, size)), to + n * 0.004)
	laser_visible = true


func _update_light(show: bool, params: Dictionary) -> void:
	light_visible = false
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var o: Array = _origin(&"LightOrigin") if show else []
	if o.is_empty():
		if _light != null:
			_light.visible = false
		return
	if _light == null:
		_light = SpotLight3D.new()
		_light.name = "Flashlight"
		_light.layers = 1 | CrewView.VIEWMODEL_LIT_LAYER
		_light.shadow_enabled = false
		_light.light_volumetric_fog_energy = 0.0
		add_child(_light)
	var from: Vector3 = o[0]
	var dir: Vector3 = o[1]
	_light.spot_range = float(params.get(&"gadget_light_range_m", params.get("gadget_light_range_m", tw.gadget_light_range_m)))
	_light.spot_angle = float(params.get(&"gadget_light_angle_deg", params.get("gadget_light_angle_deg",
		tw.gadget_light_angle_deg)))
	_light.light_energy = float(params.get(&"gadget_light_energy", params.get("gadget_light_energy",
		tw.gadget_light_energy)))
	_light.light_color = tw.gadget_light_color
	_light.spot_attenuation = tw.gadget_light_attenuation
	_light.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD),
		from)
	_light.visible = true
	light_visible = true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var c: CrewController = _vm.crew()
	if c == null or not c.is_inside_tree():
		return {}
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [c.get_rid()]
	q.collide_with_areas = false
	return c.get_world_3d().direct_space_state.intersect_ray(q)


## A camera-facing ribbon from `a` to `b` (QuadMesh 1 x 1 in XY, stretched along the beam).
func _beam_xform(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var along: Vector3 = b - a
	var cam: Camera3D = _vm.get_parent() as Camera3D
	var to_cam: Vector3 = (cam.global_position - (a + b) * 0.5) if cam != null else Vector3.BACK
	var side: Vector3 = along.cross(to_cam).normalized() * width
	if side.length_squared() < 1e-10:
		side = Vector3.RIGHT * width
	var normal: Vector3 = side.cross(along).normalized()
	return Transform3D(Basis(side, along, normal), (a + b) * 0.5)


func _quad_mesh(node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 1
	add_child(mi)
	return mi


func _set_vis(n: Node3D, v: bool) -> void:
	if n != null and is_instance_valid(n):
		n.visible = v


func _hide_all() -> void:
	laser_visible = false
	light_visible = false
	_set_vis(_beam, false)
	_set_vis(_dot, false)
	_set_vis(_light, false)
