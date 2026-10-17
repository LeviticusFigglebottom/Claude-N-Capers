## characters.md v1.23 (D-116 crew_actions) third-person crew actions for AnimDriver (crew bodies only). Owner: ENV A.
## Presentation only, driven on every peer from replicated state (never local input):
## - mask-up hold: while unmasked with mask_progress > 0 (server: the hold; clients: the SYNC_HZ state diff `mp`),
##   mask_on plays with its time = progress x length, so `mask_on` (18/30) lands at 0.6 of the hold. The shown progress
##   runs at 1 / mask_up_time_s between diffs, never behind the replicated value nor more than one diff ahead. A cancel
##   (progress back to 0 unmasked) ends it: the clip blends out and no mask shows.
## - masked (CrewController.masked_changed): the clip finishes from where it is (a forced mask with no hold plays it
##   whole); the weapon (holstered while unmasked, PD2 casing) draws after it. A body masked before the driver's first
##   tick (spawned masked, loud-only start) skips it: armed at once.
## - throw: `cue.throwable_pin` [R] starts throw_grenade, re-timed so `release` lands on the gameplay release
##   (CombatTweak.throw_windup_s after the pin, as the first-person throw); the grenade (ThrowableDef.model, the scene the
##   FP throw holds) sits at HandL/Socket until `release`. Gameplay timing is untouched.
## - standing: the action is the body's clip (AnimDriver.choose_clip); moving: the `ActionLayer` upper-body layer over
##   locomotion (legs keep walking, no foot slide). A crew-state change (downed, tased, cuffed) ends any action.
## - the mask: at the `mask_on` event. During the hold CrewView has no mask yet (it builds `Mask` once masked), so a
##   preview built the way CrewView builds it shows from the event; once masked, CrewView's mask is held hidden while
##   mask_on is before its event (forced mask-up), re-applied every tick (a rebuild mid-clip is held too).
class_name CrewActionAnim
extends RefCounted

const MASK_ON: StringName = &"mask_on"
const THROW_GRENADE: StringName = &"throw_grenade"
const LAYER_NODE: String = "ActionLayer"
const MASK_PREVIEW_NODE: String = "MaskOnPreview"
const HELD_THROWABLE_NODE: String = "HeldThrowable"

## The action playing (MASK_ON / THROW_GRENADE, &"" none), its clip time (s) and rate (clip s per s).
var action: StringName = &""
var time: float = 0.0
var speed: float = 1.0
## The upper-body layer (over the weapon holds; the flinch layer goes after it).
var layer: UpperBodyLayer = null

var _d: AnimDriver = null
var _crew: CrewController = null
## Hold progress shown (0..1).
var _mask_p: float = 0.0
var _mask_held: bool = false
## Started since the last update: it shows its frame 0 first.
var _fresh: bool = false
var _mask_preview: Node3D = null
var _held_item: Node3D = null


func _init(driver: AnimDriver, crew: CrewController) -> void:
	_d = driver
	_crew = crew
	if not crew.masked_changed.is_connected(_on_masked_changed):
		crew.masked_changed.connect(_on_masked_changed)


func bind_layer(skel: Skeleton3D) -> void:
	layer = UpperBodyLayer.ensure(skel, LAYER_NODE, 1)


## Before the clip choice: the hold, the finishing clip, the end.
func update(delta: float) -> void:
	if not _crew.masked:
		var up_s: float = maxf(Tweak.crew().mask_up_time_s, 0.001)
		var p: float = _crew.mask_progress
		if p > 0.0 and _crew.crew_state == Enums.CrewState.NORMAL and _has(MASK_ON):
			if action != MASK_ON:
				_start(MASK_ON)
				_mask_p = 0.0
			var lead: float = 1.0 / (HeistNetSync.SYNC_HZ * up_s)
			_mask_p = clampf(_mask_p + delta / up_s, p, minf(p + lead, 1.0))
			time = _mask_p * length()
			speed = length() / up_s
		elif action == MASK_ON:
			end()  # the hold was cancelled
		return
	if action == &"":
		return
	if _fresh:
		_fresh = false
	else:
		time += delta * speed
	if time >= length():
		end()


## After the clip choice: the layer, the mask, the held grenade.
func update_visuals(delta: float, tw: AnimTweak) -> void:
	_update_layer(delta, tw)
	_update_mask(tw)
	_update_held_item(tw)


