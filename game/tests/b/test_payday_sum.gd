## LEAD r229 (A's GN windowed run): the payday hero showed $78,969 while the cash total read $78,980. The hero number
## must equal the cash total, and the total the sum of the shown cash lines, on every difficulty, with and without
## the crew-alive bonus and a civilian penalty; a count-up cut short (stage change, skip) still lands on the total.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _money(l: Label) -> int:
	var digits: String = ""
	for ch: String in l.text:
		if ch.is_valid_int() or ch == "-":
			digits += ch
	return int(digits)


func _screen(result: Dictionary) -> PaydayScreen:
	var s: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	s.apply_to_profile = false
	s.setup(PlayerProfile.new_default())
	add_child(s)
	s.show_result(result)
	return s


func test_hero_equals_the_sum_of_the_shown_lines() -> void:
	for diff: int in range(6):
		for custody: bool in [false, true]:
			var r: Dictionary = HeistCatalog.sample_result()
			r["success"] = true
			r["difficulty"] = diff
			r["small_loot"] = 1777  # an odd number so the difficulty multiplier has to round
			if custody:
				((r["crew"] as Array)[1] as Dictionary)["in_custody"] = true
			var s: PaydayScreen = _screen(r)
			await wait_frames(1)
			var sum: int = 0
			for id: Variant in s.value_labels:
				var key: String = String(id)
				if key == "contract" or key.begins_with("loot.") or key in ["small_loot", "crew_alive",
						"civilian_penalty"]:
					sum += _money(s.value_labels[id] as Label)
			var total: int = _money(s.value_labels[&"total"] as Label)
			assert_eq(sum, total, "diff %d custody %s: the lines add up to the total" % [diff, custody])
			assert_eq(_money(s.value_labels[&"hero_total"] as Label), total, "diff %d: hero = total" % diff)
			assert_eq(total, int(s.payout["total"]))
			s.queue_free()
			await wait_frames(1)


func test_a_cut_short_count_up_lands_on_the_total() -> void:
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	var s: PaydayScreen = _screen(r)
	await wait_frames(1)
	var hero: Label = s.value_labels[&"hero_total"] as Label
	var total: int = int(s.payout["total"])
	s._count_label = hero
	s._count_amount = total
	s._count_step(float(total) * 0.9998, hero)  # the frame A's capture caught
	assert_ne(_money(hero), total, "mid count-up")
	s._land_total()
	assert_eq(_money(hero), total, "landing writes the exact total")
	s.queue_free()
	await wait_frames(1)
