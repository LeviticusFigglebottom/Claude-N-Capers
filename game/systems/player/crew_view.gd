## Presentation of one crew member (QB-47, D-038). Owner: ENV A. Child `View` of every CrewController,
## added by CrewController._ready. Visual only: no gameplay state, safe headless.
## - Local human (CrewController.is_local()): makes `Head/Camera` current and puts ENV B's
##   `WeaponVisual` (by class name) for the equipped weapon under it at CrewTweak.viewmodel_offset;
##   sets `crew.weapon_visual` (CrewWeapons reads get_marker(&"Muzzle")). Rebuilt on weapon switch
##   (CrewWeapons.equipped_changed) and on CrewController.set_loadout(). When someone else puts a
##   WeaponVisual under the camera (e.g. ENV B's firing range bridge), ours is removed and that one is kept.
## - Every crew member, once masked: the Loadout.mask (MaskCatalog.resolve / from_descriptor +
##   MaskComposer.instantiate, ENV B, by class name; characters.md v1.2) at the model's `Head/Socket`.
##   The capsule placeholder gets a `Visual/Head` Node3D with a `Socket` Marker3D so the path matches.
##   On the local human the mask meshes use FIRST_PERSON_HIDDEN_LAYER, which its camera does not render.
class_name CrewView
extends Node

const NODE_NAME: String = "View"
const VIEWMODEL_NAME: String = "Viewmodel"
const MASK_NAME: String = "Mask"
## Render layer 20: third-person-only parts of the local human (culled by its own camera).
const FIRST_PERSON_HIDDEN_LAYER: int = 1 << 19

## Optional MaskCatalog.descriptor() of the equipped mask (custom masks on peers without the profile).
var mask_descriptor: Dictionary = {}
## True once an external WeaponVisual owns the camera (ours is no longer attached).
var external_viewmodel: bool = false

var _crew: CrewController = null
var _viewmodel: Node3D = null
var _mask: Node3D = null
var _mask_id: StringName = &""


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
	var want: StringName = _crew.loadout.mask if _crew.masked and _crew.loadout != null else &""
	if want == _mask_id and (want == &"" or (_mask != null and is_instance_valid(_mask))):
		return
	_clear_mask()
	if want == &"":
		return
	var def: MaskDef = _resolve_mask(want)
	if def == null:
		return
	var socket: Node3D = head_socket(true)
	_mask = MaskComposer.instantiate(def)
	_mask.name = MASK_NAME
	socket.add_child(_mask)
	_mask_id = want
	if _is_local_human():
		for n: Node in _mask.find_children("*", "VisualInstance3D", true, false):
			(n as VisualInstance3D).layers = FIRST_PERSON_HIDDEN_LAYER


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


func _resolve_mask(mask_id: StringName) -> MaskDef:
	if not mask_descriptor.is_empty():
		return MaskCatalog.from_descriptor(mask_descriptor)
	if MaskCatalog.is_custom_id(mask_id):
		return null  # needs the owner's profile: set mask_descriptor
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


func _on_camera_child(n: Node) -> void:
	if n == _viewmodel or not (n is WeaponVisual):
		return
	external_viewmodel = true
	_clear_viewmodel.call_deferred()
