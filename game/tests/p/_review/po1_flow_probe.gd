## Diagnostic: MenuFlow.launch (Net.start_solo + in-heist UI) then hold mask_up. Owner: ENV P.
extends Node


func _ready() -> void:
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child.call_deferred(flow)
	await get_tree().process_frame
	await get_tree().process_frame
	flow.launch(&"glasshouse", Enums.Difficulty.ROUTINE, CrewWeapons.build_loadout(null).duplicate() as Loadout, 1002)
	while flow.runtime == null:
		await get_tree().process_frame
	var c: CrewController = flow.runtime.crew_controller(Net.local_slot()) as CrewController
	for _i: int in 30:
		await get_tree().physics_frame
	var inp: PInputDriver = PInputDriver.new(self)
	inp.key(KEY_G, true)
	var peak: float = 0.0
	for _i: int in 240:
		await get_tree().physics_frame
		peak = maxf(peak, c.mask_progress)
		if c.masked:
			break
	inp.release_all()
	print("[PO1] masked=%s peak=%.2f authority=%s" % [c.masked, peak, Net.is_authority()])
	get_tree().quit()
