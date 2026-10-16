## D-118 third-person weapon gadgets of one crew member (visual_slots.md v1.3). Owner: ENV A.
## Child `GadgetVisual` of a CrewController, added by AnimDriver.ensure (so: every crew member but the local
## human, whose first-person laser / flashlight ENV P draws on the viewmodel). **Presentation only.**
## While the equipped slot's gadget is on (CrewWeapons.gadget_on, replicated as crew state "gd", so it works
## the same on the server and on clients):
## - laser (`&"laser"` in CrewWeapons.toggle_gadgets): a thin emissive beam from the outermost `LaserOrigin`
##   marker of the third-person WeaponVisual (−Z = beam), raycast to the first hit and capped at
##   `gadget_laser_range_m`, plus a small dot at the hit;
## - flashlight (`&"flashlight"`): a SpotLight3D (shadows off) at the outermost `LightOrigin` marker with
##   `gadget_light_range_m` / `gadget_light_angle_deg` (as SpotLight3D.spot_angle) / `gadget_light_energy`.
## Params come from the resolved weapon params (SpecialWeapons.params_for), else AnimTweak's gadget_* fallbacks.
## No marker (B has no gadget mod scenes yet): the `Muzzle` marker, else the 3P weapon's own −Z, else the eye
## along aim_direction (capsule placeholder). Hidden while the 3P weapon is hidden (poses, death) or the body is.
## Headless: the nodes still toggle (tests read them) but nothing updates per frame; tests call update_now().
class_name CrewGadgetVisual
extends Node3D

const NODE_NAME: String = "GadgetVisual"
const LASER: StringName = &"laser"
const FLASHLIGHT: StringName = &"flashlight"
const LASER_MARKER: StringName = &"LaserOrigin"
const LIGHT_MARKER: StringName = &"LightOrigin"
const MUZZLE_MARKER: StringName = &"Muzzle"
const PROCESS_PRIORITY: int = 100

## Built in _ready: beam (unit box scaled to the length), hit dot, flashlight.
var beam: MeshInstance3D = null
var dot: MeshInstance3D = null
var light: SpotLight3D = null
## Current beam length (m): distance to the first hit, else the laser range.
var beam_length: float = 0.0
var laser_on: bool = false
var light_on: bool = false

var _crew: CrewController = null
var _weapons: CrewWeapons = null
var _laser_mat: StandardMaterial3D = null
var _laser_range: float = 50.0
var _headless: bool = false


## The gadget visual of `crew` (null when it has none).
static func of(crew: Node) -> CrewGadgetVisual:
	return crew.get_node_or_null(NODE_NAME) as CrewGadgetVisual if crew != null else null


## Add (or re-bind) the gadget visual of `crew`; returns it.
static func ensure(crew: CrewController) -> CrewGadgetVisual:
	if crew == null:
		return null
	var g: CrewGadgetVisual = of(crew)
	if g != null:
		g.bind()
		return g
	g = CrewGadgetVisual.new()
	g.name = NODE_NAME
	crew.add_child(g)
	return g


func _ready() -> void:
	top_level = true  # world-space transforms written directly each update
	process_priority = PROCESS_PRIORITY  # after the AnimationPlayer has posed the hand this frame
	_headless = DisplayServer.get_name() == "headless"
	_build()
	bind()


func _exit_tree() -> void:
	_connect(null)


## (Re)find the crew and its weapons, then refresh.
func bind() -> void:
	_crew = get_parent() as CrewController
	_connect(_crew.weapons if _crew != null else null)
	refresh()


func _connect(w: CrewWeapons) -> void:
	if _weapons != null and is_instance_valid(_weapons) and _weapons != w:
		if _weapons.gadget_changed.is_connected(_on_gadget_changed):
			_weapons.gadget_changed.disconnect(_on_gadget_changed)
		if _weapons.equipped_changed.is_connected(_on_equipped_changed):
			_weapons.equipped_changed.disconnect(_on_equipped_changed)
	_weapons = w
	if w != null and not w.gadget_changed.is_connected(_on_gadget_changed):
		w.gadget_changed.connect(_on_gadget_changed)
		w.equipped_changed.connect(_on_equipped_changed)


func _build() -> void:
	var tw: AnimTweak = AnimTweak.data()
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.emission_enabled = true
	_laser_mat.emission_energy_multiplier = tw.gadget_laser_emission
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _laser_mat
	beam = MeshInstance3D.new()
	beam.name = "LaserBeam"
	beam.mesh = box
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.top_level = true
	add_child(beam)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = tw.gadget_dot_radius_m
	sphere.height = tw.gadget_dot_radius_m * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _laser_mat
	dot = MeshInstance3D.new()
	dot.name = "LaserDot"
	dot.mesh = sphere
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.top_level = true
	add_child(dot)
	light = SpotLight3D.new()
	light.name = "Flashlight"
	light.shadow_enabled = false
	light.top_level = true
	light.layers = 1 | CrewView.VIEWMODEL_LIT_LAYER  # D-094: a teammate's flashlight also lights our viewmodel
	add_child(light)
	_hide_all()


