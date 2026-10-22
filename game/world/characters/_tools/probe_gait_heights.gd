## Hip height and knee bend per locomotion clip (ENV D probe: is a clip "crouchy"?). Prints, per clip, the hips
## joint's min / mean height (m above the root) and the mean knee flexion (deg) of the stance leg over the cycle.
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/probe_gait_heights.gd
## Owner: ENV D.
extends SceneTree

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const CLIPS: Array[String] = ["idle_alert", "crouch_walk", "walk", "walk_fl", "walk_back", "run", "run_fl", "run_fr", "run_l", "run_r",
	"run_bl", "run_br", "run_b", "sprint", "aim_pistol_run", "aim_rifle_run", "hold_pistol_run", "hold_rifle_run"]
const N: int = 24


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root3: Node3D = (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(root3)
	var skel: Skeleton3D = root3.get_node("rig_humanoid/Skeleton3D") as Skeleton3D
	var player: AnimationPlayer = root3.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var hips: int = skel.find_bone("hips")
	for c: String in CLIPS:
		if not player.has_animation(StringName(c)):
			print("PROBE %s missing" % c)
			continue
		var a: Animation = player.get_animation(StringName(c))
		player.play(StringName(c))
		var lo: float = INF
		var sum: float = 0.0
		var knee: float = 0.0
		for i: int in N:
			player.seek(a.length * float(i) / float(N), true)
			await process_frame
			var y: float = skel.get_bone_global_pose(hips).origin.y
			lo = minf(lo, y)
			sum += y
			var kn: float = 0.0
			for s: String in ["L", "R"]:
				var th: Vector3 = skel.get_bone_global_pose(skel.find_bone("thigh." + s)).origin
				var sh: Vector3 = skel.get_bone_global_pose(skel.find_bone("shin." + s)).origin
				var ft: Vector3 = skel.get_bone_global_pose(skel.find_bone("foot." + s)).origin
				kn = maxf(kn, 180.0 - rad_to_deg((th - sh).angle_to(ft - sh)))
			knee += kn
		player.stop()
		print("PROBE %-16s hips min %.3f mean %.3f  max-knee-flex mean %.0f deg" % [c, lo, sum / N, knee / N])
	quit(0)
