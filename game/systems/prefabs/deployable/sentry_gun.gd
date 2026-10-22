## D-157 crew sentry gun (PD2 sentry; B's unhooked skill keys, batch 5). Owner: ENV A. The behaviour child of a
## DeployablePrefab of kind &"sentry" (same deploy / pickup flow as every deployable; DeployablePrefab adds it).
## Server-authoritative; yaw / pitch / ammo / mode / health / shield replicate through the prefab's state
## (NetEntityCodec "sentry").
## - Deploy: costs the owner ammo_cost_frac of each weapon's full ammo x deploy.sentry_cost_mult (reserve first);
##   pickup refunds that cost x the ammo it has left.
## - Aim: the nearest alive enemy within range_m in line of sight from the muzzle; Yaw / Pitch turn at
##   turn_speed_deg x deploy.sentry_turn_speed_mult; it fires within FIRE_CONE_DEG of the target, at fire_rate_rpm,
##   with spread_deg x deploy.sentry_accuracy_mult, until its ammo runs out (then it idles, cue.sentry_empty).
## - Health: health x deploy.sentry_health_mult; NPC fire (NpcGunner) and blasts hit it (take_hit); a frontal shield
##   (deploy.sentry_shield) blocks hits from within SHIELD_ARC_DEG of its aim. Zero health destroys it.
## - Police (PoliceBrain) weigh it as a target like a crew member, x quiet_threat_mult in quiet mode.
## - deploy.sentry_modes {quiet, ap, quiet_threat_mult, ap_fire_rate_mult, ap_damage_mult}: the owner's interaction
##   cycles normal -> quiet -> ap (AP: fire rate x ap_fire_rate_mult, damage x ap_damage_mult, shield-piercing);
##   without modes, or once empty, the owner's interaction picks it up.
## Node contract (D models to it; a placeholder is built when the def has no model): Visual/Base/Yaw/Pitch with
## Pitch/Gun, Pitch/Muzzle (Marker3D, -Z = fire) and Pitch/Shield; Yaw / Pitch are turned by code only.
## Values marked ◇ are placeholders until B's DeployableDef sets them (params override DEFAULTS).
class_name SentryGun
extends Node3D

const NODE_NAME: String = "Sentry"
const GROUP: StringName = &"crew_sentry"
const WEAPON_ID: StringName = &"deployable.sentry"
const MODE_NORMAL: StringName = &"normal"
const MODE_QUIET: StringName = &"quiet"
const MODE_AP: StringName = &"ap"
const FIRE_CONE_DEG: float = 6.0
const SHIELD_ARC_DEG: float = 70.0
const RETARGET_S: float = 0.3
const PIVOT_Y: float = 0.55
const DEFAULTS: Dictionary = {
	"ammo": 150, "damage": 20.0, "fire_rate_rpm": 600.0, "range_m": 30.0, "spread_deg": 3.0,  # ◇
	"turn_speed_deg": 160.0, "health": 300.0, "ammo_cost_frac": 0.4,  # ◇ (PD2: a sentry costs 40 % of your ammo)
}

var owner_slot: int = -1
var params: Dictionary = {}
var ammo: int = 0
var ammo_max: int = 0
var health: float = 0.0
var max_health: float = 0.0
var mode: StringName = MODE_NORMAL
var shield: bool = false
var destroyed: bool = false
## Owner ammo taken at deploy, per weapon slot (refunded x ammo / ammo_max at pickup).
var cost: Dictionary = {}
var target: NpcBase = null

var _cooldown: float = 0.0
var _retarget_left: float = 0.0
var _yaw: Node3D = null
var _pitch: Node3D = null
var _muzzle: Node3D = null


## The sentry behaviour of a deployable (null when it is no sentry).
static func of(node: Node) -> SentryGun:
	return node.get_node_or_null(NodePath(NODE_NAME)) as SentryGun if node != null else null


