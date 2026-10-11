## Third-person animation driver for NPCs and crew bodies (characters.md v1.3, D-041). Owner: ENV A.
## Child `AnimDriver` of an NpcBase or a CrewController. Finds the character visual's AnimationPlayer at the
## contract path (`Visual/<Root>/AnimationPlayer` with library "humanoid"); with no such player (capsule
## placeholder) it does nothing. **Presentation only**: it reads gameplay state and never writes it; no
## gameplay code may read animation state. Headless-safe.
## Each frame it picks one clip, by priority:
##   death_front/back (from the last hit direction vs facing) > crew state (downed, tased, kneel_cuffed) /
##   stun (tased) > pose hints (tied, cower, hands_up, surrender, lie_down, kneel_cuffed) > special actions
##   (kick_charge, shield_bang, heal_ally) > one-shots (turn, fire, reload, throw_bag, melee, kick_hit,
##   hit_react) > interact_* / pager_answer > locomotion by velocity (walk, run, sprint, crouch_walk, strafe,
##   walk_back, flee, carry_bag_walk, the unit's EnemyDef.params.anim_walk_clip = shield_walk / dozer_walk at
##   walking speed; speed_scale = v / clip speed) > aim_* >
##   the brain's `anim_hint` idles (phone_call, smoke, radio_call, investigate_look...) > idle / idle_alert /
##   crouch_idle. Clips crossfade (AnimTweak.blend_s).
## Turn in place: a standing body whose yaw moved more than AnimTweak.turn_threshold_deg plays turn_l/r while
## the rig root yaws toward the body at 90 deg / 0.8 s (the rig is counter-rotated; the body itself is untouched).
## Third-person weapon: WeaponVisual (ENV B, by class name) of WeaponDef.model at `HandR/Socket` (crew: the
## equipped weapon, NPC: EnemyDef.weapon when it has a WeaponDef with a model; otherwise none).
## Clients: velocity comes from position deltas and alert state / crew state are replicated; brain hints and
## interaction heights are host data (clients fall back to alert-state poses).
class_name AnimDriver
extends Node

