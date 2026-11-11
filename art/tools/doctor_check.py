"""Sprite doctor, --check (each move measured against its view's stand; no pixel changed). The usage and the reasons are in sprite_doctor.py's docstring."""
import glob
import json
import numpy as np
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from steady_sheets import view_of, head_of     # a move's view letter, as the head finder reads it; its fallback head
import sprite_consistency as sc       # --match: the master's colours in Lab, the shader's luma bands
from doctor_core import GAME, _solid, frames_of, head_masks
from doctor_shapes import pick_key
from doctor_paint import crop
from doctor_match import MATCH_MIN, master_ramp, skin_of, skin_split, snap_frame

# --check (round four, try C): % off the stand's height or head ratio, points off a band or skin step share, that flag a move
CHECK_PCT, CHECK_PTS, CHECK_HEAD_MIN = 10, 15, 0.15     # a stand whose head ratio is under CHECK_HEAD_MIN had no head found (old elvis: 0.124)
CHECK_NO_PROPORTIONS = {"jackal", "scorpion"}            # four-legged: a bite or a sting has no upright frame, so height and head ratio are report-only
CHECK_POSE = ("roll", "death", "kneel", "get_up", "look_hands", "wake", "dive", "split", "crawl", "statue", "backswing", "slam")   # pose changes by design
CHECK_BANDS = ["ink", "line", "shade", "lit"]


