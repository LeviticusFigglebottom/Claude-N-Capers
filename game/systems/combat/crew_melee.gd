## Crew melee (L3.9 "charge, knockdown, silent; melee kills in stealth are silent"; D-069). Owner: ENV A.
## Child `Melee` of CrewController, ticked with the weapons (server and the owning client). The melee item is
## Loadout.melee (MeleeDef); without one it is a gun bash (CombatTweak bash_*).
## - intent.melee press starts a charge; released within melee_tap_s = quick swing (MeleeDef.damage), held =
##   charged swing: damage lerps to charged_damage over charge_time_s / weapon.melee_charge_speed_mult.
## - the swing lasts swing_time_s (MeleeDef or melee_swing_s); at hit_delay_s the authority strikes the nearest
##   target in a melee_cone_deg cone out to range_m with line of sight: one DamageType.MELEE hit (x
##   weapon.damage_mult[melee], x weapon.melee_bloodthirst, x PerkHooks.melee_damage_mult; a miss calls
##   PerkHooks.on_melee_miss). A charged hit's knockdown chance (MeleeDef.knockdown,
##   or bash_knockdown, x weapon.melee_knockdown_mult) stuns a non-special NPC melee_knockdown_s; specials
##   (Bulwark, Wrecker...) resist it, except weapon.shield_knockback, which staggers a Bulwark on any melee hit.
## - silent: no noise, no weapon_fired (S4.3), so a stealth melee kill alarms nobody (no S3.7 misfire either).
## - only NORMAL / masked crew melee (no melee while casing, downed or incapacitated); swinging cancels a reload.
## Signals (presentation; FpViewmodel plays melee_* / <set>_bash clips): charge_started, swung(charged),
## hit_landed(target).
class_name CrewMelee
extends Node

signal charge_started()
signal swung(charged: bool)
signal hit_landed(target: Object)

const DAMAGE_QUALIFIER: StringName = &"melee"
const BLOODTHIRST_KEY: StringName = &"weapon.melee_bloodthirst"

## &"" idle, &"charging", &"swinging".
var state: StringName = &""
## Charge 0..1 while charging / of the current swing.
var charge: float = 0.0
## The swing in progress lands its hit after this (s; < 0 = already struck).
var hit_left: float = -1.0
var swing_left: float = 0.0
var swings: int = 0

var _crew: CrewController = null
var _prev_melee: bool = false
var _charge_t: float = 0.0
var _bloodthirst_kills: int = 0


func _ready() -> void:
	_crew = get_parent() as CrewController
	EventBus.npc_killed.connect(_on_npc_killed)


func _exit_tree() -> void:
	if EventBus.npc_killed.is_connected(_on_npc_killed):
		EventBus.npc_killed.disconnect(_on_npc_killed)


## The equipped melee item (null = gun bash).
func melee_def() -> MeleeDef:
	var id: StringName = _crew.loadout.melee if _crew != null and _crew.loadout != null else &""
	return ContentDB.melee(id) if id != &"" else null


func can_melee() -> bool:
	return _crew != null and _crew.masked and _crew.crew_state == Enums.CrewState.NORMAL \
		and (_crew.throwables == null or not _crew.throwables.busy())


## Server and the owning client: one tick of intent.melee.
func tick(intent: CrewIntent, delta: float) -> void:
	var held: bool = intent != null and intent.melee
	var pressed: bool = held and not _prev_melee
	_prev_melee = held
	match state:
		&"":
			if pressed and can_melee():
				state = &"charging"
				_charge_t = 0.0
				charge = 0.0
				charge_started.emit()
		&"charging":
			if not can_melee():
				state = &""
			elif held:
				_charge_t += delta * Modifiers.mult(_crew.slot, &"weapon.melee_charge_speed_mult")
				var def: MeleeDef = melee_def()
				charge = clampf(_charge_t / maxf(def.charge_time_s if def != null else 1.0, 0.01), 0.0, 1.0)
			else:
				_start_swing(_charge_t >= CombatTweak.data().melee_tap_s)
		&"swinging":
			swing_left -= delta
			if hit_left >= 0.0:
				hit_left -= delta
				if hit_left < 0.0 and Net.is_authority():
					_strike()
			if swing_left <= 0.0:
				state = &""
				charge = 0.0


func _start_swing(charged: bool) -> void:
	var tw: CombatTweak = CombatTweak.data()
	var def: MeleeDef = melee_def()
	if not charged:
		charge = 0.0
	state = &"swinging"
	swings += 1
	swing_left = (def.swing_time_s if def != null and def.swing_time_s > 0.0 else tw.melee_swing_s) if def != null else tw.bash_swing_s
	hit_left = (def.hit_delay_s if def != null and def.hit_delay_s > 0.0 else tw.melee_hit_delay_s) if def != null else tw.bash_hit_delay_s
	if _crew.weapons != null and _crew.weapons.reloading:
		_crew.weapons.reloading = false  # PD2: a swing cancels the reload
		_crew.weapons.reload_left = 0.0
	swung.emit(charged)