const NODE_NAME: String = "AnimDriver"
const LIBRARY: String = "humanoid"
const WEAPON_NODE: String = "ThirdPersonWeapon"
## Brain anim_hint -> clip (characters.md names). Locomotion hints (walk/run/walk_back) are ignored:
## velocity decides. &"aim" resolves to aim_pistol / aim_rifle by weapon class.
const HINT_CLIPS: Dictionary = {
	&"idle": &"idle", &"idle_alert": &"idle_alert", &"investigate_look": &"investigate_look",
	&"radio_call": &"radio_call", &"pager_answer": &"pager_answer", &"phone_call": &"phone_call",
	&"smoke": &"smoke", &"cower": &"cower", &"hands_up": &"hands_up", &"tied": &"tied",
	&"kneel_cuffed": &"kneel_cuffed", &"lie_down": &"lie_down", &"surrender": &"surrender",
	&"browse": &"browse", &"desk_type": &"desk_type", &"sit_chair": &"sit_chair", &"lean_wall": &"lean_wall",
	&"melee": &"melee", &"flee": &"flee", &"aim_pistol": &"aim_pistol", &"aim_rifle": &"aim_rifle",
	&"tased": &"tased", &"downed": &"downed", &"hit_react": &"hit_react",
	# Specials (characters.md v1.4): Phantom windup / kick, Bulwark bang, Corpsman heal.
	&"kick_charge": &"kick_charge", &"kick_hit": &"kick_hit", &"shield_bang": &"shield_bang",
	&"heal_ally": &"heal_ally",
	# Brain / patrol-point aliases.
	&"phone": &"phone_call", &"call": &"phone_call", &"desk_work": &"desk_type", &"sit": &"sit_chair",
	&"queue": &"idle", &"lean": &"lean_wall", &"check_door": &"investigate_look", &"down": &"lie_down",
	&"cuff": &"interact_low",
}
## Clips that win over locomotion (the body holds a pose).
const POSE_CLIPS: Array[StringName] = [
	&"tied", &"kneel_cuffed", &"lie_down", &"cower", &"hands_up", &"surrender", &"downed", &"tased",
]
## Special actions held while the hint lasts: they win over one-shots, locomotion and aim (the brain
## stands the body still for them).
const ACTION_CLIPS: Array[StringName] = [&"kick_charge", &"shield_bang", &"heal_ally"]
## Hints played once when the hint changes to them.
const ONESHOT_HINTS: Array[StringName] = [&"melee", &"kick_hit", &"hit_react"]
## One-shot hints that are not held as an idle once played (the hint may linger in the brain).
const ONCE_ONLY_HINTS: Array[StringName] = [&"kick_hit", &"hit_react"]
## Clip -> substitute when the library lacks it (then idle).
const FALLBACK_CLIPS: Dictionary = {
	&"aim_pistol": &"idle_alert", &"aim_rifle": &"idle_alert", &"interact_low": &"interact_mid",
	&"interact_high": &"interact_mid", &"flee": &"run", &"carry_bag_walk": &"walk", &"crouch_walk": &"walk",
	&"crouch_idle": &"idle", &"strafe_l": &"walk", &"strafe_r": &"walk", &"walk_back": &"walk",
	&"sprint": &"run", &"pager_answer": &"phone_call", &"idle_alert": &"idle",
	&"shield_walk": &"walk", &"dozer_walk": &"walk", &"kick_charge": &"idle_alert", &"kick_hit": &"melee",
	&"shield_bang": &"idle_alert", &"heal_ally": &"interact_mid",
}
## EnemyDef.params key: the unit's own walk clip (Bulwark shield_walk, Wrecker dozer_walk), played instead
## of walk while moving at walking speed (above it: run / sprint).
const WALK_CLIP_PARAM: String = "anim_walk_clip"
const CREW_STATE_CLIPS: Dictionary = {
	Enums.CrewState.DOWNED: &"downed", Enums.CrewState.CLOAKER_DOWNED: &"downed",
	Enums.CrewState.TASED: &"tased", Enums.CrewState.CUFFED: &"kneel_cuffed",
}
const ALERT_STATES: Array[int] = [
	Enums.AlertState.CURIOUS, Enums.AlertState.INVESTIGATING, Enums.AlertState.ALARMED, Enums.AlertState.COMBAT,
]

static var _weapon_defs: Dictionary = {}

## The AnimationPlayer driven (null = inactive, e.g. capsule placeholder).
var player: AnimationPlayer = null
## The character visual root (the AnimationPlayer's parent).
var rig: Node3D = null
## Clip currently requested (without the library prefix), &"" before the first frame.
var clip: StringName = &""
## &"pistol" or &"rifle": aim/fire/reload clip family.
var weapon_kind: StringName = &"pistol"
## Third-person WeaponVisual at HandR/Socket (null when there is no model).
var weapon_visual: Node3D = null

var _body: Node3D = null
var _npc: NpcBase = null
var _crew: CrewController = null
var _rig_base_yaw: float = 0.0
var _visual_yaw: float = 0.0
var _prev_body_yaw: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _vel: Vector3 = Vector3.ZERO
var _oneshot: StringName = &""
var _oneshot_left: float = 0.0
var _oneshot_speed: float = 1.0
var _oneshot_while_moving: bool = false
var _restart: bool = false
var _turning_left: float = 0.0
var _aim_hold_left: float = 0.0
var _hit_dir: Vector3 = Vector3.ZERO
var _death_clip: StringName = &""
var _last_hint: StringName = &""
var _interact_kind: StringName = &""
var _interact_height: float = 1.0


## The driver of `body` (null when it has none).
static func of(body: Node) -> AnimDriver:
	return body.get_node_or_null(NODE_NAME) as AnimDriver if body != null else null


## True when `body` has an active driver (an animated character visual): NpcBase skips the capsule tip-over.
static func drives(body: Node) -> bool:
	var d: AnimDriver = of(body)
	return d != null and d.player != null


