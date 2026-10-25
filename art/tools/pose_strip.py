# Blender 5.2 headless: a grey pose-guide strip for Gemini, one cell per pose, seen from the game camera.
#   blender.exe -b --factory-startup --python art/tools/pose_strip.py -- --source <glb | .blend copy> --clip <name>
#       --frames <n | a-b/n | f1,f2,..> --view F|B|S --prop none|spear|greatsword --out <png> [--cell 256]
#       [--left-grip M] [--carry R,F,U] [--air 1] [--yaw DEG] [--build plain|chunky]
#   blender.exe -b --factory-startup --python art/tools/pose_strip.py -- --source <glb> --batch <jobs.json>
#       (jobs.json: a list of {"clip", "frames", "view", "prop", "out", "cell", "left_grip", "carry", "air", "yaw", "build"},
#       the last six optional: the GLB is imported once, ~30 s, then each strip takes about a second; "yaw" may be a list,
#       one per frame, and --yaw a comma list)
# Paths are Windows paths (D:\...), since blender.exe is a Windows program. Only ever give it copies (art/_work/).
# --source: "All animations.glb" (CC0: Quaternius UAL 1+2 and MakeHuman poses), or a .blend copy with the same mixamorig rig.
# --clip: a clip of the source, or a hand-keyed clip ("HK ...") from hand_keys.json next to this script, built from key poses.
# --frames (clip frames, 30 fps, 0 = the clip's first): "8" = 8 evenly over the whole clip, end left out (a loop);
#   "4-20/5" = 5 evenly from frame 4 to frame 20, both in; "46,40,36" = those frames, in that order (backwards is fine).
# --view: F faces the camera, B faces away, S faces screen-right (the game mirrors S for left).
# --cell: pixels per cell side. The scale is fixed (PPM), so --cell only decides how much fits: 256 bare-handed, 384 with
#   the spear or the greatsword. --left-grip, --carry, --air, --yaw: see strip().
# The look: orthographic, 48.59 deg down (Pixel.PITCH_DEG), 80 px per metre in every strip, each cell centred on the hips with
# the ground under them on the same row (GROUND), a grey clay mannequin (left limbs darker, a nose for the facing), a darker
# prop in the right hand, flat #FF00FF background, hard edges. A pose that leaves its cell is reported as CLIPPED.
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

PITCH = math.radians(48.59)
PPM = 80                # pixels per metre, every strip (the library man, 2 m tall, stands ~125 px high); a weapon needs a bigger --cell
GROUND = 0.62           # the ground under the hips, as a fraction of the cell height from the top (F: room for a blade on the ground ahead)
BODY, FAR, PROP = (0.66, 0.66, 0.66, 1), (0.44, 0.44, 0.44, 1), (0.28, 0.29, 0.32, 1)   # FAR: the left limbs
B = 'mixamorig'
# build "chunky": the pixel masters' proportions (a big head about a quarter of the height, broad pauldrons, heavy
# gauntlets and boots, short legs) instead of the library man's. Gemini paints over the guide's proportions, so a plain
# guide turns Elvis tall and thin. Radii factors per part; LEGS scales the legs from the hips (the body is lowered so the
# standing feet stay on the ground).
CHUNKY = dict(head=1.55, chest=1.3, belly=1.2, pelvis=1.15, shoulder=1.9, upperarm=1.35, elbow=1.3, forearm=1.35,
              hand=1.3, hip=1.2, thigh=1.2, knee=1.2, shin=1.25, foot=1.3)
LEGS = 0.7
HERE = os.path.dirname(os.path.abspath(__file__))


def p(*a):
    print('POSE_STRIP', *a, flush=True)


