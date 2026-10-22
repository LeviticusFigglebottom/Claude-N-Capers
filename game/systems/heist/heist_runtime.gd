# gdlint:disable=max-public-methods
## Root of a running heist: owns the map, the phase machine, services and crew. Owner: ENV A.
## Contracts: test_hooks.md (public API used by LEAD gates), events.md (lifecycle facts),
## heist_map.md (map structure), architecture.md §3-§5 (authority, services, events).
## Gameplay managers are children of this node (not autoloads), so teardown leaves nothing behind.
## Phase machine (A1-01): LOADING -> CASING -> STEALTH -> LOUD -> ESCAPE -> ENDED (S11.2: the
## STEALTH -> LOUD change is a state change only; the same HeistMap instance persists).
class_name HeistRuntime
extends Node

## Server-side fact: a stealth noise event (S4.3). Consumed by the stealth director.
signal noise_made(position: Vector3, radius: float, kind: StringName, source_net_id: int)
signal phase_changed(old_phase: int, new_phase: int)
signal crew_spawned(slot: int, crew: Node)
signal npc_spawned(npc: Node)

const CREW_SCENE: String = "res://systems/player/crew_member.tscn"
const NPC_SCENES: Dictionary = {
	&"guard": "res://systems/ai/npc/npc_guard.tscn",
	&"civilian": "res://systems/ai/npc/npc_civilian.tscn",
	&"police": "res://systems/ai/npc/npc_police.tscn",
	&"cartel": "res://systems/ai/npc/npc_cartel.tscn",
}

## HeistResult.fail_reason values (events.md, D-038 QA-19). &"" on success.
const FAIL_NONE: StringName = &""
const FAIL_STEALTH_ONLY_ALARM: StringName = &"stealth_only_alarm"
const FAIL_ALL_CUSTODY: StringName = &"all_custody"
const FAIL_ABORT: StringName = &"abort"
## A3-09: GUARD SpawnPoints carrying this tag are not spawned at load; HeistMission.spawn_guards()
## spawns them later (timed mission events, e.g. the armoured car's guards).
const SCRIPTED_SPAWN_TAG: StringName = &"scripted"
## S1.3 start modes (HeistDef.start_mode / options["start_mode"]).
const START_CASING: StringName = &"casing"
const START_CIVILIAN: StringName = &"civilian"

static var _current: HeistRuntime = null

var map: HeistMap = null
var phase: Enums.HeistPhase = Enums.HeistPhase.LOADING
var variants: Dictionary = {}
var run_seed: int = 0
var heist_id: StringName = &""
var difficulty: int = Enums.Difficulty.ROUTINE
var difficulty_def: DifficultyDef = null
var options: Dictionary = {}
## D-062 (read-only): the options passed to HeistLauncher.launch() / launch_client(). On a replica the host's
## network-safe options (bring-up `launch_options`, e.g. "music_track") override the client's own.
## S1.3 (D-065): &"casing" (default) or &"civilian": options["start_mode"], else HeistDef.start_mode.
var start_mode: StringName = START_CASING
var launch_options: Dictionary:
	get:
		return _launch_options
## True once the alarm has sounded (stays true through ESCAPE/ENDED).
var went_loud: bool = false
## A5-02 (D-149.1): the active layout id per layout group (ConvoyLayouts; absent / "" = none). Server sets it via
## set_layout, clients follow (HeistNetSync SVC_RUNTIME "layouts").
var layouts: Dictionary = {}
## The "convoy" group's active layout ("" = the convoy has not stopped).
var convoy_layout: String:
	get:
		return String(layouts.get(ConvoyLayouts.DEFAULT_GROUP, ""))
var interaction: InteractionSystem = null
var stealth: StealthDirector = null
var mission: HeistMission = null
var hud_model: LocalHudModel = null
## D-105: ENV C's VfxDirector (shot_fx / explosion_fx effects), one per runtime on every peer.
var vfx: VfxDirector = null
## D-071 per-crew counters (service CrewStatsService.SERVICE).
var stats: CrewStatsService = null
## Container for runtime-spawned entities (NPCs, crew, bags).
var dynamic_root: Node3D = null
## C3 pre-planning assets chosen for this run (A2-07, game/systems/heist/README.md).
var preplan: PreplanAssets = PreplanAssets.new()
## S11.3 STEALTH_ONLY: seconds until heist_ended(failed) after the alarm (-1 = not aborting).
var stealth_abort_left: float = -1.0
## S11.3 HeistDef.mode (STEALTH_OR_LOUD when the map has no HeistDef). Set by start().
var heist_mode: Enums.HeistMode = Enums.HeistMode.STEALTH_OR_LOUD
## A3-09: seconds of heist time since start() (physics delta, so it follows Engine.time_scale).
var heist_time_s: float = 0.0
## A3-07: host/client replication (child `NetSync`, service HeistNetSync.SERVICE, every peer).
var net_sync: HeistNetSync = null
## A3-07: true on a client: this runtime mirrors the host's heist (start() with options["bring_up"]); it never simulates.
var is_replica: bool = false
## A3-07 (client): map paths of the bring-up id table that did not resolve in the local map.
var replica_missing_ids: Array[String] = []
## QB-L2: slot -> effective Loadout (LoadoutModifiers.effective_loadouts), pushed before the crew spawns;
## HeistDropIn replaces a drop-in's slot and pushes again.
var crew_loadouts: Dictionary = {}

## begin_tag_scope() depth, and the shared tag index of the open scope (built at its first lookup).
var _tag_scope: int = 0
var _tag_scope_built: bool = false
var _tag_scope_index: Dictionary = {}
var _crew: Dictionary[int, CrewController] = {}
var _bot_intents: Dictionary[int, CrewIntent] = {}
var _services: Dictionary[StringName, Node] = {}
var _crew_tick_handlers: Array[Callable] = []
var _loot_secured: Array[Dictionary] = []
## B achievements (HeistResult.loot_available): net ids of valued bags that existed this run (spawned or placed).
var _offered_bags: Dictionary[int, bool] = {}
var _small_loot: int = 0
var _pagers_answered: int = 0
var _ended: bool = false
var _launch_options: Dictionary = {}


