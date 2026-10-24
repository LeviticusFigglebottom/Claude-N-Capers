## D-132 (3) animation LOD for NPC AnimDrivers (ENV D's perf audit §4). Owner: ENV A. Presentation only: it decides
## which process frames an NPC's AnimDriver ticks and its AnimationPlayer samples, vs the LOCAL camera
## (get_viewport().get_camera_3d()); gameplay never reads animation state (D-121), so nothing gameplay-side changes.
## Bands (AnimTweak anim_lod_*; on screen = a sphere around the body inside the camera frustum):
##   FULL    < near (15 m) and on screen: every frame, the AnimationPlayer processes itself (pre-D-132).
##   NEAR    near..far (15-30 m) on screen: every near_cadence (2nd) frame; left-hand IK off.
##   FAR     > far (30 m) OR off screen: every far_cadence (4th) frame; left-hand IK and the hold layer off.
##   PAUSED  off screen AND > far: no tick at all.
## Outside FULL the player is MANUAL: the driver ticks with the time banked since its last tick and then
## `advance()`s the player by the same amount, so one-shot timers, crossfades and method-track keys crossed in that
## interval all land (a key fires at most one cadence step late). A paused body banks its time too and catches up on
## its first due frame back (off screen, so the catch-up never shows; on screen the pose is never more than one
## cadence step stale). Frames are staggered per NPC by hash(net_id) % cadence.
## Always FULL: crew bodies (any non-NpcBase), the first tick, headless (no rendering) unless `allow_headless`, no
## camera, AnimTweak.anim_lod_enabled off, dead bodies (death clip settling, ragdoll handoff), stunned, scripted
## (META_ANIM_OVERRIDE, rappel), intimidated / surrendered / dominated (surrender / cuff sequences), carrying a bag,
## and any NPC within anim_lod_aim_radius_m of a crew member's aim ray.
## Back-reference `_d` to the AnimDriver, like CombatClips / AnimLayers / HitClips / HeldVisuals.
class_name AnimLod
extends RefCounted

enum Band { FULL, NEAR, FAR, PAUSED }

## States in which an NPC plays its surrender / cuff sequence (never LOD'd).
const SEQUENCE_STATES: Array[int] = [
	Enums.AlertState.INTIMIDATED, Enums.AlertState.SURRENDERED, Enums.AlertState.DOMINATED,
]

## Tests / benches: apply the LOD under the headless display server too (otherwise headless is always FULL).
static var allow_headless: bool = false

## Shared per frame by every driver: the frame key, the camera, its position and frustum, crew aim rays.
static var _view_key: Vector2i = Vector2i(-1, -1)
static var _view_cam: Camera3D = null
static var _view_pos: Vector3 = Vector3.ZERO
static var _view_planes: Array[Plane] = []
static var _aim_rays: Array[Vector3] = []
## 1 under the headless display server (cached; -1 = not checked yet).
static var _headless: int = -1

## Test hook: {"pos": Vector3, "on_screen": bool} stands in for the viewport camera ({} = the real camera).
var view_override: Dictionary = {}
## This frame's band and cadence (frames per tick; 0 = paused).
var band: Band = Band.FULL
var cadence: int = 1
## Driven ticks / skipped frames since bind (tests, bench).
var ticks: int = 0
var skipped: int = 0

var _d: AnimDriver = null
## Seconds banked since the last tick.
var _acc: float = 0.0
## The player is in MANUAL process mode (we advance it).
var _manual: bool = false
## Seconds to advance the player by after this frame's tick (MANUAL, or leaving it).
var _advance: float = 0.0
## The due tick's frame delta, and the driver's clip / restart flag before it (after_tick splits a clip start).
var _frame_dt: float = 0.0
var _clip_before: StringName = &""
var _restart_before: bool = false
## The player's / skeleton's process modes before MANUAL.
var _player_mode: AnimationMixer.AnimationCallbackModeProcess = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _skel_mode: Skeleton3D.ModifierCallbackModeProcess = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE


func _init(driver: AnimDriver) -> void:
	_d = driver


