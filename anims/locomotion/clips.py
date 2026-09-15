"""Locomotion clip set for the blob R15 character, authored as Blender Actions (Loco_*).

Poses are written in Roblox joint conventions (see rbxanim.py). Each clip is a list of
(time_s, pose, feet) beats; feet = {'Right': sole target | None, 'Left': ...} where a target
is the sole height above the floor (0 = planted) and None leaves the authored knee alone.
Knees for planted feet are solved against the blob character's real leg geometry.
"""
import bpy, math, os, sys
from mathutils import Vector
ra = sys.modules['rbxanim_c9']

HERE = os.path.dirname(os.path.abspath(__file__))
SERVE = os.path.join(os.path.dirname(HERE), 'serve', 'c9')
PREFIX = 'Loco_'

# blob leg chain measured on the rest-pose rig, relative to the root pivot (Roblox axes, studs)
def _leg(side):
    s = 1 if side == 'Right' else -1
    return (Vector((s * 0.706, 0.376, 0.0)),      # hip pivot
            Vector((s * 0.244, -0.579, 0.0)),     # hip -> knee (thigh angles outward)
            Vector((s * -0.160, -0.686, 0.0)),    # knee -> ankle (shin angles back inward)
            Vector((0.0, -0.314, 0.0)))           # ankle -> sole
FLOOR = -1.203  # sole y at rest -> rest sole height = 0


def full(pose):
    return {j: tuple(pose.get(j, (0, 0, 0))) for j in ra.JOINTS}


def sole_height(pose, side):
    hip, thigh, shin, foot = _leg(side)
    lt = pose.get('LowerTorso', (0, 0, 0))
    R0 = ra.rbx_rot(*lt[:3]); p0 = Vector(lt[3:6]) if len(lt) == 6 else Vector((0, 0, 0))
    Rh = R0 @ ra.rbx_rot(*pose.get(side + 'UpperLeg', (0, 0, 0))[:3])
    knee = p0 + R0 @ hip + Rh @ thigh
    Rk = Rh @ ra.rbx_rot(*pose.get(side + 'LowerLeg', (0, 0, 0))[:3])
    ankle = knee + Rk @ shin
    Rf = Rk @ ra.rbx_rot(*pose.get(side + 'Foot', (0, 0, 0))[:3])
    return (ankle + Rf @ foot).y - FLOOR


def plant(pose, feet):
    pose = dict(pose)
    for side, target in feet.items():
        if target is None:
            continue
        hip = pose.get(side + 'UpperLeg', (0, 0, 0))
        lt = pose.get('LowerTorso', (0, 0, 0))
        knee_y = pose.get(side + 'LowerLeg', (0, 0, 0))[1]
        knee_z = pose.get(side + 'LowerLeg', (0, 0, 0))[2]
        pose[side + 'LowerLeg'] = (0, knee_y, knee_z)
        if sole_height(pose, side) <= target:
            lo, hi = -150.0, 0.0
            for _ in range(60):
                mid = (lo + hi) / 2
                pose[side + 'LowerLeg'] = (mid, knee_y, knee_z)
                if sole_height(pose, side) < target:
                    hi = mid
                else:
                    lo = mid
            pose[side + 'LowerLeg'] = (round((lo + hi) / 2, 2), knee_y, knee_z)
        if target < 0.02:  # planted: keep the sole flat
            k = pose[side + 'LowerLeg'][0]
            f = pose.get(side + 'Foot', (0, 0, 0))
            pose[side + 'Foot'] = (round(-(lt[0] + hip[0] + k), 2), f[1], f[2])
    return pose


def build(name, beats, length, loop):
    ra.set_action(PREFIX + name)
    keys = [(t, plant(full(p), feet)) for t, p, feet in beats]
    if loop:
        keys = ([(t - length, p) for t, p in keys] + keys + [(t + length, p) for t, p in keys])
    keys.sort(key=lambda k: k[0])
    for t, p in keys:
        ra.key_pose(t, p)
    ra.finalize()
    sc = bpy.context.scene
    sc.frame_start = 0
    sc.frame_end = int(round(length * ra.FPS))
    return keys


