"""Authors the hammer swing KeyframeSequences for the R15 rig and validates them.

Three variants share one strike skeleton and differ only in read: Chop is tight and
vertical, Haymaker is a wide rotational haymaker, Pogo hops into the slam. All three
put contact on the same frame and carry the same marker, so combat is untouched.

Two halves, authored differently on purpose:

  Strike (0 -> Absorb)  Hand-posed and sparsely keyed. Linear interpolation is correct
                        here: a hard corner between two extreme poses is a smear, which
                        is what sells the impact.

  Settle (Absorb -> end) Generated, not hand-posed. Every channel runs settle_curve from
                        the absorb pose to the ready pose: past the target exactly once,
                        then down onto it. Hand-authoring this half produced several
                        small opposing poses per channel, and under linear interpolation
                        each reversal reads as a shake rather than a settle. Joints are
                        staggered by DELAY so the hips lead and the hammer hand trails;
                        that overlap is what makes it read as fluid rather than uniform.

Because the settle is a baked curve sampled densely, every pose stays on Linear easing.
The clip therefore plays identically no matter which side of a segment the engine
applies a Pose's easing to, which is not otherwise pinned down.

Two things are solved rather than eyeballed: the wrist, so the hammer (which leaves the
fist along the hand's local -Z) points where each beat needs it, and the knees, so the
feet stay on the floor plane under the root's squash drop.

Conventions. R15 Motor6Ds are axis-aligned at rest, so a Pose CFrame is a pure local
rotation about the joint pivot. Character space: +X right, +Y up, -Z forward.
  shoulder +X = arm swings up through the front   shoulder +Z = arm abducts right
  elbow    +X = flexion                           wrist    +X = hammer tips up
  waist    +X = arch back, -X = fold forward      waist    +Y = twist left
  hip      +X = leg forward                       knee     -X = flexion

Beats, against Combat.Hammer: the swing input fires the 58 stud/s dash impulse at t=0,
ActiveDuration runs 0.18s, a miss then costs MissRecovery 0.5s plus a 0.25s stun, and
the next swing is gated by Cooldown 1.5s. Contact sits at 0.100s in every variant so the
visual bonk lands close to when the dash actually carries the player into 7-stud range.
"""

import math
import os

MARKER_TIME = 0.100
MARKER_NAME = "SwingHit"
SETTLE_SAMPLES = 22

# Fraction of the settle each joint waits before it starts moving. Hips lead, the
# hammer hand trails furthest; that stagger is the overlap that reads as follow-through.
DELAY = {
    "LowerTorso": 0.00, "RightUpperLeg": 0.02, "LeftUpperLeg": 0.02,
    "RightFoot": 0.03, "LeftFoot": 0.03, "UpperTorso": 0.06, "Head": 0.12,
    "LeftUpperArm": 0.08, "LeftLowerArm": 0.12, "LeftHand": 0.16,
    "RightUpperArm": 0.09, "RightLowerArm": 0.14, "RightHand": 0.19,
}
LERP_JOINTS = list(DELAY.keys())

# The knees are solved to hold the soles down, so they are a dependent channel: they
# track the root drop, the hip angle and the foot-height target at once. Running the
# foot target on its own schedule made the solver chase a mismatch and the knee reversed
# several times per settle. Feet share their leg's delay and never overshoot, so the
# knee inherits one smooth curve instead of the difference between three, and never
# overshoots, so a springing body cannot drive a foot through the floor.
FOOT_OVERSHOOT = 0.0

