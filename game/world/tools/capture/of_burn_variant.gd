## Review-shot helper (OF-C2 lane C, ENV C): writes a TEST-ONLY copy of Ostrander Federal with the burn-through set
## piece in its end state (BurnAnim "burnt": shown, debris at rest, the ember glow), the lid prefab hidden
## (`Gameplay/Devices/Lid`; the mission set_enabled(false)s it at the burn, ENV A's OF-A6 hook) and, with --drops, the drill-drop heli
## hovering over the terrace and the second van parked in Ledger Lane. The shipped scene is never touched.
##   /opt/godot/godot --headless --path game --script res://world/tools/capture/of_burn_variant.gd -- \
##     [--out=user://of_burn_test.tscn] [--drops]
## then render it: tools/levelcheck/render_shots.sh ostrander_federal g2 --scene=user://of_burn_test.tscn \
##     --out=<dir> --cameras=rc_vault_hole,rc_teller_workroom
extends SceneTree

const SCENE: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
## The lid prefab (its Plug and Visual/LidPanel): the mission set_enabled(false)s it at the burn; hidden in the test copy only.
const LID_PATHS: Array[String] = ["Gameplay/Devices/Lid"]


func _initialize() -> void:
	var out: String = "user://of_burn_test.tscn"
	var drops: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--drops":
			drops = true
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		push_error("of_burn_variant: cannot load %s" % SCENE)
		quit(2)
		return
	var root: Node = ps.instantiate()
	var burn: Node3D = root.get_node_or_null("Props/DressC/BurnThrough") as Node3D
	if burn == null:
		push_error("of_burn_variant: no Props/DressC/BurnThrough")
		quit(2)
		return
	_end_state(root, burn, "BurnAnim", &"burnt")
	for p: String in LID_PATHS:
		var n: Node3D = root.get_node_or_null(p) as Node3D
		if n != null:
			n.visible = false
		else:
			print("of_burn_variant: %s not found (the lid prefab moved it?)" % p)
	if drops:
		var heli: Node3D = root.get_node_or_null("Props/DressC/DrillDropHeli") as Node3D
		if heli != null:
			_at_time(root, heli, "DropAnim", &"drop", 9.0)
		var van: Node3D = root.get_node_or_null("Props/DressC/DrillDropVan") as Node3D
		if van != null:
			_end_state(root, van, "DropAnim", &"parked")
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, out)
	root.free()
	print("of_burn_variant: wrote %s (%d)" % [out, err])
	quit(0 if err == OK else 1)


## Applies the last key of every track of `anim` (value tracks) to the nodes under `host`.
func _end_state(scene_root: Node, host: Node3D, player: String, anim: StringName) -> void:
	var ap: AnimationPlayer = host.get_node(player) as AnimationPlayer
	var a: Animation = ap.get_animation(anim)
	_apply(scene_root, host, a, a.length)


## Applies every value track of `anim` sampled at `t` (the heli mid-hover).
func _at_time(scene_root: Node, host: Node3D, player: String, anim: StringName, t: float) -> void:
	var ap: AnimationPlayer = host.get_node(player) as AnimationPlayer
	_apply(scene_root, host, ap.get_animation(anim), t)


func _apply(scene_root: Node, host: Node3D, a: Animation, t: float) -> void:
	for i: int in range(a.get_track_count()):
		var path: NodePath = a.track_get_path(i)
		var node: Node = host.get_node_or_null(NodePath(String(path.get_concatenated_names())))
		if String(path.get_concatenated_names()) == ".":
			node = host
		if node == null:
			continue
		var prop: StringName = StringName(String(path.get_concatenated_subnames()))
		var v: Variant = a.value_track_interpolate(i, t)
		node.set(prop, v)
		if node != host and node.owner != scene_root:
			scene_root.set_editable_instance(node.owner if node.owner != null else node, true)
