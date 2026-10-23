## Perk-deck item use pose for FpViewmodel (LEAD round 298, A's CrewThrowables.deck_item_used). Owner: ENV P.
## Presentation only: the deck item already fired on the server; every peer's local FP arms show it.
## - injector / leech_ampule / flask / pocket_ecm / gas_dispenser: the `throwable` set's `draw` (ready@ after DRAW_S)
##   with the item (ThrowableDef.model) in the right fist, a hold of the kind's `hold_s` with an arm pose layered on
##   the arms (offset m + rotation deg about the firing hand, eased in and out) and its part motion, then `holster`
##   (gone@ after HOLSTER_S); FpViewmodel then draws the gun again.
##   injector: press to the thigh, the cap (`Pin`) off. leech_ampule: press to the thigh, the `Serum` drains.
##   flask: to the mouth and tipped, the cap (`Pin`) off. pocket_ecm: thumb press, the `Led` blinks.
##   gas_dispenser: point ahead, the `Canister` pressed down.
## - smoke_bomb: thrown like a grenade: `draw` (the `Pin` hidden at pin_pull@) + `throw` (`throw_low` crouched) over
##   CombatTweak.throw_windup_s, the item hidden at release@.
class_name FpViewmodelDeck
extends RefCounted

const DRAW_S: float = 0.25
const HOLSTER_S: float = 0.2
## Share of the hold spent easing the pose in (and again out).
const EASE_SHARE: float = 0.3
## kind -> hold_s, off (arms offset, m), rot (deg: pitch, yaw, roll), press (0..1 of the hold) + press_off (m) pulse.
const POSES: Dictionary = {
	&"injector": {"hold_s": 0.4, "off": Vector3(-0.02, -0.07, 0.02), "rot": Vector3(-25.0, 10.0, -15.0),
		"press": 0.5, "press_off": Vector3(0.0, -0.03, 0.0)},
	&"leech_ampule": {"hold_s": 0.45, "off": Vector3(-0.02, -0.07, 0.02), "rot": Vector3(-25.0, 10.0, -15.0),
		"press": 0.4, "press_off": Vector3(0.0, -0.03, 0.0)},
	&"flask": {"hold_s": 0.5, "off": Vector3(-0.06, 0.03, 0.03), "rot": Vector3(30.0, 15.0, -25.0),
		"press": -1.0, "press_off": Vector3.ZERO},
	&"pocket_ecm": {"hold_s": 0.35, "off": Vector3(-0.04, 0.03, 0.03), "rot": Vector3(10.0, 10.0, -10.0),
		"press": 0.45, "press_off": Vector3(0.0, -0.008, -0.01)},
	&"gas_dispenser": {"hold_s": 0.4, "off": Vector3(-0.05, 0.04, -0.08), "rot": Vector3(5.0, 5.0, 0.0),
		"press": 0.45, "press_off": Vector3(0.0, 0.0, 0.015)},
}
const THROWN_KINDS: Array[StringName] = [&"smoke_bomb"]
## Canister travel when pressed (m), Led blink rate (Hz).
const CANISTER_TRAVEL_M: float = 0.008
const LED_BLINK_HZ: float = 8.0

## Read only: the pose layered on the arms this frame (FpViewmodel._update_offset).
var offset: Vector3 = Vector3.ZERO
var rot_deg: Vector3 = Vector3.ZERO
## Read only: the kind playing (&"" none).
var kind: StringName = &""

var _hold_from: float = 0.0
var _release_at: float = -1.0
var _pose: Dictionary = {}
var _rest: Dictionary = {}


## Start the use pose of `def` (kind `item_kind`) on `vm`. False when it cannot play (no set, mid swap / reload /
## melee / deploy / throw / interaction).
func play(vm: FpViewmodel, def: ThrowableDef, item_kind: StringName) -> bool:
	if def == null or not vm.supports(def.anim_set):
		return false
	if vm.action != FpViewmodel.Action.NONE and vm.action != FpViewmodel.Action.FIRE \
			and vm.action != FpViewmodel.Action.DECK:
		return false
	var segs: Array[Dictionary] = []
	var draw_c: StringName = vm._resolve(def.anim_set, &"draw")
	if THROWN_KINDS.has(item_kind):
		if not _throw_segs(vm, def, segs):
			return false
	elif POSES.has(item_kind):
		_pose = POSES[item_kind]
		vm._add_timed(segs, def.anim_set, &"draw", &"ready", DRAW_S)
		vm._add_seg(segs, def.anim_set, &"", float(_pose["hold_s"]), 1.0)  # the draw's last frame holds
		vm._add_timed(segs, def.anim_set, &"holster", &"gone", HOLSTER_S)
		_hold_from = float(segs[1]["start"])
		_release_at = -1.0
	else:
		return false
	vm._start_item(FpViewmodel.Action.DECK, segs, def.model)
	kind = item_kind
	_rest.clear()
	for part: StringName in [&"Pin", &"Serum", &"Canister", &"Led"]:
		var n: Node3D = _part(vm, part)
		if n != null:
			_rest[part] = n.transform
	if THROWN_KINDS.has(item_kind):
		var pin: float = vm._event(def.anim_set, draw_c, &"pin_pull") if draw_c != &"" else -1.0
		vm._pin_t = pin / maxf(float(segs[0]["speed"]), 0.001) if pin >= 0.0 else 0.0
	return true


