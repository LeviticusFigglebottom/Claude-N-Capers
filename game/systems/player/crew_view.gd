## Presentation of one crew member (QB-47, D-038). Owner: ENV A. Child `View` of every CrewController,
## added by CrewController._ready. Visual only: no gameplay state, safe headless.
## - Local human (CrewController.is_local()): makes `Head/Camera` current and puts ENV B's
##   `WeaponVisual` (by class name) for the equipped weapon under it at CrewTweak.viewmodel_offset;
##   sets `crew.weapon_visual` (CrewWeapons reads get_marker(&"Muzzle")). Rebuilt on weapon switch
##   (CrewWeapons.equipped_changed) and on CrewController.set_loadout(). When someone else puts a
##   WeaponVisual under the camera (e.g. ENV B's firing range bridge), ours is removed and that one is kept.
##   With the first-person arms (FpViewmodel, characters.md v1.3) the WeaponVisual hangs on their `weapon` bone.
##   None while the crew member is a civilian (S1.3 / QC-43 hub: no weapon drawn).
## - Every crew member, once masked: the mask at the model's `Head/Socket`, built on every peer from
##   `Loadout.mask_descriptor` (QA-25, D-043: MaskCatalog.from_descriptor; the server replicates it with
##   a reliable authority RPC on set_loadout, on mask-up and on set_mask_descriptor) or, when that is {}, the preset `Loadout.mask`
##   (MaskCatalog.resolve), then MaskComposer.instantiate (ENV B, by class name; characters.md v1.2).
##   The capsule placeholder gets a `Visual/Head` Node3D with a `Socket` Marker3D so the path matches.
##   On the local human the mask meshes use FIRST_PERSON_HIDDEN_LAYER, which its camera does not render.
## - Everyone but the local human, when the visual is an animated character (characters.md v1.3): an
##   AnimDriver (systems/anim) plays the humanoid clips and holds the third-person weapon at HandR/Socket.
class_name CrewView
extends Node

## D-084: the local view's zoom changed (f = zoom_factor). Emitted only by the local human's view.
signal zoom_factor_changed(f: float)

const NODE_NAME: String = "View"
const VIEWMODEL_NAME: String = "Viewmodel"
const MASK_NAME: String = "Mask"
## Render layer 20: third-person-only parts of the local human (culled by its own camera).
const FIRST_PERSON_HIDDEN_LAYER: int = 1 << 19
## PP-P-11: render layer of everything under the local camera (arms, weapon, held items); drawn by the
## viewmodel camera at FpViewmodelTweak.viewmodel_fov_deg, culled from the world camera.
const VIEWMODEL_LAYER: int = 1 << 18
## D-094 (visual_slots 1.1, QP-3 layer number pending): set IN ADDITION to a Light3D's normal layers on lights that
## should also light the viewmodel (lamps, muzzle flashes, flashlights). The viewmodel camera culls everything else,
## lights included. Never used on geometry.
const VIEWMODEL_LIT_LAYER: int = 1 << 20
## PO6-10: set IN ADDITION to VIEWMODEL_LAYER on the first-person weapon's meshes (not the arms), so the viewmodel
## gun fill light (FpViewmodelTweak.viewmodel_gun_fill_*) lifts the black-albedo gun without flattening the arms.
const VIEWMODEL_GUN_LAYER: int = 1 << 21

## Compatibility alias of the crew member's `Loadout.mask_descriptor` (QA-25); setting it calls
## set_mask_descriptor().
## The local human's view (null when none).
static var _local_view: CrewView = null
var mask_descriptor: Dictionary:
	get:
		return _crew.loadout.mask_descriptor if _crew != null and _crew.loadout != null else {}
	set(value):
		set_mask_descriptor(value)
## True once an external WeaponVisual owns the camera (ours is no longer attached).
var external_viewmodel: bool = false
## P1-03 (read-only): eased 0 (hip) .. 1 (ADS) shared by the camera zoom and the FpViewmodel arms (one weight, one
## rate: CrewView.ads_rate(crew), smoothstep ease). Follows CrewController.is_aiming().
var ads_blend: float:
	get:
		return smoothstep(0.0, 1.0, _ads_weight)