# ------------------------------------------------------------------- variants
CHOP_BEATS = [
    (0.000, "Ready", {
        "LowerTorso": (0, 2, 0, 0, 0, 0), "UpperTorso": (-2, -4, 0), "Head": (0, 2, 0),
        "RightUpperArm": (12, 0, 8), "RightLowerArm": (55, 0, 0),
        "LeftUpperArm": (6, 0, -5), "LeftLowerArm": (12, 0, 0), "LeftHand": (0, 0, 0),
        "RightUpperLeg": (2, 0, 0), "RightFoot": (2, 0, 0),
        "LeftUpperLeg": (-2, 0, 0), "LeftFoot": (2, 0, 0)}),
    (0.045, "Coil", {
        "LowerTorso": (4, -5, 0, 0, -0.14, 0.16), "UpperTorso": (8, -16, -4), "Head": (6, -8, 0),
        "RightUpperArm": (158, -12, 18), "RightLowerArm": (42, 0, 0),
        "LeftUpperArm": (40, 14, -18), "LeftLowerArm": (48, 0, 0), "LeftHand": (-6, 0, 0),
        "RightUpperLeg": (-12, 0, 5), "RightFoot": (10, 0, 0),
        "LeftUpperLeg": (12, 0, -3), "LeftFoot": (8, 0, 0)}),
    (0.072, "Break", {
        "LowerTorso": (0, -3, 0, 0, -0.08, 0.06), "UpperTorso": (-2, -9, -2), "Head": (0, -4, 0),
        "RightUpperArm": (124, -6, 12), "RightLowerArm": (66, 0, 0),
        "LeftUpperArm": (30, 10, -13), "LeftLowerArm": (40, 0, 0), "LeftHand": (-3, 0, 0),
        "RightUpperLeg": (-4, 0, 4), "RightFoot": (8, 0, 0),
        "LeftUpperLeg": (18, 0, -3), "LeftFoot": (7, 0, 0)}),
    (0.100, "Contact", {
        "LowerTorso": (-7, 3, 0, 0, -0.20, -0.28), "UpperTorso": (-20, 7, 3), "Head": (-12, 3, 0),
        "RightUpperArm": (88, 5, 4), "RightLowerArm": (8, 0, 0),
        "LeftUpperArm": (-28, -11, -15), "LeftLowerArm": (24, 0, 0), "LeftHand": (5, 0, 0),
        "RightUpperLeg": (42, 0, 4), "RightFoot": (-5, 0, 0),
        "LeftUpperLeg": (-27, 0, -4), "LeftFoot": (-16, 0, 0)}),
    (0.132, "PunchThrough", {
        "LowerTorso": (-11, 5, 0, 0, -0.30, -0.30), "UpperTorso": (-27, 12, 4), "Head": (-17, 5, 0),
        "RightUpperArm": (40, 14, -4), "RightLowerArm": (4, 0, 0),
        "LeftUpperArm": (-40, -14, -12), "LeftLowerArm": (32, 0, 0), "LeftHand": (8, 0, 0),
        "RightUpperLeg": (50, 0, 3), "RightFoot": (3, 0, 0),
        "LeftUpperLeg": (-30, 0, -3), "LeftFoot": (-20, 0, 0)}),
    (0.185, "Absorb", {
        "LowerTorso": (-13, 4, 0, 0, -0.44, -0.16), "UpperTorso": (-31, 10, 4), "Head": (-14, 4, 0),
        "RightUpperArm": (16, 14, -2), "RightLowerArm": (26, 0, 0),
        "LeftUpperArm": (-34, -13, -9), "LeftLowerArm": (44, 0, 0), "LeftHand": (7, 0, 0),
        "RightUpperLeg": (56, 0, 5), "RightFoot": (14, 0, 0),
        "LeftUpperLeg": (-24, 0, -5), "LeftFoot": (-9, 0, 0)}),
]

