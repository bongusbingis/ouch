"""Authors four PLACEHOLDER R15 emote KeyframeSequences and validates them.

These are placeholders for a human animator to replace later: 6-10 hand-posed keyframes
per clip, "clearly readable, correct timing, no floor penetration, no joint explosions,"
not polish. All four use the exact rbxmx-authoring technique hammerswing.py established
for this rig.

Reused directly from hammerswing.py, by import (nothing copied -- its generation code is
gated behind `if __name__ == "__main__":`, so importing it as a module is side-effect
free): the FK math (rot_xyz, mul, apply, add, unit, solve), the rig description (TREE,
ORDER, PARENT_OF, REST, SOLE_BELOW_ROOT), the floor-tracking knee solver (fit_knee,
plant, sole) that hammerswing's own Pogo variant uses for its hop, the settle-curve
generator (settle_curve), the validation helper (lerp_pose), and the .rbxmx writer's pose
building blocks (pose_xml, cframe_xml, next_ref). See hammerswing.py's module docstring
for the joint-axis conventions these clips follow: character space +X right, +Y up, -Z
forward; shoulder +X = arm swings up through the front, shoulder +Z = arm abducts;
elbow +X = flexion; waist +X = arch back / -X = fold forward, waist +Y = twist;
knee -X = flexion.

Two things are adapted rather than reused as-is:

  Settle. hammerswing samples its settle at 22 steps per joint, staggered by DELAY, to
  suppress the shake a hand-keyed multi-reversal tail produces under Linear easing --
  that density is solving a combat-wobble problem these clips don't have. A placeholder
  emote just needs its final pose to land clean, not shake-free follow-through, so each
  clip here takes ONE settle_curve sample partway back from its last hand pose to Ready,
  then a last keyframe that IS Ready exactly. Foot targets are blended the same way and
  re-solved through plant(), rather than blending the solved knee angles directly, so the
  settle sample can't reintroduce foot penetration between two validated endpoints.

  Priority. hammerswing's writer hardcodes token value 5 (Action4) for combat swings.
  Roblox's Enum.AnimationPriority is Idle=0, Movement=1, Action=2, Action2=3, Action3=4,
  Action4=5, Core=1000; these clips use Action3 (4), as specified for emotes, so the
  writer below is a copy of hammerswing.build() with that one property changed and the
  KeyframeMarker branch dropped (emotes carry no markers).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hammerswing as hs  # noqa: E402  (path insert must run first)

PRIORITY_ACTION3 = 4  # Enum.AnimationPriority.Action3 -- see module docstring

# --------------------------------------------------------------------- rig / ready pose
# A neutral standing "ready" stance shared by all four clips as both their opening and
# closing pose. LowerTorso is always the 6-value (rotation + translation) form and every
# other joint the 3-value rotation-only form, kept consistent across every beat in this
# file so hs.lerp_pose (equal-length tuples per joint) never trips on a length mismatch.
READY = {
    "LowerTorso": (0, 0, 0, 0, 0, 0), "UpperTorso": (0, 0, 0), "Head": (0, 0, 0),
    "RightUpperArm": (5, 0, 6), "RightLowerArm": (8, 0, 0), "RightHand": (0, 0, 0),
    "LeftUpperArm": (5, 0, -6), "LeftLowerArm": (8, 0, 0), "LeftHand": (0, 0, 0),
    "RightUpperLeg": (0, 0, 0), "RightLowerLeg": (0, 0, 0), "RightFoot": (0, 0, 0),
    "LeftUpperLeg": (0, 0, 0), "LeftLowerLeg": (0, 0, 0), "LeftFoot": (0, 0, 0),
}
READY_FEET = (0.0, 0.0)  # (right, left) sole target height above the floor plane


def make_pose(overrides):
    """Ready plus per-joint overrides for one beat, same pattern as hammerswing's beats:
    each beat restates every joint it cares about in full, not as a delta from the
    previous one."""
    p = dict(READY)
    p.update(overrides)
    return p


# ------------------------------------------------------------------------- Wave beats
# Right arm raises overhead and waves 3x (WaveOut/WaveIn x3 = three swings), small torso
# lean throughout, settle back to Ready. Feet stay flat on the floor the whole clip.
WAVE_TORSO = {"LowerTorso": (-3, 0, 0, 0, 0, 0), "UpperTorso": (-4, 0, 3), "Head": (0, 0, 2)}
WAVE_RAISE = {**WAVE_TORSO,
              "RightUpperArm": (150, -5, 15), "RightLowerArm": (20, 0, 0), "RightHand": (0, 0, 0)}
WAVE_OUT = {**WAVE_TORSO,
            "RightUpperArm": (150, -5, 28), "RightLowerArm": (20, 0, 0), "RightHand": (0, 0, 22)}
WAVE_IN = {**WAVE_TORSO,
           "RightUpperArm": (150, -5, 2), "RightLowerArm": (20, 0, 0), "RightHand": (0, 0, -22)}
WAVE_LEAN = {
    "LowerTorso": (-1, 0, 0, 0, 0, 0), "UpperTorso": (-2, 0, 1), "Head": (0, 0, 1),
    "RightUpperArm": (85, -2, 15), "RightLowerArm": (14, 0, 0), "RightHand": (0, 0, 0),
}

WAVE_BEATS = [
    (0.00, "Ready", {}, (0.0, 0.0)),
    (0.40, "RaiseOverhead", WAVE_RAISE, (0.0, 0.0)),
    (0.70, "WaveOut1", WAVE_OUT, (0.0, 0.0)),
    (0.95, "WaveIn1", WAVE_IN, (0.0, 0.0)),
    (1.20, "WaveOut2", WAVE_OUT, (0.0, 0.0)),
    (1.45, "WaveIn2", WAVE_IN, (0.0, 0.0)),
    (1.70, "WaveOut3", WAVE_OUT, (0.0, 0.0)),
    (2.10, "LeanSettle", WAVE_LEAN, (0.0, 0.0)),
]

# ------------------------------------------------------------------------ Twirl beats
# Arms out to the sides, one full 360 degree yaw of the whole body keyed progressively
# in 90 degree steps (0.30s -> 1.90s = 1.6s) so each segment is an unambiguous short-arc
# rotation rather than one 0->360 snap (which would slerp as no rotation at all -- 0 and
# 360 share a rotation matrix). LowerTorso carries the yaw because it is TREE's root of
# everything but the (never-posed) HumanoidRootPart, so rotating it spins the whole body
# as one rigid piece while every child's own local rotation (arms held out) rides along
# unchanged. Spin360 is keyed at 360 (reached honestly via the progressive steps);
# ArmsUp is keyed at 0 -- same matrix as 360, and the two keyframes are adjacent with
# nothing else changing on that channel, so the switch is invisible and every later pose
# (and the settle blend) only ever deals with 0, never wraps through 360.
ARMS_OUT = {"RightUpperArm": (0, 0, 85), "RightLowerArm": (0, 0, 0), "RightHand": (0, 0, 0),
            "LeftUpperArm": (0, 0, -85), "LeftLowerArm": (0, 0, 0), "LeftHand": (0, 0, 0)}
ARMS_UP = {"LowerTorso": (0, 0, 0, 0, 0, 0),
           "RightUpperArm": (150, 0, 20), "RightLowerArm": (10, 0, 0), "RightHand": (0, 0, 0),
           "LeftUpperArm": (150, 0, -20), "LeftLowerArm": (10, 0, 0), "LeftHand": (0, 0, 0)}


def yawed(deg):
    return {**ARMS_OUT, "LowerTorso": (0, deg, 0, 0, 0, 0)}


TWIRL_BEATS = [
    (0.00, "Ready", {}, (0.0, 0.0)),
    (0.30, "ArmsOut", yawed(0), (0.0, 0.0)),
    (0.70, "Spin090", yawed(90), (0.0, 0.0)),
    (1.10, "Spin180", yawed(180), (0.0, 0.0)),
    (1.50, "Spin270", yawed(270), (0.0, 0.0)),
    (1.90, "Spin360", yawed(360), (0.0, 0.0)),
    (2.30, "ArmsUp", ARMS_UP, (0.0, 0.0)),
]

# ------------------------------------------------------------------------- Flex beats
# Double-bicep curl (shoulders abducted ~90, elbows flexed ~120), held with a small
# alternating shoulder pump x2 (PumpA/PumpB twice), settle. Feet flat throughout.
FLEX_CURL = {
    "LowerTorso": (-2, 0, 0, 0, 0, 0), "UpperTorso": (-3, 0, 0),
    "RightUpperArm": (20, 0, 90), "RightLowerArm": (120, 0, 0), "RightHand": (0, 0, 0),
    "LeftUpperArm": (20, 0, -90), "LeftLowerArm": (120, 0, 0), "LeftHand": (0, 0, 0),
}
FLEX_PUMP_A = {**FLEX_CURL, "RightUpperArm": (24, 0, 100), "RightLowerArm": (128, 0, 0),
               "LeftUpperArm": (18, 0, -82), "LeftLowerArm": (114, 0, 0)}
FLEX_PUMP_B = {**FLEX_CURL, "RightUpperArm": (18, 0, 82), "RightLowerArm": (114, 0, 0),
               "LeftUpperArm": (24, 0, -100), "LeftLowerArm": (128, 0, 0)}

FLEX_BEATS = [
    (0.00, "Ready", {}, (0.0, 0.0)),
    (0.55, "Curl", FLEX_CURL, (0.0, 0.0)),
    (1.15, "PumpA", FLEX_PUMP_A, (0.0, 0.0)),
    (1.70, "PumpB", FLEX_PUMP_B, (0.0, 0.0)),
    (2.25, "PumpA2", FLEX_PUMP_A, (0.0, 0.0)),
    (2.80, "PumpB2", FLEX_PUMP_B, (0.0, 0.0)),
]

# ----------------------------------------------------------------------- Bounce beats
# Three hops. Each is a Down (root drops -0.28 studs, squash) / Up (root rises +0.45,
# feet target 0.60 studs off the floor -- more than the rise, since a tucked knee can
# only lift the sole above the straight-leg baseline, never below it) pair; the feet
# targets are what make it a real hop rather than a knee-bend -- exactly hammerswing's
# Pogo trick (see its POGO_BEATS "feet" targets), reused here through the same
# plant()/fit_knee() solver so the knee angle is whatever keeps the sole at that target
# regardless of where the root sits. Arms swing loosely (back on Down, forward on Up).
#
# Magnitudes are pulled in from the table's ~1.2-stud guidance: a straight leg's sole
# height is flat (zero-derivative) right at knee=0, so any segment that starts or ends
# on a straight leg while the target height is also changing is poorly approximated by
# Roblox's linear in-between -- validate() caught a -0.095 stud floor penetration
# partway through the first, largest such jump (Ready's straight leg into Down1's
# compensating bend). Once the knee is already bent, further changes track linearly
# fine (validate() shows ~0 error on every Down<->Up hop-to-hop segment below); the
# straight-leg step is the one that needed both a shallower squash and a second,
# closer-to-Ready keyframe to stay on the floor plane.
BOUNCE_DOWN = {
    "LowerTorso": (2, 0, 0, 0, -0.28, 0),
    "RightUpperArm": (-15, 0, 8), "RightLowerArm": (10, 0, 0), "RightHand": (0, 0, 0),
    "LeftUpperArm": (-15, 0, -8), "LeftLowerArm": (10, 0, 0), "LeftHand": (0, 0, 0),
}
BOUNCE_UP = {
    "LowerTorso": (-2, 0, 0, 0, 0.45, 0),
    "RightUpperArm": (35, 0, 10), "RightLowerArm": (15, 0, 0), "RightHand": (0, 0, 0),
    "LeftUpperArm": (35, 0, -10), "LeftLowerArm": (15, 0, 0), "LeftHand": (0, 0, 0),
}
BOUNCE_FEET_UP = (0.60, 0.60)


def blend_overrides(a, b, f):
    """Poses a and b blended toward b by fraction f (both already full, post-make_pose
    dicts). Used once, below, to split the opening Ready -> Down1 step: see the comment
    above BOUNCE_DOWN for why that particular step needs it. f=0.24, not 0.5 -- because
    the straight-leg end of the step is where the approximation is worst (zero-derivative
    point), the extra keyframe needs to sit closer to Ready than to Down1 to bring the
    worst-case floor error down (checked numerically while tuning this clip)."""
    return {j: tuple(a[j][i] + (b[j][i] - a[j][i]) * f for i in range(len(a[j]))) for j in a}


BOUNCE_CROUCH1 = blend_overrides(READY, make_pose(BOUNCE_DOWN), 0.24)

BOUNCE_BEATS = [
    (0.00, "Ready", {}, (0.0, 0.0)),
    (0.10, "Crouch1", BOUNCE_CROUCH1, (0.0, 0.0)),
    (0.28, "Down1", BOUNCE_DOWN, (0.0, 0.0)),
    (0.52, "Up1", BOUNCE_UP, BOUNCE_FEET_UP),
    (0.90, "Down2", BOUNCE_DOWN, (0.0, 0.0)),
    (1.14, "Up2", BOUNCE_UP, BOUNCE_FEET_UP),
    (1.52, "Down3", BOUNCE_DOWN, (0.0, 0.0)),
    (1.76, "Up3", BOUNCE_UP, BOUNCE_FEET_UP),
]

CLIPS = [
    ("EmoteWave.rbxmx", "Wave", WAVE_BEATS, 3.2),
    ("EmoteTwirl.rbxmx", "Twirl", TWIRL_BEATS, 4.0),
    ("EmoteFlex.rbxmx", "Flex", FLEX_BEATS, 3.6),
    ("EmoteBounce.rbxmx", "Bounce", BOUNCE_BEATS, 3.2),
]


# --------------------------------------------------------------------- clip assembly
def build_clip(beats, duration, settle_u=0.4, overshoot=0.6):
    """Hand-posed beats (each already floor-planted via hs.plant), plus one
    settle_curve sample easing the last beat back to Ready, plus Ready itself as the
    final keyframe. See the module docstring for why one sample is enough here."""
    keys = [(t, name, hs.plant(make_pose(overrides), *feet)) for t, name, overrides, feet in beats]

    t_last, _, pose_last = keys[-1]
    _, _, _, feet_last = beats[-1]
    ready_planted = hs.plant(make_pose({}), *READY_FEET)

    b = hs.settle_curve(settle_u, overshoot)
    blended = {}
    for joint, a in pose_last.items():
        if joint in ("RightLowerLeg", "LeftLowerLeg"):
            continue  # re-solved below against the blended foot target, not blended directly
        z = ready_planted[joint]
        blended[joint] = tuple(round(a[i] + (z[i] - a[i]) * b, 3) for i in range(len(a)))
    mid_feet = tuple(feet_last[i] + (READY_FEET[i] - feet_last[i]) * b for i in range(2))
    t_mid = round(t_last + (duration - t_last) * settle_u, 4)

    keys.append((t_mid, "Settle", hs.plant(blended, *mid_feet)))
    keys.append((round(duration, 4), "Ready", ready_planted))
    return keys


# --------------------------------------------------------------------- validation
def validate(name, keys, duration):
    """Adapted from hammerswing's report()/validation loop: monotonically increasing
    keyframe times ending exactly at duration, no NaN, and no sole below the floor
    plane, checked both at each keyframe and densely (60fps) across every segment via
    hs.lerp_pose, same sampling hammerswing's own report() uses."""
    times = [t for t, _, _ in keys]
    ok = True
    if times[0] != 0.0:
        print(f"  [{name}] FAIL: first time {times[0]} != 0")
        ok = False
    if abs(times[-1] - duration) > 1e-6:
        print(f"  [{name}] FAIL: last time {times[-1]} != duration {duration}")
        ok = False
    for a, z in zip(times, times[1:]):
        if z <= a:
            print(f"  [{name}] FAIL: times not strictly increasing ({a} -> {z})")
            ok = False

    low, low_t, nan = 1e9, 0.0, False
    for i in range(len(keys) - 1):
        t0, _, p0 = keys[i]
        t1, _, p1 = keys[i + 1]
        steps = max(1, int(round((t1 - t0) * 60)))
        for s in range(steps + 1):
            f = s / steps
            t = t0 + (t1 - t0) * f
            pose = hs.lerp_pose(p0, p1, f)
            for vals in pose.values():
                for v in vals:
                    if v != v:  # NaN
                        nan = True
            frames = hs.solve(pose)
            for side in ("Right", "Left"):
                h = hs.sole(frames, side)
                if h < low:
                    low, low_t = h, t
    if nan:
        print(f"  [{name}] FAIL: NaN encountered")
        ok = False
    if low < -0.02:
        print(f"  [{name}] FAIL: foot below floor, lowest sole {low:.3f} at t={low_t:.3f}")
        ok = False

    print(f"  [{name}] {len(keys)} keyframes, {times[0]:.2f}s-{times[-1]:.2f}s, "
          f"lowest sole {low:.3f} at t={low_t:.3f} -> {'PASS' if ok else 'FAIL'}")
    return ok