## D-084 (read-only): linear zoom of the local camera, tan(base_fov/2) / tan(current_fov/2); 1.0 at hip fire and
## for every non-local view. ENV C/D scale visibility ranges by it (mesh LOD is already FOV-aware in Godot).
var zoom_factor: float:
	get:
		return _zoom_factor

var _crew: CrewController = null
var _viewmodel: Node3D = null
var _fp: FpViewmodel = null
var _vm_viewport: SubViewport = null
var _vm_cam: Camera3D = null
## PO6-10: the gun-only fill light (null when off); its energy eases from hip to ADS with ads_blend.
var _vm_gun_fill: DirectionalLight3D = null
## Scoped ADS: the gun image (hidden at a full sight picture) and the overlay above it.
var _vm_image: TextureRect = null
var _scope: FpScopeOverlay = null
var _mask: Node3D = null
var _mask_id: StringName = &""
var _ads_weight: float = 0.0
var _zoom_factor: float = 1.0
## Descriptor the current mask was built from (rebuild when it changes).
var _mask_desc: Dictionary = {}
## Heister whose body is under `Visual` (&"" = the placeholder).
var _body_id: StringName = &""


## The crew member's view component (null when missing).
static func of(crew: Node) -> CrewView:
	return crew.get_node_or_null(NODE_NAME) as CrewView if crew != null else null


## P1-03: `crew` is actually aiming down sights: aim held, masked, mobile, not sprinting (sprint wins, PD2) and
## not reloading. Camera zoom (CrewView) and arms (FpViewmodel) both follow this.
static func is_aiming(crew: CrewController) -> bool:
	if crew == null or crew.intent == null or not crew.intent.aim or crew.is_casing() or crew.sprinting:
		return false
	if crew.crew_state != Enums.CrewState.NORMAL and crew.crew_state != Enums.CrewState.SWAN_SONG:
		return false
	return crew.weapons == null or not crew.weapons.reloading


## PO-4 (PD2 TRANSITION_DURATION 0.23 s + weapon transition_duration): ADS in/out rate (1/s) of the equipped weapon,
## 1 / WeaponStats.ads_time_s (weapon data, incl. mods); FpViewmodelTweak.ads_rate when the weapon has none. Shared by
## the camera zoom and the FpViewmodel arms so sights and zoom arrive together (P1-03).
static func ads_rate(crew: CrewController) -> float:
	var w: CrewWeapons = crew.weapons if crew != null else null
	var st: WeaponStats = w.stats(w.equipped_slot) if w != null else null
	var base: float = 1.0 / st.ads_time_s if st != null and st.ads_time_s > 0.0 else FpViewmodelTweak.data().ads_rate
	if crew == null:
		return base
	# A4-04 weapon.ads_speed_mult by class (Snap Shot .all, Pump Action .shotgun, Hushed Hands .suppressed).
	return base * Modifiers.mult(crew.slot, &"weapon.ads_speed_mult", weapon_qualifiers(crew))


## A4-04: Modifiers qualifiers of `crew`'s equipped weapon: its class (Enums.weapon_class_qualifier) and &"suppressed"
## when it is.
static func weapon_qualifiers(crew: CrewController) -> Array[StringName]:
	var out: Array[StringName] = []
	var w: CrewWeapons = crew.weapons if crew != null else null
	if w == null:
		return out
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(w.equipped_slot))
	if def != null:
		out.append(Enums.weapon_class_qualifier(def.weapon_class))
	if w.is_suppressed():
		out.append(&"suppressed")
	return out


## D-084: zoom_factor of the local player's view; 1.0 when there is none.
static func local_zoom_factor() -> float:
	if _local_view == null or not is_instance_valid(_local_view) or not _local_view.is_inside_tree():
		return 1.0
	return _local_view.zoom_factor


