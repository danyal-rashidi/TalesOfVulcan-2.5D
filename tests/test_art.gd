extends TestCase
# The art lane's manifests, as CharacterSprite reads them.

# Every art/*/manifest.json loads; each sheet it names exists, is one cell tall and wide enough for (start + frames) cells.
func test_manifests_valid() -> void:
	var seen := 0
	for folder in DirAccess.get_directories_at("res://art"):
		var path := "res://art/%s/manifest.json" % folder
		if not FileAccess.file_exists(path):
			continue
		seen += 1
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (m is Dictionary and m.get("cell") is Array and m.get("anims") is Dictionary):
			check(false, "%s: not {cell, anims}" % path)
			continue
		var cell: Array = m["cell"]
		var anims: Dictionary = m["anims"]
		var w := int(cell[0])
		var h := int(cell[1])
		for key: String in anims:
			var a: Dictionary = anims[key]
			var sheet := "res://art/%s/%s" % [folder, a.get("file", "")]
			var img: Image = Image.load_from_file(sheet) if FileAccess.file_exists(sheet) else null
			if img == null:
				check(false, "%s/%s: no sheet %s" % [folder, key, sheet])
				continue
			var wide := int(a.get("w", w))
			var need := (int(a.get("start", 0)) + int(a.get("frames", 1))) * wide
			check(img.get_width() >= need, "%s/%s: %d px wide, needs %d" % [folder, key, img.get_width(), need])
			check(img.get_height() == h or a.has("w"), "%s/%s: %d px tall, the cell is %d" % [folder, key, img.get_height(), h])    # with its own "w", a sheet's as tall as its blade
			check(int(a.get("below", 0)) >= 0 and int(a.get("below", 0)) < img.get_height(), "%s/%s: below %s is outside the cell" % [folder, key, a.get("below")])
	check(seen >= 4, "the stand-in and the three characters have manifests (found %d)" % seen)

# Being hit is a move of his own: a flinch in every view, left-facing too so his sword keeps its hand, and not his stand. He used to change body when hit.
func test_vulcan_flinches_in_his_own_body() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/%s/manifest.json" % folder))
		var cell := Rect2i(0, 0, int(m["cell"][0]), int(m["cell"][1]))
		for view: String in ["F", "S", "B", "L"]:
			var a: Dictionary = m["anims"].get("hurt_spear_" + view, {})
			check(int(a.get("frames", 0)) == 5 and not a.get("loop", true), "%s has a flinch from %s, once (%s)" % [folder, view, a])
			var hurt := Image.load_from_file("res://art/%s/hurt_spear_%s.png" % [folder, view]).get_region(cell)
			var stand := Image.load_from_file("res://art/%s/idle_spear_%s.png" % [folder, view]).get_region(cell)
			check(hurt.get_data() != stand.get_data(), "%s's flinch from %s isn't just his stand" % [folder, view])

func test_vulcan_side_view_has_a_nose_in_open_air() -> void:
	# A nose of one brown pixel where the face's outline is, flush with it (anything past it read as Pinocchio), with nothing in front of it: a block of "neck" left by his old, bigger head once stood there (art/tools/smaller_head.py).
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/%s/manifest.json" % folder))
		var cell := Rect2i(0, 0, int(m["cell"][0]), int(m["cell"][1]))
		for view: String in ["S", "L"]:
			var img := Image.load_from_file("res://art/%s/idle_spear_%s.png" % [folder, view]).get_region(cell)
			var top := img.get_used_rect().position.y
			var front := func(row: int) -> int:    # how far forward he reaches on this row of his head, counting from the back of the picture
				for i in cell.size.x:
					var x := cell.size.x - 1 - i if view == "S" else i
					if img.get_pixel(x, top + row).a > 0.5:
						return cell.size.x - i
				return 0
			var face: int = front.call(7)
			check(front.call(6) == face and front.call(8) == face and front.call(9) == face and front.call(10) == face, "%s from %s has a nose out in the open" % [folder, view])
			check(img.get_pixel(face - 1 if view == "S" else cell.size.x - face, top + 8).r > 0.35, "%s from %s has skin for a nose, not outline" % [folder, view])

