## First-person viewmodel arms of the local human (characters.md v1.3/v1.4, D-041/D-044). Owner: ENV A.
## Child `FpViewmodel` of the local human's `Head/Camera`, created by CrewView when FpViewmodelTweak.arms_scene
## (the `char_arms_fp` rig: root = camera origin, -Z forward) has a Skeleton3D with the `weapon` helper bone, an
## AnimationPlayer and a library for the equipped `WeaponDef.anim_set`; otherwise CrewView keeps the static
## viewmodel. **Presentation only**: it reads gameplay state (CrewWeapons signals, intent.aim, velocity) and
## never writes it; nothing in gameplay reads it. Headless-safe.
## - Libraries: one per anim_set, played as "<set>/<clip>". A glb that carries "<set>_<clip>" clips in its
##   default library gets the per-set libraries built at bind time (same Animation resources).
## - The WeaponVisual (ENV B, by class name) hangs on a BoneAttachment3D of the `weapon` bone; the weapon's
##   `Magwell` follows the `magazine` bone (identity when seated).
## - Base loop: `sprint` (sprinting and moving), `ads_idle` (intent.aim), else `idle` plus a walk bob.
## - Fire per shot (restarted every shot, so 3-frame full-auto clips restart); shotgun pump inside fire;
##   sniper `bolt`/`bolt_ads` after the shot. Sped up only when the fire cycle outlasts the shot interval.
## - Reload: `reload` / `reload_empty`, or shell-by-shell `reload_start` + n x `reload_loop` + `reload_end` /
##   `reload_end_empty` (n = rounds missing, capped by reserve), re-timed so the `done` event frame lands on
##   the gameplay reload_finished time. A cancelled reload (swap, state change) returns to idle.
## - Swap: the old set's `holster` (FpViewmodelTweak.holster_share of the gameplay equip time), then the new
##   set's `draw` with its `ready` frame on the end of the equip time.
## - Parts: `Slide` / `Pump` / `Bolt` / `FeedCover` of the weapon model move from the clip event frames
##   (FpViewmodelTweak.clip_events(): parsed from SOURCE.txt + extra_events) with the contract travels. Pistol slides lock
##   back on the last round until `slide_release`.
## - ADS: while aimed the arms shift so the weapon's `AimPoint` sits on the camera axis (when present).
## - Melee (D-069, CrewMelee signals): with a MeleeDef the gun is hidden and the item (`MeleeDef.model`) rides the
##   weapon bone in its `anim_set`: `charge_start` (its `charged` frame on the full charge) + `charge` loop while
##   held, then `swing` / `charge_swing` re-timed so `hit@` lands on the gameplay strike; without one the gun
##   set's `bash` (hit@ on the bash strike). The gun comes back when the swing clip ends.
## - Throw (A3-12, D-069): CrewThrowables.pin_pulled plays the `throwable` set's `draw` then `throw` (`throw_low`
##   crouched), re-timed so `release@` lands on the gameplay release (CombatTweak.throw_windup_s); the item's
##   `Pin` hides at `pin_pull@` and the item itself at the release.
## - Deploy (D-069): holding intent.deploy with a deployable left (masked, NORMAL) plays the DeployableDef
##   `anim_set` `place` with its `place@` frame on the deploy hold time (DeployableSystem.deploy_time_for); the
##   held form (`DeployableDef.model`) replaces the gun; releasing early cancels it.
## - Deck item (LEAD r298): CrewThrowables.deck_item_used plays the item's use pose (FpViewmodelDeck), then the gun's
##   `draw`.
class_name FpViewmodel
extends Node3D


## PO-4: the ADS AimPoint alignment runs as the skeleton's last modifier, on this frame's animated pose. Reading the
## marker in _process used last frame's pose (FpViewmodel processes before its AnimationPlayer, the BoneAttachment
## later still), so during the idle -> ads_idle crossfade the sights swung up to ~0.1 m around the crosshair.
class AdsAlign:
	extends SkeletonModifier3D
	var vm: FpViewmodel = null

	func _process_modification_with_delta(_delta: float) -> void:
		if vm != null and is_instance_valid(vm):
			vm.offhand.align(vm.skeleton, vm._weapon_bone, vm.weapon_attach, vm.ads_weight)
			vm._late_align()


## PO-13: the left-hand IK (TwoBoneIK3D) only places the wrist, and the hand inherits the forearm's new rotation
## (fingers pointing up off the handguard). HandCapture (before the IK) records hand.L's orientation relative to the
## weapon bone as the clip authored it; HandRestore (after the IK) puts it back, blended by the IK's influence.
class HandCapture:
	extends SkeletonModifier3D
	var vm: FpViewmodel = null

	func _process_modification_with_delta(_delta: float) -> void:
		if vm != null and is_instance_valid(vm):
			vm._capture_hand()


class HandRestore:
	extends SkeletonModifier3D
	var vm: FpViewmodel = null

	func _process_modification_with_delta(_delta: float) -> void:
		if vm != null and is_instance_valid(vm):
			vm._restore_hand()


## D-116: one-handed first-person sets (pistol / revolver): drops the left arm out of view (see _hide_left_arm).
class LeftArmHide:
	extends SkeletonModifier3D
	var vm: FpViewmodel = null

	func _process_modification_with_delta(_delta: float) -> void:
		if vm != null and is_instance_valid(vm):
			vm._hide_left_arm()


## D-118: with a vertical-grip mod the left hand takes D's `<set>_vgrip_hand` pose (before HandCapture / the IK).
class VgripPose:
	extends SkeletonModifier3D
	var vm: FpViewmodel = null

	func _process_modification_with_delta(_delta: float) -> void:
		if vm != null and is_instance_valid(vm):
			vm.vgrip.apply(vm)


enum Action { NONE, FIRE, RELOAD, SWAP, MELEE, DEPLOY, THROW, INTERACT, DECK }

const NODE_NAME: String = "FpViewmodel"
const ATTACH_NAME: String = "WeaponBone"
const ITEM_NAME: String = "HeldItem"
## `charge` loop repetitions queued behind charge_start (the release replaces the sequence).
const CHARGE_LOOPS: int = 600
## Clip -> substitute when the set lacks it (then nothing).
const FALLBACK_CLIPS: Dictionary = {
	&"ads_idle": &"idle", &"sprint": &"idle", &"fire_ads": &"fire", &"bolt_ads": &"bolt",
	&"reload_empty": &"reload", &"reload_end_empty": &"reload_end",
}
## Clip event -> [part channel, position 0..1] (characters.md v1.4 / SOURCE.txt fp.parts).
const EVENT_PARTS: Dictionary = {
	&"slide_back": [&"slide", 1.0], &"slide_forward": [&"slide", 0.0], &"slide_release": [&"slide", 0.0],
	&"pump_back": [&"pump", 1.0], &"pump_forward": [&"pump", 0.0],
	&"bolt_open": [&"bolt_lift", 1.0], &"bolt_back": [&"bolt_slide", 1.0],
	&"bolt_forward": [&"bolt_slide", 0.0], &"bolt_close": [&"bolt_lift", 0.0],
	&"cover_open": [&"cover", 1.0], &"cover_close": [&"cover", 0.0], &"mag_out_l": [&"mag_l_out", 1.0],
	&"mag_in_l": [&"mag_l_out", 0.0],
}
const CHANNELS: Array[StringName] = [&"slide", &"pump", &"bolt_lift", &"bolt_slide", &"cover", &"mag_l_out"]
## Weapon model part node names (visual_slots.md).
const PART_SLIDE: StringName = &"Slide"
const PART_PUMP: StringName = &"Pump"
const PART_BOLT: StringName = &"Bolt"
const PART_COVER: StringName = &"FeedCover"

## D-063: weapon|clip pairs already reported outside the shared-clip speed range.
static var _reload_scale_logged: Dictionary = {}
## PI-19: weapon ids already warned for having no `AimPoint` (sights cannot align while aimed).
static var _aim_missing_logged: Dictionary = {}

## The arms rig's AnimationPlayer / Skeleton3D / instanced scene root.
var player: AnimationPlayer = null
var skeleton: Skeleton3D = null
## D-069: runtime left-hand IK to the weapon's `LeftHandIK` (null when the rig has no left arm).
var left_hand_ik: FpLeftHandIk = null
var arms: Node3D = null
## BoneAttachment3D on the `weapon` bone: the WeaponVisual's parent.
var weapon_attach: BoneAttachment3D = null
## Akimbo (D-050, rig fp.offhand_grip): the left gun on hand.L (FpViewmodelOffhand).
var offhand: FpViewmodelOffhand = FpViewmodelOffhand.new()
## D-118 vertical grip: the left hand takes D's `<set>_vgrip_hand` pose (FpViewmodelVgrip).
var vgrip: FpViewmodelVgrip = FpViewmodelVgrip.new()
## Perk-deck item use pose (FpViewmodelDeck).
var deck: FpViewmodelDeck = FpViewmodelDeck.new()
## The WeaponVisual shown (during a holster: the outgoing one until the draw starts).
var weapon_visual: WeaponVisual = null
## anim_set of the weapon currently in the hands.
var anim_set: StringName = &""
## Short clip name currently playing ("fire", "idle"...); the player plays "<anim_set>/<clip>".
var clip: StringName = &""
## Current one-shot (Action), and its playback speed scale (re-timing).
var action: int = Action.NONE
var action_speed: float = 1.0
## D-105: first-person weapon FX (muzzle burst, smoke, shells, tracers).
var fx: FpViewmodelFx = null
## D-118: first-person laser / flashlight (lives next to the crew, freed with the viewmodel).
var gadgets: FpViewmodelGadgets = null
## 0 = hip, 1 = aimed down sights.
var ads_weight: float = 0.0
## Part channel -> position 0..1 (slide, pump, bolt_lift, bolt_slide, cover).
var parts: Dictionary = {}