## D-084: the local player's view (null when none), for connecting zoom_factor_changed.
static func local_view() -> CrewView:
	return _local_view if _local_view != null and is_instance_valid(_local_view) else null


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew == null:
		return
	_crew.masked_changed.connect(_on_masked_changed)
	_crew.crew_state_changed.connect(func(_o: int, _n: int) -> void: _apply_casing_visibility())
	_crew.civilian_changed.connect(func(_c: bool) -> void: refresh_weapon())
	if _crew.weapons != null:
		_crew.weapons.equipped_changed.connect(func(_ws: int) -> void: refresh_weapon(true))
	var cam: Camera3D = camera()
	if cam != null:
		cam.child_entered_tree.connect(_on_camera_child)
	get_tree().node_added.connect(_on_node_added)
	refresh.call_deferred()


func _exit_tree() -> void:
	if _local_view == self:
		_local_view = null
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## The usual FPS treatment (lead, ENV D): nothing under the local camera (FP weapon, item, arms) casts shadows;
## rails and scope rings otherwise cast saw-toothed shadows on the FP sleeves. Third-person weapons keep theirs.
## Also catches meshes a WeaponVisual / mod builds after attach.
func _on_node_added(n: Node) -> void:
	var g: GeometryInstance3D = n as GeometryInstance3D
	if g == null or not _is_local_human():
		return
	var cam: Camera3D = camera()
	if cam != null and cam.is_ancestor_of(g):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _vm_cam != null:
			g.layers = viewmodel_layers_for(g, cam)


## Re-apply everything (camera, weapon visual, mask).
func refresh() -> void:
	if _crew == null or not is_instance_valid(_crew) or not _crew.is_inside_tree():
		return
	refresh_camera()
	refresh_body()
	refresh_weapon()
	refresh_mask()
	if not _is_local_human():
		AnimDriver.ensure(_crew)  # D-041: third-person clips + HandR weapon (animated visuals only)


## D-073: the third-person body of `crew.heister` (CrewTweak.body_scenes) under `Visual`, replacing the capsule
## placeholder (none for generic crew). The local human's own body renders on FIRST_PERSON_HIDDEN_LAYER only
## (its camera culls it; it still casts shadows). The mask moves to the new body's Head/Socket.
func refresh_body() -> void:
	var ps: PackedScene = Tweak.crew().body_scenes.get(_crew.heister) if _crew.heister != &"" else null
	var visual: Node3D = _crew.get_node_or_null(^"Visual") as Node3D
	if ps == null or visual == null or _crew.heister == _body_id:
		return
	_clear_mask()
	for c: Node in visual.get_children():
		visual.remove_child(c)
		c.queue_free()
	var body: Node = ps.instantiate()
	visual.add_child(body)
	_body_id = _crew.heister
	if _is_local_human():
		for g: Node in body.find_children("*", "VisualInstance3D", true, false):
			(g as VisualInstance3D).layers = FIRST_PERSON_HIDDEN_LAYER


func camera() -> Camera3D:
	return _crew.get_node_or_null(^"Head/Camera") as Camera3D if _crew != null else null


## Local human only: this crew member's camera becomes the viewport's current camera.
func refresh_camera() -> void:
	var cam: Camera3D = camera()
	if cam == null or not cam.is_inside_tree() or not _is_local_human():
		return
	cam.cull_mask &= ~FIRST_PERSON_HIDDEN_LAYER
	cam.near = Tweak.crew().camera_near_m  # D-069
	cam.make_current()


## B5-01 options: the local camera FOV is GameSettings.fov() (re-read every frame, so a changed setting
## applies at once); aiming zooms to fov / WeaponStats.magnification at CrewView.ads_rate (P1-03).
func _process(delta: float) -> void:
	if _crew == null or not _is_local_human():
		return
	var cam: Camera3D = camera()
	var gs: GameSettings = GameSettings.current()
	if cam == null or gs == null:
		return
	var mag: float = 1.0
	var w: CrewWeapons = _crew.weapons
	var st: WeaponStats = w.stats(w.equipped_slot) if w != null else null
	if st != null:
		mag = maxf(st.magnification, 1.0)
	# P1-03: arms' rate
	_ads_weight = move_toward(_ads_weight, 1.0 if CrewView.is_aiming(_crew) else 0.0, delta * CrewView.ads_rate(_crew))
	cam.fov = gs.fov() / lerpf(1.0, mag, ads_blend)
	_publish_ads()
	_update_viewmodel_camera(cam)
	_update_scope(st, mag)
	_local_view = self
	_set_zoom_factor(zoom_factor_for(gs.fov(), cam.fov))


