p = 'game/world/heists/dockside_burn/dockside_burn_mission.gd'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:70]
    s = s.replace(a, b, 1)


rep("""		_set_enabled(crates, false)
		crates.visible = false
	update_objective_data(&"containers", {"count": _weapons.size()})""", """		_set_enabled(crates, false)
		crates.visible = false
	for k4: String in CONTAINER_KEYS:
		var latch: Node = get_node_or_null(NodePath(String(CRATES) + "/Latch" + k4.to_upper()))
		if latch != null and latch.has_signal(&"opened"):
			latch.connect(&"opened", _open_container.bind(k4))
	update_objective_data(&"containers", {"count": _weapons.size()})""")
rep("""	_apply_entry_and_perch()
	_schedule_police()""", """	_apply_entry_and_perch()
	_watch_entry_doors()
	_schedule_police()""")
rep("""## Cartel phase, then the police""", """## A building entry door opening (lockpicked, its padlock picked or sawn, breached) is the breach.
## Connected after _apply_entry_and_perch so the variant's open door does not count.
func _watch_entry_doors() -> void:
	for tag: StringName in ENTRY_TAGS:
		for d: Node in find_tagged(tag):
			if d.has_signal(&"open_changed") and not d.is_connected(&"open_changed", _on_entry_door):
				d.connect(&"open_changed", _on_entry_door)


func _on_entry_door(open: bool, _by_net_id: int) -> void:
	if open:
		_breach()


## Cartel phase, then the police""")
rep("""func _on_device_started(device_net_id: int, _kind: StringName, _duration: float) -> void:""",
    """func _on_device_started(device_net_id: int, _kind: StringName, duration: float) -> void:""")
rep("""		if not _burn_started:
			_burn_started = true
			say(&"vo.mercer.dockside_burn_burn_started")""", """		if not _burn_started:
			_burn_started = true
			say(&"vo.mercer.dockside_burn_burn_started")
			# The burn_point's telegraph starts when the burn ends: Mercer calls the shutters with it.
			start_timer(&"burn_warning", maxf(duration, 0.0), _on_burn_warning)""")
rep("""	elif _is_tagged(device_net_id, TAG_PADLOCK):
		_breach()
	else:
		_check_container(device_net_id)""", """	elif _is_tagged(device_net_id, TAG_PADLOCK):
		_breach()""")
rep("""## A container padlock was cut: crates for a weapons container, nothing for the others.
func _check_container(device_net_id: int) -> void:
	for k: String in CONTAINER_KEYS:
		if not _is_tagged(device_net_id, StringName("padlock_" + k)):
			continue
		if not _weapons.has(k):
			say(&"vo.mercer.dockside_burn_containers_hint")
			return
		var crates: Node3D = get_node_or_null(NodePath(String(CRATES) + "/Crates" + k.to_upper())) as Node3D
		if crates != null:
			crates.visible = true
			_set_enabled(crates, true)
		say(&"vo.mercer.dockside_burn_weapons_found")
		if not _weapons_found:
			_weapons_found = true
			complete(&"containers")
		return""", """## A container's padlock came off (picked or sawn; its latch opened): crates for a weapons container,
## nothing for the others.
func _open_container(k: String) -> void:
	if not _weapons.has(k):
		say(&"vo.mercer.dockside_burn_containers_hint")
		return
	var crates: Node3D = get_node_or_null(NodePath(String(CRATES) + "/Crates" + k.to_upper())) as Node3D
	if crates != null:
		crates.visible = true
		_set_enabled(crates, true)
	say(&"vo.mercer.dockside_burn_weapons_found")
	if not _weapons_found:
		_weapons_found = true
		complete(&"containers")""")
rep("""## Burn done (D-064 Q6): warning, a 5 s countdown, then the shutters of the burning room drop and
## its fire volume goes live. TODO(QC-38): the fire volume's damage (DoT, ignores armour) is ENV A's
## burn_point; G1 marks it active only.
func _on_burn_done() -> void:
	if _burned:
		return
	_burned = true
	say(&"vo.mercer.dockside_burn_burn_done", {"shutters_in_s": SHUTTER_WARNING_S})
	update_objective_data(&"burn", {"shutters_in_s": SHUTTER_WARNING_S})
	start_timer(&"fire_shutters", SHUTTER_WARNING_S, _drop_shutters)
	complete(&"burn")
	_try_escape()""", """## The burn ended and the burn_point's telegraph runs (cue.burn_warning, burn_warning_s): Mercer
## calls the shutters.
func _on_burn_warning() -> void:
	if _burned:
		return
	say(&"vo.mercer.dockside_burn_burn_done", {"shutters_in_s": SHUTTER_WARNING_S})
	update_objective_data(&"burn", {"shutters_in_s": SHUTTER_WARNING_S})


## Burn done (D-064 Q6): the burn_point lit its fire volume (device_finished, after its telegraph):
## the burning room's fire shutters drop and bar now.
func _on_burn_done() -> void:
	if _burned:
		return
	_burned = true
	_drop_shutters()
	complete(&"burn")
	_try_escape()""")
rep("""		d.call(&"set_open", false)
		_set_enabled(d, false)
		if d.has_method(&"bar"):
			d.call(&"bar")  # TODO(QC-38): door re-lock (BARRED) API; G1 disables the interaction.
	var fv: Node = get_node_or_null(NodePath(String(PRODUCT_GROUP) + "/Slot_" + sid + "/FireVolume"))
	if fv != null:
		fv.set_meta(&"active", true)""", """		# Fire shutter: locked BARRED before it closes, so the close also drops its NavLink.
		d.set(&"lock", Door.Lock.BARRED)
		d.set(&"locked", true)
		d.call(&"set_open", false)
		_set_enabled(d, false)""")
rep("""const PRODUCT_GROUP: NodePath = ^"../Variants/Group_product_location"
""", "")
open(p, 'w').write(s)
print("ok")