## Authority: strike the nearest target in the melee cone.
func _strike() -> void:
	var tw: CombatTweak = CombatTweak.data()
	var def: MeleeDef = melee_def()
	var range_m: float = def.range_m if def != null else tw.bash_range_m
	var eye: Vector3 = _crew.eye_position()
	var fwd: Vector3 = _crew.aim_direction().normalized()
	var best: Object = null
	var best_d: float = INF
	for t: Object in SpecialWeapons.cone_targets(_crew, eye, fwd, range_m, tw.melee_cone_deg, true):
		var n3: Node3D = t as Node3D
		var d: float = n3.global_position.distance_to(_crew.global_position) if n3 != null else INF
		if d < best_d:
			best = t
			best_d = d
	if best == null:
		if _kick_device(eye, fwd, range_m, tw):  # B1 Kickstarter: the swing hit a jammed drill / saw
			return
		PerkHooks.on_melee_miss(_crew)  # perk.infiltrator: a miss resets the melee chain
		return
	var base: float = def.damage if def != null else tw.bash_damage
	if def != null and charge > 0.0:
		base = lerpf(def.damage, maxf(def.charged_damage, def.damage), charge)
	var amount: float = base * Modifiers.mult(_crew.slot, &"weapon.damage_mult", DAMAGE_QUALIFIER) * _bloodthirst_mult() \
		* PerkHooks.melee_damage_mult(_crew) * SkillTriggers.berserk_mult(_crew, false)  # perk.infiltrator; B1 Berserker
	var center: Vector3 = (best as Node3D).global_position + Vector3(0.0, 1.0, 0.0) if best is Node3D else eye
	var info: Dictionary = Damage.info(amount, Enums.DamageType.MELEE, Enums.HitZone.BODY,
		def.id if def != null else &"melee.bash", center, fwd, _crew.net_id)
	CombatSystem.deliver_hit(best, info, _crew.net_id)
	ShotFx.melee_hit(_crew, eye, center, best)  # PO-8: shot_fx (&"melee") here + relayed (impact_fx.md)
	_bloodthirst_kills = 0
	hit_landed.emit(best)
	_knock(best, def, tw)


## B1 `interaction.device_melee_restart`: a swing with no enemy in reach strikes the nearest JAMMED device (DrillPoint /
## Safe runner) within the melee range and cone (DeviceRunner.kick rolls the restart). True: it struck one.
func _kick_device(eye: Vector3, fwd: Vector3, range_m: float, tw: CombatTweak) -> bool:
	if not Modifiers.flag(_crew.slot, &"interaction.device_melee_restart"):
		return false
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt == null or rt.map == null:
		return false
	var half: float = deg_to_rad(tw.melee_cone_deg * 0.5)
	var devices: Array[Node] = rt.map.find_children("*", "DrillPoint", true, false)
	devices.append_array(rt.map.find_children("*", "Safe", true, false))
	for n: Node in devices:
		var runner: DeviceRunner = n.get(&"runner") as DeviceRunner if &"runner" in n else null
		var at: Node3D = n.get(&"device_node") as Node3D if &"device_node" in n else null
		if runner == null or runner.state != DeviceRunner.State.JAMMED:
			continue
		var p: Vector3 = at.global_position if at != null else (n as Node3D).global_position
		var to: Vector3 = p - eye
		if to.length() > range_m + 0.5 or fwd.angle_to(to) > half:
			continue
		runner.kick(_crew.slot)
		return true
	return false


func _knock(target: Object, def: MeleeDef, tw: CombatTweak) -> void:
	var npc: NpcBase = target as NpcBase
	if npc == null or not npc.alive:
		return
	var bw: BulwarkBrain = npc.get_node_or_null("Brain") as BulwarkBrain
	if bw != null and Modifiers.flag(_crew.slot, &"weapon.shield_knockback"):
		bw.stagger()  # weapon.shield_knockback: melee knocks Bulwarks back 100%
		return
	if charge <= 0.0 or (npc.enemy_def != null and npc.enemy_def.is_special):
		return  # PD2: only a charged hit knocks down, and specials resist it
	var chance: float = (def.knockdown if def != null else tw.bash_knockdown) * Modifiers.mult(_crew.slot, &"weapon.melee_knockdown_mult")
	if chance > 0.0 and GameRng.stream(&"melee").randf() < chance:
		npc.stun(tw.melee_knockdown_s)  # stun-immune enemies (Wrecker) ignore it (NpcBase.stun)


## weapon.melee_bloodthirst {per_kill, cap}: each non-melee kill since the last melee hit adds per_kill.
func _bloodthirst_mult() -> float:
	var p: Dictionary = Modifiers.params(_crew.slot, BLOODTHIRST_KEY)
	if p.is_empty():
		return 1.0
	return minf(1.0 + float(p.get("per_kill", 0.0)) * float(_bloodthirst_kills), float(p.get("cap", 16.0)))


func _on_npc_killed(_npc: int, killer: int, info: Dictionary) -> void:
	if _crew != null and killer == _crew.net_id and int(info.get("type", Enums.DamageType.BULLET)) != Enums.DamageType.MELEE:
		_bloodthirst_kills += 1
