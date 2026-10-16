## Akimbo left gun in first person (D-050; ENV D rig SOURCE.txt fp.offhand_grip). Owner: ENV P.
## The WeaponVisual instances its `offhand` gun at the `Offhand` marker of the right gun (a rest pose that follows
## the RIGHT hand). For an akimbo set FpViewmodel moves it under a hand.L BoneAttachment3D + `OffhandSocket` at
## FpViewmodelTweak.akimbo_offhand_grip (the X-mirror of the weapon bone's hand.R offset: the same model, not
## mirrored), keeping the main model's pose relative to its own attachment. Any other set (or a new visual) puts
## the previous offhand back where the visual made it.
class_name FpViewmodelOffhand
extends RefCounted

## The hand.L attachment (created on the first akimbo set).
var attach: BoneAttachment3D = null
## Read only: the current shot comes from the LEFT gun (akimbo shots alternate, right first; rig fire_l).
var shot_left: bool = false

var _gun: Node3D = null
var _owner: WeaponVisual = null
var _next_left: bool = false
var _mag: Node3D = null


## Called by FpViewmodel._set_weapon for every equipped visual.
func setup(skeleton: Skeleton3D, wv: WeaponVisual, set_id: StringName) -> void:
	restore()
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if skeleton == null or wv == null or not is_instance_valid(wv) or not tw.akimbo_sets.has(set_id):
		return
	var off: Node3D = wv.get(&"offhand") as Node3D
	var main: Node3D = wv.get(&"model") as Node3D
	if off == null or main == null or skeleton.find_bone(FpLeftHandIk.END_BONE) < 0:
		return
	if attach == null or not is_instance_valid(attach):
		attach = BoneAttachment3D.new()
		attach.name = "OffhandAttach"
		attach.bone_name = FpLeftHandIk.END_BONE
		skeleton.add_child(attach)
		var socket: Node3D = Node3D.new()
		socket.name = "OffhandSocket"
		attach.add_child(socket)
	var sock: Node3D = attach.get_node(^"OffhandSocket") as Node3D
	sock.transform = tw.akimbo_offhand_grip
	_gun = off
	_owner = wv
	_next_left = false
	shot_left = false
	_mag = off.find_child("Magwell", true, false) as Node3D
	off.reparent(sock, false)
	off.transform = wv.transform * main.transform  # weapon bone -> model, now on the left socket


## Puts a moved offhand gun back under its WeaponVisual (frees it when the visual is gone).
func restore() -> void:
	if _gun != null and is_instance_valid(_gun):
		if _owner != null and is_instance_valid(_owner) and not _owner.is_queued_for_deletion():
			var main: Node3D = _owner.get(&"model") as Node3D
			var hand: Node3D = main.find_child(String(WeaponVisual.OFFHAND_MARKER), true, false) as Node3D \
				if main != null else null
			_gun.reparent(_owner, false)
			if main != null and hand != null:
				_gun.transform = main.transform * (main.global_transform.affine_inverse() * hand.global_transform)
		else:
			_gun.queue_free()
	if _mag != null and is_instance_valid(_mag):
		_mag.visible = true
	_gun = null
	_owner = null
	_mag = null
	shot_left = false


## A shot: picks the gun (alternating while the left one rides hand.L; always the right one otherwise).
func begin_shot() -> void:
	shot_left = gun() != null and _next_left
	_next_left = gun() != null and not _next_left


## The shot's clip: `base` + "_l" for a left-gun shot (FpViewmodel falls back to `base` when the set has none).
func clip(base: StringName) -> StringName:
	return StringName(String(base) + "_l") if shot_left else base


## The firing gun's marker (Muzzle / Eject ...): the offhand's for a left-gun shot.
func marker(wv: WeaponVisual, name: StringName) -> Node3D:
	if wv == null or not is_instance_valid(wv):
		return null
	if shot_left and gun() != null:
		var m: Node3D = wv.get_offhand_marker(name)
		if m != null:
			return m
	return wv.get_marker(name)


## The marker of the gun that fires the NEXT shot (before begin_shot(): ENV A's FX origin runs before `fired`).
func next_marker(wv: WeaponVisual, name: StringName) -> Node3D:
	if wv == null or not is_instance_valid(wv):
		return null
	if _next_left and gun() != null:
		var m: Node3D = wv.get_offhand_marker(name)
		if m != null:
			return m
	return wv.get_marker(name)


## The left magazine has no bone (rig fp.akimbo): hidden between the reload's mag_out_l and mag_in_l.
func set_mag_hidden(hidden: bool) -> void:
	if _mag != null and is_instance_valid(_mag) and _mag.visible == hidden:
		_mag.visible = not hidden


## Read only (tests): the left gun while it rides hand.L, else null.
func gun() -> Node3D:
	return _gun if _gun != null and is_instance_valid(_gun) else null
