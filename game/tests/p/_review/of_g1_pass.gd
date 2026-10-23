# gdlint:disable=max-returns,max-file-lines
## OF-P1 (next_heist_ostrander.md §6/§7): Ostrander Federal G1 greybox traversal pass by REAL INPUT, prepared before the
## map exists so it runs the day ENV C lands G1. Po5Pilot + PlayerInputDriver only (mouse look, WASD, crouch, F holds,
## G throws, mask, deploy, shout): no teleports, no intent injection.
## One scene, one mode per §7 "G1 tests (ENV P...)" item (--test=):
##   laser       VC laser grid (x 21): bypass gap >= 1.0 m / crouch-under (beam lower face >= 1.215 m) / sweep + timed
##               windows vs the time a MEDIUM bag (x0.75) needs to cross 4 m; a real crossing each way with the bag.
##   throws      GA throw spot (hall floor, not the 1.0 m base ledge) and the terrace east parapet (Tannery / E2, not
##               the coping): MEDIUM (4 m) and HEAVY (2 m) bags at 3 pitches each; logs where every bag rests.
##   fire_escape Corvino drop ladder up -> roof `fe` (2 x 0.35 m steps) -> caged ladder down to the terrace and back
##               up -> HH door (lockpick) -> SA down through Executive / Gallery / Ground to the Basement.
##   hole        a bag thrown down the hole lands in VT; rope ladder down; the bag into the hoist car, sent up; rope
##               ladder up; the bag out of the car in TW (the hoist cycle).
##   dock        Ledger Lane -> LD personnel door -> LD and back, then the throw into the E1 van zone; MEDIUM and HEAVY.
##   fire_exit   BC east -> the Tannery fire exit -> the E2 van zone with a HEAVY bag.
##   ghost       the design doc's ghost line ("The hardest roll and its ghost line"), solo on Cataclysm, 2 ECM (one
##               ECM with 2 charges), 1 cable tie: logs per-step game time, D-102 carry speeds, every observer's peak
##               D-128 fill meter and the total time. NPCs stay in.
##   burn        OF-A6 loud line through the real burn-through: drill parts -> lid -> 360 s -> rope ladder (4.0 m) down
##               -> bag into the hoist -> ride up -> ladder up -> take-out (needs A's mission, wip/a-of-a6 f326ad00+).
##   all         every G1 test above in turn (a fresh launch each); stops at the first failure.
## --dry runs the generic parts on EXISTING heists to prove the harness works today:
##   laser   night_deposit seed 21 (laser_static; bypass gap at x 9.575 found at runtime): lot -> grate -> ladder ->
##           B3 -> B5 -> records keycard -> vault gate -> a MEDIUM bag -> crouched through the gap and back.
##   throws  glasshouse: MEDIUM and HEAVY bags at 3 pitches at the active van secure zone (lands in / short of it).
##   ladder  night_deposit: AreawayLadder down, the cash lift cycle B1 -> G1 with a bag, AreawayLadder up.
##   all     the three dry tests in turn.
## Command (windowed only, D-086; start it only when `pgrep -xc godot` <= 1):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/of_g1_pass.tscn -- --test=laser|throws|fire_escape|hole|dock|fire_exit|ghost|all \
##     [--dry] --out=/abs/dir [--seed=N] [--map=res://world/heists/ostrander_federal/ostrander_federal.tscn]
##     [--pattern=lz_static|lz_sweep|lz_timed] [--npcs] [--render] [--bags=6]
## Stated shortcuts (as nd_stealth_route.gd): direct HeistLauncher.launch with a seed and pinned variants (PreplanResult
## force_variants, a variant-table copy for scalars / the ghost roll's rare event); traversal tests (all but ghost)
## despawn NPCs (HeistRuntime.isolate_npc, test_hooks.md) and set the crew stealth_hidden, because they test geometry,
## not stealth (--npcs keeps NPCs); bags the test needs at a spot with no reachable loot spawn come from
## LootManager.spawn_bag at the crew's feet (the call HeistMission.spawn_loot will wrap) and are PICKED UP by F; the
## hole test enables the hole's ladder / hoist if the mission's burn-through has not (G1 has no mission yet); the
## ghost line's time-lock wait runs at Engine.time_scale TIME_LOCK_SCALE. Fast mode (default; --render turns it off):
## the render loop is off and the HUD canvas layers are hidden between screenshots (presentation only).
## Output: "[OFP ...]" notes, "[OFP] FAIL <test>/<step>" at the first failed step, one "[OFP] RESULT <PASS|FAIL> <test>"
## per test and a final "[OFP] RESULT ...". PNGs in --out.
## Owner: ENV P.
extends Node

# --- Ostrander Federal G1 expectations ------------------------------------------------------------------------------
# Everything the G1 tests rely on, from docs/design/heists/ostrander_federal.md (G0, D-075/D-136) and
# next_heist_ostrander.md §7. Map coordinates = the design doc's floor-plan grid (origin the bank's NW corner, +x east,
# +z south, metres, y = FFL), shifted by OF_ORIGIN if C's map root sits elsewhere. Runtime lookups come first (prefab
# type + objective_tag / variant slot near these points); the coordinates are the fallback / the "near" anchor.
const OF_HEIST: StringName = &"ostrander_federal"
const OF_ORIGIN: Vector3 = Vector3.ZERO
## "Vertical data": HeistMap.floor_heights.
const OF_FFL: Array[float] = [-4.0, 0.0, 5.0, 8.6, 12.2]
## Variant groups / slot ids ("Variable table") pinned per test (PreplanResult force_variants).
const OF_FORCE_COMMON: Dictionary = {&"side_door": [&"door_dock_open"], &"keycard": [&"kc_security"]}
## Spawn tags ("Pre-planning": pp_spawn_lane / pp_spawn_tannery -> spawn_tag).
const OF_SPAWN_LANE: StringName = &"preplan_spawn_lane"
const OF_SPAWN_TANNERY: StringName = &"preplan_spawn_tannery"
## Basement notes: VC concourse x 14-34, z 9-13 (FFL -4); the laser grid across it at x 21 (§7.1: bypass gap >= 1.0 m
## at the SOUTH wall, crouch-under beams' lower face >= 1.215 m); the vault gate GGG x 16-18 on z 9 (objective_tag
## vault_gate); the keycard (kc_security: SR key cabinet, Ground, objective_tag keycard).
const OF_LASER_AT: Vector3 = Vector3(21.0, -4.0, 11.0)
const OF_VC_WEST: Vector3 = Vector3(18.5, -4.0, 11.0)
const OF_LASER_GAP_MIN_M: float = 1.0
const OF_CROUCH_FACE_MIN_M: float = 1.215
const OF_LASER_LEAD_M: float = 2.0  # start 2 m before the plane, end 2 m past it: the 4 m crossing of §7.1
## Ground notes: BC (back corridor) z 7-9; SA door (14, 7) on every floor (stair core x 13-16); SB door (46, 7).
const OF_SA_DOOR_X: float = 14.0
const OF_CORRIDOR_Z: float = 8.2
## Stair A floor landing inside the core (door (14.5, FFL, 7) in C's G1; flights split by a divider from z ~5.9 north).
const OF_SA_CORE: Vector3 = Vector3(14.5, 0.0, 6.4)
const OF_SR_DOOR: Vector3 = Vector3(19.0, 0.0, 7.0)
## Gallery notes: GA (z 18-20, FFL 5.0) is a throw spot to the hall floor (FFL 0.0) over the 1.1 m guard (solid base to
## 1.0 m, guard line z ~20); hall floor x 8-40, z 20-36. §7.3.
const OF_GA_STAND: Vector3 = Vector3(24.0, 5.0, 19.2)
const OF_GA_AIM: Vector3 = Vector3(24.0, 5.0, 26.0)
const OF_HALL_RECT: Rect2 = Rect2(8.0, 20.0, 32.0, 16.0)  # x, z, w, d
## Executive notes: terrace +8.6 (z 17-36); east parapet x 48 (1.1 m guard + coping >= 50 deg, §7.4); Tannery Street
## x 48-62 at FFL 0.0; E2 van (Escape) at the loading bay (52, 8). Stand at the parapet's NE end, throw east.
const OF_TERRACE_E_STAND: Vector3 = Vector3(47.2, 8.6, 19.0)
const OF_TERRACE_E_AIM: Vector3 = Vector3(53.0, 8.6, 19.0)
const OF_E2_AT: Vector3 = Vector3(52.0, 0.0, 8.0)
const OF_E2_BESIDE_M: float = 4.0
## Throw pitches (deg; 0 = level view, + up), the same three for every throw spot (§7.3/7.4 "at 3 pitches").
const THROW_PITCHES: Array[float] = [-20.0, 0.0, 25.0]
## Roof notes / Vertical data: the Corvino drop ladder (3.0 m, lane -> first landing; fire_escape = fe_down) at the
## fire-escape foot in Ledger Lane by the bank's NW corner; `fe` arrival on the roof (1, 12.2, 2); HH door (14, 12.2, 7);
## the caged ladder (3.6 m) roof -> terrace at (46, 17).
const OF_DROP_LADDER_AT: Vector3 = Vector3(-2.0, 0.0, -3.0)
const OF_FE_ROOF: Vector3 = Vector3(2.0, 12.2, 2.5)
const OF_HH_DOOR: Vector3 = Vector3(14.0, 12.2, 7.0)
const OF_CAGED_LADDER_AT: Vector3 = Vector3(46.0, 8.6, 17.0)
## The hole (24, 14) under the lid in TW: rope ladder 4.0 m (-4 -> 0), hoist (bag_lift "hoist", vault floor <-> TW);
## VT (the vault) x 14-34, z 13-25. §7.7. Burn-through objective tags: vault_drill (the lid's drill_point), vault_breach.
const OF_HOLE_AT: Vector3 = Vector3(24.0, 0.0, 14.0)
const OF_VT_RECT: Rect2 = Rect2(14.0, 13.0, 20.0, 12.0)
## CQ and GL (the cash lift's basement room, where its panel is: ghost6_k started the climb there).
const OF_CQ_RECT: Rect2 = Rect2(10.0, 0.0, 3.0, 7.0)
## Dock (Ground notes / Escape): LD personnel door (8, 0); roller door x 3-6.6 on z 0; LD interior; E1 van at (5, -3)
## in Ledger Lane. §7.8.
const OF_LD_DOOR: Vector3 = Vector3(8.0, 0.0, 0.0)
const OF_LANE_START: Vector3 = Vector3(24.0, 0.0, -4.0)  # clear of the C6 pole (20, -6): a bag behind it was not aimable
const OF_LD_IN: Vector3 = Vector3(5.0, 0.0, 4.0)
const OF_E1_AT: Vector3 = Vector3(5.0, 0.0, -3.0)
## Tannery fire exit (48, 8) at BC's east end (push_bar; door_fire_propped props it); BC east (46, 0, 8.5). §7.8.
const OF_FIRE_EXIT: Vector3 = Vector3(48.0, 0.0, 8.0)
const OF_BC_EAST: Vector3 = Vector3(45.5, 0.0, 8.3)
## Loot ids (D-102 classes): cash MEDIUM, gold HEAVY.
const LOOT_MEDIUM: StringName = &"loot.cash_bricks"
const LOOT_HEAVY: StringName = &"loot.gold"
## The ghost roll ("The hardest roll and its ghost line"): Cataclysm, cam_a, operator in, 4 rovers, kc_on_manager +
## mgr_vault, code_pc = pc_exec, srv_gallery, lz_sweep, door_none, fe_up, customers 8, officers 3, time_lock_s 270,
## esc_van_dock, rare vip_client.
const GHOST_FORCE: Dictionary = {&"camera": [&"cam_a"], &"security_room_staffed": [&"sec_staffed"],
	&"guard_post": [&"rover_hall", &"rover_gallery", &"rover_basement", &"rover_dock"],
	&"keycard": [&"kc_on_manager"], &"manager_route": [&"mgr_vault"], &"code_pc": [&"pc_exec"],
	&"server_room": [&"srv_gallery"], &"laser_pattern": [&"lz_sweep"], &"side_door": [&"door_none"],
	&"fire_escape": [&"fe_up"], &"escape": [&"esc_van_dock"],
	# C's G1 table makes these slot groups (Slot_cust_8, Slot_off_3, Slot_vip_in), not scalars.
	&"customers": [&"cust_8"], &"officers": [&"off_3"], &"vip": [&"vip_in"]}
## Scalars in C's table (scalars: time_lock_s, drill_eta_s, escape_eta_s, cash_bags, gold_bags, deposit_boxes).
## guard_extra / civ_extra (D-130 Cataclysm extras) are left to the roll: the doc's ghost line predates D-130.
const GHOST_SCALARS: Dictionary = {&"time_lock_s": 270}
const GHOST_RARE: StringName = &"vip_client"
## Ghost line waypoints (design doc steps 1-7; Ledger Lane z -10..0, dumpsters x 26-30 z -6 behind the C6 pole (20, -6),
## rover_dock's smoke pause at the Tannery corner (~48, -5); LK (locker room, x 0-10 z 0-7, door (5, -4, 7)); EA (pc_exec,
## door (19, 8.6, 7)); E3 (x 10-13, door (12, 8.6, 7)); RC (records, door (6, -4, 9)), an end aisle by its west wall;
## CQ + the cash lift GL (basement x 10-13, z 0-7) -> LD; the E1 throw from the personnel door).
## Step 1's walk: the plaza's east end -> down Tannery Street (x 48-62) -> into Ledger Lane.
const GHOST_STREET: Array[Vector3] = [Vector3(46.0, 0.0, 44.0), Vector3(55.0, 0.0, 30.0), Vector3(55.0, 0.0, 5.0),
	Vector3(52.0, 0.0, -6.0)]
const GHOST_MASK_AT: Vector3 = Vector3(28.0, 0.0, -6.8)
const GHOST_SMOKE_AT: Vector3 = Vector3(48.0, 0.0, -5.0)
## The lane counts as clear when every Ledger Lane guard is this far from the dock door (m).
const LANE_CLEAR_M: float = 20.0
const GHOST_LK_WAIT: Vector3 = Vector3(3.0, -4.0, 4.0)
## ManagerLKWC (C's Patrols/Staff stop on mgr_vault): his WC break, 40-70 s at the middle cubicle.
const GHOST_MGR_WC: Vector3 = Vector3(7.25, -4.0, 2.2)
## lkprobe (r260): behind WCPartitionLK2, hidden from his whole walk in and from BB; and where to step out to shout.
const GHOST_MGR_WC_HIDE: Vector3 = Vector3(8.5, -4.0, 0.5)
const GHOST_MGR_SHOUT: Vector3 = Vector3(8.7, -4.0, 2.3)
const GHOST_E3_WAIT: Vector3 = Vector3(11.5, 8.6, 4.0)
## LK hide for the step 5 wait, from --test=lkprobe on r252 (headless): floor navmesh reachable from GHOST_LK_WAIT and
## hidden at crouch height from 8 BB eyes outside LockerDoor (x 5, z 7). (1.5, 4.0) and its 4 neighbours see 0 of 8;
## GHOST_LK_WAIT (3, 4) is seen by 2 (r251i/r252b: rover_basement filled it through the door, crouched or not).
const GHOST_LK_HIDES: Array[Vector3] = [Vector3(1.5, -4.0, 4.0), Vector3(2.0, -4.0, 4.5), Vector3(1.5, -4.0, 3.5)]
const GHOST_RC_WAIT: Vector3 = Vector3(1.0, -4.0, 16.0)
const GHOST_CQ_AT: Vector3 = Vector3(11.5, -4.0, 4.0)
## lkprobe (r263): SA's half landing between B and G, seen from no BB / BC corridor eye: the step 2 -> 3 wait (haz_x).
const GHOST_SA_MID: Vector3 = Vector3(14.5, -2.0, 2.0)
## lkprobe (r260): CQ floor point no BB corridor eye (x 0-47, z 7.6 / 8.4) sees: the time-lock refuge (haz_u).
const GHOST_CQ_HIDE: Vector3 = Vector3(12.5, -4.0, 3.5)
## lkprobe (r263): a VT floor point beside VaultCash (24, 20.5) seen from no VC eye point: step 6's wait with a bag.
const GHOST_VT_HIDE: Vector3 = Vector3(24.5, -4.0, 20.5)
## Just inside VaultGate (17, -4, 9) on the VC side: blind from BB except right at the gate (step 6's peek).
const GHOST_GATE_INNER: Vector3 = Vector3(17.0, -4.0, 10.3)
const GHOST_LD_STAGE: Vector3 = Vector3(8.0, 0.0, 1.6)
## Runtime lookups (_x): prefab class + objective_tag (ENV C's G1 tags, wip/c-of-g1 f49df211) near a design-doc point;
## the tag wins when present, else the nearest node of the class within `max` m. --resolve prints this table's
## resolution against the map scene (FOUND by tag / FOUND near / FALLBACK far / MISSING).
const EXPECT: Dictionary = {
	"laser_grid": {"type": "LaserGrid", "tag": &"laser_grid", "near": OF_LASER_AT, "max": 8.0},
	"vault_gate": {"type": "Door", "tag": &"vault_gate", "near": Vector3(17.0, -4.0, 9.0), "max": 4.0},
	"keycard": {"type": "Node3D", "tag": &"keycard", "near": Vector3(22.0, 0.0, 3.0), "max": 60.0},
	"time_lock": {"type": "Node3D", "tag": &"time_lock", "near": Vector3(33.0, -4.0, 12.0), "max": 6.0},
	"vault_door": {"type": "Door", "tag": &"vault_door", "near": Vector3(30.0, -4.0, 13.0), "max": 4.0},
	"vault_loot": {"type": "LootSpawn", "tag": &"vault_loot", "near": Vector3(24.0, -4.0, 18.5), "max": 8.0},
	"code_pc": {"type": "Node3D", "tag": &"code_pc", "near": Vector3(19.0, 8.6, 3.0), "max": 6.0},
	"drop_ladder": {"type": "Ladder", "tag": &"fire_escape", "near": OF_DROP_LADDER_AT, "max": 12.0},
	"caged_ladder": {"type": "Ladder", "tag": &"", "near": OF_CAGED_LADDER_AT, "max": 6.0},
	"hh_door": {"type": "Door", "tag": &"head_house", "near": OF_HH_DOOR, "max": 2.5},
	# Pre-placed disabled (hidden) until the burn-through (QC-61): looked up hidden too.
	"rope_ladder": {"type": "Ladder", "tag": &"", "near": Vector3(24.0, -2.0, 14.0), "max": 4.0, "hidden_ok": true},
	"hoist": {"type": "BagLift", "tag": &"hoist", "near": Vector3(24.0, -4.0, 14.0), "max": 6.0, "hidden_ok": true},
	"lid": {"type": "Node3D", "tag": &"lid", "near": OF_HOLE_AT, "max": 3.0},
	"vault_drill": {"type": "Node3D", "tag": &"vault_drill", "near": OF_HOLE_AT, "max": 3.0},
	"ld_door": {"type": "Door", "tag": &"dock_door", "near": OF_LD_DOOR, "max": 2.0},
	"fire_exit": {"type": "Door", "tag": &"fire_exit", "near": OF_FIRE_EXIT, "max": 2.0},
	"cash_lift": {"type": "BagLift", "tag": &"cash_lift", "near": GHOST_CQ_AT, "max": 8.0},
	"e1_secure": {"type": "SecureZone", "tag": &"", "near": OF_E1_AT, "max": 6.0},
	# C's G1 (ad972c5e): SecureTannery (50.4, 0, 14.3), SecureTerrace (42.5, 8.6, 26.0): 6.5 m off the doc's points.
	"e2_secure": {"type": "SecureZone", "tag": &"", "near": OF_E2_AT, "max": 8.0},
	"e3_secure": {"type": "SecureZone", "tag": &"", "near": Vector3(36.0, 8.6, 27.0), "max": 8.0},
	"e1_escape": {"type": "EscapeZone", "tag": &"", "near": OF_E1_AT, "max": 6.0},
	"e2_escape": {"type": "EscapeZone", "tag": &"", "near": OF_E2_AT, "max": 6.0},
	"e3_escape": {"type": "EscapeZone", "tag": &"", "near": Vector3(36.0, 8.6, 27.0), "max": 6.0},
}
## Design-doc points the tests walk to / stand on (checked against the navmesh by --resolve --launch).
const EXPECT_POINTS: Dictionary = {
	"vc_west": OF_VC_WEST, "ga_stand": OF_GA_STAND, "terrace_e_stand": OF_TERRACE_E_STAND, "fe_roof": OF_FE_ROOF,
	"lane_start": OF_LANE_START, "ld_in": OF_LD_IN, "bc_east": OF_BC_EAST, "sa_b": Vector3(14.0, -4.0, 8.2),
	"sa_g": Vector3(14.0, 0.0, 8.2), "sa_gallery": Vector3(14.0, 5.0, 8.2), "sa_exec": Vector3(14.0, 8.6, 8.2),
	"ghost_mask": GHOST_MASK_AT, "ghost_lk": GHOST_LK_WAIT, "ghost_e3": GHOST_E3_WAIT, "ghost_rc": GHOST_RC_WAIT,
	"ghost_cq": GHOST_CQ_AT, "ghost_ld_stage": GHOST_LD_STAGE,
}
const EXPECT_SPAWN_TAGS: Array[StringName] = [&"preplan_spawn_lane", &"preplan_spawn_tannery"]

# --- Dry-run anchors on existing heists (night_deposit seed 21 from nd_stealth_route.gd; glasshouse) ----------------
const ND_SEED: int = 21
const ND_GRATE_AT: Vector3 = Vector3(16.95, 0.0, -1.4)
const ND_MASK_AT: Vector3 = Vector3(18.5, -4.0, 3.0)  # B3, below the areaway
const ND_GATE_AT: Vector3 = Vector3(14.0, -4.0, 6.9)
const ND_GATE_IN: Vector3 = Vector3(14.0, -4.0, 7.95)
const ND_LASER_AT: Vector3 = Vector3(14.0, -4.0, 8.5)
const ND_B5_MID_Z: float = 6.65
const ND_PLANT_THROUGH: Vector3 = Vector3(18.3, -4.0, 6.9)
const ND_B1_HATCH_STAND: Vector3 = Vector3(4.6, -4.0, 1.8)
const ND_LEAD_M: float = 0.6  # the antechamber is shallow: gate side z ~7.9, panel side z ~9.15
const GH_SEED: int = 1002
const TIME_LOCK_SCALE: float = 4.0

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _test: String = "laser"
var _dry: bool = false
var _seed: int = -1
var _map: String = ""
var _pattern: StringName = &""
var _keep_npcs: bool = false
var _bags: int = 6
var _fast: bool = true
var _shot: int = 0
var _alarm: StringName = &""
var _t0_ms: int = 0
var _cur: String = ""
var _traversal: bool = true
var _laser_trips: int = 0
var _secured_ids: Dictionary[int, bool] = {}
## observer net id -> {name, kind, max, t, at, pilot}
var _peaks: Dictionary[int, Dictionary] = {}
var _results: PackedStringArray = PackedStringArray()
var _climbing: bool = false
var _grid_floor: Dictionary[LaserGrid, float] = {}
var _resolve: bool = false
var _resolve_launch: bool = false
var _line: String = ""
var _stray: Ladder = null
## Ghost line from step 4 on (no ECM window running): floor changes wait for a clear stair core (traversal tests have
## no NPCs; steps 2-3 go straight down under ECM #1 as the doc times them).
var _ghost_stair_wait: bool = false
## Walks may use ladders on purpose (the interact sweep's pass 2 crosses the hole by the rope ladder): the stray-ladder
## watch stands down (r255 sweep: it climbed the pilot back down every time, a 15-min ping-pong).
var _ladders_ok: bool = false
## Ghost line difficulty (--diff=hazardous|cataclysm|...). D-150: the no-kill ghost acceptance runs on Hazardous (6 guards);
## Cataclysm stealth allows pager kills.
var _ghost_diff: int = Enums.Difficulty.HAZARDOUS
## _vault_guard_off_vc: consecutive samples with the vault guard off VC.
var _vg_away_n: int = 0
## Ghost step 2 (C's cue, ostrander_federal.md 8c034cdb): heist time rover_hall was last within 8 m of DockCorridorDoor
## (his loop (b) LD check); -1 before he's been seen there.
var _rh_ld_t: float = -1.0
## Step 6's window: samples in a row with the vault guard on loop (b) or (c), and when that absence began.
var _vc_away_n: int = 0
var _vc_away_since: float = -1.0
## Step 6: other basement guards' last sampled positions (closing on the gate).
var _vc_last: Dictionary = {}
var _vg_vel: Vector3 = Vector3.ZERO
var _vg_last_len: float = INF


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"test": _test = v
			"dry": _dry = true
			"seed": _seed = v.to_int()
			"map": _map = v
			"pattern": _pattern = StringName(v)
			"npcs": _keep_npcs = true
			"render": _fast = false
			"bags": _bags = v.to_int()
			"resolve": _resolve = true
			"launch": _resolve_launch = true
			"line": _line = v
			"diff": _ghost_diff = Enums.Difficulty.get(v.to_upper(), _ghost_diff)
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/of_g1_pass"
	DirAccess.make_dir_recursive_absolute(runner_out)
	EventBus.alarm_raised.connect(func(reason: StringName, src: int) -> void:
		if _alarm == &"":
			_alarm = reason
		var who: String = _observer_name(src) if rt != null and is_instance_valid(rt) and src != 0 else str(src)
		note("ALARM %s by %s (pilot at %s)" % [reason, who, Po5Pilot._v(pilot.crew.global_position)
			if pilot != null and is_instance_valid(pilot.crew) else "-"]))
	EventBus.laser_tripped.connect(func(_id: int) -> void:
		_laser_trips += 1
		note("LASER TRIPPED"))
	EventBus.loot_secured.connect(func(id: int, loot: StringName, _v: int) -> void:
		_secured_ids[id] = true
		note("secured %s (bag %d)" % [loot, id]))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		note("objective %s -> %d" % [id, st]))
	_run.call_deferred()