## Scoped ADS (LEAD 2026-10-16, PD2): a high-power scope fades in the FpScopeOverlay sight picture over the end
## of ads_blend and hides the gun image (no opaque ocular disc); the world FOV zoom by magnification is above.
## ENV B's optional WeaponStats fields `is_scope` (bool), `scope_reticle` (StringName) and `scope_reticle_color`
## (Color) win over the magnification threshold and the tweak defaults when they exist.
func _update_scope(st: WeaponStats, mag: float) -> void:
	if _scope == null or not is_instance_valid(_scope):
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var scoped: bool = scope_overlay_for(st, mag)
	var t: float = 0.0
	if scoped and tw.scope_blend_in.y > tw.scope_blend_in.x:
		t = clampf(inverse_lerp(tw.scope_blend_in.x, tw.scope_blend_in.y, ads_blend), 0.0, 1.0)
	if scoped:
		var rs: Variant = st.get(&"scope_reticle") if st != null else null
		_scope.style = rs if rs is StringName and rs != &"" else tw.scope_reticle_default
		var rc: Variant = st.get(&"scope_reticle_color") if st != null else null
		_scope.tint = rc if rc is Color and (rc as Color).a > 0.0 else tw.scope_reticle_color
	_scope.amount = t
	_scope.offset = _scope_sway_px(tw) if t > 0.0 else Vector2.ZERO
	_publish_scope(t > 0.5)
	if _vm_image != null and is_instance_valid(_vm_image):
		_vm_image.visible = t < tw.scope_hide_gun_at


## PO (2026-10-23): PD2 hides the crosshair while aiming down sights. The local HUD model carries `ads_blend` (0 hip
## .. 1 ADS, this view's eased weight), written here every frame like `scoped_ads`; ENV B fades the crosshair by it.
## Duck-typed until ENV A's field is on this branch.
func _publish_ads() -> void:
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	var hm: Object = rt.hud_model if rt != null else null
	if hm != null and &"ads_blend" in hm:
		hm.set(&"ads_blend", ads_blend)


## ui_hud.md v1.16 (ENV A e308d22e): the local HUD model carries `scoped_ads` and `scope_ring` (the ocular's
## screen-space bounds, viewport px; Rect2() when not scoped), written here every frame (no signal; the model never
## writes them) so ENV B can move text panels out of the ring. Duck-typed until the fields are on this branch.
func _publish_scope(scoped: bool) -> void:
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	var hm: Object = rt.hud_model if rt != null else null
	if hm == null or not (&"scoped_ads" in hm) or not (&"scope_ring" in hm):
		return
	var ring: Rect2 = Rect2()
	if scoped:
		var size: Vector2 = _scope.size
		var r: float = FpScopeOverlay.ocular_radius(size)
		ring = Rect2(size * 0.5 + _scope.offset - Vector2(r, r), Vector2(r, r) * 2.0)
	hm.set(&"scoped_ads", scoped)
	hm.set(&"scope_ring", ring)


## The viewmodel's sight sway (deg) as a screen offset (px) at the world camera's zoomed FOV: yaw left / pitch up
## move the sight picture left / up.
func _scope_sway_px(tw: FpViewmodelTweak) -> Vector2:
	var cam: Camera3D = camera()
	var vm: FpViewmodel = FpViewmodel.of(cam) if cam != null else null
	if vm == null:
		return Vector2.ZERO
	var deg: Vector2 = vm.sight_sway_deg(tw.scope_sway_mult, tw.scope_breath_mult)
	var f: float = cam.get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	return Vector2(-tan(deg_to_rad(deg.x)), -tan(deg_to_rad(deg.y))) * f


## Whether `st` (magnification `mag`) is a scope with a sight picture overlay rather than a 3D sight.
static func scope_overlay_for(st: WeaponStats, mag: float) -> bool:
	var flag: Variant = st.get(&"is_scope") if st != null else null
	if flag is bool:
		return flag as bool
	return mag >= FpViewmodelTweak.data().scope_overlay_min_mag


