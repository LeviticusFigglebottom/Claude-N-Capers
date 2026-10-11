## Bulwark brain (A3-01b, L4.5; PD2 Shield). Owner: ENV A. Server only. Child `Brain` of npc_bulwark.tscn.
## Extends the PoliceBrain pattern (loud-only, retarget, standoff, L2.12 cuffing, ECM stun) with:
## - Shield: HeavySpecialTweak.bulwark_shield_scene (BulwarkShield, `Shield` + `Collision`) carried in
##   front (bulwark_shield_offset). It blocks all but shield-piercing rounds (x0.25), fire and
##   explosions (which go around it). Flanks and the back are unprotected (weak to flanks). On death the
##   shield is dropped in place and keeps blocking.
## - Movement (PD2, lead ruling): walks while advancing at EnemyDef.params.advance_speed (1.8 m/s;
##   shield_walk), EnemyDef.move_speed only for director orders (PoliceSpecialKit.heavy_move_speed).
## - Shield visual / body follow the character visual's `HandL/Socket` when it has one (BulwarkShield).
## - Fixation: the first target picked is kept until it is in CUSTODY or gone (PD2 shields lock on).
## - Doorways: a free SHIELD_ANCHOR TacticalPoint near the target with LOS to it is claimed and held
##   (one Bulwark per point); otherwise a short standoff band (bulwark_standoff_*). No cover, no flank.
## - Bang: while holding with the target in sight, every bulwark_bang_interval_s it bangs the shield
##   (cue.bulwark_bang [R], anim_hint shield_bang) and holds fire for bulwark_bang_hold_s.
## - Formation: the NPC is in PoliceSpecialKit.BULWARK_GROUP while alive, so other specials can take
##   the spot behind it (PoliceSpecialKit.spot_behind_bulwark).
## - Stagger (shock-and-awe-like, HeavySpecialTweak "Bulwark stagger"): a single shield hit of at least
##   bulwark_stagger_hit_damage, or an explosion that damages it, staggers it for bulwark_stagger_s:
##   the guard drops (BulwarkShield.set_guard(false): lowered, no collision, so frontal hits reach the
##   body), it neither moves nor fires (anim_hint hit_react), then bulwark_stagger_cooldown_s before
##   the next. Aegis shields (AegisCaptain.META_NO_FLINCH) never stagger.
## - special_spawned(net_id, &"bulwark") [R] on start.
class_name BulwarkBrain
extends PoliceBrain

const ANCHOR_GROUP: StringName = &"shield_anchor"

@export var special_type: StringName = &"bulwark"
@export var special_tweak: HeavySpecialTweak

var shield: BulwarkShield = null
## Fixated crew member (L4.5).
var fixated: CrewController = null
var bangs: int = 0
## L4.5 stagger count (tests / debug).
var staggers: int = 0

var _bang_left: float = 0.0
var _bang_hold_left: float = 0.0
var _stagger_left: float = 0.0
var _stagger_cd: float = 0.0


func _ready() -> void:
	if special_tweak == null:
		special_tweak = HeavySpecialTweak.data()
	super._ready()
	if _npc == null:
		return
	if tweak != null:
		tweak = tweak.duplicate() as PoliceTweak
		tweak.standoff_min_m = special_tweak.bulwark_standoff_min_m
		tweak.standoff_pref_m = special_tweak.bulwark_standoff_pref_m
		tweak.standoff_max_m = special_tweak.bulwark_standoff_max_m
		tweak.flank_chance = 0.0
	_npc.add_to_group(PoliceSpecialKit.BULWARK_GROUP)
	_npc.damaged.connect(_on_damaged)
	_attach_shield.call_deferred()  # the NpcBase is still setting up its children


func _start() -> void:
	super._start()
	if _started:
		_bang_left = _roll(special_tweak.bulwark_bang_interval_s)
		PoliceSpecialKit.announce(_npc, special_type)


func _physics_process(delta: float) -> void:
	if _stagger_cd > 0.0:
		_stagger_cd -= delta
	if _stagger_left > 0.0:
		_stagger_left -= delta
		wants_to_fire = false
		anim_hint = &"hit_react"
		if _motor != null:
			_motor.stop()
		if _stagger_left <= 0.0:
			_raise_guard()
		return
	super._physics_process(delta)
	if not _active or _npc == null or not _npc.alive or _npc.is_stunned():
		return
	if _bang_hold_left > 0.0:
		_bang_hold_left -= delta
		wants_to_fire = false
		anim_hint = &"shield_bang"
		return
	if mode == &"hold" and _target_visible:
		_bang_left -= delta
		if _bang_left <= 0.0:
			bang()


## Bang the shield (cue.bulwark_bang [R]) and hold fire briefly.
func bang() -> void:
	bangs += 1
	_bang_left = _roll(special_tweak.bulwark_bang_interval_s)
	_bang_hold_left = special_tweak.bulwark_bang_hold_s
	wants_to_fire = false
	anim_hint = &"shield_bang"
	PoliceSpecialKit.cue(_npc, &"cue.bulwark_bang", shield.global_position if shield != null else Vector3.INF)


