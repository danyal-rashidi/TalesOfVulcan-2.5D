"""List the clips of "All animations.glb" as a Markdown table (the catalogue at the end of clips.md).

Plain Python, no Blender: reads only the GLB's JSON chunk (the file is downloaded data; nothing in it is run).
  python3 -I art/tools/list_clips.py art/_work/a2/all_animations.glb > catalogue.md
Frames are at 30 fps (the clips' own rate). Clips 1-261 are Quaternius's Universal Animation Library 1+2, the rest MakeHuman
poses (held poses, 1 s): both CC0, see the Unreal repo's SourceArt/Fab/LICENCES.md, "Animations from All animations.glb".
"""
import json
import struct
import sys

UAL_COUNT = 261     # "Idle" .. "Spell Simple Shoot"; the MakeHuman poses follow ("Anrico Sitting 02" ..)


def clips(path):
    with open(path, 'rb') as f:
        magic, _, _ = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF', 'not a .glb'
        clen, ctype = struct.unpack('<I4s', f.read(8))
        assert ctype == b'JSON'
        js = json.loads(f.read(clen))
    acc = js['accessors']
    for a in js.get('animations', []):
        ins = [acc[a['samplers'][c['sampler']]['input']] for c in a['channels']]
        yield a.get('name', '?'), min(i['min'][0] for i in ins), max(i['max'][0] for i in ins)


def main():
    rows = list(clips(sys.argv[1]))
    assert len(rows) == 360, f'expected 360 clips, found {len(rows)}'
    print('| # | Clip | Source | Seconds | Frames (30 fps) |')
    print('| ---: | --- | --- | ---: | --- |')
    for i, (name, t0, t1) in enumerate(rows, 1):
        src = 'UAL' if i <= UAL_COUNT else 'MakeHuman pose'
        print(f'| {i} | {name} | {src} | {t1 - t0:.2f} | {round(t0 * 30)}-{round(t1 * 30)} |')


if __name__ == '__main__':
    main()