## Read only (tests, review tools): the scope overlay (null until the viewmodel camera exists).
func scope_overlay() -> FpScopeOverlay:
	return _scope if _scope != null and is_instance_valid(_scope) else null


## PP-P-11 (PD2): the arms and weapon under `cam` render through a second camera with a fixed narrower FOV into a
## transparent SubViewport (same World3D: same lights, GI and shadows) drawn under the HUD; the world camera
## culls them. The world FOV setting and ADS zoom no longer stretch the gun. The viewmodel camera shares the
## world camera's transform, so the ADS AimPoint on the camera axis stays on the crosshair.
func _update_viewmodel_camera(cam: Camera3D) -> void:
	var fov: float = FpViewmodelTweak.data().viewmodel_fov_deg
	if fov <= 0.0:
		return
	if _vm_cam == null or not is_instance_valid(_vm_cam):
		_build_viewmodel_camera(cam)
	var size: Vector2i = Vector2i(cam.get_viewport().get_visible_rect().size)
	if _vm_viewport.size != size and size.x > 0 and size.y > 0:
		_vm_viewport.size = size
	cam.cull_mask &= ~VIEWMODEL_LAYER
	_vm_cam.global_transform = cam.global_transform
	_vm_cam.fov = fov
	_vm_cam.near = cam.near
	if _vm_gun_fill != null and is_instance_valid(_vm_gun_fill):
		var vt: FpViewmodelTweak = FpViewmodelTweak.data()
		_vm_gun_fill.light_energy = lerpf(vt.viewmodel_gun_fill_energy, vt.viewmodel_gun_fill_ads_energy, ads_blend)


## The camera that draws the viewmodel layer (null when the arms draw with the world camera).
func viewmodel_camera() -> Camera3D:
	return _vm_cam if _vm_cam != null and is_instance_valid(_vm_cam) else null


## Viewmodel camera FOV in degrees (0 when the arms draw with the world camera).
func viewmodel_fov() -> float:
	return _vm_cam.fov if _vm_cam != null and is_instance_valid(_vm_cam) else 0.0


func _build_viewmodel_camera(cam: Camera3D) -> void:
	var vt: FpViewmodelTweak = FpViewmodelTweak.data()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ViewmodelLayer"
	layer.layer = -1  # above the 3D world, below the HUD
	add_child(layer)
	var vp: SubViewport = SubViewport.new()
	vp.name = "Viewmodel"
	vp.transparent_bg = true
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(cam.get_viewport().get_visible_rect().size)
	layer.add_child(vp)  # no own_world_3d: the parent viewport's World3D (same lights / GI)
	_vm_cam = Camera3D.new()
	_vm_cam.name = "ViewmodelCamera"
	_vm_cam.cull_mask = VIEWMODEL_LAYER | VIEWMODEL_LIT_LAYER
	_vm_cam.far = 20.0
	var we: Environment = cam.get_world_3d().environment if cam.get_world_3d() != null else null
	if we != null:
		var env: Environment = we.duplicate() as Environment
		env.background_mode = Environment.BG_CLEAR_COLOR  # transparent: only the arms draw here
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ssr_enabled = false
		env.sdfgi_enabled = false
		env.ambient_light_energy = we.ambient_light_energy * vt.viewmodel_ambient_mult
		_vm_cam.environment = env
	vp.add_child(_vm_cam)
	if vt.viewmodel_key_light_energy > 0.0:
		var key: DirectionalLight3D = DirectionalLight3D.new()
		key.name = "ViewmodelKeyLight"
		key.layers = VIEWMODEL_LAYER  # Camera3D.cull_mask culls lights by `layers` too: on layer 1 the vm camera drops it
		key.light_cull_mask = VIEWMODEL_LAYER  # the world never sees it
		key.light_energy = vt.viewmodel_key_light_energy
		key.light_color = vt.viewmodel_key_light_color
		key.shadow_enabled = false
		key.light_volumetric_fog_energy = 0.0
		key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		key.rotation_degrees = vt.viewmodel_key_light_euler_deg
		_vm_cam.add_child(key)
	_vm_cam.current = true
	_vm_viewport = vp
	var tr: TextureRect = TextureRect.new()
	tr.name = "ViewmodelImage"
	tr.texture = vp.get_texture()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(tr)
	_vm_image = tr
	_scope = FpScopeOverlay.new()
	layer.add_child(_scope)  # above the gun image, below the HUD
	if vt.viewmodel_gun_fill_energy > 0.0:
		var fill: DirectionalLight3D = DirectionalLight3D.new()
		fill.name = "ViewmodelGunFill"
		fill.layers = VIEWMODEL_LAYER  # inside the vm camera's cull mask
		fill.light_cull_mask = VIEWMODEL_GUN_LAYER  # the gun only: the arms and the world never see it
		fill.light_energy = vt.viewmodel_gun_fill_energy
		fill.light_color = vt.viewmodel_gun_fill_color
		fill.light_specular = vt.viewmodel_gun_fill_specular
		fill.shadow_enabled = false
		fill.light_volumetric_fog_energy = 0.0
		fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		fill.rotation_degrees = vt.viewmodel_gun_fill_euler_deg
		_vm_cam.add_child(fill)
		_vm_gun_fill = fill
	for n: Node in cam.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).layers = viewmodel_layers_for(n as GeometryInstance3D, cam)


