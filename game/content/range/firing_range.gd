## Firing range v1 (B1-05, pd2_fidelity.md P7 basic). Owner: ENV B.
## Scene: res://content/range/firing_range.tscn (root = this script).
##
## ENTER: instance the scene, optionally call `setup(loadout, difficulty)` before adding it to the
## tree (default: the first ContentDB weapon with stock parts, Routine), then add it as the active
## 3D scene. It needs no heist, HeistRuntime or Net session (solo offline peer is fine).
## EXIT: the range emits `exit_requested()` (Leave button, or Esc / gamepad B in panel mode). The
## owner (MenuFlow) frees the scene; the range releases the mouse in _exit_tree.
##
## Level = RangeBuilder from range_layout.tres (greybox kit floors/walls, lane lines, distance
## markers, one static RangeTarget per lane). Dummy HP/headshot multipliers per difficulty come from
## range_dummies.tres (EnemyDef stopgap, D-010). Weapon numbers are LoadoutResolver output; the
## loadout panel lets the player pick any weapon and mod from ContentDB without owning it (P7).
##
## Shooter: ENV A's crew controller through RangeCrewBridge when it exists; otherwise the TEMPORARY
## RangeSpectator camera + RangeDebugGun (delete both when A1-08 lands). Hits from any source reach
## the targets through the RangeTarget hit API, and every hit updates the damage numbers, the last
## shot and the readout here.
class_name FiringRange
extends Node3D

signal exit_requested()
## Stats changed (weapon, mod or difficulty swap). `stats` = resolved WeaponStats.
signal loadout_applied(stats: WeaponStats)

const LAYOUT_PATH: String = "res://content/data/range/range_layout.tres"
const DUMMIES_PATH: String = "res://content/data/range/range_dummies.tres"
const TWEAK_PATH: String = "res://content/data/range/range_tweak.tres"
## Re-run the readout when the shooter moved this far (m).
const READOUT_MOVE_EPS_M: float = 0.1

@export var layout: RangeLayout
@export var dummy_table: RangeDummyTable
@export var tweak: RangeTweak

var loadout: Loadout = null
var resolved: Loadout = null
var weapon_def: WeaponDef = null
var weapon_stats: WeaponStats = null
var difficulty: int = Enums.Difficulty.ROUTINE
var dummy: RangeDummyDef = null
var targets: Array[RangeTarget] = []
var markers: Array[Node3D] = []
var readout_lane: int = 0
var last_shot: Dictionary = {}
var spectator: RangeSpectator = null
var crew: Node = null
var overlay: RangeOverlay = null
var level: Node3D = null
var fx_root: Node3D = null
var aim_mode: bool = false

var _readout_from: Vector3 = Vector3.INF


## Optional, before entering the tree: the loadout to start with and the dummy difficulty.
func setup(initial_loadout: Loadout = null, initial_difficulty: int = Enums.Difficulty.ROUTINE) -> void:
	loadout = initial_loadout.duplicate(true) as Loadout if initial_loadout != null else null
	difficulty = initial_difficulty


func _ready() -> void:
	_load_data()
	dummy = dummy_table.dummy(layout.lane_dummy)
	readout_lane = clampi(layout.default_readout_lane, 0, maxi(layout.lane_count() - 1, 0))
	level = Node3D.new()
	level.name = "Level"
	add_child(level)
	RangeBuilder.build_level(layout, tweak, level)
	markers = RangeBuilder.build_markers(layout, tweak, level)
	targets = RangeBuilder.build_targets(layout, dummy, difficulty, tweak, level)
	for t: RangeTarget in targets:
		t.damaged.connect(_on_target_damaged)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	if loadout == null:
		loadout = default_loadout()
	crew = RangeCrewBridge.try_spawn(self, Transform3D(Basis.IDENTITY, layout.spawn_position), loadout)
	if crew == null:
		_spawn_spectator()
	_build_overlay()
	_apply_loadout()
	set_aim_mode(false)