# --- Harness (nd_stealth_route.gd structure) ------------------------------------------------------------------------

func note(msg: String) -> void:
	print("[OFP %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0,
		rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, msg])


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return  # no frames are drawn headless (frame_post_draw never comes): --resolve runs there
	if _fast:
		_set_fast(false)
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/%02d_%s.png" % [runner_out, _shot, label]))
	if _fast:
		_set_fast(true)


## Render loop off + HUD canvas layers hidden (A's po5_flow set_fast): presentation only.
func _set_fast(on: bool) -> void:
	RenderingServer.render_loop_enabled = not on
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = not on


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func wait_until(cond: Callable, timeout_s: float) -> bool:
	for _i: int in int(timeout_s * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


## Stop at the first failed step.
func _fail(step: String) -> bool:
	note("FAIL %s/%s (alarm %s)" % [_cur, step, _alarm])
	print("[OFP] FAIL %s/%s" % [_cur, step])
	if rt != null and is_instance_valid(rt):
		await shot("fail_%s_%s" % [_cur, step.replace(" ", "_")])
	return false


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	if _resolve:
		var code: int = await _run_resolve()
		get_tree().quit(code)
		return
	var tests: Array[String] = []
	if _test == "all":
		tests.assign(["laser", "throws", "ladder"] if _dry else ["laser", "throws", "fire_escape", "hole", "dock",
			"fire_exit", "burn", "ghost"])
	else:
		tests.append(_test)
	var ok: bool = true
	for t: String in tests:
		_cur = ("dry_" if _dry else "") + t
		_alarm = &""
		_laser_trips = 0
		var m: String = "_test_" + _cur
		if not has_method(m):
			print("[OFP] RESULT FAIL %s (unknown test; dry tests: laser, throws, ladder)" % _cur)
			ok = false
			break
		note("=== %s ===" % _cur)
		var passed: bool = bool(await Callable(self, m).call())
		var line: String = "[OFP] RESULT %s %s" % ["PASS" if passed else "FAIL", _cur]
		print(line)
		_results.append("%s %s" % [_cur, "PASS" if passed else "FAIL"])
		if not passed:
			ok = false
			break
	Engine.time_scale = 1.0
	RenderingServer.render_loop_enabled = true
	print("[OFP] RESULT %s (%s)" % ["PASS" if ok else "FAIL", ", ".join(_results)])
	get_tree().quit(0 if ok else 1)


## Fresh launch (the previous heist torn down). Traversal tests despawn NPCs and hide the crew from stealth.
func _launch(heist: StringName, seed: int, diff: Enums.Difficulty, opts: Dictionary, traversal: bool) -> bool:
	if rt != null and is_instance_valid(rt):
		rt.teardown()
		rt = null
		await wait_s(0.5)
	_traversal = traversal
	opts["ai_teammates"] = 0
	opts["crew_ai"] = false
	if heist == OF_HEIST and _map != "":
		opts["map_scene"] = _map
	rt = await HeistLauncher.launch(heist, seed, diff, self, opts)
	if rt == null:
		note("no runtime for %s (map %s)" % [heist, HeistLauncher.map_path(heist, opts)])
		return await _fail("launch")
	note("launched %s seed %d diff %d variants %s" % [heist, seed, diff, rt.variants])
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	if traversal and not _keep_npcs:
		rt.isolate_npc(null)
		c.stealth_hidden = true
		# Cameras still see a masked crew (G1 throws run: camera alarm -> loud -> police -> custody at t 215).
		var cams: int = 0
		for n: Node in rt.find_children("*", "SecurityCamera", true, false):
			if n.has_method(&"set_enabled"):  # OF-A2 (trunk); older bases have no prefab enable
				n.call(&"set_enabled", false)
				cams += 1
		note("SHORTCUT traversal: NPCs despawned, crew stealth_hidden, %d cameras disabled (GameplayPrefab.set_enabled)"
			% cams)
		_quiet_watch.call_deferred()
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	pilot.arrive_dy = 0.8
	if traversal:
		pilot.hook_need = _stray_need
		pilot.hook = _stray_back
		_watch_ladders.call_deferred()
	await pilot.calibrate()
	note("spawn %s" % Po5Pilot._v(c.global_position))
	if not traversal:
		_watch_detection.call_deferred()
	await shot("%s_spawn" % _cur)
	if _fast:
		_set_fast(true)
	return true


func _of(p: Vector3) -> Vector3:
	return p + OF_ORIGIN


func _of_opts(force: Dictionary, spawn_tag: StringName = &"") -> Dictionary:
	var f: Dictionary = OF_FORCE_COMMON.duplicate(true)
	for k: Variant in force:
		f[k] = force[k]
	if _pattern != &"":
		f[&"laser_pattern"] = [_pattern]
	var pre: Dictionary = {"force_variants": f}
	if spawn_tag != &"":
		pre["spawn_tag"] = spawn_tag
	return {"preplan": pre}


func _of_seed() -> int:
	return _seed if _seed >= 0 else 1002


func _tagged(tag: StringName) -> Node3D:
	for n: Node in rt.find_by_tag(tag):
		if n is Node3D and (n as Node3D).is_visible_in_tree():
			return n as Node3D
	return null


func _comp(node: Node, kind: StringName = &"") -> InteractableComponent:
	if node == null:
		return null
	if node is InteractableComponent and (kind == &"" or (node as InteractableComponent).kind == kind):
		return node as InteractableComponent
	for c: Node in node.find_children("*", "InteractableComponent", true, false):
		var ic: InteractableComponent = c as InteractableComponent
		if kind == &"" or ic.kind == kind:
			return ic
	return null


## The in-tree node of `type` (class name) nearest to `at` (null if none within `max_m`).
func _nearest(type: String, at: Vector3, max_m: float = 1e9) -> Node3D:
	var best: Node3D = null
	for n: Node in rt.find_children("*", type, true, false):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		if n3.global_position.distance_to(at) <= max_m and (best == null
				or n3.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = n3
	return best


## Whether `n`'s script (or a base script) is the global class `type` ("Node3D": any Node3D).
static func _is_type(n: Node, type: String) -> bool:
	if not (n is Node3D):
		return false
	if type == "Node3D":
		return true
	var sc: Script = n.get_script() as Script
	while sc != null:
		if sc.get_global_name() == type:
			return true
		sc = sc.get_base_script()
	return false


## World position, also for a node not in the tree (composed local transforms).
static func _gpos(n: Node3D) -> Vector3:
	if n.is_inside_tree():
		return n.global_position
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


## {node, how: "tag" | "near" | "far" | "", dist, count} for EXPECT[id] under `root` (in-tree runs skip hidden nodes).
func _resolve_one(root: Node, id: String) -> Dictionary:
	var e: Dictionary = EXPECT[id]
	var at: Vector3 = _of(e["near"] as Vector3)
	var tag: StringName = e["tag"]
	var by_tag: Node3D = null
	var by_pos: Node3D = null
	var n_type: int = 0
	for n: Node in root.find_children("*", "", true, false):
		if not _is_type(n, String(e["type"])):
			continue
		if n.is_inside_tree() and not (n as Node3D).is_visible_in_tree() and not bool(e.get("hidden_ok", false)):
			continue
		var t: Variant = n.get(&"objective_tag")
		var tagged: bool = tag != &"" and t != null and StringName(t) == tag
		if String(e["type"]) == "Node3D" and not tagged:
			continue
		n_type += 1
		var d: float = _gpos(n as Node3D).distance_to(at)
		if tagged and (by_tag == null or d < _gpos(by_tag).distance_to(at)):
			by_tag = n as Node3D
		if by_pos == null or d < _gpos(by_pos).distance_to(at):
			by_pos = n as Node3D
	if by_tag != null:
		return {"node": by_tag, "how": "tag", "dist": _gpos(by_tag).distance_to(at), "count": n_type}
	if by_pos != null:
		var d2: float = _gpos(by_pos).distance_to(at)
		return {"node": by_pos, "how": "near" if d2 <= float(e["max"]) else "far", "dist": d2, "count": n_type}
	return {"node": null, "how": "", "dist": INF, "count": 0}


## The live node for EXPECT[id] (tag first, else nearest of its class within max); null when none.
func _x(id: String) -> Node3D:
	var r: Dictionary = _resolve_one(rt, id)
	if r["node"] == null or r["how"] == "far":
		note("lookup %s: %s" % [id, "MISSING" if r["node"] == null else "only %s at %.1f m (> %.1f m)" % [
			(r["node"] as Node).name, float(r["dist"]), float((EXPECT[id] as Dictionary)["max"])]])
		return null
	return r["node"] as Node3D


func _door_near(at: Vector3, max_m: float = 2.0) -> Door:
	var best: Door = null
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d != null and d.global_position.distance_to(at) <= max_m and (best == null
				or d.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = d
	return best


func _objective(id: StringName) -> int:
	for o: Dictionary in rt.hud_model.objectives:
		if StringName(o["id"]) == id:
			return int(o["state"])
	return -1


func _mask() -> bool:
	if pilot.crew.masked:
		return true
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await wait_s(0.3)
	note("masked %s" % pilot.crew.masked)
	return pilot.crew.masked


func _crew_v() -> float:
	var v: Vector3 = pilot.crew.velocity
	return Vector2(v.x, v.z).length()


## Walk the navmesh; with `crouch` the crouch key is held the whole way. A ladder grabbed by accident on the way
## (walking past its grab point facing it) is climbed straight back by the pilot hook (_stray_need / _stray_back).
func _go(at: Vector3, arrive: float = 0.5, timeout: float = 90.0, crouch: bool = false) -> bool:
	if crouch:
		pilot.inp.press(&"crouch")
	var ok: bool = await pilot.goto(at, arrive, timeout)
	if crouch:
		pilot.inp.release(&"crouch")
	if not ok:
		note("could not reach %s (at %s)" % [Po5Pilot._v(at), Po5Pilot._v(pilot.crew.global_position)])
	return ok


## Straight walk (no navmesh) to `to` holding W (and crouch): used across laser planes, door sills and coping steps.
## Returns the mean horizontal speed (m/s) while moving, or -1 when `to` was not reached.
## `prepped`: the caller already holds crouch and faces `to` (timed laser crossings start on the tick).
func _walk_straight(to: Vector3, timeout: float = 15.0, crouch: bool = false, arrive: float = 0.15,
		prepped: bool = false) -> float:
	if not prepped:
		if crouch:
			pilot.inp.press(&"crouch")
			await wait_s(0.35)
		await pilot.face(Vector3(to.x, pilot.crew.eye_position().y, to.z), 0.03, 1.5)
	pilot.inp.press(&"move_forward")
	var t: float = 0.0
	var sum_v: float = 0.0
	var n_v: int = 0
	var start_d: float = pilot.flat_dist(pilot.crew.global_position, to)
	var ok: bool = false
	while t < timeout:
		var d: float = pilot.flat_dist(pilot.crew.global_position, to)
		if d <= arrive:
			ok = true
			break
		var fwd: Vector3 = Vector3(to.x - pilot.crew.global_position.x, 0.0, to.z - pilot.crew.global_position.z)
		pilot.steer(atan2(-fwd.x, -fwd.z), 0.0)
		await pilot.tick()
		t += pilot.dt()
		if _crew_v() > 0.2:
			sum_v += _crew_v()
			n_v += 1
		if d > start_d + 0.5:  # moving away from it: give up
			break
	pilot.inp.release(&"move_forward")
	if crouch:
		pilot.inp.release(&"crouch")
	await pilot.inp.ticks(2)
	return (sum_v / float(maxi(n_v, 1))) if ok else -1.0


# --- Bags -----------------------------------------------------------------------------------------------------------

## Carry a bag of `loot_id`: from a loot spawn of that id reachable within `walk_m`, else (SHORTCUT) one spawned by
## LootManager.spawn_bag at the crew's feet; picked up with F either way. Returns the carried bag or null.
func _get_bag(loot_id: StringName, walk_m: float = 0.0) -> LootBag:
	if pilot.crew.is_carrying_bag():
		return pilot.crew.carried_bag as LootBag
	if walk_m > 0.0:
		for n: Node in rt.find_children("*", "LootSpawn", true, false):
			var ls: LootSpawn = n as LootSpawn
			if ls == null or ls.loot_id != loot_id or ls.remaining <= 0 or not ls.is_visible_in_tree():
				continue
			if pilot.flat_dist(ls.global_position, pilot.crew.global_position) > walk_m:
				continue
			if await pilot.use(_comp(ls), 40.0, func() -> bool: return pilot.crew.is_carrying_bag()):
				note("bag %s taken from loot spawn %s" % [loot_id, ls.name])
				return pilot.crew.carried_bag as LootBag
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	if mgr == null:
		note("no LootManager")
		return null
	var at: Vector3 = _open_spot(pilot.crew.global_position, 1.0) + Vector3.UP * 0.3
	var bag: LootBag = mgr.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, at), true)
	if bag == null:
		return null
	note("SHORTCUT bag %s (weight %d) spawned by LootManager.spawn_bag at %s" % [loot_id, bag.weight, Po5Pilot._v(at)])
	await wait_s(0.6)
	if not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
		note("spawned bag not picked up (bag at %s): one more, 1 m the other way" % Po5Pilot._v(bag.global_position))
		var at2: Vector3 = pilot.crew.global_position + (pilot.crew.global_position - bag.global_position).normalized()
		bag = mgr.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, pilot.stand_point(at2) + Vector3.UP * 0.3), true)
		await wait_s(0.6)
		if bag == null or not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			return null
	return pilot.crew.carried_bag as LootBag


## A navmesh point `r` m from `p` (8 headings, the crew's facing first) in clear view of `p` at chest height: where a
## spawned bag can lie without landing in a wall or behind a door.
func _open_spot(p: Vector3, r: float) -> Vector3:
	var fwd: Vector3 = -pilot.crew.global_transform.basis.z
	var yaw0: float = atan2(fwd.x, fwd.z)
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	for k: int in 8:
		var a: float = yaw0 + TAU * float(k) / 8.0
		var cand: Vector3 = p + Vector3(sin(a), 0.0, cos(a)) * r
		var on: Vector3 = pilot.stand_point(cand)
		if pilot.flat_dist(on, cand) > 0.15 or absf(on.y - p.y) > 0.3:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0,
			on + Vector3.UP * 0.6, 1 | 2)
		q.exclude = [pilot.crew.get_rid()]
		if space.intersect_ray(q).is_empty() and not _crosses_laser(p, on) and not _near_laser(on, 1.7):
			return on
	return p


## Whether `p` is within `m` of an active laser grid's plane (where a pick-up stand could end up across it).
func _near_laser(p: Vector3, m: float) -> bool:
	for n: Node in rt.find_children("*", "LaserGrid", true, false):
		var g: LaserGrid = n as LaserGrid
		if g == null or not g.active or not g.is_visible_in_tree():
			continue
		var l: Vector3 = g.global_transform.affine_inverse() * p
		if absf(l.y) < 3.0 and absf(l.z) < m and absf(l.x) < g.size_m.x * 0.5 + m:
			return true
	return false


## Whether the step a -> b crosses an active laser grid's plane within its width (+0.5 m).
func _crosses_laser(a: Vector3, b: Vector3) -> bool:
	for n: Node in rt.find_children("*", "LaserGrid", true, false):
		var g: LaserGrid = n as LaserGrid
		if g == null or not g.active or not g.is_visible_in_tree():
			continue
		var inv: Transform3D = g.global_transform.affine_inverse()
		var la: Vector3 = inv * a
		var lb: Vector3 = inv * b
		if absf(la.y) > 3.0 or signf(la.z) == signf(lb.z):
			continue
		var x: float = lerpf(la.x, lb.x, absf(la.z) / maxf(absf(la.z) + absf(lb.z), 0.001))
		if absf(x) <= g.size_m.x * 0.5 + 0.5:
			return true
	return false