# ------------------------------------------------------------------ scene
def load(src):
    if src.lower().endswith('.blend'):
        bpy.ops.wm.open_mainfile(filepath=src)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps = 30          # the clips are 30 fps: keys on whole frames
        bpy.ops.import_scene.gltf(filepath=src)
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type == 'MESH' and o.name.startswith('Icosphere')]:
        bpy.data.objects.remove(o)                 # a stray helper sphere in the GLB
    arm = next(o for o in sc.objects if o.type == 'ARMATURE')
    if arm.animation_data is None:
        arm.animation_data_create()
    for t in list(arm.animation_data.nla_tracks):  # the importer stacks every clip in the NLA; play one at a time
        arm.animation_data.nla_tracks.remove(t)
    acts = {}
    for a in bpy.data.actions:
        acts.setdefault(a.name.split('|')[-1].strip(), a)
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light, sh.color_type = 'STUDIO', 'OBJECT'
    sh.show_cavity, sh.cavity_type = True, 'BOTH'
    sh.show_object_outline, sh.object_outline_color = True, (0.08, 0.08, 0.08)
    sc.view_settings.view_transform = 'Standard'
    sc.render.film_transparent = True
    sc.render.image_settings.file_format, sc.render.image_settings.color_mode = 'PNG', 'RGBA'
    sc.render.resolution_percentage = 100
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.clip_start, cam.data.clip_end = 0.1, 100
    cam.data.shift_y = GROUND - 0.5               # moves the hips' ground point down from the centre to the GROUND row
    # the character's own axes, standing in Idle (the bind pose floats ~0.3 m up with its feet turned): forward = left hip x up
    arm.animation_data.action = None
    if 'Idle' in acts:
        set_action(arm, acts['Idle'])
        sc.frame_set(int(acts['Idle'].frame_range[0]))
    bpy.context.view_layer.update()
    up = Vector((0, 0, 1))
    left = head(arm, 'LeftUpLeg') - head(arm, 'RightUpLeg')
    fw = Vector((left.x, left.y, 0)).normalized().cross(up)
    fw = Vector((round(fw.x), 0, 0)) if abs(fw.x) > abs(fw.y) else Vector((0, round(fw.y), 0))   # the clips are keyed along the axes; Idle's hips are turned ~7 deg
    axes = {'forward': fw, 'up': up, 'right': fw.cross(up)}
    hr = rot(arm, 'Head').inverted()
    s = dict(sc=sc, arm=arm, acts=acts, cam=cam, axes=axes, props={}, ground=lowest(sc), parts={}, stand=head(arm, 'Hips').z,
             face=hr @ fw, head_up=hr @ up,          # the face's forward and up in the head bone's own frame
             arm_z=arm.location.z, leg=head(arm, 'LeftUpLeg').z - lowest(sc), build='plain')
    for o in sc.objects:
        if o.type == 'MESH':
            o.hide_render = True    # the library's own mesh (an old caped Elvis) hides the pose: the mannequin stands in
    p('loaded', src, len(acts), 'clips; forward', tuple(round(v, 2) for v in fw), 'ground z', round(s['ground'], 3))
    return s


def rot(arm, bone):
    return (arm.matrix_world @ arm.pose.bones[B + bone].matrix).to_3x3().normalized()