def mirror(pose):
    """Swap left/right and mirror across the sagittal plane (negate Y and Z rotations, X pos)."""
    out = {}
    for j, v in pose.items():
        m = j.replace('Left', '@').replace('Right', 'Left').replace('@', 'Right')
        r = (v[0], -v[1], -v[2])
        out[m] = r + ((-v[3], v[4], v[5]) if len(v) == 6 else ())
    return out


ARMS_READY = {'RightUpperArm': (6, 0, 10), 'LeftUpperArm': (6, 0, -10),
              'RightLowerArm': (10, 0, 0), 'LeftLowerArm': (10, 0, 0),
              'RightHand': (0, 0, 0), 'LeftHand': (0, 0, 0)}
DOWN = {'Right': 0.0, 'Left': 0.0}


def P(**kw):
    """Compact pose builder: keys are joint names (abbrev allowed), values tuples."""
    ab = {'LT': 'LowerTorso', 'UT': 'UpperTorso', 'H': 'Head',
          'RUA': 'RightUpperArm', 'RLA': 'RightLowerArm', 'RH': 'RightHand',
          'LUA': 'LeftUpperArm', 'LLA': 'LeftLowerArm', 'LH': 'LeftHand',
          'RUL': 'RightUpperLeg', 'RLL': 'RightLowerLeg', 'RF': 'RightFoot',
          'LUL': 'LeftUpperLeg', 'LLL': 'LeftLowerLeg', 'LF': 'LeftFoot'}
    return {ab.get(k, k): v for k, v in kw.items()}


# ------------------------------------------------------------------ IDLE (2.0 s loop)
IDLE = [
    (0.00, P(LT=(0, 0, 0, 0, 0.00, 0), UT=(0, 0, 0), H=(0, 0, 0), **ARMS_READY), DOWN),
    (0.55, P(LT=(2, 0, 2.5, 0.05, -0.11, 0), UT=(-5, 3, -2), H=(-5, 7, 3),
             RUA=(2, 0, 18), LUA=(2, 0, -18), RLA=(22, 0, 0), LLA=(22, 0, 0), RH=(-8, 0, 0), LH=(-8, 0, 0)), DOWN),
    (1.10, P(LT=(-2, 0, 0, 0, 0.04, 0), UT=(3, 0, 0), H=(4, 0, 0),
             RUA=(9, 0, 6), LUA=(9, 0, -6), RLA=(6, 0, 0), LLA=(6, 0, 0), RH=(5, 0, 0), LH=(5, 0, 0)), DOWN),
    (1.55, P(LT=(2, 0, -2.5, -0.05, -0.07, 0), UT=(-2, -3, 2), H=(-2, -7, -3),
             RUA=(2, 0, 15), LUA=(2, 0, -15), RLA=(18, 0, 0), LLA=(18, 0, 0), RH=(-5, 0, 0), LH=(-5, 0, 0)), DOWN),
]
IDLE_LEN = 2.0

