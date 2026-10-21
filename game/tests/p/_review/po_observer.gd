## Fresh-eyes product-owner pass (lead 2026-10-14): rides along ENV A's PO-5 playthrough (po5_runner.tscn,
## unchanged) and records what a player would call odd. Launch this scene instead of po5_runner.tscn with the
## same --po5-* arguments plus --obs-out=/abs/dir [--obs-every=4] (heist seconds between frames):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/p/_review/po_observer.tscn -- --po5-flow=gh_stealth --po5-out=DIR --po5-heist=Glasshouse --obs-out=DIR
## It never touches game state or input. Logged ([OBS] lines + <obs-out>/observer.log, heist time t):
## - FRAME: a rendered screenshot every --obs-every heist seconds (the runner's fast mode does not render);
## - BUNCH: two live NPCs closer than 0.35 m (overlap / bunching);
## - PROMPT_AIM: an interaction prompt is up for a component that is far (> 3.5 m) or off the aim (> 35 deg);
## - FLICKER: the interaction prompt toggles on/off more than 6 times in a second;
## - CREW_STACK: two AI teammates closer than 0.5 m, or one inside the player (< 0.6 m);
## - CREW (every 10 s while enemies are near): AI teammates' mean
##   spacing, distance to the player and the share in clear line of sight of the nearest enemy (exposed);
## - PROMPT: every distinct interaction prompt key shown (verb check);
## - SFX_PLACEHOLDER: a cue with no definition played (the placeholder beep); SFX_SPAM: one cue > 8 times / s;
## Hitches: read the runner's own HITCH lines (FrameProf); Performance.TIME_PROCESS only updates on drawn frames.
## Owner: ENV P.
extends Node

const BUNCH_M: float = 0.35
const PROMPT_FAR_M: float = 3.5
const PROMPT_ANGLE_DEG: float = 35.0
const FLICKER_TOGGLES: int = 6
const SPAM_PER_S: int = 8

var _out: String = ""
var _every: float = 4.0
var _log: FileAccess = null
var _next_frame_t: float = 0.0
var _check_t: float = 0.0
var _capturing: bool = false
var _n_frames: int = 0
var _rt: HeistRuntime = null
var _cues: CuePlayer = null
var _last_count: int = 0
var _cue_times: Dictionary[StringName, Array] = {}
var _placeholder_seen: Dictionary[StringName, bool] = {}
var _prompt_up: bool = false
var _toggles: Array[float] = []
var _bunch_seen: Dictionary[String, float] = {}
var _prompt_seen: Dictionary[String, float] = {}
var _prompt_keys: Dictionary[StringName, bool] = {}
var _stack_seen: Dictionary[String, float] = {}
var _crew_t: float = 0.0
var _crew_samples: int = 0
var _crew_exposed: int = 0
var _crew_spacing: float = 0.0
var _crew_dist: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000  # before the PO-5 driver resets FrameProf for the frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--obs-out="):
			_out = a.substr(10)
		elif a.begins_with("--obs-every="):
			_every = maxf(a.substr(12).to_float(), 0.5)
	if _out == "":
		_out = OS.get_user_data_dir() + "/po_observer"
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out + "/observer.log", FileAccess.WRITE)


func _note(kind: String, msg: String) -> void:
	var t: float = _rt.heist_time_s if _rt != null and is_instance_valid(_rt) else -1.0
	var line: String = "[OBS t=%.1f] %s %s" % [t, kind, msg]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _process(delta: float) -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt != _rt:
		_rt = rt
		_cues = null
		_next_frame_t = 0.0
		if rt != null:
			_note("HEIST", "runtime up (%s)" % rt.heist_id)
	if _rt == null or not is_instance_valid(_rt):
		return
	_check_sfx()
	_check_flicker()
	_check_t += delta
	if _check_t >= 0.5:
		_check_t = 0.0
		_check_bunch()
		_check_prompt()
		_check_crew()
	if not _capturing and _rt.heist_time_s >= _next_frame_t:
		_next_frame_t = _rt.heist_time_s + _every
		_capture()


func _driver_fast() -> bool:
	var d: Node = get_tree().root.get_node_or_null(^"PO5Driver")
	return d != null and bool(d.get(&"fast"))


