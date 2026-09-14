"""Idle and run design variants on the jelly engine, with per-frame foot grounding.

Grounding uses the blob character's measured leg chain (hip pivot 0.376 above the root
pivot, thigh 0.63, shin 0.70, sole 0.31 below the ankle, floor 1.203 below the root
pivot): while a foot is planted its knee bends until the sole meets the floor, or if a
straight leg cannot reach (body stretched up) the shin slides down so the sole stays on
the floor, and the foot is flattened. Idles keep both feet planted; gaits plant each foot
inside a raised-cosine stance window centred on mid-stance.
"""
import bpy, math, sys, os, json
from mathutils import Vector
ra = sys.modules['rbxanim_c9']
clips = sys.modules['clips_c9']
J = sys.modules['jelly_c9']
H, K, KC, with_left, CH = J.H, J.K, J.KC, J.with_left, J.CH

FLOOR = -1.203
MAX_STRETCH = 0.40


def _leg(side):
    s = 1 if side == 'Right' else -1
    return (Vector((s * 0.706, 0.376, 0.0)), Vector((s * 0.244, -0.579, 0.0)),
            Vector((s * -0.160, -0.686, 0.0)), Vector((0.0, -0.314, 0.0)))


def rot(v):
    return ra.rbx_rot(v[0], v[1], v[2])


def sole_y(pose, side):
    hip, thigh, shin, foot = _leg(side)
    lt = pose['LowerTorso']; ul = pose[side + 'UpperLeg']; ll = pose[side + 'LowerLeg']; ft = pose[side + 'Foot']
    R0 = rot(lt); p0 = Vector(lt[3:6])
    Rh = R0 @ rot(ul)
    knee = p0 + R0 @ (hip + Vector(ul[3:6])) + Rh @ thigh
    Rk = Rh @ rot(ll)
    ankle = knee + Rh @ Vector(ll[3:6]) + Rk @ shin
    Rf = Rk @ rot(ft)
    sole = ankle + Rk @ Vector(ft[3:6]) + Rf @ foot
    return sole.y - FLOOR


def ground_side(pose, side, w):
    """Blend the planted solution for one leg into pose by weight w."""
    if w <= 1e-3:
        return
    ll = list(pose[side + 'LowerLeg']); ft = list(pose[side + 'Foot'])
    free_k, free_py, free_fx = ll[0], ll[4], ft[0]
    # straight the knee first, then bend until the sole reaches the floor
    trial = dict(pose)
    trial[side + 'LowerLeg'] = (0.0, ll[1], ll[2], ll[3], ll[4], ll[5])
    h = sole_y(trial, side)
    knee = 0.0
    stretch = 0.0
    if h < 0:
        lo, hi = -150.0, 0.0
        for _ in range(40):
            mid = (lo + hi) / 2
            trial[side + 'LowerLeg'] = (mid, ll[1], ll[2], ll[3], ll[4], ll[5])
            if sole_y(trial, side) < 0:
                hi = mid
            else:
                lo = mid
        knee = (lo + hi) / 2
    else:
        stretch = min(MAX_STRETCH, h)
    flat = -(pose['LowerTorso'][0] + pose[side + 'UpperLeg'][0] + knee)
    pose[side + 'LowerLeg'] = (free_k * (1 - w) + knee * w, ll[1], ll[2], ll[3], free_py * (1 - w) + (ll[4] - stretch) * w, ll[5])
    pose[side + 'Foot'] = (free_fx * (1 - w) + flat * w, ft[1], ft[2], ft[3], ft[4], ft[5])


def window(t, T, centre, width):
    """Raised-cosine stance window (1 at centre, 0 outside centre +- width/2), periodic."""
    d = ((t / T - centre + 0.5) % 1.0) - 0.5
    x = abs(d) / (width / 2)
    return 0.0 if x >= 1 else 0.5 * (1 + math.cos(math.pi * x))


def ground_idle(pose, t, T):
    J.knees(pose)
    ground_side(pose, 'Right', 1.0)
    ground_side(pose, 'Left', 1.0)
    return pose


