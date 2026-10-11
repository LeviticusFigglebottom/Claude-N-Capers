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
## markers, one static RangeTarget per lane) plus B4-13's extra lanes: a moving-target area (targets
## on lateral RangeTracks, 2-5 m/s) and an armory area (frontal-plate, shield, staged-plate and
## plain special dummies). `targets` = static lanes first, then the extra lanes. Dummy HP/headshot
## multipliers per difficulty come from ENV A's EnemyDef via range_dummies.tres (D-010).
## Weapon numbers are LoadoutResolver output; the loadout
## panel lets the player pick any weapon and mod from ContentDB without owning it (P7).
## Readout: the selected target's RangeDamageModel (the function its take_hit uses) gives
## shots/TTK/DPS with armor, shield and plate math; a per-dummy-type table does the same for every
## dummy type at the readout distance; the falloff graph plots RangeMath.shot_damage vs distance.
##
## Shooter: ENV A's real crew member (CrewController.spawn_for_range through RangeCrewBridge): its
## first-person camera, PlayerInput and CrewWeapons runtime fire hitscan claims that CombatSystem
## validates and delivers ONCE to RangeTarget.take_hit (damage.md single hit path). Loadout swaps
## call the crew's set_loadout(resolved). Panel mode pauses the crew input (RangeModeInput).
## FALLBACK ONLY (CrewController or its range hook missing, or `use_fallback_shooter` set for
## tests): the RangeSpectator camera + RangeDebugGun.
## Last shot, damage numbers and the readout lane follow EventBus.damage_applied emitted by this
## range's targets with attacker = the shooter's net id; ammo comes from ENV A's LocalHudModel
## following the crew through `track(crew)` (ui_hud.md v1.2; `hud_model`), with the magazine size from
## the resolved stats and the reloading flag from the crew's weapons. Without the model (older A) the
## crew's weapons are read directly (CrewWeapons HUD interface).
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
## Tests/tooling: use the fallback range camera even when ENV A's crew controller exists.
@export var use_fallback_shooter: bool = false

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
## FALLBACK shooter (null while the real crew is used).
var spectator: RangeSpectator = null
## ENV A's CrewController (null in fallback mode).
var crew: Node = null
## ENV A's LocalHudModel tracking `crew` (null in fallback mode or when A has no track()).
var hud_model: Node = null
var mode_input: RangeModeInput = null
var viewmodel: WeaponVisual = null
var overlay: RangeOverlay = null
var level: Node3D = null
var fx_root: Node3D = null
var aim_mode: bool = false

var _readout_dist: float = -INF
var _readout_cooldown: float = 0.0


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
	targets.append_array(RangeBuilder.build_extra_lanes(layout, dummy_table, difficulty, tweak, level))
	EventBus.damage_applied.connect(_on_damage_applied)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	if loadout == null:
		loadout = default_loadout()
	if not use_fallback_shooter:
		crew = RangeCrewBridge.try_spawn(self, Transform3D(Basis.IDENTITY, layout.spawn_position), loadout)
	if crew != null:
		_setup_crew()
	else:
		_spawn_spectator()
	_build_overlay()
	_apply_loadout()
	set_aim_mode(false)


func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)
	if spectator != null:
		spectator.set_aim_active(false)


func _process(delta: float) -> void:
	if overlay == null or weapon_stats == null:
		return
	if spectator != null:
		overlay.show_ammo(spectator.gun.ammo, weapon_stats.mag_size, spectator.gun.is_reloading())
	elif crew != null and is_instance_valid(crew):
		var a: Dictionary = _crew_ammo()
		if not a.is_empty():
			if int(a["mag"]) <= 0 and int(a["reserve"]) <= 0 and not bool(a["reloading"]):
				RangeCrewBridge.push_loadout(crew, resolved)  # the range never runs dry: re-arm
				if hud_model != null and hud_model.has_method(&"refresh"):
					hud_model.call(&"refresh")  # poll now, not at the model's poll_hz
			overlay.show_ammo(int(a["mag"]), int(a["mag_size"]), bool(a["reloading"]), int(a["reserve"]))
	# Re-run the readout when the shooter-to-target distance changed (shooter or moving target),
	# at most every tweak.readout_refresh_s (the per-dummy table simulates every shot).
	_readout_cooldown -= delta
	if _readout_cooldown <= 0.0 and absf(readout_distance() - _readout_dist) > READOUT_MOVE_EPS_M:
		_refresh_readout()