## A throw stand `dist` m from `target` (with `zone`: from the zone box's edge on that heading) in the open: on the
## navmesh, with a clear line from chest height to target + `aim_up` (16 headings; the one nearest the crew).
func _open_stand(target: Vector3, dist: float, zone: SecureZone = null, aim_up: float = 0.8) -> Vector3:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var best: Vector3 = Vector3.INF
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		var hd: Vector3 = Vector3(sin(a), 0.0, cos(a))
		var cand: Vector3 = target + hd * (dist + (_zone_extent(zone, hd) if zone != null else 0.0))
		var on: Vector3 = pilot.stand_point(cand)
		if pilot.flat_dist(on, cand) > 0.3:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(on + Vector3.UP * 1.3,
			target + Vector3.UP * aim_up, 1 | 2)
		q.exclude = [pilot.crew.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		# The van's own body (the zone's vehicle collision) counts as reaching it.
		if not hit.is_empty() and not (zone != null and (zone.is_ancestor_of(hit["collider"] as Node)
				or _zone_dist(hit["position"] as Vector3, zone) < 0.3)):
			continue
		if best == Vector3.INF or on.distance_to(pilot.crew.global_position) < best.distance_to(pilot.crew.global_position):
			best = on
	return best


## Throw the carried bag (G) toward `aim` at `pitch_deg` (0 = level) and follow it until it rests or is secured.
## {ok, rest: Vector3, secured, under: String, dist (horizontal from the release point), t, weight}
func _throw(aim: Vector3, pitch_deg: float) -> Dictionary:
	var bag: LootBag = pilot.crew.carried_bag as LootBag
	if bag == null:
		return {"ok": false}
	var eye: Vector3 = pilot.crew.eye_position()
	var dir: Vector3 = Vector3(aim.x - eye.x, 0.0, aim.z - eye.z).normalized()
	var p: float = deg_to_rad(pitch_deg)
	await pilot.face(eye + (dir * cos(p) + Vector3.UP * sin(p)) * 6.0, 0.01, 2.0)
	var from: Vector3 = pilot.crew.global_position
	var id: int = bag.net_id
	var w: int = int(bag.weight)
	_secured_ids.erase(id)
	await pilot.inp.tap(&"drop_bag")
	var t: float = 0.0
	var still: float = 0.0
	var last: Vector3 = bag.global_position if is_instance_valid(bag) else from
	while t < 8.0:
		await pilot.tick()
		t += pilot.dt()
		if _secured_ids.has(id) or not is_instance_valid(bag) or bag.secured:
			break
		last = bag.global_position
		if bag.is_carried():
			break
		still = still + pilot.dt() if bag.linear_velocity.length() < 0.05 and not bag.in_flight else 0.0
		if still >= 0.3:
			break
	# A secure zone takes a bag a moment after it settles in the zone: give it 1.5 s.
	await wait_until(func() -> bool: return _secured_ids.has(id) or not is_instance_valid(bag) or bag.secured, 1.5)
	var secured: bool = _secured_ids.has(id) or (is_instance_valid(bag) and bag.secured)
	var under: String = "-"
	if is_instance_valid(bag):
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(last + Vector3.UP * 0.2,
			last + Vector3.DOWN * 2.0, 1 | 2)
		q.exclude = [bag.get_rid()]
		var hit: Dictionary = bag.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			under = String((hit["collider"] as Node).name)
	return {"ok": true, "rest": last, "secured": secured, "under": under, "t": t, "weight": w,
		"dist": pilot.flat_dist(from, last), "from": from}


func _throw_note(label: String, r: Dictionary, verdict: String) -> void:
	note("THROW %s weight %d pitch -> rests %s (%.1f m from the stand, %.1f s) on %s secured %s: %s" % [label,
		int(r.get("weight", -1)), Po5Pilot._v(r.get("rest", Vector3.ZERO)), float(r.get("dist", 0.0)),
		float(r.get("t", 0.0)), r.get("under", "-"), r.get("secured", false), verdict])


func _in_rect(p: Vector3, r: Rect2) -> bool:
	return r.has_point(Vector2(p.x - OF_ORIGIN.x, p.z - OF_ORIGIN.z))


## Horizontal distance from `p` to a secure zone's box (0 = inside its footprint).
static func _zone_dist(p: Vector3, z: SecureZone) -> float:
	var l: Vector3 = z.global_transform.affine_inverse() * p
	var h: Vector3 = z.zone_size_m * 0.5
	return Vector2(maxf(absf(l.x) - h.x, 0.0), maxf(absf(l.z) - h.z, 0.0)).length()


func _secure_zone_near(at: Vector3) -> SecureZone:
	var best: SecureZone = null
	for n: Node in rt.find_children("*", "SecureZone", true, false):
		var z: SecureZone = n as SecureZone
		if z != null and z.is_visible_in_tree() and (best == null
				or z.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = z
	return best


# --- Ladders and lifts ----------------------------------------------------------------------------------------------

## Climb `lad` by real input like a player: walk to 1.5 m short of the grab point (Bottom going up, Top going down),
## then hold W toward the ladder until the climb takes the crew (Ladder: forward while facing it within the grab
## radius), keep W held to the other end.
func _climb(lad: Ladder, up: bool) -> bool:
	if lad == null:
		return false
	if not lad.usable:
		note("ladder %s is not usable" % lad.name)
		return false
	var grab: Vector3 = lad.bottom_position() if up else lad.top_position()
	var end_y: float = lad.top_position().y if up else lad.bottom_position().y
	var away: Vector3 = Vector3(grab.x - lad.global_position.x, 0.0, grab.z - lad.global_position.z)
	away = away.normalized() if away.length() > 0.01 else (Vector3.FORWARD if up else Vector3.BACK)
	# The side the ladder faces first, then the other three: the OF rope ladder's foot faces the hoist shaft (C
	# f385a22c), so its facing-side stand point is inside the walled shaft once the car has gone up.
	var side: Vector3 = Vector3(-away.z, 0.0, away.x)
	var approach: Vector3 = pilot.stand_point(grab + away * 1.5)
	for d: Vector3 in [away, -away, side, -side]:
		var want: Vector3 = grab + d * 1.5
		var pt: Vector3 = pilot.stand_point(want)
		if pilot.flat_dist(pt, want) > 0.5:  # snapped off a non-walkable spot (r246: the shaft is off the navmesh)
			continue
		var path: PackedVector3Array = pilot.nav_path(pt)
		if not path.is_empty() and pilot.flat_dist(path[path.size() - 1], pt) < 0.3 and _path_clear(path):
			if d != away:
				note("ladder %s: approach from the %s side (the facing side has no path)" % [lad.name,
					"back" if d == -away else "flank"])
			approach = pt
			break
	if not await _go(approach, 0.4, 120.0):
		note("ladder %s approach not reached (%s)" % [lad.name, Po5Pilot._v(approach)])
		return false
	# D-145 free climbing (CrewLadderClimb): forward moves along the ladder in the look's direction, so look up the
	# ladder to climb up and down at its foot (below CrewTweak.ladder_down_pitch_deg) to climb down; the prefab's own
	# climb (bots, old path) still counts.
	var look_at: Vector3 = lad.global_position + Vector3(0, 4.0, 0) if up \
		else lad.bottom_position() + Vector3(0, 0.2, -0.3)
	var pitch: float = deg_to_rad(35.0) if up else deg_to_rad(Tweak.crew().ladder_down_pitch_deg - 25.0)
	await pilot.face(look_at, 0.05, 1.5)
	_climbing = true
	pilot.inp.press(&"move_forward")
	var t: float = 0.0
	var started: bool = false
	while t < lad.climb_time() + 10.0:
		await pilot.tick()
		t += pilot.dt()
		if _on_ladder(lad):
			started = true
			pilot.steer(pilot.crew.look_yaw, pitch)
		elif started:
			break
		else:
			var to: Vector3 = Vector3(grab.x, 0.0, grab.z) - Vector3(pilot.crew.global_position.x, 0.0,
				pilot.crew.global_position.z)
			if to.length() > 0.2:
				pilot.steer(atan2(-to.x, -to.z), pitch)
			else:
				pilot.steer_at(look_at)
	var ok: bool = started and absf(pilot.crew.global_position.y - end_y) < 0.4
	if ok:
		# Step off with W still held: the ladder re-arms only once forward / interact is let go (Ladder._latch), and a
		# walk that starts at the grab point facing the ladder takes it straight back (ND dry run: back up the areaway
		# ladder on the first step toward AreawayDoor). Turn away and walk 1.5 m off before letting go.
		var end_m: Vector3 = lad.top_position() if up else lad.bottom_position()
		var off: Vector3 = Vector3(end_m.x - lad.global_position.x, 0.0, end_m.z - lad.global_position.z)
		off = off.normalized() if off.length() > 0.01 else -away
		var off_pt: Vector3 = pilot.stand_point(end_m + off * 1.5)
		var s_t: float = 0.0
		while s_t < 3.0 and pilot.flat_dist(pilot.crew.global_position, off_pt) > 0.3:
			var to2: Vector3 = off_pt - pilot.crew.global_position
			pilot.steer(atan2(-to2.x, -to2.z), 0.0)
			await pilot.tick()
			s_t += pilot.dt()
	pilot.inp.release(&"move_forward")
	await wait_s(0.2)
	_climbing = false
	note("LADDER %s %s: %s in %.1f s (climb %.1f s, height %.1f m; at %s)" % [lad.name, "up" if up else "down",
		"OK" if ok else "NOT DONE", t, lad.climb_time(), lad.height_m, Po5Pilot._v(pilot.crew.global_position)])
	return ok


## Traversal runs: should anything still raise the alarm, keep the map empty of NPCs (police included) every second.
func _quiet_watch() -> void:
	var my_rt: HeistRuntime = rt
	while is_inside_tree() and rt == my_rt and is_instance_valid(rt):
		if rt.went_loud and not rt.npcs().is_empty():
			rt.isolate_npc(null)
		await wait_s(1.0)


## Every tick: a ladder climb this harness did not start (_climbing false) is a stray grab.
func _watch_ladders() -> void:
	var my_rt: HeistRuntime = rt
	while is_inside_tree() and rt == my_rt and is_instance_valid(rt) and pilot != null:
		# The prefab's own climb puts the Ladder in the crew's climbing meta; a human under D-145 free climbing carries
		# the crew itself there as an opt-out marker (CrewLadderClimb.sync_opt_out), so only a Ladder value is a climb.
		var held: Variant = pilot.crew.get_meta(Ladder.META_CLIMBING) if pilot.crew.has_meta(Ladder.META_CLIMBING) \
			else null
		var free: CrewLadderClimb = pilot.crew.ladder
		if _ladders_ok:
			pass
		elif not _climbing and _stray == null and held is Ladder:
			_stray = held as Ladder
			note("FINDING a walk took %s by accident at %s" % [_stray.name, Po5Pilot._v(pilot.crew.global_position)])
		elif not _climbing and _stray == null and free != null and free.is_climbing():
			_stray = free.ladder
			note("FINDING a walk attached to %s (free climb) at %s" % [_stray.name,
				Po5Pilot._v(pilot.crew.global_position)])
		await pilot.tick()


## Every leg of `path` is free at knee height (the navmesh can run through colliders C added after the bake).
func _path_clear(path: PackedVector3Array) -> bool:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	for k: int in range(1, path.size()):
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(path[k - 1] + Vector3(0, 0.3, 0),
			path[k] + Vector3(0, 0.3, 0))
		q.exclude = [pilot.crew.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## The crew is on `lad`: the prefab's climb (bots, legacy) or the human's free climb (D-145).
func _on_ladder(lad: Ladder) -> bool:
	if lad.is_climbing(pilot.crew.slot):
		return true
	var free: CrewLadderClimb = pilot.crew.ladder
	return free != null and free.is_climbing() and free.ladder == lad


func _stray_need() -> bool:
	return _stray != null and is_instance_valid(_stray) and not _on_ladder(_stray)


## Pilot hook: climb a stray ladder straight back, then the interrupted walk re-paths.
func _stray_back() -> bool:
	var lad: Ladder = _stray
	var went_up: bool = pilot.crew.global_position.y > lad.global_position.y + lad.height_m * 0.5
	var ok: bool = await _climb(lad, not went_up)
	note("stray ladder %s climbed back %s" % [lad.name, ok])
	_stray = null
	return true


## The panel of `lift` at landing `i` (landing 0 = the prefab's own Interactable).
static func _lift_panel(lift: BagLift, i: int) -> InteractableComponent:
	if i == 0:
		return lift.interactable
	return lift.get_node_or_null("%s%d" % [BagLift.PANEL_PREFIX, i]) as InteractableComponent


static func _lift_nearest_landing(lift: BagLift, p: Vector3) -> int:
	var best: int = 0
	for i: int in lift.landing_count():
		if lift.landing_transform(i).origin.distance_to(p) < lift.landing_transform(best).origin.distance_to(p):
			best = i
	return best


## Call / send `lift` so its car stands at `to`, using the panel at the crew's landing (`stand` = where to stand).
func _lift_to(lift: BagLift, to: int, stand: Vector3) -> bool:
	await wait_until(func() -> bool: return not lift.is_moving(), lift.travel_s + 5.0)
	if lift.landing == to:
		return true
	# The landing the panel is at follows the STAND, not where the crew is now (C 2026-10-20: after a stray climb the
	# crew stood by the other landing and aimed its panel through the slab).
	var here: int = _lift_nearest_landing(lift, stand)
	var panel: InteractableComponent = _lift_panel(lift, here)
	if panel == null:
		note("lift %s: no panel at landing %d" % [lift.name, here])
		return false
	await _go(stand, 0.3, 60.0)
	# Walk to the panel when the stand is out of reach of it (G1 hoist: panel 2.0 m from the car-side stand).
	var walk_to: bool = pilot.crew.global_position.distance_to(panel.global_position) > 1.4
	_diag_hold.call_deferred(panel, 8.0)
	if not await pilot.use(panel, 30.0, func() -> bool: return lift.is_moving(), walk_to):
		note("lift %s panel %d not used (at %s)" % [lift.name, here, Po5Pilot._v(pilot.crew.global_position)])
		return false
	var ok: bool = await wait_until(func() -> bool: return not lift.is_moving() and lift.landing == to,
		lift.travel_s + 5.0)
	note("LIFT %s %s landing %d (%d bags in the car)" % [lift.name, "at" if ok else "NOT at", to,
		lift.bags_in_car().size()])
	return ok


## Diagnostic (the r245 hoist "hold dropped" loop): 10 Hz for `max_s`, a line whenever the hold's state changes:
## session alive, distance from its start (InteractionTweak.cancel_move_m), aim angle to the panel (cancel_look_deg),
## the panel's availability and what the crosshair resolves to.
func _diag_hold(comp: InteractableComponent, max_s: float) -> void:
	var isys: InteractionSystem = rt.interaction
	if isys == null or not is_instance_valid(comp):
		return
	var tw: InteractionTweak = Tweak.interaction()
	var last: String = ""
	var t: float = 0.0
	while t < max_s and is_instance_valid(comp):
		var c: CrewController = pilot.crew
		var s: Dictionary = isys.session(c.slot)
		var moved: float = c.global_position.distance_to(s.get("start_pos", c.global_position)) if not s.is_empty() \
			else -1.0
		var ang: float = rad_to_deg(c.aim_direction().angle_to(comp.global_position - c.eye_position()))
		var am: InteractableComponent = isys.aimed_component(c)
		var line: String = "session %s moved %.2f/%.2f aim %.0f/%.0f deg avail '%s' aimed %s blocked '%s'" % [
			not s.is_empty(), moved, tw.cancel_move_m, ang, tw.cancel_look_deg, comp.availability(c),
			am.name if am != null else "<none>", isys.blocked_reason(c.slot)]
		var key: String = "%s|%s|%s|%s" % [not s.is_empty(), comp.availability(c), am, isys.blocked_reason(c.slot)]
		if key != last:
			last = key
			note("DIAG hold t=%.1f %s eye %s panel %s" % [t, line, Po5Pilot._v(c.eye_position()),
				Po5Pilot._v(comp.global_position)])
		await wait_s(0.1)
		t += 0.1


## Throw the carried bag into `lift`'s car from `stand`, up against it (the release point 0.7 m ahead is in the car).
func _bag_into_car(lift: BagLift, stand: Vector3) -> bool:
	var before: int = lift.bags_in_car().size()
	for attempt: int in 2:
		if not await _go(stand, 0.2, 60.0):
			return false
		var car: Vector3 = lift.car_transform().origin
		await pilot.face(Vector3(car.x, car.y + 0.6, car.z), 0.02, 1.5)
		pilot.inp.press(&"move_forward")
		await wait_s(0.4)
		pilot.inp.release(&"move_forward")
		await pilot.face(Vector3(car.x, car.y + 0.4, car.z), 0.02, 1.0)
		var bag: LootBag = pilot.crew.carried_bag as LootBag
		await pilot.inp.tap(&"drop_bag")
		await wait_s(1.5)
		if lift.bags_in_car().size() > before:
			note("bag in the car of %s (%d)" % [lift.name, lift.bags_in_car().size()])
			return true
		note("car throw %d missed: bag at %s" % [attempt, Po5Pilot._v(bag.global_position) if is_instance_valid(bag)
			else "-"])
		await shot("car_miss_%d" % attempt)
		if bag == null or not is_instance_valid(bag) or not await pilot.use(_comp(bag), 20.0,
				func() -> bool: return pilot.crew.is_carrying_bag()):
			return false
	return false


# --- Laser grids (heist-agnostic) -----------------------------------------------------------------------------------

## Lowest beam face above the grid's floor pivot (static / timed_off: horizontal beams); 0 for sweeping (full height).
func _lowest_face(grid: LaserGrid) -> float:
	if grid.pattern == LaserGrid.PATTERN_SWEEPING or grid.beam_total() == 0:
		return 0.0
	var lo: float = INF
	for i: int in grid.beam_total():
		lo = minf(lo, grid.beam_offset(i))
	return lo + _floor_off(grid) - Tweak.interaction().laser_beam_thickness_m * 0.5


## Height of the grid's pivot above the floor under it (0 for a floor-standing grid; C's G1 lz_static grid hangs at
## +1.0 m so a crouched crew passes under it). Ray down from the pivot, cached per grid.
func _floor_off(grid: LaserGrid) -> float:
	if _grid_floor.has(grid):
		return _grid_floor[grid]
	var from: Vector3 = grid.global_position + Vector3.UP * 0.05
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1 | 2)
	if pilot != null:
		q.exclude = [pilot.crew.get_rid()]
	var hit: Dictionary = grid.get_world_3d().direct_space_state.intersect_ray(q)
	var off: float = maxf(grid.global_position.y - (hit["position"] as Vector3).y, 0.0) if not hit.is_empty() else 0.0
	_grid_floor[grid] = off
	return off


## World point on the floor under the grid at local (lx, lz).
func _gfloor(grid: LaserGrid, lx: float, lz: float) -> Vector3:
	return grid.global_transform * Vector3(lx, -_floor_off(grid), lz)


## Clear width beside the grid on each side (-x, +x local) up to the first wall (rays at 3 heights), m.
func _gaps(grid: LaserGrid) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	var space: PhysicsDirectSpaceState3D = grid.get_world_3d().direct_space_state
	var ax: Vector3 = grid.global_basis.x.normalized()
	for k: int in 2:
		var side: float = -1.0 if k == 0 else 1.0
		var best: float = 3.0
		for h: float in [0.3, 0.9, 1.5]:
			var from: Vector3 = grid.global_position + ax * side * (grid.size_m.x * 0.5 + 0.01) + Vector3.UP * (h - _floor_off(grid))
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + ax * side * 3.0, 1 | 2)
			q.exclude = [pilot.crew.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				best = minf(best, from.distance_to(hit["position"] as Vector3))
		out[k] = best
	return out


## Whether the beams leave the local-x lane [lo, hi] clear at grid time `t` (crouched: under horizontal beams).
func _lane_clear(grid: LaserGrid, t: float, lo: float, hi: float, crouch: bool) -> bool:
	if not grid.active or grid.tripped or grid.beam_total() == 0:
		return true
	var th: float = Tweak.interaction().laser_beam_thickness_m * 0.5
	var half: float = grid.size_m.x * 0.5
	if hi < -half - th or lo > half + th:
		return true  # the lane is in the gap beside the grid
	var n: int = grid.beam_total()
	if grid.pattern == LaserGrid.PATTERN_SWEEPING:
		var p: float = maxf(grid.period_s, 0.01)
		for i: int in n:
			var u: float = fposmod(t / p + float(i) / float(n), 1.0)
			var x: float = (1.0 - absf(2.0 * u - 1.0) - 0.5) * grid.size_m.x
			if x + th >= lo and x - th <= hi:
				return false
		return true
	if grid.pattern == LaserGrid.PATTERN_TIMED_OFF and grid.period_s > 0.0:
		if fposmod(t, grid.period_s) >= grid.period_s - clampf(grid.off_s, 0.0, grid.period_s):
			return true
	return crouch and _lowest_face(grid) >= Tweak.crew().height_crouched + 0.005


## Longest clear window (s) for a capsule lane centred at local x `lx` over two cycles (static: INF or 0).
func _longest_window(grid: LaserGrid, lx: float, crouch: bool) -> float:
	var r: float = Tweak.crew().capsule_radius + 0.05
	if grid.pattern == LaserGrid.PATTERN_STATIC:
		return INF if _lane_clear(grid, 0.0, lx - r, lx + r, crouch) else 0.0
	var span: float = maxf(grid.period_s, 0.1) * 2.0
	var best: float = 0.0
	var run: float = 0.0
	var dt: float = 0.02
	var t: float = 0.0
	while t < span:
		run = run + dt if _lane_clear(grid, t, lx - r, lx + r, crouch) else 0.0
		best = maxf(best, run)
		t += dt
	return best


## Geometry read-out of `grid` (logged): pattern, size, gaps, lowest face, windows vs the 4 m MEDIUM crossing.
func _laser_report(grid: LaserGrid) -> Dictionary:
	var tw: CrewTweak = Tweak.crew()
	var g: Vector2 = _gaps(grid)
	var face: float = _lowest_face(grid)
	var v_med: float = tw.walk_speed * tw.bag_speed_mult[Enums.LootWeight.MEDIUM]
	var need: float = 4.0 / v_med
	var half: float = grid.size_m.x * 0.5
	# Every 0.1 m lane the capsule fits in (walls at the gaps' far side), outermost first.
	var lanes: Array[float] = []
	var lane_r: float = tw.capsule_radius + 0.05
	var lx0: float = -(half + g.x) + lane_r
	while lx0 <= half + g.y - lane_r + 0.001:
		lanes.append(lx0)
		lx0 += 0.1
	var wins: PackedStringArray = PackedStringArray()
	var best_win: float = 0.0
	var best_lane: float = 0.0
	for lx: float in lanes:
		var w: float = _longest_window(grid, lx, false)
		if absf(lx - lanes[0]) < 0.01 or absf(lx - lanes[lanes.size() - 1]) < 0.01 or absf(lx) < 0.05:
			wins.append("x%+.2f: %.2f s" % [lx, w])
		if w > best_win:
			best_win = w
			best_lane = lx
	wins.append("best x%+.2f: %.2f s" % [best_lane, best_win])
	var rep: Dictionary = {"gap_lo": g.x, "gap_hi": g.y, "face": face, "need_s": need, "best_window": best_win,
		"best_lane": best_lane}
	note(("LASER %s pattern %s size %s at %s: gaps beside it %.2f / %.2f m; lowest beam face %.3f m above the floor"
		+ " (pivot +%.2f m; crouch %.2f);")
		% [grid.name, grid.pattern, grid.size_m, Po5Pilot._v(grid.global_position), g.x, g.y, face, _floor_off(grid),
		tw.height_crouched] + " period %.1f off %.1f; standing windows %s; a MEDIUM bag (%.2f m/s) needs %.2f s for 4 m"
		% [grid.period_s, grid.off_s, ", ".join(wins), v_med, need])
	return rep


## Whether the navmesh walk from the crew to `to` keeps the capsule off every active laser plane.
func _path_safe(to: Vector3) -> bool:
	var path: PackedVector3Array = pilot.nav_path(to)
	if path.is_empty():
		return false
	var r: float = Tweak.crew().capsule_radius + 0.12
	for n: Node in rt.find_children("*", "LaserGrid", true, false):
		var g: LaserGrid = n as LaserGrid
		if g == null or not g.active or g.tripped or not g.is_visible_in_tree():
			continue
		var inv: Transform3D = g.global_transform.affine_inverse()
		var prev: Vector3 = inv * pilot.crew.global_position
		for p: Vector3 in path:
			var l: Vector3 = inv * p
			for k: int in 5:  # samples along the leg
				var m: Vector3 = prev.lerp(l, float(k + 1) / 5.0)
				if absf(m.y) < 2.5 and absf(m.z) < r + g.size_m.z * 0.5 and absf(m.x) < g.size_m.x * 0.5 + r:
					return false
			prev = l
	return true


## Whether a crossing lane at local x `lx` has navmesh on both sides (within 0.2 m of the lane) and a clear knee-high
## line across the plane.
func _lane_ok(grid: LaserGrid, lx: float, lead: float) -> bool:
	var xf: Transform3D = grid.global_transform
	var a: Vector3 = _gfloor(grid, lx, -lead)
	var b: Vector3 = _gfloor(grid, lx, lead)
	for q: Vector3 in [a, b]:
		var on: Vector3 = pilot.stand_point(q)
		if pilot.flat_dist(on, q) > 0.2 or absf(on.y - q.y) > 0.4:
			return false
	var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.5, b + Vector3.UP * 0.5,
		1 | 2)
	rq.exclude = [pilot.crew.get_rid()]
	return grid.get_world_3d().direct_space_state.intersect_ray(rq).is_empty()


## One real crossing of `grid` along local-x lane `lx` (crouched or not), `lead` m each side of the plane, timed on
## the beams it can see (the window prediction mirrors LaserGrid's pattern maths). True when across with no trip.
func _laser_cross(grid: LaserGrid, lx: float, crouch: bool, lead: float) -> bool:
	var xf: Transform3D = grid.global_transform
	var side: float = signf((xf.affine_inverse() * pilot.crew.global_position).z)
	side = side if side != 0.0 else -1.0
	var start: Vector3 = pilot.stand_point(_gfloor(grid, lx, side * lead))
	var end: Vector3 = pilot.stand_point(_gfloor(grid, lx, -side * lead))
	var lane_err: float = absf((xf.affine_inverse() * start).x - lx) + absf((xf.affine_inverse() * end).x - lx)
	if lane_err > 0.25:
		note("laser lane x%+.2f: navmesh ends off the lane (%s -> %s)" % [lx, Po5Pilot._v(start), Po5Pilot._v(end)])
	if not await _go(start, 0.15, 60.0, crouch):
		return false
	var tw: CrewTweak = Tweak.crew()
	var bag: LootBag = pilot.crew.carried_bag as LootBag
	var mult: float = tw.bag_speed_mult[int(bag.weight)] if bag != null else 1.0
	var v: float = (tw.crouch_speed if crouch else tw.walk_speed) * mult
	var d0: float = absf((xf.affine_inverse() * pilot.crew.global_position).z)
	# Tight margins: C's G1 lz_sweep (3 beams / 8 s over 3.3 m) leaves 0.58 s at best per lane.
	var band: float = tw.capsule_radius + maxf(grid.size_m.z * 0.5, 0.02) + 0.03
	var t_in: float = maxf(d0 - band, 0.0) / v
	var t_out: float = (d0 + band) / v + 0.12  # + the time to get up to speed
	var r: float = tw.capsule_radius + 0.05
	if crouch:
		pilot.inp.press(&"crouch")
		await wait_s(0.4)
	await pilot.face(Vector3(end.x, pilot.crew.eye_position().y, end.z), 0.03, 1.5)
	var waited: float = 0.0
	var limit: float = maxf(grid.period_s, 1.0) * 3.0 + 5.0
	while waited < limit:
		var clear: bool = true
		var s: float = t_in
		while s <= t_out and clear:
			clear = _lane_clear(grid, grid.time_s + s, lx - r, lx + r, crouch)
			s += 0.05
		if clear:
			break
		await pilot.tick()
		waited += pilot.dt()
	if waited >= limit:
		note("laser: no clear window on lane x%+.2f within %.0f s" % [lx, limit])
		pilot.inp.release(&"crouch")
		return false
	var trips0: int = _laser_trips
	var speed: float = await _walk_straight(end, 20.0, crouch, 0.12, true)
	var tripped: bool = _laser_trips > trips0 or grid.tripped
	note("LASER CROSS lane x%+.2f %s with %s: waited %.1f s, %s at %.2f m/s (expected %.2f), tripped %s, at %s"
		% [lx, "crouched" if crouch else "standing", ("bag w%d" % int(bag.weight)) if bag != null else "no bag", waited,
		"across" if speed > 0.0 else "NOT across", speed, v, tripped, Po5Pilot._v(pilot.crew.global_position)])
	return speed > 0.0 and not tripped


## The §7.1 laser checks on `grid` with the carried bag: read-out, then real crossings over and back (gap lane for a
## static grid with a gap, else crouch-under, else the timing lane). `require_of` asserts the OF numbers.
func _laser_test(grid: LaserGrid, lead: float, require_of: bool) -> bool:
	if _laser_trips > 0 or grid.tripped:
		return await _fail("laser tripped before the test")
	var rep: Dictionary = _laser_report(grid)
	await pilot.face(_gfloor(grid, 0.0, 0.0) + Vector3.UP * 1.0, 0.05, 1.5)  # look at the grid for the shot
	await shot("laser_%s" % grid.pattern)
	var tw: CrewTweak = Tweak.crew()
	var half: float = grid.size_m.x * 0.5
	# A gap counts only where a lane through it is walkable on both sides with a clear line across the plane.
	var gap: float = 0.0
	var gap_side: float = -1.0
	for side: float in [-1.0, 1.0]:
		var gw: float = float(rep["gap_lo"]) if side < 0.0 else float(rep["gap_hi"])
		var lx: float = side * (half + gw * 0.5)
		var ok_lane: bool = gw >= tw.capsule_radius * 2.0 + 0.05 and _lane_ok(grid, lx, lead)
		var near_side: float = signf((grid.global_transform.affine_inverse() * pilot.crew.global_position).z)
		var start_pt: Vector3 = pilot.stand_point(_gfloor(grid, lx,
			(near_side if near_side != 0.0 else -1.0) * lead))
		var safe: bool = ok_lane and _path_safe(start_pt)
		note("laser gap %s: %.2f m, lane %s%s" % ["-x" if side < 0.0 else "+x", gw, "walkable" if ok_lane
			else "NOT walkable", "" if not ok_lane else (", reachable without crossing" if safe
			else ", NOT reachable on this side without crossing")])
		ok_lane = safe
		if ok_lane and gw > gap:
			gap = gw
			gap_side = side
	var lanes: Array[Dictionary] = []
	if grid.pattern == LaserGrid.PATTERN_STATIC:
		if require_of and gap < OF_LASER_GAP_MIN_M:
			note("FINDING laser bypass gap %.2f m < %.1f m (§7.1)" % [gap, OF_LASER_GAP_MIN_M])
			return await _fail("laser gap width")
		if gap >= tw.capsule_radius * 2.0 + 0.05:
			lanes.append({"x": gap_side * (half + gap * 0.5), "crouch": true, "what": "bypass gap"})
		var face: float = float(rep["face"])
		if require_of and face < OF_CROUCH_FACE_MIN_M:
			note("FINDING lowest beam face %.3f m < %.3f m: no crouch-under (§7.1)" % [face, OF_CROUCH_FACE_MIN_M])
			return await _fail("laser crouch face")
		if face >= tw.height_crouched + 0.005:
			lanes.append({"x": 0.0, "crouch": true, "what": "crouch-under"})
		elif not require_of:
			note("crouch-under not possible on this grid (lowest face %.3f m): gap only" % face)
	else:
		if float(rep["best_window"]) < float(rep["need_s"]):
			# The plane itself takes (capsule + beam depth) / speed to cross; below that no timing gets through.
			var plane_s: float = (tw.capsule_radius * 2.0 + grid.size_m.z + 0.06) / (tw.walk_speed
				* tw.bag_speed_mult[Enums.LootWeight.MEDIUM]) + 0.12
			note("FINDING longest %s window %.2f s < %.2f s for 4 m with a MEDIUM bag (§7.1); crossing the plane alone"
				% [grid.pattern, float(rep["best_window"]), float(rep["need_s"])] + " needs %.2f s: trying a real crossing"
				% plane_s)
			if require_of and float(rep["best_window"]) < plane_s:
				return await _fail("laser window")
		lanes.append({"x": float(rep["best_lane"]), "crouch": false, "what": "timed window"})
		if gap >= tw.capsule_radius * 2.0 + 0.05:
			lanes.append({"x": gap_side * (half + gap * 0.5), "crouch": true, "what": "bypass gap"})
	if lanes.is_empty():
		return await _fail("laser no lane")
	for ln: Dictionary in lanes:
		note("laser: %s lane x%+.2f, over and back" % [ln["what"], float(ln["x"])])
		for leg: int in 2:
			if not await _laser_cross(grid, float(ln["x"]), bool(ln["crouch"]), lead):
				return await _fail("laser cross %s %d" % [ln["what"], leg])
			await shot("laser_%s_%d" % [String(ln["what"]).replace(" ", "_"), leg])
	return true


# --- Detection watch (D-128 fills; ghost) ---------------------------------------------------------------------------

func _watch_detection() -> void:
	var sd: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	var seen: Dictionary = {}
	while sd != null and is_inside_tree() and rt != null and is_instance_valid(rt) and pilot != null:
		for e: Dictionary in sd.detection_entries(pilot.crew.slot):
			var v: float = float(e["value"])
			var id: int = int(e["observer_net_id"])
			var pk: Dictionary = _peaks.get(id, {})
			if pk.is_empty() or v > float(pk["max"]):
				_peaks[id] = {"name": _observer_name(id), "kind": int(e["kind"]), "max": v, "t": rt.heist_time_s,
					"at": e["world_pos"], "pilot": pilot.crew.global_position, "crouched": pilot.crew.crouched}
			var band: int = 3 if v >= 1.0 else (2 if v >= 0.5 else (1 if v >= 0.05 else 0))
			if band > int(seen.get(id, 0)):
				note("DETECT %s kind %d meter %.2f at %s, pilot %s crouched %s" % [_observer_name(id), int(e["kind"]), v,
					Po5Pilot._v(e["world_pos"]), Po5Pilot._v(pilot.crew.global_position), pilot.crew.crouched])
			seen[id] = band
		_track_rover_hall()  # ghost step 2's dock cue (non-traversal runs only have this watcher)
		await wait_s(0.25)


func _observer_name(net_id: int) -> String:
	var by_id: Node = Ids.lookup(net_id)  # A: turret vans, sentries, burn points are not NPCs / take_hit nodes
	if by_id != null:
		return String(by_id.name)
	for n: Node in rt.find_children("*", "Node3D", true, false):
		if (n is NpcBase or n.has_method(&"take_hit")) and NetIds.of(n) == net_id:
			return String(n.name)
	return str(net_id)


func _peaks_table() -> void:
	note("FILLS per observer (peak D-128 meter on the pilot): %d observers" % _peaks.size())
	for id: int in _peaks:
		var pk: Dictionary = _peaks[id]
		note("  FILL %-28s kind %d peak %.2f at t=%.1f (observer %s, pilot %s crouched %s)" % [pk["name"],
			int(pk["kind"]), float(pk["max"]), float(pk["t"]), Po5Pilot._v(pk["at"]), Po5Pilot._v(pk["pilot"]),
			pk["crouched"]])


# --- DRY tests on existing heists -----------------------------------------------------------------------------------

## night_deposit seed 21 (laser_static): lot -> AreawayGrate -> ladder -> B3 -> B5 -> records keycard -> vault gate ->
## MEDIUM bag -> the laser test (gap found at runtime; ND has no crouch-under: 4 beams from 0.25 m).
func _test_dry_laser() -> bool:
	var opts: Dictionary = {"preplanning": {&"asset.alternate_entry": &"pp_spawn_lot", &"asset.vent_access": &"pp_vent"}}
	if _pattern != &"":
		opts["preplan"] = {"force_variants": {&"laser_pattern": [_pattern]}}
	if not await _launch(&"night_deposit", _seed if _seed >= 0 else ND_SEED, Enums.Difficulty.ROUTINE, opts, true):
		return false
	if not await _mask():
		return await _fail("mask")
	if not await _nd_down_areaway():
		return await _fail("areaway ladder down")
	await _go(ND_MASK_AT, 0.8, 40.0)
	if not await _go(ND_PLANT_THROUGH, 0.5, 60.0):
		return await _fail("to B5")
	var kc: Node3D = _tagged(&"keycard")
	if kc != null:
		await _go(Vector3(4.2, ND_GATE_AT.y, ND_B5_MID_Z), 0.4, 40.0)
		var ic: InteractableComponent = _comp(kc)
		var kc_done: Callable = func() -> bool: return not ic.enabled or _objective(&"keycard") == 2
		if ic != null and ic.enabled and not await pilot.use(ic, 60.0, kc_done):
			return await _fail("keycard")
		note("keycard taken")
	var gate: Door = _tagged(&"vault_gate") as Door
	if gate == null:
		return await _fail("no vault gate")
	await _go(Vector3(12.0, ND_GATE_AT.y, ND_B5_MID_Z), 0.4, 40.0)
	if not gate.is_open and not await pilot.use(_comp(gate), 30.0, func() -> bool: return gate.is_open):
		return await _fail("vault gate")
	await _go(Vector3(11.5, ND_GATE_AT.y, ND_B5_MID_Z), 0.4, 20.0)
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	if not await _go(ND_GATE_IN, 0.3, 30.0):
		return await _fail("antechamber")
	var grid: LaserGrid = _nearest("LaserGrid", ND_LASER_AT, 6.0) as LaserGrid
	if grid == null:
		return await _fail("no laser grid")
	return await _laser_test(grid, ND_LEAD_M, false)


func _nd_down_areaway() -> bool:
	var grate: Door = rt.find_child("AreawayGrate", true, false) as Door
	if grate == null:
		note("no AreawayGrate")
		return false
	if not grate.is_open and not await pilot.use(_comp(grate), 20.0, func() -> bool: return grate.is_open):
		return false
	return await _climb(_nearest("Ladder", ND_GRATE_AT) as Ladder, false)


## glasshouse: at the active van secure zone, MEDIUM and HEAVY bags thrown from just outside it at 3 pitches.
func _test_dry_throws() -> bool:
	if not await _launch(&"glasshouse", _seed if _seed >= 0 else GH_SEED, Enums.Difficulty.ROUTINE, {}, true):
		return false
	if not await _mask():
		return await _fail("mask")
	var zone: SecureZone = pilot.secure_zone()
	if zone == null:
		return await _fail("no secure zone")
	var target: Vector3 = zone.global_position
	note("secure zone %s at %s size %s" % [zone.get_path(), Po5Pilot._v(target), zone.zone_size_m])
	var tw: CrewTweak = Tweak.crew()
	var n_in: int = 0
	for loot: StringName in [LOOT_MEDIUM, LOOT_HEAVY]:
		for pitch: float in THROW_PITCHES:
			var w: int = int(LootManager.loot_info(loot)["weight"])
			var throw_m: float = tw.bag_throw_distance_m[w]
			# In the open, so the throw distance reaches the zone's near half: the zone's long half + half the throw.
			var stand: Vector3 = _open_stand(target, throw_m * 0.5, zone)
			if stand == Vector3.INF:
				return await _fail("no open throw stand round the zone")
			if not await _go(stand, 0.4, 60.0):
				return await _fail("throw stand")
			if await _get_bag(loot) == null:
				return await _fail("bag")
			await _go(stand, 0.3, 20.0)
			var r: Dictionary = await _throw(target, pitch)
			if not bool(r.get("ok", false)):
				return await _fail("throw")
			var verdict: String = "in the van zone" if bool(r["secured"]) else ("short / wide, %.1f m from the zone"
				% _zone_dist(r["rest"], zone))
			n_in += 1 if bool(r["secured"]) else 0
			_throw_note("%s %+.0f deg from %.1f m" % [loot, pitch, pilot.flat_dist(stand, target)], r, verdict)
			if pitch == THROW_PITCHES[1]:
				await shot("throw_w%d" % w)
			# Leave the bag where it fell (a fresh one per throw keeps the stand points the same).
	note("dry throws: %d of %d secured" % [n_in, 2 * THROW_PITCHES.size()])
	return true


## Logs what stands in front of `from` along `dir` at 0.25 m height steps (0.25-3.0 m above the feet): the height of
## a parapet / guard as the crew meets it, and what it is.
func _wall_profile(from: Vector3, dir: Vector3, label: String) -> void:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var rows: PackedStringArray = PackedStringArray()
	var top: float = 0.0
	for k: int in 12:
		var h: float = 0.25 * float(k + 1)
		var a: Vector3 = from + Vector3.UP * h
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, a + dir * 3.0, 1 | 2)
		q.exclude = [pilot.crew.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			rows.append("%.2f: open" % h)
		else:
			top = h
			rows.append("%.2f: %.2f m %s" % [h, a.distance_to(hit["position"] as Vector3), (hit["collider"] as Node).name])
	note("WALL %s from %s: blocked up to ~%.2f m above the feet; %s" % [label, Po5Pilot._v(from), top, "; ".join(rows)])


## Half extent of a secure zone's box along horizontal `dir`.
static func _zone_extent(z: SecureZone, dir: Vector3) -> float:
	var l: Vector3 = z.global_basis.inverse() * dir
	return absf(l.x) * z.zone_size_m.x * 0.5 + absf(l.z) * z.zone_size_m.z * 0.5


## night_deposit: AreawayLadder down, the cash lift cycle B1 -> G1 with a MEDIUM bag, AreawayLadder up.
func _test_dry_ladder() -> bool:
	var opts: Dictionary = {"preplanning": {&"asset.alternate_entry": &"pp_spawn_lot", &"asset.vent_access": &"pp_vent"}}
	if not await _launch(&"night_deposit", _seed if _seed >= 0 else ND_SEED, Enums.Difficulty.ROUTINE, opts, true):
		return false
	if not await _mask():
		return await _fail("mask")
	if not await _nd_down_areaway():
		return await _fail("ladder down")
	await shot("ladder_down")
	var lift: BagLift = _nearest("BagLift", ND_B1_HATCH_STAND) as BagLift
	if lift == null:
		return await _fail("no cash lift")
	var b1: int = _lift_nearest_landing(lift, ND_B1_HATCH_STAND)
	var top: int = 1 - b1 if lift.landing_count() == 2 else 0
	for wp: Vector3 in [ND_MASK_AT, ND_PLANT_THROUGH, Vector3(10.0, ND_GATE_AT.y, ND_B5_MID_Z),
			Vector3(7.0, ND_GATE_AT.y, ND_B5_MID_Z), Vector3(4.2, ND_GATE_AT.y, ND_B5_MID_Z),
			Vector3(3.5, ND_GATE_AT.y, 5.2)]:
		await pilot.goto(wp, 0.4, 40.0, false, false)
	if not await _lift_to(lift, b1, ND_B1_HATCH_STAND):
		return await _fail("lift to B1")
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	if not await _bag_into_car(lift, ND_B1_HATCH_STAND):
		return await _fail("bag into car")
	if not await _lift_to(lift, top, ND_B1_HATCH_STAND):
		return await _fail("lift up")
	var up_ok: bool = lift.bags_in_car().size() >= 1
	note("HOIST cycle: car at landing %d with %d bag(s)" % [lift.landing, lift.bags_in_car().size()])
	await shot("lift_up")
	if not up_ok:
		return await _fail("bag rode up")
	# Back up the areaway ladder (empty-handed: S10.1b).
	for wp: Vector3 in [Vector3(4.2, ND_GATE_AT.y, ND_B5_MID_Z), Vector3(10.0, ND_GATE_AT.y, ND_B5_MID_Z),
			ND_PLANT_THROUGH, ND_MASK_AT]:
		await pilot.goto(wp, 0.4, 40.0, false, false)
	if not await _climb(_nearest("Ladder", ND_GRATE_AT) as Ladder, true):
		return await _fail("ladder up")
	await shot("ladder_up")
	return true


# --- G1 tests (Ostrander Federal) -----------------------------------------------------------------------------------

## Lane spawn (dock door open) -> LD -> BC -> SA: the way in every traversal test uses.
## Floor changes go through stair A's core: its landing on this floor, its landing on the target floor (stair door
## at (14.5, FFL, 7) on every floor in C's G1), then the corridor. A corridor-to-corridor walk has its target on the
## crew's side of the open stair door, so Po5Pilot never crosses the door link and the path corner flips in the
## doorway (G1 run 2026-10-17: 250 s pinned in StairDoorSAG).
func _of_to_floor(ffl_i: int, x: float = OF_SA_DOOR_X) -> bool:
	var cur: int = 0
	for i: int in OF_FFL.size():
		if absf(pilot.crew.global_position.y - OF_FFL[i]) < absf(pilot.crew.global_position.y - OF_FFL[cur]):
			cur = i
	if cur != ffl_i:
		if _ghost_stair_wait and cur == 0 and _in_rect(pilot.crew.global_position, OF_CQ_RECT):
			# From CQ (step 6, after the cash lift): SA's door is 2.5 m of BB away; wait in CQ's blind corner for BB, not
			# a walk down BB to the LK hide (ghost6_j: the vault guard in BB 11 m off saw that walk, t=309).
			await _go(pilot.stand_point(_of(GHOST_CQ_HIDE)), 0.3, 20.0)
			pilot.inp.press(&"crouch")
			await _wait_bb_clear()
			pilot.inp.release(&"crouch")
			if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[cur], OF_SA_CORE.z)), 0.4, 60.0) \
					or not await _go(pilot.stand_point(_of(GHOST_SA_MID)), 0.4, 30.0):
				return false
			if ffl_i == 1:
				# Up to LD to unload the lift: just after rover_hall's loop (b) LD check, ~88 s to the next (doc §7).
				var ok_t: Callable = func() -> bool:
					return _rh_ld_t >= 0.0 and rt.heist_time_s - _rh_ld_t >= 4.0 and rt.heist_time_s - _rh_ld_t <= 40.0
				await wait_until(ok_t, 150.0)
				note("GHOST up to LD %.0f s after rover_hall's LD check" % (rt.heist_time_s - _rh_ld_t))
			await _wait_core_clear(GHOST_SA_MID.y, OF_FFL[ffl_i], false, 25.0, 60.0)
			if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[ffl_i], OF_SA_CORE.z)), 0.5, 240.0):
				return false
			return await _go(_of(Vector3(x, OF_FFL[ffl_i], OF_CORRIDOR_Z)), 0.6, 240.0)
		if _ghost_stair_wait and cur == 0:
			# Leaving LK for SA (step 4): BB itself is the danger. With A's guard_vault loops the vault guard walks BB
			# too (r255a: rover_basement saw the walk at 8 m after a 4 s core wait that skipped this floor). Wait in
			# the probed LK hide, crouched, counting BB's guards as well.
			await _go(_lk_hide(), 0.4, 60.0)
			pilot.inp.press(&"crouch")
			# 10 m on BB: the vault guard's VC post is ~12 m off and was never a problem standing (r251-r253 walked
			# LK -> SA past it); walkers are caught by the 15 m moving rule. Phase 1 is BB only (r255b: counting every floor
			# at once never cleared in 180 s with A's loops); phase 2 peeks up the flights from the foot of SA.
			# haz_o: the BB-only core check cleared at once, then rover_basement came west down BB and saw the LK -> SA walk
			# at 12 m. Crossing BB needs the same window as the vault gate: rover_basement away + no walker closing in.
			pilot.inp.release(&"crouch")
			await _wait_spot_clear(_of(Vector3(OF_SA_CORE.x, OF_FFL[cur], OF_SA_CORE.z)), OF_FFL[cur], "BB to SA", _lk_hide(),
				_rover_basement_away)
			if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[cur], OF_SA_CORE.z)), 0.4, 240.0):
				return false
			# Phase 2 from SA's half landing, not the B landing behind the door (haz_y: rover_basement walked down BB past
			# it and saw the pilot at 1.5 m while it waited for rover_hall on G, t=380). Then straight up: the corridor
			# step below would walk it back out into BB.
			if not await _go(pilot.stand_point(_of(GHOST_SA_MID)), 0.4, 30.0):
				return false
			await _wait_core_clear(GHOST_SA_MID.y, OF_FFL[ffl_i], false, 25.0, 60.0)
			if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[ffl_i], OF_SA_CORE.z)), 0.5, 240.0):
				return false
			return await _go(_of(Vector3(x, OF_FFL[ffl_i], OF_CORRIDOR_Z)), 0.6, 240.0)
		if _ghost_stair_wait:  # from where the crew stands (a room): stepping out to wait gets it seen (r248: BB)
			# Same-floor guards count too (r255c: rover_gallery came up SA, dropped out of the count the moment he
			# stepped onto the Executive floor, and met the pilot leaving E3 at 2 m). From LD after staging (step 6): no
			# same-floor radius (walkers within 15 m and posts with LOS still count) and at most 60 s (ghost6_l: the posted
			# guard at (19.5, 0, 1.1), 7 m off behind walls, held a 25 m wait until rover_hall's LD check found the pilot).
			var from_ld: bool = cur == 1 and ffl_i == 0
			await _wait_core_clear(OF_FFL[cur], OF_FFL[ffl_i], true, 0.0 if from_ld else 25.0, 60.0 if from_ld else 180.0)
		# Out to this floor's corridor first: Po5Pilot crosses an open door only toward a target beyond its plane (a
		# room-to-core walk from SR has both behind the same wall and flipped in SecurityDoor, G1 run 2).
		if cur != 4 and not await _go(_of(Vector3(OF_SA_DOOR_X, OF_FFL[cur], OF_CORRIDOR_Z)), 0.6, 240.0):
			return false
		if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[cur], OF_SA_CORE.z)), 0.4, 240.0):
			return false
		if _ghost_stair_wait and ffl_i == 0:
			# Down to BB: wait for it on SA's half landing (haz_z: stepped out of SA into BB with the vault guard walking
			# west down BB 9 m off, t=515; the upper-floor core check doesn't count BB).
			if not await _down_to_bb():
				return false
		if not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[ffl_i], OF_SA_CORE.z)), 0.5, 240.0):
			return false
	return await _go(_of(Vector3(x, OF_FFL[ffl_i], OF_CORRIDOR_Z)), 0.6, 240.0)