# ------------------------------------------------------------------ IDLE2 (5.0 s loop): look around, then a big stretch
IDLE2 = [
    (0.00, P(LT=(0, 0, 0, 0, 0, 0), **ARMS_READY), DOWN),
    (0.50, P(LT=(1, 0, 1.5, 0.03, -0.06, 0), UT=(-3, 2, -1), H=(-3, 4, 1.5),
             RUA=(4, 0, 14), LUA=(4, 0, -14), RLA=(16, 0, 0), LLA=(16, 0, 0)), DOWN),
    (0.90, P(LT=(0, 6, 0, -0.04, -0.02, 0), UT=(0, 12, 2), H=(2, 38, 4),
             RUA=(8, 0, 12), LUA=(2, 0, -12), RLA=(12, 0, 0), LLA=(12, 0, 0)), DOWN),
    (1.40, P(LT=(0, 5, 0, -0.03, -0.03, 0), UT=(0, 10, 2), H=(0, 32, 3),
             RUA=(8, 0, 12), LUA=(2, 0, -12), RLA=(12, 0, 0), LLA=(12, 0, 0)), DOWN),
    (1.60, P(LT=(0, 7, 0, -0.03, -0.05, 0), UT=(-2, 14, 2), H=(-3, 44, 5),
             RUA=(8, 0, 12), LUA=(2, 0, -12), RLA=(12, 0, 0), LLA=(12, 0, 0)), DOWN),
    (1.85, P(LT=(0, -6, 0, 0.04, -0.02, 0), UT=(0, -12, -2), H=(2, -38, -4),
             RUA=(2, 0, 12), LUA=(8, 0, -12), RLA=(12, 0, 0), LLA=(12, 0, 0)), DOWN),
    (2.40, P(LT=(0, -5, 0, 0.03, -0.03, 0), UT=(0, -10, -2), H=(0, -32, -3),
             RUA=(2, 0, 12), LUA=(8, 0, -12), RLA=(12, 0, 0), LLA=(12, 0, 0)), DOWN),
    (2.75, P(LT=(0, 0, 0, 0, -0.02, 0), UT=(0, 0, 0), H=(0, 0, 0), **ARMS_READY), DOWN),
    # anticipation crouch
    (3.00, P(LT=(3, 0, 0, 0, -0.14, 0.04), UT=(-8, 0, 0), H=(-8, 0, 0),
             RUA=(-18, 0, 12), LUA=(-18, 0, -12), RLA=(20, 0, 0), LLA=(20, 0, 0), RH=(-10, 0, 0), LH=(-10, 0, 0)), DOWN),
    # big stretch up
    (3.25, P(LT=(-4, 0, 0, 0, 0.16, -0.02), UT=(9, 0, 0), H=(14, 0, 0),
             RUA=(168, 0, 22), LUA=(168, 0, -22), RLA=(12, 0, 0), LLA=(12, 0, 0), RH=(12, 0, 0), LH=(12, 0, 0),
             RUL=(4, 0, 0), LUL=(4, 0, 0), RLL=(-6, 0, 0), LLL=(-6, 0, 0), RF=(-14, 0, 0), LF=(-14, 0, 0)), {}),
    (3.65, P(LT=(-5, 0, 2, 0.02, 0.13, -0.02), UT=(11, 0, -2), H=(16, 0, -3),
             RUA=(172, 0, 30), LUA=(172, 0, -30), RLA=(8, 0, 0), LLA=(8, 0, 0), RH=(16, 0, 0), LH=(16, 0, 0),
             RUL=(4, 0, 0), LUL=(4, 0, 0), RLL=(-6, 0, 0), LLL=(-6, 0, 0), RF=(-12, 0, 0), LF=(-12, 0, 0)), {}),
    # release and droop
    (4.00, P(LT=(3, 0, 0, 0, -0.09, 0.02), UT=(-5, 0, 0), H=(-6, 0, 0),
             RUA=(24, 0, 30), LUA=(24, 0, -30), RLA=(30, 0, 0), LLA=(30, 0, 0), RH=(-12, 0, 0), LH=(-12, 0, 0)), DOWN),
    (4.40, P(LT=(-1, 0, 0, 0, 0.03, 0), UT=(2, 0, 0), H=(2, 0, 0),
             RUA=(8, 0, 8), LUA=(8, 0, -8), RLA=(6, 0, 0), LLA=(6, 0, 0), RH=(4, 0, 0), LH=(4, 0, 0)), DOWN),
]
IDLE2_LEN = 5.0

