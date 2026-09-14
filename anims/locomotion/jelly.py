"""Jelly locomotion set, built the way the Boneless reference curves are built.

Review of the reference (current_anims.rbxmx, decoded): every channel is a broad, smooth
sine-like wave with one or two cycles per loop; motion rolls through the body with roughly
a quarter-cycle phase lag per link (shoulder -> elbow -> hand, hip -> knee -> foot) and the
amplitude GROWS toward the extremities (idle: elbows +-31 deg, hands +-39 deg); the head
yaw runs in anti-phase to the torso twist and the head tilt is a large wave of its own;
knees are clipped at 0 into plateaus; joints also translate (leg/arm slides of 0.2-0.4
studs, body bobs of 0.3-0.4); the one-shot jump is a chain of S-curves with a single
overshoot each. So each channel here is authored directly as harmonics (mean + sines with
per-joint phase) or loop-aware Catmull keypoints, then evaluated on every frame at 60 fps.
Poses use Roblox joint conventions (rbxanim.py).
"""
import bpy, math, sys, os, json
ra = sys.modules['rbxanim_c9']
clips = sys.modules['clips_c9']

FPS = 60
CH = ('rx', 'ry', 'rz', 'px', 'py', 'pz')
SIGN = {'rx': 1, 'ry': -1, 'rz': -1, 'px': -1, 'py': 1, 'pz': 1}  # left/right mirror
HERE = os.path.dirname(os.path.abspath(__file__))


# ----------------------------------------------------------------- channel expressions
class Ch:
    def __init__(self, fs):
        self.fs = list(fs)

    def __call__(self, t, T, loop):
        return sum(f(t, T, loop) for f in self.fs)

    def __add__(self, other):
        return Ch(self.fs + other.fs)


def H(mean=0.0, *harm):
    """mean + sum of amp*sin(2pi*(cycles*t/T + phase)), phase in cycle fractions."""
    def f(t, T, loop):
        v = mean
        for k, a, ph in harm:
            v += a * math.sin(2 * math.pi * (k * t / T + ph))
        return v
    return Ch([f])


def _catmull1(pts, t, T, loop):
    if loop:
        t = t % T
        ext = [(p[0] - T, p[1]) for p in pts] + list(pts) + [(p[0] + T, p[1]) for p in pts]
    else:
        ext = list(pts)
        if t <= ext[0][0]:
            return ext[0][1]
        if t >= ext[-1][0]:
            return ext[-1][1]
    n = len(ext)
    for i in range(n - 1):
        if ext[i][0] <= t <= ext[i + 1][0]:
            i0, i3 = max(i - 1, 0), min(i + 2, n - 1)
            (ta, p0), (tb, p1), (tc, p2), (td, p3) = ext[i0], ext[i], ext[i + 1], ext[i3]
            break
    else:
        return ext[-1][1]
    h = tc - tb
    s = (t - tb) / h if h > 0 else 0.0
    m1 = (p2 - p0) / max(1e-6, tc - ta) * h
    m2 = (p3 - p1) / max(1e-6, td - tb) * h
    s2, s3 = s * s, s * s * s
    return (2 * s3 - 3 * s2 + 1) * p1 + (s3 - 2 * s2 + s) * m1 + (-2 * s3 + 3 * s2) * p2 + (s3 - s2) * m2


def K(*pts):
    """Catmull-Rom through (t, v) keypoints (loop-aware when the clip loops)."""
    pts = sorted(pts)
    return Ch([lambda t, T, loop: _catmull1(pts, t, T, loop)])


def KC(*pts):
    """Clamped Catmull-Rom (never wraps): holds the first value before the first keypoint and
    the last value after the last one. Use for windmills that end on a multiple of 360."""
    pts = sorted(pts)
    return Ch([lambda t, T, loop: _catmull1(pts, t % T if loop else t, T, False)])


def shift(ch, dt):
    return Ch([lambda t, T, loop, f=f: f(t + dt, T, loop) for f in ch.fs])


def scale(ch, k):
    return Ch([lambda t, T, loop, f=f: k * f(t, T, loop) for f in ch.fs])


