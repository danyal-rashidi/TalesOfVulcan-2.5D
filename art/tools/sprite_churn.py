"""Sprite churn: scores how much a move's SHAPES churn from frame to frame, so rival cleaning methods compare on one
number, and draws the worst frames so the owner can see which to repaint. It never writes into the game.
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_churn.py FOLDER [KEY ...] [--src DIR] [--out PNG]
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_churn.py --selftest

The doctor removed pixel noise; what is left is limbs redrawn a little differently each frame. Per consecutive frame
pair (wrapping on a loop) the previous frame is followed to the current one with a coarser block match than the
doctor's (window radius 4, reach 6: whole limbs, not pixels), so a swinging arm is explained by motion, then:
 - silhouette churn: pixels where solid(cur) != solid(warped prev) - the figure's shape was redrawn;
 - border churn: pixels solid in both whose palette colour (nearest of the sheet's own colours) differs - a
   skin/cloth/belt/outline border drawn in a different place;
both as a share of the figure's pixels; plus the doctor's unsteady(), flicker_score() and specks() for continuity.
Per frame, churn = silhouette + border, so frames can be ranked; the 12 worst of a character go to
art/_work/shapes/worst/<folder>.png, each with its previous and next frame at 4x, labelled move and frame index.
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doctor_core as sd     # the noise-fix code, where follow and its WIN / REACH live
from doctor_core import GAME, SAME, frames_of, _dist, _solid, unsteady, flicker_score, specks

WIN, REACH = 4, 6     # coarser than the doctor's 2 / 4: a limb, not a pixel
WORST, ZOOM = 12, 4


def follow(cur, nb):
    """The doctor's follow at limb scale; its window and reach are module globals, so they are swapped for the call."""
    sd.WIN, sd.REACH = WIN, REACH
    try:
        return sd.follow(cur, nb)
    finally:
        sd.WIN, sd.REACH = 2, 4


def palette_index(frames):
    """A function mapping a frame to per-pixel palette index (-1 where transparent): the sheet's own colours, merged
    within SAME, so a pixel moved by follow() keeps its index."""
    cols = np.unique(np.concatenate([f[_solid(f)][:, :3] for f in frames]), axis=0).astype(int)
    pal = []
    for c in cols:
        if not pal or min(abs(c - p).sum() for p in pal) > SAME:
            pal.append(c)
    pal = np.array(pal)
    return lambda f: np.where(_solid(f), np.abs(f[..., None, :3].astype(int) - pal).sum(-1).argmin(-1), -1)


def churn(frames, loop):
    """Per frame (None where there is no previous frame): (silhouette px, border px, figure px)."""
    n, idx = len(frames), palette_index(frames)
    out = [None] * n
    for k in range(n) if loop else range(1, n):
        cur, warped = frames[k], follow(frames[k], frames[(k - 1) % n])[0]
        s, w = _solid(cur), _solid(warped)
        sil = s != w
        bord = s & w & (idx(cur) != idx(warped))
        out[k] = (int(sil.sum()), int(bord.sum()), max(int(s.sum()), 1))
    return out


def score_move(frames, loop):
    """One move's numbers: dict with frames, sil%, border%, unsteady, flicker, specks and per-frame churn % list."""
    per = churn(frames, loop)
    have = [p for p in per if p]
    sil = sum(p[0] for p in have) / max(sum(p[2] for p in have), 1) * 100
    bord = sum(p[1] for p in have) / max(sum(p[2] for p in have), 1) * 100
    return dict(frames=len(frames), sil=sil, border=bord, unsteady=unsteady(frames, loop),
                flicker=flicker_score(frames, loop), specks=sum(specks(f) for f in frames) / len(frames),
                per=[None if p is None else (p[0] + p[1]) / p[2] * 100 for p in per])


def load_moves(folder, keys=(), src=None):
    """(key, frames, loop) for the manifest's moves, cut from the sheets in src (the game's art/<folder>/ by default)."""
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    src = src or os.path.join(GAME, "art", folder)
    moves, sheets = [], {}
    for key, a in man["anims"].items():
        if keys and key not in keys:
            continue
        path = os.path.join(src, a["file"])
        if not os.path.exists(path):
            print(f"  {key}: no sheet {path}", file=sys.stderr)
            continue
        if path not in sheets:
            sheets[path] = np.array(Image.open(path).convert("RGBA"))
        cw, n, st = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0))
        moves.append((key, frames_of(sheets[path], cw, n, st), bool(a.get("loop", False))))
    return moves