## Nearest HeistRuntime above `node`, else the current one.
static func of(node: Node) -> HeistRuntime:
	var n: Node = node
	while n != null:
		var rt: HeistRuntime = n as HeistRuntime
		if rt != null:
			return rt
		n = n.get_parent()
	if _current != null and is_instance_valid(_current):
		return _current
	return null


static func current() -> HeistRuntime:
	return _current if _current != null and is_instance_valid(_current) else null


## architecture.md §5: HeistRuntime.get_service(&"stealth").
static func get_service(service_name: StringName) -> Node:
	var rt: HeistRuntime = current()
	if rt != null and rt._services.has(service_name):
		return rt._services[service_name]
	return Services.get_service(service_name) as Node


func _enter_tree() -> void:
	_current = self
	process_physics_priority = -100


func _exit_tree() -> void:
	if _current == self:
		_current = null


# --- Startup (HeistLauncher) ---------------------------------------------------

## Server: build the heist. Returns false on a contract violation (logged).
## A3-07: with `p_options["bring_up"]` (a client, HeistLauncher.join_running) it builds the replica of
## the host's running heist instead (_start_replica); the other arguments then come from the bring-up.
func start(p_heist_id: StringName, map_scene: PackedScene, p_seed: int, p_difficulty: int, p_options: Dictionary) -> bool:
	if p_options.has("bring_up"):
		return _start_replica(p_options["bring_up"] as Dictionary, map_scene, p_options)
	heist_id = p_heist_id
	run_seed = p_seed
	difficulty = p_difficulty
	options = p_options
	_launch_options = p_options
	_resolve_difficulty_def()
	GameRng.begin_run(run_seed)
	var inst: Node = map_scene.instantiate()
	map = inst as HeistMap
	if map == null:
		Log.error(&"heist", "contract violation: map root of '%s' is not a HeistMap" % heist_id)
		inst.free()
		return false
	if map.heist_def != null:
		heist_mode = map.heist_def.mode
	# Dev/test: options["variant_table"] replaces the map's HeistVariantTable for this run (the roll and the
	# mission's rare-event reads); the map scene and its .tres are untouched. Server only (a replica takes the
	# host's resolved variants).
	var vt: HeistVariantTable = options.get("variant_table") as HeistVariantTable
	if vt != null:
		map.variant_table = vt
	# heist_map.md §5: resolve and strip inactive variant content BEFORE anything spawns.
	var slots: Dictionary = VariantResolver.collect_slots(map)
	preplan.setup(options, map.heist_def, heist_id, difficulty)  # C3 (A3-08): PreplanResult, before the roll
	variants = VariantResolver.resolve(map.variant_table, slots, difficulty, preplan.forced_variants())
	var pending: Array = VariantResolver.apply(slots, variants)
	Log.info(&"variants", "seed %d resolved %s" % [run_seed, variants])
	_create_services()
	add_child(map)
	move_child(map, 0)
	if bool(options.get("nav_sync", true)):
		use_sync_navigation(map)
	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	VariantResolver.configure_pending(pending)
	ConvoyLayouts.reset(map)  # A5-02: every layout group off until the mission switches it
	_apply_rare_modifiers()
	preplan.apply_modifiers()  # C3: TEAM sources `asset.<id>`, before the crew reads modifiers
	crew_loadouts = LoadoutModifiers.effective_loadouts(options.get("loadouts", {}), Net.all_slots())
	LoadoutModifiers.push(crew_loadouts)  # QB-L2: skills + perk deck, before the crew spawns
	_claim_map_ids(map)
	RappelLinks.build(map)  # QC-41: one-way rappel links from RAPPEL points
	_spawn_npcs()
	_spawn_crew()
	_apply_dev_options()
	preplan.spawn_drops(map, dynamic_root)  # C3: drop assets at their PREPLAN_POINTs
	_connect_events()
	mission = map.get_node_or_null("Mission") as HeistMission
	if mission == null and map.get_node_or_null("Mission") != null:
		Log.error(&"heist", "contract violation: %s/Mission does not extend HeistMission" % heist_id)
	if mission != null:
		mission._bind(self)
	if heist_mode == Enums.HeistMode.LOUD_ONLY:
		went_loud = true
		for slot: int in _crew:  # S11.3: loud-only heists start masked (no casing)
			_crew[slot].set_masked(true)
		_set_phase(Enums.HeistPhase.LOUD)
	elif bool(options.get("skip_casing", false)):
		_set_phase(Enums.HeistPhase.STEALTH)
	else:
		start_mode = _resolve_start_mode()
		for slot: int in _crew:  # S1.3: civilian-start heists begin without gear
			_crew[slot].civilian = start_mode == START_CIVILIAN
		_set_phase(Enums.HeistPhase.CASING)
	EventBus.heist_loaded.emit(heist_id, run_seed, variants)
	# A3-07: clients emit heist_loaded themselves once their replica is built (_start_replica), so the
	# fact is not relayed here (it would reach them before the bring-up).
	if mission != null:
		mission._on_mission_start()
	return true