## PO6-10: render layers of a mesh under the local camera: VIEWMODEL_LAYER, plus VIEWMODEL_GUN_LAYER inside a
## WeaponVisual (the gun and its mods, not the arms).
static func viewmodel_layers_for(g: GeometryInstance3D, cam: Node) -> int:
	var n: Node = g.get_parent()
	while n != null and n != cam:
		if n is WeaponVisual:
			return VIEWMODEL_LAYER | VIEWMODEL_GUN_LAYER
		n = n.get_parent()
	return VIEWMODEL_LAYER


## D-084: linear zoom of `fov_deg` relative to `base_fov_deg` (both vertical, degrees).
static func zoom_factor_for(base_fov_deg: float, fov_deg: float) -> float:
	var t: float = tan(deg_to_rad(clampf(fov_deg, 1.0, 179.0)) * 0.5)
	return tan(deg_to_rad(clampf(base_fov_deg, 1.0, 179.0)) * 0.5) / t if t > 0.0 else 1.0


func _set_zoom_factor(f: float) -> void:
	if absf(f - 1.0) < 1e-4:
		f = 1.0
	if absf(f - _zoom_factor) < 1e-4 and not (f == 1.0 and _zoom_factor != 1.0):
		return
	_zoom_factor = f
	zoom_factor_changed.emit(f)


## Local human only: WeaponVisual of the equipped weapon under the camera. With the first-person arms
## (FpViewmodel, characters.md v1.3) it hangs on the arms' `weapon` bone; without them (no arms scene, or no
## library for the weapon's anim_set) it sits at CrewTweak.viewmodel_offset. `animated` (weapon switch):
## the arms play holster + draw over the gameplay equip time.
func refresh_weapon(animated: bool = false) -> void:
	if external_viewmodel:
		return
	var cam: Camera3D = camera()
	var ws: int = _crew.weapons.equipped_slot if _crew.weapons != null else -1
	var def: WeaponDef = null
	if cam != null and _is_local_human() and _crew.weapons != null and _crew.weapons.has_weapon(ws):
		def = ContentDB.weapon(_crew.weapons.weapon_id(ws))
	if _crew.civilian:
		def = null  # S1.3 / QC-43: civilian mode has no weapon drawn
	if def == null or def.model == null:
		_clear_viewmodel()
		_clear_fp()
		return
	var l: Loadout = _crew.loadout
	var mod_ids: Array[StringName] = []
	if l != null:
		mod_ids = l.primary_mods if ws == Enums.WeaponSlot.PRIMARY else l.secondary_mods
	var old: Node3D = viewmodel()
	if old != null and _crew.weapon_visual == old:
		_crew.weapon_visual = null
	var fp: FpViewmodel = _ensure_fp(cam, def)
	var wv: WeaponVisual = WeaponVisual.new()
	wv.name = VIEWMODEL_NAME
	_viewmodel = wv
	if fp != null:
		wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
		wv.apply_loadout_finish(_crew.loadout)  # B7-04 finish on the FP gun too (ENV B PO6-12 ask)
		var keep: Node3D = old if old != null and fp.is_ancestor_of(old) else null
		if old != null and keep == null:
			_free_node(old)
		fp.attach_weapon(wv, def, keep, _equip_time(ws, def) if animated else -1.0)
	else:
		if old != null:
			_free_node(old)
		wv.position = Tweak.crew().viewmodel_offset
		cam.add_child(wv)
		wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
		wv.apply_loadout_finish(_crew.loadout)
	_crew.weapon_visual = wv
	WeaponPartsAnimator.attach(wv, _crew.weapons)  # B4-18: Breech / Lever / String / Blade / Rotor
	_apply_casing_visibility()