## Ghost line: a player peeks into the stair core before using it (r246 run: Npc_guard4 on SA at 0.9 m). Wait until no
## living guard is within 8 m of the SA core between `y_lo` and `y_hi`; logs the wait (max 180 s, then goes anyway).
func _wait_core_clear(from_y: float, to_y: float, same_floor: bool = false, same_r: float = 25.0, max_s: float = 180.0) -> void:
	# Guards on the floor the crew stands on see it whether it waits or not: count those on the stair flights and
	# on the destination floor only (r246c: waiting by the ground core for a basement rover got the crew seen).
	# `same_floor` counts them too: a walk across the core on this floor (EA -> E3, r251c: rover_gallery up SA).
	var y_lo: float = minf(from_y, to_y) - 1.0
	var y_hi: float = maxf(from_y, to_y) + 2.0
	var core: Vector3 = _of(OF_SA_CORE)
	var last: Dictionary = {}
	var t: float = 0.0
	while t < max_s:
		var near: PackedStringArray = PackedStringArray()
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or g.global_position.y <= y_lo or g.global_position.y >= y_hi \
					or (not same_floor and absf(g.global_position.y - from_y) <= 0.6):
				continue
			# A walking guard reaches the flights during a multi-floor climb (~14 s, r248b: rover_gallery onto SA from
			# the Gallery floor): moving within 15 m counts; a standing post only within 8 m with LOS to the core.
			var id: int = g.get_instance_id()
			var moving: bool = last.has(id) and g.global_position.distance_to(last[id]) > 0.15
			last[id] = g.global_position
			var d: float = pilot.flat_dist(g.global_position, core)
			# Same floor: any guard within 25 m holds the crossing, LOS or not. Rooms open onto the corridor
			# (r251d/e: rover_gallery in an east room at the check, back out in XC 13 m off during the 8 s walk EA -> E3).
			var same: bool = absf(g.global_position.y - from_y) <= 0.6
			if (same and d < same_r) or (moving and d < 15.0) or (d < 8.0 and _sees_core(g, core)):
				near.append("%s %s%s" % [g.name, Po5Pilot._v(g.global_position), " moving" if moving else ""])
		if near.is_empty() and t >= 1.0:  # two samples: a guard's movement is known
			if t > 1.0:
				note("GHOST stair core clear after %.0f s" % t)
			return
		if int(t * 2.0) % 20 == 0:
			note("GHOST waiting for the stair core: %s" % ", ".join(near))
		await wait_s(0.5)
		t += 0.5
	note("GHOST stair core NOT clear after %.0f s (going anyway)" % max_s)


func _lk_hide() -> Vector3:
	for c: Vector3 in GHOST_LK_HIDES:
		var want: Vector3 = _of(c)
		var got: Vector3 = pilot.stand_point(want)
		if pilot.flat_dist(got, want) > 0.4 or absf(got.y - want.y) > 0.3:  # LK's navmesh sits at y+0.2 (cell height)
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(pilot.crew.get_world_3d().navigation_map,
			pilot.crew.global_position, got, true)
		if path.size() > 0 and path[path.size() - 1].distance_to(got) <= 0.3:
			note("GHOST LK hide at %s" % Po5Pilot._v(got))
			return got
	note("GHOST no LK corner on the navmesh: using GHOST_LK_WAIT")
	return _of(GHOST_LK_WAIT)


## Doc §5: swipe at the gate when the vault guard is off VC (loops (b)/(c)) and rover_basement is east (r251g: seen at
## the gate by Npc_guard2 in VC 6.6 m off). Waits until no living guard on floor `y` is within 8 m of `spot`, within 20 m
## with LOS to it, or walking within 20 m; if not clear at once the crew waits at `hide` (LK, doc §3; r251h: waiting in BB
## by the core, rover_basement walked down BB and saw it). Logs the wait (max 300 s, then goes anyway).
func _wait_spot_clear(spot: Vector3, y: float, label: String, hide: Vector3, extra: Callable = Callable(),
		min_z: float = -INF) -> void:
	var t: float = 0.0
	var hidden: bool = false
	var last: Dictionary = {}
	while t < 300.0:
		var near: PackedStringArray = PackedStringArray()
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or absf(g.global_position.y - y) > 1.5 or g.global_position.z < min_z:
				continue
			var id: int = g.get_instance_id()
			var moving: bool = last.has(id) and g.global_position.distance_to(last[id]) > 0.15
			var d: float = pilot.flat_dist(g.global_position, spot)
			var closing: bool = moving and pilot.flat_dist(last[id], spot) - d > 0.05
			last[id] = g.global_position
			# Walkers count within 12 m; out to 20 m only with LOS to the spot (r256d: Cataclysm's extra BB guards walking
			# x 28-36 held both of the vault guard's RC windows, t 347-377 and 557-597).
			# ...and any walker within 20 m heading this way (r257a: rover_basement out of LOS east at the 'clear', back
			# west down BB to the gate 5 s later; doc: 'rover_basement is east').
			if d < 8.0 or (moving and d < 12.0) or (d < 20.0 and (closing or _sees_core(g, spot))):
				near.append("%s %s%s" % [g.name, Po5Pilot._v(g.global_position), " moving" if moving else ""])
		if not near.is_empty() and not hidden:
			hidden = true
			note("GHOST %s not clear (%s): waiting at %s" % [label, ", ".join(near), Po5Pilot._v(hide)])
			await _go(hide, 0.5, 60.0)
			pilot.inp.press(&"crouch")  # a player waiting in a side room crouches
			last.clear()
			continue
		if near.is_empty() and extra.is_valid() and not bool(extra.call()):
			near.append("vault guard still on VC")
			if not hidden:
				hidden = true
				note("GHOST %s: waiting for the vault guard's loop (b)/(c) at %s" % [label, Po5Pilot._v(hide)])
				await _go(hide, 0.5, 60.0)
				pilot.inp.press(&"crouch")
				last.clear()
				continue
		if near.is_empty() and t >= 1.0:
			if hidden:
				pilot.inp.release(&"crouch")
			note("GHOST %s clear after %.0f s" % [label, t])
			return
		if int(t * 2.0) % 20 == 0:
			note("GHOST waiting for the %s: %s" % [label, ", ".join(near)])
		await wait_s(0.5)
		t += 0.5
	if hidden:
		pilot.inp.release(&"crouch")
	note("GHOST %s NOT clear after 300 s (going anyway)" % label)


## Doc §5: the vault guard is on loop (b) (RC, west of BB / south): two samples in a row (r256b/c: "clear" while he was on
## VC's / BB's east end, back at the gate 13-20 s later).
func _vault_guard_off_vc(_gate: Door) -> bool:
	var vg: NpcBase = null
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.is_alive():
			continue
		for t: Variant in g.spawn_info.get("tags", []):
			if String(t) == "guard_vault":
				vg = g
	if vg == null:
		return true
	# Away = deep in loop (b)'s RC (west / south of BB), not merely out of VC: r256c went at "out of VC, > 12 m" with him
	# on BB east (31.7, 8.3), 13 s from the gate again. Loop (b) in r256c: RC at t 347-377, back at the gate t 387.
	var p: Vector3 = vg.global_position
	var away: bool = absf(p.y - OF_FFL[0]) < 1.5 and (p.x < 12.0 or p.z > 13.5)
	_vg_away_n = _vg_away_n + 1 if away else 0
	return _vg_away_n >= 2