# ------------------------------------------------------------------ the clay mannequin: balls and tubes placed on the bones each frame
def segments(s):
    """(name, shape, a, b, side, width radius, depth radius, extra half-length, colour) for the current pose, in metres.
    A ball spans a to b (+ extra each end); a tube is a cylinder from a to b; a ball with a == b is a joint."""
    arm = s['arm']
    h = lambda n: head(arm, n)
    out = []
    big = CHUNKY if s['build'] == 'chunky' else {}
    hips_side, sh_side = h('LeftUpLeg') - h('RightUpLeg'), h('LeftArm') - h('RightArm')
    out += [('pelvis', 'ball', (h('LeftUpLeg') + h('RightUpLeg')) / 2, h('Spine'), hips_side, 0.165, 0.12, 0.07, BODY),
            ('belly', 'ball', h('Hips'), h('Spine1'), sh_side, 0.145, 0.105, 0.03, BODY),
            ('chest', 'ball', h('Spine1'), h('Neck'), sh_side, 0.18, 0.125, 0.0, BODY),
            ('neck', 'tube', h('Neck'), h('Head'), sh_side, 0.055, 0.055, 0.0, BODY)]
    r = rot(arm, 'Head')
    face, hup = r @ s['face'], r @ s['head_up']
    c = h('Head') + hup * (0.16 if big else 0.10)
    out += [('head', 'ball', c - hup * 0.12, c + hup * 0.12, hup.cross(face), 0.095, 0.11, 0.0, BODY),
            ('nose', 'ball', c + face * 0.10 * big.get('head', 1), c + face * 0.10 * big.get('head', 1), hup.cross(face), 0.03, 0.03, 0.0, BODY)]
    for side, col in (('Left', FAR), ('Right', BODY)):
        g = lambda n: h(side + n)
        toe = g('ToeBase') + (g('ToeBase') - g('Foot')).normalized() * 0.07
        out += [(side + 'shoulder', 'ball', g('Arm'), g('Arm'), hips_side, 0.06, 0.06, 0.0, col),
                (side + 'upperarm', 'tube', g('Arm'), g('ForeArm'), hips_side, 0.055, 0.055, 0.0, col),
                (side + 'elbow', 'ball', g('ForeArm'), g('ForeArm'), hips_side, 0.05, 0.05, 0.0, col),
                (side + 'forearm', 'tube', g('ForeArm'), g('Hand'), hips_side, 0.045, 0.045, 0.0, col),
                (side + 'hand', 'ball', g('Hand'), g('Hand') + (g('HandMiddle1') - g('Hand')) * 1.8,
                 g('HandIndex1') - g('HandPinky1'), 0.045, 0.024, 0.01, col),
                (side + 'hip', 'ball', g('UpLeg'), g('UpLeg'), hips_side, 0.08, 0.08, 0.0, col),
                (side + 'thigh', 'tube', g('UpLeg'), g('Leg'), hips_side, 0.075, 0.075, 0.0, col),
                (side + 'knee', 'ball', g('Leg'), g('Leg'), hips_side, 0.062, 0.062, 0.0, col),
                (side + 'shin', 'tube', g('Leg'), g('Foot'), hips_side, 0.055, 0.055, 0.0, col),
                (side + 'foot', 'ball', g('Foot'), toe, hips_side, 0.05, 0.04, 0.05, col)]     # extra: the heel behind the ankle
    if big:    # the chunky build: thicker parts for the master's proportions (the legs are shortened in strip())
        out = [(n, sh, a, b, sd, rw * big.get(n.replace('Left', '').replace('Right', ''), 1),
                rd * big.get(n.replace('Left', '').replace('Right', ''), 1), x * big.get(n.replace('Left', '').replace('Right', ''), 1), col)
               for n, sh, a, b, sd, rw, rd, x, col in out]
    return out


def place_body(s):
    if 'ball' not in s['parts']:
        for shape in ('ball', 'tube'):
            me = bpy.data.meshes.new(shape)
            bm = bmesh.new()
            if shape == 'ball':
                bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
            else:   # a cylinder along +Y, radius 1, from -1 to 1
                bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=1.0, radius2=1.0, depth=2.0,
                                      matrix=Matrix.Rotation(math.radians(90), 4, 'X'))
            bm.to_mesh(me)
            bm.free()
            s['parts'][shape] = me
    for name, shape, a, b, side, rw, rd, extra, col in segments(s):
        o = s['parts'].get(name)
        if o is None:
            o = s['parts'][name] = bpy.data.objects.new('body_' + name, s['parts'][shape])
            o.color = col
            s['sc'].collection.objects.link(o)
        y = (b - a).normalized() if (b - a).length > 1e-6 else Vector((0, 0, 1))
        if (b - a).length <= 1e-6:
            extra = rw          # a joint: a ball of radius rw
        x = (side - y * side.dot(y)).normalized()
        m = Matrix((x * rw, y * ((b - a).length / 2 + extra), x.cross(y) * rd)).transposed().to_4x4()
        m.translation = (a + b) / 2
        o.matrix_world = m