def mirror_joint(spec, T=None, gait=False):
    """Left-side channels from right-side ones: flip Y/Z rotations and X position; a gait
    mirror also shifts by half a cycle."""
    out = {}
    for c, ch in spec.items():
        m = scale(ch, SIGN[c])
        out[c] = shift(m, T / 2) if gait else m
    return out


def with_left(right_specs, T=None, gait=False):
    """right_specs: {'RightUpperArm': {...}, ...} -> adds the Left* joints."""
    out = dict(right_specs)
    for j, spec in right_specs.items():
        if j.startswith('Right'):
            out['Left' + j[5:]] = mirror_joint(spec, T, gait)
    return out


def knees(pose):
    for j in ('RightLowerLeg', 'LeftLowerLeg'):
        v = pose[j]
        pose[j] = (min(0.0, v[0]),) + tuple(v[1:])
    return pose


# ----------------------------------------------------------------- bake
RAW = {}


def bake(name, spec, T, loop, post=knees, priority='Core'):
    n = int(round(T * FPS))
    ra.set_action(clips.PREFIX + name)
    frames = []
    for i in range(n + 1):
        t = i / FPS
        pose = {}
        for j in ra.JOINTS:
            s = spec.get(j, {})
            pose[j] = tuple(s[c](t, T, loop) if c in s else 0.0 for c in CH)
        if post:
            pose = post(pose)
        frames.append((round(t, 5), pose))
        ra.key_pose(t, pose)
    ra.finalize(smooth=False)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, n
    RAW[name] = frames
    clips.CLIPS[name] = (None, T, loop, priority)
    with open(os.path.join(HERE, f'raw_{name}.json'), 'w') as fh:
        json.dump({'T': T, 'loop': loop, 'frames': frames}, fh)
    return n + 1


def at0(spec, T, loop):
    """Values of every channel at t=0 (used to end the jump on the fall's first frame)."""
    return {j: {c: ch(0.0, T, loop) for c, ch in s.items()} for j, s in spec.items()}


# ================================================================= IDLE (4.0 s loop)
# Jellyfish pulse, not a twist: the body squashes and stretches twice per loop while it
# sways side to side once; the arms float outward on every squash and swing like
# pendulums with the sway, the head bobs and tilts a beat behind the body, the knee on
# the unloaded side softens as the weight shifts, and a faint fast ripple lives in the
# head and hands.
T_IDLE = 4.0


def idle_spec():
    R = {
        'LowerTorso': {'py': H(-0.03, (2, 0.15, 0.5)), 'px': H(0, (1, 0.12, 0.0)), 'pz': H(0, (2, 0.03, 0.75)),
                       'rz': H(0, (1, 4, 0.0)), 'ry': H(0, (1, 5, 0.25)), 'rx': H(2, (2, 3, 0.5))},
        'UpperTorso': {'rx': H(1, (2, 7, 0.55)), 'rz': H(0, (1, 7, 0.56)), 'ry': H(0, (1, 9, 0.3))},
        'Head': {'rx': H(-6, (2, 10, 0.72), (6, 1.5, 0.0)), 'rz': H(0, (1, 14, 0.25)), 'ry': H(0, (1, 26, 0.12))},
        'RightUpperArm': {'rz': H(14, (2, 10, 0.5), (1, 9, 0.2)), 'rx': H(-6, (2, 8, 0.7), (1, 6, 0.0)), 'ry': H(0, (1, 10, 0.1)),
                          'py': H(0, (2, 0.05, 0.5)), 'pz': H(0.02, (2, 0.03, 0.5))},
        'RightLowerArm': {'rx': H(12, (2, 16, 0.85), (1, 10, -0.05)), 'py': H(0, (2, 0.04, 0.9))},
        'RightHand': {'rx': H(-4, (2, 24, 1.0), (1, 16, -0.15), (6, 5, 0.0)), 'rz': H(-8, (1, 14, -0.1), (2, 8, 1.0)), 'ry': H(-3, (1, 8, -0.15))},
        'RightUpperLeg': {'rx': H(3, (2, 7, 0.45)), 'rz': H(3, (1, 5, 0.0)), 'ry': H(-3, (1, 5, 0.0)), 'py': H(-0.02, (2, 0.02, 0.5))},
        'RightLowerLeg': {'rx': H(-14, (2, 14, 0.5), (1, 10, 0.5)), 'py': H(0.03, (2, 0.05, 0.5))},
        'RightFoot': {'rx': H(3, (2, 6, 0.8), (1, 10, 0.5)), 'ry': H(6, (1, 8, 0.2)), 'rz': H(0, (1, 4, 0.0))},
    }
    L = with_left(R, T_IDLE, gait=False)
    # asymmetry: the left side is a little lazier and its knee softens on the other half of the sway
    L['LeftUpperArm']['rz'] = H(-12, (2, 11, 0.52), (1, -8, 0.2))
    L['LeftLowerArm']['rx'] = H(10, (2, 14, 0.9), (1, 9, -0.02))
    L['LeftHand']['rx'] = H(-2, (2, 22, 1.03), (1, 14, -0.12), (6, 4, 0.3))
    L['LeftLowerLeg']['rx'] = H(-14, (2, 14, 0.5), (1, 10, 0.0))
    L['LeftFoot']['rx'] = H(3, (2, 6, 0.8), (1, 10, 0.0))
    return L