## DET (server replay determinism): Godot 4.7 commits navigation map / region changes on worker threads by
## default (navigation/world/map_use_async_iterations, region_use_async_iterations), so a door's NavLink
## toggle, a breach or rappel link, or the map's first build becomes visible to path queries after a
## thread-timing-dependent number of physics frames, and the same seed walks different paths. The heist's
## navigation map and its regions iterate synchronously instead (at the end of the physics frame that changed
## them). Launch option "nav_sync": false keeps the engine default (determinism tests compare both).
static func use_sync_navigation(root: Node3D) -> void:
	if root == null or not root.is_inside_tree():
		return
	var map_rid: RID = root.get_world_3d().navigation_map
	if map_rid.is_valid():
		NavigationServer3D.map_set_use_async_iterations(map_rid, false)
	for n: Node in root.find_children("*", "NavigationRegion3D", true, false):
		var reg: NavigationRegion3D = n as NavigationRegion3D
		NavigationServer3D.region_set_use_async_iterations(reg.get_rid(), false)
		var own_map: RID = reg.get_navigation_map()
		if own_map.is_valid() and own_map != map_rid:
			NavigationServer3D.map_set_use_async_iterations(own_map, false)


func _resolve_start_mode() -> StringName:
	var m: Variant = options.get("start_mode", map.heist_def.start_mode if map.heist_def != null else START_CASING)
	return START_CIVILIAN if m != null and StringName(m) == START_CIVILIAN else START_CASING


# --- Co-op replica (A3-07, docs/contracts/net.md, heist/README.md "Co-op") -----------------------

## Client: build the replica of the host's heist from its bring-up (HeistNetSync.bring_up(), via
## HeistLauncher.join_running -> start() with options["bring_up"]). Same map, the server's resolved
## variants applied (never rolled), map ids adopted from the table, dynamic entities from the
## snapshot. No mission, AI or director logic runs here.
func _start_replica(data: Dictionary, map_scene: PackedScene, p_options: Dictionary) -> bool:
	is_replica = true
	heist_id = StringName(data.get("heist_id", &""))
	run_seed = int(data.get("seed", 0))
	difficulty = int(data.get("difficulty", Enums.Difficulty.ROUTINE))
	options = p_options
	_launch_options = p_options.duplicate()
	_launch_options.erase("bring_up")
	_launch_options.merge(data.get("launch_options", {}) as Dictionary, true)  # D-062: the host's pick wins
	_resolve_difficulty_def()
	GameRng.begin_run(run_seed)
	var inst: Node = map_scene.instantiate()
	map = inst as HeistMap
	if map == null:
		Log.error(&"heist", "contract violation: map root of '%s' is not a HeistMap" % heist_id)
		inst.free()
		return false
	if map.heist_def != null:
		heist_mode = map.heist_def.mode
	variants = (data.get("variants", {}) as Dictionary).duplicate(true)
	var pp: Dictionary = data.get("preplan", {}) as Dictionary
	preplan.setup({"preplan": pp} if not pp.is_empty() else {}, map.heist_def, heist_id, difficulty)
	var pending: Array = VariantResolver.apply(VariantResolver.collect_slots(map), variants)
	_create_services()
	net_sync.token = int(data.get("token", 0))  # C11: keys the heist_closed / heist_left notices
	net_sync.replica_spawned.connect(_on_replica_spawned)
	net_sync.phase_replicated.connect(_on_phase_replicated)
	EventBus.heist_phase_changed.connect(_on_relayed_phase)  # the relayed fact lands before heist_ended
	add_child(map)
	move_child(map, 0)
	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	VariantResolver.configure_pending(pending)
	ConvoyLayouts.reset(map)  # A5-02: every layout group off until the mission switches it
	_apply_rare_modifiers()
	preplan.apply_modifiers()
	_adopt_map_ids(data.get("map_ids", {}) as Dictionary)
	mission = map.get_node_or_null("Mission") as HeistMission  # not bound: the host runs the mission
	heist_time_s = float(data.get("heist_time_s", 0.0))
	went_loud = bool(data.get("went_loud", false))
	phase = int(data.get("phase", Enums.HeistPhase.CASING)) as Enums.HeistPhase
	net_sync.apply_snapshot(data.get("snapshot", {}) as Dictionary)
	hud_model.seed_objectives(data.get("objectives", []) as Array)  # PO-B-C7
	Log.info(&"heist", "replica of %s (seed %d) built: %d map ids, %d missing" % [
		heist_id, run_seed, (data.get("map_ids", {}) as Dictionary).size(), replica_missing_ids.size()])
	EventBus.heist_loaded.emit(heist_id, run_seed, variants)
	return true


## Client (HeistNetSync.replica_spawned): bookkeeping for a replicated dynamic entity.
func _on_replica_spawned(node: Node) -> void:
	var crew: CrewController = node as CrewController
	if crew != null:
		_crew[crew.slot] = crew
		stats.ensure(crew.slot)
		if crew.is_local() and crew.get_node_or_null(^"PlayerInput") == null:
			var pin: PlayerInput = PlayerInput.new()
			pin.name = "PlayerInput"
			crew.add_child(pin)
		crew_spawned.emit(crew.slot, crew)
	var npc: NpcBase = node as NpcBase
	if npc != null:
		npc_spawned.emit(npc)


## Client (HeistNetSync.phase_replicated): the host's phase / alarm state (the EventBus facts
## arrive relayed).
## Server (A5-02, D-149.1): make `id` the active layout of `group` ("" = none): show it and swap in its pre-baked
## nav and cover (ConvoyLayouts.apply); replicated to clients. False (nothing changes) for an id not in the group.
func set_layout(id: String, group: String = ConvoyLayouts.DEFAULT_GROUP) -> bool:
	if not Net.is_authority() or map == null:
		return false
	if not ConvoyLayouts.apply(map, id, group):
		Log.warn(&"heist", "unknown %s layout %s" % [group, id])
		return false
	layouts[group] = id
	Log.info(&"heist", "%s layout %s" % [group, id if id != "" else "<none>"])
	return true


## Server: the convoy stopped in layout `id` (the "convoy" group).
func set_convoy_layout(id: String) -> bool:
	return set_layout(id, ConvoyLayouts.DEFAULT_GROUP)