def head(arm, bone):
    return arm.matrix_world @ arm.pose.bones[B + bone].head


def lowest(sc):
    dg = bpy.context.evaluated_depsgraph_get()
    z = []
    for o in sc.objects:
        if o.type == 'MESH' and o.name not in ('spear', 'greatsword'):
            e = o.evaluated_get(dg)
            m = e.to_mesh()
            co = np.empty(len(m.vertices) * 3)
            m.vertices.foreach_get('co', co)
            co = co.reshape(-1, 3)
            mw = np.array(o.matrix_world)
            z.append((co @ mw[:3, :3].T + mw[:3, 3])[:, 2].min())
            e.to_mesh_clear()
    return float(min(z))


def set_action(arm, a):
    arm.animation_data.action = a
    if getattr(a, 'slots', None) and len(a.slots):
        arm.animation_data.action_slot = a.slots[0]


# ------------------------------------------------------------------ props (metres; +Y along the prop, X across the edge)
def taper(y0, y1, w0, w1, t0, t1):
    v = [(-w0 / 2, y0, -t0 / 2), (w0 / 2, y0, -t0 / 2), (w0 / 2, y0, t0 / 2), (-w0 / 2, y0, t0 / 2),
         (-w1 / 2, y1, -t1 / 2), (w1 / 2, y1, -t1 / 2), (w1 / 2, y1, t1 / 2), (-w1 / 2, y1, t1 / 2)]
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return v, f


SHAPES = {   # the right hand grips at y = 0
    'spear': [(-0.78, -0.73, 0.045, 0.045, 0.045, 0.045), (-0.73, 1.08, 0.032, 0.032, 0.032, 0.032),     # 2.2 m
              (1.08, 1.21, 0.025, 0.075, 0.02, 0.02), (1.21, 1.42, 0.075, 0.004, 0.02, 0.004)],
    'greatsword': [(-0.37, -0.30, 0.07, 0.07, 0.07, 0.07), (-0.30, 0.06, 0.04, 0.04, 0.04, 0.04),
                   (0.06, 0.11, 0.36, 0.36, 0.07, 0.07), (0.11, 1.30, 0.10, 0.09, 0.025, 0.025),
                   (1.30, 1.48, 0.09, 0.004, 0.025, 0.004)],
}


def prop_obj(s, kind):
    if kind not in s['props']:
        verts, faces = [], []
        for part in SHAPES[kind]:
            v, f = taper(*part)
            faces += [tuple(i + len(verts) for i in q) for q in f]
            verts += v
        me = bpy.data.meshes.new(kind)
        me.from_pydata(verts, [], faces)
        o = bpy.data.objects.new(kind, me)
        o.color = PROP
        s['sc'].collection.objects.link(o)
        s['props'][kind] = o
    return s['props'][kind]


def grip(arm):
    """The right fist's grip: centre, the axis out of the thumb side (pinky to index knuckle) and the knuckles' direction."""
    h, i, k = head(arm, 'RightHand'), head(arm, 'RightHandIndex1'), head(arm, 'RightHandPinky1')
    axis = (i - k).normalized()
    mid = (i + k) / 2
    knuckles = mid - h
    knuckles = (knuckles - axis * knuckles.dot(axis)).normalized()
    return h.lerp(mid, 0.85), axis, knuckles