func setup(p_owner_slot: int, def_params: Dictionary) -> void:
	owner_slot = p_owner_slot
	params = DEFAULTS.duplicate()
	params.merge(def_params, true)
	ammo_max = int(params["ammo"])
	ammo = ammo_max
	max_health = float(params["health"]) * Modifiers.mult(owner_slot, &"deploy.sentry_health_mult")
	health = max_health
	shield = Modifiers.flag(owner_slot, &"deploy.sentry_shield")


func _ready() -> void:
	add_to_group(GROUP)
	var visual: Node3D = get_parent().get_node_or_null(^"Visual") as Node3D
	if visual != null and visual.get_node_or_null(^"Base") == null:
		_build_placeholder(visual)
	_yaw = visual.get_node_or_null(^"Base/Yaw") as Node3D if visual != null else null
	_pitch = _yaw.get_node_or_null(^"Pitch") as Node3D if _yaw != null else null
	_muzzle = _pitch.get_node_or_null(^"Muzzle") as Node3D if _pitch != null else null
	_show_shield()


## Box placeholder following the node contract (the default deployable box hidden).
func _build_placeholder(visual: Node3D) -> void:
	for c: Node in visual.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
	var base: Node3D = _box("Base", Vector3(0.5, 0.3, 0.5), Vector3(0, 0.15, 0), visual)
	var yaw: Node3D = Node3D.new()
	yaw.name = "Yaw"
	yaw.position = Vector3(0, PIVOT_Y, 0)
	base.add_child(yaw)
	var pitch: Node3D = Node3D.new()
	pitch.name = "Pitch"
	yaw.add_child(pitch)
	_box("Gun", Vector3(0.14, 0.14, 0.6), Vector3(0, 0, -0.2), pitch)
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -0.52)
	pitch.add_child(muzzle)
	_box("Shield", Vector3(0.6, 0.45, 0.04), Vector3(0, 0.05, -0.62), pitch)


func _box(n: String, size: Vector3, pos: Vector3, parent: Node3D) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.name = n
	parent.add_child(holder)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos if n != "Base" else Vector3.ZERO
	holder.position = Vector3.ZERO if n != "Base" else pos
	holder.add_child(mi)
	return holder


func _show_shield() -> void:
	var s: Node3D = _pitch.get_node_or_null(^"Shield") as Node3D if _pitch != null else null
	if s != null:
		s.visible = shield and not destroyed


## Server: take the deploy cost from `crew`'s weapons (reserve first).
func pay_deploy_cost(crew: CrewController) -> void:
	var w: CrewWeapons = crew.weapons if crew != null else null
	if w == null:
		return
	var frac: float = float(params["ammo_cost_frac"]) * Modifiers.mult(owner_slot, &"deploy.sentry_cost_mult")
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if not w.has_weapon(ws):
			continue
		var want: int = int(round(float(DeployablePrefab.max_ammo(crew, ws)) * frac))
		var from_reserve: int = mini(want, w.reserve(ws))
		var from_mag: int = mini(want - from_reserve, w.mag(ws))
		w.set_ammo(ws, w.mag(ws) - from_mag, w.reserve(ws) - from_reserve)
		cost[ws] = from_reserve + from_mag


## Server: picked up by its owner `crew`: the cost back x the ammo left.
func refund(crew: CrewController) -> void:
	var w: CrewWeapons = crew.weapons if crew != null else null
	if w == null or ammo_max <= 0:
		return
	var share: float = float(ammo) / float(ammo_max)
	for ws: Variant in cost:
		if w.has_weapon(int(ws)):
			var back: int = int(round(float(cost[ws]) * share))
			var room: int = DeployablePrefab.max_ammo(crew, int(ws)) - w.mag(int(ws)) - w.reserve(int(ws))
			w.set_ammo(int(ws), w.mag(int(ws)), w.reserve(int(ws)) + mini(back, maxi(room, 0)))