def worst_sheet(rows, path):
    """rows: (churn%, label, prev, cur, next) with None for a missing neighbour; the WORST of them, 2 columns, at ZOOM."""
    seen = set()                                                                # a sheet copied to 3 views is one drawing
    rows = [r for r in sorted(rows, key=lambda r: -r[0]) if not (r[3].tobytes() in seen or seen.add(r[3].tobytes()))][:WORST]
    if not rows:
        return
    h, w = rows[0][3].shape[:2]
    cw, ch, cols = w * ZOOM, h * ZOOM, 2
    cell_w, cell_h = 3 * cw + 24, ch + 18
    nrows = (len(rows) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, nrows * cell_h), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(14)
    except TypeError:
        font = ImageFont.load_default()
    for i, (c, label, prev, cur, nxt) in enumerate(rows):
        x0, y0 = (i % cols) * cell_w, (i // cols) * cell_h
        draw.text((x0 + 4, y0 + 2), f"{label}  churn {c:.1f}%  (prev | this | next)", fill=(255, 220, 120, 255), font=font)
        for j, f in enumerate((prev, cur, nxt)):
            if f is None:
                continue
            x = x0 + j * (cw + 8)
            if j == 1:
                draw.rectangle([x - 2, y0 + 16, x + cw + 1, y0 + 17 + ch], outline=(255, 90, 90, 255))
            sheet.paste(Image.fromarray(f).resize((cw, ch), Image.NEAREST), (x, y0 + 18))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    return rows


def run(folder, keys=(), src=None, out=None):
    rows = []
    print(f"{folder}  (src {src or 'game'})")
    print(f"  {'move':<22}{'fr':>3}{'sil%':>7}{'bord%':>7}{'unst':>7}{'flick':>7}{'spk':>6}  per-frame churn %")
    for key, frames, loop in load_moves(folder, keys, src):
        if len(frames) < 2:
            print(f"  {key:<22}{len(frames):>3}  single frame")
            continue
        r = score_move(frames, loop)
        per = " ".join("-" if p is None else f"{p:.0f}" for p in r["per"])
        print(f"  {key:<22}{r['frames']:>3}{r['sil']:>7.1f}{r['border']:>7.1f}{r['unsteady']:>7.1f}{r['flicker']:>7.1f}{r['specks']:>6.1f}  {per}")
        n = len(frames)
        for k, p in enumerate(r["per"]):
            if p is not None:
                nxt = frames[(k + 1) % n] if loop or k + 1 < n else None
                rows.append((p, f"{key} f{k}", frames[(k - 1) % n], frames[k], nxt))
    top = worst_sheet(rows, out or os.path.join(GAME, "art", "_work", "shapes", "worst", f"{folder}.png"))
    if top:
        print("  worst: " + ", ".join(f"{l} {c:.0f}%" for c, l, *_ in top))


def selftest():
    """A square moving 3 px a frame (motion, no churn) and a two-colour block whose border jitters a column."""
    A, B, INK = (200, 60, 60, 255), (200, 100, 60, 255), (20, 20, 20, 255)     # A-B is 40 > SAME; INK far from both
    frames = []
    for k, split in enumerate((4, 5, 4)):
        f = np.zeros((40, 60, 4), np.uint8)
        f[5:13, 5 + 3 * k:13 + 3 * k] = A                                       # the moving square
        f[20:32, 20:30] = INK                                                  # the block: outline, A left, B right
        f[21:31, 21:split + 20] = A
        f[21:31, split + 20:29] = B
        frames.append(f)
    per = churn(frames, False)
    assert per[0] is None and [p[0] for p in per[1:]] == [0, 0], per           # the square's motion is followed
    assert [p[1] for p in per[1:]] == [10, 10], per                            # one 10 px border column jitters
    r = score_move(frames, False)
    assert abs(r["border"] - 10 / per[1][2] * 100) < 1e-9 and r["sil"] == 0, r
    worst_sheet([(r["per"][k], f"test f{k}", frames[k - 1], frames[k], None) for k in (1, 2)],
                os.path.join(GAME, "art", "_work", "shapes", "worst", "_selftest.png"))
    print("selftest ok", {k: v for k, v in r.items() if k != "per"})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?")
    ap.add_argument("keys", nargs="*")
    ap.add_argument("--src", help="folder of sheets to score instead of the game's (a rival cleaning's output)")
    ap.add_argument("--out", help="worst-frames PNG (default art/_work/shapes/worst/<folder>.png)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.folder:
        ap.error("FOLDER or --selftest")
    run(a.folder, tuple(a.keys), a.src, a.out)


if __name__ == "__main__":
    main()