func _capture() -> void:
	_capturing = true
	var was_on: bool = RenderingServer.render_loop_enabled
	RenderingServer.render_loop_enabled = true
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n_frames += 1
	var t: float = _rt.heist_time_s if _rt != null and is_instance_valid(_rt) else -1.0
	var path: String = "%s/obs_%03d_t%04d.png" % [_out, _n_frames, int(t)]
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path(path))
	_note("FRAME", path.get_file())
	if not was_on:
		RenderingServer.render_loop_enabled = not _driver_fast()  # the driver may have switched meanwhile
	_capturing = false


func _check_sfx() -> void:
	if _cues == null or not is_instance_valid(_cues):
		_cues = _find_cues()
		if _cues == null:
			return
		_last_count = _cues.play_count
	if _cues.play_count == _last_count:
		return
	_last_count = _cues.play_count
	var cue: StringName = _cues.last_cue
	var now: float = Time.get_ticks_msec() / 1000.0
	var ts: Array = _cue_times.get(cue, [])
	ts.append(now)
	while not ts.is_empty() and now - float(ts[0]) > 1.0:
		ts.pop_front()
	_cue_times[cue] = ts
	if ts.size() > SPAM_PER_S:
		_note("SFX_SPAM", "%s x%d in 1 s" % [cue, ts.size()])
		ts.clear()
	if not _placeholder_seen.has(cue) and AudioCueLib.resolve(_cues.registry, cue) == null:
		_placeholder_seen[cue] = true
		_note("SFX_PLACEHOLDER", "cue %s has no definition (placeholder beep)" % cue)


func _find_cues() -> CuePlayer:
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CuePlayer:
			return n as CuePlayer
		stack.append_array(n.get_children())
	return null


func _check_flicker() -> void:
	if _rt.hud_model == null:
		return
	var up: bool = not _rt.hud_model.interaction.is_empty()
	if up:
		var key: StringName = StringName(_rt.hud_model.interaction.get("text_key", &""))
		if key != &"" and not _prompt_keys.has(key):
			_prompt_keys[key] = true
			_note("PROMPT", "%s on %s" % [key, _aimed_name()])
	if up == _prompt_up:
		return
	_prompt_up = up
	var now: float = Time.get_ticks_msec() / 1000.0
	_toggles.append(now)
	while not _toggles.is_empty() and now - _toggles[0] > 1.0:
		_toggles.pop_front()
	if _toggles.size() > FLICKER_TOGGLES:
		_note("FLICKER", "interaction prompt toggled %d times in 1 s (now %s)" % [_toggles.size(),
			_rt.hud_model.interaction.get("text_key", &"")])
		_toggles.clear()


func _check_bunch() -> void:
	var npcs: Array[Node] = _rt.npcs()
	for i: int in npcs.size():
		var a: Node3D = npcs[i] as Node3D
		for j: int in range(i + 1, npcs.size()):
			var b: Node3D = npcs[j] as Node3D
			var d: Vector3 = a.global_position - b.global_position
			if absf(d.y) < 1.0 and Vector2(d.x, d.z).length() < BUNCH_M:
				var key: String = "%s|%s" % [a.name, b.name]
				if _rt.heist_time_s - float(_bunch_seen.get(key, -99.0)) > 10.0:
					_bunch_seen[key] = _rt.heist_time_s
					_note("BUNCH", "%s and %s %.2f m apart at %s" % [a.name, b.name, Vector2(d.x, d.z).length(),
						a.global_position.snappedf(0.1)])


func _check_prompt() -> void:
	if _rt.hud_model == null or _rt.hud_model.interaction.is_empty() or _rt.interaction == null:
		return
	var c: CrewController = _rt.crew_controller(Net.local_slot()) as CrewController
	if c == null or not _rt.interaction.has_method(&"aimed_component"):
		return
	var comp: Node = _rt.interaction.call(&"aimed_component", c) as Node
	if comp == null:
		return
	var host: Node3D = comp as Node3D if comp is Node3D else comp.get_parent() as Node3D
	if host == null:
		return
	var eye: Vector3 = c.eye_position()
	var to: Vector3 = host.global_position - eye
	var ang: float = rad_to_deg(c.aim_direction().angle_to(to)) if to.length() > 0.01 else 0.0
	if to.length() > PROMPT_FAR_M or ang > PROMPT_ANGLE_DEG:
		var key: String = String(host.get_path())
		if _rt.heist_time_s - float(_prompt_seen.get(key, -99.0)) > 15.0:
			_prompt_seen[key] = _rt.heist_time_s
			_note("PROMPT_AIM", "'%s' for %s at %.1f m, %.0f deg off aim" % [
				_rt.hud_model.interaction.get("text_key", &""), host.name, to.length(), ang])