# Three different attacks, not one borrowed sheet, in every view, left-facing too so his sword keeps its hand; the two heavies are one sheet.
func test_vulcan_has_three_different_attacks() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var anims: Dictionary = _manifest(folder)["anims"]
		for view: String in ["S", "L", "F", "B"]:
			var pics := {}
			for sheet: String in ["light1", "light2", "heavy"]:
				var path := "res://art/%s/%s_%s.png" % [folder, sheet, view]
				check(FileAccess.file_exists(path), "%s has %s" % [folder, path])
				pics[FileAccess.get_file_as_bytes(path)] = true
			check(pics.size() == 3, "%s from %s: three different sheets (%d)" % [folder, view, pics.size()])
			for key: String in ["lunge_", "thrust_", "charge_"]:
				check(anims[key + view]["file"] == "heavy_%s.png" % view, "%s%s plays the heavy" % [key, view])
			for key: String in ["light1_", "light2_", "lunge_", "thrust_"]:
				check(not anims[key + view].has("trail"), "%s%s has no trail drawn on it: the game's mark follows the blade" % [key, view])
				check(anims[key + view].get("arc", []).size() >= 3, "%s%s names the way its blade cuts" % [key, view])
		for gone: String in ["light3_F", "light4_S", "light3_B", "light4_B"]:
			check(not anims.has(gone), "%s has no %s" % [folder, gone])

# No blade cropped, and his approved head's hair on him, in every frame of every view; his feet on the feet line as he ends.
func test_vulcan_swings_are_whole() -> void:
	const HAIR: Array[int] = [0x262226ff, 0x3e3632ff]    # smaller_head.py's n and g
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var anims: Dictionary = _manifest(folder)["anims"]
		for sheet: String in ["light1", "light2", "lunge"]:
			for view: String in ["S", "L", "F", "B"]:
				var a: Dictionary = anims["%s_%s" % [sheet, view]]
				var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
				var w := int(a["w"])
				var h := img.get_height()
				for f in int(a["frames"]):
					var hair := 0
					var low := -1    # his lowest warm row: the blade can reach lower
					for y in h:
						for x in w:
							var c := img.get_pixel(f * w + x, y)
							if c.a > 0.0:
								check(x > 0 and x < w - 1 and y > 0 and y < h - 1, "%s/%s frame %d: opaque at its edge (%d, %d)" % [folder, a["file"], f, x, y])
								hair += int(c.to_rgba32() in HAIR)
								if c.r > c.b + 0.04:
									low = y
					check(hair >= 4, "%s/%s frame %d carries his head's hair (%d px: the blade crosses it in light 1 from the side)" % [folder, a["file"], f, hair])
					check(_pieces(img, f * w, w) == 1, "%s/%s frame %d is one piece: no hand, hilt or blade left floating by the head change" % [folder, a["file"], f])
					if f == int(a["frames"]) - 1:
						var feet := h - 2 - int(a.get("below", 0))
						check(low <= feet and low >= feet - 3, "%s/%s ends with his feet on the feet line (row %d, the line %d)" % [folder, a["file"], low, feet])

# The heavy's low pose from the front holds longest: its blade goes off to his side, never down between his legs, which reads as something hanging from him.
func test_vulcan_heavy_blade_clear_of_his_legs() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var a: Dictionary = _manifest(folder)["anims"]["lunge_F"]
		var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
		var w := int(a["w"])
		for f: int in [int(a["active"][1]), int(a["active"][1]) + 1]:
			var tip := Vector2i(-1, -1)
			var warm := 0.0
			var warm_n := 0
			for y in img.get_height():
				for x in w:
					var c := img.get_pixel(f * w + x, y)
					if c.a > 0.0:
						tip = Vector2i(x, y)
						if c.r > c.b + 0.04:
							warm += x
							warm_n += 1
			check(abs(tip.x - warm / warm_n) >= 12.0, "%s heavy from the front, frame %d: the blade's tip (%d) is well to the side of his middle (%d)" % [folder, f, tip.x, warm / warm_n])