var _crew: CrewController = null
## Segments of the current one-shot: {set, clip, start, dur, speed}; times in real seconds.
var _segs: Array[Dictionary] = []
var _seg_i: int = -1
var _seq_t: float = 0.0
## Part keys of the current one-shot: {t, ch, v, ramp} (real seconds), and channel values at its start.
var _keys: Array[Dictionary] = []
var _key_start: Dictionary = {}
var _reload_done: bool = false
var _incoming: WeaponVisual = null
var _incoming_set: StringName = &""
var _part_nodes: Dictionary = {}
var _magwell: Node3D = null
var _magwell_rest: Transform3D = Transform3D.IDENTITY
var _weapon_bone: int = -1
## PO-13: hand.L bone and its clip orientation relative to the weapon bone (HandCapture -> HandRestore).
var _hand_bone: int = -1
var _hand_rel: Basis = Basis.IDENTITY
var _hand_rel_set: bool = false
## D-116: upper_arm.L and how far (0..1) the left arm is dropped out of view for a one-handed set.
var _left_root_bone: int = -1
var _left_drop: float = 0.0
var _mag_bone: int = -1
var _bob_phase: float = 0.0
## Linear ADS progress behind the eased ads_weight.
var _ads_lin: float = 0.0
var _bob_weight: float = 0.0
## PO-20: 0..1 eased sprint weight (sprint sway and pose).
var _sprint_w: float = 0.0
## PO-4: hip/bob/step offset (_update_offset) and the ADS alignment (AdsAlign, late) that make up `position`.
var _base_offset: Vector3 = Vector3.ZERO
## PO-4: eased per-set framing offset (FpViewmodelTweak.set_hip_offset / set_ads_offset_z).
var _set_off: Vector3 = Vector3.ZERO
var _set_off_init: bool = true
## PO-4: per-shot muzzle light (FpViewmodelTweak.muzzle_light_*), seconds left of the current flash.
var _muzzle_light: OmniLight3D = null
var _flash_left: float = 0.0
var _flash_peak: float = 0.0
var _align: Vector3 = Vector3.ZERO
## PO6-11: eased per-set hip pose rotation (deg) and the ADS settle spring (position, velocity) chasing ads_weight.
var _set_rot: Vector3 = Vector3.ZERO
var _settle: float = 0.0
var _settle_v: float = 0.0
## D-105: the per-shot kick (x = back m, y = pitch deg) as an exact critically damped spring (position, velocity).
var _kick: Vector2 = Vector2.ZERO
## PO pass: seconds left before a running interaction lowers the weapon (-1 = none pending).
var _interact_wait: float = -1.0
var _kick_v: Vector2 = Vector2.ZERO
## PO-13 (PD2 vel_overshot): look-lag sway target and applied value (x = yaw, y = pitch; deg), the last look angles,
## and the breathing clock.
var _sway_target: Vector2 = Vector2.ZERO
var _sway: Vector2 = Vector2.ZERO
var _sway_v: Vector2 = Vector2.ZERO
## D-116: bob rotation (x pitch, z roll; deg) and the landing pitch, applied about the firing hand.
var _bob_rot: Vector3 = Vector3.ZERO
var _last_look: Vector2 = Vector2.INF
var _breath_t: float = 0.0
## The item model on the weapon bone during a melee / deploy one-shot (null = none / gun bash).
var _item: Node3D = null
var _deploy_prev: bool = false
## Seconds into the THROW one-shot when the item's Pin hides (< 0 = done / none).
var _pin_t: float = -1.0


## The camera's viewmodel arms (null when none).
static func of(cam: Node) -> FpViewmodel:
	return cam.get_node_or_null(NODE_NAME) as FpViewmodel if cam != null else null


## The local first-person viewmodel of `crew` (its CrewView camera's), or null (remote peers, bots, no arms).
static func of_crew(crew: Node) -> FpViewmodel:
	var cv: CrewView = CrewView.of(crew)
	return of(cv.camera()) if cv != null else null


## Arms for `crew` from `scene` (default FpViewmodelTweak.arms_scene); null when the scene is missing or has no
## Skeleton3D with the weapon bone and an AnimationPlayer (CrewView then keeps the static viewmodel).
static func create(crew: CrewController, scene: PackedScene = null) -> FpViewmodel:
	var ps: PackedScene = scene if scene != null else FpViewmodelTweak.data().arms_scene
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return null
	var fp: FpViewmodel = FpViewmodel.new()
	fp.name = NODE_NAME
	if not fp._bind(inst, crew):
		inst.free()
		fp.free()
		return null
	return fp