HAYMAKER_BEATS = [
    (0.000, "Ready", {
        "LowerTorso": (0, 3, 0, 0, 0, 0), "UpperTorso": (-2, -6, 0), "Head": (0, 3, 0),
        "RightUpperArm": (12, 0, 12), "RightLowerArm": (52, 0, 0),
        "LeftUpperArm": (6, 0, -7), "LeftLowerArm": (14, 0, 0), "LeftHand": (0, 0, 0),
        "RightUpperLeg": (2, 0, 1), "RightFoot": (2, 0, 0),
        "LeftUpperLeg": (-2, 0, -1), "LeftFoot": (2, 0, 0)}),
    (0.055, "Coil", {
        "LowerTorso": (7, -12, 0, 0, -0.20, 0.26), "UpperTorso": (12, -34, -9), "Head": (9, -16, 0),
        "RightUpperArm": (148, -26, 40), "RightLowerArm": (56, 0, 0),
        "LeftUpperArm": (54, 22, -26), "LeftLowerArm": (58, 0, 0), "LeftHand": (-10, 0, 0),
        "RightUpperLeg": (-20, 0, 8), "RightFoot": (14, 0, 0),
        "LeftUpperLeg": (18, 0, -6), "LeftFoot": (12, 0, 0)}),
    (0.078, "Break", {
        "LowerTorso": (2, -6, 0, 0, -0.12, 0.10), "UpperTorso": (1, -19, -4), "Head": (3, -8, 0),
        "RightUpperArm": (114, -12, 28), "RightLowerArm": (76, 0, 0),
        "LeftUpperArm": (40, 15, -19), "LeftLowerArm": (48, 0, 0), "LeftHand": (-5, 0, 0),
        "RightUpperLeg": (-8, 0, 6), "RightFoot": (11, 0, 0),
        "LeftUpperLeg": (24, 0, -5), "LeftFoot": (9, 0, 0)}),
    (0.100, "Contact", {
        "LowerTorso": (-8, 7, 0, 0, -0.24, -0.34), "UpperTorso": (-22, 16, 6), "Head": (-14, 7, 0),
        "RightUpperArm": (82, 12, 8), "RightLowerArm": (10, 0, 0),
        "LeftUpperArm": (-36, -18, -20), "LeftLowerArm": (28, 0, 0), "LeftHand": (7, 0, 0),
        "RightUpperLeg": (48, 0, 5), "RightFoot": (-7, 0, 0),
        "LeftUpperLeg": (-32, 0, -5), "LeftFoot": (-19, 0, 0)}),
    (0.140, "PunchThrough", {
        "LowerTorso": (-13, 12, 0, 0, -0.38, -0.36), "UpperTorso": (-30, 26, 8), "Head": (-20, 12, 0),
        "RightUpperArm": (32, 26, -12), "RightLowerArm": (4, 0, 0),
        "LeftUpperArm": (-50, -22, -16), "LeftLowerArm": (36, 0, 0), "LeftHand": (11, 0, 0),
        "RightUpperLeg": (58, 0, 4), "RightFoot": (5, 0, 0),
        "LeftUpperLeg": (-36, 0, -4), "LeftFoot": (-23, 0, 0)}),
    (0.200, "Absorb", {
        "LowerTorso": (-15, 9, 0, 0, -0.52, -0.18), "UpperTorso": (-34, 20, 7), "Head": (-16, 9, 0),
        "RightUpperArm": (12, 24, 0), "RightLowerArm": (28, 0, 0),
        "LeftUpperArm": (-40, -18, -11), "LeftLowerArm": (50, 0, 0), "LeftHand": (9, 0, 0),
        "RightUpperLeg": (64, 0, 6), "RightFoot": (17, 0, 0),
        "LeftUpperLeg": (-28, 0, -6), "LeftFoot": (-11, 0, 0)}),
]

POGO_BEATS = [
    (0.000, "Ready", {
        "LowerTorso": (0, 2, 0, 0, 0, 0), "UpperTorso": (-2, -4, 0), "Head": (0, 2, 0),
        "RightUpperArm": (12, 0, 8), "RightLowerArm": (55, 0, 0),
        "LeftUpperArm": (6, 0, -5), "LeftLowerArm": (12, 0, 0), "LeftHand": (0, 0, 0),
        "RightUpperLeg": (2, 0, 0), "RightFoot": (2, 0, 0),
        "LeftUpperLeg": (-2, 0, 0), "LeftFoot": (2, 0, 0)}),
    (0.050, "Coil", {
        "LowerTorso": (6, -8, 0, 0, 0.22, 0.14), "UpperTorso": (10, -22, -5), "Head": (8, -10, 0),
        "RightUpperArm": (154, -16, 22), "RightLowerArm": (46, 0, 0),
        "LeftUpperArm": (46, 16, -20), "LeftLowerArm": (54, 0, 0), "LeftHand": (-8, 0, 0),
        "RightUpperLeg": (24, 0, 5), "RightFoot": (16, 0, 0),
        "LeftUpperLeg": (20, 0, -5), "LeftFoot": (14, 0, 0)}),
    (0.075, "Break", {
        "LowerTorso": (2, -4, 0, 0, 0.10, 0.04), "UpperTorso": (0, -12, -3), "Head": (2, -5, 0),
        "RightUpperArm": (122, -8, 16), "RightLowerArm": (70, 0, 0),
        "LeftUpperArm": (34, 12, -15), "LeftLowerArm": (42, 0, 0), "LeftHand": (-4, 0, 0),
        "RightUpperLeg": (18, 0, 4), "RightFoot": (12, 0, 0),
        "LeftUpperLeg": (24, 0, -4), "LeftFoot": (10, 0, 0)}),
    (0.100, "Contact", {
        "LowerTorso": (-9, 4, 0, 0, -0.26, -0.30), "UpperTorso": (-24, 9, 4), "Head": (-15, 4, 0),
        "RightUpperArm": (86, 7, 5), "RightLowerArm": (9, 0, 0),
        "LeftUpperArm": (-30, -13, -17), "LeftLowerArm": (25, 0, 0), "LeftHand": (6, 0, 0),
        "RightUpperLeg": (44, 0, 4), "RightFoot": (-6, 0, 0),
        "LeftUpperLeg": (-28, 0, -4), "LeftFoot": (-17, 0, 0)}),
    (0.135, "PunchThrough", {
        "LowerTorso": (-13, 6, 0, 0, -0.42, -0.30), "UpperTorso": (-30, 15, 5), "Head": (-19, 6, 0),
        "RightUpperArm": (36, 17, -5), "RightLowerArm": (4, 0, 0),
        "LeftUpperArm": (-44, -16, -13), "LeftLowerArm": (33, 0, 0), "LeftHand": (9, 0, 0),
        "RightUpperLeg": (52, 0, 3), "RightFoot": (4, 0, 0),
        "LeftUpperLeg": (-30, 0, -3), "LeftFoot": (-21, 0, 0)}),
    (0.195, "Absorb", {
        "LowerTorso": (-15, 5, 0, 0, -0.62, -0.14), "UpperTorso": (-35, 12, 5), "Head": (-15, 5, 0),
        "RightUpperArm": (14, 16, -3), "RightLowerArm": (28, 0, 0),
        "LeftUpperArm": (-36, -14, -10), "LeftLowerArm": (46, 0, 0), "LeftHand": (8, 0, 0),
        "RightUpperLeg": (60, 0, 6), "RightFoot": (16, 0, 0),
        "LeftUpperLeg": (-20, 0, -6), "LeftFoot": (-8, 0, 0)}),
]