# ================================================================= IDLE2 (8.0 s loop)
# The idle pulse keeps running underneath (two cycles); on top, a double arm windmill with
# the elbows and hands flailing, the torso arching back and bobbing, then everything
# settles for the second half.
T_IDLE2 = 8.0


def idle2_event():
    """Windmill, arch and settle layer of the alt idle, independent of the idle underneath."""
    return {
        'RightUpperArm': {'rx': KC((1.4, 0), (1.9, 90), (2.4, 330), (2.9, 560), (3.4, 720), (4.1, 720), (4.7, 720)),
                          'rz': K((1.4, 0), (2.2, 10), (3.4, 6), (4.4, 0)), 'px': K((1.4, 0), (2.6, -0.3), (3.4, -0.35), (4.4, 0))},
        'RightLowerArm': {'rx': K((1.4, 0), (2.0, 55), (2.5, -60), (3.0, 60), (3.5, -55), (4.0, 30), (4.6, 0)),
                          'py': K((1.4, 0), (2.2, -0.08), (2.7, 0.08), (3.2, -0.08), (3.7, 0.06), (4.4, 0))},
        'RightHand': {'rx': K((1.5, 0), (2.15, 45), (2.65, -50), (3.15, 50), (3.65, -45), (4.15, 25), (4.7, 0)),
                      'rz': K((1.5, 0), (2.3, -25), (3.0, 20), (3.7, -15), (4.5, 0))},
        'LeftUpperArm': {'rx': KC((1.7, 0), (2.2, 90), (2.7, 330), (3.2, 560), (3.7, 720), (4.4, 720), (5.0, 720)),
                         'rz': K((1.7, 0), (2.5, -10), (3.7, -6), (4.7, 0)), 'px': K((1.7, 0), (2.9, 0.3), (3.7, 0.35), (4.7, 0))},
        'LeftLowerArm': {'rx': K((1.7, 0), (2.3, 55), (2.8, -60), (3.3, 60), (3.8, -55), (4.3, 30), (4.9, 0)),
                         'py': K((1.7, 0), (2.5, -0.08), (3.0, 0.08), (3.5, -0.08), (4.0, 0.06), (4.7, 0))},
        'LeftHand': {'rx': K((1.8, 0), (2.45, 45), (2.95, -50), (3.45, 50), (3.95, -45), (4.45, 25), (5.0, 0)),
                     'rz': K((1.8, 0), (2.6, 25), (3.3, -20), (4.0, 15), (4.8, 0))},
        'UpperTorso': {'rx': K((1.3, 0), (1.9, -10), (2.6, 12), (3.2, 18), (3.9, -6), (4.6, 0))},
        'LowerTorso': {'rx': K((1.3, 0), (2.0, -8), (2.8, 12), (3.6, 8), (4.4, 0)),
                       'py': K((1.3, 0), (1.9, -0.25), (2.5, 0.10), (3.1, -0.22), (3.7, 0.12), (4.3, -0.1), (4.9, 0)),
                       'pz': K((1.3, 0), (2.2, 0.15), (3.0, 0.45), (3.8, 0.3), (4.6, 0))},
        'Head': {'rx': K((1.3, 0), (1.9, -11), (2.7, 10), (3.4, 12), (4.1, -6), (4.8, 0))},
        'RightUpperLeg': {'rx': K((1.3, 0), (2.0, 14), (2.8, 30), (3.6, 20), (4.4, 0)), 'py': K((1.3, 0), (2.6, -0.1), (3.8, -0.06), (4.6, 0))},
        'LeftUpperLeg': {'rx': K((1.3, 0), (2.1, 10), (2.9, 24), (3.7, 16), (4.5, 0)), 'py': K((1.3, 0), (2.7, -0.08), (3.9, -0.05), (4.7, 0))},
        'RightLowerLeg': {'rx': K((1.3, 0), (2.2, -25), (3.0, -40), (3.8, -20), (4.5, 0))},
        'LeftLowerLeg': {'rx': K((1.3, 0), (2.3, -20), (3.1, -35), (3.9, -18), (4.6, 0))},
    }