# Light 2 starts on the picture light 1 holds from its cancel on: no snap. And the times the game plays them at are the sheets' own: the hit where the blade moves, the heavy's where the lunge's was.
func test_vulcan_swings_flow() -> void:
	var anims: Dictionary = _manifest("vulcan_human")["anims"]
	for view: String in ["S", "L", "F", "B"]:
		var first := _frame("vulcan_human", "light2_" + view, 0).get_data()
		check(first == _frame("vulcan_human", "light1_" + view, 5).get_data(), "light 2's first frame is light 1's low pose, from %s" % view)
		check(first == _frame("vulcan_human", "light1_" + view, 4).get_data(), "which he reaches as light 1 lands, from %s" % view)
		for key: String in ["light1_", "light2_"]:
			near(_seconds(anims[key + view], int(anims[key + view]["frames"])), Elvis.ATTACKS["light1"]["cancel"] + Elvis.RECOVERY, 0.001, "%s%s lasts what the game plays it for" % [key, view])
		near(_seconds(anims["light1_" + view], 5), Elvis.ATTACKS["light1"]["cancel"], 0.001, "light 1's hit is over at its cancel, from %s" % view)
		var heavy: Dictionary = anims["lunge_" + view]
		near(_seconds(heavy, int(heavy["frames"])), Elvis.ATTACKS["lunge"]["cancel"] + Elvis.RECOVERY, 0.001, "the heavy lasts as the lunge did, from %s" % view)
		near(_seconds(heavy, int(heavy["active"][1]) + 1), Elvis.ATTACKS["lunge"]["hit"].y, 0.001, "its hit is over when the lunge's was, from %s" % view)
		near(_seconds(heavy, int(heavy["active"][0])), Elvis.ATTACKS["lunge"]["hit"].x, 0.04, "and opens about when it did, from %s" % view)

# The pose he holds for as long as the player likes: the ground shows through him nowhere, and no ring of it hugs his head.
func test_vulcan_held_pose_has_no_holes() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		for view: String in ["S", "L", "F", "B"]:
			var a: Dictionary = _manifest(folder)["anims"]["charge_" + view]
			var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
			var holes := _holes(img, (int(a["frames"]) - 1) * int(a["w"]), int(a["w"]))
			check(holes == 0, "%s charge_%s: %d px of ground show through him" % [folder, view, holes])

# A late light 2 goes back down light 1's own frames: each of its keys starts on that frame's picture, and joins light 2 past its low pose, or he drops back into that crouch for 2 ticks.
func test_vulcan_late_light2_starts_on_the_frame_he_is_on() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var anims: Dictionary = _manifest(folder)["anims"]
		for view: String in ["S", "L", "F", "B"]:
			for from in [6, 7, 8]:
				var key := "light2_late%d_%s" % [from, view]
				var a: Dictionary = anims[key]
				var late := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
				var w := int(a["w"])
				var start := int(a["start"])
				var one := Image.load_from_file("res://art/%s/%s" % [folder, anims["light1_" + view]["file"]])
				var low := Image.load_from_file("res://art/%s/%s" % [folder, anims["light2_" + view]["file"]])
				check(_same_ground_up(late, start * w, one, from * w, w), "%s %s starts on light 1's frame %d" % [folder, key, from])
				check(_same_ground_up(late, (start + from - 5) * w, low, w, w), "%s %s reaches light 2's first frame past the low pose" % [folder, key])

# Light 1, sword up: from behind, one blade that holds its width from tip to guard, not a club pinched in the middle; facing left, no skin at his groin where the cut melted his free fist into his legs. Both from a review.
func test_vulcan_light1_raised_frames() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var back := Image.load_from_file("res://art/%s/light1_B.png" % folder)
		var left := Image.load_from_file("res://art/%s/light1_L.png" % folder)
		for f in [1, 2]:
			var peak := 0
			for x in range(34, 54):
				var rows := 0
				for y in 17:
					var c := back.get_pixel(f * 104 + x, y)
					if c.a > 0.0 and c.b >= c.r - 0.01 and c.r8 + c.g8 + c.b8 > 170:
						rows += 1
				peak = maxi(peak, rows)
				check(rows >= peak - 1, "%s light1_B %d: blade pinched to %d rows at x %d, %d nearer the tip" % [folder, f, rows, x, peak])
			var skin := 0
			for y in range(40, 45):
				for x in range(54, 60):
					var c := left.get_pixel(f * 104 + x, y)
					if c.a > 0.0 and c.r8 + c.g8 + c.b8 >= 270:
						skin += 1
			check(skin <= 3, "%s light1_L %d: %d px of skin at his groin" % [folder, f, skin])