def make_ground_gait(centre_right=0.5, width=0.55):
    def f(pose, t, T):
        J.knees(pose)
        ground_side(pose, 'Right', window(t, T, centre_right, width))
        ground_side(pose, 'Left', window(t, T, centre_right + 0.5, width))
        return pose
    return f


def ground_walk(pose, t, T):
    """A walk always has its lower foot on the floor: plant whichever free sole is lower,
    and the other one too when it is already near the ground."""
    J.knees(pose)
    hr, hl = sole_y(pose, 'Right'), sole_y(pose, 'Left')
    low, high = ('Right', 'Left') if hr <= hl else ('Left', 'Right')
    ground_side(pose, low, 1.0)
    other = hl if low == 'Right' else hr
    if other < 0.12:
        ground_side(pose, high, 1.0 - other / 0.12)
    return pose


def bake(name, spec, T, loop, post):
    n = int(round(T * J.FPS))
    ra.set_action(clips.PREFIX + name)
    frames = []
    for i in range(n + 1):
        t = i / J.FPS
        pose = {}
        for j in ra.JOINTS:
            s = spec.get(j, {})
            pose[j] = tuple(s[c](t, T, loop) if c in s else 0.0 for c in CH)
        pose = post(pose, t, T)
        frames.append((round(t, 5), pose))
        ra.key_pose(t, pose)
    ra.finalize(smooth=False)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, n
    J.RAW[name] = frames
    clips.CLIPS[name] = (None, T, loop, 'Core')
    with open(os.path.join(J.HERE, f'raw_{name}.json'), 'w') as fh:
        json.dump({'T': T, 'loop': loop, 'frames': frames}, fh)
    return n + 1


# ====================================================================== IDLE VARIANTS
def idle_A():
    """Jellyfish pulse over a side sway (the previous idle), now grounded."""
    return J.idle_spec(), 4.0


def idle_B():
    """Bob and look: one slow vertical bob per 2 s, head does a lazy left/right look with
    tilt, arms hang and only the hands flop; barely any sway."""
    T = 4.0
    R = {
        'LowerTorso': {'py': H(-0.08, (2, 0.10, 0.5)), 'rx': H(2, (2, 3, 0.55)), 'px': H(0, (1, 0.04, 0.0)), 'ry': H(0, (1, 4, 0.1))},
        'UpperTorso': {'rx': H(0, (2, 5, 0.6)), 'ry': H(0, (1, 8, 0.2)), 'rz': H(0, (1, 3, 0.4))},
        'Head': {'ry': H(0, (1, 34, 0.3)), 'rz': H(0, (1, 12, 0.55)), 'rx': H(-4, (2, 7, 0.78), (6, 1.2, 0.0))},
        'RightUpperArm': {'rz': H(9, (2, 4, 0.6)), 'rx': H(-2, (2, 5, 0.75), (1, 4, 0.2)), 'ry': H(0, (1, 6, 0.3)), 'py': H(0, (2, 0.03, 0.6))},
        'RightLowerArm': {'rx': H(8, (2, 10, 0.9), (1, 6, 0.1)), 'py': H(0, (2, 0.03, 0.95))},
        'RightHand': {'rx': H(-6, (2, 22, 1.05), (1, 10, 0.05), (6, 5, 0.2)), 'rz': H(-6, (2, 9, 1.0)), 'ry': H(0, (1, 6, 0.0))},
        'RightUpperLeg': {'rx': H(2, (2, 4, 0.5)), 'rz': H(2, (1, 2, 0.0)), 'py': H(-0.01, (2, 0.01, 0.5))},
        'RightLowerLeg': {'rx': H(-8, (2, 8, 0.5))},
        'RightFoot': {'rx': H(0, (2, 3, 0.8)), 'ry': H(4, (1, 3, 0.0))},
    }
    L = with_left(R, T, gait=False)
    L['LeftHand']['rx'] = H(-4, (2, 20, 1.1), (1, 9, 0.0), (6, 4, 0.5))
    return L, T


