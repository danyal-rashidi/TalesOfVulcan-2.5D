"""Sprite doctor: finds and fixes the pixel noise a video model leaves in a character's sheets, after
steady_sheets.py and sprite_consistency.py have run (Danyal: "even seedance has a lot of pixel issues", "make a close
to perfect sprite doctor"). It never writes into the game: cleaned sheets, a report and before|after GIFs go to
art/_work/doctor/<folder>/ for review.
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_doctor.py FOLDER [ANIM ...] [--out DIR]
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_doctor.py --all [--strong] [--src DIR]
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_doctor.py --selftest
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_doctor.py FOLDER|--all --shapes [--hitch]

The rule behind every fix: a pixel is noise when the frames either side of it agree with each other, once each part
of the figure is followed to where it moved, and this frame alone differs. Detail that is really there (an eye, a
buckle, a stripe) is in the neighbouring frames too, so it is never touched; real movement doesn't look like a
one-frame blip, so it isn't either. Per frame, against the frames before and after it (wrapping round a loop):
 - shimmer and crawl: a colour that 3 of the 4 frames either side agree on (2 of 2 in a short move), which this frame
   alone breaks, comes back; shading that crawls a pixel back and forth settles, a change that lasts stays;
 - edge blips: a pixel of the silhouette that appears or vanishes for one frame goes, or comes back;
 - lone specks and pinholes the neighbours don't have: a pixel unlike all 8 around it takes their colour, a
   1 px hole inside the figure is filled, a tiny loose island is removed.
Before that, each frame is tidied on its own (the noisy texture: about a sixth of a Seedance frame is 1-2 px patches):
 - a patch of 1-2 px a shade off what surrounds it takes the surrounding colour; a strong mark (a dark dot on skin)
   only goes when it is a single pixel ringed by one colour. Outline and ink, the figure's edge, and the head where
   steady_sheets.py finds it (the hand-drawn face, the eyes) are never touched.
 - --strong then smooths each pixel with the same-material pixels round it and snaps it to the nearest colour already
   there: speckled texture becomes clean shading, as a pixel artist would draw it, at the cost of some 1 px detail.
A pixel changes only where the window round it matches the neighbouring frames well, so a fast arm or a sword smear
(nothing to match) is left as drawn. Alpha is carried with the colour it came from, never invented: the boss keeps
data in it. Moves with fewer than 4 frames are left alone (a 2-frame breath is two different frames on purpose).
Last, the character's frames are linked: each sheet is cleaned on its own, so a frame two sheets share, a swing that
ends on the stand or a parked animal's still parts would come out a shade apart. Wherever two frames (stood on the same
ground line, or one mirrored: a left sheet drawn as the side one flipped) were mostly the same drawing, every pixel that
was exactly the same in both takes the cleaned pixel of the first of them, the stands first; a pixel the doctor added or
removed in one of them only where the silhouette round it (3x3) was the same too.

--shapes, a separate pass run on the game's current (strong-cleaned) sheets, for what the cleaning leaves: about 86% of
the frame-to-frame change inside a figure is a material border (skin/cloth/belt/outline) redrawn a little differently
each frame. Per move, the cleanest frame is the key (best agreement with its neighbours, fewest specks); every other
frame is reached from it by chaining the block match frame to frame at limb scale (SHAPE_*), so a part is tracked across
the move. First the key is anchored to the view's stand (idle_<view> or idle_spear_<view>, its cleanest frame, stood on
the key by ground line and the figure's middle column; whichever tracks more of the key): the torso, belt and chest are
drawn a little differently in every move of one view, so where the same block match tracks the stand confidently, the
key's pixel becomes the stand's (never the head, never more than 1 px outside the key's figure); a leaning or crouching
pose, an arm, a spear are not tracked and stay the move's own. Where the chain is confident all the way and the part
moved slowly at every step, the pixel (colour and alpha, so the border takes the key's shape) becomes the key's carried
along the chain; fast parts (a sword, a swinging arm, a cape), poorly tracked pixels and the locked head stay as drawn,
treat() then settles the seams, a loose crumb the frame never had is dropped, and the head is pasted back. A move this
would leave with fewer than 2 distinct frames (an idle that would become a still) or with under SHAPE_FROZEN of its raw
frame-to-frame change (a breath that froze) comes back untouched and is logged. Output: art/_work/doctor_shapes/<folder>/.
--hitch then repairs the walk loops whose last frame is a redrawn pose (the step back to the first frame is much bigger
than a normal step), only the ones in HITCH_LOOPS, which were checked by eye: one in-between is synthesised part by part
(the last frame followed to the first and back, the figure split into regions of one shift, each drawn moved halfway, a
3x3 vote where the two layers clash) and appended as a new last frame; the sheet gets one more cell and manifest_patch.json
the anims entry to swap in. Nothing goes into art/<folder>/ until Danyal approves.

--paint, round three, runs on the --shapes output (art/_work/doctor_shapes/<folder>/, its manifest_patch.json applied and
carried over) for what still reads as AI-made at 8x: the cape, torso and legs a jumble of 1-4 px patches of near shades,
the outline 2 px thick in places with staircase teeth and stray corner pixels. Per move the head (the finder's mask grown
PAINT_FACE px down, so the mouth and beard count) is never painted and is asserted identical. First the interior, a pixel
artist's flat areas (skipped for PAINT_EDGES_ONLY: it deleted vulcan's gold buckle and chest marks and gained nothing on
fur): palette colours within PAINT_MERGE of a commoner one are one shade; a same-colour patch under PAINT_FLAT px takes the
shade of its own ramp round it (the palette chained into ramps: luma a shade apart, chroma pointing the same way, grey with
grey, so a gold buckle in a brown belt stays), a dot of another ramp up to PAINT_SPECK px goes too; one highlight and one
shadow per flat area (of the marks under PAINT_FORM px in one area only the largest of each kind stays); then every other
frame's shading becomes the key's where the --shapes chain is confident and the part slow, shade for shade of one material
only (never material or alpha). Then the outline as one 1-px line: a 1 px gap in the ink round the silhouette closes where
ink lies on both sides, ink 2 px thick thins from the inside (the silhouette the doctor steadied stays), a bump of up to
PAINT_TOOTH px with a second colour on three sides takes it (a staircase tooth, a notch, a stray corner), a border between
two colours zigzagging by one pixel over 3..PAINT_RUN columns or rows straightens to its majority side; thin long parts (a
spear, a sword, fingers) are left as drawn, and no colour is invented: a pixel only takes a colour next to it. Last, one
treat() pass settles the seams between frames. Output: art/_work/doctor_paint/<folder>/: the sheets, manifest_patch.json,
report.json, before|after GIFs, 8x strips (input over output, 6 frames a strip) and master_cmp.png (the master or the stand
beside a painted idle frame and a painted move frame).

--match, round four, runs on the game's sheets of every folder that has a master.png, for the moves that read as different
men (Danyal's screenshots: Vulcan's stand a shadow-heavy orange back, his run a lighter pink one; vulcan_human has no one
palette, hundreds of near-skin colours, and each move its own light/base/shade split). First every solid pixel takes the
Lab-nearest master colour of its own luma band (sprite_consistency.BANDS, so nothing crosses the shader's ink lines) when
within MATCH_SNAP, else it stays as drawn (steel, a glow, dust: effects the master has no colour for). Then each frame's
skin (the master's warm colours, MATCH_NOT_SKIN left out) is re-split across the master's skin ramp by quantile, darkest
3x3 mean luma first, so its light/base/shade shares equal the master's (a few lone shade specks stay on a flat back: a 3x3
median of the ramp step took them but halved the shade share, the thing being fixed; a shorts/leather ramp was dropped too:
belt, bracers, shorts and sandals are not one material, and the quantile gave the shorts light patches). The head (grown PAINT_FACE px as --paint) is pasted
back and asserted identical. Output: art/_work/doctor_match/<folder>/: sheets, report.json, GIFs, 8x strips, master_cmp.png.
The tone step as shipped (round four's judge, try B): the first cut lost Vulcan's chest and abs lines to the quantile and left
the back's shade as a soft blob with lone specks. Now a thin dark or light run of the INPUT (1-2 px wide, MATCH_MARK luma off
both sides, MATCH_MARK_MIN px long, skin-like, touching body skin) is a drawn line: it is kept out of the split, an on-ramp one
takes the darkest (lightest) tone and an off-ramp master colour stays as drawn. The rest is cut by quantile of the input's
MATCH_KEY-square mean luma per tone (ramp colours under MATCH_GROUP luma apart are one tone), regions under MATCH_TINY px merge
into the tone round them, and the tone most off grows or shrinks along the edge of its largest region until every tone is within
MATCH_TOL of the master's share; each tone is then split between its near-twin colours by the same key. For a move of MIN_FRAMES+
frames the key frame's tones are carried along the --shapes flow as --paint does (confident chain, slow part, never a head or a
mark) and only the rest of each frame is re-split round them, so a shade patch does not crawl from frame to frame.
--check, round four, changes no pixels: per folder with 2+ sheets, every move is measured against its view's stand (idle_<view>,
idle_spear_<view> first for a spear move; its cleanest frame): figure height (top of the head to the lowest pixel, so a raised
spear is not height), shoulder width, head height and head ratio, read on the move's most upright frame (tallest, narrowest
shoulder row, median head; frames whose head is 20% off the median dropped as lost heads), and on the key and the widest frame
the body's share of each luma band (sprite_consistency.BANDS) and, with a master.png, of each master skin ramp step after the
snap. A move is flagged when height or head ratio is over CHECK_PCT % off the stand or a share over CHECK_PTS points off: those
are the clips to remake (Vulcan's skin steps are what --match fixes). Width is report-only (a cape, an arm or a level spear reads
as shoulders); four-legged folders (CHECK_NO_PROPORTIONS) get height and head ratio report-only; a stand whose head ratio is
under CHECK_HEAD_MIN had no head found and its folder is skipped; a move whose head is lost in every frame prints n/a for them
and is judged on shares alone; CHECK_POSE moves are skipped. Output: art/_work/doctor_check/: report.json, a 6x contact sheet
(stand | key frame, numbers burnt in) per flagged move, the table on stdout worst first.
"""
import argparse
import glob
import os
import sys
from doctor_core import GAME, doctor_folder, relink_folder
from doctor_shapes import hitch_folder, shapes_folder
from doctor_paint import paint_folder
from doctor_match import match_folder
from doctor_check import check_all
from doctor_selftest import selftest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder", nargs="?")
    ap.add_argument("anims", nargs="*")
    ap.add_argument("--out", help="output folder (for --match and --check: the root, in place of art/_work/doctor_match/ or doctor_check/)")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--no-gifs", action="store_true")
    ap.add_argument("--no-tidy", action="store_true", help="only the frame-to-frame fixes, no per-frame texture tidy")
    ap.add_argument("--strong", action="store_true", help="also smooth speckled texture into shading (art/_work/doctor_strong/)")
    ap.add_argument("--src", help="a folder holding <folder>/ with the uncleaned sheets (default: the game's art/)")
    ap.add_argument("--shapes", action="store_true", help="the redrawn-border pass on the game's current sheets (art/_work/doctor_shapes/)")
    ap.add_argument("--hitch", action="store_true", help="an in-between for the hitching loops in HITCH_LOOPS, after --shapes (same folder)")
    ap.add_argument("--paint", action="store_true", help="round three on the --shapes output: flat areas and a 1-px outline (art/_work/doctor_paint/)")
    ap.add_argument("--match", action="store_true", help="round four on the game's sheets of every folder with a master.png: one palette and the master's skin split (art/_work/doctor_match/)")
    ap.add_argument("--check", action="store_true", help="round four, no pixels changed: each move measured against its view's stand, the clips to remake flagged (art/_work/doctor_check/)")
    ap.add_argument("--relink", metavar="ORIG", help="relink the game's sheets against ORIG/<folder>/, where shared frames were still the same (art/_work/doctor_relink/)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    folders = sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(GAME, "art", "*", "manifest.json"))) if a.all else [a.folder]
    if a.relink:
        for f in folders:
            relink_folder(f, os.path.join(a.relink, f))
        return
    if a.paint:
        for f in folders:
            paint_folder(f, a.anims, gifs=not a.no_gifs)
        return
    if a.match:                 # --out here is the root that holds <folder>/
        for f in folders:
            match_folder(f, a.anims, gifs=not a.no_gifs, out_root=a.out)
        return
    if a.check:
        check_all(folders, a.out)
        return
    if a.shapes or a.hitch:
        for f in folders:
            if a.shapes:
                shapes_folder(f, a.anims, gifs=not a.no_gifs)
            if a.hitch:
                hitch_folder(f, gifs=not a.no_gifs)
        return
    for f in folders:
        rep = doctor_folder(f, a.anims, None if a.all else a.out, gifs=not a.no_gifs, do_tidy=not a.no_tidy, strong=a.strong,
                            src=os.path.join(a.src, f) if a.src else None)
        b = sum(r["flicker_before"] for r in rep.values())
        af = sum(r["flicker_after"] for r in rep.values())
        ub = sum(r["unsteady_before"] for r in rep.values())
        ua = sum(r["unsteady_after"] for r in rep.values())
        sb = sum(r["specks_before"] for r in rep.values())
        sa = sum(r["specks_after"] for r in rep.values())
        print(f"{f}: {len(rep)} moves, per frame summed over moves: specks {sb:.0f} -> {sa:.0f}, one-frame flicker {b:.0f} -> {af:.0f}, unsteady {ub:.0f} -> {ua:.0f}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