def aim(s, kind, c, y, x, carry=None):
    """The prop's axis and edge from grip c: the fist's (y, x), or a steady carry angle. Then, if an end would go through
    the floor, the prop tilts up about the grip, keeping its heading, until that end rests on the ground (a chop lands
    along the ground; a planted sword stands on its tip). Returns (y, x, rested)."""
    if carry:
        ax = s['axes']
        y = (ax['right'] * carry[0] + ax['forward'] * carry[1] + ax['up'] * carry[2]).normalized()
        x = ax['up'].cross(y).normalized() if abs(y.z) < 0.99 else ax['right']
    rested = False
    for end in ((SHAPES[kind][-1][1], SHAPES[kind][0][0]) if kind in SHAPES else ()):   # the tip, then the butt or pommel
        if c.z + y.z * end < s['ground'] - 0.005:
            uz = max(-1.0, min(1.0, (s['ground'] - c.z) / end))
            hz = Vector((y.x, y.y, 0))
            hz = hz.normalized() if hz.length > 0.05 else s['axes']['forward']
            y = hz * math.sqrt(1 - uz * uz) + Vector((0, 0, uz))
            x = (x - y * x.dot(y)).normalized()
            rested = True
    return y, x, rested


def two_hands(s, off, kind='none', carry=None):
    """Both hands on the prop: the left hand `off` metres along it from the right. The library's sword clips are one-handed and
    often fling the right arm out of the left's reach: then the right hand and the prop (its angle kept) come in toward the
    left shoulder by the shortfall. Returns the prop's grip frame (centre, axis, knuckles) for place_prop."""
    arm = s['arm']
    c, y, x = grip(arm)
    sh = head(arm, 'LeftArm')
    reach = 0.95 * ((head(arm, 'LeftForeArm') - sh).length + (head(arm, 'LeftHand') - head(arm, 'LeftForeArm')).length)
    t = c + aim(s, kind, c, y, x, carry)[0] * float(off)     # the left hand goes where place_prop will draw the prop
    short = (t - sh).length - reach
    if short > 0:
        delta = (sh - t).normalized() * short
        two_bone_ik(arm, 'RightArm', 'RightForeArm', 'RightHand', head(arm, 'RightHand') + delta)
        c, t = c + delta, t + delta
    two_bone_ik(arm, 'LeftArm', 'LeftForeArm', 'LeftHand', t)
    return c, y, x


def place_prop(s, kind, carry=None, held=None):
    """carry: [right, forward, up] = the prop held at that steady angle (the character's axes) instead of turning with the fist.
    held: a grip frame from two_hands (the right fist was moved, so its own turn no longer says where the prop points).
    Returns True when the prop was tilted up to rest on the ground (see aim)."""
    for o in s['props'].values():
        o.hide_render = o.name != kind
    if kind == 'none':
        return False
    o = prop_obj(s, kind)
    c, y, x = held or grip(s['arm'])
    y, x, rested = aim(s, kind, c, y, x, carry)
    m = Matrix((x, y, x.cross(y))).transposed().to_4x4()
    m.translation = c
    o.matrix_world = m
    return rested


# ------------------------------------------------------------------ hand-keyed clips
def rotate_bone(arm, bone, q, at):
    """Turn a bone (its children follow) by the world rotation q about the world point at."""
    pb = arm.pose.bones[B + bone]
    mw = arm.matrix_world @ pb.matrix
    pb.matrix = arm.matrix_world.inverted() @ (Matrix.Translation(at) @ q.to_matrix().to_4x4() @ Matrix.Translation(-at) @ mw)
    bpy.context.view_layer.update()


def two_bone_ik(arm, upper, lower, end, target):
    """Bend upper/lower so end's head reaches target, the elbow staying on the side it was on."""
    s, e, h = head(arm, upper), head(arm, lower), head(arm, end)
    a, b = (e - s).length, (h - e).length
    d = target - s
    dist = min(max(d.length, abs(a - b) + 1e-4), a + b - 1e-4)
    u = d.normalized()
    pole = (e - s) - u * (e - s).dot(u)
    pole = pole.normalized() if pole.length > 1e-6 else Vector((0, 0, -1))
    cos_a = (a * a + dist * dist - b * b) / (2 * a * dist)
    elbow = s + u * a * cos_a + pole * a * math.sqrt(max(0.0, 1 - cos_a * cos_a))
    rotate_bone(arm, upper, (e - s).rotation_difference(elbow - s), s)
    e, h = head(arm, lower), head(arm, end)
    rotate_bone(arm, lower, (h - e).rotation_difference(s + u * dist - e), e)
    miss = (head(arm, end) - target).length
    if miss > 0.03:
        p('IK: %s is %.2f m short of its target (out of reach)' % (end, miss))