# ------------------------------------------------------------------- rbxmx writer
def build(name, keys):
    """Adapted from hammerswing.build(): Priority is Action3 (4) instead of hammerswing's
    hardcoded combat value (5, Action4), and there is no KeyframeMarker branch -- emotes
    carry no markers. Everything else (the roblox/KeyframeSequence/Keyframe scaffolding,
    pose_xml for the Pose tree) is hammerswing's own writer, called directly."""
    hs._ref[0] = 0
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'  <Item class="KeyframeSequence" referent="{hs.next_ref()}">',
           "    <Properties>",
           f'      <string name="Name">{name}</string>',
           '      <float name="AuthoredHipHeight">2</float>',
           '      <bool name="Loop">false</bool>',
           f'      <token name="Priority">{PRIORITY_ACTION3}</token>',
           "    </Properties>"]
    for t, _beat, pose in keys:
        out.append(f'    <Item class="Keyframe" referent="{hs.next_ref()}">')
        out.append("      <Properties>")
        out.append('        <string name="Name">Keyframe</string>')
        out.append(f'        <float name="Time">{t:.4f}</float>')
        out.append("      </Properties>")
        out.append(hs.pose_xml("HumanoidRootPart", pose, 6))
        out.append("    </Item>")
    out += ["  </Item>", "</roblox>", ""]
    return "\n".join(out)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    all_ok = True
    for filename, name, beats, duration in CLIPS:
        keys = build_clip(beats, duration)
        print(f"\n=== {name} ({filename}, {duration:.2f}s) ===")
        all_ok &= validate(name, keys, duration)
        path = os.path.join(here, filename)
        with open(path, "w", encoding="utf-8") as f:
            f.write(build(name, keys))
        print(f"  wrote {filename}")
    if not all_ok:
        raise SystemExit("validation failed")