## Doc §5's window: the vault guard on loop (b) and rover_basement away. rover_basement sweeps BB (x 5-35) every 20-40 s
## (r256d/r257c); his only long stops are in RC, whose aisles are blind from BB (doc), or far east at SS. r257c: a peek
## per leg saw him come back down BB, but the retreat ran west along the same straight corridor and he filled 1.0 anyway.
func _gate_window(gate: Door) -> bool:
	if not _vault_guard_off_vc(gate):
		return false
	return _rover_basement_away()


## rover_basement is in RC (aisles blind from BB) or far east (SS), not sweeping BB.
func _rover_basement_away() -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.is_alive():
			continue
		for t: Variant in g.spawn_info.get("tags", []):
			if String(t) == "guard_rover_basement":
				var p: Vector3 = g.global_position
				var in_rc: bool = p.x < 14.0 and p.z > 9.5
				return absf(p.y - OF_FFL[0]) > 1.5 or in_rc or p.x > 36.0
	return true


func _track_rover_hall() -> void:
	var cd: Node3D = rt.find_child("DockCorridorDoor", true, false) as Node3D if rt != null else null
	if cd == null:
		return
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g != null and g.is_alive() and _has_tag(g, "guard_rover_hall") \
				and pilot.flat_dist(g.global_position, cd.global_position) < 8.0:
			if _rh_ld_t < 0.0 or rt.heist_time_s - _rh_ld_t > 5.0:
				note("GHOST rover_hall at the LD check (t=%.0f)" % rt.heist_time_s)
			_rh_ld_t = rt.heist_time_s


## C's step 2 cue: rover_hall has done his loop (b) LD check within the last 90 s and is now east (x > 25: MO, then
## loop (c) stair B / fire exit: x > 38 on BC's corridor line), so the next LD visit is two loops away.
func _rover_hall_gone_east() -> String:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.is_alive() or not _has_tag(g, "guard_rover_hall"):
			continue
		if _rh_ld_t < 0.0:
			return "rover_hall not seen at LD yet"
		if rt.heist_time_s - _rh_ld_t > 90.0:
			return "rover_hall's LD check %.0f s ago" % (rt.heist_time_s - _rh_ld_t)
		var p0: Vector3 = g.global_position
		# Just done: out of the LD check >= 4 s, on BC east of the core walking east to MO (haz_v, r263: the queue-rail
		# bake fix moved his loop; at every smoke cue he was 9-36 s from his next LD check, never on MO).
		if rt.heist_time_s - _rh_ld_t >= 4.0 and rt.heist_time_s - _rh_ld_t <= 40.0 and p0.x > 16.0 and p0.z < 12.0 \
				and g.velocity.x > 0.3:
			return ""
		# MO / loop (c) (stair B, fire exit) = BC's east end on the corridor line (z < 9.5). Loop (a)'s TW east side is z > 9.5
		# (haz_m: t=11 LD check, then at t=82 he was on (a) at (35.3, 11.5) heading round to the next LD check).
		var p: Vector3 = g.global_position
		if p.x < 38.0 or p.z > 9.5:
			return "rover_hall at %s (not on MO / loop (c))" % Po5Pilot._v(p)
		return ""
	return ""


func _has_tag(g: NpcBase, tag: String) -> bool:
	for t: Variant in g.spawn_info.get("tags", []):
		if String(t) == tag:
			return true
	return false


## Step 5's peek before each leg of the LK -> gate walk: a guard walking within 20 m who sees the pilot or closes on the
## gate, or the vault guard back off his RC leg. "" when the next leg is safe.
func _gate_threat(gate: Door) -> String:
	if not _gate_window(gate):
		return "vault guard / rover_basement not away"
	var me: Vector3 = pilot.crew.global_position
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.is_alive() or absf(g.global_position.y - OF_FFL[0]) > 1.5:
			continue
		var d_me: float = pilot.flat_dist(g.global_position, me)
		var d_gate: float = pilot.flat_dist(g.global_position, gate.global_position)
		if d_me < 8.0 or (d_me < 20.0 and _sees_core(g, me)) or d_gate < 8.0:
			return "%s %s (%.0f m)" % [g.name, Po5Pilot._v(g.global_position), d_me]
	return ""


## SA's half landing -> the foot of SA on B, waiting for BB on the landing; back up when a guard is still within 10 m at
## the foot (haz_zb/zc: BB cleared, then a guard stepped out of RC / VC as the pilot came down). Up to 4 tries.
func _down_to_bb() -> bool:
	var foot: Vector3 = _of(Vector3(OF_SA_CORE.x, OF_FFL[0], OF_SA_CORE.z))
	for _k: int in 4:
		if not await _go(pilot.stand_point(_of(GHOST_SA_MID)), 0.4, 60.0):
			return false
		await _wait_bb_clear()
		if not await _go(foot, 0.5, 30.0):
			return false
		if _b_guards_clear(foot):
			return true
		note("GHOST foot of SA not clear: back up to the half landing")
	return true


## Step 6's VC crossing window: the vault guard on loop (b) or (c) (two samples) since at most `max_age` s (his absences
## run ~30-40 s), or >= 25 m by path from the gate; and no other basement guard in VC, within 12 m of the gate, in BB
## within 25 m, or walking in BB toward it within 32 m (the gate -> CQ leg is BB).
func _vc_window(max_age: float) -> bool:
	# Doc §6: a window is the vault guard on loop (b) (RC: west / south) or (c) (east, SD: x > 36); ghost6_g saw (c) at
	# t=280 / 490 / 670 unused. A fresh absence only (ghost6_b: "away" at t=183.5 on an absence begun at t=167, he was
	# back in VC 5 s later).
	var vp: Vector3 = Vector3.INF
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g != null and g.is_alive() and _has_tag(g, "guard_vault"):
			vp = g.global_position
			_vg_vel = Vector3(g.velocity.x, 0.0, g.velocity.z)
	var away: bool = vp == Vector3.INF or absf(vp.y - OF_FFL[0]) >= 1.5 or vp.x < 12.0 or vp.z > 13.5 or vp.x > 36.0
	_vc_away_n = _vc_away_n + 1 if away else 0
	if _vc_away_n == 1:
		_vc_away_since = rt.heist_time_s
	var gate_at: Vector3 = _of(Vector3(14.5, OF_FFL[0], 9.5))
	# ...or far enough by path that he can't be back at the gate within the trip (ghost6_i: clear of the others at
	# t=179 / 299 with him 18-28 s into loop (b) / (c), refused on age alone). 25 m: ~17 s at his walk, a bag trip.
	# Where he will be at the end of the trip too (ghost6_n: 25 m by path but walking back west down BB from loop (c), at
	# the gate 12 s later, t=309): linear, his velocity times the trip.
	var trip_s: float = 8.0 if max_age > 12.0 else 12.0
	var far: bool = vp != Vector3.INF and absf(vp.y - OF_FFL[0]) < 1.5 and _nav_len(vp, gate_at) >= 25.0 \
		and _nav_len(vp + _vg_vel * trip_s, gate_at) >= 12.0
	# Out with a bag: only "far" counts, not a fresh absence (ghost6_t: an absence 0 s old was a short turn at RC's front;
	# he came back east down BB within 10 s and met the gate -> CQ dash head on, t=1004).
	var vg_len: float = _nav_len(vp, gate_at) if vp != Vector3.INF else INF
	var vg_closing: bool = vg_len < _vg_last_len - 0.05
	_vg_last_len = vg_len
	# ...and not on his way back (ghost6_t/u: far at t=989, walking back out of RC, at the gate 15 s later): standing or
	# walking deeper.
	if trip_s > 10.0 and (not far or vg_closing):
		return false
	if not far and (_vc_away_n < 2 or rt.heist_time_s - _vc_away_since > max_age):
		return false
	# Out with a bag, rover_basement away too (RC, east of x 36, off the floor: step 5's rule). Every out-trip death
	# (ghost6_m/n/o/p/q/r/s) was a BB guard near the gate during the dash, mostly him; the in-trips never failed.
	if trip_s > 10.0 and not _rover_basement_away():
		return false
	return _vc_others(trip_s) == ""


## Step 6, out with a bag: stop just inside the vault gate (VC side, blind from BB but next to the gate) and step into
## BB only when no basement guard (the vault guard included) is in BB within 25 m of the gate or within 8 m anywhere,
## while the vault guard is away (ghost6_o: rover_basement stepped into BB 8 m off during the trip, t=576, past what the
## window's prediction could see).
func _gate_peek() -> void:
	var gate: Vector3 = _of(Vector3(17.0, OF_FFL[0], 9.0))
	await _go(pilot.stand_point(_of(GHOST_GATE_INNER)), 0.4, 20.0)
	# Hold while the vault guard is still >= 18 m from the gate by path (he always comes back through BB to it: ghost6_q
	# held 20 s and went out with him back, t=204); a fixed 6 s went out beside rover_basement walking past (ghost6_r,
	# t=585). Up to 30 s.
	var t: float = 0.0
	while t < 30.0:
		var vg_far: bool = true
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g != null and g.is_alive() and _has_tag(g, "guard_vault") and absf(g.global_position.y - OF_FFL[0]) < 1.5:
				vg_far = _nav_len(g.global_position, gate) >= 18.0
		if not vg_far:
			note("GHOST gate peek: the vault guard is coming back (< 18 m), out now")
			return
		var who: String = ""
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			# The vault guard too (ghost6_p: back from RC down BB during a 17 s hold, 6 m off the gate when it cleared).
			if g == null or not g.is_alive() or absf(g.global_position.y - OF_FFL[0]) > 1.5:
				continue
			var p: Vector3 = g.global_position
			var d: float = pilot.flat_dist(p, gate)
			if d < 8.0 or (p.z > 6.5 and p.z < 9.6 and d < 25.0):
				who = "%s %s" % [g.name, Po5Pilot._v(p)]
		if who == "":
			if t > 0.0:
				note("GHOST gate peek: BB clear after %.1f s" % t)
			return
		if t == 0.0:
			note("GHOST gate peek: %s in BB, holding inside the gate" % who)
		await wait_s(0.5)
		t += 0.5
	note("GHOST gate peek: BB NOT clear after 30 s (going anyway)")


## Navmesh path length (m) from `a` to `b` on the crew's map (INF when there is no path).
func _nav_len(a: Vector3, b: Vector3) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(pilot.crew.get_world_3d().navigation_map, a, b, true)
	if path.size() < 2:
		return INF
	var d: float = 0.0
	for i: int in range(1, path.size()):
		d += path[i - 1].distance_to(path[i])
	return d


## Step 6: the first other basement guard that holds a VC crossing ("" = none), for the window and its log.
func _vc_others(trip_s: float = 0.0) -> String:
	var gate_at: Vector3 = _of(Vector3(14.5, OF_FFL[0], 9.0))
	var who: String = ""
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.is_alive() or absf(g.global_position.y - OF_FFL[0]) > 1.5 or _has_tag(g, "guard_vault"):
			continue
		# Also where he will be at the end of the trip (ghost6_n: Npc_guard7 walking in from BB's east end).
		var ahead: Vector3 = g.global_position + Vector3(g.velocity.x, 0.0, g.velocity.z) * trip_s
		if trip_s > 0.0 and who == "" and ahead.z > 6.5 and ahead.z < 9.6 and pilot.flat_dist(ahead, gate_at) < 25.0:
			who = "%s %s in %.0f s" % [g.name, Po5Pilot._v(ahead), trip_s]
		var p: Vector3 = g.global_position
		var id: int = g.get_instance_id()
		var d: float = pilot.flat_dist(p, gate_at)
		var closing: bool = _vc_last.has(id) and d < pilot.flat_dist(_vc_last[id], gate_at) - 0.05
		_vc_last[id] = p
		# BB is one sight line, but VC is walled off from it: the exposed leg is the gate -> CQ dash. A BB walker
		# heading for the gate within 32 m holds it (ghost6_d: 19 m east, walking west, 1.0 in 1.5 s, t=576); one
		# walking away or standing far off does not (ghost6_i: rover_basement's BB sweep held every window).
		# ...but anyone in BB within 25 m does, standing or not (ghost6_m: rover_basement standing 14 m east facing west
		# filled 1.0 on the CQ -> gate leg, t=572); 25 m = the gate peek's, so a started trip is rarely held there.
		var in_bb: bool = p.z > 6.5 and p.z < 9.6
		if who == "" and ((p.x > 14.0 and p.x < 34.0 and p.z > 9.0 and p.z < 13.5) or d < 12.0
				or (in_bb and (d < 25.0 or (d < 32.0 and closing)))):
			who = "%s %s%s" % [g.name, Po5Pilot._v(p), " closing" if closing else ""]
	return who


func _wait_vc_window(label: String, max_age: float, max_s: float = 900.0) -> void:
	var t: float = 0.0
	while t < max_s and not _vc_window(max_age):
		if int(t * 2.0) % 60 == 0:
			var vg: String = ""
			for n: Node in rt.npcs(&"guard"):
				var g: NpcBase = n as NpcBase
				if g != null and g.is_alive() and _has_tag(g, "guard_vault"):
					vg = Po5Pilot._v(g.global_position)
			note("GHOST waiting to cross VC (%s): vault guard at %s (away %d, since %.0f s); others: %s" % [label, vg,
				_vc_away_n, rt.heist_time_s - _vc_away_since, _vc_others()])
		await wait_s(0.5)
		t += 0.5
	note("GHOST VC %s %s after %.0f s" % [label, "window" if t < max_s else "NO window (going anyway)", t])


## True when no living basement guard is within 10 m of the pilot or of `spot`, moving or not (one sample). 10 m: the vault
## guard's VC post (25.6, 10.9) is 12 m from the foot of SA.
func _b_guards_clear(spot: Vector3) -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g != null and g.is_alive() and absf(g.global_position.y - OF_FFL[0]) < 1.5 \
				and (pilot.flat_dist(g.global_position, pilot.crew.global_position) < 10.0
					or pilot.flat_dist(g.global_position, spot) < 10.0):
			return false
	return true


## Ghost line, SA's half landing -> BB (haz_za: the core check let a standing vault guard 6.5 m off in BB through, no LOS to
## the core, and he saw the walk to LK). BB is one long sight line: wait until no living basement guard stands in BB's strip
## (z 6.5-9.6) west of x 32, in RC's front, walking in VC, or within 6 m of SA's door; two samples in a row, up to `max_s`.
func _wait_bb_clear(max_s: float = 120.0) -> void:
	var door: Vector3 = _of(Vector3(OF_SA_CORE.x, OF_FFL[0], 7.5))
	var t: float = 0.0
	var ok_n: int = 0
	var last: Dictionary = {}
	while t < max_s:
		var near: PackedStringArray = PackedStringArray()
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or absf(g.global_position.y - OF_FFL[0]) > 1.5:
				continue
			var p: Vector3 = g.global_position
			var id: int = g.get_instance_id()
			var moving: bool = last.has(id) and p.distance_to(last[id]) > 0.15
			last[id] = p
			# VC walkers come out through the gate into BB (haz_zc: clear at t=517, he was in BB 5 m off at 519); his VC
			# post standing doesn't count.
			if moving and p.x > 14.0 and p.x < 34.0 and p.z > 9.0 and p.z < 13.5:
				near.append("%s %s moving in VC" % [g.name, Po5Pilot._v(p)])
				continue
			# ...and RC's front (x < 14, z < 14): the vault guard steps out of RC's door into BB (haz_zb, t=183.5).
			if (p.z > 6.5 and p.z < 9.6 and p.x < 32.0) or (p.x < 14.0 and p.z < 14.0 and p.z > 6.5) \
					or pilot.flat_dist(p, door) < 6.0:
				near.append("%s %s" % [g.name, Po5Pilot._v(p)])
		ok_n = ok_n + 1 if near.is_empty() else 0
		if ok_n >= 2:
			if t > 0.5:
				note("GHOST BB clear after %.0f s" % t)
			return
		if int(t * 2.0) % 20 == 0:
			note("GHOST waiting on SA's half landing for BB: %s" % ", ".join(near))
		await wait_s(0.5)
		t += 0.5
	note("GHOST BB NOT clear after %.0f s (going anyway)" % max_s)


## `g` has a line of sight (world layer 1) from his eyes to the stair core column at his own height: a guard behind
## the core walls cannot see the flights (r248: Npc_guard10's ground-floor post 7 m off held the wait for 180 s).
func _sees_core(g: NpcBase, core: Vector3) -> bool:
	var eye: Vector3 = g.global_position + Vector3(0, 1.6, 0)
	var to: Vector3 = Vector3(core.x, g.global_position.y + 1.2, core.z)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, to, 1)
	q.exclude = [g.get_rid()] if g is CollisionObject3D else []
	return g.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## §7.1: keycard (kc_security in SR) -> SA down -> vault gate -> a MEDIUM bag -> the laser test (4 m crossings).