## Client: the host's active layouts (HeistNetSync).
func apply_replicated_layouts(d: Dictionary) -> void:
	if map == null:
		return
	for g: Variant in d:
		var id: String = String(d[g])
		if String(layouts.get(String(g), "")) != id:
			layouts[String(g)] = id
			ConvoyLayouts.apply(map, id, String(g))


func _on_phase_replicated(new_phase: int, loud: bool) -> void:
	went_loud = went_loud or loud
	if new_phase != phase:
		var old: int = phase
		phase = new_phase as Enums.HeistPhase
		phase_changed.emit(old, new_phase)
		if is_replica and phase == Enums.HeistPhase.ENDED:
			# C11: the heist is over; the local crew stops predicting and sending intents, so none is still
			# in flight when the host tears its heist down (payday Continue) and frees the crew node.
			for c: CrewController in _crew.values():
				if c != null and is_instance_valid(c) and c.is_local():
					c.set_physics_process(false)


## Client: the relayed heist_phase_changed fact, so `phase` is ENDED before the relayed heist_ended
## arrives (the 15 Hz state sync alone lags a few frames behind the facts).
func _on_relayed_phase(_old: int, new_phase: int) -> void:
	if is_replica:
		_on_phase_replicated(new_phase, went_loud or new_phase == Enums.HeistPhase.LOUD)


func _adopt_map_ids(table: Dictionary) -> void:
	replica_missing_ids.clear()
	for k: Variant in table:
		var n: Node = map.get_node_or_null(NodePath(String(k)))
		if n == null:
			replica_missing_ids.append(String(k))
			continue
		NetIds.adopt(n, int(table[k]))
		var bag: LootBag = n as LootBag
		if bag != null:
			bag.freeze = true  # the host simulates bag physics
	if not replica_missing_ids.is_empty():
		Log.error(&"net", "replica of %s: %d map ids do not resolve (map or variants differ): %s" % [
			heist_id, replica_missing_ids.size(), replica_missing_ids.slice(0, 5)])


func _resolve_difficulty_def() -> void:
	difficulty_def = options.get("difficulty_def") as DifficultyDef
	if difficulty_def == null:
		difficulty_def = ContentDB.difficulty(difficulty as Enums.Difficulty)
	if difficulty_def == null:
		difficulty_def = DifficultyDef.new()
		difficulty_def.difficulty = difficulty as Enums.Difficulty


func _create_services() -> void:
	interaction = InteractionSystem.new()
	interaction.name = "InteractionSystem"
	register_service(&"interaction", interaction)
	stealth = StealthDirector.new()
	stealth.name = "StealthDirector"
	register_service(G.SVC_STEALTH, stealth)
	var pagers: PagerSystem = PagerSystem.new()
	pagers.name = "PagerSystem"
	register_service(G.SVC_PAGERS, pagers)
	var loot: LootManager = LootManager.new()
	loot.name = "LootManager"
	register_service(G.SVC_LOOT, loot)
	var codes: CodeRegistry = CodeRegistry.new()  # A2-04 (S9.7): per-run keypad codes
	codes.name = "CodeRegistry"
	register_service(CodeRegistry.SERVICE, codes)
	var director: AssaultDirector = AssaultDirector.new()  # A1-09 (L1.1, L1.4)
	director.name = "AssaultDirector"
	register_service(G.SVC_DIRECTOR, director)
	var ecm: EcmSystem = EcmSystem.new()  # A2-03 (S8.4-S8.6, S5.6)
	ecm.name = "EcmSystem"
	register_service(EcmSystem.SERVICE, ecm)
	var deployables: DeployableSystem = DeployableSystem.new()  # A2-06 (L2.11, S6.2)
	deployables.name = "DeployableSystem"
	register_service(DeployableSystem.SERVICE, deployables)
	var ammo: AmmoPickupSystem = AmmoPickupSystem.new()  # QB-57: enemy ammo drops + walk-over pickup
	ammo.name = "AmmoPickupSystem"
	register_service(AmmoPickupSystem.SERVICE, ammo)
	var hostage_stimuli: HostageStimuli = HostageStimuli.new()  # A2-07 (S6.4)
	hostage_stimuli.name = "HostageStimuli"
	add_child(hostage_stimuli)
	stats = CrewStatsService.new()  # D-071: per-crew counters (HeistResult rows, ui_hud v1.7 crew_stats)
	stats.name = "CrewStatsService"
	register_service(CrewStatsService.SERVICE, stats)
	CrewBuffs.of(self)  # B1 skill keys: timed buffs (replicated) and the kill / hit / bag triggers (server)
	SkillTriggers.of(self)
	var custody: CustodySystem = CustodySystem.new()  # A3-04 (L2.9, L2.10)
	custody.name = "CustodySystem"
	register_service(CustodySystem.SERVICE, custody)
	ShoutSystem.ensure(self)  # A3-04 (L5.1): shouts reach police on maps without civilians too
	var oob: OutOfBoundsSystem = OutOfBoundsSystem.new()  # A3-09 (QC-14): OUT_OF_BOUNDS zones
	oob.name = "OutOfBoundsSystem"
	register_service(OutOfBoundsSystem.SERVICE, oob)
	var barks: BarkDirector = BarkDirector.new()  # D-117 §6 (C8): VO barks, server only, replicated
	barks.name = "BarkDirector"
	register_service(BarkDirector.SERVICE, barks)
	hud_model = LocalHudModel.new()
	hud_model.name = "LocalHudModel"
	add_child(hud_model)
	vfx = VfxDirector.new()  # D-105: ENV C's combat VFX, presentation only, on every peer (host and replica)
	vfx.name = "VfxDirector"
	add_child(vfx)
	_prewarm_vfx()
	net_sync = HeistNetSync.new()  # A3-07: idle in solo
	net_sync.name = HeistNetSync.NODE_NAME
	register_service(HeistNetSync.SERVICE, net_sync)
	if Net.is_authority():
		# QB-B6-DROPIN: the host answers drop-in requests while the heist runs. Deferred: the root is still
		# setting up children at heist start ("parent busy" add_child error otherwise).
		HeistDropIn.ensure.call_deferred(get_tree())
	var factories: Array = options.get("extra_services", [])
	for f: Variant in factories:
		if f is Callable:
			var n: Node = (f as Callable).call(self)
			if n != null and not n.is_inside_tree():
				add_child(n)


