## OF-D1 QC-67 windowed check on C's Ostrander Federal map: the tellers at their stations (teller_count, hands on the
## worktop behind the bandit screen), seen from the teller side and the customer side, then the alarm and the
## civilians at the five cower points (cower_stand; back-bag looks stand their cower_offsets.json offset forward).
## Logs every teller / cowering civilian with its clip, its distance to the nearest station / cower point and its
## facing. PNGs and log go to --out.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 960x540 --path game res://world/characters/_tools/render_of_qc67_review.tscn \
##     -- --out=/abs/dir [--seed=1] [--no-alarm]   (--no-alarm: tellers + queue only, no cower phase)
## Owner: ENV D.
extends Node3D

## Teller stations (x, z) and cower points (name: position, facing deg) from ostrander_federal_layout_content.gd.
const TELLERS: Array[Vector3] = [Vector3(15.0, 0.0, 16.07), Vector3(17.0, 0.0, 16.07), Vector3(31.0, 0.0, 16.07),
	Vector3(33.0, 0.0, 16.07)]
## Queue marks (CivQueueW/E, the queue_idle spawn rows stand near them)
const QUEUES: Array[Vector3] = [Vector3(15.0, 0.0, 21.0), Vector3(33.0, 0.0, 21.0)]
const COWER: Dictionary = {
	"CowerCounterW": Vector3(12.0, 0.0, 17.66), "CowerCounterE": Vector3(36.0, 0.0, 17.66),
	"CowerWallW": Vector3(8.31, 0.0, 30.5), "CowerWallE": Vector3(39.69, 0.0, 31.0),
	"CowerPillar": Vector3(19.0, 0.0, 20.46),
}
## Camera eye per cower point: in front of it (the side it faces), 3 m out, 1.5 m up.
const COWER_EYE: Dictionary = {
	"CowerCounterW": Vector3(12.0, 1.5, 20.6), "CowerCounterE": Vector3(36.0, 1.5, 20.6),
	"CowerWallW": Vector3(11.3, 1.5, 30.5), "CowerWallE": Vector3(36.7, 1.5, 31.0),
	"CowerPillar": Vector3(19.0, 1.5, 23.4),
}

var _out: String = ""
var _seed: int = 1
var _alarm: bool = true
var _cam: Camera3D = null
var _log: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a == "--no-alarm":
			_alarm = false
	if _out == "":
		_out = OS.get_user_data_dir() + "/of_qc67"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"ostrander_federal", _seed, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0})
	if rt == null:
		push_error("[QC67] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 60.0
	_cam.current = true
	await _ticks(120)
	_say("seed %d" % _seed)
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		var d: float = _nearest(npc.global_position, TELLERS)
		if d < 1.5:
			_say("teller %s tags %s look %s clip %s at %s station %.2f m facing %.0f" % [npc.name,
				npc.spawn_info.get("tags"), NpcVisuals.character_id(npc), _clip(npc), npc.global_position, d,
				rad_to_deg(npc.global_rotation.y)])
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		var dq: float = _nearest(npc.global_position, QUEUES)
		if dq < 3.0:
			_say("queue %s activity %s look %s clip %s at %s mark %.2f m" % [npc.name, npc.spawn_info.get("idle_activity"),
				NpcVisuals.character_id(npc), _clip(npc), npc.global_position, dq])
	await _shot("tellers_w_staff_side", Vector3(14.2, 1.65, 14.4), Vector3(16.0, 0.95, 16.3))
	await _shot("tellers_w_customer_side", Vector3(16.0, 2.05, 19.6), Vector3(16.0, 1.0, 16.1))
	await _shot("tellers_e_staff_side", Vector3(34.8, 1.65, 14.4), Vector3(32.0, 0.95, 16.3))
	await _shot("tellers_e_customer_side", Vector3(32.0, 2.05, 19.6), Vector3(32.0, 1.0, 16.1))
	await _shot("teller_counter_profile", Vector3(18.6, 1.15, 16.4), Vector3(14.5, 1.0, 16.2))
	await _shot("queue_w_side", Vector3(19.5, 1.6, 22.5), Vector3(15.0, 0.9, 20.0))
	if not _alarm:
		_finish()
		return
	rt.stealth.raise_alarm(&"qc67_review")
	await _ticks(480)
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		var best: String = ""
		var bd: float = INF
		for k: String in COWER:
			var dd: float = Vector2(npc.global_position.x, npc.global_position.z).distance_to(
				Vector2((COWER[k] as Vector3).x, (COWER[k] as Vector3).z))
			if dd < bd:
				best = k
				bd = dd
		if bd < 2.5:
			_say("cower %s near %s %.2f m look %s clip %s facing %.0f" % [npc.name, best, bd,
				NpcVisuals.character_id(npc), _clip(npc), rad_to_deg(npc.global_rotation.y)])
	for k: String in COWER:
		var p: Vector3 = COWER[k]
		await _shot("cower_%s" % k.trim_prefix("Cower").to_lower(), COWER_EYE[k], p + Vector3(0.0, 0.7, 0.0))
	await _shot("tellers_w_after_alarm", Vector3(14.2, 1.65, 14.4), Vector3(16.0, 0.8, 16.3))
	_finish()


func _finish() -> void:
	var f: FileAccess = FileAccess.open("%s/qc67_log.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[QC67] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _clip(npc: NpcBase) -> String:
	var ad: AnimDriver = AnimDriver.of(npc)
	return String(ad.choose_clip()) if ad != null else "-"


func _nearest(p: Vector3, pts: Array[Vector3]) -> float:
	var best: float = INF
	for q: Vector3 in pts:
		best = minf(best, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
	return best


func _shot(name: String, eye: Vector3, at: Vector3) -> void:
	_cam.look_at_from_position(eye, at)
	for _i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [_out, name])
	_say("shot %s" % name)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _say(s: String) -> void:
	_log.append(s)
	print("[QC67] " + s)