def idle2_spec():
    base = idle_spec()
    # re-time the idle harmonics to 4 cycles of the 6 s loop (same 1.5 s period)
    def retime(ch):
        return Ch([lambda t, T, loop, f=f: f(t, T_IDLE, True) for f in ch.fs])
    spec = {j: {c: retime(ch) for c, ch in s.items()} for j, s in base.items()}
    ev = idle2_event()
    for j, s in ev.items():
        spec.setdefault(j, {})
        for c, ch in s.items():
            spec[j][c] = spec[j][c] + ch if c in spec[j] else ch
    return spec


# ================================================================= WALK (1.0 s loop)
# Penguin waddle: arms held out low and flapping with each step, elbows and hands
# trailing, hips rolling against the upper torso, body bobbing twice per stride, head
# rolling a beat behind.
T_WALK = 1.0


def walk_spec():
    R = {
        'LowerTorso': {'py': H(-0.22, (2, 0.12, 0.5)), 'pz': H(0.06, (2, 0.05, 0.3)), 'px': H(0, (1, 0.08, 0.25)),
                       'rz': H(0, (1, 9, 0.0)), 'rx': H(-3, (2, 4, 0.0)), 'ry': H(0, (1, 5, 0.25))},
        'UpperTorso': {'rz': H(0, (1, 8, 0.5)), 'ry': H(0, (1, 10, 0.0)), 'rx': H(4, (2, 3, 0.4))},
        'Head': {'rz': H(0, (1, 9, 0.7)), 'ry': H(0, (1, 12, 0.5)), 'rx': H(-8, (2, 6, 0.6), (6, 1.2, 0.0))},
        'RightUpperArm': {'rz': H(38, (2, 12, 0.3), (1, 6, 0.0)), 'rx': H(4, (1, 24, 0.1)), 'ry': H(0, (1, 10, 0.1)),
                          'py': H(0.02, (2, 0.04, 0.5)), 'pz': H(0, (1, 0.06, 0.1))},
        'RightLowerArm': {'rx': H(14, (1, 18, -0.12), (2, 8, 0.55)), 'py': H(0, (2, 0.03, 0.7))},
        'RightHand': {'rx': H(-4, (1, 26, -0.3), (2, 10, 0.75), (4, 4, 0.0)), 'rz': H(-12, (2, 12, 0.5)), 'ry': H(0, (1, 8, -0.3))},
        'RightUpperLeg': {'rx': H(0, (1, 40, 0.0)), 'ry': H(-6, (1, 8, 0.1)), 'rz': H(3, (1, 9, 0.0)), 'py': H(0.04, (1, 0.05, 0.2))},
        'RightLowerLeg': {'rx': H(-32, (1, 34, -0.22)), 'py': H(0.03, (2, 0.05, 0.2))},
        'RightFoot': {'rx': H(-6, (1, 20, -0.4), (2, 5, 0.0)), 'rz': H(2, (1, 8, 0.0)), 'ry': H(-2, (1, 6, 0.0)), 'py': H(-0.01, (2, 0.03, 0.2))},
    }
    return with_left(R, T_WALK, gait=True)


# ================================================================= RUN (0.7 s loop)
# Panicked blob scurry: arms held up like little wings and flapping alternately with
# loose elbows and flopping hands, a big bounce every step under a forward lean, hips
# rolling against the upper torso, torso twisting with the head swinging back the other
# way and bobbing a beat late, short quick strides with the legs sliding forward.
T_RUN = 0.7