## PD2: casing (unmasked) shows no first-person weapon or arms; masking up draws it (P, lead request). Nor does
## custody (PD2 spectates; the downed secondary still shows). Visibility only: the WeaponVisual stays attached (its
## Muzzle marker is gameplay's tracer origin).
func _apply_casing_visibility() -> void:
	var show: bool = not _crew.is_casing() and _crew.crew_state != Enums.CrewState.CUSTODY
	if _fp != null and is_instance_valid(_fp):
		_fp.visible = show
	if _viewmodel != null and is_instance_valid(_viewmodel) and (_fp == null or not is_instance_valid(_fp)):
		_viewmodel.visible = show


## Is the first-person weapon / arms visible (false while casing or with none).
func viewmodel_visible() -> bool:
	if _fp != null and is_instance_valid(_fp):
		return _fp.is_visible_in_tree()
	return _viewmodel != null and is_instance_valid(_viewmodel) and _viewmodel.is_visible_in_tree()


func _on_masked_changed(_m: bool) -> void:
	refresh_mask()
	refresh_weapon(true)  # shown again with the draw clip


## Gameplay equip time of slot `ws` (CrewWeapons.equip: equip_time_s / weapon.swap_speed_mult).
func _equip_time(ws: int, def: WeaponDef) -> float:
	var st: WeaponStats = _crew.weapons.stats(ws)
	if st == null:
		return 0.0
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class)
	return st.equip_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.swap_speed_mult", q), 0.01)


## The first-person arms under `cam` when they can show `def` (else none: static viewmodel).
func _ensure_fp(cam: Camera3D, def: WeaponDef) -> FpViewmodel:
	if _fp == null or not is_instance_valid(_fp):
		_fp = FpViewmodel.create(_crew)
		if _fp == null:
			return null
		cam.add_child(_fp)
	if not _fp.supports(def.anim_set):
		_clear_fp()
	return _fp


## The local human's first-person arms (null when the static viewmodel is used).
func fp_viewmodel() -> FpViewmodel:
	return _fp if _fp != null and is_instance_valid(_fp) else null


## Every crew member: the equipped mask at `Head/Socket` once masked.
func refresh_mask() -> void:
	var l: Loadout = _crew.loadout if _crew.masked else null
	var desc: Dictionary = l.mask_descriptor if l != null else {}
	var want: StringName = l.mask if l != null else &""
	if want == &"" and not desc.is_empty():
		want = StringName(String(desc.get("id", desc.get("preset", ""))))
	if want == _mask_id and desc == _mask_desc and (want == &"" or (_mask != null and is_instance_valid(_mask))):
		return
	_clear_mask()
	if want == &"":
		return
	var def: MaskDef = _resolve_mask(want, desc)
	if def == null:
		return
	var socket: Node3D = head_socket(true)
	_mask = MaskComposer.instantiate(def)
	_mask.name = MASK_NAME
	socket.add_child(_mask)
	_mask_id = want
	_mask_desc = desc
	if _is_local_human():
		for n: Node in _mask.find_children("*", "VisualInstance3D", true, false):
			(n as VisualInstance3D).layers = FIRST_PERSON_HIDDEN_LAYER