## The band for a body `dist_m` from the camera, `on_screen` or not.
static func band_for(dist_m: float, on_screen: bool, tw: AnimTweak) -> Band:
	var far: bool = dist_m > tw.anim_lod_far_m
	if not on_screen and far:
		return Band.PAUSED
	if not on_screen or far:
		return Band.FAR
	return Band.NEAR if dist_m >= tw.anim_lod_near_m else Band.FULL


## Frames per tick in band `b` (0 = paused).
static func cadence_of(b: Band, tw: AnimTweak) -> int:
	match b:
		Band.NEAR:
			return maxi(tw.anim_lod_near_cadence, 1)
		Band.FAR:
			return maxi(tw.anim_lod_far_cadence, 1)
		Band.PAUSED:
			return 0
	return 1


## This NPC's frame offset within `p_cadence` (hash of its net id: every NPC of a crowd ticks on a different frame).
static func stagger(net_id: int, p_cadence: int) -> int:
	return posmod(hash(net_id), p_cadence) if p_cadence > 1 else 0


## True when an NPC with `net_id` ticks on process frame `frame` at `p_cadence`.
static func due(net_id: int, frame: int, p_cadence: int) -> bool:
	return p_cadence == 1 or (p_cadence > 1 and posmod(frame + stagger(net_id, p_cadence), p_cadence) == 0)


## Drop the shared per-frame view (tests that move the camera or crew within one frame).
static func invalidate() -> void:
	_view_key = Vector2i(-1, -1)
	_view_cam = null


## Called once per process frame (`frame` = Engine.get_process_frames()): the delta to tick the driver with, or a
## negative value when this frame is skipped. Call after_tick() after the tick.
func step(delta: float, frame: int) -> float:
	var tw: AnimTweak = AnimTweak.data()
	var was: Band = band
	band = _select(tw, frame)
	if band != was and _d.held_visuals != null:
		_d.held_visuals.set_weapon_shadows(band == Band.FULL)  # OF perf: no weapon shadows past the near tier
	cadence = cadence_of(band, tw)
	_frame_dt = delta
	_clip_before = _d.clip
	_restart_before = _d._restart
	if band == Band.FULL:
		var dt: float = delta + _acc
		_advance = dt if _manual else 0.0  # leaving MANUAL: this frame's sampling is ours, then IDLE again
		_acc = 0.0
		ticks += 1
		return dt
	_set_manual(true)
	_acc += delta
	if not due(_d._net_id(), frame, cadence):
		skipped += 1
		return -1.0
	var out: float = _acc
	_acc = 0.0
	_advance = out
	ticks += 1
	return out


## After this frame's tick: apply the band's layer limits, then sample the player for the banked time (which
## updates the skeleton and its modifiers once).
func after_tick() -> void:
	var player: AnimationPlayer = _d.player
	if player == null or not is_instance_valid(player):
		return
	if band != Band.FULL:
		var ik: ThirdPersonLeftHandIK = _d.left_hand_ik
		if ik != null and is_instance_valid(ik):
			ik.influence = 0.0
			ik.active = false
		var hold: UpperBodyLayer = _d.hold_layer
		if band != Band.NEAR and hold != null and is_instance_valid(hold):
			hold.influence = 0.0
			hold.active = false
	if _advance > 0.0 and _manual:
		player.advance(_start_aligned(_advance))
	_advance = 0.0
	if band == Band.FULL:
		_set_manual(false)


## A clip (re)started on this tick starts NOW: its first sample is one frame long, as at full rate (the banked time
## before the tick belongs to the clip it replaced, so the new clip's keys are never early, at most one cadence step
## late). A one-shot started between ticks (play_oneshot) gets the same banked time back on its timer.
func _start_aligned(adv: float) -> float:
	var restarted: bool = _restart_before and not _d._restart
	if adv <= _frame_dt or (_d.clip == _clip_before and not restarted):
		return adv
	var lost: float = adv - _frame_dt
	if restarted and _d._oneshot_left > 0.0:
		_d._oneshot_left = minf(_d._oneshot_left + lost, _d._oneshot_dur)
	return _frame_dt