def run_spec():
    R = {
        'LowerTorso': {'py': H(-0.22, (2, 0.22, 0.5)), 'px': H(0, (1, 0.10, 0.25)), 'pz': H(0.15, (2, 0.12, 0.3)),
                       'rx': H(-6, (2, 6, 0.0)), 'rz': H(0, (1, 12, 0.0)), 'ry': H(0, (1, 6, 0.25))},
        'UpperTorso': {'rx': H(-14, (2, 6, 0.4)), 'rz': H(0, (1, 10, 0.5)), 'ry': H(0, (1, 14, 0.0))},
        'Head': {'ry': H(0, (1, 16, 0.5)), 'rx': H(6, (2, 10, 0.6), (4, 2.5, 0.0)), 'rz': H(0, (1, 6, 0.7))},
        # chugging pump: elbows tucked, upper arms driving with the stride, forearms and hands
        # trailing further behind and flopping, arms sliding fore/aft as they pump
        'RightUpperArm': {'rx': H(-12, (1, 50, 0.0), (2, 5, 0.4)), 'rz': H(12, (2, 8, 0.3), (1, 5, 0.0)), 'ry': H(-4, (1, 10, 0.1)),
                          'pz': H(0.0, (1, 0.08, 0.0)), 'py': H(0.03, (2, 0.05, 0.5))},
        'RightLowerArm': {'rx': H(72, (1, 30, -0.15), (2, 10, 0.6)), 'py': H(0, (2, 0.04, 0.7)), 'pz': H(0, (1, 0.03, -0.15))},
        'RightHand': {'rx': H(-6, (1, 36, -0.32), (2, 10, 0.8), (4, 6, 0.0)), 'rz': H(-8, (1, 14, -0.3)), 'ry': H(0, (1, 12, -0.3))},
        'RightUpperLeg': {'rx': H(-4, (1, 50, 0.0)), 'ry': H(-6, (1, 10, 0.1)), 'rz': H(2, (1, 10, 0.0)),
                          'py': H(0.08, (1, 0.08, 0.2)), 'pz': H(-0.08, (1, 0.08, 0.5))},
        'RightLowerLeg': {'rx': H(-48, (1, 50, -0.22)), 'py': H(0.05, (1, 0.05, 0.0))},
        'RightFoot': {'rx': H(-4, (1, 20, -0.42), (2, 5, 0.0)), 'rz': H(2, (2, 6, 0.0)), 'ry': H(-2, (2, 5, 0.0))},
    }
    return with_left(R, T_RUN, gait=True)


# ================================================================= FALL (1.0 s loop)
# Every channel one broad wave: arms overhead behind the head swinging, elbows and
# hands trailing and growing, head thrown back, body pitched back and drifting, legs
# paddling out of phase.
T_FALL = 1.0


