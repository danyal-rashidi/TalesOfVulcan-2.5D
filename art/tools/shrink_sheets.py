"""Shrinks a character's sheets in place, to stand on the same scale as blue Elvis (48 px tall). Every small pixel takes the most common
palette colour of its block, then the figure gets a 1 px outline in the palette's darkest colour. All frames share one grid, so what
stands still in the big sheet stands still here. The full-size sheets stay in git.
  uv run --with pillow --with numpy python art/tools/shrink_sheets.py art/vulcan_boss 0.6
"""
import json, sys
import numpy as np
from PIL import Image


def shrink_frame(idx, alpha, w, h, n):
    ys, xs = np.linspace(0, idx.shape[0], h + 1).astype(int), np.linspace(0, idx.shape[1], w + 1).astype(int)
    out, solid = np.zeros((h, w), int), np.zeros((h, w), bool)
    for i in range(h):
        for j in range(w):
            a = alpha[ys[i]:ys[i + 1], xs[j]:xs[j + 1]]
            if a.mean() > 0.5:
                solid[i, j] = True
                out[i, j] = np.bincount(idx[ys[i]:ys[i + 1], xs[j]:xs[j + 1]][a].ravel(), minlength=n).argmax()
    return out, solid


def neighbours(m):
    p = np.pad(m, 1).astype(int)
    return p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]


def main():
    folder, k = sys.argv[1], float(sys.argv[2])
    with open(f"{folder}/manifest.json") as f:
        m = json.load(f)
    assert "shrunk" not in m, "already shrunk: restore the full-size sheets and manifest from git first"
    pal = np.asarray(Image.open(f"{folder}/palette.png").convert("RGB"))[0].astype(int)
    dark = pal[pal.sum(axis=1).argmin()]
    cw, ch = m["cell"]
    w, h = round(cw * k), round(ch * k)
    for file in sorted({a["file"] for a in m["anims"].values()}):
        sheet = np.asarray(Image.open(f"{folder}/{file}").convert("RGBA"))
        assert sheet.shape[0] == ch and sheet.shape[1] % cw == 0, f"{file}: not whole {cw}x{ch} cells"
        n = sheet.shape[1] // cw
        idx = ((sheet[..., :3, None].astype(int).swapaxes(-1, -2) - pal[None, None]) ** 2).sum(-1).argmin(-1)
        out = np.zeros((h + 2, (w + 4) * n, 4), np.uint8)  # 2 px round the figure for its outline; the last 2 rows go, so the feet stay at the bottom
        for i in range(n):
            c, solid = shrink_frame(idx[:, i * cw:(i + 1) * cw], sheet[:, i * cw:(i + 1) * cw, 3] > 127, w, h, len(pal))
            solid &= neighbours(solid) >= 2  # a lone pixel is noise
            f = np.zeros((h + 4, w + 4, 4), np.uint8)
            f[2:-2, 2:-2, :3], f[2:-2, 2:-2, 3] = pal[c], solid * 255
            ring = (neighbours(f[..., 3] > 0) > 0) & (f[..., 3] == 0)
            f[ring] = (*dark, 255)
            out[:, i * (w + 4):(i + 1) * (w + 4)] = f[:h + 2]
        colours = {tuple(x) for x in out[out[..., 3] > 0][:, :3]}
        assert colours <= {tuple(x) for x in pal}, f"{file}: colours outside the palette"
        assert out[..., 3].max() == 255 and set(np.unique(out[..., 3])) <= {0, 255}, f"{file}: alpha must be on or off"
        Image.fromarray(out).save(f"{folder}/{file}")
    m["cell"], m["shrunk"] = [w + 4, h + 2], k
    for a in m["anims"].values():
        if "below" in a:
            a["below"] = round(a["below"] * k)
    with open(f"{folder}/manifest.json", "w") as f:
        json.dump(m, f, indent=1)
    print(f"{folder}: cell {cw}x{ch} -> {w + 4}x{h + 2}")


if __name__ == "__main__":
    main()