# ------------------------------------------------------------------ WALK (1.0 s loop): strut
WALK_CONTACT = P(LT=(-2, -6, 0, 0.02, -0.12, 0), UT=(-4, 9, -2), H=(2, -4, 1),
                 RUL=(28, 0, 0), RLL=(-8, 0, 0), RF=(12, 0, 0),
                 LUL=(-24, 0, 0), LLL=(-22, 0, 0), LF=(-16, 0, 0),
                 LUA=(32, 0, -10), LLA=(24, 0, 0), LH=(0, 0, 0),
                 RUA=(-26, 0, 10), RLA=(10, 0, 0), RH=(-6, 0, 0))
WALK_PASS = P(LT=(-1, 0, 4, 0.05, 0.02, 0), UT=(-2, 0, -3), H=(-2, 0, -1),
              RUL=(0, 0, 0), RLL=(-6, 0, 0), RF=(0, 0, 0),
              LUL=(6, 0, 0), LLL=(-62, 0, 0), LF=(-20, 0, 0),
              LUA=(4, 0, -10), LLA=(18, 0, 0), RUA=(4, 0, 10), RLA=(12, 0, 0))
WALK = [
    (0.00, WALK_CONTACT, {'Right': 0.0, 'Left': None}),
    (0.25, WALK_PASS, {'Right': 0.0, 'Left': None}),
    (0.50, mirror(WALK_CONTACT), {'Left': 0.0, 'Right': None}),
    (0.75, mirror(WALK_PASS), {'Left': 0.0, 'Right': None}),
]
WALK_LEN = 1.0

# ------------------------------------------------------------------ RUN (0.6 s loop): bouncy scurry
RUN_CONTACT = P(LT=(-5, -8, 0, 0, -0.14, -0.06), UT=(-20, 12, -3), H=(10, -6, 2),
                RUL=(42, 0, 2), RLL=(-28, 0, 0), RF=(6, 0, 0),
                LUL=(-34, 0, -2), LLL=(-40, 0, 0), LF=(-24, 0, 0),
                LUA=(58, 0, -12), LLA=(88, 0, 0), LH=(0, 0, -8),
                RUA=(-46, 0, 12), RLA=(70, 0, 0), RH=(0, 0, 8))
RUN_FLIGHT = P(LT=(-3, 0, 0, 0, 0.18, -0.02), UT=(-14, 0, 0), H=(6, 0, 0),
               RUL=(-30, 0, 2), RLL=(-18, 0, 0), RF=(-30, 0, 0),
               LUL=(34, 0, -2), LLL=(-96, 0, 0), LF=(-12, 0, 0),
               LUA=(6, 0, -12), LLA=(84, 0, 0), LH=(0, 0, -4),
               RUA=(6, 0, 12), RLA=(84, 0, 0), RH=(0, 0, 4))
RUN = [
    (0.00, RUN_CONTACT, {'Right': 0.0, 'Left': None}),
    (0.15, RUN_FLIGHT, {}),
    (0.30, mirror(RUN_CONTACT), {'Left': 0.0, 'Right': None}),
    (0.45, mirror(RUN_FLIGHT), {}),
]
RUN_LEN = 0.6

# ------------------------------------------------------------------ FALL (0.8 s loop): flail
FALL_A = P(LT=(6, 0, 0, 0, 0.0, 0.05), UT=(4, 0, 0), H=(-10, 0, 0),
           RUA=(132, 0, 50), LUA=(132, 0, -50), RLA=(25, 0, 0), LLA=(25, 0, 0), RH=(0, 0, -15), LH=(0, 0, 15),
           LUL=(25, 0, -3), LLL=(-50, 0, 0), LF=(-15, 0, 0), RUL=(-10, 0, 3), RLL=(-35, 0, 0), RF=(-15, 0, 0))