## PERF (npc_gunner HITCH): build every VFX pool now, at load, instead of lazily inside the first shots of each kind
## (muzzle flashes, impact sets, decals, blood, lights). Windowed on llvmpipe each new GPU resource waits for the
## frames in flight, which booked 1-22 s stalls to npc_gunner. Rendering peers only (headless draws nothing;
## options.vfx_prewarm forces it). Duck-typed: VfxDirector.prewarm() is ENV C's.
func _prewarm_vfx() -> void:
	var on: bool = DisplayServer.get_name() != "headless"
	if not bool(options.get("vfx_prewarm", on)) or not vfx.has_method(&"prewarm"):
		return
	var t0: int = Time.get_ticks_msec()
	vfx.call(&"prewarm")
	Log.info(&"heist", "vfx prewarm: %d ms" % (Time.get_ticks_msec() - t0))


## Register a manager node (adds it as a child if needed and publishes it in Services).
func register_service(service_name: StringName, node: Node) -> void:
	if node.get_parent() == null:
		add_child(node)
	_services[service_name] = node
	Services.register(service_name, node)


func service(service_name: StringName) -> Node:
	return _services.get(service_name)


## Systems (weapons, shout, bags...) hook per-crew server ticks here: func(crew, intent, delta).
func add_crew_tick_handler(handler: Callable) -> void:
	_crew_tick_handlers.append(handler)


func crew_actions_tick(crew: CrewController, intent: CrewIntent, delta: float) -> void:
	for h: Callable in _crew_tick_handlers:
		if h.is_valid():
			h.call(crew, intent, delta)


func _apply_rare_modifiers() -> void:
	if map.variant_table == null:
		return
	for ev: Dictionary in map.variant_table.rare_events:
		var ev_id: StringName = StringName(ev.get("id", &""))
		if not (variants.get(VariantResolver.RARE_KEY, []) as Array).has(ev_id):
			continue
		var fx: Dictionary = ev.get("effects", {})
		if fx.has("modifier_team"):
			Modifiers.set_source(Modifiers.TEAM, StringName("rare.%s" % ev_id), fx["modifier_team"])


