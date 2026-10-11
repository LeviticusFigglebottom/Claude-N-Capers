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
class_name FpViewmodel
extends Node3D

enum Action { NONE, FIRE, RELOAD, SWAP }

const NODE_NAME: String = "FpViewmodel"
const ATTACH_NAME: String = "WeaponBone"
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
	&"cover_open": [&"cover", 1.0], &"cover_close": [&"cover", 0.0],
}
const CHANNELS: Array[StringName] = [&"slide", &"pump", &"bolt_lift", &"bolt_slide", &"cover"]
## Weapon model part node names (visual_slots.md).
const PART_SLIDE: StringName = &"Slide"
const PART_PUMP: StringName = &"Pump"
const PART_BOLT: StringName = &"Bolt"
const PART_COVER: StringName = &"FeedCover"

## The arms rig's AnimationPlayer / Skeleton3D / instanced scene root.
var player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var arms: Node3D = null
## BoneAttachment3D on the `weapon` bone: the WeaponVisual's parent.
var weapon_attach: BoneAttachment3D = null
## The WeaponVisual shown (during a holster: the outgoing one until the draw starts).
var weapon_visual: WeaponVisual = null
## anim_set of the weapon currently in the hands.
var anim_set: StringName = &""
## Short clip name currently playing ("fire", "idle"...); the player plays "<anim_set>/<clip>".
var clip: StringName = &""
## Current one-shot (Action), and its playback speed scale (re-timing).
var action: int = Action.NONE
var action_speed: float = 1.0
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
var _mag_bone: int = -1
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0


## The camera's viewmodel arms (null when none).
static func of(cam: Node) -> FpViewmodel:
	return cam.get_node_or_null(NODE_NAME) as FpViewmodel if cam != null else null


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
	skeleton.add_child(weapon_attach)
	_no_shadows(inst)
	_crew = crew
	for ch: StringName in CHANNELS:
		parts[ch] = 0.0
	return true


func _ready() -> void:
	if _crew != null and _crew.weapons != null:
		_crew.weapons.fired.connect(_on_fired)
		_crew.weapons.reload_started.connect(_on_reload_started)
		_crew.weapons.reload_finished.connect(_on_reload_finished)