def key_pose(s, pose):
    """One key pose: a frame of a clip, eased toward a calmer pose, then hips moves, turns about the character's axes, hands on
    targets, the prop aimed, the left hand onto the prop, and the body set down on the ground (keys in clips.md)."""
    arm, sc, ax = s['arm'], s['sc'], s['axes']
    calm = {}               # "ease": {"to": [clip, frame], "by": 0.5, "bones": [...]} or a list of them: those bones'
    for e in ([pose['ease']] if isinstance(pose.get('ease'), dict) else pose.get('ease', [])):    # turns eased toward a calmer pose
        set_action(arm, s['acts'][e['to'][0]])
        sc.frame_set(int(s['acts'][e['to'][0]].frame_range[0] + e['to'][1]))
        calm.update({n: (arm.pose.bones[B + n].rotation_quaternion.copy(), e['by']) for n in e['bones']})
    clip, frame = pose['from']
    set_action(arm, s['acts'][clip])
    sc.frame_set(int(s['acts'][clip].frame_range[0] + frame))
    arm.animation_data.action = None               # keep the evaluated pose, stop the clip overwriting the edits
    bpy.context.view_layer.update()
    if calm:                # eased legs straighten: lift or drop the body so the lowest foot stays where the clip had it
        low = lambda: min(head(arm, n).z for n in ('LeftFoot', 'RightFoot', 'LeftToeBase', 'RightToeBase'))
        was = low()
        for n, (q, by) in calm.items():
            pb = arm.pose.bones[B + n]
            pb.rotation_quaternion = pb.rotation_quaternion.slerp(q, by)
        bpy.context.view_layer.update()
        pb = arm.pose.bones[B + 'Hips']
        pb.matrix = arm.matrix_world.inverted() @ Matrix.Translation(ax['up'] * (was - low())) @ arm.matrix_world @ pb.matrix
        bpy.context.view_layer.update()
    if 'hips' in pose:
        pb = arm.pose.bones[B + 'Hips']
        dx, dy, dz = pose['hips']
        mw = Matrix.Translation(ax['right'] * dx + ax['forward'] * dy + ax['up'] * dz) @ arm.matrix_world @ pb.matrix
        pb.matrix = arm.matrix_world.inverted() @ mw
        bpy.context.view_layer.update()
    depth = lambda n: len(arm.pose.bones[B + n].parent_recursive)
    for bone in sorted(pose.get('turn', {}), key=depth):
        for axis, deg in pose['turn'][bone]:
            rotate_bone(arm, bone, Quaternion(ax[axis], math.radians(deg)), head(arm, bone))
    for side, (bone, off) in pose.get('hand_on', {}).items():   # "Left": ["LeftLeg", [right, forward, up]]: the wrist onto a joint
        t = head(arm, bone) + ax['right'] * off[0] + ax['forward'] * off[1] + ax['up'] * off[2]
        two_bone_ik(arm, side + 'Arm', side + 'ForeArm', side + 'Hand', t)
    if 'aim' in pose:       # [right, forward, up]: the right fist turns so the prop points that way
        y = grip(arm)[1]
        want = (ax['right'] * pose['aim'][0] + ax['forward'] * pose['aim'][1] + ax['up'] * pose['aim'][2]).normalized()
        rotate_bone(arm, 'RightHand', y.rotation_difference(want), head(arm, 'RightHand'))
    if 'left_grip' in pose:     # metres along the prop from the right hand: + toward the blade, - toward the pommel or butt
        two_hands(s, pose['left_grip'])     # shortcut: a moved right fist then aims the prop by its own turn; key it if that's off
    if pose.get('plant'):   # the body moved up or down until its lowest part rests on the ground (the library's in-place roll floats)
        place_body(s)
        z = min((o.matrix_world @ v.co).z for n, o in s['parts'].items() if n not in ('ball', 'tube') for v in o.data.vertices)
        pb = arm.pose.bones[B + 'Hips']
        pb.matrix = arm.matrix_world.inverted() @ Matrix.Translation(ax['up'] * (s['ground'] - z)) @ arm.matrix_world @ pb.matrix
        bpy.context.view_layer.update()
    return {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}