## Contract AnimationPlayer of `body`'s visual: `Visual/<Root>/AnimationPlayer` with library "humanoid".
static func find_player(body: Node) -> AnimationPlayer:
	var visual: Node = body.get_node_or_null(^"Visual") if body != null else null
	if visual == null:
		return null
	for c: Node in visual.get_children():
		if c.is_queued_for_deletion():
			continue
		var ap: AnimationPlayer = c.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if ap != null and ap.has_animation_library(LIBRARY):
			return ap
	return null


## `<Marker>/Socket` (characters.md v1.2: HandR, HandL, Head, Back, Hip) of `body`'s contract visual, or null
## (capsule placeholder / no skeleton).
static func socket_of(body: Node, marker: String) -> Node3D:
	var ap: AnimationPlayer = find_player(body)
	var root: Node = ap.get_parent() if ap != null else null
	return root.get_node_or_null(NodePath("Skeleton3D/%s/Socket" % marker)) as Node3D if root != null else null


## Add a driver to `body` when its visual has a contract AnimationPlayer (else none; returns the driver or null).
static func ensure(body: Node) -> AnimDriver:
	var d: AnimDriver = of(body)
	if d != null:
		d.bind()
		return d
	if find_player(body) == null:
		return null
	d = AnimDriver.new()
	d.name = NODE_NAME
	body.add_child(d)
	return d


func _ready() -> void:
	bind()
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_cancelled.connect(_on_interaction_ended)
	EventBus.interaction_completed.connect(_on_interaction_completed)


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.damage_applied, _on_damage_applied], [EventBus.weapon_fired, _on_weapon_fired],
		[EventBus.loot_dropped, _on_loot_dropped], [EventBus.interaction_started, _on_interaction_started],
		[EventBus.interaction_cancelled, _on_interaction_ended],
		[EventBus.interaction_completed, _on_interaction_completed],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


## (Re)find the visual's AnimationPlayer and the weapon; returns true when active.
func bind() -> bool:
	_body = get_parent() as Node3D
	_npc = _body as NpcBase
	_crew = _body as CrewController
	player = find_player(_body)
	rig = player.get_parent() as Node3D if player != null else null
	set_process(player != null)
	if player == null:
		return false
	_rig_base_yaw = rig.rotation.y if rig != null else 0.0
	_visual_yaw = _body.global_rotation.y if _body.is_inside_tree() else _body.rotation.y
	_prev_body_yaw = _visual_yaw
	_last_pos = Vector3.INF
	if _crew != null and _crew.weapons != null and not _crew.weapons.equipped_changed.is_connected(_on_equipped):
		_crew.weapons.equipped_changed.connect(_on_equipped)
		_crew.weapons.reload_started.connect(_on_reload_started)
	refresh_weapon()
	return true


func _process(delta: float) -> void:
	tick(delta)


## Advance one presentation frame (tests call it directly).
func tick(delta: float) -> void:
	if player == null or _body == null or not is_instance_valid(player):
		return
	delta = maxf(delta, 0.0001)
	var tw: AnimTweak = AnimTweak.data()
	_update_velocity(delta, tw)
	_oneshot_left = maxf(_oneshot_left - delta, 0.0)
	_aim_hold_left = maxf(_aim_hold_left - delta, 0.0)
	_turning_left = maxf(_turning_left - delta, 0.0)
	var hint: StringName = _hint()
	if hint != _last_hint:
		_last_hint = hint
		if ONESHOT_HINTS.has(hint):
			play_oneshot(hint, -1.0, true)
	_update_turn(delta, tw)
	var want: StringName = choose_clip()
	_apply(want, _speed_scale_for(want, tw), tw)
	if weapon_visual != null and is_instance_valid(weapon_visual):
		weapon_visual.visible = not POSE_CLIPS.has(want) and _death_clip == &""


## Play `p_clip` once for `duration` seconds (-1 = the clip's length / speed). `while_moving` lets it
## override locomotion (throw_bag, melee); otherwise it shows only while standing (fire, reload, turn).
func play_oneshot(p_clip: StringName, duration: float = -1.0, while_moving: bool = false, speed: float = 1.0) -> void:
	if player == null:
		return
	var full: String = _resolve(p_clip)
	if full == "":
		return
	if duration < 0.0:
		duration = player.get_animation(full).length / maxf(speed, 0.01)
	_oneshot = p_clip
	_oneshot_left = duration
	_oneshot_speed = speed
	_oneshot_while_moving = while_moving
	_restart = true