FALL_B = P(LT=(9, 0, 2, 0.02, 0.02, 0.06), UT=(6, 0, -2), H=(-12, 0, 4),
           RUA=(152, 0, 35), LUA=(152, 0, -35), RLA=(15, 0, 0), LLA=(15, 0, 0), RH=(0, 0, 15), LH=(0, 0, -15),
           LUL=(5, 0, -3), LLL=(-70, 0, 0), LF=(-20, 0, 0), RUL=(20, 0, 3), RLL=(-45, 0, 0), RF=(-10, 0, 0))
FALL_C = P(LT=(5, 0, 0, 0, 0.0, 0.05), UT=(3, 0, 0), H=(-9, 0, 0),
           RUA=(130, 0, 60), LUA=(130, 0, -60), RLA=(35, 0, 0), LLA=(35, 0, 0), RH=(0, 0, -15), LH=(0, 0, 15),
           LUL=(-10, 0, -3), LLL=(-35, 0, 0), LF=(-15, 0, 0), RUL=(25, 0, 3), RLL=(-50, 0, 0), RF=(-15, 0, 0))
FALL_D = P(LT=(8, 0, -2, -0.02, 0.02, 0.06), UT=(6, 0, 2), H=(-12, 0, -4),
           RUA=(150, 0, 40), LUA=(150, 0, -40), RLA=(15, 0, 0), LLA=(15, 0, 0), RH=(0, 0, 15), LH=(0, 0, -15),
           LUL=(20, 0, -3), LLL=(-45, 0, 0), LF=(-10, 0, 0), RUL=(5, 0, 3), RLL=(-70, 0, 0), RF=(-20, 0, 0))
FALL = [(0.0, FALL_A, {}), (0.2, FALL_B, {}), (0.4, FALL_C, {}), (0.6, FALL_D, {})]
FALL_LEN = 0.8

# ------------------------------------------------------------------ JUMP (0.7 s, plays once; fall blends in after ~0.3 s)
JUMP = [
    (0.00, P(LT=(2, 0, 0, 0, 0.14, 0), UT=(6, 0, 0), H=(10, 0, 0),
             RUA=(118, 0, 18), LUA=(118, 0, -18), RLA=(22, 0, 0), LLA=(22, 0, 0), RH=(6, 0, 0), LH=(6, 0, 0),
             RUL=(10, 0, 2), LUL=(10, 0, -2), RLL=(-18, 0, 0), LLL=(-18, 0, 0), RF=(-22, 0, 0), LF=(-22, 0, 0)), {}),
    (0.12, P(LT=(-2, 0, 0, 0, 0.30, -0.02), UT=(9, 0, 0), H=(15, 0, 0),
             RUA=(162, 0, 28), LUA=(162, 0, -28), RLA=(10, 0, 0), LLA=(10, 0, 0), RH=(12, 0, 0), LH=(12, 0, 0),
             RUL=(-6, 0, 2), LUL=(-6, 0, -2), RLL=(-34, 0, 0), LLL=(-34, 0, 0), RF=(-36, 0, 0), LF=(-36, 0, 0)), {}),
    (0.30, P(LT=(4, 0, 0, 0, 0.10, 0.02), UT=(-4, 0, 0), H=(2, 0, 0),
             RUA=(142, 0, 40), LUA=(142, 0, -40), RLA=(26, 0, 0), LLA=(26, 0, 0), RH=(0, 0, -10), LH=(0, 0, 10),
             RUL=(52, 0, 3), LUL=(48, 0, -3), RLL=(-100, 0, 0), LLL=(-96, 0, 0), RF=(-10, 0, 0), LF=(-10, 0, 0)), {}),
    (0.52, P(LT=(6, 0, 0, 0, 0.02, 0.04), UT=(4, 0, 0), H=(-6, 0, 0),
             RUA=(130, 0, 52), LUA=(130, 0, -52), RLA=(28, 0, 0), LLA=(28, 0, 0), RH=(0, 0, -14), LH=(0, 0, 14),
             RUL=(4, 0, 3), LUL=(22, 0, -3), RLL=(-48, 0, 0), LLL=(-56, 0, 0), RF=(-14, 0, 0), LF=(-14, 0, 0)), {}),
    (0.70, FALL_A, {}),
]
JUMP_LEN = 0.7