func _test_laser() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts({}, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	var kic: InteractableComponent = _comp(_x("keycard"))
	if kic == null:
		return await _fail("no keycard (objective_tag keycard)")
	if not await pilot.use(kic, 240.0, func() -> bool: return not kic.enabled or _objective(&"keycard") == 2):
		return await _fail("keycard")
	if not await _of_to_floor(0):
		return await _fail("SA down to the basement")
	var gate: Door = _x("vault_gate") as Door
	if gate == null:
		return await _fail("no vault gate (objective_tag vault_gate)")
	if not gate.is_open and not await pilot.use(_comp(gate), 60.0, func() -> bool: return gate.is_open):
		return await _fail("vault gate")
	if not await _go(_of(OF_VC_WEST), 0.5, 40.0):
		return await _fail("VC")
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	var grid: LaserGrid = _x("laser_grid") as LaserGrid
	if grid == null:
		return await _fail("no LaserGrid near %s" % Po5Pilot._v(_of(OF_LASER_AT)))
	return await _laser_test(grid, OF_LASER_LEAD_M, true)


## §7.3 + §7.4: GA -> hall floor, terrace east parapet -> Tannery / E2; MEDIUM and HEAVY at 3 pitches each.
func _test_throws() -> bool:
	var force: Dictionary = {&"escape": [&"esc_van_tannery"]}
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts(force, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	if not await _of_to_floor(2):
		return await _fail("SA up to the Gallery")
	var bad: int = 0
	for loot: StringName in [LOOT_MEDIUM, LOOT_HEAVY]:
		for pitch: float in THROW_PITCHES:
			if not await _go(_of(OF_GA_STAND), 0.3, 120.0):
				return await _fail("GA throw stand")
			if await _get_bag(loot) == null:
				return await _fail("bag")
			await _go(pilot.stand_point(_of(OF_GA_STAND)), 0.25, 10.0)
			var r: Dictionary = await _throw(_of(OF_GA_AIM), pitch)
			var p: Vector3 = r.get("rest", Vector3.ZERO)
			var verdict: String = "?"
			if p.y < OF_FFL[1] + 0.6 and _in_rect(p, OF_HALL_RECT):
				verdict = "OK hall floor"
			elif p.y > OF_FFL[2] + 0.6 and p.y < OF_FFL[2] + 1.6:
				verdict = "FAIL on the guard's base ledge"
			elif absf(p.y - OF_FFL[2]) < 0.6:
				verdict = "FAIL fell short on GA"
			else:
				verdict = "FAIL elsewhere"
			bad += 0 if verdict.begins_with("OK") else 1
			_throw_note("GA %s %+.0f deg" % [loot, pitch], r, verdict)
			if not verdict.begins_with("OK"):
				await shot("ga_throw_bad")
	await shot("ga_throws")
	if not await _of_to_floor(3):
		return await _fail("SA up to the Executive level")
	var e2: SecureZone = _x("e2_secure") as SecureZone
	await _go(pilot.stand_point(_of(OF_TERRACE_E_STAND)), 0.3, 180.0)
	_wall_profile(pilot.crew.global_position, Vector3.RIGHT, "terrace east parapet")
	# From the parapet face first, then 0.8 / 1.6 m back (the release point is 0.7 m ahead at 1.3 m: against the
	# 1.1 m guard it can start inside the coping): the first stand whose throw clears the parapet counts.
	for loot: StringName in [LOOT_MEDIUM, LOOT_HEAVY]:
		for pitch: float in THROW_PITCHES:
			var verdict: String = "?"
			for back: float in [0.0, 0.8, 1.6]:
				var stand: Vector3 = pilot.stand_point(_of(OF_TERRACE_E_STAND) - Vector3(back, 0.0, 0.0))
				if not await _go(stand, 0.3, 180.0):
					return await _fail("terrace east stand")
				if await _get_bag(loot, 3.0) == null:  # the last throw's bag if it came back at our feet
					return await _fail("bag")
				await _go(stand, 0.25, 10.0)
				var r: Dictionary = await _throw(_of(OF_TERRACE_E_AIM), pitch)
				var p: Vector3 = r.get("rest", Vector3.ZERO)
				var zd: float = _zone_dist(p, e2) if e2 != null else INF
				if bool(r.get("secured", false)):
					verdict = "OK in the E2 zone"
				elif p.y < OF_FFL[1] + 0.6 and p.x > _of(OF_FIRE_EXIT).x + 0.3:
					verdict = ("OK Tannery Street, %.1f m from E2" % zd) if zd <= OF_E2_BESIDE_M else (
						"FAIL Tannery Street but %.1f m from the E2 zone (> %.0f m)" % [zd, OF_E2_BESIDE_M])
				elif p.y > OF_FFL[3] - 0.6 and p.x < _of(OF_FIRE_EXIT).x:
					verdict = "FAIL bounced back off the parapet / coping onto the terrace"
				elif p.y > OF_FFL[3] + 0.3:
					verdict = "FAIL on the coping"
				else:
					verdict = "FAIL caught at y %.1f (awning / ledge)" % p.y
				_throw_note("terrace %s %+.0f deg from %.1f m back of the parapet stand" % [loot, pitch, back], r,
					verdict)
				if not verdict.begins_with("FAIL bounced"):
					break
				var lb: LootBag = _bag_near(p, 1.5)
				if lb != null:
					await pilot.use(_comp(lb), 20.0, func() -> bool: return pilot.crew.is_carrying_bag())
			bad += 0 if verdict.begins_with("OK") else 1
			if not verdict.begins_with("OK"):
				await shot("terrace_throw_bad")
	await shot("terrace_throws")
	if bad > 0:
		return await _fail("%d of %d throws did not land where §7.3/7.4 want" % [bad, 4 * THROW_PITCHES.size()])
	return true


## §7.5/7.6/7.10: fe_down: Corvino drop ladder up -> roof fe -> caged ladder down/up -> HH door -> SA down to -4.
func _test_fire_escape() -> bool:
	var force: Dictionary = {&"fire_escape": [&"fe_down"]}
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts(force, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	var drop: Ladder = _x("drop_ladder") as Ladder
	if drop == null:
		return await _fail("no drop ladder near %s" % Po5Pilot._v(_of(OF_DROP_LADDER_AT)))
	if not await _climb(drop, true):
		return await _fail("drop ladder up")
	await shot("fe_drop_ladder_top")
	if not await _go(_of(OF_FE_ROOF), 0.6, 120.0):
		return await _fail("fire-escape stair to the roof fe")
	note("roof fe reached; stuck rows so far %d" % pilot.stuck_spots.size())
	await shot("fe_roof")
	var caged: Ladder = _x("caged_ladder") as Ladder
	if caged == null:
		return await _fail("no caged ladder near %s" % Po5Pilot._v(_of(OF_CAGED_LADDER_AT)))
	if not await _climb(caged, false):
		return await _fail("caged ladder down")
	await shot("terrace_caged_bottom")
	if not await _climb(caged, true):
		return await _fail("caged ladder up")
	var hh: Door = _x("hh_door") as Door
	if hh == null:
		return await _fail("no HH door near %s" % Po5Pilot._v(_of(OF_HH_DOOR)))
	if not hh.is_open and not await pilot.use(_comp(hh), 120.0, func() -> bool: return hh.is_open):
		return await _fail("HH door (lockpick)")
	await shot("hh_open")
	for i: int in [3, 2, 1, 0]:
		if not await _of_to_floor(i):
			return await _fail("SA down to FFL %.1f" % OF_FFL[i])
		note("SA landing FFL %.1f reached (stuck rows %d)" % [OF_FFL[i], pilot.stuck_spots.size()])
	await shot("sa_basement")
	if not pilot.stuck_spots.is_empty():
		return await _fail("%d STUCK rows on the fire escape / SA" % pilot.stuck_spots.size())
	return true


## §7.7: hole (24, 14): bag thrown down lands in VT; rope ladder down; bag into the hoist car; up; ladder up; bag out.
func _test_hole() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts({}, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	var rope: Ladder = _x("rope_ladder") as Ladder
	var hoist: BagLift = _x("hoist") as BagLift
	if rope == null or hoist == null:
		return await _fail("no rope ladder (%s) / hoist (%s) at the hole" % [rope, hoist])
	await _enable_hole(rope, hoist)
	# The hole's centre: C's LidMarker (24, 0, 14.6) when present, else the doc's (24, 14).
	var lid: Node3D = _x("lid")
	var hole: Vector3 = Vector3(lid.global_position.x, OF_FFL[1], lid.global_position.z) if lid != null else _of(OF_HOLE_AT)
	# A player throws a bag down the hole from its edge, looking straight down (G is always a throw: release 0.7 m
	# ahead, the elevation clamps at throw_min_elev_deg): stand 1.0 m from the centre (0.6 m radius + capsule).
	var tw_stand: Vector3 = pilot.stand_point(hole + Vector3(-1.0, 0.0, 0.0))
	if not await _go(pilot.stand_point(hole + Vector3(-2.0, 0.0, 0.0)), 0.4, 240.0):
		return await _fail("to TW by the hole")
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	await _walk_straight(tw_stand, 5.0, false, 0.12)
	var r: Dictionary = await _throw(hole, -89.0)
	var p: Vector3 = r.get("rest", Vector3.ZERO)
	var in_vt: bool = absf(p.y - OF_FFL[0]) < 0.6 and _in_rect(p, OF_VT_RECT)
	_throw_note("down the hole", r, "OK in VT" if in_vt else "FAIL not in VT")
	await shot("hole_throw")
	# Not fatal yet: the ladder and the hoist are still checked (a bag from the vault floor stands in).
	if not in_vt:
		note("FINDING a bag thrown down the hole from its edge rests at %s, not in VT" % Po5Pilot._v(p))
	if not await _climb(rope, false):
		return await _fail("rope ladder down")
	await shot("vault_floor")
	var thrown: LootBag = _bag_near(p, 1.5) if in_vt else null
	if thrown != null:
		if not await pilot.use(_comp(thrown), 30.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			return await _fail("pick up the thrown bag in VT")
	elif await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag in VT")
	var bottom: int = _lift_nearest_landing(hoist, Vector3(hole.x, OF_FFL[0], hole.z))
	var top: int = 1 - bottom if hoist.landing_count() == 2 else 0
	var car_stand: Vector3 = pilot.stand_point(hoist.landing_transform(bottom).origin + Vector3(0.0, 0.0, 1.2))
	if not await _lift_to(hoist, bottom, car_stand):
		return await _fail("hoist down")
	var car_ok: bool = await _bag_into_car(hoist, car_stand)
	if not car_ok:
		# G is always a throw (2-4 m): an open hoist car does not hold it. Note it, then place a bag in the car
		# (SHORTCUT) so the ride up, the rope ladder up and the take-out in TW are still checked.
		note("FINDING a G-thrown bag does not stay in the open hoist car (car at %s)" % Po5Pilot._v(
			hoist.car_transform().origin))
		if pilot.crew.is_carrying_bag():
			await pilot.inp.tap(&"drop_bag")
			await wait_s(1.0)
		var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
		mgr.spawn_bag(LOOT_MEDIUM, Transform3D(Basis.IDENTITY, hoist.car_transform().origin + Vector3.UP * 0.4), true)
		await wait_s(1.0)
		note("SHORTCUT bag placed in the hoist car (%d in the car)" % hoist.bags_in_car().size())
		if hoist.bags_in_car().is_empty():
			return await _fail("bag into the hoist")
	if not await _lift_to(hoist, top, car_stand):
		return await _fail("hoist up")
	if not await _climb(rope, true):
		return await _fail("rope ladder up")
	var up: LootBag = hoist.bags_in_car().front() if not hoist.bags_in_car().is_empty() else null
	if up == null or not await pilot.use(_comp(up), 30.0, func() -> bool: return pilot.crew.is_carrying_bag()):
		return await _fail("bag out of the hoist in TW")
	note("HOIST cycle OK: the bag rode up and was taken out in TW")
	await shot("hoist_done")
	if not in_vt or not car_ok:
		return await _fail("hole: thrown-down bag in VT %s, G-throw into the hoist car %s (rope ladder + hoist ride OK)"
			% [in_vt, car_ok])
	return true


## OF-A6 (phase 2) loud line through the REAL burn-through, by real input: alarm -> the drill's 2 tool bags at the drop
## (drill_dock forced: 30 m through LD) carried (HEAVY) to the lid and placed -> 360 s burn (jams fixed) -> the rope
## ladder (4.0 m after the burn) down -> a bag into the hoist car -> the hoist sent up -> the rope ladder up -> the bag out
## in TW. Stated shortcuts: traversal mode (NPCs despawned, police kept out), the alarm raised through the
## StealthDirector (how the crew goes loud is not tested here), the burn waited out at Engine.time_scale TIME_LOCK_SCALE
## while standing at the drill, the vault bag spawned at the crew's feet (picked up by F). Each step logs "BURN <step>
## PASS|FAIL"; map-side misses (thrown bag not in the car) are FINDINGs and the flow goes on where it can.
func _test_burn() -> bool:
	var force: Dictionary = {&"drill_delivery": [&"drop_dock"]}
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts(force, OF_SPAWN_LANE), true):
		return false
	var m: Node = rt.mission
	var drill: Node3D = _x("vault_drill")
	var hoist: BagLift = _x("hoist") as BagLift
	var rope: Ladder = _x("rope_ladder") as Ladder
	if drill == null or hoist == null or rope == null:
		return await _fail("no drill (%s) / hoist (%s) / rope ladder (%s)" % [drill, hoist, rope])
	note("BURN before: rope ladder usable %s height %.2f (top %s bottom %s); hoist visible %s" % [rope.usable,
		rope.height_m, Po5Pilot._v(rope.top_position()), Po5Pilot._v(rope.bottom_position()), hoist.is_visible_in_tree()])
	if not await _mask():
		return await _fail("mask")
	var sd: Node = HeistRuntime.get_service(G.SVC_STEALTH)
	sd.call(&"raise_alarm", &"ofp_burn", 0)
	note("SHORTCUT alarm raised through the StealthDirector")
	if not await wait_until(func() -> bool: return bool(m.get(&"lockdown")), 5.0):
		return await _fail("lockdown")
	note("BURN lockdown PASS; drill_delivery %s eta %s" % [rt.variants.get(&"drill_delivery"), rt.variants.get(
		&"drill_eta_s")])
	# 1. The parts arrive at the drop.
	var got: bool = await wait_until(func() -> bool: return _drill_parts().size() >= 2, 150.0)
	var parts: Array[LootBag] = _drill_parts()
	if not got:
		return await _fail("drill parts arrive (%d)" % parts.size())
	note("BURN parts PASS at %s" % [Po5Pilot._v(parts[0].global_position)])
	# 2. Each part carried to the lid and placed.
	for i: int in 2:
		parts = _drill_parts()
		if parts.is_empty():
			return await _fail("drill part %d to carry" % i)
		var bag: LootBag = parts[0]
		var t0: float = rt.heist_time_s
		if not await pilot.use(_comp(bag), 240.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			return await _fail("pick up drill part %d at %s" % [i, Po5Pilot._v(bag.global_position)])
		var before: int = int(drill.get(&"delivered"))
		var place: InteractableComponent = _comp(drill)
		var placed: Callable = func() -> bool:
			return int(drill.get(&"delivered")) > before or int(drill.call(&"device_state")) != 0
		if not await pilot.use(place, 240.0, placed):
			return await _fail("place drill part %d on the lid" % i)
		note("BURN part %d PASS: drop -> lid in %.1f s (HEAVY), delivered %d" % [i, rt.heist_time_s - t0,
			int(drill.get(&"delivered"))])
	if int(drill.call(&"device_state")) == 0:
		return await _fail("the drill runs")
	await shot("burn_drill_running")
	# 3. The burn: stand at the drill, fix jams.
	var jams: int = 0
	Engine.time_scale = TIME_LOCK_SCALE
	note("SHORTCUT burn wait at x%.0f beside the drill" % TIME_LOCK_SCALE)
	var tb: float = rt.heist_time_s
	while not bool(m.get(&"burned_through")) and rt.heist_time_s - tb < 900.0:
		await wait_s(1.0)
		if int(drill.call(&"device_state")) == 2:  # DeviceRunner.State.JAMMED
			Engine.time_scale = 1.0
			jams += 1
			var ok_fix: bool = await pilot.use(_comp(drill), 60.0, func() -> bool:
				return int(drill.call(&"device_state")) != 2)
			note("BURN jam %d fixed %s" % [jams, ok_fix])
			Engine.time_scale = TIME_LOCK_SCALE
	Engine.time_scale = 1.0
	if not bool(m.get(&"burned_through")):
		return await _fail("burn-through (%d jams, %.0f s)" % [jams, rt.heist_time_s - tb])
	await wait_s(1.0)
	var span: float = rope.top_position().y - rope.bottom_position().y
	note("BURN burn-through PASS after %.0f s (%d jams); rope ladder usable %s height_m %.2f, top %s bottom %s (span %.2f m):"
		% [rt.heist_time_s - tb, jams, rope.usable, rope.height_m, Po5Pilot._v(rope.top_position()),
		Po5Pilot._v(rope.bottom_position()), span] + " %s; hoist enabled %s" % ["4.0 m OK" if absf(rope.height_m - 4.0)
		< 0.05 else "NOT 4.0 m", hoist.call(&"is_enabled") if hoist.has_method(&"is_enabled") else hoist.visible])
	await shot("burn_through")
	var bad: PackedStringArray = PackedStringArray()
	if absf(rope.height_m - 4.0) >= 0.05:
		bad.append("rope ladder %.2f m" % rope.height_m)
	# 4. Down the rope ladder.
	if not await _climb(rope, false):
		return await _fail("rope ladder down")
	note("BURN ladder down PASS at %s" % Po5Pilot._v(pilot.crew.global_position))
	# 5. A bag into the hoist car.
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag in VT")
	var bottom: int = _lift_nearest_landing(hoist, pilot.crew.global_position)
	var top: int = 1 - bottom if hoist.landing_count() == 2 else 0
	var car_stand: Vector3 = pilot.stand_point(hoist.landing_transform(bottom).origin + Vector3(0.0, 0.0, 1.2))
	if not await _lift_to(hoist, bottom, car_stand):
		return await _fail("hoist car down at the vault floor")
	var car_ok: bool = await _bag_into_car(hoist, car_stand)
	note("BURN bag into the hoist car %s (car at %s)" % ["PASS" if car_ok else "FAIL", Po5Pilot._v(
		hoist.car_transform().origin)])
	if not car_ok:
		bad.append("G-thrown bag not held by the hoist car")
		if pilot.crew.is_carrying_bag():
			await pilot.inp.tap(&"drop_bag")
			await wait_s(1.0)
		var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
		mgr.spawn_bag(LOOT_MEDIUM, Transform3D(Basis.IDENTITY, hoist.car_transform().origin + Vector3.UP * 0.4), true)
		await wait_s(1.0)
		note("SHORTCUT bag placed in the hoist car (%d in the car)" % hoist.bags_in_car().size())
	await shot("burn_hoist_loaded")
	# 6. The ride up.
	if not await _lift_to(hoist, top, car_stand):
		return await _fail("hoist ride up (send from the vault floor)")
	note("BURN hoist ride PASS: car at landing %d with %d bag(s)" % [hoist.landing, hoist.bags_in_car().size()])
	# 7. Up the rope ladder, the bag out in TW.
	if not await _climb(rope, true):
		return await _fail("rope ladder up")
	note("BURN ladder up PASS at %s" % Po5Pilot._v(pilot.crew.global_position))
	var up: LootBag = hoist.bags_in_car().front() if not hoist.bags_in_car().is_empty() else null
	if up == null or not await pilot.use(_comp(up), 60.0, func() -> bool: return pilot.crew.is_carrying_bag()):
		return await _fail("take the bag out of the hoist in TW")
	note("BURN take-out PASS at %s" % Po5Pilot._v(pilot.crew.global_position))
	await shot("burn_take_out")
	if not bad.is_empty():
		return await _fail("burn flow done with map-side misses: %s" % ", ".join(bad))
	return true


func _drill_parts() -> Array[LootBag]:
	var out: Array[LootBag] = []
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
		var lb: LootBag = n as LootBag
		if lb != null and lb.loot_id == &"loot.thermal_drill_part" and not lb.is_carried() and lb.is_inside_tree():
			out.append(lb)
	return out


## SHORTCUT (G1 has no mission): the hole's ladder and hoist on, unless the mission's burn-through did it.
func _enable_hole(rope: Ladder, hoist: BagLift) -> void:
	# OF-A6 has the mission's own burn-through (lid + plug dropped, rope ladder to burn_height_m, hoist on, rappel):
	# use it, so the hole test sees exactly the post-burn map (C's f385a22c Plug was not in the hand-made shortcut).
	if rt.mission != null and rt.mission.has_method(&"burn_through"):
		# The hole only opens by the LOUD burn-through and the hoist panels are phase-gated to loud
		# (ui.blocked.phase in stealth, r246 hole DIAG): go loud first, as the burn test does. NPCs stay out.
		if not rt.went_loud:
			HeistRuntime.get_service(G.SVC_STEALTH).call(&"raise_alarm", &"ofp_hole", 0)
			await wait_s(0.5)
			rt.isolate_npc(null)
			note("SHORTCUT alarm raised through the StealthDirector (the hoist is loud-only)")
		rt.mission.call(&"burn_through")
		await wait_s(0.5)
		note("SHORTCUT hole via the mission's burn_through(): rope ladder usable %s height %.2f, hoist %s enabled" % [
			rope.usable, rope.height_m, hoist.name])
		return
	for n: Node3D in [rope, hoist]:
		if n.has_method(&"set_enabled"):
			n.call(&"set_enabled", true)
	if not rope.usable:
		rope.usable = true
	# The burn-through drops the lid (C's G1: Geometry/Building/Lid/Lid StaticBody3D, meta burn_lid; mesh LidPanel).
	var lids: int = 0
	for n: Node in rt.find_children("*", "", true, false):
		if (n is CollisionObject3D and n.has_meta(&"burn_lid")) or String(n.name) == "LidPanel":
			(n as Node3D).visible = false
			for cs: Node in n.find_children("*", "CollisionShape3D", true, false):
				(cs as CollisionShape3D).set_deferred(&"disabled", true)
			if n is CollisionObject3D:
				(n as CollisionObject3D).set_deferred(&"collision_layer", 0)
			lids += 1
	note("SHORTCUT hole (no burn-through in the G1 mission): rope ladder usable %s, hoist %s enabled, lid nodes "
		% [rope.usable, hoist.name] + "dropped %d (vault_breach objective state %d)" % [lids, _objective(&"vault_breach")])


func _bag_near(p: Vector3, r: float) -> LootBag:
	var best: LootBag = null
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
		var lb: LootBag = n as LootBag
		if lb != null and not lb.is_carried() and lb.global_position.distance_to(p) <= r and (best == null
				or lb.global_position.distance_to(p) < best.global_position.distance_to(p)):
			best = lb
	return best


## §7.8: Ledger Lane -> LD personnel door -> LD and back out, then the throw into the E1 van zone; MEDIUM, then HEAVY
## (HEAVY: 2 m throw, so it walks out toward the van until the zone is in reach).
func _test_dock() -> bool:
	var force: Dictionary = {&"escape": [&"esc_van_dock"]}
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts(force, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	var e1: SecureZone = _x("e1_secure") as SecureZone
	if e1 == null:
		return await _fail("no secure zone near E1 %s" % Po5Pilot._v(_of(OF_E1_AT)))
	var door: Door = _x("ld_door") as Door
	if door == null:
		return await _fail("no LD personnel door near %s" % Po5Pilot._v(_of(OF_LD_DOOR)))
	# The lane is north (-z) of the dock: "out" is the door side with the smaller z.
	var pa: Vector3 = pilot.stand_point(door.global_transform * Vector3(0.0, 0.0, 1.2))
	var pb: Vector3 = pilot.stand_point(door.global_transform * Vector3(0.0, 0.0, -1.2))
	var out_pt: Vector3 = pa if pa.z < pb.z else pb
	var in_pt: Vector3 = pb if pa.z < pb.z else pa
	for loot: StringName in [LOOT_MEDIUM, LOOT_HEAVY]:
		if not await _go(_of(OF_LANE_START), 1.0, 120.0):
			return await _fail("lane start")
		if await _get_bag(loot) == null:
			return await _fail("bag")
		var stuck0: int = pilot.stuck_spots.size()
		var t0: float = rt.heist_time_s
		if not await _go(out_pt, 0.4, 120.0):
			return await _fail("lane -> LD door (%s)" % loot)
		if not door.is_open and not await pilot.use(_comp(door), 60.0, func() -> bool: return door.is_open):
			return await _fail("LD door open")
		var v_sill: float = await _walk_straight(in_pt, 10.0)
		if not await _go(_of(OF_LD_IN), 0.6, 60.0):
			return await _fail("into LD (%s)" % loot)
		note("DOCK %s: lane -> LD in %.1f s, sill crossing %.2f m/s, STUCK rows %d" % [loot, rt.heist_time_s - t0,
			v_sill, pilot.stuck_spots.size() - stuck0])
		await _go(in_pt, 0.3, 60.0)
		var w: int = int((pilot.crew.carried_bag as LootBag).weight)
		var reach: float = Tweak.crew().bag_throw_distance_m[w]
		# Throw stands, nearest the dock first: on the door's threshold, 0.7 m out in the lane, then (out of reach)
		# walked out toward the van until its zone is within the throw. The first that secures the bag counts.
		var dir: Vector3 = (e1.global_position - door.global_position)
		dir.y = 0.0
		var stands: Array[Vector3] = [pilot.stand_point(door.global_position), pilot.stand_point(door.global_position
			+ (out_pt - door.global_position).normalized() * 0.7), pilot.stand_point(e1.global_position
			- dir.normalized() * (_zone_extent(e1, dir.normalized()) + reach * 0.6))]
		var ok: bool = false
		for si: int in stands.size():
			if not pilot.crew.is_carrying_bag():
				var lb: LootBag = _bag_near(pilot.crew.global_position, 4.0)
				if lb == null or not await pilot.use(_comp(lb), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
					break
			await _go(stands[si], 0.25, 30.0)
			var r: Dictionary = await _throw(e1.global_position, 10.0)
			ok = bool(r.get("secured", false))
			_throw_note("LD -> E1 %s stand %d %s: %.1f m from the zone, %.1f m from the door" % [loot, si,
				Po5Pilot._v(pilot.crew.global_position), _zone_dist(pilot.crew.global_position, e1),
				pilot.flat_dist(pilot.crew.global_position, door.global_position)], r, "OK in E1" if ok
				else "FAIL not in E1")
			if ok:
				break
		await shot("dock_%s" % String(loot).get_slice(".", 1))
		if not ok:
			return await _fail("LD -> E1 throw (%s)" % loot)
		if pilot.stuck_spots.size() > stuck0:
			return await _fail("STUCK on the lane / LD sill (%s)" % loot)
	return true


## §7.8: BC east -> the Tannery fire exit (propped) -> the E2 van zone with a HEAVY bag.
func _test_fire_exit() -> bool:
	var force: Dictionary = {&"escape": [&"esc_van_tannery"], &"side_door": [&"door_fire_propped"]}
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts(force, OF_SPAWN_TANNERY), true):
		return false
	if not await _mask():
		return await _fail("mask")
	var e2: SecureZone = _x("e2_secure") as SecureZone
	var door: Door = _x("fire_exit") as Door
	if e2 == null or door == null:
		return await _fail("no E2 zone (%s) / fire exit door (%s)" % [e2, door])
	if not await _go(_of(OF_BC_EAST), 0.5, 120.0):
		return await _fail("in through the fire exit to BC east")
	if await _get_bag(LOOT_HEAVY) == null:
		return await _fail("bag")
	var stuck0: int = pilot.stuck_spots.size()
	var t0: float = rt.heist_time_s
	if not door.is_open and not await pilot.use(_comp(door), 30.0, func() -> bool: return door.is_open):
		return await _fail("fire exit (push bar)")
	# Out through the fire exit (outward = away from BC east), then throw at the zone from 0.9 m / 1.8 m outside.
	var outward: Vector3 = door.global_position - _of(OF_BC_EAST)
	outward.y = 0.0
	outward = outward.normalized()
	var ok: bool = false
	for si: int in 2:
		if not pilot.crew.is_carrying_bag():
			var lb: LootBag = _bag_near(pilot.crew.global_position, 4.0)
			if lb == null or not await pilot.use(_comp(lb), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
				break
		var stand: Vector3 = pilot.stand_point(door.global_position + outward * (0.9 + 0.9 * si))
		if not await _go(stand, 0.3, 60.0):
			return await _fail("out to the E2 throw stand")
		var aim: Vector3 = e2.global_position
		var r: Dictionary = await _throw(aim, 10.0)
		ok = bool(r.get("secured", false))
		_throw_note("fire exit -> E2 HEAVY stand %d %s (%.1f m from the zone; BC east -> stand %.1f s, STUCK rows %d)"
			% [si, Po5Pilot._v(pilot.crew.global_position), _zone_dist(pilot.crew.global_position, e2),
			rt.heist_time_s - t0, pilot.stuck_spots.size() - stuck0], r, "OK in E2" if ok else "FAIL not in E2")
		if ok:
			break
	await shot("fire_exit_e2")
	if not ok:
		return await _fail("fire exit -> E2 throw")
	if pilot.stuck_spots.size() > stuck0:
		return await _fail("STUCK between BC east and E2")
	return true


# --- Ghost line (design doc "The hardest roll and its ghost line") --------------------------------------------------

## The ghost roll pinned: force_variants for slot groups, a variant-table copy for the scalars and the rare event.
func _ghost_opts() -> Dictionary:
	var opts: Dictionary = _of_opts(GHOST_FORCE, &"")
	var path: String = _map if _map != "" else HeistLauncher.map_path(OF_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		return opts
	var inst: Node = (load(path) as PackedScene).instantiate()
	var vt: HeistVariantTable = inst.get(&"variant_table") as HeistVariantTable
	if vt != null:
		var t: HeistVariantTable = vt.duplicate(true) as HeistVariantTable
		for s: Dictionary in t.scalars:
			var id: StringName = StringName(s.get("id", &""))
			if GHOST_SCALARS.has(id):
				var w: PackedFloat32Array = PackedFloat32Array()
				for val: Variant in s.get("values", []):
					w.append(1.0 if val == GHOST_SCALARS[id] else 0.0)
				s["weights"] = w
				s.erase("weights_by_difficulty")
		for ev: Dictionary in t.rare_events:
			ev["chance"] = 1.0 if StringName(ev.get("id", &"")) == GHOST_RARE else 0.0
		opts["variant_table"] = t
	inst.free()
	return opts


func _ghost_loadout() -> Loadout:
	var lo: Loadout = CrewWeapons.build_loadout(null).duplicate()
	lo.deployable = &"deployable.ecm"
	var mods: Dictionary = lo.modifiers.duplicate()
	mods[&"stealth.ecm_extra"] = 1.0  # the gate flag + 1 unit: 2 ECM charges ("one ECM (2 charges)")
	lo.modifiers = mods
	return lo


func _step(label: String, t0: float) -> void:
	note("GHOST step %s done at t=%.1f (+%.1f s)" % [label, rt.heist_time_s, rt.heist_time_s - t0])


func _deploy_ecm() -> bool:
	var started: Array[bool] = [false]
	var cb: Callable = func(_id: int, _d: float) -> void: started[0] = true
	EventBus.ecm_started.connect(cb)
	await pilot.inp.hold(&"deploy", 2.4)
	await wait_s(0.3)
	EventBus.ecm_started.disconnect(cb)
	note("ECM %s" % ("on" if started[0] else "NOT started"))
	return started[0]


func _guard_near(at: Vector3, r: float) -> NpcBase:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g != null and g.is_alive() and pilot.flat_dist(g.global_position, at) <= r and absf(g.global_position.y - at.y) < 2.0:
			return g
	return null


func _civ_near(at: Vector3, r: float) -> NpcBase:
	for n: Node in rt.npcs(&"civilian"):
		var c: NpcBase = n as NpcBase
		if c != null and c.is_alive() and pilot.flat_dist(c.global_position, at) <= r and absf(c.global_position.y - at.y) < 2.0:
			return c
	return null


## LEAD 2026-10-21 (GPU-15: the pilot got "aimed <none> at 2.22 m" at the BondSafe): can a player use every OF loud
## interactable from its UsePoint? Loud (alarm via the StealthDirector, NPCs out), vault gate + vault door opened
## instantly (SHORTCUT, logged), burn-through done (lid, rope ladder, hoist on). Then for each Safe / DrillPoint /
## BagLift / DepositBox / vault door / time lock / lid component: walk to its stand like a player, aim, press interact
## and log whether the hold STARTED (component `started`) within 6 s, plus availability and the aimed component.
func _test_interact() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts({}, OF_SPAWN_LANE), true):
		return false
	if not await _mask():
		return await _fail("mask")
	if not rt.went_loud:
		HeistRuntime.get_service(G.SVC_STEALTH).call(&"raise_alarm", &"ofp_interact", 0)
		await wait_s(0.5)
		rt.isolate_npc(null)
		note("SHORTCUT alarm raised through the StealthDirector (loud sweep), NPCs out")
	var vault_door: Door = _x("vault_door") as Door
	for d: Door in [_tagged(&"vault_gate") as Door, vault_door]:
		if d != null and not d.is_open:
			d.set_open(true, true)
			note("SHORTCUT %s opened instantly" % d.name)
	await wait_s(1.0)
	var rows: PackedStringArray = PackedStringArray()
	var ok_n: Array[int] = [0]
	# Pass 1, before the burn-through: the rope ladder hangs in VT's walkway and free climb grabs every walk past it
	# (r254 first try: 20 min of ladder ping-pong), so the hoist and the lid wait for pass 2.
	var first: Array[InteractableComponent] = []
	var late: Array[InteractableComponent] = []
	for n: Node in rt.find_children("*", "InteractableComponent", true, false):
		var ic: InteractableComponent = n as InteractableComponent
		var o: Node = ic.owner_node()
		var nm: String = String(o.name) if o != null else ""
		if o is BagLift or nm.contains("Lid"):
			late.append(ic)
		elif o is Safe or o is DrillPoint or o is DepositBox or nm.contains("TimeLock") or nm.contains("Thermal"):
			first.append(ic)
	note("INTERACT sweep: %d before the burn-through, %d after (vault door opened by the shortcut: not swept)" % [
		first.size(), late.size()])
	await _sweep(_nearest_order(first), rows, ok_n)
	var rope: Ladder = _x("rope_ladder") as Ladder
	var hoist: BagLift = _x("hoist") as BagLift
	if rope != null and hoist != null:
		await _enable_hole(rope, hoist)
	_ladders_ok = true
	await _sweep(_nearest_order(late), rows, ok_n)
	_ladders_ok = false
	note("INTERACT summary: %d / %d started" % [ok_n[0], rows.size()])
	await shot("interact_end")
	return true


func _nearest_order(list: Array[InteractableComponent]) -> Array[InteractableComponent]:
	var out: Array[InteractableComponent] = []
	var left: Array[InteractableComponent] = list.duplicate()
	var at: Vector3 = pilot.crew.global_position
	while not left.is_empty():
		var best: int = 0
		for k: int in left.size():
			if left[k].global_position.distance_to(at) < left[best].global_position.distance_to(at):
				best = k
		at = left[best].global_position
		out.append(left[best])
		left.remove_at(best)
	return out


func _sweep(list: Array[InteractableComponent], rows: PackedStringArray, ok_n: Array[int]) -> void:
	var isys: InteractionSystem = rt.interaction
	for ic: InteractableComponent in list:
		if not is_instance_valid(ic):
			continue
		var o: Node = ic.owner_node()
		var label: String = "%s/%s (%s)" % [o.name if o != null else "?", ic.name, ic.kind]
		if not ic.enabled:
			rows.append("%s: disabled" % label)
			note("INTERACT %s: disabled" % label)
			continue
		var started: Array[bool] = [false]
		var cb: Callable = func(c: Node) -> void:
			if c == pilot.crew:
				started[0] = true
		ic.started.connect(cb)
		var avail0: StringName = ic.availability(pilot.crew)
		var ret: bool = await pilot.use(ic, 6.0, func() -> bool: return started[0])
		ic.started.disconnect(cb)
		pilot.inp.release(&"interact")
		var aimed: InteractableComponent = isys.aimed_component(pilot.crew)
		var row: String = "%s: %s (avail before '%s', after '%s', aimed %s, eye dist %.2f, use() %s)" % [label,
			"STARTED" if started[0] else "NOT STARTED", avail0, ic.availability(pilot.crew),
			aimed.owner_node().name if aimed != null and aimed.owner_node() != null else "<none>",
			pilot.crew.eye_position().distance_to(ic.global_position), ret]
		note("INTERACT " + row)
		rows.append(row)
		if started[0]:
			ok_n[0] += 1
		await wait_s(1.0)
		if not isys.session(pilot.crew.slot).is_empty():  # step off to cancel a hold still running
			await _go(pilot.crew.global_position + Vector3(0.8, 0, 0), 0.3, 3.0)


## How many of 8 BB eye points outside LockerDoor see `pos` at chest height (the lkprobe set).
func _bb_eyes_see(pos: Vector3, h: float = 0.7) -> int:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var seen: int = 0
	for e: Vector2 in [Vector2(4.0, 8.5), Vector2(5.0, 9.0), Vector2(6.0, 9.0), Vector2(6.5, 10.0), Vector2(8.0, 8.5),
			Vector2(3.0, 8.5), Vector2(10.0, 8.5), Vector2(5.0, 11.0)]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_of(Vector3(e.x, -4.0 + 1.6, e.y)),
			pos + Vector3(0, h, 0), 1)
		if space.intersect_ray(q).is_empty():
			seen += 1
	return seen


## Headless probe (no pilot movement needed): LK floor points on the navmesh at floor height, reachable from
## GHOST_LK_WAIT, and hidden at crouch height from BB eyes outside LockerDoor. Picks GHOST_LK_HIDES (r252b).
func _test_lkprobe() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), _ghost_diff as Enums.Difficulty, _ghost_opts(), false):
		return false
	var map: RID = pilot.crew.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var from: Vector3 = pilot.stand_point(_of(GHOST_LK_WAIT))
	var eyes: Array[Vector3] = []
	for e: Vector2 in [Vector2(4.0, 8.5), Vector2(5.0, 9.0), Vector2(6.0, 9.0), Vector2(6.5, 10.0), Vector2(8.0, 8.5),
			Vector2(3.0, 8.5), Vector2(10.0, 8.5), Vector2(5.0, 11.0)]:
		eyes.append(_of(Vector3(e.x, -4.0 + 1.6, e.y)))
	# The manager's walk BB -> LockerDoor -> his WC stop (ManagerLKWC), sampled every 0.5 m at eye height.
	var mgr_path: PackedVector3Array = NavigationServer3D.map_get_path(map, pilot.stand_point(_of(Vector3(5.0, -4.0, 9.5))),
		pilot.stand_point(_of(GHOST_MGR_WC)), true)
	var mgr_eyes: Array[Vector3] = []
	for i: int in range(1, mgr_path.size()):
		var seg: float = mgr_path[i - 1].distance_to(mgr_path[i])
		for k: int in int(ceilf(seg / 0.5)) + 1:
			mgr_eyes.append(mgr_path[i - 1].lerp(mgr_path[i], minf(1.0, k * 0.5 / maxf(seg, 0.01))) + Vector3(0, 1.6, 0))
	note("LKPROBE manager path %s (%d eye samples)" % [", ".join(Array(mgr_path).map(Po5Pilot._v)), mgr_eyes.size()])
	# Per path sample: BB eyes on him (h 0.5, where he'd lie tied), and the first sample each candidate wait spot sees.
	var rows: PackedStringArray = PackedStringArray()
	for i: int in mgr_eyes.size():
		rows.append("%d %s bb %d" % [i, Po5Pilot._v(mgr_eyes[i] - Vector3(0, 1.6, 0)), _bb_eyes_see(mgr_eyes[i] - Vector3(0, 1.6, 0), 0.5)])
	note("LKPROBE manager samples: %s" % "; ".join(rows))
	for xi: int in range(1, 20):
		for zi: int in range(1, 14):
			var cand: Vector3 = NavigationServer3D.map_get_closest_point(map, _of(Vector3(xi * 0.5, -4.0, zi * 0.5)))
			if pilot.flat_dist(cand, _of(Vector3(xi * 0.5, -4.0, zi * 0.5))) > 0.15 or _bb_eyes_see(cand, 0.7) > 0:
				continue
			var first: int = -1
			for i: int in mgr_eyes.size():
				var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(mgr_eyes[i], cand + Vector3(0, 0.7, 0), 1)
				if space.intersect_ray(q2).is_empty():
					first = i
					break
			if first >= 0 and pilot.flat_dist(mgr_eyes[first], cand) >= 3.5:
				note("LKPROBE wait (%.1f, %.1f): first seen from sample %d at %.1f m" % [xi * 0.5, zi * 0.5, first,
					pilot.flat_dist(mgr_eyes[first], cand)])
	var hits: PackedStringArray = PackedStringArray()
	for xi: int in range(1, 20):
		for zi: int in range(1, 14):
			var want: Vector3 = _of(Vector3(xi * 0.5, -4.0, zi * 0.5))
			var got: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
			if pilot.flat_dist(got, want) > 0.15 or absf(got.y - want.y) > 0.3:
				continue
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, got, true)
			if path.is_empty() or path[path.size() - 1].distance_to(got) > 0.3:
				continue
			var seen: int = 0
			for eye: Vector3 in eyes:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, got + Vector3(0, 0.7, 0), 1)
				if space.intersect_ray(q).is_empty():
					seen += 1
			var mseen: int = 0
			for eye: Vector3 in mgr_eyes:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, got + Vector3(0, 0.7, 0), 1)
				if space.intersect_ray(q).is_empty():
					mseen += 1
			hits.append("(%.1f, %.1f) seen_by %d mgr %d" % [xi * 0.5, zi * 0.5, seen, mseen])
	note("LKPROBE from %s: %d floor points: %s" % [Po5Pilot._v(from), hits.size(), "; ".join(hits)])
	# CQ (x 10-13, z 3-7) as the time-lock refuge (haz_u): BB corridor eye points (x 0-47, z 7.6 / 8.4) seeing each point.
	var cq: PackedStringArray = PackedStringArray()
	for xi: int in range(21, 26):
		for zi: int in range(7, 14):
			var want: Vector3 = _of(Vector3(xi * 0.5, -4.0, zi * 0.5))
			var got: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
			if pilot.flat_dist(got, want) > 0.15:
				continue
			var seers: PackedStringArray = PackedStringArray()
			for bx: int in range(0, 48):
				for bz: float in [7.6, 8.4]:
					var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_of(Vector3(bx, -4.0 + 1.6, bz)),
						got + Vector3(0, 0.7, 0), 1)
					if space.intersect_ray(q).is_empty():
						seers.append("%d/%.1f" % [bx, bz])
			cq.append("(%.1f, %.1f) %d [%s]" % [xi * 0.5, zi * 0.5, seers.size(), ",".join(seers)])
	note("LKPROBE CQ: %s" % "; ".join(cq))
	# SA (x 13-16, z 0-7) between B and G as the step 2 -> 3 wait (haz_x: on the B landing behind the door, the vault guard
	# walking BB saw it at 2 m): corridor eye points on BB (y -4) and BC (y 0), x 0-47, z 7.6 / 8.4, seeing each point.
	var sa: PackedStringArray = PackedStringArray()
	var seen_sa: Dictionary = {}
	for yi: int in range(0, 9):
		for xi: int in range(27, 32):
			for zi: int in range(1, 14):
				var want: Vector3 = _of(Vector3(xi * 0.5, -4.0 + yi * 0.5, zi * 0.5))
				var got: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
				if pilot.flat_dist(got, want) > 0.2 or absf(got.y - want.y) > 0.3:
					continue
				var key: String = Po5Pilot._v(got)
				if seen_sa.has(key):
					continue
				seen_sa[key] = true
				var nb: int = 0
				var ng: int = 0
				for bx: int in range(0, 48):
					for bz: float in [7.6, 8.4]:
						for fy: float in [-4.0, 0.0]:
							var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_of(Vector3(bx, fy + 1.6, bz)),
								got + Vector3(0, 0.7, 0), 1)
							if space.intersect_ray(q).is_empty():
								if fy < -1.0:
									nb += 1
								else:
									ng += 1
				sa.append("%s bb %d bc %d" % [key, nb, ng])
	note("LKPROBE SA: %s" % "; ".join(sa))
	# VT (x 14-34, z 13-25) as the step 6 wait with a bag (haz_zd: the vault guard back on his VC post after the time lock):
	# VC eye points (x 14.5-33.5, z 9.6 / 11 / 12.4) seeing each VT floor point; only the hidden ones are listed.
	var vt: PackedStringArray = PackedStringArray()
	for xi: int in range(29, 68, 2):
		for zi: int in range(27, 50, 2):
			var want: Vector3 = _of(Vector3(xi * 0.5, -4.0, zi * 0.5))
			var got: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
			if pilot.flat_dist(got, want) > 0.2:
				continue
			var nv: int = 0
			for vx: int in range(29, 68, 2):
				for vz: float in [9.6, 11.0, 12.4]:
					var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_of(Vector3(vx * 0.5, -4.0 + 1.6, vz)),
						got + Vector3(0, 0.7, 0), 1)
					if space.intersect_ray(q).is_empty():
						nv += 1
			if nv == 0:
				vt.append("(%.1f, %.1f)" % [xi * 0.5, zi * 0.5])
	note("LKPROBE VT hidden from VC: %s" % ", ".join(vt))
	var spawns: PackedStringArray = PackedStringArray()
	for sp: Node in rt.find_children("*", "LootSpawn", true, false):
		var ls: LootSpawn = sp as LootSpawn
		if ls != null and _in_rect(ls.global_position, OF_VT_RECT) and absf(ls.global_position.y - OF_FFL[0]) < 2.0:
			spawns.append("%s %s %s x%d vis %s" % [ls.name, Po5Pilot._v(ls.global_position), ls.loot_id, ls.remaining,
				ls.is_visible_in_tree()])
	note("LKPROBE VT loot: %s" % "; ".join(spawns))
	return true