# Two frames the same, counted up from their sheets' bottoms, which can differ in height.
func _same_ground_up(a: Image, ax: int, b: Image, bx: int, w: int) -> bool:
	for y in mini(a.get_height(), b.get_height()):
		for x in w:
			if a.get_pixel(ax + x, a.get_height() - 1 - y) != b.get_pixel(bx + x, b.get_height() - 1 - y):
				return false
	return true

# The blow lands as the blade gets there: light 1's and the heavy's first hit frame has it far lower than the frame before, which still shows it on its way.
func test_vulcan_blow_lands_with_the_blade_down() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var anims: Dictionary = _manifest(folder)["anims"]
		for key: String in ["light1_", "lunge_"]:
			for view: String in ["S", "L", "F", "B"]:
				var a: Dictionary = anims[key + view]
				var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
				var f := int(a["active"][0])
				check(_blade_row(img, f, int(a["w"])) > _blade_row(img, f - 1, int(a["w"])) + 15.0, "%s%s: the blade comes down into frame %d" % [key, view, f])

# Facing left the clips hold the sword forward in his far hand, as in the approved picture, and his stand has it across his shins. Every left swing ends on his stand with the sword in that far hand, so his body and feet don't jump.
func test_vulcan_left_swings_end_on_his_stand() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var stand := Image.load_from_file("res://art/%s/idle_spear_L.png" % folder)
		var cell_h := stand.get_height()
		for sheet: String in ["light1_L", "light2_L", "lunge_L"]:
			var a: Dictionary = _manifest(folder)["anims"][sheet]
			var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
			var w := int(a["w"])
			var x0 := (int(a["frames"]) + int(a.get("start", 0)) - 1) * w + (w - 96) / 2
			var y0 := img.get_height() - int(a.get("below", 0)) - cell_h
			var changed := 0
			var solid := 0
			var feet := 0
			for y in cell_h:
				for x in 96:
					var c := img.get_pixel(x0 + x, y0 + y)
					var d := stand.get_pixel(x, y)
					solid += int(d.a > 0.0)
					if c != d:
						changed += 1
						feet += int(y >= cell_h - 6)    # the new sword's wider blade in his stand reaches the row above
			check(changed * 2 < solid, "%s/%s ends close to his stand (%d of %d px differ)" % [folder, sheet, changed, solid])
			check(feet == 0, "%s/%s ends in his stand's feet (%d px differ)" % [folder, sheet, feet])

# The average row of a frame's steel. Its cool greys: nothing else of his is.
func _blade_row(img: Image, f: int, w: int) -> float:
	var rows := 0.0
	var n := 0
	for y in img.get_height():
		for x in w:
			var c := img.get_pixel(f * w + x, y)
			if c.a > 0.0 and c.b > c.r + 0.02 and c.r + c.g + c.b > 0.8:
				rows += y
				n += 1
	return rows / maxi(n, 1)

# How many separate pieces a frame of a sheet is in, touching corners counting as one.
func _pieces(img: Image, x0: int, w: int) -> int:
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var n := 0
	for y in h:
		for x in w:
			if seen[y * w + x] == 0 and img.get_pixel(x0 + x, y).a > 0.0:
				n += 1
				var todo: Array[Vector2i] = [Vector2i(x, y)]
				seen[y * w + x] = 1
				while not todo.is_empty():
					var at: Vector2i = todo.pop_back()
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var q := at + Vector2i(dx, dy)
							if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and seen[q.y * w + q.x] == 0 and img.get_pixel(x0 + q.x, q.y).a > 0.0:
								seen[q.y * w + q.x] = 1
								todo.append(q)
	return n

# Clear pixels of a frame that the outside can't reach.
func _holes(img: Image, x0: int, w: int) -> int:
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var todo: Array[Vector2i] = []
	for x in w:
		todo.append(Vector2i(x, 0))
		todo.append(Vector2i(x, h - 1))
	for y in h:
		todo.append(Vector2i(0, y))
		todo.append(Vector2i(w - 1, y))
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h or seen[at.y * w + at.x] == 1 or img.get_pixel(x0 + at.x, at.y).a > 0.0:
			continue
		seen[at.y * w + at.x] = 1
		todo.append_array([at + Vector2i.LEFT, at + Vector2i.RIGHT, at + Vector2i.UP, at + Vector2i.DOWN])
	var n := 0
	for y in h:
		for x in w:
			n += int(seen[y * w + x] == 0 and img.get_pixel(x0 + x, y).a == 0.0)
	return n

