## D-116 police combat movement (ENV D SOURCE `police_combat` + `locomotion_holds`, characters.md v1.26) for AnimDriver:
## NPC police / specials / cartel and third-person crew. Owner: ENV A. Presentation only (reads state, never writes it).
## Every clip here is optional: a rig / library without it plays exactly what it played before (the trunk rig).
## - aim on the move: while aiming AND moving, aim_<fam>_<gait> (fam = rifle | pistol | akimbo by aim family; gait:
##   walk / walk_* / walk_back / strafe_* -> walk, run / run_* -> run, crouch_walk -> crouch) is the upper-body layer
##   (UpperBodyLayer, the weapon_holds bone filter, weight 1) over the locomotion clip, its time locked to the base
##   clip's position every tick (phase-locked when the lengths differ: the 18 f strafes). Starts / stops and sprint
##   keep the plain aim_* (they have no aim gait).
## - class reloads by WeaponDef.weapon_class: SMG / SPECIAL -> reload_smg, SHOTGUN -> reload_shotgun, LMG -> reload_lmg,
##   SNIPER -> reload_sniper (ASSAULT_RIFLE keeps reload_rifle, pistols theirs); AnimTweak.reload_done keys smg /
##   shotgun / lmg / sniper put `done` on reload completion. Moving: the reload's upper body is the layer.
## - cover: a brain's claimed cover post (PoliceBrain / CartelBrain `cover_point`, host only), standing on it and aiming:
##   cover_low_<fam> behind low cover, cover_peek_l_<fam> / cover_peek_r_<fam> at a corner (fam = rifle | pistol).
##   TacticalPoint carries no low / side data (its tags are descriptive: counter, jamb, crates...), so the post is
##   classified by short LOS rays from the body (classify_cover; CombatTweak.los_mask, shields ignored): blocked at
##   the low probe height in front but clear at the high one = low cover; else a wall close on one side at the high
##   height (side or front-diagonal ray) with the other side clear = a corner, leaning out to the CLEAR side; else
##   none (plain aim). Re-probed every AnimTweak.cover_probe_interval_s while on the post.
## - stagger_<fam> (fam = rifle | pistol): a stagger-strength hit: the Bulwark's L4.5 stagger (HeavySpecialTweak; brain
##   is_staggered() with the hit_react hint) and an explosion that hurts a non-shield NPC (not stun-immune, no
##   AegisCaptain no_flinch). Without the clip the existing flinches play.
## - DB-4: `sit` on a seat post plays sit_chair_armed for cartel gunmen (role CartelBrain.ROLE) and for an armed
##   guard (a modelled weapon); everyone else, or a rig without it, keeps sit_chair.
class_name CombatClips
extends RefCounted

## WeaponDef.weapon_class -> class reload clip (the AnimTweak.reload_done key is the name after `reload_`).
const RELOAD_BY_CLASS: Dictionary = {
	Enums.WeaponClass.SMG: &"reload_smg", Enums.WeaponClass.SPECIAL: &"reload_smg",
	Enums.WeaponClass.SHOTGUN: &"reload_shotgun", Enums.WeaponClass.LMG: &"reload_lmg",
	Enums.WeaponClass.SNIPER: &"reload_sniper",
}
const START_STOP: Array[StringName] = [&"walk_start", &"walk_stop", &"run_start", &"run_stop"]
## classify_cover results.
const COVER_NONE: StringName = &""
const COVER_LOW: StringName = &"low"
const COVER_PEEK_L: StringName = &"peek_l"
const COVER_PEEK_R: StringName = &"peek_r"

var _d: AnimDriver = null
## Cover classification cache: the post it is for, the result, the next probe time (engine ms).
var _cover_post: Node3D = null
var _cover_kind: StringName = COVER_NONE
var _cover_next_ms: int = 0


func _init(driver: AnimDriver) -> void:
	_d = driver


## Aim gait of base locomotion clip `c`: &"walk" / &"run" / &"crouch", or &"" (no aim gait: plain aim_*).
static func aim_gait_of(c: StringName) -> StringName:
	var s: String = String(c)
	if START_STOP.has(c) or s == "walk_text":
		return &""
	if s == "crouch_walk":
		return &"crouch"
	if s == "run" or s.begins_with("run_"):
		return &"run"
	if s == "walk" or s.begins_with("walk_") or s.begins_with("strafe_"):
		return &"walk"
	return &""


