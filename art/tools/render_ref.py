"""Colour reference of Vulcan at the game camera angle, for Gemini (Task A1).

Blender 5.2, headless, on a COPY of the Unreal repo's SourceArt/Vulcan/Vulcan.blend (copies live in art/_work/):
  blender.exe -b <copy.blend> --python render_ref.py -- --outfit 1 --possessed 1 --yaw 0 --out <png>

--outfit / --possessed: Armature["outfit"] (0 human, 1 boss armour) and ["possessed"] (0..1), see
SourceArt/Scripts/vulcan_boss.py. --yaw turns the camera around him (0 = front). The camera is orthographic and looks
down 48.59 deg, like the game's. Arms are lowered from the A-pose so he stands at rest. Transparent background.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

A = sys.argv[sys.argv.index("--") + 1:]
arg = lambda k, d: A[A.index(k) + 1] if k in A else d
OUTFIT, POSS = int(arg("--outfit", "1")), float(arg("--possessed", "1"))
YAW, OUT = float(arg("--yaw", "0")), arg("--out", "ref.png")
ARM_DOWN = float(arg("--arm-down", "38"))
SRC_DIR = arg("--src-dir", r"D:\TalesOfVulkan\TalesOfVulkan\SourceArt\Vulcan")   # read-only: textures only
PITCH = 48.59

# The copy sits elsewhere, so its //relative texture paths point at the original folder (read, never written).
for im in bpy.data.images:
    if im.filepath.startswith("//"):
        im.filepath = os.path.join(SRC_DIR, im.filepath[2:].replace("/", "\\"))
        im.reload()

O = bpy.data.objects
ARM = O["Armature"]
ARM["outfit"], ARM["possessed"] = OUTFIT, POSS
for o in O:
    if o.name.startswith("Boss_") or o.name == "Trousers_Boss":
        o.hide_render = OUTFIT == 0
ARM.data.pose_position = "POSE"

# Lower both arms about the front axis at the shoulder (the A-pose is ~40 deg out).
bpy.context.view_layer.update()
for side, sgn in (("l", 1), ("r", -1)):
    pb = ARM.pose.bones["upperarm_" + side]
    head = pb.head.copy()
    for s in (sgn, -sgn):
        rot = Matrix.Translation(head) @ Matrix.Rotation(math.radians(ARM_DOWN) * s, 4, "Y") @ Matrix.Translation(-head)
        old = pb.matrix.copy()
        pb.matrix = rot @ old
        bpy.context.view_layer.update()
        if pb.tail.z < head.z - 0.2:      # pointing down: keep
            break
        pb.matrix = old
        bpy.context.view_layer.update()
bpy.context.view_layer.update()

# Which way he faces: the eyes are in front of the head bone.
eye = (ARM.matrix_world @ ARM.pose.bones["eye_l"].head + ARM.matrix_world @ ARM.pose.bones["eye_r"].head) / 2
hd = ARM.matrix_world @ ARM.pose.bones["head"].head
fwd = Vector((eye.x - hd.x, eye.y - hd.y, 0)).normalized()
face_yaw = math.atan2(fwd.y, fwd.x)          # angle of his forward vector

sc = bpy.context.scene
cam_data = bpy.data.cameras.new("RefCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.6
cam = bpy.data.objects.new("RefCam", cam_data)
sc.collection.objects.link(cam)
yaw = face_yaw + math.radians(YAW)
d = Vector((math.cos(yaw), math.sin(yaw), 0))     # from him toward the camera, on the ground
p = math.radians(PITCH)
target = Vector((0, 0, 1.0))
cam.location = target + (d * math.cos(p) + Vector((0, 0, math.sin(p)))) * 10
cam.rotation_euler = (cam.location - target).to_track_quat("Z", "Y").to_euler()
sc.camera = cam

# Light: a warm sun high front-left, cool fill from the world.
sun_d = bpy.data.lights.new("RefSun", "SUN")
sun_d.energy = 3.5
sun_d.color = (1.0, 0.93, 0.82)
sun = bpy.data.objects.new("RefSun", sun_d)
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(40), 0, yaw - math.radians(35) + math.pi / 2)
w = sc.world or bpy.data.worlds.new("RefWorld")
sc.world = w
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.42, 0.45, 0.52, 1)
bg.inputs[1].default_value = 0.9

for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
if sc.render.engine == "CYCLES":
    sc.cycles.samples = 64
else:
    sc.eevee.taa_render_samples = 64
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 800, 1000, 100
sc.view_settings.view_transform = "Standard"
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("REF wrote", OUT, "engine", sc.render.engine, "face_yaw", round(math.degrees(face_yaw), 1))