func _bind(inst: Node3D, crew: CrewController) -> bool:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	skeleton = _first(inst, "Skeleton3D") as Skeleton3D
	player = _first(inst, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or player == null:
		return false
	_weapon_bone = skeleton.find_bone(String(tw.weapon_bone))
	if _weapon_bone < 0:
		return false
	_mag_bone = skeleton.find_bone(String(tw.magazine_bone))
	arms = inst
	add_child(inst)
	weapon_attach = BoneAttachment3D.new()
	weapon_attach.name = ATTACH_NAME
	weapon_attach.bone_name = String(tw.weapon_bone)
	left_hand_ik = FpLeftHandIk.create(skeleton)  # D-069: hand.L onto the weapon's LeftHandIK
	skeleton.add_child(weapon_attach)
	_hand_bone = skeleton.find_bone(FpLeftHandIk.END_BONE)
	if left_hand_ik != null and _hand_bone >= 0 and tw.left_hand_keep_orientation:
		var cap: HandCapture = HandCapture.new()
		cap.name = "HandCapture"
		cap.vm = self
		skeleton.add_child(cap)
		skeleton.move_child(cap, left_hand_ik.ik.get_index())  # before the IK
		var vg: VgripPose = VgripPose.new()
		vg.name = "VgripPose"
		vg.vm = self
		skeleton.add_child(vg)
		skeleton.move_child(vg, cap.get_index())  # before HandCapture: the captured hand is the grip pose
		var res: HandRestore = HandRestore.new()
		res.name = "HandRestore"
		res.vm = self
		skeleton.add_child(res)  # after the IK, before AdsAlign
	_left_root_bone = skeleton.find_bone(FpLeftHandIk.ROOT_BONE)
	if _left_root_bone >= 0:
		var hide: LeftArmHide = LeftArmHide.new()
		hide.name = "LeftArmHide"
		hide.vm = self
		skeleton.add_child(hide)  # after the IK / HandRestore, before AdsAlign
	var align: AdsAlign = AdsAlign.new()
	align.name = "AdsAlign"
	align.vm = self
	skeleton.add_child(align)  # last: after the animation and the left-hand IK
	_crew = crew
	fx = FpViewmodelFx.new()
	fx.setup(self)
	add_child(fx)
	gadgets = FpViewmodelGadgets.new()  # D-118: world-space, next to the crew (not under the camera)
	gadgets.setup(self)
	if crew != null and crew.get_parent() != null:
		crew.get_parent().add_child.call_deferred(gadgets)
	apply_sleeves(crew.heister if crew != null else &"")
	_no_shadows(inst)
	for ch: StringName in CHANNELS:
		parts[ch] = 0.0
	return true


func _ready() -> void:
	if _crew != null and _crew.weapons != null:
		_crew.weapons.fired.connect(_on_fired)
		_crew.weapons.reload_started.connect(_on_reload_started)
		_crew.weapons.reload_finished.connect(_on_reload_finished)
	if _crew != null and _crew.melee != null:
		_crew.melee.charge_started.connect(_on_melee_charge)
		_crew.melee.swung.connect(_on_melee_swung)
	if _crew != null and _crew.throwables != null:
		_crew.throwables.pin_pulled.connect(_on_pin_pulled)
		_crew.throwables.released.connect(_on_throw_released)
		_crew.throwables.deck_item_used.connect(_on_deck_item_used)
	if _crew != null:
		_crew.carried_bag_changed.connect(_on_bag_changed)
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_cancelled.connect(_on_interaction_ended)
	EventBus.interaction_completed.connect(_on_interaction_ended)


func _exit_tree() -> void:
	if gadgets != null and is_instance_valid(gadgets):
		gadgets.queue_free()
	for pair: Array in [[EventBus.interaction_started, _on_interaction_started],
			[EventBus.interaction_cancelled, _on_interaction_ended], [EventBus.interaction_completed, _on_interaction_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	if _crew != null and is_instance_valid(_crew) and _crew.carried_bag_changed.is_connected(_on_bag_changed):
		_crew.carried_bag_changed.disconnect(_on_bag_changed)
	if _crew == null or not is_instance_valid(_crew) or _crew.weapons == null:
		return
	var pairs: Array = [
		[_crew.weapons.fired, _on_fired], [_crew.weapons.reload_started, _on_reload_started],
		[_crew.weapons.reload_finished, _on_reload_finished],
	]
	if _crew.melee != null:
		pairs.append_array([[_crew.melee.charge_started, _on_melee_charge], [_crew.melee.swung, _on_melee_swung]])
	if _crew.throwables != null:
		pairs.append_array([[_crew.throwables.pin_pulled, _on_pin_pulled], [_crew.throwables.released, _on_throw_released],
			[_crew.throwables.deck_item_used, _on_deck_item_used]])
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


## characters.md v1.8: copy the heister's sleeve variant `Arms` mesh + skin onto the rig's `Arms` (the variant is
## freed). False when there is no variant for `heister` (the rig keeps its own sleeves).
func apply_sleeves(heister: StringName) -> bool:
	var ps: PackedScene = FpViewmodelTweak.data().sleeve_scenes.get(heister) if heister != &"" else null
	var mine: MeshInstance3D = skeleton.get_node_or_null(^"Arms") as MeshInstance3D if skeleton != null else null
	if ps == null or mine == null:
		return false
	var v: Node = ps.instantiate()
	var theirs: MeshInstance3D = v.find_child("Arms", true, false) as MeshInstance3D
	var ok: bool = theirs != null and theirs.mesh != null
	if ok:
		mine.mesh = theirs.mesh
		mine.skin = theirs.skin
		for i: int in theirs.get_surface_override_material_count():
			mine.set_surface_override_material(i, theirs.get_surface_override_material(i))
	v.free()
	return ok


## True when the rig has a library for `set` (built from "<set>_<clip>" glb clips if needed) with `idle`.
func supports(set_id: StringName) -> bool:
	if player == null or set_id == &"":
		return false
	if not player.has_animation_library(set_id):
		_build_library(set_id)
	return player.has_animation("%s/idle" % set_id)


## Hang `wv` (already set up for `def`) on the weapon bone. `old` is the previous WeaponVisual: freed now, or
## kept for the holster when `equip_s` >= 0 (animated swap: holster + draw over `equip_s` seconds).
func attach_weapon(wv: WeaponVisual, def: WeaponDef, old: Node3D = null, equip_s: float = -1.0) -> void:
	_finish_swap()
	var new_set: StringName = def.anim_set if def != null else &""
	var animated: bool = equip_s >= 0.0
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var keep_old: bool = animated and old != null and is_instance_valid(old) and old == weapon_visual \
		and anim_set != &"" and _resolve(anim_set, &"holster") != &"" and equip_s > 0.0
	weapon_attach.add_child(wv)
	_no_shadows(wv)
	_end_action()
	if keep_old:
		wv.visible = false
		_incoming = wv
		_incoming_set = new_set
		var hol: float = equip_s * clampf(tw.holster_share, 0.0, 1.0)
		var segs: Array[Dictionary] = []
		_add_timed(segs, anim_set, &"holster", &"gone", hol)
		_add_timed(segs, new_set, &"draw", &"ready", equip_s - hol)
		_start(Action.SWAP, segs)
		return
	if old != null and is_instance_valid(old) and old != wv:
		_free_node(old)
	_set_weapon(wv, new_set)
	if animated:
		var segs: Array[Dictionary] = []
		_add_timed(segs, new_set, &"draw", &"ready", equip_s)
		_start(Action.SWAP, segs)


func _process(delta: float) -> void:
	tick(delta)


## Advance one presentation frame (tests call it directly).
func tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if action == Action.RELOAD and not _reload_done and _crew != null and _crew.weapons != null \
			and not _crew.weapons.reloading:
		_end_action()  # cancelled (swap, crew state)
	if _interact_wait >= 0.0:
		_interact_wait -= delta
		if _interact_wait < 0.0:
			_lower_for_interaction()
	if action != Action.NONE:
		_seq_t += delta
		while action != Action.NONE and _seg_i >= 0 and _seg_i < _segs.size() \
				and _seq_t >= float(_segs[_seg_i]["start"]) + float(_segs[_seg_i]["dur"]):
			_play_segment(_seg_i + 1)
	_update_deploy()
	_update_pin()
	deck.tick(self, _seq_t)
	_update_parts()
	_update_ads(delta)
	if action == Action.NONE:
		_play_base(tw)
	_tick_kick(delta, tw)
	_tick_sway(delta, tw)
	_update_offset(delta, tw)
	_update_magazine()
	_update_flash(delta, tw)
	# D-116: one-handed FP sets keep the left arm out of view, except while a reload clip needs the hand.
	var drop: float = 1.0 if tw.one_handed_fp_sets.has(_playing_set()) and action != Action.RELOAD else 0.0
	_left_drop = move_toward(_left_drop, drop, delta * tw.one_handed_drop_rate)
	if left_hand_ik != null:  # D-069: the clip owns the left hand while reloading / swapping
		left_hand_ik.update(delta, action == Action.NONE or action == Action.FIRE)


# --- Gameplay signal handlers (presentation only) ---------------------------------------------

func _on_fired(_claim: Dictionary) -> void:
	if anim_set == &"" or action == Action.SWAP or action == Action.INTERACT:
		return
	offhand.begin_shot()
	_flash_muzzle()
	var aimed: bool = _aim_wanted()
	var fire: StringName = _resolve(anim_set, offhand.clip(&"fire_ads" if aimed else &"fire"))
	fire = fire if fire != &"" else _resolve(anim_set, &"fire_ads" if aimed else &"fire")
	var bolt: StringName = _resolve(anim_set, &"bolt_ads" if aimed else &"bolt")
	var cycle: float = _length(anim_set, fire) if fire != &"" else 0.0
	var done: float = _event(anim_set, fire, &"done") if fire != &"" else -1.0
	if bolt != &"":
		done = cycle + maxf(_event(anim_set, bolt, &"done"), 0.0)
	elif done < 0.0:
		done = cycle
	var speed: float = maxf(1.0, done / maxf(_shot_interval(), 0.01))
	_shot_fx(aimed, _eject_delay(fire, bolt, cycle, speed))
	if fire == &"":
		return
	var segs: Array[Dictionary] = []
	_add_seg(segs, anim_set, fire, cycle / speed, speed)
	if bolt != &"":
		_add_seg(segs, anim_set, bolt, _length(anim_set, bolt) / speed, speed)
	_start(Action.FIRE, segs)
	if _last_round():
		_drop_keys(&"slide", 0.0)  # pistol slide lock on the last round


## D-102 lane (PD2 PlayerCarry:_enter): a bag pickup re-plays the weapon's draw over its equip time, unless a
## swap, reload, melee, throw or deploy is already playing (PD2 skips it while changing weapon).
func _on_bag_changed(bag: Node) -> void:
	if bag == null or not FpViewmodelTweak.data().carry_reequip or anim_set == &"" or _crew == null \
			or _crew.weapons == null or (action != Action.NONE and action != Action.FIRE):
		return
	var w: CrewWeapons = _crew.weapons
	var st: WeaponStats = w.stats(w.equipped_slot)
	if st == null or st.equip_time_s <= 0.0 or _resolve(anim_set, &"draw") == &"":
		return
	var equip_s: float = st.equip_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.swap_speed_mult"), 0.01)
	_end_action()
	var segs: Array[Dictionary] = []
	_add_timed(segs, anim_set, &"draw", &"ready", equip_s)
	_start(Action.SWAP, segs)


## PO pass: a timed interaction by this crew lowers the weapon after interact_lower_delay_s (instant ones end first).
func _on_interaction_started(_interactable_net_id: int, crew_slot: int, _kind: StringName) -> void:
	if _crew == null or crew_slot != _crew.slot or not FpViewmodelTweak.data().interact_lower:
		return
	_interact_wait = FpViewmodelTweak.data().interact_lower_delay_s


func _on_interaction_ended(_interactable_net_id: int, crew_slot: int, _kind: StringName = &"") -> void:
	if _crew == null or crew_slot != _crew.slot:
		return
	_interact_wait = -1.0
	if action == Action.INTERACT:
		_draw_weapon()


func _lower_for_interaction() -> void:
	var equip_s: float = _equip_time()
	if anim_set == &"" or equip_s <= 0.0 or (action != Action.NONE and action != Action.FIRE) \
			or _resolve(anim_set, &"holster") == &"":
		return
	_end_action()
	var segs: Array[Dictionary] = []
	_add_timed(segs, anim_set, &"holster", &"gone", equip_s * clampf(FpViewmodelTweak.data().holster_share, 0.0, 1.0))
	_start(Action.INTERACT, segs)


## The equipped weapon's draw over its gameplay equip time (bag pickup, end of an interaction).
## PO6-12 (ENV B range): replay the equipped weapon's `draw` (ready@ on the gameplay equip time), e.g. when a pick
## lands in the slot already in the hands. Presentation only.
func play_draw() -> void:
	_draw_weapon()


func _draw_weapon() -> void:
	var equip_s: float = _equip_time()
	_end_action()
	if anim_set == &"" or equip_s <= 0.0 or _resolve(anim_set, &"draw") == &"":
		return
	var segs: Array[Dictionary] = []
	_add_timed(segs, anim_set, &"draw", &"ready", equip_s)
	_start(Action.SWAP, segs)


## Gameplay equip time of the equipped weapon (x weapon.swap_speed_mult), -1 without one.
func _equip_time() -> float:
	if _crew == null or _crew.weapons == null:
		return -1.0
	var st: WeaponStats = _crew.weapons.stats(_crew.weapons.equipped_slot)
	if st == null or st.equip_time_s <= 0.0:
		return -1.0
	return st.equip_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.swap_speed_mult"), 0.01)


## D-105: muzzle burst + smoke, the casing (on the bolt / pump / lever cycle when the set has one: `eject_delay`),
## and the per-shot kick.
func _shot_fx(aimed: bool, eject_delay: float) -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if weapon_visual != null and is_instance_valid(weapon_visual) and fx != null:
		var st: WeaponStats = _crew.weapons.stats(_crew.weapons.equipped_slot) \
			if _crew != null and _crew.weapons != null else null
		if not tw.no_flash_sets.has(anim_set):
			fx.flash(offhand.marker(weapon_visual, &"Muzzle"), st != null and st.suppressed,
				float(tw.muzzle_flash_set_mult.get(anim_set, 1.0)), tw.flash_class_by_set.get(anim_set, &""))
		var kind: StringName = tw.shell_kind.get(anim_set, &"")
		if kind != &"":
			fx.eject(offhand.marker(weapon_visual, &"Eject"), kind, eject_delay)
	var amp: Vector2 = Vector2(float(tw.kick_back_m.get(anim_set, 0.0)), float(tw.kick_pitch_deg.get(anim_set, 0.0)))
	if aimed:
		amp *= tw.kick_ads_mult
	var w: float = TAU * maxf(tw.kick_hz, 0.1)
	_kick_v += amp * w * exp(1.0)  # x(t) = v0 t e^(-wt) peaks at amp after 1/w s


## Seconds after the shot when the case leaves the port: the set's cycle event (pump back, lever open, bolt back;
## FpViewmodelTweak.shell_eject_event) at the playing speed, else 0 (on the shot).
func _eject_delay(fire: StringName, bolt: StringName, cycle: float, speed: float) -> float:
	var spec: Array = FpViewmodelTweak.data().shell_eject_event.get(anim_set, [])
	if spec.size() < 2:
		return 0.0
	var on_bolt: bool = StringName(spec[0]) == &"bolt"
	var clip: StringName = bolt if on_bolt else fire
	if clip == &"":
		return 0.0
	var t: float = _event(anim_set, clip, StringName(spec[1]))
	if t < 0.0:
		return 0.0
	return (cycle + t if on_bolt else t) / maxf(speed, 0.01)


## PO-13 (PD2 _calculate_soft_velocity_overshot): the weapon lags the look. Turning right swings it left (and rolls
## it), looking up dips it; it catches up as the look slows, faster the further behind it is.
func _tick_sway(delta: float, tw: FpViewmodelTweak) -> void:
	if _crew == null or not is_instance_valid(_crew) or delta <= 0.0:
		return
	var look: Vector2 = Vector2(_crew.look_yaw, _crew.look_pitch)
	if _last_look == Vector2.INF:
		_last_look = look
	var rate: Vector2 = Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
	_last_look = look
	var max_deg: Vector2 = Vector2(lerpf(tw.sway_yaw_max_deg, tw.sway_ads_yaw_max_deg, ads_weight),
		lerpf(tw.sway_pitch_max_deg, tw.sway_ads_pitch_max_deg, ads_weight))
	var full: float = deg_to_rad(maxf(tw.sway_full_dps, 1.0))
	# Godot yaw grows turning left: turning right (rate.x < 0) swings the gun left (+yaw); looking up dips it (-pitch).
	var input: Vector2 = Vector2(
		-signf(rate.x) * pow(clampf(absf(rate.x) / full, 0.0, 1.0), 1.5) * max_deg.x,
		-signf(rate.y) * pow(clampf(absf(rate.y) / full, 0.0, 1.0), 1.5) * max_deg.y)
	_sway_target.x = move_toward(_sway_target.x, input.x, tw.sway_target_rate_dps * delta)
	_sway_target.y = move_toward(_sway_target.y, input.y, tw.sway_target_rate_dps * delta)
	if tw.sway_spring_hz > 0.0:  # D-116: spring with a slight overshoot
		var w: float = TAU * tw.sway_spring_hz
		var left: float = delta
		while left > 0.0:
			var h: float = minf(left, 1.0 / 120.0)
			_sway_v += (w * w * (_sway_target - _sway) - 2.0 * tw.sway_spring_damping * w * _sway_v) * h
			_sway += _sway_v * h
			left -= h
	else:
		for k: int in 2:
			var diff: float = absf(_sway_target[k] - _sway[k])
			_sway[k] = move_toward(_sway[k], _sway_target[k], lerpf(3.0, 180.0, clampf(diff / 40.0, 0.0, 1.0)) * delta)
	_breath_t += delta


## PO-13 (PD2 breathing shaker): a slow idle drift, x = yaw, y = pitch (deg); smaller crouched, almost none aimed.
func _breathing() -> Vector2:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var amp: float = tw.breathing_crouched_amp_deg if _crew != null and is_instance_valid(_crew) and _crew.crouched \
		else tw.breathing_amp_deg
	amp = lerpf(amp, tw.breathing_ads_amp_deg, ads_weight)
	var w: float = TAU * tw.breathing_hz
	return Vector2(sin(_breath_t * w * 0.63) * amp * 0.6, sin(_breath_t * w) * amp)


func _capture_hand() -> void:
	if skeleton == null or _hand_bone < 0 or _weapon_bone < 0:
		return
	if vgrip.active():  # D-118: the vertical grip's hand orientation
		_hand_rel = vgrip.rel
		_hand_rel_set = true
		return
	# PO6-11: mid ADS blend the clip's hand orientation is a blend artefact; keep the one from hip / full ADS.
	if _hand_rel_set and ads_weight > 0.001 and ads_weight < 0.999 \
			and FpViewmodelTweak.data().left_hand_hold_rel_sets.has(anim_set):
		return
	_hand_rel_set = true
	_hand_rel = skeleton.get_bone_global_pose(_weapon_bone).basis.orthonormalized().inverse() \
		* skeleton.get_bone_global_pose(_hand_bone).basis.orthonormalized()


func _restore_hand() -> void:
	if skeleton == null or _hand_bone < 0 or _weapon_bone < 0 or left_hand_ik == null or left_hand_ik.ik == null:
		return
	var w: float = left_hand_ik.ik.influence
	if w <= 0.0:
		return
	var pose: Transform3D = skeleton.get_bone_global_pose(_hand_bone)
	var want: Basis = skeleton.get_bone_global_pose(_weapon_bone).basis.orthonormalized() * _hand_rel
	var scale_v: Vector3 = pose.basis.get_scale()
	var q: Quaternion = pose.basis.orthonormalized().get_rotation_quaternion().slerp(want.get_rotation_quaternion(), w)
	skeleton.set_bone_global_pose(_hand_bone, Transform3D(Basis(q).scaled(scale_v), pose.origin))


## Presentation origin for the NEXT shot's tracer / FX (ENV A's CrewWeapons._fx_origin, which runs before `fired`):
## the Muzzle of the gun that fires it (akimbo: the left one on a left shot); null without a visual. Gameplay stays
## at the eye (D-121).
func fx_muzzle() -> Node3D:
	return offhand.next_marker(weapon_visual, &"Muzzle")


## Read only (tests): whether the equipped gun's vertical grip took over the left hand.
func vgrip_active() -> bool:
	return vgrip.active()


## D-116 (LeftArmHide modifier): move upper_arm.L (and so the whole left arm) by one_handed_left_drop (camera space,
## scaled by the eased _left_drop) so a one-handed set shows no support arm.
func _hide_left_arm() -> void:
	if skeleton == null or _left_root_bone < 0 or _left_drop <= 0.0 or arms == null:
		return
	var off_cam: Vector3 = FpViewmodelTweak.data().one_handed_left_drop * smoothstep(0.0, 1.0, _left_drop)
	var off_skel: Vector3 = skeleton.global_basis.inverse() * (arms.global_basis * off_cam)
	var pose: Transform3D = skeleton.get_bone_global_pose(_left_root_bone)
	skeleton.set_bone_global_pose(_left_root_bone, Transform3D(pose.basis, pose.origin + off_skel))


## Read only (tests): how far the left arm is dropped for a one-handed set (0..1).
func left_arm_drop() -> float:
	return _left_drop


## Read only (tests): the current look-lag sway (yaw, pitch; deg).
func sway() -> Vector2:
	return _sway


## Read only (CrewView scope overlay): the sight's sway this frame, look-lag spring + breathing (yaw, pitch; deg),
## the same terms that turn the gun in _late_align (recoil kick excluded: the camera carries it).
func sight_sway_deg(sway_mult: float = 1.0, breath_mult: float = 1.0) -> Vector2:
	return _sway * sway_mult + _breathing() * breath_mult


## Exact critically damped step (no amplitude loss at 60 Hz, see the PO-4 landing dip). The step is capped at 1/30 s
## so a slow frame still shows the punch instead of skipping past its 18 ms peak.
func _tick_kick(delta: float, tw: FpViewmodelTweak) -> void:
	if _kick == Vector2.ZERO and _kick_v == Vector2.ZERO:
		return
	var w: float = TAU * maxf(tw.kick_hz, 0.1)
	delta = minf(delta, 1.0 / 30.0)
	var e: float = exp(-w * delta)
	var b: Vector2 = _kick_v + w * _kick
	_kick = (_kick + b * delta) * e
	_kick_v = (_kick_v - w * b * delta) * e
	if _kick.length() < 1e-5 and _kick_v.length() < 1e-4:
		_kick = Vector2.ZERO
		_kick_v = Vector2.ZERO


## Read only (tests): the current per-shot kick (back m, pitch deg).
func kick() -> Vector2:
	return _kick


## The crew this viewmodel belongs to.
func crew() -> CrewController:
	return _crew


## Enums.WeaponClass key of the equipped weapon (FpViewmodelTweak.tracer_every), &"" when unknown.
func weapon_class_key() -> StringName:
	if _crew == null or _crew.weapons == null:
		return &""
	var def: WeaponDef = ContentDB.weapon(_crew.weapons.weapon_id(_crew.weapons.equipped_slot))
	return StringName(Enums.WeaponClass.keys()[def.weapon_class]) if def != null else &""


## Where the muzzle APPEARS in the world: the viewmodel draws through its own camera (other FOV), so the Muzzle
## marker's world position is not where the player sees it. Projected through the viewmodel camera to the screen,
## then back out of the world camera at the same depth. Vector3.INF without a muzzle.
func muzzle_world_apparent() -> Vector3:
	if weapon_visual == null or not is_instance_valid(weapon_visual):
		return Vector3.INF
	return marker_world_apparent(weapon_visual.get_marker(&"Muzzle"))


## D-118: where any viewmodel node `m` APPEARS in the world (see muzzle_world_apparent); Vector3.INF without one.
func marker_world_apparent(m: Node3D) -> Vector3:
	var cam: Camera3D = get_parent() as Camera3D
	if m == null or not m.is_inside_tree() or cam == null:
		return Vector3.INF
	var view: CrewView = CrewView.of(_crew) if _crew != null else null
	var vcam: Camera3D = view.viewmodel_camera() if view != null else null
	if vcam == null:
		return m.global_position
	var depth: float = -(cam.global_transform.affine_inverse() * m.global_position).z
	return cam.project_position(vcam.unproject_position(m.global_position), maxf(depth, cam.near + 0.01))


func _on_reload_started(ws: int, duration: float) -> void:
	_finish_swap()
	if anim_set == &"" or _crew == null or _crew.weapons == null:
		return
	var w: CrewWeapons = _crew.weapons
	var empty: bool = w.mag(ws) <= 0
	var st: WeaponStats = w.stats(ws)
	var segs: Array[Dictionary] = []
	var native: float = 0.0
	var loop: StringName = _resolve(anim_set, &"reload_loop")
	var start: StringName = _resolve(anim_set, &"reload_start")
	var end: StringName = _resolve(anim_set, &"reload_end_empty" if empty else &"reload_end")
	if st != null and st.reload_per_round_s > 0.0 and loop != &"" and start != &"" and end != &"":
		var n: int = maxi(mini(w.mag_size(ws) - w.mag(ws), w.reserve(ws)), 1)
		_add_seg(segs, anim_set, start, _length(anim_set, start), 1.0)
		_add_seg(segs, anim_set, loop, _length(anim_set, loop) * n, 1.0, n)
		_add_seg(segs, anim_set, end, _length(anim_set, end), 1.0)
		var end_done: float = _event(anim_set, end, &"done")
		native = _length(anim_set, start) + _length(anim_set, loop) * n \
			+ (end_done if end_done >= 0.0 else _length(anim_set, end))
	else:
		var c: StringName = _resolve(anim_set, &"reload_empty" if empty else &"reload")
		if c == &"":
			return
		_add_seg(segs, anim_set, c, _length(anim_set, c), 1.0)
		native = _event(anim_set, c, &"done")
		if native < 0.0:
			native = _length(anim_set, c)
		_check_shared_reload(w.weapon_id(ws), c, _length(anim_set, c), st.reload_empty_time_s if empty else st.reload_time_s)
	var speed: float = native / maxf(duration, 0.05)
	var at: float = 0.0
	for s: Dictionary in segs:
		s["start"] = at
		s["dur"] = float(s["dur"]) / maxf(speed, 0.001)
		s["speed"] = speed
		at += float(s["dur"])
	_reload_done = false
	_start(Action.RELOAD, segs)


## D-063: a shared single reload clip plays at about clip length / the weapon's reload time (the retiming
## above, before skill multipliers). True when that ratio is inside FpViewmodelTweak's allowed range.
static func shared_reload_ratio_ok(clip_s: float, reload_s: float) -> bool:
	if reload_s <= 0.0 or clip_s <= 0.0:
		return true
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var ratio: float = clip_s / reload_s
	return ratio >= tw.reload_scale_min and ratio <= tw.reload_scale_max


func _check_shared_reload(weapon_id: StringName, clip: StringName, clip_s: float, reload_s: float) -> void:
	var key: String = "%s|%s" % [weapon_id, clip]
	if not shared_reload_ratio_ok(clip_s, reload_s) and not _reload_scale_logged.has(key):
		var tw: FpViewmodelTweak = FpViewmodelTweak.data()
		var ratio: float = clip_s / reload_s
		_reload_scale_logged[key] = true
		Log.error(&"anim", "D-063: %s plays %s at x%.2f (allowed %.2f-%.2f): needs its own reload clip"
			% [weapon_id, clip, ratio, tw.reload_scale_min, tw.reload_scale_max])


func _on_reload_finished(_ws: int) -> void:
	_reload_done = true


## The melee item's set when the rig has it (&"" = gun bash / no item clips).
func _melee_set() -> StringName:
	var def: MeleeDef = _crew.melee.melee_def() if _crew != null and _crew.melee != null else null
	return def.anim_set if def != null and supports(def.anim_set) else &""


func _on_melee_charge() -> void:
	var set_id: StringName = _melee_set()
	if set_id == &"" or action == Action.SWAP:
		return  # gun bash: the clip plays on the swing
	var def: MeleeDef = _crew.melee.melee_def()
	var full_s: float = def.charge_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.melee_charge_speed_mult"), 0.01)
	var segs: Array[Dictionary] = []
	_add_timed(segs, set_id, &"charge_start", &"charged", full_s)
	var loop: StringName = _resolve(set_id, &"charge")
	if loop != &"":
		_add_seg(segs, set_id, loop, _length(set_id, loop) * CHARGE_LOOPS, 1.0, CHARGE_LOOPS)
	_start_item(Action.MELEE, segs, def.model)


func _on_melee_swung(charged: bool) -> void:
	if action == Action.SWAP:
		return
	var set_id: StringName = _melee_set()
	var hit_s: float = maxf(_crew.melee.hit_left, 0.01)
	var segs: Array[Dictionary] = []
	if set_id != &"":
		var c: StringName = _resolve(set_id, &"charge_swing" if charged else &"swing")
		if c == &"":
			c = _resolve(set_id, &"swing")
		if c == &"":
			return
		_add_timed(segs, set_id, c, &"hit", hit_s)
		_start_item(Action.MELEE, segs, _crew.melee.melee_def().model)
		return
	if _resolve(anim_set, &"bash") == &"":
		return
	_add_timed(segs, anim_set, &"bash", &"hit", hit_s)
	_end_action()
	_start(Action.MELEE, segs)


func _on_pin_pulled() -> void:
	var def: ThrowableDef = _crew.throwables.throwable_def() if _crew.throwables != null else null
	if def == null or action == Action.SWAP or not supports(def.anim_set):
		return
	var windup: float = CombatTweak.data().throw_windup_s
	var throw_c: StringName = _resolve(def.anim_set, &"throw_low" if _crew.intent != null and _crew.intent.crouch else &"throw")
	if throw_c == &"":
		throw_c = _resolve(def.anim_set, &"throw")
	if throw_c == &"":
		return
	var draw_c: StringName = _resolve(def.anim_set, &"draw")
	var draw_n: float = _length(def.anim_set, draw_c) if draw_c != &"" else 0.0
	var rel_n: float = maxf(_event(def.anim_set, throw_c, &"release"), 0.01)
	var share: float = draw_n / (draw_n + rel_n)  # split the windup in the clips' native proportion
	var segs: Array[Dictionary] = []
	if draw_c != &"":
		_add_timed(segs, def.anim_set, draw_c, &"ready", windup * share)
	_add_timed(segs, def.anim_set, throw_c, &"release", windup * (1.0 - share))
	_start_item(Action.THROW, segs, def.model)
	var pin: float = _event(def.anim_set, draw_c, &"pin_pull") if draw_c != &"" else -1.0
	_pin_t = pin / maxf(float(segs[0]["speed"]), 0.001) if pin >= 0.0 else 0.0


func _on_throw_released() -> void:
	if action == Action.THROW and _item != null and is_instance_valid(_item):
		_item.visible = false  # the ThrownItem flies from here
	_pin_t = -1.0


## A perk-deck item was used (every peer): its use pose (FpViewmodelDeck).
func _on_deck_item_used(item_id: StringName, kind: StringName) -> void:
	deck.play(self, ContentDB.throwable(item_id), kind)


func _update_pin() -> void:
	if (action != Action.THROW and action != Action.DECK) or _pin_t < 0.0 or _seq_t < _pin_t:
		return
	_pin_t = -1.0
	var pin: Node3D = _item.find_child("Pin", true, false) as Node3D if _item != null and is_instance_valid(_item) else null
	if pin != null:
		pin.visible = false  # visual_slots.md Items: ENV A hides the Pin at pin_pull


## Item one-shot (MELEE / DEPLOY / THROW) with `model` in the hands (the gun hidden until _end_action).
func _start_item(kind: int, segs: Array[Dictionary], model: PackedScene) -> void:
	_end_action()
	if weapon_visual != null and is_instance_valid(weapon_visual):
		weapon_visual.visible = false
	if model != null:
		_item = model.instantiate() as Node3D
		if _item != null:
			_item.name = ITEM_NAME
			weapon_attach.add_child(_item)
			_no_shadows(_item)
	_start(kind, segs)


func _clear_item() -> void:
	if _item != null and is_instance_valid(_item):
		_free_node(_item)
	_item = null
	if weapon_visual != null and is_instance_valid(weapon_visual) and _incoming == null:
		weapon_visual.visible = true


# --- Sequences --------------------------------------------------------------------------------

## Append clip `c` of `set_id` for `dur` real seconds at `speed`; `loops` = repetitions (looped clips).
func _add_seg(segs: Array[Dictionary], set_id: StringName, c: StringName, dur: float, speed: float,
		loops: int = 1) -> void:
	var start: float = 0.0
	if not segs.is_empty():
		start = float(segs.back()["start"]) + float(segs.back()["dur"])
	segs.append({"set": set_id, "clip": c, "start": start, "dur": maxf(dur, 0.0), "speed": speed, "loops": loops})


## Append `c` re-timed so its `event` frame (else its end) lands `dur` seconds after the segment start.
func _add_timed(segs: Array[Dictionary], set_id: StringName, c: StringName, event: StringName, dur: float) -> void:
	var r: StringName = _resolve(set_id, c)
	if r == &"" or dur <= 0.0:
		_add_seg(segs, set_id, &"", maxf(dur, 0.0), 1.0)  # no clip: still switch the weapon at this point
		return
	var at: float = _event(set_id, r, event)
	if at <= 0.0:
		at = _length(set_id, r)
	var speed: float = at / dur
	_add_seg(segs, set_id, r, _length(set_id, r) / maxf(speed, 0.001), speed)


func _start(kind: int, segs: Array[Dictionary]) -> void:
	if _item_action() and kind != action:
		_clear_item()  # e.g. a reload started mid-charge
	action = kind
	_segs = segs
	_seq_t = 0.0
	_keys.clear()
	_key_start = parts.duplicate()
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	for s: Dictionary in segs:
		if StringName(s["clip"]) == &"":
			continue
		var speed: float = maxf(float(s["speed"]), 0.001)
		var per: float = float(s["dur"]) / maxi(int(s["loops"]), 1)
		var ev: Dictionary = tw.events_s(StringName("%s_%s" % [s["set"], s["clip"]]))
		for i: int in maxi(int(s["loops"]), 1):
			for e: Variant in ev:
				if EVENT_PARTS.has(e):
					var map: Array = EVENT_PARTS[e]
					_keys.append({
						"t": float(s["start"]) + per * i + float(ev[e]) / speed, "ch": map[0], "v": float(map[1]),
						"ramp": tw.part_ramp_frames / maxf(tw.fps, 1.0) / speed,
					})
	_keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var last: Dictionary = {}
	for k: Dictionary in _keys:  # a ramp never starts before the channel's previous event (or the start)
		k["ramp"] = minf(float(k["ramp"]), float(k["t"]) - float(last.get(k["ch"], 0.0)))
		last[k["ch"]] = float(k["t"])
	_play_segment(0)


func _play_segment(i: int) -> void:
	_seg_i = i
	if i >= _segs.size():
		if action == Action.DECK:
			_draw_weapon()  # the gun comes back after the deck item
		elif action != Action.INTERACT:  # an interaction holds the holstered pose until it ends
			_end_action()
		return
	var s: Dictionary = _segs[i]
	var set_id: StringName = s["set"]
	if action == Action.SWAP and _incoming != null and set_id == _incoming_set and i > 0:
		_finish_swap()
	var c: StringName = s["clip"]
	if c == &"":
		return
	action_speed = float(s["speed"])
	var full: String = "%s/%s" % [set_id, c]
	player.play(full, FpViewmodelTweak.data().oneshot_blend_s, action_speed)
	player.seek(0.0, true)  # restart (full-auto fire clips restart every shot)
	clip = c


func _end_action() -> void:
	for k: Dictionary in _keys:  # settle the parts on the one-shot's final positions
		parts[k["ch"]] = float(k["v"])
	if _item_action():
		_clear_item()
	_finish_swap()
	action = Action.NONE
	action_speed = 1.0
	_segs.clear()
	_seg_i = -1
	_keys.clear()


## Drop the outgoing weapon and show the incoming one.
func _finish_swap() -> void:
	if _incoming == null:
		return
	var wv: WeaponVisual = _incoming
	var set_id: StringName = _incoming_set
	_incoming = null
	_incoming_set = &""
	if weapon_visual != null and is_instance_valid(weapon_visual) and weapon_visual != wv:
		_free_node(weapon_visual)
	if is_instance_valid(wv):
		wv.visible = true
		_set_weapon(wv, set_id)


func _set_weapon(wv: WeaponVisual, set_id: StringName) -> void:
	weapon_visual = wv
	anim_set = set_id
	clip = &""
	_hand_rel_set = false
	for ch: StringName in CHANNELS:
		parts[ch] = 0.0
		_key_start[ch] = 0.0
	_part_nodes.clear()
	for n: StringName in [PART_SLIDE, PART_PUMP, PART_BOLT, PART_COVER]:
		var node: Node3D = wv.get_base_marker(n) if wv != null else null
		if node != null:
			_part_nodes[n] = [node, node.transform]
	_magwell = wv.get_base_marker(&"Magwell") if wv != null else null
	if left_hand_ik != null:
		left_hand_ik.set_target(wv.get_marker(&"LeftHandIK") if wv != null else null, set_id)
	if vgrip.setup(self, wv, set_id, _weapon_bone):
		_hand_rel_set = false
	offhand.setup(skeleton, wv, set_id)
	_magwell_rest = _magwell.transform if _magwell != null else Transform3D.IDENTITY
	_check_aim_point(wv)


## PI-19: true when the visual (base model or an attached sight) has an `AimPoint` the ADS offset can align.
static func has_aim_point(wv: WeaponVisual) -> bool:
	return wv != null and is_instance_valid(wv) and wv.get_marker(WeaponVisual.AIM_POINT) != null


## PI-19: weapon ids among `defs` whose bare visual has no `AimPoint` (ADS would sit off-axis on them).
static func missing_aim_points(defs: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: Variant in defs:
		var def: WeaponDef = d as WeaponDef
		if def == null or def.model == null:
			continue
		var wv: WeaponVisual = WeaponVisual.new()
		var none: Array[WeaponModDef] = []
		wv.setup(def, none)
		if not has_aim_point(wv):
			out.append(def.id)
		wv.free()
	return out


func _check_aim_point(wv: WeaponVisual) -> void:
	if wv == null or wv.weapon == null or has_aim_point(wv) or _aim_missing_logged.has(wv.weapon.id):
		return
	_aim_missing_logged[wv.weapon.id] = true
	Log.warn(&"anim", "PI-19: %s has no AimPoint marker; ADS sights cannot align to the camera axis" % wv.weapon.id)


# --- Per-frame helpers ------------------------------------------------------------------------

func _item_action() -> bool:
	return action == Action.MELEE or action == Action.DEPLOY or action == Action.THROW or action == Action.DECK


## D-069 deploy `place` while intent.deploy is held (presentation of DeployableSystem's server hold).
func _update_deploy() -> void:
	var held: bool = _crew != null and _crew.intent != null and _crew.intent.deploy
	var pressed: bool = held and not _deploy_prev
	_deploy_prev = held
	if action == Action.DEPLOY:
		if not held:
			_end_action()  # released early (or the clip outlived the hold)
		return
	if not pressed or action == Action.SWAP or action == Action.MELEE or action == Action.THROW or action == Action.DECK \
			or not _can_deploy():
		return
	var def: DeployableDef = DeployableSystem.def_for(_crew.weapons.deployable_id)
	if def == null or not supports(def.anim_set):
		return
	var segs: Array[Dictionary] = []
	_add_timed(segs, def.anim_set, &"place", &"place", DeployableSystem.deploy_time_for(_crew.slot, def))
	if segs.is_empty() or StringName(segs[0]["clip"]) == &"":
		return
	_start_item(Action.DEPLOY, segs, def.model)


func _can_deploy() -> bool:
	return _crew.weapons != null and _crew.weapons.deployable_count > 0 and _crew.masked \
		and _crew.crew_state == Enums.CrewState.NORMAL

func _play_base(tw: FpViewmodelTweak) -> void:
	if anim_set == &"":
		return
	var want: StringName = &"idle"
	var aiming: bool = _aim_wanted() and action != Action.SWAP
	if _sprinting(tw):
		want = &"sprint"
	elif aiming:
		want = &"ads_idle"
	var r: StringName = _resolve(anim_set, want)
	if r == &"" or (r == clip and player.is_playing()):
		return
	# PO-4: idle <-> ads_idle switch on the aim press / release and crossfade over the whole ADS time, so the arms move
	# with the zoom for the full transition (switching at weight 0.5 with blend_s left the first half static, then
	# snapped once ads_time_s grew to PD2's ~0.23-0.3 s).
	var ads_switch: bool = (want == &"ads_idle") != (clip == _resolve(anim_set, &"ads_idle"))
	var blend: float = 1.0 / maxf(CrewView.ads_rate(_crew), 0.01) if ads_switch and not _sprinting(tw) else tw.blend_s
	player.play("%s/%s" % [anim_set, r], blend)
	clip = r


func _update_ads(delta: float) -> void:
	# P1-03: same target (CrewView.is_aiming), rate (CrewView.ads_rate) and smoothstep ease as the camera
	# zoom in CrewView, so sights and zoom arrive together. A swap also drops the sights (arms only).
	var target: float = 1.0 if _aim_wanted() and action != Action.SWAP else 0.0
	_ads_lin = move_toward(_ads_lin, target, CrewView.ads_rate(_crew) * delta)
	ads_weight = smoothstep(0.0, 1.0, _ads_lin)


func _update_offset(delta: float, tw: FpViewmodelTweak) -> void:
	var speed: float = _speed()
	var sprint: bool = _sprinting(tw)
	# D-116: the bob also runs while sprinting (bigger), riding the sprint clip.
	var moving: bool = speed > tw.move_threshold_mps and (tw.bob_follow_steps or not sprint)
	var target: float = clampf(speed / maxf(tw.bob_ref_speed_mps, 0.01), 0.0, 1.5) if moving else 0.0
	if sprint and tw.bob_follow_steps:
		target = minf(target, 1.0) * tw.bob_sprint_mult
	_bob_weight = move_toward(_bob_weight, target, tw.bob_rate * delta)
	_bob_phase = fmod(_bob_phase + delta * TAU * tw.bob_frequency_hz * maxf(target, 0.5), TAU)
	if tw.bob_follow_steps and _crew != null and is_instance_valid(_crew) and _crew.bob_weight > 0.0:
		# D-116: the camera's footstep phase (own clock when Options head bob is off); PO-20: eased onto it, no jump.
		var lag: float = wrapf(_crew.bob_phase - _bob_phase, -PI, PI)
		_bob_phase = fmod(_bob_phase + lag * clampf(tw.bob_phase_rate * delta, 0.0, 1.0) + TAU, TAU)
	var phase: float = _bob_phase
	_sprint_w = move_toward(_sprint_w, 1.0 if sprint else 0.0, tw.sprint_pose_rate * delta)
	var amp: float = _bob_weight * lerpf(1.0, tw.ads_bob_mult, ads_weight)
	# PO-20: the walk figure-8 crossfades into the gentler sprint sway.
	var ax: Vector2 = tw.bob_amplitude.lerp(tw.sprint_sway_amplitude, _sprint_w)
	var off: Vector3 = Vector3(sin(phase) * ax.x, sin(phase * 2.0) * ax.y, 0.0) * amp
	off.y += step_lag(tw)
	var land: float = _crew.land_dip if _crew != null and is_instance_valid(_crew) else 0.0
	off.y += land * tw.land_vm_mult * lerpf(1.0, tw.ads_bob_mult, ads_weight)  # D-116: arms dip deeper on landing
	var pitch_deg: float = lerpf(tw.bob_pitch_deg, tw.sprint_sway_pitch_deg, _sprint_w)
	var roll_deg: float = lerpf(tw.bob_roll_deg, tw.sprint_sway_roll_deg, _sprint_w)
	_bob_rot = Vector3(sin(phase * 2.0) * pitch_deg * amp + land * tw.land_vm_pitch_deg_per_m, 0.0,
		sin(phase) * roll_deg * amp)
	# PO-20: the steady sprint pose on top of the sprint clip (not while aimed).
	var pose_w: float = _sprint_w * (1.0 - ads_weight)
	off += tw.sprint_pose_offset * pose_w
	_bob_rot += tw.sprint_pose_rot_deg * pose_w
	off += deck.offset  # the deck item use pose (about the firing hand, like the set pose)
	_bob_rot += deck.rot_deg
	# PO-4: the offset of the set actually playing (a melee / throw / deploy item set rides the gun's arms but has its
	# own framing), eased so switching sets does not jump.
	var set_now: StringName = _playing_set()
	var hip: Vector3 = tw.set_hip_offset.get(set_now, Vector3.ZERO)
	var want: Vector3 = hip.lerp(Vector3(0.0, 0.0, float(tw.set_ads_offset_z.get(set_now, 0.0))), ads_weight)
	var want_rot: Vector3 = (tw.set_hip_rot_deg.get(set_now, Vector3.ZERO) as Vector3) * (1.0 - ads_weight)
	_set_rot = want_rot if _set_off_init else _set_rot.move_toward(want_rot, tw.set_offset_rate * 60.0 * delta)
	_set_off = want if _set_off_init else _set_off.move_toward(want, tw.set_offset_rate * delta)
	_set_off_init = false
	_tick_settle(delta, tw)
	off += _set_off
	off.y -= sin(PI * clampf(ads_weight, 0.0, 1.0)) * tw.ads_dip_m  # PO-13: the arc into / out of the sights
	_base_offset = off
	_late_align()  # first pass on the last applied pose (direct tick() callers / tests); AdsAlign refines it


## PO-4: light the muzzle for one shot (world layer + CrewView.VIEWMODEL_LIT_LAYER, D-094).
func _flash_muzzle() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if tw.muzzle_light_energy <= 0.0 or weapon_visual == null or not is_instance_valid(weapon_visual):
		return
	var muzzle: Node3D = offhand.marker(weapon_visual, &"Muzzle")
	if muzzle == null or not muzzle.is_inside_tree():
		return
	if _muzzle_light == null or not is_instance_valid(_muzzle_light):
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.name = "MuzzleLight"
		_muzzle_light.layers = 1 | CrewView.VIEWMODEL_LIT_LAYER
		_muzzle_light.shadow_enabled = false
		add_child(_muzzle_light)
	var st: WeaponStats = _crew.weapons.stats(_crew.weapons.equipped_slot) \
		if _crew != null and _crew.weapons != null else null
	var mult: float = tw.muzzle_light_suppressed_mult if st != null and st.suppressed else 1.0
	_muzzle_light.omni_range = tw.muzzle_light_range_m
	_muzzle_light.light_color = tw.muzzle_light_color
	_muzzle_light.global_position = muzzle.global_position
	_flash_peak = tw.muzzle_light_energy * mult
	_flash_left = tw.muzzle_light_s
	_muzzle_light.light_energy = _flash_peak
	_muzzle_light.visible = _flash_peak > 0.0


func _update_flash(delta: float, tw: FpViewmodelTweak) -> void:
	if _muzzle_light == null or not is_instance_valid(_muzzle_light) or not _muzzle_light.visible:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_muzzle_light.visible = false
		return
	_muzzle_light.light_energy = _flash_peak * _flash_left / maxf(tw.muzzle_light_s, 0.001)


## The anim set of the segment playing now (an item set during melee / throw / deploy), else the weapon's set.
func _playing_set() -> StringName:
	if action != Action.NONE and _seg_i >= 0 and _seg_i < _segs.size():
		var sid: StringName = StringName(_segs[_seg_i].get("set", &""))
		if sid != &"":
			return sid
	return anim_set


## AdsAlign (skeleton modifier, this frame's pose): shift so the weapon's AimPoint sits on the camera axis while aimed.
func _late_align() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var a: Vector3 = Vector3.ZERO
	if tw.ads_align_aim_point and ads_weight > 0.0 and weapon_visual != null and is_instance_valid(weapon_visual) \
			and is_inside_tree() and skeleton != null and _weapon_bone >= 0:
		var aim: Node3D = weapon_visual.get_marker(WeaponVisual.AIM_POINT)
		if aim != null and aim.is_inside_tree():
			var rel: Vector3 = weapon_attach.global_transform.affine_inverse() * aim.global_position  # rigid
			var in_skel: Vector3 = skeleton.get_bone_global_pose(_weapon_bone) * rel
			var off_aim: Variant = offhand.marker_in_skeleton(skeleton, weapon_visual, WeaponVisual.AIM_POINT)
			if off_aim is Vector3:  # akimbo (PD2): the crosshair sits between the two guns' sights
				in_skel = (in_skel + (off_aim as Vector3)) * 0.5
			var p: Vector3 = arms.global_transform.affine_inverse() * (skeleton.global_transform * in_skel)
			a = Vector3(-p.x, -p.y, 0.0) * ads_weight
	_align = a
	var fs: CrewFpStates = _crew.fp_states if _crew != null and is_instance_valid(_crew) else null
	var s_off: Vector3 = fs.vm_offset if fs != null else Vector3.ZERO  # P-FP-STATES: downed / tased / kicked hold
	var s_rot: Vector3 = fs.vm_rot_deg if fs != null else Vector3.ZERO
	var breath: Vector2 = _breathing()
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(_kick.y + _sway.y + breath.y + s_rot.x),
		deg_to_rad(_sway.x + breath.x + s_rot.y), deg_to_rad(-_sway.x + s_rot.z)))
	# PO6-11: hip pose, ADS arc and settle turn the arms about the firing hand (the weapon bone, this frame's pose).
	var pose: Vector3 = _pose_rot_deg(tw)
	var pivot_off: Vector3 = Vector3.ZERO
	var r: Basis = Basis.IDENTITY
	if pose != Vector3.ZERO and skeleton != null and _weapon_bone >= 0 and skeleton.is_inside_tree():
		var q: Vector3 = global_transform.affine_inverse() \
			* (skeleton.global_transform * skeleton.get_bone_global_pose(_weapon_bone).origin)
		r = Basis.from_euler(pose * (PI / 180.0))
		pivot_off = q - r * q
	# D-116 (LEAD ADS note): aimed, the set's ADS pitch turns the arms about the rear sight (AimPoint, so the sight
	# stays on the crosshair): nose down puts the eye above and behind the hand, looking along the slide.
	var ads_rot: Vector3 = (tw.set_ads_rot_deg.get(_playing_set(), Vector3.ZERO) as Vector3) * ads_weight
	if ads_rot != Vector3.ZERO and weapon_visual != null and is_instance_valid(weapon_visual) and is_inside_tree():
		var aim_m: Node3D = weapon_visual.get_marker(WeaponVisual.AIM_POINT)
		if aim_m != null and aim_m.is_inside_tree():
			var qa: Vector3 = global_transform.affine_inverse() * aim_m.global_position
			var r2: Basis = Basis.from_euler(ads_rot * (PI / 180.0))
			pivot_off += r * (qa - r2 * qa)
			r = r * r2
	transform = Transform3D(b * r, _base_offset + a + Vector3(0.0, 0.0, _kick.x) + s_off + b * pivot_off)


## PO6-11: the arms' extra rotation (deg, x pitch, y yaw, z roll) about the firing hand: the set's hip pose, the ADS
## arc roll and the settle pitch.
func _pose_rot_deg(tw: FpViewmodelTweak) -> Vector3:
	var set_now: StringName = _playing_set()
	var r: Vector3 = _set_rot + _bob_rot
	r.z += sin(PI * clampf(ads_weight, 0.0, 1.0)) * float(tw.set_ads_arc_roll_deg.get(set_now, 0.0))
	r.x += (_settle - ads_weight) * tw.ads_settle_pitch_deg * float(tw.ads_settle_set_mult.get(set_now, 1.0))
	return r


## PO6-11: advance the ADS settle spring (exact enough at frame rate: semi-implicit Euler, capped step).
func _tick_settle(delta: float, tw: FpViewmodelTweak) -> void:
	if tw.ads_settle_pitch_deg == 0.0 or tw.ads_settle_hz <= 0.0:
		_settle = ads_weight
		_settle_v = 0.0
		return
	var w: float = TAU * tw.ads_settle_hz
	var left: float = delta
	while left > 0.0:
		var h: float = minf(left, 1.0 / 120.0)
		_settle_v += (w * w * (ads_weight - _settle) - 2.0 * tw.ads_settle_damping * w * _settle_v) * h
		_settle += _settle_v * h
		left -= h


## PI-21: vertical arms lag from the camera's step smoothing (m): the arms dip after a step up and float after
## a step down, then settle with the camera. Reduced while aimed like the walk bob.
func step_lag(tw: FpViewmodelTweak) -> float:
	if _crew == null or not is_instance_valid(_crew):
		return 0.0
	return _crew.step_offset * tw.step_lag_mult * lerpf(1.0, tw.ads_bob_mult, ads_weight)


func _update_parts() -> void:
	for ch: StringName in CHANNELS:
		var v: float = float(_key_start.get(ch, parts[ch])) if action != Action.NONE else float(parts[ch])
		if action != Action.NONE:
			for k: Dictionary in _keys:
				if StringName(k["ch"]) != ch:
					continue
				var t: float = float(k["t"])
				var ramp: float = maxf(float(k["ramp"]), 0.0001)
				if _seq_t >= t:
					v = float(k["v"])
				else:
					if _seq_t > t - ramp:
						v = lerpf(v, float(k["v"]), (_seq_t - (t - ramp)) / ramp)
					break
		parts[ch] = v
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	_pose_part(PART_SLIDE, Vector3(0, 0, tw.slide_travel_m * float(parts[&"slide"])), Basis.IDENTITY)
	_pose_part(PART_PUMP, Vector3(0, 0, tw.pump_travel_m * float(parts[&"pump"])), Basis.IDENTITY)
	_pose_part(PART_BOLT, Vector3(0, 0, tw.bolt_travel_m * float(parts[&"bolt_slide"])),
		Basis(Vector3.BACK, deg_to_rad(tw.bolt_lift_deg) * float(parts[&"bolt_lift"])))
	_pose_part(PART_COVER, Vector3.ZERO, Basis(Vector3.RIGHT, deg_to_rad(tw.feed_cover_deg) * float(parts[&"cover"])))
	offhand.set_mag_hidden(float(parts[&"mag_l_out"]) > 0.5)


func _pose_part(part: StringName, offset: Vector3, rot: Basis) -> void:
	var entry: Array = _part_nodes.get(part, [])
	if entry.is_empty() or not is_instance_valid(entry[0]):
		return
	(entry[0] as Node3D).transform = (entry[1] as Transform3D) * Transform3D(rot, offset)


## The weapon's `Magwell` follows the `magazine` bone relative to the `weapon` bone (identity when seated).
func _update_magazine() -> void:
	if _mag_bone < 0 or _magwell == null or not is_instance_valid(_magwell) or weapon_visual == null:
		return
	var d: Transform3D = skeleton.get_bone_global_pose(_weapon_bone).affine_inverse() \
		* skeleton.get_bone_global_pose(_mag_bone)
	var p: Transform3D = Transform3D.IDENTITY
	var n: Node = _magwell.get_parent()
	while n != null and n != weapon_visual:
		if n is Node3D:
			p = (n as Node3D).transform * p
		n = n.get_parent()
	_magwell.transform = p.affine_inverse() * d * p * _magwell_rest


## Remove the slide-return keys of `ch` going to `v` (last round: the slide stays locked back).
func _drop_keys(ch: StringName, v: float) -> void:
	_keys.assign(_keys.filter(func(k: Dictionary) -> bool: return not (StringName(k["ch"]) == ch and float(k["v"]) == v)))


# --- Queries ----------------------------------------------------------------------------------

## Clip of `set_id` after the fallback chain (&"" when none exists).
func _resolve(set_id: StringName, c: StringName) -> StringName:
	if player == null or set_id == &"":
		return &""
	if not player.has_animation_library(set_id):
		_build_library(set_id)
	var cur: StringName = c
	for _i: int in 3:
		if player.has_animation("%s/%s" % [set_id, cur]):
			return cur
		if not FALLBACK_CLIPS.has(cur):
			return &""
		cur = FALLBACK_CLIPS[cur]
	return &""


func _length(set_id: StringName, c: StringName) -> float:
	var full: String = "%s/%s" % [set_id, c]
	return player.get_animation(full).length if player.has_animation(full) else 0.0


## Seconds from the start of `set_id`/`c` to `event` (-1 when unknown).
func _event(set_id: StringName, c: StringName, event: StringName) -> float:
	return FpViewmodelTweak.data().event_s(StringName("%s_%s" % [set_id, c]), event)


func _build_library(set_id: StringName) -> void:
	if not player.has_animation_library(&""):
		return
	var src: AnimationLibrary = player.get_animation_library(&"")
	var prefix: String = "%s_" % set_id
	var lib: AnimationLibrary = AnimationLibrary.new()
	for a: StringName in src.get_animation_list():
		if String(a).begins_with(prefix):
			lib.add_animation(StringName(String(a).substr(prefix.length())), src.get_animation(a))
	if not lib.get_animation_list().is_empty():
		player.add_animation_library(set_id, lib)


func _aim_wanted() -> bool:
	return _crew != null and CrewView.is_aiming(_crew)


func _speed() -> float:
	return Vector2(_crew.velocity.x, _crew.velocity.z).length() if _crew != null else 0.0


func _sprinting(tw: FpViewmodelTweak) -> bool:
	return _crew != null and _crew.sprinting and _speed() > tw.move_threshold_mps


func _shot_interval() -> float:
	if _crew == null or _crew.weapons == null:
		return 1.0
	var ws: int = _crew.weapons.equipped_slot
	var st: WeaponStats = _crew.weapons.stats(ws)
	if st == null:
		return 1.0
	return 60.0 / maxf(st.fire_rate_rpm * maxf(fire_rate_mult(_crew.slot, _crew.weapons.weapon_id(ws)), 0.01), 1.0)


## A4-04 weapon.fire_rate_mult (higher = faster), qualified by the weapon class like CrewWeapons; 1.0 when no
## source sets it (Modifiers.mult default), so this matches the gameplay cadence before and after A's merge.
static func fire_rate_mult(slot: int, weapon_id: StringName) -> float:
	var def: WeaponDef = ContentDB.weapon(weapon_id) if weapon_id != &"" else null
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class) if def != null else &""
	return Modifiers.mult(slot, &"weapon.fire_rate_mult", q)


func _last_round() -> bool:
	# `fired` is emitted before the round is taken from the magazine.
	return _crew != null and _crew.weapons != null and _crew.weapons.mag(_crew.weapons.equipped_slot) <= 1


func _no_shadows(n: Node) -> void:
	if FpViewmodelTweak.data().cast_shadows:
		return
	for g: Node in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _first(root: Node, cls: String) -> Node:
	var found: Array[Node] = root.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


static func _free_node(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()
