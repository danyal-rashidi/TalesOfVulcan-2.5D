extends TestCase

const BIG: Array[StringName] = [&"slam", &"spell", &"breath", &"dive"]

func test_opening_order() -> void:
	var b := VulcanBrain.new()
	var got: Array[StringName] = []
	for d: float in [1.0, 20.0, 5.0, 0.5]:
		got.append(b.next_move(d))
	check(got == VulcanBrain.OPENING, "the opening comes first, in order, at any distance (got %s)" % [got])

func test_close_slash() -> void:
	var b := _after_opening(VulcanBrain.new())
	for i in 20:
		var m := b.next_move(2.0)
		check(m == &"slash" or m == &"backswing", "close up he slashes (got %s)" % m)

func test_no_repeat_big_move() -> void:
	var b := _after_opening(VulcanBrain.new(7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var last := &"dive"    # the opening's last
	var seen := {}
	for i in 300:
		var m := b.next_move(rng.randf_range(0.0, 12.0))
		check(not (m in BIG and m == last), "%s twice in a row at call %d" % [m, i])
		last = m
		seen[m] = true
	check(seen.size() == 7, "every move came up in 300 calls (got %s)" % [seen.keys()])

func test_phase_two_faster() -> void:
	var b := VulcanBrain.new()
	check(b.speed_scale() == 1.0, "phase 1 at normal speed")
	b.phase = 2
	check(b.speed_scale() > 1.0, "phase 2 is faster (got %s)" % b.speed_scale())

# Beyond the plan: reset() starts the opening again and plays the same fight from the same seed.
func test_reset_replays() -> void:
	var b := _after_opening(VulcanBrain.new(3))
	var first: Array[StringName] = []
	for i in 10:
		first.append(b.next_move(float(i)))
	b.phase = 2
	b.reset()
	check(b.phase == 1, "phase back to 1")
	var again: Array[StringName] = []
	for i in 14:
		again.append(b.next_move(float(i - 4)))
	check(again.slice(0, 4) == VulcanBrain.OPENING and again.slice(4) == first, "the same opening and mix again (got %s, then %s)" % [again, first])

func _after_opening(b: VulcanBrain) -> VulcanBrain:
	for i in VulcanBrain.OPENING.size():
		b.next_move(5.0)
	return b