def idle_C():
    """Wobble: a lateral jelly wobble, torso and head swinging like a soft column with a
    faster ripple on top, arms swinging as pendulums, almost no vertical motion."""
    T = 3.0
    R = {
        'LowerTorso': {'px': H(0, (1, 0.14, 0.0), (3, 0.02, 0.1)), 'rz': H(0, (1, 6, 0.0), (3, 1.5, 0.1)), 'ry': H(0, (1, 8, 0.25)),
                       'py': H(-0.04, (2, 0.04, 0.5)), 'rx': H(1, (2, 2, 0.5))},
        'UpperTorso': {'rz': H(0, (1, 9, 0.12), (3, 2, 0.2)), 'ry': H(0, (1, 10, 0.35)), 'rx': H(0, (2, 3, 0.6))},
        'Head': {'rz': H(0, (1, 16, 0.24), (3, 3, 0.3)), 'ry': H(0, (1, 22, 0.45)), 'rx': H(-5, (2, 5, 0.7), (6, 1.5, 0.0))},
        'RightUpperArm': {'rz': H(11, (1, 12, 0.3), (3, 2, 0.35)), 'rx': H(-4, (1, 10, 0.15)), 'ry': H(0, (1, 8, 0.3)), 'pz': H(0, (1, 0.03, 0.15))},
        'RightLowerArm': {'rx': H(10, (1, 16, -0.05), (3, 3, 0.45)), 'py': H(0, (1, 0.04, 0.0))},
        'RightHand': {'rx': H(-4, (1, 26, -0.2), (3, 6, 0.5), (6, 4, 0.0)), 'rz': H(-8, (1, 16, -0.15)), 'ry': H(0, (1, 10, -0.2))},
        'RightUpperLeg': {'rz': H(3, (1, 5, 0.0)), 'rx': H(2, (2, 3, 0.5)), 'ry': H(-2, (1, 4, 0.0))},
        'RightLowerLeg': {'rx': H(-6, (2, 6, 0.5), (1, 8, 0.5))},
        'RightFoot': {'rx': H(0, (1, 6, 0.4)), 'ry': H(5, (1, 6, 0.2)), 'rz': H(0, (1, 4, 0.0))},
    }
    L = with_left(R, T, gait=False)
    L['LeftLowerLeg']['rx'] = H(-6, (2, 6, 0.5), (1, 8, 0.0))
    return L, T


def idle_D():
    """Deep breather: slow big inhale/exhale (one per 3 s) with the arms rising out and
    forward on the inhale, chest arching, head tilting back, then everything sagging."""
    T = 3.0
    R = {
        'LowerTorso': {'py': H(-0.10, (1, 0.14, 0.5)), 'rx': H(3, (1, 5, 0.5)), 'pz': H(0, (1, 0.05, 0.0)), 'rz': H(0, (1, 2, 0.2))},
        'UpperTorso': {'rx': H(-2, (1, 10, 0.05)), 'rz': H(0, (1, 3, 0.3)), 'ry': H(0, (1, 5, 0.1))},
        'Head': {'rx': H(-4, (1, 14, 0.12), (6, 1.2, 0.0)), 'rz': H(0, (1, 8, 0.35)), 'ry': H(0, (1, 12, 0.3))},
        'RightUpperArm': {'rz': H(14, (1, 14, 0.0)), 'rx': H(4, (1, 18, 0.05)), 'ry': H(0, (1, 6, 0.1)), 'py': H(0, (1, 0.05, 0.0)), 'pz': H(0, (1, 0.04, 0.0))},
        'RightLowerArm': {'rx': H(14, (1, 22, -0.12)), 'py': H(0, (1, 0.05, -0.1))},
        'RightHand': {'rx': H(-6, (1, 30, -0.25), (6, 4, 0.0)), 'rz': H(-8, (1, 12, -0.2)), 'ry': H(0, (1, 8, -0.2))},
        'RightUpperLeg': {'rx': H(3, (1, 5, 0.5)), 'rz': H(2, (1, 2, 0.0))},
        'RightLowerLeg': {'rx': H(-10, (1, 10, 0.5))},
        'RightFoot': {'rx': H(0, (1, 4, 0.7)), 'ry': H(5, (1, 3, 0.0))},
    }
    return with_left(R, T, gait=False), T