def fall_spec():
    R = {
        'LowerTorso': {'rx': H(20, (1, 5, 0.0)), 'rz': H(0, (1, 2, 0.5)), 'ry': H(-9, (1, 0.8, 0)),
                       'py': H(0.34, (1, 0.11, 0.5)), 'pz': H(-0.24, (1, 0.06, 0.0)), 'px': H(-0.16, (1, 0.02, 0.0))},
        'UpperTorso': {'rx': H(-6, (1, 2.3, 0.5)), 'rz': H(5.7, (1, 2.2, 0.5)), 'ry': H(3, (1, 1, 0.5))},
        'Head': {'rx': H(45, (1, 11, -0.15)), 'ry': H(6.5, (1, 2.7, 0.0)), 'rz': H(12, (1, 2.8, 0.0))},
        'RightUpperArm': {'rx': H(200, (1, 28, 0.25)), 'ry': H(11.5, (1, 9.5, 0.35)), 'rz': H(12, (1, 7, 0.3)),
                          'pz': H(0.20, (1, 0.07, 0.25)), 'py': H(0.22, (1, 0.02, 0.25))},
        'RightLowerArm': {'rx': H(-2, (1, 27, 0.0)), 'py': H(0, (1, 0.045, 0.0)), 'pz': H(0.005, (1, 0.005, 0))},
        'RightHand': {'rx': H(0.5, (1, 45.5, -0.16)), 'ry': H(26.5, (1, 14, -0.16)), 'rz': H(-3.5, (1, 12, -0.16))},
        'RightUpperLeg': {'rx': H(-2, (1, 8, 0.6)), 'ry': H(-11, (1, 8, 0.6)), 'rz': H(14.3, (1, 1.3, 0.6)), 'py': H(-0.08, (1, 0, 0)), 'px': H(0.02, (1, 0, 0))},
        'RightLowerLeg': {'rx': H(-43, (1, 16.5, 0.5)), 'py': H(0.085, (1, 0.025, 0.5)), 'pz': H(-0.03, (1, 0.02, 0.5))},
        'RightFoot': {'rx': H(-1, (1, 3.5, 0.5)), 'ry': H(-2, (1, 2.5, 0.5)), 'rz': H(2.4, (1, 2.9, 0.5)), 'py': H(0.02, (1, 0.01, 0.5))},
    }
    L = with_left(R, T_FALL, gait=False)
    # legs paddle out of phase and with different reach; left knee stays bent
    L['LeftUpperLeg'] = {'rx': H(-15, (1, 15, 0.2)), 'ry': H(12, (1, 6, 0.2)), 'rz': H(-20.5, (1, 4, 0.2))}
    L['LeftLowerLeg'] = {'rx': H(-74, (1, 3, 0.2)), 'py': H(0.12, (1, 0, 0)), 'pz': H(-0.075, (1, 0.005, 0.2))}
    L['LeftFoot'] = {'rx': H(5, (1, 18, 0.0)), 'ry': H(-10, (1, 3, 0.0)), 'rz': H(12.5, (1, 4, 0.0)), 'py': H(0.03, (1, 0, 0))}
    return L


# ================================================================= JUMP (1.0 s, once)
# Deep squash, then the body shoots up and pitches back, arms whip forward and over the
# head, legs snap out then tuck; every channel ends on the fall's first frame so the
# fall crossfade is invisible. S-curves with one overshoot each (Catmull keypoints).
T_JUMP = 1.0