## The clip this frame's state asks for (pure selection; see the class doc for the priorities).
func choose_clip() -> StringName:
	if _npc != null and not _npc.alive:
		if _death_clip == &"":
			_death_clip = _pick_death_clip(AnimTweak.data())
		return _death_clip
	var state_clip: StringName = _state_clip()
	if state_clip != &"":
		return state_clip
	var hint_clip: StringName = HINT_CLIPS.get(_hint(), &"")
	if POSE_CLIPS.has(hint_clip) or ACTION_CLIPS.has(hint_clip):
		return hint_clip
	return _active_clip(hint_clip)


## Below the poses: one-shot > interaction > locomotion > aim > hint idle > idle.
func _active_clip(hint_clip: StringName) -> StringName:
	var tw: AnimTweak = AnimTweak.data()
	var speed: float = horizontal_speed()
	var moving: bool = speed > tw.move_threshold_mps
	var out: StringName = _idle_clip()
	if _oneshot_left > 0.0 and (not moving or _oneshot_while_moving):
		out = _oneshot
	elif _interact_kind != &"" and _crew != null:
		out = _interact_clip(tw)
	elif moving:
		out = _locomotion_clip(speed, tw)
	elif _aiming():
		out = &"aim_rifle" if weapon_kind == &"rifle" else &"aim_pistol"
	elif hint_clip != &"" and hint_clip != &"idle" and not ONCE_ONLY_HINTS.has(hint_clip):
		out = hint_clip
	return out


## Horizontal speed estimate (m/s) used for locomotion.
func horizontal_speed() -> float:
	return Vector2(_vel.x, _vel.z).length()


## Rebuild the third-person weapon at `HandR/Socket` (crew: equipped weapon; NPC: EnemyDef.weapon).
func refresh_weapon() -> void:
	if weapon_visual != null and is_instance_valid(weapon_visual):
		weapon_visual.get_parent().remove_child(weapon_visual)
		weapon_visual.queue_free()
	weapon_visual = null
	var def: WeaponDef = null
	var mod_ids: Array[StringName] = []
	if _crew != null and _crew.weapons != null:
		var ws: int = _crew.weapons.equipped_slot
		if _crew.weapons.has_weapon(ws):
			def = _weapon_def(_crew.weapons.weapon_id(ws))
		var l: Loadout = _crew.loadout
		if l != null:
			mod_ids = l.primary_mods if ws == Enums.WeaponSlot.PRIMARY else l.secondary_mods
	elif _npc != null and _npc.enemy_def != null:
		def = _weapon_def(_npc.enemy_def.weapon)
	weapon_kind = _kind_for(def)
	var socket: Node3D = rig.get_node_or_null(^"Skeleton3D/HandR/Socket") as Node3D if rig != null else null
	if def == null or def.model == null or socket == null:
		return
	var wv: WeaponVisual = WeaponVisual.new()
	wv.name = WEAPON_NODE
	socket.add_child(wv)
	wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
	weapon_visual = wv


# --- Selection helpers ---------------------------------------------------------------------

func _state_clip() -> StringName:
	if _crew != null:
		return CREW_STATE_CLIPS.get(_crew.crew_state, &"")
	if _npc == null:
		return &""
	if _npc.is_stunned():
		return &"tased"
	if Net.is_authority() and _hint() != &"":
		return &""  # the host's brain hint is authoritative; the fallbacks below are for clients
	var out: StringName = &""
	match _npc.alert_state:
		Enums.AlertState.TIED:
			out = &"tied"
		Enums.AlertState.SURRENDERED:
			out = &"surrender"
		Enums.AlertState.INTIMIDATED, Enums.AlertState.DOMINATED:
			out = &"lie_down" if _npc.role == &"civilian" else &"hands_up"
		Enums.AlertState.PANICKED:
			out = &"cower" if horizontal_speed() <= AnimTweak.data().move_threshold_mps else &""
	return out