def idle_E():
    """Fidget: bouncing on the toes twice a second with tiny knee dips, arms doing little
    loose circles at the sides, head bobbing and glancing, weight shuffling."""
    T = 2.0
    R = {
        'LowerTorso': {'py': H(-0.10, (4, 0.07, 0.5)), 'px': H(0, (1, 0.06, 0.0)), 'rz': H(0, (1, 3, 0.0)), 'ry': H(0, (2, 4, 0.25)), 'rx': H(2, (4, 2, 0.6))},
        'UpperTorso': {'rx': H(0, (4, 3, 0.7)), 'ry': H(0, (2, 6, 0.35)), 'rz': H(0, (1, 4, 0.1))},
        'Head': {'rx': H(-5, (4, 5, 0.85), (8, 1.5, 0.0)), 'ry': H(0, (1, 18, 0.2)), 'rz': H(0, (2, 6, 0.5))},
        'RightUpperArm': {'rx': H(-8, (2, 14, 0.0)), 'rz': H(12, (2, 8, 0.25)), 'ry': H(0, (2, 8, 0.5)), 'py': H(0, (4, 0.03, 0.6))},
        'RightLowerArm': {'rx': H(24, (2, 18, -0.15), (4, 6, 0.8)), 'py': H(0, (4, 0.03, 0.9))},
        'RightHand': {'rx': H(-4, (2, 28, -0.3), (4, 10, 1.0), (8, 5, 0.0)), 'rz': H(-8, (2, 12, -0.25)), 'ry': H(0, (2, 8, -0.3))},
        'RightUpperLeg': {'rx': H(3, (4, 3, 0.5)), 'rz': H(3, (1, 3, 0.0)), 'ry': H(-2, (2, 3, 0.0))},
        'RightLowerLeg': {'rx': H(-6, (4, 6, 0.5), (1, 6, 0.5))},
        'RightFoot': {'rx': H(0, (4, 4, 0.8)), 'ry': H(4, (1, 4, 0.0))},
    }
    L = with_left(R, T, gait=True)
    L['LeftLowerLeg']['rx'] = H(-6, (4, 6, 0.5), (1, 6, 0.0))
    return L, T


# ====================================================================== RUN VARIANTS
def run_body(T, lean=-14, bounce=0.22, low=-0.30, hip_roll=12, twist=14, stride=48):
    """Shared torso, head and legs of the scurry."""
    R = {
        'LowerTorso': {'py': H(low, (2, bounce, 0.5)), 'px': H(0, (1, 0.10, 0.25)), 'pz': H(0.12, (2, 0.10, 0.3)),
                       'rx': H(-6, (2, 6, 0.0)), 'rz': H(0, (1, hip_roll, 0.0)), 'ry': H(0, (1, 6, 0.25))},
        'UpperTorso': {'rx': H(lean, (2, 6, 0.4)), 'rz': H(0, (1, hip_roll * 0.8, 0.5)), 'ry': H(0, (1, twist, 0.0))},
        'Head': {'ry': H(0, (1, twist * 1.1, 0.5)), 'rx': H(6, (2, 10, 0.6), (4, 2.5, 0.0)), 'rz': H(0, (1, 6, 0.7))},
        'RightUpperLeg': {'rx': H(-4, (1, stride, 0.0)), 'ry': H(-6, (1, 10, 0.1)), 'rz': H(2, (1, 10, 0.0)),
                          'py': H(0.04, (1, 0.04, 0.2)), 'pz': H(-0.06, (1, 0.06, 0.5))},
        'RightLowerLeg': {'rx': H(-48, (1, 50, -0.22)), 'py': H(0.03, (1, 0.03, 0.0))},
        'RightFoot': {'rx': H(-4, (1, 20, -0.42), (2, 5, 0.0)), 'rz': H(2, (2, 6, 0.0)), 'ry': H(-2, (2, 5, 0.0))},
    }
    return R


