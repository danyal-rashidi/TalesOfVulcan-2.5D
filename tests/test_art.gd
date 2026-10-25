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
			var need := (int(a.get("start", 0)) + int(a.get("frames", 1))) * w
			check(img.get_width() >= need, "%s/%s: %d px wide, needs %d" % [folder, key, img.get_width(), need])
			check(img.get_height() == h, "%s/%s: %d px tall, the cell is %d" % [folder, key, img.get_height(), h])
			check(int(a.get("below", 0)) >= 0 and int(a.get("below", 0)) < h, "%s/%s: below %s is outside the cell" % [folder, key, a.get("below")])
	check(seen >= 4, "the stand-in and the three characters have manifests (found %d)" % seen)
