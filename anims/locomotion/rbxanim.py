"""Blender-side helpers: pose the Roblox R15 FBX armature using Roblox joint conventions,
key it into Actions, and export Motor6D transforms.

Roblox joint-space conventions (same as anims/hammerswing.py): character +X right, +Y up,
-Z forward. shoulder +X = arm swings up through the front, +Z = abduct (right arm out to the
right, so the left arm uses -Z); elbow +X = flexion; waist/neck +X = arch back, -X = fold
forward, +Y = turn left; hip +X = leg forward; knee -X = flexion; ankle +X = toes up.

The armature's rest bone axes are all identity (armature-local), 1 unit = 1 stud, and every
bone head sits on its Motor6D pivot, so a Roblox transform maps to bone-local space through
the fixed change of basis M = diag(-1, 1, -1) (a 180 degree turn about Y).
"""
import bpy, math, json
from mathutils import Matrix, Vector, Quaternion

ARM = bpy.data.objects['Armature']
FPS = 60
JOINTS = ["LowerTorso", "UpperTorso", "Head",
          "LeftUpperArm", "LeftLowerArm", "LeftHand",
          "RightUpperArm", "RightLowerArm", "RightHand",
          "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
          "RightUpperLeg", "RightLowerLeg", "RightFoot"]
PARENT = {"LowerTorso": "HumanoidRootNode", "UpperTorso": "LowerTorso", "Head": "UpperTorso",
          "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
          "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
          "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
          "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg"}
M = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, -1)))

_last_q = {}


def rbx_rot(rx, ry, rz):
    """Roblox CFrame.Angles(x, y, z) == Rx * Ry * Rz (degrees in)."""
    return (Matrix.Rotation(math.radians(rx), 3, 'X') @
            Matrix.Rotation(math.radians(ry), 3, 'Y') @
            Matrix.Rotation(math.radians(rz), 3, 'Z'))


def set_action(name, reset=True):
    ad = ARM.animation_data or ARM.animation_data_create()
    act = bpy.data.actions.get(name)
    if act and reset:
        bpy.data.actions.remove(act)
        act = None
    if not act:
        act = bpy.data.actions.new(name)
    ad.action = act
    if not ad.action_slot:
        slot = act.slots[0] if len(act.slots) else act.slots.new('OBJECT', 'Armature')
        ad.action_slot = slot
    _last_q.clear()
    return act


def apply_pose(pose):
    """pose: {joint: (rx, ry, rz[, px, py, pz])}; joints left out go to rest."""
    for j in JOINTS:
        pb = ARM.pose.bones[j]
        vals = pose.get(j, (0, 0, 0))
        q = (M @ rbx_rot(*vals[:3]) @ M).to_quaternion()
        prev = _last_q.get(j)
        if prev is not None and prev.dot(q) < 0:
            q = -q
        _last_q[j] = q.copy()
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = q
        pb.location = (M @ Vector(vals[3:6])) if len(vals) == 6 else Vector((0, 0, 0))


def key_pose(t, pose, interp=None):
    """Key a full pose at time t (seconds). interp: None (bezier auto-clamped) or 'LINEAR'."""
    frame = t * FPS
    apply_pose(pose)
    for j in JOINTS:
        pb = ARM.pose.bones[j]
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('location', frame=frame)
    if interp:
        for fc in _fcurves():
            for kp in fc.keyframe_points:
                if abs(kp.co[0] - frame) < 1e-3:
                    kp.interpolation = interp


def _fcurves():
    act = ARM.animation_data.action
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                for fc in cb.fcurves:
                    yield fc


def finalize(smooth=True):
    for fc in _fcurves():
        for kp in fc.keyframe_points:
            if smooth and kp.interpolation == 'BEZIER':
                kp.handle_left_type = 'AUTO_CLAMPED'
                kp.handle_right_type = 'AUTO_CLAMPED'
        fc.update()


def joint_transform(j):
    """Motor6D Transform for joint j at the current evaluated pose, in Roblox axes."""
    pb = ARM.pose.bones[j]
    pp = ARM.pose.bones[PARENT[j]]
    Rp = pp.matrix.to_3x3()
    Rb = pb.matrix.to_3x3()
    child_pos = pb.matrix.translation
    parent_carried = pp.matrix @ (pp.bone.matrix_local.inverted() @ pb.bone.head_local)
    T_rot = Rp.transposed() @ Rb
    T_pos = Rp.transposed() @ (child_pos - parent_carried)
    return (M @ T_rot @ M), (M @ T_pos)


def sample(t_end, sample_fps=30):
    """Sample the active action from 0..t_end at sample_fps. Returns list of (t, {j: [px,py,pz,qx,qy,qz,qw]})."""
    sc = bpy.context.scene
    n = int(round(t_end * sample_fps))
    frames = []
    for i in range(n + 1):
        t = i / sample_fps
        f = t * FPS
        sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        row = {}
        for j in JOINTS:
            R, p = joint_transform(j)
            q = R.to_quaternion()
            row[j] = [round(p.x, 4), round(p.y, 4), round(p.z, 4), round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)]
        frames.append((round(t, 4), row))
    return frames


def export_json(path, name, t_end, loop, priority, sample_fps=30):
    data = {"name": name, "loop": loop, "priority": priority, "fps": sample_fps,
            "joints": JOINTS, "frames": sample(t_end, sample_fps)}
    with open(path, 'w') as fh:
        json.dump(data, fh)
    return len(data["frames"])


def setup_scene():
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.render.fps_base = 1.0
    sc.frame_start = 0
