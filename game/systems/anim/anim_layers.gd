## AnimDriver's upper-body layers and third-person left-hand IK (characters.md v1.19 / v1.25, D-116, lead rulings
## (b) and (c)). Owner: ENV A. Presentation only. The layer nodes stay on the driver (hold_layer, flinch_layer,
## left_hand_ik); this RefCounted helper (back-reference `_d`, like CombatClips) updates them every tick.
class_name AnimLayers
extends RefCounted

var _d: AnimDriver = null
## Lead ruling (b): seconds left of the upper-body flinch.
var _flinch_left: float = 0.0


func _init(driver: AnimDriver) -> void:
	_d = driver


## v1.19: the upper-body layer over walk / run / strafe* (weight 1, AnimTweak.hold_layer_blend_s): hold_<kind> while
## the crew body holds a weapon; while aiming, aim_* keeps priority (the layer carries aim_<kind>, never hold_*).
## Off for every other clip (idle uses idle_alert_<kind>, poses, deaths, one-shots).
func update_hold(delta: float, tw: AnimTweak) -> void:
	var hold_layer: UpperBodyLayer = _d.hold_layer
	if hold_layer == null or not is_instance_valid(hold_layer):
		return
	var player: AnimationPlayer = _d.player
	var clip: StringName = _d.clip
	var want: StringName = &""
	var plain: StringName = &""
	var aim_move: StringName = &""  # D-116: aim_<fam>_<gait>, phase-locked to the base gait
	var moving_reload: bool = _d._oneshot_left > 0.0 and String(_d._oneshot).begins_with("reload_")
	if AnimDriver._layered_locomotion(clip):
		if moving_reload:
			want = _d._oneshot  # D-116: a reload while moving rides the layer at its own time
		elif _d._aiming():
			aim_move = _d.combat.aim_move_clip(clip)
			want = aim_move if aim_move != &"" else _d.aim_clip()
			if (_d._crew != null and _d._held_weapon_clip(&"hold_") == &"") or (_d._crew == null and aim_move == &"") \
					or not player.has_animation("%s/%s" % [AnimDriver.LIBRARY, want]):
				want = &""
		elif _d._crew != null:
			plain = _d._held_weapon_clip(&"hold_")
			want = HoldGait.clip_for(plain, clip, player, AnimDriver.LIBRARY)  # v1.25: hold_<kind>_<gait> when D has it
		else:
			plain = npc_hold_clip()
			want = HoldGait.clip_for(plain, clip, player, AnimDriver.LIBRARY)  # v1.26 (a): NPCs get the crew's layer
			if want == &"hold_rifle_run" and _d._npc != null and _d._npc.role == &"police" \
					and player.has_animation("%s/hold_rifle_port_run" % AnimDriver.LIBRARY):
				want = &"hold_rifle_port_run"  # v1.39 (D d2a2e3fd): TAC police run at port arms; the crew keep hold_rifle_run
	var gait_locked: bool = want != &"" and want != plain and not moving_reload
	if want != &"" and want != hold_layer.clip:
		var a: Animation = player.get_animation("%s/%s" % [AnimDriver.LIBRARY, want])
		var start: float = 0.0 if gait_locked else _d._loop_offset(&"weapon_hold") * a.length
		hold_layer.set_clip(want, a, start if String(want).begins_with("hold_") else 0.0)
	hold_layer.advance(delta)
	if want == _d._oneshot and moving_reload:
		hold_layer.time = (_d._oneshot_dur - _d._oneshot_left) * _d._oneshot_speed
	elif gait_locked and player.is_playing():  # v1.25: frame-locked to the base gait, every tick
		hold_layer.time = CombatClips.gait_time(player, want, aim_move != &"")
	var target: float = 1.0 if want != &"" else 0.0
	hold_layer.influence = move_toward(hold_layer.influence, target, delta / maxf(tw.hold_layer_blend_s, 0.001))
	hold_layer.active = hold_layer.influence > 0.0


## characters.md v1.26 (a): an alert, armed NPC (police, guards, escorts) on the move holds its weapon like the crew:
## `hold_<kind>` (HoldGait picks hold_<kind>_<gait> when D has it), &"" when calm, unarmed or the rig has no hold clip.
func npc_hold_clip() -> StringName:
	var npc: NpcBase = _d._npc
	if npc == null or _d.weapon_visual == null or not AnimDriver.ALERT_STATES.has(npc.alert_state):
		return &""
	var c: StringName = StringName("hold_" + String(_d.weapon_kind))
	return c if _d._has_clip(c) else &""