func _claim_map_ids(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n.get(&"net_id") != null and NetIds.of(n) == Ids.INVALID:
			NetIds.claim(n)
		for c: Node in n.get_children():
			stack.append(c)


func _spawn_npcs() -> void:
	for sp_node: Node in map.get_slots(G.GUARD_SPAWN):
		var gsp: SpawnPoint = sp_node as SpawnPoint
		if gsp != null and gsp.tags.has(SCRIPTED_SPAWN_TAG):
			continue  # A3-09: spawned later by the mission (spawn_guards)
		if gsp != null and gsp.tags.has(CartelBrain.SPAWN_TAG):  # QC-36: a cartel post on a GUARD spawn
			var info: Dictionary = spawn_info(gsp)
			info["enemy_def"] = load(CartelBrain.ENEMY_DEF) as EnemyDef
			spawn_npc(CartelBrain.ROLE, gsp.global_transform, info)
			continue
		_spawn_npc_at(&"guard", gsp)
	for sp_node: Node in map.get_slots(G.CIVILIAN_SPAWN):
		_spawn_npc_at(&"civilian", sp_node as SpawnPoint)


## Server: spawn an NPC of `role` at a SpawnPoint (or a transform). Returns the NPC.
func spawn_npc(role: StringName, xform: Transform3D, info: Dictionary = {}) -> NpcBase:
	var path: String = NPC_SCENES.get(role, "")
	var def_scene: Variant = (info["enemy_def"] as EnemyDef).params.get("scene", "") if info.get("enemy_def") is EnemyDef else ""
	if def_scene is String and String(def_scene) != "":  # A3-01: specials pick their scene by EnemyDef
		path = String(def_scene)
	if path == "":
		Log.error(&"heist", "no NPC scene for role %s" % role)
		return null
	# GN-8: through WarmLoader, so this main-thread load never runs beside the director's prewarm loads.
	# LEAD (OF loud GPU hitches): FrameProf books the instancing / setup / tree entry per stage, so a HITCH line names it.
	var fp: int = FrameProf.begin()
	var npc: NpcBase = (WarmLoader.get_or_load(path) as PackedScene).instantiate() as NpcBase
	FrameProf.end(&"spawn_npc.instantiate", fp)
	fp = FrameProf.begin()
	if info.get("enemy_def") is EnemyDef:  # A1-09: per-EnemyDef spawns (director)
		npc.enemy_def = info["enemy_def"] as EnemyDef
	npc.setup_npc(difficulty, info)
	FrameProf.end(&"spawn_npc.setup", fp)
	fp = FrameProf.begin()
	dynamic_root.add_child(npc, true)
	npc.global_transform = xform
	FrameProf.end(&"spawn_npc.enter_tree", fp)
	NetIds.claim(npc)
	npc_spawned.emit(npc)
	return npc


func _spawn_npc_at(role: StringName, sp: SpawnPoint) -> void:
	if sp == null:
		return
	spawn_npc(role, sp.global_transform, spawn_info(sp))


## Spawn info dictionary for an NPC placed at SpawnPoint `sp` (tags, idle activity, patrol graph).
static func spawn_info(sp: SpawnPoint) -> Dictionary:
	return {
		"tags": sp.tags, "idle_activity": sp.idle_activity,
		"patrol_graph": sp.get_node_or_null(sp.patrol_graph) if not sp.patrol_graph.is_empty() else null,
		"spawn_point": sp,
	}


## D-133 harness-only dev option (HeistLauncher.dev_options; never menus / saves): crew_damage_taken_mult on every
## crew slot as a Modifiers source, logged so the evidence names it.
func _apply_dev_options() -> void:
	if not options.has("crew_damage_taken_mult"):
		return
	var m: float = float(options["crew_damage_taken_mult"])
	Log.info(&"heist", "DEV OPTION crew_damage_taken_mult = %.2f (D-133 harness-only)" % m)
	for slot: int in _crew:
		Modifiers.set_source(slot, &"dev.crew_damage_taken", {&"defense.damage_taken_mult": m})


func _spawn_crew() -> void:
	var spawns: Array[Node] = []
	var chosen_tag: StringName = preplan.spawn_tag()  # C3 spawn-location asset
	var chosen: Array[Node] = []
	var oob_spawns: Array[Node] = []  # A3-09: `oob_respawn` points are not start points
	for n: Node in map.get_slots(G.PLAYER_SPAWN):
		var sp: SpawnPoint = n as SpawnPoint
		var alt: bool = false
		for t: StringName in sp.tags:
			if String(t).begins_with("preplan"):
				alt = true
		if chosen_tag != &"" and sp.tags.has(chosen_tag):
			chosen.append(sp)
		if not alt and sp.tags.has(OutOfBoundsSystem.RESPAWN_TAG):
			oob_spawns.append(sp)
		elif not alt:
			spawns.append(sp)
	if spawns.is_empty():
		spawns = oob_spawns
	if not chosen.is_empty():
		spawns = chosen
	elif chosen_tag != &"":
		Log.error(&"heist", "pre-planning spawn tag '%s' matches no PLAYER SpawnPoint; using defaults" % chosen_tag)
	if spawns.is_empty():
		Log.error(&"heist", "contract violation: no PLAYER SpawnPoints in %s" % heist_id)
	var loadouts: Dictionary = options.get("loadouts", {})
	var scene: PackedScene = load(CREW_SCENE) as PackedScene
	for slot: int in Net.all_slots():
		var crew: CrewController = scene.instantiate() as CrewController
		crew.setup(slot, Net.crew[slot], crew_loadouts.get(slot, loadouts.get(slot)) as Loadout)
		dynamic_root.add_child(crew)
		var xf: Transform3D = Transform3D.IDENTITY
		if not spawns.is_empty():
			var sp3: Node3D = spawns[slot % spawns.size()] as Node3D
			xf = sp3.global_transform
			if slot >= spawns.size():
				xf.origin += Vector3(0.8 * (slot / spawns.size()), 0.0, 0.0)
		crew.teleport(xf)
		NetIds.claim(crew)
		_crew[slot] = crew
		stats.ensure(slot)
		if crew.is_local():
			var pin: PlayerInput = PlayerInput.new()
			pin.name = "PlayerInput"
			crew.add_child(pin)
		if crew.is_ai:
			crew.add_child(CrewAiBrain.new())  # A1-10 AI teammate (L6.1)
		EventBus.crew_member_joined.emit(slot, crew.peer_id, crew.is_ai)
		Net.replicate_event(&"crew_member_joined", [slot, crew.peer_id, crew.is_ai])
		crew_spawned.emit(slot, crew)


# --- Phase machine ----------------------------------------------------------------

func _set_phase(p: Enums.HeistPhase) -> void:
	if p == phase:
		return
	var old: int = phase
	phase = p
	Log.info(&"heist", "phase %s -> %s" % [Enums.HeistPhase.keys()[old], Enums.HeistPhase.keys()[p]])
	# LEAD (OF loud hitches: the alarm frame): with FrameProf on, each listener is booked under phase.* / bus_phase.*.
	begin_tag_scope()  # the listeners' find_tagged calls share one map walk
	if not FrameProf.enabled or not FrameProf.emit_timed(phase_changed, &"phase", [old, p]):
		phase_changed.emit(old, p)
	if not FrameProf.enabled or not FrameProf.emit_timed(EventBus.heist_phase_changed, &"bus_phase", [old, p]):
		EventBus.heist_phase_changed.emit(old, p)
	end_tag_scope()
	Net.replicate_event(&"heist_phase_changed", [old, p])


func _connect_events() -> void:
	EventBus.alarm_raised.connect(_on_alarm_raised)
	EventBus.crew_masked.connect(_on_crew_masked)
	EventBus.loot_secured.connect(_on_loot_secured)
	EventBus.loot_spawned.connect(_on_loot_spawned)
	EventBus.small_loot_taken.connect(_on_small_loot)
	EventBus.pager_answered.connect(_on_pager_answered)


func _disconnect_events() -> void:
	for pair: Array in [
		[EventBus.alarm_raised, _on_alarm_raised], [EventBus.crew_masked, _on_crew_masked],
		[EventBus.loot_secured, _on_loot_secured], [EventBus.loot_spawned, _on_loot_spawned],
		[EventBus.small_loot_taken, _on_small_loot], [EventBus.pager_answered, _on_pager_answered],
		[EventBus.heist_phase_changed, _on_relayed_phase],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _on_alarm_raised(reason: StringName, _source: int) -> void:
	if not Net.is_authority() or went_loud or _ended:
		return
	went_loud = true
	Log.info(&"heist", "alarm (%s): going loud" % reason)
	# S1.2: any alarm masks everyone.
	for slot: int in _crew:
		_crew[slot].set_masked(true)
	if phase == Enums.HeistPhase.CASING or phase == Enums.HeistPhase.STEALTH:
		_set_phase(Enums.HeistPhase.LOUD)
	if heist_mode == Enums.HeistMode.STEALTH_ONLY:
		# S11.3: alarm = fail. Mercer abort line, then heist_ended(failed) after the tweak delay.
		stealth_abort_left = Tweak.stealth().stealth_only_abort_s
		if mission == null or not mission.own_abort_line:  # SL-6: the heist's own abort line replaces it
			EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.abort", {})
			Net.replicate_event(&"voice_line_requested", [&"mercer", &"vo.mercer.abort", {}])



func _on_crew_masked(slot: int) -> void:
	# An alarm while casing masks everyone and goes CASING -> LOUD directly (no STEALTH hop, PD2 S1.2).
	# P1-02 / PI-10: a forced mask (detection, combat) is not a mask-up choice: stay CASING until the alarm.
	# Duck-typed: CrewController.mask_forced lands with ENV P 4860fdbc (absent = voluntary).
	var c: Node = crew_controller(slot)
	if c != null and c.get(&"mask_forced") == true:
		return
	if phase == Enums.HeistPhase.CASING and not went_loud:
		_set_phase(Enums.HeistPhase.STEALTH)


## Mission: escape is available (C10).
func enter_escape_phase() -> void:
	if phase != Enums.HeistPhase.ENDED:
		_set_phase(Enums.HeistPhase.ESCAPE)


## Server: finish the heist and emit heist_ended(result) [R] (events.md HeistResult).
## `fail_reason` (QA-19): ignored on success (&""); a failure without one reports FAIL_ABORT.
func end_heist(success: bool, escaped_slots: Array[int] = [], fail_reason: StringName = FAIL_NONE) -> Dictionary:
	if _ended:
		return {}
	_ended = true
	# SL-6 (S11.3): a STEALTH_ONLY heist cannot be won once the alarm sounded (an escape inside the abort window).
	if success and heist_mode == Enums.HeistMode.STEALTH_ONLY and went_loud:
		success = false
		fail_reason = FAIL_STEALTH_ONLY_ALARM
	# events.md v1.7: a successful escape completes the mission's `escape` objective before heist_ended (HUD, B's
	# achievement objectives_completed), whichever trigger ended it (escape zone, mission, stealth-only win).
	if success and mission != null and mission.objective_state(&"escape") == Enums.ObjectiveState.ACTIVE:
		mission.complete(&"escape")
	var reason: StringName = FAIL_NONE if success else (fail_reason if fail_reason != FAIL_NONE else FAIL_ABORT)
	var crew_rows: Array[Dictionary] = []
	for slot: int in Net.all_slots():
		var st: Dictionary = stats.row(slot) if stats != null else {}
		var c: CrewController = _crew.get(slot)
		crew_rows.append({
			"slot": slot, "is_ai": c.is_ai if c != null else true, "name": c.display_name if c != null else "",
			"kills": int(st.get(&"kills", 0)), "specials_killed": int(st.get(&"specials_killed", 0)),
			"downs": int(st.get(&"downs", 0)), "civilians_killed": int(st.get(&"civilians_killed", 0)),
			"shots": int(st.get(&"shots", 0)), "hits": int(st.get(&"hits", 0)),
			"headshots": int(st.get(&"headshots", 0)),
			"in_custody": c != null and c.crew_state == Enums.CrewState.CUSTODY,
			"escaped": escaped_slots.has(slot) or (success and escaped_slots.is_empty()),
		})
	var result: Dictionary = {
		"heist_id": heist_id, "success": success, "stealth": not went_loud,
		"time_s": heist_time_s, "difficulty": difficulty,  # heist clock (pauses, time scale), not wall time
		"contract_pay": map.heist_def.base_payout if map != null and map.heist_def != null else 0,
		"loot": _loot_secured.duplicate(true), "small_loot": _small_loot, "crew": crew_rows,
		"pagers_answered": _pagers_answered, "seed": run_seed, "variants": variants.duplicate(true),
		"fail_reason": reason, "loot_available": _loot_available(),
	}
	_set_phase(Enums.HeistPhase.ENDED)
	EventBus.heist_ended.emit(result)
	Net.replicate_event(&"heist_ended", [result])
	return result


func _on_loot_secured(bag: int, loot_id: StringName, value: int) -> void:
	_loot_secured.append({"loot_id": loot_id, "value": value})
	if value > 0 and bag != Ids.INVALID:
		_offered_bags[bag] = true


func _on_loot_spawned(bag: int, loot_id: StringName) -> void:
	if int(LootManager.loot_info(loot_id).get("value", 0)) > 0:
		_offered_bags[bag] = true


## Server: every valued bag this run offered (HeistResult.loot_available, for B's "all bags" achievements):
## bags that existed (spawned from a LootSpawn or by the mission, or placed in the map) plus what is still
## left in LootSpawns (safe contents included; variant-disabled spawns hold 0). Body bags and tool bags
## (thermite, value 0) do not count.
func _loot_available() -> int:
	var seen: Dictionary[int, bool] = _offered_bags.duplicate()
	var left: int = 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var ls: LootSpawn = n as LootSpawn
		if ls != null and ls.remaining > 0 and int(LootManager.loot_info(ls.loot_id).get("value", 0)) > 0:
			left += ls.remaining
		var bag: LootBag = n as LootBag
		if bag != null and bag.net_id != Ids.INVALID and bag.value > 0:
			seen[bag.net_id] = true
	return seen.size() + left


func _on_small_loot(value: int, _slot: int) -> void:
	_small_loot += value


func _on_pager_answered(_pid: int, _slot: int, total: int) -> void:
	_pagers_answered = total


# --- Noise (S4.3) ---------------------------------------------------------------

## Server: broadcast a NoiseEvent. Movement never calls this (S1.5).
func make_noise(position: Vector3, radius: float, kind: StringName, source_net_id: int = 0) -> void:
	if not Net.is_authority() or radius <= 0.0:
		return
	noise_made.emit(position, radius, kind, source_net_id)


# --- Test hooks (docs/contracts/test_hooks.md) -------------------------------------

func crew_controller(slot: int) -> Node:
	return _crew.get(slot)


func crew_members() -> Array[CrewController]:
	var out: Array[CrewController] = []
	for s: int in Net.all_slots():
		if _crew.has(s) and is_instance_valid(_crew[s]):
			out.append(_crew[s])
	return out


## Held: applied every physics tick until replaced/cleared.
func set_bot_intent(slot: int, intent: CrewIntent) -> void:
	_bot_intents[slot] = intent


func clear_bot_intent(slot: int) -> void:
	_bot_intents.erase(slot)
	var c: CrewController = _crew.get(slot)
	if c != null:
		c.apply_intent(CrewIntent.new())


func has_bot_intent(slot: int) -> bool:
	return _bot_intents.has(slot)


func teleport_crew(slot: int, xform: Transform3D) -> void:
	if not Net.is_authority():
		return
	var c: CrewController = _crew.get(slot)
	if c != null:
		c.teleport(xform)


## Alive NPCs, optionally filtered by role (&"guard", &"civilian", &"police", &"special").
func npcs(role: StringName = &"") -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = n as NpcBase
		if npc == null or not is_ancestor_of(npc) or not npc.alive:
			continue
		if role == &"" or npc.role == role:
			out.append(npc)
	return out


## Gameplay prefabs (anything with an `objective_tag`) inside this heist.
## LEAD (OF loud hitches: OF's _go_loud ran ~8 map walks in the alarm frame, 172 ms): between begin_tag_scope() and
## end_tag_scope() (nested) every find_by_tag / find_by_tags shares ONE index of the map, built at the first lookup.
## For synchronous cascades that only read tags (the phase change); a tag set inside the scope is not seen until it ends.
func begin_tag_scope() -> void:
	_tag_scope += 1


func end_tag_scope() -> void:
	_tag_scope = maxi(_tag_scope - 1, 0)
	if _tag_scope == 0:
		_tag_scope_built = false
		_tag_scope_index = {}


func _index_all_tags() -> Dictionary:
	var index: Dictionary = {}
	var queue: Array[Node] = [self]
	var i: int = 0
	while i < queue.size():
		var n: Node = queue[i]
		i += 1
		var t: Variant = n.get(&"objective_tag")
		if t != null and StringName(t) != &"":
			if not index.has(StringName(t)):
				index[StringName(t)] = [] as Array[Node]
			(index[StringName(t)] as Array).append(n)
		queue.append_array(n.get_children())
	return index


func find_by_tag(objective_tag: StringName) -> Array[Node]:
	return find_by_tags([objective_tag]).get(objective_tag, [] as Array[Node])


## LEAD (OF loud hitches: hud_model.objectives 477 ms at OF start): ONE breadth-first walk for several tags,
## objective_tag -> nodes (tree order). The walk advances an index (popping the front of an Array was O(n) per node
## over ~18k nodes, once per tag); callers that resolve many tags at once (the HUD's markers) pass them together.
func find_by_tags(tags: Array) -> Dictionary:
	var out: Dictionary = {}
	for t: Variant in tags:
		out[StringName(t)] = [] as Array[Node]
	if _tag_scope > 0:  # inside begin_tag_scope(): one full index for the whole synchronous cascade
		if not _tag_scope_built:
			_tag_scope_built = true
			_tag_scope_index = _index_all_tags()
		for k: StringName in out:
			for n: Node in _tag_scope_index.get(k, []):
				if is_instance_valid(n):
					(out[k] as Array).append(n)
		return out
	var queue: Array[Node] = [self]
	var i: int = 0
	while i < queue.size():
		var n: Node = queue[i]
		i += 1
		var t: Variant = n.get(&"objective_tag")
		if t != null and out.has(StringName(t)):
			(out[StringName(t)] as Array).append(n)
		queue.append_array(n.get_children())
	return out


## TEST ONLY (test_hooks.md v1.1, D-032 QA-9): despawn every NPC except `npc`.
func isolate_npc(npc: Node) -> void:
	for n: Node in npcs():
		if n != npc:
			n.get_parent().remove_child(n)
			n.queue_free()


func detection_value(observer: Node, slot: int) -> float:
	var st: Node = service(G.SVC_STEALTH)
	if st != null and st.has_method(&"detection_value"):
		return float(st.call(&"detection_value", observer, slot))
	return 0.0


## Frees everything: Services.clear(), Ids.reset(). Never ends the Net session (ruling C11: after a co-op
## payday every peer returns to the crew lobby on the same session; only Net.leave() ends it). On a live
## session it tells the other side first (HeistNetSync.notify_teardown). AI seats stay: the kept lobby shows
## them as Crew AI and a joining peer takes one over (Net._on_peer_connected).
func teardown() -> void:
	if net_sync != null and is_instance_valid(net_sync):
		net_sync.notify_teardown()
	_disconnect_events()
	if vfx != null and is_instance_valid(vfx):
		vfx.clear()
	if mission != null and is_instance_valid(mission):
		mission._unbind()
	_bot_intents.clear()
	Services.clear()
	Modifiers.clear_all()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
	Ids.reset()


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"heist_runtime", fp)


func _physics_step(delta: float) -> void:
	if not _ended:
		heist_time_s += delta
	if stealth_abort_left >= 0.0 and not _ended:
		stealth_abort_left -= delta
		if stealth_abort_left <= 0.0:
			stealth_abort_left = -1.0
			end_heist(false, [], FAIL_STEALTH_ONLY_ALARM)
	for slot: int in _bot_intents:
		var c: CrewController = _crew.get(slot)
		if c != null:
			c.apply_intent(_bot_intents[slot])
