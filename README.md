# Tales of Vulcan 2.5D

A pixel-art action game made in Godot.

## Play it

1. Download [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/).
2. Clone this repo.
3. Open Godot, choose **Import**, and pick `project.godot`. The first import takes a few minutes.
4. Press F5 to play.

`play.bat` and the other `.bat` files only work if Godot is at `D:\GODOT`. Change the path inside them if yours is somewhere else.

## Work on it

- `docs/NEXT.md` says where the game stands. Start there.
- `docs/PROGRESS.md` logs every change, newest first.
- Run the tests before you push, in Godot's folder (add `--path` and the game's folder):
  `Godot_v4.7.2-stable_win64_console.exe --headless res://tests/run_tests.tscn`

Remake a sheet only if you have the source clips: some tools in `art/tools` read clips that are not in this repo. The finished sheets are here, so playing and coding don't need them.

The dark outline has one switch: `PAL_LINE_ON` in `core/palette.gdshaderinc`.
