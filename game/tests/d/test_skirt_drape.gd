## D-116 stride drape: no leg through a dress or skirt at the knee-bend extremes. For every dress / skirt look
## (g.dress, n.skirt), world/characters/_tools/check_skirt_drape.gd CPU-skins Body and Outfit through walk, run, flee,
## crouch_walk, cower, cower_b, cower_c and the seated sit_chair / desk_work, and counts the leg vertices the skirt
## covers at rest that end up outside it (before the stride drape: 35-150 per clip, knees and shins through the cloth;
## after: 0-11, all on the inner thighs between the legs). The dress cloths render both faces (a squat or seat shows the
## skirt's inside). Run after `godot --import`.
extends TestCase

const Drape = preload("res://world/characters/_tools/check_skirt_drape.gd")
const LOOKS: Array[String] = ["civilian_sales", "npc_penthouse_guest_a", "club_patron", "gallery_patron",
	"gallery_patron_c", "gallery_patron_e", "gallery_patron_g", "gallery_patron_h", "gallery_patron_j",
	"npc_bank_teller", "npc_bank_night_manager", "bank_officer", "npc_bank_teller_d", "bank_customer_c",
	# D-165 skirt pass: every look whose cloth covers the legs (all 235 rigs swept), the Afterhours dresses dance all night
	"club_patron_e", "club_patron_g", "club_patron_i", "club_patron_k", "club_dancer_c", "club_vip", "club_vip_c",
	"club_vip_e", "diner_waitress"]
## clip -> sample times (s): the peak knee bends (walk/run/flee contact and passing frames, the squats, the seat)
const FRAMES: Dictionary = {
	"walk": [0.12, 0.38, 0.62], "run": [0.09, 0.26, 0.44], "flee": [0.0, 0.25],
	"crouch_walk": [0.0, 0.45, 0.79], "cower": [0.0, 1.5], "cower_b": [0.22, 0.65], "cower_c": [0.0, 0.6],
	"sit_chair": [0.0, 2.0], "desk_work": [7.5],
	"dance_a": [0.0, 0.5, 1.0, 1.5], "dance_b": [0.0, 0.5, 1.0, 1.5], "dance_c": [0.0, 0.5, 1.0, 1.5],
}
## leg vertices through the skirt allowed per frame: this share of the covered ones, at least POKE_MIN
const POKE_SHARE: float = 0.06
const POKE_MIN: int = 14
## a skirt must cover at least this many leg vertices at rest (else the check measures nothing)
const COVERED_MIN: int = 80
## the dress / skirt cloth per look (rendered double-sided)
const CLOTH: Dictionary = {
	"civilian_sales": "char_dress_black", "npc_penthouse_guest_a": "char_satin_teal", "club_patron": "char_satin_gold",
	"gallery_patron": "char_satin_wine", "gallery_patron_c": "char_dress_black", "gallery_patron_e": "char_satin_sapphire",
	"gallery_patron_g": "char_satin_amethyst", "gallery_patron_h": "char_satin_gold",
	"gallery_patron_j": "char_silk_graphite", "npc_bank_teller": "char_bank_slate_dark",
	"npc_bank_night_manager": "char_bank_slate_dark", "bank_officer": "char_suit_grey",
	"npc_bank_teller_d": "char_bank_slate_dark", "bank_customer_c": "char_skirt_navy",
	"club_patron_e": "char_club_satin_ivory", "club_patron_g": "char_club_satin_black",
	"club_patron_i": "char_club_satin_black", "club_patron_k": "char_satin_teal", "club_dancer_c": "char_club_coral",
	"club_vip": "char_club_satin_black", "club_vip_c": "char_club_coral", "club_vip_e": "char_club_satin_black",
	"diner_waitress": "char_diner_rose",
}


func _rig(id: String) -> Node3D:
	var packed: PackedScene = load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene
	if packed == null:
		fail("no scene for %s (run godot --import first)" % id)
		return null
	var rig: Node3D = packed.instantiate() as Node3D
	add_child(rig)
	return rig


func test_no_leg_through_the_skirt_at_knee_bends() -> void:
	for id: String in LOOKS:
		var rig: Node3D = _rig(id)
		if rig == null:
			continue
		for clip: String in FRAMES:
			var times: Array[float] = []
			for t: Variant in FRAMES[clip]:
				times.append(float(t))
			var r: Dictionary = Drape.measure(rig, clip, times)
			var covered: int = int(r["covered"])
			var limit: int = maxi(POKE_MIN, int(covered * POKE_SHARE))
			assert_true(covered >= COVERED_MIN, "%s: the skirt covers only %d leg vertices at rest" % [id, covered])
			assert_true(int(r["poke"]) <= limit, "%s %s: %d leg vertices through the skirt at %.2f s (limit %d of %d)"
					% [id, clip, r["poke"], r["time"], limit, covered])
		rig.free()


func test_dress_cloths_render_both_faces() -> void:
	for id: String in CLOTH:
		var mat: BaseMaterial3D = load("res://world/materials/%s.tres" % CLOTH[id]) as BaseMaterial3D
		assert_true(mat != null, "%s: no material %s" % [id, CLOTH[id]])
		if mat != null:
			assert_eq(mat.cull_mode, BaseMaterial3D.CULL_DISABLED, "%s: %s must render both faces" % [id, CLOTH[id]])