func _test_ghost() -> bool:
	var opts: Dictionary = _ghost_opts()
	opts["loadouts"] = {0: _ghost_loadout()}
	if not await _launch(OF_HEIST, _of_seed(), _ghost_diff as Enums.Difficulty, opts, false):
		return false
	_ghost_stair_wait = false
	var t_start: float = rt.heist_time_s
	var t0: float = t_start
	var ok: bool = true
	for st: Callable in [_g1_lane, _g2_dock, _g3_keycard, _g4_code, _g5_vault, _g6_bags, _g7_throw]:
		if _alarm != &"":
			ok = await _fail("alarm before %s" % st.get_method())
			break
		if not await st.call():
			ok = await _fail(st.get_method())
			break
		_step(st.get_method(), t0)
		t0 = rt.heist_time_s
	_peaks_table()
	note("GHOST total %.1f s game time (%s); alarm %s; ECM left %s" % [rt.heist_time_s - t_start, "complete" if ok
		else "stopped", _alarm, _ecm_left()])
	return ok


## Debug only (not the acceptance): steps 6-7 from a SHORTCUT start, to iterate on the bag trips without the 25 min
## before them. Masked at CQ's corner (teleport, logged), the vault gate and door opened instantly, one ECM spent.
func _test_ghost6() -> bool:
	var opts: Dictionary = _ghost_opts()
	opts["loadouts"] = {0: _ghost_loadout()}
	if not await _launch(OF_HEIST, _of_seed(), _ghost_diff as Enums.Difficulty, opts, false):
		return false
	if not await _mask():
		return false
	rt.teleport_crew(pilot.crew.slot, Transform3D(Basis.IDENTITY, pilot.stand_point(_of(GHOST_CQ_HIDE)) + Vector3(0, 0.05, 0)))
	for d: Door in [_tagged(&"vault_gate") as Door, _x("vault_door") as Door]:
		if d != null and not d.is_open:
			d.set_open(true, true)
	# The manager is tied in LK by step 3 in the real line (ghost6_c: walking his route he saw the bag trip in BB, t=529).
	for n: Node in rt.npcs(&"civilian"):
		if n is NpcBase and _has_tag(n as NpcBase, "keycard_carrier"):
			n.get_parent().remove_child(n)
			n.queue_free()
			note("SHORTCUT ghost6: the manager despawned (tied in LK in the real line)")
	var reg: CodeRegistry = CodeRegistry.of(pilot.crew)
	if reg != null:
		reg.reveal(&"vault", pilot.crew.slot)
	note("SHORTCUT ghost6: masked, teleported to CQ's corner, vault gate + door opened instantly, vault code revealed")
	await wait_s(2.0)
	_ghost_stair_wait = true
	var t0: float = rt.heist_time_s
	for st: Callable in [_g6_bags, _g7_throw]:
		if _alarm != &"":
			return await _fail("alarm before %s" % st.get_method())
		if not await st.call():
			return await _fail(st.get_method())
		_step(st.get_method(), t0)
		t0 = rt.heist_time_s
	return true


## Headless probe (debug): the cash lift's landings, car and doors; a bag spawned at the car's centre, where it rests and
## whether bags_in_car counts it (ghost6_e/f: every drop came to rest at (11.5, -4, 0.4), never in the car).
func _test_liftprobe() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), _ghost_diff as Enums.Difficulty, _ghost_opts(), false):
		return false
	var lift: BagLift = _x("cash_lift") as BagLift
	if lift == null:
		return await _fail("no cash lift")
	for i: int in lift.landing_count():
		note("LIFTPROBE landing %d at %s, car at %s" % [i, Po5Pilot._v(lift.landing_transform(i).origin),
			Po5Pilot._v(lift.car_transform_at(i).origin)])
	note("LIFTPROBE now at landing %d moving %s, car %s size %s" % [lift.landing, lift.is_moving(),
		Po5Pilot._v(lift.car_transform().origin), lift.car_size_m])
	for d: Node in lift.find_children("*", "Door", true, false):
		note("LIFTPROBE door %s at %s open %s" % [d.name, Po5Pilot._v((d as Node3D).global_position), (d as Door).is_open])
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	var at: Vector3 = lift.car_transform().origin + Vector3.UP * 0.5
	var bag: LootBag = mgr.spawn_bag(LOOT_MEDIUM, Transform3D(Basis.IDENTITY, at), false) if mgr != null else null
	await wait_s(3.0)
	note("LIFTPROBE bag spawned at %s rests at %s; bags_in_car %d" % [Po5Pilot._v(at),
		Po5Pilot._v(bag.global_position) if bag != null else "-", lift.bags_in_car().size()])
	return true


## Debug (windowed): C's cash-lift fix (r272, test_of_cash_lift_throw): the plain throw from the landing stand, as
## G1 / GH use (_bag_into_car), two bags (liftdoor_272 PASS; it replaced step 6's low-throw workaround).
func _test_liftdoor() -> bool:
	if not await _launch(OF_HEIST, _of_seed(), _ghost_diff as Enums.Difficulty, _ghost_opts(), false):
		return false
	rt.isolate_npc(null)
	if not await _mask():
		return false
	var lift: BagLift = _x("cash_lift") as BagLift
	var low: int = _lift_nearest_landing(lift, _of(GHOST_CQ_AT))
	var cq_stand: Vector3 = pilot.stand_point(lift.landing_transform(low).origin + lift.landing_transform(low).basis.z
		* -1.2)
	for k: int in 2:
		rt.teleport_crew(pilot.crew.slot, Transform3D(Basis.IDENTITY, pilot.stand_point(_of(GHOST_CQ_AT)) + Vector3(0, 0.05, 0)))
		note("SHORTCUT liftdoor: NPCs out, teleported into CQ")
		await wait_s(1.0)
		if await _get_bag(LOOT_MEDIUM) == null or not await _bag_into_car(lift, cq_stand):
			return await _fail("door throw %d" % k)
	return lift.bags_in_car().size() == 2


func _ecm_left() -> String:
	var ds: DeployableSystem = rt.service(DeployableSystem.SERVICE) as DeployableSystem
	return str(ds.count_of_kind(pilot.crew.slot, &"ecm")) if ds != null else "?"


## 1. Plaza spawn, unmasked down Tannery Street into Ledger Lane (PUBLIC); to the dumpsters.
func _g1_lane() -> bool:
	for wp: Vector3 in GHOST_STREET:  # outside the bank: the navmesh's shortest way runs through the hall
		if not await _go(_of(wp), 1.5, 240.0):
			return false
	return await _go(_of(GHOST_MASK_AT), 1.0, 240.0)


## 2. rover_dock at his Tannery-corner smoke pause -> mask behind the dumpsters -> ECM #1 -> lockpick the personnel
## door -> LD -> BC west -> SA down.
func _g2_dock() -> bool:
	# The doc's cue is rover_dock's smoke pause at the Tannery corner; the first live run (G1 + OF-A6 f326ad00) never saw
	# him there: he stood at (14, 0, -5) by the dock door and filled 0 -> 1.0 in 1.3 s at 2.6 m. Read the lane instead:
	# wait until every guard in Ledger Lane is > LANE_CLEAR_M from the dock door, logging where they walk.
	var door_at: Vector3 = _of(OF_LD_DOOR)
	var waited: float = 0.0
	# Inside too: rover_hall's loop (b) checks LD (doc), so a smoke window with him in LD is no window (r256a: lockpicked
	# into Npc_guard3 standing 5 m inside). Skip that cue and take the next one, up to 3 tries.
	# ...and BC by DockCorridorDoor: rover_hall's loop (b) comes through it into LD (haz_b: waited inside LD, he walked in
	# and found the pilot at 1 m). Inside the building = z > 0.5.
	var cdoor_n: Node3D = rt.find_child("DockCorridorDoor", true, false) as Node3D
	# 20 m at the cue: mask + ECM + the 8 s lockpick take ~15 s, about 22 m of rover_hall's walk (haz_c: > 10 m at the cue,
	# 6 m off DockCorridorDoor once the pilot was in). Re-checked at 10 m right before the lockpick.
	# Standing guards only within 8 m of either door: a posted guard at (19.5, 0, 1.1) held all 4 smoke windows (haz_e).
	var ld_last: Dictionary = {}
	var ld_busy: Callable = func(r: float) -> String:
		var rh: String = _rover_hall_gone_east()
		if rh != "":
			return rh
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or g.global_position.z <= 0.5 or absf(g.global_position.y) >= 1.5:
				continue
			var id: int = g.get_instance_id()
			var moving: bool = ld_last.has(id) and g.global_position.distance_to(ld_last[id]) > 0.15
			var was: Vector3 = ld_last.get(id, g.global_position)
			ld_last[id] = g.global_position
			# BC / LD side only (z < 12): the lobby guard's hall post (10.9, 0, 21.8) is 14 m off but another room (haz_d).
			var dc: float = pilot.flat_dist(g.global_position, cdoor_n.global_position) if cdoor_n != null else 999.0
			# Walkers count only while closing on the corridor door (haz_v: rover_hall walking away east after his check).
			var closing: bool = moving and dc < (pilot.flat_dist(was, cdoor_n.global_position) if cdoor_n != null else 999.0)
			if pilot.flat_dist(g.global_position, door_at) < 8.0 or dc < 8.0 \
					or (g.global_position.z < 12.0 and closing and dc < r):
				return "%s %s" % [g.name, Po5Pilot._v(g.global_position)]
		return ""
	# One loop per smoke window: the cue, LD clear, the lane clear, mask, then LD again before the ECM is spent (haz_h/i:
	# rover_hall turned toward LD between the cue at t=78 and t=83, flagged only after the ECM was down).
	var clear: bool = false
	for _win: int in 5:
		clear = await _smoke_cue(300.0)
		ld_busy.call(20.0)  # first sample: walking needs two
		await wait_s(0.5)
		var who: String = ld_busy.call(20.0)
		if who != "":
			# rover_hall heading in for his LD check: let it pass inside this smoke window, then go (r260 haz_t's pass did
			# this by luck: in the lane during his t=185 check). Up to 25 s of the 33-40 s window.
			var t_cue: float = rt.heist_time_s
			var ld0: Array[float] = [_rh_ld_t]
			await wait_until(func() -> bool:
				return _rh_ld_t > ld0[0] and rt.heist_time_s - _rh_ld_t >= 4.0 and ld_busy.call(20.0) == "", 25.0)
			who = ld_busy.call(20.0)
			if who == "" and _rh_ld_t > ld0[0]:
				note("GHOST rover_hall's LD check passed (t=%.0f), %.0f s into this smoke window: going" % [_rh_ld_t,
					rt.heist_time_s - t_cue])
			else:
				note("GHOST LD occupied (%s): skipping this smoke window" % who)
				await wait_until(func() -> bool: return ld_busy.call(20.0) == "", 90.0)
				continue
		while waited < 600.0 and not clear:
			clear = true
			var where: PackedStringArray = PackedStringArray()
			for n: Node in rt.npcs(&"guard"):
				var g: NpcBase = n as NpcBase
				if g == null or not g.is_alive() or g.global_position.z > 0.5 or absf(g.global_position.y) > 1.5:
					continue
				where.append("%s %s" % [g.name, Po5Pilot._v(g.global_position)])
				if pilot.flat_dist(g.global_position, door_at) < LANE_CLEAR_M \
						or pilot.flat_dist(g.global_position, pilot.crew.global_position) < 12.0:
					clear = false
			if int(waited) % 20 == 0:
				note("GHOST lane guards: %s" % (", ".join(where) if not where.is_empty() else "none"))
			if not clear:
				await wait_s(1.0)
				waited += 1.0
		note("GHOST lane %s after %.0f s" % ["clear" if clear else "NOT clear (going anyway)", waited])
		# Watch 5 s, UNMASKED, before committing (haz_j: one sample at t~80 missed rover_hall turning for LD at ~t 81-83).
		# The mask is the commitment: it doesn't come off (PD2), and a masked crew waiting in the lane for the next
		# window was spotted by rover_dock walking back from his smoke (haz_k, t=118 at 14 m).
		ld_busy.call(20.0)
		for _k: int in 10:
			await wait_s(0.5)
			who = ld_busy.call(20.0)
			if who != "":
				break
		if who != "":
			note("GHOST LD busy in the 5 s watch (%s): still unmasked, next smoke window" % who)
			await wait_until(func() -> bool: return ld_busy.call(20.0) == "", 90.0)
			continue
		if not await _mask():
			return false
		break
	if not await _deploy_ecm():
		return false
	var door: Door = _x("ld_door") as Door
	if door == null or (not door.is_open and not await pilot.use(_comp(door), 30.0, func() -> bool: return door.is_open)):
		return false
	# Peek through LD -> BC too: on Hazardous (D-150) rover_hall stood 1.7 m behind DockCorridorDoor when the pilot
	# opened it (haz_a, t=100). Not clear: back out to the lane beside the dock door, out of the doorway's line (haz_b/c/f:
	# waiting inside LD, rover_hall's loop (b) walked in and found the pilot), and come back in once BC is clear.
	var cdoor: Node3D = rt.find_child("DockCorridorDoor", true, false) as Node3D
	if cdoor != null:
		var hide: Vector3 = pilot.stand_point(door.global_position + Vector3(-2.0, 0.0, -1.5))
		await _wait_spot_clear(cdoor.global_position, OF_FFL[1], "dock corridor door", hide, Callable(), 0.5)
	# Down SA to its half landing and wait there for BB (haz_w, r263: the dock done 24 s sooner, the vault guard's loop (b)
	# walk down BB met the pilot stepping out of SA at t=184; haz_x: waiting on the B landing behind the door, he walked
	# past it at 2 m). lkprobe: GHOST_SA_MID is seen from no BB or BC corridor point.
	if not await _go(_of(Vector3(OF_SA_DOOR_X, OF_FFL[1], OF_CORRIDOR_Z)), 0.6, 240.0) \
			or not await _go(_of(Vector3(OF_SA_CORE.x, OF_FFL[1], OF_SA_CORE.z)), 0.4, 240.0):
		return false
	return await _down_to_bb()