func _locomotion_clip(speed: float, tw: AnimTweak) -> StringName:
	var special: StringName = _special_locomotion(speed, tw)
	if special != &"":
		return special
	var fwd: Vector3 = -_body.global_transform.basis.z
	var right: Vector3 = _body.global_transform.basis.x
	var dir: Vector3 = Vector3(_vel.x, 0.0, _vel.z) / maxf(speed, 0.0001)
	var out: StringName = &"sprint"
	var side: float = dir.dot(right)
	if speed <= tw.strafe_max_mps and dir.dot(fwd) < tw.walk_back_dot:
		out = &"walk_back"
	elif speed <= tw.strafe_max_mps and absf(side) > tw.strafe_side_dot:
		out = &"strafe_r" if side > 0.0 else &"strafe_l"
	elif speed <= tw.walk_run_split_mps:
		out = &"walk"
	elif speed <= tw.run_sprint_split_mps:
		out = &"run"
	return out


## Crouch / carry / sprint (crew), flee (panicked civilians) and the unit's own walk clip (EnemyDef
## params anim_walk_clip, only at walking speed); &"" = pick by speed and direction.
func _special_locomotion(speed: float, tw: AnimTweak) -> StringName:
	var out: StringName = &""
	if _crew != null:
		if _crew.crouched:
			out = &"crouch_walk"
		elif _crew.is_carrying_bag():
			out = &"carry_bag_walk"
		elif _crew.sprinting:
			out = &"sprint"
	elif _npc != null and _npc.role == &"civilian" and (
			_npc.alert_state == Enums.AlertState.PANICKED or _hint() == &"run" or _hint() == &"flee"):
		out = &"flee"
	elif _npc != null:
		out = _unit_walk_clip(speed, tw)
	return out


## The NPC's own walk clip at `speed`, or &"" (no such clip, or faster than a walk: never above
## AnimTweak.speed_scale_max nor walk_run_split_mps; then run / sprint play).
func _unit_walk_clip(speed: float, tw: AnimTweak) -> StringName:
	if _npc.enemy_def == null or not _npc.enemy_def.params.has(WALK_CLIP_PARAM):
		return &""
	var c: StringName = StringName(str(_npc.enemy_def.params[WALK_CLIP_PARAM]))
	var clip_speed: float = float(tw.clip_speeds.get(c, tw.clip_speeds.get(&"walk", 1.6))) * _motion_scale()
	if c == &"" or speed > minf(tw.walk_run_split_mps, clip_speed * tw.speed_scale_max):
		return &""
	return c


func _interact_clip(tw: AnimTweak) -> StringName:
	if _interact_kind == &"answer_pager":
		return &"pager_answer"
	if _interact_height < tw.interact_low_max_m:
		return &"interact_low"
	return &"interact_high" if _interact_height > tw.interact_high_min_m else &"interact_mid"


func _idle_clip() -> StringName:
	if _crew != null:
		if _crew.crouched:
			return &"crouch_idle"
		return &"idle_alert" if _crew.masked else &"idle"
	if _npc != null and ALERT_STATES.has(_npc.alert_state):
		return &"idle_alert"
	return &"idle"


func _aiming() -> bool:
	if _crew != null:
		return _aim_hold_left > 0.0 or (_crew.weapons != null and _crew.weapons.is_shooting())
	var h: StringName = _hint()
	if h == &"aim":
		return true
	var gunner: NpcGunner = _body.get_node_or_null(^"Gunner") as NpcGunner
	return gunner != null and gunner.engaging


## The brain's anim_hint (a non-empty `Surrender` component hint wins), host only.
func _hint() -> StringName:
	if _npc == null or not Net.is_authority():
		return &""
	var s: Node = _body.get_node_or_null(^"Surrender")
	if s != null:
		var sh: Variant = s.get(&"anim_hint")
		if sh is StringName and sh != &"":
			return sh
	var b: Node = _body.get_node_or_null(^"Brain")
	if b == null:
		return &""
	var h: Variant = b.get(&"anim_hint")
	return h if h is StringName else &""