## The modes the owner's skill unlocks, in cycle order (normal first).
func modes() -> Array[StringName]:
	var out: Array[StringName] = [MODE_NORMAL]
	var p: Dictionary = Modifiers.params(owner_slot, &"deploy.sentry_modes")
	if bool(p.get("quiet", false)):
		out.append(MODE_QUIET)
	if bool(p.get("ap", false)):
		out.append(MODE_AP)
	return out


## Server, DeployablePrefab: `crew` used the sentry. True: it was picked up (the prefab removes itself).
func interact(crew: CrewController) -> bool:
	if crew == null or crew.slot != owner_slot:
		return false
	var m: Array[StringName] = modes()
	if m.size() > 1 and ammo > 0 and not destroyed:
		mode = m[(m.find(mode) + 1) % m.size()]
		_cue(&"cue.sentry_mode")
		return false
	refund(crew)
	return true


## Police target weight (PoliceBrain: distance / this): quiet mode draws less fire.
func threat_mult() -> float:
	if mode == MODE_QUIET:
		return maxf(float(Modifiers.params(owner_slot, &"deploy.sentry_modes").get("quiet_threat_mult", 1.0)), 0.01)
	return 1.0


## Turn rate (rad/s): turn_speed_deg x deploy.sentry_turn_speed_mult (Calibrated Aced).
func turn_rate_rad() -> float:
	return deg_to_rad(float(params["turn_speed_deg"]) * Modifiers.mult(owner_slot, &"deploy.sentry_turn_speed_mult"))


## Spread half-angle (rad): spread_deg x deploy.sentry_accuracy_mult (Calibrated).
func spread_rad() -> float:
	return deg_to_rad(float(params["spread_deg"]) * Modifiers.mult(owner_slot, &"deploy.sentry_accuracy_mult"))


func aim_point() -> Vector3:
	return global_position + Vector3(0, PIVOT_Y, 0)


func eye_position() -> Vector3:
	return aim_point()


func alive() -> bool:
	return not destroyed and is_inside_tree()


## Damage from NPCs / blasts: the frontal shield blocks hits from ahead of its aim.
func take_hit(info: Dictionary, _attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = info.duplicate()
	if not Net.is_authority() or destroyed:
		out["amount"] = 0.0
		return out
	var dir: Vector3 = info.get("direction", Vector3.ZERO) as Vector3
	if shield and dir.length() > 0.01 and _forward().angle_to(-dir) < deg_to_rad(SHIELD_ARC_DEG) \
			and not bool(info.get("shield_pierce", false)):
		out["amount"] = 0.0
		out["blocked"] = true
		return out
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0)
	health = maxf(health - amount, 0.0)
	out["amount"] = amount
	if health <= 0.0:
		destroyed = true
		target = null
		_show_shield()
		_cue(&"cue.sentry_destroyed")
	return out


func _forward() -> Vector3:
	var basis: Basis = _pitch.global_basis if _pitch != null else global_basis
	return -basis.z.normalized()


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or destroyed or not is_inside_tree():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget_left -= delta
	if _retarget_left <= 0.0 or target == null or not is_instance_valid(target) or not target.alive:
		_retarget_left = RETARGET_S
		target = _pick_target()
	if target == null:
		return
	var aligned: bool = _turn_towards(target.global_position + Vector3(0, 1.2, 0), delta)
	if aligned and _cooldown <= 0.0 and ammo > 0:
		_fire()


func _pick_target() -> NpcBase:
	var rng: float = float(params["range_m"])
	var from: Vector3 = aim_point()
	var best: NpcBase = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or HeistRuntime.of(npc) != HeistRuntime.of(self):
			continue
		var d: float = npc.global_position.distance_to(global_position)
		if d > rng or d >= best_d:
			continue
		if not CombatSystem.has_los(self, from, npc.global_position + Vector3(0, 1.2, 0), [npc]):
			continue
		best = npc
		best_d = d
	return best