## The design doc's own cue (A 160b8e07 hub loops: LaneCorner smoke 20-40 s): a Ledger Lane guard ARRIVING at the
## Tannery corner smoke spot (GHOST_SMOKE_AT, within 5 m) and starting `smoke*` (or standing still there for 1 s). Logs the lane guards
## every 10 s (where his loop goes). False after `max_s` (the caller falls back to the lane-distance rule).
func _smoke_cue(max_s: float) -> bool:
	var at: Vector3 = _of(GHOST_SMOKE_AT)
	var still: Dictionary = {}
	var last: Dictionary = {}
	# The doc says when he STARTS the pause: a guard already smoking on arrival may be near its end (ghost run 5:
	# cue at once, back at the dock door 24 s later), so a guard must first be seen away from the corner / not
	# smoking, then arrive and light up.
	var armed: Dictionary = {}
	var t: float = 0.0
	while t < max_s:
		var where: PackedStringArray = PackedStringArray()
		for n: Node in rt.npcs(&"guard"):
			var g: NpcBase = n as NpcBase
			if g == null or not g.is_alive() or g.global_position.z > 0.5 or absf(g.global_position.y) > 1.5:
				continue
			var id: int = g.get_instance_id()
			var moved: float = g.global_position.distance_to(last.get(id, g.global_position))
			last[id] = g.global_position
			still[id] = float(still.get(id, 0.0)) + 0.5 if moved < 0.1 else 0.0
			var drv: AnimDriver = AnimDriver.of(g)
			var clip: String = String(drv.clip) if drv != null else ""
			where.append("%s %s %s" % [g.name, Po5Pilot._v(g.global_position), clip])
			var at_corner: bool = pilot.flat_dist(g.global_position, at) < 5.0
			if not at_corner or not clip.begins_with("smoke"):
				armed[id] = true
			if bool(armed.get(id, false)) and at_corner and (clip.begins_with("smoke") or float(still[id]) >= 1.0):
				note("GHOST smoke cue: %s at %s clip '%s' (still %.1f s) after %.0f s" % [g.name,
					Po5Pilot._v(g.global_position), clip, float(still[id]), t])
				return true
		if int(t * 2.0) % 20 == 0:
			note("GHOST lane guards (waiting for the smoke cue): %s" % (", ".join(where) if not where.is_empty() else "none"))
		await wait_s(0.5)
		t += 0.5
	note("GHOST no smoke cue at %s in %.0f s: falling back to the lane-distance rule" % [Po5Pilot._v(at), max_s])
	return false


## 3. Wait in LK for the manager's WC break; shout him down, tie him (tie 1), take the keycard.
func _g3_keycard() -> bool:
	# Wait for the manager behind the WC partition beside his stop (haz_q: in the LK hide at (1.5, 4) he saw the pilot
	# from LockerDoor at 5 m and ran to rover_basement; NPCs see all round within 1.5 m and 120 deg wide at 5 m).
	# lkprobe: (8.5, 0.5) is seen by none of his 33 path samples and none of the 8 BB eyes. Go once BB is quiet.
	var wc_hide: Vector3 = pilot.stand_point(_of(GHOST_MGR_WC_HIDE))
	await _wait_spot_clear(wc_hide, OF_FFL[0], "LK WC", _lk_hide())
	# The LK navmesh runs through WCPartitionLK2 (not in the bake: haz_r stuck on it for 60 s): round its open end first.
	if not await _go(pilot.stand_point(_of(GHOST_MGR_SHOUT)), 0.4, 40.0) or not await _go(wc_hide, 0.3, 20.0):
		return false
	pilot.inp.press(&"crouch")
	await pilot.face(_of(GHOST_MGR_WC) + Vector3(0, 1.3, 0), 0.05, 0.6)
	# A lambda captures locals by value: an assignment inside it never reaches `mgr`, so hold it in an array.
	var found: Array[NpcBase] = [null]
	await wait_until(func() -> bool:
		found[0] = _civ_near(_of(GHOST_MGR_WC), 0.8)
		return found[0] != null and found[0].velocity.length() < 0.2, 600.0)
	var mgr: NpcBase = found[0]
	if mgr == null:
		note("manager never came to his LK WC stop")
		return false
	await wait_s(1.0)
	# Doc §3 'leave him in a cubicle': a tied civilian is a `restrained` stimulus (15 m, LOS), so tie only where BB
	# can't see him (haz_p: tied in LockerDoor's sight line, rover_basement radioed at t=355).
	note("GHOST manager at his WC stop %s, seen by %d of 8 BB eyes" % [Po5Pilot._v(mgr.global_position),
		_bb_eyes_see(mgr.global_position, 0.5)])
	# Shout from the hide (haz_s: stepping out at 1.7 m, he filled 1.0 at once and ran). The all-round shout reaches a
	# civilian within shout_all_within_m (6 m) by LOS or a short navmesh path, so the partition doesn't stop it.
	var b: CivilianBrain = mgr.get_node_or_null(^"Brain") as CivilianBrain
	for _k: int in 4:
		if b == null or b.mode == CivilianBrain.Mode.DOWN:
			break
		await pilot.inp.tap(&"shout")
		await wait_s(0.8)
	note("GHOST manager shouted from the WC hide: mode %d" % (b.mode if b != null else -1))
	if b == null or b.mode != CivilianBrain.Mode.DOWN:
		return false
	# Down he is blind; tie him when rover_basement is away (one BB eye, west of LockerDoor, sees the WC stop).
	await wait_until(_rover_basement_away, 30.0)
	pilot.inp.release(&"crouch")
	await _go(pilot.stand_point(_of(GHOST_MGR_SHOUT)), 0.4, 6.0)
	var tie: InteractableComponent = _comp(mgr, &"cable_tie")
	if tie == null or not await pilot.use(tie, 20.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED, true):
		return false
	var kic: InteractableComponent = _comp(_x("keycard"))
	if kic == null:
		return false
	var kc_done: Callable = func() -> bool: return _objective(&"keycard") == 2 or not kic.enabled
	if not await pilot.use(kic, 20.0, kc_done):
		return false
	await shot("ghost_keycard")
	return true


## 4. SA up to the Executive level; pc_exec hack (45 s, 1 interruption), waiting in E3; read the code.
func _g4_code() -> bool:
	_ghost_stair_wait = true
	if not await _of_to_floor(3):
		return false
	var pc: Node3D = _x("code_pc")
	if pc == null:
		return false
	var running: Callable = func() -> bool:
		var st: int = int(pc.get(&"state"))
		return st == HackTerminal.State.RUNNING or st == HackTerminal.State.DONE
	for _k: int in 6:
		if _objective(&"code_pc") == 2 or int(pc.get(&"state")) == HackTerminal.State.DONE:
			break
		# Start / restart only when the hack needs it (r251f: `state != IDLE` passed on INTERRUPTED, so three
		# "restarts" returned in 0 s without pressing anything).
		if not running.call():
			var ic: InteractableComponent = _comp(pc)
			if ic != null and ic.enabled:
				await pilot.use(ic, 30.0, running, true)
			# Doc §4: wait in E3 while rover_gallery passes. EA -> E3 crosses the SA core: peek first (r251c: seen
			# at 3.5 m by rover_gallery coming up SA as the pilot left EA).
			await _wait_core_clear(OF_FFL[3], OF_FFL[2], true)
			if not running.call() and ic != null and ic.enabled:  # interrupted during the peek: still at the PC
				await pilot.use(ic, 30.0, running, true)
			await _go(_of(GHOST_E3_WAIT), 0.5, 40.0)
		await wait_until(func() -> bool: return int(pc.get(&"state")) != HackTerminal.State.RUNNING, 90.0)
		note("GHOST code hack state %d at t=%.0f" % [int(pc.get(&"state")), rt.heist_time_s])
	return _objective(&"code_pc") == 2 or int(pc.get(&"state")) == HackTerminal.State.DONE


## 5. SA down; the vault guard away -> keycard at the gate -> the sweep -> code at TL -> wait in RC (time lock).
func _g5_vault() -> bool:
	if not await _of_to_floor(0):
		return false
	var gate: Door = _tagged(&"vault_gate") as Door
	if gate != null:  # open or not (r255d: the vault guard's loop (b)/(c) left it open; no wait, walked into him in VC)
		# A player walks LK -> gate in legs and peeks before each, retreating to LK when a guard shows up (r257a/b: the
		# 'clear' was right, then rover_basement stepped out of SD into BB and met the pilot at the gate 5 s later).
		var hide: Vector3 = _lk_hide()
		var legs: Array[Vector3] = [_of(Vector3(8.0, OF_FFL[0], 8.2)), _of(Vector3(13.5, OF_FFL[0], 8.2))]
		for attempt: int in 4:
			await _wait_spot_clear(gate.global_position, OF_FFL[0], "vault gate", hide, _gate_window.bind(gate))
			var ok: bool = true
			for leg: Vector3 in legs + [pilot.stand_point(gate.global_position + Vector3(-1.2, 0.0, 0.0))]:
				var who: String = _gate_threat(gate)
				if who != "":
					note("GHOST vault gate approach %d: %s, back to LK" % [attempt + 1, who])
					ok = false
					break
				await _go(pilot.stand_point(leg), 0.5, 30.0)
			if ok:
				break
			await _go(hide, 0.4, 60.0)
	if gate == null or (not gate.is_open and not await pilot.use(_comp(gate), 30.0, func() -> bool: return gate.is_open)):
		return false
	var grid: LaserGrid = _x("laser_grid") as LaserGrid
	if grid != null:
		var rep: Dictionary = _laser_report(grid)
		if not await _laser_cross(grid, float(rep["best_lane"]), false, OF_LASER_LEAD_M):
			return false
	var tl: Node3D = _x("time_lock")
	if tl == null or not await pilot.use(_comp(tl), 40.0, func() -> bool: return _objective(&"time_lock") == 2, true):
		return false
	if grid != null and not await _laser_cross(grid, float(_laser_report(grid)["best_lane"]), false, OF_LASER_LEAD_M):
		return false
	# Wait out the time lock in CQ's SE corner, not RC (haz_t: RC is the vault guard's loop (b); walking there after the
	# code, the pilot met him coming back out of RC, t=1008). Not LK either (haz_u: holding in BB on the way, the pilot
	# stood in his RC -> BB -> gate walk, t=1010). lkprobe: no BB corridor point (x 0-47) sees GHOST_CQ_HIDE; CQ's door
	# is 2 m from the gate. Go at once.
	await _go(pilot.stand_point(_of(GHOST_CQ_HIDE)), 0.3, 20.0)
	pilot.inp.press(&"crouch")
	var vault: Door = _x("vault_door") as Door
	Engine.time_scale = TIME_LOCK_SCALE
	note("SHORTCUT time lock wait in CQ at x%.0f" % TIME_LOCK_SCALE)
	var open_or_alarm: Callable = func() -> bool:
		return (vault != null and vault.is_open) or _objective(&"time_lock_wait") == 2 or _alarm != &""
	await wait_until(open_or_alarm, 400.0)
	Engine.time_scale = 1.0
	pilot.inp.release(&"crouch")
	return vault == null or vault.is_open or _objective(&"time_lock_wait") == 2


## 6. Bags (cash, MEDIUM: no sprint, D-102) one at a time VT -> the sweep -> the gate -> CQ -> the cash lift (2 per
## cycle) -> LD, staged by the personnel door. Logs each trip's time and carry speed.
func _g6_bags() -> bool:
	var lift: BagLift = _x("cash_lift") as BagLift
	var grid: LaserGrid = _x("laser_grid") as LaserGrid
	if lift == null:
		return false
	var low: int = _lift_nearest_landing(lift, _of(GHOST_CQ_AT))
	var high: int = 1 - low if lift.landing_count() == 2 else 0
	var cq_stand: Vector3 = pilot.stand_point(lift.landing_transform(low).origin + lift.landing_transform(low).basis.z
		* -1.2)
	var ld_stand: Vector3 = pilot.stand_point(lift.landing_transform(high).origin + lift.landing_transform(high).basis.z
		* -1.2)
	var staged: int = 0
	while staged < _bags:
		await _lift_to(lift, low, cq_stand)
		for _b: int in mini(2, _bags - staged):
			var t0: float = rt.heist_time_s
			var src: LootSpawn = null
			# The cash cage's loot spawns (C's G1 tags them cash_cage / vault_loot): any live cash spawn in VT.
			for sp: Node in rt.find_children("*", "LootSpawn", true, false):
				var ls: LootSpawn = sp as LootSpawn
				if ls != null and ls.is_visible_in_tree() and ls.loot_id == LOOT_MEDIUM and ls.remaining > 0 \
						and _in_rect(ls.global_position, OF_VT_RECT) and absf(ls.global_position.y - OF_FFL[0]) < 2.0:
					src = ls
			if src == null:
				return false
			# Every VC crossing waits for the vault guard's loop (b) (haz_zd: after the time lock he was back on his VC
			# post 4 m from VT's door, t=1489). In: from CQ's corner. Out with the bag: from VT's blind corner.
			if not _in_rect(pilot.crew.global_position, OF_VT_RECT):
				await _go(pilot.stand_point(_of(GHOST_CQ_HIDE)), 0.3, 30.0)
				await _wait_vc_window("CQ -> VT", 15.0)
				await _go(_of(OF_VC_WEST), 0.5, 60.0)
				if grid != null and not await _laser_cross(grid, float(_laser_report(grid)["best_lane"]), false,
						OF_LASER_LEAD_M):
					return false
			# The cash cage (CashCageGate, BARRED) opens on the vault code at its keypad (ghost6_a: the cash's use point
			# was 2.3 m behind the closed gate).
			var cage: Door = rt.find_child("CashCageGate", true, false) as Door
			var kp: Node3D = rt.find_child("CashCageKeypad", true, false) as Node3D
			if cage != null and not cage.is_open and kp != null \
					and not await pilot.use(_comp(kp), 30.0, func() -> bool: return cage.is_open, true):
				note("GHOST cash cage keypad: the gate did not open")
				return false
			if not await pilot.use(_comp(src), 90.0, func() -> bool: return pilot.crew.is_carrying_bag()):
				return false
			await _go(pilot.stand_point(_of(GHOST_VT_HIDE)), 0.4, 30.0)
			await _wait_vc_window("VT -> CQ", 10.0)
			if grid != null and not await _laser_cross(grid, float(_laser_report(grid)["best_lane"]), false,
					OF_LASER_LEAD_M):
				return false
			await _gate_peek()
			if not await _bag_into_car(lift, cq_stand):
				return false
			note("GHOST bag trip VT -> car %.1f s" % (rt.heist_time_s - t0))
		if not await _lift_to(lift, high, cq_stand):
			return false
		if not await _of_to_floor(1, 11.0):
			return false
		while not lift.bags_in_car().is_empty():
			var bag: LootBag = lift.bags_in_car().front()
			await _go(ld_stand, 0.3, 60.0)
			if not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
				return false
			await _go(_of(GHOST_LD_STAGE), 0.3, 30.0)
			await pilot.inp.tap(&"drop_bag")
			await wait_s(1.0)
			staged += 1
			note("GHOST staged %d/%d by the LD door" % [staged, _bags])
		if staged < _bags and not await _of_to_floor(0):
			return false
	return true


## 7. In LD, ECM #2: throw the staged bags from the personnel door into the E1 van zone; walk out.
func _g7_throw() -> bool:
	var e1: SecureZone = _x("e1_secure") as SecureZone
	if e1 == null or not await _deploy_ecm():
		return false
	var secured: int = 0
	for _i: int in _bags + 2:
		var bag: LootBag = _bag_near(_of(GHOST_LD_STAGE), 5.0)
		if bag == null:
			break
		if not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			break
		await _go(pilot.stand_point(_of(OF_LD_DOOR)), 0.3, 20.0)
		var r: Dictionary = await _throw(e1.global_position, 10.0)
		secured += 1 if bool(r.get("secured", false)) else 0
	note("GHOST secured %d/%d into E1" % [secured, _bags])
	var ez: EscapeZone = pilot.active_escape()
	if ez != null:
		await _go(ez.global_position, 1.0, 60.0)
	return secured >= _bags


# --- Resolve (OF-P1: the names / tags / points the G1 tests expect, against C's map) -------------------------------

## --resolve [--map=...] [--launch]: loads the Ostrander map scene (no launch: every variant slot is still there) and
## prints one "[OFP] RESOLVE" row per EXPECT id: FOUND tag / FOUND near / FALLBACK far / MISSING, plus the spawn tags
## and every node of the classes the tests use. --launch also launches it (seed --seed, Routine; variants resolved)
## and checks each EXPECT_POINTS point against the navmesh. Headless-safe.
func _run_resolve() -> int:
	var path: String = _map if _map != "" else HeistLauncher.map_path(OF_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		print("[OFP] RESOLVE FAIL no map scene at '%s'" % path)
		return 1
	var root: Node = (load(path) as PackedScene).instantiate()
	print("[OFP] RESOLVE map %s (scene only: all variant slots present)" % path)
	var missing: PackedStringArray = PackedStringArray()
	for id: String in EXPECT:
		var r: Dictionary = _resolve_one(root, id)
		var e: Dictionary = EXPECT[id]
		var n: Node3D = r["node"] as Node3D
		var what: String = "MISSING"
		match String(r["how"]):
			"tag": what = "FOUND tag %s" % e["tag"]
			"near": what = "FOUND near" + (" (tag %s NOT set)" % e["tag"] if e["tag"] != &"" else "")
			"far": what = "FALLBACK far (> %.1f m)" % float(e["max"])
		if String(r["how"]) in ["", "far"] or (String(r["how"]) == "near" and e["tag"] != &""):
			missing.append(id)
		print("[OFP] RESOLVE %-13s %-10s %-34s %s %s (%.1f m from doc %s; %d candidates)" % [id, e["type"], what,
			root.get_path_to(n) if n != null else ^"-", Po5Pilot._v(_gpos(n)) if n != null else "-", float(r["dist"]),
			Po5Pilot._v(_of(e["near"] as Vector3)), int(r["count"])])
	for tag: StringName in EXPECT_SPAWN_TAGS:
		var pts: PackedStringArray = PackedStringArray()
		for n: Node in root.find_children("*", "", true, false):
			var tags: Variant = n.get(&"tags")
			if n is Node3D and tags is Array and (tags as Array).has(tag):
				pts.append(Po5Pilot._v(_gpos(n as Node3D)))
		print("[OFP] RESOLVE spawn %-22s %s" % [tag, ("FOUND x%d %s" % [pts.size(), pts[0]]) if not pts.is_empty()
			else "MISSING"])
		if pts.is_empty():
			missing.append(String(tag))
	for type: String in ["LaserGrid", "Ladder", "BagLift", "SecureZone", "EscapeZone"]:
		var rows: PackedStringArray = PackedStringArray()
		for n: Node in root.find_children("*", "", true, false):
			if _is_type(n, type):
				var t: Variant = n.get(&"objective_tag")
				rows.append("%s %s%s" % [n.name, Po5Pilot._v(_gpos(n as Node3D)), (" [%s]" % t)
					if t != null and StringName(t) != &"" else ""])
		print("[OFP] RESOLVE all %s (%d): %s" % [type, rows.size(), "; ".join(rows)])
	root.free()
	if _resolve_launch:
		if await _launch(OF_HEIST, _of_seed(), Enums.Difficulty.ROUTINE, _of_opts({}, OF_SPAWN_LANE), true):
			for id: String in EXPECT_POINTS:
				var q: Vector3 = _of(EXPECT_POINTS[id] as Vector3)
				var on: Vector3 = pilot.stand_point(q)
				var ok: bool = pilot.flat_dist(on, q) <= 0.5 and absf(on.y - q.y) <= 0.5
				print("[OFP] RESOLVE point %-15s %s navmesh %s (%.2f m off doc %s)" % [id, "OK" if ok else "OFF",
					Po5Pilot._v(on), on.distance_to(q), Po5Pilot._v(q)])
				if not ok:
					missing.append("point:" + id)
			if _line != "":
				await _probe_line()
			for id: String in EXPECT:
				var r2: Dictionary = _resolve_one(rt, id)
				print("[OFP] RESOLVE live  %-13s %s" % [id, ("%s %s %s" % [(r2["node"] as Node).name, r2["how"],
					Po5Pilot._v(_gpos(r2["node"] as Node3D))]) if r2["node"] != null else "MISSING (inactive slot)"])
		else:
			missing.append("launch")
	print("[OFP] RESULT RESOLVE %s missing/fallback: %s" % ["PASS" if missing.is_empty() else "GAPS",
		", ".join(missing) if not missing.is_empty() else "none"])
	return 0


## --resolve --launch --line=ax,ay,az,bx,by,bz: every door opened, then the crew's standing capsule swept along the line
## (0.1 m steps, 0.36 m up so a step does not count): logs each step where it overlaps world geometry, and what.
func _probe_line() -> void:
	var f: PackedFloat64Array = PackedFloat64Array()
	for t: String in _line.split(","):
		f.append(t.to_float())
	if f.size() != 6:
		print("[OFP] RESOLVE line: need 6 numbers")
		return
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d != null and d.global_position.distance_to(Vector3(f[0], f[1], f[2])) < 4.0:
			d.unlock()  # diagnostic only (as po3_snag_probe): open the doors on the line
			d.set_open(true)
	await wait_s(1.5)
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d != null and d.global_position.distance_to(Vector3(f[0], f[1], f[2])) < 4.0:
			print("[OFP] RESOLVE line door %s open %s lock %s width %.2f at %s" % [d.name, d.is_open, d.get(&"lock"),
				d.effective_width(), Po5Pilot._v(d.global_position)])
	var a: Vector3 = _of(Vector3(f[0], f[1], f[2]))
	var b: Vector3 = _of(Vector3(f[3], f[4], f[5]))
	var tw: CrewTweak = Tweak.crew()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = tw.capsule_radius
	cap.height = tw.height_standing - 0.4
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = CrewController.COLLISION_MASK_WORLD
	q.exclude = [pilot.crew.get_rid()]
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var steps: int = maxi(int(a.distance_to(b) / 0.1), 1)
	for i: int in steps + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(steps))
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (0.36 + cap.height * 0.5))
		var hits: Array[Dictionary] = space.intersect_shape(q, 8)
		var names: PackedStringArray = PackedStringArray()
		for h: Dictionary in hits:
			var c: Node = h["collider"] as Node
			names.append(String(rt.get_path_to(c)) if c != null and rt.is_ancestor_of(c) else str(c))
		var on: Vector3 = pilot.stand_point(p)
		print("[OFP] RESOLVE line %s nav %.2f off: %s" % [Po5Pilot._v(p), pilot.flat_dist(on, p),
			"clear" if names.is_empty() else "BLOCKED by " + ", ".join(names)])