## Layer time for a frame-locked layer of length `layer_len` over a base clip at `base_pos` of `base_len`: the base
## position itself when the lengths match (the v1.25 hold rule), else the same phase.
static func locked_time(base_pos: float, base_len: float, layer_len: float) -> float:
	if base_len <= 0.0 or layer_len <= 0.0 or absf(base_len - layer_len) < 0.001:
		return base_pos
	return fposmod(base_pos / base_len, 1.0) * layer_len


## The frame-locked time of layer clip `want` over `player`'s base clip: its position (v1.25), or with `phase` the same
## phase when the lengths differ (aim_<fam>_<gait> over an 18 f strafe).
static func gait_time(player: AnimationPlayer, want: StringName, phase: bool) -> float:
	var pos: float = player.current_animation_position
	if not phase:
		return pos
	var base: Animation = player.get_animation(player.current_animation)
	var layer: Animation = player.get_animation("%s/%s" % [AnimDriver.LIBRARY, want])
	return locked_time(pos, base.length if base != null else 0.0, layer.length if layer != null else 0.0)


## The aim family for the moving / cover / stagger names: akimbo (moving aim only, `with_akimbo`), pistol or rifle.
func fam(with_akimbo: bool) -> String:
	if with_akimbo and _d.weapon_kind == &"akimbo":
		return "akimbo"
	return String(_d.aim_family())


## aim_<fam>_<gait> over base locomotion clip `base`, or &"" (no gait, or the rig lacks it: today's aim_* layer).
func aim_move_clip(base: StringName) -> StringName:
	var g: StringName = aim_gait_of(base)
	if g == &"":
		return &""
	var c: StringName = StringName("aim_%s_%s" % [fam(true), g])
	return c if _d._has_clip(c) else &""


## The reload to play for `base` (reload_rifle / reload_pistol): reload_rifle becomes the held weapon's class reload
## (AnimDriver.weapon_class) when the rig has it; otherwise `base` (today's clip).
func reload_clip(base: StringName) -> StringName:
	var c: StringName = RELOAD_BY_CLASS.get(_d.weapon_class, &"")
	return c if base == &"reload_rifle" and c != &"" and _d._has_clip(c) else base


## The one-shot for brain hint `hint`: stagger_<fam> for hit_react while the brain's L4.5 stagger runs (rig has it),
## else `hint`.
func hint_oneshot(hint: StringName) -> StringName:
	var c: StringName = stagger_clip() if hint == &"hit_react" and brain_staggered(_d.get_parent()) else &""
	return c if c != &"" else hint


## stagger_<fam> when the rig has it, else &"".
func stagger_clip() -> StringName:
	var c: StringName = StringName("stagger_" + fam(false))
	return c if _d._has_clip(c) else &""


## True when `info` is an explosion that staggers this NPC: a non-shield unit (no carried shield), not stun-immune
## (Wrecker), no no_flinch (Aegis).
func explosion_staggers(npc: NpcBase, info: Dictionary) -> bool:
	if npc == null or int(info.get("type", -1)) != Enums.DamageType.EXPLOSION:
		return false
	if _d.carried_shield() != null or npc.has_meta(AegisCaptain.META_NO_FLINCH):
		return false
	var p: Dictionary = npc.enemy_def.params if npc.enemy_def != null else {}
	return not bool(p.get("stun_immune", false)) and not bool(p.get("no_flinch", false))


## The brain's L4.5 stagger is running (BulwarkBrain.is_staggered()).
static func brain_staggered(body: Node) -> bool:
	var b: Node = body.get_node_or_null(^"Brain") if body != null else null
	return b != null and b.has_method(&"is_staggered") and bool(b.call(&"is_staggered"))


## D-116 door breach: while this NPC breaches its motor's waiting_door (Door.breach_elapsed_s), door_kick_<fam> plays
## as a one-shot at speed impact / npc_door_breach_s from the breach's own elapsed time, so `impact` lands on the door
## opening (re-asserted every tick: a turn one-shot cannot cut it). A raised shield plays shield_bang ending on the
## open instead; a rig without the clip stands as before. Host only (the breach timer is host data).
func update_door_kick(npc: NpcBase) -> void:
	var motor: NpcMotor = npc.get_node_or_null(^"Motor") as NpcMotor if npc != null and npc.alive else null
	var door: Door = motor.waiting_door if motor != null else null
	var el: float = door.breach_elapsed_s(npc) if door != null and is_instance_valid(door) else -1.0
	if el < 0.0:
		return
	var breach_s: float = maxf(Tweak.interaction().npc_door_breach_s, 0.05)
	var c: StringName = StringName("door_kick_" + fam(false))
	var shield: bool = _d.shield_up() and _d._has_clip(&"shield_bang")
	if shield:
		c = &"shield_bang"
	elif not _d._has_clip(c):
		return
	var length: float = _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, c]).length
	var s: float = AnimTweak.clip_event_s(c, &"impact", AnimTweak.data().door_kick_impact_s) / breach_s
	var pos: float = el * s
	if shield:  # the bang ends on the open
		s = 1.0
		pos = el - (breach_s - length)
	if pos < 0.0 or pos >= length:
		return
	if _d._oneshot != c or _d._oneshot_left <= 0.0:
		_d.play_oneshot(c, (length - pos) / s, false, s, pos)
	elif _d.clip == c and absf(_d.player.current_animation_position - pos) > 0.05 \
			and String(_d.player.current_animation).ends_with(String(c)):
		_d.player.seek(pos, true)  # shown late (the unit stepped to its stand first): back on the breach's time