## {mag, mag_size, reserve, reloading} of the crew's equipped weapon: through the tracking HUD model when
## there is one, else straight from the crew's weapons.
func _crew_ammo() -> Dictionary:
	if hud_model != null and is_instance_valid(hud_model):
		var m: Dictionary = RangeCrewBridge.ammo_from_model(hud_model)
		if not m.is_empty():
			m["mag_size"] = weapon_stats.mag_size
			m["reloading"] = RangeCrewBridge.reloading(crew)
			return m
	return RangeCrewBridge.ammo(crew)


## The starter weapon (lowest unlock level, then price; ties by id order) with stock parts, in its
## own slot. Not simply the first id: the armory grows (B4-04) and ids sort alphabetically.
static func default_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	var best: WeaponDef = null
	for w: WeaponDef in ContentDB.all_weapons():
		if best == null or w.unlock_level < best.unlock_level \
				or (w.unlock_level == best.unlock_level and w.price < best.price):
			best = w
	if best != null:
		_put_weapon(l, best)
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
	if overlay != null and overlay.readout_option.selected != readout_lane:
		overlay.readout_option.select(readout_lane)
	_refresh_readout()


## Stand every target back up; the crew is re-armed (full magazine and reserve) too.
func reset_targets() -> void:
	for t: RangeTarget in targets:
		t.reset_target()
	if crew != null and resolved != null:
		RangeCrewBridge.push_loadout(crew, resolved)


## Net id the range's last-shot readout follows: the crew's (attacker id of its hits), else the
## fallback gun's.
func shooter_net_id() -> int:
	if crew != null:
		return RangeCrewBridge.net_id(crew)
	return spectator.attacker_net_id if spectator != null else -1


## The readout lane's dummy with the resolved weapon, at the live distance from the shooter to the
## dummy's body (what falloff will use), not the lane's nominal distance. Shots/TTK/damage come from
## the target's own RangeDamageModel (the function its take_hit uses: armor, shield, plates), with
## RangeMath for falloff and timing (RangeDamageModel.readout).
func readout() -> Dictionary:
	if weapon_stats == null or targets.is_empty():
		return {}
	return targets[readout_lane].model.readout(weapon_stats, readout_distance())


## B4-13: the same readout for every dummy type in range_dummies.tres at the current difficulty and
## readout distance: [{id, name, readout}].
func dummy_readouts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if weapon_stats == null:
		return out
	var d: float = readout_distance()
	for def: RangeDummyDef in dummy_table.dummies:
		out.append({"id": def.id, "name": UiText.t(def.name_key),
				"readout": RangeDamageModel.from_def(def, difficulty).readout(weapon_stats, d)})
	return out


## One-line armor description of a dummy model (readout "Armor" row).
static func armor_text(m: RangeDamageModel) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if m.has_frontal_armor():
		parts.append(UiText.t(&"ui.range.armor.frontal", {"mult": RangeOverlay._num(m.frontal_armor, 2),
				"arc": RangeOverlay._num(m.frontal_armor_arc_deg, 0)}))
	if not is_equal_approx(m.armor_body_mult, 1.0):
		parts.append(UiText.t(&"ui.range.armor.body", {"mult": RangeOverlay._num(m.armor_body_mult, 2)}))
	if not is_equal_approx(m.explosive_mult, 1.0):
		parts.append(UiText.t(&"ui.range.armor.explosive", {"mult": RangeOverlay._num(m.explosive_mult, 2)}))
	if m.shield:
		parts.append(UiText.t(&"ui.range.armor.shield", {"mult": RangeOverlay._num(m.shield_pierce_mult, 2)}))
	if not m.plate_health.is_empty():
		var hp: PackedStringArray = PackedStringArray()
		for p: float in m.plate_health:
			hp.append(RangeOverlay._num(p, 0))
		parts.append(UiText.t(&"ui.range.armor.plates", {"hp": " / ".join(hp)}))
	if parts.is_empty():
		return UiText.t(&"ui.range.armor.none")
	return ", ".join(parts)