def hand_keyed(s, name):
    spec = json.load(open(os.path.join(HERE, 'hand_keys.json'), encoding='utf-8'))[name]
    arm, step = s['arm'], spec['step']
    poses = [key_pose(s, {**spec.get('each', {}), **k}) for k in spec['poses']]     # "each": keys every pose shares
    a = bpy.data.actions.new(name)
    set_action(arm, a)
    for i, pose in enumerate(poses):
        for pb in arm.pose.bones:
            pb.matrix_basis = pose[pb.name]
            pb.keyframe_insert('location', frame=i * step, group=pb.name)
            pb.keyframe_insert('rotation_quaternion', frame=i * step, group=pb.name)
    s['acts'][name] = a
    p('hand-keyed', name, len(poses), 'poses, every', step, 'frames')
    return a


# ------------------------------------------------------------------ render
def frames_of(spec, f0, f1):
    spec = str(spec)
    if ',' in spec:
        return [float(f) for f in spec.split(',')]
    if '/' in spec:
        rng, n = spec.split('/')
        a, b = (float(v) for v in rng.split('-'))
        n = int(n)
        return [a + (b - a) * i / max(1, n - 1) for i in range(n)]
    n = int(spec)
    if n < 1:
        raise SystemExit('--frames %r: a count of 1 or more, a range a-b/n, or a list (one frame: "0,0")' % spec)
    return [(f1 - f0) * i / n for i in range(n)]


