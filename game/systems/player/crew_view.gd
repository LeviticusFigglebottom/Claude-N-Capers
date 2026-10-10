## Presentation of one crew member (QB-47, D-038). Owner: ENV A. Child `View` of every CrewController,
## added by CrewController._ready. Visual only: no gameplay state, safe headless.
## - Local human (CrewController.is_local()): makes `Head/Camera` current and puts ENV B's
##   `WeaponVisual` (by class name) for the equipped weapon under it at CrewTweak.viewmodel_offset;
##   sets `crew.weapon_visual` (CrewWeapons reads get_marker(&"Muzzle")). Rebuilt on weapon switch
##   (CrewWeapons.equipped_changed) and on CrewController.set_loadout(). When someone else puts a
##   WeaponVisual under the camera (e.g. ENV B's firing range bridge), ours is removed and that one is kept.
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
var _mask: Node3D = null
var _mask_id: StringName = &""
## Descriptor the current mask was built from (rebuild when it changes).
var _mask_desc: Dictionary = {}


## The crew member's view component (null when missing).
static func of(crew: Node) -> CrewView:
	return crew.get_node_or_null(NODE_NAME) as CrewView if crew != null else null


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew == null:
		return
	_crew.masked_changed.connect(func(_m: bool) -> void: refresh_mask())
	if _crew.weapons != null:
		_crew.weapons.equipped_changed.connect(func(_ws: int) -> void: refresh_weapon())
	var cam: Camera3D = camera()
	if cam != null:
		cam.child_entered_tree.connect(_on_camera_child)
	refresh.call_deferred()


## Re-apply everything (camera, weapon visual, mask).
func refresh() -> void:
	if _crew == null or not is_instance_valid(_crew) or not _crew.is_inside_tree():
		return
	refresh_camera()
	refresh_weapon()
	refresh_mask()
	if not _is_local_human():
		AnimDriver.ensure(_crew)  # D-041: third-person clips + HandR weapon (animated visuals only)


func camera() -> Camera3D:
	return _crew.get_node_or_null(^"Head/Camera") as Camera3D if _crew != null else null


## Local human only: this crew member's camera becomes the viewport's current camera.
func refresh_camera() -> void:
	var cam: Camera3D = camera()
	if cam == null or not cam.is_inside_tree() or not _is_local_human():
		return
	cam.cull_mask &= ~FIRST_PERSON_HIDDEN_LAYER
	cam.make_current()


## Local human only: WeaponVisual of the equipped weapon under the camera.
func refresh_weapon() -> void:
	if external_viewmodel:
		return
	_clear_viewmodel()
	var cam: Camera3D = camera()
	if cam == null or not _is_local_human() or _crew.weapons == null:
		return
	var ws: int = _crew.weapons.equipped_slot
	var def: WeaponDef = ContentDB.weapon(_crew.weapons.weapon_id(ws)) if _crew.weapons.has_weapon(ws) else null
	if def == null or def.model == null:
		return
	var l: Loadout = _crew.loadout
	var mod_ids: Array[StringName] = []
	if l != null:
		mod_ids = l.primary_mods if ws == Enums.WeaponSlot.PRIMARY else l.secondary_mods
	var wv: WeaponVisual = WeaponVisual.new()
	wv.name = VIEWMODEL_NAME
	wv.position = Tweak.crew().viewmodel_offset
	_viewmodel = wv
	cam.add_child(wv)
	wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
	_crew.weapon_visual = wv


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
		_viewmodel.get_parent().remove_child(_viewmodel)
		_viewmodel.queue_free()
	_viewmodel = null


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