# Nothing of an old shoulder stands up beside his new head: the top of the figure is his head alone.
func test_no_skin_stands_beside_his_new_head() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		for spot: Array in [["look_hands_F", 4], ["look_hands_F", 5], ["sprint_spear_S", 3], ["sprint_spear_S", 4], ["roll_spear_B", 0]]:
			var img := Image.load_from_file("res://art/%s/%s.png" % [folder, spot[0]]).get_region(Rect2i(int(spot[1]) * 96, 0, 96, 62))
			var top := img.get_used_rect().position.y
			for y in range(top, top + 5):
				var wide := 0
				for x in 96:
					wide += int(img.get_pixel(x, y).a > 0.0)
				check(wide <= 15, "%s %s frame %d: %d px across, %d rows down, wider than his head" % [folder, spot[0], spot[1], wide, y - top])

# His far arm, raised behind his new head at the Hammer Blow's start, is an arm and not a wire of outline.
func test_hammer_blow_keeps_his_raised_arm() -> void:
	for folder: String in ["vulcan_human", "vulcan_new_sword"]:
		var img := Image.load_from_file("res://art/%s/hammer_blow_S.png" % folder)
		for f in 3:
			var most := 0
			for y in range(16, 26):
				var run := 0
				for x in range(60, 72):
					var c := img.get_pixel(f * 96 + x, y)
					run = run + 1 if c.a > 0.0 and c.r > 0.35 else 0
					most = maxi(most, run)
			check(most >= 4, "%s frame %d: %d px of skin across" % [folder, f, most])

# The sword is held in every frame of every swing: nothing floats free of him with sand between.
func test_vulcan_is_all_one_piece_in_his_swings() -> void:
	var anims: Dictionary = _manifest("vulcan_human")["anims"]
	for key: String in ["light1_", "light2_", "lunge_"]:
		for view: String in ["S", "L", "F", "B"]:
			var a: Dictionary = anims[key + view]
			var img := Image.load_from_file("res://art/vulcan_human/%s" % a["file"])
			var w := int(a["w"])
			for f in int(a["frames"]):
				var bits := BitMap.new()
				bits.create_from_image_alpha(img.get_region(Rect2i(f * w, 0, w, img.get_height())), 0.0)
				var pieces := bits.opaque_to_polygons(Rect2i(0, 0, w, img.get_height()), 0.0).size()
				check(pieces == 1, "%s%s frame %d is %d pieces" % [key, view, f, pieces])

# Nothing stamps a head on him while he's upside down: clearing its place once cut a leg off roll_F 4, and the foot floated.
func test_vulcan_is_all_one_piece_in_his_rolls() -> void:
	var anims: Dictionary = _manifest("vulcan_human")["anims"]
	for key: String in anims:
		if not key.begins_with("roll_"):
			continue
		var img := Image.load_from_file("res://art/vulcan_human/%s" % anims[key]["file"])
		for f in img.get_width() / 96:
			var bits := BitMap.new()
			bits.create_from_image_alpha(img.get_region(Rect2i(f * 96, 0, 96, img.get_height())), 0.0)
			var pieces := bits.opaque_to_polygons(Rect2i(0, 0, 96, img.get_height()), 0.0).size()
			check(pieces == 1, "%s frame %d is %d pieces" % [key, f, pieces])

func _manifest(folder: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://art/%s/manifest.json" % folder))

# A frame on a canvas with its feet on one row, as sheets differ in height.
func _frame(folder: String, key: String, f: int) -> Image:
	var a: Dictionary = _manifest(folder)["anims"][key]
	var img := Image.load_from_file("res://art/%s/%s" % [folder, a["file"]])
	var out := Image.create(int(a["w"]), 200, false, img.get_format())
	out.blit_rect(img, Rect2i(f * int(a["w"]), 0, int(a["w"]), img.get_height()), Vector2i(0, 150 - (img.get_height() - 2 - int(a.get("below", 0)))))
	return out

func _seconds(a: Dictionary, frames: int) -> float:
	var s := 0.0
	for i in frames:
		s += CharacterSprite._hold_of(a, i)
	return s