VARIANTS = {
    "Chop": {
        "sequence": "HammerSwingChop",
        "length": 0.80,
        "overshoot": 0.7,      # ~2% past neutral: crisp, businesslike recovery
        "beats": CHOP_BEATS,
        "aim": {
            "Ready": (0.05, 0.85, -0.52), "Coil": (0.08, 0.80, 0.60),
            "Break": (0.04, 0.94, 0.34), "Contact": (0.04, -0.14, -0.99),
            "PunchThrough": (-0.20, -0.36, -0.91), "Absorb": (-0.28, -0.32, -0.90)},
        "feet": {
            "Ready": (0.00, 0.00), "Coil": (0.00, 0.08), "Break": (0.12, 0.00),
            "Contact": (0.48, 0.30), "PunchThrough": (0.26, 0.38), "Absorb": (0.00, 0.16)},
    },
    "Haymaker": {
        "sequence": "HammerSwingHaymaker",
        "length": 1.00,
        "overshoot": 1.5,      # ~8% past neutral: heavy body drifts before it lands
        "beats": HAYMAKER_BEATS,
        "aim": {
            "Ready": (0.06, 0.84, -0.53), "Coil": (0.20, 0.66, 0.72),
            "Break": (0.10, 0.90, 0.42), "Contact": (0.10, -0.12, -0.99),
            "PunchThrough": (-0.40, -0.34, -0.85), "Absorb": (-0.48, -0.30, -0.82)},
        "feet": {
            "Ready": (0.00, 0.00), "Coil": (0.00, 0.12), "Break": (0.18, 0.00),
            "Contact": (0.60, 0.40), "PunchThrough": (0.34, 0.50), "Absorb": (0.00, 0.22)},
    },
    "Pogo": {
        "sequence": "HammerSwingPogo",
        "length": 0.92,
        "overshoot": 2.4,      # ~18% past neutral: one clear inflatable bounce
        "beats": POGO_BEATS,
        "aim": {
            "Ready": (0.05, 0.85, -0.52), "Coil": (0.10, 0.76, 0.64),
            "Break": (0.05, 0.93, 0.36), "Contact": (0.04, -0.20, -0.98),
            "PunchThrough": (-0.24, -0.30, -0.92), "Absorb": (-0.30, -0.28, -0.91)},
        "feet": {
            "Ready": (0.00, 0.00), "Coil": (0.45, 0.40), "Break": (0.50, 0.45),
            "Contact": (0.40, 0.28), "PunchThrough": (0.10, 0.15), "Absorb": (0.00, 0.00)},
    },
}