func _exit_tree() -> void:
	if spectator != null:
		spectator.set_aim_active(false)


func _process(_delta: float) -> void:
	if overlay == null or weapon_stats == null:
		return
	if spectator != null:
		overlay.show_ammo(spectator.gun.ammo, weapon_stats.mag_size, spectator.gun.is_reloading())
	var pos: Vector3 = _shooter_position()
	if pos.distance_to(_readout_from) > READOUT_MOVE_EPS_M:
		_readout_from = pos
		_refresh_readout()


## The first weapon in ContentDB with stock parts, in its own slot.
static func default_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	var weapons: Array = ContentDB.all_weapons()
	if not weapons.is_empty():
		_put_weapon(l, weapons[0] as WeaponDef)
	return l


## The weapon under test (primary if set, else secondary).
func current_weapon_id() -> StringName:
	return loadout.primary if loadout.primary != &"" else loadout.secondary


## Swap to any ContentDB weapon (ownership is not checked, P7), stock parts.
func select_weapon(weapon_id: StringName) -> void:
	var def: WeaponDef = ContentDB.weapon(weapon_id)
	if def == null:
		return
	_put_weapon(loadout, def)
	_apply_loadout()


## Put `mod_id` in its ModType slot of the current weapon (&"" = back to the stock part).
func set_mod(mod_type: int, mod_id: StringName) -> void:
	var primary: bool = loadout.primary != &""
	var mods: Array[StringName] = loadout.primary_mods if primary else loadout.secondary_mods
	var kept: Array[StringName] = []
	for m: StringName in mods:
		var md: WeaponModDef = ContentDB.mod(m)
		if md != null and int(md.mod_type) != mod_type:
			kept.append(m)
	if mod_id != &"":
		kept.append(mod_id)
	if primary:
		loadout.primary_mods = kept
	else:
		loadout.secondary_mods = kept
	_apply_loadout()


func set_difficulty(diff: int) -> void:
	difficulty = clampi(diff, 0, Enums.Difficulty.size() - 1)
	for t: RangeTarget in targets:
		t.set_difficulty(difficulty)
	_refresh_readout()


func set_readout_lane(lane: int) -> void:
	readout_lane = clampi(lane, 0, maxi(targets.size() - 1, 0))
	_refresh_readout()


func reset_targets() -> void:
	for t: RangeTarget in targets:
		t.reset_target()


## RangeMath.readout() for the readout lane's dummy with the resolved weapon, at the live distance
## from the shooter to the dummy's body (what falloff will use), not the lane's nominal distance.
func readout() -> Dictionary:
	if weapon_stats == null or targets.is_empty():
		return {}
	var t: RangeTarget = targets[readout_lane]
	return RangeMath.readout(weapon_stats, t.max_health, t.headshot_mult(), readout_distance())


## Shooter -> readout target body distance (m).
func readout_distance() -> float:
	if targets.is_empty():
		return 0.0
	return _shooter_position().distance_to(targets[readout_lane].zone_position(Enums.HitZone.BODY))


## Panel mode (false) or aim mode (true).
func set_aim_mode(on: bool) -> void:
	aim_mode = on
	if spectator != null:
		spectator.set_aim_active(on)
	if overlay != null:
		overlay.set_interactive(not on)


func request_exit() -> void:
	set_aim_mode(false)
	exit_requested.emit()


## Mod id per ModType currently on the weapon (equipped or stock).
func mods_by_type() -> Dictionary:
	var out: Dictionary = {}
	if weapon_def == null:
		return out
	var mods: Array[StringName] = loadout.primary_mods if loadout.primary != &"" else loadout.secondary_mods
	for m: WeaponModDef in LoadoutResolver.applied_mods(weapon_def, mods):
		out[int(m.mod_type)] = m.id
	return out