## AI teammates: stacking (pairs < 0.5 m) every check; spacing / distance to the player / exposure summed and logged
## every 10 heist s while an enemy is within 30 m.
func _check_crew() -> void:
	var me: CrewController = _rt.crew_controller(Net.local_slot()) as CrewController
	if me == null:
		return
	var bots: Array[CrewController] = []
	for c: CrewController in _rt.crew_members():
		if c.is_ai and c.crew_state == Enums.CrewState.NORMAL:
			bots.append(c)
	for i: int in bots.size():
		for j: int in range(i + 1, bots.size()):
			var d: float = bots[i].global_position.distance_to(bots[j].global_position)
			if d < 0.5:
				var key: String = "%d|%d" % [bots[i].slot, bots[j].slot]
				if _rt.heist_time_s - float(_stack_seen.get(key, -99.0)) > 10.0:
					_stack_seen[key] = _rt.heist_time_s
					_note("CREW_STACK", "AI %d and %d %.2f m apart at %s" % [bots[i].slot, bots[j].slot, d,
						bots[i].global_position.snappedf(0.1)])
	for b: CrewController in bots:
		var dp: float = Vector2(b.global_position.x - me.global_position.x, b.global_position.z - me.global_position.z).length()
		if dp < 0.6 and absf(b.global_position.y - me.global_position.y) < 1.0:
			var pk: String = "p|%d" % b.slot
			if _rt.heist_time_s - float(_stack_seen.get(pk, -99.0)) > 10.0:
				_stack_seen[pk] = _rt.heist_time_s
				_note("CREW_STACK", "AI %d inside the player (%.2f m) at %s" % [b.slot, dp, me.global_position.snappedf(0.1)])
	var enemy: Node3D = null
	var best: float = 30.0
	for n: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var e: Node3D = n as Node3D
		if e != null and _rt.is_ancestor_of(e) and e.global_position.distance_to(me.global_position) < best:
			best = e.global_position.distance_to(me.global_position)
			enemy = e
	if enemy == null or bots.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = me.get_world_3d().direct_space_state
	for b: CrewController in bots:
		_crew_samples += 1
		_crew_dist += b.global_position.distance_to(me.global_position)
		var near: float = INF
		for o: CrewController in bots:
			if o != b:
				near = minf(near, o.global_position.distance_to(b.global_position))
		_crew_spacing += near if near < INF else 0.0
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 1.5,
			b.global_position + Vector3.UP * 1.2)
		q.exclude = [enemy.get_rid(), b.get_rid()] if enemy is CollisionObject3D else [b.get_rid()]
		if space.intersect_ray(q).is_empty():
			_crew_exposed += 1
	if _rt.heist_time_s - _crew_t >= 10.0 and _crew_samples > 0:
		_crew_t = _rt.heist_time_s
		_note("CREW", "AI spacing %.1f m, to player %.1f m, exposed %d%% (%d samples, enemy %.0f m)" % [
			_crew_spacing / _crew_samples, _crew_dist / _crew_samples, 100 * _crew_exposed / _crew_samples,
			_crew_samples, best])
		_crew_samples = 0
		_crew_exposed = 0
		_crew_spacing = 0.0
		_crew_dist = 0.0


## Name of the interactable the local crew aims at (prompt source), "?" when unknown.
func _aimed_name() -> String:
	var c: CrewController = _rt.crew_controller(Net.local_slot()) as CrewController
	if c == null or _rt.interaction == null or not _rt.interaction.has_method(&"aimed_component"):
		return "?"
	var comp: Node = _rt.interaction.call(&"aimed_component", c) as Node
	if comp == null:
		return "?"
	return "%s/%s" % [comp.get_parent().name if comp.get_parent() != null else "", comp.name]