def measure(f, head):
    """One frame's numbers: figure height (top of the head to the lowest pixel: a raised spear is not height), shoulder
    width (the widest of the first eighth of the body's rows below the head), head height, head/body ratio, luma band
    shares of the body off the head; None for an empty frame."""
    sol = _solid(f)
    rows = np.nonzero(sol.any(1))[0]
    if not len(rows):
        return None
    top, bot = int(rows.min()), int(rows.max())
    hrows = np.nonzero(head.any(1))[0]
    head_h = int(hrows.max() - hrows.min() + 1) if len(hrows) else 0
    top, body_top = (int(hrows.min()), int(hrows.max()) + 1) if len(hrows) else (top, top)
    spans = [np.nonzero(sol[y])[0] for y in range(body_top, body_top + max((bot - body_top + 1) // 8, 2)) if y <= bot and sol[y].any()]
    body = f[sol & ~head][:, :3]
    bands = np.bincount(sc.band(body), minlength=4)[:4] / max(len(body), 1) * 100
    return dict(height=bot - top + 1, width=max((int(x.max() - x.min() + 1) for x in spans), default=0), head_h=head_h,
                head_ratio=round(head_h / (bot - top + 1), 3), bands=dict(zip(CHECK_BANDS, np.round(bands, 1).tolist())))


def skin_share(f, head, ramp):
    """Points of the frame's body skin on each master skin ramp step after the snap; None without enough skin."""
    pal, plab, pband, skin, _ = ramp
    x = snap_frame(f, pal, plab, pband)
    return [v * 100 for v in skin_split([x], pal, skin, [head])] if (skin_of(x, pal, skin) & ~head).sum() >= MATCH_MIN else None


def compare(ref, m, proportions=True):
    """What is off between the stand's numbers ref and a frame's m: (severity, text), worst first. Height or head ratio
    over CHECK_PCT % off (only with proportions, and only when the frame has them), a band or skin step share over
    CHECK_PTS points off."""
    off = []
    for k in ("height", "head_ratio"):      # shortcut: width reads capes, arms and a level spear, so it is never flagged; flag it once a torso mask exists
        if proportions and ref[k] and m.get(k) is not None:
            pct = (m[k] - ref[k]) / ref[k] * 100
            if abs(pct) > CHECK_PCT:
                off.append((abs(pct) / CHECK_PCT, f"{k} {pct:+.0f}% ({ref[k]} -> {m[k]})"))
    for name in CHECK_BANDS:
        pts = m["bands"][name] - ref["bands"][name]
        if abs(pts) > CHECK_PTS:
            off.append((abs(pts) / CHECK_PTS, f"{name} band {pts:+.0f} pts ({ref['bands'][name]:.0f} -> {m['bands'][name]:.0f})"))
    if ref.get("skin") and m.get("skin"):
        for i, (a, b) in enumerate(zip(ref["skin"], m["skin"])):
            if abs(b - a) > CHECK_PTS:
                off.append((abs(b - a) / CHECK_PTS, f"skin step {i} {b - a:+.0f} pts ({a:.0f} -> {b:.0f})"))
    return sorted(off, reverse=True)


def contact(stand, key, text, path, zoom=6):
    """stand | key frame at zoom on sand, the numbers burnt in below."""
    H, W = max(stand.shape[0], key.shape[0]), max(stand.shape[1], key.shape[1])        # a move may have its own cell width
    rows = crop([[np.pad(f, ((0, H - f.shape[0]), (0, W - f.shape[1]), (0, 0))) for f in (stand, key)]])[0]
    H, W = rows[0].shape[:2]
    lines = text.split("\n")
    img = Image.new("RGB", (max(2 * W * zoom, 8 + 6 * max(map(len, lines))), H * zoom + 12 * len(lines) + 6), (196, 178, 140))
    for i, f in enumerate(rows):
        img.paste(Image.fromarray(f).resize((W * zoom, H * zoom), Image.NEAREST), (i * W * zoom, 0), Image.fromarray(f[..., 3]).resize((W * zoom, H * zoom), Image.NEAREST))
    ImageDraw.Draw(img).multiline_text((4, H * zoom + 3), text, fill=(20, 15, 10))
    img.save(path)


def check_folder(folder, out_dir):
    """--check on one folder's game sheets (see the top of the file): per move the stand used, its numbers, the key and
    widest frames' numbers and off lists, severity, or why it was skipped; a contact sheet per flagged move in out_dir."""
    src = os.path.join(GAME, "art", folder)
    man = json.load(open(os.path.join(src, "manifest.json")))
    anims = {k: a for k, a in man["anims"].items() if os.path.exists(os.path.join(src, a["file"]))}
    if len(anims) < 2:
        return {}
    for old in glob.glob(os.path.join(out_dir, f"{folder}_*.png")):     # a move cleared since the last run keeps no sheet
        os.remove(old)
    ramp = master_ramp(os.path.join(src, "master.png")) if os.path.exists(os.path.join(src, "master.png")) else None
    proportions = folder not in CHECK_NO_PROPORTIONS
    sheets, stands, out = {}, {}, {}

    def cut(key):
        a = anims[key]
        if a["file"] not in sheets:
            sheets[a["file"]] = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
        fr = frames_of(sheets[a["file"]], int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0)))
        return fr, head_masks(fr, folder, key, man, src), bool(a.get("loop", False))

    def numbers(f, head):
        m = measure(f, head)
        if m is not None and ramp is not None:
            m["skin"] = skin_share(f, head, ramp)
        return m

    def stand_of(key):
        view = view_of(key)
        names = [f"idle_spear_{view}", f"idle_{view}"] if "spear" in key else [f"idle_{view}", f"idle_spear_{view}"]
        name = next((n for n in names if n in anims), None)
        if name is None:
            return None, None
        if name not in stands:
            fr, heads, loop = cut(name)
            k = pick_key(fr, loop) if len(fr) > 1 else 0
            stands[name] = (fr[k], numbers(fr[k], heads[k]))
        return name, stands[name]

    for key in anims:
        name, stand = stand_of(key)
        if stand is None or stand[1] is None or key == name:
            continue
        if any(p in key for p in CHECK_POSE):
            out[key] = dict(stand=name, skipped="pose changes by design")
            continue
        if stand[1]["head_ratio"] < CHECK_HEAD_MIN:
            out[key] = dict(stand=name, skipped="stand head not found")
            continue
        fr, heads, loop = cut(key)
        k = pick_key(fr, loop) if len(fr) > 1 else 0
        spans = [np.ptp(np.nonzero(_solid(f).any(0))[0]) if _solid(f).any() else -1 for f in fr]
        w = int(np.argmax(spans))
        all_m = [m for m in (measure(f, h) for f, h in zip(fr, heads)) if m]
        mid = np.median([m["head_h"] for m in all_m])
        all_m = [m for m in all_m if abs(m["head_h"] - mid) <= 0.2 * mid] or all_m     # a frame whose head the finder lost
        # proportions from the move's most upright frame: a lunge or a swing is a pose, a clip drawn smaller is not
        geo = dict(height=max(m["height"] for m in all_m), width=min(m["width"] for m in all_m), head_h=int(np.median([m["head_h"] for m in all_m])))
        geo["head_ratio"] = round(geo["head_h"] / geo["height"], 3)
        if all((h == head_of(f)[1]).all() for f, h in zip(fr, heads) if f[..., 3].any()):   # the head lost in every frame: the fallback is the top of the figure
            geo.update(height=None, head_h=None, head_ratio=None)
        got = {}
        for tag, i in (("key", k), ("widest", w)):
            m = numbers(fr[i], heads[i])
            if m is not None:
                m.update(geo)
                off = compare(stand[1], m, proportions)
                got[tag] = dict(frame=i, **m, off=[t for _, t in off], worst=max([x for x, _ in off], default=0))
        if not got:
            continue
        worst = max(got.values(), key=lambda g: g["worst"])
        out[key] = dict(stand=name, stand_numbers=stand[1], flagged=worst["worst"] > 0, severity=round(worst["worst"], 2), **got)
        if out[key]["flagged"]:
            lines = [f"{folder} {key} (key frame {k}, widest {w}) vs {name}"]
            for tag, g in got.items():
                na = lambda v: "n/a" if v is None else v
                lines.append(f"{tag} f{g['frame']}: h {stand[1]['height']}->{na(g['height'])} w {stand[1]['width']}->{g['width']} "
                             f"head {stand[1]['head_ratio']}->{na(g['head_ratio'])}  " + ("; ".join(g["off"]) or "ok"))
            contact(stand[0], fr[k], "\n".join(lines), os.path.join(out_dir, f"{folder}_{key}.png"))
    return out


def check_all(folders, out_dir=None):
    """--check over folders: report.json (totals and per folder) in out_dir, art/_work/doctor_check/ by default, and the
    table on stdout, worst first; given folders rerun only theirs, the report keeps the rest."""
    out_dir = out_dir or os.path.join(GAME, "art", "_work", "doctor_check")
    os.makedirs(out_dir, exist_ok=True)
    rows, totals = [], {}
    report = json.load(open(os.path.join(out_dir, "report.json")))["folders"] if os.path.exists(os.path.join(out_dir, "report.json")) else {}
    for folder in folders:
        res = check_folder(folder, out_dir)
        if res:
            report[folder] = res
    for folder, res in sorted(report.items()):
        checked = [k for k, v in res.items() if "flagged" in v]
        flagged = [k for k in checked if res[k]["flagged"]]
        totals[folder] = dict(moves=len(checked), flagged=len(flagged), skipped=sum("skipped" in v for v in res.values()),
                              stand_head_not_found=any(v.get("skipped") == "stand head not found" for v in res.values()))
        print(f"{folder:<14} checked {len(checked):>3}  flagged {len(flagged):>3}  skipped {totals[folder]['skipped']:>2}"
              + ("  stand head not found" if totals[folder]["stand_head_not_found"] else ""), flush=True)
        for k in flagged:
            g = max((res[k][t] for t in ("key", "widest") if t in res[k]), key=lambda g: g["worst"])
            rows.append((res[k]["severity"], folder, k, res[k]["stand"], f"f{g['frame']}: " + "; ".join(g["off"])))
    rows.sort(reverse=True)
    json.dump(dict(totals=totals, folders=report), open(os.path.join(out_dir, "report.json"), "w"), indent=1)
    print(f"\n{'sev':>5} {'folder':<14}{'move':<22}{'stand':<14}what is off")
    for sev, folder, k, stand, what in rows:
        print(f"{sev:5.1f} {folder:<14}{k:<22}{stand:<14}{what}")
    print("\ntotals: " + ", ".join(f"{f} {t['flagged']}/{t['moves']}" for f, t in totals.items()), flush=True)
    return report