## Before a (re)bind: the current player back to IDLE, nothing banked.
func reset() -> void:
	_set_manual(false)
	_acc = 0.0
	_advance = 0.0
	band = Band.FULL
	cadence = 1
	ticks = 0
	skipped = 0


## Seconds banked and not yet ticked (tests).
func banked_s() -> float:
	return _acc


## MANUAL: the player samples only when we advance it, and the skeleton runs its modifiers (hold / flinch layers,
## hat lift, left-hand IK) only on those updates instead of every frame (the skin keeps the last pose in between).
## Leaving MANUAL restores the modes they had.
func _set_manual(on: bool) -> void:
	if on == _manual:
		return
	_manual = on
	var player: AnimationPlayer = _d.player
	if player == null or not is_instance_valid(player):
		return
	var skel: Skeleton3D = player.get_parent().get_node_or_null(^"Skeleton3D") as Skeleton3D
	if on:
		_player_mode = player.callback_mode_process
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if skel != null:
			_skel_mode = skel.modifier_callback_mode_process
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	else:
		player.callback_mode_process = _player_mode
		if skel != null:
			skel.modifier_callback_mode_process = _skel_mode


func _select(tw: AnimTweak, frame: int) -> Band:
	var test_view: bool = not view_override.is_empty()
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	if (not test_view and not allow_headless and _headless == 1) or exempt(tw):
		return Band.FULL
	var center: Vector3 = _d._body.global_position + Vector3(0.0, tw.anim_lod_center_y_m, 0.0)
	_refresh_view(frame)
	if _aimed_at(center, tw):
		return Band.FULL
	if test_view:
		var vp: Vector3 = view_override.get("pos", center)
		return band_for(vp.distance_to(center), bool(view_override.get("on_screen", true)), tw)
	if _view_cam == null:
		return Band.FULL
	var on_screen: bool = true
	for p: Plane in _view_planes:
		if p.distance_to(center) > tw.anim_lod_radius_m:
			on_screen = false
			break
	return band_for(_view_pos.distance_to(center), on_screen, tw)


## True when this driver must run at full rate whatever the camera (see the class doc).
func exempt(tw: AnimTweak) -> bool:
	var npc: NpcBase = _d._npc
	if not tw.anim_lod_enabled or npc == null or _d.clip == &"" or not npc.is_inside_tree():
		return true
	if not npc.alive or npc.is_stunned() or SEQUENCE_STATES.has(npc.alert_state):
		return true
	if _d.bag_visual != null and is_instance_valid(_d.bag_visual):
		return true
	return _d._scripted_clip() != &""


## Crew aim rays (eye, aim direction) within anim_lod_aim_radius_m of `center`.
func _aimed_at(center: Vector3, tw: AnimTweak) -> bool:
	for i: int in range(0, _aim_rays.size(), 2):
		var v: Vector3 = center - _aim_rays[i]
		var t: float = v.dot(_aim_rays[i + 1])
		if t >= 0.0 and (v - _aim_rays[i + 1] * t).length_squared() <= tw.anim_lod_aim_radius_m * tw.anim_lod_aim_radius_m:
			return true
	return false


## Refresh the shared camera (null without one) and crew aim rays once per frame (one viewport: the local view).
func _refresh_view(frame: int) -> void:
	var key: Vector2i = Vector2i(frame, Engine.get_process_frames())
	if key == _view_key:
		return
	_view_key = key
	var cam: Camera3D = _d.get_viewport().get_camera_3d() if _d.is_inside_tree() else null
	_view_cam = cam if cam != null and cam.is_inside_tree() else null
	if _view_cam != null:
		_view_pos = _view_cam.global_position
		_view_planes.assign(_view_cam.get_frustum())
	_aim_rays.clear()
	for n: Node in _d.get_tree().get_nodes_in_group(G.CREW):
		var c: CrewController = n as CrewController
		if c != null and c.is_inside_tree():
			_aim_rays.append(c.eye_position())
			_aim_rays.append(c.aim_direction().normalized())