func _apply_loadout() -> void:
	resolved = LoadoutResolver.resolve(loadout)
	weapon_def = ContentDB.weapon(current_weapon_id())
	weapon_stats = resolved.resolved_primary if loadout.primary != &"" else resolved.resolved_secondary
	if weapon_def == null or weapon_stats == null:
		return
	if spectator != null:
		spectator.gun.equip(weapon_def.id, weapon_stats, weapon_def.fire_modes.has(&"auto"))
	RangeCrewBridge.push_loadout(crew, resolved)
	if overlay != null:
		overlay.show_weapon(weapon_def, mods_by_type())
	_refresh_readout()
	loadout_applied.emit(weapon_stats)


func _refresh_readout() -> void:
	if overlay == null or targets.is_empty():
		return
	var name_text: String = UiText.t(dummy.name_key) if dummy != null else ""
	var r: Dictionary = readout()
	if not r.is_empty():
		overlay.show_readout(r, name_text)
		overlay.show_stats(weapon_stats)


func _on_target_damaged(target: RangeTarget, info: Dictionary, _attacker_net_id: int) -> void:
	var pos: Vector3 = info.get("position", Vector3.ZERO)
	if pos == Vector3.ZERO:
		pos = target.zone_position(int(info.get("zone", Enums.HitZone.BODY)) as Enums.HitZone)
	var shot: Dictionary = info.duplicate()
	if not shot.has("distance_m"):
		shot["distance_m"] = _shooter_position().distance_to(pos)
	last_shot = shot
	var n: RangeDamageNumber = RangeDamageNumber.new()
	n.setup(float(info.get("amount", 0.0)), int(info.get("zone", 0)), bool(info.get("killed", false)), pos, tweak)
	fx_root.add_child(n)
	if target.lane != readout_lane:
		readout_lane = target.lane
		_refresh_readout()
	if overlay != null:
		overlay.show_last_shot(shot)
		overlay.readout_option.select(readout_lane)


func _shooter_position() -> Vector3:
	if spectator != null:
		return spectator.global_position
	if crew is Node3D:
		return (crew as Node3D).global_position
	return layout.spawn_position


func _spawn_spectator() -> void:
	spectator = RangeSpectator.new()
	spectator.name = "RangeSpectator"
	spectator.tweak = tweak
	add_child(spectator)
	spectator.set_eye(layout.spawn_position, layout.eye_height_m)
	var t: RangeTarget = targets[readout_lane] if not targets.is_empty() else null
	var focus: Vector3 = Vector3(layout.spawn_position.x, layout.eye_height_m, -20.0)
	if t != null:
		focus = Vector3(layout.spawn_position.x, layout.eye_height_m - 0.3, t.position.z)
	spectator.look_at_point(focus)
	spectator.aim_requested.connect(set_aim_mode)


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "OverlayLayer"
	add_child(layer)
	overlay = RangeOverlay.new()
	overlay.name = "RangeOverlay"
	overlay.setup(layout.lane_target_distances, difficulty, readout_lane, spectator != null)
	layer.add_child(overlay)
	overlay.weapon_selected.connect(select_weapon)
	overlay.mod_selected.connect(set_mod)
	overlay.difficulty_selected.connect(set_difficulty)
	overlay.readout_lane_selected.connect(set_readout_lane)
	overlay.reset_requested.connect(reset_targets)
	overlay.exit_requested.connect(request_exit)
	overlay.aim_requested.connect(set_aim_mode)
	overlay.show_last_shot({})


func _load_data() -> void:
	if layout == null:
		layout = load(LAYOUT_PATH) as RangeLayout
	if dummy_table == null:
		dummy_table = load(DUMMIES_PATH) as RangeDummyTable
	if tweak == null:
		tweak = load(TWEAK_PATH) as RangeTweak


static func _put_weapon(l: Loadout, def: WeaponDef) -> void:
	var empty: Array[StringName] = []
	l.primary = &""
	l.primary_mods = empty.duplicate()
	l.secondary = &""
	l.secondary_mods = empty.duplicate()
	if def.slot == Enums.WeaponSlot.PRIMARY:
		l.primary = def.id
	else:
		l.secondary = def.id