func _pick_death_clip(tw: AnimTweak) -> StringName:
	var dir: Vector3 = _hit_dir
	if dir == Vector3.ZERO and _npc != null:
		dir = _npc.last_damage.get("direction", Vector3.ZERO)
	dir.y = 0.0
	if dir.length() < 0.001:
		return &"death_back"
	var facing: Vector3 = -_body.global_transform.basis.z
	facing.y = 0.0
	# Bullet travelling along the facing = hit from behind = pitched forward, face down.
	return &"death_front" if dir.normalized().dot(facing.normalized()) > tw.death_front_dot else &"death_back"


func _speed_scale_for(p_clip: StringName, tw: AnimTweak) -> float:
	if p_clip == _oneshot and _oneshot_left > 0.0:
		return _oneshot_speed
	if not tw.clip_speeds.has(p_clip):
		return 1.0
	var s: float = horizontal_speed() / maxf(float(tw.clip_speeds[p_clip]) * _motion_scale(), 0.01)
	return clampf(s, tw.speed_scale_min, tw.speed_scale_max)


## Skeleton3D.motion_scale of the rig (1 when unset): clip speeds scale with character height.
func _motion_scale() -> float:
	var skel: Skeleton3D = rig.get_node_or_null(^"Skeleton3D") as Skeleton3D if rig != null else null
	return skel.motion_scale if skel != null and skel.motion_scale > 0.0 else 1.0


# --- Frame update helpers ---------------------------------------------------------------------

func _update_velocity(delta: float, tw: AnimTweak) -> void:
	var pos: Vector3 = _body.global_position if _body.is_inside_tree() else _body.position
	var cb: CharacterBody3D = _body as CharacterBody3D
	var remote_crew: bool = _crew != null and not _crew.is_ai and _crew.peer_id != 0 \
		and _crew.peer_id != Net.local_peer_id()
	if cb != null and Net.is_authority() and not remote_crew:
		_vel = cb.velocity
	elif _last_pos != Vector3.INF:
		var raw: Vector3 = (pos - _last_pos) / delta
		if raw.length() <= tw.teleport_speed_mps:
			_vel = _vel.lerp(raw, clampf(tw.velocity_smoothing * delta, 0.0, 1.0))
	_last_pos = pos
	if _npc != null and not _npc.alive:
		_vel = Vector3.ZERO


func _update_turn(delta: float, tw: AnimTweak) -> void:
	var body_yaw: float = _body.global_rotation.y if _body.is_inside_tree() else _body.rotation.y
	var standing: bool = horizontal_speed() <= tw.move_threshold_mps
	var held: bool = (_npc != null and not _npc.alive) or _interact_kind != &""
	var now: StringName = choose_clip() if standing and not held else &""
	if held:
		pass
	elif not standing or POSE_CLIPS.has(now) or ACTION_CLIPS.has(now):
		_visual_yaw = body_yaw
		_turning_left = 0.0
	else:
		var diff: float = wrapf(body_yaw - _visual_yaw, -PI, PI)
		var step: float = deg_to_rad(tw.turn_clip_deg) / maxf(tw.turn_time_s, 0.01) * delta
		var body_turned: bool = absf(wrapf(body_yaw - _prev_body_yaw, -PI, PI)) > 0.0005
		if _turning_left <= 0.0 and absf(diff) > deg_to_rad(tw.turn_threshold_deg):
			_turning_left = tw.turn_time_s
			play_oneshot(&"turn_l" if diff > 0.0 else &"turn_r", tw.turn_time_s)
		if _turning_left > 0.0 or not body_turned:
			_visual_yaw += clampf(diff, -step, step)
	_prev_body_yaw = body_yaw
	if rig != null:
		rig.rotation.y = _rig_base_yaw + wrapf(_visual_yaw - body_yaw, -PI, PI)