def run_A():
    """Chugging pump: elbows tucked, upper arms driving with the stride, forearms and
    hands trailing and flopping, arms sliding fore and aft."""
    T = 0.7
    R = run_body(T)
    R['RightUpperArm'] = {'rx': H(-12, (1, 50, 0.0), (2, 5, 0.4)), 'rz': H(12, (2, 8, 0.3), (1, 5, 0.0)), 'ry': H(-4, (1, 10, 0.1)),
                          'pz': H(0.0, (1, 0.08, 0.0)), 'py': H(0.03, (2, 0.05, 0.5))}
    R['RightLowerArm'] = {'rx': H(72, (1, 30, -0.15), (2, 10, 0.6)), 'py': H(0, (2, 0.04, 0.7)), 'pz': H(0, (1, 0.03, -0.15))}
    R['RightHand'] = {'rx': H(-6, (1, 36, -0.32), (2, 10, 0.8), (4, 6, 0.0)), 'rz': H(-8, (1, 14, -0.3)), 'ry': H(0, (1, 12, -0.3))}
    return with_left(R, T, gait=True), T


def run_B():
    """Propeller: each arm windmills a full circle per stride (opposite phases), elbows
    nearly straight, hands whipping at the end of the arm."""
    T = 0.7
    R = run_body(T, lean=-16, bounce=0.20)
    R['RightUpperArm'] = {'rx': KC((0, 0), (0.7, 360)), 'rz': H(18, (2, 6, 0.3)), 'ry': H(0, (1, 8, 0.1)), 'py': H(0.02, (2, 0.04, 0.5))}
    R['RightUpperArm']['rx'] = J.Ch([lambda t, T_, loop: 360.0 * ((t / T_) % 1.0)])
    R['RightLowerArm'] = {'rx': H(14, (1, 14, -0.2), (2, 6, 0.6)), 'py': H(0, (1, 0.06, -0.25))}
    R['RightHand'] = {'rx': H(0, (1, 40, -0.35), (2, 8, 0.8), (4, 5, 0.0)), 'rz': H(-6, (1, 12, -0.3)), 'ry': H(0, (1, 10, -0.3))}
    return with_left(R, T, gait=True), T


def run_C():
    """Airplane: arms out low to the sides like wings, banking with the hip roll and
    flapping with each step, forearms and hands trailing the flap."""
    T = 0.7
    R = run_body(T, lean=-12, bounce=0.24, hip_roll=14)
    R['RightUpperArm'] = {'rz': H(70, (1, 14, 0.15), (2, 10, 0.3)), 'rx': H(-6, (1, 16, 0.0)), 'ry': H(0, (1, 8, 0.1)),
                          'py': H(0.02, (2, 0.04, 0.5)), 'px': H(0, (1, 0.04, 0.15))}
    R['RightLowerArm'] = {'rx': H(8, (2, 12, 0.55), (1, 8, -0.15)), 'py': H(0, (2, 0.04, 0.7))}
    R['RightHand'] = {'rx': H(-4, (2, 20, 0.75), (1, 18, -0.3), (4, 5, 0.0)), 'rz': H(-12, (2, 16, 0.5), (1, 8, -0.3)), 'ry': H(0, (1, 8, -0.3))}
    return with_left(R, T, gait=True), T


def run_D():
    """Sprinter: deep lean, head down, long straight-ish arm swings far back and forward,
    hands trailing, everything stretched along the direction of travel."""
    T = 0.68
    R = run_body(T, lean=-24, bounce=0.18, low=-0.34, hip_roll=10, twist=18, stride=52)
    R['Head'] = {'ry': H(0, (1, 18, 0.5)), 'rx': H(12, (2, 8, 0.6), (4, 2, 0.0)), 'rz': H(0, (1, 5, 0.7))}
    R['RightUpperArm'] = {'rx': H(-20, (1, 70, 0.0), (2, 4, 0.4)), 'rz': H(8, (2, 6, 0.3)), 'ry': H(-6, (1, 8, 0.1)),
                          'pz': H(0.0, (1, 0.10, 0.0)), 'py': H(0.02, (2, 0.04, 0.5))}
    R['RightLowerArm'] = {'rx': H(36, (1, 26, -0.15), (2, 8, 0.6)), 'py': H(0, (1, 0.05, -0.2))}
    R['RightHand'] = {'rx': H(-4, (1, 40, -0.32), (2, 8, 0.8), (4, 5, 0.0)), 'rz': H(-6, (1, 12, -0.3)), 'ry': H(0, (1, 10, -0.3))}
    return with_left(R, T, gait=True), T