func is_staggered() -> bool:
	return _stagger_left > 0.0


## Server: stagger now (guard down for bulwark_stagger_s). False when dead, Aegis, without a carried
## shield, already staggered or cooling down.
func stagger() -> bool:
	if not Net.is_authority() or _npc == null or not _npc.alive or _npc.has_meta(AegisCaptain.META_NO_FLINCH):
		return false
	if shield == null or not is_instance_valid(shield) or shield.dropped or _stagger_left > 0.0 or _stagger_cd > 0.0:
		return false
	staggers += 1
	_stagger_left = maxf(special_tweak.bulwark_stagger_s, 0.01)
	_stagger_cd = _stagger_left + special_tweak.bulwark_stagger_cooldown_s
	_bang_hold_left = 0.0
	wants_to_fire = false
	anim_hint = &"hit_react"
	if _motor != null:
		_motor.stop()
	shield.set_guard(false, special_tweak.bulwark_stagger_shield_offset)
	return true


func _raise_guard() -> void:
	_stagger_left = 0.0
	if shield != null and is_instance_valid(shield) and not shield.dropped:
		shield.set_guard(true, special_tweak.bulwark_shield_offset)


func _on_shield_struck(info: Dictionary) -> void:
	if float(info.get("amount", 0.0)) >= special_tweak.bulwark_stagger_hit_damage:
		stagger()


func _on_damaged(info: Dictionary, _attacker: int) -> void:
	if special_tweak.bulwark_stagger_on_explosion and float(info.get("amount", 0.0)) > 0.0 \
			and int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.EXPLOSION:
		stagger()


func _attach_shield() -> void:
	var ps: PackedScene = special_tweak.bulwark_shield_scene
	if ps == null:
		Log.error(&"ai", "BulwarkBrain: HeavySpecialTweak.bulwark_shield_scene is not set")
		return
	shield = ps.instantiate() as BulwarkShield
	if shield == null:
		Log.error(&"ai", "BulwarkBrain: bulwark_shield_scene root is not a BulwarkShield")
		return
	shield.attach_to(_npc, special_tweak.bulwark_shield_offset)
	shield.struck.connect(_on_shield_struck)


# --- PoliceBrain overrides -------------------------------------------------------------------

## PD2: walks while advancing (EnemyDef.params.advance_speed), runs only to reposition / flank.
func _move_speed(move_mode: StringName) -> float:
	return PoliceSpecialKit.heavy_move_speed(_npc, move_mode, _run_speed())


func _pick_target() -> void:
	if fixated != null and is_instance_valid(fixated) and fixated.crew_state != Enums.CrewState.CUSTODY:
		combat_target = fixated
		_target_visible = _can_see(fixated)
		return
	fixated = null
	super._pick_target()
	fixated = combat_target as CrewController


## Doorway blocking: a free SHIELD_ANCHOR point (claimed like cover) instead of COVER points.
func _find_cover(t: Node3D) -> TacticalPoint:
	if _runtime == null or _runtime.map == null:
		return null
	var best: TacticalPoint = null
	var best_d: float = special_tweak.bulwark_anchor_search_m
	for n: Node in _runtime.map.get_slots(ANCHOR_GROUP):
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or _claimed_by_other(tp):
			continue
		var d_self: float = _flat(tp.global_position - _npc.global_position).length()
		if d_self >= best_d or not _cover_ok(tp, t):
			continue
		best = tp
		best_d = d_self
	return best


func _cover_ok(tp: TacticalPoint, t: Node3D) -> bool:
	if not is_instance_valid(tp) or t == null:
		return false
	if _flat(t.global_position - tp.global_position).length() > special_tweak.bulwark_anchor_max_from_target_m:
		return false
	var to_t: Vector3 = _flat(t.global_position - _npc.global_position)
	var to_a: Vector3 = _flat(tp.global_position - _npc.global_position)
	if to_a.length() > 0.5 and (to_a.dot(to_t) <= 0.0 or to_a.length() >= to_t.length()):
		return false  # PD2: advance to cover between itself and the crew, never past / behind the target
	var c: CrewController = t as CrewController
	var to: Vector3 = c.eye_position() if c != null else t.global_position + Vector3.UP * 1.5
	return CombatSystem.has_npc_los(_npc, tp.global_position + Vector3(0.0, _npc.head_height, 0.0), to, [_npc, t])


func _on_died(info: Dictionary, killer_net_id: int) -> void:
	super._on_died(info, killer_net_id)
	_npc.remove_from_group(PoliceSpecialKit.BULWARK_GROUP)
	if shield != null and is_instance_valid(shield):
		if shield.guard_down:
			_raise_guard()  # a dropped shield still blocks
		var parent: Node = _runtime.dynamic_root if _runtime != null else _npc.get_parent()
		shield.drop.call_deferred(parent)  # not inside the hit/physics callback that killed us
