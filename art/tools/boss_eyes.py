"""Marks where the boss's eyes are in his sheets, so core/sprite.gdshader can light them red in phase two and nothing else. Nothing is redrawn: an eye pixel gets alpha EYE and the pixels touching it alpha GLOW, which only the shader reads; both still count as solid everywhere else.
  uv run --with pillow --with numpy python art/tools/boss_eyes.py
Run it after anything that rewrites art/vulcan_boss's sheets. Safe to run again: it clears its own marks first.
Almost every sheet has the same pasted head, so each frame's head is found by matching idle's. The side walk and run have heads of their own, so those are listed by hand. kneel_F has none on purpose: he's beaten and the light has gone out of them. Claude's call.
"""
import json
import numpy as np
from PIL import Image

DIR = 'art/vulcan_boss/'
W = 122
EYE, GLOW = 250, 240    # core/sprite.gdshader's EYE_MARK and GLOW_MARK
SKIP = ('statue', 'wake', 'kneel')    # asleep, and beaten
BOX = {'F': (54, 60, 70, 74), 'S': (56, 60, 72, 75), 'B': (56, 60, 72, 75)}    # idle's head in each view, x0 y0 x1 y1
BAND = {'F': (56, 68, 66, 72), 'S': (62, 68, 70, 73)}    # the eyes' strip alone, for when an arm hides the rest of the head
EYES = {
    'F': [(58, 70), (59, 70), (62, 70), (63, 70)],    # the cream pixel and the pupil of each, in idle_F
    'S': [(65, 70), (65, 71), (66, 71), (68, 71)],    # the molten orange of the near eye and the far one, in idle_S
    'B': [(57, 67), (65, 67)],    # no eyes from behind: the light spilling past his temples. Claude's call, as they asked for every view
}
SEARCH = {'F': (range(-35, 35), range(-30, 45)), 'S': (range(-35, 35), range(-30, 45)), 'B': (range(-10, 17), range(-8, 19))}    # dx, dy. From behind the head has little to match, so it's kept near where it can be
TOO_FAR = 62    # mean colour difference: above this the head isn't there to see (behind an arm, off the frame), and no mark beats a mark on his armour
HAND = {    # frame -> eye pixels, read off the sheet at 8x
    'walk_S': {0: [(63, 70), (65, 70)], 1: [(60, 68), (61, 68), (62, 68)], 2: [(64, 69), (65, 69)], 3: [(63, 70), (65, 70)],
               4: [(62, 69), (63, 69)], 5: [(60, 68), (61, 68), (62, 68)], 6: [(64, 69), (65, 69)], 7: [(63, 70), (65, 70)]},
    'run_S': {0: [(63, 68), (64, 68)], 1: [(66, 68), (67, 68)], 2: [(64, 66), (65, 66)], 3: [(66, 66), (67, 66)],
              4: [(63, 68), (64, 68)], 5: [(66, 68), (67, 68)], 6: [(64, 66), (65, 66)], 7: [(66, 66), (67, 66)]},    # the upper of its two heads, an old flaw of these sheets: the one the crown is on
}


def difference(cell, tpl, mask, x, y):
    win = cell[y:y + tpl.shape[0], x:x + tpl.shape[1]]
    return (np.abs(win[..., :3] - tpl[..., :3]).sum(-1) + (win[..., 3] == 0) * 300)[mask].mean()


def best(cell, tpl, x0, y0, view):
    mask = tpl[..., 3] > 0
    tried = [(difference(cell, tpl, mask, x0 + dx, y0 + dy), dx, dy) for dx in SEARCH[view][0] for dy in SEARCH[view][1]
             if 0 <= x0 + dx and x0 + dx + tpl.shape[1] <= W and 0 <= y0 + dy and y0 + dy + tpl.shape[0] <= cell.shape[0]]
    return min(tried)


def eyes_of(key, frame, cell, heads):
    view = key[-1]
    if key in HAND:
        return HAND[key][frame]
    x0, y0, x1, y1 = BOX[view]
    cost, dx, dy = best(cell, heads[view][y0:y1, x0:x1], x0, y0, view)
    if view in BAND and cost > TOO_FAR:
        x0, y0, x1, y1 = BAND[view]
        cost, dx, dy = best(cell, heads[view][y0:y1, x0:x1], x0, y0, view)
    if view != 'B' and cost > TOO_FAR:
        print('  no eyes:', key, frame, round(cost))
        return []
    return [(x + dx, y + dy) for x, y in EYES[view] if view != 'B' or cell[y + dy, x + dx, 3] > 0]    # from behind the match is a guess: it stays on him


def main():
    anims = json.load(open(DIR + 'manifest.json'))['anims']
    heads = {v: np.asarray(Image.open(f'{DIR}idle_{v}.png').convert('RGBA')).astype(int)[:, :W] for v in 'FSB'}
    for key, anim in anims.items():
        sheet = np.asarray(Image.open(DIR + anim['file']).convert('RGBA')).copy()
        sheet[..., 3][sheet[..., 3] > 0] = 255
        if not key.startswith(SKIP):
            view = key[-1]
            for f in range(anim['frames']):
                cell = sheet[:, f * W:(f + 1) * W]
                eyes = eyes_of(key, f, cell.astype(int), heads)
                for x, y in eyes:
                    assert cell[y, x, 3] > 0, f'{key} frame {f}: an eye at {x},{y} is off him'
                for x, y in eyes:
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if cell[ny, nx, 3] == 255:
                            cell[ny, nx, 3] = GLOW
                for x, y in eyes:
                    cell[y, x, 3] = EYE
        Image.fromarray(sheet, 'RGBA').save(DIR + anim['file'])


main()