def run_E():
    """Bounding skip: one big hop per stride instead of two small ones, both arms swinging
    together (forward on the hop, back on the landing), head bobbing with the hop."""
    T = 0.72
    R = run_body(T, lean=-10, bounce=0.0, low=-0.18, hip_roll=10, twist=10)
    R['LowerTorso']['py'] = H(-0.18, (1, 0.26, 0.55))
    R['LowerTorso']['rx'] = H(-4, (1, 8, 0.05))
    R['UpperTorso']['rx'] = H(-10, (1, 8, 0.45))
    R['Head']['rx'] = H(4, (1, 12, 0.65), (4, 2, 0.0))
    arms = {'rx': H(10, (1, 46, 0.1), (2, 4, 0.4)), 'rz': H(16, (1, 8, 0.35)), 'ry': H(0, (1, 6, 0.1)), 'pz': H(0.0, (1, 0.07, 0.1)), 'py': H(0.02, (1, 0.05, 0.55))}
    R['RightUpperArm'] = arms
    R['RightLowerArm'] = {'rx': H(30, (1, 28, -0.1), (2, 6, 0.6)), 'py': H(0, (1, 0.04, -0.15))}
    R['RightHand'] = {'rx': H(-6, (1, 36, -0.28), (2, 8, 0.8), (4, 5, 0.0)), 'rz': H(-8, (1, 12, -0.25)), 'ry': H(0, (1, 8, -0.3))}
    L = with_left(R, T, gait=True)
    # arms move together: the left arm copies the right without the half-cycle gait shift
    L['LeftUpperArm'] = J.mirror_joint(R['RightUpperArm'], T, gait=False)
    L['LeftLowerArm'] = J.mirror_joint(R['RightLowerArm'], T, gait=False)
    L['LeftHand'] = J.mirror_joint(R['RightHand'], T, gait=False)
    return L, T


def idle2_on(base_fn, T2=8.0):
    """The alt idle: the chosen idle keeps running underneath (whole cycles of T2) with the
    windmill/arch/settle event from jelly.idle2_spec layered on top."""
    base, Tb = base_fn()
    assert abs(T2 / Tb - round(T2 / Tb)) < 1e-9, "alt idle length must be a whole number of base cycles"

    def retime(ch):
        return J.Ch([lambda t, T, loop, f=f: f(t, Tb, True) for f in ch.fs])
    spec = {j: {c: retime(ch) for c, ch in s.items()} for j, s in base.items()}
    for j, s in J.idle2_event().items():
        spec.setdefault(j, {})
        for c, ch in s.items():
            spec[j][c] = spec[j][c] + ch if c in spec[j] else ch
    return spec, T2


def idle2_E():
    return idle2_on(idle_E)


IDLES = {'Idle_A': idle_A, 'Idle_B': idle_B, 'Idle_C': idle_C, 'Idle_D': idle_D, 'Idle_E': idle_E}
RUNS = {'Run_A': run_A, 'Run_B': run_B, 'Run_C': run_C, 'Run_D': run_D, 'Run_E': run_E}
GAIT_GROUND = make_ground_gait(centre_right=0.5, width=0.55)


def build_variants():
    out = {}
    for name, fn in IDLES.items():
        spec, T = fn()
        out[name] = bake(name, spec, T, True, ground_idle)
    for name, fn in RUNS.items():
        spec, T = fn()
        out[name] = bake(name, spec, T, True, GAIT_GROUND)
    # grounded walk and grounded copies of the A picks under the Animate names
    spec_w = J.walk_spec()
    out['Walk'] = bake('Walk', spec_w, J.T_WALK, True, GAIT_GROUND)
    spec, T = idle_A(); out['Idle'] = bake('Idle', spec, T, True, ground_idle)
    spec, T = run_A(); out['Run'] = bake('Run', spec, T, True, GAIT_GROUND)
    spec = J.idle2_spec(); out['Idle2'] = bake('Idle2', spec, J.T_IDLE2, True, ground_idle)
    return out
