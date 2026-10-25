# Art tools

Python runs through `uv run --with pillow --with numpy --with scipy python ...` from the project folder.
Blender is `"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"` and takes Windows paths.

| Tool | What it does |
| --- | --- |
| `art/sprites.py` | A Gemini strip on magenta -> a sheet: cut into cells, magenta and its rim tint removed, each frame shrunk to the shared scale (block mode colour, not the average, so lava cracks, trims and outlines stay crisp), feet on one line, <= 32 colours or locked to a palette, hand touch-ups, `<out>_x4.png` preview, optional manifest entry. Usage at the top of the file; `--selftest` checks it |
| `render_ref.py` | Blender, headless: a colour reference of Vulcan at the game camera (orthographic, 48.59 degrees down) from a **copy** of the Unreal repo's `SourceArt/Vulcan/Vulcan.blend`; `--outfit 0/1 --possessed 0..1 --yaw <deg> --out <png>` |

```
cp /mnt/d/TalesOfVulkan/TalesOfVulkan/SourceArt/Vulcan/Vulcan.blend art/_work/Vulcan_copy.blend
"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\Vulcan_copy.blend' \
    --python 'D:\TalesOfVulkan\TalesOfVulcan25D\art\tools\render_ref.py' -- --outfit 1 --possessed 1 --yaw 0 \
    --out 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\boss_ref_F.png' > art/_work/render.log 2>&1
```

The copy's textures are relative (`//textures/...`), so the script points them at the original folder (read only).

## Gemini through the Playwright browser

- The Playwright MCP only uploads from the folder the Claude session started in. For sessions started in the Unreal
  repo that is `/mnt/d/TalesOfVulkan/TalesOfVulkan/.playwright-mcp/` (gitignored there): copy references into
  `.playwright-mcp/a1/` and upload from there.
- Per chat: Upload & tools -> Create image **first** (turning it on drops attached pictures), then Aspect ratio 3:4
  for one standing figure, then Upload files.
- Save the full-size result straight into the project with `browser_run_code_unsafe`: hover the last
  `model-response img`, click the last "Download full size image" button, `download.saveAs('<art/<c>/raw/...>')`.
  The full size is about 896x1200; the image shown in the page is smaller.
- Gemini edits the image it just made: a follow-up in the same chat changes little (good for small fixes, like red
  gems on the crown). For a real redraw (a higher camera, new proportions) start a new chat. Never give it an earlier
  pixel version as a reference: it hands it back unchanged.
- Giving a finished sprite of another character as "copy its camera, proportions and pixel style, not its
  character" is what got the high camera and the big readable heads.
- Gemini's eyes are 1-2 shrunken pixels and usually lose their colour in the shrink: check every face at 8x and
  redraw the eyes with `--touchup` (each eye a dark pupil and a light catch-light).

## Limits seen

25 Oct 2026, Task A1: 11 images in 6 chats, no refusal, no rate limit, no daily cap message.