func _exit_tree() -> void:
	if _crew == null or not is_instance_valid(_crew) or _crew.weapons == null:
		return
	for pair: Array in [
		[_crew.weapons.fired, _on_fired], [_crew.weapons.reload_started, _on_reload_started],
		[_crew.weapons.reload_finished, _on_reload_finished],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


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
	if action != Action.NONE:
		_seq_t += delta
		while action != Action.NONE and _seg_i >= 0 and _seg_i < _segs.size() \
				and _seq_t >= float(_segs[_seg_i]["start"]) + float(_segs[_seg_i]["dur"]):
			_play_segment(_seg_i + 1)
	_update_parts()
	_update_ads(delta, tw)
	if action == Action.NONE:
		_play_base(tw)
	_update_offset(delta, tw)
	_update_magazine()


# --- Gameplay signal handlers (presentation only) ---------------------------------------------

func _on_fired(_claim: Dictionary) -> void:
	if anim_set == &"" or action == Action.SWAP:
		return
	var aimed: bool = _aim_wanted()
	var fire: StringName = _resolve(anim_set, &"fire_ads" if aimed else &"fire")
	if fire == &"":
		return
	var cycle: float = _length(anim_set, fire)
	var done: float = _event(anim_set, fire, &"done")
	var bolt: StringName = _resolve(anim_set, &"bolt_ads" if aimed else &"bolt")
	if bolt != &"":
		done = cycle + maxf(_event(anim_set, bolt, &"done"), 0.0)
	elif done < 0.0:
		done = cycle
	var speed: float = maxf(1.0, done / maxf(_shot_interval(), 0.01))
	var segs: Array[Dictionary] = []
	_add_seg(segs, anim_set, fire, cycle / speed, speed)
	if bolt != &"":
		_add_seg(segs, anim_set, bolt, _length(anim_set, bolt) / speed, speed)
	_start(Action.FIRE, segs)
	if _last_round():
		_drop_keys(&"slide", 0.0)  # pistol slide lock on the last round


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
	var speed: float = native / maxf(duration, 0.05)
	var at: float = 0.0
	for s: Dictionary in segs:
		s["start"] = at
		s["dur"] = float(s["dur"]) / maxf(speed, 0.001)
		s["speed"] = speed
		at += float(s["dur"])
	_reload_done = false
	_start(Action.RELOAD, segs)


func _on_reload_finished(_ws: int) -> void:
	_reload_done = true


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
	for ch: StringName in CHANNELS:
		parts[ch] = 0.0
		_key_start[ch] = 0.0
	_part_nodes.clear()
	for n: StringName in [PART_SLIDE, PART_PUMP, PART_BOLT, PART_COVER]:
		var node: Node3D = wv.get_base_marker(n) if wv != null else null
		if node != null:
			_part_nodes[n] = [node, node.transform]
	_magwell = wv.get_base_marker(&"Magwell") if wv != null else null
	_magwell_rest = _magwell.transform if _magwell != null else Transform3D.IDENTITY


# --- Per-frame helpers ------------------------------------------------------------------------

func _play_base(tw: FpViewmodelTweak) -> void:
	if anim_set == &"":
		return
	var want: StringName = &"idle"
	if _sprinting(tw):
		want = &"sprint"
	elif ads_weight > 0.5:
		want = &"ads_idle"
	var r: StringName = _resolve(anim_set, want)
	if r == &"" or (r == clip and player.is_playing()):
		return
	player.play("%s/%s" % [anim_set, r], tw.blend_s)
	clip = r


func _update_ads(delta: float, tw: FpViewmodelTweak) -> void:
	var target: float = 1.0 if _aim_wanted() and action != Action.RELOAD and action != Action.SWAP else 0.0
	ads_weight = move_toward(ads_weight, target, tw.ads_rate * delta)


func _update_offset(delta: float, tw: FpViewmodelTweak) -> void:
	var speed: float = _speed()
	var moving: bool = speed > tw.move_threshold_mps and not _sprinting(tw)
	var target: float = clampf(speed / maxf(tw.bob_ref_speed_mps, 0.01), 0.0, 1.5) if moving else 0.0
	_bob_weight = move_toward(_bob_weight, target, tw.bob_rate * delta)
	_bob_phase = fmod(_bob_phase + delta * TAU * tw.bob_frequency_hz * maxf(target, 0.5), TAU * 2.0)
	var amp: float = _bob_weight * lerpf(1.0, tw.ads_bob_mult, ads_weight)
	var off: Vector3 = Vector3(sin(_bob_phase) * tw.bob_amplitude.x, sin(_bob_phase * 2.0) * tw.bob_amplitude.y, 0.0) * amp
	if tw.ads_align_aim_point and ads_weight > 0.0 and weapon_visual != null and is_instance_valid(weapon_visual) \
			and is_inside_tree():
		var aim: Node3D = weapon_visual.get_marker(WeaponVisual.AIM_POINT)
		if aim != null and aim.is_inside_tree():
			var p: Vector3 = arms.global_transform.affine_inverse() * aim.global_position
			off += Vector3(-p.x, -p.y, 0.0) * ads_weight
	position = off


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
	return _crew != null and _crew.intent != null and _crew.intent.aim


func _speed() -> float:
	return Vector2(_crew.velocity.x, _crew.velocity.z).length() if _crew != null else 0.0


func _sprinting(tw: FpViewmodelTweak) -> bool:
	return _crew != null and _crew.sprinting and _speed() > tw.move_threshold_mps


func _shot_interval() -> float:
	if _crew == null or _crew.weapons == null:
		return 1.0
	var st: WeaponStats = _crew.weapons.stats(_crew.weapons.equipped_slot)
	return 60.0 / maxf(st.fire_rate_rpm, 1.0) if st != null else 1.0


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
