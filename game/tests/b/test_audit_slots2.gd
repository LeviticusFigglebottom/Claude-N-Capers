## D-118 weapon audit II (slot gaps): two STOCK mods (light / heavy) on ten more long guns and GRIP mods on the
## pistols. Each new option is offered on its weapon, has a model, non-zero deltas that trade concealment for
## stability the PD2 way, and strings; attaching one hides the base `StockMount/StockStock` or
## `GripMount/StockGrip` (on both guns of the akimbo pair). Wrapping the stock parts moved no marker: the base
## markers still sit where the pre-audit models (5af6bc62) had them.
extends TestCase

const S: int = Enums.ModType.STOCK
const G: int = Enums.ModType.GRIP
## mod id -> [weapon id, ModType, light (hides better, less stable)]
const NEW_MODS: Dictionary = {
	&"mod.corsair_collapsed_stock": [&"weapon.corsair_ar", S, true],
	&"mod.corsair_tactical_stock": [&"weapon.corsair_ar", S, false],
	&"mod.falchion_collapsed_stock": [&"weapon.falchion_dmr", S, true],
	&"mod.falchion_marksman_stock": [&"weapon.falchion_dmr", S, false],
	&"mod.brute_folding_stock": [&"weapon.brute_12", S, true],
	&"mod.brute_padded_stock": [&"weapon.brute_12", S, false],
	&"mod.anvil_collapsed_stock": [&"weapon.anvil_lmg", S, true],
	&"mod.anvil_heavy_stock": [&"weapon.anvil_lmg", S, false],
	&"mod.gale_collapsed_stock": [&"weapon.gale_mg", S, true],
	&"mod.gale_heavy_stock": [&"weapon.gale_mg", S, false],
	&"mod.rampart_collapsed_stock": [&"weapon.rampart_lmg", S, true],
	&"mod.rampart_heavy_stock": [&"weapon.rampart_lmg", S, false],
	&"mod.condor_skeleton_stock": [&"weapon.condor_50", S, true],
	&"mod.condor_precision_stock": [&"weapon.condor_50", S, false],
	&"mod.heron_skeleton_stock": [&"weapon.heron_308", S, true],
	&"mod.heron_precision_stock": [&"weapon.heron_308", S, false],
	&"mod.osprey_skeleton_stock": [&"weapon.osprey_762", S, true],
	&"mod.osprey_precision_stock": [&"weapon.osprey_762", S, false],
	&"mod.shrike_trapper_stock": [&"weapon.shrike_44", S, true],
	&"mod.shrike_target_stock": [&"weapon.shrike_44", S, false],
	&"mod.p9_rubber_grip": [&"weapon.kestrel_p9", G, false],
	&"mod.wren_rubber_grip": [&"weapon.wren_380", G, false],
	&"mod.w45_rubber_grip": [&"weapon.warden_45", G, false],
	&"mod.w45_slim_grip": [&"weapon.warden_45", G, true],
	&"mod.akimbo_w45_rubber_grip": [&"weapon.akimbo_warden_45", G, false],
	&"mod.akimbo_w45_slim_grip": [&"weapon.akimbo_warden_45", G, true],
	&"mod.sparrow_rubber_grip": [&"weapon.sparrow_mp", G, false],
	&"mod.sparrow_slim_grip": [&"weapon.sparrow_mp", G, true],
}
## Akimbo pair mods mirror the single Warden's (same model, D-050).
const PAIR_OF: Dictionary = {
	&"mod.akimbo_w45_rubber_grip": &"mod.w45_rubber_grip",
	&"mod.akimbo_w45_slim_grip": &"mod.w45_slim_grip",
}
const POS_TOL: float = 0.0005
## Base markers of the pre-audit models (5af6bc62): weapon -> marker -> [position, forward (-Z), up (+Y)] in the
## model frame. Wrapping StockStock / StockGrip (and cutting the Heron's butt) must not move any of them.
const BASE_MARKERS: Dictionary = {
	&"weapon.corsair_ar": {
		&"LeftHandIK": [Vector3(0, 0.038, -0.26), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1212, 0.06), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.08, -0.616), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0115, 0.08, -0.59), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0115, 0.08, -0.59), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1042, -0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0503, -0.38), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.08, -0.172), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0292, 0.077, -0.405), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, -0.012, -0.1235), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.077, 0.078), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.falchion_dmr": {
		&"LeftHandIK": [Vector3(0, 0.036, -0.298), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1272, 0.07), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.078, -0.759), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0138, 0.078, -0.7315), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0138, 0.078, -0.7315), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1102, -0.03), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0478, -0.42), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.078, -0.19), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0297, 0.078, -0.44), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, -0.01, -0.132), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.078, 0.085), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.brute_12": {
		&"LeftHandIK": [Vector3(0, 0.026, -0.307), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1482, 0.04), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.062, -0.469), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0048, 0.0748, -0.4555), Vector3(-0.6645, 0.7071, -0.2418), Vector3(0.6645, 0.7071, 0.2418)],
		&"MuzzlePortR": [Vector3(0.0048, 0.0748, -0.4555), Vector3(0.6645, 0.7071, -0.2418), Vector3(-0.6645, 0.7071, 0.2418)],
		&"SightRail": [Vector3(0, 0.1342, -0.04), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.038, -0.33), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.062, -0.25), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0277, 0.062, -0.33), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.022, -0.15), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.06, 0.33), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.anvil_lmg": {
		&"LeftHandIK": [Vector3(0, 0.032, -0.296), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1572, -0.01), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.088, -0.761), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0148, 0.088, -0.7325), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0148, 0.088, -0.7325), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1402, -0.06), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0408, -0.33), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.088, -0.215), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0182, 0.058, -0.33), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.022, -0.14), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.078, 0.085), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.gale_mg": {
		&"LeftHandIK": [Vector3(0, 0.04, -0.292), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1452, -0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.078, -0.608), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0153, 0.078, -0.5835), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0153, 0.078, -0.5835), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1282, -0.07), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0523, -0.47), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.078, -0.16), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.022, 0.078, -0.4), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.022, -0.11), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.068, 0.08), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.rampart_lmg": {
		&"LeftHandIK": [Vector3(0, 0.029, -0.293), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1542, 0.005), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.085, -0.718), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0148, 0.085, -0.6935), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0148, 0.085, -0.6935), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1382, -0.05), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0413, -0.385), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.085, -0.23), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.035, 0.078, -0.385), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.02, -0.15), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.085, 0.08), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.condor_50": {
		&"LeftHandIK": [Vector3(0, 0.034, -0.387), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1572, -0.0015), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.08, -1.016), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0233, 0.08, -0.975), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0233, 0.08, -0.975), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1072, -0.15), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0462, -0.56), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.08, -0.27), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0338, 0.08, -0.56), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.024, -0.155), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.074, 0.04), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.heron_308": {
		&"LeftHandIK": [Vector3(0, 0.024, -0.333), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1422, 0.01), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.078, -0.856), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0153, 0.078, -0.83), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0153, 0.078, -0.83), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.1002, -0.125), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0303, -0.465), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.078, -0.24), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0297, 0.05, -0.445), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.022, -0.135), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.074, 0.012), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.osprey_762": {
		&"LeftHandIK": [Vector3(0, 0.02, -0.277), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.1362, 0.075), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.064, -0.709), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"MuzzlePortL": [Vector3(-0.0138, 0.064, -0.6865), Vector3(-0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"MuzzlePortR": [Vector3(0.0138, 0.064, -0.6865), Vector3(0.9397, 0, -0.342), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.0962, -0.06), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0328, -0.4), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.064, -0.175), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.0307, 0.064, -0.4), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.022, -0.098), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.062, 0.085), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.shrike_44": {
		&"LeftHandIK": [Vector3(0, 0.004, -0.21), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.074, -0.27), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.052, -0.561), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.063, -0.2), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.013, -0.25), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.052, -0.15), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0.018, 0.042, -0.25), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Magwell": [Vector3(0, 0.012, -0.14), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"StockMount": [Vector3(0, 0.03, 0.034), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.kestrel_p9": {
		&"LeftHandIK": [Vector3(-0.025, -0.02, -0.0115), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.0665, 0.03), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.048, -0.1425), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.063, 0.03), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0145, -0.105), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.048, 0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0, 0.0145, -0.105), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		&"Magwell": [Vector3(0, -0.07, 0.0227), Vector3(0, -0.309, -0.9511), Vector3(0, 0.9511, -0.309)],
		&"StockMount": [Vector3(0, 0.03, 0.043), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.warden_45": {
		&"LeftHandIK": [Vector3(-0.024, -0.02, -0.0114), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.066, 0.034), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.048, -0.171), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.062, 0.034), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.018, -0.12), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.048, 0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0, 0.018, -0.12), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		&"Magwell": [Vector3(0, -0.076, 0.0232), Vector3(0, -0.2924, -0.9563), Vector3(0, 0.9563, -0.2924)],
		&"StockMount": [Vector3(0, 0.03, 0.058), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.akimbo_warden_45": {
		&"LeftHandIK": [Vector3(-0.024, -0.02, -0.0114), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.066, 0.034), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.048, -0.171), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.062, 0.034), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.018, -0.12), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.048, 0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0, 0.018, -0.12), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		&"Magwell": [Vector3(0, -0.076, 0.0232), Vector3(0, -0.2924, -0.9563), Vector3(0, 0.9563, -0.2924)],
		&"StockMount": [Vector3(0, 0.03, 0.058), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.wren_380": {
		&"LeftHandIK": [Vector3(-0.0238, -0.02, -0.0088), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.0572, 0.026), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.043, -0.113), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.054, 0.026), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.013, -0.08), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.043, 0.018), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0, 0.013, -0.08), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		&"Magwell": [Vector3(0, -0.056, 0.0161), Vector3(0, -0.2756, -0.9613), Vector3(0, 0.9613, -0.2756)],
		&"StockMount": [Vector3(0, -0.01, 0.0234), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
	&"weapon.sparrow_mp": {
		&"LeftHandIK": [Vector3(-0.0268, -0.02, -0.0105), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"AimPoint": [Vector3(0, 0.066, 0.028), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Muzzle": [Vector3(0, 0.048, -0.172), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SightRail": [Vector3(0, 0.062, 0.028), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"Underbarrel": [Vector3(0, 0.0123, -0.12), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"BarrelMount": [Vector3(0, 0.048, 0.02), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"SideRail": [Vector3(0, 0.0123, -0.12), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		&"Magwell": [Vector3(0, -0.072, 0.0234), Vector3(0, -0.309, -0.9511), Vector3(0, 0.9511, -0.309)],
		&"StockMount": [Vector3(0, -0.01, 0.0262), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		&"GripMount": [Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	},
}


func before_all() -> void:
	ContentDB.clear_cache()


func _visual(wid: StringName, mids: Array[StringName]) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(wid, mids)
	return v


func _marker_for(t: int) -> StringName:
	return &"StockMount" if t == S else &"GripMount"


func test_each_new_mod_is_offered_in_its_slot() -> void:
	for mid: StringName in NEW_MODS:
		var wid: StringName = NEW_MODS[mid][0]
		var t: int = NEW_MODS[mid][1]
		var w: WeaponDef = ContentDB.weapon(wid)
		assert_true(w != null, "%s exists" % wid)
		if w == null:
			continue
		var slot: Array = w.mod_slots.get(t, [])
		assert_true(slot.has(mid), "%s offers %s in slot %d" % [wid, mid, t])
		assert_false(w.default_mods.values().has(mid), "%s is optional" % mid)


func test_each_new_mod_has_model_deltas_and_strings() -> void:
	for mid: StringName in NEW_MODS:
		var m: WeaponModDef = ContentDB.mod(mid)
		assert_true(m != null, "%s def" % mid)
		if m == null:
			continue
		assert_eq(int(m.mod_type), int(NEW_MODS[mid][1]), "%s type" % mid)
		assert_true(m.model != null, "%s model" % mid)
		assert_true(m.price > 0 and m.unlock == &"", "%s priced, unlocked like its siblings" % mid)
		var d: WeaponStats = m.delta
		assert_true(d != null, "%s delta" % mid)
		if d == null:
			continue
		assert_true(d.concealment != 0 and d.recoil_kick_deg != 0.0 and d.recoil_horizontal_deg != 0.0,
			"%s has non-zero concealment / stability deltas" % mid)
		for suffix: String in [".name", ".desc"]:
			var key: String = "item." + String(mid) + suffix
			assert_ne(UiText.t(StringName(key)), key, "%s string" % key)


func test_light_hides_better_heavy_steadies() -> void:
	for mid: StringName in NEW_MODS:
		var d: WeaponStats = ContentDB.mod(mid).delta
		var stock: bool = int(NEW_MODS[mid][1]) == S
		if NEW_MODS[mid][2]:
			assert_true(d.concealment > 0 and d.recoil_kick_deg > 0.0 and d.recoil_horizontal_deg > 0.0,
				"%s: lighter = hides better, less stable" % mid)
			if stock:
				assert_true(d.spread_deg_ads > 0.0, "%s: light stock, less accurate" % mid)
		else:
			assert_true(d.concealment < 0 and d.recoil_kick_deg < 0.0 and d.recoil_horizontal_deg < 0.0,
				"%s: heavier = steadier, hides worse" % mid)
			if stock:
				assert_true(d.spread_deg_ads < 0.0, "%s: heavy stock, more accurate" % mid)
		if not stock:
			assert_true(absi(d.concealment) <= 2 and d.spread_deg_ads == 0.0, "%s: grips are small trades" % mid)
		# a mod never more than halves the base recoil (the class-scaled step, not a flat number)
		var base: WeaponStats = ContentDB.weapon(NEW_MODS[mid][0]).base
		assert_true(absf(d.recoil_kick_deg) <= base.recoil_kick_deg * 0.5, "%s kick step in scale" % mid)


func test_akimbo_grips_mirror_the_single_warden() -> void:
	for mid: StringName in PAIR_OF:
		var pair: WeaponModDef = ContentDB.mod(mid)
		var one: WeaponModDef = ContentDB.mod(PAIR_OF[mid])
		assert_eq(pair.model, one.model, "%s uses the Warden's model" % mid)
		assert_eq(pair.mod_type, one.mod_type, "%s same type" % mid)
		assert_true(signi(pair.delta.concealment) == signi(one.delta.concealment)
				and absi(pair.delta.concealment) >= absi(one.delta.concealment), "%s: two grips, same trade" % mid)
		assert_true(signf(pair.delta.recoil_kick_deg) == signf(one.delta.recoil_kick_deg), "%s kick sign" % mid)


func test_new_mods_hide_the_stock_part() -> void:
	for mid: StringName in NEW_MODS:
		var wid: StringName = NEW_MODS[mid][0]
		var t: Enums.ModType = NEW_MODS[mid][1]
		var part_name: String = "StockStock" if t == S else "StockGrip"
		var v: WeaponVisual = _visual(wid, [mid] as Array[StringName])
		var part: Node3D = v.stock_part(t)
		assert_true(part != null, "%s: base has %s" % [mid, part_name])
		if part != null:
			assert_eq(String(part.name), part_name, "%s: stock part name" % mid)
			assert_eq(part.get_parent(), v.get_base_marker(_marker_for(t)), "%s: under %s" % [mid, _marker_for(t)])
			assert_false(part.visible, "%s hides %s" % [mid, part_name])
			assert_true(not part.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s: part has mesh" % mid)
		var inst: Node3D = v.attached.get(t)
		assert_true(inst != null and inst.get_parent() == v.get_base_marker(_marker_for(t)),
			"%s at %s" % [mid, _marker_for(t)])
		if v.is_akimbo():
			var off: Node3D = v.offhand_stock_part(t)
			assert_true(off != null and not off.visible, "%s hides the offhand's %s" % [mid, part_name])
			assert_true(v.attached_offhand.get(t) != null, "%s mirrored on the offhand" % mid)
		v.queue_free()


func test_stock_part_visible_without_the_mod() -> void:
	var seen: Dictionary = {}
	for mid: StringName in NEW_MODS:
		var wid: StringName = NEW_MODS[mid][0]
		if seen.has(wid):
			continue
		seen[wid] = true
		var t: Enums.ModType = NEW_MODS[mid][1]
		var v: WeaponVisual = _visual(wid, [] as Array[StringName])
		var part: Node3D = v.stock_part(t)
		assert_true(part != null and part.visible, "%s shows its stock %s" % [wid, "StockStock" if t == S else "StockGrip"])
		v.queue_free()


func test_base_markers_unchanged() -> void:
	for wid: StringName in BASE_MARKERS:
		var v: WeaponVisual = _visual(wid, [] as Array[StringName])
		var inv: Transform3D = v.model.global_transform.affine_inverse()
		var expect: Dictionary = BASE_MARKERS[wid]
		for marker: StringName in expect:
			var n: Node3D = v.get_base_marker(marker)
			assert_true(n != null, "%s %s exists" % [wid, marker])
			if n == null:
				continue
			var xf: Transform3D = inv * n.global_transform
			var e: Array = expect[marker]
			var pos: Vector3 = e[0]
			var fwd: Vector3 = e[1]
			var up: Vector3 = e[2]
			assert_true(xf.origin.distance_to(pos) <= POS_TOL, "%s %s at %s (was %s)" % [wid, marker, xf.origin, pos])
			assert_true((-xf.basis.z).normalized().dot(fwd) > 0.9999, "%s %s forward %s" % [wid, marker, -xf.basis.z])
			assert_true(xf.basis.y.normalized().dot(up) > 0.9999, "%s %s up %s" % [wid, marker, xf.basis.y])
		v.queue_free()
