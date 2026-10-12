extends TestCase


func test_probe_scout2() -> void:
	for pair: Array in [["night_deposit", 2001, [&"vault_gate", &"vault_door", &"time_lock", &"keycard", &"code_note", &"escape_van", &"escape_boat", &"antechamber_lasers"]],
			["shadow_ledger", 2001, [&"server_door", &"server_reader", &"cage", &"cage_gate", &"hack", &"laptop", &"study_door", &"escape_heli", &"escape_line", &"escape_service", &"art_hall_lasers"]]]:
		var rt: HeistRuntime = await HeistLauncher.launch(StringName(pair[0]), int(pair[1]), Enums.Difficulty.ROUTINE, self, {"ai_teammates": 3})
		await wait_physics_frames(5)
		print("SCOUT ===== %s" % pair[0])
		var c0: CrewController = rt.crew_controller(0) as CrewController
		print("SCOUT loadout p=%s s=%s dep=%s eqslot=%s" % [c0.loadout.primary, c0.loadout.secondary, c0.loadout.deployable, c0.weapons.equipped_slot])
		for tag: StringName in pair[2]:
			for n: Node in rt.find_by_tag(tag):
				var s: String = "SCOUT tag %s: %s (%s) @ %s basis_z %s" % [tag, n.name, n.get_class(), (n as Node3D).global_position, (n as Node3D).global_basis.z]
				if n.get_script() != null:
					s += " script=%s" % (n.get_script() as Script).resource_path.get_file()
				if n is Door:
					s += " lock=%d locked=%s open=%s" % [(n as Door).lock, (n as Door).locked, (n as Door).is_open]
				if n is GameplayPrefab and (n as GameplayPrefab).use_point != null:
					s += " use=%s" % (n as GameplayPrefab).use_point.global_position
				var it: Node = n.get_node_or_null(^"Interactable")
				if it != null:
					s += " kind=%s enabled=%s req=%s" % [it.get(&"kind"), it.get(&"enabled"), it.get(&"requires_item")]
				print(s)
		for n: Node in get_tree().get_nodes_in_group(G.BODY_HIDE_ZONE):
			if rt.is_ancestor_of(n):
				print("SCOUT bodyhide %s center %s" % [n.name, BotUtil.zone_center(n as Area3D)])
		for n: Node in rt.npcs():
			var npc: NpcBase = n as NpcBase
			print("SCOUT npc %s %s fwd %s" % [npc.name, npc.global_position, npc.look_forward()])
		rt.teardown()
		await wait_frames(2)