## Re-read the equipped slot, its gadget state and params; show / hide accordingly.
func refresh() -> void:
	if beam == null:
		return
	var ws: int = _weapons.equipped_slot if _weapons != null else -1
	var active: bool = _weapons != null and is_instance_valid(_weapons) and not _first_person_owner() \
		and _weapons.gadget_on(ws)
	var kinds: Array[StringName] = _weapons.toggle_gadgets(ws) if active else ([] as Array[StringName])
	laser_on = kinds.has(LASER)
	light_on = kinds.has(FLASHLIGHT)
	if laser_on or light_on:
		_apply_params(SpecialWeapons.params_for(_crew, ws))
	set_process(not _headless and (laser_on or light_on))
	if not laser_on and not light_on:
		_hide_all()
		return
	update_now()


## Place the beam / dot / light for this frame (called from _process; tests call it directly).
func update_now() -> void:
	if beam == null or _crew == null or not _crew.is_inside_tree():
		return
	if not _shown():
		_hide_all()
		return
	if laser_on:
		_update_laser(_origin(LASER_MARKER))
	else:
		beam.visible = false
		dot.visible = false
	light.visible = light_on
	if light_on:
		var lo: Transform3D = _origin(LIGHT_MARKER)
		light.global_transform = Transform3D(lo.basis.orthonormalized(), lo.origin)


func _process(_delta: float) -> void:
	update_now()


func _update_laser(o: Transform3D) -> void:
	var b: Basis = o.basis.orthonormalized()
	var fwd: Vector3 = -b.z
	var tw: CombatTweak = CombatTweak.data()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(o.origin, o.origin + fwd * _laser_range,
		tw.hitscan_mask | tw.penetrable_mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = _own_rids()
	var hit: Dictionary = _crew.get_world_3d().direct_space_state.intersect_ray(q)
	beam_length = _laser_range
	if not hit.is_empty():
		var p: Vector3 = hit.get("position", o.origin) as Vector3
		beam_length = o.origin.distance_to(p)
		var n: Vector3 = hit.get("normal", -fwd) as Vector3
		dot.global_position = p + n * AnimTweak.data().gadget_dot_offset_m
	dot.visible = not hit.is_empty()
	var w: float = AnimTweak.data().gadget_beam_width_m
	beam.global_transform = Transform3D(b.scaled_local(Vector3(w, w, maxf(beam_length, 0.001))),
		o.origin + fwd * (beam_length * 0.5))
	beam.visible = true


func _apply_params(p: Dictionary) -> void:
	var tw: AnimTweak = AnimTweak.data()
	_laser_range = maxf(float(p.get("gadget_laser_range_m", tw.gadget_laser_range_m)), 0.01)
	var c: Color = _color(p.get("gadget_laser_color", tw.gadget_laser_color), tw.gadget_laser_color)
	_laser_mat.albedo_color = c
	_laser_mat.emission = c
	light.spot_range = maxf(float(p.get("gadget_light_range_m", tw.gadget_light_range_m)), 0.01)
	light.spot_angle = clampf(float(p.get("gadget_light_angle_deg", tw.gadget_light_angle_deg)), 1.0, 89.0)
	light.light_energy = float(p.get("gadget_light_energy", tw.gadget_light_energy))


## World transform of the gadget emitter (−Z = direction): the outermost `marker` of the 3P weapon, else its
## Muzzle, else the weapon itself, else the eye looking along aim_direction.
func _origin(marker: StringName) -> Transform3D:
	var wv: Node3D = _weapon_visual()
	if wv != null:
		for m_name: StringName in [marker, MUZZLE_MARKER]:
			var m: Node3D = wv.call(&"get_marker", m_name) as Node3D if wv.has_method(&"get_marker") else null
			if m != null and m.is_inside_tree():
				return m.global_transform
		return wv.global_transform
	var d: Vector3 = _crew.aim_direction()
	var up: Vector3 = Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	return Transform3D(Basis.looking_at(d, up), _crew.eye_position())


func _weapon_visual() -> Node3D:
	var ad: AnimDriver = AnimDriver.of(_crew)
	if ad == null or ad.weapon_visual == null or not is_instance_valid(ad.weapon_visual):
		return null
	return ad.weapon_visual if ad.weapon_visual.is_inside_tree() else null


func _shown() -> bool:
	if not _crew.is_visible_in_tree():
		return false
	var ad: AnimDriver = AnimDriver.of(_crew)
	var wv: Node3D = ad.weapon_visual if ad != null and is_instance_valid(ad.weapon_visual) else null
	return wv == null or wv.is_visible_in_tree()


## The local human's own body: P draws its gadgets in first person.
func _first_person_owner() -> bool:
	return _crew != null and not _crew.is_ai and _crew.is_local()


func _own_rids() -> Array[RID]:
	var out: Array[RID] = [_crew.get_rid()]
	for n: Node in _crew.find_children("*", "CollisionObject3D", true, false):
		out.append((n as CollisionObject3D).get_rid())
	return out


func _hide_all() -> void:
	beam.visible = false
	dot.visible = false
	light.visible = false
	beam_length = 0.0


func _on_gadget_changed(_ws: int, _on: bool) -> void:
	refresh()


func _on_equipped_changed(_ws: int) -> void:
	refresh()


static func _color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v as Color
	if v is String or v is StringName:
		return Color.from_string(String(v), fallback)
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v as Array
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return fallback