func _apply(want: StringName, speed: float, tw: AnimTweak) -> void:
	var full: String = _resolve(want)
	if full == "":
		return
	var restart: bool = _restart and want == _oneshot
	if want != clip or restart:
		var blend: float = tw.blend_s
		if want == _death_clip:
			blend = tw.death_blend_s
		elif want == _oneshot:
			blend = tw.oneshot_blend_s
		player.play(full, blend)
		if restart:
			player.seek(0.0, true)
		clip = want
		_restart = false
	player.speed_scale = speed


## "humanoid/<clip>", else the fallback chain (FALLBACK_CLIPS, then idle); "" when nothing exists.
func _resolve(p_clip: StringName) -> String:
	var c: StringName = p_clip
	for _i: int in 4:
		var full: String = "%s/%s" % [LIBRARY, c]
		if player.has_animation(full):
			return full
		c = FALLBACK_CLIPS.get(c, &"idle")
	return ""


func _kind_for(def: WeaponDef) -> StringName:
	if def != null:
		return &"pistol" if def.weapon_class == Enums.WeaponClass.PISTOL else &"rifle"
	if _npc != null:
		if _npc.enemy_def != null and _npc.enemy_def.params.has("anim_weapon"):
			return StringName(_npc.enemy_def.params["anim_weapon"])
		return AnimTweak.data().npc_weapon_anim_by_role.get(_npc.role, &"pistol")
	return &"pistol"


## WeaponDef by id without ContentDB's unknown-id error (NPC weapons usually have no WeaponDef).
static func _weapon_def(id: StringName) -> WeaponDef:
	if id == &"":
		return null
	if _weapon_defs.is_empty():
		for r: Variant in ContentDB.all_weapons():
			var w: WeaponDef = r as WeaponDef
			if w != null:
				_weapon_defs[w.id] = w
	return _weapon_defs.get(id) as WeaponDef


func _net_id() -> int:
	if _npc != null:
		return _npc.net_id
	return _crew.net_id if _crew != null else 0


# --- Events ---------------------------------------------------------------------------------

func _on_damage_applied(victim_net_id: int, _attacker: int, info: Dictionary) -> void:
	if victim_net_id != 0 and victim_net_id == _net_id():
		_hit_dir = info.get("direction", Vector3.ZERO)


func _on_weapon_fired(shooter_net_id: int, _weapon_id: StringName, _suppressed: bool, _pos: Vector3) -> void:
	if player == null or shooter_net_id == 0 or shooter_net_id != _net_id():
		return
	_aim_hold_left = AnimTweak.data().aim_hold_s
	play_oneshot(&"fire_rifle" if weapon_kind == &"rifle" else &"fire_pistol")


func _on_reload_started(_ws: int, duration: float) -> void:
	if player == null:
		return
	var tw: AnimTweak = AnimTweak.data()
	var done_s: float = float(tw.reload_done_s.get(weapon_kind, 1.0))
	var speed: float = done_s / maxf(duration, 0.05)  # the `done` event frame lands on reload completion
	play_oneshot(&"reload_rifle" if weapon_kind == &"rifle" else &"reload_pistol", duration, false, speed)


func _on_equipped(_ws: int) -> void:
	refresh_weapon()


func _on_loot_dropped(_bag: int, crew_slot: int, thrown: bool) -> void:
	if thrown and _crew != null and crew_slot == _crew.slot:
		play_oneshot(&"throw_bag", -1.0, true)


func _on_interaction_started(interactable_net_id: int, crew_slot: int, kind: StringName) -> void:
	if _crew == null or crew_slot != _crew.slot:
		return
	_interact_kind = kind if kind != &"" else &"use"
	_interact_height = 1.0
	var target: Node3D = Ids.lookup(interactable_net_id) as Node3D
	if target != null and target.is_inside_tree() and _body.is_inside_tree():
		_interact_height = target.global_position.y - _body.global_position.y


func _on_interaction_ended(_interactable_net_id: int, crew_slot: int) -> void:
	if _crew != null and crew_slot == _crew.slot:
		_interact_kind = &""


func _on_interaction_completed(interactable_net_id: int, crew_slot: int, _kind: StringName) -> void:
	_on_interaction_ended(interactable_net_id, crew_slot)