## Turn Yaw / Pitch toward `point` at the turn rate. True when the aim is within FIRE_CONE_DEG.
func _turn_towards(point: Vector3, delta: float) -> bool:
	if _yaw == null or _pitch == null:
		return true
	var step: float = turn_rate_rad() * delta
	var local: Vector3 = _yaw.get_parent().to_local(point) - _yaw.position
	var want_yaw: float = atan2(-local.x, -local.z)
	_yaw.rotation.y = _yaw.rotation.y + clampf(wrapf(want_yaw - _yaw.rotation.y, -PI, PI), -step, step)
	var flat: float = Vector2(local.x, local.z).length()
	var want_pitch: float = atan2(local.y, flat)
	_pitch.rotation.x = _pitch.rotation.x + clampf(want_pitch - _pitch.rotation.x, -step, step)
	var to: Vector3 = point - (_muzzle.global_position if _muzzle != null else aim_point())
	return _forward().angle_to(to) <= deg_to_rad(FIRE_CONE_DEG)


func _fire() -> void:
	var ap: bool = mode == MODE_AP
	var mp: Dictionary = Modifiers.params(owner_slot, &"deploy.sentry_modes")
	var rate: float = float(params["fire_rate_rpm"]) * (float(mp.get("ap_fire_rate_mult", 1.0)) if ap else 1.0)
	_cooldown = 60.0 / maxf(rate, 1.0)
	ammo -= 1
	var from: Vector3 = _muzzle.global_position if _muzzle != null else aim_point()
	var spread: float = spread_rad()
	var rng: RandomNumberGenerator = GameRng.stream(&"sentry")
	var dir: Vector3 = _forward().rotated(Vector3.UP, rng.randf_range(-spread, spread))
	dir = dir.rotated(dir.cross(Vector3.UP).normalized(), rng.randf_range(-spread, spread)) if absf(dir.y) < 0.99 else dir
	var to: Vector3 = target.global_position + Vector3(0, 1.2, 0)
	var hit: bool = dir.angle_to(to - from) <= atan2(0.35, maxf(from.distance_to(to), 0.1))  # within the body's half-width
	var owner_crew: Node = HeistRuntime.of(self).crew_controller(owner_slot) if HeistRuntime.of(self) != null else null
	var by: int = NetIds.of(owner_crew) if owner_crew != null else 0
	EventBus.audio_cue_requested.emit(&"cue.sentry_fire", from, by)
	if hit and CombatSystem.has_los(self, from, to, [target]):
		var info: Dictionary = Damage.info(float(params["damage"]) * (float(mp.get("ap_damage_mult", 1.0)) if ap else 1.0),
			Enums.DamageType.BULLET, Enums.HitZone.BODY, WEAPON_ID, to, (to - from).normalized(), by)
		info["shield_pierce"] = ap
		CombatSystem.deliver_hit(target, info, by)
	if ammo <= 0:
		target = null
		_cue(&"cue.sentry_empty")


func _cue(id: StringName) -> void:
	EventBus.audio_cue_requested.emit(id, global_position, 0)
	Net.replicate_event(&"audio_cue_requested", [id, global_position, 0])


## NetEntityCodec "sentry" state.
func net_state() -> Dictionary:
	return {"yaw": _yaw.rotation.y if _yaw != null else 0.0, "pitch": _pitch.rotation.x if _pitch != null else 0.0,
		"ammo": ammo, "mode": mode, "hp": health, "shield": shield, "dead": destroyed}


func apply_net_state(d: Dictionary) -> void:
	if Net.is_authority():
		return
	if _yaw != null:
		_yaw.rotation.y = float(d.get("yaw", 0.0))
	if _pitch != null:
		_pitch.rotation.x = float(d.get("pitch", 0.0))
	ammo = int(d.get("ammo", ammo))
	mode = StringName(d.get("mode", mode))
	health = float(d.get("hp", health))
	shield = bool(d.get("shield", shield))
	destroyed = bool(d.get("dead", destroyed))
	_show_shield()