## QA-25 (D-043): replace `Loadout.mask_descriptor` (a copy; never mutated in place) and rebuild the
## mask. On the server it is replicated to every peer. Late joiners: P6.
func set_mask_descriptor(d: Dictionary) -> void:
	if _crew == null:
		_crew = get_parent() as CrewController
	if _crew == null:
		return
	if _crew.loadout == null:
		_crew.loadout = CrewWeapons.build_loadout(null)
	if _crew.loadout.mask_descriptor != d:
		_crew.loadout.mask_descriptor = d.duplicate(true)
		if _crew.is_inside_tree():
			refresh_mask()
	replicate_mask_descriptor()


## Server: send this crew member's mask descriptor to every peer that replicates the heist (reliable authority RPC).
func replicate_mask_descriptor() -> void:
	if _crew == null or not Net.is_authority() or not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return
	if not HeistNetSync.can_rpc(_crew):
		return  # A3-07: before the bring-up; clients get the descriptor with the crew's loadout
	var d: Dictionary = _crew.loadout.mask_descriptor if _crew.loadout != null else {}
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	var sync: Object = rt.net_sync if rt != null else null
	if sync == null or not sync.has_method(&"replicates_to"):
		_rpc_mask_descriptor.rpc(d)
		return
	# Only peers that already hold this crew's replica; a drop-in still loading gets the current descriptor with its
	# late bring-up (an rpc before its replica exists errors "Node not found").
	for p: int in multiplayer.get_peers():
		if bool(sync.call(&"replicates_to", p)):
			_rpc_mask_descriptor.rpc_id(p, d)


@rpc("authority", "call_remote", "reliable")
func _rpc_mask_descriptor(d: Dictionary) -> void:
	set_mask_descriptor(d)


## The model's `Head/Socket` (an assembled character's BoneAttachment3D `Head` + `Socket`, else the
## capsule placeholder's `Visual/Head/Socket`, created when `create`).
func head_socket(create: bool = false) -> Node3D:
	var visual: Node3D = _crew.get_node_or_null(^"Visual") as Node3D
	if visual == null:
		return null
	var head: Node3D = visual.find_child("Head", true, false) as Node3D
	if head != null:
		var s: Node3D = head.get_node_or_null(^"Socket") as Node3D
		if s != null:
			return s
	if not create:
		return null
	if head == null:
		head = Node3D.new()
		head.name = "Head"
		visual.add_child(head)
	var socket: Marker3D = Marker3D.new()
	socket.name = "Socket"
	socket.position = Tweak.crew().placeholder_head_socket
	head.add_child(socket)
	return socket


func mask_node() -> Node3D:
	return _mask if _mask != null and is_instance_valid(_mask) else null


func viewmodel() -> Node3D:
	return _viewmodel if _viewmodel != null and is_instance_valid(_viewmodel) else null


func _is_local_human() -> bool:
	return _crew != null and not _crew.is_ai and _crew.is_local()


func _resolve_mask(mask_id: StringName, desc: Dictionary) -> MaskDef:
	if not desc.is_empty():
		return MaskCatalog.from_descriptor(desc)
	if MaskCatalog.is_custom_id(mask_id):
		return null  # needs the owner's profile: the server replicates Loadout.mask_descriptor
	return MaskCatalog.resolve(mask_id, null)


func _clear_viewmodel() -> void:
	if _viewmodel != null and is_instance_valid(_viewmodel):
		if _crew.weapon_visual == _viewmodel:
			_crew.weapon_visual = null
		_free_node(_viewmodel)
	_viewmodel = null


func _clear_fp() -> void:
	if _fp != null and is_instance_valid(_fp):
		_free_node(_fp)
	_fp = null


static func _free_node(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


func _clear_mask() -> void:
	if _mask != null and is_instance_valid(_mask):
		_mask.get_parent().remove_child(_mask)
		_mask.queue_free()
	_mask = null
	_mask_id = &""
	_mask_desc = {}


func _on_camera_child(n: Node) -> void:
	if n == _viewmodel or not (n is WeaponVisual):
		return
	external_viewmodel = true
	_clear_viewmodel.call_deferred()
	_clear_fp.call_deferred()