CLIPS = {
    'Idle':  (IDLE,  IDLE_LEN,  True,  'Core'),
    'Idle2': (IDLE2, IDLE2_LEN, True,  'Core'),
    'Walk':  (WALK,  WALK_LEN,  True,  'Core'),
    'Run':   (RUN,   RUN_LEN,   True,  'Core'),
    'Jump':  (JUMP,  JUMP_LEN,  False, 'Core'),
    'Fall':  (FALL,  FALL_LEN,  True,  'Core'),
}


def build_all(names=None):
    for name in (names or CLIPS):
        beats, length, loop, _ = CLIPS[name]
        build(name, beats, length, loop)


def use(name):
    ra.ARM.animation_data.action = bpy.data.actions[PREFIX + name]
    sc = bpy.context.scene
    sc.frame_end = int(round(CLIPS[name][1] * ra.FPS))


def export_all(names=None, sample_fps=30):
    os.makedirs(SERVE, exist_ok=True)
    out = {}
    for name in (names or CLIPS):
        beats, length, loop, prio = CLIPS[name]
        use(name)
        out[name] = ra.export_json(os.path.join(SERVE, name + '.json'), name, length, loop, prio, sample_fps)
    return out


def review_camera(kind='threequarter'):
    rc = bpy.data.objects.get('ReviewCam')
    if not rc:
        rc = bpy.data.objects.new('ReviewCam', bpy.data.cameras.new('ReviewCam'))
        bpy.context.scene.collection.objects.link(rc)
    rc.data.type = 'PERSP'; rc.data.lens = 32; rc.data.sensor_fit = 'VERTICAL'; rc.data.sensor_height = 24
    target = Vector((0, 0, 2.2))
    d = {'front': Vector((0, -1, 0.05)), 'side': Vector((1, 0, 0.05))}.get(kind, Vector((0.64, -0.75, 0.16)))
    rc.location = target + d.normalized() * 9.5
    rc.rotation_mode = 'XYZ'
    rc.rotation_euler = (target - rc.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = rc
    return rc


def render_frames(name, times, folder, kind='threequarter', size=(300, 420), visible=None):
    """Render frames of a clip with only my character meshes visible; restores render flags after."""
    use(name)
    review_camera(kind)
    sc = bpy.context.scene
    prev = {o.name: o.hide_render for o in bpy.data.objects}
    prev_engine = sc.render.engine
    visible = visible or [o.name for o in bpy.data.objects if o.type == 'MESH' and o.name.endswith('_Geo')]
    try:
        for o in bpy.data.objects:
            if o.type in ('MESH', 'CURVE', 'FONT', 'META'):
                o.hide_render = o.name not in visible
                if o.name in visible:
                    o.color = (0.45, 0.65, 1.0, 1.0) if o.name.startswith('Left') else (0.85, 0.85, 0.85, 1.0)
        sc.render.engine = 'BLENDER_WORKBENCH'
        sc.render.resolution_x, sc.render.resolution_y = size
        sc.render.resolution_percentage = 100
        sc.render.image_settings.file_format = 'PNG'
        sc.display.shading.light = 'STUDIO'
        sc.display.shading.color_type = 'OBJECT'
        sc.display.shading.show_shadows = False
        sc.display.shading.show_cavity = True
        os.makedirs(folder, exist_ok=True)
        paths = []
        for t in times:
            f = t * ra.FPS
            sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
            p = os.path.join(folder, f'{name}_{kind}_{t:.2f}.png')
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            paths.append(p)
    finally:
        for o in bpy.data.objects:
            if o.name in prev:
                o.hide_render = prev[o.name]
        sc.render.engine = prev_engine
    return paths