def jump_spec():
    F = at0(fall_spec(), T_FALL, True)

    def end(j, c):
        return F.get(j, {}).get(c, 0.0)

    def kj(j, c, *pts):
        return K(*pts, (T_JUMP, end(j, c)))

    S = {
        'LowerTorso': {'py': kj('LowerTorso', 'py', (0, -0.80), (0.30, 0.90), (0.55, 0.60), (0.8, 0.38)),
                       'pz': kj('LowerTorso', 'pz', (0, -0.30), (0.25, 0.35), (0.55, -0.30), (0.8, -0.2)),
                       'px': kj('LowerTorso', 'px', (0, 0.0), (0.4, -0.15), (0.8, -0.14)),
                       'rx': kj('LowerTorso', 'rx', (0, -23), (0.12, -20), (0.35, 44), (0.6, 12), (0.8, 22)),
                       'ry': kj('LowerTorso', 'ry', (0, -6), (0.3, -20), (0.7, -8)),
                       'rz': kj('LowerTorso', 'rz', (0, 3), (0.3, -9), (0.65, 2))},
        'UpperTorso': {'rx': kj('UpperTorso', 'rx', (0, -28), (0.2, 27), (0.45, -29), (0.75, 2)),
                       'ry': kj('UpperTorso', 'ry', (0, 1), (0.35, 14), (0.7, 2)),
                       'rz': kj('UpperTorso', 'rz', (0, 2), (0.4, 12), (0.75, 4))},
        'Head': {'rx': kj('Head', 'rx', (0, -21), (0.15, -12), (0.4, 48), (0.7, 28)),
                 'ry': kj('Head', 'ry', (0, -1), (0.4, 7), (0.8, 5)),
                 'rz': kj('Head', 'rz', (0, -11), (0.35, 15), (0.7, 8))},
        'RightUpperArm': {'rx': kj('RightUpperArm', 'rx', (0, -40), (0.15, 15), (0.35, 150), (0.55, 222), (0.8, 205)),
                          'ry': kj('RightUpperArm', 'ry', (0, 5), (0.3, -49), (0.6, 4), (0.8, 12)),
                          'rz': kj('RightUpperArm', 'rz', (0, -13), (0.35, 6), (0.65, 22), (0.85, 14)),
                          'py': kj('RightUpperArm', 'py', (0, -0.15), (0.5, 0.22), (0.8, 0.22)),
                          'pz': kj('RightUpperArm', 'pz', (0, 0.18), (0.5, 0.25), (0.8, 0.22))},
        'RightLowerArm': {'rx': kj('RightLowerArm', 'rx', (0, 30), (0.2, 74), (0.45, -14), (0.7, -30)),
                          'py': kj('RightLowerArm', 'py', (0, -0.02), (0.3, 0.10), (0.7, 0.0))},
        'RightHand': {'rx': kj('RightHand', 'rx', (0, -30), (0.25, 41), (0.5, -37), (0.75, -20)),
                      'ry': kj('RightHand', 'ry', (0, -4), (0.35, 34), (0.7, 20)),
                      'rz': kj('RightHand', 'rz', (0, 1), (0.3, -36), (0.6, -5))},
        'RightUpperLeg': {'rx': kj('RightUpperLeg', 'rx', (0, 50), (0.15, -28), (0.4, 84), (0.7, 20)),
                          'ry': kj('RightUpperLeg', 'ry', (0, -3), (0.4, -10), (0.7, -8)),
                          'rz': kj('RightUpperLeg', 'rz', (0, -1), (0.3, 47), (0.7, 20))},
        'RightLowerLeg': {'rx': kj('RightLowerLeg', 'rx', (0, -100), (0.18, -28), (0.45, -100), (0.75, -50)),
                          'py': kj('RightLowerLeg', 'py', (0, 0.13), (0.3, 0.06), (0.7, 0.10)),
                          'pz': kj('RightLowerLeg', 'pz', (0, -0.11), (0.3, -0.01), (0.7, -0.05))},
        'RightFoot': {'rx': kj('RightFoot', 'rx', (0, 35), (0.2, -30), (0.5, 20), (0.8, 2)),
                      'ry': kj('RightFoot', 'ry', (0, 9), (0.4, -7), (0.8, 0)),
                      'rz': kj('RightFoot', 'rz', (0, -10), (0.4, 9), (0.8, 1))},
    }
    # left side: same beats, mirrored, with the left leg ending bent like the fall
    for j in list(S):
        if j.startswith('Right'):
            S['Left' + j[5:]] = mirror_joint(S[j])
    S['LeftUpperLeg'] = {'rx': kj('LeftUpperLeg', 'rx', (0, 45), (0.15, -25), (0.4, 95), (0.7, 5)),
                         'ry': kj('LeftUpperLeg', 'ry', (0, 2), (0.4, 31), (0.7, 16)),
                         'rz': kj('LeftUpperLeg', 'rz', (0, 5), (0.3, -32), (0.7, -22))}
    S['LeftLowerLeg'] = {'rx': kj('LeftLowerLeg', 'rx', (0, -80), (0.18, -16), (0.45, -95), (0.75, -78)),
                         'py': kj('LeftLowerLeg', 'py', (0, 0.12), (0.3, 0.03), (0.7, 0.1)),
                         'pz': kj('LeftLowerLeg', 'pz', (0, -0.08), (0.3, 0.0), (0.7, -0.06))}
    S['LeftFoot'] = {'rx': kj('LeftFoot', 'rx', (0, -12), (0.2, -34), (0.5, 10), (0.8, 8)),
                     'ry': kj('LeftFoot', 'ry', (0, -11), (0.4, 10), (0.8, -6)),
                     'rz': kj('LeftFoot', 'rz', (0, 13), (0.4, -12), (0.8, 10))}
    return S


CLIPS = {
    'Idle': (idle_spec, T_IDLE, True),
    'Idle2': (idle2_spec, T_IDLE2, True),
    'Walk': (walk_spec, T_WALK, True),
    'Run': (run_spec, T_RUN, True),
    'Jump': (jump_spec, T_JUMP, False),
    'Fall': (fall_spec, T_FALL, True),
}


def build_all(names=None):
    out = {}
    for name in (names or CLIPS):
        fn, T, loop = CLIPS[name]
        out[name] = bake(name, fn(), T, loop)
    return out
