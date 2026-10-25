# Cut one row of figures out of a Gemini image that drew other things above and below it (Gemini often pads a strip
# with extra copies of the character): keeps rows Y0..Y1 and turns magenta every shape (with its rim) that reaches
# outside them, so the neighbours poking in are gone (shapes that only touch are split first).
# Usage: python art/tools/band.py <in> <out.png> Y0 Y1 [ERODE]
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, __file__.rsplit('/', 2)[0])
from sprites import magenta

src, out, y0, y1 = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
erode = int(sys.argv[5]) if len(sys.argv) > 5 else 2
a = np.asarray(Image.open(src).convert('RGB')).copy()
fg = ~magenta(a.astype(int))
# Shapes that only touch (a foot on a neighbour's spear tip) are split: label the shapes shrunk by ERODE px, then give every
# pixel the label of the nearest shrunk shape.
lab, n = ndimage.label(ndimage.binary_erosion(fg, iterations=erode))
idx = ndimage.distance_transform_edt(lab == 0, return_distances=False, return_indices=True)
lab = np.where(fg, lab[idx[0], idx[1]], 0)
drop = [i for i, sl in enumerate(ndimage.find_objects(lab), 1) if sl[0].start < y0 or sl[0].stop > y1]
gone = ndimage.binary_dilation(np.isin(lab, drop), iterations=4)
a[gone] = (255, 0, 255)
Image.fromarray(a[y0:y1]).save(out)
print('dropped', len(drop), 'of', n, 'shapes reaching outside the band')