## DB-4: `sit` -> sit_chair_armed for a cartel gunman or an armed guard when the rig has it; else &"".
func armed_seat_clip(npc: NpcBase) -> StringName:
	if npc == null or not _d._has_clip(&"sit_chair_armed"):
		return &""
	# The clip lays a long gun across the lap: a pistol guard keeps sit_chair.
	var armed: bool = npc.role == CartelBrain.ROLE \
		or (npc.role == &"guard" and _d.weapon_visual != null and fam(false) == "rifle")
	return &"sit_chair_armed" if armed else &""


## The cover loop for this NPC this frame (host: on its brain's claimed cover post, standing), or &"".
func cover_clip(npc: NpcBase) -> StringName:
	var post: Node3D = cover_post(npc)
	if post == null:
		_cover_post = null
		return &""
	var now: int = Time.get_ticks_msec()
	if post != _cover_post or now >= _cover_next_ms:
		_cover_post = post
		_cover_next_ms = now + int(AnimTweak.data().cover_probe_interval_s * 1000.0)
		_cover_kind = probe_cover(npc)
	if _cover_kind == COVER_NONE:
		return &""
	var c: StringName = StringName("cover_%s_%s" % [String(_cover_kind), fam(false)])
	return c if _d._has_clip(c) else &""


## The brain's claimed cover post when the NPC stands on it (host only; clients have no brain data), else null.
func cover_post(npc: NpcBase) -> Node3D:
	if npc == null or not npc.alive or not Net.is_authority() or not npc.is_inside_tree():
		return null
	var b: Node = npc.get_node_or_null(^"Brain")
	var v: Variant = b.get(&"cover_point") if b != null else null
	var p: Node3D = v as Node3D if is_instance_valid(v) else null
	if p == null or not p.is_inside_tree():
		return null
	var off: Vector3 = p.global_position - npc.global_position
	return p if Vector2(off.x, off.z).length() <= AnimTweak.data().cover_post_m else null


## Classify the NPC's cover by LOS rays from where it stands, facing its target (the brain faces it on the post).
func probe_cover(npc: NpcBase) -> StringName:
	var tw: AnimTweak = AnimTweak.data()
	var ms: float = _d._motion_scale()
	var xf: Transform3D = npc.global_transform
	var fwd: Vector3 = Vector3(-xf.basis.z.x, 0.0, -xf.basis.z.z).normalized()
	var right: Vector3 = Vector3(xf.basis.x.x, 0.0, xf.basis.x.z).normalized()
	var base: Vector3 = npc.global_position
	var lo: Vector3 = base + Vector3.UP * tw.cover_probe_low_m * ms
	var hi: Vector3 = base + Vector3.UP * tw.cover_probe_high_m * ms
	var ray: Callable = func(from: Vector3, to: Vector3) -> bool:
		return not CombatSystem.has_npc_los(npc, from, to, [npc])
	var front_m: float = tw.cover_probe_front_m
	var side_m: float = tw.cover_probe_side_m
	return classify_cover(
		ray.call(lo, lo + fwd * front_m), ray.call(hi, hi + fwd * front_m),
		ray.call(hi, hi - right * side_m) or ray.call(hi, hi + (fwd - right).normalized() * side_m),
		ray.call(hi, hi + right * side_m) or ray.call(hi, hi + (fwd + right).normalized() * side_m))


## Cover kind from four probes (true = blocked): low in front, high in front, left side, right side. Low blocked with
## the high clear = low cover; otherwise a wall on exactly one side = a corner, lean out to the other side.
static func classify_cover(front_low: bool, front_high: bool, left: bool, right: bool) -> StringName:
	if front_low and not front_high:
		return COVER_LOW
	if left != right:
		return COVER_PEEK_R if left else COVER_PEEK_L
	return COVER_NONE