## The thrown kinds: the grenade throw over the gameplay windup (FpViewmodel._on_pin_pulled's timing).
func _throw_segs(vm: FpViewmodel, def: ThrowableDef, segs: Array[Dictionary]) -> bool:
	var crouch: bool = vm.crew() != null and vm.crew().intent != null and vm.crew().intent.crouch
	var throw_c: StringName = vm._resolve(def.anim_set, &"throw_low" if crouch else &"throw")
	if throw_c == &"":
		throw_c = vm._resolve(def.anim_set, &"throw")
	if throw_c == &"":
		return false
	var windup: float = CombatTweak.data().throw_windup_s
	var draw_c: StringName = vm._resolve(def.anim_set, &"draw")
	var draw_n: float = vm._length(def.anim_set, draw_c) if draw_c != &"" else 0.0
	var rel_n: float = maxf(vm._event(def.anim_set, throw_c, &"release"), 0.01)
	var share: float = draw_n / (draw_n + rel_n)
	if draw_c != &"":
		vm._add_timed(segs, def.anim_set, draw_c, &"ready", windup * share)
	vm._add_timed(segs, def.anim_set, throw_c, &"release", windup * (1.0 - share))
	_pose = {}
	_release_at = windup
	return true


## Advance with FpViewmodel's sequence clock (after its segment step).
func tick(vm: FpViewmodel, seq_t: float) -> void:
	offset = Vector3.ZERO
	rot_deg = Vector3.ZERO
	if vm.action != FpViewmodel.Action.DECK:
		kind = &""
		return
	if _release_at >= 0.0:
		if seq_t >= _release_at and vm._item != null and is_instance_valid(vm._item):
			vm._item.visible = false  # the smoke bomb leaves the hand at release@
		return
	if _pose.is_empty():
		return
	var hold: float = float(_pose["hold_s"])
	var u: float = clampf((seq_t - _hold_from) / maxf(hold, 0.001), 0.0, 1.0)
	var w: float = smoothstep(0.0, EASE_SHARE, u) * (1.0 - smoothstep(1.0 - EASE_SHARE, 1.0, u)) \
		if seq_t >= _hold_from else 0.0
	offset = (_pose["off"] as Vector3) * w
	rot_deg = (_pose["rot"] as Vector3) * w
	var press: float = float(_pose["press"])
	var pressed: float = 0.0
	if press >= 0.0 and seq_t >= _hold_from:
		pressed = clampf(1.0 - absf(u - press) / 0.15, 0.0, 1.0)  # a 0.3-of-the-hold tent pulse at `press`
		offset += (_pose["press_off"] as Vector3) * pressed
	_parts(vm, u if seq_t >= _hold_from else -1.0, press, pressed, seq_t)


func _parts(vm: FpViewmodel, u: float, press: float, pressed: float, seq_t: float) -> void:
	var cap: Node3D = _part(vm, &"Pin")
	if cap != null and (kind == &"injector" or kind == &"flask"):
		cap.visible = u < 0.0  # the cap comes off as the hold starts
	var serum: Node3D = _part(vm, &"Serum")
	if serum != null and _rest.has(&"Serum"):
		var left: float = 1.0 - clampf((u - press) / maxf(1.0 - press, 0.001), 0.0, 1.0) if u >= 0.0 else 1.0
		var t: Transform3D = _rest[&"Serum"]
		serum.transform = Transform3D(t.basis.scaled(Vector3(1.0, maxf(left, 0.001), 1.0)), t.origin)
		serum.visible = left > 0.01
	var can: Node3D = _part(vm, &"Canister")
	if can != null and _rest.has(&"Canister"):
		var down: float = 1.0 if u >= press and u >= 0.0 else 0.0
		var tc: Transform3D = _rest[&"Canister"]
		can.transform = Transform3D(tc.basis, tc.origin + Vector3(0.0, -CANISTER_TRAVEL_M * maxf(down, pressed), 0.0))
	var led: Node3D = _part(vm, &"Led")
	if led != null:
		led.visible = u < press or u < 0.0 or fmod(seq_t * LED_BLINK_HZ, 1.0) < 0.5


func _part(vm: FpViewmodel, part: StringName) -> Node3D:
	if vm._item == null or not is_instance_valid(vm._item):
		return null
	return vm._item.find_child(String(part), true, false) as Node3D