def strip(s, clip, frames, view, prop, out, cell=256, left_grip=None, air=False, yaw=0.0, carry=None, build='plain'):
    """left_grip: put the left hand on the prop (metres along it from the right hand) in every frame, by IK.
    carry: [right, forward, up]: the prop kept at that angle (runs: the pumping fist would spin it).
    air: the cell rises with the hips above standing height (a jump stays in the cell; the game adds the arc).
    yaw: degrees to swing the camera round him (+ = toward his left); a clip keyed turned off his forward is re-centred by
    passing the 'hips facing' the log prints for it. A list gives each frame its own yaw: a clip that spins (a slash) is
    re-centred frame by frame, keeping some of the twist (guide_jobs.json keeps 35 degrees)."""
    sc, arm, cam, ax = s['sc'], s['arm'], s['cam'], s['axes']
    a = s['acts'].get(clip) or (hand_keyed(s, clip) if clip.startswith('HK ') else None)
    if a is None:
        raise SystemExit('no clip named %r' % clip)
    f0, f1 = (int(round(v)) for v in a.frame_range)
    fw, up = ax['forward'], ax['up']
    sc.render.resolution_x = sc.render.resolution_y = cell
    cam.data.ortho_scale = cell / PPM
    tmp = out + '.tmp.png'
    cells, clipped, facing, rested = [], [], [], []
    fs = frames_of(frames, f0, f1)
    yaws = yaw if isinstance(yaw, list) else [yaw] * len(fs)     # a list: one yaw per frame (re-centres a clip that turns)
    assert len(yaws) == len(fs), 'yaw: one value per frame, or one for all'
    for k, f in enumerate(fs):
        h = Quaternion(up, math.radians(yaws[k])) @ {'F': -fw, 'B': fw, 'S': up.cross(fw)}[view]   # the camera looks along h
        d = Vector((h.x * math.cos(PITCH), h.y * math.cos(PITCH), -math.sin(PITCH)))
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        f = min(max(f0 + f, f0), f1)
        set_action(arm, a)
        sc.frame_set(int(f), subframe=f - int(f))
        s['build'] = build
        if build == 'chunky':    # shorter legs, uniform scale so the knee and ankle angles stay the clip's
            for side in ('Left', 'Right'):
                arm.pose.bones[B + side + 'UpLeg'].scale = (LEGS, LEGS, LEGS)
            arm.location.z = s['arm_z'] - (1 - LEGS) * s['leg']
            bpy.context.view_layer.update()
        held = None
        if left_grip is not None:
            arm.animation_data.action = None       # keep the clip's pose and edit it (as key_pose does)
            held = two_hands(s, left_grip, prop, carry)
        place_body(s)
        if place_prop(s, prop, carry, held):
            rested.append(k)
        hips = head(arm, 'Hips')
        hf = (head(arm, 'LeftUpLeg') - head(arm, 'RightUpLeg')).cross(up)      # where the hips face
        facing.append(round(math.degrees(math.atan2(fw.cross(hf).z, fw.dot(hf)))))
        lift = max(0.0, hips.z - s['stand']) if air else 0.0
        cam.location = Vector((hips.x, hips.y, s['ground'] + lift)) - d * 30
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(cell, cell, 4)
        bpy.data.images.remove(im)
        fig = px[..., 3] > 0.5                       # hard edges: no half-magenta fringe for the clean-up to fight
        if fig[0].any() or fig[-1].any() or fig[:, 0].any() or fig[:, -1].any():
            clipped.append(k)
        rgb = np.where(fig[..., None], px[..., :3], np.array([1.0, 0.0, 1.0], np.float32))
        cells.append(np.dstack([rgb, np.ones((cell, cell), np.float32)]))
    os.remove(tmp)
    for side in ('Left', 'Right'):
        arm.pose.bones[B + side + 'UpLeg'].scale = (1, 1, 1)
    arm.location.z, s['build'] = s['arm_z'], 'plain'
    img = np.concatenate(cells, axis=1)
    im = bpy.data.images.new('strip', img.shape[1], img.shape[0])
    im.pixels.foreach_set(img.ravel())
    im.filepath_raw, im.file_format = out, 'PNG'
    im.save()
    bpy.data.images.remove(im)
    p('strip', out, clip, view, prop, len(cells), 'frames', 'CLIPPED cells %s' % clipped if clipped else 'ok',
      '| hips facing (deg, + = his left):', facing, '| prop rests on the ground in cells %s' % rested if rested else '')


def main():
    argv = sys.argv[sys.argv.index('--') + 1:]
    opt = dict(zip(argv[::2], argv[1::2]))
    s = load(opt['--source'])
    if '--batch' in opt:
        jobs = json.load(open(opt['--batch'], encoding='utf-8'))
    else:
        jobs = [dict(clip=opt['--clip'], frames=opt['--frames'], view=opt.get('--view', 'F'), prop=opt.get('--prop', 'none'),
                     out=opt['--out'], cell=opt.get('--cell', 256), left_grip=opt.get('--left-grip'),
                     air=opt.get('--air') == '1', yaw=[float(v) for v in opt.get('--yaw', '0').split(',')],
                     carry=[float(v) for v in opt['--carry'].split(',')] if '--carry' in opt else None,
                     build=opt.get('--build', 'plain'))]
    for j in jobs:
        y = j.get('yaw', 0)
        y = [float(v) for v in y] if isinstance(y, list) else float(y)
        if isinstance(y, list) and len(y) == 1:
            y = y[0]
        strip(s, j['clip'], j['frames'], j.get('view', 'F'), j.get('prop', 'none'), j['out'], int(j.get('cell', 256)),
              j.get('left_grip'), bool(j.get('air')), y, j.get('carry'), j.get('build', 'plain'))


main()
