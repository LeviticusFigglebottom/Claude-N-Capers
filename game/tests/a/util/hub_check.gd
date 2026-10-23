## C4-03 hub check (LEAD): B6-06's 3D safehouse mode (MenuFlow / SafehouseHost) on C's REAL staged scene
## (safehouse_g1.tscn) with ENV A's hub crew (A3-11 CrewController.spawn_for_hub), run on one peer: the walker spawns
## at the entry marker, a station is pressed through the crew's own interaction (aim + interact) and opens its screen,
## Back returns the walker to the station's UsePoint, and leave(marker) + enter() spawns at ReturnRange /
## ReturnHeist / the Spawn fallback. The host test runs it locally and on the client process (LoopbackProbe
## "hub_check") while the ENet session is up, so it also proves the hub does not depend on being the authority.
## Off the authority the check ticks the crew's HubInteraction itself (`ticked_by_check`): CrewController (P) ticks
## interactions in its authority branch only, so a connected client's hub stations need P's one-line change too.
## Returns plain data (it travels in an RPC report).
class_name HubCheck
extends RefCounted

const SCENE: String = "res://world/hub/safehouse/safehouse_g1.tscn"
const MAP_CLASS: StringName = &"SafehouseMap"
const FLOW_SCENE: String = "res://content/ui/menus/menu_flow.tscn"
const HUB_KEY: StringName = &"safehouse_hub"
const STATION: StringName = &"armory"


## `root_dir`: this peer's own profile directory (host and client share user://).
static func run(parent: Node, root_dir: String) -> Dictionary:
	var tree: SceneTree = parent.get_tree()
	var out: Dictionary = {"authority": Net.is_authority(), "peers": tree.root.multiplayer.get_peers().size()}
	var old_root: String = SaveService.root_dir
	var old_mode: Variant = GameSettings.current().get_value(GameSettings.CONTROLS, HUB_KEY)
	SaveService.root_dir = root_dir
	SaveService.delete_profile(0)
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	GameSettings.current().set_value(GameSettings.CONTROLS, HUB_KEY, "walk")
	var f: MenuFlow = (load(FLOW_SCENE) as PackedScene).instantiate() as MenuFlow
	var t: SafehouseHubTweak = SafehouseHubTweak.load_default().duplicate() as SafehouseHubTweak
	t.scene_path = SCENE
	t.map_class = MAP_CLASS
	t.station_cam_blend_s = 0.0
	parent.add_child(f)
	f.safehouse.tweak = t
	await tree.process_frame
	f.main_menu.safehouse_button.pressed.emit()
	for _i: int in 6:
		await tree.physics_frame
	var sh: SafehouseHost = f.safehouse
	out["active"] = sh.is_active()
	var c: CrewController = sh.walker as CrewController
	out["hub_crew"] = c != null
	if c == null:
		await _cleanup(f, old_root, old_mode)
		return out
	out["civilian"] = c.civilian and not c.masked
	out["spawn_m"] = _flat(c.global_position, _marker(sh, "Spawns/ReturnHeist"))
	out["stations"] = sh.stations().size()
	# The armory through the crew's own interaction: stand on its UsePoint, aim at the Interactable, press.
	var st: Node3D = sh.station_node(STATION) as Node3D
	var up: Node3D = st.get_node_or_null(^"UsePoint") as Node3D if st != null else null
	var it: Node3D = st.get(&"interactable") as Node3D if st != null else null
	out["station_found"] = up != null and it != null
	if up != null and it != null:
		c.set_input_paused(true)
		c.global_transform = up.global_transform
		for _i: int in 4:
			await tree.physics_frame
		var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), it.global_position)
		c.apply_intent(aim)
		for _i: int in 3:
			await tree.physics_frame
		var press: CrewIntent = BotUtil.look_at_intent(c.eye_position(), it.global_position)
		press.interact = true
		c.apply_intent(press)
		# Off the authority CrewController never ticks its HubInteraction (its interaction tick is server-only;
		# P's part of the C4-03 fix): stand in for that tick so the LOCAL InteractionSystem (A) is proven here.
		out["ticked_by_check"] = not Net.is_authority()
		if not Net.is_authority() and c.hub_interaction != null:
			c.hub_interaction.local = true
		for _i: int in 4:
			if not Net.is_authority() and c.hub_interaction != null:
				c.hub_interaction.tick(c, press, tree.root.get_physics_process_delta_time())
			await tree.physics_frame
		out["screen"] = String(f.current.name) if f.current != null else "-"
		out["station_id"] = String(sh.station_id)
		out["opened"] = f.loadout_screen != null and f.current == (f.loadout_screen as Control) and sh.input_paused
		if f.loadout_screen == null:
			await _cleanup(f, old_root, old_mode)
			return out
		f.loadout_screen.back_button.pressed.emit()
		for _i: int in 4:
			await tree.physics_frame
		out["back_hud"] = f.current == (sh.hud as Control) and not sh.input_paused
		out["back_m"] = _flat(c.global_position, up.global_position)
	for m: StringName in [&"ReturnRange", &"ReturnHeist", &"NoSuchMarker"]:
		sh.leave(m)
		await tree.process_frame
		sh.enter()
		for _i: int in 3:
			await tree.physics_frame
		var w: Node3D = sh.walker as Node3D
		var expect: String = "Spawns/Spawn" if m == &"NoSuchMarker" else "Spawns/" + String(m)
		out["return_%s_m" % m] = _flat(w.global_position, _marker(sh, expect)) if w != null else -1.0
	await _cleanup(f, old_root, old_mode)
	return out


static func _cleanup(f: MenuFlow, old_root: String, old_mode: Variant) -> void:
	var tree: SceneTree = f.get_tree()
	f.queue_free()
	await tree.process_frame
	SaveService.delete_profile(0)
	SaveService.root_dir = old_root
	GameSettings.current().set_value(GameSettings.CONTROLS, HUB_KEY, old_mode)


static func _marker(sh: SafehouseHost, path: String) -> Vector3:
	var n: Node3D = sh.map.get_node_or_null(NodePath(path)) as Node3D if sh.map != null else null
	return n.global_position if n != null else Vector3.INF


static func _flat(a: Vector3, b: Vector3) -> float:
	if b == Vector3.INF:
		return -1.0
	return Vector2(a.x - b.x, a.z - b.z).length()