# --------------------------------------------------------------------- rig
TREE = {
    "HumanoidRootPart": ["LowerTorso"],
    "LowerTorso": ["UpperTorso", "LeftUpperLeg", "RightUpperLeg"],
    "UpperTorso": ["Head", "LeftUpperArm", "RightUpperArm"],
    "LeftUpperArm": ["LeftLowerArm"], "LeftLowerArm": ["LeftHand"], "LeftHand": [],
    "RightUpperArm": ["RightLowerArm"], "RightLowerArm": ["RightHand"], "RightHand": [],
    "LeftUpperLeg": ["LeftLowerLeg"], "LeftLowerLeg": ["LeftFoot"], "LeftFoot": [],
    "RightUpperLeg": ["RightLowerLeg"], "RightLowerLeg": ["RightFoot"], "RightFoot": [],
    "Head": [],
}
ORDER = ["LowerTorso", "UpperTorso", "Head",
         "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperLeg", "RightLowerLeg", "RightFoot",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
PARENT_OF = {c: p for p, cs in TREE.items() for c in cs}

REST = {
    "LowerTorso": [0, -0.10, 0], "UpperTorso": [0, 0.90, 0], "Head": [0, 1.00, 0],
    "RightUpperArm": [0.85, 1.05, 0], "RightLowerArm": [0, -1.15, 0], "RightHand": [0, -1.15, 0],
    "LeftUpperArm": [-0.85, 1.05, 0], "LeftLowerArm": [0, -1.15, 0], "LeftHand": [0, -1.15, 0],
    "RightUpperLeg": [0.50, -0.90, 0], "RightLowerLeg": [0, -1.00, 0], "RightFoot": [0, -0.95, 0],
    "LeftUpperLeg": [-0.50, -0.90, 0], "LeftLowerLeg": [0, -1.00, 0], "LeftFoot": [0, -0.95, 0],
}
GRIP_FROM_WRIST = [0, -0.35, 0]
SOLE_FROM_ANKLE = [0, -0.05, 0]
HAMMER_LENGTH = 2.4
SOLE_BELOW_ROOT = 3.00


# ------------------------------------------------------------- math helpers
def rot_xyz(rx, ry, rz):
    """Roblox CFrame.Angles(x, y, z) == Rx * Ry * Rz, row-major 3x3."""
    x, y, z = map(math.radians, (rx, ry, rz))
    cx, sx = math.cos(x), math.sin(x)
    cy, sy = math.cos(y), math.sin(y)
    cz, sz = math.cos(z), math.sin(z)
    return [[cy * cz, -cy * sz, sy],
            [sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy],
            [-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def add(a, b):
    return [a[i] + b[i] for i in range(3)]


def unit(v):
    m = math.sqrt(sum(c * c for c in v))
    return [c / m for c in v]


def settle_curve(u, overshoot):
    """Rise past the target exactly once, then land on it. Peak = 4c^3/(27(c+1)^2).

    A literal damped spring was the obvious choice and the wrong one: at the low damping
    that gives a lively bounce, roughly one and a half oscillation cycles fit inside the
    settle, so the body shook two or three times instead of following through once. This
    curve's derivative changes sign exactly once at any amplitude, and it lands on the
    target exactly at u=1 rather than leaving a residual to snap out.
    """
    if u <= 0.0:
        return 0.0
    if u >= 1.0:
        return 1.0
    v = u - 1.0
    return 1.0 + (overshoot + 1.0) * v * v * v + overshoot * v * v


def solve(pose):
    frames = {"HumanoidRootPart": (rot_xyz(0, 0, 0), [0, 0, 0])}
    for joint in ORDER:
        pr, pp = frames[PARENT_OF[joint]]
        vals = pose[joint]
        offset = list(REST[joint])
        if len(vals) == 6:
            offset = add(offset, [vals[3], vals[4], vals[5]])
        frames[joint] = (mul(pr, rot_xyz(vals[0], vals[1], vals[2])),
                         add(pp, apply(pr, offset)))
    return frames


def hammer(frames):
    r, p = frames["RightHand"]
    grip = add(p, apply(r, GRIP_FROM_WRIST))
    forward = apply(r, [0, 0, -1])
    return grip, add(grip, [forward[i] * HAMMER_LENGTH for i in range(3)]), forward


def sole(frames, side):
    r, p = frames[f"{side}Foot"]
    return add(p, apply(r, SOLE_FROM_ANKLE))[1] + SOLE_BELOW_ROOT


def segment_gap(a, b, centre, radius):
    ab = [b[i] - a[i] for i in range(3)]
    denom = sum(c * c for c in ab)
    tt = 0.0 if denom < 1e-9 else sum((centre[i] - a[i]) * ab[i] for i in range(3)) / denom
    tt = max(0.0, min(1.0, tt))
    near = [a[i] + ab[i] * tt for i in range(3)]
    return math.sqrt(sum((near[i] - centre[i]) ** 2 for i in range(3))) - radius


def self_clip(frames):
    """Worst penetration of the hammer shaft into the character's own head or torso.

    The torso is a capsule sampled along the pelvis-to-neck line rather than a sphere per
    part: R15's LowerTorso is a flat 2 x 0.4 x 1 slab, and a sphere around its pivot
    reports the fist tucking underneath it as a collision when nothing actually meets.
    The shaft runs 0.22 studs behind the grip, which is where HammerGrip seats it.
    """
    grip, head, forward = hammer(frames)
    tail = [grip[i] - forward[i] * HAMMER_LENGTH * 0.094 for i in range(3)]
    hips, neck = frames["LowerTorso"][1], frames["Head"][1]
    worst = segment_gap(tail, head, add(neck, [0, 0.55, 0]), 0.70)
    for s in range(9):
        f = s / 8
        spine = [hips[i] + (neck[i] - hips[i]) * f for i in range(3)]
        worst = min(worst, segment_gap(tail, head, spine, 0.62))
    return worst


# ------------------------------------------------------------------ solvers
def fit_wrist(pose, aim):
    """Aim the hammer. 3 DOF against a 2-DOF direction; roll is held near zero."""
    w = [0.0, 0.0, 0.0]
    limits = [(-85.0, 85.0), (-60.0, 60.0), (-55.0, 55.0)]

    def cost(cand):
        trial = dict(pose)
        trial["RightHand"] = tuple(cand)
        _, _, fwd = hammer(solve(trial))
        dot = max(-1.0, min(1.0, sum(fwd[i] * aim[i] for i in range(3))))
        return math.degrees(math.acos(dot)) ** 2 + 2.5e-5 * sum(v * v for v in cand)

    best, step = cost(w), 40.0
    while step > 0.02:
        improved = False
        for i in range(3):
            for delta in (step, -step):
                cand = list(w)
                cand[i] = min(limits[i][1], max(limits[i][0], w[i] + delta))
                c = cost(cand)
                if c < best - 1e-10:
                    w, best, improved = cand, c, True
        if not improved:
            step *= 0.5
    return tuple(round(v, 1) for v in w)


def fit_knee(pose, side, target):
    """Bend the knee until the sole sits at `target` above the floor plane."""
    lo, hi = -140.0, 0.0
    for _ in range(70):
        mid = (lo + hi) / 2
        trial = dict(pose)
        trial[f"{side}LowerLeg"] = (mid, 0, 0)
        if sole(solve(trial), side) < target:
            hi = mid
        else:
            lo = mid
    return round((lo + hi) / 2, 1)


def plant(pose, right, left):
    pose["RightLowerLeg"] = (0, 0, 0)
    pose["LeftLowerLeg"] = (0, 0, 0)
    pose["RightLowerLeg"] = (fit_knee(pose, "Right", max(right, 0.0)), 0, 0)
    pose["LeftLowerLeg"] = (fit_knee(pose, "Left", max(left, 0.0)), 0, 0)
    return pose


def build_keys(variant):
    keys = []
    for t, beat, base in variant["beats"]:
        pose = dict(base)
        pose["RightHand"] = (0, 0, 0)
        pose["RightLowerLeg"] = (0, 0, 0)
        pose["LeftLowerLeg"] = (0, 0, 0)
        pose["RightHand"] = fit_wrist(pose, unit(variant["aim"][beat]))
        keys.append((t, beat, plant(pose, *variant["feet"][beat])))

    start_t, _, start = keys[-1]
    ready = keys[0][2]
    ready_feet = variant["feet"]["Ready"]
    start_feet = variant["feet"]["Absorb"]
    span = variant["length"] - start_t
    overshoot = variant["overshoot"]

    for s in range(1, SETTLE_SAMPLES + 1):
        u = s / SETTLE_SAMPLES
        pose = {}
        for joint in LERP_JOINTS:
            d = DELAY[joint]
            local = 0.0 if u <= d else (u - d) / (1.0 - d)
            b = 1.0 if s == SETTLE_SAMPLES else settle_curve(local, overshoot)
            a, z = start[joint], ready[joint]
            pose[joint] = tuple(round(a[i] + (z[i] - a[i]) * b, 3) for i in range(len(a)))
        feet = []
        for i, side in enumerate(("RightUpperLeg", "LeftUpperLeg")):
            d = DELAY[side]
            local = 0.0 if u <= d else (u - d) / (1.0 - d)
            b = 1.0 if s == SETTLE_SAMPLES else settle_curve(local, FOOT_OVERSHOOT)
            feet.append(start_feet[i] + (ready_feet[i] - start_feet[i]) * b)
        keys.append((round(start_t + span * u, 4), f"Settle{s:02d}", plant(pose, *feet)))
    return keys


# --------------------------------------------------------------- validation
def lerp_pose(a, b, f):
    return {j: tuple(a[j][i] + (b[j][i] - a[j][i]) * f for i in range(len(a[j]))) for j in a}


def reversals(keys, after):
    """Direction changes per animated channel past time `after` — the wobble metric.

    Measured strictly inside the generated settle, so the turn-around out of the squash
    is excluded and only the settle's own shape is counted. settle_curve reverses exactly
    once, at its overshoot peak, so every channel should read 0 (barely moves) or 1. Two
    or more means that joint is shaking rather than following through, which is what the
    hand-keyed tail did and what this generator exists to prevent.
    """
    times = [t for t, _, _ in keys]
    counts = {}
    for joint in ORDER:
        for axis in range(len(keys[0][2][joint])):
            series = [(t, keys[i][2][joint][axis]) for i, t in enumerate(times)]
            sign, count = 0, 0
            for i in range(1, len(series)):
                if series[i][0] <= after:
                    continue
                dv = series[i][1] - series[i - 1][1]
                if abs(dv) < 0.35:
                    continue
                s = 1 if dv > 0 else -1
                if sign and s != sign:
                    count += 1
                sign = s
            counts[f"{joint}.{'xyzXYZ'[axis]}"] = count
    hist = {}
    for c in counts.values():
        hist[c] = hist.get(c, 0) + 1
    bad = sorted((ch for ch, c in counts.items() if c >= 2),
                 key=lambda ch: -counts[ch])
    return hist, [(ch, counts[ch]) for ch in bad]


def report(name, variant, keys):
    print(f"\n=== {name} ({variant['sequence']}, {variant['length']:.2f}s, "
          f"overshoot {variant['overshoot']}, {len(keys)} keys) ===")
    print(f"{'t':>6}  {'beat':<13}{'aimErr':>7}{'headF':>7}{'reach':>7}{'speed':>7}"
          f"{'clip':>7}{'Rsole':>7}{'Lsole':>7}")
    prev = None
    for t, beat, pose in keys:
        if beat.startswith("Settle") and beat not in ("Settle01", f"Settle{SETTLE_SAMPLES:02d}"):
            prev = (t, hammer(solve(pose))[1])
            continue
        frames = solve(pose)
        _, head, fwd = hammer(frames)
        err = ""
        if beat in variant["aim"]:
            aim = unit(variant["aim"][beat])
            err = f"{math.degrees(math.acos(max(-1, min(1, sum(fwd[i] * aim[i] for i in range(3)))))):7.1f}"
        speed = ""
        if prev:
            pt, ph = prev
            speed = f"{math.sqrt(sum((head[i] - ph[i]) ** 2 for i in range(3))) / (t - pt):7.0f}"
        print(f"{t:6.3f}  {beat:<13}{err:>7}{head[1] + SOLE_BELOW_ROOT:7.2f}{-head[2]:7.2f}"
              f"{speed:>7}{self_clip(frames):7.2f}{sole(frames, 'Right'):7.2f}"
              f"{sole(frames, 'Left'):7.2f}")
        prev = (t, head)

    low, low_t, fast, fast_t, clip, clip_t = 1e9, 0, 0, 0, 1e9, 0
    ph = pt = None
    for i in range(len(keys) - 1):
        t0, _, p0 = keys[i]
        t1, _, p1 = keys[i + 1]
        for s in range(max(1, int(round((t1 - t0) * 60))) + 1):
            f = s / max(1, int(round((t1 - t0) * 60)))
            t = t0 + (t1 - t0) * f
            frames = solve(lerp_pose(p0, p1, f))
            _, head, _ = hammer(frames)
            if head[1] + SOLE_BELOW_ROOT < low:
                low, low_t = head[1] + SOLE_BELOW_ROOT, t
            if self_clip(frames) < clip:
                clip, clip_t = self_clip(frames), t
            if ph is not None and t > pt:
                v = math.sqrt(sum((head[j] - ph[j]) ** 2 for j in range(3))) / (t - pt)
                if v > fast:
                    fast, fast_t = v, t
            ph, pt = head, t
    settle_t = keys[len(variant["beats"])][0]
    hist, bad = reversals(keys, settle_t)
    print(f"  lowest head {low:5.2f} at t={low_t:.3f} | self-gap {clip:5.2f} at t={clip_t:.3f} "
          f"| peak {fast:.0f} studs/s at t={fast_t:.3f} (marker {MARKER_TIME})")
    spread = "  ".join(f"{k}x:{v}" for k, v in sorted(hist.items()))
    print(f"  settle reversals per channel -> {spread}")
    print(f"  channels shaking (>=2): {', '.join(f'{c}={n}' for c, n in bad) if bad else 'none'}")


# ------------------------------------------------------------- rbxmx output
_ref = [0]


def next_ref():
    _ref[0] += 1
    return f"RBX{_ref[0]}"


def cframe_xml(vals, indent):
    px, py, pz = (vals[3], vals[4], vals[5]) if len(vals) == 6 else (0.0, 0.0, 0.0)
    m = rot_xyz(vals[0], vals[1], vals[2])
    pad = " " * indent
    out = [f'{pad}<CoordinateFrame name="CFrame">']
    for tag, v in (("X", px), ("Y", py), ("Z", pz)):
        out.append(f"{pad}  <{tag}>{v:.6f}</{tag}>")
    for i in range(3):
        for j in range(3):
            out.append(f"{pad}  <R{i}{j}>{m[i][j]:.6f}</R{i}{j}>")
    out.append(f"{pad}</CoordinateFrame>")
    return "\n".join(out)


def pose_xml(joint, pose, indent):
    pad = " " * indent
    vals = pose.get(joint, (0, 0, 0))
    out = [f'{pad}<Item class="Pose" referent="{next_ref()}">',
           f"{pad}  <Properties>",
           f'{pad}    <string name="Name">{joint}</string>',
           cframe_xml(vals, indent + 4),
           # PoseEasingStyle.Linear / PoseEasingDirection.Out. The settle is a baked
           # curve sampled densely, so no Pose relies on the engine's easing.
           f'{pad}    <token name="EasingDirection">0</token>',
           f'{pad}    <token name="EasingStyle">0</token>',
           f'{pad}    <float name="Weight">1</float>',
           f"{pad}  </Properties>"]
    for child in TREE[joint]:
        out.append(pose_xml(child, pose, indent + 2))
    out.append(f"{pad}</Item>")
    return "\n".join(out)


def build(keys, name):
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'  <Item class="KeyframeSequence" referent="{next_ref()}">',
           "    <Properties>",
           f'      <string name="Name">{name}</string>',
           '      <float name="AuthoredHipHeight">2</float>',
           '      <bool name="Loop">false</bool>',
           '      <token name="Priority">5</token>',
           "    </Properties>"]
    for t, _beat, pose in keys:
        out.append(f'    <Item class="Keyframe" referent="{next_ref()}">')
        out.append("      <Properties>")
        out.append('        <string name="Name">Keyframe</string>')
        out.append(f'        <float name="Time">{t:.4f}</float>')
        out.append("      </Properties>")
        if abs(t - MARKER_TIME) < 1e-9:
            out.append(f'      <Item class="KeyframeMarker" referent="{next_ref()}">')
            out.append("        <Properties>")
            out.append(f'          <string name="Name">{MARKER_NAME}</string>')
            out.append('          <string name="Value"></string>')
            out.append("        </Properties>")
            out.append("      </Item>")
        out.append(pose_xml("HumanoidRootPart", pose, 6))
        out.append("    </Item>")
    out += ["  </Item>", "</roblox>", ""]
    return "\n".join(out)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for name, variant in VARIANTS.items():
        keys = build_keys(variant)
        report(name, variant, keys)
        path = os.path.join(here, f"{variant['sequence']}.rbxmx")
        with open(path, "w", encoding="utf-8") as f:
            f.write(build(keys, variant["sequence"]))
        print(f"  wrote {os.path.basename(path)}")