## Lead ruling (c) / characters.md v1.19: the left hand goes onto the held weapon's LeftHandIK (HandL/Socket on the
## marker) while a rifle-family weapon shows and the clip holds it with both hands (idle_alert_<kind>, aim_rifle,
## fire_rifle, or the hold_* / aim_rifle upper-body layer over locomotion); blends out for anything else (reloads,
## armed interactions, the bag carry, poses, pistols and akimbo).
func update_left_hand_ik(delta: float, tw: AnimTweak) -> void:
	var left_hand_ik: ThirdPersonLeftHandIK = _d.left_hand_ik
	if left_hand_ik == null or not is_instance_valid(left_hand_ik):
		return
	var clip: StringName = _d.clip
	var hold_layer: UpperBodyLayer = _d.hold_layer
	var wv: WeaponVisual = _d.weapon_visual as WeaponVisual
	var marker: Node3D = wv.get_marker(&"LeftHandIK") if wv != null and is_instance_valid(wv) else null
	var two_hands: bool = String(clip).begins_with("idle_alert_") or clip == &"aim_rifle" or clip == &"fire_rifle" \
		or (hold_layer != null and hold_layer.active and AnimDriver._layered_locomotion(clip) \
			and not String(hold_layer.clip).begins_with("reload_"))
	two_hands = two_hands and (_d.crew_action == null or _d.crew_action.action == &"")  # v1.23: not during an action
	var want: bool = marker != null and _d.aim_family() == &"rifle" and _d.weapon_visual.visible and two_hands \
		and not (_d.flinch_layer != null and _d.flinch_layer.active)
	var rig: Node3D = _d.rig
	# LEAD (D's OF Cataclysm anim coverage, 21k errors): the kept marker is freed when the WeaponVisual is replaced
	# (drop / swap); fade out on no marker instead.
	var kept: Variant = left_hand_ik.get(&"marker")
	var keep: Node3D = kept as Node3D if is_instance_valid(kept) else null
	left_hand_ik.set_target(marker if want else keep,
		rig.get_node_or_null(^"Skeleton3D/HandR/Socket") as Node3D, rig.get_node_or_null(^"Skeleton3D/HandL/Socket") as Node3D)
	left_hand_ik.influence = move_toward(left_hand_ik.influence, 1.0 if want else 0.0, delta * tw.left_hand_ik_rate)
	left_hand_ik.active = left_hand_ik.influence > 0.0 and is_instance_valid(left_hand_ik.get(&"marker"))


## Lead ruling (b) / SOURCE hit_zones: a hit-zone flinch on a moving body plays on the upper body only (spine and up,
## UpperBodyLayer `FlinchLayer` over whatever the legs do) at AnimTweak.hit_zone_layer_weight (head: _head_weight),
## fading in / out over hit_zone_blend_in_s / _out_s. False when the rig has no layer / clip (then full body).
func play_flinch(c: StringName) -> bool:
	var flinch_layer: UpperBodyLayer = _d.flinch_layer
	if flinch_layer == null or not is_instance_valid(flinch_layer) or not _d._has_clip(c):
		return false
	flinch_layer.set_clip(&"", null)
	flinch_layer.set_clip(c, _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, c]), 0.0)
	_flinch_left = _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, c]).length
	return true


func update_flinch(delta: float, tw: AnimTweak) -> void:
	var flinch_layer: UpperBodyLayer = _d.flinch_layer
	if flinch_layer == null or not is_instance_valid(flinch_layer):
		return
	var dead: bool = _d._npc != null and not _d._npc.alive
	if _flinch_left <= 0.0 or dead:
		_flinch_left = 0.0
		flinch_layer.influence = move_toward(flinch_layer.influence, 0.0, delta / maxf(tw.hit_zone_blend_out_s, 0.001))
	else:
		flinch_layer.advance(delta)
		_flinch_left = maxf(_flinch_left - delta, 0.0)
		var peak: float = tw.hit_zone_layer_head_weight if flinch_layer.clip == AnimDriver.HIT_HEAD \
			else tw.hit_zone_layer_weight
		var target: float = peak if _flinch_left > tw.hit_zone_blend_out_s \
			else peak * _flinch_left / maxf(tw.hit_zone_blend_out_s, 0.001)
		flinch_layer.influence = move_toward(flinch_layer.influence, target, delta * peak / maxf(tw.hit_zone_blend_in_s, 0.001))
	flinch_layer.active = flinch_layer.influence > 0.0