func end() -> void:
	action = &""
	time = 0.0
	_mask_p = 0.0
	_mask_preview = _free(_mask_preview)
	_held_item = _free(_held_item)


func length() -> float:
	return _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, action]).length if _has(action) else 0.0


## True while the action plays as the upper-body layer (the body's clip is locomotion).
func layered() -> bool:
	return action != &"" and _d.clip != action


## The third-person weapon is holstered: unmasked (PD2 casing) or during mask_on.
func holsters_weapon() -> bool:
	return not _crew.masked or action == MASK_ON


## True while CrewView's mask is held hidden (a forced mask-up before its event).
func mask_held() -> bool:
	return _mask_held


func mask_preview() -> Node3D:
	return _mask_preview if _mask_preview != null and is_instance_valid(_mask_preview) else null


func held_item() -> Node3D:
	return _held_item if _held_item != null and is_instance_valid(_held_item) else null


func play_throw() -> void:
	if _has(THROW_GRENADE):
		_start(THROW_GRENADE, AnimTweak.data().throw_release_s() / maxf(CombatTweak.data().throw_windup_s, 0.05))


func _start(c: StringName, rate: float = 1.0) -> void:
	action = c
	time = 0.0
	speed = rate
	_fresh = true


func _has(c: StringName) -> bool:
	return c != &"" and _d.player != null and _d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c])


func _on_masked_changed(now_masked: bool) -> void:
	if not now_masked or _d == null or _d.player == null or _d._last_crew_state == -1:
		return  # spawned masked: no mask-up to show
	if action == MASK_ON:
		speed = 1.0  # the hold completed: finish the clip from here
	elif _crew.crew_state == Enums.CrewState.NORMAL and _has(MASK_ON):
		_start(MASK_ON)  # forced mask (detection / alarm): the whole clip
	_update_mask(AnimTweak.data())


func _update_layer(delta: float, tw: AnimTweak) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var on: bool = layered()
	if on:
		layer.set_clip(action, _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, action]), time)
		layer.time = time
	layer.influence = move_toward(layer.influence, 1.0 if on else 0.0, delta / maxf(tw.hold_layer_blend_s, 0.001))
	layer.active = layer.influence > 0.0


func _update_mask(tw: AnimTweak) -> void:
	var socket: Node3D = AnimDriver.socket_of(_crew, "Head")
	if socket == null:
		return
	var past_event: bool = action == MASK_ON and time >= tw.mask_on_s()
	if not _crew.masked:
		if past_event:
			_ensure_mask_preview(socket)
		else:
			_mask_preview = _free(_mask_preview)
		return
	_mask_preview = _free(_mask_preview)
	var mask: Node3D = socket.get_node_or_null(NodePath(CrewView.MASK_NAME)) as Node3D
	if mask == null:
		return
	if action == MASK_ON and not past_event:
		mask.visible = false
		_mask_held = true
	elif _mask_held:
		mask.visible = true
		_mask_held = false


func _ensure_mask_preview(socket: Node3D) -> void:
	if mask_preview() != null or _crew.loadout == null:
		return
	var l: Loadout = _crew.loadout
	var def: MaskDef = null
	if not l.mask_descriptor.is_empty():
		def = MaskCatalog.from_descriptor(l.mask_descriptor)
	elif l.mask != &"" and not MaskCatalog.is_custom_id(l.mask):
		def = MaskCatalog.resolve(l.mask, null)
	if def == null:
		return
	_mask_preview = MaskComposer.instantiate(def)
	_mask_preview.name = MASK_PREVIEW_NODE
	socket.add_child(_mask_preview)


func _update_held_item(tw: AnimTweak) -> void:
	if action != THROW_GRENADE or time >= tw.throw_release_s():
		_held_item = _free(_held_item)
		return
	if held_item() != null:
		return
	var def: ThrowableDef = _crew.throwables.throwable_def() if _crew.throwables != null else null
	var socket: Node3D = AnimDriver.socket_of(_crew, "HandL")
	if def == null or def.model == null or socket == null:
		return
	_held_item = def.model.instantiate() as Node3D
	if _held_item == null:
		return
	_held_item.name = HELD_THROWABLE_NODE
	socket.add_child(_held_item)
	_held_item.transform = Transform3D.IDENTITY


## Frees `n` (when valid); returns null for the caller's field.
static func _free(n: Node3D) -> Node3D:
	if n != null and is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()
	return null
