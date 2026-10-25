# A Higgsfield strip whose background came back grey, lilac, pink or a white-pink gradient instead of #FF00FF -> the same
# strip on flat #FF00FF, so sprites.py keys it out. The background is every light, unsaturated or pinkish pixel joined to
# the picture's border, and any near-white patch bigger than a catch-light (background seen through a gap); the figures'
# dark 1 px outline closes them off, so their lava (saturated orange, little blue) stays.
# Usage: uv run --with pillow --with numpy --with scipy python art/tools/rekey.py <raw.png> <out.png>   (--selftest checks it)
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def rekey(a):
    a = a[..., :3].astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    light = (a @ [30, 59, 11]) / 100 > 100
    cand = light & ((a.max(-1) - a.min(-1) < 60) | ((r > 140) & (b > 140) & (g < np.minimum(r, b))))
    lab, _ = ndimage.label(cand)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    L = (a @ [30, 59, 11]) / 100; idx = np.arange(1, lab.max() + 1)
    size, lum = ndimage.sum(cand, lab, idx), ndimage.mean(L, lab, idx)
    bg |= np.isin(lab, idx[(size > 80) & (lum > 200)])     # background seen through a gap (arm and body), not an eye's catch-light
    out = a.copy(); out[bg] = (255, 0, 255)
    return out.astype(np.uint8), bg.mean()


def selftest():
    a = np.full((20, 20, 3), (215, 150, 210), np.uint8); a[5:15, 5:15] = (10, 10, 10); a[8:12, 8:12] = (250, 220, 80)
    o, f = rekey(a)
    assert (o[0, 0] == (255, 0, 255)).all() and (o[10, 10] == (250, 220, 80)).all() and (o[5, 5] == (10, 10, 10)).all()
    print('selftest ok')


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        selftest()
    else:
        o, f = rekey(np.asarray(Image.open(sys.argv[1]).convert('RGB')))
        Image.fromarray(o).save(sys.argv[2]); print('background %.0f%% of the picture' % (100 * f))
