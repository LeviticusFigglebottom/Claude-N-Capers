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

## Compatibility alias of the crew member's `Loadout.mask_descriptor` (QA-25); setting it calls
## set_mask_descriptor().
var mask_descriptor: Dictionary:
	get:
		return _crew.loadout.mask_descriptor if _crew != null and _crew.loadout != null else {}
	set(value):
		set_mask_descriptor(value)
## True once an external WeaponVisual owns the camera (ours is no longer attached).
var external_viewmodel: bool = false

var _crew: CrewController = null
var _viewmodel: Node3D = null
var _fp: FpViewmodel = null
var _mask: Node3D = null
var _mask_id: StringName = &""
var _ads_weight: float = 0.0
## D-084 (read-only): linear zoom of the local camera, tan(base_fov/2) / tan(current_fov/2); 1.0 at hip fire and
## for every non-local view. ENV C/D scale visibility ranges by it (mesh LOD is already FOV-aware in Godot).
var zoom_factor: float:
	get:
		return _zoom_factor
var _zoom_factor: float = 1.0
## The local human's view (null when none).
static var _local_view: CrewView = null
## Descriptor the current mask was built from (rebuild when it changes).
var _mask_desc: Dictionary = {}
## Heister whose body is under `Visual` (&"" = the placeholder).
var _body_id: StringName = &""


## The crew member's view component (null when missing).
static func of(crew: Node) -> CrewView:
	return crew.get_node_or_null(NODE_NAME) as CrewView if crew != null else null


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
	_crew.masked_changed.connect(func(_m: bool) -> void: refresh_mask())
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
## applies at once); aiming zooms to fov / WeaponStats.magnification at CrewTweak.ads_zoom_rate.
func _process(delta: float) -> void:
	if _crew == null or not _is_local_human():
		return
	var cam: Camera3D = camera()
	var gs: GameSettings = GameSettings.current()
	if cam == null or gs == null:
		return
	var mag: float = 1.0
	var w: CrewWeapons = _crew.weapons
	if w != null and w.stats(w.equipped_slot) != null:
		mag = maxf(w.stats(w.equipped_slot).magnification, 1.0)
	var aiming: bool = _crew.intent != null and _crew.intent.aim
	_ads_weight = move_toward(_ads_weight, 1.0 if aiming else 0.0, delta * Tweak.crew().ads_zoom_rate)
	cam.fov = gs.fov() / lerpf(1.0, mag, _ads_weight)
	_local_view = self
	_set_zoom_factor(zoom_factor_for(gs.fov(), cam.fov))


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
	_crew.weapon_visual = wv
	WeaponPartsAnimator.attach(wv, _crew.weapons)  # B4-18: Breech / Lever / String / Blade / Rotor


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


## Server: send this crew member's mask descriptor to every peer (reliable authority RPC).
func replicate_mask_descriptor() -> void:
	if _crew == null or not Net.is_authority() or not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return
	if not HeistNetSync.can_rpc(_crew):
		return  # A3-07: before the bring-up; clients get the descriptor with the crew's loadout
	_rpc_mask_descriptor.rpc(_crew.loadout.mask_descriptor if _crew.loadout != null else {})


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