## Option text of every range target, in lane order.
func lane_labels() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: RangeTarget in targets:
		var m: String = UiText.t(&"ui.range.marker", {"m": roundi(t.distance_m)})
		if t.lane < layout.lane_count():
			out.append(m)
		else:
			var def: RangeLaneDef = layout.extra_lanes[t.lane - layout.lane_count()]
			var dname: String = UiText.t(t.dummy.name_key) if t.dummy != null else ""
			if def.is_moving():
				out.append(UiText.t(&"ui.range.lane_moving", {"name": dname, "m": m, "speed": snappedf(def.speed_mps, 0.1)}))
			else:
				out.append(UiText.t(&"ui.range.lane_named", {"name": dname, "m": m}))
	return out


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
	if mode_input != null:
		mode_input.set_aim_active(on)
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
	if crew != null:
		RangeCrewBridge.push_loadout(crew, resolved)
		var mods: Array[StringName] = loadout.primary_mods if loadout.primary != &"" else loadout.secondary_mods
		viewmodel = RangeCrewBridge.attach_viewmodel(crew, weapon_def, mods, tweak.viewmodel_offset)
		if viewmodel != null:
			viewmodel.apply_loadout_finish(loadout)  # B7-04: Loadout.weapon_finishes (stamped by MenuFlow)
	if overlay != null:
		overlay.show_weapon(weapon_def, mods_by_type())
	_refresh_readout()
	loadout_applied.emit(weapon_stats)


func _refresh_readout() -> void:
	if overlay == null or targets.is_empty():
		return
	var t: RangeTarget = targets[readout_lane]
	var name_text: String = UiText.t(t.dummy.name_key) if t.dummy != null else ""
	var r: Dictionary = readout()
	_readout_dist = readout_distance()
	_readout_cooldown = tweak.readout_refresh_s
	if not r.is_empty():
		overlay.show_readout(r, name_text, armor_text(t.model))
		overlay.show_stats(weapon_stats)
		overlay.show_falloff(weapon_stats, float(r["distance_m"]))
		overlay.show_dummy_table(dummy_readouts())


## EventBus.damage_applied (damage.md): only hits on this range's targets by the range shooter.
func _on_damage_applied(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	if attacker_net_id != shooter_net_id():
		return
	for t: RangeTarget in targets:
		if is_instance_valid(t) and t.net_id == victim_net_id and t.net_id != Ids.INVALID:
			_on_target_damaged(t, info)
			return


func _on_target_damaged(target: RangeTarget, info: Dictionary) -> void:
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


## Where shots start: the fallback camera, or the crew's eye (CrewWeapons hitscan origin).
func _shooter_position() -> Vector3:
	if spectator != null:
		return spectator.global_position
	if crew != null and is_instance_valid(crew):
		return RangeCrewBridge.eye_position(crew)
	return layout.spawn_position + Vector3.UP * layout.eye_height_m


func _setup_crew() -> void:
	RangeCrewBridge.activate_camera(crew)
	mode_input = RangeModeInput.new()
	mode_input.name = "RangeModeInput"
	mode_input.crew = crew
	add_child(mode_input)
	mode_input.aim_requested.connect(set_aim_mode)
	hud_model = RangeCrewBridge.track_hud_model(self, crew)


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
	overlay.setup(lane_labels(), difficulty, readout_lane, spectator != null, tweak)
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
